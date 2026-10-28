"""Text -> SQL without an LLM: catalogue safety, slot parsing, classifier accuracy on held-out questions."""

from __future__ import annotations

import re
from contextlib import contextmanager
from datetime import date
from pathlib import Path

import pytest

from app.nl2sql import catalog, evaluate
from app.nl2sql.service import plan, run
from app.nl2sql.slots import extract

DB = Path(__file__).resolve().parents[2] / "database"
SLOT_PARAMS = {"period": "period", "n": "n", "amount": "amount", "days": "days", "employee": "emp"}
TODAY = date(2026, 10, 28)


def _known_tables() -> set[str]:
    text = "\n".join(p.read_text(encoding="utf-8", errors="ignore") for p in DB.rglob("*.sql"))
    return {m.lower().replace('"', "") for m in re.findall(r"CREATE TABLE (?:IF NOT EXISTS )?([\w\"]+\.[\w\"]+)", text, re.I)}


def _intents():
    return [i for i in catalog.load().values() if i.id != catalog.UNSUPPORTED]


@pytest.mark.parametrize("intent", _intents(), ids=lambda i: i.id)
def test_template_is_read_only_and_uses_only_its_own_parameters(intent):
    sql = intent.sql
    assert re.match(r"\s*(SELECT|WITH)\b", sql, re.I) and ";" not in sql and "@" not in sql
    assert not re.search(r"\b(INSERT|UPDATE|DELETE|DROP|ALTER|CREATE|TRUNCATE|GRANT|COPY)\b", sql, re.I)
    used = set(re.findall(r"%\((\w+)\)s", sql))
    assert "c" in used, "every query must be scoped to the session company"
    assert used - {"c"} <= {SLOT_PARAMS[s] for s in intent.slots}
    assert len(intent.phrasings) >= 15


def test_templates_only_reference_tables_in_the_schema():
    known = _known_tables()
    assert known, "schema files not found"
    for i in _intents():
        for t in re.findall(r"\b(payroll|employee|company|security|times_intelligence)\.\"?(\w+)\"?", i.sql):
            assert f"{t[0]}.{t[1]}".lower() in known, f"{i.id}: {t[0]}.{t[1]}"


@pytest.mark.parametrize("q, want", [
    ("net pay for September 2026", {"period": date(2026, 9, 1)}),
    ("net pay for 08/2026", {"period": date(2026, 8, 1)}),
    ("net pay for 2026-07", {"period": date(2026, 7, 1)}),
    ("cpf last month", {"period": date(2026, 9, 1)}),
    ("cpf this month", {"period": date(2026, 10, 1)}),
    ("new hires in December", {"period": date(2025, 12, 1)}),  # no year: the latest December not in the future
    ("may I see the payroll", {"period": None}),
    ("top 5 earners in may", {"period": date(2026, 5, 1), "n": 5}),
    ("net pay above 12k", {"amount": 12000.0}),
    ("more than 9,500.50", {"amount": 9500.5}),
    ("passes expiring within 2 weeks", {"days": 14}),
    ("passes expiring in the next 3 months", {"days": 90}),
    ("pay history for e0045", {"employee": "E0045"}),
    ("payslip history of Siti Aminah", {"employee": "Siti Aminah"}),
    ("Has Mei Ling's pay changed", {"employee": "Mei Ling"}),
])
def test_slots(q, want):
    s = extract(q, TODAY)
    for k, v in want.items():
        assert getattr(s, k) == v, (q, k, getattr(s, k))


def test_held_out_questions():
    s, _ = evaluate.run()
    assert s.intent_ok / s.answerable >= 0.90, s.misses
    assert s.slots_ok / s.answerable >= 0.90, s.misses
    assert s.refused_ok == s.refused_total, s.misses


def test_missing_employee_asks_for_it_and_off_topic_is_refused():
    assert plan("show me the pay history", TODAY).status == "NEEDS_INPUT"
    p = plan("book a meeting room for tomorrow", TODAY)
    assert p.status == "UNSUPPORTED" and len(p.suggestions) == 3


class _Cur:
    def __init__(self, rows):
        self.rows, self.description = rows, []

    def fetchone(self):
        return self.rows[0]

    def fetchall(self):
        return self.rows


class _Conn:
    def __init__(self):
        self.calls = []

    @contextmanager
    def transaction(self):
        yield

    def execute(self, sql, params=None):
        self.calls.append((sql, params))
        return _Cur([{"period": date(2026, 10, 1)}])


def test_runs_read_only_with_the_session_company_and_resolves_latest_month():
    c = _Conn()
    res = run(c, 42, plan("total net pay", TODAY))
    sqls = [s for s, _ in c.calls]
    assert sqls[0] == "SET TRANSACTION READ ONLY" and sqls[1].startswith("SET LOCAL statement_timeout")
    assert c.calls[-1][1]["c"] == 42 and c.calls[-1][1]["period"] == date(2026, 10, 1)
    assert "LIMIT" in sqls[-1] and res["status"] == "READY"
