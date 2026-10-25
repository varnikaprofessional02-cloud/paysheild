"""Tenant lookup in the tenant-store DB (tenant.tenant.identifier = subscription uid) with a TTL cache."""

from __future__ import annotations

import threading
import time
import uuid

from app.core.tenant_context import TenantInfo
from app.db.connection import ConnectionManager

_SQL = """SELECT t.identifier::text AS uid, t.db_name, tip.instance_code AS realm, t.subdomain
FROM tenant.tenant t
LEFT JOIN tenant.tenant_identity_provider tip ON tip.tenant_id = t.id AND tip.active = true
WHERE t.db_name IS NOT NULL AND t.db_name <> ''"""


class PostgresTenantResolver:
    def __init__(self, conn: ConnectionManager, ttl_seconds: int = 300):
        self.conn, self.ttl = conn, ttl_seconds
        self._cache: dict[str, tuple[float, TenantInfo | None]] = {}
        self._lock = threading.Lock()

    def _rows(self, where: str = "", params: dict | None = None) -> list[TenantInfo]:
        with self.conn.tenant_store_connection() as c:
            rows = c.execute(_SQL + where, params or {}).fetchall()
        return [TenantInfo(r["uid"], r["db_name"], r["realm"], r["subdomain"]) for r in rows]

    def get_by_uid(self, tenant_uid: str) -> TenantInfo | None:
        try:
            key = str(uuid.UUID(str(tenant_uid)))
        except ValueError:
            return None
        with self._lock:
            hit = self._cache.get(key)
            if hit and hit[0] > time.monotonic():
                return hit[1]
        rows = self._rows(" AND t.identifier = %(u)s::uuid", {"u": key})
        info = rows[0] if rows else None
        with self._lock:
            self._cache[key] = (time.monotonic() + self.ttl, info)
        return info

    def list_tenants(self) -> list[TenantInfo]:
        return self._rows()
