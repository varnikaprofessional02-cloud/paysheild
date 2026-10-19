"""Read-only access to existing payroll/employee/company/security tables of ONE tenant database.
Every company-scoped query filters on pay_period.company_id / user_company_contract.company_id."""

from __future__ import annotations

import uuid
from datetime import date
from typing import Any

from app.data.parsing import snapshot_from_row
from app.db.connection import ConnectionManager
from app.db.interfaces import RunState, SchemaCapabilities
from app.domain.models import CompanyRef, ConfiguredPayItem, PayCodeMaster, PayRecordSnapshot, PayRunRef, SalaryRevision

_DOC = """json_build_object(
    'payRecord', CASE WHEN json_typeof(pr.data_processed -> 'payRecord') = 'object' THEN json_build_object(
        'basicSalaryCalculationResult', pr.data_processed #> '{payRecord,basicSalaryCalculationResult}',
        'backPayCalculationResult', pr.data_processed #> '{payRecord,backPayCalculationResult}',
        'allowanceDeductionCalculationResult', pr.data_processed #> '{payRecord,allowanceDeductionCalculationResult}',
        'grossPay', pr.data_processed #> '{payRecord,grossPay}',
        'nettPay', pr.data_processed #> '{payRecord,nettPay}',
        'cpfCalculationResult', pr.data_processed #> '{payRecord,cpfCalculationResult}',
        'communityFundsCalculationResult', pr.data_processed #> '{payRecord,communityFundsCalculationResult}',
        'sdlCalculationResult', pr.data_processed #> '{payRecord,sdlCalculationResult}',
        'donationCalculationResult', pr.data_processed #> '{payRecord,donationCalculationResult}') END,
    'employee', json_build_object('statutorySummary', pr.data_processed #> '{employee,statutorySummary}'),
    'employeeContract', json_build_object(
        'hiredDate', pr.data_processed #>> '{employeeContract,hiredDate}',
        'resignationDate', pr.data_processed #>> '{employeeContract,resignationDate}'))"""

_RECORDS = f"""
SELECT pr.id AS pay_record_id, pr.uid::text AS pay_record_uid, r.id AS pay_run_id, r.uid::text AS pay_run_uid,
       r.pay_run_date, c.code AS cycle_code, __TRIAL__ AS is_trial, to_date(pp.value, 'MM/YYYY') AS period,
       pr.status_id, pr.user_id, u.uid::text AS user_uid, ucc.employee_no, pr.contract_id, ucc.contract_id AS contract_code,
       pr.is_new_hire, pr.is_resignee, pr.basic_salary, pr.total_allowance, pr.total_deduction, pr.total_cpf,
       pr.total_payout, pr.created_on, pr.updated_on, {_DOC} AS doc
FROM payroll.pay_record pr
JOIN payroll.pay_run r ON r.id = pr.pay_run_id
JOIN payroll.pay_period pp ON pp.id = r.pay_period_id
JOIN payroll.lk_payroll_cycle c ON c.id = r.pay_cycle_id
LEFT JOIN employee.user_company_contract ucc ON ucc.id = pr.contract_id
LEFT JOIN security."user" u ON u.id = pr.user_id
WHERE pp.company_id = %(company_id)s"""

# fingerprint components use postgres' own numeric text so python never re-formats money
FINGERPRINT_SQL = """md5(string_agg(pr.id || ':' || COALESCE(pr.total_payout::text,'') || ':' || COALESCE(pr.total_allowance::text,'')
    || ':' || COALESCE(pr.total_deduction::text,'') || ':' || COALESCE(pr.basic_salary::text,'') || ':'
    || CASE WHEN pr.status_id IN (2,4) THEN 'ok' ELSE pr.status_id::text END, ',' ORDER BY pr.id))"""


def _guid(v: str) -> str:
    return str(uuid.UUID(str(v)))


