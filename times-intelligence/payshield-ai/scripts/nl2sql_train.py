"""Train the text -> SQL intent classifier on app/nl2sql/templates.yaml and save it next to the catalogue.

  python scripts/nl2sql_train.py

Prints 5-fold cross-validated accuracy on the catalogue phrasings and the score on the held-out questions
(tests/nl2sql_eval.yaml). No database is used.
"""

from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from sklearn.model_selection import StratifiedKFold, cross_val_score  # noqa: E402

from app.nl2sql import catalog, classifier, evaluate  # noqa: E402


def main() -> None:
    intents = catalog.load()
    x, y = classifier.training_data(intents)
    cv = cross_val_score(classifier.build(), x, y, cv=StratifiedKFold(5, shuffle=True, random_state=7))
    print(f"catalogue: {len(intents) - 1} intents, {len(x)} phrasings")
    print(f"cross-validated accuracy on phrasings: {cv.mean():.1%} (+/- {cv.std():.1%})")
    pipe = classifier.train(intents)
    classifier.save(pipe)
    print(f"saved {classifier.MODEL_PATH}")
    s, _ = evaluate.run(pipe=pipe)
    print(f"held-out questions: intent {s.intent_ok}/{s.answerable} ({s.intent_ok / s.answerable:.1%}), "
          f"intent + values {s.slots_ok}/{s.answerable} ({s.slots_ok / s.answerable:.1%}), "
          f"off-topic refused {s.refused_ok}/{s.refused_total}")
    for m in s.misses:
        print("  miss:", m)


if __name__ == "__main__":
    main()
