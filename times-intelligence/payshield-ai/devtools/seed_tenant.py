"""Dev/test only: write a SyntheticCompany into a tenant database built from the real schema dump.
Synthetic ids are inserted as-is (OVERRIDING SYSTEM VALUE) so domain objects and rows line up."""

from __future__ import annotations

import json

import psycopg

from app.data.data_processed_builder import build_data_processed
from app.data.synthetic import SyntheticCompany
from app.domain.models import PayRecordSnapshot, PayRunRef, SalaryRevision

OV = "OVERRIDING SYSTEM VALUE"


def seed_lookups(c: psycopg.Connection) -> None:
    c.execute(f"""
    INSERT INTO company.company_status (id, name) {OV} VALUES (1,'Active') ON CONFLICT DO NOTHING;
    INSERT INTO security.user_status (id, status, name) {OV} VALUES (1,'Active','Active') ON CONFLICT DO NOTHING;
    INSERT INTO payroll.lk_pay_run_status (id, name) {OV} VALUES (1,'Processing'),(2,'Completed'),(3,'Failed'),(4,'Locked'),(5,'Trial'),(6,'Skipped') ON CONFLICT DO NOTHING;
    INSERT INTO payroll.lk_payroll_cycle (id, name, code, short_code) {OV} VALUES (1,'Mid Month','MID','MM'),(2,'End Month','END','EM'),(3,'Special','SPECIAL','SP'),(4,'Bonus','BONUS','BN') ON CONFLICT DO NOTHING;
    INSERT INTO company.allowance_deduction_type (id, code, name) {OV} VALUES (1,'EARNING','Earning'),(2,'DEDUCTION','Deduction') ON CONFLICT DO NOTHING;
    INSERT INTO company.allowance_deduction_cpf (id, code, name) {OV} VALUES (1,'OW','Ordinary'),(2,'AW','Additional'),(3,'NONE','None') ON CONFLICT DO NOTHING;
    INSERT INTO company.allowance_deduction_bonus_type (id, code, name) {OV} VALUES (1,'NONBONU','Non bonus'),(2,'BONU','Bonus'),(3,'PREBONU','Previous year bonus') ON CONFLICT DO NOTHING;
    INSERT INTO company.allowance_deduction_unit (id, code, name) {OV} VALUES (1,'HOUR','Hour'),(2,'DAY','Day') ON CONFLICT DO NOTHING;
    INSERT INTO company.allowance_deduction_tax (id, code, name) {OV} VALUES (1,'TAX','Taxable') ON CONFLICT DO NOTHING;
    INSERT INTO employee.lk_recurring_method (id, name, code) {OV} VALUES (1,'Monthly','MON'),(2,'Non recurring','NRC'),(3,'Yearly','YRL') ON CONFLICT DO NOTHING;
    INSERT INTO employee.lk_amount_type (id, name, code) {OV} VALUES (1,'Amount','AMT'),(2,'Fix rate','FIX') ON CONFLICT DO NOTHING;
    INSERT INTO security.permission (id, code, name) {OV} VALUES (1,'View','View'),(2,'Edit','Edit') ON CONFLICT DO NOTHING;
    INSERT INTO company.code_setup_category (id, name) {OV} VALUES (1,'General') ON CONFLICT DO NOTHING;
    """)
    for tid, code in ((9, "CURRENCY"), (16, "CONTRACT_TYPE"), (17, "CAREER_PROGRESSION"), (25, "OCCUPATION"), (74, "JOB_LEVEL"),
                      (75, "JOB_GRADE"), (76, "COST_CENTRE")):
        c.execute(f"INSERT INTO company.code_setup_type (id, name, code) {OV} VALUES (%s,%s,%s) ON CONFLICT DO NOTHING", (tid, code, code))


def _code(c, company_id: int, type_id: int, code: str) -> int:
    row = c.execute("SELECT id FROM company.code_setup WHERE company_id=%s AND code_setup_type_id=%s AND code=%s",
                    (company_id, type_id, code)).fetchone()
    if row:
        return row["id"]
    return c.execute("""INSERT INTO company.code_setup (company_id, code_setup_type_id, code, description, sort)
                        VALUES (%s,%s,%s,%s,0) RETURNING id""", (company_id, type_id, code, code)).fetchone()["id"]


