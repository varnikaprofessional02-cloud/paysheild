"""Contract between the analyzer and the ML layer.

The analyzer builds one ``ScoringRow`` per observation of the analysed run and hands the list to an
``ObservationScorer``. ``BaselineOnlyScorer`` is used when no active model exists (or the active model's
evaluation preferred the baseline); ``app.ml.predictor.BundleScorer`` wraps a trained ModelBundle.
"""

from __future__ import annotations

import math
from dataclasses import dataclass
from typing import Protocol

from app.domain.enums import Detector, MlStatus
from app.domain.models import ObservationScore
from app.ml.baseline import BASELINE_Z_FEATURES, baseline_score

INSUFFICIENT_HISTORY = "INSUFFICIENT_HISTORY"


@dataclass(frozen=True)
class ScoringRow:
    user_id: int
    contract_id: int
    features: dict[str, float]  # FEATURE_COLUMNS
    history_periods: int


class ObservationScorer(Protocol):
    detector: str  # Detector value actually used for ml findings
    model_uid: str | None
    model_version: str | None
    ml_status: str  # MlStatus value for the analysis as a whole

    def score(self, rows: list[ScoringRow]) -> list[ObservationScore]: ...


class BaselineOnlyScorer:
    """Robust-baseline scoring (no trained model). ``ml_percentile`` stays None: the baseline score is a
    robust z-score in units of the employee's own historical spread, not a percentile."""

    detector = Detector.ROBUST_BASELINE.value
    model_uid: str | None = None
    model_version: str | None = None

    def __init__(self, ml_status: str = MlStatus.NO_ACTIVE_MODEL.value, min_history_periods: int = 3):
        self.ml_status = ml_status
        self._min_history = min_history_periods

    def score(self, rows: list[ScoringRow]) -> list[ObservationScore]:
        out: list[ObservationScore] = []
        for row in rows:
            if row.history_periods < self._min_history:
                out.append(ObservationScore(row.user_id, row.contract_id, INSUFFICIENT_HISTORY,
                                            features=row.features, history_periods=row.history_periods))
                continue
            score = baseline_score(row.features)
            contributors = sorted(
                (
                    {"feature": name, "value": row.features.get(name), "z": row.features.get(name)}
                    for name in BASELINE_Z_FEATURES
                    if not math.isnan(row.features.get(name, math.nan))
                ),
                key=lambda c: abs(c["z"]),
                reverse=True,
            )[:3]
            out.append(ObservationScore(
                user_id=row.user_id,
                contract_id=row.contract_id,
                ml_status=self.ml_status,
                baseline_score=None if math.isnan(score) else score,
                top_contributors=contributors,
                features=row.features,
                history_periods=row.history_periods,
            ))
        return out
