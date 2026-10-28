"""Skills taught to the PayShield Agent, and the questions it could not answer (no LLM involved).

Matching: both texts are reduced to content words (lower case, stop words removed, simple stemming, a few payroll
synonyms), then compared with a weighted overlap (Dice coefficient, rare words count more). A skill answers when its
best example question scores at least MATCH_AT.
"""

from __future__ import annotations

import re
from typing import Any

from app.core.errors import NotFound, ValidationFailed
from app.db.connection import ConnectionManager

MATCH_AT = 0.6
_STOP = set("""a an the is are was were be been am do does did of to in on at for by with and or but if then than this that these those
it its our we us you your i me my they them their he she his her what which who whom whose how when where why can could
should would will shall may might must please tell show give list me any all some there here about from into as so just
get got have has had much many""".split())
_SYN = {"salary": "pay", "earner": "pay", "big": "highest", "high": "highest", "small": "lowest", "low": "lowest", "salaries": "pay", "wage": "pay", "wages": "pay", "earn": "pay", "earning": "pay", "earnings": "pay",
        "income": "pay", "paid": "pay", "staff": "employee", "staffs": "employee", "people": "employee", "worker": "employee",
        "workers": "employee", "headcount": "employee", "emp": "employee", "ot": "overtime", "biggest": "highest", "largest": "highest",
        "top": "highest", "maximum": "highest", "max": "highest", "smallest": "lowest", "minimum": "lowest"}


def words(text: str) -> list[str]:
    out = []
    for w in re.findall(r"[a-z0-9]+", (text or "").lower()):
        if w in _STOP or len(w) < 2:
            continue
        w = _SYN.get(w, w)
        for suf in ("ings", "ing", "ies", "ed", "es", "s"):
            if len(w) > 4 and w.endswith(suf):
                w = w[: -len(suf)] + ("y" if suf == "ies" else "")
                break
        out.append(_SYN.get(w, w))
    return out


def similarity(a: str, b: str) -> float:
    x, y = set(words(a)), set(words(b))
    if not x or not y:
        return 0.0
    weight = lambda w: 1.0 + min(1.0, len(w) / 8) + (0.5 if w.isdigit() else 0)  # noqa: E731 - longer words carry more meaning
    both = sum(weight(w) for w in x & y)
    return 2 * both / (sum(weight(w) for w in x) + sum(weight(w) for w in y))


