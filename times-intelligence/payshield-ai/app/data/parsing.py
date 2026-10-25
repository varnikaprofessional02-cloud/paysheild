"""Parse payroll.pay_record.data_processed (engine JSON, camelCase) into domain snapshots.

Row keys expected by ``snapshot_from_row`` (SQL aliases in app/db/payroll_repository.py):
pay_record_id, pay_record_uid, pay_run_id, pay_run_uid, pay_run_date, cycle_code, is_trial, period, status_id,
user_id, user_uid, employee_no, contract_id, contract_code, is_new_hire, is_resignee, basic_salary,
total_allowance, total_deduction, total_cpf, total_payout, created_on, updated_on, doc (json: the projected
subset {payRecord, employee.statutorySummary, employeeContract.hiredDate/resignationDate}).
"""

from __future__ import annotations

import json
from datetime import date, datetime
from typing import Any, Mapping

from app.domain.models import PayCodeMaster, PayItem, PayRecordSnapshot

_RECURRING_NAMES = {"day": 0, "month": 1, "quarterly": 2, "halfyearly": 3, "yearly": 4, "nonrecurring": 5}
_RATE_NAMES = {"amount": 0, "ratebysalary": 1, "fixrate": 2}


def _num(v: Any) -> float | None:
    if isinstance(v, dict):
        v = v.get("amount")
    if v is None or isinstance(v, bool):
        return None
    try:
        return float(v)
    except (TypeError, ValueError):
        return None


def _enum(v: Any, names: dict[str, int]) -> int | None:
    if isinstance(v, dict):
        v = next(iter(v.values()), None) if len(v) == 1 else v.get("recurringMethodType", v.get("payComponentAmountTypeRate"))
    if isinstance(v, bool) or v is None:
        return None
    if isinstance(v, (int, float)):
        return int(v)
    return names.get(str(v).replace("_", "").lower())


def _get(d: Any, *path: str) -> Any:
    for p in path:
        if not isinstance(d, dict):
            return None
        d = d.get(p)
    return d


def _date(v: Any) -> date | None:
    if not v or not isinstance(v, str) or v.startswith("9999") or v.startswith("0001"):
        return None
    try:
        return datetime.fromisoformat(v[:19]).date()
    except ValueError:
        return None


def parse_pay_items(results: Any, master: Mapping[str, PayCodeMaster] | None = None,
                    overtime_codes: frozenset[str] = frozenset()) -> list[PayItem]:
    if isinstance(results, str):
        results = json.loads(results)
    out: list[PayItem] = []
    for r in results or []:
        comp = r.get("payComponent") or {}
        code = str(_get(comp, "payCode", "code") or "").strip()
        if not code:
            continue
        is_earning = comp.get("isEarning")
        if is_earning is None:
            is_earning = comp.get("type") in (1, "Earning")
        amt_type = comp.get("amountType") or {}
        adjustments = r.get("adjustments") or []
        factor = _num(adjustments[-1].get("factor")) if adjustments else None
        m = (master or {}).get(code)
        out.append(PayItem(
            code=code,
            description=_get(comp, "payCode", "description"),
            is_earning=bool(is_earning),
            amount=abs(_num(r.get("amount")) or 0.0),
            cpf_wage_type=comp.get("cpfWageType") if isinstance(comp.get("cpfWageType"), str) else None,
            recurring_method=_enum(comp.get("recurringMethodType"), _RECURRING_NAMES),
            rate_kind=_enum(amt_type.get("payComponentAmountTypeRate"), _RATE_NAMES),
            rate_value=_num(amt_type.get("amountTypeRateValue")),
            frequency=_num(amt_type.get("frequency")),
            component_uid=comp.get("uid"),
            proration_factor=factor,
            is_bonus=bool(m and m.is_bonus),
            is_hourly=bool(m and m.is_hourly),
            is_overtime=code in overtime_codes,
        ))
    return out


