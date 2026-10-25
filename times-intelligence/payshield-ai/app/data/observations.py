"""Group pay records into observations: one (user, contract, cycle, period) aggregate.

The analysed run is observed on its own (a second same-cycle run in the same period is a finding,
not something to merge). History observations sum every same-cycle run of a period, matching how the
product rolls months up (PayPeriodContributionWriter sums all non-trial runs of a period).
"""

from __future__ import annotations

from collections import defaultdict
from dataclasses import dataclass, field
from datetime import date
from typing import Iterable

from app.domain.enums import RecurringMethod
from app.domain.models import PayItem, PayRecordSnapshot

ObservationKey = tuple[int, int, str, date]  # user_id, contract_id, cycle_code, period
SeriesKey = tuple[int, int, str]  # user_id, contract_id, cycle_code
USER_LEVEL_CONTRACT = -1  # contract id used for user-level (cross-contract) fallback observations


def _sum(values: Iterable[float | None]) -> float | None:
    present = [v for v in values if v is not None]
    return sum(present) if present else None


@dataclass
class Observation:
    user_id: int
    contract_id: int
    cycle_code: str
    period: date
    records: list[PayRecordSnapshot] = field(default_factory=list)

    # ---- identity ----------------------------------------------------------------------
    @property
    def key(self) -> ObservationKey:
        return (self.user_id, self.contract_id, self.cycle_code, self.period)

    @property
    def pay_record_ids(self) -> list[int]:
        return [r.pay_record_id for r in self.records]

    @property
    def latest(self) -> PayRecordSnapshot:
        return max(self.records, key=lambda r: (r.pay_run_date, r.pay_record_id))

    # ---- aggregated money --------------------------------------------------------------
    @property
    def basic_contractual(self) -> float | None:
        # a rate, not additive: take the latest record's contractual salary
        for r in sorted(self.records, key=lambda r: (r.pay_run_date, r.pay_record_id), reverse=True):
            if r.basic_contractual is not None:
                return r.basic_contractual
        return None

    @property
    def basic_earned(self) -> float | None:
        return _sum(r.basic_earned for r in self.records)

    @property
    def total_allowance(self) -> float | None:
        return _sum(r.total_allowance for r in self.records)

    @property
    def total_deduction(self) -> float | None:
        return _sum(r.total_deduction for r in self.records)

    @property
    def back_pay(self) -> float | None:
        return _sum(r.back_pay for r in self.records)

    @property
    def gross_engine(self) -> float | None:
        return _sum(r.gross_engine for r in self.records)

    @property
    def net_pay(self) -> float | None:
        return _sum(r.net_pay for r in self.records)

    @property
    def earnings_gross(self) -> float | None:
        return _sum(r.earnings_gross for r in self.records)

    @property
    def cpf_assessed(self) -> bool:
        return any(r.cpf_assessed for r in self.records)

    @property
    def cpf_employee(self) -> float | None:
        return _sum(r.cpf_employee for r in self.records if r.cpf_assessed)

    @property
    def cpf_employer(self) -> float | None:
        return _sum(r.cpf_employer for r in self.records if r.cpf_assessed)

    @property
    def eligible_wage(self) -> float | None:
        return _sum(
            _sum([r.eligible_ow, r.eligible_aw]) for r in self.records if r.cpf_assessed
        )

    @property
    def is_new_hire(self) -> bool:
        return any(r.is_new_hire for r in self.records)

    @property
    def is_resignee(self) -> bool:
        return any(r.is_resignee for r in self.records)

    @property
    def hired_date(self) -> date | None:
        return next((r.hired_date for r in self.records if r.hired_date is not None), None)

    @property
    def currencies(self) -> set[str]:
        return {r.currency for r in self.records if r.currency}

    @property
    def statutory_flags(self) -> dict:
        merged: dict = {}
        for r in self.records:
            for k, v in r.statutory_flags.items():
                if isinstance(v, bool):
                    merged[k] = merged.get(k, False) or v
                elif v is not None:
                    merged[k] = v
        return merged

    # ---- items -------------------------------------------------------------------------
    @property
    def items(self) -> list[PayItem]:
        return [i for r in self.records for i in r.items]

    def earning_items(self) -> list[PayItem]:
        return [i for i in self.items if i.is_earning]

    def deduction_items(self) -> list[PayItem]:
        return [i for i in self.items if not i.is_earning]

    @property
    def bonus_total(self) -> float:
        return sum(i.amount for i in self.earning_items() if i.is_bonus)

    @property
    def aw_total(self) -> float:
        return sum(i.amount for i in self.earning_items() if i.is_aw)

    @property
    def ordinary_allowance_total(self) -> float:
        return sum(
            i.amount for i in self.earning_items() if not (i.is_bonus or i.is_aw or i.is_overtime)
        )

    def overtime_amount(self, tracked: bool) -> float | None:
        if not tracked:
            return None
        return sum(i.amount for i in self.earning_items() if i.is_overtime)

    def overtime_hours(self, tracked: bool) -> float | None:
        if not tracked:
            return None
        hours = [i.hours for i in self.earning_items() if i.is_overtime and i.hours is not None]
        return sum(hours) if hours else None

    @property
    def hourly_item_hours(self) -> float | None:
        hours = [i.hours for i in self.earning_items() if i.hours is not None]
        return sum(hours) if hours else None

    def earning_code_amounts(self) -> dict[str, float]:
        out: dict[str, float] = defaultdict(float)
        for i in self.earning_items():
            out[i.code] += i.amount
        return dict(out)

    def deduction_code_amounts(self) -> dict[str, float]:
        out: dict[str, float] = defaultdict(float)
        for i in self.deduction_items():
            out[i.code] += i.amount
        return dict(out)

    def monthly_recurring_earning_codes(self) -> set[str]:
        return {i.code for i in self.earning_items() if i.recurring_method == RecurringMethod.MONTH}

    @property
    def duplicate_code_count(self) -> int:
        """Codes appearing on more than one earning line within a single record."""
        count = 0
        for r in self.records:
            seen: dict[str, int] = defaultdict(int)
            for i in r.items:
                if i.is_earning:
                    seen[i.code] += 1
            count += sum(1 for n in seen.values() if n > 1)
        return count


