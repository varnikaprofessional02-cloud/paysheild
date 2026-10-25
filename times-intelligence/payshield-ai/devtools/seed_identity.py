"""LOCAL TEST ONLY: synthetic identity data (NRIC/FIN, work passes, bank accounts, phones) for the Identification area.

Values are fake and stored as plain bytes in the bytea columns (production encrypts them). A few problems are planted
so the checks have something to find: duplicate NRIC, shared bank accounts, expired/expiring passes, a missing NRIC
and a shared phone number.
"""

from __future__ import annotations

import random
from datetime import date, timedelta

OV = "OVERRIDING SYSTEM VALUE"


def _nric(rng: random.Random, prefix: str) -> str:
    return f"{prefix}{rng.randint(1000000, 9999999)}{rng.choice('ABCDEFGHIJZ')}"


def seed_identity_lookups(c) -> None:
    c.execute(f"INSERT INTO company.area (id, name, uid, created_by) {OV} VALUES (1,'Singapore',gen_random_uuid(),'seed') ON CONFLICT DO NOTHING")
    c.execute(f"INSERT INTO company.bank_category (id, name, created_on, created_by) {OV} VALUES (1,'Bank',now(),'seed') ON CONFLICT DO NOTHING")
    c.execute("INSERT INTO employee.lk_pass_status (id, name) VALUES (1,'Active'),(2,'Cancelled'),(3,'Expired') ON CONFLICT DO NOTHING")
    c.execute("INSERT INTO company.bank_type (id, name) VALUES (1,'Local') ON CONFLICT DO NOTHING")
    c.execute("INSERT INTO company.payment_mode (id, name) VALUES (1,'Bank transfer'),(2,'Cash'),(3,'Cheque') ON CONFLICT DO NOTHING")
    for i, (code, name) in enumerate((("7171", "DBS Bank"), ("7339", "OCBC Bank"), ("7375", "UOB")), start=1):
        c.execute(f"INSERT INTO company.bank (id, bank_code, bank_name) {OV} VALUES (%s,%s,%s) ON CONFLICT DO NOTHING", (i, code, name))
        c.execute(f"INSERT INTO company.bank_branch (id, code, name, bank_id) {OV} VALUES (%s,'001','Main',%s) ON CONFLICT DO NOTHING", (i, i))


def seed_identity(c, sc, company_id: int, seed: int = 5) -> dict:
    rng = random.Random(seed)
    seed_identity_lookups(c)
    users = sorted(sc.users.values(), key=lambda u: u.user_id)
    today = date.today()
    accounts, nrics, planted = {}, {}, {}
    for i, u in enumerate(users):
        holder = i % 7 == 3  # about 1 in 7 is a work pass holder
        nric = None if holder else _nric(rng, rng.choice("ST"))
        rid = c.execute("""INSERT INTO employee.user_regulatory (user_id, residency_type, singaporean_or_spr, nric_no, created_by)
            VALUES (%s, %s, %s, %s, 'seed') RETURNING id""",
                        (u.user_id, "WorkPassHolder" if holder else "SingaporeanOrSPR", None if holder else "Singaporean",
                         nric.encode() if nric else None)).fetchone()["id"]
        if holder:
            exp = today + timedelta(days=rng.randint(90, 900))
            c.execute("""INSERT INTO employee.epm_work_pass_records (id, regulatory_id, fin, pass_status_id, application_date,
                    pass_issue_date, pass_expiry_date, created_by) VALUES (%s,%s,%s,1,%s,%s,%s,'seed')""",
                      (u.user_id, rid, _nric(rng, rng.choice("FG")), exp - timedelta(days=760), exp - timedelta(days=730), exp))
        acct = f"{rng.randint(100, 999)}-{rng.randint(10000, 99999)}-{rng.randint(1, 9)}"
        pf = c.execute("""INSERT INTO employee.payment_profile (user_id, contract_id, company_id, profile_name, effective_date,
                bank_type_id, is_preferred) VALUES (%s,%s,%s,'Salary',%s,1,true) RETURNING id""",
                       (u.user_id, u.contract_id, company_id, u.hired)).fetchone()["id"]
        c.execute("""INSERT INTO employee.payment_split (payment_profile_id, sort, payment_mode_id, bank_id, bank_branch_id,
                is_percentage, percentage, account_number) VALUES (%s,1,1,%s,%s,true,100,%s)""",
                  (pf, (i % 3) + 1, (i % 3) + 1, acct.encode()))
        c.execute('UPDATE security."user" SET ph_number = %s WHERE id = %s', (f"+65 9{rng.randint(1000000, 9999999)}", u.user_id))
        accounts[u.user_id], nrics[u.user_id] = acct, nric

    citizens = [u for i, u in enumerate(users) if i % 7 != 3]
    holders = [u for i, u in enumerate(users) if i % 7 == 3]
    pick = iter(citizens[len(citizens) // 3:])

    def plant(kind: str, u) -> None:
        planted.setdefault(kind, []).append(u.employee_no)

    a, b = next(pick), next(pick)  # duplicate NRIC
    c.execute("UPDATE employee.user_regulatory SET nric_no = %s WHERE user_id = %s", (nrics[a.user_id].encode(), b.user_id))
    plant("duplicate_nric", b)
    for _ in range(2):  # shared bank account
        a, b = next(pick), next(pick)
        c.execute("""UPDATE employee.payment_split ps SET account_number = %s FROM employee.payment_profile pf
                     WHERE ps.payment_profile_id = pf.id AND pf.user_id = %s""", (accounts[a.user_id].encode(), b.user_id))
        plant("shared_bank_account", b)
    u = next(pick)  # missing NRIC
    c.execute("UPDATE employee.user_regulatory SET nric_no = NULL WHERE user_id = %s", (u.user_id,))
    plant("missing_nric", u)
    a, b = next(pick), next(pick)  # shared phone
    c.execute('UPDATE security."user" SET ph_number = (SELECT ph_number FROM security."user" WHERE id = %s) WHERE id = %s', (a.user_id, b.user_id))
    plant("shared_phone", b)
    for k, days in enumerate((-12, 9, 21)):  # work pass expired / expiring
        if k < len(holders):
            c.execute("UPDATE employee.epm_work_pass_records SET pass_expiry_date = %s WHERE id = %s", (today + timedelta(days=days), holders[k].user_id))
            plant("work_pass_expired" if days < 0 else "work_pass_expiring", holders[k])
    return planted


def change_identity(c, sc, round_no: int) -> list[dict]:
    """After training: switch two bank accounts and one phone, so 'changed since training' fires on the next check."""
    rng = random.Random(1000 + round_no)
    users = sorted(sc.users.values(), key=lambda u: u.user_id)
    picks = rng.sample(users[: max(10, len(users) // 2)], 3)
    for u in picks[:2]:
        c.execute("""UPDATE employee.payment_split ps SET account_number = %s FROM employee.payment_profile pf
                     WHERE ps.payment_profile_id = pf.id AND pf.user_id = %s""",
                  (f"{rng.randint(100, 999)}-{rng.randint(10000, 99999)}-{rng.randint(1, 9)}".encode(), u.user_id))
    c.execute('UPDATE security."user" SET ph_number = %s WHERE id = %s', (f"+65 8{rng.randint(1000000, 9999999)}", picks[2].user_id))
    return [{"employeeNo": picks[0].employee_no, "scenario": "bank_account_changed"},
            {"employeeNo": picks[1].employee_no, "scenario": "bank_account_changed"},
            {"employeeNo": picks[2].employee_no, "scenario": "phone_changed"}]
