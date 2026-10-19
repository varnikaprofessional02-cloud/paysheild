/**
 * PayShield Trust Score
 * ---------------------------------------------------------------
 * Pure functions, no I/O. In production this runs inside the payroll
 * backend (the rules engine). Personal data never leaves that service;
 * only the result is shown in the UI or summarised for the AI (see explain.js).
 *
 * Score = 100 x (1 - risk), where
 *   risk = 0.40 x pay + 0.35 x bank + 0.25 x attendance
 *        + 0.03 for each extra signal >= 0.50 on the same person
 * Then hard overrides apply (critical rule -> at least Review,
 * fraud match / unconfirmed bank change -> Held).
 */

export const DEFAULT_CONFIG = Object.freeze({
  weights: { pay: 0.4, bank: 0.35, attendance: 0.25 },
  comboBonus: 0.03,
  comboThreshold: 0.5,
  thresholds: { clear: 80, review: 50 }, // >=80 Clear, 50-79 Review, <50 Held
  ruleSeverity: { CRITICAL: 0.9, WARNING: 0.6, INFO: 0.3 },
  bankPoints: {
    changedWithin30Days: 0.3,
    within7DaysOfPayday: 0.2,
    newDevice: 0.2,
    alertUnconfirmed: 0.2,
    sharedWithOtherEmployee: 0.5,
  },
});

const clamp01 = (v) => Math.max(0, Math.min(1, v));
const round2 = (v) => Math.round(v * 100) / 100;

export function median(xs) {
  if (!xs.length) throw new Error('median of empty list');
  const s = [...xs].sort((a, b) => a - b);
  const m = Math.floor(s.length / 2);
  return s.length % 2 ? s[m] : (s[m - 1] + s[m]) / 2;
}

/** Median absolute deviation: a spread measure that one odd month cannot distort. */
export function mad(xs) {
  const m = median(xs);
  return median(xs.map((x) => Math.abs(x - m)));
}

/** How many "robust spreads" the current value is from the person's own normal. */
export function robustZ(value, history) {
  if (history.length < 3) return 0; // not enough history: rely on rules only
  const m = median(history);
  const spread = Math.max(1.4826 * mad(history), 0.02 * Math.abs(m), 1); // floor avoids divide-by-zero for flat pay
  return Math.abs(value - m) / spread;
}

/** Maps distance from normal to a 0-1 signal. Under 2 spreads is treated as normal. */
export function deviationToSignal(z) {
  if (z < 2) return 0;
  if (z <= 4) return round2(0.3 + ((z - 2) / 2) * 0.3);
  return round2(Math.min(0.95, 0.6 + 0.05 * (z - 4)));
}

/**
 * Pay variance signal (Anomaly Guard).
 * @param {{current:number, history:number[], ruleHits?:{code:string,severity:'CRITICAL'|'WARNING'|'INFO'}[], knownReasons?:string[]}} input
 */
export function payVarianceSignal(input, cfg = DEFAULT_CONFIG) {
  const { current, history = [], ruleHits = [], knownReasons = [] } = input;
  const rule = ruleHits.reduce((mx, h) => Math.max(mx, cfg.ruleSeverity[h.severity] ?? 0), 0);
  // A known reason (increment, bonus month, proration) explains a change in pay level.
  const stat = knownReasons.length ? 0 : deviationToSignal(robustZ(current, history));
  return {
    value: round2(Math.max(rule, stat)),
    rule,
    stat,
    critical: ruleHits.some((h) => h.severity === 'CRITICAL'),
  };
}

/**
 * Bank-change risk signal (Bank-Change Shield).
 * @param {{changedDaysAgo?:number|null, daysToPayday?:number, newDevice?:boolean, alertUnconfirmed?:boolean, sharedWithOtherEmployee?:boolean, fraudNetworkMatch?:boolean}} f
 */
export function bankRiskSignal(f, cfg = DEFAULT_CONFIG) {
  if (f.fraudNetworkMatch) return { value: 1, forceHold: true, reason: 'FRAUD_NETWORK_MATCH' };
  const p = cfg.bankPoints;
  let v = 0;
  const recent = f.changedDaysAgo != null && f.changedDaysAgo <= 30;
  if (recent) v += p.changedWithin30Days;
  if (recent && f.daysToPayday != null && f.daysToPayday <= 7) v += p.within7DaysOfPayday;
  if (recent && f.newDevice) v += p.newDevice;
  if (recent && f.alertUnconfirmed) v += p.alertUnconfirmed;
  if (f.sharedWithOtherEmployee) v += p.sharedWithOtherEmployee;
  const value = round2(clamp01(v));
  // A new account that the employee has not confirmed is never paid in this run.
  const forceHold = Boolean(recent && f.alertUnconfirmed && f.daysToPayday != null && f.daysToPayday <= 7);
  // Two employees paid into one account is a classic "ghost employee" pattern: always reviewed (added after the first test run).
  const reviewRequired = Boolean(f.sharedWithOtherEmployee);
  return { value, forceHold, reviewRequired };
}

