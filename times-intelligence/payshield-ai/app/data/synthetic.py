"""Deterministic synthetic payroll for tests, evaluation and demos. Nothing here is real data.

generate_company(seed, ...) -> SyntheticCompany with END-cycle history (allowances, loan deductions,
December AWS bonus, April increments backed by salary revisions, hourly overtime for some staff, new
hires with proration). make_analysis_run(...) builds a new run with known injected scenarios.
"""

from __future__ import annotations

import random
import uuid
from dataclasses import dataclass, field
from datetime import date, datetime

from app.domain.models import (
    CompanyRef, ConfiguredPayItem, PayCodeMaster, PayItem, PayRecordSnapshot, PayRunRef, SalaryRevision,
)

OT_CODE = "OT15"
MASTER = {
    "TRAN": PayCodeMaster("TRAN", "Transport allowance", "EARNING", "OW", "NONBONU", None),
    "MEAL": PayCodeMaster("MEAL", "Meal allowance", "EARNING", "OW", "NONBONU", None),
    "AWS": PayCodeMaster("AWS", "Annual wage supplement", "EARNING", "AW", "BONU", None),
    OT_CODE: PayCodeMaster(OT_CODE, "Overtime 1.5x", "EARNING", "OW", "NONBONU", "Hour"),
    "LOAN": PayCodeMaster("LOAN", "Staff loan repayment", "DEDUCTION", "NONE", "NONBONU", None),
    "ADV": PayCodeMaster("ADV", "Salary advance recovery", "DEDUCTION", "NONE", "NONBONU", None),
}


def add_months(d: date, n: int) -> date:
    y, m = divmod(d.month - 1 + n, 12)
    return date(d.year + y, m + 1, 1)


@dataclass
class SyntheticUser:
    user_id: int
    user_uid: str
    employee_no: str
    contract_id: int
    hired: date
    basic: float
    has_meal: bool
    has_ot: bool
    loan_until: date | None


@dataclass
class SyntheticCompany:
    tenant_uid: str
    company: CompanyRef
    runs: list[PayRunRef] = field(default_factory=list)
    records: list[PayRecordSnapshot] = field(default_factory=list)
    revisions: list[SalaryRevision] = field(default_factory=list)
    configured: list[ConfiguredPayItem] = field(default_factory=list)
    master: dict[str, PayCodeMaster] = field(default_factory=lambda: dict(MASTER))
    overtime_codes: frozenset[str] = frozenset({OT_CODE})
    users: dict[int, SyntheticUser] = field(default_factory=dict)
    _ids: list[int] = field(default_factory=lambda: [100000])

    def next_id(self) -> int:
        self._ids[0] += 1
        return self._ids[0]


def _uid(rng: random.Random) -> str:
    return str(uuid.UUID(int=rng.getrandbits(128), version=4))


def _item(code: str, amount: float, rng: random.Random, *, recurring: int = 1, frequency: float = 1.0,
          rate: float | None = None) -> PayItem:
    m = MASTER[code]
    return PayItem(code, m.description, m.type_code == "EARNING", round(amount, 2),
                   "Additional" if m.cpf_code == "AW" else ("Ordinary" if m.type_code == "EARNING" else "None"),
                   recurring, 2 if rate else 0, rate if rate else amount, frequency, _uid(rng),
                   is_bonus=m.is_bonus, is_hourly=m.is_hourly, is_overtime=code == OT_CODE)


def build_record(sc: SyntheticCompany, run: PayRunRef, u: SyntheticUser, *, basic: float, items: list[PayItem],
                 basic_earned: float | None = None, cpf_assessed: bool = True, is_new_hire: bool = False,
                 status_id: int = 2) -> PayRecordSnapshot:
    earned = round(basic if basic_earned is None else basic_earned, 2)
    allowance = round(sum(i.amount for i in items if i.is_earning), 2)
    deduct = round(sum(i.amount for i in items if not i.is_earning), 2)
    gross = earned + allowance - deduct
    ow = min(earned + sum(i.amount for i in items if i.is_earning and not i.is_aw), 7400.0)
    aw = sum(i.amount for i in items if i.is_earning and i.is_aw)
    ee = round((ow + aw) * 0.20, 2) if cpf_assessed else None
    er = round((ow + aw) * 0.17, 2) if cpf_assessed else None
    return PayRecordSnapshot(
        pay_record_id=sc.next_id(), pay_record_uid=str(uuid.uuid4()), pay_run_id=run.id, pay_run_uid=run.uid,
        pay_run_date=run.pay_run_date, cycle_code=run.cycle_code, is_trial=run.is_trial, period=run.period,
        status_id=status_id, user_id=u.user_id, contract_id=u.contract_id, user_uid=u.user_uid,
        employee_no=u.employee_no, contract_code=f"CT-{u.employee_no}", is_new_hire=is_new_hire,
        basic_earned=earned, basic_contractual=basic, total_allowance=allowance, total_deduction=deduct,
        back_pay=0.0, gross_engine=round(gross, 2), net_pay=round(max(0.0, gross - (ee or 0)), 2),
        total_cpf_column=None if ee is None else round(ee + er, 2), cpf_employee=ee, cpf_employer=er,
        cpf_assessed=cpf_assessed, eligible_ow=ow if cpf_assessed else None, eligible_aw=aw if cpf_assessed else None,
        community_funds=2.0, sdl=round(min(11.25, earned * 0.0025), 2), hired_date=u.hired, items=items,
        created_on=run.pay_run_date,
    )


