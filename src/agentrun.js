// PayShield Agent, orchestrator mode: one prompt runs the whole of PayShield in the background
// (all five guards, our own model, compliance, history), returns a report with a Pay Score and
// suggested fixes, and records the run. The agent can read and propose; only people apply and approve.
import { GUARDS, HISTORY, SEPT_FACTS, RUN, payScore, money, pendingIn, GUARD_SWITCH } from './company.js';
import { RULES } from './rules.js';
import { MODEL_V1 } from './model.js';
import { subjectToken } from './explain.js';
import { getSample } from './ai.js';

const RUN_SALT = 'run-2026-09';
export const tok = (id) => subjectToken(id, RUN_SALT);

/** Is this prompt asking the agent to check the whole pay run (rather than a single question)? */
export function isRunRequest(q) {
  const t = q.toLowerCase();
  return /(check|run|review|audit|validate|scan|verify|go through)/.test(t) && /(pay ?run|payroll|pay score|whole run|september run|this run)/.test(t);
}

const ms = (a, b) => a + Math.round(Math.random() * (b - a));
const guardTool = (key, label) => ({
  tool: `guard.${key}`, label,
  run: (issues) => {
    const off = GUARD_SWITCH.off[key];
    if (off) return { count: 0, skipped: true, out: `skipped: guard turned off for ${RUN.name} by ${off.by} (${off.reason})` };
    const f = issues.filter((i) => i.guard === key && i.state === 'open');
    return { count: f.length, out: f.length ? `${f.length} finding${f.length > 1 ? 's' : ''}: ${f.map((i) => `${tok(i.id)} ${i.status}`).join(', ')}` : 'no findings' };
  },
});

/** The plan the agent follows. Every tool is read-only. */
export const PLAN = [
  { tool: 'payrun.read', label: 'Read the September pay run', run: () => ({ out: `${RUN.headcount} records · gross ${money(RUN.gross)} · pay date ${RUN.payDate}` }) },
  guardTool('people', 'Employment guard: joiners, leavers, work passes'),
  guardTool('time', 'Attendance guard: OT cap, clock proof, buddy punching'),
  { ...guardTool('bank', 'Bank Shield + Fraud Network lookup'), extra: '0 Fraud Network matches' },
  guardTool('pay', 'Pay Structure guard: bands, raises, bonus, AWS, share awards'),
  { tool: 'model.v1.score', label: 'Our own risk model on rule-cleared records', run: (issues) => { if (GUARD_SWITCH.off.pay) return { out: 'skipped: Pay Structure is off for this run' }; const f = issues.filter((i) => i.id === 'ravi' && i.state === 'open'); return { out: `${RUN.headcount} scored · ${f.length} flag${f.length === 1 ? '' : 's'} at ≥ ${MODEL_V1.threshold.toFixed(2)}` }; } },
  { ...guardTool('compliance', 'Compliance: rule library and company policies'), extra: `${RULES.length} statutory rules in force · 6 company policies` },
  { tool: 'history.compare', label: 'Compare with the last 6 pay runs', run: () => { const a = HISTORY[HISTORY.length - 1]; return { out: `gross ${pct(SEPT_FACTS.gross, a.gross)} · OT hours ${pct(SEPT_FACTS.otHours, a.otHours)} · bank changes ${a.bankChanges} → ${SEPT_FACTS.bankChanges}` }; } },
  { tool: 'payscore.compute', label: 'Compute the Pay Score', run: (issues) => { const p = payScore(issues); return { out: `${p.score}/100 · ${p.verdict}` }; } },
  { tool: 'fixes.draft', label: 'Draft fixes with references; mask names; check numbers', run: (issues) => ({ out: `${pendingIn(issues).length} fixes drafted · names masked · numbers checked` }) },
];
const pct = (a, b) => `${a >= b ? '+' : ''}${(((a - b) / b) * 100).toFixed(1)}%`;

/** Runs the plan step by step. onStep(i, step, result) is called after each tool returns. */
export async function runPayShield(issues, { onStep, delay = true, prompt = '' } = {}) {
  const started = Date.now(), steps = [];
  for (let n = 0; n < PLAN.length; n++) {
    const p = PLAN[n];
    const t = delay ? ms(220, 520) : 0;
    if (delay) await new Promise((r) => setTimeout(r, t));
    const r = p.run(issues);
    const step = { tool: p.tool, label: p.label, out: r.out + (p.extra && !r.skipped ? ` · ${p.extra}` : ''), skipped: !!r.skipped, ms: t || 1 };
    steps.push(step);
    onStep?.(n, step);
  }
  return buildReport(issues, { steps, prompt, durationMs: Date.now() - started });
}

