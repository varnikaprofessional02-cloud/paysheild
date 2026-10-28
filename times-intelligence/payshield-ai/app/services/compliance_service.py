"""Compliance checks on one pay run: the reasons a payroll must not be paid as it stands.

Every check is a hard rule on the pay records and employee records as they were at the end of the pay period
(Singapore figures in app.rules.sg_statutory). Findings use the same shape as the Identification checks, so they are
decided (fixed / accepted) and block the release of the pay run the same way. Findings about the whole pay run
use employeeNo RUN_LEVEL.
"""

from __future__ import annotations

import statistics
from dataclasses import dataclass, field
from datetime import date, datetime, timedelta
from typing import Any

from app.data.parsing import snapshot_from_row
from app.db.connection import ConnectionManager
from app.domain.models import PayRecordSnapshot
from app.rules import sg_statutory as sg

RUN_LEVEL = "PAY RUN"
ONE_OFF_MIN = 500.0         # ad-hoc earnings from this amount need an approval on the contract
TOTAL_TOLERANCE = 0.12      # pay run net total vs the total expected from past months

_RECORDS = """
SELECT pr.id AS pay_record_id, pr.uid AS pay_record_uid, pr.pay_run_id, r.uid AS pay_run_uid, r.pay_run_date,
       coalesce(cy.code, 'END') AS cycle_code, %(start)s::date AS period, pr.status_id, pr.user_id, pr.contract_id,
       ucc.employee_no, pr.basic_salary, pr.total_allowance, pr.total_deduction, pr.total_cpf, pr.total_payout,
       pr.data_processed AS doc,
       ur.residency_type::text AS residency, ui.date_of_birth AS dob,
       wp.pass_code, wp.pass_issue_date, wp.levy_management_id, cr.last_day AS last_day,
       coalesce(cfg.codes, ARRAY[]::text[]) AS configured_codes
FROM payroll.pay_record pr
JOIN payroll.pay_run r ON r.id = pr.pay_run_id
LEFT JOIN payroll.lk_payroll_cycle cy ON cy.id = r.pay_cycle_id
JOIN employee.user_company_contract ucc ON ucc.id = pr.contract_id AND ucc.company_id = %(c)s
LEFT JOIN employee.user_regulatory ur ON ur.user_id = ucc.user_id
LEFT JOIN LATERAL (SELECT i.date_of_birth FROM security.user_identity i WHERE i.user_id = ucc.user_id ORDER BY i.id DESC LIMIT 1) ui ON true
LEFT JOIN LATERAL (SELECT cs.code AS pass_code, w.pass_issue_date, w.levy_management_id FROM employee.epm_work_pass_records w
                   LEFT JOIN company.code_setup cs ON cs.id = w.work_pass_id
                   WHERE w.regulatory_id = ur.id AND (w.cancellation_date IS NULL OR w.cancellation_date > %(e)s)
                     AND (w.pass_issue_date IS NULL OR w.pass_issue_date <= %(e)s)
                   ORDER BY w.pass_expiry_date DESC LIMIT 1) wp ON true
LEFT JOIN LATERAL (SELECT min(x.last_day_of_work)::date AS last_day FROM employee.contract_resignation x WHERE x.contract_id = ucc.id) cr ON true
LEFT JOIN LATERAL (SELECT array_agg(DISTINCT ad.code) AS codes FROM employee.contract_allowance_deduction cad
                   JOIN company.allowance_deduction ad ON ad.id = cad.pay_code_id
                   WHERE cad.contract_id = ucc.id AND cad.effective_date <= %(e)s) cfg ON true
WHERE pr.pay_run_id = %(run)s"""

# CPF wages already paid this year, before this pay period (for the annual Additional Wage ceiling)
_YTD = """
SELECT pr.contract_id,
       sum(coalesce((pr.data_processed #>> '{payRecord,cpfCalculationResult,eligibleOW,amount}')::numeric, 0)) AS ow,
       sum(coalesce((pr.data_processed #>> '{payRecord,cpfCalculationResult,eligibleAW,amount}')::numeric, 0)) AS aw
FROM payroll.pay_record pr JOIN payroll.pay_run r ON r.id = pr.pay_run_id
JOIN payroll.pay_period pp ON pp.id = r.pay_period_id AND pp.company_id = %(c)s
WHERE to_date(pp.value, 'MM/YYYY') >= %(y)s AND to_date(pp.value, 'MM/YYYY') < %(start)s
GROUP BY pr.contract_id"""

