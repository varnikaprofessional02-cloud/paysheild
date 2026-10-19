// "Check your own file": score an anonymised pay-run CSV in the browser. Nothing is uploaded anywhere.
import { scoreRecord } from './scoring.js';
import { runTest } from './backtest.js';

export const RUN_DAYS_TO_PAYDAY = 5;

/** Columns the file must have (one row per employee). */
export const COLUMNS = [
  ['employee_ref', 'Any anonymous reference, e.g. A001. Never a name or NRIC.'],
  ['pay_type', 'salaried or hourly'],
  ['pay_m1 … pay_m6', 'Gross pay for the last 6 months, oldest first (blank if not employed yet)'],
  ['pay_current', 'Gross pay in the run being checked'],
  ['reason_code', 'Blank, or INCREMENT, BONUS, PRORATION if a reason was recorded'],
  ['bank_changed_days_ago', 'Blank if the bank account did not change recently'],
  ['new_device', 'Y if the change came from a device never used before'],
  ['confirmed', 'none, email or second_channel'],
  ['shared_account', 'Y if another employee is paid into the same account'],
  ['shifts', 'Shifts or working days in the period'],
  ['missing_punches', 'Days with a missing clock-in or clock-out'],
  ['ot_hours', 'OT hours paid'],
  ['ot_hours_without_proof', 'OT hours paid with no matching clock record'],
  ['pay_matches_clocked_hours', 'Hourly staff: Y if pay = verified hours × rate'],
  ['cpf_mismatch', 'Y if the CPF calculation check failed'],
  ['left_before_period', 'Y if the last working day is before this pay period'],
];
const HEADER = ['employee_ref', 'pay_type', 'pay_m1', 'pay_m2', 'pay_m3', 'pay_m4', 'pay_m5', 'pay_m6', 'pay_current', 'reason_code',
  'bank_changed_days_ago', 'new_device', 'confirmed', 'shared_account', 'shifts', 'missing_punches', 'ot_hours', 'ot_hours_without_proof',
  'pay_matches_clocked_hours', 'cpf_mismatch', 'left_before_period'];

/** Small RFC 4180-style parser: commas, quotes, CRLF. */
export function parseCSV(text) {
  const rows = []; let row = [], cell = '', q = false;
  for (let i = 0; i < text.length; i++) {
    const c = text[i];
    if (q) {
      if (c === '"' && text[i + 1] === '"') { cell += '"'; i++; } else if (c === '"') q = false; else cell += c;
    } else if (c === '"') q = true;
    else if (c === ',') { row.push(cell); cell = ''; }
    else if (c === '\n' || c === '\r') { if (c === '\r' && text[i + 1] === '\n') i++; row.push(cell); rows.push(row); row = []; cell = ''; }
    else cell += c;
  }
  if (cell !== '' || row.length) { row.push(cell); rows.push(row); }
  return rows.filter((r) => r.some((x) => x.trim() !== ''));
}

const PERSONAL_HEADER = /(^|_)(name|full_?name|nric|fin|passport|ic_?no|email|e_?mail|phone|mobile|address|account_?(no|number)|bank_?(acc|account)_?(no|number)?|iban|dob|birth)($|_)/i;
const NRIC = /^[STFGM]\d{7}[A-Z]$/i;
const EMAIL = /^[^@\s]+@[^@\s]+\.[a-z]{2,}$/i;
const LONG_DIGITS = /^\d{9,}$/; // looks like a bank account or phone number

/** Refuse files that contain personal data. Returns a list of problems (empty = OK). */
export function privacyProblems(rows) {
  if (!rows.length) return ['The file is empty.'];
  const head = rows[0].map((h) => h.trim().toLowerCase());
  const out = [];
  const bad = head.filter((h) => PERSONAL_HEADER.test(h));
  if (bad.length) out.push(`Remove these columns, they look like personal data: ${bad.join(', ')}`);
  let hits = 0;
  for (const r of rows.slice(1)) for (const v of r) { const t = v.trim(); if (NRIC.test(t) || EMAIL.test(t) || LONG_DIGITS.test(t.replace(/[\s()+-]/g, ''))) hits++; }
  if (hits) out.push(`${hits} value(s) look like an NRIC/FIN, email, phone or bank number. Replace them before checking.`);
  return out;
}

const yes = (v) => /^(y|yes|true|1)$/i.test(String(v || '').trim());
const num = (v) => { const t = String(v ?? '').replace(/[,\s$]/g, ''); return t === '' ? null : Number(t); };

/** Turn one CSV row (as an object) into a scoring record. */
export function rowToRecord(o) {
  const hist = ['pay_m1', 'pay_m2', 'pay_m3', 'pay_m4', 'pay_m5', 'pay_m6'].map((k) => num(o[k])).filter((x) => x != null && Number.isFinite(x));
  const changed = num(o.bank_changed_days_ago);
  const conf = String(o.confirmed || '').trim().toLowerCase();
  const hourly = /^h/i.test(String(o.pay_type || ''));
  const reason = String(o.reason_code || '').trim().toUpperCase();
  return {
    current: num(o.pay_current) ?? 0,
    history: hist,
    knownReasons: reason ? [reason] : [],
    bank: changed == null && !yes(o.shared_account) ? { changedDaysAgo: null } : {
      changedDaysAgo: changed, daysToPayday: changed == null ? null : changed + RUN_DAYS_TO_PAYDAY,
      newDevice: yes(o.new_device), alertUnconfirmed: changed != null && (conf === '' || conf === 'none'),
      secondChannelConfirmed: conf === 'second_channel', sharedWithOtherEmployee: yes(o.shared_account),
    },
    attendance: { shifts: num(o.shifts) || 22, missingPunches: num(o.missing_punches) || 0, otHours: num(o.ot_hours) || 0, otHoursWithoutProof: num(o.ot_hours_without_proof) || 0 },
    cpfMismatch: yes(o.cpf_mismatch), paidAfterExit: yes(o.left_before_period),
    payMatchesClockedHours: hourly && yes(o.pay_matches_clocked_hours),
  };
}

