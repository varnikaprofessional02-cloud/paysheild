"""Pay runs as PayShield sees them: list with status and release, decisions on identity findings, and the release.

A pay run can only be released (and is then locked) when nothing is open: every payroll finding of its latest analysis
and every Identification finding of that pay period has been fixed or accepted - the Pay Score is 100.
The check runs here on the server; the UI only mirrors it.
"""

from __future__ import annotations

from typing import Any

from app.core.errors import Conflict, NotFound
from app.db.connection import ConnectionManager
from app.services.area_service import AreaService

RESOLVED = ("CONFIRMED_ERROR", "EXPECTED_CHANGE", "FALSE_POSITIVE")
_GROSS = "COALESCE((pr.data_processed #>> '{payRecord,grossPay,amount}')::numeric, 0)"
_NET = "COALESCE((pr.data_processed #>> '{payRecord,nettPay,amount}')::numeric, pr.total_payout, 0)"


class PayRunService:
    def __init__(self, conn: ConnectionManager, db_name: str):
        self.conn, self.db = conn, db_name
        self.areas = AreaService(conn, db_name)

    def _all(self, sql: str, p: dict[str, Any]) -> list[dict]:
        with self.conn.connection(self.db) as c:
            cur = c.execute(sql, p)
            return cur.fetchall() if cur.description else []

    def _run(self, company_id: int, uid: str) -> dict:
        r = self._all("""SELECT r.id, r.uid::text AS uid, r.name, pp.value AS period, r.is_lock FROM payroll.pay_run r
                         JOIN payroll.pay_period pp ON pp.id = r.pay_period_id WHERE pp.company_id = %(c)s AND r.uid = %(u)s::uuid""",
                      {"c": company_id, "u": uid})
        if not r:
            raise NotFound("PAY_RUN_NOT_FOUND", f"No pay run {uid} in this company.")
        return r[0]

    def list_runs(self, company_id: int) -> list[dict]:
        """Every pay run of the company, newest first, with totals, lock state, latest PayShield check and release."""
        return self._all(f"""SELECT r.uid::text AS uid, r.name, pp.value AS period, r.is_lock AS locked, r.pay_run_date,
                t.records, t.gross, t.net, t.cpf, t.basic,
                a.uid::text AS analysis_id, a.completed_on AS checked_on, a.anomaly_count,
                rel.uid::text AS release_id, rel.pay_score, rel.findings AS resolved_findings, rel.released_by, rel.released_on
            FROM payroll.pay_run r JOIN payroll.pay_period pp ON pp.id = r.pay_period_id
            JOIN LATERAL (SELECT count(*) AS records, round(sum({_GROSS}), 2) AS gross, round(sum({_NET}), 2) AS net,
                                 round(sum(pr.total_cpf), 2) AS cpf, round(sum(pr.basic_salary), 2) AS basic
                          FROM payroll.pay_record pr WHERE pr.pay_run_id = r.id) t ON true
            LEFT JOIN LATERAL (SELECT * FROM times_intelligence.analysis x WHERE x.company_id = %(c)s AND x.pay_run_id = r.id
                               AND x.status <> 'SUPERSEDED' ORDER BY x.requested_on DESC, x.id DESC LIMIT 1) a ON true
            LEFT JOIN times_intelligence.pay_run_release rel ON rel.pay_run_id = r.id AND rel.company_id = %(c)s
            WHERE pp.company_id = %(c)s AND t.records > 0
            ORDER BY to_date(pp.value, 'MM/YYYY') DESC, r.id DESC""", {"c": company_id})

    # identity decisions ------------------------------------------------------------------------
    def decide_identity(self, company_id: int, pay_run_uid: str, employee_no: str, anomaly_type: str, outcome: str, actor: str) -> dict:
        run = self._run(company_id, pay_run_uid)
        if run["is_lock"]:
            raise Conflict("PAY_RUN_LOCKED", "This pay run is locked; its findings can no longer change.")
        return self._all("""INSERT INTO times_intelligence.identity_decision (company_id, pay_run_id, employee_no, anomaly_type, outcome, decided_by)
            VALUES (%(c)s, %(r)s, %(e)s, %(t)s, %(o)s, %(u)s) RETURNING outcome, decided_by, decided_on""",
                         {"c": company_id, "r": run["id"], "e": employee_no, "t": anomaly_type, "o": outcome, "u": actor})[0]

    def identity_for_run(self, company_id: int, pay_run_uid: str) -> dict | None:
        """Identification checks as at the end of the pay period, each with its latest Fix / Accept decision."""
        r = self.areas.check_identification(company_id, pay_run_uid)
        if r is None:
            return None
        run = self._run(company_id, pay_run_uid)
        latest = {(d["employee_no"], d["anomaly_type"]): d["outcome"] for d in self._all(
            """SELECT DISTINCT ON (employee_no, anomaly_type) employee_no, anomaly_type, outcome FROM times_intelligence.identity_decision
               WHERE company_id = %(c)s AND pay_run_id = %(r)s ORDER BY employee_no, anomaly_type, decided_on DESC, id DESC""",
            {"c": company_id, "r": run["id"]})}
        for f in r["findings"]:
            f["latestFeedback"] = latest.get((f["employeeNo"], f["anomalyType"]))
        return r

    # release -----------------------------------------------------------------------------------
    def open_items(self, company_id: int, pay_run_uid: str) -> dict:
        run = self._run(company_id, pay_run_uid)
        a = self._all("""SELECT id FROM times_intelligence.analysis WHERE company_id = %(c)s AND pay_run_id = %(r)s AND status <> 'SUPERSEDED'
                         ORDER BY requested_on DESC, id DESC LIMIT 1""", {"c": company_id, "r": run["id"]})
        if not a:
            return {"run": run, "analysis": None, "payroll": None, "identity": 0, "total": 0}
        rows = self._all("""SELECT x.id, fb.code FROM times_intelligence.anomaly x
            LEFT JOIN LATERAL (SELECT o.code FROM times_intelligence.feedback f JOIN times_intelligence.lk_feedback_outcome o ON o.id = f.outcome_id
                               WHERE f.anomaly_id = x.id ORDER BY f.created_on DESC, f.id DESC LIMIT 1) fb ON true
            WHERE x.analysis_id = %(a)s""", {"a": a[0]["id"]})
        open_pay = sum(1 for x in rows if x["code"] not in RESOLVED)
        ident = self.identity_for_run(company_id, pay_run_uid)
        idf = (ident or {}).get("findings", [])
        open_id = sum(1 for f in idf if f["latestFeedback"] not in RESOLVED)
        return {"run": run, "analysis": a[0]["id"], "payroll": open_pay, "identity": open_id,
                "total": len(rows) + len(idf), "open": open_pay + open_id}

    def release(self, company_id: int, pay_run_uid: str, actor: str) -> dict:
        o = self.open_items(company_id, pay_run_uid)
        run = o["run"]
        if run["is_lock"]:
            raise Conflict("PAY_RUN_LOCKED", f"{run['name']} is already locked.")
        if o["analysis"] is None:
            raise Conflict("NOT_CHECKED", f"Process {run['name']} in PayShield before running payroll.")
        if o["open"]:
            raise Conflict("PAY_SCORE_BELOW_100",
                           f"{o['open']} finding(s) are still open ({o['payroll']} payroll, {o['identity']} identity). "
                           "Fix or accept each one to reach a Pay Score of 100.")
        with self.conn.connection(self.db) as c, c.transaction():
            t = c.execute(f"""SELECT count(*) AS n, round(sum({_GROSS}), 2) AS gross, round(sum({_NET}), 2) AS net
                              FROM payroll.pay_record pr WHERE pr.pay_run_id = %(r)s""", {"r": run["id"]}).fetchone()
            rel = c.execute("""INSERT INTO times_intelligence.pay_run_release (company_id, pay_run_id, analysis_id, pay_score, findings,
                    headcount, gross, net, released_by) VALUES (%(c)s,%(r)s,%(a)s,100,%(f)s,%(n)s,%(g)s,%(t)s,%(u)s)
                RETURNING uid::text AS release_id, released_on""",
                            {"c": company_id, "r": run["id"], "a": o["analysis"], "f": o["total"], "n": t["n"], "g": t["gross"],
                             "t": t["net"], "u": actor}).fetchone()
            # lock the pay run the way the payroll module does: run locked, its records in status 4 (Locked)
            c.execute("UPDATE payroll.pay_run SET is_lock = true, updated_by = %(u)s, updated_on = now() WHERE id = %(r)s", {"u": actor, "r": run["id"]})
            c.execute("UPDATE payroll.pay_record SET status_id = 4, updated_by = %(u)s, updated_on = now() WHERE pay_run_id = %(r)s",
                      {"u": actor, "r": run["id"]})
        return {"payRunId": run["uid"], "name": run["name"], "period": run["period"], "releaseId": rel["release_id"],
                "releasedOn": rel["released_on"].isoformat(), "releasedBy": actor, "payScore": 100, "resolvedFindings": o["total"],
                "headcount": t["n"], "gross": t["gross"], "net": t["net"]}
