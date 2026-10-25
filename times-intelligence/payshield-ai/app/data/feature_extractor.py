"""Feature engineering for one observation against its own (strictly earlier) history window.

``FEATURE_COLUMNS`` is a persisted contract: names are stored with every anomaly and in every model
manifest. Append new names at the end and bump ``FEATURE_SCHEMA_VERSION`` when semantics change.
"""

from __future__ import annotations

import math
from datetime import date
from typing import Sequence

import numpy as np
import pandas as pd

from app.data.observations import Observation
from app.ml.baseline import log_ratio, pct_change, robust_stats

FEATURE_SCHEMA_VERSION = "1"

FEATURE_COLUMNS: tuple[str, ...] = (
    # current levels
    "basic_contractual", "basic_earned", "proration_ratio", "earnings_gross", "net_pay",
    "allowance_total", "deduction_total", "bonus_total", "aw_total", "ordinary_allowance_total", "back_pay",
    "cpf_employee", "cpf_employer", "cpf_rate_employee",
    "overtime_amount", "overtime_hours", "hourly_item_hours",
    "item_count", "earning_item_count", "deduction_item_count", "adhoc_item_count", "duplicate_code_count",
    # history references
    "prev_basic_contractual", "prev_earnings_gross", "prev_net_pay",
    "median_basic_contractual", "median_earnings_gross", "median_net_pay", "median_allowance_total",
    "median_deduction_total", "median_overtime_amount",
    "mean_earnings_gross_3", "mean_earnings_gross_6", "mean_overtime_amount_6",
    # relative change
    "basic_change_pct", "earnings_gross_change_pct", "net_pay_change_pct", "allowance_change_pct", "deduction_change_pct",
    "rz_basic_contractual", "rz_earnings_gross", "rz_net_pay", "rz_allowance_total", "rz_deduction_total",
    "rz_overtime_amount", "rz_cpf_rate_employee",
    "log_ratio_net_pay", "log_ratio_earnings_gross", "log_ratio_allowance_total", "log_ratio_deduction_total",
    # composition / context
    "new_code_count", "missing_recurring_code_count", "history_periods", "tenure_months",
    "period_month", "period_month_sin", "period_month_cos", "is_mid_cycle", "is_bonus_cycle",
    "is_new_hire", "is_resignee", "contract_count",
)

# scale-free inputs for the Isolation Forest; raw money levels are excluded so that high earners
# are not anomalous merely for being high earners
MODEL_FEATURES: tuple[str, ...] = (
    "proration_ratio", "cpf_rate_employee",
    "basic_change_pct", "earnings_gross_change_pct", "net_pay_change_pct", "allowance_change_pct", "deduction_change_pct",
    "rz_basic_contractual", "rz_earnings_gross", "rz_net_pay", "rz_allowance_total", "rz_deduction_total",
    "rz_overtime_amount", "rz_cpf_rate_employee",
    "log_ratio_net_pay", "log_ratio_earnings_gross", "log_ratio_allowance_total", "log_ratio_deduction_total",
    "item_count", "adhoc_item_count", "duplicate_code_count", "new_code_count", "missing_recurring_code_count",
    "history_periods", "period_month_sin", "period_month_cos", "is_mid_cycle", "is_bonus_cycle",
    "is_new_hire", "is_resignee", "contract_count",
)

CHANGE_PCT_CLIP = 500.0
RZ_CLIP = 50.0
MISSING_RECURRING_LOOKBACK = 3

NAN = math.nan


def _f(value: float | None) -> float:
    return NAN if value is None else float(value)


def _cpf_rate(obs: Observation) -> float:
    if not obs.cpf_assessed or obs.cpf_employee is None:
        return NAN
    wage = obs.eligible_wage
    if wage is None or wage <= 0:
        return NAN
    return obs.cpf_employee / wage


def _months_between(start: date, end: date) -> int:
    return (end.year - start.year) * 12 + (end.month - start.month)


