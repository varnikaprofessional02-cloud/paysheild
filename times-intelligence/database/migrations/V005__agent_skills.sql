-- V005: teach the PayShield Agent. Idempotent: safe to run more than once.
--
-- agent_skill: something a user taught the agent. Example questions (phrases) are matched against new questions
--   (word overlap, no LLM). kind ANSWER replies with the taught text; kind ROUTE answers as if the user had asked
--   another question the agent already knows (e.g. "big earners" -> "Top 10 highest paid").
-- agent_gap: questions the agent could not answer, so a user can teach them later.

CREATE TABLE IF NOT EXISTS times_intelligence.agent_skill (
    id              bigint      GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    uid             uuid        NOT NULL DEFAULT gen_random_uuid() UNIQUE,
    company_id      integer     NOT NULL,
    phrases         text[]      NOT NULL,
    kind            text        NOT NULL CHECK (kind IN ('ANSWER', 'ROUTE')),
    answer          text,
    route           text,
    is_active       boolean     NOT NULL DEFAULT true,
    used_count      integer     NOT NULL DEFAULT 0,
    last_used_on    timestamptz,
    helpful         integer     NOT NULL DEFAULT 0,
    not_helpful     integer     NOT NULL DEFAULT 0,
    created_by      text        NOT NULL,
    created_on      timestamptz NOT NULL DEFAULT now(),
    updated_by      text,
    updated_on      timestamptz,
    CONSTRAINT agent_skill_company_fkey FOREIGN KEY (company_id) REFERENCES company.company (id) ON DELETE CASCADE,
    CONSTRAINT agent_skill_content_chk CHECK ((kind = 'ANSWER' AND answer IS NOT NULL) OR (kind = 'ROUTE' AND route IS NOT NULL))
);
CREATE INDEX IF NOT EXISTS agent_skill_company_ix ON times_intelligence.agent_skill (company_id) WHERE is_active;

CREATE TABLE IF NOT EXISTS times_intelligence.agent_gap (
    id              bigint      GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    uid             uuid        NOT NULL DEFAULT gen_random_uuid() UNIQUE,
    company_id      integer     NOT NULL,
    question        text        NOT NULL,
    norm            text        NOT NULL,           -- normalised words, one row per distinct question
    times_asked     integer     NOT NULL DEFAULT 1,
    first_asked     timestamptz NOT NULL DEFAULT now(),
    last_asked      timestamptz NOT NULL DEFAULT now(),
    resolved_by_skill bigint,
    CONSTRAINT agent_gap_company_fkey FOREIGN KEY (company_id) REFERENCES company.company (id) ON DELETE CASCADE,
    CONSTRAINT agent_gap_uq UNIQUE (company_id, norm)
);

INSERT INTO times_intelligence.schema_version (version, description)
SELECT 5, 'agent skills' WHERE NOT EXISTS (SELECT 1 FROM times_intelligence.schema_version WHERE version = 5);
