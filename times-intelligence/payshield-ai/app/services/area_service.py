"""Training areas other than Payroll.

IDENTIFICATION is real: deterministic identity checks on the tenant DB plus a trained baseline of hashed identifiers,
so later checks can also flag identity details that changed since training (e.g. a bank account switched before payday).
ATTENDANCE, EPM, TIMESHEET and CLAIMS are demo areas: training records a mock model so the flow can be shown,
and every response marks them as mock.
"""

from __future__ import annotations

import random
import time
from datetime import date, timedelta
from typing import Any

from psycopg.types.json import Jsonb

from app.db.connection import ConnectionManager
from app.services.compliance_service import ComplianceService

AREAS: dict[str, dict[str, Any]] = {
    "PAYROLL": {"label": "Payroll", "mock": False, "detail": "Pay anomalies per employee vs their own history (ML + 17 rules)"},
    "IDENTIFICATION": {"label": "Identification", "mock": False, "detail": "Duplicate NRIC/FIN, shared bank accounts, work pass expiry, missing IDs, changes since training; per pay run also CPF, MOM, Employment Act and approval checks"},
    "ATTENDANCE": {"label": "Attendance", "mock": True, "detail": "Clock-in patterns, buddy punching, missed clock-outs"},
    "EPM": {"label": "EPM", "mock": True, "detail": "Employee records: job, grade and contract consistency"},
    "TIMESHEET": {"label": "Timesheet", "mock": True, "detail": "Hours vs roster, unusual overtime claims"},
    "CLAIMS": {"label": "Claims", "mock": True, "detail": "Unusual expense claims vs the employee's and team's history"},
}

# one row per employee of the company, with the identifiers the checks need; hashes only leave the database
_PEOPLE = """
SELECT ucc.user_id, ucc.employee_no, ur.residency_type::text AS residency,
       md5(ur.nric_no) AS nric_h, wp.fin_h, wp.pass_expiry,
       bank.acct_h, md5(lower(u.email)) AS email_h, md5(regexp_replace(coalesce(u.ph_number, ''), '\\D', '', 'g')) AS phone_h,
       nullif(regexp_replace(coalesce(u.ph_number, ''), '\\D', '', 'g'), '') AS phone_digits,
       EXISTS (SELECT 1 FROM payroll.pay_record pr WHERE pr.contract_id = ucc.id AND pr.pay_run_id = %(run)s) AS on_latest_run
FROM employee.user_company_contract ucc
JOIN security."user" u ON u.id = ucc.user_id
LEFT JOIN employee.user_regulatory ur ON ur.user_id = ucc.user_id
LEFT JOIN LATERAL (SELECT md5(upper(w.fin)) AS fin_h, w.pass_expiry_date AS pass_expiry FROM employee.epm_work_pass_records w
                   WHERE w.regulatory_id = ur.id AND w.cancellation_date IS NULL ORDER BY w.pass_expiry_date DESC LIMIT 1) wp ON true
LEFT JOIN LATERAL (SELECT md5(ps.account_number) AS acct_h FROM employee.payment_profile pf
                   JOIN employee.payment_split ps ON ps.payment_profile_id = pf.id
                   WHERE pf.contract_id = ucc.id AND pf.company_id = %(c)s AND pf.is_active AND ps.account_number IS NOT NULL
                   ORDER BY pf.is_preferred DESC, ps.sort LIMIT 1) bank ON true
WHERE ucc.company_id = %(c)s"""

