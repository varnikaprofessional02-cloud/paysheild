"""The company model learns from review decisions (times_intelligence.learned_pattern).

* Accept a finding as expected (EXPECTED_CHANGE / FALSE_POSITIVE): its value becomes a learned pattern for that employee.
  In later analyses the same kind of finding at about the same value (within tolerance) is not raised; it is reported
  as "learned" instead, so a reviewer can still see what was let through and why.
* Mark it a real error (CONFIRMED_ERROR) or ask to investigate: the pattern learned from that finding is removed.
* Self-correction per finding type: when reviewers keep accepting one type of finding (at least MIN_REVIEWS decisions and
  ACCEPT_SHARE of them accepted), new findings of that type are lowered one severity level.
"""

from __future__ import annotations

from dataclasses import replace
from typing import Any

from app.db.connection import ConnectionManager

ACCEPTED = ("EXPECTED_CHANGE", "FALSE_POSITIVE")
MIN_REVIEWS, ACCEPT_SHARE = 3, 0.8
LOWER = {"CRITICAL": "HIGH", "HIGH": "MEDIUM", "MEDIUM": "LOW", "LOW": "LOW"}
_RANK = {"LOW": 1, "MEDIUM": 2, "HIGH": 3, "CRITICAL": 4}


class FeedbackLearning:
    def __init__(self, conn: ConnectionManager, db_name: str):
        self.conn, self.db = conn, db_name

    def _all(self, sql: str, p: dict[str, Any]) -> list[dict]:
        with self.conn.connection(self.db) as c:
            cur = c.execute(sql, p)
            return cur.fetchall() if cur.description else []

    # learning from one decision ------------------------------------------------------------------
    def learn(self, company_id: int, anomaly, outcome: str, actor: str) -> dict | None:
        if outcome not in ACCEPTED:
            # a real error (or "investigate") undoes what was learned from this finding
            self._all("""UPDATE times_intelligence.learned_pattern SET is_active = false, forgotten_by = %(u)s, forgotten_on = now()
                         WHERE company_id = %(c)s AND source_anomaly_id = %(a)s AND is_active""",
                      {"c": company_id, "a": anomaly.id, "u": actor})
            return None
        with self.conn.connection(self.db) as c, c.transaction():
            c.execute("""UPDATE times_intelligence.learned_pattern SET is_active = false, forgotten_by = %(u)s, forgotten_on = now()
                         WHERE company_id = %(c)s AND user_id = %(e)s AND anomaly_type = %(t)s AND metric IS NOT DISTINCT FROM %(m)s AND is_active""",
                      {"c": company_id, "e": anomaly.user_id, "t": anomaly.anomaly_type, "m": anomaly.metric, "u": actor})
            return c.execute("""INSERT INTO times_intelligence.learned_pattern (company_id, user_id, anomaly_type, metric, accepted_value,
                    outcome, source_anomaly_id, description, learned_by)
                VALUES (%(c)s, %(e)s, %(t)s, %(m)s, %(v)s, %(o)s, %(a)s, %(d)s, %(u)s) RETURNING uid::text AS uid""",
                             {"c": company_id, "e": anomaly.user_id, "t": anomaly.anomaly_type, "m": anomaly.metric,
                              "v": anomaly.current_value, "o": outcome, "a": anomaly.id, "d": anomaly.description, "u": actor}).fetchone()

    # applying what was learned to a new analysis ------------------------------------------------
    def calibration(self, company_id: int) -> dict[str, dict]:
        """Finding types reviewers keep accepting: {type: {reviews, accepted}} for the ones to lower."""
        rows = self._all("""SELECT a.anomaly_type, count(*) AS reviews, count(*) FILTER (WHERE fb.code = ANY(%(ok)s)) AS accepted
            FROM times_intelligence.anomaly a
            JOIN times_intelligence.analysis x ON x.id = a.analysis_id AND x.status <> 'SUPERSEDED'
            JOIN LATERAL (SELECT o.code FROM times_intelligence.feedback f JOIN times_intelligence.lk_feedback_outcome o ON o.id = f.outcome_id
                          WHERE f.anomaly_id = a.id ORDER BY f.created_on DESC, f.id DESC LIMIT 1) fb ON true
            WHERE a.company_id = %(c)s GROUP BY a.anomaly_type""", {"c": company_id, "ok": list(ACCEPTED)})
        return {r["anomaly_type"]: {"reviews": r["reviews"], "accepted": r["accepted"]} for r in rows
                if r["reviews"] >= MIN_REVIEWS and r["accepted"] >= ACCEPT_SHARE * r["reviews"]}

    def apply(self, company_id: int, anomalies: list) -> tuple[list, list[dict], list[dict]]:
        """Returns (findings to raise, findings let through by a learned pattern, findings lowered by calibration)."""
        if not anomalies:
            return anomalies, [], []
        pats = self._all("""SELECT id, uid::text AS uid, user_id, anomaly_type, metric, accepted_value, tolerance_pct, outcome,
                learned_by, learned_on FROM times_intelligence.learned_pattern
            WHERE company_id = %(c)s AND is_active AND user_id = ANY(%(u)s)""", {"c": company_id, "u": sorted({a.user_id for a in anomalies})})
        cal = self.calibration(company_id)
        keep, learned, lowered, used = [], [], [], []
        for a in anomalies:
            p = next((p for p in pats if p["user_id"] == a.user_id and p["anomaly_type"] == a.anomaly_type and p["metric"] == a.metric
                      and _within(a.current_value, p["accepted_value"], float(p["tolerance_pct"]))), None)
            if p:
                used.append(p["id"])
                learned.append({"userId": a.user_id, "anomalyType": a.anomaly_type, "metric": a.metric, "currentValue": a.current_value,
                                "acceptedValue": None if p["accepted_value"] is None else float(p["accepted_value"]),
                                "patternId": p["uid"], "learnedBy": p["learned_by"], "learnedOn": p["learned_on"].isoformat(),
                                "description": a.description})
                continue
            c = cal.get(a.anomaly_type)
            if c and a.severity != "LOW":
                lowered.append({"userId": a.user_id, "anomalyType": a.anomaly_type, "from": a.severity, "to": LOWER[a.severity], **c})
                a = replace(a, severity=LOWER[a.severity], risk_score=max(1, a.risk_score - 15),
                            description=f"{a.description} (Lowered from {a.severity.lower()}: reviewers accepted {c['accepted']} of {c['reviews']} findings like this.)")
            keep.append(a)
        if used:
            self._all("""UPDATE times_intelligence.learned_pattern SET applied_count = applied_count + 1, last_applied_on = now()
                         WHERE id = ANY(%(i)s)""", {"i": used})
        return keep, learned, lowered

    # what the model learned (for the UI) --------------------------------------------------------
    def list(self, company_id: int) -> dict:
        pats = self._all("""SELECT p.uid::text AS uid, ucc.employee_no, trim(u.first_name || ' ' || u.last_name) AS name, p.anomaly_type, p.metric,
                p.accepted_value, p.tolerance_pct, p.outcome, p.description, p.applied_count, p.last_applied_on, p.learned_by, p.learned_on
            FROM times_intelligence.learned_pattern p
            JOIN security."user" u ON u.id = p.user_id
            LEFT JOIN employee.user_company_contract ucc ON ucc.user_id = p.user_id AND ucc.company_id = p.company_id
            WHERE p.company_id = %(c)s AND p.is_active ORDER BY p.learned_on DESC""", {"c": company_id})
        cal = self.calibration(company_id)
        return {"patterns": pats, "calibrations": [{"anomalyType": t, **v} for t, v in sorted(cal.items())],
                "rules": {"tolerancePct": 5, "minReviews": MIN_REVIEWS, "acceptShare": ACCEPT_SHARE}}

    def forget(self, company_id: int, uid: str, actor: str) -> int:
        return len(self._all("""UPDATE times_intelligence.learned_pattern SET is_active = false, forgotten_by = %(u)s, forgotten_on = now()
            WHERE company_id = %(c)s AND uid = %(p)s::uuid AND is_active RETURNING id""", {"c": company_id, "p": uid, "u": actor}))


def _within(value, accepted, tol_pct: float) -> bool:
    if accepted is None:
        return True
    if value is None:
        return False
    accepted = float(accepted)
    return abs(float(value) - accepted) <= max(abs(accepted) * tol_pct / 100, 0.01)


def max_severity(anomalies: list) -> str | None:
    return max((a.severity for a in anomalies), key=lambda s: _RANK[s], default=None)