def _mean_last(values: Sequence[float | None], n: int) -> float:
    vals = [v for v in values[-n:] if v is not None]
    return float(np.mean(vals)) if vals else NAN


def _rz(current: float | None, history: Sequence[float | None]) -> float:
    stats = robust_stats(history)
    if stats is None or current is None:
        return NAN
    return float(np.clip(stats.z(current), -RZ_CLIP, RZ_CLIP))


def _median(history: Sequence[float | None]) -> float:
    stats = robust_stats(history)
    return NAN if stats is None else stats.median


def _clip_pct(value: float) -> float:
    return value if math.isnan(value) else float(np.clip(value, -CHANGE_PCT_CLIP, CHANGE_PCT_CLIP))


def missing_recurring_codes(current: Observation, window: Sequence[Observation]) -> set[str]:
    """Monthly-recurring earning codes paid in each of the last N window periods but absent now."""
    if len(window) < MISSING_RECURRING_LOOKBACK:
        return set()
    recent = window[-MISSING_RECURRING_LOOKBACK:]
    steady = set.intersection(*(o.monthly_recurring_earning_codes() for o in recent))
    present = {i.code for i in current.earning_items()}
    return steady - present


def new_codes(current: Observation, window: Sequence[Observation]) -> set[str]:
    if not window:
        return set()
    seen = {i.code for o in window for i in o.items}
    return {i.code for i in current.items} - seen


