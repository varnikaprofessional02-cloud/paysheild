"""Token validation. The tenant is taken only from a token verified against THAT tenant's Keycloak realm
(a token from realm A carrying tenant B's id fails the issuer check). Service callers use Entra
client-credential tokens; a shared secret exists for local/dev only and is refused in production."""

from __future__ import annotations

import hmac
import logging
import threading
import time
import uuid
from dataclasses import dataclass, field
from typing import Mapping

import httpx
import jwt

from app.core.config import Settings
from app.core.errors import Unauthorized
from app.core.tenant_context import TenantInfo
from app.db.interfaces import TenantResolver

log = logging.getLogger(__name__)
ALGORITHMS = ["RS256", "RS384", "RS512", "PS256"]


class JwksCache:
    def __init__(self, ttl_seconds: int = 600, client: httpx.Client | None = None):
        self.ttl, self.client = ttl_seconds, client or httpx.Client(timeout=5.0)
        self._keys: dict[str, tuple[float, dict]] = {}
        self._lock = threading.Lock()

    def _fetch(self, url: str) -> dict:
        resp = self.client.get(url)
        resp.raise_for_status()
        keys = {k["kid"]: k for k in resp.json().get("keys", []) if "kid" in k}
        with self._lock:
            self._keys[url] = (time.monotonic() + self.ttl, keys)
        return keys

    def key(self, url: str, kid: str):
        with self._lock:
            hit = self._keys.get(url)
        keys = hit[1] if hit and hit[0] > time.monotonic() else self._fetch(url)
        if kid not in keys:
            keys = self._fetch(url)  # key rotation: refetch once
        if kid not in keys:
            raise Unauthorized("TOKEN_INVALID", "Invalid token.")
        return jwt.PyJWK(keys[kid]).key


@dataclass(frozen=True)
class VerifiedUser:
    tenant: TenantInfo
    user_uid: str
    roles: tuple[str, ...] = ()


@dataclass(frozen=True)
class VerifiedService:
    app_id: str
    roles: tuple[str, ...] = field(default=())


def _bearer(headers: Mapping[str, str]) -> str | None:
    auth = headers.get("authorization") or ""
    return auth[7:].strip() if auth.lower().startswith("bearer ") else None


def _fail(reason: str) -> Unauthorized:
    log.info("authentication rejected", extra={"error_code": reason})
    return Unauthorized("UNAUTHENTICATED", "Authentication failed.")


class Authenticator:
    def __init__(self, settings: Settings, tenants: TenantResolver, jwks: JwksCache):
        self.s, self.tenants, self.jwks = settings, tenants, jwks

    def authenticate(self, headers: Mapping[str, str]) -> VerifiedUser | VerifiedService:
        headers = {k.lower(): v for k, v in headers.items()}
        key = headers.get("x-payshield-service-key")
        if key is not None:
            return self._shared_secret(key)
        token = _bearer(headers)
        if not token:
            raise _fail("NO_TOKEN")
        try:
            unverified = jwt.decode(token, options={"verify_signature": False})
            header = jwt.get_unverified_header(token)
        except jwt.PyJWTError:
            raise _fail("MALFORMED") from None
        if header.get("alg") not in ALGORITHMS or not header.get("kid"):
            raise _fail("ALGORITHM")
        if "tenant_id" in unverified:
            return self._keycloak(token, unverified, header["kid"])
        return self._entra(token, header["kid"])

    def _keycloak(self, token: str, unverified: dict, kid: str) -> VerifiedUser:
        tenant = self.tenants.get_by_uid(str(unverified.get("tenant_id")))
        if tenant is None or not tenant.realm or not self.s.keycloak.authority:
            raise _fail("TENANT_UNKNOWN")
        issuer = f"{self.s.keycloak.authority.rstrip('/')}/realms/{tenant.realm}"
        try:
            claims = jwt.decode(token, self.jwks.key(f"{issuer}/protocol/openid-connect/certs", kid), algorithms=ALGORITHMS,
                                issuer=issuer, audience=self.s.keycloak.audiences or None,
                                leeway=self.s.keycloak.clock_skew_seconds,
                                options={"verify_aud": bool(self.s.keycloak.audiences), "require": ["exp", "iss"]})
        except (jwt.PyJWTError, httpx.HTTPError):
            raise _fail("TOKEN_INVALID") from None
        if str(claims.get("tenant_id")) != tenant.tenant_uid:
            raise _fail("TENANT_MISMATCH")
        uid = next((claims[c] for c in self.s.keycloak.user_uid_claims if claims.get(c)), None)
        try:
            uid = str(uuid.UUID(str(uid)))
        except ValueError:
            raise _fail("USER_UID") from None
        roles = list((claims.get("realm_access") or {}).get("roles", []))
        for res in (claims.get("resource_access") or {}).values():
            roles += res.get("roles", [])
        return VerifiedUser(tenant, uid, tuple(roles))

    def _entra(self, token: str, kid: str) -> VerifiedService:
        sa = self.s.service_auth
        if sa.mode != "entra" or not sa.entra_tenant_id:
            raise _fail("SERVICE_AUTH_DISABLED")
        url = f"https://login.microsoftonline.com/{sa.entra_tenant_id}/discovery/v2.0/keys"
        issuers = [f"https://login.microsoftonline.com/{sa.entra_tenant_id}/v2.0", f"https://sts.windows.net/{sa.entra_tenant_id}/"]
        try:
            claims = jwt.decode(token, self.jwks.key(url, kid), algorithms=ALGORITHMS, audience=sa.entra_audience,
                                leeway=30, options={"require": ["exp", "iss", "aud"]})
        except (jwt.PyJWTError, httpx.HTTPError):
            raise _fail("TOKEN_INVALID") from None
        app_id = claims.get("azp") or claims.get("appid")
        if claims.get("iss") not in issuers or app_id not in sa.allowed_app_ids or sa.required_role not in claims.get("roles", []):
            raise _fail("SERVICE_NOT_ALLOWED")
        return VerifiedService(app_id, tuple(claims.get("roles", [])))

    def _shared_secret(self, key: str) -> VerifiedService:
        secret = self.s.service_auth.shared_secret.get_secret_value()
        if self.s.is_production or self.s.service_auth.mode != "shared_secret" or not secret:
            raise _fail("SHARED_SECRET_DISABLED")
        if not hmac.compare_digest(key.encode(), secret.encode()):
            raise _fail("SHARED_SECRET_INVALID")
        return VerifiedService("shared-secret", (self.s.service_auth.required_role,))
