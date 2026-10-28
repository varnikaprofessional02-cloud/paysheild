"""Evaluate text -> SQL on the held-out questions (tests/nl2sql_eval.yaml), and optionally run every answer on a database.

  python scripts/nl2sql_eval.py                                  # classifier + values only, no database
  python scripts/nl2sql_eval.py --live --company-id 1            # also run each query on the local demo DB (read-only)
  python scripts/nl2sql_eval.py --ask "top 5 earners last month" --live --company-id 1

--live connects as --user to --db on --host/--port; set PGPASSWORD in the environment if the login needs one.
Every query runs in a READ ONLY transaction with a 10 s timeout.
"""

from __future__ import annotations

import argparse
import sys
from datetime import date
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import psycopg  # noqa: E402
from psycopg.rows import dict_row  # noqa: E402

from app.nl2sql import evaluate  # noqa: E402
from app.nl2sql.service import plan, run  # noqa: E402


def _print(res: dict, limit: int = 10) -> None:
    print(f"  -> {res['status']} {res.get('title') or ''} (confidence {res['confidence']})")
    if res["status"] != "READY":
        print("    ", res.get("message"))
        for s in res.get("suggestions") or []:
            print(f"     - {s['title']}: e.g. \"{s['example']}\"")
        return
    print(f"     params {res['params']}, {len(res['rows'])} rows")
    if res["rows"]:
        print("     " + " | ".join(res["columns"]))
        for r in res["rows"][:limit]:
            print("     " + " | ".join(str(r[k]) for k in res["columns"]))


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--live", action="store_true")
    ap.add_argument("--ask")
    ap.add_argument("--company-id", type=int, default=1)
    ap.add_argument("--host", default="localhost")
    ap.add_argument("--port", type=int, default=55433)
    ap.add_argument("--db", default="times-prod-is-down")
    ap.add_argument("--user", default="postgres")
    a = ap.parse_args()

    conn = psycopg.connect(host=a.host, port=a.port, dbname=a.db, user=a.user, row_factory=dict_row) if a.live else None
    if a.ask:
        p = plan(a.ask, date.today())
        print(a.ask)
        _print(run(conn, a.company_id, p) if conn else {"status": p.status, "title": p.title, "confidence": round(p.confidence, 3),
                                                         "params": p.params, "rows": [], "columns": [], "message": p.message,
                                                         "suggestions": p.suggestions})
        return

    s, detail = evaluate.run()
    print(f"held-out questions: intent {s.intent_ok}/{s.answerable} ({s.intent_ok / s.answerable:.1%}), "
          f"intent + values {s.slots_ok}/{s.answerable} ({s.slots_ok / s.answerable:.1%}), "
          f"off-topic refused {s.refused_ok}/{s.refused_total}")
    for m in s.misses:
        print("  miss:", m)
    if not conn:
        return
    failed = 0
    today = date.fromisoformat(str(evaluate.yaml.safe_load(evaluate.EVAL_SET.read_text(encoding="utf-8"))["today"]))
    for d in detail:
        if d["got"] == "_unsupported":
            continue
        print(d["q"])
        try:
            _print(run(conn, a.company_id, plan(d["q"], today)), limit=3)
        except psycopg.Error as e:
            failed += 1
            print(f"  -> SQL ERROR: {e}".splitlines()[0])
    print(f"\nqueries that failed on the database: {failed}")


if __name__ == "__main__":
    main()