_TOTALS = """
SELECT to_date(pp.value, 'MM/YYYY') AS period,
       sum(COALESCE((pr.data_processed #>> '{payRecord,nettPay,amount}')::numeric, pr.total_payout, 0)) AS net
FROM payroll.pay_record pr JOIN payroll.pay_run r ON r.id = pr.pay_run_id
JOIN payroll.pay_period pp ON pp.id = r.pay_period_id AND pp.company_id = %(c)s
WHERE to_date(pp.value, 'MM/YYYY') <= %(start)s
GROUP BY 1 ORDER BY 1"""


@dataclass
class Person:
    snap: PayRecordSnapshot
    residency: str | None = None
    dob: date | None = None
    pass_code: str | None = None
    pass_issue_date: date | None = None
    levy_id: int | None = None
    last_day: date | None = None
    configured_codes: set[str] = field(default_factory=set)
    ytd_ow: float = 0.0
    ytd_aw: float = 0.0


@dataclass
class RunInfo:
    name: str
    start: date
    end: date
    pay_run_date: datetime | date | None = None
    created_by: str | None = None
    updated_by: str | None = None
    totals: dict[date, float] = field(default_factory=dict)  # net total per month, this month included


def _f(emp, rule, typ, sev, risk, desc, action, **ev) -> dict:
    return {"employeeNo": emp, "ruleId": rule, "anomalyType": typ, "severity": sev, "riskScore": risk,
            "description": desc, "recommendedAction": action, "source": "RULE", "evidence": ev}


def _m(v: float) -> str:
    return f"S${v:,.2f}"


