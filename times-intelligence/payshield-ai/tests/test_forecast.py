"""Pay forecast: learns a steady salary and the December bonus from history, and reports a backtest."""

from __future__ import annotations

from datetime import date

from app.ml.forecast import forecast


def _history(months: int = 26) -> list[dict]:
    rows, start = [], date(2024, 9, 1)
    for k in range(12):
        base = 3000 + 250 * k
        for i in range(months):
            y, m = start.year + (start.month - 1 + i) // 12, (start.month - 1 + i) % 12 + 1
            net = base * (2 if m == 12 else 1)  # 13th-month bonus every December
            rows.append({"user_id": k + 1, "employee_no": f"E{k + 1:05d}", "name": f"Emp {k + 1}", "period": date(y, m, 1),
                         "basic": base, "allowances": 200, "cpf": net * 0.2, "gross": net * 1.25, "net": net})
    return rows


def test_forecast_learns_december_bonus_and_backtests():
    f = forecast(_history(), months=3)  # history ends Oct 2026 -> Nov, Dec, Jan
    by = {m["period"]: m for m in f["months"]}
    assert set(by) == {"11/2026", "12/2026", "01/2027"}
    nov, dec = by["11/2026"]["net"]["likely"], by["12/2026"]["net"]["likely"]
    steady = sum(3000 + 250 * k for k in range(12))
    assert abs(nov - steady) / steady < 0.05
    assert dec > 1.6 * nov  # the December bonus is expected again
    assert by["12/2026"]["headcount"] == 12 and len(by["12/2026"]["employees"]) == 12
    assert f["backtest"]["meanErrorPct"] is not None and f["backtest"]["meanErrorPct"] < 5