# the same identifiers as they were at the end of one pay period, for the employees paid in that pay run:
# bank account = the payment profile effective on the period end; an NRIC or phone updated after the period end is unknown
# for that period (its earlier value is not kept), so it is left out instead of being judged on today's value
_PEOPLE_AT = """
SELECT ucc.user_id, ucc.employee_no, ur.residency_type::text AS residency,
       CASE WHEN ur.updated_on IS NULL OR ur.updated_on::date <= %(e)s THEN md5(ur.nric_no) END AS nric_h,
       (ur.updated_on IS NOT NULL AND ur.updated_on::date > %(e)s) AS id_unknown,
       wp.fin_h, wp.pass_expiry, bank.acct_h, bank.since AS bank_since, prev.acct_h AS prev_acct_h, NULL AS email_h,
       CASE WHEN u.updated_on IS NULL OR u.updated_on::date <= %(e)s
            THEN md5(nullif(regexp_replace(coalesce(u.ph_number, ''), '\\D', '', 'g'), '')) END AS phone_h,
       true AS on_latest_run
FROM payroll.pay_record pr
JOIN employee.user_company_contract ucc ON ucc.id = pr.contract_id AND ucc.company_id = %(c)s
JOIN security."user" u ON u.id = ucc.user_id
LEFT JOIN employee.user_regulatory ur ON ur.user_id = ucc.user_id
LEFT JOIN LATERAL (SELECT md5(upper(w.fin)) AS fin_h, w.pass_expiry_date AS pass_expiry FROM employee.epm_work_pass_records w
                   WHERE w.regulatory_id = ur.id AND (w.cancellation_date IS NULL OR w.cancellation_date > %(e)s)
                   ORDER BY w.pass_expiry_date DESC LIMIT 1) wp ON true
LEFT JOIN LATERAL (SELECT md5(ps.account_number) AS acct_h, pf.effective_date AS since FROM employee.payment_profile pf
                   JOIN employee.payment_split ps ON ps.payment_profile_id = pf.id
                   WHERE pf.contract_id = ucc.id AND pf.company_id = %(c)s AND pf.effective_date <= %(e)s AND ps.account_number IS NOT NULL
                   ORDER BY pf.effective_date DESC, pf.id DESC, ps.sort LIMIT 1) bank ON true
LEFT JOIN LATERAL (SELECT md5(ps.account_number) AS acct_h FROM employee.payment_profile pf
                   JOIN employee.payment_split ps ON ps.payment_profile_id = pf.id
                   WHERE pf.contract_id = ucc.id AND pf.company_id = %(c)s AND pf.effective_date < bank.since AND ps.account_number IS NOT NULL
                   ORDER BY pf.effective_date DESC, pf.id DESC, ps.sort LIMIT 1) prev ON true
WHERE pr.pay_run_id = %(run)s"""

_RUN = """SELECT r.id, r.name, to_date(pp.value, 'MM/YYYY') AS start FROM payroll.pay_run r JOIN payroll.pay_period pp ON pp.id = r.pay_period_id
          WHERE pp.company_id = %(c)s AND r.uid = %(u)s::uuid"""

_LATEST_RUN = """SELECT r.id, r.name FROM payroll.pay_run r JOIN payroll.pay_period pp ON pp.id = r.pay_period_id
                 WHERE pp.company_id = %(c)s ORDER BY to_date(pp.value, 'MM/YYYY') DESC, r.id DESC LIMIT 1"""


def _f(emp, rule, typ, sev, risk, desc, action, **ev) -> dict:
    return {"employeeNo": emp, "ruleId": rule, "anomalyType": typ, "severity": sev, "riskScore": risk,
            "description": desc, "recommendedAction": action, "source": "RULE", "evidence": ev}


