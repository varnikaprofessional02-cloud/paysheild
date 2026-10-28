-- V003: PayShield decisions on identity findings, and the release of a pay run once its Pay Score is 100.
-- Idempotent: safe to run more than once.

-- Fix / Accept on an Identification finding of one pay run (payroll findings use times_intelligence.feedback)
CREATE TABLE IF NOT EXISTS times_intelligence.identity_decision (
    id              bigint      GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    company_id      integer     NOT NULL,
    pay_run_id      bigint      NOT NULL,
    employee_no     text        NOT NULL,
    anomaly_type    text        NOT NULL,          -- e.g. SHARED_BANK_ACCOUNT, WORK_PASS_EXPIRED
    outcome         text        NOT NULL CHECK (outcome IN ('CONFIRMED_ERROR', 'EXPECTED_CHANGE', 'FALSE_POSITIVE', 'NEEDS_INVESTIGATION')),
    decided_by      text        NOT NULL,
    decided_on      timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT identity_decision_company_fkey FOREIGN KEY (company_id) REFERENCES company.company (id) ON DELETE CASCADE,
    CONSTRAINT identity_decision_run_fkey FOREIGN KEY (pay_run_id) REFERENCES payroll.pay_run (id) ON DELETE CASCADE
);
CREATE INDEX IF NOT EXISTS identity_decision_run_ix ON times_intelligence.identity_decision (company_id, pay_run_id, employee_no, anomaly_type, decided_on DESC);

-- A pay run released by PayShield: every finding was fixed or accepted (Pay Score 100); the pay run is then locked
CREATE TABLE IF NOT EXISTS times_intelligence.pay_run_release (
    id              bigint      GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    uid             uuid        NOT NULL DEFAULT gen_random_uuid() UNIQUE,
    company_id      integer     NOT NULL,
    pay_run_id      bigint      NOT NULL UNIQUE,
    analysis_id     bigint,
    pay_score       integer     NOT NULL,
    findings        integer     NOT NULL DEFAULT 0, -- resolved before release
    headcount       integer     NOT NULL,
    gross           numeric(14, 2),
    net             numeric(14, 2),
    released_by     text        NOT NULL,
    released_on     timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT pay_run_release_company_fkey FOREIGN KEY (company_id) REFERENCES company.company (id) ON DELETE CASCADE,
    CONSTRAINT pay_run_release_run_fkey FOREIGN KEY (pay_run_id) REFERENCES payroll.pay_run (id) ON DELETE CASCADE
);

INSERT INTO times_intelligence.schema_version (version, description)
SELECT 3, 'pay run release' WHERE NOT EXISTS (SELECT 1 FROM times_intelligence.schema_version WHERE version = 3);
