"""Enumerations shared across PayShield. Values are persisted, so never rename a member."""

from __future__ import annotations

from enum import Enum, IntEnum


class PayRecordStatus(IntEnum):
    """payroll.lk_pay_run_status / PayRunStatusEnum in times-payroll-api."""

    PROCESSING = 1
    COMPLETED = 2
    FAILED = 3
    LOCKED = 4
    TRIAL = 5  # derived for runs only; never stored on a record
    SKIPPED = 6


# history rows used for baselines and training
HISTORY_STATUSES: tuple[int, ...] = (PayRecordStatus.COMPLETED, PayRecordStatus.LOCKED)


class RecurringMethod(IntEnum):
    """payComponent.recurringMethodType.recurringMethodType as serialised by the pay engine."""

    DAY = 0
    MONTH = 1
    QUARTERLY = 2
    HALF_YEARLY = 3
    YEARLY = 4
    NON_RECURRING = 5


class AmountRateKind(IntEnum):
    """payComponent.amountType.payComponentAmountTypeRate."""

    AMOUNT = 0
    RATE_BY_SALARY = 1
    FIX_RATE = 2


class Severity(str, Enum):
    LOW = "LOW"
    MEDIUM = "MEDIUM"
    HIGH = "HIGH"
    CRITICAL = "CRITICAL"

    @property
    def rank(self) -> int:
        return _SEVERITY_RANK[self]

    @classmethod
    def max_of(cls, values: "list[Severity]") -> "Severity | None":
        return max(values, key=lambda s: s.rank) if values else None


_SEVERITY_RANK = {Severity.LOW: 1, Severity.MEDIUM: 2, Severity.HIGH: 3, Severity.CRITICAL: 4}


class Confidence(str, Enum):
    LOW = "LOW"
    MEDIUM = "MEDIUM"
    HIGH = "HIGH"


class FindingSource(str, Enum):
    RULE = "RULE"  # deterministic payroll validation rule
    ML = "ML"  # per-company Isolation Forest
    BASELINE = "BASELINE"  # robust statistical baseline vs the employee's own history
    STATUTORY = "STATUTORY"  # consistency of engine-computed CPF/funds/SDL (engine stays authoritative)
    DATA_QUALITY = "DATA_QUALITY"


class AnomalyType(str, Enum):
    UNUSUAL_SALARY_INCREASE = "UNUSUAL_SALARY_INCREASE"
    UNUSUAL_SALARY_DECREASE = "UNUSUAL_SALARY_DECREASE"
    LARGE_SALARY_REVISION = "LARGE_SALARY_REVISION"
    DUPLICATE_ALLOWANCE = "DUPLICATE_ALLOWANCE"
    DUPLICATE_PAY_RUN = "DUPLICATE_PAY_RUN"
    MISSING_RECURRING_ALLOWANCE = "MISSING_RECURRING_ALLOWANCE"
    UNUSUAL_ALLOWANCE = "UNUSUAL_ALLOWANCE"
    UNUSUAL_OVERTIME = "UNUSUAL_OVERTIME"
    UNEXPECTED_NET_PAY_CHANGE = "UNEXPECTED_NET_PAY_CHANGE"
    NEW_DEDUCTION = "NEW_DEDUCTION"
    UNUSUAL_DEDUCTION = "UNUSUAL_DEDUCTION"
    STATUTORY_CONTRIBUTION_CHANGE = "STATUTORY_CONTRIBUTION_CHANGE"
    STATUTORY_MISSING_CONTRIBUTION = "STATUTORY_MISSING_CONTRIBUTION"
    STATUTORY_ENGINE_FLAG = "STATUTORY_ENGINE_FLAG"
    NEGATIVE_OR_ZERO_NET_PAY = "NEGATIVE_OR_ZERO_NET_PAY"
    UNUSUAL_PAY_PATTERN = "UNUSUAL_PAY_PATTERN"  # multivariate ML finding
    DATA_QUALITY = "DATA_QUALITY"


class FeedbackOutcome(str, Enum):
    """times_intelligence.lk_feedback_outcome (id = position)."""

    CONFIRMED_ERROR = "CONFIRMED_ERROR"
    EXPECTED_CHANGE = "EXPECTED_CHANGE"
    FALSE_POSITIVE = "FALSE_POSITIVE"
    NEEDS_INVESTIGATION = "NEEDS_INVESTIGATION"

    @property
    def db_id(self) -> int:
        return {"CONFIRMED_ERROR": 1, "EXPECTED_CHANGE": 2, "FALSE_POSITIVE": 3, "NEEDS_INVESTIGATION": 4}[self.value]


class ModelStatus(str, Enum):
    TRAINED = "TRAINED"  # validated but not active (gate failed, auto-activation off, or superseded candidate)
    ACTIVE = "ACTIVE"
    REJECTED = "REJECTED"  # failed validation criteria
    RETIRED = "RETIRED"  # previously active


class Detector(str, Enum):
    ISOLATION_FOREST = "ISOLATION_FOREST"
    ROBUST_BASELINE = "ROBUST_BASELINE"


class TrainingTrigger(str, Enum):
    INITIAL = "INITIAL"
    MANUAL = "MANUAL"
    SCHEDULED = "SCHEDULED"
    RECOVERY = "RECOVERY"


class TrainingStatus(str, Enum):
    QUEUED = "QUEUED"
    RUNNING = "RUNNING"
    SUCCEEDED = "SUCCEEDED"
    REJECTED = "REJECTED"
    INSUFFICIENT_DATA = "INSUFFICIENT_DATA"
    FAILED = "FAILED"
    CANCELLED = "CANCELLED"


class AnalysisTrigger(str, Enum):
    MANUAL = "MANUAL"
    SWEEPER = "SWEEPER"
    EVENT = "EVENT"
    API = "API"


class AnalysisStatus(str, Enum):
    QUEUED = "QUEUED"
    RUNNING = "RUNNING"
    COMPLETED = "COMPLETED"
    COMPLETED_WITH_WARNINGS = "COMPLETED_WITH_WARNINGS"
    FAILED = "FAILED"
    SUPERSEDED = "SUPERSEDED"


class MlStatus(str, Enum):
    SCORED = "SCORED"
    NO_ACTIVE_MODEL = "NO_ACTIVE_MODEL"
    MODEL_UNAVAILABLE = "MODEL_UNAVAILABLE"
    DISABLED = "DISABLED"
    BASELINE_PREFERRED = "BASELINE_PREFERRED"  # active model's evaluation chose the robust baseline


class PrincipalKind(str, Enum):
    USER = "USER"  # Keycloak user token
    SERVICE = "SERVICE"  # Entra client-credentials (or dev shared secret)
