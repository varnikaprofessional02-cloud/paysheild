-- V002: training areas. Payroll keeps using model_registry; every other area (Identification and the demo areas)
-- records its trained version here. Idempotent: safe to run more than once.

CREATE TABLE IF NOT EXISTS times_intelligence.area_model (
    id              bigint      GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    uid             uuid        NOT NULL DEFAULT gen_random_uuid() UNIQUE,
    company_id      integer     NOT NULL,
    area            text        NOT NULL,          -- IDENTIFICATION, ATTENDANCE, EPM, TIMESHEET, CLAIMS
    version         integer     NOT NULL,
    status          text        NOT NULL DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE', 'SUPERSEDED')),
    is_mock         boolean     NOT NULL DEFAULT false,
    record_count    integer     NOT NULL DEFAULT 0,
    duration_ms     integer     NOT NULL DEFAULT 0,
    summary         jsonb       NOT NULL DEFAULT '{}'::jsonb,
    baseline        jsonb,                         -- e.g. hashed identifiers per employee (never raw values)
    trained_on      timestamptz NOT NULL DEFAULT now(),
    trained_by      text        NOT NULL,
    CONSTRAINT area_model_company_fkey FOREIGN KEY (company_id) REFERENCES company.company (id) ON DELETE CASCADE
);

CREATE UNIQUE INDEX IF NOT EXISTS area_model_active_uq
    ON times_intelligence.area_model (company_id, area) WHERE status = 'ACTIVE';

ALTER TABLE times_intelligence.training_job ADD COLUMN IF NOT EXISTS areas text[] NOT NULL DEFAULT ARRAY['PAYROLL'];

INSERT INTO times_intelligence.schema_version (version, description)
SELECT 2, 'training areas' WHERE NOT EXISTS (SELECT 1 FROM times_intelligence.schema_version WHERE version = 2);
