"""Deterministic payroll validation rules (ARCHITECTURE section 7). Rules never block payroll; each
returns Findings with evidence. CPF is never recomputed: statutory rules only compare engine output
with the employee's own history and surface the engine's own flags."""

from __future__ import annotations

import logging
import math
from dataclasses import dataclass, field, fields
from datetime import date
from typing import Callable

from app.data.observations import Observation
from app.domain.enums import AnomalyType as T, Confidence, FindingSource as S, Severity as V
from app.domain.models import ConfiguredPayItem, Evidence, Finding, PayRecordSnapshot, SalaryRevision
from app.ml.baseline import robust_stats

log = logging.getLogger(__name__)


@dataclass(frozen=True)
class Thresholds:
    salary_change_pct: float = 10.0
    salary_change_high_pct: float = 30.0
    large_revision_pct: float = 30.0
    late_revision_days: int = 3
    missing_allowance_periods: int = 3
    missing_allowance_high_amount: float = 500.0
    amount_rz: float = 4.0
    allowance_change_pct: float = 50.0
    overtime_ratio: float = 2.5
    net_change_pct: float = 25.0
    net_unexplained_pct: float = 15.0
    new_deduction_min_pct_of_gross: float = 5.0
    deduction_change_pct: float = 50.0
    cpf_rate_change_pp: float = 2.0
    baseline_alert_rz: float = 6.0
    alert_percentile: float = 97.0

    @classmethod
    def from_overrides(cls, overrides: dict | None) -> tuple["Thresholds", list[str]]:
        names = {f.name: f.type for f in fields(cls)}
        values, warnings = {}, []
        for k, v in (overrides or {}).items():
            if k not in names:
                warnings.append(f"unknown threshold '{k}' ignored")
            elif isinstance(v, (int, float)) and not isinstance(v, bool) and v >= 0:
                values[k] = int(v) if names[k] in ("int", int) else float(v)
            else:
                warnings.append(f"invalid value for threshold '{k}' ignored")
        return cls(**values), warnings


@dataclass
class RuleContext:
    obs: Observation
    window: list[Observation]
    history_key: str
    run_date: date
    revisions: list[SalaryRevision]
    configured: list[ConfiguredPayItem]
    same_period_other_runs: list[Observation]
    overtime_tracked: bool
    t: Thresholds
    company_overtime_p99: float | None = None


def _fmt(v: float | None) -> str:
    return "n/a" if v is None else f"{v:,.2f}"


def _ym(d: date) -> str:
    return f"{d:%Y-%m}"


def _pct(cur: float | None, ref: float | None) -> float | None:
    if cur is None or ref in (None, 0):
        return None
    return (cur - ref) / abs(ref) * 100.0


def _finding(ctx: RuleContext, typ: T, sev: V, rule: str, desc: str, action: str, *, source: S = S.RULE,
             metric: str | None = None, current: float | None = None, expected=None, change: float | None = None,
             evidence: list[Evidence] | None = None, explained: bool = False) -> Finding:
    stats = expected
    ev = [Evidence("pay_record", r.pay_record_uid, {"period": _ym(r.period), "cycle": r.cycle_code}) for r in ctx.obs.records]
    return Finding(
        anomaly_type=typ, source=source, severity=sev, user_id=ctx.obs.user_id, contract_id=ctx.obs.contract_id,
        pay_record_id=ctx.obs.latest.pay_record_id, description=desc, recommended_action=action, rule_id=rule,
        metric=metric, current_value=current,
        expected_value=stats.median if stats else None, expected_low=stats.low if stats else None,
        expected_high=stats.high if stats else None, expected_method=f"median_{stats.n}_periods" if stats else None,
        change_pct=round(change, 2) if change is not None else None, is_explained=explained,
        evidence=ev + (evidence or []),
    )


def _history(ctx: RuleContext, getter: Callable[[Observation], float | None]):
    return robust_stats([getter(o) for o in ctx.window])


