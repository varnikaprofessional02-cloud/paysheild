-- =====================================================================================
-- Times Intelligence — V001: isolated schema "times_intelligence" (one per subscription database).
-- Module 1: PayShield AI. Nothing outside this schema is created or altered.
--
-- Run against EVERY tenant database (tenant-store tenant.tenant.db_name) AND against the
-- template database used to provision new tenants ("times-template-db-readonly").
-- Idempotent: safe to re-run. Does not alter any existing schema object.
-- Requires: PostgreSQL 13+ (gen_random_uuid() is core since 13).
-- =====================================================================================

CREATE SCHEMA IF NOT EXISTS times_intelligence;

COMMENT ON SCHEMA times_intelligence IS
    'PayShield AI: per-company payroll anomaly models, analyses, findings and reviewer feedback. Advisory only - never blocks payroll.';

-- -------------------------------------------------------------------------------------
-- Lookups
-- -------------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS times_intelligence.lk_feedback_outcome (
    id          smallint    NOT NULL,
    code        text        NOT NULL,
    name        text        NOT NULL,
    description text,
    created_on  timestamp   NOT NULL DEFAULT now(),
    created_by  text                 DEFAULT 'Admin',
    CONSTRAINT lk_feedback_outcome_pkey PRIMARY KEY (id),
    CONSTRAINT lk_feedback_outcome_code_key UNIQUE (code)
);

INSERT INTO times_intelligence.lk_feedback_outcome (id, code, name, description) VALUES
    (1, 'CONFIRMED_ERROR',     'Confirmed error',     'The finding was a real payroll error.'),
    (2, 'EXPECTED_CHANGE',     'Expected change',     'The change is legitimate (promotion, bonus, policy).'),
    (3, 'FALSE_POSITIVE',      'False positive',      'Nothing unusual; the finding should not have been raised.'),
    (4, 'NEEDS_INVESTIGATION', 'Needs investigation', 'Not yet resolved.')
ON CONFLICT (id) DO UPDATE
    SET code = EXCLUDED.code, name = EXCLUDED.name, description = EXCLUDED.description;


-- -------------------------------------------------------------------------------------
-- Times Intelligence subscription (per company inside this subscription DB)
-- -------------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS times_intelligence.subscription (
    id               bigint      GENERATED ALWAYS AS IDENTITY,
    uid              uuid        NOT NULL DEFAULT gen_random_uuid(),
    company_id       integer     NOT NULL,
    status           text        NOT NULL DEFAULT 'ACTIVE',
    modules          text[]      NOT NULL DEFAULT ARRAY['PAYSHIELD'],
    subscribed_on    timestamptz NOT NULL DEFAULT now(),
    subscribed_by    text        NOT NULL,
    cancelled_on     timestamptz,
    cancelled_by     text,
    created_on       timestamp   NOT NULL DEFAULT now(),
    created_by       text                 DEFAULT 'Admin',
    updated_on       timestamp,
    updated_by       text,
    CONSTRAINT subscription_pkey PRIMARY KEY (id),
    CONSTRAINT subscription_uid_key UNIQUE (uid),
    CONSTRAINT subscription_company_key UNIQUE (company_id),
    CONSTRAINT subscription_company_fkey FOREIGN KEY (company_id) REFERENCES company.company (id) ON DELETE CASCADE,
    CONSTRAINT subscription_status_check CHECK (status IN ('ACTIVE', 'CANCELLED')),
    CONSTRAINT subscription_modules_check CHECK (modules <@ ARRAY['PAYSHIELD']::text[])
);

-- -------------------------------------------------------------------------------------
-- Per-company configuration (thresholds override service defaults; see docs/03_RISK_SCORING.md)
-- -------------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS times_intelligence.company_setting (
    id                   bigint      GENERATED ALWAYS AS IDENTITY,
    uid                  uuid        NOT NULL DEFAULT gen_random_uuid(),
    company_id           integer     NOT NULL,
    is_enabled           boolean     NOT NULL DEFAULT true,
    auto_analyze         boolean     NOT NULL DEFAULT true,
    auto_activate_models boolean     NOT NULL DEFAULT true,
    overtime_pay_codes   text[]      NOT NULL DEFAULT '{}',
    thresholds           jsonb       NOT NULL DEFAULT '{}'::jsonb,
    created_on           timestamp   NOT NULL DEFAULT now(),
    created_by           text                 DEFAULT 'Admin',
    updated_on           timestamp,
    updated_by           text,
    CONSTRAINT company_setting_pkey PRIMARY KEY (id),
    CONSTRAINT company_setting_uid_key UNIQUE (uid),
    CONSTRAINT company_setting_company_key UNIQUE (company_id),
    CONSTRAINT company_setting_company_fkey FOREIGN KEY (company_id)
        REFERENCES company.company (id) ON DELETE CASCADE,
    CONSTRAINT company_setting_thresholds_is_object CHECK (jsonb_typeof(thresholds) = 'object')
);

