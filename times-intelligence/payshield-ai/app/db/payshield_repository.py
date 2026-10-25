"""times_intelligence.* persistence for one tenant database. Every method filters by company_id."""

from __future__ import annotations

import uuid
from dataclasses import fields


import psycopg
from psycopg.types.json import Jsonb

from app.db.connection import ConnectionManager
from app.db.interfaces import (
    AnalysisRecord, AnomalyRecord, CompanySettingRecord, FeedbackRecord, ModelRecord, TrainingAlreadyInProgress,
    TrainingJobRecord,
)
from app.domain.enums import FeedbackOutcome

_LIVE = "('QUEUED','RUNNING','COMPLETED','COMPLETED_WITH_WARNINGS')"


def _guid(v: str) -> str:
    return str(uuid.UUID(str(v)))


def _build(cls, row: dict):
    names = {f.name for f in fields(cls)}
    data = {k: v for k, v in row.items() if k in names}
    for k in ("uid", "tenant_uid", "company_uid", "pay_run_uid", "reviewer_uid"):
        if k in data and data[k] is not None:
            data[k] = str(data[k])
    for k, v in list(data.items()):
        if hasattr(v, "is_finite"):  # Decimal
            data[k] = float(v)
    return cls(**data)


class PostgresPayShieldRepository:
    def __init__(self, conn: ConnectionManager, db_name: str):
        self.conn, self.db = conn, db_name

    def _all(self, sql: str, p: dict | None = None) -> list[dict]:
        with self.conn.connection(self.db) as c:
            cur = c.execute(sql, p or {})
            return cur.fetchall() if cur.description else []

    def _one(self, sql: str, p: dict | None = None) -> dict | None:
        rows = self._all(sql, p)
        return rows[0] if rows else None

    # subscription -----------------------------------------------------------------------------
    def get_subscription(self, company_id: int) -> dict | None:
        return self._one("""SELECT uid::text AS uid, status, modules, subscribed_on, subscribed_by
                             FROM times_intelligence.subscription WHERE company_id=%(c)s""", {"c": company_id})

    def subscribe(self, company_id: int, actor: str) -> dict:
        return self._one("""INSERT INTO times_intelligence.subscription (company_id, subscribed_by) VALUES (%(c)s, %(a)s)
            ON CONFLICT (company_id) DO UPDATE SET status='ACTIVE', subscribed_on=now(), subscribed_by=%(a)s,
                cancelled_on=NULL, cancelled_by=NULL,
                updated_on=now(), updated_by=%(a)s
            RETURNING uid::text AS uid, status, modules, subscribed_on, subscribed_by""", {"c": company_id, "a": actor})

    def unsubscribe(self, company_id: int, actor: str) -> dict | None:
        # data (models, analyses, feedback) is kept so a later re-subscription continues where it left off
        return self._one("""UPDATE times_intelligence.subscription SET status='CANCELLED', cancelled_on=now(), cancelled_by=%(a)s,
                updated_on=now(), updated_by=%(a)s WHERE company_id=%(c)s
            RETURNING uid::text AS uid, status, modules, subscribed_on, subscribed_by""", {"c": company_id, "a": actor})

    # settings -------------------------------------------------------------------------------
    def get_company_setting(self, company_id: int) -> CompanySettingRecord:
        r = self._one("SELECT * FROM times_intelligence.company_setting WHERE company_id = %(c)s", {"c": company_id})
        return _build(CompanySettingRecord, r) if r else CompanySettingRecord(company_id)

    def upsert_company_setting(self, s: CompanySettingRecord, actor: str) -> None:
        self._all("""INSERT INTO times_intelligence.company_setting (company_id, is_enabled, auto_analyze, auto_activate_models,
                overtime_pay_codes, thresholds, created_by) VALUES (%(c)s,%(e)s,%(a)s,%(m)s,%(o)s,%(t)s,%(u)s)
            ON CONFLICT (company_id) DO UPDATE SET is_enabled=EXCLUDED.is_enabled, auto_analyze=EXCLUDED.auto_analyze,
                auto_activate_models=EXCLUDED.auto_activate_models, overtime_pay_codes=EXCLUDED.overtime_pay_codes,
                thresholds=EXCLUDED.thresholds, updated_on=now(), updated_by=%(u)s""",
                  {"c": s.company_id, "e": s.is_enabled, "a": s.auto_analyze, "m": s.auto_activate_models,
                   "o": list(s.overtime_pay_codes), "t": Jsonb(s.thresholds), "u": actor})

    # training jobs ------------------------------------------------------------------------------
    def create_training_job(self, tenant_uid, company_id, trigger, requested_by) -> TrainingJobRecord:
        try:
            r = self._one("""INSERT INTO times_intelligence.training_job (tenant_uid, company_id, trigger, requested_by)
                VALUES (%(t)s::uuid, %(c)s, %(g)s, %(u)s) RETURNING *""",
                          {"t": _guid(tenant_uid), "c": company_id, "g": trigger, "u": requested_by})
        except psycopg.errors.UniqueViolation:
            active = self._one("""SELECT uid::text AS uid FROM times_intelligence.training_job WHERE company_id=%(c)s
                                  AND status IN ('QUEUED','RUNNING')""", {"c": company_id})
            raise TrainingAlreadyInProgress(company_id, active["uid"] if active else None) from None
        return _build(TrainingJobRecord, r)

    def get_training_job(self, company_id, job_uid):
        r = self._one("SELECT * FROM times_intelligence.training_job WHERE company_id=%(c)s AND uid=%(u)s::uuid",
                      {"c": company_id, "u": _guid(job_uid)})
        return _build(TrainingJobRecord, r) if r else None

    def list_training_jobs(self, company_id, limit=20):
        return [_build(TrainingJobRecord, r) for r in self._all(
            "SELECT * FROM times_intelligence.training_job WHERE company_id=%(c)s ORDER BY requested_on DESC LIMIT %(n)s",
            {"c": company_id, "n": limit})]

    def claim_training_job(self, company_id, job_uid):
        r = self._one("""UPDATE times_intelligence.training_job SET status='RUNNING', started_on=now(), heartbeat_on=now()
            WHERE company_id=%(c)s AND uid=%(u)s::uuid AND status='QUEUED' RETURNING *""", {"c": company_id, "u": _guid(job_uid)})
        return _build(TrainingJobRecord, r) if r else None

    def heartbeat_training_job(self, job_id):
        self._all("UPDATE times_intelligence.training_job SET heartbeat_on=now() WHERE id=%(i)s", {"i": job_id})

    def complete_training_job(self, job_id, status, metrics, model_registry_id, error_code=None, error_message=None):
        self._all("""UPDATE times_intelligence.training_job SET status=%(s)s, metrics=%(m)s, model_registry_id=%(r)s,
                error_code=%(ec)s, error_message=%(em)s, completed_on=now(),
                duration_ms=(EXTRACT(EPOCH FROM now() - COALESCE(started_on, requested_on)) * 1000)::bigint, updated_on=now()
            WHERE id=%(i)s""", {"s": status, "m": Jsonb(metrics), "r": model_registry_id, "ec": error_code,
                                "em": error_message, "i": job_id})

    def recover_stale_training_jobs(self, stale_after_seconds):
        return [_build(TrainingJobRecord, r) for r in self._all("""UPDATE times_intelligence.training_job SET status='FAILED',
                error_code='STALE', error_message='training worker stopped responding', completed_on=now()
            WHERE status='RUNNING' AND heartbeat_on < now() - make_interval(secs => %(s)s) RETURNING *""",
                                                                {"s": stale_after_seconds})]

    # models -------------------------------------------------------------------------------------
    def next_model_sequence(self, company_id):
        return self._one("SELECT count(*) + 1 AS n FROM times_intelligence.model_registry WHERE company_id=%(c)s", {"c": company_id})["n"]

    def insert_model(self, m: ModelRecord) -> ModelRecord:
        r = self._one("""INSERT INTO times_intelligence.model_registry (tenant_uid, company_id, company_uid, model_version, model_type,
                detector, feature_schema_version, training_job_id, training_started_at, training_completed_at,
                training_record_count, training_period_start, training_period_end, evaluation_metrics,
                model_storage_location, artifact_sha256, artifact_size_bytes, model_status, status_reason)
            VALUES (%(tenant_uid)s::uuid, %(company_id)s, %(company_uid)s::uuid, %(model_version)s, %(model_type)s, %(detector)s,
                %(feature_schema_version)s, %(training_job_id)s, %(training_started_at)s, %(training_completed_at)s,
                %(training_record_count)s, %(training_period_start)s, %(training_period_end)s, %(evaluation_metrics)s,
                %(model_storage_location)s, %(artifact_sha256)s, %(artifact_size_bytes)s, %(model_status)s, %(status_reason)s)
            RETURNING *""", {**{f.name: getattr(m, f.name) for f in fields(m)}, "evaluation_metrics": Jsonb(m.evaluation_metrics)})
        return _build(ModelRecord, r)

    def get_model(self, company_id, model_uid):
        r = self._one("SELECT * FROM times_intelligence.model_registry WHERE company_id=%(c)s AND uid=%(u)s::uuid",
                      {"c": company_id, "u": _guid(model_uid)})
        return _build(ModelRecord, r) if r else None

    def get_active_model(self, company_id):
        r = self._one("SELECT * FROM times_intelligence.model_registry WHERE company_id=%(c)s AND model_status='ACTIVE'", {"c": company_id})
        return _build(ModelRecord, r) if r else None

    def list_models(self, company_id, limit=50):
        return [_build(ModelRecord, r) for r in self._all(
            "SELECT * FROM times_intelligence.model_registry WHERE company_id=%(c)s ORDER BY created_on DESC, id DESC LIMIT %(n)s",
            {"c": company_id, "n": limit})]

    def activate_model(self, company_id, model_uid, actor, reason) -> ModelRecord:
        with self.conn.connection(self.db) as c, c.transaction():
            c.execute("""UPDATE times_intelligence.model_registry SET model_status='RETIRED', retired_on=now(), updated_on=now()
                         WHERE company_id=%(c)s AND model_status='ACTIVE'""", {"c": company_id})
            r = c.execute("""UPDATE times_intelligence.model_registry SET model_status='ACTIVE', activated_on=now(), activated_by=%(a)s,
                    status_reason=%(r)s, retired_on=NULL, updated_on=now()
                WHERE company_id=%(c)s AND uid=%(u)s::uuid RETURNING *""",
                          {"c": company_id, "u": _guid(model_uid), "a": actor, "r": reason}).fetchone()
            if r is None:
                raise LookupError("model not found")
        return _build(ModelRecord, r)

    def set_model_status(self, company_id, model_uid, status, reason):
        self._all("""UPDATE times_intelligence.model_registry SET model_status=%(s)s, status_reason=%(r)s, updated_on=now()
                     WHERE company_id=%(c)s AND uid=%(u)s::uuid""", {"s": status, "r": reason, "c": company_id, "u": _guid(model_uid)})

    # analyses -----------------------------------------------------------------------------------
    def create_analysis(self, tenant_uid, company_id, pay_run, trigger, fingerprint, requested_by, supersede_existing):
        params = {"t": _guid(tenant_uid), "c": company_id, "rid": pay_run.id, "ruid": pay_run.uid, "p": pay_run.period,
                  "cy": pay_run.cycle_code, "tr": pay_run.is_trial, "g": trigger, "f": fingerprint, "u": requested_by}
        with self.conn.connection(self.db) as c, c.transaction():
            if supersede_existing:
                c.execute(f"""UPDATE times_intelligence.analysis SET status='SUPERSEDED', updated_on=now()
                              WHERE company_id=%(c)s AND pay_run_id=%(rid)s AND status IN {_LIVE}""", params)
            r = c.execute(f"""INSERT INTO times_intelligence.analysis (tenant_uid, company_id, pay_run_id, pay_run_uid, period, cycle_code,
                    is_trial_run, trigger, run_fingerprint, requested_by)
                VALUES (%(t)s::uuid,%(c)s,%(rid)s,%(ruid)s::uuid,%(p)s,%(cy)s,%(tr)s,%(g)s,%(f)s,%(u)s)
                ON CONFLICT (pay_run_id, run_fingerprint) WHERE status IN {_LIVE} DO NOTHING RETURNING *""", params).fetchone()
            if r is not None:
                return _build(AnalysisRecord, r), True
            r = c.execute(f"""SELECT * FROM times_intelligence.analysis WHERE company_id=%(c)s AND pay_run_id=%(rid)s
                              AND run_fingerprint=%(f)s AND status IN {_LIVE}""", params).fetchone()
            return _build(AnalysisRecord, r), False

    def mark_analysis_running(self, company_id, analysis_id):
        self._all("UPDATE times_intelligence.analysis SET status='RUNNING', started_on=now() WHERE company_id=%(c)s AND id=%(i)s",
                  {"c": company_id, "i": analysis_id})

    def complete_analysis(self, company_id, analysis_id, rec: AnalysisRecord, anomalies: list[AnomalyRecord]):
        with self.conn.connection(self.db) as c, c.transaction():
            c.execute("""UPDATE times_intelligence.analysis SET status=%(s)s, model_registry_id=%(m)s, model_version=%(v)s, detector=%(d)s,
                    ml_status=%(ml)s, total_records=%(tr)s, total_employees=%(te)s, flagged_employees=%(fe)s, anomaly_count=%(ac)s,
                    max_severity=%(ms)s, summary=%(su)s, completed_on=now(),
                    duration_ms=(EXTRACT(EPOCH FROM now() - COALESCE(started_on, requested_on)) * 1000)::bigint, updated_on=now()
                WHERE company_id=%(c)s AND id=%(i)s""",
                      {"s": rec.status, "m": rec.model_registry_id, "v": rec.model_version, "d": rec.detector, "ml": rec.ml_status,
                       "tr": rec.total_records, "te": rec.total_employees, "fe": rec.flagged_employees, "ac": len(anomalies),
                       "ms": rec.max_severity, "su": Jsonb(rec.summary), "c": company_id, "i": analysis_id})
            with c.cursor() as cur:
                cur.executemany("""INSERT INTO times_intelligence.anomaly (analysis_id, company_id, pay_run_id, pay_record_id, user_id,
                        contract_id, anomaly_type, source, rule_id, severity, risk_score, ml_percentile, confidence, metric,
                        current_value, expected_value, expected_low, expected_high, expected_method, change_pct, is_explained,
                        description, recommended_action, evidence, features)
                    VALUES (%(analysis_id)s,%(company_id)s,%(pay_run_id)s,%(pay_record_id)s,%(user_id)s,%(contract_id)s,
                        %(anomaly_type)s,%(source)s,%(rule_id)s,%(severity)s,%(risk_score)s,%(ml_percentile)s,%(confidence)s,
                        %(metric)s,%(current_value)s,%(expected_value)s,%(expected_low)s,%(expected_high)s,%(expected_method)s,
                        %(change_pct)s,%(is_explained)s,%(description)s,%(recommended_action)s,%(evidence)s,%(features)s)""",
                                [{**{f.name: getattr(a, f.name) for f in fields(a)}, "evidence": Jsonb(a.evidence),
                                  "features": Jsonb(a.features)} for a in anomalies])

    def fail_analysis(self, company_id, analysis_id, error_code, error_message):
        self._all("""UPDATE times_intelligence.analysis SET status='FAILED', error_code=%(e)s, error_message=%(m)s, completed_on=now()
                     WHERE company_id=%(c)s AND id=%(i)s""", {"e": error_code, "m": error_message[:500], "c": company_id, "i": analysis_id})

    def get_analysis(self, company_id, analysis_uid):
        r = self._one("SELECT * FROM times_intelligence.analysis WHERE company_id=%(c)s AND uid=%(u)s::uuid",
                      {"c": company_id, "u": _guid(analysis_uid)})
        return _build(AnalysisRecord, r) if r else None

    def get_latest_analysis_for_run(self, company_id, pay_run_uid):
        r = self._one("""SELECT * FROM times_intelligence.analysis WHERE company_id=%(c)s AND pay_run_uid=%(u)s::uuid
                         AND status <> 'SUPERSEDED' ORDER BY requested_on DESC, id DESC LIMIT 1""",
                      {"c": company_id, "u": _guid(pay_run_uid)})
        return _build(AnalysisRecord, r) if r else None

    def list_anomalies(self, company_id, analysis_id, user_ids=None, severity=None, anomaly_type=None, limit=500):
        if user_ids is not None and not user_ids:
            return []
        rows = self._all("""SELECT a.*, fb.code AS latest_feedback FROM times_intelligence.anomaly a
            LEFT JOIN LATERAL (SELECT o.code FROM times_intelligence.feedback f JOIN times_intelligence.lk_feedback_outcome o ON o.id = f.outcome_id
                               WHERE f.anomaly_id = a.id ORDER BY f.created_on DESC, f.id DESC LIMIT 1) fb ON true
            WHERE a.company_id=%(c)s AND a.analysis_id=%(a)s AND (%(u)s::int[] IS NULL OR a.user_id = ANY(%(u)s))
              AND (%(s)s::text IS NULL OR a.severity=%(s)s) AND (%(t)s::text IS NULL OR a.anomaly_type=%(t)s)
            ORDER BY a.risk_score DESC, a.id LIMIT %(n)s""",
                         {"c": company_id, "a": analysis_id, "u": list(user_ids) if user_ids is not None else None,
                          "s": severity, "t": anomaly_type, "n": limit})
        return [_build(AnomalyRecord, r) for r in rows]

    def get_anomaly(self, company_id, anomaly_uid):
        r = self._one("""SELECT a.*, (SELECT o.code FROM times_intelligence.feedback f JOIN times_intelligence.lk_feedback_outcome o ON o.id=f.outcome_id
                WHERE f.anomaly_id=a.id ORDER BY f.created_on DESC, f.id DESC LIMIT 1) AS latest_feedback
            FROM times_intelligence.anomaly a WHERE a.company_id=%(c)s AND a.uid=%(u)s::uuid""", {"c": company_id, "u": _guid(anomaly_uid)})
        return _build(AnomalyRecord, r) if r else None

    # feedback -----------------------------------------------------------------------------------
    def add_feedback(self, company_id, anomaly_id, outcome, comment, reviewer_uid) -> FeedbackRecord:
        r = self._one("""INSERT INTO times_intelligence.feedback (anomaly_id, company_id, outcome_id, comment, reviewer_uid)
            SELECT a.id, a.company_id, %(o)s, %(m)s, %(r)s::uuid FROM times_intelligence.anomaly a WHERE a.id=%(a)s AND a.company_id=%(c)s
            RETURNING *""", {"o": FeedbackOutcome(outcome).db_id, "m": comment, "r": _guid(reviewer_uid), "a": anomaly_id, "c": company_id})
        if r is None:
            raise LookupError("anomaly not found")
        r["outcome"] = outcome
        return _build(FeedbackRecord, r)

    def list_labelled_anomalies(self, company_id, since=None):
        return [_build(AnomalyRecord, r) for r in self._all("""SELECT * FROM (SELECT a.*, (SELECT o.code FROM times_intelligence.feedback f
                JOIN times_intelligence.lk_feedback_outcome o ON o.id=f.outcome_id WHERE f.anomaly_id=a.id
                ORDER BY f.created_on DESC, f.id DESC LIMIT 1) AS latest_feedback
            FROM times_intelligence.anomaly a WHERE a.company_id=%(c)s AND (%(s)s::timestamp IS NULL OR a.created_on >= %(s)s)) x
            WHERE latest_feedback IN ('CONFIRMED_ERROR','EXPECTED_CHANGE','FALSE_POSITIVE')""", {"c": company_id, "s": since})]

    # sweeper / audit ----------------------------------------------------------------------------
    def get_watermarks(self, pay_run_ids):
        return {r["pay_run_id"]: r["last_fingerprint"] for r in self._all(
            "SELECT pay_run_id, last_fingerprint FROM times_intelligence.run_watermark WHERE pay_run_id = ANY(%(i)s)", {"i": list(pay_run_ids)})}

    def upsert_watermark(self, pay_run_id, company_id, fingerprint, enqueued):
        self._all("""INSERT INTO times_intelligence.run_watermark (pay_run_id, company_id, last_fingerprint, last_enqueued_on)
            VALUES (%(r)s,%(c)s,%(f)s, CASE WHEN %(e)s THEN now() END)
            ON CONFLICT (pay_run_id) DO UPDATE SET last_fingerprint=EXCLUDED.last_fingerprint, last_seen_on=now(),
                last_enqueued_on=COALESCE(EXCLUDED.last_enqueued_on, times_intelligence.run_watermark.last_enqueued_on)""",
                  {"r": pay_run_id, "c": company_id, "f": fingerprint, "e": enqueued})

    def add_assistant_audit(self, company_id, analysis_id, user_uid, question_sha256, question_length, tool_calls,
                            llm_model, status, latency_ms):
        self._all("""INSERT INTO times_intelligence.assistant_audit (company_id, analysis_id, user_uid, question_sha256, question_length,
                tool_calls, llm_model, status, latency_ms) VALUES (%(c)s,%(a)s,%(u)s::uuid,%(h)s,%(l)s,%(t)s,%(m)s,%(s)s,%(ms)s)""",
                  {"c": company_id, "a": analysis_id, "u": _guid(user_uid), "h": question_sha256, "l": question_length,
                   "t": Jsonb(tool_calls), "m": llm_model, "s": status, "ms": latency_ms})