# ------------------------------------------------------------------------------ salary
def _revisions_in(ctx: RuleContext, start: date, end_inclusive: date) -> list[SalaryRevision]:
    return [r for r in ctx.revisions
            if r.contract_id == ctx.obs.contract_id or ctx.history_key == "user"
            if start < r.effective_date <= end_inclusive and r.created_on.date() <= ctx.run_date]


def rule_salary(ctx: RuleContext) -> list[Finding]:
    if not ctx.window:
        return []
    prev = ctx.window[-1]
    cur, ref = ctx.obs.basic_contractual, prev.basic_contractual
    change = _pct(cur, ref)
    if change is None or abs(change) < ctx.t.salary_change_pct:
        return []
    from calendar import monthrange
    period_end = date(ctx.obs.period.year, ctx.obs.period.month, monthrange(ctx.obs.period.year, ctx.obs.period.month)[1])
    revs = _revisions_in(ctx, prev.period, period_end)
    ev = [Evidence("history", _ym(prev.period), {"basic_contractual": ref})]
    if revs:
        r = revs[-1]
        ev.append(Evidence("salary_revision", r.uid, {"code": r.code, "old": r.old_salary, "new": r.new_salary,
                                                      "effective_date": r.effective_date.isoformat()}))
        late = (ctx.run_date - r.created_on.date()).days <= ctx.t.late_revision_days and r.effective_date < ctx.obs.period
        if abs(change) >= ctx.t.large_revision_pct or late:
            return [_finding(ctx, T.LARGE_SALARY_REVISION, V.MEDIUM, "SAL-002",
                             f"Basic salary changed {change:+.1f}% from {_fmt(ref)} to {_fmt(cur)}; explained by salary revision "
                             f"{r.code} effective {r.effective_date:%Y-%m-%d}" + (" entered just before the run." if late else "."),
                             "Confirm the revision was approved under the company's policy.", metric="basic_contractual",
                             current=cur, change=change, evidence=ev, explained=True)]
        return []
    typ = T.UNUSUAL_SALARY_INCREASE if change > 0 else T.UNUSUAL_SALARY_DECREASE
    sev = V.CRITICAL if abs(change) >= ctx.t.salary_change_high_pct else V.HIGH
    return [_finding(ctx, typ, sev, "SAL-001",
                     f"Basic salary {'increased' if change > 0 else 'decreased'} {abs(change):.1f}% from {_fmt(ref)} to {_fmt(cur)} "
                     f"with no salary revision effective in {_ym(ctx.obs.period)}.",
                     "Verify an approved salary revision exists or correct the contract salary.",
                     metric="basic_contractual", current=cur, expected=_history(ctx, lambda o: o.basic_contractual),
                     change=change, evidence=ev)]


# ------------------------------------------------------------------------------ allowances
def rule_duplicate_allowance(ctx: RuleContext) -> list[Finding]:
    out = []
    for r in ctx.obs.records:
        by_code: dict[str, list] = {}
        for i in r.items:
            if i.is_earning and not i.is_adhoc:
                by_code.setdefault(i.code, []).append(i)
        for code, lines in by_code.items():
            if len(lines) < 2:
                continue
            amounts = sorted(i.amount for i in lines)
            same = any(abs(a - b) <= 0.01 for a, b in zip(amounts, amounts[1:]))
            out.append(_finding(ctx, T.DUPLICATE_ALLOWANCE, V.HIGH if same else V.LOW, "ALW-001" if same else "ALW-002",
                                f"{len(lines)} '{code}' lines in one pay record ({', '.join(_fmt(a) for a in amounts)})"
                                + (" with identical amounts." if same else "."),
                                "Remove the duplicate line or confirm both payments are intended.",
                                metric=f"item:{code}", current=sum(amounts),
                                evidence=[Evidence("pay_item", i.component_uid, {"code": code, "amount": i.amount}) for i in lines]))
    return out