-- -------------------------------------------------------------------------------------
-- Training jobs (one QUEUED/RUNNING job per company at a time)
-- -------------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS times_intelligence.training_job (
    id                bigint      GENERATED ALWAYS AS IDENTITY,
    uid               uuid        NOT NULL DEFAULT gen_random_uuid(),
    tenant_uid        uuid        NOT NULL,
    company_id        integer     NOT NULL,
    trigger           text        NOT NULL,
    status            text        NOT NULL DEFAULT 'QUEUED',
    attempt           integer     NOT NULL DEFAULT 1,
    requested_by      text        NOT NULL DEFAULT 'System',
    requested_on      timestamptz NOT NULL DEFAULT now(),
    started_on        timestamptz,
    heartbeat_on      timestamptz,
    completed_on      timestamptz,
    duration_ms       bigint,
    model_registry_id bigint,
    metrics           jsonb       NOT NULL DEFAULT '{}'::jsonb,
    error_code        text,
    error_message     text,
    created_on        timestamp   NOT NULL DEFAULT now(),
    created_by        text                 DEFAULT 'Admin',
    updated_on        timestamp,
    updated_by        text,
    CONSTRAINT training_job_pkey PRIMARY KEY (id),
    CONSTRAINT training_job_uid_key UNIQUE (uid),
    CONSTRAINT training_job_company_fkey FOREIGN KEY (company_id)
        REFERENCES company.company (id) ON DELETE CASCADE,
    CONSTRAINT training_job_trigger_check CHECK (trigger IN ('INITIAL', 'MANUAL', 'SCHEDULED', 'RECOVERY')),
    CONSTRAINT training_job_status_check CHECK (status IN
        ('QUEUED', 'RUNNING', 'SUCCEEDED', 'REJECTED', 'INSUFFICIENT_DATA', 'FAILED', 'CANCELLED')),
    CONSTRAINT training_job_attempt_check CHECK (attempt >= 1)
);

-- prevents overlapping training for the same company
CREATE UNIQUE INDEX IF NOT EXISTS ux_training_job_company_active
    ON times_intelligence.training_job (company_id) WHERE status IN ('QUEUED', 'RUNNING');
CREATE INDEX IF NOT EXISTS ix_training_job_company_requested
    ON times_intelligence.training_job (company_id, requested_on DESC);

-- -------------------------------------------------------------------------------------
-- Model registry (artifacts live in tenant/company-scoped blob paths; sha256 verified before load)
-- -------------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS times_intelligence.model_registry (
    id                     bigint      GENERATED ALWAYS AS IDENTITY,
    uid                    uuid        NOT NULL DEFAULT gen_random_uuid(),
    tenant_uid             uuid        NOT NULL,
    company_id             integer     NOT NULL,
    company_uid            uuid        NOT NULL,
    model_version          text        NOT NULL,
    model_type             text        NOT NULL,
    detector               text        NOT NULL,
    feature_schema_version text        NOT NULL,
    training_job_id        bigint,
    training_started_at    timestamptz NOT NULL,
    training_completed_at  timestamptz NOT NULL,
    training_record_count  integer     NOT NULL,
    training_period_start  date        NOT NULL,
    training_period_end    date        NOT NULL,
    evaluation_metrics     jsonb       NOT NULL DEFAULT '{}'::jsonb,
    model_storage_location text        NOT NULL,
    artifact_sha256        text        NOT NULL,
    artifact_size_bytes    bigint      NOT NULL,
    model_status           text        NOT NULL DEFAULT 'TRAINED',
    status_reason          text,
    activated_on           timestamptz,
    activated_by           text,
    retired_on             timestamptz,
    created_on             timestamp   NOT NULL DEFAULT now(),
    created_by             text                 DEFAULT 'Admin',
    updated_on             timestamp,
    updated_by             text,
    CONSTRAINT model_registry_pkey PRIMARY KEY (id),
    CONSTRAINT model_registry_uid_key UNIQUE (uid),
    CONSTRAINT model_registry_company_version_key UNIQUE (company_id, model_version),
    CONSTRAINT model_registry_company_fkey FOREIGN KEY (company_id)
        REFERENCES company.company (id) ON DELETE CASCADE,
    CONSTRAINT model_registry_training_job_fkey FOREIGN KEY (training_job_id)
        REFERENCES times_intelligence.training_job (id) ON DELETE SET NULL,
    CONSTRAINT model_registry_type_check CHECK (model_type IN ('ISOLATION_FOREST')),
    CONSTRAINT model_registry_detector_check CHECK (detector IN ('ISOLATION_FOREST', 'ROBUST_BASELINE')),
    CONSTRAINT model_registry_status_check CHECK (model_status IN ('TRAINED', 'ACTIVE', 'REJECTED', 'RETIRED')),
    CONSTRAINT model_registry_sha256_check CHECK (artifact_sha256 ~ '^[0-9a-f]{64}$'),
    CONSTRAINT model_registry_period_check CHECK (training_period_end >= training_period_start)
);

