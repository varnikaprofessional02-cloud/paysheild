"""Pure analysis of one pay run: observations -> features -> scorer -> rules -> risk scoring.
No I/O; repositories are queried by the caller (analysis_service)."""

from __future__ import annotations

from collections import defaultdict

import numpy as np

from app.core.config import MlSettings
from app.data.feature_extractor import build_features, json_safe
from app.data.observations import HistoryIndex, group_observations
from app.domain.enums import AnomalyType, Confidence, Detector, FindingSource, MlStatus, Severity
from app.domain.models import (
    AnalysisOutcome, ConfiguredPayItem, Evidence, Finding, PayRecordSnapshot, PayRunRef, SalaryRevision,
)
from app.ml.scoring import ObservationScorer, ScoringRow
from app.rules.engine import RuleContext, Thresholds, data_quality_findings, run_rules

BASE_RISK = {Severity.LOW: 25, Severity.MEDIUM: 50, Severity.HIGH: 75, Severity.CRITICAL: 90}


def _confidence(history: int, key: str) -> Confidence:
    if history >= 6 and key == "contract":
        return Confidence.HIGH
    return Confidence.MEDIUM if history >= 3 else Confidence.LOW


def analyze(*, pay_run: PayRunRef, run_records: list[PayRecordSnapshot], history_records: list[PayRecordSnapshot],
            same_period_records: list[PayRecordSnapshot], revisions: list[SalaryRevision],
            configured: list[ConfiguredPayItem], overtime_codes: frozenset[str], thresholds: Thresholds,
            scorer: ObservationScorer, ml: MlSettings) -> AnalysisOutcome:
    usable = [r for r in run_records if r.has_payload and r.status_id in (2, 4)]
    findings: list[Finding] = data_quality_findings([r for r in run_records if r not in usable])
    warnings: list[str] = []
    index = HistoryIndex(history_records)
    other_obs = group_observations(same_period_records)
    revs, cfg = defaultdict(list), defaultdict(list)
    for r in revisions:
        revs[r.user_id].append(r)
    for c in configured:
        cfg[c.user_id].append(c)
    contracts = defaultdict(set)
    for r in usable:
        contracts[r.user_id].add(r.contract_id)
    ot_hist = [o.overtime_amount(True) for s in index.series().values() for o in s] if overtime_codes else []
    ot_hist = [v for v in ot_hist if v]
    company_ot_p99 = float(np.percentile(ot_hist, 99)) if len(ot_hist) >= 50 else None

    contexts, rows = [], []
    for obs in group_observations(usable).values():
        window, key = index.window(obs.user_id, obs.contract_id, obs.cycle_code, obs.period,
                                   ml.history_window_periods, ml.min_history_periods_for_scoring)
        feats = build_features(obs, window, contract_count=len(contracts[obs.user_id]), overtime_tracked=bool(overtime_codes))
        contexts.append((obs, window, key, feats))
        rows.append(ScoringRow(obs.user_id, obs.contract_id, feats, len(window)))
    scores = {(s.user_id, s.contract_id): s for s in scorer.score(rows)}

    for obs, window, key, feats in contexts:
        ctx = RuleContext(obs, window, key, pay_run.pay_run_date.date(), revs[obs.user_id], cfg[obs.user_id],
                          [o for k, o in other_obs.items() if k[0] == obs.user_id], bool(overtime_codes), thresholds,
                          company_ot_p99)
        rule_findings, w = run_rules(ctx)
        warnings += w
        score = scores.get((obs.user_id, obs.contract_id))
        conf = _confidence(len(window), key)
        pct = score.ml_percentile if score else None
        for f in rule_findings:
            f.confidence = conf
            f.features = json_safe(feats)
            f.ml_percentile = pct
            f.risk_score = BASE_RISK[f.severity] + (5 if len(window) >= 6 and f.current_value is not None else 0)
            if pct is not None and pct >= thresholds.alert_percentile:
                f.risk_score += 5
            if f.is_explained:
                f.severity = min(f.severity, Severity.MEDIUM, key=lambda s: s.rank)
                f.risk_score = min(f.risk_score, 45)
            f.risk_score = min(100, f.risk_score)
        if not rule_findings and score is not None:
            if obs.bonus_total + obs.aw_total > 0:
                # a bonus / AW payment legitimately inflates gross, net and allowance totals; judge the
                # statistical outlier only on what a bonus cannot explain (contract salary, deductions)
                score.baseline_score = max([abs(feats.get("rz_basic_contractual") or 0.0) if feats.get("rz_basic_contractual") == feats.get("rz_basic_contractual") else 0.0,
                                            feats.get("rz_deduction_total") if feats.get("rz_deduction_total") == feats.get("rz_deduction_total") else 0.0])
                score.ml_percentile = None
            ml_f = _model_finding(obs, score, scorer, thresholds, conf, feats)
            if ml_f:
                rule_findings.append(ml_f)
        findings += rule_findings

    findings.sort(key=lambda f: (-f.risk_score, f.user_id))
    return AnalysisOutcome(pay_run=pay_run, findings=findings, scores=list(scores.values()), total_records=len(run_records),
                           total_employees=len({r.user_id for r in run_records}), ml_status=scorer.ml_status,
                           model_uid=scorer.model_uid, model_version=scorer.model_version, detector=scorer.detector,
                           warnings=warnings)


def _model_finding(obs, score, scorer, t: Thresholds, conf, feats) -> Finding | None:
    evidence = [Evidence("model" if score.ml_percentile is not None else "baseline", scorer.model_uid,
                         {"top_contributors": score.top_contributors})]
    if scorer.detector == Detector.ISOLATION_FOREST.value and scorer.ml_status == MlStatus.SCORED.value \
            and score.ml_percentile is not None and score.ml_percentile >= t.alert_percentile:
        sev = Severity.MEDIUM if score.ml_percentile >= 99.5 else Severity.LOW
        return Finding(AnomalyType.UNUSUAL_PAY_PATTERN, FindingSource.ML, sev, obs.user_id, obs.contract_id,
                       obs.latest.pay_record_id,
                       f"Pay pattern is more unusual than {score.ml_percentile:.1f}% of this company's historical pay observations.",
                       "Review the highlighted components against the employee's recent payslips.",
                       ml_percentile=score.ml_percentile, confidence=conf, risk_score=min(70, round(score.ml_percentile * 0.6)),
                       evidence=evidence, features=json_safe(feats))
    if scorer.detector == Detector.ROBUST_BASELINE.value and score.baseline_score is not None \
            and score.baseline_score >= t.baseline_alert_rz:
        sev = Severity.MEDIUM if score.baseline_score >= 10 else Severity.LOW
        return Finding(AnomalyType.UNUSUAL_PAY_PATTERN, FindingSource.BASELINE, sev, obs.user_id, obs.contract_id,
                       obs.latest.pay_record_id,
                       f"A pay component is {score.baseline_score:.1f} robust standard deviations from the employee's own history.",
                       "Review the highlighted components against the employee's recent payslips.",
                       confidence=conf, risk_score=min(65, 30 + round(score.baseline_score * 2)),
                       evidence=evidence, features=json_safe(feats))
    return None
