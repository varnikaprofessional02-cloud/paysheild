// Agent session: the agent walks the user through each finding, one at a time.
// Every decision the user confirms is saved to PayShield straight away (the finding in its guard),
// so Trust Check, the guard pages and the pay run all use the same, permanent result.
import { GUARDS, RUN, payScore, money, pendingIn } from './company.js';

const ORDER = (a, b) => (a.status === 'held' ? -1 : 0) - (b.status === 'held' ? -1 : 0) || b.impact - a.impact;

export function createSession(issues, mode = 'permanent') {
  return { mode, saved: [], id: 'AS-' + String(Math.floor(Date.now() / 1000) % 100000).padStart(5, '0'), queue: pendingIn(issues).sort(ORDER).map((i) => i.id), idx: 0, decisions: {}, phase: 'decide' };
}

/** A copy of the run's findings with this session's decisions applied. The originals are not touched. */
export function sessionIssues(issues, session) {
  return issues.map((i) => {
    const d = session && session.decisions[i.id];
    return d ? { ...i, state: d.kind === 'fix' ? 'fixed' : d.kind === 'alt' ? 'accepted' : 'excluded' } : { ...i };
  });
}

/** The options the agent offers for one finding, with what each one does to this pay run. */
export function optionsFor(i) {
  const g = GUARDS[i.guard];
  return [
    { key: 'A', kind: 'fix', label: i.fix.label, effect: i.fix.done, recommended: true },
    { key: 'B', kind: 'alt', label: i.alt.label, effect: i.alt.done + (i.status === 'held' ? ' Choose this only if you have the evidence.' : '') },
    { key: 'C', kind: 'hold', label: 'Leave out of this run', effect: `${i.name.split(' ')[0]} is not paid in this run; ${g.name} records the hold, and pay goes off-cycle once the evidence is in.` },
  ];
}

export function whyRecommended(i) {
  return `the rule is “${i.ref}”, and the history shows: ${i.hist.charAt(0).toLowerCase() + i.hist.slice(1)}.`;
}

export function decide(session, issue, kind, by = 'Varnika R.') {
  const opt = optionsFor(issue).find((o) => o.kind === kind);
  session.decisions[issue.id] = { kind, key: opt.key, label: opt.label, effect: opt.effect, by, at: new Date().toLocaleTimeString('en-SG', { hour: '2-digit', minute: '2-digit' }) };
  session.idx = session.queue.indexOf(issue.id) + 1;
  if (session.idx >= session.queue.length) session.phase = 'ready';
  return session.decisions[issue.id];
}

export const nextId = (session) => session.queue[session.idx];

/** What the final pay run will do with this session's decisions. */
export function finalRunPlan(issues, session) {
  const si = sessionIssues(issues, session), ps = payScore(si);
  const d = Object.entries(session.decisions);
  const leftOut = d.filter(([, x]) => x.kind === 'hold').length;
  const keptRight = d.filter(([, x]) => x.kind === 'fix').reduce((s, [id]) => s + (issues.find((i) => i.id === id)?.impact || 0), 0);
  const paid = RUN.headcount - leftOut - (session.decisions.lim && session.decisions.lim.kind === 'fix' ? 1 : 0);
  return {
    ps, paid, leftOut, keptRight, adjustments: d.length,
    stages: [
      ['payrun.lock', 'Lock inputs and rule versions for September 2026'],
      ['decisions.apply', `Use the ${d.length} decisions already saved to PayShield`],
      ['pay.calculate', `Calculate pay for ${paid} employees`],
      ['cpf.file', 'Prepare CPF and SDL submission'],
      ['bank.file', `Prepare the bank (GIRO) file for ${paid} employees`],
      ['payslips', `Generate ${paid} payslips`],
      ['audit.write', 'Write the pay run record'],
    ],
  };
}

export const summaryLine = (plan) => `${plan.paid} employees paid · ${plan.leftOut} left out of this run · ${money(plan.keptRight)} kept from being paid wrongly`;

/** Save a decision to PayShield itself (the finding in its guard). */
export function applyPermanent(issue, kind) {
  issue.state = kind === 'fix' ? 'fixed' : kind === 'alt' ? 'accepted' : 'excluded';
  return issue.state;
}