def build_features(
    current: Observation,
    window: Sequence[Observation],
    *,
    contract_count: int = 1,
    overtime_tracked: bool = False,
) -> dict[str, float]:
    """Compute ``FEATURE_COLUMNS`` for ``current`` using only ``window`` (oldest-first, strictly earlier periods)."""
    if any(o.period >= current.period for o in window):
        raise ValueError("history window must contain only periods before the observation (leakage guard)")

    prev = window[-1] if window else None
    hist_basic = [o.basic_contractual for o in window]
    hist_gross = [o.earnings_gross for o in window]
    hist_net = [o.net_pay for o in window]
    hist_allow = [o.total_allowance for o in window]
    hist_deduct = [o.total_deduction for o in window]
    hist_ot = [o.overtime_amount(overtime_tracked) for o in window]
    hist_rate = [None if math.isnan(r := _cpf_rate(o)) else r for o in window]

    basic_c = current.basic_contractual
    basic_e = current.basic_earned
    gross = current.earnings_gross
    net = current.net_pay
    allow = current.total_allowance
    deduct = current.total_deduction
    ot_amount = current.overtime_amount(overtime_tracked)
    rate = _cpf_rate(current)
    items = current.items
    month = current.period.month
    hired = current.hired_date

    feats: dict[str, float] = {
        "basic_contractual": _f(basic_c),
        "basic_earned": _f(basic_e),
        "proration_ratio": (basic_e / basic_c) if (basic_e is not None and basic_c) else NAN,
        "earnings_gross": _f(gross),
        "net_pay": _f(net),
        "allowance_total": _f(allow),
        "deduction_total": _f(deduct),
        "bonus_total": float(current.bonus_total),
        "aw_total": float(current.aw_total),
        "ordinary_allowance_total": float(current.ordinary_allowance_total),
        "back_pay": _f(current.back_pay),
        "cpf_employee": _f(current.cpf_employee),
        "cpf_employer": _f(current.cpf_employer),
        "cpf_rate_employee": rate,
        "overtime_amount": _f(ot_amount),
        "overtime_hours": _f(current.overtime_hours(overtime_tracked)),
        "hourly_item_hours": _f(current.hourly_item_hours),
        "item_count": float(len(items)),
        "earning_item_count": float(len(current.earning_items())),
        "deduction_item_count": float(len(current.deduction_items())),
        "adhoc_item_count": float(sum(1 for i in items if i.is_adhoc)),
        "duplicate_code_count": float(current.duplicate_code_count),
        "prev_basic_contractual": _f(prev.basic_contractual) if prev else NAN,
        "prev_earnings_gross": _f(prev.earnings_gross) if prev else NAN,
        "prev_net_pay": _f(prev.net_pay) if prev else NAN,
        "median_basic_contractual": _median(hist_basic),
        "median_earnings_gross": _median(hist_gross),
        "median_net_pay": _median(hist_net),
        "median_allowance_total": _median(hist_allow),
        "median_deduction_total": _median(hist_deduct),
        "median_overtime_amount": _median(hist_ot),
        "mean_earnings_gross_3": _mean_last(hist_gross, 3),
        "mean_earnings_gross_6": _mean_last(hist_gross, 6),
        "mean_overtime_amount_6": _mean_last(hist_ot, 6),
        "basic_change_pct": _clip_pct(pct_change(basic_c, prev.basic_contractual if prev else None)),
        "earnings_gross_change_pct": _clip_pct(pct_change(gross, prev.earnings_gross if prev else None)),
        "net_pay_change_pct": _clip_pct(pct_change(net, prev.net_pay if prev else None)),
        "allowance_change_pct": _clip_pct(pct_change(allow, prev.total_allowance if prev else None)),
        "deduction_change_pct": _clip_pct(pct_change(deduct, prev.total_deduction if prev else None)),
        "rz_basic_contractual": _rz(basic_c, hist_basic),
        "rz_earnings_gross": _rz(gross, hist_gross),
        "rz_net_pay": _rz(net, hist_net),
        "rz_allowance_total": _rz(allow, hist_allow),
        "rz_deduction_total": _rz(deduct, hist_deduct),
        "rz_overtime_amount": _rz(ot_amount, hist_ot) if overtime_tracked else NAN,
        "rz_cpf_rate_employee": NAN if math.isnan(rate) else _rz(rate, hist_rate),
        "log_ratio_net_pay": log_ratio(net, _median(hist_net) if window else None),
        "log_ratio_earnings_gross": log_ratio(gross, _median(hist_gross) if window else None),
        "log_ratio_allowance_total": log_ratio(allow, _median(hist_allow) if window else None),
        "log_ratio_deduction_total": log_ratio(deduct, _median(hist_deduct) if window else None),
        "new_code_count": float(len(new_codes(current, window))) if window else NAN,
        "missing_recurring_code_count": float(len(missing_recurring_codes(current, window)))
        if len(window) >= MISSING_RECURRING_LOOKBACK else NAN,
        "history_periods": float(len(window)),
        "tenure_months": float(_months_between(hired, current.period)) if hired else NAN,
        "period_month": float(month),
        "period_month_sin": math.sin(2 * math.pi * month / 12.0),
        "period_month_cos": math.cos(2 * math.pi * month / 12.0),
        "is_mid_cycle": 1.0 if current.cycle_code == "MID" else 0.0,
        "is_bonus_cycle": 1.0 if current.cycle_code in ("BONUS", "SPECIAL") else 0.0,
        "is_new_hire": 1.0 if current.is_new_hire else 0.0,
        "is_resignee": 1.0 if current.is_resignee else 0.0,
        "contract_count": float(contract_count),
    }
    # median-based log ratios are NaN (not 0) without history
    return {name: feats[name] for name in FEATURE_COLUMNS}


def to_frame(rows: Sequence[dict[str, float]], columns: Sequence[str] = FEATURE_COLUMNS) -> pd.DataFrame:
    """Rows -> float DataFrame with a fixed column order (missing names become NaN)."""
    frame = pd.DataFrame(list(rows), columns=list(columns))
    return frame.astype("float64")


def json_safe(features: dict[str, float]) -> dict[str, float | None]:
    """NaN -> None and rounding, for storage in times_intelligence.anomaly.features."""
    out: dict[str, float | None] = {}
    for k, v in features.items():
        out[k] = None if v is None or (isinstance(v, float) and (math.isnan(v) or math.isinf(v))) else round(float(v), 6)
    return out