def group_observations(records: Iterable[PayRecordSnapshot]) -> dict[ObservationKey, Observation]:
    out: dict[ObservationKey, Observation] = {}
    for r in records:
        key = (r.user_id, r.contract_id, r.cycle_code, r.period)
        obs = out.get(key)
        if obs is None:
            obs = out[key] = Observation(r.user_id, r.contract_id, r.cycle_code, r.period)
        obs.records.append(r)
    return out


class HistoryIndex:
    """Per-series, period-sorted history used for baselines. Only periods strictly before the
    requested period are ever returned, so an observation never sees itself (no leakage)."""

    def __init__(self, history_records: Iterable[PayRecordSnapshot]):
        records = list(history_records)
        self._by_contract: dict[SeriesKey, list[Observation]] = defaultdict(list)
        for obs in group_observations(records).values():
            self._by_contract[(obs.user_id, obs.contract_id, obs.cycle_code)].append(obs)
        for series in self._by_contract.values():
            series.sort(key=lambda o: o.period)

        # user-level fallback: all contracts of a user summed per (cycle, period)
        by_user: dict[tuple[int, str, date], Observation] = {}
        for r in records:
            k = (r.user_id, r.cycle_code, r.period)
            obs = by_user.get(k)
            if obs is None:
                obs = by_user[k] = Observation(r.user_id, USER_LEVEL_CONTRACT, r.cycle_code, r.period)
            obs.records.append(r)
        self._by_user: dict[tuple[int, str], list[Observation]] = defaultdict(list)
        for obs in by_user.values():
            self._by_user[(obs.user_id, obs.cycle_code)].append(obs)
        for series in self._by_user.values():
            series.sort(key=lambda o: o.period)

    def window(
        self, user_id: int, contract_id: int, cycle_code: str, before: date, max_periods: int, min_periods: int,
    ) -> tuple[list[Observation], str]:
        """Most recent ``max_periods`` observations strictly before ``before``.

        Uses the contract's own series; falls back to the user's cross-contract series when the
        contract has fewer than ``min_periods`` (contract renewals issue new contract ids).
        Returns (window oldest-first, history_key) with history_key in {"contract", "user", "none"}.
        """
        own = [o for o in self._by_contract.get((user_id, contract_id, cycle_code), []) if o.period < before]
        if len(own) >= min_periods:
            return own[-max_periods:], "contract"
        users = [o for o in self._by_user.get((user_id, cycle_code), []) if o.period < before]
        if len(users) > len(own):
            return users[-max_periods:], "user"
        return own[-max_periods:], ("contract" if own else "none")

    def series(self) -> dict[SeriesKey, list[Observation]]:
        return self._by_contract

    def periods(self) -> list[date]:
        return sorted({o.period for s in self._by_contract.values() for o in s})
