-- PayShield AI: run on the tenant-store database. Read-only access to tenant -> db_name / realm mapping.
DO $$ BEGIN EXECUTE format('GRANT CONNECT ON DATABASE %I TO payshield_svc', current_database()); END $$;
GRANT USAGE ON SCHEMA tenant TO payshield_svc;
GRANT SELECT ON tenant.tenant, tenant.tenant_identity_provider TO payshield_svc;
