"""Compliance checks: silent on a clean pay run, and each planted problem raises its own finding."""

from __future__ import annotations

from datetime import date, datetime, timedelta

from app.data.synthetic import COMPLIANCE_SCENARIOS, generate_company, make_analysis_run
from app.domain.models import CompanyRef
from app.rules import sg_statutory as sg
from app.services.compliance_service import RUN_LEVEL, Person, RunInfo, check_people, check_run

EXPECTED = {"ot_over_limit": "OT_OVER_LIMIT", "ot_rate_low": "OT_RATE_TOO_LOW", "deduction_over_half": "DEDUCTION_OVER_LIMIT",
            "cpf_on_foreigner": "CPF_ON_FOREIGNER", "aw_over_ceiling": "AW_CEILING_EXCEEDED", "sdl_missing": "SDL_MISSING",
            "shg_missing": "SHG_MISSING", "one_off_payment": "ONE_OFF_NOT_APPROVED", "paid_twice": "DUPLICATE_PAYMENT"}


def _company():
    return generate_company(11, tenant_uid="t", company=CompanyRef(1, "u", "t", "C"), n_employees=90, months=21, foreign_every=7)


def _people(sc, records, period, by_user=None):
    ytd: dict[int, list[float]] = {}
    for r in sc.records:
        if r.period.year == period.year and r.period < period:
            y = ytd.setdefault(r.contract_id, [0.0, 0.0])
            y[0] += r.eligible_ow or 0
            y[1] += r.eligible_aw or 0
    out = []
    for r in records:
        u = sc.users[r.user_id]
        p = Person(r, "WorkPassHolder" if u.foreign else "SingaporeanOrSPR", date(1990, 5, 1), None, None, None, None,
                   {"TRAN", "MEAL"}, *ytd.get(r.contract_id, [0.0, 0.0]))
        for k, v in (by_user or {}).get(r.user_id, {}).items():
            setattr(p, k, v)
        out.append(p)
    return out


def _run(period, totals=None, **kw):
    end = date(period.year + (period.month == 12), period.month % 12 + 1, 1) - timedelta(days=1)
    return RunInfo("END", period, end, datetime(period.year, period.month, 25), "System", None, totals or {}, **kw)


def test_clean_run_has_no_findings():
    sc = _company()
    run, recs, _ = make_analysis_run(sc, {}, seed=3)
    assert check_people(_people(sc, recs, run.period), _run(run.period)) == []


def test_each_planted_problem_is_found():
    sc = _company()
    users = sorted(sc.users.values(), key=lambda u: u.user_id)
    local = [u for u in users if not u.foreign and u.hired == sc.runs[0].period]
    ot = [u for u in local if u.has_ot]
    rich = max(local, key=lambda u: u.basic)
    pick = iter(u for u in local if not u.has_ot and u is not rich)
    scen = {ot[0].user_id: "ot_over_limit", ot[1].user_id: "ot_rate_low", next(u for u in users if u.foreign).user_id: "cpf_on_foreigner",
            rich.user_id: "aw_over_ceiling"}
    for s in ("deduction_over_half", "sdl_missing", "shg_missing", "one_off_payment", "paid_twice"):
        scen[next(pick).user_id] = s
    run, recs, _ = make_analysis_run(sc, scen, seed=3)
    findings = check_people(_people(sc, recs, run.period), _run(run.period))
    by = {(f["employeeNo"], f["anomalyType"]) for f in findings}
    for uid, s in scen.items():
        assert (sc.users[uid].employee_no, EXPECTED[s]) in by, s
    assert {f["anomalyType"] for f in findings} == set(EXPECTED.values())


def test_employee_record_checks():
    sc = _company()
    run, recs, _ = make_analysis_run(sc, {}, seed=3)
    holder = next(r for r in recs if sc.users[r.user_id].foreign)
    a, b, c = [r for r in recs if not sc.users[r.user_id].foreign][:3]
    plants = {a.user_id: {"last_day": run.period - timedelta(days=20)},
              b.user_id: {"dob": date(run.period.year - 62, 1, 15)},  # 62: lower CPF rates than the 20% / 17% paid
              holder.user_id: {"pass_code": "EP", "pass_issue_date": date(2026, 1, 1)},
              c.user_id: {"residency": "WorkPassHolder", "pass_code": "WP"}}
    if holder.basic_contractual >= 5600:
        holder.basic_contractual = 4200.0
    types = {(f["employeeNo"], f["anomalyType"]) for f in check_people(_people(sc, recs, run.period, plants), _run(run.period))}
    assert (a.employee_no, "PAID_AFTER_LEAVING") in types
    assert (b.employee_no, "CPF_RATE_WRONG") in types
    assert (holder.employee_no, "PASS_SALARY_BELOW_MOM") in types
    assert (c.employee_no, "LEVY_NOT_SET") in types


def test_run_level_checks():
    p = date(2026, 10, 1)
    totals = {date(2026, m, 1): 390_000.0 for m in range(4, 10)} | {p: 470_000.0}
    run = _run(p, totals)
    run.pay_run_date, run.created_by, run.updated_by = datetime(2026, 11, 12), "mei.ling", "mei.ling"
    types = {f["anomalyType"] for f in check_run(run) if f["employeeNo"] == RUN_LEVEL}
    assert types == {"LATE_PAY_RUN", "NO_SECOND_APPROVER", "RUN_TOTAL_OFF_EXPECTED"}
    run.pay_run_date, run.updated_by, run.totals = datetime(2026, 10, 25), None, totals | {p: 395_000.0}
    assert check_run(run) == []


def test_cpf_age_band_starts_the_month_after_the_birthday():
    dob = date(1971, 8, 10)  # 55 in August 2026
    assert sg.cpf_age(dob, date(2026, 8, 1)) == 54
    assert sg.cpf_age(dob, date(2026, 9, 1)) == 55
    assert sg.cpf_rates(54, 2026) == (0.20, 0.17) and sg.cpf_rates(55, 2026) == (0.18, 0.16)
    assert len(COMPLIANCE_SCENARIOS) == 10
