"""Builds the server-side TenantContext after authentication.

Employee-level Data Security (Times.AccessFilter.Engine) is NOT yet ported: a user holding PAY View on the
company sees every employee of that company, which is the same visibility the pay run screens grant today
without a data-security rule. See docs/06_SECURITY.md (known gaps)."""

from __future__ import annotations

import uuid

from app.core.config import Settings
from app.core.errors import Forbidden, Unauthorized
from app.core.security import VerifiedService, VerifiedUser
from app.core.tenant_context import AccessScope, Principal, TenantContext, TenantInfo
from app.db.interfaces import PayrollReadRepository, TenantResolver
from app.domain.enums import PrincipalKind

COMPANY_DENIED = Forbidden("COMPANY_NOT_ACCESSIBLE", "The company is not accessible.")


def _company(repo: PayrollReadRepository, tenant: TenantInfo, company_uid: str | None):
    try:
        company_uid = str(uuid.UUID(str(company_uid)))
    except ValueError:
        raise COMPANY_DENIED from None
    company = repo.get_company_by_uid(company_uid)
    # unknown company and another subscription's company produce the same response
    if company is None or company.subscription_uid != tenant.tenant_uid:
        raise COMPANY_DENIED
    return company


def build_user_context(settings: Settings, repo: PayrollReadRepository, who: VerifiedUser, company_uid: str | None,
                       correlation_id: str) -> TenantContext:
    company = _company(repo, who.tenant, company_uid)
    if repo.get_user_id_by_uid(who.user_uid) is None:
        raise Forbidden("USER_NOT_RECOGNISED", "The user is not recognised.")
    if not repo.user_has_company_access(who.user_uid, company.id):
        raise COMPANY_DENIED
    principals = [who.user_uid, f"{who.user_uid}@{company.uid}", *who.roles]
    perms = frozenset(repo.get_function_permissions(settings.pay_function_code, principals, company.uid))
    if settings.view_permission.lower() not in perms:
        raise Forbidden("PERMISSION_DENIED", "PAY View permission is required.")
    return TenantContext(who.tenant, company.id, company.uid, Principal(PrincipalKind.USER, who.user_uid, roles=who.roles),
                         perms, AccessScope(all_users=True), correlation_id)


def build_service_context(tenants: TenantResolver, repo_factory, who: VerifiedService, tenant_uid: str | None,
                          company_uid: str | None, correlation_id: str) -> TenantContext:
    tenant = tenants.get_by_uid(tenant_uid or "")
    if tenant is None:
        raise Unauthorized("TENANT_UNKNOWN", "Unknown tenant.")
    company = _company(repo_factory(tenant), tenant, company_uid)
    return TenantContext(tenant, company.id, company.uid, Principal(PrincipalKind.SERVICE, who.app_id, roles=who.roles),
                         frozenset({"view", "edit"}), AccessScope(all_users=True), correlation_id)


def require(ctx: TenantContext, permission: str) -> None:
    if not ctx.can(permission):
        raise Forbidden("PERMISSION_DENIED", f"PAY {permission} permission is required.")
