"""Per-company training: chronological dataset -> Isolation Forest -> evaluation against the robust
baseline using injected anomalies -> activation gate. Uses only the given company's records."""

from __future__ import annotations

import copy
import dataclasses
import math
import time
from dataclasses import dataclass, field
from datetime import date

import numpy as np
from sklearn.ensemble import IsolationForest
from sklearn.impute import SimpleImputer
from sklearn.metrics import average_precision_score, roc_auc_score
from sklearn.pipeline import Pipeline
from sklearn.preprocessing import RobustScaler

from app.core.config import MlSettings
from app.data.feature_extractor import FEATURE_SCHEMA_VERSION, MODEL_FEATURES, build_features, to_frame
from app.data.observations import HistoryIndex, Observation, group_observations
from app.domain.enums import Detector, ModelStatus, TrainingStatus
from app.domain.models import CompanyRef, PayItem, PayRecordSnapshot
from app.ml.baseline import baseline_score


@dataclass
class Row:
    obs: Observation
    window: list[Observation]
    features: dict[str, float]


def build_rows(records: list[PayRecordSnapshot], ml: MlSettings, overtime_codes: frozenset[str]) -> list[Row]:
    usable = [r for r in records if r.has_payload and r.status_id in (2, 4)]
    index = HistoryIndex(usable)
    contracts: dict[tuple, set[int]] = {}
    for r in usable:
        contracts.setdefault((r.user_id, r.cycle_code, r.period), set()).add(r.contract_id)
    rows: list[Row] = []
    for obs in group_observations(usable).values():
        window, _ = index.window(obs.user_id, obs.contract_id, obs.cycle_code, obs.period,
                                 ml.history_window_periods, ml.min_history_periods_for_scoring)
        if len(window) < ml.min_history_periods_for_scoring:
            continue
        f = build_features(obs, window, contract_count=len(contracts[(obs.user_id, obs.cycle_code, obs.period)]),
                           overtime_tracked=bool(overtime_codes))
        rows.append(Row(obs, window, f))
    rows.sort(key=lambda r: r.obs.period)
    return rows


# ---------------------------------------------------------------- anomaly injection (evaluation only)
def _replace(obs: Observation, mutate) -> Observation:
    recs = [copy.deepcopy(r) for r in obs.records]
    r = recs[-1]
    mutate(r)
    r.total_allowance = sum(i.amount for i in r.items if i.is_earning)
    r.total_deduction = sum(i.amount for i in r.items if not i.is_earning)
    gross = (r.basic_earned or 0) + r.total_allowance - r.total_deduction + (r.back_pay or 0)
    r.gross_engine = gross
    r.net_pay = max(0.0, gross - (r.cpf_employee or 0))
    return Observation(obs.user_id, obs.contract_id, obs.cycle_code, obs.period, recs)


def _salary(r):
    r.basic_contractual = (r.basic_contractual or 0) * 1.5
    r.basic_earned = (r.basic_earned or 0) * 1.5


def _dup(r):
    e = [i for i in r.items if i.is_earning]
    r.items.append(e[0] if e else PayItem("TRAN", "dup", True, 200.0, "Ordinary", 1, 0, 200.0, 1.0, None))


def _missing(r):
    e = [i for i in r.items if i.is_earning and i.recurring_method == 1]
    if e:
        r.items.remove(e[0])


def _deduction(r):
    r.items.append(PayItem("ADHOC_DED", "deduction", False, max(300.0, (r.basic_earned or 0) * 0.3), "None", 5, 2, None, 1.0, None))


def _net(r):
    r.items.append(PayItem("ADHOC_PAY", "payment", True, (r.net_pay or 1000) * 0.55, "Ordinary", 5, 2, None, 1.0, None))


SCENARIOS = {"salary_increase_50": _salary, "duplicate_allowance": _dup, "missing_recurring_allowance": _missing,
             "deduction_spike": _deduction, "net_jump_55": _net}


