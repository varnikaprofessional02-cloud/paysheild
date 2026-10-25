"""Domain objects shared by data access, feature engineering, rules, ML and the API.

Money is carried as ``float`` inside the analytics pipeline (pandas/scikit-learn) and rounded to
2 dp only when persisted or returned. ``None`` always means "not available", never zero.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from datetime import date, datetime
from typing import Any

from app.domain.enums import (
    AnomalyType,
    Confidence,
    FindingSource,
    Severity,
)

# ------------------------------------------------------------------------------------------
# Reference data
# ------------------------------------------------------------------------------------------


@dataclass(frozen=True)
class CompanyRef:
    id: int  # company.company.id (tenant-local)
    uid: str  # company.company.uid (immutable, model key part 2)
    subscription_uid: str  # company.company.subscription_uid (must equal the tenant uid)
    code: str | None = None


@dataclass(frozen=True)
class PayRunRef:
    id: int
    uid: str
    company_id: int
    period: date  # first day of the payroll month, from to_date(pay_period.value, 'MM/YYYY')
    cycle_code: str  # payroll.lk_payroll_cycle.code: MID, END, SPECIAL, BONUS, WEEK, CUSTOM
    is_trial: bool
    pay_run_date: datetime
    name: str | None = None


@dataclass(frozen=True)
class PayCodeMaster:
    """Latest-year company.allowance_deduction row per code (DISTINCT ON code ORDER BY year DESC)."""

    code: str
    description: str | None
    type_code: str | None  # allowance_deduction_type.code (EARNING / DEDUCTION ...)
    cpf_code: str | None  # allowance_deduction_cpf.code (OW / AW / ...)
    bonus_type_code: str | None  # NONBONU / BONU / PREBONU
    unit_name: str | None  # allowance_deduction_unit.name (e.g. Hour, Day)

    @property
    def is_bonus(self) -> bool:
        return (self.bonus_type_code or "").upper() in ("BONU", "PREBONU")

    @property
    def is_hourly(self) -> bool:
        return "hour" in (self.unit_name or "").lower()


@dataclass(frozen=True)
class SalaryRevision:
    """Non-CONSTART employee.career_progression row (no approval state exists in the product)."""

    id: int
    uid: str
    user_id: int
    contract_id: int
    code: str  # company.code_setup code, e.g. PROMOTION, ANLINCR
    old_salary: float | None
    new_salary: float | None
    adjusted_amount: float | None
    adjustment_percent: float | None
    effective_date: date  # governs the salary in force
    pay_effective_date: date  # governs when back pay is paid
    created_on: datetime
    updated_on: datetime | None = None


@dataclass(frozen=True)
class ConfiguredPayItem:
    """employee.contract_allowance_deduction line joined with its pay code."""

    id: int
    uid: str
    user_id: int
    contract_id: int
    code: str
    is_earning: bool | None
    recurring_method_code: str | None  # employee.lk_recurring_method.code
    cycle_code: str | None  # lk_payroll_cycle.code of the line
    amount: float
    effective_date: date
    end_date: date | None


# ------------------------------------------------------------------------------------------
# Parsed payroll records
# ------------------------------------------------------------------------------------------


@dataclass(frozen=True)
class PayItem:
    """One entry of payRecord.allowanceDeductionCalculationResult.payComponentResults[]."""

    code: str  # payComponent.payCode.code — stable per-company item key
    description: str | None
    is_earning: bool
    amount: float  # magnitude as stored (deductions are positive)
    cpf_wage_type: str | None  # 'Ordinary' | 'Additional' | 'None'
    recurring_method: int | None  # RecurringMethod value
    rate_kind: int | None  # AmountRateKind value
    rate_value: float | None
    frequency: float | None
    component_uid: str | None
    proration_factor: float | None = None
    # enrichment from PayCodeMaster / company settings (filled by the parser when master data is given)
    is_bonus: bool = False
    is_hourly: bool = False
    is_overtime: bool = False

    @property
    def is_adhoc(self) -> bool:
        return self.rate_kind == 2 and self.recurring_method == 5

    @property
    def is_aw(self) -> bool:
        return (self.cpf_wage_type or "").lower() == "additional"

    @property
    def signed_amount(self) -> float:
        return self.amount if self.is_earning else -self.amount

    @property
    def hours(self) -> float | None:
        return self.frequency if self.is_hourly and self.frequency is not None else None


@dataclass
class PayRecordSnapshot:
    """One payroll.pay_record row with the data_processed paths PayShield needs.

    Every money field is ``None`` when the engine did not produce it (failed/skipped rows,
    statutory deferred by Mid Month policy, pre-#8113 records lacking a path).
    """

    pay_record_id: int
    pay_record_uid: str
    pay_run_id: int
    pay_run_uid: str
    pay_run_date: datetime
    cycle_code: str
    is_trial: bool
    period: date
    status_id: int
    user_id: int
    contract_id: int
    user_uid: str | None = None
    employee_no: str | None = None
    contract_code: str | None = None  # employee.user_company_contract.contract_id text
    is_new_hire: bool = False
    is_resignee: bool = False
    basic_earned: float | None = None
    basic_contractual: float | None = None
    total_allowance: float | None = None
    total_deduction: float | None = None
    back_pay: float | None = None
    gross_engine: float | None = None
    net_pay: float | None = None
    total_cpf_column: float | None = None  # employee + employer, as stored on pay_record.total_cpf
    cpf_employee: float | None = None
    cpf_employer: float | None = None
    cpf_assessed: bool = False  # payRecord.cpfCalculationResult is not null
    cpf_is_adjustment: bool = False
    eligible_ow: float | None = None
    eligible_aw: float | None = None
    community_funds: float | None = None
    sdl: float | None = None
    donation: float | None = None
    currency: str = "SGD"
    hired_date: date | None = None
    resignation_date: date | None = None
    statutory_flags: dict[str, Any] = field(default_factory=dict)  # hasAWExcess, awExcess, hasAWShortfall, awShortfall
    has_payload: bool = True  # payRecord object present in data_processed
    items: list[PayItem] = field(default_factory=list)
    created_on: datetime | None = None
    updated_on: datetime | None = None

    # ---- derived helpers ---------------------------------------------------------------
    @property
    def earnings_gross(self) -> float | None:
        """basic + allowances + back pay (deductions NOT subtracted)."""
        if self.basic_earned is None and self.total_allowance is None:
            return None
        return (self.basic_earned or 0.0) + (self.total_allowance or 0.0) + (self.back_pay or 0.0)

    def earning_items(self) -> list[PayItem]:
        return [i for i in self.items if i.is_earning]

    def deduction_items(self) -> list[PayItem]:
        return [i for i in self.items if not i.is_earning]


# ------------------------------------------------------------------------------------------
# Findings
# ------------------------------------------------------------------------------------------


@dataclass(frozen=True)
class Evidence:
    """A verifiable reference that backs a finding. ``kind`` values:
    pay_record, pay_item, salary_revision, configured_item, history, statutory_flag, model, rule, baseline.
    ``ref`` is a tenant-local identifier (uid preferred); ``detail`` carries numbers, never names.
    """

    kind: str
    ref: str | None
    detail: dict[str, Any] = field(default_factory=dict)

    def to_dict(self) -> dict[str, Any]:
        return {"kind": self.kind, "ref": self.ref, "detail": self.detail}


@dataclass
class Finding:
    anomaly_type: AnomalyType
    source: FindingSource
    severity: Severity
    user_id: int
    contract_id: int | None
    pay_record_id: int | None
    description: str
    recommended_action: str
    rule_id: str | None = None
    metric: str | None = None
    current_value: float | None = None
    expected_value: float | None = None  # only when a baseline/regression actually computed it
    expected_low: float | None = None
    expected_high: float | None = None
    expected_method: str | None = None  # e.g. "median_6_periods", "xgboost_quantile", "previous_period"
    change_pct: float | None = None
    is_explained: bool = False
    ml_percentile: float | None = None
    confidence: Confidence = Confidence.MEDIUM
    risk_score: int = 0  # set by the risk engine; see docs/03_RISK_SCORING.md
    evidence: list[Evidence] = field(default_factory=list)
    features: dict[str, float | None] = field(default_factory=dict)


@dataclass
class ObservationScore:
    """ML/baseline result for one (user, contract) observation of the analysed run."""

    user_id: int
    contract_id: int
    ml_status: str  # SCORED | INSUFFICIENT_HISTORY | MODEL_UNAVAILABLE ...
    ml_raw_score: float | None = None  # higher = more anomalous
    ml_percentile: float | None = None  # rank vs the company's training scores (0-100), NOT a probability
    baseline_score: float | None = None  # max robust |z| across key metrics
    top_contributors: list[dict[str, Any]] = field(default_factory=list)
    features: dict[str, float | None] = field(default_factory=dict)
    history_periods: int = 0


@dataclass
class AnalysisOutcome:
    """Return value of the analyzer before persistence."""

    pay_run: PayRunRef
    findings: list[Finding]
    scores: list[ObservationScore]
    total_records: int
    total_employees: int
    ml_status: str
    model_uid: str | None = None
    model_version: str | None = None
    detector: str | None = None
    warnings: list[str] = field(default_factory=list)

    @property
    def flagged_user_ids(self) -> set[int]:
        return {f.user_id for f in self.findings}

    @property
    def max_severity(self) -> Severity | None:
        return Severity.max_of([f.severity for f in self.findings])
