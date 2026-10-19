-- =====================================================================================
-- PayShield AI: least-privilege grants for the service login (run per tenant DB + template DB,
-- after V001). The role is cluster-wide; a DBA creates it once with a password from Key Vault:
--   CREATE ROLE payshield_svc LOGIN PASSWORD '<from key vault>';
-- (or map an Entra managed identity to it on Azure Database for PostgreSQL). Idempotent.
-- =====================================================================================
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'payshield_svc') THEN
    CREATE ROLE payshield_svc NOLOGIN;  -- placeholder; DBA enables LOGIN + password
  END IF;
END $$;

DO $$ BEGIN EXECUTE format('GRANT CONNECT ON DATABASE %I TO payshield_svc', current_database()); END $$;

GRANT USAGE ON SCHEMA payroll, employee, company, security, times_intelligence, public TO payshield_svc;

-- read-only: exactly the tables PayShield reads
GRANT SELECT ON payroll.pay_record, payroll.pay_run, payroll.pay_period, payroll.lk_payroll_cycle TO payshield_svc;
GRANT SELECT ON employee.user_company_contract, employee.career_progression, employee.contract_allowance_deduction,
                employee.lk_recurring_method TO payshield_svc;
GRANT SELECT ON company.company, company.company_status, company.code_setup, company.allowance_deduction,
                company.allowance_deduction_type, company.allowance_deduction_cpf, company.allowance_deduction_bonus_type,
                company.allowance_deduction_unit TO payshield_svc;
-- security."user" is read for uid -> id and employee number joins only (no names are selected by the service)
GRANT SELECT ON security."user", security.user_company, security.access_rules TO payshield_svc;
-- the permission function is SECURITY INVOKER (LANGUAGE sql STABLE), so its tables above must be readable
GRANT EXECUTE ON FUNCTION security.get_permissions_for_principle_on_resource(text, public.resource_type_enum, text, uuid) TO payshield_svc;

-- read/write on PayShield's own schema only
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA times_intelligence TO payshield_svc;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA times_intelligence TO payshield_svc;
ALTER DEFAULT PRIVILEGES IN SCHEMA times_intelligence GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO payshield_svc;
-- no UPDATE/DELETE on payroll.*: PayShield can never modify payroll
