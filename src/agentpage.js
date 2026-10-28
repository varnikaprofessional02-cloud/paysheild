// PayShield Agent page (orchestrator + Q&A) and Pay run records page.
import { ICON } from './chrome.js';
import { GUARDS, HISTORY, RUN, money, pendingIn, payScore, GUARD_SWITCH } from './company.js';
import { PLAN, isRunRequest, runPayShield, buildReport, aiSummary, tok } from './agentrun.js';
import { askAgent } from './agent.js';
import { getSample } from './ai.js';
import { createSession, sessionIssues, optionsFor, whyRecommended, decide, nextId, finalRunPlan, summaryLine, applyPermanent } from './agentsession.js';

const esc = (s) => String(s ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
export const RUN_PROMPT = 'Check the September pay run, suggest fixes as per compliance and previous history, and give the pay score';
const CHIPS = [RUN_PROMPT, 'Why is Daniel held?', 'Is CPF due on share awards?', 'How do I prorate a new joiner?'];
const APPROVER = { name: 'Grace Lim', role: 'HR Director (approver)' };
const st = (s) => s === 'held' ? '<span class="tag t-r">Held</span>' : '<span class="tag t-o">Review</span>';
const now = () => new Date().toLocaleTimeString('en-SG', { hour: '2-digit', minute: '2-digit' });

export function initAgentState(S) {
  S.agent = { msgs: [], busy: false, q: '', live: null };
  S.records = HISTORY.map((h, n) => ({ id: `PR-2026-0${n + 3}`, kind: 'payrun', period: h.run, by: h.by, viaAgent: false, approver: h.approver, findings: h.findings, scoreBefore: null, scoreAfter: h.score, headcount: h.headcount, gross: h.gross, status: 'Paid' })).reverse();
  getSample().then((s) => { S.agent.live = !!s; });
}

const scoreRing = (v, ok) => { const r = 30, c = 2 * Math.PI * r; return `<svg width="76" height="76" viewBox="0 0 76 76" role="img" aria-label="Pay Score ${v}"><circle cx="38" cy="38" r="${r}" fill="none" stroke="var(--line)" stroke-width="8"/><circle cx="38" cy="38" r="${r}" fill="none" stroke="${ok ? 'var(--good)' : v < 80 ? 'var(--bad)' : '#f59e0b'}" stroke-width="8" stroke-linecap="round" stroke-dasharray="${(c * v / 100).toFixed(1)} ${c.toFixed(1)}" transform="rotate(-90 38 38)"/><text x="38" y="44" text-anchor="middle" font-size="19" font-weight="800" fill="var(--ink)">${v}</text></svg>`; };

function stepsHtml(m) {
  return `<div class="ar-steps">${PLAN.map((p, n) => { const s = m.steps[n]; const state = s ? (s.skipped ? 'skip' : 'done') : n === m.steps.length && m.running ? 'run' : 'wait';
    return `<div class="ar-step ${state}"><span class="ar-ic">${state === 'done' ? '✓' : state === 'skip' ? '–' : state === 'run' ? '' : n + 1}</span><div style="min-width:0"><b>${esc(p.label)}</b> <code>${p.tool}</code>${s ? `<div class="small muted">${esc(s.out)}</div>` : ''}</div></div>`; }).join('')}</div>`;
}

function reportHtml(m, S) {
  const r = m.report, ps = r.ps, ready = !r.open.length;
  const guards = r.byGuard.filter((g) => g.items.length).map((g) => `<tr class="ar-g"><td colspan="5"><b>${esc(g.name)}</b> · ${g.items.length} finding${g.items.length > 1 ? 's' : ''}</td></tr>` + g.items.map((i) => `<tr>
     <td><b>${esc(i.name)}</b><div class="small muted">${tok(i.id)} · ${esc(i.dept)}</div></td>
     <td class="small">${esc(i.title)}<div style="margin-top:3px">${st(i.status)} <span class="muted">Trust ${i.score}</span></div></td>
     <td class="small"><span class="ar-lbl">Rule</span>${esc(i.ref)}<br><span class="ar-lbl">History</span>${esc(i.hist)}</td>
     <td class="small"><b>${esc(i.fix.label)}</b><div><button class="linkbtn" data-act="goIssue:${i.id}">Open in ${GUARDS[i.guard].short} →</button></div></td><td style="text-align:right;white-space:nowrap"><b>${money(i.impact)}</b></td></tr>`).join('')).join('');
  const flow = m.flow || 'report';
  let actions = '';
  if (!ready && flow === 'report') actions = `<div class="ar-actions"><button class="btn p" data-act="agWalk">Go through the ${r.open.length} findings with me, one by one</button></div>
      <div class="ar-perm-note">${ICON.circleCheck}<span>Each decision you confirm is <b>saved to PayShield</b> in its guard straight away, so Trust Check, the guard pages and this pay run all use the same result.</span></div>`;
  if (flow === 'walking') actions = '<div class="small muted">Going through the findings below…</div>';
  return `<div class="ar-report">
    <div class="ar-score">${scoreRing(ps.score, ready)}<div><div class="eyebrow">Pay Score</div><b style="font-size:18px">${ps.score}/100 · ${ps.verdict}</b>
      <div class="small muted">Records ready ${Math.round(ps.recordsPart * 100)}% · pay value safe ${Math.round(ps.valuePart * 100)}%${ps.cap < 100 && ps.raw > ps.score ? ` · ${ps.raw} before caps: ${ps.held ? 'held records cap it at 79' : 'open reviews cap it at 89'}` : ''}</div></div></div>
    <p class="ar-sum">${esc(m.aiText || r.summary)} <span class="tag ${m.aiText ? 't-b' : 't-n'}">${m.aiText ? 'Live AI · numbers checked' : 'Verified text'}</span></p>
    ${r.open.length ? `<div class="tblwrap"><table class="g ar-t" style="min-width:0"><thead><tr><th>Employee</th><th>What was found</th><th>Compliance and history</th><th>Suggested fix</th><th style="text-align:right">At risk</th></tr></thead><tbody>${guards}</tbody></table></div>` : ''}
    <details class="ar-hist" ${m.histOpen ? 'open' : ''}><summary><b>Compared with the last 6 pay runs</b></summary><table class="g" style="min-width:0;margin-top:6px"><tbody>${r.history.map(([a, b, c]) => `<tr><td class="small"><b>${a}</b></td><td class="small">${b}</td><td class="small muted">${c}</td></tr>`).join('')}</tbody></table></details>
    <div class="small muted" style="margin:8px 0">Run ${r.id} · ${PLAN.length} read-only tools · rule versions ${esc(r.ruleVersions.slice(0, 2).join(', '))} +${r.ruleVersions.length - 2} more · recorded in <button class="linkbtn" data-act="page:records">Pay run records</button></div>
    ${actions}</div>`;
}

function msgHtml(m, S) {
  if (m.me) return `<div class="msg me"><div class="bubble">${esc(m.text)}</div></div>`;
  if (m.kind === 'run') return `<div class="msg"><div class="bubble ar-bubble"><div class="ar-head">${ICON.bot}<b>PayShield Agent</b><span class="small muted">${m.running ? 'Running PayShield…' : `Checked at ${m.at}`}</span></div>${m.running ? stepsHtml(m) : `<details class="ar-tools"><summary><b style="color:var(--good)">✓</b> PayShield ran ${m.steps.length} read-only tools · names masked · numbers checked <span class="muted">(show)</span></summary>${stepsHtml(m)}</details>`}${m.report ? reportHtml(m, S) : ''}</div></div>`;
  if (m.kind === 'note') return `<div class="msg"><div class="bubble ar-note">${m.html}</div></div>`;
  if (m.kind === 'q') return qHtml(m, S);
  if (m.kind === 'summary') return summaryHtml(m, S);
  if (m.kind === 'final') return finalHtml(m, S);
  const tag = m.source === 'none' ? '<span class="tag t-n">No verified answer</span>' : m.source === 'ai' ? '<span class="tag t-b">Live AI</span>' : m.source === 'tool' ? '<span class="tag t-b">Validators tool</span>' : '<span class="tag t-n">Verified answer</span>';
  return `<div class="msg"><div class="bubble">${m.busy ? '<span class="muted">Thinking…</span>' : esc(m.text)}${m.busy ? '' : `<div class="bubble-meta">${tag}${m.source !== 'none' ? '<span class="small" style="color:var(--good)">✓ numbers checked</span>' : ''}${(m.hits || []).slice(0, 1).map((h) => `<span class="small muted">Source: ${esc(h.entry.src)}</span>`).join('')}</div>`}</div></div>`;
}

function qHtml(m, S) {
  const i = S.issues.find((x) => x.id === m.id), sess = S.agent.session, d = sess.decisions[i.id], g = GUARDS[i.guard];
  const opts = optionsFor(i);
  return `<div class="msg"><div class="bubble ar-bubble ar-q ${d ? 'answered' : ''}"><div class="ar-head">${ICON.bot}<b>PayShield Agent</b><span class="small muted">Finding ${m.n} of ${m.of} · ${g.name}</span></div>
    <div class="ar-q-title">${st(i.status)} <b>${esc(i.name)}</b> <span class="muted small">${esc(i.dept)} · Trust ${i.score}</span></div>
    <p class="ar-q-text">${esc(i.title)}.</p>
    ${d ? `<div class="ar-q-done">✓ You chose <b>${d.key} · ${esc(d.label)}</b> at ${d.at}. ${esc(d.effect)} <span class="tag t-g">Saved to ${g.name}</span></div>` : `
    <div class="ar-facts"><div><span class="ar-lbl">Checked</span>${esc(i.param[0])}: <b>${esc(i.param[1])}</b> · rule: ${esc(i.param[2])}</div><div><span class="ar-lbl">Rule</span>${esc(i.ref)}</div><div><span class="ar-lbl">History</span>${esc(i.hist)}</div><div><span class="ar-lbl">At risk</span><b>${money(i.impact, i.impact % 1 ? 2 : 0)}</b> if paid as it is</div></div>
    <p class="ar-q-ask"><b>How do you want to fix this?</b> I recommend <b>A</b>, because ${esc(whyRecommended(i))}</p>
    <div class="ar-opts">${opts.map((o) => `<button class="ar-opt ${o.recommended ? 'rec' : ''}" data-act="agPick:${i.id}|${o.kind}"><span class="ar-key">${o.key}</span><span><b>${esc(o.label)}</b>${o.recommended ? ' <span class="tag t-b">Recommended</span>' : ''}<span class="small muted">${esc(o.effect)}</span></span></button>`).join('')}</div>
    <div class="small muted">Your choice is saved to ${g.name} in PayShield. You can also type A, B or C, or ask me a question first.</div>`}
  </div></div>`;
}
function summaryHtml(m, S) {
  const sess = S.agent.session, plan = finalRunPlan(S.issues, sess), ds = sess.queue.map((id) => [S.issues.find((i) => i.id === id), sess.decisions[id]]);
  const cnt = (k) => ds.filter(([, d]) => d.kind === k).length;
  let act = '';
  if (m.flow === 'ready') act = `<div class="ar-actions"><button class="btn p" data-act="agFinal">Run the ${RUN.name} pay run</button></div>`;
  if (m.flow === 'approval') act = `<div class="card ar-approve"><div><span class="tag t-n">Approver view</span> <b>${APPROVER.name}</b> · ${APPROVER.role}</div><p class="small" style="margin:6px 0">${RUN.name}: ${summaryLine(plan)} · ${plan.adjustments} decisions by Varnika R., saved to PayShield · Pay Score ${plan.ps.score}/100.</p><button class="btn p" data-act="agApprove">Approve and run</button></div>`;
  return `<div class="msg"><div class="bubble ar-bubble"><div class="ar-head">${ICON.bot}<b>PayShield Agent</b><span class="small muted">All findings decided</span></div>
    <div class="ar-score">${scoreRing(plan.ps.score, !plan.ps.open)}<div><div class="eyebrow">Pay Score</div><b style="font-size:18px">${plan.ps.score}/100 · ${plan.ps.verdict}</b><div class="small muted">All ${plan.adjustments} decisions saved to PayShield · Trust Check ${payScore(S.issues).score}/100</div></div></div>
    <p class="ar-sum" style="margin:10px 0">${cnt('fix')} fixed as recommended, ${cnt('alt')} accepted with a reason, ${cnt('hold')} left out of this run. ${summaryLine(plan)}.</p>
    <div class="tblwrap"><table class="g" style="min-width:0"><thead><tr><th>Employee</th><th>Guard</th><th>Your decision</th><th>Saved to</th></tr></thead><tbody>${ds.map(([i, d]) => `<tr><td class="small"><b>${esc(i.name)}</b></td><td class="small">${GUARDS[i.guard].short}</td><td class="small"><b>${d.key}</b> · ${esc(d.label)}</td><td class="small"><span class="tag t-g">${GUARDS[i.guard].name}</span></td></tr>`).join('')}</tbody></table></div>
    <div class="ar-done" style="margin-top:10px">✓ PayShield is up to date: ${sess.saved.length} decisions saved to their guards. Trust Check and the guard pages already show them.</div>
    ${act}</div></div>`;
}
function finalHtml(m, S) {
  const plan = m.plan;
  return `<div class="msg"><div class="bubble ar-bubble"><div class="ar-head">${ICON.bot}<b>PayShield Agent</b><span class="small muted">${m.done ? `Pay run completed at ${m.at}` : 'Running the pay run…'}</span></div>
    <div class="ar-steps">${plan.stages.map(([t, l], n) => { const state = n < m.stage ? 'done' : n === m.stage && !m.done ? 'run' : m.done ? 'done' : 'wait';
      return `<div class="ar-step ${state}"><span class="ar-ic">${state === 'done' ? '✓' : state === 'run' ? '' : n + 1}</span><div><b>${esc(l)}</b> <code>${t}</code></div></div>`; }).join('')}</div>
    ${m.done ? `<div class="ar-done"><b>✓ ${RUN.name} pay run completed.</b> ${summaryLine(plan)}. Approved by ${APPROVER.name}. Logged as <b>PR-2026-09</b> with every question, decision and approval. <button class="linkbtn" data-act="page:records">Open the audit record →</button></div>
      <div class="ar-done" style="background:var(--surface2);border-color:var(--line)">PayShield already has all ${plan.adjustments} decisions, so nothing is left to fix for September. <button class="linkbtn" data-act="page:home">Open Trust Check →</button></div>}` : ''}</div></div>`;
}
export function agentBody(S) {
  const a = S.agent, last = S.records.find((r) => r.viaAgent);
  return `<div class="card ps-ghead"><span class="ps-gic">${ICON.bot}</span><div style="flex:1;min-width:0"><div class="eyebrow">PayShield Agent</div><h3>Ask, or let the agent check the whole pay run</h3>
    <p class="muted">One prompt runs every guard, our own model, compliance and the last 6 runs in the background, then returns a Pay Score. It then asks you about each finding, with the rule, history and options, and runs the pay run once all are decided. Every decision you confirm is saved to PayShield; every run is recorded.</p>
    <div class="ps-covers"><span class="chip">Read-only tools</span><span class="chip">Names masked for the AI</span><span class="chip">Numbers checked</span><span class="chip">Decisions saved to PayShield</span><span class="chip">Two-person approval</span><span class="chip">Every run recorded</span></div></div>
    <div class="ps-gside"><span class="tag ${a.live ? 't-b' : 't-n'}">${a.live ? 'Live AI' : 'Offline: verified text'}</span><div class="ps-demos"><button class="btn sm" data-act="go:agent">▶ Q&A training and tests</button></div></div></div>
  <div class="ps-cols"><div class="ps-main"><div class="card agent-chat">
    <div class="ag-msgs" id="agMsgs">${a.msgs.length ? a.msgs.map((m) => msgHtml(m, S)).join('') : `<div class="agent-empty" style="padding:30px 10px"><b>Try the full check</b><span class="small muted">Click the first suggestion. The agent runs ${PLAN.length} tools and reports back.</span></div>`}</div>
    <div class="agent-chips">${CHIPS.map((c, n) => `<button class="chip-btn ${n === 0 ? 'chip-main' : ''}" data-act="agChip:${n}" ${a.busy ? 'disabled' : ''}>${n === 0 ? '▶ ' : ''}${esc(c)}</button>`).join('')}</div>
    <div class="agent-input"><input id="agQ" placeholder="Ask PayShield Agent, e.g. “check this pay run”" value="${esc(a.q)}" ${a.busy ? 'disabled' : ''} aria-label="Ask PayShield Agent"><button class="btn p" data-act="agSend" ${a.busy ? 'disabled' : ''}>Send</button></div></div></div>
   <div class="ps-side">
    <div class="card" style="padding:14px 16px"><b>What the agent runs</b><div class="small muted" style="margin:2px 0 6px">All read-only. None can change pay.</div>${PLAN.map((p) => `<div class="ar-tool"><code>${p.tool}</code><span class="small">${esc(p.label)}</span></div>`).join('')}</div>
    <div class="card" style="padding:14px 16px"><b>Guardrails</b><ul class="agent-ul small"><li>Checks only read; only a decision you confirm, one by one, is saved to PayShield</li><li>Cannot release a hold, approve or pay; approval needs a second person</li><li>Only masked tokens and numbers reach the language model</li><li>Any number not in the tool results is rejected</li><li>Text inside payroll data is treated as data, never as instructions</li><li>Every prompt, tool call, fix and approval is recorded</li></ul></div>
    <div class="card" style="padding:14px 16px"><b>Last agent run</b><p class="small muted" style="margin:4px 0 0">${last ? `${last.id} · ${last.period} · Pay Score ${last.scoreBefore} → ${last.scoreAfter ?? '—'} · ${last.status}` : 'None yet in this session'}</p><button class="linkbtn" data-act="page:records">Open Pay run records →</button></div>
   </div></div>`;
}

