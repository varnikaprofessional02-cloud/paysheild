"""Data-access contracts. Implementations: ``app.db.payroll_repository`` / ``app.db.payshield_repository``
(PostgreSQL via psycopg 3) and in-memory fakes in ``tests/fakes.py``.

Every method operates on ONE tenant database (the repository instance is bound to it) and every
company-scoped method takes ``company_id`` explicitly; implementations must include it in the WHERE
clause even when another argument (e.g. a pay run id) would already identify the row. That is the
defence against cross-company access by guessed ids.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from datetime import date, datetime
from typing import Any, Protocol

from app.core.tenant_context import TenantInfo
from app.domain.models import (
    CompanyRef,
    ConfiguredPayItem,
    PayCodeMaster,
    PayRecordSnapshot,
    PayRunRef,
    SalaryRevision,
)

# ------------------------------------------------------------------------------------------
# Tenant resolution (tenant-store DB)
# ------------------------------------------------------------------------------------------


class TenantResolver(Protocol):
    def get_by_uid(self, tenant_uid: str) -> TenantInfo | None: ...

    def list_tenants(self) -> list[TenantInfo]: ...


# ------------------------------------------------------------------------------------------
# Payroll read model (existing tables, read-only)
# ------------------------------------------------------------------------------------------


@dataclass(frozen=True)
class SchemaCapabilities:
    """Columns that exist in newer code but not in every tenant DB (the 2026-09-28 dump lacks them)."""

    has_pay_run_is_trial: bool
    has_payshield_schema: bool
    payshield_schema_version: int | None


@dataclass(frozen=True)
class RunState:
    """Sweeper view of a pay run (aggregated over its pay_record rows)."""

    pay_run_id: int
    pay_run_uid: str
    company_id: int
    period: date
    cycle_code: str
    is_trial: bool
    record_count: int
    processing_count: int  # status_id = 1
    fingerprint: str  # changes whenever figures change; NOT on 2<->4 lock transitions
    last_change: datetime | None


class PayrollReadRepository(Protocol):
    def capabilities(self) -> SchemaCapabilities: ...

    def get_company_by_uid(self, company_uid: str) -> CompanyRef | None: ...

    def list_companies(self) -> list[CompanyRef]: ...

    def get_pay_run(self, company_id: int, pay_run_uid: str) -> PayRunRef | None: ...

    def list_run_records(
        self, company_id: int, pay_run_id: int, master: dict[str, PayCodeMaster] | None = None,
        overtime_codes: frozenset[str] = frozenset(),
    ) -> list[PayRecordSnapshot]:
        """All records of the run, any status (failed/skipped rows feed data-quality checks)."""
        ...

    def list_history_records(
        self,
        company_id: int,
        period_from: date,
        period_to_exclusive: date,
        user_ids: list[int] | None = None,
        master: dict[str, PayCodeMaster] | None = None,
        overtime_codes: frozenset[str] = frozenset(),
        exclude_pay_run_id: int | None = None,
    ) -> list[PayRecordSnapshot]:
        """Completed/Locked (2,4), non-trial records with period in [from, to_exclusive)."""
        ...

    def list_salary_revisions(self, company_id: int, user_ids: list[int], since: date) -> list[SalaryRevision]: ...

    def list_configured_items(
        self, company_id: int, user_ids: list[int], period_start: date, period_end: date
    ) -> list[ConfiguredPayItem]: ...

    def get_pay_code_master(self, company_id: int) -> dict[str, PayCodeMaster]: ...

    def list_run_states(self, since_period: date, max_runs: int) -> list[RunState]: ...

    def get_function_permissions(self, function_code: str, principals: list[str], company_uid: str) -> set[str]:
        """Lower-cased permissions from security.get_permissions_for_principle_on_resource."""
        ...

    def user_has_company_access(self, user_uid: str, company_id: int) -> bool: ...

    def get_user_id_by_uid(self, user_uid: str) -> int | None: ...

    def get_user_refs(self, company_id: int, user_ids: list[int]) -> dict[int, dict[str, Any]]:
        """user_id -> {"user_uid", "employee_no"}; no names/emails."""
        ...


# ------------------------------------------------------------------------------------------
# PayShield persistence (times_intelligence.* tables)
# ------------------------------------------------------------------------------------------


@dataclass
class CompanySettingRecord:
    company_id: int
    is_enabled: bool = True
    auto_analyze: bool = True
    auto_activate_models: bool = True
    overtime_pay_codes: list[str] = field(default_factory=list)
    thresholds: dict[str, Any] = field(default_factory=dict)


@dataclass
class TrainingJobRecord:
    id: int
    uid: str
    tenant_uid: str
    company_id: int
    trigger: str
    status: str
    attempt: int
    requested_by: str
    requested_on: datetime
    started_on: datetime | None = None
    heartbeat_on: datetime | None = None
    completed_on: datetime | None = None
    duration_ms: int | None = None
    model_registry_id: int | None = None
    metrics: dict[str, Any] = field(default_factory=dict)
    error_code: str | None = None
    error_message: str | None = None


@dataclass
class ModelRecord:
    id: int
    uid: str
    tenant_uid: str
    company_id: int
    company_uid: str
    model_version: str
    model_type: str
    detector: str
    feature_schema_version: str
    training_job_id: int | None
    training_started_at: datetime
    training_completed_at: datetime
    training_record_count: int
    training_period_start: date
    training_period_end: date
    evaluation_metrics: dict[str, Any]
    model_storage_location: str
    artifact_sha256: str
    artifact_size_bytes: int
    model_status: str
    status_reason: str | None = None
    activated_on: datetime | None = None
    activated_by: str | None = None
    retired_on: datetime | None = None
    created_on: datetime | None = None


@dataclass
class AnalysisRecord:
    id: int
    uid: str
    tenant_uid: str
    company_id: int
    pay_run_id: int
    pay_run_uid: str
    period: date
    cycle_code: str | None
    is_trial_run: bool
    trigger: str
    status: str
    run_fingerprint: str
    model_registry_id: int | None = None
    model_version: str | None = None
    detector: str | None = None
    ml_status: str | None = None
    total_records: int = 0
    total_employees: int = 0
    flagged_employees: int = 0
    anomaly_count: int = 0
    max_severity: str | None = None
    summary: dict[str, Any] = field(default_factory=dict)
    error_code: str | None = None
    error_message: str | None = None
    requested_by: str = "System"
    requested_on: datetime | None = None
    started_on: datetime | None = None
    completed_on: datetime | None = None
    duration_ms: int | None = None


@dataclass
class AnomalyRecord:
    id: int
    uid: str
    analysis_id: int
    company_id: int
    pay_run_id: int
    pay_record_id: int | None
    user_id: int
    contract_id: int | None
    anomaly_type: str
    source: str
    rule_id: str | None
    severity: str
    risk_score: int
    ml_percentile: float | None
    confidence: str
    metric: str | None
    current_value: float | None
    expected_value: float | None
    expected_low: float | None
    expected_high: float | None
    expected_method: str | None
    change_pct: float | None
    is_explained: bool
    description: str
    recommended_action: str | None
    evidence: list[dict[str, Any]]
    features: dict[str, Any]
    created_on: datetime | None = None
    latest_feedback: str | None = None  # FeedbackOutcome value of the latest feedback row


@dataclass
class FeedbackRecord:
    id: int
    uid: str
    anomaly_id: int
    company_id: int
    outcome: str
    comment: str | None
    reviewer_uid: str
    created_on: datetime


class PayShieldRepository(Protocol):
    # settings
    def get_company_setting(self, company_id: int) -> CompanySettingRecord: ...  # defaults when no row

    def upsert_company_setting(self, setting: CompanySettingRecord, actor: str) -> None: ...

    # training jobs
    def create_training_job(self, tenant_uid: str, company_id: int, trigger: str, requested_by: str) -> TrainingJobRecord:
        """Raises ``TrainingAlreadyInProgress`` when a QUEUED/RUNNING job exists (unique partial index)."""
        ...

    def get_training_job(self, company_id: int, job_uid: str) -> TrainingJobRecord | None: ...

    def list_training_jobs(self, company_id: int, limit: int = 20) -> list[TrainingJobRecord]: ...

    def claim_training_job(self, company_id: int, job_uid: str) -> TrainingJobRecord | None:
        """QUEUED -> RUNNING atomically (returns None if not claimable)."""
        ...

    def heartbeat_training_job(self, job_id: int) -> None: ...

    def complete_training_job(
        self, job_id: int, status: str, metrics: dict[str, Any], model_registry_id: int | None,
        error_code: str | None = None, error_message: str | None = None,
    ) -> None: ...

    def recover_stale_training_jobs(self, stale_after_seconds: int) -> list[TrainingJobRecord]:
        """RUNNING jobs whose heartbeat is older than the threshold -> FAILED (error_code STALE)."""
        ...

    # model registry
    def next_model_sequence(self, company_id: int) -> int: ...

    def insert_model(self, record: ModelRecord) -> ModelRecord: ...  # id/uid assigned by DB when 0/""

    def get_model(self, company_id: int, model_uid: str) -> ModelRecord | None: ...

    def get_active_model(self, company_id: int) -> ModelRecord | None: ...

    def list_models(self, company_id: int, limit: int = 50) -> list[ModelRecord]: ...

    def activate_model(self, company_id: int, model_uid: str, actor: str, reason: str) -> ModelRecord:
        """Retire current ACTIVE and activate target in one transaction."""
        ...

    def set_model_status(self, company_id: int, model_uid: str, status: str, reason: str | None) -> None: ...

    # analyses
    def create_analysis(
        self, tenant_uid: str, company_id: int, pay_run: PayRunRef, trigger: str, fingerprint: str, requested_by: str,
        supersede_existing: bool,
    ) -> tuple[AnalysisRecord, bool]:
        """Returns (record, created). When a live analysis with the same fingerprint exists and
        ``supersede_existing`` is False, returns (existing, False)."""
        ...

    def mark_analysis_running(self, company_id: int, analysis_id: int) -> None: ...

    def complete_analysis(self, company_id: int, analysis_id: int, record: AnalysisRecord, anomalies: list[AnomalyRecord]) -> None:
        """Writes status/counters/summary and inserts anomalies in one transaction."""
        ...

    def fail_analysis(self, company_id: int, analysis_id: int, error_code: str, error_message: str) -> None: ...

    def get_analysis(self, company_id: int, analysis_uid: str) -> AnalysisRecord | None: ...

    def get_latest_analysis_for_run(self, company_id: int, pay_run_uid: str) -> AnalysisRecord | None: ...

    def list_anomalies(
        self, company_id: int, analysis_id: int, user_ids: list[int] | None = None,
        severity: str | None = None, anomaly_type: str | None = None, limit: int = 500,
    ) -> list[AnomalyRecord]:
        """``user_ids`` = None means unrestricted; [] means nothing visible."""
        ...

    def get_anomaly(self, company_id: int, anomaly_uid: str) -> AnomalyRecord | None: ...

    # feedback
    def add_feedback(self, company_id: int, anomaly_id: int, outcome: str, comment: str | None, reviewer_uid: str) -> FeedbackRecord: ...

    def list_labelled_anomalies(self, company_id: int, since: datetime | None = None) -> list[AnomalyRecord]:
        """Anomalies whose latest feedback is CONFIRMED_ERROR / EXPECTED_CHANGE / FALSE_POSITIVE."""
        ...

    # sweeper
    def get_watermarks(self, pay_run_ids: list[int]) -> dict[int, str]: ...

    def upsert_watermark(self, pay_run_id: int, company_id: int, fingerprint: str, enqueued: bool) -> None: ...

    # assistant audit
    def add_assistant_audit(
        self, company_id: int, analysis_id: int | None, user_uid: str, question_sha256: str, question_length: int,
        tool_calls: list[dict[str, Any]], llm_model: str | None, status: str, latency_ms: int,
    ) -> None: ...


class TrainingAlreadyInProgress(Exception):
    def __init__(self, company_id: int, job_uid: str | None = None):
        super().__init__(f"training already in progress for company {company_id}")
        self.company_id = company_id
        self.job_uid = job_uid


# ------------------------------------------------------------------------------------------
# Model artifacts
# ------------------------------------------------------------------------------------------


class ArtifactStore(Protocol):
    """Tenant/company-scoped artifact storage. Paths are built by the store from ids, never from input."""

    def save(self, tenant_uid: str, company_uid: str, model_version: str, payload: bytes) -> tuple[str, str, int]:
        """Returns (storage_location, sha256_hex, size_bytes)."""
        ...

    def load(self, tenant_uid: str, company_uid: str, storage_location: str, expected_sha256: str) -> bytes:
        """Raises ``ArtifactIntegrityError`` when the location is outside the tenant/company prefix
        or the content hash does not match."""
        ...


class ArtifactIntegrityError(Exception):
    pass


# ------------------------------------------------------------------------------------------
# Messaging
# ------------------------------------------------------------------------------------------


class MessagePublisher(Protocol):
    def publish_analysis_request(
        self, tenant_uid: str, company_uid: str, pay_run_uid: str, fingerprint: str, trigger: str, actor: str,
    ) -> None: ...

    def publish_training_request(self, tenant_uid: str, company_uid: str, job_uid: str, actor: str) -> None: ...
