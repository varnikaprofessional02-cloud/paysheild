// PayShield product pages: Home (pay run readiness), the five guard pages and Proof.
// Scenarios (step-by-step stories) are launched from these pages with "Demo this".
import { ICON, statCard } from './chrome.js';
import { GUARDS, POLICIES, RUN, AWS_PREVIEW, money, pendingIn, runSummary, payScore, GUARD_SWITCH, HIGH_RISK_GUARDS, isRemoval } from './company.js';
import { RULES } from './rules.js';
import { DEFAULT_CONFIG } from './scoring.js';

const esc = (s) => String(s ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
const st = (s) => s === 'held' ? '<span class="tag t-r">Held</span>' : s === 'review' ? '<span class="tag t-o">Review</span>' : '<span class="tag t-g">Clear</span>';
const pv = (v) => `<span class="pv">${esc(v)}</span>`;
const SCN = {
  preflight: 'Pre-flight check: 5 employees', payrun: 'Full pay run: 219 records', bank: 'Bank-change attack', network: 'Fraud Network', attend: 'Buddy punching & missed clock-out',
  rules: 'Rule Watch: new CPF ceiling', model: 'Train our own model', validators: 'All validators & parameters', compare: 'Before / after', proof: 'Test run: 50 companies', csv: 'Check your own file', agent: 'Ask PayShield Agent', learn: 'Learns from you', ask: 'AI guardrails',
};
const demoBtn = (k, primary) => `<button class="btn ${primary ? 'p' : ''} sm" data-act="go:${k}">▶ ${SCN[k]}</button>`;

function issueCard(i, showGuard, focus, sess) {
  const g = GUARDS[i.guard];
  const open = i.state === 'open', rm = !open && isRemoval(i);
  return `<div class="card ps-issue ${open ? 'is-' + i.status : rm ? 'is-removed' : 'is-done'} ${focus === i.id ? 'ps-focus' : ''}" id="iss-${i.id}">
    <div class="ps-ih"><span class="pf-av">${i.ini}</span><div style="min-width:0"><b>${esc(i.name)}</b><div class="small muted">${esc(i.dept)}${showGuard ? ` · ${g.name}` : ''}</div></div>
      <div class="ps-ir">${open ? `${st(i.status)}<span class="small muted">Trust ${i.score}</span>` : `<span class="tag ${rm ? 't-o' : 't-g'}">${rm ? (i.state === 'excluded' ? '⚠ Left out of run' : '⚠ Removed from run') : i.state === 'fixed' ? 'Fixed' : 'Accepted'}</span>`}</div></div>
    <div class="ps-it">${esc(i.title)}</div>
    ${sess && sess.decisions[i.id] && !open ? `<div class="ps-sess">${ICON.bot}<span>Decided with PayShield Agent: <b>${sess.decisions[i.id].key} · ${esc(sess.decisions[i.id].label)}</b> by ${esc(sess.decisions[i.id].by)} at ${sess.decisions[i.id].at}.</span></div>` : ''}
    <div class="ps-ip"><span class="small muted">${esc(i.param[0])}</span> ${pv(i.param[1])} <span class="small muted">rule: ${esc(i.param[2])}</span><span class="ps-imp">${open ? 'At risk' : rm ? 'Not paid this run' : 'Kept right'} <b>${money(i.impact, i.impact % 1 ? 2 : 0)}</b></span></div>
    ${open ? `<div class="ps-ia"><button class="btn p sm" data-act="fix:${i.id}">${esc(i.fix.label)}</button><button class="btn sm" data-act="alt:${i.id}">${esc(i.alt.label)}</button>${i.demo ? `<button class="linkbtn" data-act="go:${i.demo}">▶ See how it was caught</button>` : ''}</div>`
      : `<div class="ps-done ${rm ? 'warn' : ''}">${rm ? '⚠' : '✓'} ${esc(i.state === 'fixed' ? i.fix.done : i.state === 'excluded' ? `Left out of the ${RUN.name} run; pay off-cycle once the evidence is in.` : i.alt.done)} <button class="linkbtn" data-act="undo:${i.id}">Undo</button></div>`}
  </div>`;
}

export const OFF_REASONS = ['Company does not use this check', 'Handled in another system', 'Not applicable to these employees this month', 'Other (written note)'];
const SKIPS = { people: 'joiner proration, leaver, work pass and employment-change checks', time: 'overtime cap, clock-proof, buddy-punch and OT pre-approval checks', bank: 'bank-change, second-channel, shared-account and Fraud Network checks', pay: 'grade band, increment, bonus, AWS, share award and model checks', compliance: 'statutory rule and company policy checks' };
function guardSwitch(key, S) {
  const off = GUARD_SWITCH.off[key], d = S.offDraft && S.offDraft.key === key ? S.offDraft : null, g = GUARDS[key], high = HIGH_RISK_GUARDS.includes(key);
  const sw = `<button type="button" class="ps-switch ${off ? '' : 'on'}" role="switch" aria-checked="${!off}" data-act="guardToggle:${key}" ${d ? 'disabled' : ''}><i></i><span>${off ? `Off for ${RUN.name}` : `On for ${RUN.name}`}</span></button>`;
  return sw;
}
function offPanel(key, S) {
  const d = S.offDraft && S.offDraft.key === key ? S.offDraft : null, g = GUARDS[key], high = HIGH_RISK_GUARDS.includes(key);
  if (!d) return '';
  if (d.stage === 'approval') return `<div class="card ps-offpanel"><div><span class="tag t-n">Approver view</span> <b>Grace Lim</b> · HR Director</div><p class="small" style="margin:6px 0">Varnika R. asks to turn off <b>${g.name}</b> for ${d.scope === 'run' ? RUN.name : 'every run until turned back on'}: “${esc(d.reason)}”. ${SKIPS[key].charAt(0).toUpperCase() + SKIPS[key].slice(1)} would not run.</p><div class="ar-actions"><button class="btn p sm" data-act="guardOffApprove">Approve</button><button class="btn sm" data-act="guardOffCancel">Reject</button></div></div>`;
  return `<div class="card ps-offpanel"><b>Turn off ${g.name}?</b><p class="small" style="margin:4px 0 8px">While it is off, PayShield skips ${SKIPS[key]} for this company. Nothing in this guard is raised, scored or asked about, even if something is wrong.</p>
    ${high ? `<div class="ar-session-note" style="margin-bottom:8px">${ICON.alert}<span><b>High risk.</b> ${key === 'bank' ? 'Salaries could go to a changed or fraudulent account without a check.' : 'CPF, MOM and IRAS errors would not be caught; the company stays liable for them.'} A second person must approve.</span></div>` : ''}
    <div class="small" style="font-weight:700;margin-bottom:4px">Reason (required)</div><div class="ps-reasons">${OFF_REASONS.map((r) => `<button type="button" class="chip-btn ${d.reason === r ? 'chip-main' : ''}" data-act="guardOffReason:${encodeURIComponent(r)}">${esc(r)}</button>`).join('')}</div>
    <div class="small" style="font-weight:700;margin:8px 0 4px">For how long</div><div class="ps-reasons"><button type="button" class="chip-btn ${d.scope === 'run' ? 'chip-main' : ''}" data-act="guardOffScope:run">${RUN.name} pay run only</button><button type="button" class="chip-btn ${d.scope === 'until' ? 'chip-main' : ''}" data-act="guardOffScope:until">Until turned back on</button></div>
    <div class="ar-actions" style="margin-top:10px"><button class="btn p sm" data-act="guardOffConfirm" ${d.reason ? '' : 'disabled'}>${high ? 'Send to approver' : 'Turn off'}</button><button class="btn sm" data-act="guardOffCancel">Cancel</button></div>
    <div class="small muted" style="margin-top:6px">Logged in Pay run records with who, when, reason and scope.</div></div>`;
}
function guardHeader(key, issues, demos, S) {
  const g = GUARDS[key], open = pendingIn(issues, key), held = open.filter((i) => i.status === 'held').length, off = GUARD_SWITCH.off[key];
  const chip = off ? '<span class="tag t-n">Not checked this run</span>' : open.length ? `<span class="tag ${held ? 't-r' : 't-o'}">${open.length} to review${held ? ` · ${held} held` : ''}</span>` : '<span class="tag t-g">All clear</span>';
  return `<div class="card ps-ghead"><span class="ps-gic">${ICON[g.icon]}</span><div style="min-width:0;flex:1"><div class="eyebrow">PayShield guard</div><h3>${g.name}</h3><p class="muted">${g.q}</p>
    <div class="ps-covers">${g.covers.map((c) => `<span class="chip">${esc(c)}</span>`).join('')}</div></div>
    <div class="ps-gside">${chip}${guardSwitch(key, S)}<div class="ps-demos">${demos.map((d, n) => demoBtn(d, n === 0)).join('')}</div></div></div>${offPanel(key, S)}`;
}

function validatorsCard(key) {
  const g = GUARDS[key];
  return `<div class="card" style="padding:14px 16px"><b style="font-size:14.5px">Validators and parameters</b><div class="small muted" style="margin:2px 0 8px">Live values from the code and the rule library</div>
    <table class="g val-t" style="min-width:0"><tbody>${g.params.map(([n, v, note]) => `<tr><td class="small">${esc(n)}</td><td>${pv(v)}${note ? `<div class="small muted">${esc(note)}</div>` : ''}</td></tr>`).join('')}</tbody></table>
    <div class="ps-note"><b>Feeds PayShield:</b> ${esc(g.feeds)}</div>
    <div class="ps-note ps-note-ai"><span class="tag t-b">AI</span> ${esc(g.ai)}</div></div>`;
}

function guardPage(key, h, extraLeft = '', extraRight = '', demos = []) {
  const issues = h.S.issues, list = issues.filter((i) => i.guard === key), open = pendingIn(issues, key);
  const atRisk = open.reduce((s, i) => s + i.impact, 0), kept = list.filter((i) => i.state === 'fixed').reduce((s, i) => s + i.impact, 0);
  const f = h.S.focus && issues.find((i) => i.id === h.S.focus && i.guard === key);
  const banner = f ? `<div class="ps-from"><span class="tag t-b">From Trust Check</span><span><b>${esc(f.name)}</b> · ${esc(f.title)}. Fix it below.</span><button class="linkbtn" data-act="page:home">← Back to Trust Check</button></div>` : '';
  const off = GUARD_SWITCH.off[key];
  if (off) return `${guardHeader(key, issues, demos, h.S)}
  <div class="ps-cols"><div class="ps-main"><div class="card ps-offcard"><span class="ps-gic">${ICON[GUARDS[key].icon]}</span><div><h3 style="margin:0 0 4px">${GUARDS[key].name} is off for ${off.scope === 'run' ? `the ${RUN.name} pay run` : 'pay runs until it is turned back on'}</h3>
    <p class="small" style="margin:0">PayShield is not running ${SKIPS[key]} for ${esc(h.company)}. Nothing here is raised, scored in Trust Check or asked about by the agent, even if something is wrong.</p>
    <p class="small muted" style="margin:6px 0 0">Turned off by ${esc(off.by)} at ${off.at}${off.approver ? ` · approved by ${esc(off.approver)}` : ''} · “${esc(off.reason)}”</p>
    <div class="ar-actions" style="margin-top:10px"><button class="btn p sm" data-act="guardToggle:${key}">Turn ${GUARDS[key].name} back on</button><button class="btn sm" data-act="page:records">See the log</button></div></div></div></div>
    <div class="ps-side ps-dim">${validatorsCard(key)}</div></div>`;
  return `${banner}${guardHeader(key, issues, demos, h.S)}
  <div class="stats ps-stats">${statCard(ICON.users, 'Checked', `${RUN.headcount}`, 'employees in this run')}${statCard(ICON.alert, 'Found', `${list.length}`, `${list.length - open.length} resolved`)}${statCard(ICON.wallet, 'At risk now', money(atRisk), 'if paid as it is')}${statCard(ICON.circleCheck, 'Kept right', money(kept), 'fixed before payday', 'good')}</div>
  <div class="ps-cols"><div class="ps-main"><div class="ps-sec"><b>Needs review before the pay run</b>${open.length > 1 ? `<button class="btn sm" data-act="fixAll:${key}">Apply all suggested fixes</button>` : ''}</div>
    ${list.length ? list.map((i) => issueCard(i, false, h.S.focus, h.S.agent && h.S.agent.session)).join('') : '<div class="card muted" style="padding:14px">Nothing found in this run.</div>'}${extraLeft}</div>
    <div class="ps-side">${validatorsCard(key)}${extraRight}</div></div>`;
}

const scoreRing = (v, ok) => { const r = 52, c = 2 * Math.PI * r; return `<svg class="ps-ring" viewBox="0 0 130 130" role="img" aria-label="Pay Score ${v}"><circle cx="65" cy="65" r="${r}" fill="none" stroke="var(--line)" stroke-width="12"/><circle cx="65" cy="65" r="${r}" fill="none" stroke="${ok ? 'var(--good)' : v < 80 ? 'var(--bad)' : '#f59e0b'}" stroke-width="12" stroke-linecap="round" stroke-dasharray="${(c * v / 100).toFixed(1)} ${c.toFixed(1)}" transform="rotate(-90 65 65)" style="transition:stroke-dasharray .5s"/><text x="65" y="72" text-anchor="middle" font-size="34" font-weight="800" fill="var(--ink)">${v || '…'}</text></svg>`; };
const ring = (pct, label) => { const r = 52, c = 2 * Math.PI * r; return `<svg class="ps-ring" viewBox="0 0 130 130" role="img" aria-label="${label}"><circle cx="65" cy="65" r="${r}" fill="none" stroke="var(--line)" stroke-width="12"/><circle cx="65" cy="65" r="${r}" fill="none" stroke="${pct >= 100 ? 'var(--good)' : 'var(--accent)'}" stroke-width="12" stroke-linecap="round" stroke-dasharray="${(c * pct / 100).toFixed(1)} ${c.toFixed(1)}" transform="rotate(-90 65 65)"/><text x="65" y="62" text-anchor="middle" font-size="26" font-weight="800" fill="var(--ink)">${Math.floor(pct)}%</text><text x="65" y="82" text-anchor="middle" font-size="11" fill="var(--mute)">ready</text></svg>`; };

export function buildPages(h) {
  const { S } = h;
  return {
    home: {
      crumb: 'PayShield › <b>Trust Check</b>',
      body: () => {
        const r = runSummary(S.issues), ps = payScore(S.issues), tc = S.tc || {};
        if (S.approved) return `<div class="card ps-approved"><div class="ps-big-ok">✓</div><h3 style="font-size:22px;margin:6px 0">${RUN.name} pay run approved</h3>
          <p class="muted">${RUN.headcount - S.issues.filter((i) => i.id === 'lim' && i.state === 'fixed').length} employees paid on ${RUN.payDate}. Trust Check passed: Pay Score ${ps.score}/100.</p>
          <div class="stats ps-stats" style="margin-top:14px">${statCard(ICON.circleCheck, 'Kept from being paid wrongly', money(r.protectedAmt), 'fixed in the guards before payday', 'good')}${statCard(ICON.alert, 'Issues found', `${S.issues.length}`, 'all resolved or accepted')}${statCard(ICON.users, 'Records reviewed by a person', `${S.issues.length}`, `instead of ${RUN.headcount}`)}${statCard(ICON.library, 'Rule versions recorded', `${RULES.length}`, 'for audit replay')}</div>
          <div style="display:flex;gap:8px;justify-content:center;margin-top:16px"><button class="btn" data-act="resetRun">Reset demo</button><button class="btn p" data-act="page:records">Open the pay run record</button></div></div>`;
        const keys = Object.keys(GUARDS);
        const rows = keys.map((k, n) => { const g = GUARDS[k], o = pendingIn(S.issues, k), held = o.filter((i) => i.status === 'held').length;
          const off = GUARD_SWITCH.off[k];
          if (off) return `<div class="tc-row off"><span class="ps-gic sm">${ICON[g.icon]}</span><div class="tc-mid"><b>${g.name}</b><span class="small muted">Turned off for ${off.scope === 'run' ? 'this run' : 'all runs'} by ${esc(off.by)} · “${esc(off.reason)}”</span><div class="tc-bar"><i style="width:0"></i></div></div><div class="tc-res"><span class="tag t-n">Off · not checked</span></div><div class="tc-go"><button class="linkbtn" data-act="page:${k}">Turn on</button></div></div>`;
          const state = tc.running ? (n < tc.stage ? 'done' : n === tc.stage ? 'run' : 'wait') : 'done';
          const fail = state === 'done' && o.length;
          const res = state === 'wait' ? '<span class="small muted">Waiting</span>' : state === 'run' ? '<span class="small muted">Checking ${RUN.headcount} records…</span>'
            : o.length ? `<span class="tag ${held ? 't-r' : 't-o'}">${o.length} failed${held ? ` · ${held} held` : ''}</span><span class="small"><b>${money(o.reduce((s2, i) => s2 + i.impact, 0))}</b> at risk</span>` : '<span class="tag t-g">✓ Passed</span>';
          return `<div class="tc-row ${fail ? (held ? 'fail-h' : 'fail') : state === 'done' ? 'pass' : state}"><span class="ps-gic sm">${ICON[g.icon]}</span>
            <div class="tc-mid"><b>${g.name}</b><span class="small muted">${g.q}</span><div class="tc-bar"><i style="width:${state === 'done' ? 100 : state === 'run' ? 55 : 0}%"></i></div></div>
            <div class="tc-res">${res}</div>
            <div class="tc-go">${fail ? `<button class="btn sm ${held ? 'p' : ''}" data-act="page:${k}">Fix in ${g.name} →</button>` : state === 'done' ? `<button class="linkbtn" data-act="page:${k}">Open</button>` : ''}</div></div>`; }).join('');
        const alerts = pendingIn(S.issues).sort((a, b) => (a.status === 'held' ? -1 : 0) - (b.status === 'held' ? -1 : 0) || b.impact - a.impact);
        const ready = !r.open;
        const offs = Object.keys(GUARD_SWITCH.off);
        const offBanner = offs.length ? `<div class="ps-from" style="background:var(--surface2);border-color:var(--line)"><span class="tag t-n">${offs.length} guard${offs.length > 1 ? 's' : ''} off</span><span>${offs.map((k) => GUARDS[k].name).join(', ')} ${offs.length > 1 ? 'are' : 'is'} not checked in this run, so ${offs.length > 1 ? 'they are' : 'it is'} not part of the Pay Score.</span></div>` : '';
        const paidBanner = S.agentPaid ? `<div class="ps-paid"><span class="ps-big-ok sm">✓</span><div><b>${RUN.name} pay run paid through PayShield Agent</b> · ${S.agentPaid.id} · approved by ${esc(S.agentPaid.approver)} at ${S.agentPaid.at}<div class="small">${S.agentPaid.decisions} decisions were made with the agent, one by one, and saved to the guards in PayShield.</div></div><button class="btn sm" data-act="page:records">Audit record</button></div>` : '';
        return `${paidBanner}${offBanner}<div class="card ps-hero"><div class="ps-hero-l"><div class="eyebrow">PayShield · Trust Check</div><h3>${RUN.name} pay run</h3>
          <p class="muted">Pay date ${RUN.payDate} · ${RUN.headcount} employees · gross ${money(RUN.gross)} · ${(RUN.headcount * RUN.checksPerPerson).toLocaleString('en-SG')} checks</p>
          <div class="ps-verdict ${tc.running || S.agentPaid ? 'warn' : r.open ? (r.held ? 'bad' : 'warn') : 'good'}">${tc.running ? '<b>Checking…</b> every record is going through the five guards.' : S.agentPaid && r.open ? `<b>September is paid; ${r.open} findings are still open.</b> They come back in October unless fixed in their guards. ${money(r.atRisk)} at risk.` : r.open ? `<b>Not ready to pay.</b> ${r.held} held · ${r.review} to review in ${keys.filter((k) => pendingIn(S.issues, k).length).length} guards. ${money(r.atRisk)} would be paid wrongly.` : `<b>Ready to approve.</b> Every ${Object.keys(GUARD_SWITCH.off).length ? 'active ' : ''}guard has passed.`}</div>
          <p class="small muted" style="margin:8px 0 0">Trust Check only analyses and alerts. Each finding is fixed in its own guard, and Trust Check re-scores straight away.</p>
          <div style="display:flex;gap:8px;flex-wrap:wrap;margin-top:12px">${S.agentPaid ? '<span class="tag t-g" style="font-size:13px;padding:6px 12px">September paid via agent</span>' : `<button class="btn p" data-act="approveRun" ${ready && !tc.running ? '' : 'disabled'}>Approve pay run</button>`}<button class="btn" data-act="tcRun" ${tc.running ? 'disabled' : ''}>↻ Re-run Trust Check</button><span class="small muted" style="align-self:center">${tc.running ? '' : `Last run ${tc.at || '09:00'}`}</span></div></div>
          <div class="ps-hero-r tc-score">${scoreRing(tc.running ? 0 : ps.score, ready)}<div class="small muted" style="text-align:center;margin-top:4px">${tc.running ? 'Pay Score' : `Pay Score · ${ps.verdict}`}</div></div></div>
          <div class="ps-sec"><b>Guard results</b><span class="small muted">Fix a failing guard on its own page</span></div>
          <div class="card tc-list">${rows}</div>
          <div class="ps-cols"><div class="ps-main"><div class="ps-sec"><b>Pay alerts</b><span class="small muted">${alerts.length ? 'Held first · click to go to the finding' : 'Nothing left to review'}</span></div>
            ${tc.running ? '<div class="card muted" style="padding:14px">Waiting for the check to finish…</div>' : alerts.length ? `<div class="card" style="padding:0;overflow:hidden"><table class="g" style="min-width:0"><thead><tr><th>Employee</th><th>What Trust Check found</th><th>Status</th><th style="text-align:right">At risk</th><th></th></tr></thead><tbody>
            ${alerts.map((i) => `<tr class="ps-row" data-act="goIssue:${i.id}" tabindex="0"><td><b>${esc(i.name)}</b><div class="small muted">${esc(i.dept)}</div></td><td class="small">${esc(i.title)}</td><td>${st(i.status)}</td><td style="text-align:right"><b>${money(i.impact)}</b></td><td class="small" style="white-space:nowrap;color:var(--accent);font-weight:700">${GUARDS[i.guard].short} →</td></tr>`).join('')}</tbody></table></div>` : '<div class="card" style="padding:14px">All alerts resolved. You can approve the pay run.</div>'}</div>
          <div class="ps-side"><div class="card" style="padding:14px 16px"><b>How the Pay Score is worked out</b>
            <p class="small" style="margin:6px 0 0">Each record gets a Trust Score from its guards: Pay Structure × ${DEFAULT_CONFIG.weights.pay.toFixed(2)}, Bank Shield × ${DEFAULT_CONFIG.weights.bank.toFixed(2)}, Attendance × ${DEFAULT_CONFIG.weights.attendance.toFixed(2)}; Employment and Compliance breaches are critical rules. 80+ Clear · 50–79 Review · under 50 Held.</p>
            <p class="small" style="margin:8px 0 0">The run’s <b>Pay Score</b> = half records ready (${Math.round(ps.recordsPart * 100)}%) + half pay value safe (${Math.round(ps.valuePart * 100)}%). Held records cap it at 79; open reviews at 89.</p></div>
            <div class="card" style="padding:14px 16px"><b>PayShield Agent</b><p class="small muted" style="margin:4px 0 8px">Runs Trust Check, compliance and history from one prompt</p>
            <button class="btn p sm" style="width:100%;margin-bottom:8px" data-act="agHome:run">▶ Ask the agent to check this whole run</button><div class="agent-chips" style="padding:0;border:0">${['Why is Daniel held?', 'How do I prorate a new joiner?', 'Is CPF due on share awards?'].map((q, n) => `<button class="chip-btn" data-act="agHome:${n}">${q}</button>`).join('')}</div></div></div></div>`;
      },
    },
    people: { crumb: 'PayShield › Guards › <b>People & Employment</b>', body: () => guardPage('people', h,
      `<div class="card" style="padding:14px 16px;margin-top:12px"><b>Employee lifecycle this month</b><div class="ps-mini">${[['Joiners', 6, '1 needs proration'], ['Leavers', 4, '1 still in the run'], ['Work passes expiring in 30 days', 3, '1 before payday'], ['Designation or pay changes', 9, 'all approved']].map(([a, b, c]) => `<div><span class="v">${b}</span><span class="small"><b>${a}</b><br><span class="muted">${c}</span></span></div>`).join('')}</div></div>`, '', []) },
    time: { crumb: 'PayShield › Guards › <b>Time & Attendance</b>', body: () => guardPage('time', h,
      `<div class="card" style="padding:14px 16px;margin-top:12px"><b>Overtime this month vs the 72 h cap</b>${[['Tan Wei Ming', 88], ['Hafiz Rahman', 64], ['Grace Lim', 58], ['Mohd Faizal', 41], ['Joseph Tan', 36]].map(([n, v]) => `<div class="ps-otrow"><span class="small">${n}</span><div class="ps-otbar"><i style="width:${Math.min(100, v / 96 * 100)}%;background:${v > 72 ? 'var(--bad)' : 'var(--accent)'}"></i><s style="left:${72 / 96 * 100}%"></s></div><b class="small">${v} h</b></div>`).join('')}<div class="small muted" style="margin-top:6px">Red line: MOM cap of 72 h a month</div></div>
      <div class="card" style="padding:14px 16px;margin-top:12px"><b>Clock-in integrity</b><div class="ps-mini">${[['Buddy-punch attempts blocked', 3, 'one phone, one person'], ['Outside geofence', 5, 'all explained'], ['Missed clock-outs', 11, '8 fixed with AI suggestion'], ['Selfie checks', '4,812', 'photos not stored']].map(([a, b, c]) => `<div><span class="v">${b}</span><span class="small"><b>${a}</b><br><span class="muted">${c}</span></span></div>`).join('')}</div></div>`, '', ['attend']) },
    bank: { crumb: 'PayShield › Guards › <b>Bank Shield</b>', body: () => guardPage('bank', h,
      `<div class="card" style="padding:0;overflow:hidden;margin-top:12px"><div style="padding:12px 14px"><b>Bank changes in the last 30 days</b></div><table class="g" style="min-width:0"><thead><tr><th>Employee</th><th>Changed</th><th>Device</th><th>2nd channel</th><th>Risk</th></tr></thead><tbody>
      ${[['Daniel Lim', '2 days ago', 'New', S.issues.find((i) => i.id === 'daniel').state === 'open' ? 'Not confirmed' : 'Rejected', 0.9], ['Priya Menon', '9 days ago', 'Known', 'Confirmed', 0.3], ['Wong Kai Xin', '15 days ago', 'Known', 'Confirmed', 0.3], ['Ahmad Yusof', '21 days ago', 'New', 'Confirmed', 0.5]].map(([n, c, d, x, r]) => `<tr><td><b>${n}</b></td><td class="small">${c}</td><td class="small">${d}</td><td>${x === 'Confirmed' ? '<span class="tag t-g">Confirmed</span>' : x === 'Rejected' ? '<span class="tag t-n">Rejected: “Not me”</span>' : '<span class="tag t-r">Not confirmed</span>'}</td><td>${pv('+' + r.toFixed(2))}</td></tr>`).join('')}</tbody></table></div>`,
      `<div class="card" style="padding:14px 16px"><b>Fraud Network</b><p class="small muted" style="margin:4px 0 8px">Only in PayShield: every company protects the others</p><div class="ps-mini one">${[['Companies protected', '1,240'], ['Fraud accounts on watch', '37'], ['Blocked this month', '2']].map(([a, b]) => `<div><span class="v">${b}</span><span class="small">${a}</span></div>`).join('')}</div><p class="small" style="margin:8px 0 0">Shared as a keyed fingerprint (HMAC, key in an HSM). The account number never leaves the company.</p></div>`, ['bank', 'network']) },
    pay: { crumb: 'PayShield › Guards › <b>Pay Structure</b>', body: () => guardPage('pay', h,
      `<div class="card" style="padding:0;overflow:hidden;margin-top:12px"><div style="padding:12px 14px"><b>Salary structure: what PayShield checks for each pay item</b></div><table class="g" style="min-width:0"><thead><tr><th>Pay item</th><th>Checked against</th><th>CPF</th><th>Tax reporting</th></tr></thead><tbody>
      ${[['Basic salary', 'own 6-month median, grade band', 'Ordinary Wage', 'IR8A'], ['Fixed allowances', 'cap per grade', 'Ordinary Wage', 'IR8A'], ['Overtime', '72 h cap, 1.5× hourly basic, clock proof', 'Ordinary Wage', 'IR8A'], ['Bonus', 'policy ≤ 2 months without CFO', 'Additional Wage', 'IR8A'], ['AWS (13th month)', 'contract terms, proration', 'Additional Wage', 'IR8A'], ['Share awards / options', 'how settled: shares or cash', 'Shares: none · cash: yes', 'Appendix 8B']].map((r) => `<tr>${r.map((c, n) => `<td class="small">${n ? esc(c) : `<b>${esc(c)}</b>`}</td>`).join('')}</tr>`).join('')}</tbody></table></div>`,
      `<div class="card" style="padding:14px 16px"><b>December AWS: dry run</b> <span class="tag t-n">Preview</span><p class="small muted" style="margin:4px 0 8px">Checked 2 months early, so December has no surprises</p><div class="ps-mini one">${[['Eligible (per contract)', AWS_PREVIEW.eligible], ['Joined mid-year: prorate per contract', AWS_PREVIEW.joiners], ['Leaving before December', AWS_PREVIEW.leavers], ['Would pass the CPF AW ceiling', AWS_PREVIEW.overCeiling]].map(([a, b]) => `<div><span class="v">${b}</span><span class="small">${a}</span></div>`).join('')}</div><p class="small" style="margin:8px 0 0">AWS is not required by law; PayShield uses each contract’s terms. Estimated cost ${money(AWS_PREVIEW.total)}.</p></div>`, ['model']) },
    compliance: { crumb: 'PayShield › Guards › <b>Compliance</b>', body: () => guardPage('compliance', h,
      `<div class="card" style="padding:14px 16px;margin-top:12px"><div class="ps-sec" style="margin:0 0 6px"><b>Company policies</b><span class="small muted">Set by ${esc(h.company)} · every change logged</span></div>
        ${POLICIES.map((p) => `<label class="ps-pol"><input type="checkbox" data-pol="${p.id}" ${S.policy[p.id] ? 'checked' : ''}><span><b>${esc(p.name)}</b><span class="small muted">${esc(p.detail)}</span></span><span class="tag ${S.policy[p.id] ? 't-g' : 't-n'}">${S.policy[p.id] ? 'On' : 'Off'}</span></label>`).join('')}</div>`,
      `<div class="card" style="padding:0;overflow:hidden"><div style="padding:12px 14px"><b>Statutory rule library</b><div class="small muted">Versioned · verified October 2026 · <button class="linkbtn" data-act="go:rules">1 update from Rule Watch</button></div></div><div style="max-height:330px;overflow:auto"><table class="g" style="min-width:0"><tbody>
        ${RULES.map((r) => `<tr><td class="small"><b>${esc(r.name)}</b><div class="muted">${esc(r.version)} · ${esc(r.src)}</div></td><td>${pv(typeof r.value === 'number' && r.code.startsWith('CPF') ? money(r.value) : r.value)}</td></tr>`).join('')}</tbody></table></div></div>`, ['rules', 'validators']) },
    proof: { crumb: 'PayShield › <b>Proof</b>', body: () => `<div class="card ps-ghead"><span class="ps-gic">${ICON.flask}</span><div style="flex:1"><div class="eyebrow">Does it work?</div><h3>Test PayShield yourself</h3><p class="muted">Every number in the proposal can be reproduced here or with <code>npm test</code>.</p></div></div>
      <div class="ps-tiles two">${[['proof', 'Test run', '25 of 25 hidden problems caught in each of 50 synthetic companies; false alarms 3.6% → 1.4%'], ['compare', 'Before / after', 'Same pay run, two endings: S$15,070 paid wrongly vs S$0'], ['model', 'Our own model', 'Rules + model caught 620 of 620 on 20 unseen companies'], ['csv', 'Check your own file', 'Score an anonymised pay-run CSV in the browser; nothing is uploaded'], ['ask', 'AI guardrails', 'Masked data in, every number checked out'], ['learn', 'Learns from you', 'Accepted reasons remembered for 3 runs; tuning only suggested'], ['validators', 'All validators', 'Every check and the exact parameters it uses']].map(([k, t, d]) => `<button type="button" class="card ps-tile" data-act="go:${k}"><b>${t}</b><span class="small muted">${d}</span><span class="ps-open">▶ Run it</span></button>`).join('')}</div>` },
  };
}