-- exactly one active model per company
CREATE UNIQUE INDEX IF NOT EXISTS ux_model_registry_company_active
    ON times_intelligence.model_registry (company_id) WHERE model_status = 'ACTIVE';
CREATE INDEX IF NOT EXISTS ix_model_registry_company_created
    ON times_intelligence.model_registry (company_id, created_on DESC);

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'training_job_model_registry_fkey') THEN
        ALTER TABLE times_intelligence.training_job
            ADD CONSTRAINT training_job_model_registry_fkey FOREIGN KEY (model_registry_id)
                REFERENCES times_intelligence.model_registry (id) ON DELETE SET NULL;
    END IF;
END $$;

-- -------------------------------------------------------------------------------------
-- Payroll analyses (one row per analysis of a pay run)
-- -------------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS times_intelligence.analysis (
    id                 bigint      GENERATED ALWAYS AS IDENTITY,
    uid                uuid        NOT NULL DEFAULT gen_random_uuid(),
    tenant_uid         uuid        NOT NULL,
    company_id         integer     NOT NULL,
    pay_run_id         bigint      NOT NULL,
    pay_run_uid        uuid        NOT NULL,
    period             date        NOT NULL,
    cycle_code         text,
    is_trial_run       boolean     NOT NULL DEFAULT false,
    trigger            text        NOT NULL,
    status             text        NOT NULL DEFAULT 'QUEUED',
    run_fingerprint    text        NOT NULL,
    model_registry_id  bigint,
    model_version      text,
    detector           text,
    ml_status          text,
    total_records      integer     NOT NULL DEFAULT 0,
    total_employees    integer     NOT NULL DEFAULT 0,
    flagged_employees  integer     NOT NULL DEFAULT 0,
    anomaly_count      integer     NOT NULL DEFAULT 0,
    max_severity       text,
    summary            jsonb       NOT NULL DEFAULT '{}'::jsonb,
    error_code         text,
    error_message      text,
    requested_by       text        NOT NULL DEFAULT 'System',
    requested_on       timestamptz NOT NULL DEFAULT now(),
    started_on         timestamptz,
    completed_on       timestamptz,
    duration_ms        bigint,
    created_on         timestamp   NOT NULL DEFAULT now(),
    created_by         text                 DEFAULT 'Admin',
    updated_on         timestamp,
    updated_by         text,
    CONSTRAINT analysis_pkey PRIMARY KEY (id),
    CONSTRAINT analysis_uid_key UNIQUE (uid),
    CONSTRAINT analysis_company_fkey FOREIGN KEY (company_id)
        REFERENCES company.company (id) ON DELETE CASCADE,
    CONSTRAINT analysis_pay_run_fkey FOREIGN KEY (pay_run_id)
        REFERENCES payroll.pay_run (id) ON DELETE CASCADE,
    CONSTRAINT analysis_model_registry_fkey FOREIGN KEY (model_registry_id)
        REFERENCES times_intelligence.model_registry (id) ON DELETE SET NULL,
    CONSTRAINT analysis_trigger_check CHECK (trigger IN ('MANUAL', 'SWEEPER', 'EVENT', 'API')),
    CONSTRAINT analysis_status_check CHECK (status IN
        ('QUEUED', 'RUNNING', 'COMPLETED', 'COMPLETED_WITH_WARNINGS', 'FAILED', 'SUPERSEDED')),
    CONSTRAINT analysis_ml_status_check CHECK (ml_status IS NULL OR ml_status IN
        ('SCORED', 'NO_ACTIVE_MODEL', 'MODEL_UNAVAILABLE', 'DISABLED', 'BASELINE_PREFERRED')),
    CONSTRAINT analysis_max_severity_check CHECK (max_severity IS NULL OR max_severity IN
        ('LOW', 'MEDIUM', 'HIGH', 'CRITICAL'))
);

