"""Pay-run analysis, training and feedback services (persistence around the pure analyzer/trainer).
Failures are recorded on the analysis/job row and re-raised — never silently ignored."""

from __future__ import annotations

import logging
import threading
from datetime import date, datetime, timezone

from app.core.config import Settings
from app.core.errors import Conflict, Forbidden, NotFound, ValidationFailed
from app.core.tenant_context import TenantContext
from app.db.interfaces import AnalysisRecord, AnomalyRecord, PayrollReadRepository, PayShieldRepository, TrainingAlreadyInProgress
from app.domain.enums import AnalysisStatus, FeedbackOutcome, MlStatus, TrainingStatus
from app.services import learning
from app.domain.models import CompanyRef
from app.ml.model_registry import ModelRegistry
from app.ml.predictor import BundleScorer
from app.ml.scoring import BaselineOnlyScorer
from app.ml.trainer import train_company_model
from app.rules.engine import Thresholds
from app.services.payroll_analyzer import analyze

log = logging.getLogger(__name__)


def add_months(d: date, n: int) -> date:
    y, m = divmod(d.month - 1 + n, 12)
    return date(d.year + y, m + 1, 1)


LOCAL_DEV_REVIEWER = "00000000-0000-4000-8000-00000000d0e0"  # fixed reviewer id for the local demo UI


