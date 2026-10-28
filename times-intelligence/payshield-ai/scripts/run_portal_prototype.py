"""LOCAL portal prototype for subscription "prod-is-down".

  python scripts/run_portal_prototype.py --reset     # first time: build DBs + seed, then serve
  python scripts/run_portal_prototype.py             # later: just serve
  open http://127.0.0.1:8080/portal/CHPL/dashboard

Databases (local PostgreSQL --port, default 55433):
  times-tenantstore-local   tenant store (tenant.tenant row for prod-is-down)
  times-prod-is-down        the subscription DB: real tenant schema + times_intelligence schema (V001)
The company starts NOT subscribed to Times Intelligence; subscribing happens from the portal page.
Dev-only helper endpoints (/dev/...) exist only in this script.
"""

from __future__ import annotations

import argparse
import shutil
import subprocess
import sys
from datetime import date
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

import psycopg  # noqa: E402
import uvicorn  # noqa: E402
from fastapi.responses import HTMLResponse  # noqa: E402
from psycopg.rows import dict_row  # noqa: E402

from app.core.config import Settings  # noqa: E402
from app.data.synthetic import COMPLIANCE_SCENARIOS, generate_company, make_analysis_run  # noqa: E402
from app.domain.models import CompanyRef  # noqa: E402
from devtools.seed_compliance import seed_compliance  # noqa: E402
from devtools.seed_identity import change_identity, seed_identity  # noqa: E402
from devtools.seed_names import name_employees  # noqa: E402
from devtools.seed_tenant import seed_company, seed_lookups, seed_revisions, seed_runs  # noqa: E402

DB = ROOT.parent / "database"
KEY = "local-demo-only-secret"
TENANT = "5ab1c0de-0000-4000-8000-0000000000aa"          # subscription uid of prod-is-down
SUB_DB, TS_DB = "times-prod-is-down", "times-tenantstore-local"
COMPANY = CompanyRef(1, "c4a1e7f0-0000-4000-8000-00000000c4a1", TENANT, "CHPL")
MODEL_DIR = Path.home() / ".payshield-tmp" / "models-prod-is-down"
HISTORY_MONTHS = 21  # clean history Oct 2024 - Jun 2026; every month after that, up to the current one, gets planted problems


def _company(n_employees: int):
    return generate_company(11, tenant_uid=TENANT, company=COMPANY, n_employees=n_employees, months=HISTORY_MONTHS, foreign_every=7)


def _psql(pg_bin, port, db, file):
    subprocess.run([str(Path(pg_bin) / "psql"), "-p", str(port), "-U", "postgres", "-d", db, "-q", "-v", "ON_ERROR_STOP=1",
                    "-f", str(file)], check=True, capture_output=True)


def reset(pg_bin: str, port: int, n_employees: int) -> None:
    admin = psycopg.connect(f"host=localhost port={port} user=postgres dbname=postgres", autocommit=True)
    _psql(pg_bin, port, "postgres", DB / "test/00_create_roles.sql")
    for db in (TS_DB, SUB_DB):
        admin.execute(f'DROP DATABASE IF EXISTS "{db}" WITH (FORCE)')
        admin.execute(f'CREATE DATABASE "{db}"')
    print("  loading tenant schema + times_intelligence schema into", SUB_DB)
    for f in ("test/schema/tenant_schema_2026-09-28.sql", "test/01_newer_columns.sql",
              "migrations/V001__times_intelligence_schema.sql", "migrations/V002__training_areas.sql",
              "migrations/V003__pay_run_release.sql", "migrations/V004__feedback_learning.sql",
              "migrations/V005__agent_skills.sql"):
        _psql(pg_bin, port, SUB_DB, DB / f)
    _psql(pg_bin, port, TS_DB, DB / "test/02_tenantstore_minimal.sql")
    with psycopg.connect(f"host=localhost port={port} user=postgres dbname={TS_DB}") as c:
        c.execute("INSERT INTO tenant.identity_provider (name) VALUES ('Keycloak')")
        tid = c.execute("INSERT INTO tenant.tenant (identifier, name, db_name, subdomain) VALUES (%s,'prod-is-down',%s,'prod-is-down') "
                        "RETURNING id", (TENANT, SUB_DB)).fetchone()[0]
        c.execute("INSERT INTO tenant.tenant_identity_provider (tenant_id, identity_provider_id, instance_code) VALUES (%s,1,'CHPL')", (tid,))
    print(f"  seeding {HISTORY_MONTHS} months of clean payroll for CARLTON HOTEL (SINGAPORE) PTE LTD: {n_employees} employees")
    sc = _company(n_employees)
    with psycopg.connect(f"host=localhost port={port} user=postgres dbname={SUB_DB}", row_factory=dict_row) as c:
        seed_lookups(c)
        seed_company(c, sc)
        c.execute("UPDATE company.company SET name='CARLTON HOTEL (SINGAPORE) PTE LTD' WHERE id=%s", (COMPANY.id,))
        print(f"  named {name_employees(c, COMPANY.id)} employees")
        print("  seeding identity data (NRIC/FIN, work passes, bank accounts) with planted problems:",
              seed_identity(c, sc, COMPANY.id))
        c.execute("INSERT INTO times_intelligence.company_setting (company_id, overtime_pay_codes) VALUES (%s, %s)", (COMPANY.id, ["OT15"]))
    shutil.rmtree(MODEL_DIR, ignore_errors=True)
    dsn = f"host=localhost port={port} user=postgres dbname={SUB_DB}"
    today = date.today().replace(day=1)
    uids = {}
    while True:  # monthly pay runs with planted problems, up to the current month
        r = inject_run(dsn, n_employees, change_ids=False)
        uids[r["period"]] = r["payRunId"]
        print(f"  pay run {r['period']}: planted {len(r['injected'])} problems")
        if r["period"] >= f"{today:%Y-%m}":
            break
    with psycopg.connect(dsn, row_factory=dict_row) as c:
        print("  compliance records (date of birth, work passes, resignations, pay dates) with planted problems:",
              seed_compliance(c, _company(n_employees), COMPANY.id, uids))