class AreaService:
    def __init__(self, conn: ConnectionManager, db_name: str):
        self.conn, self.db = conn, db_name

    def _all(self, sql: str, p: dict | None = None) -> list[dict]:
        with self.conn.connection(self.db) as c:
            cur = c.execute(sql, p or {})
            return cur.fetchall() if cur.description else []

    # models ------------------------------------------------------------------------------------
    def list_active(self, company_id: int) -> list[dict]:
        return self._all("""SELECT uid::text AS model_id, area, version, is_mock, record_count, duration_ms, summary, trained_on, trained_by
            FROM times_intelligence.area_model WHERE company_id = %(c)s AND status = 'ACTIVE' ORDER BY area""", {"c": company_id})

    def _register(self, company_id: int, area: str, actor: str, *, mock: bool, records: int, ms: int, summary: dict,
                  baseline: dict | None) -> dict:
        with self.conn.connection(self.db) as c, c.transaction():
            v = c.execute("""SELECT coalesce(max(version), 0) + 1 AS v FROM times_intelligence.area_model
                             WHERE company_id = %(c)s AND area = %(a)s""", {"c": company_id, "a": area}).fetchone()["v"]
            c.execute("""UPDATE times_intelligence.area_model SET status = 'SUPERSEDED'
                         WHERE company_id = %(c)s AND area = %(a)s AND status = 'ACTIVE'""", {"c": company_id, "a": area})
            return c.execute("""INSERT INTO times_intelligence.area_model (company_id, area, version, is_mock, record_count,
                    duration_ms, summary, baseline, trained_by) VALUES (%(c)s,%(a)s,%(v)s,%(m)s,%(n)s,%(d)s,%(s)s,%(b)s,%(u)s)
                RETURNING uid::text AS model_id, area, version, is_mock, record_count, duration_ms, summary, trained_on, trained_by""",
                             {"c": company_id, "a": area, "v": v, "m": mock, "n": records, "d": ms, "s": Jsonb(summary),
                              "b": Jsonb(baseline) if baseline is not None else None, "u": actor}).fetchone()

    def train(self, company_id: int, area: str, actor: str) -> dict:
        if area == "IDENTIFICATION":
            return self._train_identification(company_id, actor)
        if AREAS.get(area, {}).get("mock"):
            return self._train_mock(company_id, area, actor)
        raise ValueError(f"unknown training area {area}")

    def _train_mock(self, company_id: int, area: str, actor: str) -> dict:
        t0 = time.perf_counter()
        n = self._all("SELECT count(*) AS n FROM employee.user_company_contract WHERE company_id = %(c)s", {"c": company_id})[0]["n"]
        rng = random.Random(f"{company_id}:{area}")
        time.sleep(0.6)  # the demo areas have no data to learn from; this only makes the flow visible
        summary = {"mock": True, "note": "Demo area: no real data was used and no model was trained.",
                   "records": n * 24, "recallAtAlert": round(rng.uniform(0.78, 0.93), 3), "falseAlertRate": round(rng.uniform(0.004, 0.02), 3)}
        return self._register(company_id, area, actor, mock=True, records=n * 24, ms=int((time.perf_counter() - t0) * 1000),
                              summary=summary, baseline=None)

    def _people(self, company_id: int) -> tuple[list[dict], dict | None]:
        run = self._all(_LATEST_RUN, {"c": company_id})
        return self._all(_PEOPLE, {"c": company_id, "run": run[0]["id"] if run else -1}), (run[0] if run else None)

    def _train_identification(self, company_id: int, actor: str) -> dict:
        t0 = time.perf_counter()
        people, _ = self._people(company_id)
        # baseline = hashed identifiers per employee; the raw NRIC / account numbers are never copied out of payroll
        baseline = {str(p["user_id"]): {k: p[k] for k in ("nric_h", "fin_h", "acct_h", "email_h", "phone_h")} for p in people}
        findings = self._checks(people, None)
        summary = {"employees": len(people), "withNric": sum(1 for p in people if p["nric_h"]),
                   "withWorkPass": sum(1 for p in people if p["fin_h"]), "withBankAccount": sum(1 for p in people if p["acct_h"]),
                   "openFindings": len(findings), "byType": _count(findings)}
        return self._register(company_id, "IDENTIFICATION", actor, mock=False, records=len(people),
                              ms=int((time.perf_counter() - t0) * 1000), summary=summary, baseline=baseline)

    # checks ------------------------------------------------------------------------------------
    def check_identification(self, company_id: int, pay_run_uid: str | None = None) -> dict | None:
        """Identity checks. With a pay run: as at the end of that pay period, for the employees paid in it."""
        if pay_run_uid:
            return self._check_period(company_id, pay_run_uid)
        m = self._all("""SELECT version, baseline, trained_on FROM times_intelligence.area_model
                         WHERE company_id = %(c)s AND area = 'IDENTIFICATION' AND status = 'ACTIVE'""", {"c": company_id})
        if not m:
            return None
        t0 = time.perf_counter()
        people, run = self._people(company_id)
        findings = self._checks(people, m[0]["baseline"] or {})
        findings.sort(key=lambda f: -f["riskScore"])
        return {"area": "IDENTIFICATION", "modelVersion": m[0]["version"], "trainedOn": m[0]["trained_on"].isoformat(),
                "payRun": run["name"] if run else None, "employees": len(people),
                "flaggedEmployees": len({f["employeeNo"] for f in findings}), "findingCount": len(findings),
                "byType": _count(findings), "durationMs": int((time.perf_counter() - t0) * 1000), "findings": findings}

    def _check_period(self, company_id: int, pay_run_uid: str) -> dict | None:
        m = self._all("""SELECT version, trained_on FROM times_intelligence.area_model
                         WHERE company_id = %(c)s AND area = 'IDENTIFICATION' AND status = 'ACTIVE'""", {"c": company_id})
        run = self._all(_RUN, {"c": company_id, "u": pay_run_uid})
        if not m or not run:
            return None
        t0 = time.perf_counter()
        start = run[0]["start"]
        end = date(start.year + (start.month == 12), start.month % 12 + 1, 1) - timedelta(days=1)
        people = self._all(_PEOPLE_AT, {"c": company_id, "run": run[0]["id"], "e": end})
        findings = self._checks(people, None, asof=end)
        for p in people:  # bank account switched during this pay period
            if p["bank_since"] and start <= p["bank_since"] <= end and p["prev_acct_h"] and p["prev_acct_h"] != p["acct_h"]:
                findings.append(_f(p["employee_no"], "ID-006", "BANK_ACCOUNT_CHANGED", "HIGH", 85,
                                   f"Bank account changed on {p['bank_since']:%d %b %Y}, so this pay run goes to a new account.",
                                   "Confirm the new account with the employee through a known contact before releasing pay.",
                                   field="Bank account", changedOn=str(p["bank_since"])))
        # compliance checks (CPF, MOM, Employment Act, approvals) on the same pay run; decided and released the same way
        findings += ComplianceService(self.conn, self.db).check(company_id, run[0]["id"], start, end)
        findings.sort(key=lambda f: -f["riskScore"])
        return {"area": "IDENTIFICATION", "modelVersion": m[0]["version"], "trainedOn": m[0]["trained_on"].isoformat(),
                "payRun": run[0]["name"], "asOf": str(end), "employees": len(people),
                "flaggedEmployees": len({f["employeeNo"] for f in findings}), "findingCount": len(findings),
                "byType": _count(findings), "durationMs": int((time.perf_counter() - t0) * 1000), "findings": findings}

    @staticmethod
    def _checks(people: list[dict], baseline: dict | None, asof=None) -> list[dict]:
        out: list[dict] = []
        today = asof or date.today()
        word = "the period end" if asof else "today"

        def shared(key: str) -> dict[str, list[dict]]:
            groups: dict[str, list[dict]] = {}
            for p in people:
                if p[key]:
                    groups.setdefault(p[key], []).append(p)
            return {k: v for k, v in groups.items() if len(v) > 1}

        for key, rule, typ, sev, risk, what, act in (
            ("nric_h", "ID-001", "DUPLICATE_NRIC", "CRITICAL", 95, "NRIC", "Two employees cannot share an NRIC. Check for a duplicate or ghost employee record."),
            ("fin_h", "ID-001", "DUPLICATE_FIN", "CRITICAL", 95, "FIN", "Two employees cannot share a FIN. Check the work pass records."),
            ("acct_h", "ID-002", "SHARED_BANK_ACCOUNT", "HIGH", 88, "bank account", "Confirm both employees really share this account (e.g. joint account); otherwise hold payment."),
            ("phone_h", "ID-005", "SHARED_PHONE", "MEDIUM", 55, "mobile number", "Confirm the contact details; shared numbers can hide duplicate employees."),
        ):
            for grp in shared(key).values():
                nos = sorted(p["employee_no"] for p in grp)
                for p in grp:
                    others = ", ".join(n for n in nos if n != p["employee_no"])
                    out.append(_f(p["employee_no"], rule, typ, sev, risk if p["on_latest_run"] else risk - 10,
                                  f"Same {what} as {others}.", act, sharedWith=[n for n in nos if n != p["employee_no"]]))
        for p in people:
            if p["pass_expiry"] is not None:
                days = (p["pass_expiry"] - today).days
                if days < 0:
                    out.append(_f(p["employee_no"], "ID-003", "WORK_PASS_EXPIRED", "HIGH", 90 if p["on_latest_run"] else 70,
                                  f"Work pass expired {-days} day(s) before {word} ({p['pass_expiry']}) but the employee is still on payroll.",
                                  "Stop pay until a valid pass is on file; check MOM for renewal.", expiry=str(p["pass_expiry"])))
                elif days <= 30:
                    out.append(_f(p["employee_no"], "ID-003", "WORK_PASS_EXPIRING", "MEDIUM", 60,
                                  f"Work pass expires {days} day(s) after {word} ({p['pass_expiry']}).",
                                  "Start the renewal now so pay is not held next month.", expiry=str(p["pass_expiry"])))
            if p.get("id_unknown"):
                pass
            elif p["residency"] == "SingaporeanOrSPR" and not p["nric_h"] or p["residency"] == "WorkPassHolder" and not p["fin_h"]:
                out.append(_f(p["employee_no"], "ID-004", "MISSING_ID", "HIGH", 80 if p["on_latest_run"] else 65,
                              f"No {'NRIC' if p['residency'] == 'SingaporeanOrSPR' else 'FIN / work pass'} on file for a {('citizen/PR' if p['residency'] == 'SingaporeanOrSPR' else 'work pass holder')}.",
                              "Add the identity document before paying; CPF and IR8A need it."))
            b = (baseline or {}).get(str(p["user_id"]))
            if b:
                for key, label, sev, risk in (("acct_h", "Bank account", "HIGH", 85), ("nric_h", "NRIC", "HIGH", 82),
                                              ("fin_h", "FIN", "MEDIUM", 70), ("phone_h", "Mobile number", "LOW", 40),
                                              ("email_h", "Email", "LOW", 35)):
                    if b.get(key) and p[key] and b[key] != p[key]:
                        out.append(_f(p["employee_no"], "ID-006", _CHANGED[key], sev, risk,
                                      f"{label} changed since Identification was trained.",
                                      "Verify the change with the employee through a known contact before releasing pay.", field=label))
        return out


_CHANGED = {"acct_h": "BANK_ACCOUNT_CHANGED", "nric_h": "NRIC_CHANGED", "fin_h": "FIN_CHANGED",
            "phone_h": "PHONE_CHANGED", "email_h": "EMAIL_CHANGED"}


def _count(findings: list[dict]) -> dict[str, int]:
    c: dict[str, int] = {}
    for f in findings:
        c[f["anomalyType"]] = c.get(f["anomalyType"], 0) + 1
    return c