export function recordsBody(S) {
  const rows = S.records.map((r) => r.kind === 'config' ? `<tr class="ar-cfg"><td><b>${r.id}</b><div class="small muted">${r.period}</div></td><td class="small">${esc(r.by)}</td><td class="small" colspan="3"><b>${esc(r.guard)} turned ${r.action}</b>${r.action === 'off' ? ` · ${r.scope === 'run' ? 'this pay run only' : 'until turned back on'} · “${esc(r.reason)}”` : ''} · ${r.at}</td><td class="small">${esc(r.approver || '—')}</td><td><span class="tag ${r.action === 'off' ? 't-o' : 't-g'}">Guard ${r.action}</span></td></tr>` : `<tr class="${r.viaAgent ? 'ar-row' : ''}"><td><b>${r.id}</b><div class="small muted">${r.period}</div></td>
    <td class="small">${r.viaAgent ? `<span class="tag t-b">${ICON.bot} PayShield Agent</span><div class="muted" style="margin-top:3px">for ${esc(r.by)}</div>` : esc(r.by)}</td>
    <td class="small">${r.kind === 'check' ? 'Check only' : `${r.headcount} · ${money(r.gross)}`}</td><td class="small">${r.findings}</td>
    <td class="small">${r.scoreBefore != null ? `${r.scoreBefore} → ` : ''}<b>${r.scoreAfter ?? '—'}</b></td><td class="small">${esc(r.approver || '—')}</td>
    <td>${r.status === 'Paid' || r.status === 'Approved' ? `<span class="tag t-g">${r.status}</span>` : `<span class="tag t-n">${r.status}</span>`}</td></tr>
    ${r.trace ? `<tr class="ar-trace"><td colspan="7"><details ${r.open ? 'open' : ''}><summary class="small"><b>Audit trail</b> · prompt, ${r.trace.length} tool calls${r.decisions ? `, ${r.decisions.length} decisions saved to PayShield` : ''}${r.fixes ? ', fixes' : ''}${r.approver ? ', approval' : ''}</summary>
      <div class="ar-audit"><div><span class="ar-lbl">Prompt</span>“${esc(r.prompt)}” · ${esc(r.by)} · ${r.at}</div>
      ${r.trace.map((t) => `<div><code>${t.tool}</code> · ${esc(t.out)}</div>`).join('')}
      ${r.decisions ? `<div><span class="ar-lbl">Decisions</span>${r.decisions.length}, each saved to its guard in PayShield when it was made</div>${r.decisions.map((d, n) => `<div style="padding-left:12px">${n + 1}. ${esc(d.name)} · ${esc(d.guard)} · asked: ${esc(d.title)} → chose <b>${d.key}</b> ${esc(d.label)} · ${esc(d.by)} ${d.at}</div>`).join('')}` : ''}
      ${r.fixes ? `<div><span class="ar-lbl">Fixes</span>${r.fixes} suggested fixes applied by ${esc(r.by)} after confirming</div>` : ''}
      ${r.approver ? `<div><span class="ar-lbl">Approval</span>${esc(r.approver)} approved at ${r.approvedAt}</div>` : ''}
      ${r.guardsOff && r.guardsOff.length ? `<div><span class="ar-lbl">Guards off</span>${esc(r.guardsOff.join(' · '))}: not checked in this run</div>` : ''}
      <div><span class="ar-lbl">Rule versions</span>${esc(r.ruleVersions.join(' · '))}</div></div></details></td></tr>` : ''}`).join('');
  return `<div class="card ps-ghead"><span class="ps-gic">${ICON.receipt}</span><div style="flex:1"><div class="eyebrow">Audit</div><h3>Pay run records</h3><p class="muted">Every pay run, every agent check and every guard switched on or off, with who ran it, what PayShield found, the Pay Score, the approver and the rule versions used. Records cannot be edited.</p></div></div>
  <div class="card" style="padding:0;overflow:hidden"><div class="tblwrap"><table class="g" style="min-width:0"><thead><tr><th>Run</th><th>Run by</th><th>Records · gross</th><th>Findings</th><th>Pay Score</th><th>Approver</th><th>Status</th></tr></thead><tbody>${rows}</tbody></table></div></div>`;
}