def inject_run(dsn: str, n_employees: int, change_ids: bool = True) -> dict:
    """Adds the next month's pay run with planted problems (different employees each month). The current month gets
    every compliance problem; earlier months get three each, so each month shows a different mix.

    change_ids also changes a few bank accounts / phones, so 'changed since training' fires (only useful after training)."""
    sc = _company(n_employees)
    with psycopg.connect(dsn, row_factory=dict_row) as c:
        extra = c.execute("SELECT count(*) AS n FROM payroll.pay_run").fetchone()["n"] - len(sc.runs)
        last = sc.runs[-1]
        for _ in range(extra):  # continue after any runs created earlier
            last = last.__class__(0, "", COMPANY.id, _next_month(last.period), "END", False, last.pay_run_date, "")
            sc.runs.append(last)
        users = sorted((u for u in sc.users.values() if u.hired == sc.runs[0].period and not u.loan_until),
                       key=lambda u: u.user_id)
        plain = [u for u in users if not u.has_ot and not u.has_meal and not u.foreign]
        k = (extra * 7) % len(plain)
        plain = iter(plain[k:] + plain[:k])  # different employees each run, so old injections never look normal
        scen = {next(plain).user_id: s for s in ("salary_increase_no_revision", "duplicate_allowance",
                                                 "missing_recurring_allowance", "unexpected_net_increase",
                                                 "new_large_deduction", "cpf_missing", "approved_promotion")[: 4 + extra % 4]}
        ot = [u for u in users if u.has_ot and not u.foreign]
        scen[ot[extra % len(ot)].user_id] = "unusual_overtime"
        period = _next_month(last.period)
        comp = COMPLIANCE_SCENARIOS if period >= date.today().replace(day=1) else COMPLIANCE_SCENARIOS[(extra * 3) % 10:][:3]
        free = lambda pool: next(u for u in pool if u.user_id not in scen)  # noqa: E731
        local = [u for u in users if not u.foreign]
        for s in comp:
            pool = (ot[extra + 1:] + ot[:extra + 1] if s in ("ot_over_limit", "ot_rate_low")
                    else [u for u in users if u.foreign][extra:] if s == "cpf_on_foreigner"
                    else sorted(local, key=lambda u: -u.basic)[extra:] if s == "aw_over_ceiling" else plain)
            scen[free(pool).user_id] = s
        sc._ids[0] = 2_000_000 + extra * 10_000
        run, recs, revs = make_analysis_run(sc, scen, seed=100 + extra)
        seed_revisions(c, sc, revs)
        seed_runs(c, sc, [run], recs)
        ident = change_identity(c, sc, extra) if change_ids else []
    names = {u.user_id: u.employee_no for u in sc.users.values()}
    return {"payRunId": run.uid, "period": f"{run.period:%Y-%m}",
            "injected": [{"employeeNo": names[k], "scenario": v} for k, v in scen.items()] + ident}


def _next_month(d: date) -> date:
    return date(d.year + (d.month == 12), d.month % 12 + 1, 1)


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--port", type=int, default=55433)
    ap.add_argument("--pg-bin", default="C:/Program Files/PostgreSQL/18/bin")
    ap.add_argument("--reset", action="store_true")
    ap.add_argument("--employees", type=int, default=80, help="employees to seed with --reset (use the same value when serving)")
    args = ap.parse_args()
    if args.reset:
        print("resetting prod-is-down databases ...")
        reset(args.pg_bin, args.port, args.employees)

    settings = Settings(environment="local", db={"port": args.port, "username": "postgres", "sslmode": "disable",
                                                  "tenant_store_database": TS_DB},
                        service_auth={"mode": "shared_secret", "shared_secret": KEY},
                        storage={"backend": "local", "local_root": str(MODEL_DIR)},
                        keycloak={"authority": "https://keycloak.invalid"})
    from app.main import create_app

    app = create_app(settings)
    dsn = f"host=localhost port={args.port} user=postgres dbname={SUB_DB}"

    @app.get("/portal/CHPL/dashboard", response_class=HTMLResponse)
    def portal():
        html = (ROOT / "prototype" / "portal.html").read_text(encoding="utf-8")
        return html.replace("__KEY__", KEY).replace("__TENANT__", TENANT).replace("__COMPANY__", COMPANY.uid)

    @app.get("/dev/context")
    def context():
        return {"tenantUid": TENANT, "companyUid": COMPANY.uid, "companyName": "CARLTON HOTEL (SINGAPORE) PTE LTD",
                "database": SUB_DB, "demo": True}

    @app.get("/dev/runs")
    def runs():
        with psycopg.connect(dsn, row_factory=dict_row) as c:
            return c.execute("""SELECT r.uid::text AS uid, r.name, pp.value AS period, count(pr.id) AS records
                FROM payroll.pay_run r JOIN payroll.pay_period pp ON pp.id = r.pay_period_id
                JOIN payroll.pay_record pr ON pr.pay_run_id = r.id
                GROUP BY r.id, r.uid, r.name, pp.value ORDER BY to_date(pp.value,'MM/YYYY') DESC, r.id DESC""").fetchall()

    @app.post("/dev/inject-run")
    def inject():
        return inject_run(dsn, args.employees)

    print("open http://127.0.0.1:8080/portal/CHPL/dashboard")
    uvicorn.run(app, host="127.0.0.1", port=8080, log_level="warning")


if __name__ == "__main__":
    main()
