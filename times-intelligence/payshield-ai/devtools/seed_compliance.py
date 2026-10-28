"""LOCAL TEST ONLY: employee records the compliance checks need (date of birth, work pass type and levy, resignations),
with planted problems that start in different months, so each pay run shows a different mix:

  Jul 2026  employee aged 61 paid CPF at the under-55 rate (every month)
  Aug 2026  EP issued below the MOM minimum salary · resigned on 31 Jul but still paid · no second approver
  Sep 2026  turned 55 in Aug, CPF rate not lowered · WP with no levy · pay day 9 Oct (late)
  Oct 2026  resigned on 30 Sep but still paid · pay day 10 Nov (late) · no second approver
Pay-data problems (overtime, deductions, CPF on foreigners, SDL, SHG, one-off payments, duplicates, a 10x salary)
are planted per pay run by run_portal_prototype.inject_run.
"""

from __future__ import annotations

import random
from datetime import date

OV = "OVERRIDING SYSTEM VALUE"
_TYPES = ((2, "RACE"), (3, "RELIGION"), (6, "MARITAL_STATUS"), (7, "SALUTATION"), (24, "RESIGNATION_REASON"), (56, "PLACE"),
          (57, "NATIONALITY"), (58, "CITIZENSHIP"), (59, "WORK_PASS"), (60, "SECTOR"), (61, "LEVY_TIER"), (62, "LEVY_QUOTA"))


def _code(c, company_id: int, type_id: int, code: str) -> int:
    row = c.execute("SELECT id FROM company.code_setup WHERE company_id=%s AND code_setup_type_id=%s AND code=%s",
                    (company_id, type_id, code)).fetchone()
    if row:
        return row["id"]
    return c.execute("""INSERT INTO company.code_setup (company_id, code_setup_type_id, code, description, sort)
                        VALUES (%s,%s,%s,%s,0) RETURNING id""", (company_id, type_id, code, code)).fetchone()["id"]


