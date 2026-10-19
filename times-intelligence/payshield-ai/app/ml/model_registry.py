"""Model versioning, activation/rollback and secure cached loading.

The cache is process-wide and keyed by (tenant uid, company uid, model uid, sha256): an entry for one
tenant can never satisfy a lookup for another. The registry row is always read from the caller's
tenant DB with the caller's company id first, so foreign model ids are never resolvable."""

from __future__ import annotations

import threading
from collections import OrderedDict
from datetime import datetime, timezone

from app.data.feature_extractor import FEATURE_SCHEMA_VERSION
from app.db.interfaces import ArtifactStore, ModelRecord, PayShieldRepository
from app.domain.enums import ModelStatus
from app.domain.models import CompanyRef
from app.ml.model_bundle import ModelBundle
from app.ml.trainer import TrainingResult


class BundleCache:
    def __init__(self, max_entries: int = 64):
        self._max = max_entries
        self._items: OrderedDict[tuple, ModelBundle] = OrderedDict()
        self._lock = threading.Lock()

    def get(self, key: tuple) -> ModelBundle | None:
        with self._lock:
            b = self._items.get(key)
            if b is not None:
                self._items.move_to_end(key)
            return b

    def put(self, key: tuple, bundle: ModelBundle) -> None:
        with self._lock:
            self._items[key] = bundle
            self._items.move_to_end(key)
            while len(self._items) > self._max:
                self._items.popitem(last=False)


class ModelRegistry:
    def __init__(self, repo: PayShieldRepository, store: ArtifactStore, cache: BundleCache):
        self.repo, self.store, self.cache = repo, store, cache

    def register(self, tenant_uid: str, company: CompanyRef, result: TrainingResult, training_job_id: int | None,
                 actor: str, started_at: datetime) -> ModelRecord:
        version = f"{FEATURE_SCHEMA_VERSION}.{self.repo.next_model_sequence(company.id)}.0"
        bundle = ModelBundle(tenant_uid, company.uid, version, result.detector, result.pipeline, result.score_quantiles,
                             result.feature_medians, result.feature_scales, result.report)
        location, sha, size = self.store.save(tenant_uid, company.uid, version, bundle.to_bytes())
        status = result.gate["model_status"]
        record = self.repo.insert_model(ModelRecord(
            id=0, uid="", tenant_uid=tenant_uid, company_id=company.id, company_uid=company.uid, model_version=version,
            model_type="ISOLATION_FOREST", detector=result.detector, feature_schema_version=FEATURE_SCHEMA_VERSION,
            training_job_id=training_job_id, training_started_at=started_at, training_completed_at=datetime.now(timezone.utc),
            training_record_count=result.record_count, training_period_start=result.period_start,
            training_period_end=result.period_end, evaluation_metrics=result.report, model_storage_location=location,
            artifact_sha256=sha, artifact_size_bytes=size,
            model_status=ModelStatus.TRAINED.value if status == ModelStatus.ACTIVE.value else status,
            status_reason=result.gate["reason"],
        ))
        if result.gate["activate"]:
            record = self.repo.activate_model(company.id, record.uid, actor, "passed activation gate")
        return record

    def load(self, tenant_uid: str, company: CompanyRef, record: ModelRecord) -> ModelBundle:
        if record.company_id != company.id or record.tenant_uid != tenant_uid:
            raise PermissionError("model does not belong to this tenant/company")
        key = (tenant_uid, company.uid, record.uid, record.artifact_sha256)
        bundle = self.cache.get(key)
        if bundle is None:
            data = self.store.load(tenant_uid, company.uid, record.model_storage_location, record.artifact_sha256)
            bundle = ModelBundle.from_bytes(data, tenant_uid, company.uid)
            self.cache.put(key, bundle)
        return bundle

    def load_active(self, tenant_uid: str, company: CompanyRef) -> tuple[ModelRecord, ModelBundle] | None:
        record = self.repo.get_active_model(company.id)
        return None if record is None else (record, self.load(tenant_uid, company, record))

    def activate(self, company: CompanyRef, model_uid: str, actor: str, reason: str) -> ModelRecord:
        record = self.repo.get_model(company.id, model_uid)
        if record is None:
            raise LookupError("model not found")
        if record.feature_schema_version != FEATURE_SCHEMA_VERSION or record.model_status == ModelStatus.REJECTED.value:
            raise ValueError("model cannot be activated (rejected or incompatible feature schema)")
        return self.repo.activate_model(company.id, model_uid, actor, reason)
