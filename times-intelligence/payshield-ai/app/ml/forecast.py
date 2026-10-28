"""Pay forecast for future pay runs (scikit-learn, per company, trained on request from its own pay history).

A gradient-boosting model predicts each employee's net pay h months ahead (h = 1..12) as a ratio of their
recent median, from: last three months, 6-month median and spread, basic and
allowances, the same month last year (catches the year-end bonus / AWS in December), the target month, tenure and h.
Gross and CPF follow the employee's own gross/net and CPF/net ratios (same month last year when it exists).
The low / high range comes from the model's own errors on its training data for the same horizon (10th and 90th
percentile). Totals add the employees up; the range assumes employees vary independently.
A backtest re-trains without the last three months and forecasts them, so the UI can show how close it gets.
"""

from __future__ import annotations

import math
from dataclasses import dataclass
from datetime import date

import numpy as np
import pandas as pd
from sklearn.ensemble import HistGradientBoostingRegressor

MAX_H = 12
FEATURES = ["n0", "n1", "n2", "med6", "sd6", "basic", "allow", "ly_ratio", "ly_known", "m_sin", "m_cos", "is_dec", "is_apr", "tenure", "h"]


@dataclass
class Fitted:
    model: HistGradientBoostingRegressor
    spread: dict[int, tuple[float, float]]  # horizon -> (10th, 90th percentile of the ratio error)
    rows: int


def _month_index(d: date) -> int:
    return d.year * 12 + d.month - 1


