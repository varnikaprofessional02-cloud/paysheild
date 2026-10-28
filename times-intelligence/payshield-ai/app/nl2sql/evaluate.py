"""Score the classifier and slot parser on held-out questions (tests/nl2sql_eval.yaml)."""

from __future__ import annotations

from dataclasses import dataclass, field
from datetime import date
from pathlib import Path

import yaml

from app.nl2sql import catalog
from app.nl2sql.service import plan

EVAL_SET = Path(__file__).resolve().parents[2] / "tests" / "nl2sql_eval.yaml"


@dataclass
class Score:
    total: int = 0
    intent_ok: int = 0
    slots_ok: int = 0
    refused_ok: int = 0
    refused_total: int = 0
    misses: list[str] = field(default_factory=list)

    @property
    def answerable(self) -> int:
        return self.total - self.refused_total


def _expected_slots(case: dict) -> dict:
    out = {}
    for k in ("period", "n", "amount", "days", "employee"):
        if k in case:
            v = case[k]
            if k == "period":
                y, m = str(v).split("-")
                v = date(int(y), int(m), 1)
            out["emp" if k == "employee" else k] = f"%{v}%" if k == "employee" else v
    return out


def run(path: Path = EVAL_SET, pipe=None) -> tuple[Score, list[dict]]:
    doc = yaml.safe_load(path.read_text(encoding="utf-8"))
    today = doc["today"] if isinstance(doc["today"], date) else date.fromisoformat(doc["today"])
    s, detail = Score(), []
    for case in doc["cases"]:
        s.total += 1
        p = plan(case["q"], today, pipe)
        got = p.intent if p.status != "UNSUPPORTED" else catalog.UNSUPPORTED
        want = case["intent"]
        if want == catalog.UNSUPPORTED:
            s.refused_total += 1
            ok_intent = got == catalog.UNSUPPORTED
            s.refused_ok += ok_intent
            ok_slots = ok_intent
        else:
            ok_intent = got == want
            s.intent_ok += ok_intent
            exp = _expected_slots(case)
            ok_slots = ok_intent and all(p.params.get(k) == v for k, v in exp.items())
            s.slots_ok += ok_slots
        if not ok_slots:
            s.misses.append(f"{case['q']!r}: wanted {want} {_expected_slots(case)}, got {got} {p.params} ({p.confidence:.2f})")
        detail.append({"q": case["q"], "want": want, "got": got, "confidence": p.confidence, "params": p.params})
    return s, detail