def rule_missing_allowance(ctx: RuleContext) -> list[Finding]:
    n = ctx.t.missing_allowance_periods
    if len(ctx.window) < n or ctx.obs.is_resignee:
        return []
    steady = set.intersection(*(o.monthly_recurring_earning_codes() for o in ctx.window[-n:]))
    missing = steady - {i.code for i in ctx.obs.earning_items()}
    out = []
    for code in sorted(missing):
        cfg = [c for c in ctx.configured if c.code == code and c.contract_id == ctx.obs.contract_id]
        if cfg and not any(c.end_date is None or c.end_date >= ctx.obs.period for c in cfg):
            continue  # configured line ended: absence is expected
        amount = ctx.window[-1].earning_code_amounts().get(code, 0.0)
        out.append(_finding(ctx, T.MISSING_RECURRING_ALLOWANCE, V.HIGH if amount >= ctx.t.missing_allowance_high_amount else V.MEDIUM,
                            "ALW-003", f"Monthly allowance '{code}' ({_fmt(amount)}) was paid in each of the last {n} periods but is missing now.",
                            "Check whether the allowance was stopped intentionally; otherwise add it back.",
                            metric=f"item:{code}", current=0.0,
                            evidence=[Evidence("configured_item", c.uid, {"code": code, "amount": c.amount}) for c in cfg]))
    return out


# ------------------------------------------------------------------------------ overtime
def rule_overtime(ctx: RuleContext) -> list[Finding]:
    if not ctx.overtime_tracked:
        return []
    hours = ctx.obs.overtime_hours(True)
    use_hours = hours is not None
    get = (lambda o: o.overtime_hours(True)) if use_hours else (lambda o: o.overtime_amount(True))
    cur = hours if use_hours else ctx.obs.overtime_amount(True)
    stats = _history(ctx, get)
    if not cur or stats is None or stats.n < 3:
        return []
    ratio = cur / stats.median if stats.median > 0 else math.inf
    above_company = ctx.company_overtime_p99 is not None and not use_hours and cur > ctx.company_overtime_p99
    if not ((stats.z(cur) >= ctx.t.amount_rz and ratio >= ctx.t.overtime_ratio) or above_company):
        return []
    unit = "hours" if use_hours else "amount"
    return [_finding(ctx, T.UNUSUAL_OVERTIME, V.HIGH if ratio >= 4 else V.MEDIUM, "OT-001",
                     f"Overtime {unit} {_fmt(cur)} vs typical {_fmt(stats.median)} ({ratio:.1f}x the employee's median).",
                     "Verify overtime claims and approvals for this period.", metric=f"overtime_{unit}", current=cur,
                     expected=stats, change=_pct(cur, stats.median))]


# ------------------------------------------------------------------------------ net pay
def rule_net(ctx: RuleContext) -> list[Finding]:
    out = []
    net, gross = ctx.obs.net_pay, ctx.obs.earnings_gross
    if net is not None and gross and gross > 0 and net <= 0:
        out.append(_finding(ctx, T.NEGATIVE_OR_ZERO_NET_PAY, V.HIGH, "NET-002", f"Net pay is {_fmt(net)} while earnings are {_fmt(gross)}.",
                            "Review deductions and statutory amounts before finalisation.", metric="net_pay", current=net))
    stats = _history(ctx, lambda o: o.net_pay)
    if net is None or stats is None or stats.median <= 0:
        return out
    change = _pct(net, stats.median)
    if abs(change) < ctx.t.net_change_pct:
        return out
    # explained components: bonus/AW lines (counted once), back pay, new deductions, and basic changes
    # backed by a revision or caused by hire/resignation proration; net moves by ~80% of a gross change (cpf)
    explained_items = sum(i.amount for i in ctx.obs.earning_items() if i.is_bonus or i.is_aw) + (ctx.obs.back_pay or 0.0)
    seen_deductions = {i.code for o in ctx.window for i in o.deduction_items()}
    new_deductions = sum(a for c, a in ctx.obs.deduction_code_amounts().items() if c not in seen_deductions)
    explained = 0.8 * explained_items - new_deductions
    basic_med = robust_stats([o.basic_earned for o in ctx.window])
    if basic_med and ctx.obs.basic_earned is not None:
        revised = bool(_revisions_in(ctx, ctx.window[-1].period, date(9999, 12, 31)))
        if revised or ctx.obs.is_new_hire or ctx.obs.is_resignee:
            explained += 0.8 * (ctx.obs.basic_earned - basic_med.median)
    diff = net - stats.median
    # an explanation larger than the change fully explains it (it never creates a new anomaly)
    unexplained = max(0.0, diff - max(0.0, explained)) if diff > 0 else min(0.0, diff - min(0.0, explained))
    unexplained_pct = unexplained / stats.median * 100.0
    if abs(unexplained_pct) < ctx.t.net_unexplained_pct:
        return out
    out.append(_finding(ctx, T.UNEXPECTED_NET_PAY_CHANGE, V.HIGH if abs(unexplained_pct) >= 40 else V.MEDIUM, "NET-001",
                        f"Net pay {_fmt(net)} vs typical {_fmt(stats.median)} ({change:+.1f}%); {_fmt(abs(unexplained))} is not explained "
                        f"by bonus, back pay or salary revisions.",
                        "Review the components that changed (see evidence) before approving.",
                        metric="net_pay", current=net, expected=stats, change=change,
                        evidence=[Evidence("baseline", None, {"explained_amount": round(explained, 2),
                                                              "unexplained_amount": round(unexplained, 2)})]))
    return out