# ---------------------------------------------------------------- model
def make_pipeline(ml: MlSettings) -> Pipeline:
    return Pipeline([
        ("impute", SimpleImputer(strategy="median", add_indicator=True, keep_empty_features=True)),
        ("scale", RobustScaler()),
        ("iforest", IsolationForest(n_estimators=ml.isolation_forest_estimators, max_samples=ml.isolation_forest_max_samples,
                                    contamination="auto", random_state=ml.random_state)),
    ])


def raw_scores(pipeline: Pipeline, feature_rows: list[dict[str, float]]) -> np.ndarray:
    return -pipeline.score_samples(to_frame(feature_rows, MODEL_FEATURES))


@dataclass
class TrainingResult:
    status: str
    pipeline: Pipeline | None = None
    detector: str = Detector.ROBUST_BASELINE.value
    score_quantiles: list[float] = field(default_factory=list)
    feature_medians: dict[str, float] = field(default_factory=dict)
    feature_scales: dict[str, float] = field(default_factory=dict)
    report: dict = field(default_factory=dict)
    gate: dict = field(default_factory=dict)
    record_count: int = 0
    period_start: date | None = None
    period_end: date | None = None
    duration_ms: int = 0


def _metrics(labels, scores, alert_threshold) -> dict:
    labels, scores = np.asarray(labels), np.nan_to_num(np.asarray(scores, dtype=float), nan=0.0)
    clean = scores[labels == 0]
    return {
        "roc_auc": round(float(roc_auc_score(labels, scores)), 4),
        "average_precision": round(float(average_precision_score(labels, scores)), 4),
        "recall_at_alert": round(float(np.mean(scores[labels == 1] >= alert_threshold)), 4),
        "clean_alert_rate": round(float(np.mean(clean >= alert_threshold)), 4) if clean.size else None,
    }


def evaluate(pipeline: Pipeline, train_scores: np.ndarray, valid: list[Row], ml: MlSettings,
             overtime_codes: frozenset[str], active: Pipeline | None = None) -> dict:
    feats, labels, scen = [], [], []
    for row in valid:
        feats.append(row.features); labels.append(0); scen.append("clean")
        for name, fn in SCENARIOS.items():
            inj = _replace(row.obs, fn)
            feats.append(build_features(inj, row.window, overtime_tracked=bool(overtime_codes)))
            labels.append(1); scen.append(name)
    if_scores = raw_scores(pipeline, feats)
    if_thr = float(np.percentile(train_scores, ml.alert_percentile))
    base = np.array([baseline_score(f) for f in feats])
    base_thr = 6.0
    report = {
        "n_validation_rows": len(valid), "n_injected": int(sum(labels)),
        "detectors": {
            Detector.ISOLATION_FOREST.value: _metrics(labels, if_scores, if_thr),
            Detector.ROBUST_BASELINE.value: _metrics(labels, base, base_thr),
        },
        "per_scenario_recall": {
            s: {Detector.ISOLATION_FOREST.value: round(float(np.mean([if_scores[i] >= if_thr for i in range(len(scen)) if scen[i] == s])), 4),
                Detector.ROBUST_BASELINE.value: round(float(np.mean([base[i] >= base_thr for i in range(len(scen)) if scen[i] == s])), 4)}
            for s in SCENARIOS
        },
        "thresholds": {"if_alert_percentile": ml.alert_percentile, "baseline_alert_rz": base_thr},
    }
    if active is not None:
        try:
            report["active_model_average_precision"] = _metrics(labels, raw_scores(active, feats), if_thr)["average_precision"]
        except Exception:  # noqa: BLE001 - incompatible active model is simply not compared
            report["active_model_average_precision"] = None
    return report


