"""End-to-end demo on a LOCAL PostgreSQL with the real tenant schema and synthetic data.

  python scripts/demo_end_to_end.py --port 55433 [--pg-bin "C:/Program Files/PostgreSQL/18/bin"]

Creates DBs payshield_ts (tenant store), payshield_t1 and payshield_t2 (two tenants), seeds synthetic companies,
then through the HTTP API (service auth, shared-secret dev mode): trains company A's model, analyses a new pay run
with injected anomalies, checks tenant isolation, and asks the assistant. Writes demo_output/*.json.
"""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

import psycopg  # noqa: E402
from psycopg.rows import dict_row  # noqa: E402

from app.core.config import Settings  # noqa: E402
from app.data.synthetic import generate_company, make_analysis_run  # noqa: E402
from app.domain.models import CompanyRef  # noqa: E402
from devtools.seed_tenant import seed_company, seed_lookups, seed_revisions, seed_runs  # noqa: E402

DB = ROOT.parent / "database"
T1, T2 = "11111111-1111-4111-8111-111111111111", "22222222-2222-4222-8222-222222222222"
A = CompanyRef(1, "aaaaaaa1-0000-4000-8000-000000000001", T1, "ACO")
B = CompanyRef(1, "bbbbbbb1-0000-4000-8000-000000000001", T2, "BCO")
KEY = "local-demo-only-secret"


def psql(args, pg_bin, port, db, file):
    subprocess.run([str(Path(pg_bin) / "psql"), "-p", str(port), "-U", "postgres", "-d", db, "-q", "-v", "ON_ERROR_STOP=1",
                    "-f", str(file)], check=True, capture_output=True)


def setup(pg_bin: str, port: int):
    admin = psycopg.connect(f"host=localhost port={port} user=postgres dbname=postgres", autocommit=True)
    psql(None, pg_bin, port, "postgres", DB / "test/00_create_roles.sql")
    for db in ("payshield_ts", "payshield_t1", "payshield_t2"):
        admin.execute(f'DROP DATABASE IF EXISTS "{db}" WITH (FORCE)')
        admin.execute(f'CREATE DATABASE "{db}"')
    for db in ("payshield_t1", "payshield_t2"):
        for f in ("test/schema/tenant_schema_2026-09-28.sql", "test/01_newer_columns.sql", "migrations/V001__times_intelligence_schema.sql"):
            psql(None, pg_bin, port, db, DB / f)
    psql(None, pg_bin, port, "payshield_ts", DB / "test/02_tenantstore_minimal.sql")
    with psycopg.connect(f"host=localhost port={port} user=postgres dbname=payshield_ts") as c:
        c.execute("INSERT INTO tenant.identity_provider (name) VALUES ('Keycloak')")
        for uid, db, realm in ((T1, "payshield_t1", "UEN000001"), (T2, "payshield_t2", "UEN000002")):
            tid = c.execute("INSERT INTO tenant.tenant (identifier, name, db_name, subdomain) VALUES (%s,%s,%s,%s) RETURNING id",
                            (uid, db, db, db)).fetchone()[0]
            c.execute("INSERT INTO tenant.tenant_identity_provider (tenant_id, identity_provider_id, instance_code) VALUES (%s,1,%s)",
                      (tid, realm))


