// PayShield monthly pay run check: pick a month, Process it, and see the Pay Score and the findings of the five guards.
// Everything comes from the database: pay runs, the saved analysis per run (company ML model + payroll rules),
// the Identification checks, and the Fix / Accept decisions (saved as model feedback).
import { ICON } from './chrome.js';

const GUARDS = [
  ['people', 'Employment', 'users', 'Is every person in this run really due this pay?'],
  ['time', 'Attendance', 'clock', 'Were the paid hours really worked?'],
  ['bank', 'Bank Shield', 'shield', 'Is the salary going to the right account?'],
  ['pay', 'Pay Structure', 'wallet', 'Is this pay right for this person and policy?'],
  ['compliance', 'Compliance', 'library', 'Are we following CPF, MOM and our own policies?'],
];
const GUARD_OF = {
  UNUSUAL_OVERTIME: 'time',
  SHARED_BANK_ACCOUNT: 'bank', BANK_ACCOUNT_CHANGED: 'bank',
  DUPLICATE_NRIC: 'people', DUPLICATE_FIN: 'people', MISSING_ID: 'people', WORK_PASS_EXPIRED: 'people', WORK_PASS_EXPIRING: 'people',
  SHARED_PHONE: 'people', NRIC_CHANGED: 'people', FIN_CHANGED: 'people', PHONE_CHANGED: 'people', EMAIL_CHANGED: 'people', DATA_QUALITY: 'people',
  STATUTORY_CONTRIBUTION_CHANGE: 'compliance', STATUTORY_MISSING_CONTRIBUTION: 'compliance', STATUTORY_ENGINE_FLAG: 'compliance',
  NEGATIVE_OR_ZERO_NET_PAY: 'compliance', DUPLICATE_PAY_RUN: 'compliance', NEW_DEDUCTION: 'compliance', UNUSUAL_DEDUCTION: 'compliance',
  // compliance checks on the pay run (CPF, MOM, Employment Act, approvals)
  PAID_AFTER_LEAVING: 'people', DUPLICATE_PAYMENT: 'people',
  OT_OVER_LIMIT: 'time', OT_RATE_TOO_LOW: 'time',
  ONE_OFF_NOT_APPROVED: 'pay', RUN_TOTAL_OFF_EXPECTED: 'pay',
  CPF_RATE_WRONG: 'compliance', CPF_ON_FOREIGNER: 'compliance', AW_CEILING_EXCEEDED: 'compliance', SDL_MISSING: 'compliance',
  SHG_MISSING: 'compliance', PASS_SALARY_BELOW_MOM: 'compliance', LEVY_NOT_SET: 'compliance', DEDUCTION_OVER_LIMIT: 'compliance',
  LATE_PAY_RUN: 'compliance', NO_SECOND_APPROVER: 'compliance',
};
const RUN_LEVEL = 'PAY RUN'; // findings about the whole pay run, not one employee
const guardOf = (t) => GUARD_OF[t] || 'pay';

// [fix button, done text, accept button, done text]
const ACTIONS = {
  UNUSUAL_SALARY_INCREASE: ['Revert to last approved salary', 'Reverted to the last approved salary.', 'Keep: revision approved', 'Kept: salary revision approved.'],
  UNUSUAL_SALARY_DECREASE: ['Restore the salary', 'Salary restored.', 'Keep: reduction approved', 'Kept: reduction approved.'],
  LARGE_SALARY_REVISION: ['Hold for a second approver', 'Held for a second approver.', 'Keep: revision approved', 'Kept: revision approved.'],
  UNUSUAL_OVERTIME: ['Hold OT until approved', 'Overtime held until the manager approves it.', 'Accept: OT approved', 'Accepted: overtime was approved.'],
  DUPLICATE_ALLOWANCE: ['Remove the duplicate allowance', 'Duplicate allowance removed.', 'Keep: both are valid', 'Kept: both allowances are valid.'],
  MISSING_RECURRING_ALLOWANCE: ['Add the allowance back', 'Recurring allowance added back.', 'Accept: allowance ended', 'Accepted: the allowance has ended.'],
  UNUSUAL_ALLOWANCE: ['Correct the allowance', 'Allowance corrected.', 'Accept: allowance approved', 'Accepted: allowance approved.'],
  UNEXPECTED_NET_PAY_CHANGE: ['Hold for review', 'Held until the change is explained.', 'Accept: change explained', 'Accepted: the change is explained.'],
  UNUSUAL_PAY_PATTERN: ['Hold for review', 'Held for review.', 'Accept: pattern expected', 'Accepted: the pattern is expected.'],
  NEW_DEDUCTION: ['Remove the deduction', 'Deduction removed.', 'Keep: deduction authorised', 'Kept: the employee authorised it.'],
  UNUSUAL_DEDUCTION: ['Correct the deduction', 'Deduction corrected.', 'Keep: deduction authorised', 'Kept: deduction authorised.'],
  STATUTORY_MISSING_CONTRIBUTION: ['Recalculate CPF', 'CPF recalculated for this run.', 'Accept: not liable', 'Accepted: not liable for CPF.'],
  STATUTORY_CONTRIBUTION_CHANGE: ['Recalculate CPF', 'CPF recalculated for this run.', 'Accept: change expected', 'Accepted: the CPF change is expected.'],
  NEGATIVE_OR_ZERO_NET_PAY: ['Hold and correct the record', 'Held and corrected.', 'Accept: zero pay expected', 'Accepted: zero pay is expected.'],
  DUPLICATE_NRIC: ['Hold pay and investigate', 'Pay held while HR checks the duplicate record.', 'Accept: records verified', 'Accepted: both records verified.'],
  DUPLICATE_FIN: ['Hold pay and investigate', 'Pay held while HR checks the work pass records.', 'Accept: records verified', 'Accepted: records verified.'],
  SHARED_BANK_ACCOUNT: ['Hold until confirmed', 'Pay held until the account owner is confirmed.', 'Accept: joint account confirmed', 'Accepted: joint account confirmed.'],
  BANK_ACCOUNT_CHANGED: ['Hold until confirmed on a 2nd channel', 'Held until the employee confirms the new account on a known number.', 'Accept: change verified', 'Accepted: bank change verified with the employee.'],
  WORK_PASS_EXPIRED: ['Stop pay until renewed', 'Pay stopped until a valid pass is on file.', 'Accept: renewal on file', 'Accepted: renewal is on file.'],
  WORK_PASS_EXPIRING: ['Start the renewal', 'Renewal started with HR.', 'Accept: renewal in progress', 'Accepted: renewal already in progress.'],
  MISSING_ID: ['Request the ID document', 'ID document requested from the employee.', 'Accept: exempt', 'Accepted: exempt.'],
  PAID_AFTER_LEAVING: ['Remove from this pay run', 'Removed from the pay run; recovery of overpaid salary started.', 'Accept: final pay due', 'Accepted: this is the final settlement.'],
  DUPLICATE_PAYMENT: ['Delete the duplicate record', 'Duplicate pay record deleted.', 'Accept: two contracts', 'Accepted: two separate contracts.'],
  OT_OVER_LIMIT: ['Hold hours above 72', 'Overtime above 72 hours held.', 'Accept: MOM exemption on file', 'Accepted: MOM overtime exemption on file.'],
  OT_RATE_TOO_LOW: ['Recalculate at 1.5x', 'Overtime recalculated at 1.5x.', 'Accept: not covered by Part IV', 'Accepted: employee not covered by the overtime rules.'],
  ONE_OFF_NOT_APPROVED: ['Remove the payment', 'One-off payment removed.', 'Accept: approval attached', 'Accepted: approval attached.'],
  RUN_TOTAL_OFF_EXPECTED: ['Hold the bank file', 'Bank file held until the total is explained.', 'Accept: total explained', 'Accepted: the total is explained.'],
  CPF_RATE_WRONG: ['Recalculate CPF', 'CPF recalculated with the right age band.', 'Accept: rate confirmed', 'Accepted: CPF rate confirmed.'],
  CPF_ON_FOREIGNER: ['Remove CPF', 'CPF removed and the employee share refunded.', 'Accept: now a PR', 'Accepted: employee is now a PR.'],
  AW_CEILING_EXCEEDED: ['Cap CPF on the bonus', 'CPF capped at the annual ceiling.', 'Accept: ceiling checked', 'Accepted: ceiling checked.'],
  SDL_MISSING: ['Recalculate SDL', 'SDL recalculated.', 'Accept: exempt', 'Accepted: SDL exempt.'],
  SHG_MISSING: ['Recalculate the fund', 'Self-help group fund recalculated.', 'Accept: employee opted out', 'Accepted: employee opted out.'],
  PASS_SALARY_BELOW_MOM: ['Correct to the declared salary', 'Salary corrected to the amount declared to MOM.', 'Accept: pass updated', 'Accepted: pass updated with MOM.'],
  LEVY_NOT_SET: ['Set up the levy', 'Levy tier and sector set up.', 'Accept: levy waived', 'Accepted: levy waived.'],
  DEDUCTION_OVER_LIMIT: ['Cap deductions at 50%', 'Deductions capped; recovery spread over later months.', 'Accept: employee consent on file', 'Accepted: written consent on file.'],
  LATE_PAY_RUN: ['Bring the pay date forward', 'Pay date brought forward.', 'Accept: MOM approval on file', 'Accepted: MOM approval for the later date.'],
  NO_SECOND_APPROVER: ['Send to a second approver', 'Sent to a second approver.', 'Accept: second approver signed off', 'Accepted: second approver signed off.'],
};
const DEFAULT_ACTIONS = ['Mark as error and fix it', 'Marked as an error and fixed.', 'Accept: expected', 'Accepted as expected.'];
const STATE_OF = { CONFIRMED_ERROR: 'fixed', EXPECTED_CHANGE: 'accepted', FALSE_POSITIVE: 'accepted' };
const WEIGHT = { CRITICAL: 8, HIGH: 4, MEDIUM: 2, LOW: 1 };

