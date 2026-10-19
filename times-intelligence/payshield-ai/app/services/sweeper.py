"""Scheduled jobs invoked by the Azure Functions timers (service auth only).

sweep_all: detects settled pay runs (records exist, none Processing, fingerprint changed since last seen)
in every tenant DB and analyses them. This needs no change to times-payroll-api. Lock transitions
(Completed <-> Locked) do not change the fingerprint, so locking never re-triggers an analysis."""

from __future__ import annotations

import logging
from datetime import date, timedelta

from app.core.tenant_context import AccessScope, Principal, TenantContext
from app.db.payshield_repository import PostgresPayShieldRepository
from app.domain.enums import PrincipalKind

log = logging.getLogger(__name__)


def _ctx(tenant, company) -> TenantContext:
    return TenantContext(tenant, company.id, company.uid, Principal(PrincipalKind.SERVICE, "payshield-scheduler"),
                         frozenset({"view", "edit"}), AccessScope(all_users=True), "scheduler")


def sweep_all(rt) -> dict:
    stats = {"tenants": 0, "analysed": 0, "skipped": 0, "failed": 0}
    since = (date.today() - timedelta(days=rt.s.sweeper.lookback_days)).replace(day=1)
    for tenant in rt.tenants.list_tenants():
        stats["tenants"] += 1
        try:
            payroll = rt.payroll(tenant)
            if not payroll.capabilities().has_payshield_schema:
                continue  # migration not applied to this tenant yet
            repo = PostgresPayShieldRepository(rt.conn, tenant.db_name)
            companies = {c.id: c for c in payroll.list_companies() if c.subscription_uid == tenant.tenant_uid}
            states = payroll.list_run_states(since, rt.s.sweeper.max_runs_per_tenant)
            marks = repo.get_watermarks([s.pay_run_id for s in states])
            for st in states:
                company = companies.get(st.company_id)
                if company is None or st.processing_count or not st.record_count or marks.get(st.pay_run_id) == st.fingerprint:
                    stats["skipped"] += 1
                    continue
                setting = repo.get_company_setting(company.id)
                sub = repo.get_subscription(company.id)
                if sub and sub["status"] == "ACTIVE" and setting.is_enabled and setting.auto_analyze:
                    ctx = _ctx(tenant, company)
                    rt.service(ctx).analyze_pay_run(ctx, st.pay_run_uid, "SWEEPER")
                    stats["analysed"] += 1
                repo.upsert_watermark(st.pay_run_id, company.id, st.fingerprint, True)
        except Exception:  # noqa: BLE001 - one tenant must not stop the sweep; failure is logged and counted
            stats["failed"] += 1
            log.exception("sweep failed for tenant", extra={"tenant_uid": tenant.tenant_uid})
    return stats


def schedule_retraining(rt) -> dict:
    stats = {"queued": 0, "skipped": 0, "failed": 0}
    for tenant in rt.tenants.list_tenants():
        try:
            payroll = rt.payroll(tenant)
            if not payroll.capabilities().has_payshield_schema:
                continue
            repo = PostgresPayShieldRepository(rt.conn, tenant.db_name)
            for company in payroll.list_companies():
                sub = repo.get_subscription(company.id)
                if company.subscription_uid != tenant.tenant_uid or not (sub and sub["status"] == "ACTIVE")                         or not repo.get_company_setting(company.id).is_enabled:
                    continue
                ctx = _ctx(tenant, company)
                try:
                    rt.service(ctx).request_training(ctx, "SCHEDULED", run_inline=True)
                    stats["queued"] += 1
                except Exception:  # noqa: BLE001 - e.g. a job already running
                    stats["skipped"] += 1
        except Exception:  # noqa: BLE001
            stats["failed"] += 1
            log.exception("retraining fan-out failed", extra={"tenant_uid": tenant.tenant_uid})
    return stats