# ------------------------------------------------------------------------------ deductions
def rule_deductions(ctx: RuleContext) -> list[Finding]:
    out = []
    gross = ctx.obs.earnings_gross or 0.0
    if ctx.window:
        seen = {i.code for o in ctx.window for i in o.deduction_items()}
        for code, amount in ctx.obs.deduction_code_amounts().items():
            if code not in seen and gross > 0 and amount / gross * 100 >= ctx.t.new_deduction_min_pct_of_gross:
                out.append(_finding(ctx, T.NEW_DEDUCTION, V.MEDIUM, "DED-001",
                                    f"New deduction '{code}' of {_fmt(amount)} ({amount / gross * 100:.1f}% of earnings) not seen in the last {len(ctx.window)} periods.",
                                    "Confirm the deduction is authorised (e.g. signed loan or advance agreement).",
                                    metric=f"item:{code}", current=amount))
    stats = _history(ctx, lambda o: o.total_deduction)
    cur = ctx.obs.total_deduction
    if stats and cur is not None and stats.n >= 3:
        change = _pct(cur, stats.median) if stats.median > 0 else None
        if stats.z(cur) >= ctx.t.amount_rz and change is not None and change >= ctx.t.deduction_change_pct and not out:
            out.append(_finding(ctx, T.UNUSUAL_DEDUCTION, V.HIGH if change >= 200 else V.MEDIUM, "DED-002",
                                f"Total deductions {_fmt(cur)} vs typical {_fmt(stats.median)} ({change:+.1f}%).",
                                "Review the deduction lines for this employee.", metric="deduction_total",
                                current=cur, expected=stats, change=change))
    return out


