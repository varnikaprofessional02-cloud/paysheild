// One company, one September pay run. Every guard page reads its issues from here.
// Trust Scores come from the real scoring code (trustScore / pre-flight checkEmployee); amounts are sample data.
import { trustScore, DEFAULT_CONFIG } from './scoring.js';
import { EMPLOYEES, checkEmployee } from './preflight.js';
import { rule } from './rules.js';
import { MODEL_V1 } from './model.js';

const ENV = (typeof import.meta !== 'undefined' && import.meta.env) || {};
export const COMPANY = {
  name: ENV.VITE_COMPANY || 'Marina Bay Sands',
  get letter() { return this.name.trim()[0].toUpperCase(); },
};
export const RUN = { name: 'September 2026', payDate: '30 Sep 2026', headcount: 219, gross: 1284560, checksPerPerson: 30 };

export const money = (n, dp = 0) => 'S$' + Number(n).toLocaleString('en-SG', { minimumFractionDigits: dp, maximumFractionDigits: dp });
const round2 = (n) => Math.round(n * 100) / 100;

// MOM formulas used in the examples
export const hourlyBasic = (monthlyBasic) => (12 * monthlyBasic) / (52 * 44);
export const prorate = (monthlyGross, daysWorked, workingDays) => (monthlyGross * daysWorked) / workingDays;
const SEP_WORKING_DAYS = 22; // Mon–Fri in September 2026

const pf = Object.fromEntries(EMPLOYEES.map((e) => [e.id, { e, r: checkEmployee(e) }]));
const fromPF = (id) => ({ score: pf[id].r.score, status: pf[id].r.status });
const seeded = (s, o) => { const r = trustScore(s, o); return { score: r.score, status: r.status }; };