def train_company_model(*, company: CompanyRef, history_records: list[PayRecordSnapshot], ml: MlSettings,
                        overtime_codes: frozenset[str] = frozenset(), active_pipeline: Pipeline | None = None,
                        auto_activate: bool = True) -> TrainingResult:
    started = time.perf_counter()
    records = [r for r in history_records if r.period and r.pay_run_id]
    rows = build_rows(records, ml, overtime_codes)
    periods = sorted({r.obs.period for r in rows})
    result = TrainingResult(status=TrainingStatus.INSUFFICIENT_DATA.value, record_count=len(rows),
                            period_start=periods[0] if periods else None, period_end=periods[-1] if periods else None)
    if len(rows) < ml.min_training_observations or len(periods) < ml.min_training_periods:
        result.report = {"reason": f"{len(rows)} observations over {len(periods)} periods; need "
                                   f"{ml.min_training_observations} over {ml.min_training_periods}"}
        result.duration_ms = int((time.perf_counter() - started) * 1000)
        return result

    n_valid = max(2, math.ceil(len(periods) * ml.validation_fraction))
    cut = periods[-n_valid]
    train, valid = [r for r in rows if r.obs.period < cut], [r for r in rows if r.obs.period >= cut]
    pipeline = make_pipeline(ml).fit(to_frame([r.features for r in train], MODEL_FEATURES))
    train_scores = raw_scores(pipeline, [r.features for r in train])
    report = evaluate(pipeline, train_scores, valid, ml, overtime_codes, active_pipeline)

    # refit on everything for production use; evaluation stays on the held-out periods
    final = make_pipeline(ml).fit(to_frame([r.features for r in rows], MODEL_FEATURES))
    final_scores = raw_scores(final, [r.features for r in rows])
    frame = to_frame([r.features for r in rows], MODEL_FEATURES)
    med = frame.median(skipna=True)
    mad = (frame - med).abs().median(skipna=True) * 1.4826

    if_m = report["detectors"][Detector.ISOLATION_FOREST.value]
    base_m = report["detectors"][Detector.ROBUST_BASELINE.value]
    # champion = best recall at the operating threshold among detectors within the clean-alert budget;
    # average precision is reported but is inflated by the injected:clean ratio, so it does not decide
    def _ok(m):
        return (m["clean_alert_rate"] or 0) <= ml.gate_max_clean_alert_rate
    detector = Detector.ISOLATION_FOREST if (_ok(if_m) and (not _ok(base_m) or if_m["recall_at_alert"] > base_m["recall_at_alert"])) else Detector.ROBUST_BASELINE
    champ = if_m if detector == Detector.ISOLATION_FOREST else base_m
    report["champion"] = detector.value
    report["champion_rule"] = "max recall_at_alert subject to clean_alert_rate <= gate_max_clean_alert_rate"

    reasons = []
    if champ["recall_at_alert"] < ml.gate_min_recall_at_alert or champ["average_precision"] < ml.gate_min_average_precision:
        reasons.append("detection quality below minimum")
    if (champ["clean_alert_rate"] or 0) > ml.gate_max_clean_alert_rate:
        reasons.append("clean alert rate above maximum")
    rejected = bool(reasons)
    active_ap = report.get("active_model_average_precision")
    if not rejected and active_ap is not None and if_m["average_precision"] < active_ap - ml.gate_max_ap_regression:
        reasons.append("worse than the active model")
    if not rejected and not auto_activate:
        reasons.append("auto activation disabled for company")
    activate = not reasons
    status = ModelStatus.REJECTED if rejected else (ModelStatus.ACTIVE if activate else ModelStatus.TRAINED)

    result.status = TrainingStatus.REJECTED.value if rejected else TrainingStatus.SUCCEEDED.value
    result.pipeline, result.detector, result.report = final, detector.value, report
    result.score_quantiles = [float(q) for q in np.quantile(final_scores, np.linspace(0, 1, 1001))]
    result.feature_medians = {k: (None if math.isnan(v) else float(v)) for k, v in med.items()}
    result.feature_scales = {k: (None if math.isnan(v) else max(float(v), 1e-6)) for k, v in mad.items()}
    result.gate = {"activate": activate, "model_status": status.value, "reason": "; ".join(reasons) or "passed"}
    result.duration_ms = int((time.perf_counter() - started) * 1000)
    return result


__all__ = ["TrainingResult", "train_company_model", "build_rows", "raw_scores", "SCENARIOS", "dataclasses"]
