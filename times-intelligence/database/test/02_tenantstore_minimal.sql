-- local test only: minimal tenant-store tables read by PayShield (column names from TimesTenantStore.cs)
CREATE SCHEMA IF NOT EXISTS tenant;
CREATE TABLE IF NOT EXISTS tenant.tenant (id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY, identifier uuid NOT NULL UNIQUE,
  name text NOT NULL, db_name text, subdomain text);
CREATE TABLE IF NOT EXISTS tenant.identity_provider (id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY, name text NOT NULL);
CREATE TABLE IF NOT EXISTS tenant.tenant_identity_provider (id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  tenant_id bigint NOT NULL REFERENCES tenant.tenant(id), identity_provider_id bigint NOT NULL REFERENCES tenant.identity_provider(id),
  instance_code text NOT NULL, active boolean NOT NULL DEFAULT true);
