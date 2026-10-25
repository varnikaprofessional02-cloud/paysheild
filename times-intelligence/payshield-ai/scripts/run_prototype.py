"""LOCAL prototype server: python scripts/run_prototype.py  ->  open http://127.0.0.1:8080/prototype

Uses the demo databases created by scripts/demo_end_to_end.py (payshield_ts / payshield_t1 on --port 55433).
Adds dev-only endpoints (list pay runs, inject a test run) that do not exist in the real service."""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

import psycopg  # noqa: E402
import uvicorn  # noqa: E402
from fastapi.responses import HTMLResponse  # noqa: E402
from psycopg.rows import dict_row  # noqa: E402

from app.core.config import Settings  # noqa: E402
from app.main import create_app  # noqa: E402

KEY = "local-demo-only-secret"
T1 = "11111111-1111-4111-8111-111111111111"
A_UID = "aaaaaaa1-0000-4000-8000-000000000001"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--port", type=int, default=55433)
    args = ap.parse_args()
    settings = Settings(environment="local", db={"port": args.port, "username": "postgres", "sslmode": "disable",
                                                  "tenant_store_database": "payshield_ts"},
                        service_auth={"mode": "shared_secret", "shared_secret": KEY},
                        storage={"backend": "local", "local_root": str(Path.home() / ".payshield-tmp" / "models")},
                        keycloak={"authority": "https://keycloak.invalid"})
    app = create_app(settings)
    dsn = f"host=localhost port={args.port} user=postgres dbname=payshield_t1"

    @app.get("/prototype", response_class=HTMLResponse)
    def page():
        html = (ROOT / "prototype" / "index.html").read_text(encoding="utf-8")
        return html.replace("__KEY__", KEY).replace("__TENANT__", T1).replace("__COMPANY__", A_UID)

    @app.get("/dev/runs")
    def runs():
        with psycopg.connect(dsn, row_factory=dict_row) as c:
            return c.execute("""SELECT r.uid::text AS uid, r.name, pp.value AS period, count(pr.id) AS records
                FROM payroll.pay_run r JOIN payroll.pay_period pp ON pp.id = r.pay_period_id
                JOIN payroll.pay_record pr ON pr.pay_run_id = r.id
                GROUP BY r.id, r.uid, r.name, pp.value ORDER BY to_date(pp.value,'MM/YYYY') DESC, r.id DESC LIMIT 6""").fetchall()

    @app.post("/dev/inject-run")
    def inject():
        from app.data.synthetic import generate_company, make_analysis_run
        from app.domain.models import CompanyRef
        from devtools.seed_tenant import seed_revisions, seed_runs

        co = CompanyRef(1, A_UID, T1, "ACO")
        sc = generate_company(1, tenant_uid=T1, company=co)
        with psycopg.connect(dsn, row_factory=dict_row) as c:
            n = c.execute("SELECT count(*) AS n FROM payroll.pay_run").fetchone()["n"]
            # continue after the latest seeded month so each injected run is a new period
            for _ in range(n - len(sc.runs)):
                sc.runs.append(sc.runs[-1].__class__(sc.next_id() + 10_000 * n, "", co.id, _next(sc.runs[-1].period), "END",
                                                      False, sc.runs[-1].pay_run_date, ""))
            users = sorted((u for u in sc.users.values() if u.hired == date_first(sc) and not u.loan_until), key=lambda u: u.user_id)
            # rotate employees per test run so an earlier injected run never becomes the "normal" history
            plain_all = [u for u in users if not u.has_ot and not u.has_meal]
            k = (n * 7) % len(plain_all)
            plain = iter(plain_all[k:] + plain_all[:k])
            scen = {next(plain).user_id: s for s in ("salary_increase_no_revision", "duplicate_allowance",
                                                     "missing_recurring_allowance", "unexpected_net_increase",
                                                     "new_large_deduction", "cpf_missing", "approved_promotion")}
            ot_users = [u for u in users if u.has_ot]
            scen[ot_users[n % len(ot_users)].user_id] = "unusual_overtime"
            sc._ids[0] = 900000 + n * 1000
            run, recs, revs = make_analysis_run(sc, scen, seed=n)
            seed_revisions(c, sc, revs)
            seed_runs(c, sc, [run], recs)
        names = {u.user_id: u.employee_no for u in sc.users.values()}
        return {"payRunId": run.uid, "period": f"{run.period:%Y-%m}",
                "injected": [{"employeeNo": names[k], "scenario": v} for k, v in scen.items()]}

    print("open http://127.0.0.1:8080/prototype")
    uvicorn.run(app, host="127.0.0.1", port=8080, log_level="warning")


def _next(d):
    from datetime import date
    return date(d.year + (d.month == 12), d.month % 12 + 1, 1)


def date_first(sc):
    return min(u.hired for u in sc.users.values())


if __name__ == "__main__":
    main()
