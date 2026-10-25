"""Synthetic builders shared by unit tests. Values are invented; nothing here comes from production."""

from __future__ import annotations

import itertools
import uuid
from datetime import date, datetime
from typing import Iterable

from app.domain.models import (
    CompanyRef,
    ConfiguredPayItem,
    PayCodeMaster,
    PayItem,
    PayRecordSnapshot,
    PayRunRef,
    SalaryRevision,
)

_ids = itertools.count(1)

TENANT_A = "11111111-1111-4111-8111-111111111111"
TENANT_B = "22222222-2222-4222-8222-222222222222"
COMPANY_A1 = CompanyRef(id=1, uid="aaaaaaa1-0000-4000-8000-000000000001", subscription_uid=TENANT_A, code="ACO")
COMPANY_A2 = CompanyRef(id=2, uid="aaaaaaa2-0000-4000-8000-000000000002", subscription_uid=TENANT_A, code="ACO2")
COMPANY_B1 = CompanyRef(id=1, uid="bbbbbbb1-0000-4000-8000-000000000001", subscription_uid=TENANT_B, code="BCO")


def next_id() -> int:
    return next(_ids)


def new_uid() -> str:
    return str(uuid.uuid4())


def month(year: int, m: int) -> date:
    return date(year, m, 1)


def add_months(d: date, n: int) -> date:
    y, m = divmod(d.month - 1 + n, 12)
    return date(d.year + y, m + 1, 1)


def periods(start: date, count: int) -> list[date]:
    return [add_months(start, i) for i in range(count)]


def item(
    code: str,
    amount: float,
    *,
    is_earning: bool = True,
    description: str | None = None,
    cpf_wage_type: str = "Ordinary",
    recurring_method: int | None = 1,
    rate_kind: int | None = 0,
    frequency: float | None = 1.0,
    is_bonus: bool = False,
    is_hourly: bool = False,
    is_overtime: bool = False,
    component_uid: str | None = None,
) -> PayItem:
    return PayItem(
        code=code,
        description=description or code,
        is_earning=is_earning,
        amount=amount,
        cpf_wage_type=cpf_wage_type,
        recurring_method=recurring_method,
        rate_kind=rate_kind,
        rate_value=amount if rate_kind == 0 else None,
        frequency=frequency,
        component_uid=component_uid or new_uid(),
        is_bonus=is_bonus,
        is_hourly=is_hourly,
        is_overtime=is_overtime,
    )


def deduction(code: str, amount: float, **kw) -> PayItem:
    kw.setdefault("cpf_wage_type", "None")
    return item(code, amount, is_earning=False, **kw)


def pay_run(
    period: date,
    *,
    company_id: int = 1,
    cycle_code: str = "END",
    is_trial: bool = False,
    run_id: int | None = None,
    uid: str | None = None,
) -> PayRunRef:
    return PayRunRef(
        id=run_id or next_id(),
        uid=uid or new_uid(),
        company_id=company_id,
        period=period,
        cycle_code=cycle_code,
        is_trial=is_trial,
        pay_run_date=datetime(period.year, period.month, 25, 9, 0),
        name=f"{cycle_code} {period:%b %Y}",
    )


