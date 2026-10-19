"""FastAPI application. Tenant and company are resolved server-side from verified credentials
(app.core.security / app.security.permissions); request bodies never carry tenant identity."""

from __future__ import annotations

import logging
from dataclasses import asdict
from typing import Any, Literal

from fastapi import Depends, FastAPI, Request
from fastapi.responses import JSONResponse
from pydantic import BaseModel, ConfigDict, Field
from pydantic.alias_generators import to_camel

from app.core.config import Settings, get_settings
from app.core.errors import Forbidden, NotFound, PayShieldError, Unauthorized, problem_response
from app.core.logging import configure_logging, new_correlation_id, set_correlation_id
from app.core.security import Authenticator, JwksCache, VerifiedService
from app.core.tenant_context import TenantContext, TenantInfo
from app.db.connection import ConnectionManager
from app.db.payroll_repository import PostgresPayrollReadRepository
from app.db.payshield_repository import PostgresPayShieldRepository
from app.db.tenant_resolver import PostgresTenantResolver
from app.llm.client import build_llm_client
from app.ml.model_bundle import build_artifact_store
from app.ml.model_registry import BundleCache, ModelRegistry
from app.security.permissions import build_service_context, build_user_context, require
from app.services.analysis_service import PayShieldService
from app.services.assistant_service import AssistantService

log = logging.getLogger(__name__)
RISK_SEMANTICS = ("riskScore 0-100 is a priority rank (LOW 25, MEDIUM 50, HIGH 75, CRITICAL 90 base, +5 for strong history / "
                  "model agreement). It is NOT a probability of error. mlPercentile = share of this company's historical pay "
                  "observations that were less unusual.")


class Api(BaseModel):
    model_config = ConfigDict(alias_generator=to_camel, populate_by_name=True)


class AnalyzeRequest(Api):
    pay_run_id: str
    supersede: bool = False


class TrainRequest(Api):
    trigger: Literal["MANUAL", "INITIAL"] = "MANUAL"


class FeedbackRequest(Api):
    anomaly_id: str
    outcome: Literal["CONFIRMED_ERROR", "EXPECTED_CHANGE", "FALSE_POSITIVE", "NEEDS_INVESTIGATION"]
    comment: str | None = Field(default=None, max_length=2000)


class AskRequest(Api):
    question: str = Field(max_length=2000)
    analysis_id: str


class Runtime:
    def __init__(self, settings: Settings):
        self.s = settings
        self.conn = ConnectionManager(settings.db)
        self.tenants = PostgresTenantResolver(self.conn, settings.db.tenant_cache_ttl_seconds)
        self.auth = Authenticator(settings, self.tenants, JwksCache(settings.keycloak.jwks_cache_ttl_seconds))
        self.store = build_artifact_store(settings.storage)
        self.cache = BundleCache(settings.storage.model_cache_max_entries)
        self.llm = build_llm_client(settings.llm)

    def payroll(self, t: TenantInfo):
        return PostgresPayrollReadRepository(self.conn, t.db_name)

    def service(self, ctx: TenantContext) -> PayShieldService:
        repo = PostgresPayShieldRepository(self.conn, ctx.tenant.db_name)
        return PayShieldService(self.s, self.payroll(ctx.tenant), repo, ModelRegistry(repo, self.store, self.cache))

    def assistant(self, ctx: TenantContext) -> AssistantService:
        return AssistantService(self.llm, PostgresPayShieldRepository(self.conn, ctx.tenant.db_name),
                                self.s.llm.max_tool_rounds, self.s.llm.max_output_tokens)


def _anomaly(a, refs) -> dict[str, Any]:
    ref = refs.get(a.user_id, {})
    return {"anomalyId": a.uid, "employeeUid": ref.get("user_uid"), "employeeNo": ref.get("employee_no"),
            "contractId": a.contract_id, "anomalyType": a.anomaly_type, "source": a.source, "ruleId": a.rule_id,
            "severity": a.severity, "riskScore": a.risk_score, "mlPercentile": a.ml_percentile, "confidence": a.confidence,
            "metric": a.metric, "currentValue": a.current_value, "expectedValue": a.expected_value,
            "expectedLow": a.expected_low, "expectedHigh": a.expected_high, "expectedMethod": a.expected_method,
            "changePct": a.change_pct, "isExplained": a.is_explained, "description": a.description,
            "recommendedAction": a.recommended_action, "evidence": a.evidence, "latestFeedback": a.latest_feedback}


