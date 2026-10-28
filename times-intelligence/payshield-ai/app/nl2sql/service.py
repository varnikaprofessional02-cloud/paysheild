"""Text -> SQL -> result without an LLM: classify the question into a catalogue intent, fill its slots, run its fixed SQL.

Safety: the SQL is never written at run time. The company id comes from the session and never from the text, values
from the text are bound as parameters, and the query runs in a read-only transaction with a timeout and a row cap.
"""

from __future__ import annotations

from dataclasses import dataclass
from datetime import date
from typing import Any

from app.db.connection import ConnectionManager
from app.nl2sql import catalog, classifier
from app.nl2sql.slots import extract

MAX_ROWS = 500
TIMEOUT_MS = 10_000

_LATEST_PERIOD = """SELECT max(to_date(pp.value, 'MM/YYYY')) AS period FROM payroll.pay_period pp
JOIN payroll.pay_run r ON r.pay_period_id = pp.id WHERE pp.company_id = %(c)s"""


@dataclass
class Plan:
    """What a question resolves to before anything runs."""
    status: str  # READY | NEEDS_INPUT | UNSUPPORTED
    intent: str | None
    title: str | None
    confidence: float
    params: dict[str, Any]
    message: str | None = None
    suggestions: list[dict] | None = None


def _suggest(pred: classifier.Prediction, intents: dict[str, catalog.Intent]) -> list[dict]:
    return [{"intent": i, "title": intents[i].title, "example": intents[i].phrasings[0]}
            for i, _ in pred.ranked if i != catalog.UNSUPPORTED][:3]


def plan(question: str, today: date, pipe=None) -> Plan:
    """Pick the intent and its parameters (no database access; period 'latest' is resolved when the query runs)."""
    intents = catalog.load()
    pred = classifier.predict(question, pipe)
    if pred.intent == catalog.UNSUPPORTED or pred.confidence < classifier.MIN_CONFIDENCE:
        return Plan("UNSUPPORTED", None, None, pred.confidence, {},
                    "I can't answer that yet. These are the closest questions I can answer:", _suggest(pred, intents))
    intent, slots = intents[pred.intent], extract(question, today)
    params: dict[str, Any] = {}
    for name, default in intent.slots.items():
        value = getattr(slots, name)
        if value is None:
            if default == "required":
                return Plan("NEEDS_INPUT", intent.id, intent.title, pred.confidence, {},
                            f"Which {name}? For example: {intent.phrasings[0]}")
            value = None if default == "latest" else default
        params[name] = value
    if "employee" in params:
        params["emp"] = f"%{params.pop('employee')}%"
    return Plan("READY", intent.id, intent.title, pred.confidence, params)


class Nl2SqlService:
    def __init__(self, conn: ConnectionManager, db_name: str):
        self.conn, self.db = conn, db_name

    def ask(self, company_id: int, question: str, today: date | None = None) -> dict:
        p = plan(question, today or date.today())
        if p.status != "READY":
            return run(None, company_id, p)
        with self.conn.connection(self.db) as c:
            return run(c, company_id, p)


def run(c, company_id: int, p: Plan) -> dict:
    """Run a planned question on a connection (dict rows) in a read-only transaction."""
    out: dict[str, Any] = {"status": p.status, "intent": p.intent, "title": p.title, "confidence": round(p.confidence, 3)}
    if p.status != "READY":
        return out | {"message": p.message, "suggestions": p.suggestions or []}
    sql = catalog.load()[p.intent].sql
    params = {**p.params, "c": company_id}  # set last: the company never comes from the question
    with c.transaction():
        c.execute("SET TRANSACTION READ ONLY")
        c.execute(f"SET LOCAL statement_timeout = {TIMEOUT_MS}")
        if "period" in params and params["period"] is None:
            params["period"] = c.execute(_LATEST_PERIOD, {"c": company_id}).fetchone()["period"]
            if params["period"] is None:
                return out | {"status": "NO_DATA", "message": "There are no pay runs for this company yet."}
        cur = c.execute(f"SELECT * FROM ({sql}) q LIMIT {MAX_ROWS + 1}", params)
        columns = [d.name for d in cur.description or []]
        rows = cur.fetchall()
    shown = {k: (v.isoformat() if isinstance(v, date) else v) for k, v in params.items() if k != "c"}
    return out | {"sql": sql, "params": shown, "columns": columns, "rows": rows[:MAX_ROWS], "truncated": len(rows) > MAX_ROWS}
