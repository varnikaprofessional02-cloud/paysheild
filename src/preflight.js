// Pre-flight check for a small pay run: 5 employees, 6 checks each, then fix, then pay.
// Scores come from the real scoring code; the AI pattern check uses the approved model v1.
import { scoreRecord, robustZ, deviationToSignal, median, DEFAULT_CONFIG } from './scoring.js';
import { rule } from './rules.js';
import { MODEL_V1, predict, FEATURES } from './model.js';

export const CHECKS = [
  ['emp', 'Employee record', 'Active, contract, last working day'],
  ['pay', 'Pay calculation', 'vs own 6-month pay, OT cap'],
  ['rules', 'Statutory rules', 'CPF, SDL, rule versions in force'],
  ['bank', 'Bank details', 'Recent changes, device, Fraud Network'],
  ['att', 'Attendance proof', 'Clock-ins behind paid hours'],
  ['ai', 'AI pattern check', 'Our own model: creep, peer outliers'],
];

const flat = (v, n = 6) => Array(n).fill(v);
/** Ravi's last 11 months: +2% every two months, never approved (salary creep). */
const RAVI = [4800, 4800, 4896, 4896, 4994, 4994, 5094, 5094, 5196, 5196, 5300, 5406];

export const EMPLOYEES = [
  { id: 'aisha', name: 'Aisha Tan', ini: 'AT', role: 'Accountant · salaried', pay: 4200,
    rec: { current: 4200, history: flat(4200) } },
  { id: 'daniel', name: 'Daniel Lim', ini: 'DL', role: 'Logistics executive · salaried', pay: 4980,
    rec: { current: 4980, history: [4980, 4950, 5010, 4990, 4980, 4960], bank: { changedDaysAgo: 2, daysToPayday: 7, newDevice: true, alertUnconfirmed: true } },
    issue: { check: 'bank', title: 'Bank account changed 2 days ago from a new device, not confirmed', risk: 'S$4,980 would go to an unknown account',
      fix: 'Call Daniel on his number on file', after: 'Daniel: “Not me.” Change rejected; paid to his usual OCBC ···· 2209.', saved: 4980 } },
  { id: 'tan', name: 'Tan Wei Ming', ini: 'TW', role: 'Operations · hourly', pay: 9840, fixedPay: 7210,
    rec: { current: 9840, history: [5100, 5200, 5050, 5150, 5120, 5180], attendance: { shifts: 22, missingPunches: 3, otHours: 88, otHoursWithoutProof: 14 } },
    issue: { check: 'att', title: 'OT 88 h is above the 72 h cap; 14 h have no clock-out', risk: 'S$2,630 overpaid',
      fix: 'Cap OT at 72 h; send 14 h to his manager', after: 'Pay S$7,210. The 14 h go to the manager to confirm next run.', saved: 2630 } },
  { id: 'siti', name: 'Siti Rahmah', ini: 'SR', role: 'Finance manager · salaried', pay: 9200,
    rec: { current: 9200, history: flat(9200), cpfMismatch: true, cpfCeilingUsed: 7400 },
    issue: { check: 'rules', title: 'CPF worked out on the old S$7,400 ceiling; the ceiling is S$8,000 from 1 Jan 2026', risk: 'CPF short by S$222 this month',
      fix: 'Recalculate CPF on the S$8,000 ceiling', after: 'Employee CPF S$1,480 → S$1,600; employer CPF S$1,258 → S$1,360.', saved: 222 } },
  { id: 'ravi', name: 'Ravi Kumar', ini: 'RK', role: 'Sales executive · salaried', pay: 5406, fixedPay: 5000, months: RAVI,
    rec: { current: RAVI[11], history: RAVI.slice(5, 11) },
    issue: { check: 'ai', title: 'Pay up 12.6% in 10 months in 5 small steps, with no approved increment', risk: 'S$406 a month unapproved',
      fix: 'Pay the last approved S$5,000; ask his manager to approve the rest', after: 'Pay S$5,000. The S$406 rise waits for manager approval.', saved: 406 } },
];

/** The model's 15 inputs for one employee (same definitions as model.js featurize). */
export function modelInputs(e) {
  const x = new Array(FEATURES.length).fill(0);
  const hist = e.rec.history, cur = e.rec.current;
  x[0] = hist.length >= 3 ? deviationToSignal(robustZ(cur, hist)) : 0;
  if (e.months) {
    const m = e.months; let steps = 0;
    for (let i = m.length - 10; i < m.length; i++) if (m[i] / m[i - 1] - 1 > 0.012) steps++;
    x[3] = Math.min(1, steps / 5);
    x[4] = Math.max(-1, Math.min(2, (m[m.length - 1] / m[m.length - 11] - 1) / 0.1));
  }
  return x;
}

/** Run all six checks for one employee. Returns check states, Trust Score and model probability. */
export function checkEmployee(e) {
  const res = scoreRecord(e.rec);
  const p = predict(MODEL_V1, modelInputs(e));
  const hits = res.ruleHits.map((h) => h.code);
  const s = res.signals;
  const st = {
    emp: e.rec.paidAfterExit ? 'fail' : 'ok',
    pay: s.pay >= 0.5 && !hits.includes('CPF_MISMATCH') ? 'warn' : 'ok',
    rules: hits.includes('CPF_MISMATCH') ? 'fail' : 'ok',
    bank: res.overridesApplied.includes('FORCE_HOLD') || s.bank >= 0.5 ? 'fail' : s.bank > 0 ? 'warn' : 'ok',
    att: hits.includes('OT_WITHOUT_PROOF') || hits.includes('UNVERIFIED_HOURS') ? 'warn' : 'ok',
    ai: p >= MODEL_V1.threshold ? 'warn' : 'ok',
  };
  let status = res.status;
  if (status === 'clear' && st.ai === 'warn') status = 'review'; // the model can only add a Review flag
  return { checks: st, score: res.score, status, p };
}

