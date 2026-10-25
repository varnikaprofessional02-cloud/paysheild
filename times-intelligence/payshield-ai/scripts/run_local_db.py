"""Run the PayShield AI API against YOUR OWN local PostgreSQL database (no synthetic data, nothing dropped).

  set PGPASSWORD=<your postgres password>          (PowerShell: $env:PGPASSWORD = "...")
  python scripts/run_local_db.py --db times-prod-is-down --company "prodisdown"

What it does (all idempotent):
  1. creates database  times-tenantstore-local  on the same server if missing, with a tenant row -> --db
  2. applies database/migrations/V001__times_intelligence_schema.sql to --db (CREATE ... IF NOT EXISTS)
  3. picks the company from company.company (by name/code match, else the first one)
  4. serves the API on :8080; the PayShield UI (npm run dev) reads the tenant/company from GET /dev/context
"""

from __future__ import annotations

import argparse
import os
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

import psycopg  # noqa: E402
import uvicorn  # noqa: E402
from psycopg.rows import dict_row  # noqa: E402

from app.core.config import Settings  # noqa: E402

DB = ROOT.parent / "database"
KEY = "local-demo-only-secret"
TS_DB = "times-tenantstore-local"


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--host", default="localhost")
    ap.add_argument("--port", type=int, default=5432)
    ap.add_argument("--user", default="postgres")
    ap.add_argument("--db", default="times-prod-is-down")
    ap.add_argument("--company", default="", help="part of the company name or code; default = first company")
    ap.add_argument("--pg-bin", default="C:/Program Files/PostgreSQL/18/bin")
    a = ap.parse_args()
    pw = os.environ.get("PGPASSWORD", "")
    conn = lambda db, **kw: psycopg.connect(host=a.host, port=a.port, user=a.user, password=pw, dbname=db, **kw)  # noqa: E731
    psql = lambda db, f: subprocess.run([str(Path(a.pg_bin) / "psql"), "-h", a.host, "-p", str(a.port), "-U", a.user, "-d", db,  # noqa: E731
                                         "-q", "-v", "ON_ERROR_STOP=1", "-f", str(f)], check=True, env={**os.environ, "PGPASSWORD": pw})

    with conn(a.db, row_factory=dict_row) as c:
        cos = c.execute("SELECT id, uid::text AS uid, name, code, subscription_uid::text AS sub FROM company.company ORDER BY id").fetchall()
    if not cos:
        sys.exit(f"no rows in {a.db}.company.company")
    want = a.company.lower().replace("-", "").replace(" ", "")
    co = next((x for x in cos if want and want in f"{x['name']}{x['code']}".lower().replace("-", "").replace(" ", "")), cos[0])
    print(f"1. company {co['id']} {co['name']} ({co['code']}) uid={co['uid']}")

    print(f"2. tenant store {TS_DB}")
    with conn("postgres", autocommit=True) as c:
        if not c.execute("SELECT 1 FROM pg_database WHERE datname=%s", (TS_DB,)).fetchone():
            c.execute(f'CREATE DATABASE "{TS_DB}"')
    psql(TS_DB, DB / "test/02_tenantstore_minimal.sql")
    with conn(TS_DB) as c:
        row = c.execute("SELECT identifier::text FROM tenant.tenant WHERE db_name=%s", (a.db,)).fetchone()
        if row:
            tenant = row[0]
        else:
            tenant = co["sub"]  # tenant identifier = the company's subscription uid
            if not c.execute("SELECT 1 FROM tenant.identity_provider WHERE name='Keycloak'").fetchone():
                c.execute("INSERT INTO tenant.identity_provider (name) VALUES ('Keycloak')")
            tid = c.execute("INSERT INTO tenant.tenant (identifier, name, db_name, subdomain) VALUES (%s,%s,%s,%s) RETURNING id",
                            (tenant, a.db, a.db, a.db)).fetchone()[0]
            c.execute("INSERT INTO tenant.tenant_identity_provider (tenant_id, identity_provider_id, instance_code) "
                      "SELECT %s, id, 'LOCAL' FROM tenant.identity_provider WHERE name='Keycloak' LIMIT 1", (tid,))

    print(f"3. times_intelligence schema in {a.db}")
    psql(a.db, DB / "migrations/V001__times_intelligence_schema.sql")
    psql(a.db, DB / "migrations/V002__training_areas.sql")

    settings = Settings(environment="local", db={"host": a.host, "port": a.port, "username": a.user, "password": pw,
                                                  "sslmode": "disable", "tenant_store_database": TS_DB},
                        service_auth={"mode": "shared_secret", "shared_secret": KEY},
                        storage={"backend": "local", "local_root": str(Path.home() / ".payshield-tmp" / f"models-{a.db}")},
                        keycloak={"authority": "https://keycloak.invalid"})
    from app.main import create_app

    app = create_app(settings)

    @app.get("/dev/context")
    def context():
        return {"tenantUid": tenant, "companyUid": co["uid"], "companyName": co["name"], "database": a.db}

    @app.get("/dev/runs")
    def runs():
        with conn(a.db, row_factory=dict_row) as c:
            return c.execute("""SELECT r.uid::text AS uid, r.name, pp.value AS period, count(pr.id) AS records
                FROM payroll.pay_run r JOIN payroll.pay_period pp ON pp.id = r.pay_period_id
                JOIN payroll.pay_record pr ON pr.pay_run_id = r.id WHERE r.company_id = %s
                GROUP BY r.id, r.uid, r.name, pp.value ORDER BY to_date(pp.value,'MM/YYYY') DESC, r.id DESC LIMIT 12""",
                             (co["id"],)).fetchall()

    print(f"   tenant uid={tenant}")
    print("4. API on http://127.0.0.1:8080  (then: npm run dev in payshield/paysheild)")
    uvicorn.run(app, host="127.0.0.1", port=8080, log_level="warning")


if __name__ == "__main__":
    main()