-- idempotency: one live analysis per run fingerprint (re-analysis supersedes the previous one first)
CREATE UNIQUE INDEX IF NOT EXISTS ux_analysis_run_fingerprint_live
    ON times_intelligence.analysis (pay_run_id, run_fingerprint)
    WHERE status IN ('QUEUED', 'RUNNING', 'COMPLETED', 'COMPLETED_WITH_WARNINGS');
CREATE INDEX IF NOT EXISTS ix_analysis_pay_run_requested
    ON times_intelligence.analysis (pay_run_id, requested_on DESC);
CREATE INDEX IF NOT EXISTS ix_analysis_company_requested
    ON times_intelligence.analysis (company_id, requested_on DESC);

-- -------------------------------------------------------------------------------------
-- Findings
-- -------------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS times_intelligence.anomaly (
    id               bigint        GENERATED ALWAYS AS IDENTITY,
    uid              uuid          NOT NULL DEFAULT gen_random_uuid(),
    analysis_id      bigint        NOT NULL,
    company_id       integer       NOT NULL,
    pay_run_id       bigint        NOT NULL,
    pay_record_id    bigint,
    user_id          integer       NOT NULL,
    contract_id      bigint,
    anomaly_type     text          NOT NULL,
    source           text          NOT NULL,
    rule_id          text,
    severity         text          NOT NULL,
    risk_score       smallint      NOT NULL,
    ml_percentile    numeric(5, 2),
    confidence       text          NOT NULL DEFAULT 'MEDIUM',
    metric           text,
    current_value    numeric(18, 2),
    expected_value   numeric(18, 2),
    expected_low     numeric(18, 2),
    expected_high    numeric(18, 2),
    expected_method  text,
    change_pct       numeric(12, 2),
    is_explained     boolean       NOT NULL DEFAULT false,
    description      text          NOT NULL,
    recommended_action text,
    evidence         jsonb         NOT NULL DEFAULT '[]'::jsonb,
    features         jsonb         NOT NULL DEFAULT '{}'::jsonb,
    created_on       timestamp     NOT NULL DEFAULT now(),
    created_by       text                   DEFAULT 'Admin',
    CONSTRAINT anomaly_pkey PRIMARY KEY (id),
    CONSTRAINT anomaly_uid_key UNIQUE (uid),
    CONSTRAINT anomaly_analysis_fkey FOREIGN KEY (analysis_id)
        REFERENCES times_intelligence.analysis (id) ON DELETE CASCADE,
    CONSTRAINT anomaly_pay_record_fkey FOREIGN KEY (pay_record_id)
        REFERENCES payroll.pay_record (id) ON DELETE SET NULL,
    CONSTRAINT anomaly_source_check CHECK (source IN ('RULE', 'ML', 'BASELINE', 'STATUTORY', 'DATA_QUALITY')),
    CONSTRAINT anomaly_severity_check CHECK (severity IN ('LOW', 'MEDIUM', 'HIGH', 'CRITICAL')),
    CONSTRAINT anomaly_confidence_check CHECK (confidence IN ('LOW', 'MEDIUM', 'HIGH')),
    CONSTRAINT anomaly_risk_score_check CHECK (risk_score BETWEEN 0 AND 100),
    CONSTRAINT anomaly_ml_percentile_check CHECK (ml_percentile IS NULL OR ml_percentile BETWEEN 0 AND 100),
    CONSTRAINT anomaly_evidence_is_array CHECK (jsonb_typeof(evidence) = 'array')
);

CREATE INDEX IF NOT EXISTS ix_anomaly_analysis_severity ON times_intelligence.anomaly (analysis_id, risk_score DESC);
CREATE INDEX IF NOT EXISTS ix_anomaly_company_user ON times_intelligence.anomaly (company_id, user_id, created_on DESC);
CREATE INDEX IF NOT EXISTS ix_anomaly_pay_record ON times_intelligence.anomaly (pay_record_id);

