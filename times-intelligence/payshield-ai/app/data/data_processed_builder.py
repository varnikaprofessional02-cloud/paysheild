"""Build a data_processed document in the envelope written by times-payroll-api PayRecordFactory
(camelCase, enums as ints except cpfWageType, Money = {amount, currency}). Used for synthetic seeding."""

from __future__ import annotations

from typing import Any

from app.domain.models import PayRecordSnapshot


def _m(v: float | None, cur: str = "SGD") -> dict[str, Any] | None:
    return None if v is None else {"amount": round(v, 2), "currency": cur}


def build_data_processed(s: PayRecordSnapshot, *, full_name: str = "Synthetic Employee") -> dict[str, Any]:
    if not s.has_payload:
        pay_record = None
    else:
        comps = [{
            "amount": _m(i.amount),
            "payComponent": {
                "id": 0, "uid": i.component_uid,
                "payCode": {"code": i.code, "description": i.description, "wageType": 1 if i.is_aw else 0},
                "type": 1 if i.is_earning else 2, "isEarning": i.is_earning,
                "cpfWageType": i.cpf_wage_type or "None",
                "amountType": {"payComponentAmountTypeRate": i.rate_kind or 0,
                               "amountTypeRateValue": i.rate_value, "frequency": i.frequency},
                "recurringMethodType": {"recurringMethodType": i.recurring_method if i.recurring_method is not None else 5,
                                        "recurringMethodValue": 1},
                "amount": _m(i.amount),
            },
            "adjustments": [],
        } for i in s.items]
        pay_record = {
            "employeeId": s.user_id, "contractId": s.contract_id,
            "grossPay": _m(s.gross_engine, s.currency), "nettPay": _m(s.net_pay, s.currency),
            "backPayCalculationResult": {"amount": _m(s.back_pay or 0.0)},
            "basicSalaryCalculationResult": {"amount": _m(s.basic_earned), "basicSalary": _m(s.basic_contractual), "adjustments": []},
            "allowanceDeductionCalculationResult": {
                "amount": _m((s.total_allowance or 0) - (s.total_deduction or 0)),
                "totalAllowance": _m(s.total_allowance), "totalDeduction": _m(s.total_deduction),
                "payComponentResults": comps,
            },
            "donationCalculationResult": {"amount": _m(s.donation or 0.0)},
            "cpfCalculationResult": None if not s.cpf_assessed else {
                "totalEmployeeContribution": _m(s.cpf_employee), "totalEmployerContribution": _m(s.cpf_employer),
                "totalContribution": _m((s.cpf_employee or 0) + (s.cpf_employer or 0)),
                "eligibleOW": _m(s.eligible_ow), "eligibleAW": _m(s.eligible_aw), "isAdjustment": s.cpf_is_adjustment,
            },
            "communityFundsCalculationResult": {"totalAmount": _m(s.community_funds or 0.0)},
            "sdlCalculationResult": {"amount": _m(s.sdl or 0.0)},
        }
    return {
        "payRunUid": s.pay_run_uid, "payrollCycleId": 2, "status": 1,
        "processedOn": s.pay_run_date.isoformat(), "processedBy": "synthetic",
        "employee": {"userId": s.user_id, "fullName": full_name, "statutorySummary": dict(s.statutory_flags)},
        "payRecord": pay_record,
        "employeeContract": {
            "hiredDate": s.hired_date.isoformat() + "T00:00:00" if s.hired_date else None,
            "resignationDate": s.resignation_date.isoformat() + "T00:00:00" if s.resignation_date else None,
        },
    }