def _analysis(rt: Runtime, ctx: TenantContext, a, anomalies) -> dict[str, Any]:
    refs = rt.payroll(ctx.tenant).get_user_refs(ctx.company_id, sorted({x.user_id for x in anomalies})) if anomalies else {}
    return {"analysisId": a.uid, "payRunId": a.pay_run_uid, "payrollPeriod": f"{a.period:%Y-%m}", "cycleCode": a.cycle_code,
            "isTrialRun": a.is_trial_run, "status": a.status, "modelVersion": a.model_version, "detector": a.detector,
            "mlStatus": a.ml_status, "totalEmployees": a.total_employees, "flaggedEmployees": len({x.user_id for x in anomalies}),
            "anomalyCount": len(anomalies), "maxSeverity": a.max_severity,
            "generatedAt": a.completed_on.isoformat() if a.completed_on else None,
            "warnings": (a.summary or {}).get("warnings", []), "riskScoreSemantics": RISK_SEMANTICS,
            "errorCode": a.error_code, "anomalies": [_anomaly(x, refs) for x in anomalies]}


def create_app(settings: Settings | None = None, runtime: Runtime | None = None) -> FastAPI:
    settings = settings or get_settings()
    configure_logging(settings)
    app = FastAPI(title="PayShield AI", version="1.0.0")
    rt = runtime or Runtime(settings)
    app.state.runtime = rt

    @app.middleware("http")
    async def correlation(request: Request, call_next):
        cid = request.headers.get("x-correlation-id") or new_correlation_id()
        set_correlation_id(cid)
        response = await call_next(request)
        response.headers["x-correlation-id"] = cid
        return response

    @app.exception_handler(PayShieldError)
    async def _err(request: Request, exc: PayShieldError):
        return problem_response(exc, request.headers.get("x-correlation-id"))

    @app.exception_handler(Exception)
    async def _unexpected(request: Request, exc: Exception):
        log.exception("unhandled error", extra={"path": request.url.path})
        return problem_response(PayShieldError("INTERNAL_ERROR", "error"), request.headers.get("x-correlation-id"))

    def context(request: Request) -> TenantContext:
        h = request.headers
        who = rt.auth.authenticate(dict(h))
        cid = h.get("x-correlation-id") or ""
        if isinstance(who, VerifiedService):
            return build_service_context(rt.tenants, rt.payroll, who, h.get("x-tenant-uid"), h.get("x-company-uid"), cid)
        return build_user_context(settings, rt.payroll(who.tenant), who, h.get("x-company-uid"), cid)

    def service_only(request: Request) -> VerifiedService:
        who = rt.auth.authenticate(dict(request.headers))
        if not isinstance(who, VerifiedService):
            raise Unauthorized("SERVICE_ONLY", "Service credentials required.")
        return who

    p = "/api/v1"

    def subscribed(ctx: TenantContext = Depends(context)) -> TenantContext:
        sub = rt.service(ctx).repo.get_subscription(ctx.company_id)
        if not sub or sub["status"] != "ACTIVE":
            raise Forbidden("NOT_SUBSCRIBED", "Times Intelligence is not subscribed for this company.")
        return ctx

    @app.get(p + "/intelligence/subscription")
    def subscription(ctx: TenantContext = Depends(context)):
        sub = rt.service(ctx).repo.get_subscription(ctx.company_id)
        return {"subscribed": bool(sub and sub["status"] == "ACTIVE"), "modules": (sub or {}).get("modules", []),
                "subscribedOn": sub["subscribed_on"].isoformat() if sub else None}

    @app.post(p + "/intelligence/unsubscribe")
    def unsubscribe(ctx: TenantContext = Depends(context)):
        require(ctx, settings.manage_permission)
        rt.service(ctx).repo.unsubscribe(ctx.company_id, ctx.actor)
        return {"subscribed": False, "modules": [], "subscribedOn": None}

    @app.post(p + "/intelligence/subscribe")
    def subscribe(ctx: TenantContext = Depends(context)):
        require(ctx, settings.manage_permission)
        sub = rt.service(ctx).repo.subscribe(ctx.company_id, ctx.actor)
        return {"subscribed": True, "modules": sub["modules"], "subscribedOn": sub["subscribed_on"].isoformat()}

    @app.get(p + "/health/live")
    def live():
        return {"status": "ok"}

    @app.get(p + "/health/ready")
    def ready():
        with rt.conn.tenant_store_connection() as c:
            c.execute("SELECT 1")
        return {"status": "ready"}

    @app.post(p + "/models/train", status_code=202)
    def train(body: TrainRequest, ctx: TenantContext = Depends(subscribed)):
        require(ctx, settings.manage_permission)
        job = rt.service(ctx).request_training(ctx, body.trigger, run_inline=settings.messaging.execution_mode == "inline")
        return {"jobId": job.uid, "status": job.status}

    @app.get(p + "/models/training-jobs/{job_id}")
    def job(job_id: str, ctx: TenantContext = Depends(subscribed)):
        j = rt.service(ctx).repo.get_training_job(ctx.company_id, job_id)
        if j is None:
            raise NotFound("JOB_NOT_FOUND", "Training job not found.")
        return _job(j)

    @app.get(p + "/models/status")
    def status(ctx: TenantContext = Depends(subscribed)):
        svc = rt.service(ctx)
        active = svc.repo.get_active_model(ctx.company_id)
        jobs = svc.repo.list_training_jobs(ctx.company_id, 1)
        return {"activeModel": _model(active) if active else None, "latestJob": _job(jobs[0]) if jobs else None}

    @app.get(p + "/models/versions")
    def versions(ctx: TenantContext = Depends(subscribed)):
        return {"models": [_model(m) for m in rt.service(ctx).repo.list_models(ctx.company_id)]}

    @app.post(p + "/models/{model_id}/activate")
    def activate(model_id: str, ctx: TenantContext = Depends(subscribed)):
        require(ctx, settings.manage_permission)
        return _model(rt.service(ctx).activate(ctx, model_id))

    @app.post(p + "/payroll/analyze")
    def analyze_run(body: AnalyzeRequest, ctx: TenantContext = Depends(subscribed)):
        svc = rt.service(ctx)
        a = svc.analyze_pay_run(ctx, body.pay_run_id, "API", body.supersede)
        return _analysis(rt, ctx, *svc.get_analysis(ctx, a.uid))

    @app.get(p + "/payroll/analysis/{analysis_id}")
    def get_analysis(analysis_id: str, ctx: TenantContext = Depends(subscribed)):
        return _analysis(rt, ctx, *rt.service(ctx).get_analysis(ctx, analysis_id))

    @app.get(p + "/payroll/runs/{pay_run_id}/analysis")
    def run_analysis(pay_run_id: str, ctx: TenantContext = Depends(subscribed)):
        return _analysis(rt, ctx, *rt.service(ctx).latest_for_run(ctx, pay_run_id))

    @app.post(p + "/payroll/feedback", status_code=201)
    def feedback(body: FeedbackRequest, ctx: TenantContext = Depends(subscribed)):
        require(ctx, settings.manage_permission)
        fb = rt.service(ctx).feedback(ctx, body.anomaly_id, body.outcome, body.comment)
        return {"feedbackId": fb.uid, "outcome": body.outcome}

    @app.post(p + "/assistant/ask")
    def ask(body: AskRequest, ctx: TenantContext = Depends(subscribed)):
        ans = rt.assistant(ctx).ask(ctx, body.question, body.analysis_id)
        return {"answer": ans.answer, "status": ans.status, "citations": ans.citations, "toolCalls": ans.tool_calls,
                "model": ans.model}

    @app.post(p + "/internal/sweep")
    def sweep(_: VerifiedService = Depends(service_only)):
        from app.services.sweeper import sweep_all

        return sweep_all(rt)

    @app.post(p + "/internal/retraining")
    def retrain(_: VerifiedService = Depends(service_only)):
        from app.services.sweeper import schedule_retraining

        return schedule_retraining(rt)

    return app


def _model(m) -> dict[str, Any]:
    return {"modelId": m.uid, "modelVersion": m.model_version, "modelType": m.model_type, "detector": m.detector,
            "status": m.model_status, "statusReason": m.status_reason, "trainingRecordCount": m.training_record_count,
            "trainingPeriodStart": str(m.training_period_start), "trainingPeriodEnd": str(m.training_period_end),
            "trainingCompletedAt": m.training_completed_at.isoformat(), "evaluationMetrics": m.evaluation_metrics,
            "activatedOn": m.activated_on.isoformat() if m.activated_on else None}


def _job(j) -> dict[str, Any]:
    return {"jobId": j.uid, "trigger": j.trigger, "status": j.status, "requestedOn": j.requested_on.isoformat(),
            "completedOn": j.completed_on.isoformat() if j.completed_on else None, "durationMs": j.duration_ms,
            "errorCode": j.error_code, "gate": (j.metrics or {}).get("gate"), "recordCount": (j.metrics or {}).get("record_count")}


__all__ = ["create_app", "Runtime", "asdict"]
