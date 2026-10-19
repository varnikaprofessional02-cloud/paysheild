// PayShield learning loop: it remembers what admins decide, so the same false alarm does not come back,
// and it suggests (never applies) threshold changes. Every change to a setting still needs a person.

const VALID_MONTHS = 3; // an accepted reason is remembered for 3 pay runs, then expires

export function createMemory() {
  return { entries: [], decisions: [] };
}

/**
 * An admin accepts a flagged record with a reason.
 * PROMOTION: the new pay is the new normal, so the baseline restarts from this month.
 * BANK_VERIFIED_BY_CALL: the new account was confirmed on a second channel.
 * EXPECTED_VARIATION: nothing is suppressed; the month simply joins the person's history.
 */
export function acceptFlag(mem, { employeeId, reason, month, code = null }) {
  mem.entries.push({ employeeId, reason, month, validUntil: month + VALID_MONTHS });
  mem.decisions.push({ code: code || reason, outcome: 'accepted' });
  return mem;
}

/** A flag that turned out to be a real problem and was fixed. */
export function recordFix(mem, { code }) {
  mem.decisions.push({ code, outcome: 'fixed' });
  return mem;
}

/** What the memory changes for one employee in a given month. Rules and bank checks are never switched off. */
export function applyMemory(mem, employeeId, month) {
  const live = mem.entries.filter((m) => m.employeeId === employeeId && month > m.month && month <= m.validUntil);
  const out = { knownReasons: [], baselineFrom: null, notes: [] };
  for (const m of live) {
    if (m.reason === 'PROMOTION') { out.baselineFrom = m.month; out.notes.push('New pay level accepted'); }
    if (m.reason === 'BANK_VERIFIED_BY_CALL') out.notes.push('Bank account verified');
  }
  return out;
}

/**
 * Suggest tuning from admin decisions. A flag type accepted 80%+ of the time over at least 5 decisions
 * is a candidate to soften; one that is almost always a real problem is a candidate to escalate.
 */
export function tuningSuggestions(mem, { minDecisions = 5, labels = {} } = {}) {
  const by = {};
  for (const d of mem.decisions) {
    by[d.code] = by[d.code] || { accepted: 0, fixed: 0 };
    by[d.code][d.outcome] += 1;
  }
  const out = [];
  for (const [code, c] of Object.entries(by)) {
    const n = c.accepted + c.fixed;
    if (n < minDecisions) continue;
    const acceptRate = c.accepted / n;
    const name = labels[code] || code;
    if (acceptRate >= 0.8) out.push({ code, action: 'soften', acceptRate, text: `${name} was accepted in ${c.accepted} of ${n} reviews. Suggest asking for a reason code at entry, or lowering its weight. Needs admin approval.` });
    else if (acceptRate <= 0.2) out.push({ code, action: 'escalate', acceptRate, text: `${name} was a real problem in ${c.fixed} of ${n} reviews. Suggest holding it automatically. Needs admin approval.` });
  }
  return out;
}
