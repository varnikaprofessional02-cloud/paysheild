-- local test DBs only: columns that exist in current times-payroll-api code but not in the 2026-09-28 dump
ALTER TABLE payroll.pay_run ADD COLUMN IF NOT EXISTS is_trial boolean NOT NULL DEFAULT false;