/** The five guards that feed PayShield. Parameters are read from the code and the rule library. */
export const GUARDS = {
  people: {
    name: 'People & Employment', short: 'People', icon: 'users', q: 'Is every person in this run really due this pay?',
    covers: ['New joiners and proration', 'Leavers and final pay', 'Work pass validity', 'Contract and employment changes'],
    feeds: 'A failed record check is a critical rule: the record is at least Review, and pay to a non-employee is Held.',
    params: [
      ['Last working day', 'on or after the pay period start', 'else Held'],
      ['Join date in period', `prorate: gross × days worked ÷ ${SEP_WORKING_DAYS} working days`, 'MOM formula'],
      ['Work pass', 'valid on every paid day', 'else prorate to expiry'],
      ['Final pay due', 'last day · 7 days if no notice · 3 working days if dismissed', 'MOM'],
      ['Designation or pay change', 'needs an approval record', 'company policy'],
    ],
    ai: 'Explains each flag in plain English; the Agent answers “how do I prorate a joiner?” with the MOM formula.',
  },
  time: {
    name: 'Time & Attendance', short: 'Time', icon: 'clock', q: 'Were the paid hours really worked?',
    covers: ['Overtime cap and rate', 'Paid hours vs clock-ins', 'Buddy punching (geofence, selfie, one phone)', 'Missed clock-outs', 'OT pre-approval policy'],
    feeds: `Attendance signal, weight ${DEFAULT_CONFIG.weights.attendance.toFixed(2)} in the Trust Score.`,
    params: [
      ['Overtime cap', `${rule('MOM_OT_CAP').value} h / month`, 'MOM'],
      ['OT rate', `≥ ${rule('MOM_OT_RATE').value}× hourly basic (12 × monthly ÷ (52 × 44))`, 'MOM'],
      ['OT without clock proof', '> 0 h → Warning', 'rule'],
      ['Days without clock-out', '≥ 3 → Warning', 'rule'],
      ['Clock-in', 'inside geofence + live selfie + own phone', 'buddy-punch block'],
      ['OT pre-approval', 'required before the shift', 'company policy'],
    ],
    ai: 'Suggests the usual clock-out time for a missed punch; the person confirms it and the manager approves.',
  },
  bank: {
    name: 'Bank Shield', short: 'Bank', icon: 'shield', q: 'Is the salary going to the right account?',
    covers: ['Bank changes near payday', 'New device sign-ins', 'Second-channel confirmation', 'Shared accounts', 'Fraud Network across companies'],
    feeds: `Bank signal, weight ${DEFAULT_CONFIG.weights.bank.toFixed(2)}. An unconfirmed new account near payday, or a Fraud Network match, is Held.`,
    params: [
      ['Changed in last 30 days', `+${DEFAULT_CONFIG.bankPoints.changedWithin30Days.toFixed(2)}`, 'bank signal'],
      ['Within 7 days of payday', `+${DEFAULT_CONFIG.bankPoints.within7DaysOfPayday.toFixed(2)}`, 'bank signal'],
      ['From a new device', `+${DEFAULT_CONFIG.bankPoints.newDevice.toFixed(2)}`, 'bank signal'],
      ['Not confirmed on 2nd channel', `+${DEFAULT_CONFIG.bankPoints.alertUnconfirmed.toFixed(2)} · Held near payday`, 'bank signal'],
      ['Shared with another employee', 'always Review', 'rule'],
      ['Fraud Network match', 'Held', 'keyed fingerprint only'],
    ],
    ai: 'Fraud Network shares only a keyed fingerprint of an account confirmed as fraud, never the number.',
  },
  pay: {
    name: 'Pay Structure', short: 'Pay', icon: 'wallet', q: 'Is this pay right for this person, this grade and this policy?',
    covers: ['Salary vs own history', 'Grade bands', 'Increments and approvals', 'Bonuses', 'AWS (13th month)', 'Stock awards'],
    feeds: `Pay signal, weight ${DEFAULT_CONFIG.weights.pay.toFixed(2)}. Our own model can add Review for slow patterns.`,
    params: [
      ['Unusual pay', 'more than 2 robust spreads (MAD) from own 6-month median', 'statistics'],
      ['Grade band', 'basic inside the band for the grade', 'company policy'],
      ['Increment', 'needs 2 approvers on record', 'company policy'],
      ['Bonus', '≤ 2 months of basic without CFO approval', 'company policy'],
      ['AWS', 'per contract (not required by law); CPF as Additional Wage', 'MOM, CPF'],
      ['CPF on bonus / AWS', `AW ceiling ${rule('CPF_AW_CEILING').value}`, 'CPF'],
      ['Stock awards', 'shares in own name: no CPF, report in IR8A Appendix 8B; cash proceeds: CPF', 'CPF, IRAS'],
      ['AI pattern check', `model v1 flags at ≥ ${MODEL_V1.threshold.toFixed(2)}`, 'can only add Review'],
    ],
    ai: 'Our own model finds salary creep and raises far above peers that no single rule catches.',
  },
  compliance: {
    name: 'Compliance', short: 'Compliance', icon: 'library', q: 'Are we following MOM, CPF, IRAS and our own policies?',
    covers: ['Statutory rule library (versioned)', 'Rule Watch: new rules drafted from official sources', 'Company policies', 'Audit trail of rule versions per pay run'],
    feeds: 'A statutory rule breach is a critical rule: the record is at least Review.',
    params: [
      ['CPF Ordinary Wage ceiling', `${money(rule('CPF_OW_CEILING').value)} / month · ${rule('CPF_OW_CEILING').version}`, 'from 1 Jan 2026'],
      ['CPF rates 55–65', 'new rates from 1 Jan 2026', rule('CPF_RATE_55_60').version],
      ['SDL', rule('SDL').value, 'IRAS / SkillsFuture'],
      ['Salary payment', rule('MOM_PAY_DUE').value, 'MOM'],
      ['Deductions', `≤ ${rule('MOM_DEDUCTION_CAP').value} of salary`, 'MOM'],
    ],
    ai: 'Rule Watch reads MOM, CPF Board and IRAS updates and drafts the change; a named compliance owner publishes it.',
  },
};

/** Company policies (editable by an admin; every change is logged). */
export const POLICIES = [
  { id: 'ot', name: 'Overtime needs pre-approval', detail: 'OT without an approved request is held back for the manager', on: true },
  { id: 'bonus', name: 'Bonus above 2 months needs CFO approval', detail: 'Applies to performance and retention bonuses', on: true },
  { id: 'inc', name: 'Increments need two approvers', detail: 'Line manager and HR business partner', on: true },
  { id: 'bank', name: 'Bank changes confirmed on a second channel', detail: 'SMS to the number on file, not the one just changed', on: true },
  { id: 'band', name: 'Basic salary inside the grade band', detail: 'Outside the band needs a promotion or exception letter', on: true },
  { id: 'allow', name: 'Allowances capped per grade', detail: 'Transport, meal and shift allowance limits', on: true },
];