const RULE_TEXT = { CPF_MISMATCH: 'CPF calculation check failed', PAID_AFTER_EXIT: 'Last working day is before this period',
  OT_WITHOUT_PROOF: 'OT paid without clock proof', UNVERIFIED_HOURS: 'Pay for days with no clock-out' };
const med = (xs) => { const s = [...xs].sort((a, b) => a - b), m = s.length >> 1; return s.length % 2 ? s[m] : (s[m - 1] + s[m]) / 2; };

/** Plain-English reasons for one scored record. */
export function reasons(rec, res) {
  const out = res.ruleHits.map((h) => RULE_TEXT[h.code] || h.code);
  if (res.signals.pay > 0 && rec.history.length >= 3 && !res.ruleHits.length) {
    const m = med(rec.history); out.push(`Pay ${Math.round((rec.current / m - 1) * 100)}% vs 6-month median`);
  }
  const b = rec.bank || {};
  if (b.changedDaysAgo != null && b.changedDaysAgo <= 30) out.push(`Bank changed ${b.changedDaysAgo} day${b.changedDaysAgo === 1 ? '' : 's'} ago${b.newDevice ? ', new device' : ''}${b.secondChannelConfirmed ? ', confirmed on 2nd channel' : b.alertUnconfirmed ? ', not confirmed' : ', email confirmation only'}`);
  if (b.sharedWithOtherEmployee) out.push('Account shared with another employee');
  if (res.signals.attendance > 0 && !res.ruleHits.some((h) => h.code === 'OT_WITHOUT_PROOF' || h.code === 'UNVERIFIED_HOURS')) out.push('Attendance gaps');
  return out;
}

/** Check a whole file. Throws an Error with a viewer-readable message on bad input. */
export function checkFile(text) {
  const rows = parseCSV(text);
  const problems = privacyProblems(rows);
  if (problems.length) { const e = new Error(problems.join(' ')); e.privacy = true; throw e; }
  const head = rows[0].map((h) => h.trim().toLowerCase());
  const missing = ['employee_ref', 'pay_current'].filter((h) => !head.includes(h));
  if (missing.length) throw new Error(`Missing column(s): ${missing.join(', ')}. Use the template.`);
  if (rows.length > 20001) throw new Error('Up to 20,000 rows per file.');
  const results = rows.slice(1).map((r) => {
    const o = Object.fromEntries(head.map((h, i) => [h, r[i] ?? '']));
    const rec = rowToRecord(o);
    const res = scoreRecord(rec);
    return { ref: String(o.employee_ref).slice(0, 40), score: res.score, status: res.status, reasons: reasons(rec, res) };
  });
  const count = (s) => results.filter((x) => x.status === s).length;
  return { rows: results.length, clear: count('clear'), review: count('review'), held: count('held'),
    flagged: results.filter((x) => x.status !== 'clear').sort((a, b) => (a.status === 'held' ? 0 : 1) - (b.status === 'held' ? 0 : 1) || a.score - b.score) };
}

const cell = (v) => (v == null ? '' : String(v));
/** An anonymised sample file built from the synthetic test company (seeded, so it is always the same). */
export function sampleCSV() {
  const t = runTest({ keepRows: true });
  const lines = [HEADER.join(',')];
  t.v2.rows.forEach((x, i) => {
    const e = x.e, b = e.bank || {}, a = e.attendance || {};
    const hist = e.pay.slice(5, 11);
    lines.push([
      'A' + String(i + 1).padStart(4, '0'), e.shift ? 'hourly' : 'salaried', ...hist.map(cell), cell(e.pay[11]), (e.knownReasons || [])[0] || '',
      cell(b.changedDaysAgo), b.newDevice ? 'Y' : 'N', b.changedDaysAgo == null ? '' : b.secondChannelConfirmed ? 'second_channel' : b.alertUnconfirmed ? 'none' : 'email',
      b.sharedWithOtherEmployee ? 'Y' : 'N', a.shifts, a.missingPunches, a.otHours, a.otHoursWithoutProof,
      e.shift ? (e.payMismatch ? 'N' : 'Y') : '', e.cpfMismatch ? 'Y' : 'N', e.paidAfterExit ? 'Y' : 'N',
    ].join(','));
  });
  return lines.join('\n') + '\n';
}

export function templateCSV() {
  return HEADER.join(',') + '\n' + 'A0001,salaried,5200,5210,5190,5205,5198,5202,5830,,,N,,N,22,0,0,0,,N,N\n' + 'A0002,hourly,2300,2410,2250,2380,2290,2350,2330,,,N,,N,22,1,18,0,Y,N,N\n';
}