const MONEY = new Set(['basic_contractual', 'basic', 'net_pay', 'gross_pay', 'gross', 'allowances', 'allowance', 'deductions', 'deduction', 'cpf', 'cpf_employee', 'cpf_employer']);
const LABEL = { basic_contractual: 'Basic salary', net_pay: 'Net pay', gross_pay: 'Gross pay', overtime_hours: 'Overtime hours' };
const MONTHS = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
const esc = (v) => String(v ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
const sgd = (v, dp = 0) => 'S$' + Number(v || 0).toLocaleString('en-SG', { minimumFractionDigits: dp, maximumFractionDigits: dp });
const fmt = (m, v) => (v == null ? '—' : MONEY.has(m) ? sgd(v, 2) : `${Number(v).toLocaleString('en-SG', { maximumFractionDigits: 2 })}${m === 'overtime_hours' ? ' h' : ''}`);
const cap = (s) => String(s || '').toLowerCase().replace(/_/g, ' ').replace(/^./, (c) => c.toUpperCase());
const key = (y, m) => `${String(m + 1).padStart(2, '0')}/${y}`; // pay_period.value format

export function payShield({ api, isTrained, render, toast, go }) {
  const now = new Date();
  const P = { year: now.getFullYear(), month: now.getMonth(), tab: 'overview', runs: null, people: null, byPeriod: {}, identBy: {}, emps: {}, filter: 'all', openRow: null, busy: '', err: '', loaded: false, sel: null };
  const runOf = (y, m) => (P.runs || []).find((r) => r.period === key(y, m));
  const years = () => [...new Set([now.getFullYear(), ...(P.runs || []).map((r) => +r.period.slice(3))])].sort((a, b) => b - a);
  const latestRun = () => (P.runs || [])[0];
  // employees taken out of a pay run (On Hold); kept in this browser, per pay run: { runUid: { employeeNo: { name, on } } }
  const HOLD_KEY = 'payshield-on-hold';
  const H = (() => { try { return JSON.parse(localStorage.getItem(HOLD_KEY)) || {}; } catch { return {}; } })();
  const saveHold = () => { try { localStorage.setItem(HOLD_KEY, JSON.stringify(H)); } catch { /* storage off: kept for this session */ } };
  const holdOf = (run) => (run && H[run.uid]) || {};

  function toIssues(analysis, identity) {
    const byNo = Object.fromEntries((P.people || []).map((e) => [e.employee_no, e]));
    const all = [...(analysis?.anomalies || []).map((x) => ({ ...x, from: 'payroll' })), ...(identity?.findings || []).map((x) => ({ ...x, from: 'identity' }))];
    // a net pay jump is usually the result of another finding on the same person; keep it only when it is the only signal
    const other = new Set(all.filter((x) => x.anomalyType !== 'UNEXPECTED_NET_PAY_CHANGE').map((x) => x.employeeNo));
    const groups = {}, folded = {};
    for (const x of all) {
      if (x.anomalyType === 'UNEXPECTED_NET_PAY_CHANGE' && other.has(x.employeeNo)) { (folded[x.employeeNo] = folded[x.employeeNo] || []).push(x); continue; }
      const k = `${guardOf(x.anomalyType)}|${x.employeeNo}`;
      (groups[k] = groups[k] || []).push(x);
    }
    return Object.entries(groups).map(([k, xs], n) => {
      xs.sort((a, b) => b.riskScore - a.riskScore);
      const top = xs[0], [guard, no] = k.split('|'), e = byNo[no] || {};
      const money = xs.filter((x) => MONEY.has(x.metric) && x.currentValue != null && x.expectedValue != null).map((x) => Math.abs(x.currentValue - x.expectedValue));
      const netJump = (analysis?.anomalies || []).find((x) => x.employeeNo === no && x.anomalyType === 'UNEXPECTED_NET_PAY_CHANGE');
      const impact = money.length ? Math.max(...money) : netJump ? Math.abs(netJump.currentValue - netJump.expectedValue) : ['CRITICAL', 'HIGH'].includes(top.severity) ? e.net || 0 : 0;
      const [fl, fd, al, ad] = ACTIONS[top.anomalyType] || DEFAULT_ACTIONS;
      return {
        id: n, guard, no, name: no === RUN_LEVEL ? 'Whole pay run' : e.name || no, basic: e.basic, top, signals: xs.length, runLevel: no === RUN_LEVEL,
        held: top.severity === 'CRITICAL' || (top.severity === 'HIGH' && top.riskScore >= 88),
        state: STATE_OF[top.latestFeedback] || 'open',
        idf: xs.filter((x) => x.from === 'identity'),
        folded: folded[no] || [],
        impact: Math.round(impact * 100) / 100,
        param: top.from === 'payroll' && top.metric
          ? [LABEL[top.metric] || cap(top.metric), fmt(top.metric, top.currentValue), `usual ${fmt(top.metric, top.expectedValue)}${top.changePct != null ? ` (${top.changePct > 0 ? '+' : ''}${Number(top.changePct).toFixed(0)}%)` : ''}`]
          : [cap(top.anomalyType), top.evidence?.expiry || (top.evidence?.sharedWith || []).join(', ') || top.evidence?.field || no, `rule ${top.ruleId || ''}`],
        fix: [fl, fd], alt: [al, ad], ids: [...xs, ...(folded[no] || [])].filter((x) => x.anomalyId).map((x) => x.anomalyId),
      };
    }).sort((a, b) => b.held - a.held || b.impact - a.impact);
  }

  // Pay Score: share of employees with nothing open, minus severity weights; any open HIGH/CRITICAL caps it at 79
  function score(issues, total) {
    const open = issues.filter((i) => i.state === 'open');
    const raw = Math.round(100 * (1 - new Set(open.map((i) => i.no)).size / Math.max(1, total)) - Math.min(40, open.reduce((s, i) => s + (WEIGHT[i.top.severity] || 1), 0)));
    const capped = open.some((i) => ['CRITICAL', 'HIGH'].includes(i.top.severity)) ? Math.min(raw, 79) : raw;
    const s = Math.max(0, capped);
    return { score: s, verdict: s < 80 ? 'Not ready to pay' : s < 90 ? 'Needs review' : 'Ready to approve', tone: s < 80 ? 'bad' : s < 90 ? 'warn' : 'good',
      open: open.length, held: open.filter((i) => i.held).length, atRisk: open.reduce((t, i) => t + i.impact, 0), kept: issues.filter((i) => i.state === 'fixed').reduce((t, i) => t + i.impact, 0) };
  }

  // identity checks for a pay run use the employee records as they were at the end of that pay period
  const identFor = (run) => (run && P.identBy[run.period]) || null;
  const loadIdent = async (run) => { if (isTrained('IDENTIFICATION')) P.identBy[run.period] = await api(`/api/v1/identity/check?pay_run_id=${run.uid}`).catch(() => null); };
  const view = (run) => {
    const a = run && P.byPeriod[run.period];
    if (!a || a === 'none') return null;
    const all = toIssues(a, identFor(run)), hold = holdOf(run);
    const issues = all.filter((i) => !hold[i.no]), parked = all.filter((i) => hold[i.no]);
    return { a, issues, parked, held: Object.keys(hold), s: score(issues, a.totalEmployees - Object.keys(hold).length) };
  };

  async function loadAll() {
    P.busy = 'load'; P.err = ''; render();
    try {
      P.runs = (await api('/api/v1/pay-runs')).payRuns;
      P.people = (await api('/api/v1/lookup/employees?limit=200')).employees;
      if (!runOf(P.year, P.month) && latestRun()) { P.year = +latestRun().period.slice(3); P.month = +latestRun().period.slice(0, 2) - 1; }
      await loadYear();
    } catch (e) { P.err = e.message; } finally { P.busy = ''; P.loaded = true; render(); }
  }
  // saved analyses (scores) for every pay run of the selected year, for the month strip
  async function loadYear() {
    const runs = (P.runs || []).filter((r) => +r.period.slice(3) === P.year && !(r.period in P.byPeriod));
    await Promise.all(runs.map(async (r) => {
      P.byPeriod[r.period] = await api(`/api/v1/payroll/runs/${r.uid}/analysis`).catch(() => 'none');
      if (P.byPeriod[r.period] !== 'none') await loadIdent(r);
    }));
  }

  async function process() {
    const run = runOf(P.year, P.month);
    if (!run || P.busy) return;
    if (P.byPeriod[run.period] && P.byPeriod[run.period] !== 'none'
      && !confirm(`Process ${MONTHS[P.month]} ${P.year} again?\n\nThe pay run is checked again with the current model. Fix / Accept decisions made on the previous check stay in its history but start again on the new results.`)) return;
    P.busy = 'process'; P.err = ''; render();
    try {
      await loadIdent(run);
      P.byPeriod[run.period] = await api('/api/v1/payroll/analyze', { method: 'POST', body: JSON.stringify({ payRunId: run.uid, supersede: true }) });
      const v = view(run);
      toast(`<b>${MONTHS[P.month]} ${P.year} processed.</b> Pay Score ${v.s.score}/100 · ${v.s.verdict} · ${v.issues.length} finding${v.issues.length === 1 ? '' : 's'}`);
    } catch (e) { P.err = e.message; } finally { P.busy = ''; render(); }
  }

  async function decide(id, how, uid) {
    const run = (uid && (P.runs || []).find((r) => r.uid === uid)) || runOf(P.year, P.month);
    const v = view(run), i = v && [...v.issues, ...v.parked].find((x) => x.id === +id);
    if (!i) return;
    const outcome = how === 'fix' ? 'CONFIRMED_ERROR' : how === 'alt' ? 'EXPECTED_CHANGE' : 'NEEDS_INVESTIGATION';
    await Promise.all([
      ...i.ids.map((aid) => api('/api/v1/payroll/feedback', { method: 'POST', body: JSON.stringify({ anomalyId: aid, outcome }) })),
      ...i.idf.map((f) => api('/api/v1/identity/decisions', { method: 'POST', body: JSON.stringify({ payRunId: run.uid, employeeNo: f.employeeNo, anomalyType: f.anomalyType, outcome }) })),
    ]);
    v.a.anomalies.filter((x) => i.ids.includes(x.anomalyId)).forEach((x) => { x.latestFeedback = outcome; });
    i.idf.forEach((f) => { const g = identFor(run)?.findings.find((y) => y.employeeNo === f.employeeNo && y.anomalyType === f.anomalyType); if (g) g.latestFeedback = outcome; });
    const after = view(run).s, taught = taughtNote(i, how);
    if (v.parked.includes(i)) { toast(how === 'undo' ? `<b>${esc(i.name)}</b> is open again (still on hold)` : `<b>${esc(i.name)} ${how === 'fix' ? 'fixed' : 'accepted'}</b> (on hold)${taught}`); render(); return; }
    toast(how === 'undo' ? `<b>${esc(i.name)}</b> is open again · Pay Score ${after.score}${taught}` : `<b>${esc(i.name)} ${how === 'fix' ? 'fixed' : 'accepted'}.</b> Pay Score ${v.s.score} → <b>${after.score}</b>${after.score === 100 ? ' · 🎉 ready to run payroll' : ''}${taught}`);
    render();
  }
  const taughtNote = (i, how) => (how === 'alt' && i.ids.length ? `<br>🧠 Learned: ${esc(typeName(i.top.anomalyType).toLowerCase())} at ${esc(i.param[1])} is normal for ${esc(i.name)}; it won’t be flagged again.` : how !== 'alt' && i.ids.length ? '<br>🧠 Anything the model learned from this finding was removed.' : '');

  // take an employee out of this pay run (all their findings move to On Hold) or bring them back
  function hold(no, back, uid) {
    const run = (uid && (P.runs || []).find((r) => r.uid === uid)) || runOf(P.year, P.month), v = view(run);
    if (!v || run.locked) return;
    const name = (P.people || []).find((e) => e.employee_no === no)?.name || no;
    if (back) { delete H[run.uid][no]; if (!Object.keys(H[run.uid]).length) delete H[run.uid]; }
    else (H[run.uid] = H[run.uid] || {})[no] = { name, on: new Date().toISOString() };
    saveHold(); P.openRow = null;
    toast(back ? `<b>${esc(name)}</b> is back in the ${esc(run.name)} pay run · Pay Score ${v.s.score} → <b>${view(run).s.score}</b>`
      : `<b>${esc(name)}</b> moved to <b>On Hold</b> and left out of ${esc(run.name)} · Pay Score ${v.s.score} → <b>${view(run).s.score}</b>`);
    render();
  }

  /* ---------- page ---------- */
  const ring = (v, tone) => { const r = 52, c = 2 * Math.PI * r, col = { bad: '#ef4444', warn: '#f59e0b', good: '#10b981' }[tone] || '#e5e7eb';
    return `<svg class="psm-ring" viewBox="0 0 130 130"><circle cx="65" cy="65" r="${r}" fill="none" stroke="#eef0f4" stroke-width="12"/><circle cx="65" cy="65" r="${r}" fill="none" stroke="${col}" stroke-width="12" stroke-linecap="round" stroke-dasharray="${(c * (v || 0) / 100).toFixed(1)} ${c.toFixed(1)}" transform="rotate(-90 65 65)" style="transition:stroke-dasharray .6s"/><text x="65" y="74" text-anchor="middle" font-size="34" font-weight="800" fill="#111827">${v ?? '—'}</text></svg>`; };

  function strip() {
    return `<div class="psm-strip">${MONTHS.map((m, k) => {
      const run = runOf(P.year, k), v = view(run), on = k === P.month;
      const cls = !run ? 'none' : !v ? 'todo' : v.s.tone;
      return `<button class="psm-m ${cls} ${on ? 'on' : ''}" data-act="psMonth:${k}" ${P.busy ? 'disabled' : ''}><small>${m}</small><b>${!run ? '·' : v ? v.s.score : '—'}</b><em>${!run ? 'no run' : v ? (v.s.open ? `${v.s.open} open` : 'clear') : 'not processed'}</em></button>`;
    }).join('')}</div>`;
  }

  function card(i, uid) {
    const open = i.state === 'open', onHold = !!uid, act = (how) => `psDecide:${i.id}-${how}${uid ? `-${uid}` : ''}`;
    return `<div class="psm-card ${open ? (i.held ? 'held' : 'review') : 'done'}">
      <div class="psm-ch"><span class="psm-av">${esc((i.name.match(/\b\w/g) || ['?']).slice(-2).join('').toUpperCase())}</span><div><b>${esc(i.name)}</b><small>${esc(i.no)}${i.basic ? ` · basic ${sgd(i.basic)}` : ''}</small></div>
        <span class="psm-tag ${open ? (i.held ? 'r' : 'o') : 'g'}">${open ? (i.held ? 'Held' : 'Review') : i.state === 'fixed' ? 'Fixed' : 'Accepted'}</span></div>
      <p>${esc(i.top.description)}${i.signals > 1 ? ` <span class="psm-more">+${i.signals - 1} more signal${i.signals > 2 ? 's' : ''}</span>` : ''}</p>
      <div class="psm-param"><span>${esc(i.param[0])}</span><code>${esc(i.param[1])}</code><span>${esc(i.param[2])}</span><span class="psm-imp">${open ? 'At risk' : 'Kept right'} <b>${sgd(i.impact, i.impact % 1 ? 2 : 0)}</b></span></div>
      <div class="psm-src">${i.top.source === 'ML' ? '🤖 Company ML model' : String(i.top.ruleId || '').startsWith('CMP') ? `📜 Compliance check ${esc(i.top.ruleId)}` : i.top.from === 'identity' ? '🪪 Identification check' : `📏 Payroll rule ${esc(i.top.ruleId || '')}`} · ${esc(i.top.recommendedAction || '')}</div>
      ${open && locked() && !onHold ? '<div class="psm-done" style="color:#6b7280">🔒 Pay run locked</div>' : open ? `<div class="psm-act"><button class="btn sm p" data-act="${act('fix')}" ${P.busy ? 'disabled' : ''}>${esc(i.fix[0])}</button><button class="btn sm" data-act="${act('alt')}" ${P.busy ? 'disabled' : ''}>${esc(i.alt[0])}</button>${!onHold && !i.runLevel ? `<button class="btn sm psm-holdbtn" data-act="psHold:${i.no}" ${P.busy ? 'disabled' : ''} title="Leave this employee out of the pay run and fix later from On Hold">⏸ Remove from pay run</button>` : ''}</div>`
        : `<div class="psm-done">✓ ${esc(i.state === 'fixed' ? i.fix[1] : i.alt[1])} ${locked() && !onHold ? '' : `<button class="linkbtn" data-act="${act('undo')}">Undo</button>`}</div>`}
    </div>`;
  }

  /* ---------- one guard tab: every employee in the pay run, coloured by result ---------- */
  const COLS = {
    people: [['Joined', (e) => fmtDate(e.hired)], ['Employment', (e) => (e.new_hire ? '<span class="psm-chip b">New joiner</span>' : e.leaver ? '<span class="psm-chip o">Leaver</span>' : 'Active')]],
    time: [['OT hours', (e) => (e.ot_hours ? `<b>${Number(e.ot_hours).toFixed(1)} h</b>` : '<span class="muted">—</span>')],
      ['vs 72 h cap', (e) => (e.ot_hours ? `<span class="psm-otbar"><i style="width:${Math.min(100, e.ot_hours / 96 * 100)}%;background:${e.ot_hours > 72 ? '#ef4444' : e.ot_hours > 50 ? '#f59e0b' : '#10b981'}"></i><s></s></span>` : '')]],
    bank: [['Net pay to bank', (e) => sgd(e.net, 2)]],
    pay: [['Basic', (e) => sgd(e.basic)], ['Allowances', (e) => sgd(e.allowances)], ['Gross', (e) => sgd(e.gross, 2)], ['Net', (e) => `<b>${sgd(e.net, 2)}</b>`]],
    compliance: [['CPF', (e) => sgd(e.cpf, 2)], ['Deductions', (e) => sgd(e.deductions, 2)], ['Net', (e) => sgd(e.net, 2)]],
  };
  const PASS = { people: 'Identity, work pass and records OK', time: 'Hours in line with own history', bank: 'Account unchanged, not shared',
    pay: 'Pay in line with own history', compliance: 'CPF and deductions OK' };
  const fmtDate = (d) => (d ? new Date(d).toLocaleDateString('en-SG', { day: 'numeric', month: 'short', year: 'numeric' }) : '—');
  const rowState = (i) => (!i ? 'ok' : i.state !== 'open' ? 'done' : i.held ? 'issue' : 'warn');

  function guardTable(run, issues) {
    const g = GUARDS.find((x) => x[0] === P.tab), d = P.emps[run.period];
    const na = (P.tab === 'people' || P.tab === 'bank') && !identFor(run);
    if (!d || d === 'loading') {
      if (!d) { P.emps[run.period] = 'loading'; api(`/api/v1/lookup/pay-runs/${run.uid}/employees`).then((x) => { P.emps[run.period] = x; }).catch((e) => { P.err = e.message; P.emps[run.period] = { employees: [] }; }).finally(render); }
      return '<div class="card muted" style="padding:16px">Loading employees…</div>';
    }
    const by = Object.fromEntries(issues.filter((i) => i.guard === P.tab).map((i) => [i.no, i])), hold = holdOf(run);
    const runRow = by[RUN_LEVEL] ? [{ e: { employee_no: RUN_LEVEL, name: '📋 Whole pay run', run: true }, i: by[RUN_LEVEL], st: rowState(by[RUN_LEVEL]) }] : [];
    const rows = [...runRow, ...d.employees.map((e) => ({ e, i: by[e.employee_no], st: hold[e.employee_no] ? 'hold' : rowState(by[e.employee_no]) }))];
    const n = (k) => rows.filter((x) => x.st === k).length;
    const order = { issue: 0, warn: 1, done: 2, ok: 3, hold: 4 };
    const shown = rows.filter((x) => P.filter === 'all' || x.st === P.filter || (P.filter === 'ok' && x.st === 'done'))
      .sort((a, b) => order[a.st] - order[b.st] || (b.i?.impact || 0) - (a.i?.impact || 0) || a.e.employee_no.localeCompare(b.e.employee_no));
    const cols = COLS[P.tab];
    const tag = { issue: '<span class="psm-tag r">⛔ Issue</span>', warn: '<span class="psm-tag o">⚠ Warning</span>', done: '', ok: '<span class="psm-tag g">✓ Passed</span>', hold: '<span class="psm-tag n">⏸ On hold</span>' };
    const chip = (k, label, cls) => `<button class="psm-f ${cls} ${P.filter === k ? 'on' : ''}" data-act="psFilter:${k}">${label}</button>`;
    return `<div class="psm-gh"><span class="psm-gi">${ICON[g[2]] || ''}</span><div><b>${g[1]}</b><small>${g[3]}</small></div></div>
      ${na ? '<div class="psm-clear" style="background:#f9fafb;border-color:#e5e7eb;color:#6b7280;margin-bottom:10px">Train the Identification area to run identity checks. Rows below show pay data only.</div>' : ''}
      <div class="psm-filters">${chip('all', `All <b>${rows.length}</b>`, '')}${chip('issue', `⛔ Issues <b>${n('issue')}</b>`, 'r')}${chip('warn', `⚠ Warnings <b>${n('warn')}</b>`, 'o')}${chip('ok', `✓ Passed <b>${n('ok') + n('done')}</b>`, 'g')}</div>
      <div class="psm-tw"><table class="psm-t psm-gt"><thead><tr><th class="c-emp">Employee</th>${cols.map(([h]) => `<th>${h}</th>`).join('')}<th class="c-res">Result</th><th class="c-st">Status</th></tr></thead><tbody>
      ${shown.map(({ e, i, st }) => {
        const result = st === 'hold' ? '<span class="muted">Left out of this pay run · see On Hold</span>' : i ? `${esc(i.top.description)}${i.signals > 1 ? ` <span class="psm-more">+${i.signals - 1}</span>` : ''}` : (na ? '<span class="muted">Not checked</span>' : PASS[P.tab]);
        const status = st === 'done' ? `<span class="psm-tag g">✓ ${i.state === 'fixed' ? 'Fixed' : 'Accepted'}</span>` : tag[st];
        const open = P.openRow === `${P.tab}|${e.employee_no}`;
        return `<tr class="psm-r ${st} ${i ? 'click' : ''}" ${i ? `data-act="psRow:${e.employee_no}"` : ''}><td><b>${esc(e.name)}</b><small>${esc(e.employee_no)}</small></td>
          ${cols.map(([, f]) => `<td>${e.run ? '<span class="muted">—</span>' : f(e)}</td>`).join('')}<td class="psm-res">${result}</td><td>${status}${i ? `<i class="psm-chev">${open ? '▴' : '▾'}</i>` : ''}</td></tr>
          ${open ? `<tr class="psm-det"><td colspan="${cols.length + 3}">${card(i)}</td></tr>` : ''}`;
      }).join('') || `<tr><td colspan="${cols.length + 3}" class="muted" style="padding:16px">No employees in this filter.</td></tr>`}</tbody></table></div>`;
  }

  const locked = () => !!runOf(P.year, P.month)?.locked;
  const typeName = (t) => cap(String(t || '').replaceAll('_', ' '));
  function learnedNote(a, names = {}) {
    const L = a?.learned || [], low = a?.lowered || [];
    if (!L.length && !low.length) return '';
    const nm = (no) => esc(names[no] || no || '');
    return `<details class="lrn-note"><summary>🧠 <b>Learned from your decisions:</b> ${L.length ? `${L.length} finding${L.length === 1 ? '' : 's'} not raised (accepted before)` : ''}${L.length && low.length ? ' · ' : ''}${low.length ? `${low.length} lowered in severity` : ''} <span>Show</span></summary>
      ${L.map((x) => `<div class="lrn-i">✓ <b>${nm(x.employeeNo)}</b> · ${esc(typeName(x.anomalyType))}${x.acceptedValue != null ? ` · ${fmt(x.metric, x.currentValue)} matches the accepted ${fmt(x.metric, x.acceptedValue)}` : ''} <small>accepted ${fmtDate(x.learnedOn)}</small></div>`).join('')}
      ${low.map((x) => `<div class="lrn-i">↓ ${esc(typeName(x.anomalyType))}: ${esc(x.from.toLowerCase())} → ${esc(x.to.toLowerCase())} <small>reviewers accepted ${x.accepted} of ${x.reviews} like this</small></div>`).join('')}</details>`;
  }
  // the local demo signs in as a service; show who that stands for
  const who = (x) => (String(x || '').startsWith('svc:') ? 'Payroll Admin' : x || '—');
  // the pay run can only go ahead at Pay Score 100; otherwise the button is disabled and the hover says what is left
  function proceed(run, v) {
    if (run.locked) return `<div class="psm-released">🔒 <b>Pay run completed</b> by ${esc(who(run.released_by))} on ${fmtDate(run.released_on)} · Pay Score ${run.pay_score ?? 100}
      <button class="btn sm" data-act="psOpenRun:${run.uid}">View pay run →</button></div>`;
    const { s, issues } = v;
    if (s.score === 100 && !s.open) return `<div class="psm-go"><button class="btn p psm-gobtn" data-act="psRelease" ${P.busy ? 'disabled' : ''}>${P.busy === 'release' ? 'Running payroll…' : `▶ Proceed with ${esc(run.name)} pay run`}</button><span>All checks passed. Payroll will be locked for ${MONTHS[P.month]}.</span></div>`;
    const by = GUARDS.map(([k, n]) => [n, issues.filter((i) => i.guard === k && i.state === 'open').length]).filter(([, c]) => c);
    const tip = `Pay Score must reach 100 before this pay run can go ahead. ${s.open} item${s.open === 1 ? ' is' : 's are'} still open (${s.held} held, ${s.open - s.held} to review): ${by.map(([n, c]) => `${n} ${c}`).join(', ')}. Open each guard tab and Fix or Accept every red and orange row.`;
    return `<div class="psm-go"><span class="psm-tipwrap" data-tip="${esc(tip)}" tabindex="0"><button class="btn p psm-gobtn" disabled>🔒 Proceed with pay run</button></span>
      <span>${s.open} open item${s.open === 1 ? '' : 's'} left · score ${s.score}/100</span></div>`;
  }

  async function release() {
    const run = runOf(P.year, P.month);
    if (!run || P.busy) return;
    const onHold = Object.keys(holdOf(run)).length;
    if (!confirm(`Run payroll for ${run.name}?\n\nPay Score is 100: every finding was fixed or accepted.${onHold ? ` ${onHold} employee${onHold === 1 ? ' is' : 's are'} on hold and left out; pay them off-cycle from On Hold once fixed.` : ''} The pay run will be locked and no more changes can be made.`)) return;
    P.busy = 'release'; P.err = ''; render();
    try {
      const r = await api(`/api/v1/pay-runs/${run.uid}/release`, { method: 'POST' });
      P.runs = (await api('/api/v1/pay-runs')).payRuns;
      PR.sel = P.month; PR.emps = {};
      toast(`<b>✓ ${esc(r.name)} pay run completed.</b> ${r.headcount} employees · net ${sgd(r.net, 2)} · locked`);
      go('tiPayRun');
    } catch (e) { P.err = e.message; } finally { P.busy = ''; render(); }
  }

  /* ---------- Pay runs page: a year calendar of monthly pay runs, coloured by PayShield and run status ---------- */
  const PR = { sel: null, emps: {}, q: '', fc: undefined };
  const k$ = (v) => (v >= 1e6 ? `S$${(v / 1e6).toFixed(2)}M` : `S$${Math.round(v / 1000)}k`);
  // pay forecast for future months (scikit-learn on the server, trained on this company's pay history)
  function forecastFor(y, m) {
    if (PR.fc === undefined) {
      PR.fc = null;
      api('/api/v1/forecast?months=12').then((f) => { PR.fc = f; }).catch((e) => { PR.fc = { error: e.message, months: [] }; }).finally(render);
    }
    return PR.fc?.months?.find((x) => x.period === key(y, m)) || null;
  }
  const STATES = {
    done: ['Paid', 'Pay run completed · PayShield 100', '✓'],
    ready: ['Ready to run', 'PayShield 100 · pay run not done yet', '▶'],
    blocked: ['Blocked', 'Pay run due · PayShield below 100', '⛔'],
    unchecked: ['Not checked', 'Pay run due · not processed in PayShield', '…'],
    missing: ['No pay run', 'Past month with no pay run in the database', '—'],
    future: ['Forecast', 'Future month · predicted from past pay', '✦'],
  };
  function monthState(y, m) {
    const run = runOf(y, m), v = view(run);
    if (run?.locked) return { k: 'done', run, v };
    if (!run) return { k: new Date(y, m, 1) > now ? 'future' : 'missing', run, v };
    if (!v) return { k: 'unchecked', run, v };
    return { k: v.s.score === 100 && !v.s.open ? 'ready' : 'blocked', run, v };
  }

  function payRunBody() {
    if (!P.loaded && P.busy !== 'load') loadAll();
    if (!P.runs) return P.err ? `<div class="card" style="color:var(--bad)">${esc(P.err)}</div>` : '<div class="card muted" style="padding:16px">Loading pay runs…</div>';
    const months = MONTHS.map((_, i) => ({ i, ...monthState(P.year, i) }));
    const sel = PR.sel != null ? months[PR.sel] : null;
    const count = (k) => months.filter((x) => x.k === k).length;
    const cal = `<div class="prc-bar"><div class="psm-pick"><label>Year</label><select data-ps="year" ${P.busy ? 'disabled' : ''}>${years().map((y) => `<option ${y === P.year ? 'selected' : ''}>${y}</option>`).join('')}</select></div>
        <div class="prc-legend">${Object.entries(STATES).map(([k, [n, d]]) => `<span class="prc-l ${k}" title="${esc(d)}"><i></i>${n}${count(k) ? ` <b>${count(k)}</b>` : ''}</span>`).join('')}</div></div>
      <div class="prc-grid">${months.map((x) => {
        const [name, , ic] = STATES[x.k];
        const fc = x.k === 'future' ? forecastFor(P.year, x.i) : null;
        const sub = x.k === 'future' ? (fc ? `≈ ${k$(fc.net.likely)} net · ${fc.headcount} staff` : PR.fc === null ? 'forecasting…' : 'Not yet') : x.k === 'done' ? `${x.run.records} paid · ${sgd(x.run.net)}` : x.k === 'ready' ? 'Score 100 · run it' : x.k === 'blocked' ? `Score ${x.v.s.score} · ${x.v.s.open} open` : x.k === 'unchecked' ? `${x.run.records} records` : x.k === 'future' ? 'Not yet' : 'Nothing to pay';
        return `<button class="prc-m ${x.k} ${PR.sel === x.i ? 'on' : ''}" data-act="prMonth:${x.i}">
          <span class="prc-ic">${ic}</span><small>${MONTHS[x.i]} ${P.year}</small><b>${name}</b><em>${sub}</em></button>`;
      }).join('')}</div>`;
    return `${P.err ? `<div class="card" style="border-color:var(--bad);color:var(--bad);margin-bottom:12px">${esc(P.err)}</div>` : ''}${cal}${sel ? detail(PR.sel, sel) : '<p class="prc-hint">👆 Click a month to see its pay run.</p>'}`;
  }

  function detail(m, x) {
    const label = `${MONTHS[m]} ${P.year}`, [name, desc] = STATES[x.k];
    const head = (body, actions = '') => `<div class="prc-det ${x.k}"><div class="prc-dh"><div><small>${label}</small><h3>${name}</h3><p>${desc}</p></div>${actions}</div>${body}</div>`;
    if (x.k === 'future' && forecastFor(P.year, m)) return forecastDetail(m, x, forecastFor(P.year, m), head);
    if (x.k === 'future' || x.k === 'missing') return head(`<div class="prc-none">${x.k === 'future' ? `${label} has not started yet.` : `There is no pay run for ${label} in the payroll database.`} No employees to show.</div>`);
    const open = `<button class="btn sm" data-act="prOpen:${m}">Open in PayShield →</button>`;
    if (x.k === 'unchecked') return head(`<div class="prc-none">${x.run.records} pay records are waiting. Process this month in PayShield to get its Pay Score.</div>`, `<button class="btn p" data-act="prOpen:${m}">▶ Check in PayShield</button>`);
    if (x.k === 'blocked') {
      const by = GUARDS.map(([g, n]) => [n, x.v.issues.filter((i) => i.guard === g && i.state === 'open').length]).filter(([, c]) => c);
      return head(`<div class="prc-block"><div class="prc-score bad">${x.v.s.score}<small>/100</small></div><div><b>${x.v.s.open} item${x.v.s.open === 1 ? '' : 's'} to resolve before this pay run can go ahead</b>
          <div class="prc-chips">${by.map(([n, c]) => `<span>${n} <b>${c}</b></span>`).join('')}</div><small>${x.v.s.held} held · ${sgd(x.v.s.atRisk)} at risk</small></div></div>`,
        `<button class="btn p" data-act="prOpen:${m}">Resolve in PayShield →</button>`);
    }
    if (x.k === 'ready') return head(`<div class="prc-block"><div class="prc-score good">100<small>/100</small></div><div><b>All checks passed for ${x.run.records} employees</b><small>Gross ${sgd(x.run.gross)} · Net ${sgd(x.run.net)} · CPF ${sgd(x.run.cpf)}</small></div></div>`,
      `${open}<button class="btn p psm-gobtn" data-act="prRun:${m}" ${P.busy ? 'disabled' : ''}>${P.busy === 'release' ? 'Running payroll…' : '▶ Run payroll'}</button>`);
    // done: who released it, totals, and every employee's pay (search + download)
    const d = PR.emps[x.run.uid];
    if (d === undefined) { PR.emps[x.run.uid] = null; api(`/api/v1/lookup/pay-runs/${x.run.uid}/employees`).then((r) => { PR.emps[x.run.uid] = r; }).catch((e) => { P.err = e.message; PR.emps[x.run.uid] = { employees: [] }; }).finally(render); }
    const emps = d?.employees || [];
    const kpis = `<div class="psm-kpis prc-k"><div><small>Employees paid</small><b>${x.run.records}</b></div><div><small>Gross</small><b>${sgd(x.run.gross)}</b></div><div><small>CPF</small><b>${sgd(x.run.cpf)}</b></div><div><small>Net to banks</small><b class="g">${sgd(x.run.net)}</b></div></div>`;
    const table = !d ? '<div class="card muted" style="padding:16px">Loading employees…</div>'
      : `<div class="prc-tools"><input id="prQ" placeholder="🔍 Search name or employee no." autocomplete="off"><span id="prN">${emps.length} employees</span><button class="btn sm" data-act="prCsv:${m}">⬇ Download CSV</button></div>
        <div class="psm-tw prc-tw"><table class="psm-t"><thead><tr><th>Employee</th><th>Basic</th><th>Allowances</th><th>Deductions</th><th>CPF</th><th>Gross</th><th>Net pay</th></tr></thead><tbody>
        ${emps.map((e) => `<tr class="psm-r" data-s="${esc(`${e.name} ${e.employee_no}`.toLowerCase())}"><td><b>${esc(e.name)}</b><small>${esc(e.employee_no)}</small></td><td>${sgd(e.basic)}</td><td>${sgd(e.allowances)}</td><td>${sgd(e.deductions, 2)}</td><td>${sgd(e.cpf, 2)}</td><td>${sgd(e.gross, 2)}</td><td><b>${sgd(e.net, 2)}</b></td></tr>`).join('')}</tbody></table></div>`;
    return head(`<div class="prc-rel">🔒 Completed by <b>${esc(who(x.run.released_by))}</b> on ${fmtDate(x.run.released_on)} · Pay Score ${x.run.pay_score} · ${x.run.resolved_findings} finding${x.run.resolved_findings === 1 ? '' : 's'} resolved before payday</div>${kpis}${table}`,
      `<button class="btn sm" data-act="prOpen:${m}">View PayShield results</button>`);
  }

  function forecastDetail(m, x, fc, head) {
    const f = PR.fc, bt = f.backtest || {}, last = f.basedOn.latestPeriod, lastLabel = `${MONTHS[+last.slice(0, 2) - 1]} ${last.slice(3)}`;
    const up = fc.changePct >= 0;
    const kpis = `<div class="psm-kpis prc-k"><div><small>Net pay (likely)</small><b>${sgd(fc.net.likely)}</b><em>range ${k$(fc.net.low)} – ${k$(fc.net.high)}</em></div>
      <div><small>Gross</small><b>${sgd(fc.gross)}</b><em>predicted</em></div><div><small>CPF</small><b>${sgd(fc.cpf)}</b><em>predicted</em></div>
      <div><small>vs ${lastLabel}</small><b class="${up ? '' : 'g'}">${up ? '▲' : '▼'} ${Math.abs(fc.changePct).toFixed(1)}%</b><em>${fc.headcount} employees</em></div></div>`;
    const drivers = fc.drivers.length ? `<div class="fc-drv"><b>Why it changes</b>${fc.drivers.map((d) => `<div>• ${esc(d)}</div>`).join('')}</div>` : '';
    const check = bt.months?.length ? `<div class="fc-bt">🎯 <b>Model check:</b> trained without the last 3 months, it forecast them within <b>${bt.meanErrorPct}%</b> on average
      (${bt.months.map((b) => `${MONTHS[+b.period.slice(0, 2) - 1]} ${b.errorPct}%`).join(' · ')}). Trained on ${f.basedOn.months} months · ${Number(f.basedOn.trainingRows).toLocaleString()} examples · ${esc(f.basedOn.method)}.</div>` : '';
    const table = `<div class="prc-tools"><input id="prQ" placeholder="🔍 Search name or employee no." autocomplete="off"><span id="prN">${fc.employees.length} employees</span><button class="btn sm" data-act="prFcCsv:${m}">⬇ Download CSV</button></div>
      <div class="psm-tw prc-tw"><table class="psm-t"><thead><tr><th>Employee</th><th>${lastLabel} net</th><th>Forecast low</th><th>Likely</th><th>High</th><th>Change</th></tr></thead><tbody>
      ${fc.employees.map((e) => { const d = e.likely - e.last_net; return `<tr class="psm-r" data-s="${esc(`${e.name} ${e.employee_no}`.toLowerCase())}"><td><b>${esc(e.name)}</b><small>${esc(e.employee_no)}</small></td>
        <td>${sgd(e.last_net, 2)}</td><td class="muted">${sgd(e.low)}</td><td><b>${sgd(e.likely)}</b></td><td class="muted">${sgd(e.high)}</td>
        <td class="${Math.abs(d) < 50 ? 'muted' : d > 0 ? 'fc-up' : 'fc-down'}">${Math.abs(d) < 50 ? '≈ same' : `${d > 0 ? '+' : ''}${sgd(d)}`}</td></tr>`; }).join('')}</tbody></table></div>`;
    return head(`<div class="fc-note">✦ This is a <b>forecast</b>, not a pay run: what payroll for ${MONTHS[m]} ${P.year} is likely to cost, learned from ${f.basedOn.months} months of your own pay history.</div>${kpis}${drivers}${check}${table}`);
  }
  function fcCsv(m) {
    const fc = forecastFor(P.year, m);
    if (!fc) return;
    const rows = [['Employee no', 'Name', 'Last net', 'Forecast low', 'Forecast likely', 'Forecast high'], ...fc.employees.map((e) => [e.employee_no, e.name, e.last_net, e.low, e.likely, e.high])];
    const a = document.createElement('a');
    a.href = URL.createObjectURL(new Blob([rows.map((x) => x.map((v) => `"${String(v ?? '').replace(/"/g, '""')}"`).join(',')).join('\n')], { type: 'text/csv' }));
    a.download = `Forecast_${MONTHS[m]}_${P.year}.csv`; a.click(); URL.revokeObjectURL(a.href);
  }

  // live search in the employee list without re-rendering (keeps the cursor in the box)
  document.addEventListener('input', (e) => {
    if (e.target?.id !== 'prQ') return;
    const q = e.target.value.trim().toLowerCase();
    let n = 0;
    document.querySelectorAll('.prc-tw tbody tr').forEach((tr) => { const ok = !q || tr.dataset.s.includes(q); tr.style.display = ok ? '' : 'none'; n += ok; });
    const c = document.getElementById('prN'); if (c) c.textContent = `${n} employee${n === 1 ? '' : 's'}`;
  });
  function csv(m) {
    const run = runOf(P.year, m), d = run && PR.emps[run.uid];
    if (!d) return;
    const rows = [['Employee no', 'Name', 'Basic', 'Allowances', 'Deductions', 'CPF', 'Gross', 'Net'],
      ...d.employees.map((e) => [e.employee_no, e.name, e.basic, e.allowances, e.deductions, e.cpf, e.gross, e.net])];
    const a = document.createElement('a');
    a.href = URL.createObjectURL(new Blob([rows.map((r) => r.map((v) => `"${String(v ?? '').replace(/"/g, '""')}"`).join(',')).join('\n')], { type: 'text/csv' }));
    a.download = `${run.name.replace(/\s+/g, '_')}_employees.csv`; a.click(); URL.revokeObjectURL(a.href);
  }

  function body() {
    if (!P.loaded && !P.busy) loadAll();
    if (!P.runs) return P.err ? `<div class="card" style="color:var(--bad)">${esc(P.err)}</div>` : '<div class="card muted" style="padding:16px">Loading pay runs…</div>';
    const run = runOf(P.year, P.month), v = view(run), label = `${MONTHS[P.month]} ${P.year}`;
    const isCurrent = P.year === now.getFullYear() && P.month === now.getMonth();
    const bar = `<div class="psm-bar"><div class="psm-pick"><label>Pay run month</label>
        <select data-ps="month" ${P.busy ? 'disabled' : ''}>${MONTHS.map((m, k) => `<option value="${k}" ${k === P.month ? 'selected' : ''}>${m}${runOf(P.year, k) ? '' : ' (no run)'}</option>`).join('')}</select>
        <select data-ps="year" ${P.busy ? 'disabled' : ''}>${years().map((y) => `<option ${y === P.year ? 'selected' : ''}>${y}</option>`).join('')}</select></div>
      <div class="psm-run">${run ? `<b>${esc(run.name)}</b> · ${run.records} pay records${isCurrent ? ' · <span class="psm-cur">current month</span>' : ''}<br><small>${v ? `Processed ${new Date(v.a.generatedAt).toLocaleString('en-SG', { day: 'numeric', month: 'short', hour: '2-digit', minute: '2-digit' })} · model ${v.a.modelVersion ? 'v' + v.a.modelVersion : '—'} · ${v.a.mlStatus.toLowerCase()}` : 'Not processed yet'}</small>` : `<b>No pay run for ${label}</b><br><small>Nothing in the database for this month yet</small>`}</div>
      ${run?.locked ? `<span class="psm-lock">🔒 Pay run completed${run.released_on ? ` ${fmtDate(run.released_on)}` : ''}</span>` : `<button class="btn p" data-act="psProcess" ${!run || P.busy ? 'disabled' : ''}>${P.busy === 'process' ? 'Processing…' : v ? '↻ Process again' : '▶ Process'}</button>`}</div>`;
    const err = P.err ? `<div class="card" style="border-color:var(--bad);color:var(--bad);margin-bottom:12px">${esc(P.err)}</div>` : '';
    if (!run || !v) {
      return `${bar}${err}${strip()}<div class="psm-empty"><span class="psm-ei">${ICON.gauge || ''}</span><h3>${run ? `${label} has not been processed` : `No pay run for ${label}`}</h3><p>${run ? `Click <b>Process</b> to check all ${run.records} pay records with your trained model, the payroll rules${isTrained('IDENTIFICATION') ? ' and the identity checks (as at the end of the month)' : ''}. The Pay Score and the findings of each guard appear here and are saved.` : 'Pick another month, or run payroll for this month first.'}</p>
        ${run ? `<button class="btn p" data-act="psProcess" ${P.busy ? 'disabled' : ''}>${P.busy === 'process' ? 'Processing…' : `▶ Process ${label}`}</button>` : ''}</div>`;
    }
    const { a, issues, s } = v, cnt = (g) => issues.filter((i) => i.guard === g && i.state === 'open').length;
    const tabs = `<div class="psm-tabs">${[['overview', 'Overview', null], ...GUARDS.map(([k, n]) => [k, n, cnt(k)])].map(([k, n, c]) => `<button class="${P.tab === k ? 'on' : ''}" data-act="psTab:${k}">${n}${c ? ` <span>${c}</span>` : c === 0 ? ' <i>✓</i>' : ''}</button>`).join('')}</div>`;
    const hero = `<div class="psm-hero ${s.tone}"><div class="psm-score">${ring(s.score, s.tone)}<small>Pay Score</small></div>
      <div class="psm-sum"><div class="psm-eyebrow">PayShield · ${label} pay run</div><h3>${s.verdict}</h3>
        <p>${v.held.length ? `<span class="psm-onhold" data-act="page:tiOnHold">⏸ ${v.held.length} employee${v.held.length === 1 ? '' : 's'} on hold, left out of this run</span><br>` : ''}${s.open ? `${s.held} held · ${s.open - s.held} to review · <b>${sgd(s.atRisk)}</b> would be paid wrongly` : 'Every guard passed. Nothing open.'}</p>
        ${proceed(run, v)}
        <div class="psm-kpis"><div><small>Checked</small><b>${a.totalEmployees}</b><em>employees</em></div><div><small>Findings</small><b>${issues.length}</b><em>${issues.length - s.open} resolved</em></div><div><small>At risk</small><b>${sgd(s.atRisk)}</b><em>if paid as is</em></div><div><small>Kept right</small><b class="g">${sgd(s.kept)}</b><em>fixed before payday</em></div></div></div></div>`;
    let content;
    if (P.tab === 'overview') {
      content = `<div class="psm-guards">${GUARDS.map(([k, n, ic, q]) => { const xs = issues.filter((i) => i.guard === k), o = xs.filter((i) => i.state === 'open'), h = o.some((i) => i.held);
        const na = (k === 'people' || k === 'bank') && !identFor(run);
        return `<button class="psm-g ${na ? 'na' : o.length ? (h ? 'bad' : 'warn') : 'good'}" data-act="psTab:${k}"><span class="psm-gi">${ICON[ic] || ''}</span><div><b>${n}</b><small>${q}</small></div>
          <div class="psm-gr">${na ? '<span class="psm-tag n">Identification not trained</span>' : o.length ? `<span class="psm-tag ${h ? 'r' : 'o'}">${o.length} open</span><small>${sgd(o.reduce((t, i) => t + i.impact, 0))} at risk</small>` : `<span class="psm-tag g">✓ Passed</span>${xs.length ? `<small>${xs.length} resolved</small>` : ''}`}</div></button>`; }).join('')}</div>
        ${identFor(run) ? `<p class="psm-note">Identity checks use the employee records as they were on ${new Date(identFor(run).asOf).toLocaleDateString('en-SG', { day: 'numeric', month: 'short', year: 'numeric' })} (end of this pay period).</p>` : ''}`;
    } else {
      content = guardTable(run, issues);
    }
    return `${bar}${err}${strip()}${hero}${learnedNote(a, Object.fromEntries((P.people || []).map((e) => [e.employee_no, e.name])))}${tabs}<div class="psm-body">${content}</div>`;
  }

  /* ---------- On Hold: employees taken out of a pay run, to fix and return (or pay off-cycle once the run is locked) ---------- */
  const heldCount = () => Object.values(H).reduce((t, x) => t + Object.keys(x).length, 0);
  function heldBody() {
    if (!P.loaded && !P.busy) loadAll();
    if (!P.runs) return '<div class="card muted" style="padding:16px">Loading…</div>';
    const runs = P.runs.filter((r) => H[r.uid]);
    const missing = runs.filter((r) => !(r.period in P.byPeriod));
    if (missing.length && !P.busy) {
      P.busy = 'load';
      Promise.all(missing.map(async (r) => { P.byPeriod[r.period] = await api(`/api/v1/payroll/runs/${r.uid}/analysis`).catch(() => 'none'); if (P.byPeriod[r.period] !== 'none') await loadIdent(r); }))
        .finally(() => { P.busy = ''; render(); });
    }
    if (!runs.length) return `<div class="psm-empty"><span class="psm-ei">⏸</span><h3>Nobody is on hold</h3><p>In PayShield, open a flagged employee and click <b>Remove from pay run</b> to leave them out of the run while you sort it out. They wait here with their findings, so the rest of the payroll can go ahead.</p><button class="btn p" data-act="page:tiPayShield">Go to PayShield</button></div>`;
    // grouped by pay month, newest first; chips filter to one month
    const sortKey = (p) => p.slice(3) + p.slice(0, 2), months = [...new Set(runs.map((r) => r.period))].sort((a, b) => sortKey(b).localeCompare(sortKey(a)));
    if (P.holdMonth && !months.includes(P.holdMonth)) P.holdMonth = '';
    const mLabel = (p) => `${MONTHS[+p.slice(0, 2) - 1]} ${p.slice(3)}`;
    const nIn = (p) => runs.filter((r) => r.period === p).reduce((t, r) => t + Object.keys(H[r.uid]).length, 0);
    const chip = (k, label, n) => `<button class="psm-f ${(P.holdMonth || '') === k ? 'on' : ''}" data-act="psHoldMonth:${k}">${label} <b>${n}</b></button>`;
    return `<p class="psm-note" style="margin:0 0 14px">Employees left out of a pay run. Their findings stay here until fixed or accepted. Return them to the run while it is open, or pay them off-cycle once it is locked.</p>
      <div class="psm-filters">${chip('', 'All months', heldCount())}${months.map((p) => chip(p, mLabel(p), nIn(p))).join('')}</div>
      ${months.filter((p) => !P.holdMonth || p === P.holdMonth).map((p) => `<h3 class="psm-holdm">${mLabel(p)} <small>${nIn(p)} on hold</small></h3>${runs.filter((r) => r.period === p).map((run) => {
        const v = view(run), list = Object.entries(H[run.uid]);
        return `<section class="psm-hold"><header><b>${esc(run.name)}</b> <span class="psm-tag ${run.locked ? 'n' : 'o'}">${run.locked ? '🔒 Pay run completed' : 'Pay run open'}</span><small>${list.length} on hold${v ? ` · run Pay Score ${v.s.score}` : ''}</small></header>
          ${list.map(([no, h]) => {
            const xs = v ? v.parked.filter((i) => i.no === no) : [], open = xs.filter((i) => i.state === 'open').length;
            return `<div class="psm-holdrow"><div class="psm-holdh"><span class="psm-av">${esc((h.name.match(/\b\w/g) || ['?']).slice(-2).join('').toUpperCase())}</span><div><b>${esc(h.name)}</b><small>${esc(no)} · on hold since ${fmtDate(h.on)}</small></div>
                <span class="psm-tag ${open ? 'o' : 'g'}">${!v ? 'Loading…' : open ? `${open} to fix` : '✓ All fixed'}</span>
                ${run.locked ? (open ? '' : `<button class="btn sm p" data-act="psPaid:${run.uid}|${no}">✓ Paid off-cycle</button>`) : `<button class="btn sm ${open ? '' : 'p'}" data-act="psReturn:${run.uid}|${no}" title="Put back into the pay run; its findings count in the Pay Score again">↩ Return to pay run</button>`}</div>
              <div class="psm-holdcards">${xs.map((i) => card(i, run.uid)).join('') || '<small class="muted">No open findings</small>'}</div></div>`;
          }).join('')}</section>`;
      }).join('')}`).join('')}`;
  }

  const actions = {
    psMonth: (k) => { P.month = +k; P.openRow = null; render(); },
    psTab: (k) => { P.tab = k; P.filter = 'all'; P.openRow = null; render(); },
    psFilter: (k) => { P.filter = k; render(); },
    psRow: (no) => { const k = `${P.tab}|${no}`; P.openRow = P.openRow === k ? null : k; render(); },
    psProcess: () => process(),
    psRelease: () => release(),
    psOpenRun: (uid) => { const r = (P.runs || []).find((x) => x.uid === uid); if (r) { P.year = +r.period.slice(3); PR.sel = +r.period.slice(0, 2) - 1; } go('tiPayRun'); },
    prMonth: (m) => { PR.sel = PR.sel === +m ? null : +m; render(); },
    prOpen: (m) => { P.month = +m; P.tab = 'overview'; go('tiPayShield'); },
    prRun: (m) => { P.month = +m; release(); },
    prCsv: (m) => csv(+m),
    prFcCsv: (m) => fcCsv(+m),
    psDecide: (arg) => { const [id, how, ...uid] = String(arg).split('-'); decide(id, how, uid.join('-')).catch((e) => { P.err = e.message; render(); }); },
    psHold: (no) => hold(no, false),
    psHoldMonth: (p) => { P.holdMonth = p || ''; render(); },
    psReturn: (arg) => { const [uid, no] = String(arg).split('|'); hold(no, true, uid); },
    psPaid: (arg) => { const [uid, no] = String(arg).split('|'); const h = H[uid]?.[no]; if (!h) return; delete H[uid][no]; if (!Object.keys(H[uid]).length) delete H[uid]; saveHold(); toast(`<b>${esc(h.name)}</b> marked as paid off-cycle and removed from On Hold`); render(); },
  };
  document.addEventListener('change', async (e) => {
    const w = e.target?.dataset?.ps;
    if (!w) return;
    if (w === 'month') P.month = +e.target.value;
    else { P.year = +e.target.value; P.busy = 'load'; render(); await loadYear().catch(() => {}); P.busy = ''; }
    P.tab = 'overview'; render();
  });
  // after training / unsubscribing everything is reloaded from the database
  const reset = () => Object.assign(P, { runs: null, people: null, byPeriod: {}, identBy: {}, emps: {}, openRow: null, loaded: false, err: '', tab: 'overview', local: {} });

  const scoreFor = (uid) => { const r = (P.runs || []).find((x) => x.uid === uid), v = r && view(r);
    return v ? { score: v.s.score, verdict: v.s.tone === 'good' ? 'Ready' : v.s.tone === 'warn' ? 'Review' : 'Not ready', open: v.s.open, flagged: new Set(v.issues.filter((i) => i.state === 'open').map((i) => i.no)).size, blocking: v.s.score <= 79 && v.s.held > 0 } : null; };
  // open one month on the PayShield page (from another page)
  const openMonth = (y, m) => { P.year = y; P.month = m; P.tab = 'overview'; go('tiPayShield'); };
  return { body, payRunBody, heldBody, heldCount, actions, reset, scoreFor, openMonth, learnedNote, label: () => `${MONTHS[P.month]} ${P.year}` };
}

export const PAYSHIELD_CSS = `
  .psm-bar{display:flex;align-items:center;gap:16px;flex-wrap:wrap;background:#fff;border:1px solid #e5e7eb;border-radius:14px;padding:14px 16px;margin-bottom:12px}
  .psm-pick{display:flex;align-items:center;gap:8px}.psm-pick label{font-size:12px;font-weight:700;color:#6b7280;text-transform:uppercase;letter-spacing:.04em}
  .psm-pick select{padding:8px 10px;border:1px solid #d1d5db;border-radius:9px;font:inherit;font-weight:600;background:#fff}
  .psm-run{flex:1;min-width:200px;font-size:13.5px}.psm-run small{color:#6b7280}.psm-cur{color:#4f46e5;font-weight:700}
  .psm-strip{display:grid;grid-template-columns:repeat(auto-fit,minmax(62px,1fr));gap:6px;margin-bottom:14px}
  .psm-m{border:1px solid #e5e7eb;background:#fff;border-radius:10px;padding:7px 4px;text-align:center;cursor:pointer;display:flex;flex-direction:column;gap:1px;font:inherit}
  .psm-m small{font-size:11px;color:#6b7280;font-weight:700}.psm-m b{font-size:17px}.psm-m em{font-style:normal;font-size:10px;color:#9ca3af;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
  .psm-m.none{background:#f9fafb;color:#c0c4cc;cursor:default}.psm-m.todo b{color:#9ca3af}
  .psm-m.bad{border-color:#fecaca;background:#fef2f2}.psm-m.bad b{color:#dc2626}.psm-m.warn{border-color:#fde68a;background:#fffbeb}.psm-m.warn b{color:#d97706}.psm-m.good{border-color:#a7f3d0;background:#ecfdf5}.psm-m.good b{color:#059669}
  .psm-m.on{outline:2px solid #4f46e5;outline-offset:1px}
  .psm-hero{display:flex;gap:22px;align-items:center;background:#fff;border:1px solid #e5e7eb;border-left:5px solid #9ca3af;border-radius:14px;padding:18px 20px;margin-bottom:14px}
  .psm-hero.bad{border-left-color:#ef4444}.psm-hero.warn{border-left-color:#f59e0b}.psm-hero.good{border-left-color:#10b981}
  .psm-holdbtn{margin-left:auto;color:#92400e;border-color:#fcd34d;background:#fffbeb}.psm-onhold{display:inline-block;margin-bottom:4px;color:#92400e;cursor:pointer;text-decoration:underline dotted}
  .psm-r.hold td{opacity:.55}.psm-tag.n{background:#f3f4f6;color:#4b5563;border-color:#d1d5db}
  .psm-hold{background:#fff;border:1px solid #e5e7eb;border-radius:12px;margin-bottom:16px;overflow:hidden}.psm-hold>header{display:flex;gap:10px;align-items:center;padding:12px 16px;background:#f9fafb;border-bottom:1px solid #e5e7eb}.psm-hold>header small{margin-left:auto;color:#6b7280}
  .psm-holdrow{padding:14px 16px;border-bottom:1px solid #f0f1f3}.psm-holdh{display:flex;gap:12px;align-items:center;margin-bottom:10px}.psm-holdh>div{flex:1}.psm-holdh small{display:block;color:#6b7280}
  .psm-holdcards{display:grid;gap:10px}.psm-holdm{margin:18px 0 10px;font-size:15px}.psm-holdm small{color:#6b7280;font-weight:400;margin-left:6px}
  .psm-score{text-align:center}.psm-score small{color:#6b7280;font-weight:600}.psm-ring{width:120px;height:120px;display:block}
  .psm-sum{flex:1;min-width:0}.psm-eyebrow{font-size:11px;font-weight:800;color:#7c3aed;text-transform:uppercase;letter-spacing:.06em}.psm-sum h3{margin:2px 0 4px;font-size:22px}.psm-sum p{margin:0 0 12px;color:#4b5563}
  .psm-kpis{display:grid;grid-template-columns:repeat(4,1fr);gap:8px}.psm-kpis div{background:#f9fafb;border-radius:10px;padding:8px 10px}.psm-kpis small{display:block;font-size:11px;color:#6b7280}.psm-kpis b{font-size:18px}.psm-kpis b.g{color:#059669}.psm-kpis em{display:block;font-style:normal;font-size:11px;color:#9ca3af}
  .psm-tabs{display:flex;gap:4px;border-bottom:1px solid #e5e7eb;margin-bottom:12px;overflow-x:auto}
  .psm-tabs button{border:0;background:none;padding:10px 14px;font:inherit;font-weight:600;color:#6b7280;cursor:pointer;border-bottom:2px solid transparent;white-space:nowrap}
  .psm-tabs button.on{color:#4f46e5;border-bottom-color:#4f46e5}.psm-tabs span{background:#fee2e2;color:#b91c1c;border-radius:999px;padding:1px 7px;font-size:11px;margin-left:2px}.psm-tabs i{font-style:normal;color:#059669;font-size:12px}
  .psm-guards{display:grid;gap:8px}.psm-g{display:flex;align-items:center;gap:12px;text-align:left;background:#fff;border:1px solid #e5e7eb;border-left:4px solid #10b981;border-radius:12px;padding:12px 14px;cursor:pointer;font:inherit}
  .psm-g.bad{border-left-color:#ef4444}.psm-g.warn{border-left-color:#f59e0b}.psm-g.na{border-left-color:#d1d5db}.psm-g>div:nth-child(2){flex:1}.psm-g small{display:block;color:#6b7280;font-size:12px}
  .psm-gi{width:36px;height:36px;border-radius:10px;background:#eef2ff;color:#4f46e5;display:grid;place-items:center;flex:none}.psm-gi svg{width:18px;height:18px}
  .psm-gr{text-align:right;display:flex;flex-direction:column;align-items:flex-end;gap:3px}
  .psm-tag{font-size:11.5px;font-weight:700;border-radius:999px;padding:2px 9px}.psm-tag.r{background:#fee2e2;color:#b91c1c}.psm-tag.o{background:#fef3c7;color:#92400e}.psm-tag.g{background:#d1fae5;color:#065f46}.psm-tag.n{background:#f3f4f6;color:#6b7280}
  .psm-gh{display:flex;align-items:center;gap:10px;margin-bottom:10px}.psm-gh small{display:block;color:#6b7280}
  .psm-card{background:#fff;border:1px solid #e5e7eb;border-left:4px solid #f59e0b;border-radius:12px;padding:12px 14px;margin-bottom:10px}
  .psm-card.held{border-left-color:#ef4444}.psm-card.done{border-left-color:#10b981;background:#fcfffd}
  .psm-ch{display:flex;align-items:center;gap:10px}.psm-ch>div{flex:1}.psm-ch small{display:block;color:#6b7280;font-size:12px}
  .psm-av{width:32px;height:32px;border-radius:50%;background:#eef2ff;color:#4f46e5;font-weight:800;font-size:12px;display:grid;place-items:center}
  .psm-card p{margin:8px 0;font-size:13.5px}.psm-more{font-size:11.5px;color:#7c3aed;font-weight:600}
  .psm-param{display:flex;align-items:center;gap:8px;flex-wrap:wrap;font-size:12.5px;color:#6b7280;background:#f9fafb;border-radius:8px;padding:6px 10px}
  .psm-param code{background:#fff;border:1px solid #e5e7eb;border-radius:6px;padding:1px 6px;color:#111827;font-weight:700}.psm-imp{margin-left:auto}.psm-imp b{color:#111827}
  .psm-src{font-size:12px;color:#6b7280;margin:8px 0}.psm-act{display:flex;gap:8px;flex-wrap:wrap}.psm-done{font-size:13px;color:#065f46}
  .psm-clear{background:#ecfdf5;border:1px solid #a7f3d0;color:#065f46;border-radius:12px;padding:14px}
  .psm-ei{width:56px;height:56px;border-radius:16px;background:#eef2ff;color:#4f46e5;display:inline-grid;place-items:center}.psm-ei svg{width:28px;height:28px}.psm-empty{background:#fff;border:1px dashed #d1d5db;border-radius:14px;padding:28px;text-align:center}.psm-empty h3{margin:6px 0}.psm-empty p{color:#6b7280;max-width:520px;margin:0 auto 14px}
  .psm-filters{display:flex;gap:6px;flex-wrap:wrap;margin-bottom:10px}
  .psm-f{border:1px solid #e5e7eb;background:#fff;border-radius:999px;padding:6px 12px;font:inherit;font-size:12.5px;cursor:pointer;color:#374151}
  .psm-f b{margin-left:3px}.psm-f.on{background:#111827;color:#fff;border-color:#111827}.psm-f.r:not(.on){color:#b91c1c;border-color:#fecaca;background:#fef2f2}
  .psm-f.o:not(.on){color:#92400e;border-color:#fde68a;background:#fffbeb}.psm-f.g:not(.on){color:#065f46;border-color:#a7f3d0;background:#ecfdf5}
  .psm-tw{background:#fff;border:1px solid #e5e7eb;border-radius:12px;overflow:auto;max-height:calc(100vh - 140px);container-type:inline-size}
  .psm-t thead th{position:sticky;top:0;z-index:2}
  .psm-gt{table-layout:fixed}.psm-gt th{white-space:normal}.psm-gt .c-emp{width:22%}.psm-gt .c-res{width:34%}.psm-gt .c-st{width:120px}.psm-gt td{overflow-wrap:anywhere}
  .psm-t{width:100%;border-collapse:collapse;font-size:13px;min-width:640px}
  .psm-t th{background:#f9fafb;text-align:left;font-size:11px;text-transform:uppercase;letter-spacing:.04em;color:#6b7280;padding:9px 12px;border-bottom:1px solid #e5e7eb;white-space:nowrap}
  .psm-t td{padding:9px 12px;border-bottom:1px solid #f1f2f4;vertical-align:middle}.psm-t td small{display:block;color:#9ca3af;font-size:11.5px}
  .psm-r td:first-child{border-left:4px solid transparent}
  .psm-r.issue td{background:#fef2f2}.psm-r.issue td:first-child{border-left-color:#ef4444}.psm-r.issue .psm-res{color:#991b1b}
  .psm-r.warn td{background:#fffbeb}.psm-r.warn td:first-child{border-left-color:#f59e0b}.psm-r.warn .psm-res{color:#92400e}
  .psm-r.ok td:first-child{border-left-color:#10b981}.psm-r.ok .psm-res{color:#047857}
  .psm-r.done td{background:#f0fdf4}.psm-r.done td:first-child{border-left-color:#10b981}.psm-r.done .psm-res{color:#6b7280;text-decoration:line-through}
  .psm-r.click{cursor:pointer}.psm-r.click:hover td{filter:brightness(.98)}.psm-res{min-width:260px;max-width:420px}.psm-r td:last-child{white-space:nowrap}.psm-r td:first-child{min-width:150px}
  .psm-chev{font-style:normal;color:#9ca3af;margin-left:6px}.psm-det td{background:#f9fafb;padding:10px 12px}.psm-det .psm-card{margin:0}
  .psm-chip{font-size:11.5px;font-weight:700;border-radius:999px;padding:2px 8px}.psm-chip.b{background:#dbeafe;color:#1e40af}.psm-chip.o{background:#fef3c7;color:#92400e}
  .psm-otbar{position:relative;display:inline-block;width:110px;height:8px;border-radius:4px;background:#eef0f4;vertical-align:middle}
  .psm-otbar i{position:absolute;left:0;top:0;bottom:0;border-radius:4px}.psm-otbar s{position:absolute;left:75%;top:-3px;bottom:-3px;width:2px;background:#ef4444}
  .psm-go{display:flex;align-items:center;gap:12px;flex-wrap:wrap;margin:0 0 12px}.psm-go>span:last-child{font-size:12.5px;color:#6b7280}
  .psm-gobtn{padding:10px 18px;font-weight:700}.psm-gobtn:not(:disabled){background:linear-gradient(135deg,#059669,#10b981);border-color:#059669;box-shadow:0 6px 16px rgba(16,185,129,.3)}
  .psm-gobtn:disabled{background:#e5e7eb;border-color:#e5e7eb;color:#6b7280;cursor:not-allowed}
  .psm-tipwrap{position:relative;display:inline-block}.psm-tipwrap::after{content:attr(data-tip);position:absolute;left:0;top:calc(100% + 8px);width:340px;z-index:30;background:#111827;color:#fff;font-size:12.5px;line-height:1.45;font-weight:500;padding:10px 12px;border-radius:10px;box-shadow:0 10px 24px rgba(0,0,0,.2);opacity:0;pointer-events:none;transform:translateY(-4px);transition:.15s}
  .psm-tipwrap::before{content:'';position:absolute;left:22px;top:calc(100% + 2px);border:6px solid transparent;border-bottom-color:#111827;opacity:0;transition:.15s;z-index:31}
  .psm-tipwrap:hover::after,.psm-tipwrap:focus::after,.psm-tipwrap:hover::before,.psm-tipwrap:focus::before{opacity:1;transform:none}
  .psm-released{display:flex;align-items:center;gap:10px;flex-wrap:wrap;background:#ecfdf5;border:1px solid #a7f3d0;color:#065f46;border-radius:10px;padding:8px 12px;margin:0 0 12px;font-size:13px}
  .psm-lock{font-weight:700;color:#065f46;background:#ecfdf5;border:1px solid #a7f3d0;border-radius:10px;padding:8px 12px}
  .psm-sec2{display:flex;align-items:baseline;gap:10px;margin:16px 0 8px}.psm-sec2 small{color:#6b7280}.psm-r.sel td{background:#eef2ff!important}
  .prc-bar{display:flex;align-items:center;gap:16px;flex-wrap:wrap;background:#fff;border:1px solid #e5e7eb;border-radius:14px;padding:12px 16px;margin-bottom:12px}
  .prc-legend{display:flex;gap:6px;flex-wrap:wrap}.prc-l{display:inline-flex;align-items:center;gap:6px;font-size:12px;color:#374151;background:#f9fafb;border:1px solid #eef0f4;border-radius:999px;padding:4px 10px}
  .prc-l i{width:10px;height:10px;border-radius:3px}.prc-l b{color:#111827}
  .prc-l.done i{background:#10b981}.prc-l.ready i{background:#6366f1}.prc-l.blocked i{background:#ef4444}.prc-l.unchecked i{background:#f59e0b}.prc-l.missing i{background:#d1d5db}.prc-l.future i{background:#f3f4f6;border:1px dashed #d1d5db}
  .prc-grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(150px,1fr));gap:10px;margin-bottom:14px}
  .prc-m{position:relative;text-align:left;border:1px solid #e5e7eb;border-radius:14px;padding:14px;background:#fff;cursor:pointer;font:inherit;display:flex;flex-direction:column;gap:2px;min-height:104px;transition:transform .12s,box-shadow .12s}
  .prc-m:hover{transform:translateY(-2px);box-shadow:0 8px 20px rgba(17,24,39,.08)}.prc-m.on{outline:3px solid #111827;outline-offset:2px}
  .prc-m small{font-size:12px;font-weight:700;color:inherit;opacity:.75}.prc-m b{font-size:16px}.prc-m em{font-style:normal;font-size:12px;opacity:.85}
  .prc-ic{position:absolute;top:10px;right:12px;width:26px;height:26px;border-radius:50%;display:grid;place-items:center;font-size:13px;font-weight:800;background:rgba(255,255,255,.6)}
  .prc-m.done{background:linear-gradient(135deg,#ecfdf5,#d1fae5);border-color:#6ee7b7;color:#065f46}
  .prc-m.ready{background:linear-gradient(135deg,#eef2ff,#e0e7ff);border-color:#a5b4fc;color:#3730a3}
  .prc-m.blocked{background:linear-gradient(135deg,#fef2f2,#fee2e2);border-color:#fca5a5;color:#991b1b}
  .prc-m.unchecked{background:linear-gradient(135deg,#fffbeb,#fef3c7);border-color:#fcd34d;color:#92400e}
  .prc-m.missing{background:#f9fafb;color:#9ca3af}.prc-m.future{background:#fff;border-style:dashed;color:#9ca3af}
  .prc-hint{color:#6b7280;text-align:center;margin:18px 0}
  .prc-det{background:#fff;border:1px solid #e5e7eb;border-top:5px solid #9ca3af;border-radius:14px;padding:16px 18px}
  .prc-det.done{border-top-color:#10b981}.prc-det.ready{border-top-color:#6366f1}.prc-det.blocked{border-top-color:#ef4444}.prc-det.unchecked{border-top-color:#f59e0b}
  .prc-dh{display:flex;align-items:flex-start;justify-content:space-between;gap:12px;flex-wrap:wrap;margin-bottom:12px}.prc-dh>div:last-child{display:flex;gap:8px}
  .prc-dh small{font-weight:700;color:#6b7280;text-transform:uppercase;font-size:11px;letter-spacing:.05em}.prc-dh h3{margin:2px 0;font-size:20px}.prc-dh p{margin:0;color:#6b7280;font-size:13px}
  .prc-none{background:#f9fafb;border-radius:10px;padding:16px;color:#6b7280}
  .prc-block{display:flex;align-items:center;gap:16px;background:#f9fafb;border-radius:12px;padding:14px}.prc-block small{display:block;color:#6b7280;margin-top:4px}
  .prc-score{font-size:34px;font-weight:800;line-height:1}.prc-score small{font-size:14px;color:#9ca3af}.prc-score.bad{color:#dc2626}.prc-score.good{color:#4f46e5}
  .prc-chips{display:flex;gap:6px;flex-wrap:wrap;margin-top:6px}.prc-chips span{background:#fee2e2;color:#991b1b;border-radius:999px;padding:2px 9px;font-size:12px}
  .prc-rel{background:#ecfdf5;border:1px solid #a7f3d0;color:#065f46;border-radius:10px;padding:9px 12px;font-size:13px;margin-bottom:10px}
  .prc-k{margin-bottom:12px}
  .prc-tools{display:flex;align-items:center;gap:10px;margin-bottom:8px;flex-wrap:wrap}.prc-tools input{flex:1;min-width:200px;border:1px solid #d1d5db;border-radius:10px;padding:8px 12px;font:inherit}
  .prc-tools span{color:#6b7280;font-size:12.5px}.prc-tw{max-height:420px;overflow:auto}.prc-tw thead th{position:sticky;top:0;z-index:1}
  .lrn-note{background:#f5f3ff;border:1px solid #ddd6fe;border-radius:12px;padding:10px 14px;margin:-4px 0 14px;font-size:13px;color:#4c1d95}
  .lrn-note summary{cursor:pointer;list-style:none}.lrn-note summary span{color:#7c3aed;font-weight:700;margin-left:6px}.lrn-note[open] summary span{display:none}
  .lrn-i{padding:6px 0;border-top:1px solid #ede9fe;margin-top:6px}.lrn-i small{color:#7c3aed;margin-left:6px}
  .lrn-list{display:grid;gap:8px}.lrn-row{display:flex;align-items:center;gap:12px;background:#faf5ff;border:1px solid #ede9fe;border-radius:12px;padding:10px 12px}
  .lrn-row>div{flex:1;min-width:0}.lrn-row small{display:block;color:#6b7280}.lrn-row .lrn-n{font-size:11px;font-weight:700;color:#7c3aed;background:#ede9fe;border-radius:999px;padding:2px 8px;white-space:nowrap}
  .lrn-how{display:grid;grid-template-columns:repeat(auto-fit,minmax(200px,1fr));gap:8px;margin-top:10px}.lrn-how div{background:#f9fafb;border-radius:10px;padding:10px;font-size:12.5px;color:#4b5563}.lrn-how b{display:block;color:#111827;margin-bottom:2px}
  .prc-m.future{background:linear-gradient(135deg,#fafaff,#f5f3ff);border-style:dashed;border-color:#c4b5fd;color:#6d28d9}.prc-m.future b{color:#6d28d9}
  .prc-l.future i{background:#ede9fe;border:1px dashed #a78bfa}.prc-det.future{border-top-color:#a78bfa}
  .fc-note{background:#f5f3ff;border:1px solid #ddd6fe;color:#4c1d95;border-radius:10px;padding:9px 12px;font-size:13px;margin-bottom:10px}
  .fc-drv{background:#f9fafb;border-radius:10px;padding:10px 12px;font-size:13px;margin-bottom:10px}.fc-drv b{display:block;margin-bottom:4px}
  .fc-bt{font-size:12.5px;color:#374151;background:#ecfdf5;border:1px solid #a7f3d0;border-radius:10px;padding:9px 12px;margin-bottom:10px}
  .fc-up{color:#b45309;font-weight:600}.fc-down{color:#047857;font-weight:600}
  .psm-note{font-size:12.5px;color:#6b7280;margin-top:10px}
  @media (max-width:760px){.psm-hero{flex-direction:column}.psm-kpis{grid-template-columns:repeat(2,1fr)}}
`;

export const FAB_CSS = `
  .fab{position:fixed;z-index:60;user-select:none}
  .fab-btn{position:relative;width:76px;height:76px;border:0;border-radius:50%;cursor:grab;padding:12px;color:#fff;
    background:radial-gradient(circle at 30% 25%,#a78bfa,#6366f1 45%,#7c3aed);box-shadow:0 10px 28px rgba(99,102,241,.45);animation:fabFloat 3s ease-in-out infinite}
  .fab.dragging .fab-btn,.fab.dragging header{cursor:grabbing}.fab.dragging .fab-btn{animation:none;transform:scale(1.06)}
  .fab-bot{width:100%;height:100%;display:block;position:relative;z-index:1;overflow:visible}
  .fab-eyes{transform-origin:32px 32px;animation:fabBlink 4s infinite}.fab-ant{animation:fabGlow 1.6s ease-in-out infinite}
  .fab-ring{position:absolute;inset:0;border-radius:50%;border:2px solid #818cf8;animation:fabPulse 2.4s ease-out infinite}.fab-ring.r2{animation-delay:1.2s}
  .fab-spark{position:absolute;top:-2px;right:2px;color:#fde047;font-size:18px;z-index:2;animation:fabSpark 2s ease-in-out infinite}
  .fab-n{position:absolute;top:2px;left:2px;z-index:2;min-width:20px;height:20px;border-radius:10px;background:#ef4444;color:#fff;font-size:11px;font-weight:800;display:grid;place-items:center;border:2px solid #fff}
  .fab-tip{position:absolute;right:86px;top:20px;white-space:nowrap;background:#111827;color:#fff;font-size:12.5px;font-weight:600;padding:7px 12px;border-radius:12px;box-shadow:0 6px 18px rgba(0,0,0,.18);animation:fabTip 7s ease-in-out infinite;pointer-events:none}
  .fab-tip::after{content:'';position:absolute;right:-6px;top:50%;margin-top:-6px;border:6px solid transparent;border-right:0;border-left-color:#111827}
  .fab.open{display:flex;flex-direction:column;background:#fff;border-radius:18px;box-shadow:0 24px 60px rgba(17,24,39,.28);overflow:hidden;border:1px solid #e5e7eb;animation:fabIn .18s ease-out}
  .fab header{display:flex;align-items:center;gap:10px;padding:12px 12px 12px 14px;background:linear-gradient(120deg,#4f46e5,#7c3aed);color:#fff;cursor:grab;flex:none}
  .fab header>div{flex:1;min-width:0}.fab header small{display:flex;align-items:center;gap:6px;font-size:11.5px;opacity:.9}.fab header small i{width:7px;height:7px;border-radius:50%;background:#4ade80;box-shadow:0 0 0 3px rgba(74,222,128,.3)}
  .fab-av{width:38px;height:38px;border-radius:12px;background:rgba(255,255,255,.18);padding:4px;flex:none;color:#fff}
  .fab-x{border:0;background:rgba(255,255,255,.15);color:#fff;width:30px;height:30px;border-radius:9px;cursor:pointer;font-size:14px}.fab-x:hover{background:rgba(255,255,255,.3)}
  .fab-msgs{flex:1;overflow-y:auto;overflow-x:hidden;padding:12px;background:#f8fafc;border:0!important;border-radius:0!important;margin:0!important}
  .fab-msgs .ag-card{font-size:13px;max-width:100%;box-sizing:border-box;overflow-wrap:anywhere}.fab-msgs .ag-card *{max-width:100%;box-sizing:border-box}.fab-msgs .ag-t{min-width:0!important;font-size:11.5px}.fab-msgs .ag-t td,.fab-msgs .ag-t th{padding:6px 5px}.fab-msgs .ag-score{flex-wrap:wrap}.fab-msgs .ag-me{font-size:13px}.fab-msgs table{font-size:12px}
  .fab-hello{text-align:center;padding:26px 12px;color:#4b5563}.fab-hello .fab-bot{width:64px;height:64px;margin:0 auto 8px;color:#6366f1;background:linear-gradient(135deg,#6366f1,#7c3aed);border-radius:20px;padding:8px;animation:fabFloat 3s ease-in-out infinite}.fab-hello p{font-size:13px;margin:6px 0 0}
  .fab-sugg{display:flex;gap:6px;flex-wrap:wrap;max-height:62px;overflow:hidden;padding:8px 10px;border-top:1px solid #eef0f4;flex:none}
  .fab-sugg button{flex:none;border:1px solid #c7d2fe;background:#eef2ff;color:#4338ca;border-radius:999px;padding:5px 11px;font:inherit;font-size:12px;font-weight:600;cursor:pointer}.fab-sugg button:hover{background:#e0e7ff}
  .fab-in{display:flex;gap:8px;padding:10px;border-top:1px solid #eef0f4;flex:none}
  .fab-in input{flex:1;border:1px solid #d1d5db;border-radius:12px;padding:10px 12px;font:inherit;font-size:13.5px;outline:none}.fab-in input:focus{border-color:#6366f1;box-shadow:0 0 0 3px rgba(99,102,241,.15)}
  .fab-in button{width:42px;border:0;border-radius:12px;background:linear-gradient(135deg,#6366f1,#7c3aed);color:#fff;font-size:16px;cursor:pointer}
  .fab button:disabled{opacity:.55;cursor:default}
  @keyframes fabFloat{0%,100%{transform:translateY(0)}50%{transform:translateY(-6px)}}
  @keyframes fabBlink{0%,92%,100%{transform:scaleY(1)}95%{transform:scaleY(.1)}}
  @keyframes fabGlow{0%,100%{opacity:1}50%{opacity:.45}}
  @keyframes fabPulse{0%{transform:scale(1);opacity:.8}100%{transform:scale(1.55);opacity:0}}
  @keyframes fabSpark{0%,100%{transform:scale(.7) rotate(0);opacity:.6}50%{transform:scale(1.15) rotate(25deg);opacity:1}}
  @keyframes fabTip{0%,8%{opacity:0;transform:translateX(8px)}14%,70%{opacity:1;transform:none}78%,100%{opacity:0;transform:translateX(8px)}}
  @keyframes fabIn{from{opacity:0;transform:scale(.96)}to{opacity:1;transform:none}}
  @media (prefers-reduced-motion:reduce){.fab *,.fab{animation:none!important}}
`;