def seed_compliance(c, sc, company_id: int, run_uids: dict[str, str], seed: int = 9) -> dict:
    """run_uids: 'YYYY-MM' -> pay run uid of the pay runs with planted problems."""
    rng = random.Random(seed)
    for tid, code in _TYPES:
        c.execute(f"INSERT INTO company.code_setup_type (id, name, code) {OV} VALUES (%s,%s,%s) ON CONFLICT DO NOTHING", (tid, code, code))
    c.execute(f"INSERT INTO company.period_type (id, name) {OV} VALUES (1,'Month') ON CONFLICT DO NOTHING")
    c.execute(f"INSERT INTO company.lk_levy_method (id, name, code) {OV} VALUES (1,'Tier','TIER') ON CONFLICT DO NOTHING")
    k = {t: _code(c, company_id, t, "NA") for t in (2, 3, 6, 7, 56, 57, 58)}
    planted: dict[str, list[str]] = {}

    def plant(kind: str, u, note: str) -> None:
        planted.setdefault(kind, []).append(f"{u.employee_no} {note}")

    users = sorted(sc.users.values(), key=lambda u: u.user_id)
    local = [u for u in users if not u.foreign and not u.has_ot and u.hired == sc.runs[0].period]
    holders = [u for u in users if u.foreign]

    # date of birth: 24 to 50 at the end of 2026, two planted older employees
    old61, turns55 = local[5], local[6]
    for u in users:
        dob = date(1965, 3, 2) if u is old61 else date(1971, 8, 10) if u is turns55 else date(2026 - rng.randint(24, 50), rng.randint(1, 12), rng.randint(1, 28))
        c.execute("""INSERT INTO security.user_identity (user_id, salutation_id, date_of_birth, place_of_birth_id, martial_status_id,
                race_id, religion_id, nationality_id, citizenship_id, national_id, created_by)
                VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,'seed')""",
                  (u.user_id, k[7], dob, k[56], k[6], k[2], k[3], k[57], k[58], b""))
    plant("cpf_rate_wrong", old61, "aged 61, from every month")
    plant("cpf_rate_wrong", turns55, "turned 55 on 10 Aug 2026, from Sep")

    # work pass type by salary (EP / S Pass / Work Permit); S Pass and Work Permit holders have a levy set up
    passes = {p: _code(c, company_id, 59, p) for p in ("EP", "SP", "WP")}
    levy = c.execute("""INSERT INTO company.company_levy_management (work_pass_id, sector_id, levy_method_id, tier_id, quota_id, effective_year)
            VALUES (%s,%s,1,%s,%s,2026) RETURNING id""",
                     (passes["WP"], _code(c, company_id, 60, "SERVICES"), _code(c, company_id, 61, "TIER1"), _code(c, company_id, 62, "BASIC"))).fetchone()["id"]
    for u in holders:
        kind = "EP" if u.basic >= 6200 else "SP" if u.basic >= 3700 else "WP"  # margin over the MOM minimums
        c.execute("UPDATE employee.epm_work_pass_records SET work_pass_id = %s, levy_management_id = %s WHERE id = %s",
                  (passes[kind], levy if kind != "EP" else None, u.user_id))
    spare = holders[3:]  # holders[0..2] carry the planted work pass expiries
    low_ep = next((u for u in spare if u.basic < 5600), None)
    if low_ep:  # new EP from 1 Aug 2026 although the salary is below the EP minimum
        c.execute("""UPDATE employee.epm_work_pass_records SET work_pass_id = %s, levy_management_id = NULL, pass_issue_date = %s,
                     pass_expiry_date = %s WHERE id = %s""", (passes["EP"], date(2026, 8, 1), date(2028, 7, 31), low_ep.user_id))
        plant("pass_salary_below_mom", low_ep, "EP issued 1 Aug 2026")
    no_levy = next((u for u in spare if u is not low_ep), None)
    if no_levy:  # new Work Permit from 1 Sep 2026 with no levy set up
        c.execute("""UPDATE employee.epm_work_pass_records SET work_pass_id = %s, levy_management_id = NULL, pass_issue_date = %s,
                     pass_expiry_date = %s WHERE id = %s""", (passes["WP"], date(2026, 9, 1), date(2028, 8, 31), no_levy.user_id))
        plant("levy_not_set", no_levy, "WP issued 1 Sep 2026")

    # resigned but still on the pay run
    reason = _code(c, company_id, 24, "PERSONAL")
    for u, last in ((local[7], date(2026, 7, 31)), (local[8], date(2026, 9, 30))):
        c.execute("""INSERT INTO employee.contract_resignation (contract_id, reason_id, notice_period, notice_period_type_id, tender_date,
                resignation_date, last_payment_date, last_day_of_work, additional_note, created_by)
                VALUES (%s,%s,1,1,%s,%s,%s,%s,'','seed')""",
                  (u.contract_id, reason, date(last.year, last.month, 1), last, last, last))
        plant("paid_after_leaving", u, f"last day {last:%d %b %Y}")

    # pay run level: late pay dates and runs prepared and changed by one person only
    for period, pay_day, owner in (("2026-08", None, "Ahmad Rahman (Payroll)"), ("2026-09", date(2026, 10, 9), None),
                                   ("2026-10", date(2026, 11, 10), "Mei Ling Tan (Payroll)")):
        uid = run_uids.get(period)
        if not uid:
            continue
        if pay_day:
            c.execute("UPDATE payroll.pay_run SET pay_run_date = %s WHERE uid = %s::uuid", (pay_day, uid))
            planted.setdefault("late_pay_run", []).append(f"{period} paid {pay_day}")
        if owner:
            c.execute("UPDATE payroll.pay_run SET created_by = %s, updated_by = %s WHERE uid = %s::uuid", (owner, owner, uid))
            planted.setdefault("no_second_approver", []).append(f"{period} {owner}")
    return planted
