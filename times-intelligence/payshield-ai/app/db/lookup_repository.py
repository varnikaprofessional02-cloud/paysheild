"""Read-only payroll lookups for the PayShield Agent: fixed, tested queries, always scoped to one company.

No SQL is generated at run time; parameters are bound, never interpolated.
"""

from __future__ import annotations

from typing import Any

from app.db.connection import ConnectionManager

_GROSS = "COALESCE((pr.data_processed #>> '{payRecord,grossPay,amount}')::numeric, 0)"
_NET = "COALESCE((pr.data_processed #>> '{payRecord,nettPay,amount}')::numeric, pr.total_payout, 0)"

_RUNS = """
SELECT r.id, r.uid::text AS pay_run_id, r.name, pp.value AS period, to_date(pp.value, 'MM/YYYY') AS period_date
FROM payroll.pay_run r JOIN payroll.pay_period pp ON pp.id = r.pay_period_id
WHERE pp.company_id = %(c)s"""

_TOTALS = f"""
SELECT count(*) AS headcount, round(sum(pr.basic_salary), 2) AS basic, round(sum(pr.total_allowance), 2) AS allowances,
       round(sum(pr.total_deduction), 2) AS deductions, round(sum(pr.total_cpf), 2) AS cpf,
       round(sum({_GROSS}), 2) AS gross, round(sum({_NET}), 2) AS net,
       count(*) FILTER (WHERE pr.is_new_hire) AS new_hires, count(*) FILTER (WHERE pr.is_resignee) AS leavers
FROM payroll.pay_record pr WHERE pr.pay_run_id = %(r)s"""