def check_people(people: list[Person], run: RunInfo) -> list[dict]:
    out: list[dict] = []
    count: dict[int, int] = {}
    for p in people:
        count[p.snap.user_id] = count.get(p.snap.user_id, 0) + 1
    seen_dup: set[int] = set()
    for p in people:
        s, no = p.snap, p.snap.employee_no
        net = s.net_pay or 0.0
        earned = (s.basic_earned or 0.0) + (s.total_allowance or 0.0)
        local = p.residency == "SingaporeanOrSPR"

        # employment ------------------------------------------------------------------------------
        if p.last_day and p.last_day < run.start and net > 0:
            out.append(_f(no, "CMP-001", "PAID_AFTER_LEAVING", "CRITICAL", 96,
                          f"Last day of work was {p.last_day:%d %b %Y}, but this pay run pays {_m(net)}.",
                          "Remove the employee from this pay run and recover any salary already paid after the last day.",
                          field=f"left {p.last_day:%d %b %Y}"))
        if count[s.user_id] > 1 and s.user_id not in seen_dup:
            seen_dup.add(s.user_id)
            out.append(_f(no, "CMP-002", "DUPLICATE_PAYMENT", "CRITICAL", 95,
                          f"Paid {count[s.user_id]} times in this pay run.",
                          "Delete the duplicate pay record before the bank file is generated.", field=f"{count[s.user_id]} pay records"))

        # MOM: work passes -------------------------------------------------------------------------
        if p.pass_code in sg.PASS_MIN_SALARY and p.pass_issue_date:
            floor = sg.pass_min_salary(p.pass_code, p.pass_issue_date)
            fixed = (s.basic_contractual or s.basic_earned or 0.0) + sum(
                i.amount for i in s.items if i.is_earning and i.recurring_method == 1)
            if floor and fixed < floor:
                out.append(_f(no, "CMP-003", "PASS_SALARY_BELOW_MOM", "HIGH", 86,
                              f"{p.pass_code} holder paid a fixed monthly salary of {_m(fixed)}, below the MOM minimum of {_m(floor)} for this pass.",
                              "Correct the salary to the amount declared to MOM, or update the pass; a mismatch can get the pass revoked.",
                              field=f"{_m(fixed)} < {_m(floor)}"))
        if p.pass_code in sg.LEVY_PASSES and not p.levy_id:
            out.append(_f(no, "CMP-004", "LEVY_NOT_SET", "MEDIUM", 62,
                          f"{p.pass_code} holder with no foreign worker levy set up, so the levy is not costed in this pay run.",
                          "Set the levy tier and sector for this pass so the monthly levy is paid to MOM.", field=f"{p.pass_code} · no levy"))

        # CPF ---------------------------------------------------------------------------------------
        ee, er = s.cpf_employee or 0.0, s.cpf_employer or 0.0
        if p.residency == "WorkPassHolder" and (ee > 0 or er > 0):
            out.append(_f(no, "CMP-005", "CPF_ON_FOREIGNER", "HIGH", 84,
                          f"CPF of {_m(ee + er)} calculated for a work pass holder, who is not liable for CPF.",
                          "Set the employee's residency correctly and recalculate; refund the employee share.", field=f"CPF {_m(ee + er)}"))
        elif local and s.cpf_assessed and p.dob and earned > 50:
            ow = min(s.eligible_ow or 0.0, sg.ow_ceiling(run.start.year))
            room = max(0.0, sg.ANNUAL_WAGE_CEILING - (p.ytd_ow + ow) - p.ytd_aw)
            aw = s.eligible_aw or 0.0
            if aw > room + 1:
                out.append(_f(no, "CMP-006", "AW_CEILING_EXCEEDED", "HIGH", 80,
                              f"CPF charged on {_m(aw)} of Additional Wages, but only {_m(room)} is left under this year's {_m(sg.ANNUAL_WAGE_CEILING)} ceiling.",
                              "Cap the Additional Wages that attract CPF and refund the excess contribution.",
                              field=f"AW {_m(aw)} > {_m(room)}"))
            else:
                age = sg.cpf_age(p.dob, run.start)
                ree, rer = sg.cpf_rates(age, run.start.year)
                due_ee, due_er = round((ow + aw) * ree, 2), round((ow + aw) * rer, 2)
                if abs(ee - due_ee) > max(2.0, due_ee * 0.01) or abs(er - due_er) > max(2.0, due_er * 0.01):
                    out.append(_f(no, "CMP-007", "CPF_RATE_WRONG", "HIGH", 83,
                                  f"CPF for age {age} should be {ree * 100:g}% + {rer * 100:g}% ({_m(due_ee)} + {_m(due_er)}), but the pay run has {_m(ee)} + {_m(er)}.",
                                  "Recalculate CPF with the right age band; short payment attracts late payment interest from CPF Board.",
                                  field=f"age {age}: {_m(ee)} vs {_m(due_ee)}"))
        if earned > 0 and (s.sdl is None or s.sdl <= 0):
            out.append(_f(no, "CMP-008", "SDL_MISSING", "MEDIUM", 58,
                          f"No Skills Development Levy for {_m(earned)} of wages (due about {_m(sg.sdl_due(earned))}).",
                          "Recalculate statutory contributions; SDL is payable for every employee with the CPF submission.",
                          field=f"SDL due {_m(sg.sdl_due(earned))}"))
        if local and earned > 0 and not (s.community_funds or 0) > 0:
            out.append(_f(no, "CMP-009", "SHG_MISSING", "MEDIUM", 52,
                          "No self-help group fund (CDAC / MBMF / SINDA / ECF) deducted for a citizen / PR.",
                          "Check the employee's race and opt-out status, then recalculate the community fund.", field="SHG S$0.00"))

        # Employment Act ----------------------------------------------------------------------------
        ded = s.total_deduction or 0.0
        if earned > 0 and ded > earned * sg.DEDUCTION_MAX_SHARE:
            out.append(_f(no, "CMP-010", "DEDUCTION_OVER_LIMIT", "HIGH", 85,
                          f"Deductions of {_m(ded)} are {ded / earned * 100:.0f}% of the salary; the Employment Act allows at most 50%.",
                          "Reduce the deductions in this period and spread the recovery over later months.",
                          field=f"{ded / earned * 100:.0f}% deducted"))
        for i in s.items:
            if not i.is_overtime or not i.frequency:
                continue
            hours = float(i.frequency)
            if hours > sg.OT_MAX_HOURS:
                out.append(_f(no, "CMP-011", "OT_OVER_LIMIT", "HIGH", 82,
                              f"{hours:g} overtime hours this month; the Employment Act limit is {sg.OT_MAX_HOURS} hours a month.",
                              "Hold the excess overtime until MOM exemption or a corrected timesheet is on file.",
                              field=f"{hours:g} h > {sg.OT_MAX_HOURS} h"))
            basic = s.basic_contractual or s.basic_earned or 0.0
            minimum = sg.hourly_basic(basic) * sg.OT_MIN_MULTIPLIER if basic else 0.0
            rate = i.amount / hours
            if minimum and rate < minimum - 0.01:
                out.append(_f(no, "CMP-012", "OT_RATE_TOO_LOW", "HIGH", 81,
                              f"Overtime paid at {_m(rate)}/h; the minimum is 1.5 x the hourly basic rate = {_m(minimum)}/h.",
                              "Recalculate overtime at no less than 1.5 times the hourly basic rate.",
                              field=f"{_m(rate)}/h < {_m(minimum)}/h"))

        # approvals -------------------------------------------------------------------------------
        for i in s.items:
            if (i.is_earning and i.recurring_method == 5 and not i.is_overtime and i.amount >= ONE_OFF_MIN
                    and i.code not in p.configured_codes):
                out.append(_f(no, "CMP-013", "ONE_OFF_NOT_APPROVED", "HIGH", 80,
                              f"One-off payment '{i.description or i.code}' of {_m(i.amount)} with no approved entry on the employee's contract.",
                              "Attach the approval (bonus memo / commission sheet) or remove the payment.",
                              field=f"{i.code} {_m(i.amount)}"))
    return out


