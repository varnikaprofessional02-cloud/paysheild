"""End-to-end (in-memory) payroll scenarios: train on a synthetic company, inject known anomalies into a new
run, and check that each is detected while legitimate changes are not reported as errors."""

from __future__ import annotations

import pytest

from app.core.config import MlSettings
from app.data.synthetic import generate_company, make_analysis_run
from app.domain.enums import AnomalyType as T, Severity
from app.domain.models import CompanyRef
from app.ml.model_bundle import ModelBundle
from app.ml.predictor import BundleScorer
from app.ml.scoring import BaselineOnlyScorer
from app.ml.trainer import train_company_model
from app.rules.engine import Thresholds
from app.services.payroll_analyzer import analyze

TENANT = "11111111-1111-4111-8111-111111111111"
COMPANY = CompanyRef(1, "aaaaaaa1-0000-4000-8000-000000000001", TENANT)


@pytest.fixture(scope="module")
def world():
    sc = generate_company(1, tenant_uid=TENANT, company=COMPANY)
    users = sorted((u for u in sc.users.values() if u.hired == sc.runs[0].period and not u.loan_until), key=lambda u: u.user_id)
    pick = iter(u for u in users if not u.has_ot and not u.has_meal)
    ot_user = next(u for u in users if u.has_ot)
    scen = {next(pick).user_id: s for s in ("salary_increase_no_revision", "duplicate_allowance", "missing_recurring_allowance",
                                            "unexpected_net_increase", "new_large_deduction", "cpf_missing",
                                            "approved_promotion", "december_bonus")}
    scen[ot_user.user_id] = "unusual_overtime"
    ml = MlSettings()
    result = train_company_model(company=COMPANY, history_records=sc.records, ml=ml, overtime_codes=sc.overtime_codes)
    bundle = ModelBundle(TENANT, COMPANY.uid, "1.1.0", result.detector, result.pipeline, result.score_quantiles,
                         result.feature_medians, result.feature_scales, result.report)
    run, recs, revs = make_analysis_run(sc, scen)
    out = analyze(pay_run=run, run_records=recs, history_records=sc.records, same_period_records=[],
                  revisions=sc.revisions + revs, configured=sc.configured, overtime_codes=sc.overtime_codes,
                  thresholds=Thresholds(), scorer=BundleScorer(bundle, "m1"), ml=ml)
    by_scen = {s: [f for f in out.findings if f.user_id == uid] for uid, s in scen.items()}
    normal = [f for f in out.findings if f.user_id not in scen]
    return sc, result, out, by_scen, normal


def _types(findings):
    return {f.anomaly_type for f in findings}


def test_training_succeeds_with_both_detectors_evaluated(world):
    _, result, *_ = world
    assert result.status == "SUCCEEDED"
    assert set(result.report["detectors"]) == {"ISOLATION_FOREST", "ROBUST_BASELINE"}


def test_a_salary_increase_without_revision(world):
    f = world[3]["salary_increase_no_revision"]
    hit = [x for x in f if x.anomaly_type == T.UNUSUAL_SALARY_INCREASE]
    assert hit and hit[0].severity == Severity.CRITICAL and hit[0].change_pct == pytest.approx(50, abs=1)


def test_b_duplicate_allowance(world):
    assert T.DUPLICATE_ALLOWANCE in _types(world[3]["duplicate_allowance"])


def test_c_unusual_overtime(world):
    assert T.UNUSUAL_OVERTIME in _types(world[3]["unusual_overtime"])


def test_d_missing_allowance(world):
    assert T.MISSING_RECURRING_ALLOWANCE in _types(world[3]["missing_recurring_allowance"])


def test_e_unexpected_net(world):
    assert T.UNEXPECTED_NET_PAY_CHANGE in _types(world[3]["unexpected_net_increase"])


def test_f_new_deduction(world):
    assert T.NEW_DEDUCTION in _types(world[3]["new_large_deduction"])


def test_g_cpf_missing(world):
    assert T.STATUTORY_MISSING_CONTRIBUTION in _types(world[3]["cpf_missing"])


def test_approved_promotion_is_not_an_error(world):
    f = world[3]["approved_promotion"]
    assert not any(x.severity.rank >= Severity.HIGH.rank for x in f)
    assert T.UNUSUAL_SALARY_INCREASE not in _types(f)


def test_legitimate_bonus_is_not_an_error(world):
    assert not [x for x in world[3]["december_bonus"] if x.severity.rank >= Severity.HIGH.rank]


def test_normal_employees_mostly_clean(world):
    _, _, out, _, normal = world
    high = [f for f in normal if f.severity.rank >= Severity.HIGH.rank]
    assert len(high) <= 1, [(f.user_id, f.description) for f in high]


def test_expected_value_only_when_computed(world):
    for f in world[2].findings:
        if f.expected_value is not None:
            assert f.expected_method


def test_insufficient_history_gives_no_model_finding():
    sc = generate_company(2, tenant_uid=TENANT, company=COMPANY, n_employees=5, months=2)
    run, recs, _ = make_analysis_run(sc, {})
    out = analyze(pay_run=run, run_records=recs, history_records=sc.records, same_period_records=[], revisions=[],
                  configured=[], overtime_codes=frozenset(), thresholds=Thresholds(), scorer=BaselineOnlyScorer(),
                  ml=MlSettings())
    assert not [f for f in out.findings if f.source.value in ("ML", "BASELINE")]


def test_insufficient_data_training():
    sc = generate_company(3, tenant_uid=TENANT, company=COMPANY, n_employees=5, months=4)
    r = train_company_model(company=COMPANY, history_records=sc.records, ml=MlSettings())
    assert r.status == "INSUFFICIENT_DATA" and r.pipeline is None