def snapshot_from_data_processed(doc: Mapping[str, Any] | str | None, *, master=None,
                                 overtime_codes: frozenset[str] = frozenset(), **cols: Any) -> PayRecordSnapshot:
    if isinstance(doc, str):
        doc = json.loads(doc)
    doc = doc or {}
    pr = doc.get("payRecord")
    has_payload = isinstance(pr, dict)
    pr = pr if has_payload else {}
    cpf = pr.get("cpfCalculationResult")
    cpf_assessed = isinstance(cpf, dict)
    cpf = cpf if cpf_assessed else {}
    summary = _get(doc, "employee", "statutorySummary") or {}
    contract = doc.get("employeeContract") or {}
    flags = {k: summary.get(k) for k in ("hasAWExcess", "awExcess", "hasAWShortfall", "awShortfall") if k in summary}
    return PayRecordSnapshot(
        pay_record_id=cols["pay_record_id"], pay_record_uid=str(cols["pay_record_uid"]),
        pay_run_id=cols["pay_run_id"], pay_run_uid=str(cols["pay_run_uid"]), pay_run_date=cols["pay_run_date"],
        cycle_code=cols["cycle_code"], is_trial=bool(cols.get("is_trial")), period=cols["period"],
        status_id=int(cols["status_id"]), user_id=cols["user_id"], contract_id=cols["contract_id"],
        user_uid=str(cols["user_uid"]) if cols.get("user_uid") else None, employee_no=cols.get("employee_no"),
        contract_code=cols.get("contract_code"),
        is_new_hire=bool(cols.get("is_new_hire")), is_resignee=bool(cols.get("is_resignee")),
        basic_earned=_num(cols.get("basic_salary")) if cols.get("basic_salary") is not None else _num(_get(pr, "basicSalaryCalculationResult", "amount")),
        basic_contractual=_num(_get(pr, "basicSalaryCalculationResult", "basicSalary")),
        total_allowance=_num(cols.get("total_allowance")) if cols.get("total_allowance") is not None else _num(_get(pr, "allowanceDeductionCalculationResult", "totalAllowance")),
        total_deduction=_num(cols.get("total_deduction")) if cols.get("total_deduction") is not None else _num(_get(pr, "allowanceDeductionCalculationResult", "totalDeduction")),
        back_pay=_num(_get(pr, "backPayCalculationResult", "amount")),
        gross_engine=_num(pr.get("grossPay")),
        net_pay=_num(cols.get("total_payout")) if cols.get("total_payout") is not None else _num(pr.get("nettPay")),
        total_cpf_column=_num(cols.get("total_cpf")),
        cpf_employee=_num(cpf.get("totalEmployeeContribution")) if cpf_assessed else None,
        cpf_employer=_num(cpf.get("totalEmployerContribution")) if cpf_assessed else None,
        cpf_assessed=cpf_assessed, cpf_is_adjustment=bool(cpf.get("isAdjustment")),
        eligible_ow=_num(cpf.get("eligibleOW")), eligible_aw=_num(cpf.get("eligibleAW")),
        community_funds=_num(_get(pr, "communityFundsCalculationResult", "totalAmount")),
        sdl=_num(_get(pr, "sdlCalculationResult", "amount")),
        donation=_num(_get(pr, "donationCalculationResult", "amount")),
        currency=_get(pr, "grossPay", "currency") or "SGD",
        hired_date=_date(contract.get("hiredDate")), resignation_date=_date(contract.get("resignationDate")),
        statutory_flags=flags, has_payload=has_payload,
        items=parse_pay_items(_get(pr, "allowanceDeductionCalculationResult", "payComponentResults"), master, overtime_codes),
        created_on=cols.get("created_on"), updated_on=cols.get("updated_on"),
    )


def snapshot_from_row(row: Mapping[str, Any], master=None, overtime_codes: frozenset[str] = frozenset()) -> PayRecordSnapshot:
    cols = dict(row)
    doc = cols.pop("doc", None)
    return snapshot_from_data_processed(doc, master=master, overtime_codes=overtime_codes, **cols)