-- -------------------------------------------------------------------------------------
-- Reviewer feedback (append-only; latest row per anomaly wins)
-- -------------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS times_intelligence.feedback (
    id            bigint      GENERATED ALWAYS AS IDENTITY,
    uid           uuid        NOT NULL DEFAULT gen_random_uuid(),
    anomaly_id    bigint      NOT NULL,
    company_id    integer     NOT NULL,
    outcome_id    smallint    NOT NULL,
    comment       text,
    reviewer_uid  uuid        NOT NULL,
    created_on    timestamptz NOT NULL DEFAULT now(),
    created_by    text                 DEFAULT 'Admin',
    CONSTRAINT feedback_pkey PRIMARY KEY (id),
    CONSTRAINT feedback_uid_key UNIQUE (uid),
    CONSTRAINT feedback_anomaly_fkey FOREIGN KEY (anomaly_id)
        REFERENCES times_intelligence.anomaly (id) ON DELETE CASCADE,
    CONSTRAINT feedback_outcome_fkey FOREIGN KEY (outcome_id)
        REFERENCES times_intelligence.lk_feedback_outcome (id),
    CONSTRAINT feedback_company_fkey FOREIGN KEY (company_id)
        REFERENCES company.company (id) ON DELETE CASCADE,
    CONSTRAINT feedback_comment_length CHECK (comment IS NULL OR length(comment) <= 2000)
);

CREATE INDEX IF NOT EXISTS ix_feedback_anomaly_created ON times_intelligence.feedback (anomaly_id, created_on DESC);
CREATE INDEX IF NOT EXISTS ix_feedback_company_created ON times_intelligence.feedback (company_id, created_on DESC);

-- -------------------------------------------------------------------------------------
-- Sweeper watermark (detects settled pay runs without changing payroll-api)
-- -------------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS times_intelligence.run_watermark (
    pay_run_id        bigint      NOT NULL,
    company_id        integer     NOT NULL,
    last_fingerprint  text        NOT NULL,
    last_seen_on      timestamptz NOT NULL DEFAULT now(),
    last_enqueued_on  timestamptz,
    CONSTRAINT run_watermark_pkey PRIMARY KEY (pay_run_id),
    CONSTRAINT run_watermark_pay_run_fkey FOREIGN KEY (pay_run_id)
        REFERENCES payroll.pay_run (id) ON DELETE CASCADE
);

-- -------------------------------------------------------------------------------------
-- Assistant audit (no question text or answers stored: only a hash, tools used and outcome)
-- -------------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS times_intelligence.assistant_audit (
    id              bigint      GENERATED ALWAYS AS IDENTITY,
    uid             uuid        NOT NULL DEFAULT gen_random_uuid(),
    company_id      integer     NOT NULL,
    analysis_id     bigint,
    user_uid        uuid        NOT NULL,
    question_sha256 text        NOT NULL,
    question_length integer     NOT NULL,
    tool_calls      jsonb       NOT NULL DEFAULT '[]'::jsonb,
    llm_model       text,
    status          text        NOT NULL,
    latency_ms      bigint,
    created_on      timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT assistant_audit_pkey PRIMARY KEY (id),
    CONSTRAINT assistant_audit_uid_key UNIQUE (uid),
    CONSTRAINT assistant_audit_company_fkey FOREIGN KEY (company_id)
        REFERENCES company.company (id) ON DELETE CASCADE,
    CONSTRAINT assistant_audit_analysis_fkey FOREIGN KEY (analysis_id)
        REFERENCES times_intelligence.analysis (id) ON DELETE SET NULL,
    CONSTRAINT assistant_audit_status_check CHECK (status IN ('ANSWERED', 'FALLBACK', 'REFUSED', 'FAILED'))
);

CREATE INDEX IF NOT EXISTS ix_assistant_audit_company_created ON times_intelligence.assistant_audit (company_id, created_on DESC);

-- -------------------------------------------------------------------------------------
-- Read-path index on existing payroll tables? NO: PayShield does not add indexes to payroll.*.
-- The sweeper enumerates recent pay_run rows (small) and aggregates pay_record through the
-- existing unique index ux_pay_record_run_user_contract (pay_run_id, user_id, contract_id).
-- -------------------------------------------------------------------------------------

-- -------------------------------------------------------------------------------------
-- Schema version marker
-- -------------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS times_intelligence.schema_version (
    version     integer     NOT NULL,
    description text        NOT NULL,
    applied_on  timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT schema_version_pkey PRIMARY KEY (version)
);

INSERT INTO times_intelligence.schema_version (version, description)
VALUES (1, 'times_intelligence schema: subscription, settings, registry, jobs, analyses, anomalies, feedback, watermark, audit')
ON CONFLICT (version) DO NOTHING;