/** The report the agent returns (names unmasked only on the admin's screen, never sent to a model). */
export function buildReport(issues, { steps = [], prompt = '', durationMs = 0 } = {}) {
  const ps = payScore(issues);
  const open = pendingIn(issues).sort((a, b) => (a.status === 'held' ? -1 : 0) - (b.status === 'held' ? -1 : 0) || b.impact - a.impact);
  const byGuard = Object.keys(GUARDS).map((k) => ({ key: k, name: GUARDS[k].name, items: open.filter((i) => i.guard === k) }));
  const last = HISTORY[HISTORY.length - 1];
  const history = [
    ['Headcount', `${last.headcount} → ${SEPT_FACTS.headcount}`, `+${SEPT_FACTS.joiners} joiners, −${SEPT_FACTS.leavers} leavers`],
    ['Gross pay', `${money(last.gross)} → ${money(SEPT_FACTS.gross)}`, pct(SEPT_FACTS.gross, last.gross)],
    ['Overtime hours', `${last.otHours.toLocaleString('en-SG')} → ${SEPT_FACTS.otHours.toLocaleString('en-SG')}`, `${pct(SEPT_FACTS.otHours, last.otHours)}: highest in 7 months`],
    ['Bank changes', `${last.bankChanges} → ${SEPT_FACTS.bankChanges}`, 'one unconfirmed, 2 days before payday'],
    ['Findings', `${Math.round(HISTORY.reduce((s, h) => s + h.findings, 0) / HISTORY.length)} a month on average → ${issues.length}`, 'above the 6-month average'],
  ];
  const summary = open.length
    ? `The ${RUN.name} run is not ready. Pay Score ${ps.score}/100: ${ps.held} record${ps.held === 1 ? '' : 's'} held and ${ps.review} to review, with ${money(ps.atRisk)} that would be paid wrongly. ${open.length} fixes are drafted below, each with its rule and the employee’s history.`
    : `The ${RUN.name} run is ready to approve. Pay Score ${ps.score}/100: every record is clear, fixed or accepted with a reason.`;
  const guardsOff = Object.entries(GUARD_SWITCH.off).map(([k, o]) => ({ key: k, name: GUARDS[k].name, ...o }));
  const offNote = guardsOff.length ? ` ${guardsOff.map((g) => g.name).join(' and ')} ${guardsOff.length > 1 ? 'are' : 'is'} turned off for this run, so ${guardsOff.length > 1 ? 'they were' : 'it was'} not checked.` : '';
  return { guardsOff, id: 'AR-2026-09-' + String(Math.floor(Date.now() / 1000) % 10000).padStart(4, '0'), prompt, steps, durationMs, ps, open, byGuard: byGuard.filter((g) => !GUARD_SWITCH.off[g.key]), history, summary: summary + offNote,
    ruleVersions: RULES.map((r) => `${r.code} ${r.version}`), at: new Date() };
}

/** Facts the language model may see: tokens and numbers only. */
export function maskedFacts(report) {
  return { run: RUN.name, payScore: report.ps.score, verdict: report.ps.verdict, held: report.ps.held, review: report.ps.review, atRisk: Math.round(report.ps.atRisk),
    findings: report.open.map((i) => ({ who: tok(i.id), guard: i.guard, status: i.status, amount: Math.round(i.impact) })) };
}

/** Optional: live AI rewrites the summary from masked facts; any number not in the facts → keep the verified text. */
export async function aiSummary(report) {
  const sample = await getSample();
  if (!sample) return null;
  const facts = maskedFacts(report);
  const prompt = `You are PayShield Agent. In 2 short sentences for a payroll admin, summarise this pay run check. Use only these facts; do not add numbers. Refer to people only by their token.\n${JSON.stringify(facts)}`;
  try {
    const { text: raw } = await sample(prompt, { modelTier: 'quick', cache: false });
    const text = String(raw || '').trim();
    const allowed = new Set(JSON.stringify(facts).match(/\d[\d,.]*/g).map((x) => x.replace(/,/g, '')));
    const ok = (text.match(/\d[\d,.]*/g) || []).every((x) => allowed.has(x.replace(/,/g, '').replace(/\.$/, '')));
    return ok && text ? text : null;
  } catch { return null; }
}
