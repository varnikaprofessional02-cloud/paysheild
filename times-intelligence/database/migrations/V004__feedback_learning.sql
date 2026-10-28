-- V004: the company model learns from review decisions. Idempotent: safe to run more than once.
--
-- When a reviewer accepts a finding as expected (EXPECTED_CHANGE / FALSE_POSITIVE), the accepted value becomes a learned
-- pattern for that employee: the same kind of finding at about the same value is not raised again. Marking it a real
-- error (CONFIRMED_ERROR) or asking to investigate removes the pattern again.

CREATE TABLE IF NOT EXISTS times_intelligence.learned_pattern (
    id                  bigint      GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    uid                 uuid        NOT NULL DEFAULT gen_random_uuid() UNIQUE,
    company_id          integer     NOT NULL,
    user_id             bigint      NOT NULL,
    anomaly_type        text        NOT NULL,
    metric              text,
    accepted_value      numeric(14, 2),             -- NULL: any value of this finding type is accepted
    tolerance_pct       numeric(5, 2) NOT NULL DEFAULT 5,
    outcome             text        NOT NULL,       -- EXPECTED_CHANGE or FALSE_POSITIVE
    source_anomaly_id   bigint,
    description         text,                       -- the finding that was accepted
    is_active           boolean     NOT NULL DEFAULT true,
    applied_count       integer     NOT NULL DEFAULT 0,
    last_applied_on     timestamptz,
    learned_by          text        NOT NULL,
    learned_on          timestamptz NOT NULL DEFAULT now(),
    forgotten_by        text,
    forgotten_on        timestamptz,
    CONSTRAINT learned_pattern_company_fkey FOREIGN KEY (company_id) REFERENCES company.company (id) ON DELETE CASCADE
);
CREATE INDEX IF NOT EXISTS learned_pattern_active_ix
    ON times_intelligence.learned_pattern (company_id, user_id, anomaly_type) WHERE is_active;

INSERT INTO times_intelligence.schema_version (version, description)
SELECT 4, 'feedback learning' WHERE NOT EXISTS (SELECT 1 FROM times_intelligence.schema_version WHERE version = 4);