class PayShieldService:
    def __init__(self, settings: Settings, payroll: PayrollReadRepository, repo: PayShieldRepository, registry: ModelRegistry):
        self.s, self.payroll, self.repo, self.registry = settings, payroll, repo, registry

    def _learner(self):
        """What the company model learned from review decisions (needs the PostgreSQL repository)."""
        conn = getattr(self.repo, "conn", None)
        return learning.FeedbackLearning(conn, self.repo.db) if conn is not None else None

    def _company(self, ctx: TenantContext) -> CompanyRef:
        return CompanyRef(ctx.company_id, ctx.company_uid, ctx.tenant_uid)

    # ------------------------------------------------------------------ analysis
    def analyze_pay_run(self, ctx: TenantContext, pay_run_uid: str, trigger: str = "API", supersede: bool = False
                        ) -> AnalysisRecord:
        run = self.payroll.get_pay_run(ctx.company_id, pay_run_uid)
        if run is None:
            raise NotFound("PAY_RUN_NOT_FOUND", "Pay run not found.")
        setting = self.repo.get_company_setting(ctx.company_id)
        if not setting.is_enabled:
            raise Conflict("PAYSHIELD_DISABLED", "PayShield is disabled for this company.")
        overtime = frozenset(setting.overtime_pay_codes)
        master = self.payroll.get_pay_code_master(ctx.company_id)
        records = self.payroll.list_run_records(ctx.company_id, run.id, master, overtime)
        if not records:
            raise Conflict("RUN_EMPTY", "The pay run has no pay records yet.")
        if any(r.status_id == 1 for r in records):
            raise Conflict("RUN_NOT_SETTLED", "The pay run is still processing.")
        fingerprint = self.payroll.run_fingerprint(ctx.company_id, run.id)
        analysis, created = self.repo.create_analysis(ctx.tenant_uid, ctx.company_id, run, trigger, fingerprint, ctx.actor, supersede)
        if not created and analysis.status != AnalysisStatus.QUEUED.value:
            return analysis  # same figures already analysed (idempotent)
        self.repo.mark_analysis_running(ctx.company_id, analysis.id)
        try:
            user_ids = sorted({r.user_id for r in records})
            history = self.payroll.list_history_records(ctx.company_id, add_months(run.period, -(self.s.ml.history_window_periods + 1)),
                                                        run.period, user_ids, master, overtime, run.id)
            same = self.payroll.list_history_records(ctx.company_id, run.period, add_months(run.period, 1), user_ids, master,
                                                     overtime, run.id)
            revisions = self.payroll.list_salary_revisions(ctx.company_id, user_ids, add_months(run.period, -14))
            configured = self.payroll.list_configured_items(ctx.company_id, user_ids, run.period, add_months(run.period, 1))
            thresholds, warnings = Thresholds.from_overrides(setting.thresholds)
            scorer, model_id = self._scorer(ctx, warnings)
            outcome = analyze(pay_run=run, run_records=records, history_records=history, same_period_records=same,
                              revisions=revisions, configured=configured, overtime_codes=overtime, thresholds=thresholds,
                              scorer=scorer, ml=self.s.ml)
            warnings += outcome.warnings
            if not overtime:
                warnings.append("overtime detection is off: no overtime pay codes configured for this company")
            anomalies = [AnomalyRecord(0, "", analysis.id, ctx.company_id, run.id, f.pay_record_id, f.user_id, f.contract_id,
                                       f.anomaly_type.value, f.source.value, f.rule_id, f.severity.value, f.risk_score,
                                       f.ml_percentile, f.confidence.value, f.metric, _r(f.current_value), _r(f.expected_value),
                                       _r(f.expected_low), _r(f.expected_high), f.expected_method, f.change_pct,
                                       f.is_explained, f.description, f.recommended_action,
                                       [e.to_dict() for e in f.evidence], f.features) for f in outcome.findings]
            # apply what reviewers taught the model: accepted patterns are not raised again, often-accepted types are lowered
            learner = self._learner()
            learned, lowered = [], []
            if learner is not None:
                anomalies, learned, lowered = learner.apply(ctx.company_id, anomalies)
            analysis.status = (AnalysisStatus.COMPLETED_WITH_WARNINGS if outcome.warnings or scorer.ml_status in
                               (MlStatus.MODEL_UNAVAILABLE.value,) else AnalysisStatus.COMPLETED).value
            analysis.model_registry_id, analysis.model_version = model_id, scorer.model_version
            analysis.detector, analysis.ml_status = scorer.detector, scorer.ml_status
            analysis.total_records, analysis.total_employees = outcome.total_records, outcome.total_employees
            analysis.flagged_employees = len({a.user_id for a in anomalies})
            analysis.max_severity = learning.max_severity(anomalies)
            analysis.summary = {"warnings": warnings, "by_type": _count(a.anomaly_type for a in anomalies),
                                "by_severity": _count(a.severity for a in anomalies), "learned": learned, "lowered": lowered}
            self.repo.complete_analysis(ctx.company_id, analysis.id, analysis, anomalies)
            log.info("analysis completed", extra={"analysis_uid": analysis.uid, "count": len(anomalies), "status": analysis.status})
        except Exception as exc:
            self.repo.fail_analysis(ctx.company_id, analysis.id, "ANALYSIS_FAILED", type(exc).__name__)
            log.exception("analysis failed", extra={"analysis_uid": analysis.uid, "error_code": "ANALYSIS_FAILED"})
            raise
        return self.repo.get_analysis(ctx.company_id, analysis.uid)

    def _scorer(self, ctx: TenantContext, warnings: list[str]):
        try:
            active = self.registry.load_active(ctx.tenant_uid, self._company(ctx))
        except Exception:  # noqa: BLE001 - model problems degrade to the baseline, recorded as a warning
            log.exception("model load failed", extra={"error_code": "MODEL_UNAVAILABLE"})
            warnings.append("active model could not be loaded; robust baseline used")
            return BaselineOnlyScorer(MlStatus.MODEL_UNAVAILABLE.value, self.s.ml.min_history_periods_for_scoring), None
        if active is None:
            return BaselineOnlyScorer(MlStatus.NO_ACTIVE_MODEL.value, self.s.ml.min_history_periods_for_scoring), None
        record, bundle = active
        return BundleScorer(bundle, record.uid, self.s.ml.min_history_periods_for_scoring), record.id

    def get_analysis(self, ctx: TenantContext, analysis_uid: str) -> tuple[AnalysisRecord, list[AnomalyRecord]]:
        a = self.repo.get_analysis(ctx.company_id, analysis_uid)
        if a is None:
            raise NotFound("ANALYSIS_NOT_FOUND", "Analysis not found.")
        users = None if ctx.access.all_users else sorted(ctx.access.user_ids)
        return a, self.repo.list_anomalies(ctx.company_id, a.id, users)

    def latest_for_run(self, ctx: TenantContext, pay_run_uid: str):
        a = self.repo.get_latest_analysis_for_run(ctx.company_id, pay_run_uid)
        if a is None:
            raise NotFound("ANALYSIS_NOT_FOUND", "No analysis exists for this pay run.")
        return self.get_analysis(ctx, a.uid)

    # ------------------------------------------------------------------ training
    def request_training(self, ctx: TenantContext, trigger: str = "MANUAL", run_inline: bool = True):
        try:
            job = self.repo.create_training_job(ctx.tenant_uid, ctx.company_id, trigger, ctx.actor)
        except TrainingAlreadyInProgress as e:
            raise Conflict("TRAINING_IN_PROGRESS", f"Training job {e.job_uid} is already in progress.") from None
        if run_inline:
            threading.Thread(target=self._safe_execute, args=(ctx, job.uid), daemon=True).start()
        return job

    def _safe_execute(self, ctx, job_uid):
        try:
            self.execute_training(ctx, job_uid)
        except Exception:  # noqa: BLE001 - the failure is recorded on the job row
            pass

    def execute_training(self, ctx: TenantContext, job_uid: str):
        job = self.repo.claim_training_job(ctx.company_id, job_uid)
        if job is None:
            return self.repo.get_training_job(ctx.company_id, job_uid)
        started = datetime.now(timezone.utc)
        try:
            setting = self.repo.get_company_setting(ctx.company_id)
            overtime = frozenset(setting.overtime_pay_codes)
            master = self.payroll.get_pay_code_master(ctx.company_id)
            # this company only: company_id is part of every history query
            history = self.payroll.list_history_records(ctx.company_id, date(2000, 1, 1), date(2999, 1, 1), None, master, overtime)
            # learn "normal" only from locked (paid and closed) pay runs: an open run may still hold errors nobody has
            # reviewed, and those would be learned as normal and counted as false alarms by the quality gate.
            # Until enough months are locked, fall back to every completed run.
            locked = [r for r in history if r.status_id == 4]
            history_filter = "LOCKED_ONLY" if len({r.period for r in locked}) >= self.s.ml.min_training_periods else "ALL_COMPLETED"
            if history_filter == "LOCKED_ONLY":
                history = locked
            active = self.registry.load_active(ctx.tenant_uid, self._company(ctx))
            result = train_company_model(company=self._company(ctx), history_records=history, ml=self.s.ml,
                                         overtime_codes=overtime, active_pipeline=active[1].pipeline if active else None,
                                         auto_activate=setting.auto_activate_models)
            result.report = {**(result.report or {}), "history_filter": history_filter}
            model_id = None
            if result.pipeline is not None:
                model_id = self.registry.register(ctx.tenant_uid, self._company(ctx), result, job.id, ctx.actor, started).id
            metrics = {"report": result.report, "gate": result.gate, "record_count": result.record_count,
                       "duration_ms": result.duration_ms}
            self.repo.complete_training_job(job.id, result.status, metrics, model_id)
            log.info("training finished", extra={"job_uid": job_uid, "status": result.status, "duration_ms": result.duration_ms})
        except Exception as exc:
            self.repo.complete_training_job(job.id, TrainingStatus.FAILED.value, {}, None, "TRAINING_FAILED", type(exc).__name__)
            log.exception("training failed", extra={"job_uid": job_uid, "error_code": "TRAINING_FAILED"})
            raise
        return self.repo.get_training_job(ctx.company_id, job_uid)

    def activate(self, ctx: TenantContext, model_uid: str):
        try:
            return self.registry.activate(self._company(ctx), model_uid, ctx.actor, "manual activation / rollback")
        except LookupError:
            raise NotFound("MODEL_NOT_FOUND", "Model not found.") from None
        except ValueError as e:
            raise Conflict("MODEL_NOT_ACTIVATABLE", str(e)) from None

    # ------------------------------------------------------------------ feedback
    def feedback(self, ctx: TenantContext, anomaly_uid: str, outcome: str, comment: str | None):
        # local dev uses the shared-secret service login, so allow the demo UI to record decisions there only
        if ctx.is_service and self.s.environment != "local":
            raise Forbidden("REVIEWER_REQUIRED", "Feedback must be given by a payroll user.")
        try:
            FeedbackOutcome(outcome)
        except ValueError:
            raise ValidationFailed("OUTCOME_INVALID", "Unknown feedback outcome.") from None
        anomaly = self.repo.get_anomaly(ctx.company_id, anomaly_uid)
        if anomaly is None or not ctx.access.allows(anomaly.user_id):
            raise NotFound("ANOMALY_NOT_FOUND", "Anomaly not found.")
        reviewer = LOCAL_DEV_REVIEWER if ctx.is_service else ctx.principal.subject  # service login only reaches here in local
        fb = self.repo.add_feedback(ctx.company_id, anomaly.id, outcome, comment, reviewer)
        learner = self._learner()
        if learner is not None:  # the model learns from the decision straight away (next analysis uses it)
            learner.learn(ctx.company_id, anomaly, outcome, ctx.actor)
        return fb


def _r(v):
    return None if v is None else round(float(v), 2)


def _count(values):
    out: dict[str, int] = {}
    for v in values:
        out[v] = out.get(v, 0) + 1
    return out