const I = (o) => ({ state: 'open', ...o });
/** Everything PayShield found in the September run, by guard. */
export const ISSUES = () => [
  // People & Employment
  I({ id: 'lim', ref: 'MOM: final salary is due on the last day of employment; no pay after it', hist: 'Final pay of S$4,200 settled in the 31 Aug run', guard: 'people', name: 'Lim Hui Ling', ini: 'LH', dept: 'Finance', ...seeded({ pay: 0.9, attendance: 0.48 }, { critical: true, forceHold: true }),
    title: 'Resigned, last day 31 Aug, but still in the September run', param: ['Last working day', '31 Aug 2026', 'pay period starts 1 Sep'], impact: 4200,
    fix: { label: 'Remove from this run', done: 'Removed. Her final pay was settled on 31 Aug.' }, alt: { label: 'Keep: rehired', done: 'Kept with HR note: rehired from 1 Sep.' } }),
  I({ id: 'karthik', ref: 'MOM: a valid work pass is needed to employ; pay for an incomplete month uses the MOM formula', hist: 'Paid S$2,400 in each of the last 6 runs', guard: 'people', name: 'Karthik Subramaniam', ini: 'KS', dept: 'Security', ...seeded({ pay: 0.3 }, { critical: true }),
    title: 'Work permit expires 20 Sep; no renewal on file, but paid for the full month', param: ['Work pass valid to', '20 Sep 2026', 'paid to 30 Sep'],
    impact: round2(2400 - prorate(2400, 14, SEP_WORKING_DAYS)),
    fix: { label: 'Prorate to 20 Sep', done: `Paid ${money(prorate(2400, 14, SEP_WORKING_DAYS), 2)} (14 of ${SEP_WORKING_DAYS} working days). HR asked to renew or cancel the pass.` }, alt: { label: 'Renewal on file', done: 'Renewal approval uploaded by HR; full month paid.' } }),
  I({ id: 'nicole', ref: 'MOM incomplete-month formula: monthly gross × days worked ÷ working days', hist: 'New hire: no pay history yet', guard: 'people', name: 'Nicole Wong', ini: 'NW', dept: 'Retail', ...seeded({ pay: 0.85 }, { critical: true }),
    title: 'Joined 15 Sep but set up for a full month', param: ['Join date', '15 Sep 2026', '12 of 22 working days'], impact: round2(4800 - prorate(4800, 12, SEP_WORKING_DAYS)),
    fix: { label: 'Prorate (MOM formula)', done: `Paid ${money(prorate(4800, 12, SEP_WORKING_DAYS), 2)} = S$4,800 × 12 ÷ ${SEP_WORKING_DAYS}.` }, alt: { label: 'Accept: sign-on terms', done: 'Accepted: offer letter guarantees a full first month.' } }),
  // Time & Attendance
  I({ id: 'tan', ref: 'MOM: overtime cap 72 h a month (MOM_OT_CAP v2024.1)', hist: 'OT averaged 41 h over the last 6 months; pay median S$5,135', guard: 'time', name: 'Tan Wei Ming', ini: 'TW', dept: 'Hotel Operations', ...fromPF('tan'),
    title: 'Overtime 88 h is above the 72 h cap; 14 h have no clock-out', param: ['Overtime', '88 h', `cap ${rule('MOM_OT_CAP').value} h`], impact: 2630,
    fix: { label: 'Cap at 72 h; send 14 h to manager', done: 'Paid S$7,210. The 14 h wait for the manager to confirm.' }, alt: { label: 'Accept: MOM exemption', done: 'Accepted: MOM OT exemption on file for the event period.' } }),
  I({ id: 'faizal', ref: 'Company policy: overtime needs pre-approval', hist: 'No unapproved OT in the last 6 months', guard: 'time', name: 'Mohd Faizal', ini: 'MF', dept: 'Security', ...seeded({ pay: 0.2, attendance: 0.62 }),
    title: '6 h overtime without pre-approval; one buddy-punch attempt blocked on 12 Sep', param: ['OT pre-approval', 'none for 6 h', 'company policy'], impact: round2(6 * 1.5 * hourlyBasic(2200)),
    fix: { label: 'Send to manager for approval', done: 'Manager approved 6 h OT at 1.5× (S$17.31 an hour).' }, alt: { label: 'Not worked: remove OT', done: 'OT removed; manager confirmed the shift ended on time.' }, demo: 'attend' }),
  // Bank Shield
  I({ id: 'daniel', ref: 'Company policy: bank changes confirmed on a second channel', hist: 'Same OCBC account for 4 years; never changed before', guard: 'bank', name: 'Daniel Lim', ini: 'DL', dept: 'Logistics', ...fromPF('daniel'),
    title: 'Bank account changed 2 days ago from a new device; not confirmed', param: ['Bank risk', '+0.90', 'held near payday'], impact: 4980,
    fix: { label: 'Call Daniel, reject change', done: 'Daniel: “Not me.” Change rejected; pay goes to his usual OCBC ···· 2209. Fingerprint shared with the Fraud Network.' }, alt: { label: 'Daniel confirmed it', done: 'Confirmed by Daniel on his number on file; new account accepted.' }, demo: 'bank' }),
  I({ id: 'kelvin', ref: 'PayShield rule: a shared account is always reviewed', hist: 'Shared since Mar 2026; reviewed once, not documented', guard: 'bank', name: 'Kelvin Teo', ini: 'KT', dept: 'F&B', ...seeded({ bank: 0.97 }),
    title: 'Same bank account as another employee (Jessie Teo, Retail)', param: ['Shared account', 'with 1 employee', 'always Review'], impact: 3900,
    fix: { label: 'Accept: verified joint account', done: 'Accepted: joint account with his sister, verified by HR with both.' }, alt: { label: 'Hold and investigate', done: 'Held; HR investigating a possible ghost employee.' } }),
  // Pay Structure
  I({ id: 'ravi', ref: 'Company policy: increments need two approvers', hist: 'S$4,800 → S$5,406 in 10 months; last approved pay S$5,000', guard: 'pay', name: 'Ravi Kumar', ini: 'RK', dept: 'Sales', ...fromPF('ravi'),
    title: 'Pay up 12.6% in 10 months in 5 small steps, with no approved increment', param: ['Model v1', '0.99', `flag at ${MODEL_V1.threshold.toFixed(2)}`], impact: 406,
    fix: { label: 'Pay approved S$5,000', done: 'Paid S$5,000. The S$406 rise waits for two approvers.' }, alt: { label: 'Approvals found', done: 'Two approvals found in email and attached; S$5,406 paid.' }, demo: 'model' }),
  I({ id: 'kevin', ref: 'CPF: no CPF on shares given in the employee’s name; report the gain in IRAS IR8A Appendix 8B', hist: 'First share award; earlier bonuses were cash', guard: 'pay', name: 'Kevin Ong', ini: 'KO', dept: 'Finance', ...seeded({ pay: 0.7 }, { critical: true }),
    title: 'S$12,000 share award entered as a cash bonus, so CPF was charged', param: ['Share award', 'shares in his name', 'no CPF · Appendix 8B'], impact: 12000 * 0.37,
    fix: { label: 'Recode as share award', done: 'Recoded: no CPF; the gain goes to IR8A Appendix 8B for tax.' }, alt: { label: 'Cash settled: keep CPF', done: 'Kept: the award was paid out in cash, so CPF applies.' } }),
  I({ id: 'nurul', ref: 'Company policy: bonus above 2 months of basic needs CFO approval', hist: 'Last two bonuses were 1.5 and 1.8 months', guard: 'pay', name: 'Nurul Huda', ini: 'NH', dept: 'F&B', ...seeded({ pay: 0.8 }),
    title: 'Bonus S$9,000 is 3 months of basic; policy needs CFO approval above 2', param: ['Bonus', '3.0 months', 'policy ≤ 2 months'], impact: 3000,
    fix: { label: 'Send to CFO', done: 'CFO approved the 3-month bonus with a note.' }, alt: { label: 'Cap at 2 months', done: 'Capped at S$6,000 as per policy.' } }),
  I({ id: 'marcus', ref: 'Company policy: basic inside the grade band (R3: S$4,200–S$6,500)', hist: 'S$6,400 in August; +23% this month with no promotion record', guard: 'pay', name: 'Marcus Lee', ini: 'ML', dept: 'Retail', ...seeded({ pay: 0.6 }),
    title: 'Basic S$7,900 is above the grade R3 band (S$4,200–S$6,500)', param: ['Grade band R3', 'S$7,900', 'max S$6,500'], impact: 1400,
    fix: { label: 'Attach promotion letter', done: 'Promotion to R4 from 1 Sep attached; inside the R4 band.' }, alt: { label: 'Pay band maximum', done: 'Paid S$6,500; HR to review.' } }),
  // Compliance
  I({ id: 'siti', ref: 'CPF Ordinary Wage ceiling S$8,000 from 1 Jan 2026 (CPF_OW_CEILING v2026.1)', hist: 'Same short CPF in Jan–Aug: S$1,776 back CPF to pay', guard: 'compliance', name: 'Siti Rahmah', ini: 'SR', dept: 'Finance', ...fromPF('siti'),
    title: 'CPF worked out on the old S$7,400 ceiling; the ceiling is S$8,000 from 1 Jan 2026', param: ['CPF OW ceiling', 'S$7,400 used', 'S$8,000 in force'], impact: 222,
    fix: { label: 'Apply 2026 ceiling', done: 'CPF recalculated on S$8,000; the “Legacy” scheme fixed for 46 people.' }, alt: { label: 'Accept', done: 'Accepted with note.' }, demo: 'rules' }),
];