def _to_date(mi: int) -> date:
    return date(mi // 12, mi % 12 + 1, 1)


def build_panel(rows: list[dict]) -> pd.DataFrame:
    """rows: user_id, employee_no, name, period (date), basic, allowances, cpf, gross, net -> one row per employee per month."""
    df = pd.DataFrame(rows)
    df["mi"] = df["period"].map(_month_index)
    num = ["basic", "allowances", "cpf", "gross", "net"]
    df[num] = df[num].astype(float)
    return df.groupby(["user_id", "employee_no", "name", "mi"], as_index=False)[num].sum().sort_values(["user_id", "mi"])


class _Emp:
    """One employee's monthly amounts as arrays (fast feature building)."""

    def __init__(self, g: pd.DataFrame):
        self.mi = g["mi"].to_numpy()
        self.pos = {int(m): k for k, m in enumerate(self.mi)}
        self.net, self.basic, self.allow = g["net"].to_numpy(), g["basic"].to_numpy(), g["allowances"].to_numpy()
        self.gross, self.cpf = g["gross"].to_numpy(), g["cpf"].to_numpy()
        self.first = int(self.mi[0])


def _features(e: _Emp, origin: int, h: int) -> list[float] | None:
    """Features of one employee at origin month for target month origin+h (FEATURES order); None if too little history."""
    k = e.pos.get(origin)
    if k is None or k < 2:
        return None
    last6 = e.net[max(0, k - 5): k + 1]
    med6 = float(np.median(last6)) or 1.0
    target = origin + h
    ly = target - 12
    j = e.pos.get(ly)
    if j is not None and ly <= origin:
        around = e.net[(e.mi >= ly - 6) & (e.mi < ly)]
        ly_ratio, ly_known = float(e.net[j]) / (float(np.median(around)) if len(around) else med6), 1.0
    else:
        ly_ratio, ly_known = 1.0, 0.0
    m = target % 12
    return [float(e.net[k]) / med6, float(e.net[k - 1]) / med6, float(e.net[k - 2]) / med6, med6, float(last6.std()) / med6,
            float(e.basic[k]) / med6, float(e.allow[k]) / med6, ly_ratio, ly_known, math.sin(2 * math.pi * m / 12),
            math.cos(2 * math.pi * m / 12), float(m == 11), float(m == 3), float(origin - e.first), float(h)]


def _emps(panel: pd.DataFrame) -> list[tuple[tuple, _Emp]]:
    return [(key, _Emp(g)) for key, g in panel.groupby(["user_id", "employee_no", "name"], sort=False)]


def fit(panel: pd.DataFrame, last_origin: int) -> Fitted:
    X, y = [], []
    for _, e in _emps(panel):
        for origin in e.mi:
            origin = int(origin)
            for h in range(1, MAX_H + 1):
                t = origin + h
                if t > last_origin or t not in e.pos:
                    continue
                f = _features(e, origin, h)
                if f is not None:
                    X.append(f)
                    y.append(float(e.net[e.pos[t]]) / f[3])
    X, y = np.asarray(X), np.asarray(y)
    model = HistGradientBoostingRegressor(max_iter=150, learning_rate=0.08, max_leaf_nodes=15, min_samples_leaf=20, random_state=7).fit(X, y)
    err, hs = y - model.predict(X), X[:, FEATURES.index("h")]
    spread = {h: (float(np.quantile(err[hs == h], 0.1)), float(np.quantile(err[hs == h], 0.9))) if (hs == h).any() else (0.0, 0.0)
              for h in range(1, MAX_H + 1)}
    return Fitted(model, spread, len(y))


def predict(panel: pd.DataFrame, model: Fitted, origin: int, horizons: list[int]) -> pd.DataFrame:
    """Per employee present at origin, predicted net (p10/p50/p90), gross and CPF for each horizon."""
    keys, feats, refs = [], [], []
    for (uid, no, name), e in _emps(panel):
        k = e.pos.get(origin)
        if k is None:
            continue  # not paid in the latest pay run: assume they have left
        for h in horizons:
            f = _features(e, origin, h)
            if f is None:
                continue
            ly = e.pos.get(origin + h - 12)
            sl = slice(ly, ly + 1) if ly is not None else slice(max(0, k - 2), k + 1)
            n = max(float(e.net[sl].sum()), 1.0)
            keys.append((uid, no, name, h, origin + h, float(e.net[k])))
            feats.append(f)
            refs.append((float(e.gross[sl].sum()) / n, float(e.cpf[sl].sum()) / n))
    if not feats:
        return pd.DataFrame(columns=["user_id", "employee_no", "name", "h", "mi", "last_net", "p10", "p50", "p90", "gross", "cpf"])
    X = np.asarray(feats)
    med = X[:, 3]
    mid = model.model.predict(X)
    lo = np.array([model.spread[int(h)][0] for h in X[:, FEATURES.index("h")]])
    hi = np.array([model.spread[int(h)][1] for h in X[:, FEATURES.index("h")]])
    P = np.sort(np.stack([(mid + np.minimum(lo, 0)) * med, mid * med, (mid + np.maximum(hi, 0)) * med], axis=1), axis=1)
    out = pd.DataFrame(keys, columns=["user_id", "employee_no", "name", "h", "mi", "last_net"])
    out["p10"], out["p50"], out["p90"] = P[:, 0], P[:, 1], P[:, 2]
    r = np.asarray(refs)
    out["gross"], out["cpf"] = out["p50"] * r[:, 0], out["p50"] * r[:, 1]
    return out


def _range(df: pd.DataFrame) -> dict:
    lo = float(np.sqrt(((df["p50"] - df["p10"]).clip(lower=0) ** 2).sum()))
    hi = float(np.sqrt(((df["p90"] - df["p50"]).clip(lower=0) ** 2).sum()))
    mid = float(df["p50"].sum())
    return {"low": round(mid - lo, 2), "likely": round(mid, 2), "high": round(mid + hi, 2)}


def forecast(rows: list[dict], months: int = 3) -> dict:
    panel = build_panel(rows)
    last = int(panel["mi"].max())
    hist_tot = panel.groupby("mi")[["net", "gross", "cpf"]].sum()
    # backtest: train without the last 3 months, forecast them from 3 months back
    bt_origin = last - 3
    bt_model = fit(panel[panel["mi"] <= bt_origin], bt_origin)
    bt = predict(panel[panel["mi"] <= bt_origin], bt_model, bt_origin, [1, 2, 3])
    backtest = []
    for mi, g in bt.groupby("mi"):
        actual = float(hist_tot.at[mi, "net"]) if mi in hist_tot.index else None
        if actual:
            backtest.append({"period": f"{_to_date(mi):%m/%Y}", "actual": round(actual, 2), "predicted": round(float(g["p50"].sum()), 2),
                             "errorPct": round(abs(float(g["p50"].sum()) - actual) / actual * 100, 2)})
    model = fit(panel, last)
    horizons = list(range(1, max(1, min(months, MAX_H)) + 1))
    pred = predict(panel, model, last, horizons)
    last_net = float(hist_tot.at[last, "net"])
    out = []
    for h in horizons:
        g = pred[pred["h"] == h]
        mi = last + h
        net = _range(g)
        drivers = []
        ly = mi - 12
        if ly in hist_tot.index:
            base = float(hist_tot.loc[(hist_tot.index >= ly - 6) & (hist_tot.index < ly), "net"].median())
            jump = float(hist_tot.at[ly, "net"]) / base - 1 if base else 0
            if abs(jump) >= 0.15:
                drivers.append(f"Same month last year was {jump * 100:+.0f}% vs the months before"
                               + (" (year-end bonus / AWS)" if mi % 12 == 11 and jump > 0 else " (annual increments)" if mi % 12 == 3 and jump > 0 else ""))
        g2 = g.assign(delta=g["p50"] - g["last_net"]).sort_values("delta", key=abs, ascending=False)
        for _, r in g2.head(3).iterrows():
            if abs(r["delta"]) >= 200:
                drivers.append(f"{r['name']}: {r['delta']:+,.0f} vs last month")
        out.append({"period": f"{_to_date(mi):%m/%Y}", "headcount": int(len(g)), "net": net,
                    "gross": round(float(g["gross"].sum()), 2), "cpf": round(float(g["cpf"].sum()), 2),
                    "changePct": round((net["likely"] - last_net) / last_net * 100, 2) if last_net else None, "drivers": drivers,
                    "employees": [{"employee_no": r["employee_no"], "name": r["name"], "last_net": round(r["last_net"], 2), "low": round(r["p10"], 2),
                                   "likely": round(r["p50"], 2), "high": round(r["p90"], 2)} for _, r in g.sort_values("employee_no").iterrows()]})
    return {"basedOn": {"latestPeriod": f"{_to_date(last):%m/%Y}", "months": int(panel["mi"].nunique()), "employees": int((panel["mi"] == last).sum()),
                        "trainingRows": model.rows, "method": "scikit-learn HistGradientBoosting, range from 10th-90th percentile errors"},
            "backtest": {"months": backtest, "meanErrorPct": round(float(np.mean([b["errorPct"] for b in backtest])), 2) if backtest else None},
            "months": out}