class PostgresLookupRepository:
    def __init__(self, conn: ConnectionManager, db_name: str):
        self.conn, self.db = conn, db_name

    def _all(self, sql: str, p: dict[str, Any]) -> list[dict]:
        with self.conn.connection(self.db) as c:
            return c.execute(sql, p).fetchall()

    # employees ---------------------------------------------------------------------------------
    def list_employees(self, company_id: int, search: str | None, limit: int, offset: int) -> dict:
        term = (search or "").strip()
        p = {"c": company_id, "all": not term, "q": f"%{term}%", "l": limit, "o": offset}
        where = """ucc.company_id = %(c)s AND (%(all)s OR ucc.employee_no ILIKE %(q)s
                   OR (u.first_name || ' ' || u.last_name) ILIKE %(q)s)"""
        total = self._all(f"""SELECT count(*) AS n FROM employee.user_company_contract ucc
            JOIN security."user" u ON u.id = ucc.user_id WHERE {where}""", p)[0]["n"]
        rows = self._all(f"""SELECT ucc.employee_no, trim(u.first_name || ' ' || u.last_name) AS name, ucc.contract_start_date AS hired,
                lp.period AS last_period, lp.basic, lp.net
            FROM employee.user_company_contract ucc JOIN security."user" u ON u.id = ucc.user_id
            LEFT JOIN LATERAL (SELECT pp.value AS period, pr.basic_salary AS basic, {_NET} AS net
                FROM payroll.pay_record pr JOIN payroll.pay_run r ON r.id = pr.pay_run_id
                JOIN payroll.pay_period pp ON pp.id = r.pay_period_id
                WHERE pr.contract_id = ucc.id AND pp.company_id = %(c)s
                ORDER BY to_date(pp.value, 'MM/YYYY') DESC, r.id DESC LIMIT 1) lp ON true
            WHERE {where} ORDER BY ucc.employee_no LIMIT %(l)s OFFSET %(o)s""", p)
        return {"total": total, "employees": rows}

    def employee_pay_history(self, company_id: int, employee_no: str, months: int) -> dict | None:
        emp = self._all("""SELECT ucc.id, ucc.employee_no, trim(u.first_name || ' ' || u.last_name) AS name, ucc.contract_start_date AS hired
            FROM employee.user_company_contract ucc JOIN security."user" u ON u.id = ucc.user_id
            WHERE ucc.company_id = %(c)s AND upper(ucc.employee_no) = upper(%(e)s) LIMIT 1""", {"c": company_id, "e": employee_no})
        if not emp:
            return None
        rows = self._all(f"""SELECT pp.value AS period, r.name AS pay_run, pr.basic_salary AS basic, pr.total_allowance AS allowances,
                pr.total_deduction AS deductions, pr.total_cpf AS cpf, {_GROSS} AS gross, {_NET} AS net
            FROM payroll.pay_record pr JOIN payroll.pay_run r ON r.id = pr.pay_run_id
            JOIN payroll.pay_period pp ON pp.id = r.pay_period_id
            WHERE pr.contract_id = %(k)s AND pp.company_id = %(c)s
            ORDER BY to_date(pp.value, 'MM/YYYY') DESC, r.id DESC LIMIT %(m)s""", {"k": emp[0]["id"], "c": company_id, "m": months})
        e = {k: v for k, v in emp[0].items() if k != "id"}
        return {**e, "history": rows}

    # pay runs ----------------------------------------------------------------------------------
    def _runs(self, company_id: int, limit: int) -> list[dict]:
        return self._all(_RUNS + " ORDER BY to_date(pp.value, 'MM/YYYY') DESC, r.id DESC LIMIT %(l)s", {"c": company_id, "l": limit})

    def _run(self, company_id: int, pay_run_uid: str) -> dict | None:
        rows = self._all(_RUNS + " AND r.uid = %(u)s::uuid", {"c": company_id, "u": pay_run_uid})
        return rows[0] if rows else None

    def run_totals(self, company_id: int, limit: int) -> list[dict]:
        out = []
        for r in self._runs(company_id, limit):
            t = self._all(_TOTALS, {"r": r["id"]})[0]
            out.append({"pay_run_id": r["pay_run_id"], "name": r["name"], "period": r["period"], **t})
        return out

    def compare_runs(self, company_id: int, pay_run_uid: str | None, against_uid: str | None, top: int) -> dict | None:
        runs = self._runs(company_id, 50)
        cur = self._run(company_id, pay_run_uid) if pay_run_uid else (runs[0] if runs else None)
        if not cur:
            return None
        prev = self._run(company_id, against_uid) if against_uid else next(
            (r for r in runs if r["period_date"] < cur["period_date"]), None)
        if not prev:
            return None
        movers = self._all(f"""WITH a AS (SELECT pr.contract_id, {_NET} AS net FROM payroll.pay_record pr WHERE pr.pay_run_id = %(a)s),
                b AS (SELECT pr.contract_id, {_NET} AS net FROM payroll.pay_record pr WHERE pr.pay_run_id = %(b)s)
            SELECT ucc.employee_no, trim(u.first_name || ' ' || u.last_name) AS name, b.net AS previous, a.net AS current,
                   round(a.net - b.net, 2) AS change,
                   CASE WHEN b.net > 0 THEN round((a.net - b.net) / b.net * 100, 1) END AS change_pct
            FROM a JOIN b USING (contract_id)
            JOIN employee.user_company_contract ucc ON ucc.id = a.contract_id AND ucc.company_id = %(c)s
            JOIN security."user" u ON u.id = ucc.user_id
            WHERE a.net <> b.net ORDER BY abs(a.net - b.net) DESC LIMIT %(t)s""", {"a": cur["id"], "b": prev["id"], "c": company_id, "t": top})
        joined = self._all("""SELECT count(*) AS n FROM payroll.pay_record a WHERE a.pay_run_id = %(a)s AND NOT EXISTS
            (SELECT 1 FROM payroll.pay_record b WHERE b.pay_run_id = %(b)s AND b.contract_id = a.contract_id)""", {"a": cur["id"], "b": prev["id"]})[0]["n"]
        left = self._all("""SELECT count(*) AS n FROM payroll.pay_record b WHERE b.pay_run_id = %(b)s AND NOT EXISTS
            (SELECT 1 FROM payroll.pay_record a WHERE a.pay_run_id = %(a)s AND a.contract_id = b.contract_id)""", {"a": cur["id"], "b": prev["id"]})[0]["n"]
        tot = lambda r: self._all(_TOTALS, {"r": r["id"]})[0]  # noqa: E731
        strip = lambda r: {"pay_run_id": r["pay_run_id"], "name": r["name"], "period": r["period"]}  # noqa: E731
        return {"current": {**strip(cur), **tot(cur)}, "previous": {**strip(prev), **tot(prev)},
                "only_in_current": joined, "only_in_previous": left, "top_changes": movers}