/** AWS dry run for December (preview, sample data). */
export const AWS_PREVIEW = { eligible: 204, joiners: 14, leavers: 2, overCeiling: 3, total: 1062400 };

/** Last six pay runs (sample), used by the agent to compare this run with history. */
export const HISTORY = [
  { run: 'Mar 2026', headcount: 214, gross: 1241800, findings: 9, otHours: 2810, bankChanges: 3, score: 100, by: 'Varnika R.', approver: 'Grace Lim' },
  { run: 'Apr 2026', headcount: 215, gross: 1247900, findings: 7, otHours: 2760, bankChanges: 2, score: 100, by: 'Varnika R.', approver: 'Grace Lim' },
  { run: 'May 2026', headcount: 215, gross: 1250400, findings: 11, otHours: 3020, bankChanges: 4, score: 100, by: 'Ben T.', approver: 'Grace Lim' },
  { run: 'Jun 2026', headcount: 216, gross: 1255100, findings: 8, otHours: 2890, bankChanges: 2, score: 100, by: 'Varnika R.', approver: 'Grace Lim' },
  { run: 'Jul 2026', headcount: 216, gross: 1258700, findings: 6, otHours: 2850, bankChanges: 1, score: 100, by: 'Varnika R.', approver: 'Grace Lim' },
  { run: 'Aug 2026', headcount: 217, gross: 1262300, findings: 10, otHours: 2940, bankChanges: 2, score: 100, by: 'Ben T.', approver: 'Grace Lim' },
];
export const SEPT_FACTS = { headcount: 219, joiners: 6, leavers: 4, gross: 1284560, otHours: 3410, bankChanges: 4 };