def seed_company(c, sc: SyntheticCompany) -> None:
    co = sc.company
    c.execute(f"""INSERT INTO company.company (id, uid, code, name, subscription_uid, uen) {OV}
                 VALUES (%s,%s,%s,%s,%s,%s) ON CONFLICT DO NOTHING""",
              (co.id, co.uid, co.code or f"C{co.id}", f"Synthetic Co {co.id}", sc.tenant_uid, f"UEN{co.id:06d}"))
    pp = c.execute("""INSERT INTO company.payment_profile (company_id, profile_name, created_on, created_by)
                      VALUES (%s,'Default',now(),'seed') RETURNING id""", (co.id,)).fetchone()["id"]
    cur, ctype = _code(c, co.id, 9, "SGD"), _code(c, co.id, 16, "PERM")
    codes = {k: _code(c, co.id, t, k) for t, k in ((25, "OCC"), (74, "JL1"), (75, "JG1"), (76, "CC1"))}
    for u in sc.users.values():
        c.execute(f"""INSERT INTO security."user" (id, uid, first_name, last_name, email) {OV}
                     VALUES (%s,%s,'Synthetic',%s,%s) ON CONFLICT DO NOTHING""",
                  (u.user_id, u.user_uid, u.employee_no, f"{u.employee_no.lower()}@example.invalid"))
        c.execute("INSERT INTO security.user_company (user_id, company_id) VALUES (%s,%s) ON CONFLICT DO NOTHING", (u.user_id, co.id))
        c.execute(f"""INSERT INTO employee.user_company_contract (id, user_id, company_id, contract_id, contract_type_id,
                contract_start_date, employee_no, currency_code_id, payment_profile_id) {OV}
                VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s)""",
                  (u.contract_id, u.user_id, co.id, f"CT-{u.employee_no}", ctype, u.hired, u.employee_no, cur, pp))
    for code, m in sc.master.items():
        c.execute("""INSERT INTO company.allowance_deduction (year, company_id, code, description, tax_id, cpf_id, type_id,
                bonus_type_id, unit_id) VALUES (2026,%s,%s,%s,1,
                (SELECT id FROM company.allowance_deduction_cpf WHERE code=%s),
                (SELECT id FROM company.allowance_deduction_type WHERE code=%s),
                (SELECT id FROM company.allowance_deduction_bonus_type WHERE code=%s),
                (SELECT id FROM company.allowance_deduction_unit WHERE name=%s))""",
                  (co.id, code, m.description, m.cpf_code or "NONE", m.type_code, m.bonus_type_code or "NONBONU", m.unit_name))
    for ci in sc.configured:
        c.execute("""INSERT INTO employee.contract_allowance_deduction (contract_id, pay_code_id, amount_type_id, currency_code_id,
                effective_date, payment_date, recurring_method_id, end_date, amount, payroll_cycle_id, uid)
            VALUES (%s,(SELECT id FROM company.allowance_deduction WHERE company_id=%s AND code=%s),1,%s,%s,%s,
                (SELECT id FROM employee.lk_recurring_method WHERE code=%s),%s,%s,2,%s)""",
                  (ci.contract_id, co.id, ci.code, cur, ci.effective_date, ci.effective_date, ci.recurring_method_code or "MON",
                   ci.end_date, ci.amount, ci.uid))
    seed_revisions(c, sc, sc.revisions, codes)
    seed_runs(c, sc, sc.runs, sc.records)


def seed_revisions(c, sc: SyntheticCompany, revisions: list[SalaryRevision], codes: dict | None = None) -> None:
    co = sc.company.id
    codes = codes or {k: _code(c, co, t, k) for t, k in ((25, "OCC"), (74, "JL1"), (75, "JG1"), (76, "CC1"))}
    for r in revisions:
        c.execute("""INSERT INTO employee.career_progression (uid, contract_id, career_progression_code_id, occupation_id, job_level_id,
                job_grade_id, cost_centre_id, old_salary, adjusted_amount, new_salary, adjustment_percent, effective_date,
                pay_effective_date, created_on, created_by) VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,'seed')""",
                  (r.uid, r.contract_id, _code(c, co, 17, r.code), codes["OCC"], codes["JL1"], codes["JG1"], codes["CC1"],
                   r.old_salary, r.adjusted_amount, r.new_salary, r.adjustment_percent, r.effective_date, r.pay_effective_date,
                   r.created_on))


def seed_runs(c, sc: SyntheticCompany, runs: list[PayRunRef], records: list[PayRecordSnapshot]) -> None:
    cycle_ids = {"MID": 1, "END": 2, "SPECIAL": 3, "BONUS": 4}
    for run in runs:
        value = f"{run.period:%m/%Y}"
        pp = c.execute("SELECT id FROM payroll.pay_period WHERE company_id=%s AND value=%s", (sc.company.id, value)).fetchone()
        if pp is None:
            pp = c.execute("INSERT INTO payroll.pay_period (name, value, company_id) VALUES (%s,%s,%s) RETURNING id",
                           (f"{run.period:%b %Y}", value, sc.company.id)).fetchone()
        c.execute(f"""INSERT INTO payroll.pay_run (id, uid, name, pay_run_date, pay_cycle_id, pay_period_id, is_trial) {OV}
                     VALUES (%s,%s,%s,%s,%s,%s,%s)""",
                  (run.id, run.uid, run.name, run.pay_run_date, cycle_ids[run.cycle_code], pp["id"], run.is_trial))
    with c.cursor() as cur:
        cur.executemany(f"""INSERT INTO payroll.pay_record (id, uid, user_id, contract_id, basic_salary, total_allowance,
                total_deduction, total_cpf, total_payout, data_processed, pay_run_id, status_id, is_new_hire, is_resignee) {OV}
            VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s,%s::json,%s,%s,%s,%s)""",
                        [(r.pay_record_id, r.pay_record_uid, r.user_id, r.contract_id, r.basic_earned, r.total_allowance,
                          r.total_deduction, r.total_cpf_column, r.net_pay, json.dumps(build_data_processed(r)), r.pay_run_id,
                          r.status_id, r.is_new_hire, r.is_resignee) for r in records])


def grant_pay_permission(c, user_uid: str, permissions=("View", "Edit")) -> None:
    for p in permissions:
        c.execute("""INSERT INTO security.access_rules (resource, resource_type, principle, principle_type, permission, is_active, is_granted)
                     VALUES ('PAY','function',%s,'user',%s,true,true)""", (user_uid, p))
