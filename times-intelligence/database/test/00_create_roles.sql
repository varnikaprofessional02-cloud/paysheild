-- local test clusters only: roles referenced by the tenant schema dump (cluster-wide)
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'timesadmin') THEN CREATE ROLE timesadmin; END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'azure_pg_admin') THEN CREATE ROLE azure_pg_admin; END IF;
END $$;
