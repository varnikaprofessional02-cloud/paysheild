"""Server-resolved request context. Instances are created only by ``app.core.security`` /
``app.api.deps`` after token verification; nothing in a request body can construct or alter one.
"""

from __future__ import annotations

from dataclasses import dataclass, field

from app.domain.enums import PrincipalKind


@dataclass(frozen=True)
class TenantInfo:
    """Row of tenant-store tenant.tenant (+ active tenant_identity_provider)."""

    tenant_uid: str  # tenant.tenant.identifier == subscription uid (immutable, model key part 1)
    db_name: str  # tenant.tenant.db_name
    realm: str | None  # tenant_identity_provider.instance_code (Keycloak realm)
    subdomain: str | None = None


@dataclass(frozen=True)
class Principal:
    kind: PrincipalKind
    subject: str  # user uid (Keycloak sub / user attribute) or Entra app id
    display: str | None = None  # never logged; for audit tables only
    roles: tuple[str, ...] = ()


@dataclass(frozen=True)
class AccessScope:
    """Employee-level visibility for the principal in this company.

    ``all_users`` is True for service principals and for users exempt from Data Security
    (Owner / Sub Owner). Otherwise ``user_ids`` is the exact visible set (possibly empty = fail closed).
    """

    all_users: bool
    user_ids: frozenset[int] = field(default_factory=frozenset)

    def allows(self, user_id: int) -> bool:
        return self.all_users or user_id in self.user_ids

    def filter_ids(self, user_ids: "list[int] | set[int]") -> list[int]:
        return [u for u in user_ids if self.allows(u)]


@dataclass(frozen=True)
class TenantContext:
    tenant: TenantInfo
    company_id: int
    company_uid: str
    principal: Principal
    permissions: frozenset[str]  # lower-case permissions on the PAY function, e.g. {"view", "edit"}
    access: AccessScope
    correlation_id: str

    @property
    def tenant_uid(self) -> str:
        return self.tenant.tenant_uid

    @property
    def is_service(self) -> bool:
        return self.principal.kind == PrincipalKind.SERVICE

    def can(self, permission: str) -> bool:
        return self.is_service or permission.lower() in self.permissions

    @property
    def actor(self) -> str:
        """Value written to created_by / requested_by columns."""
        prefix = "svc:" if self.is_service else ""
        return f"{prefix}{self.principal.subject}"