def seed(port: int):
    world = {}
    for company, db, seed_ in ((A, "payshield_t1", 1), (B, "payshield_t2", 2)):
        sc = generate_company(seed_, tenant_uid=company.subscription_uid, company=company)
        with psycopg.connect(f"host=localhost port={port} user=postgres dbname={db}", row_factory=dict_row) as c:
            seed_lookups(c)
            seed_company(c, sc)
            c.execute("INSERT INTO times_intelligence.company_setting (company_id, overtime_pay_codes) VALUES (%s, %s)", (company.id, ["OT15"]))
            c.execute("INSERT INTO times_intelligence.subscription (company_id, subscribed_by) VALUES (%s, 'demo')", (company.id,))
        world[company.uid] = (sc, db)
    return world


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--port", type=int, default=55433)
    ap.add_argument("--pg-bin", default="C:/Program Files/PostgreSQL/18/bin")
    args = ap.parse_args()
    out = ROOT / "demo_output"
    out.mkdir(exist_ok=True)

    print("1. creating tenant-store + 2 tenant DBs from the real schema dump, applying V001 ...")
    setup(args.pg_bin, args.port)
    # the demo recreates the DBs, so its local model files must go too (the store never overwrites artifacts)
    import shutil
    shutil.rmtree(Path.home() / ".payshield-tmp" / "models", ignore_errors=True)
    print("2. seeding synthetic companies (24 months of payroll each) ...")
    world = seed(args.port)
    sc, db = world[A.uid]

    settings = Settings(environment="local", db={"port": args.port, "username": "postgres", "sslmode": "disable",
                                                  "tenant_store_database": "payshield_ts"},
                        service_auth={"mode": "shared_secret", "shared_secret": KEY},
                        storage={"backend": "local", "local_root": str(Path.home() / ".payshield-tmp" / "models")},
                        keycloak={"authority": "https://keycloak.invalid"})
    from fastapi.testclient import TestClient

    from app.main import create_app

    client = TestClient(create_app(settings))
    h = {"X-PayShield-Service-Key": KEY, "X-Tenant-Uid": T1, "X-Company-Uid": A.uid}

    print("3. training company A model via POST /api/v1/models/train ...")
    job = client.post("/api/v1/models/train", headers=h, json={}).json()
    while True:
        j = client.get(f"/api/v1/models/training-jobs/{job['jobId']}", headers=h).json()
        if j["status"] not in ("QUEUED", "RUNNING"):
            break
        time.sleep(2)
    status = client.get("/api/v1/models/status", headers=h).json()
    print("   job:", j["status"], j["gate"], "active model:", (status["activeModel"] or {}).get("modelVersion"),
          "detector:", (status["activeModel"] or {}).get("detector"))
    (out / "model_status.json").write_text(json.dumps(status, indent=2))

    print("4. creating a new pay run with injected anomalies ...")
    users = sorted((u for u in sc.users.values() if u.hired == sc.runs[0].period and not u.loan_until), key=lambda u: u.user_id)
    plain = iter(u for u in users if not u.has_ot and not u.has_meal)
    scen = {next(plain).user_id: s for s in ("salary_increase_no_revision", "duplicate_allowance", "missing_recurring_allowance",
                                             "unexpected_net_increase", "new_large_deduction", "cpf_missing",
                                             "approved_promotion", "december_bonus")}
    scen[next(u for u in users if u.has_ot).user_id] = "unusual_overtime"
    run, recs, revs = make_analysis_run(sc, scen)
    with psycopg.connect(f"host=localhost port={args.port} user=postgres dbname={db}", row_factory=dict_row) as c:
        seed_revisions(c, sc, revs)
        seed_runs(c, sc, [run], recs)

    print("5. POST /api/v1/payroll/analyze ...")
    res = client.post("/api/v1/payroll/analyze", headers=h, json={"payRunId": run.uid})
    analysis = res.json()
    (out / "analysis.json").write_text(json.dumps(analysis, indent=2))
    print(f"   status={analysis['status']} model={analysis['modelVersion']} mlStatus={analysis['mlStatus']} "
          f"employees={analysis['totalEmployees']} flagged={analysis['flaggedEmployees']}")
    emp = {u.employee_no: s for u in sc.users.values() for k, s in scen.items() if k == u.user_id}
    for a in analysis["anomalies"]:
        print(f"   [{a['severity']:8}] {a['riskScore']:3} {a['anomalyType']:32} {a['employeeNo']} "
              f"({emp.get(a['employeeNo'], 'normal')}): {a['description'][:80]}")

    print("6. tenant isolation checks ...")
    hb = {"X-PayShield-Service-Key": KEY, "X-Tenant-Uid": T2, "X-Company-Uid": B.uid}
    checks = {
        "B cannot read A analysis": client.get(f"/api/v1/payroll/analysis/{analysis['analysisId']}", headers=hb).status_code,
        "B cannot activate A model": client.post(f"/api/v1/models/{status['activeModel']['modelId']}/activate", headers=hb).status_code
        if status["activeModel"] else None,
        "B cannot analyse A pay run": client.post("/api/v1/payroll/analyze", headers=hb, json={"payRunId": run.uid}).status_code,
        "tenant A header + company B uid": client.get("/api/v1/models/status", headers={**h, "X-Company-Uid": B.uid}).status_code,
        "B has no model": client.get("/api/v1/models/status", headers=hb).json()["activeModel"],
        "no credentials": client.get("/api/v1/models/status", headers={"X-Tenant-Uid": T1, "X-Company-Uid": A.uid}).status_code,
        "wrong service key": client.get("/api/v1/models/status", headers={**h, "X-PayShield-Service-Key": "x"}).status_code,
    }
    for k, v in checks.items():
        print(f"   {k}: {v}")
    (out / "isolation_checks.json").write_text(json.dumps(checks, indent=2))

    print("7. idempotency: re-analysing unchanged run returns the same analysis ...")
    again = client.post("/api/v1/payroll/analyze", headers=h, json={"payRunId": run.uid}).json()
    print("   same analysisId:", again["analysisId"] == analysis["analysisId"])

    print("8. assistant (LLM disabled -> deterministic fallback) ...")
    for q in ("What are the highest-risk payroll anomalies this month?", "How many employees have unusual overtime?",
              "Approve the payroll now"):
        r = client.post("/api/v1/assistant/ask", headers=h, json={"question": q, "analysisId": analysis["analysisId"]}).json()
        print(f"   Q: {q}\n   [{r['status']}] {r['answer'][:300]}")

    print("9. reviewer feedback ...")
    first = analysis["anomalies"][0]["anomalyId"]
    print("   ", client.post("/api/v1/payroll/feedback", headers=h,
                             json={"anomalyId": first, "outcome": "CONFIRMED_ERROR"}).status_code,
          "(403 expected: feedback must come from a payroll user, not a service)")
    print("done; outputs in", out)


if __name__ == "__main__":
    main()