# ------------------------------------------------------------------------------ statutory
def rule_statutory(ctx: RuleContext) -> list[Finding]:
    out = []
    if ctx.obs.cycle_code == "END" and len(ctx.window) >= 3:
        assessed_before = sum(1 for o in ctx.window if o.cpf_assessed and (o.cpf_employee or 0) > 0)
        wage = ctx.obs.earnings_gross or 0.0
        none_now = not ctx.obs.cpf_assessed or ((ctx.obs.cpf_employee or 0) == 0 and (ctx.obs.cpf_employer or 0) == 0)
        if assessed_before >= 3 and none_now and wage > 0:
            out.append(_finding(ctx, T.STATUTORY_MISSING_CONTRIBUTION, V.HIGH, "STA-001", source=S.STATUTORY,
                                desc=f"No CPF contribution in this run although CPF was deducted in {assessed_before} recent periods.",
                                action="Re-run the statutory calculation in the pay engine and check the employee's CPF eligibility.",
                                metric="cpf_employee", current=ctx.obs.cpf_employee))
        else:
            rates = [o.cpf_employee / o.eligible_wage for o in ctx.window
                     if o.cpf_assessed and o.cpf_employee is not None and o.eligible_wage]
            wage_now = ctx.obs.eligible_wage
            if rates and ctx.obs.cpf_assessed and ctx.obs.cpf_employee is not None and wage_now:
                rate_now = ctx.obs.cpf_employee / wage_now
                med = sorted(rates)[len(rates) // 2]
                if abs(rate_now - med) * 100 >= ctx.t.cpf_rate_change_pp:
                    out.append(_finding(ctx, T.STATUTORY_CONTRIBUTION_CHANGE, V.MEDIUM, "STA-002", source=S.STATUTORY,
                                        desc=f"Employee CPF rate {rate_now * 100:.1f}% differs from the usual {med * 100:.1f}%.",
                                        action="Verify age band / residency changes; the pay engine remains the authoritative calculation.",
                                        metric="cpf_rate_employee", current=round(rate_now * 100, 2)))
    flags = ctx.obs.statutory_flags
    for flag, amount in (("hasAWExcess", "awExcess"), ("hasAWShortfall", "awShortfall")):
        if flags.get(flag):
            out.append(_finding(ctx, T.STATUTORY_ENGINE_FLAG, V.LOW, "STA-003", source=S.STATUTORY,
                                desc=f"Pay engine flagged {flag[3:]} of {_fmt(flags.get(amount))}.",
                                action="Review the AW ceiling reconciliation reported by the pay engine.",
                                metric=amount, current=flags.get(amount)))
    return out


# ------------------------------------------------------------------------------ run integrity
def rule_duplicate_run(ctx: RuleContext) -> list[Finding]:
    others = [o for o in ctx.same_period_other_runs if o.cycle_code == ctx.obs.cycle_code and o.contract_id == ctx.obs.contract_id]
    if not others:
        return []
    runs = sorted({r.pay_run_uid for o in others for r in o.records})
    return [_finding(ctx, T.DUPLICATE_PAY_RUN, V.HIGH, "RUN-001",
                     f"Employee already paid in {len(runs)} other {ctx.obs.cycle_code} run(s) for {_ym(ctx.obs.period)}.",
                     "Confirm this is an intended adjustment run and not a duplicate payment.",
                     evidence=[Evidence("pay_run", u, {}) for u in runs])]


RULES: tuple[Callable[[RuleContext], list[Finding]], ...] = (
    rule_salary, rule_duplicate_allowance, rule_missing_allowance, rule_overtime, rule_net, rule_deductions,
    rule_statutory, rule_duplicate_run,
)


def data_quality_findings(records: list[PayRecordSnapshot], usual_currency: str = "SGD") -> list[Finding]:
    out = []
    for r in records:
        problem = None
        if r.status_id == 3:
            problem, sev = "The pay engine failed to calculate this record.", V.HIGH
        elif not r.has_payload and r.status_id != 6:
            problem, sev = "The pay record has no calculation payload.", V.MEDIUM
        elif r.currency and r.currency != usual_currency:
            problem, sev = f"Currency {r.currency} differs from the company's usual {usual_currency}.", V.MEDIUM
        elif any(v is not None and v < 0 for v in (r.basic_earned, r.total_allowance, r.total_deduction)):
            problem, sev = "Negative component amounts found.", V.MEDIUM
        if problem:
            out.append(Finding(T.DATA_QUALITY, S.DATA_QUALITY, sev, r.user_id, r.contract_id, r.pay_record_id, problem,
                               "Fix the record and re-run the calculation.", rule_id="DQ-001",
                               confidence=Confidence.HIGH,
                               evidence=[Evidence("pay_record", r.pay_record_uid, {"status_id": r.status_id})]))
    return out


def run_rules(ctx: RuleContext) -> tuple[list[Finding], list[str]]:
    findings, warnings = [], []
    for rule in RULES:
        try:
            findings.extend(rule(ctx))
        except Exception:  # noqa: BLE001 - one broken rule must not stop the analysis
            log.exception("rule failed", extra={"rule_id": rule.__name__})
            warnings.append(f"rule {rule.__name__} failed")
    return findings, warnings
