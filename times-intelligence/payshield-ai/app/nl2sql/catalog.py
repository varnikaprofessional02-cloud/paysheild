"""The question catalogue (templates.yaml): fixed, read-only SQL per intent, with shared SQL fragments expanded."""

from __future__ import annotations

import hashlib
import re
from dataclasses import dataclass, field
from functools import lru_cache
from pathlib import Path

import yaml

TEMPLATES = Path(__file__).with_name("templates.yaml")
UNSUPPORTED = "_unsupported"
SLOT_NAMES = ("period", "n", "amount", "days", "employee")

# shared fragments: pay records of the company joined to their pay run and pay period, and the data_processed paths
# (same envelope as app/data/parsing.py: Money is {amount, currency})
MACROS = {
    "RUNS": "payroll.pay_record pr JOIN payroll.pay_run r ON r.id = pr.pay_run_id "
            "JOIN payroll.pay_period pp ON pp.id = r.pay_period_id AND pp.company_id = %(c)s",
    "EMP_JOIN": "JOIN employee.user_company_contract ucc ON ucc.id = pr.contract_id AND ucc.company_id = %(c)s "
                'JOIN security."user" u ON u.id = ucc.user_id',
    "IN_PERIOD": "pp.value = to_char(%(period)s::date, 'MM/YYYY')",
    "NET": "COALESCE((pr.data_processed #>> '{payRecord,nettPay,amount}')::numeric, pr.total_payout, 0)",
    "GROSS": "COALESCE((pr.data_processed #>> '{payRecord,grossPay,amount}')::numeric, 0)",
    "CPF_EE": "COALESCE((pr.data_processed #>> '{payRecord,cpfCalculationResult,totalEmployeeContribution,amount}')::numeric, 0)",
    "CPF_ER": "COALESCE((pr.data_processed #>> '{payRecord,cpfCalculationResult,totalEmployerContribution,amount}')::numeric, 0)",
    "ITEMS": "CROSS JOIN LATERAL json_array_elements(CASE WHEN json_typeof(pr.data_processed #> "
             "'{payRecord,allowanceDeductionCalculationResult,payComponentResults}') = 'array' THEN pr.data_processed #> "
             "'{payRecord,allowanceDeductionCalculationResult,payComponentResults}' ELSE '[]'::json END) it",
    "ITEM_CODE": "(it #>> '{payComponent,payCode,code}')",
    "ITEM_NAME": "(it #>> '{payComponent,payCode,description}')",
    "ITEM_AMT": "abs(COALESCE((it #>> '{amount,amount}')::numeric, 0))",
    "ITEM_HOURS": "COALESCE((it #>> '{payComponent,amountType,frequency}')::numeric, 0)",
    "ITEM_EARN": "COALESCE((it #>> '{payComponent,isEarning}')::boolean, (it #>> '{payComponent,type}') IN ('1', 'Earning'))",
    "ITEM_IS_OT": "(it #>> '{payComponent,payCode,code}') = ANY(COALESCE((SELECT s.overtime_pay_codes FROM "
                  "times_intelligence.company_setting s WHERE s.company_id = %(c)s), '{}'::text[]))",
}
_MACRO = re.compile(r"@([A-Z_]+)@")


@dataclass(frozen=True)
class Intent:
    id: str
    title: str
    sql: str
    slots: dict = field(default_factory=dict)
    phrasings: tuple[str, ...] = ()


def expand(sql: str) -> str:
    def sub(m: re.Match) -> str:
        if m.group(1) not in MACROS:
            raise ValueError(f"unknown SQL fragment @{m.group(1)}@")
        return MACROS[m.group(1)]
    return _MACRO.sub(sub, sql).strip()


@lru_cache(maxsize=1)
def load(path: Path = TEMPLATES) -> dict[str, Intent]:
    doc = yaml.safe_load(path.read_text(encoding="utf-8"))
    out: dict[str, Intent] = {}
    for d in doc["intents"]:
        unknown = set(d.get("slots") or {}) - set(SLOT_NAMES)
        if unknown:
            raise ValueError(f"{d['id']}: unknown slots {unknown}")
        out[d["id"]] = Intent(d["id"], d["title"], expand(d.get("sql") or ""), dict(d.get("slots") or {}),
                              tuple(d.get("phrasings") or ()))
    return out


def fingerprint(path: Path = TEMPLATES) -> str:
    """Changes whenever the catalogue changes, so a saved classifier trained on an older catalogue is not used."""
    return hashlib.sha256(path.read_bytes()).hexdigest()[:16]