const pct = (x) => `${x >= 0 ? '+' : ''}${(x * 100).toFixed(1)}%`;
const money = (n) => 'S$' + Math.round(n).toLocaleString('en-SG');
/**
 * The parameters each check used for one employee, with the value found, the limit, and the effect.
 * hit = this parameter raised a flag. Values come from the record, DEFAULT_CONFIG, the rule library and model v1.
 */
export function evidence(e) {
  const r = e.rec, out = { emp: [], pay: [], rules: [], bank: [], att: [], ai: [] };
  const P = DEFAULT_CONFIG.bankPoints;
  out.emp.push({ label: 'Last working day', value: r.paidAfterExit ? 'before this period' : 'none (active)', limit: 'must be in or after the period', effect: r.paidAfterExit ? 'Critical' : '—', hit: !!r.paidAfterExit });
  const m = median(r.history), ch = r.current / m - 1, z = robustZ(r.current, r.history), sig = deviationToSignal(z);
  out.pay.push({ label: 'Pay vs own 6-month median', value: `${money(r.current)} vs ${money(m)} (${pct(ch)})`, limit: 'unusual if more than 2 robust spreads away', effect: sig ? `signal ${sig.toFixed(2)}` : 'normal', hit: sig >= 0.5 });
  out.pay.push({ label: 'Reason recorded', value: (r.knownReasons || []).join(', ') || 'none', limit: 'increment, bonus or proration cancels the check', effect: '—', hit: false });
  const ceil = rule('CPF_OW_CEILING');
  out.rules.push({ label: 'CPF Ordinary Wage ceiling used', value: money(r.cpfCeilingUsed || ceil.value), limit: `${money(ceil.value)} in force (${ceil.version}, from ${ceil.from})`, effect: r.cpfCeilingUsed && r.cpfCeilingUsed !== ceil.value ? 'Critical' : '—', hit: !!(r.cpfCeilingUsed && r.cpfCeilingUsed !== ceil.value) });
  const b = r.bank || {};
  if (b.changedDaysAgo == null) out.bank.push({ label: 'Bank account change', value: 'none in 30 days', limit: 'checked if changed in 30 days', effect: '—', hit: false });
  else {
    out.bank.push({ label: 'Changed', value: `${b.changedDaysAgo} days ago`, limit: '≤ 30 days', effect: `+${P.changedWithin30Days.toFixed(2)}`, hit: b.changedDaysAgo <= 30 });
    out.bank.push({ label: 'Change to payday', value: `${b.daysToPayday} days`, limit: '≤ 7 days', effect: `+${P.within7DaysOfPayday.toFixed(2)}`, hit: b.daysToPayday <= 7 });
    out.bank.push({ label: 'Device', value: b.newDevice ? 'new device' : 'known device', limit: 'new device adds risk', effect: b.newDevice ? `+${P.newDevice.toFixed(2)}` : '—', hit: !!b.newDevice });
    out.bank.push({ label: 'Confirmed on 2nd channel', value: b.alertUnconfirmed ? 'no' : 'yes', limit: 'must be confirmed', effect: b.alertUnconfirmed ? `+${P.alertUnconfirmed.toFixed(2)} · hold near payday` : '—', hit: !!b.alertUnconfirmed });
  }
  const a = r.attendance;
  if (!a) out.att.push({ label: 'Hours paid vs clock records', value: 'salaried, no OT claimed', limit: 'OT needs clock proof', effect: '—', hit: false });
  else {
    const cap = rule('MOM_OT_CAP');
    out.att.push({ label: 'Overtime hours', value: `${a.otHours} h`, limit: `≤ ${cap.value} h a month (MOM)`, effect: a.otHours > cap.value ? 'over cap' : '—', hit: a.otHours > cap.value });
    out.att.push({ label: 'OT without clock proof', value: `${a.otHoursWithoutProof} h`, limit: '0 h', effect: a.otHoursWithoutProof ? 'Warning' : '—', hit: a.otHoursWithoutProof > 0 });
    out.att.push({ label: 'Days without clock-out', value: `${a.missingPunches}`, limit: '< 3 in the period', effect: a.missingPunches >= 3 ? 'Warning' : '—', hit: a.missingPunches >= 3 });
  }
  const x = modelInputs(e), p = predict(MODEL_V1, x);
  const top = FEATURES.map(([k, label], i) => ({ label, v: x[i], c: MODEL_V1.w[i] * x[i] })).filter((f) => f.c > 0.05).sort((u, v) => v.c - u.c).slice(0, 2);
  if (e.months) out.ai.push({ label: 'Pay growth over 10 months', value: pct(e.months[11] / e.months[1] - 1), limit: 'not covered by approved increments', effect: 'weight +4.22', hit: true });
  for (const f of top) if (!e.months || !/growth over 10/.test(f.label)) out.ai.push({ label: f.label, value: /steps/.test(f.label) ? `${Math.round(f.v * 5)} raises without approval` : f.v.toFixed(2), limit: 'model input', effect: `+${f.c.toFixed(2)}`, hit: f.c > 1 });
  out.ai.push({ label: 'Model v1 probability', value: p.toFixed(2), limit: `flag at ≥ ${MODEL_V1.threshold.toFixed(2)}`, effect: p >= MODEL_V1.threshold ? 'Review' : '—', hit: p >= MODEL_V1.threshold });
  return out;
}