/** Actions for the agent page. h = { S, render } */
export function agentActions(h) {
  const { S, render } = h;
  const lastRun = () => [...S.agent.msgs].reverse().find((m) => m.kind === 'run' && m.report);
  async function fullCheck(text, { recheck = false } = {}) {
    const a = S.agent; a.busy = true;
    if (!recheck) a.msgs.push({ me: true, text });
    const m = { kind: 'run', running: true, steps: [], prompt: text };
    a.msgs.push(m); render();
    const report = await runPayShield(S.issues, { prompt: text, delay: !h.reduce, onStep: (n, s) => { m.steps.push(s); render(); } });
    m.report = report; m.running = false; m.at = now(); a.busy = false;
    S.records.unshift({ id: report.id, kind: 'check', period: RUN.name, by: 'Varnika R.', viaAgent: true, findings: report.open.length, scoreBefore: report.ps.score, scoreAfter: null, status: recheck ? 'Re-check' : 'Checked', prompt: text, trace: report.steps, ruleVersions: report.ruleVersions, at: m.at });
    render();
    aiSummary(report).then((t) => { if (t) { m.aiText = t; render(); } });
  }
  async function ask(text) {
    const a = S.agent; a.busy = true; a.msgs.push({ me: true, text }); const m = { busy: true }; a.msgs.push(m); render();
    try { const r = await askAgent(text); Object.assign(m, { busy: false, text: r.text, source: r.source, hits: r.hits }); }
    catch { Object.assign(m, { busy: false, text: 'Something went wrong. Please try again.', source: 'none' }); }
    a.busy = false; render();
  }
  const summaryMsg = () => [...S.agent.msgs].reverse().find((m) => m.kind === 'summary');
  function askNext() {
    const sess = S.agent.session, id = nextId(sess);
    if (!id) { S.agent.msgs.push({ kind: 'summary', flow: 'ready' }); render(); return; }
    S.agent.msgs.push({ kind: 'q', id, n: sess.idx + 1, of: sess.queue.length }); render();
  }
  function savePermanent(i, kind, label, effect, via) {
    const sess = S.agent.session, before = payScore(S.issues).score;
    applyPermanent(i, kind);
    const entry = { id: i.id, name: i.name, guard: GUARDS[i.guard].short, label, by: 'Varnika R.', at: now(), via };
    sess.saved.push(entry);
    return { before, after: payScore(S.issues).score };
  }
  function pick(id, kind) {
    const sess = S.agent.session; if (!sess || sess.decisions[id] || nextId(sess) !== id) return;
    const i = S.issues.find((x) => x.id === id), before = payScore(sessionIssues(S.issues, sess)).score;
    const d = decide(sess, i, kind);
    let saved = null;
    saved = savePermanent(i, kind, d.label, d.effect, 'agent session');
    const after = payScore(sessionIssues(S.issues, sess)).score;
    S.agent.msgs.push({ me: true, text: `${d.key} · ${d.label}` });
    S.agent.msgs.push({ kind: 'note', html: `✓ Saved to <b>${GUARDS[i.guard].name}</b>: ${esc(d.effect)} Trust Check ${saved.before} → <b>${saved.after}</b>.${nextId(sess) ? ` Next: ${sess.idx + 1} of ${sess.queue.length}.` : ''}` });
    askNext();
  }
  const send = (text) => {
    text = (text || '').trim(); if (!text || S.agent.busy) return; S.agent.q = '';
    const sess = S.agent.session, m = text.match(/^\s*(?:option\s*)?([abc])\b/i);
    if (sess && sess.phase === 'decide' && m) { const kind = { a: 'fix', b: 'alt', c: 'hold' }[m[1].toLowerCase()]; return pick(nextId(sess), kind); }
    (isRunRequest(text) ? fullCheck : ask)(text);
  };
  return {
    agChip(n) { send(CHIPS[+n]); },
    agSend() { send(document.getElementById('agQ')?.value); },
    agWalk() {
      const m = lastRun(); if (!m) return; m.flow = 'walking';
      S.agent.session = createSession(S.issues);
      S.agent.msgs.push({ kind: 'note', html: `OK. I’ll take the ${S.agent.session.queue.length} findings one at a time, held ones first. For each I’ll show what I found, the rule, the employee’s history and the options. <b>Each decision you confirm is saved to PayShield.</b>` });
      askNext();
    },
    agPick(arg) { const [id, kind] = String(arg).split('|'); pick(id, kind); },
    agFinal() { const m = summaryMsg(); if (!m) return; m.flow = 'approval'; S.agent.msgs.push({ me: true, text: `Run the ${RUN.name} pay run` }); S.agent.msgs.push({ kind: 'note', html: `Sent to <b>${APPROVER.name}</b> for approval. A pay run always needs a second person; I can’t release pay on my own.` }); render(); },
    agApprove() {
      const m = summaryMsg(); if (!m) return; m.flow = 'approved';
      const sess = S.agent.session, plan = finalRunPlan(S.issues, sess);
      const f = { kind: 'final', plan, stage: 0, done: false }; S.agent.msgs.push(f); S.agent.busy = true; render();
      const tick = () => {
        f.stage++;
        if (f.stage >= plan.stages.length) {
          f.done = true; f.at = now(); S.agent.busy = false; sess.phase = 'done';
          const first = S.records.filter((r) => r.viaAgent && r.kind === 'check').pop();
          S.agentPaid = { id: 'PR-2026-09', approver: APPROVER.name, decisions: plan.adjustments, at: f.at };
          S.records.unshift({ id: 'PR-2026-09', kind: 'payrun', period: RUN.name, by: 'Varnika R.', viaAgent: true, approver: APPROVER.name, approvedAt: f.at, findings: sess.queue.length,
            scoreBefore: first ? first.scoreBefore : null, scoreAfter: plan.ps.score, headcount: plan.paid, gross: RUN.gross, status: 'Paid', prompt: first ? first.prompt : RUN_PROMPT,
            trace: [...(first ? first.trace : []), ...plan.stages.map(([t, l]) => ({ tool: t, out: l }))], ruleVersions: first ? first.ruleVersions : [], at: first ? first.at : f.at, open: true, permanent: sess.saved.slice(), guardsOff: Object.entries(GUARD_SWITCH.off).map(([k, o]) => `${GUARDS[k].name} (${o.reason})`),
            decisions: sess.queue.map((id) => { const i = S.issues.find((x) => x.id === id), d = sess.decisions[id]; return { name: i.name, guard: GUARDS[i.guard].short, title: i.title, ...d }; }) });
        }
        render(); if (!f.done) setTimeout(tick, h.reduce ? 0 : 420);
      };
      setTimeout(tick, h.reduce ? 0 : 420);
    },
    agConfirm(v) { const m = lastRun(); if (m) { m.confirm = v; render(); } },
    agQ(v) { S.agent.q = v; },
    send,
  };
}
