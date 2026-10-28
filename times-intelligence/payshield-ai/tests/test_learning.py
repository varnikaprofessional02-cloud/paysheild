"""Learning from review decisions: tolerance matching, pattern suppression and per-type calibration (no database)."""

from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime, timezone

from app.services import learning


@dataclass
class A:  # the fields of AnomalyRecord the learner reads
    user_id: int
    anomaly_type: str
    metric: str | None
    current_value: float | None
    severity: str
    risk_score: int
    description: str = "finding"
    id: int = 1


class FakeLearning(learning.FeedbackLearning):
    def __init__(self, patterns, calibration=None):
        self.patterns, self.cal, self.updates = patterns, calibration or {}, []

    def _all(self, sql, p):
        if "FROM times_intelligence.learned_pattern" in sql and "SELECT" in sql:
            return self.patterns
        self.updates.append(p)
        return []

    def calibration(self, company_id):
        return self.cal


def pattern(value, **kw):
    return {"id": 7, "uid": "p-1", "user_id": 5, "anomaly_type": "UNUSUAL_SALARY_INCREASE", "metric": "basic_contractual",
            "accepted_value": value, "tolerance_pct": 5, "outcome": "EXPECTED_CHANGE", "learned_by": "u",
            "learned_on": datetime(2026, 10, 1, tzinfo=timezone.utc), **kw}


def test_within_tolerance():
    assert learning._within(10_400, 10_000, 5)
    assert not learning._within(10_600, 10_000, 5)
    assert learning._within(None, None, 5)
    assert not learning._within(None, 10_000, 5)


def test_accepted_value_is_not_raised_again_but_reported_as_learned():
    lr = FakeLearning([pattern(10_880)])
    same = A(5, "UNUSUAL_SALARY_INCREASE", "basic_contractual", 10_880, "CRITICAL", 95)
    keep, learned, lowered = lr.apply(1, [same])
    assert keep == [] and len(learned) == 1 and learned[0]["acceptedValue"] == 10_880 and lowered == []
    assert lr.updates and lr.updates[-1]["i"] == [7]  # applied_count is counted


def test_a_different_value_or_employee_is_still_raised():
    lr = FakeLearning([pattern(10_880)])
    bigger = A(5, "UNUSUAL_SALARY_INCREASE", "basic_contractual", 13_000, "CRITICAL", 95)
    other = A(6, "UNUSUAL_SALARY_INCREASE", "basic_contractual", 10_880, "CRITICAL", 95)
    keep, learned, _ = lr.apply(1, [bigger, other])
    assert keep == [bigger, other] and learned == []


def test_often_accepted_type_is_lowered_one_level():
    lr = FakeLearning([], {"UNUSUAL_OVERTIME": {"reviews": 4, "accepted": 4}})
    ot = A(9, "UNUSUAL_OVERTIME", "overtime_hours", 65, "HIGH", 85)
    keep, _, lowered = lr.apply(1, [ot])
    assert keep[0].severity == "MEDIUM" and keep[0].risk_score == 70 and lowered[0]["from"] == "HIGH"
    assert learning.max_severity(keep) == "MEDIUM"