/**
 * Pay Score for the whole run (0–100): half by records ready, half by pay value safe to pay.
 * Any held record caps it at 79 (not ready); any open review caps it at 89. 90+ with nothing open = ready to approve.
 */
export function payScore(issues, run = RUN) {
  const s = runSummary(issues);
  const recordsPart = s.ready / run.headcount, valuePart = (run.gross - s.atRisk) / run.gross;
  const raw = Math.round(100 * (0.5 * recordsPart + 0.5 * valuePart));
  const cap = s.held ? 79 : s.review ? 89 : 100;
  const score = Math.min(raw, cap);
  const verdict = s.held ? 'Not ready' : s.review ? 'Needs review' : 'Ready to approve';
  return { score, raw, cap, verdict, recordsPart, valuePart, ...s };
}

/* ---------- Guard switches (per pay run) ----------
 * A company can turn a guard off for a pay run. While it is off, that guard's checks do not run:
 * its findings are not raised, not scored and not asked about. Every change is logged. */
export const GUARD_SWITCH = { off: {} };
/** High-risk guards need a second person to approve turning them off. */
export const HIGH_RISK_GUARDS = ['bank', 'compliance'];
export const guardOff = (key) => !!GUARD_SWITCH.off[key];
export function setGuardOff(key, info) { if (info) GUARD_SWITCH.off[key] = info; else delete GUARD_SWITCH.off[key]; }
export const resetGuards = () => { GUARD_SWITCH.off = {}; };
export const pendingIn = (issues, guard) => issues.filter((i) => i.state === 'open' && !guardOff(i.guard) && (!guard || i.guard === guard));
export function runSummary(issues) {
  const open = pendingIn(issues);
  const held = open.filter((i) => i.status === 'held').length;
  const review = open.length - held;
  const resolved = issues.length - open.length;
  const clear = RUN.headcount - issues.length;
  const protectedAmt = issues.filter((i) => i.state === 'fixed').reduce((s, i) => s + i.impact, 0);
  const atRisk = open.reduce((s, i) => s + i.impact, 0);
  return { open: open.length, held, review, resolved, clear, ready: clear + resolved, protectedAmt, atRisk, found: issues.reduce((s, i) => s + i.impact, 0) };
}
