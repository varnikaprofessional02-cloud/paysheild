-- PayShield AI: remove the payshield schema from a tenant DB. DESTROYS all PayShield models registry rows,
-- analyses, findings and reviewer feedback (payroll data is untouched). Export first if feedback must be kept.
-- Model files in blob storage (tenants/<tenant>/companies/<company>/...) must be deleted separately.
REVOKE ALL ON ALL TABLES IN SCHEMA times_intelligence FROM payshield_svc;
DROP SCHEMA IF EXISTS times_intelligence CASCADE;