/**
 * Attendance integrity signal.
 * @param {{shifts:number, missingPunches?:number, otHours?:number, otHoursWithoutProof?:number, blockedAttempts?:number, geofenceExceptions?:number}} a
 */
export function attendanceSignal(a) {
  const shifts = Math.max(1, a.shifts || 0);
  const missingShare = (a.missingPunches || 0) / shifts;
  const otShare = a.otHours ? (a.otHoursWithoutProof || 0) / a.otHours : 0;
  const v =
    Math.min(0.4, missingShare * 4) +
    Math.min(0.4, otShare) +
    Math.min(0.4, (a.blockedAttempts || 0) * 0.2) +
    Math.min(0.2, (a.geofenceExceptions || 0) * 0.1);
  return { value: round2(clamp01(v)) };
}

/**
 * Combine signals into the Trust Score.
 * @param {{pay?:number, bank?:number, attendance?:number}} s  each 0-1
 * @param {{critical?:boolean, forceHold?:boolean}} overrides
 */
export function trustScore(s, overrides = {}, cfg = DEFAULT_CONFIG) {
  const pay = clamp01(s.pay ?? 0), bank = clamp01(s.bank ?? 0), attendance = clamp01(s.attendance ?? 0);
  const w = cfg.weights;
  const parts = { pay: pay * w.pay, bank: bank * w.bank, attendance: attendance * w.attendance };
  const strong = [pay, bank, attendance].filter((v) => v >= cfg.comboThreshold).length;
  const bonus = Math.max(0, strong - 1) * cfg.comboBonus;
  const risk = clamp01(parts.pay + parts.bank + parts.attendance + bonus);
  const score = Math.round(Number((100 * (1 - risk)).toFixed(6)));

  let status = score >= cfg.thresholds.clear ? 'clear' : score >= cfg.thresholds.review ? 'review' : 'held';
  const applied = [];
  if (overrides.critical && status === 'clear') { status = 'review'; applied.push('CRITICAL_RULE'); }
  if (overrides.forceHold && status !== 'held') { status = 'held'; applied.push('FORCE_HOLD'); }

  return { score, status, risk: Number(risk.toFixed(3)), bonus, parts, overridesApplied: applied, signals: { pay, bank, attendance } };
}

/**
 * Rules engine checks that turn payroll facts into rule hits.
 * Added after the first test run: paid OT with no clock proof, and pay for hours that were never clocked out,
 * are payroll errors in their own right (not just attendance noise), so they raise a Warning.
 * @param {{cpfMismatch?:boolean, paidAfterExit?:boolean, otHoursWithoutProof?:number, missingPunches?:number}} r
 * @param {{payrollChecksV2?:boolean}} opts
 */
export function deriveRuleHits(r, opts = { payrollChecksV2: true }) {
  const hits = [];
  if (r.cpfMismatch) hits.push({ code: 'CPF_MISMATCH', severity: 'CRITICAL' });
  if (r.paidAfterExit) hits.push({ code: 'PAID_AFTER_EXIT', severity: 'CRITICAL' });
  if (opts.payrollChecksV2) {
    if ((r.otHoursWithoutProof || 0) > 0) hits.push({ code: 'OT_WITHOUT_PROOF', severity: 'WARNING' });
    if ((r.missingPunches || 0) >= 3) hits.push({ code: 'UNVERIFIED_HOURS', severity: 'WARNING' });
  }
  return hits;
}

/**
 * Score one employee record end to end: rule hits, the three signals, overrides, Trust Score.
 * @param {object} rec  { current, history, knownReasons, bank:{...}, attendance:{...}, cpfMismatch, paidAfterExit }
 * @param {{payrollChecksV2?:boolean}} opts  false reproduces the first (v1) design, for the test-run comparison
 */
export function scoreRecord(rec, opts = { payrollChecksV2: true }, cfg = DEFAULT_CONFIG) {
  const v2 = opts.payrollChecksV2 !== false;
  const att = rec.attendance || { shifts: 22 };
  const ruleHits = deriveRuleHits({ ...rec, ...att }, { payrollChecksV2: v2 });
  const knownReasons = [...(rec.knownReasons || [])];
  // Hourly staff: pay that matches verified clocked hours x rate is explained, so normal OT swings are not flagged.
  if (v2 && rec.payMatchesClockedHours) knownReasons.push('VERIFIED_HOURS');
  const pay = payVarianceSignal({ current: rec.current, history: rec.history || [], ruleHits, knownReasons }, cfg);
  let b = rec.bank || {};
  // A new account set up from a new device only counts as confirmed on a second channel
  // (the phone number on file before the change, or a call from HR), not by email alone.
  const recent = b.changedDaysAgo != null && b.changedDaysAgo <= 30;
  if (v2 && recent && b.newDevice && !b.secondChannelConfirmed) b = { ...b, alertUnconfirmed: true };
  const bank = bankRiskSignal(b, cfg);
  const attendance = attendanceSignal(att);
  const result = trustScore(
    { pay: pay.value, bank: bank.value, attendance: attendance.value },
    { critical: pay.critical || (v2 && bank.reviewRequired), forceHold: bank.forceHold },
    cfg,
  );
  return { ...result, ruleHits };
}
