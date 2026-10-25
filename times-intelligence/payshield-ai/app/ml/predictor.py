"""Score observations with a trained bundle (implements app.ml.scoring.ObservationScorer)."""

from __future__ import annotations

import math

import numpy as np

from app.data.feature_extractor import MODEL_FEATURES
from app.domain.enums import Detector, MlStatus
from app.domain.models import ObservationScore
from app.ml.baseline import baseline_score
from app.ml.model_bundle import ModelBundle
from app.ml.scoring import INSUFFICIENT_HISTORY, ScoringRow
from app.ml.trainer import raw_scores


class BundleScorer:
    def __init__(self, bundle: ModelBundle, model_uid: str, min_history_periods: int = 3):
        self.bundle = bundle
        self.detector = bundle.detector
        self.model_uid = model_uid
        self.model_version = bundle.model_version
        self.ml_status = MlStatus.SCORED.value if bundle.detector == Detector.ISOLATION_FOREST.value else MlStatus.BASELINE_PREFERRED.value
        self._min = min_history_periods
        self._q = np.asarray(bundle.score_quantiles)

    def percentile(self, raw: float) -> float:
        return round(float(np.searchsorted(self._q, raw, side="right")) / len(self._q) * 100.0, 2)

    def _contributors(self, f: dict[str, float]) -> list[dict]:
        out = []
        for name in MODEL_FEATURES:
            v, med, sc = f.get(name, math.nan), self.bundle.feature_medians.get(name), self.bundle.feature_scales.get(name)
            if med is None or sc is None or v is None or math.isnan(v):
                continue
            out.append({"feature": name, "value": round(v, 4), "typical": round(med, 4), "z": round((v - med) / sc, 2)})
        return sorted(out, key=lambda c: abs(c["z"]), reverse=True)[:3]

    def score(self, rows: list[ScoringRow]) -> list[ObservationScore]:
        ok = [r for r in rows if r.history_periods >= self._min]
        raws = raw_scores(self.bundle.pipeline, [r.features for r in ok]) if ok else []
        by_key = {(r.user_id, r.contract_id): float(s) for r, s in zip(ok, raws)}
        out = []
        for r in rows:
            if (r.user_id, r.contract_id) not in by_key:
                out.append(ObservationScore(r.user_id, r.contract_id, INSUFFICIENT_HISTORY, features=r.features,
                                            history_periods=r.history_periods))
                continue
            raw = by_key[(r.user_id, r.contract_id)]
            b = baseline_score(r.features)
            out.append(ObservationScore(r.user_id, r.contract_id, self.ml_status, ml_raw_score=raw,
                                        ml_percentile=self.percentile(raw), baseline_score=None if math.isnan(b) else b,
                                        top_contributors=self._contributors(r.features), features=r.features,
                                        history_periods=r.history_periods))
        return out