class PostgresPayrollReadRepository:
    def __init__(self, conn: ConnectionManager, db_name: str):
        self.conn, self.db = conn, db_name
        self._caps: SchemaCapabilities | None = None

    def _all(self, sql: str, params: dict[str, Any] | None = None) -> list[dict]:
        with self.conn.connection(self.db) as c:
            return c.execute(sql, params or {}).fetchall()

    def _one(self, sql: str, params: dict[str, Any] | None = None) -> dict | None:
        rows = self._all(sql, params)
        return rows[0] if rows else None

    def capabilities(self) -> SchemaCapabilities:
        if self._caps is None:
            row = self._one("""SELECT
                EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='payroll' AND table_name='pay_run' AND column_name='is_trial') AS trial,
                EXISTS (SELECT 1 FROM pg_namespace WHERE nspname='times_intelligence') AS ps""")
            ver = None
            if row["ps"]:
                v = self._one("SELECT max(version) AS v FROM times_intelligence.schema_version")
                ver = v["v"] if v else None
            self._caps = SchemaCapabilities(row["trial"], row["ps"], ver)
        return self._caps

    def _trial(self) -> str:
        return "COALESCE(r.is_trial, false)" if self.capabilities().has_pay_run_is_trial else "false"

    def get_company_by_uid(self, company_uid: str) -> CompanyRef | None:
        row = self._one("""SELECT id, uid::text AS uid, subscription_uid::text AS sub, code FROM company.company
                           WHERE uid = %(u)s::uuid AND is_deleted = false""", {"u": _guid(company_uid)})
        return CompanyRef(row["id"], row["uid"], row["sub"], row["code"]) if row else None

    def list_companies(self) -> list[CompanyRef]:
        return [CompanyRef(r["id"], r["uid"], r["sub"], r["code"]) for r in self._all(
            "SELECT id, uid::text AS uid, subscription_uid::text AS sub, code FROM company.company WHERE is_deleted = false")]

    def get_pay_run(self, company_id: int, pay_run_uid: str) -> PayRunRef | None:
        row = self._one(f"""SELECT r.id, r.uid::text AS uid, pp.company_id, to_date(pp.value,'MM/YYYY') AS period, c.code,
                {self._trial()} AS is_trial, r.pay_run_date, r.name
            FROM payroll.pay_run r JOIN payroll.pay_period pp ON pp.id = r.pay_period_id
            JOIN payroll.lk_payroll_cycle c ON c.id = r.pay_cycle_id
            WHERE r.uid = %(u)s::uuid AND pp.company_id = %(cid)s""", {"u": _guid(pay_run_uid), "cid": company_id})
        if not row:
            return None
        return PayRunRef(row["id"], row["uid"], row["company_id"], row["period"], row["code"], row["is_trial"],
                         row["pay_run_date"], row["name"])

    def _records(self, where: str, params: dict, master, overtime_codes) -> list[PayRecordSnapshot]:
        sql = _RECORDS.replace("__TRIAL__", self._trial()) + where + " ORDER BY period, r.pay_run_date, pr.id"
        return [snapshot_from_row(r, master, overtime_codes) for r in self._all(sql, params)]

    def list_run_records(self, company_id, pay_run_id, master=None, overtime_codes=frozenset()):
        return self._records(" AND r.id = %(rid)s", {"company_id": company_id, "rid": pay_run_id}, master, overtime_codes)

    def list_history_records(self, company_id, period_from, period_to_exclusive, user_ids=None, master=None,
                             overtime_codes=frozenset(), exclude_pay_run_id=None):
        where = (" AND pr.status_id IN (2,4) AND to_date(pp.value,'MM/YYYY') >= %(f)s AND to_date(pp.value,'MM/YYYY') < %(t)s"
                 f" AND NOT {self._trial()} AND r.id <> COALESCE(%(ex)s, -1)")
        params = {"company_id": company_id, "f": period_from, "t": period_to_exclusive, "ex": exclude_pay_run_id}
        if user_ids is not None:
            where += " AND pr.user_id = ANY(%(uids)s)"
            params["uids"] = list(user_ids)
        return self._records(where, params, master, overtime_codes)

    def run_fingerprint(self, company_id: int, pay_run_id: int) -> str:
        row = self._one(f"""SELECT {FINGERPRINT_SQL} AS fp FROM payroll.pay_record pr
            JOIN payroll.pay_run r ON r.id = pr.pay_run_id JOIN payroll.pay_period pp ON pp.id = r.pay_period_id
            WHERE r.id = %(rid)s AND pp.company_id = %(cid)s""", {"rid": pay_run_id, "cid": company_id})
        return row["fp"] or "empty"

    def list_salary_revisions(self, company_id, user_ids, since: date) -> list[SalaryRevision]:
        rows = self._all("""SELECT cp.id, cp.uid::text AS uid, ucc.user_id, cp.contract_id, cs.code, cp.old_salary, cp.new_salary,
                cp.adjusted_amount, cp.adjustment_percent, cp.effective_date, cp.pay_effective_date, cp.created_on, cp.updated_on
            FROM employee.career_progression cp
            JOIN employee.user_company_contract ucc ON ucc.id = cp.contract_id
            JOIN company.code_setup cs ON cs.id = cp.career_progression_code_id
            WHERE ucc.company_id = %(cid)s AND ucc.user_id = ANY(%(u)s) AND cs.code <> 'CONSTART'
              AND (cp.effective_date >= %(s)s OR cp.pay_effective_date >= %(s)s)""",
                         {"cid": company_id, "u": list(user_ids), "s": since})
        f = lambda v: None if v is None else float(v)  # noqa: E731
        return [SalaryRevision(r["id"], r["uid"], r["user_id"], r["contract_id"], r["code"], f(r["old_salary"]),
                               f(r["new_salary"]), f(r["adjusted_amount"]), f(r["adjustment_percent"]), r["effective_date"],
                               r["pay_effective_date"], r["created_on"], r["updated_on"]) for r in rows]

    def list_configured_items(self, company_id, user_ids, period_start, period_end) -> list[ConfiguredPayItem]:
        rows = self._all("""SELECT cad.id, cad.uid::text AS uid, ucc.user_id, cad.contract_id, ad.code, t.code AS type_code,
                rm.code AS rm, c.code AS cycle, cad.amount, cad.effective_date, cad.end_date
            FROM employee.contract_allowance_deduction cad
            JOIN employee.user_company_contract ucc ON ucc.id = cad.contract_id
            JOIN company.allowance_deduction ad ON ad.id = cad.pay_code_id
            LEFT JOIN company.allowance_deduction_type t ON t.id = ad.type_id
            LEFT JOIN employee.lk_recurring_method rm ON rm.id = cad.recurring_method_id
            LEFT JOIN payroll.lk_payroll_cycle c ON c.id = cad.payroll_cycle_id
            WHERE ucc.company_id = %(cid)s AND ucc.user_id = ANY(%(u)s) AND cad.effective_date <= %(e)s
              AND (cad.end_date IS NULL OR cad.end_date >= %(s)s)""",
                         {"cid": company_id, "u": list(user_ids), "s": period_start, "e": period_end})
        earn = {"EARNING": True, "DEDUCTION": False}
        return [ConfiguredPayItem(r["id"], r["uid"], r["user_id"], r["contract_id"], r["code"],
                                  earn.get((r["type_code"] or "").upper()), r["rm"], r["cycle"], float(r["amount"]),
                                  r["effective_date"], r["end_date"]) for r in rows]

    def get_pay_code_master(self, company_id: int) -> dict[str, PayCodeMaster]:
        rows = self._all("""SELECT DISTINCT ON (ad.code) ad.code, ad.description, t.code AS type_code, cpf.code AS cpf_code,
                bt.code AS bonus, un.name AS unit
            FROM company.allowance_deduction ad
            LEFT JOIN company.allowance_deduction_type t ON t.id = ad.type_id
            LEFT JOIN company.allowance_deduction_cpf cpf ON cpf.id = ad.cpf_id
            LEFT JOIN company.allowance_deduction_bonus_type bt ON bt.id = ad.bonus_type_id
            LEFT JOIN company.allowance_deduction_unit un ON un.id = ad.unit_id
            WHERE ad.company_id = %(cid)s ORDER BY ad.code, ad.year DESC, ad.id DESC""", {"cid": company_id})
        return {r["code"]: PayCodeMaster(r["code"], r["description"], r["type_code"], r["cpf_code"], r["bonus"], r["unit"])
                for r in rows}

    def list_run_states(self, since_period: date, max_runs: int) -> list[RunState]:
        rows = self._all(f"""SELECT r.id, r.uid::text AS uid, pp.company_id, to_date(pp.value,'MM/YYYY') AS period, c.code,
                {self._trial()} AS is_trial, count(*) AS n, count(*) FILTER (WHERE pr.status_id = 1) AS processing,
                {FINGERPRINT_SQL} AS fp, max(COALESCE(pr.updated_on, pr.created_on)) AS last_change
            FROM payroll.pay_run r JOIN payroll.pay_period pp ON pp.id = r.pay_period_id
            JOIN payroll.lk_payroll_cycle c ON c.id = r.pay_cycle_id
            JOIN payroll.pay_record pr ON pr.pay_run_id = r.id
            WHERE to_date(pp.value,'MM/YYYY') >= %(s)s
            GROUP BY r.id, r.uid, pp.company_id, pp.value, c.code ORDER BY max(COALESCE(pr.updated_on, pr.created_on)) DESC
            LIMIT %(n)s""", {"s": since_period, "n": max_runs})
        return [RunState(r["id"], r["uid"], r["company_id"], r["period"], r["code"], r["is_trial"], r["n"], r["processing"],
                         r["fp"], r["last_change"]) for r in rows]

    def get_function_permissions(self, function_code, principals, company_uid) -> set[str]:
        perms: set[str] = set()
        for p in principals:
            for r in self._all("""SELECT permission FROM security.get_permissions_for_principle_on_resource(
                    %(res)s, 'function'::public.resource_type_enum, %(p)s, %(c)s::uuid)""",
                               {"res": function_code, "p": p, "c": _guid(company_uid)}):
                if r["permission"]:
                    perms.add(str(r["permission"]).lower())
        return perms

    def user_has_company_access(self, user_uid: str, company_id: int) -> bool:
        return self._one("""SELECT 1 AS ok FROM security.user_company uc JOIN security."user" u ON u.id = uc.user_id
                            WHERE u.uid = %(u)s::uuid AND uc.company_id = %(c)s""", {"u": _guid(user_uid), "c": company_id}) is not None

    def get_user_id_by_uid(self, user_uid: str) -> int | None:
        row = self._one('SELECT id FROM security."user" WHERE uid = %(u)s::uuid', {"u": _guid(user_uid)})
        return row["id"] if row else None

    def get_user_refs(self, company_id: int, user_ids: list[int]) -> dict[int, dict]:
        rows = self._all("""SELECT DISTINCT ON (u.id) u.id, u.uid::text AS user_uid, ucc.employee_no FROM security."user" u
            LEFT JOIN employee.user_company_contract ucc ON ucc.user_id = u.id AND ucc.company_id = %(c)s
            WHERE u.id = ANY(%(ids)s) ORDER BY u.id, ucc.is_active DESC""", {"c": company_id, "ids": list(user_ids)})
        return {r["id"]: {"user_uid": r["user_uid"], "employee_no": r["employee_no"]} for r in rows}
