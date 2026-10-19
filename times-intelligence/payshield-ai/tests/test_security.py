"""Authentication & tenant-isolation tests (synthetic keys, no network)."""

from __future__ import annotations

import time

import httpx
import jwt
import pytest
from cryptography.hazmat.primitives.asymmetric import rsa

from app.core.config import Settings
from app.core.errors import Forbidden, Unauthorized
from app.core.security import Authenticator, JwksCache
from app.core.tenant_context import TenantInfo
from app.security.permissions import build_user_context
from tests.factories import COMPANY_A1, COMPANY_B1, TENANT_A, TENANT_B

AUTH = "https://kc.example"
USER = "00000000-0000-4000-8000-000000000007"
KEYS = {r: rsa.generate_private_key(public_exponent=65537, key_size=2048) for r in ("realmA", "realmB")}


def _jwks(request: httpx.Request) -> httpx.Response:
    realm = request.url.path.split("/")[2]
    jwk = jwt.algorithms.RSAAlgorithm.to_jwk(KEYS[realm].public_key(), as_dict=True)
    return httpx.Response(200, json={"keys": [{**jwk, "kid": realm, "alg": "RS256"}]})


class Tenants:
    def get_by_uid(self, uid):
        return {TENANT_A: TenantInfo(TENANT_A, "t_a", "realmA"), TENANT_B: TenantInfo(TENANT_B, "t_b", "realmB")}.get(uid)

    def list_tenants(self):
        return []


def auth(**kw) -> Authenticator:
    s = Settings(keycloak={"authority": AUTH}, **kw)
    return Authenticator(s, Tenants(), JwksCache(client=httpx.Client(transport=httpx.MockTransport(_jwks))))


def token(realm="realmA", tenant=TENANT_A, alg="RS256", exp=3600, key=None, **claims):
    payload = {"iss": f"{AUTH}/realms/{realm}", "sub": USER, "tenant_id": tenant, "exp": int(time.time()) + exp,
               "realm_access": {"roles": ["Payroll Admin"]}, **claims}
    return jwt.encode(payload, key or KEYS[realm], algorithm=alg, headers={"kid": realm})


def hdr(t):
    return {"Authorization": f"Bearer {t}"}


def test_valid_token():
    who = auth().authenticate(hdr(token()))
    assert who.tenant.tenant_uid == TENANT_A and who.user_uid == USER and "Payroll Admin" in who.roles


def test_token_from_other_realm_claiming_tenant_a_is_rejected():
    # signed by realm B's key with realm B issuer but tenant_id of A
    with pytest.raises(Unauthorized):
        auth().authenticate(hdr(token(realm="realmB", tenant=TENANT_A)))


def test_issuer_spoof_with_wrong_key_rejected():
    t = token(realm="realmA", key=KEYS["realmB"])
    with pytest.raises(Unauthorized):
        auth().authenticate(hdr(t))


@pytest.mark.parametrize("bad", ["expired", "unknown_tenant", "hs256", "none"])
def test_invalid_tokens(bad):
    if bad == "expired":
        t = token(exp=-600)
    elif bad == "unknown_tenant":
        t = token(tenant="33333333-3333-4333-8333-333333333333")
    elif bad == "hs256":
        t = jwt.encode({"tenant_id": TENANT_A, "iss": f"{AUTH}/realms/realmA", "sub": USER}, "secret", algorithm="HS256",
                       headers={"kid": "realmA"})
    else:
        t = jwt.encode({"tenant_id": TENANT_A}, None, algorithm="none")
    with pytest.raises(Unauthorized):
        auth().authenticate(hdr(t))


def test_shared_secret_dev_only():
    a = auth(service_auth={"mode": "shared_secret", "shared_secret": "k"})
    assert a.authenticate({"X-PayShield-Service-Key": "k"}).app_id == "shared-secret"
    with pytest.raises(Unauthorized):
        a.authenticate({"X-PayShield-Service-Key": "wrong"})
    with pytest.raises(ValueError):
        Settings(environment="production", service_auth={"mode": "shared_secret", "shared_secret": "k"})


class Repo:
    def __init__(self, perms=frozenset({"view"}), access=True):
        self.perms, self.access = perms, access

    def get_company_by_uid(self, uid):
        return {c.uid: c for c in (COMPANY_A1, COMPANY_B1)}.get(uid)

    def get_user_id_by_uid(self, uid):
        return 7

    def user_has_company_access(self, uid, cid):
        return self.access

    def get_function_permissions(self, code, principals, company_uid):
        assert code == "PAY" and principals[0] == USER
        return set(self.perms)


def test_company_of_another_tenant_is_denied_like_unknown():
    who = auth().authenticate(hdr(token()))
    with pytest.raises(Forbidden) as e1:
        build_user_context(Settings(), Repo(), who, COMPANY_B1.uid, "c")
    with pytest.raises(Forbidden) as e2:
        build_user_context(Settings(), Repo(), who, "99999999-9999-4999-8999-999999999999", "c")
    assert e1.value.code == e2.value.code == "COMPANY_NOT_ACCESSIBLE"


def test_permissions_required():
    who = auth().authenticate(hdr(token()))
    ctx = build_user_context(Settings(), Repo(), who, COMPANY_A1.uid, "c")
    assert ctx.can("view") and not ctx.can("edit")
    with pytest.raises(Forbidden):
        build_user_context(Settings(), Repo(perms=frozenset()), who, COMPANY_A1.uid, "c")
    with pytest.raises(Forbidden):
        build_user_context(Settings(), Repo(access=False), who, COMPANY_A1.uid, "c")


def test_model_cache_is_tenant_keyed(tmp_path):
    from app.db.interfaces import ArtifactIntegrityError
    from app.ml.model_bundle import LocalArtifactStore

    store = LocalArtifactStore(str(tmp_path))
    loc, sha, _ = store.save(TENANT_A, COMPANY_A1.uid, "1.1.0", b"model-a")
    assert store.load(TENANT_A, COMPANY_A1.uid, loc, sha) == b"model-a"
    with pytest.raises(ArtifactIntegrityError):
        store.load(TENANT_B, COMPANY_A1.uid, loc, sha)  # other tenant, same company uid
    with pytest.raises(ArtifactIntegrityError):
        store.load(TENANT_A, COMPANY_A1.uid, loc, "0" * 64)  # tampered / wrong hash