def check_run(run: RunInfo) -> list[dict]:
    out: list[dict] = []
    if run.pay_run_date:
        pay_day = run.pay_run_date.date() if isinstance(run.pay_run_date, datetime) else run.pay_run_date
        due = run.end + timedelta(days=sg.PAY_DUE_DAYS)
        if pay_day > due:
            out.append(_f(RUN_LEVEL, "CMP-020", "LATE_PAY_RUN", "HIGH", 84,
                          f"Pay date {pay_day:%d %b %Y} is {(pay_day - due).days} day(s) after {due:%d %b %Y}, the Employment Act deadline (7 days after the period ends).",
                          "Bring the pay date forward, or record MOM's written approval for the later date.",
                          field=f"pay day {pay_day:%d %b}"))
    if run.created_by and run.created_by == run.updated_by:
        out.append(_f(RUN_LEVEL, "CMP-021", "NO_SECOND_APPROVER", "MEDIUM", 66,
                      f"Prepared and last changed by the same person ({run.created_by}); no one else has reviewed it.",
                      "Have a second payroll approver review the pay run before it is released.", field=run.created_by))
    total = run.totals.get(run.start)
    prior = sorted(d for d in run.totals if d < run.start)[-6:]
    if total and len(prior) >= 3:
        base = statistics.median(run.totals[d] for d in prior)
        ly = date(run.start.year - 1, run.start.month, 1)
        before_ly = [run.totals[d] for d in run.totals if ly > d >= date(ly.year - (ly.month <= 6), (ly.month - 7) % 12 + 1, 1)]
        season = run.totals[ly] / statistics.median(before_ly) if ly in run.totals and before_ly else 1.0
        expected = base * season
        off = total / expected - 1
        if abs(off) > TOTAL_TOLERANCE:
            out.append(_f(RUN_LEVEL, "CMP-022", "RUN_TOTAL_OFF_EXPECTED", "HIGH", 82,
                          f"Net pay total {_m(total)} is {off * 100:+.0f}% against the {_m(expected)} expected from past months"
                          + (" (same month last year included)" if season != 1.0 else "") + ".",
                          "Look for a bulk import error or a mistyped salary before releasing the bank file.",
                          field=f"{off * 100:+.0f}% vs expected"))
    return out


class ComplianceService:
    def __init__(self, conn: ConnectionManager, db_name: str):
        self.conn, self.db = conn, db_name

    def check(self, company_id: int, run_id: int, start: date, end: date) -> list[dict]:
        with self.conn.connection(self.db) as c:
            rows = c.execute(_RECORDS, {"c": company_id, "run": run_id, "start": start, "e": end}).fetchall()
            ytd = {r["contract_id"]: r for r in c.execute(_YTD, {"c": company_id, "y": date(start.year, 1, 1), "start": start}).fetchall()}
            totals = {r["period"]: float(r["net"]) for r in c.execute(_TOTALS, {"c": company_id, "start": start}).fetchall()}
            head = c.execute("SELECT name, pay_run_date, created_by, updated_by FROM payroll.pay_run WHERE id = %(r)s", {"r": run_id}).fetchone()
            ot = c.execute("SELECT overtime_pay_codes FROM times_intelligence.company_setting WHERE company_id = %(c)s",
                           {"c": company_id}).fetchone()
        ot_codes = frozenset((ot or {}).get("overtime_pay_codes") or [])
        people = []
        for r in rows:
            extra: dict[str, Any] = {k: r.pop(k) for k in ("residency", "dob", "pass_code", "pass_issue_date", "levy_management_id",
                                                           "last_day", "configured_codes")}
            y = ytd.get(r["contract_id"]) or {}
            people.append(Person(snapshot_from_row(r, overtime_codes=ot_codes), extra["residency"], extra["dob"], extra["pass_code"],
                                 extra["pass_issue_date"], extra["levy_management_id"], extra["last_day"], set(extra["configured_codes"]),
                                 float(y.get("ow") or 0), float(y.get("aw") or 0)))
        run = RunInfo(head["name"], start, end, head["pay_run_date"], head["created_by"], head["updated_by"], totals)
        return check_people(people, run) + check_run(run)
