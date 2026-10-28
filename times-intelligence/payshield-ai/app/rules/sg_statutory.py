"""Singapore statutory figures the compliance checks use (CPF, SDL, MOM work passes, Employment Act).

Values follow the published CPF Board / MOM tables for 2024-2026. They change every year: confirm them against
cpf.gov.sg and mom.gov.sg before relying on a check in production. The pay engine stays the authoritative calculation;
these checks only catch results that cannot be right.
"""

from __future__ import annotations

from datetime import date, timedelta

# CPF ordinary wage ceiling per month, by year
OW_CEILING = {2024: 6800.0, 2025: 7400.0, 2026: 8000.0}
# annual CPF wage ceiling: Additional Wages attract CPF only up to 102,000 minus the year's Ordinary Wages
ANNUAL_WAGE_CEILING = 102000.0

# CPF rates (employee, employer) for Singapore citizens and 3rd-year+ PRs, by year and age band: up to (not including) that age
_RATES = {
    2024: ((55, 0.20, 0.17), (60, 0.155, 0.145), (65, 0.095, 0.11), (70, 0.07, 0.09), (999, 0.05, 0.075)),
    2025: ((55, 0.20, 0.17), (60, 0.17, 0.155), (65, 0.115, 0.12), (70, 0.075, 0.09), (999, 0.05, 0.075)),
    2026: ((55, 0.20, 0.17), (60, 0.18, 0.16), (65, 0.125, 0.125), (70, 0.075, 0.09), (999, 0.05, 0.075)),
}

SDL_RATE, SDL_MIN, SDL_MAX = 0.0025, 2.0, 11.25

# MOM minimum qualifying monthly salary for new passes: (from date, amount)
PASS_MIN_SALARY = {
    "EP": ((date(2025, 1, 1), 5600.0), (date(2023, 9, 1), 5000.0)),
    "SP": ((date(2025, 9, 1), 3300.0), (date(2023, 9, 1), 3150.0)),
}
LEVY_PASSES = ("SP", "WP")  # passes that attract the foreign worker levy

OT_MAX_HOURS = 72          # Employment Act: overtime per month
OT_MIN_MULTIPLIER = 1.5    # Employment Act: overtime at least 1.5x the hourly basic rate
DEDUCTION_MAX_SHARE = 0.5  # Employment Act: total deductions in a salary period at most 50% of the salary
PAY_DUE_DAYS = 7           # Employment Act: salary paid within 7 days after the end of the salary period


def ow_ceiling(year: int) -> float:
    return OW_CEILING.get(year, OW_CEILING[max(OW_CEILING)] if year > max(OW_CEILING) else OW_CEILING[min(OW_CEILING)])


def age_on(dob: date, on: date) -> int:
    return on.year - dob.year - ((on.month, on.day) < (dob.month, dob.day))


def cpf_rates(age: int, year: int) -> tuple[float, float]:
    """(employee, employer) rate for an age band (see cpf_age for which age applies in a month)."""
    table = _RATES.get(year, _RATES[max(_RATES)] if year > max(_RATES) else _RATES[min(_RATES)])
    for upper, ee, er in table:
        if age < upper:
            return ee, er
    return table[-1][1], table[-1][2]


def cpf_age(dob: date, period_start: date) -> int:
    """CPF moves to the next age band from the month after the birthday month: the age on the last day of last month."""
    return age_on(dob, period_start - timedelta(days=1))


def pass_min_salary(pass_code: str, on: date) -> float | None:
    for since, amount in PASS_MIN_SALARY.get(pass_code, ()):
        if on >= since:
            return amount
    return None


def sdl_due(total_wages: float) -> float:
    return round(min(SDL_MAX, max(SDL_MIN, total_wages * SDL_RATE)), 2)


def hourly_basic(monthly_basic: float) -> float:
    """Employment Act hourly basic rate for a monthly-rated employee: (12 x monthly basic) / (52 x 44)."""
    return 12 * monthly_basic / (52 * 44)
