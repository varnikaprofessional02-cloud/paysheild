// PayShield test run: a synthetic payroll with planted problems, scored by the real scoring code.
// No real data. Deterministic (seeded), so the numbers in the proposal can be re-run by anyone.

import { scoreRecord } from './scoring.js';
import { createMemory, acceptFlag, applyMemory } from './learning.js';

/** Small seeded random generator (mulberry32). */
export function rng(seed) {
  let a = seed >>> 0;
  return () => {
    a = (a + 0x6d2b79f5) >>> 0;
    let t = a;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

export const RUN_TO_PAYDAY = 5; // the pay run is checked 5 days before payday

/** What each planted problem is, and how many of each the test hides. */
export const PLANTED = [
  { type: 'BANK_HIJACK_NEAR_PAYDAY', n: 3, label: 'Bank account changed by a hacker 1–2 days before the run' },
  { type: 'BANK_HIJACK_EARLY', n: 2, label: 'Bank account changed by a hacker 2–3 weeks earlier' },
  { type: 'BANK_HIJACK_EMAIL_TAKEN', n: 1, label: 'Hacker also controls the employee’s email and confirms the alert' },
  { type: 'GHOST_SHARED_ACCOUNT', n: 2, label: 'Ghost employee paid into another employee’s account' },
  { type: 'PAY_SPIKE', n: 5, label: 'Pay 35–90% above normal with no reason' },
  { type: 'CPF_MISMATCH', n: 4, label: 'Wrong CPF contribution' },
  { type: 'PAID_AFTER_EXIT', n: 3, label: 'Ex-employee still in the pay run' },
  { type: 'OT_WITHOUT_PROOF', n: 3, label: 'Overtime paid with no clock-in proof' },
  { type: 'UNVERIFIED_HOURS', n: 2, label: 'Full pay for days with no clock-out' },
];

export const CATEGORY = {
  BANK_HIJACK_NEAR_PAYDAY: 'Fraud', BANK_HIJACK_EARLY: 'Fraud', BANK_HIJACK_EMAIL_TAKEN: 'Fraud', GHOST_SHARED_ACCOUNT: 'Fraud',
  PAY_SPIKE: 'Pay error', CPF_MISMATCH: 'Pay error', PAID_AFTER_EXIT: 'Pay error',
  OT_WITHOUT_PROOF: 'Attendance', UNVERIFIED_HOURS: 'Attendance',
};

function normal(r) { // Box-Muller
  let u = 0, v = 0;
  while (u === 0) u = r();
  while (v === 0) v = r();
  return Math.sqrt(-2 * Math.log(u)) * Math.cos(2 * Math.PI * v);
}
const round = (x) => Math.round(x);

/**
 * Build the synthetic company: 12 months of pay per employee plus this month's run.
 * @returns {{employees: object[], month: number}}
 */
export function generateCompany({ employees = 500, seed = 2026 } = {}) {
  const r = rng(seed);
  const list = [];
  for (let i = 0; i < employees; i++) {
    const shift = r() < 0.3;
    const base = shift ? 1800 + r() * 1700 : Math.exp(Math.log(3000) + r() * Math.log(12000 / 3000));
    const joined = r() < 0.02 ? 10 + Math.floor(r() * 2) : 0; // ~2% joined in the last 2 months
    const incrementAt = !shift && r() < 0.6 ? 5 : null; // April increments
    const incPct = 0.03 + r() * 0.05;
    const pay = [];
    for (let m = 0; m < 13; m++) {
      if (m < joined) { pay.push(null); continue; }
      let p = base * (incrementAt != null && m >= incrementAt ? 1 + incPct : 1);
      if (shift) {
        const ot = Math.max(0, Math.min(60, 20 + 8 * normal(r)));
        p += ot * (base / 190) * 1.5;
      } else {
        p *= 1 + 0.005 * normal(r);
      }
      pay.push(round(p));
    }
    list.push({
      id: `E-${String(i + 1).padStart(4, '0')}`,
      shift, joined, pay, base, incrementAt, incPct,
      knownReasons: [],
      bank: { changedDaysAgo: null },
      attendance: { shifts: 22, missingPunches: shift ? (r() < 0.8 ? 0 : r() < 0.75 ? 1 : 2) : 0, otHours: shift ? 20 : 0, otHoursWithoutProof: 0 },
      planted: null,
      legit: [],
    });
  }
  return { employees: list, r };
}

/** Normal, honest events this month that should NOT be treated as problems. */
export function addLegitEvents(emps, r, m) {
  for (const e of emps) {
    if (e.pay[m] == null) continue;
    const x = r();
    if (x < 0.02 && !e.shift) { // promotion not yet recorded in the system
      const mult = 1.08 + r() * 0.07;
      for (let k = m; k < e.pay.length; k++) if (e.pay[k] != null) e.pay[k] = round(e.pay[k] * mult);
      e.legit.push('UNRECORDED_PROMOTION');
    } else if (x < 0.05 && !e.shift) { // promotion with a reason code
      e.pay[m] = round(e.pay[m] * (1.08 + r() * 0.07)); e.legit.push('RECORDED_PROMOTION'); e.knownReasons = ['INCREMENT'];
    }
    if (r() < 0.03) { // employee changes bank, confirms the alert
      const d = 3 + Math.floor(r() * 26);
      e.bank = { changedDaysAgo: d, daysToPayday: d + RUN_TO_PAYDAY, newDevice: r() < 0.3, alertUnconfirmed: false, secondChannelConfirmed: true };
      e.legit.push('BANK_CHANGE_CONFIRMED');
    }
  }
}

export function plant(e, type, r, m) {
  e.planted = type;
  switch (type) {
    case 'BANK_HIJACK_NEAR_PAYDAY': { const d = 1 + Math.floor(r() * 2); e.bank = { changedDaysAgo: d, daysToPayday: d + RUN_TO_PAYDAY, newDevice: true, alertUnconfirmed: true }; break; }
    case 'BANK_HIJACK_EARLY': { const d = 14 + Math.floor(r() * 7); e.bank = { changedDaysAgo: d, daysToPayday: d + RUN_TO_PAYDAY, newDevice: true, alertUnconfirmed: true }; break; }
    case 'BANK_HIJACK_EMAIL_TAKEN': e.bank = { changedDaysAgo: 10, daysToPayday: 15, newDevice: true, alertUnconfirmed: false, secondChannelConfirmed: false }; break;
    case 'GHOST_SHARED_ACCOUNT': e.bank = { changedDaysAgo: null, sharedWithOtherEmployee: true }; break;
    case 'PAY_SPIKE': e.pay[m] = round(e.pay[m] * (1.35 + r() * 0.55)); e.payMismatch = true; break;
    case 'CPF_MISMATCH': e.cpfMismatch = true; break;
    case 'PAID_AFTER_EXIT': e.paidAfterExit = true; break;
    case 'OT_WITHOUT_PROOF': e.payMismatch = true; e.attendance = { ...e.attendance, otHours: 32, otHoursWithoutProof: 12 + Math.floor(r() * 12) }; break;
    case 'UNVERIFIED_HOURS': e.payMismatch = true; e.attendance = { ...e.attendance, missingPunches: 4 + Math.floor(r() * 3) }; break;
    default: break;
  }
}

export function toRecord(e, m, extraReasons = []) {
  const hist = e.pay.slice(Math.max(0, m - 6), m).filter((x) => x != null);
  return {
    current: e.pay[m], history: hist, knownReasons: [...e.knownReasons, ...extraReasons],
    bank: e.bank, attendance: e.attendance, cpfMismatch: e.cpfMismatch, paidAfterExit: e.paidAfterExit,
    payMatchesClockedHours: e.shift && !e.payMismatch,
  };
}

/**
 * Run the full test: month 12 with planted problems (v1 design and current design),
 * then month 13 with and without the learning loop.
 */
export function runTest({ employees = 500, seed = 2026, keepRows = false } = {}) {
  const { employees: emps, r } = generateCompany({ employees, seed });
  const M = 11; // the run being checked (12th month)
  addLegitEvents(emps, r, M);
  // choose distinct, established employees for the planted problems
  const pool = emps.filter((e) => e.joined === 0 && e.legit.length === 0);
  const pick = () => pool.splice(Math.floor(r() * pool.length), 1)[0];
  for (const p of PLANTED) {
    for (let k = 0; k < p.n; k++) {
      const needShift = p.type === 'OT_WITHOUT_PROOF' || p.type === 'UNVERIFIED_HOURS';
      let e = pick();
      while (needShift && !e.shift) { pool.push(e); e = pick(); }
      plant(e, p.type, r, M);
    }
  }

  const evaluate = (opts) => {
    const rows = emps.map((e) => ({ e: { id: e.id, shift: e.shift, planted: e.planted, legit: [...e.legit], bank: { ...e.bank }, attendance: { ...e.attendance }, pay: [...e.pay], knownReasons: [...e.knownReasons], cpfMismatch: !!e.cpfMismatch, paidAfterExit: !!e.paidAfterExit, payMismatch: !!e.payMismatch }, res: scoreRecord(toRecord(e, M), opts) }));
    const flagged = rows.filter((x) => x.res.status !== 'clear');
    const planted = rows.filter((x) => x.e.planted);
    const caught = planted.filter((x) => x.res.status !== 'clear');
    const clean = rows.filter((x) => !x.e.planted);
    const falseAlarms = clean.filter((x) => x.res.status !== 'clear');
    const byType = PLANTED.map((p) => {
      const these = planted.filter((x) => x.e.planted === p.type);
      return { type: p.type, label: p.label, category: CATEGORY[p.type], planted: these.length,
        caught: these.filter((x) => x.res.status !== 'clear').length,
        held: these.filter((x) => x.res.status === 'held').length };
    });
    return {
      records: rows.length, planted: planted.length, caught: caught.length,
      held: caught.filter((x) => x.res.status === 'held').length,
      flagged: flagged.length, flagRate: flagged.length / rows.length,
      falseAlarms: falseAlarms.length, falseAlarmRate: falseAlarms.length / clean.length,
      falseAlarmReasons: tally(falseAlarms.map((x) => x.e.legit[0] || 'NORMAL_VARIATION')),
      missed: planted.filter((x) => x.res.status === 'clear').map((x) => ({ id: x.e.id, type: x.e.planted, score: x.res.score })),
      byType,
      rows,
    };
  };

  const v1 = evaluate({ payrollChecksV2: false });
  const v2 = evaluate({ payrollChecksV2: true });

  // ---- Learning loop: admins review this month's false alarms and accept them with a reason ----
  const memory = createMemory();
  for (const x of v2.rows) {
    if (x.res.status === 'clear' || x.e.planted) continue;
    const reason = x.e.legit.includes('UNRECORDED_PROMOTION') ? 'PROMOTION' : x.e.legit.includes('BANK_CHANGE_CONFIRMED') ? 'BANK_VERIFIED_BY_CALL' : 'EXPECTED_VARIATION';
    acceptFlag(memory, { employeeId: x.e.id, reason, month: M });
  }
  // fixed problems do not come back next month
  for (const e of emps) { e.planted = null; e.payMismatch = false; e.cpfMismatch = false; e.paidAfterExit = false; e.knownReasons = [];
    e.attendance = { ...e.attendance, otHoursWithoutProof: 0, missingPunches: Math.min(e.attendance.missingPunches, 2) };
    if (e.bank.changedDaysAgo != null) e.bank = { ...e.bank, changedDaysAgo: e.bank.changedDaysAgo + 30, daysToPayday: e.bank.daysToPayday + 30 };
    if (e.bank.sharedWithOtherEmployee) e.bank = { changedDaysAgo: null };
    e.legit = []; }
  const M2 = 12;
  addLegitEvents(emps, r, M2);
  const next = (useMemory) => {
    const rows = emps.map((e) => {
      const extra = useMemory ? applyMemory(memory, e.id, M2) : [];
      const rec = toRecord(e, M2, extra.knownReasons || []);
      if (extra.baselineFrom != null) rec.history = e.pay.slice(extra.baselineFrom, M2).filter((x) => x != null);
      return { e, res: scoreRecord(rec) };
    });
    const flagged = rows.filter((x) => x.res.status !== 'clear');
    const repeat = flagged.filter((x) => memory.entries.some((m) => m.employeeId === x.e.id));
    return { flagged: flagged.length, repeatAlarms: repeat.length, newAlarms: flagged.length - repeat.length };
  };
  const learning = { accepted: memory.entries.length, without: next(false), with: next(true) };

  const strip = ({ rows, ...rest }) => (keepRows ? { rows, ...rest } : rest);
  return { employees, seed, v1: strip(v1), v2: strip(v2), learning };
}

function tally(xs) { return xs.reduce((o, x) => ((o[x] = (o[x] || 0) + 1), o), {}); }

/** Repeat the test on many random companies, so the result is not one lucky draw. */
export function runMany({ runs = 50, employees = 500 } = {}) {
  const res = [];
  for (let s = 1; s <= runs; s++) res.push(runTest({ seed: s, employees }));
  const avg = (f) => res.reduce((a, t) => a + f(t), 0) / res.length;
  const min = (f) => Math.min(...res.map(f));
  const max = (f) => Math.max(...res.map(f));
  return {
    runs, employees, plantedPerRun: res[0].v2.planted,
    v1: { caughtAvg: avg((t) => t.v1.caught), caughtMin: min((t) => t.v1.caught), caughtMax: max((t) => t.v1.caught), falseAlarmRate: avg((t) => t.v1.falseAlarmRate) },
    v2: { caughtAvg: avg((t) => t.v2.caught), caughtMin: min((t) => t.v2.caught), falseAlarmRate: avg((t) => t.v2.falseAlarmRate), falseAlarmMax: max((t) => t.v2.falseAlarmRate) },
    learning: { repeatWithout: avg((t) => t.learning.without.repeatAlarms), repeatWith: avg((t) => t.learning.with.repeatAlarms) },
    byType: PLANTED.map((p, i) => ({
      type: p.type, label: p.label, planted: p.n * res.length,
      v1: res.reduce((a, t) => a + t.v1.byType[i].caught, 0),
      v2: res.reduce((a, t) => a + t.v2.byType[i].caught, 0),
    })),
  };
}
