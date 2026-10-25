"""Robust statistical baselines (median / MAD) for one employee's own history.

These are deliberately simple: they are the comparison point the Isolation Forest must beat
(docs/02_ML_DESIGN.md) and they supply every ``expected_value`` PayShield reports.
"""

from __future__ import annotations

import math
from dataclasses import dataclass
from typing import Sequence

import numpy as np

MAD_TO_SIGMA = 1.4826
# floors keep z-scores finite when an employee's history is perfectly flat
RELATIVE_SCALE_FLOOR = 0.05
ABSOLUTE_SCALE_FLOOR = 10.0


@dataclass(frozen=True)
class RobustStats:
    median: float
    scale: float  # 1.4826 * MAD, floored
    n: int
    low: float  # lower bound of the expected range
    high: float  # upper bound of the expected range

    def z(self, value: float | None) -> float:
        if value is None or math.isnan(value):
            return math.nan
        return (value - self.median) / self.scale


def _clean(values: Sequence[float | None]) -> np.ndarray:
    arr = np.array([v for v in values if v is not None], dtype=float)
    return arr[~np.isnan(arr)]


def robust_stats(values: Sequence[float | None], *, interval_k: float = 2.5) -> RobustStats | None:
    """Median and scaled MAD of the available values; None when there is no data.

    The expected range is the 10th-90th percentile when there are >= 5 values, otherwise
    median +/- ``interval_k`` x scale. Both are descriptive of the employee's own history,
    not a predictive interval with coverage guarantees.
    """
    arr = _clean(values)
    if arr.size == 0:
        return None
    median = float(np.median(arr))
    mad = float(np.median(np.abs(arr - median)))
    scale = max(MAD_TO_SIGMA * mad, RELATIVE_SCALE_FLOOR * abs(median), ABSOLUTE_SCALE_FLOOR)
    if arr.size >= 5:
        low, high = (float(q) for q in np.percentile(arr, [10, 90]))
        low, high = min(low, median), max(high, median)
    else:
        low, high = median - interval_k * scale, median + interval_k * scale
    return RobustStats(median=median, scale=scale, n=int(arr.size), low=low, high=high)


def robust_z(value: float | None, history: Sequence[float | None]) -> float:
    stats = robust_stats(history)
    return stats.z(value) if stats is not None else math.nan


def pct_change(current: float | None, previous: float | None) -> float:
    if current is None or previous is None or previous == 0 or math.isnan(current) or math.isnan(previous):
        return math.nan
    return (current - previous) / abs(previous) * 100.0


def log_ratio(current: float | None, reference: float | None) -> float:
    if current is None or reference is None or math.isnan(current) or math.isnan(reference):
        return math.nan
    if current < 0 or reference < 0:
        return math.nan
    return math.log((current + 1.0) / (reference + 1.0))


# metrics whose robust z drives the baseline detector score
BASELINE_Z_FEATURES: tuple[str, ...] = (
    "rz_basic_contractual",
    "rz_earnings_gross",
    "rz_net_pay",
    "rz_allowance_total",
    "rz_deduction_total",
    "rz_overtime_amount",
)


def baseline_score(features: dict[str, float]) -> float:
    """Max absolute robust z over the key metrics (NaN-safe). Higher = more unusual."""
    # deductions and overtime only matter upwards (a loan ending or less overtime is normal)
    one_sided = {"rz_deduction_total", "rz_overtime_amount"}
    vals = [features.get(k, math.nan) if k in one_sided else abs(features.get(k, math.nan)) for k in BASELINE_Z_FEATURES]
    vals = [v for v in vals if not math.isnan(v)]
    return max(vals) if vals else math.nan