def record(
    run: PayRunRef,
    *,
    user_id: int,
    contract_id: int | None = None,
    basic: float = 4000.0,
    basic_earned: float | None = None,
    items: Iterable[PayItem] = (),
    back_pay: float | None = 0.0,
    cpf_rate_employee: float = 0.20,
    cpf_rate_employer: float = 0.17,
    cpf_assessed: bool = True,
    status_id: int = 2,
    is_new_hire: bool = False,
    is_resignee: bool = False,
    hired_date: date | None = date(2020, 1, 6),
    currency: str = "SGD",
    statutory_flags: dict | None = None,
    net_override: float | None = None,
) -> PayRecordSnapshot:
    """Build a record whose totals are internally consistent with the engine formulas:
    gross = basic + allowances - deductions + back pay; net = gross - employee CPF (floored at 0)."""
    items = list(items)
    earned = basic if basic_earned is None else basic_earned
    allowance = sum(i.amount for i in items if i.is_earning)
    deduct = sum(i.amount for i in items if not i.is_earning)
    gross_engine = earned + allowance - deduct + (back_pay or 0.0)
    ow = earned + sum(i.amount for i in items if i.is_earning and not i.is_aw)
    aw = sum(i.amount for i in items if i.is_earning and i.is_aw)
    cpf_ee = round((ow + aw) * cpf_rate_employee, 2) if cpf_assessed else None
    cpf_er = round((ow + aw) * cpf_rate_employer, 2) if cpf_assessed else None
    net = max(0.0, gross_engine - (cpf_ee or 0.0)) if net_override is None else net_override
    return PayRecordSnapshot(
        pay_record_id=next_id(),
        pay_record_uid=new_uid(),
        pay_run_id=run.id,
        pay_run_uid=run.uid,
        pay_run_date=run.pay_run_date,
        cycle_code=run.cycle_code,
        is_trial=run.is_trial,
        period=run.period,
        status_id=status_id,
        user_id=user_id,
        contract_id=contract_id if contract_id is not None else 1000 + user_id,
        user_uid=f"00000000-0000-4000-8000-{user_id:012d}",
        employee_no=f"E{user_id:04d}",
        contract_code=f"C{user_id:04d}",
        is_new_hire=is_new_hire,
        is_resignee=is_resignee,
        basic_earned=earned,
        basic_contractual=basic,
        total_allowance=allowance,
        total_deduction=deduct,
        back_pay=back_pay,
        gross_engine=gross_engine,
        net_pay=net,
        total_cpf_column=(cpf_ee or 0.0) + (cpf_er or 0.0) if cpf_assessed else None,
        cpf_employee=cpf_ee,
        cpf_employer=cpf_er,
        cpf_assessed=cpf_assessed,
        eligible_ow=ow if cpf_assessed else None,
        eligible_aw=aw if cpf_assessed else None,
        community_funds=2.0,
        sdl=min(11.25, round(max(earned, 0) * 0.0025, 2)),
        currency=currency,
        hired_date=hired_date,
        statutory_flags=statutory_flags or {},
        items=items,
        created_on=run.pay_run_date,
    )


def employee_history(
    *,
    user_id: int,
    start: date,
    months: int,
    basic: float = 4000.0,
    items_factory=None,
    company_id: int = 1,
    cycle_code: str = "END",
    runs: dict[date, PayRunRef] | None = None,
) -> list[PayRecordSnapshot]:
    """Monthly END-cycle history for one employee. ``items_factory(period) -> list[PayItem]``."""
    out: list[PayRecordSnapshot] = []
    runs = runs if runs is not None else {}
    for p in periods(start, months):
        run = runs.setdefault(p, pay_run(p, company_id=company_id, cycle_code=cycle_code))
        its = items_factory(p) if items_factory else [item("TRAN", 200.0)]
        out.append(record(run, user_id=user_id, basic=basic, items=its))
    return out


def revision(
    *,
    user_id: int,
    contract_id: int | None = None,
    old: float,
    new: float,
    effective: date,
    pay_effective: date | None = None,
    code: str = "PROMOTION",
    created_on: datetime | None = None,
) -> SalaryRevision:
    return SalaryRevision(
        id=next_id(),
        uid=new_uid(),
        user_id=user_id,
        contract_id=contract_id if contract_id is not None else 1000 + user_id,
        code=code,
        old_salary=old,
        new_salary=new,
        adjusted_amount=new - old,
        adjustment_percent=round((new - old) / old * 100, 2) if old else None,
        effective_date=effective,
        pay_effective_date=pay_effective or effective,
        created_on=created_on or datetime(effective.year, effective.month, 1),
    )


def configured(
    *, user_id: int, code: str, amount: float, effective: date, end: date | None = None,
    recurring: str = "MON", is_earning: bool = True, contract_id: int | None = None,
) -> ConfiguredPayItem:
    return ConfiguredPayItem(
        id=next_id(),
        uid=new_uid(),
        user_id=user_id,
        contract_id=contract_id if contract_id is not None else 1000 + user_id,
        code=code,
        is_earning=is_earning,
        recurring_method_code=recurring,
        cycle_code="END",
        amount=amount,
        effective_date=effective,
        end_date=end,
    )


def master(*codes: tuple[str, str, str | None, str | None]) -> dict[str, PayCodeMaster]:
    """``(code, type_code, bonus_type_code, unit_name)`` tuples -> master dict."""
    return {
        c: PayCodeMaster(code=c, description=c, type_code=t, cpf_code="OW", bonus_type_code=b, unit_name=u)
        for (c, t, b, u) in codes
    }
