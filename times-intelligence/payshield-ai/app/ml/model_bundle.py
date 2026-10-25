"""Model bundle serialisation and tenant/company-scoped artifact storage with SHA-256 integrity."""

from __future__ import annotations

import hashlib
import shutil
import io
import re
import uuid
from dataclasses import dataclass, field
from pathlib import Path

import joblib
import sklearn

from app.data.feature_extractor import FEATURE_SCHEMA_VERSION, MODEL_FEATURES
from app.db.interfaces import ArtifactIntegrityError

_VERSION = re.compile(r"^\d+\.\d+\.\d+$")


@dataclass
class ModelBundle:
    tenant_uid: str
    company_uid: str
    model_version: str
    detector: str
    pipeline: object
    score_quantiles: list[float]
    feature_medians: dict[str, float | None]
    feature_scales: dict[str, float | None]
    metrics: dict
    feature_schema_version: str = FEATURE_SCHEMA_VERSION
    model_features: tuple[str, ...] = MODEL_FEATURES
    library_versions: dict = field(default_factory=lambda: {"sklearn": sklearn.__version__})

    def to_bytes(self) -> bytes:
        buf = io.BytesIO()
        joblib.dump(self, buf, compress=3)
        return buf.getvalue()

    @staticmethod
    def from_bytes(data: bytes, expected_tenant_uid: str, expected_company_uid: str) -> "ModelBundle":
        bundle = joblib.load(io.BytesIO(data))
        if not isinstance(bundle, ModelBundle):
            raise ArtifactIntegrityError("artifact is not a model bundle")
        if bundle.tenant_uid != expected_tenant_uid or bundle.company_uid != expected_company_uid:
            raise ArtifactIntegrityError("artifact belongs to another tenant or company")
        if bundle.feature_schema_version != FEATURE_SCHEMA_VERSION:
            raise ArtifactIntegrityError("artifact feature schema is incompatible")
        return bundle


def _guid(v: str) -> str:
    return str(uuid.UUID(str(v)))


def artifact_path(tenant_uid: str, company_uid: str, version: str) -> str:
    if not _VERSION.match(version):
        raise ValueError("invalid model version")
    return f"tenants/{_guid(tenant_uid)}/companies/{_guid(company_uid)}/models/{version}/model.joblib"


def _check(tenant_uid: str, company_uid: str, location: str, data: bytes, sha: str) -> bytes:
    prefix = f"tenants/{_guid(tenant_uid)}/companies/{_guid(company_uid)}/models/"
    if not location.startswith(prefix) or ".." in location:
        raise ArtifactIntegrityError("artifact location outside tenant/company scope")
    if hashlib.sha256(data).hexdigest() != sha:
        raise ArtifactIntegrityError("artifact hash mismatch")
    return data


class LocalArtifactStore:
    def __init__(self, root: str):
        self.root = Path(root)

    def save(self, tenant_uid, company_uid, model_version, payload: bytes):
        loc = artifact_path(tenant_uid, company_uid, model_version)
        path = self.root / loc
        path.parent.mkdir(parents=True, exist_ok=True)
        if path.exists():
            raise ArtifactIntegrityError("artifact already exists")
        path.write_bytes(payload)
        return loc, hashlib.sha256(payload).hexdigest(), len(payload)

    def load(self, tenant_uid, company_uid, storage_location, expected_sha256) -> bytes:
        # validate scope before touching the filesystem
        if not storage_location.startswith(f"tenants/{_guid(tenant_uid)}/companies/{_guid(company_uid)}/models/") or ".." in storage_location:
            raise ArtifactIntegrityError("artifact location outside tenant/company scope")
        path = self.root / storage_location
        data = path.read_bytes() if path.exists() else b""
        return _check(tenant_uid, company_uid, storage_location, data, expected_sha256)


    def delete_company(self, tenant_uid, company_uid) -> int:
        path = self.root / f"tenants/{_guid(tenant_uid)}/companies/{_guid(company_uid)}"
        n = sum(1 for f in path.rglob("*") if f.is_file()) if path.exists() else 0
        shutil.rmtree(path, ignore_errors=True)
        return n


class AzureBlobArtifactStore:
    def __init__(self, container_client):
        self.container = container_client

    def save(self, tenant_uid, company_uid, model_version, payload: bytes):
        loc = artifact_path(tenant_uid, company_uid, model_version)
        self.container.upload_blob(loc, payload, overwrite=False)
        return loc, hashlib.sha256(payload).hexdigest(), len(payload)

    def load(self, tenant_uid, company_uid, storage_location, expected_sha256) -> bytes:
        prefix = f"tenants/{_guid(tenant_uid)}/companies/{_guid(company_uid)}/models/"
        if not storage_location.startswith(prefix):
            raise ArtifactIntegrityError("artifact location outside tenant/company scope")
        data = self.container.download_blob(storage_location).readall()
        return _check(tenant_uid, company_uid, storage_location, data, expected_sha256)


    def delete_company(self, tenant_uid, company_uid) -> int:
        prefix = f"tenants/{_guid(tenant_uid)}/companies/{_guid(company_uid)}/"
        names = [b.name for b in self.container.list_blobs(name_starts_with=prefix)]
        for n in names:
            self.container.delete_blob(n)
        return len(names)


def build_artifact_store(storage):
    if storage.backend == "local":
        return LocalArtifactStore(storage.local_root)
    from azure.storage.blob import ContainerClient

    conn = storage.blob_connection_string.get_secret_value()
    if conn:
        return AzureBlobArtifactStore(ContainerClient.from_connection_string(conn, storage.blob_container))
    from azure.identity import DefaultAzureCredential

    return AzureBlobArtifactStore(ContainerClient(storage.blob_account_url, storage.blob_container,
                                                  credential=DefaultAzureCredential()))
