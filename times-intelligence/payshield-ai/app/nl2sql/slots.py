"""Rule-based slot extraction: the month, counts, amounts, day windows and employee a question refers to.

normalise() replaces those values with placeholders, so the classifier learns the shape of a question and not the
particular month or number in its examples.
"""

from __future__ import annotations

import re
from dataclasses import dataclass
from datetime import date

_MONTHS = ("jan", "feb", "mar", "apr", "may", "jun", "jul", "aug", "sep", "oct", "nov", "dec")
_MONTH = (r"(jan(?:uary)?|feb(?:ruary)?|mar(?:ch)?|apr(?:il)?|may|june?|july?|aug(?:ust)?|"
          r"sep(?:t(?:ember)?)?|oct(?:ober)?|nov(?:ember)?|dec(?:ember)?)")
_MONTH_YEAR = re.compile(rf"(?<![a-z])(\w+\s+)?{_MONTH}(?![a-z])(?:\s*,?\s*(\d{{4}}))?", re.I)
_NUMERIC_PERIOD = re.compile(r"\b(?:(\d{1,2})[/-](\d{4})|(\d{4})-(\d{1,2}))\b")
_RELATIVE = re.compile(r"\b(this|current|last|previous|prior)\s+(month|period|payroll)\b", re.I)
_EMP_CODE = re.compile(r"\b([A-Za-z]{1,4}-?\d{2,6})\b")
_N = re.compile(r"\b(?:top|first|bottom|highest|lowest|last|past|previous)\s+(\d{1,3})\b"
                r"|\b(\d{1,3})\s+(?:best|highest|top|biggest|largest|lowest|most)\b", re.I)
_AMOUNT = re.compile(r"(?:over|above|more than|greater than|exceed(?:s|ing)?|at least|beyond|>)\s*(?:s?\$)?\s*"
                     r"(\d[\d,]*(?:\.\d+)?)\s*(k\b)?", re.I)
_DAYS = re.compile(r"\b(?:within|next|in|coming)\s+(?:the\s+)?(?:next\s+)?(\d{1,3})\s*(day|week|month)s?\b", re.I)
_NAME = re.compile(r"(?<!^)(?<![.?!]\s)\b([A-Z][a-z'-]+(?:\s+[A-Z][a-z'-]+){0,3})")
_NOT_NAMES = {"I", "CPF", "OT", "SDL", "SHG", "EP", "SP", "WP", "PR", "MOM", "Singapore", "Singaporean"}


@dataclass
class Slots:
    period: date | None = None
    n: int | None = None
    amount: float | None = None
    days: int | None = None
    employee: str | None = None


def _shift(d: date, months: int) -> date:
    m = d.year * 12 + d.month - 1 + months
    return date(m // 12, m % 12 + 1, 1)


def _period(q: str, today: date) -> date | None:
    m = _NUMERIC_PERIOD.search(q)
    if m:
        month, year = (int(m.group(1)), int(m.group(2))) if m.group(1) else (int(m.group(4)), int(m.group(3)))
        if 1 <= month <= 12:
            return date(year, month, 1)
    for m in _MONTH_YEAR.finditer(q):
        word, name, year = (m.group(1) or "").strip().lower(), m.group(2).lower(), m.group(3)
        if name == "may" and not year and word not in ("in", "for", "of", "during"):
            continue  # "may" as a verb
        month = _MONTHS.index(name[:3]) + 1
        if year:
            return date(int(year), month, 1)
        # no year: the most recent such month that is not in the future
        return date(today.year if month <= today.month else today.year - 1, month, 1)
    m = _RELATIVE.search(q)
    if m:
        return _shift(today.replace(day=1), 0 if m.group(1).lower() in ("this", "current") else -1)
    return None


def _employee(q: str) -> str | None:
    for m in _EMP_CODE.finditer(q):
        code = m.group(1)
        if any(c.isdigit() for c in code) and code.lower()[:3] not in _MONTHS and not re.fullmatch(r"\d+", code):
            return code.upper()
    for m in _NAME.finditer(q):
        words = [w for w in re.sub(r"'s$", "", m.group(1)).split() if w not in _NOT_NAMES and w.lower()[:3] not in _MONTHS]
        if words:
            return " ".join(words)
    return None


def extract(question: str, today: date) -> Slots:
    q = question.strip()
    s = Slots(period=_period(q, today), employee=_employee(q))
    m = _N.search(q)
    if m:
        s.n = int(m.group(1) or m.group(2))
    m = _AMOUNT.search(q)
    if m:
        s.amount = float(m.group(1).replace(",", "")) * (1000 if m.group(2) else 1)
    m = _DAYS.search(q)
    if m:
        s.days = int(m.group(1)) * {"day": 1, "week": 7, "month": 30}[m.group(2).lower()]
    return s


def normalise(question: str) -> str:
    q = question.lower()
    q = _NUMERIC_PERIOD.sub(" monthref ", q)
    q = re.sub(rf"(?<![a-z]){_MONTH}(?![a-z])(\s*,?\s*\d{{4}})?", " monthref ", q)
    q = _EMP_CODE.sub(lambda m: " empref " if any(c.isdigit() for c in m.group(1)) and any(c.isalpha() for c in m.group(1)) else m.group(0), q)
    q = re.sub(r"\d[\d,.]*k?", " num ", q)
    return re.sub(r"\s+", " ", q).strip()