class AgentSkills:
    def __init__(self, conn: ConnectionManager, db_name: str):
        self.conn, self.db = conn, db_name

    def _all(self, sql: str, p: dict[str, Any]) -> list[dict]:
        with self.conn.connection(self.db) as c:
            cur = c.execute(sql, p)
            return cur.fetchall() if cur.description else []

    _COLS = """uid::text AS uid, phrases, kind, answer, route, used_count, last_used_on, helpful, not_helpful, created_by, created_on"""

    def list(self, company_id: int) -> list[dict]:
        return self._all(f"SELECT {self._COLS} FROM times_intelligence.agent_skill WHERE company_id = %(c)s AND is_active ORDER BY created_on DESC",
                         {"c": company_id})

    def match(self, company_id: int, question: str) -> dict:
        best, score = None, 0.0
        for s in self._all(f"SELECT id, {self._COLS} FROM times_intelligence.agent_skill WHERE company_id = %(c)s AND is_active", {"c": company_id}):
            sc = max((similarity(question, p) for p in s["phrases"]), default=0.0)
            if sc > score:
                best, score = s, sc
        if best is None or score < MATCH_AT:
            return {"skill": None, "score": round(score, 3)}
        self._all("UPDATE times_intelligence.agent_skill SET used_count = used_count + 1, last_used_on = now() WHERE id = %(i)s", {"i": best["id"]})
        best.pop("id")
        return {"skill": best, "score": round(score, 3)}

    def create(self, company_id: int, phrases: list[str], kind: str, answer: str | None, route: str | None, actor: str) -> dict:
        phrases = [p.strip() for p in phrases if p and p.strip()]
        if not phrases:
            raise ValidationFailed("PHRASE_REQUIRED", "Add at least one example question.")
        if kind == "ANSWER" and not (answer or "").strip() or kind == "ROUTE" and not (route or "").strip():
            raise ValidationFailed("CONTENT_REQUIRED", "Give the answer, or the question it should be treated as.")
        row = self._all(f"""INSERT INTO times_intelligence.agent_skill (company_id, phrases, kind, answer, route, created_by)
            VALUES (%(c)s, %(p)s, %(k)s, %(a)s, %(r)s, %(u)s) RETURNING id, {self._COLS}""",
                        {"c": company_id, "p": phrases, "k": kind, "a": (answer or "").strip() or None, "r": (route or "").strip() or None, "u": actor})[0]
        self._resolve_gaps(company_id, row["id"], phrases)
        row.pop("id")
        return row

    def update(self, company_id: int, uid: str, *, add_phrase: str | None = None, answer: str | None = None, route: str | None = None,
               helpful: bool | None = None, actor: str) -> dict:
        r = self._all("SELECT id, phrases FROM times_intelligence.agent_skill WHERE company_id = %(c)s AND uid = %(u)s::uuid AND is_active",
                      {"c": company_id, "u": uid})
        if not r:
            raise NotFound("SKILL_NOT_FOUND", "Nothing taught with that id.")
        phrases = r[0]["phrases"]
        if add_phrase and add_phrase.strip() and all(similarity(add_phrase, p) < 0.95 for p in phrases):
            phrases = phrases + [add_phrase.strip()]
        row = self._all(f"""UPDATE times_intelligence.agent_skill SET phrases = %(p)s,
                answer = CASE WHEN kind = 'ANSWER' THEN coalesce(%(a)s, answer) ELSE answer END,
                route = CASE WHEN kind = 'ROUTE' THEN coalesce(%(r)s, route) ELSE route END,
                helpful = helpful + %(h)s, not_helpful = not_helpful + %(n)s, updated_by = %(by)s, updated_on = now()
            WHERE id = %(i)s RETURNING {self._COLS}""",
                        {"p": phrases, "a": (answer or "").strip() or None, "r": (route or "").strip() or None,
                         "h": int(helpful is True), "n": int(helpful is False), "by": actor, "i": r[0]["id"]})[0]
        if add_phrase:
            self._resolve_gaps(company_id, r[0]["id"], [add_phrase])
        return row

    def delete(self, company_id: int, uid: str) -> None:
        if not self._all("""UPDATE times_intelligence.agent_skill SET is_active = false WHERE company_id = %(c)s AND uid = %(u)s::uuid
                            AND is_active RETURNING id""", {"c": company_id, "u": uid}):
            raise NotFound("SKILL_NOT_FOUND", "Nothing taught with that id.")

    # questions the agent could not answer ---------------------------------------------------------
    def record_gap(self, company_id: int, question: str) -> None:
        norm = " ".join(sorted(set(words(question))))
        if not norm:
            return
        self._all("""INSERT INTO times_intelligence.agent_gap (company_id, question, norm) VALUES (%(c)s, %(q)s, %(n)s)
            ON CONFLICT (company_id, norm) DO UPDATE SET times_asked = agent_gap.times_asked + 1, last_asked = now(),
                question = EXCLUDED.question, resolved_by_skill = NULL""", {"c": company_id, "q": question.strip(), "n": norm})

    def gaps(self, company_id: int) -> list[dict]:
        return self._all("""SELECT uid::text AS uid, question, times_asked, first_asked, last_asked FROM times_intelligence.agent_gap
            WHERE company_id = %(c)s AND resolved_by_skill IS NULL ORDER BY last_asked DESC LIMIT 50""", {"c": company_id})

    def dismiss_gap(self, company_id: int, uid: str) -> None:
        self._all("DELETE FROM times_intelligence.agent_gap WHERE company_id = %(c)s AND uid = %(u)s::uuid", {"c": company_id, "u": uid})

    def _resolve_gaps(self, company_id: int, skill_id: int, phrases: list[str]) -> None:
        for g in self._all("SELECT id, question FROM times_intelligence.agent_gap WHERE company_id = %(c)s AND resolved_by_skill IS NULL",
                           {"c": company_id}):
            if max(similarity(g["question"], p) for p in phrases) >= MATCH_AT:
                self._all("UPDATE times_intelligence.agent_gap SET resolved_by_skill = %(s)s WHERE id = %(i)s", {"s": skill_id, "i": g["id"]})

