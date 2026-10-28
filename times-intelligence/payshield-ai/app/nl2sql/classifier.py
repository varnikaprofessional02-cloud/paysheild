"""Intent classifier: TF-IDF (words + character n-grams) and logistic regression, trained on the catalogue phrasings.

Trains in about a second on a laptop, no GPU and no data leaves the machine. A model saved by scripts/nl2sql_train.py
is used while it matches the catalogue; otherwise one is trained in memory.
"""

from __future__ import annotations

from dataclasses import dataclass
from functools import lru_cache
from pathlib import Path

import joblib
from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.linear_model import LogisticRegression
from sklearn.pipeline import FeatureUnion, Pipeline

from app.nl2sql import catalog
from app.nl2sql.slots import normalise

MODEL_PATH = Path(__file__).with_name("intent_model.joblib")
MIN_CONFIDENCE = 0.30  # below this the question is answered with suggestions instead of a query


@dataclass
class Prediction:
    intent: str
    confidence: float
    ranked: list[tuple[str, float]]


def build() -> Pipeline:
    return Pipeline([
        ("features", FeatureUnion([
            ("words", TfidfVectorizer(ngram_range=(1, 2), sublinear_tf=True)),
            ("chars", TfidfVectorizer(analyzer="char_wb", ngram_range=(2, 5), sublinear_tf=True)),
        ])),
        ("model", LogisticRegression(C=20, max_iter=2000)),
    ])


def training_data(intents: dict[str, catalog.Intent]) -> tuple[list[str], list[str]]:
    x, y = [], []
    for i in intents.values():
        for p in i.phrasings:
            x.append(normalise(p))
            y.append(i.id)
    return x, y


def train(intents: dict[str, catalog.Intent] | None = None) -> Pipeline:
    x, y = training_data(intents or catalog.load())
    return build().fit(x, y)


def save(pipe: Pipeline, path: Path = MODEL_PATH) -> None:
    joblib.dump({"catalog": catalog.fingerprint(), "pipe": pipe}, path)


@lru_cache(maxsize=1)
def model() -> Pipeline:
    if MODEL_PATH.exists():
        saved = joblib.load(MODEL_PATH)
        if saved.get("catalog") == catalog.fingerprint():
            return saved["pipe"]
    return train()


def predict(question: str, pipe: Pipeline | None = None) -> Prediction:
    pipe = pipe or model()
    probs = pipe.predict_proba([normalise(question)])[0]
    ranked = sorted(zip(pipe.classes_, probs), key=lambda t: -t[1])
    return Prediction(ranked[0][0], float(ranked[0][1]), [(c, float(p)) for c, p in ranked])
