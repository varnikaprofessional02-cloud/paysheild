"""In-memory speed check for training and analysis (no database, no HTTP).

  python scripts/benchmark.py --employees 80 300 1000 3000 --months 24
"""

from __future__ import annotations

import argparse
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from app.core.config import MlSettings  # noqa: E402
from app.data.synthetic import generate_company, make_analysis_run  # noqa: E402
from app.domain.models import CompanyRef  # noqa: E402
from app.ml.model_bundle import ModelBundle  # noqa: E402
from app.ml.predictor import BundleScorer  # noqa: E402
from app.ml.trainer import train_company_model  # noqa: E402
from app.rules.engine import Thresholds  # noqa: E402
from app.services.payroll_analyzer import analyze  # noqa: E402

TENANT = "11111111-1111-4111-8111-111111111111"
COMPANY = CompanyRef(1, "aaaaaaa1-0000-4000-8000-000000000001", TENANT, "BEN")


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--employees", type=int, nargs="+", default=[80, 1000, 3000])
    ap.add_argument("--months", type=int, default=24)
    a = ap.parse_args()
    ml = MlSettings()
    print(f"{'employees':>9} {'records':>8} {'train s':>8} {'analyse s':>9} {'findings':>8}")
    for n in a.employees:
        sc = generate_company(1, tenant_uid=TENANT, company=COMPANY, n_employees=n, months=a.months)
        t0 = time.perf_counter()
        r = train_company_model(company=COMPANY, history_records=sc.records, ml=ml, overtime_codes=sc.overtime_codes)
        t1 = time.perf_counter()
        bundle = ModelBundle(TENANT, COMPANY.uid, "1.0.0", r.detector, r.pipeline, r.score_quantiles,
                             r.feature_medians, r.feature_scales, r.report)
        run, recs, revs = make_analysis_run(sc, {})
        t2 = time.perf_counter()
        out = analyze(pay_run=run, run_records=recs, history_records=sc.records, same_period_records=[],
                      revisions=sc.revisions + revs, configured=sc.configured, overtime_codes=sc.overtime_codes,
                      thresholds=Thresholds(), scorer=BundleScorer(bundle, "b"), ml=ml)
        t3 = time.perf_counter()
        print(f"{n:>9} {len(sc.records):>8} {t1 - t0:>8.1f} {t3 - t2:>9.1f} {len(out.findings):>8}", flush=True)


if __name__ == "__main__":
    main()