def _items_for(u: SyntheticUser, p: date, rng: random.Random, basic: float) -> list[PayItem]:
    items = [_item("TRAN", 200.0, rng)]
    if u.has_meal:
        items.append(_item("MEAL", 150.0, rng))
    if u.has_ot:
        hours = max(0.0, round(rng.gauss(12 + (4 if p.month in (11, 12) else 0), 3)))
        rate = round(basic / 173.0 * 1.5, 2)
        if hours:
            items.append(_item(OT_CODE, hours * rate, rng, recurring=5, frequency=hours, rate=rate))
    if p.month == 12:
        items.append(_item("AWS", basic, rng, recurring=4))
    if u.loan_until and p <= u.loan_until:
        items.append(_item("LOAN", 300.0, rng))
    return items


def _run(sc: SyntheticCompany, period: date, rng: random.Random, cycle: str = "END") -> PayRunRef:
    run = PayRunRef(sc.next_id(), _uid(rng), sc.company.id, period, cycle, False,
                    datetime(period.year, period.month, 25, 9, 0), f"{cycle} {period:%b %Y}")
    sc.runs.append(run)
    return run


def generate_company(seed: int, *, tenant_uid: str, company: CompanyRef, n_employees: int = 60, months: int = 24,
                     start: date = date(2024, 10, 1), user_id_offset: int = 0) -> SyntheticCompany:
    rng = random.Random(seed)
    sc = SyntheticCompany(tenant_uid, company)
    end = add_months(start, months - 1)
    for k in range(n_employees):
        uid_ = user_id_offset + k + 1
        hired = start if (k < int(n_employees * 0.85) or months < 12) else add_months(start, rng.randint(3, months - 8))
        sc.users[uid_] = SyntheticUser(
            uid_, _uid(rng), f"E{uid_:05d}", 50000 + uid_, hired,
            round(min(15000.0, max(2500.0, rng.lognormvariate(8.4, 0.35))), -1),
            rng.random() < 0.5, rng.random() < 0.3,
            add_months(start, rng.randint(2, max(2, months))) if rng.random() < 0.2 else None)
        u = sc.users[uid_]
        for code, amt, on in (("TRAN", 200.0, True), ("MEAL", 150.0, u.has_meal)):
            if on:
                sc.configured.append(ConfiguredPayItem(sc.next_id(), _uid(rng), uid_, u.contract_id, code, True, "MON",
                                                       "END", amt, hired, None))
    for i in range(months):
        p = add_months(start, i)
        run = _run(sc, p, rng)
        for u in sc.users.values():
            if p < u.hired:
                continue
            if p.month == 4 and p > u.hired:
                old, u.basic = u.basic, round(u.basic * (1 + rng.uniform(0.02, 0.06)), -1)
                sc.revisions.append(SalaryRevision(sc.next_id(), _uid(rng), u.user_id, u.contract_id, "ANLINCR", old,
                                                   u.basic, u.basic - old, round((u.basic / old - 1) * 100, 2), p, p,
                                                   datetime(p.year, p.month, 1)))
            new_hire = p == u.hired and u.hired != start
            earned = round(u.basic * rng.uniform(0.4, 0.9), 2) if new_hire else None
            sc.records.append(build_record(sc, run, u, basic=u.basic, basic_earned=earned,
                                           items=_items_for(u, p, rng, u.basic), is_new_hire=new_hire))
    assert end == sc.runs[-1].period
    return sc


SCENARIOS = ("salary_increase_no_revision", "duplicate_allowance", "missing_recurring_allowance", "unusual_overtime",
             "unexpected_net_increase", "new_large_deduction", "cpf_missing",
             "approved_promotion", "december_bonus", "normal")


def make_analysis_run(sc: SyntheticCompany, scenarios: dict[int, str], *, seed: int = 7
                      ) -> tuple[PayRunRef, list[PayRecordSnapshot], list[SalaryRevision]]:
    """Next-period END run for every active employee. Employees in ``scenarios`` get that scenario;
    returns (run, records, revisions added for legitimate promotions)."""
    rng = random.Random(seed)
    period = add_months(sc.runs[-1].period, 1)
    run = _run(sc, period, rng)
    sc.runs.pop()  # the analysed run is not history
    out, revs = [], []
    for u in sc.users.values():
        s = scenarios.get(u.user_id, "normal")
        basic, items, cpf = u.basic, _items_for(u, period, rng, u.basic), True
        if s == "salary_increase_no_revision":
            basic = round(u.basic * 1.5, -1)
        elif s == "approved_promotion":
            basic = round(u.basic * 1.2, -1)
            revs.append(SalaryRevision(sc.next_id(), _uid(rng), u.user_id, u.contract_id, "PROMOTION", u.basic, basic,
                                       basic - u.basic, 20.0, period, period, datetime(period.year, period.month, 2)))
        elif s == "duplicate_allowance":
            items.append(_item("TRAN", 200.0, rng))
        elif s == "missing_recurring_allowance":
            items = [i for i in items if i.code != "TRAN"]
        elif s == "unusual_overtime":
            rate = round(u.basic / 173.0 * 1.5, 2)
            items = [i for i in items if i.code != OT_CODE] + [_item(OT_CODE, 65 * rate, rng, recurring=5, frequency=65, rate=rate)]
        elif s == "unexpected_net_increase":
            items.append(PayItem("ADJ", "Manual adjustment", True, round(u.basic * 0.55, 2), "Ordinary", 5, 2, None, 1.0, _uid(rng)))
        elif s == "new_large_deduction":
            items.append(_item("ADV", round(u.basic * 0.35, 2), rng, recurring=5))
        elif s == "cpf_missing":
            cpf = False
        elif s == "december_bonus":
            items.append(_item("AWS", u.basic, rng, recurring=4))
        out.append(build_record(sc, run, u, basic=basic, items=items, cpf_assessed=cpf))
    return run, out, revs
