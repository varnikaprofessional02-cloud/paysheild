/**
 * AI explanation layer: the only part that talks to an LLM.
 * ---------------------------------------------------------------
 * Security design (OWASP Top 10 for LLM Applications 2025: LLM01 Prompt
 * Injection, LLM02 Sensitive Information Disclosure, LLM05 Improper Output
 * Handling, LLM09 Misinformation):
 *  1. Allow-list payload: only flag codes and the numbers the sentence needs.
 *     No name, NRIC/FIN, bank number, address, salary history or free text.
 *  2. Pseudonymous subject token per run; the token map stays in our database.
 *     (Production: HMAC-SHA256 with a key in Azure Key Vault. Demo: FNV-1a.)
 *  3. Output check: every number in the AI sentence must exist in the payload.
 *  4. Deterministic template fallback: pay checks never depend on the AI.
 */

const ALLOWED_FLAGS = new Set([
  'OT_OVER_CAP', 'NO_CLOCKOUT', 'PAY_SPIKE', 'BANK_CHANGED_RECENT', 'NEW_DEVICE', 'ALERT_UNCONFIRMED',
  'RESIGNED', 'EX_EMPLOYEE_IN_RUN', 'CPF_OLD_CEILING', 'SHARED_ACCOUNT', 'DEVICE_REUSE', 'COOLING_OFF', 'FRAUD_NETWORK_MATCH',
]);
const ALLOWED_VALUES = new Set([
  'ot_hours', 'cap', 'no_clockout_hours', 'pay_change_pct', 'days_before_payday', 'usual_ot_hours',
  'old_ceiling', 'new_ceiling', 'staff_on_device', 'cooling_off_days_left', 'baseline_months',
]);

function fnv1a(str) {
  let h = 0x811c9dc5;
  for (let i = 0; i < str.length; i++) { h ^= str.charCodeAt(i); h = Math.imul(h, 0x01000193); }
  return (h >>> 0).toString(16).toUpperCase().padStart(8, '0');
}

/** Pseudonymous token, different every pay run. */
export function subjectToken(employeeId, runSalt) {
  return 'EMP_' + fnv1a(`${runSalt}:${employeeId}`).slice(0, 6);
}

/** Builds the only object that may be sent to the LLM. Anything not allow-listed is dropped. */
export function buildExplainPayload({ employeeId, runSalt, flags = [], values = {}, score, status }) {
  const v = {};
  for (const [k, val] of Object.entries(values)) if (ALLOWED_VALUES.has(k) && Number.isFinite(val)) v[k] = val;
  if (flags.includes('PAY_SPIKE') && v.baseline_months == null) v.baseline_months = 6; // context number the sentence may use
  return {
    subject: subjectToken(employeeId, runSalt),
    flags: flags.filter((f) => ALLOWED_FLAGS.has(f)),
    values: v,
    score,
    status: String(status).toUpperCase(),
  };
}

const fmt = (n) => Number(n).toLocaleString('en-SG');
const TEMPLATES = {
  BANK_CHANGED_RECENT: (v) => `bank account changed ${v.days_before_payday} days before payday`,
  NEW_DEVICE: () => 'from a new device',
  ALERT_UNCONFIRMED: () => 'and the employee has not confirmed the change',
  PAY_SPIKE: (v) => `net pay is ${v.pay_change_pct}% above the ${v.baseline_months ?? 6}-month average`,
  OT_OVER_CAP: (v) => `OT is ${v.ot_hours} h against a ${v.cap} h cap`,
  NO_CLOCKOUT: (v) => `${v.no_clockout_hours} h have no clock-out`,
  RESIGNED: () => 'a resignation has been filed',
  EX_EMPLOYEE_IN_RUN: () => 'the last working day is before this pay period',
  CPF_OLD_CEILING: (v) => `CPF uses the S$${fmt(v.old_ceiling)} ceiling; the current ceiling is S$${fmt(v.new_ceiling)}`,
  SHARED_ACCOUNT: () => 'the bank account is also used by another employee',
  DEVICE_REUSE: (v) => `the same phone clocked in ${v.staff_on_device} staff`,
  COOLING_OFF: (v) => `the new account is in cooling-off (${v.cooling_off_days_left} days left)`,
  FRAUD_NETWORK_MATCH: () => 'the account matches a confirmed fraud report in the Fraud Network',
};

/** Deterministic sentence used when the AI is off, fails, or fails the number check. */
export function templateSentence(payload) {
  const MODIFIERS = new Set(['NEW_DEVICE', 'ALERT_UNCONFIRMED']); // read as part of the previous clause
  const parts = [];
  for (const f of payload.flags) {
    const t = TEMPLATES[f]?.(payload.values);
    if (!t) continue;
    if (MODIFIERS.has(f) && parts.length) parts[parts.length - 1] += ' ' + t; else parts.push(t);
  }
  if (!parts.length) return 'No issues found.';
  const s = parts.join('; ');
  return s.charAt(0).toUpperCase() + s.slice(1) + '.';
}

/** True only if every number in the sentence appears in the payload values or score. */
export function numbersMatch(sentence, payload) {
  const allowed = new Set([...Object.values(payload.values), payload.score].map((n) => Number(n)));
  const found = (sentence.match(/\d[\d,]*(?:\.\d+)?/g) || []).map((t) => Number(t.replace(/,/g, '')));
  return found.every((n) => allowed.has(n));
}

/**
 * Get the explanation. `llm` is an async function (payload) => string, or null.
 * Returns { text, source: 'ai' | 'template' }.
 */
export async function explain(payload, llm = null) {
  if (llm) {
    try {
      const text = await llm(payload);
      if (typeof text === 'string' && text.length <= 400 && numbersMatch(text, payload)) return { text, source: 'ai' };
    } catch { /* fall through to template */ }
  }
  return { text: templateSentence(payload), source: 'template' };
}
