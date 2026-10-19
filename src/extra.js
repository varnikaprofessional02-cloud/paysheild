// Scenarios added after the review: Before vs after, Learns from you, Test run.
// The Test run and Learns scenarios call the real code (backtest.js, learning.js, scoring.js) in the browser.

import { runTest, runMany, PLANTED } from './backtest.js';
import { scoreRecord } from './scoring.js';
import { createMemory, acceptFlag, recordFix, applyMemory, tuningSuggestions } from './learning.js';

const pct = (x, d = 1) => (x * 100).toFixed(d) + '%';
const SHORT = { BANK_HIJACK_NEAR_PAYDAY: 'hijack near payday', BANK_HIJACK_EARLY: 'early hijack', BANK_HIJACK_EMAIL_TAKEN: 'email takeover',
  GHOST_SHARED_ACCOUNT: 'ghost employees', PAY_SPIKE: 'pay spikes', CPF_MISMATCH: 'wrong CPF', PAID_AFTER_EXIT: 'ex-employees paid',
  OT_WITHOUT_PROOF: 'OT without proof', UNVERIFIED_HOURS: 'unverified hours' };
const tag = (st, sc) => st === 'held' ? `<span class="tag t-r">${sc} · Held</span>` : st === 'review' ? `<span class="tag t-o">${sc} · Review</span>` : `<span class="tag t-g">${sc} · Clear</span>`;

/* ---------- Learns from you: one real record, scored by the real code ---------- */
const GRACE_HIST = [5200, 5210, 5190, 5205, 5198, 5202];
const GRACE_OCT = 5830, GRACE_NOV = 5832;
function graceScores() {
  const oct = scoreRecord({ current: GRACE_OCT, history: GRACE_HIST });
  const novHist = [...GRACE_HIST.slice(1), GRACE_OCT];
  const novWithout = scoreRecord({ current: GRACE_NOV, history: novHist });
  const mem = createMemory();
  acceptFlag(mem, { employeeId: 'E-1150', reason: 'PROMOTION', month: 10 });
  const m = applyMemory(mem, 'E-1150', 11);
  const novWith = scoreRecord({ current: GRACE_NOV, history: m.baselineFrom != null ? [GRACE_OCT] : novHist });
  return { oct, novWithout, novWith };
}
function sampleSuggestions() {
  const mem = createMemory();
  for (let i = 0; i < 9; i++) acceptFlag(mem, { employeeId: 'E-' + i, reason: 'PROMOTION', month: 10, code: 'PAY_SPIKE_PROMOTION' });
  recordFix(mem, { code: 'PAY_SPIKE_PROMOTION' });
  for (let i = 0; i < 6; i++) recordFix(mem, { code: 'BANK_CHANGE_UNCONFIRMED' });
  return tuningSuggestions(mem, { labels: { PAY_SPIKE_PROMOTION: '“Pay spike” on a promotion', BANK_CHANGE_UNCONFIRMED: 'An unconfirmed bank change' } });
}

/* ---------- Before vs after: the same four problems from the pay run scenario ---------- */
const CASES = [
  { who: 'Daniel Lim', what: 'Bank account changed by a hacker 2 days before payday',
    without: ['S$8,120 paid to the hacker’s account', 'Found 3 days later when Daniel asks where his salary is', 'Pay him again off-cycle; police report; money usually not recovered'],
    with: ['Held at Trust Check (score 23)', 'Daniel confirms “not me” on his phone', 'Paid to his real account on time'], loss: 8120 },
  { who: 'Lim Hui Ling', what: 'Left on 31 Aug but still in the September run',
    without: ['S$4,200 paid to an ex-employee', 'Found at month-end reconciliation', 'Awkward recovery request'],
    with: ['Flagged: critical rule (score 52)', 'Removed from the run', 'Nothing paid by mistake'], loss: 4200 },
  { who: 'Tan Wei Ming', what: 'OT 88 h, above the 72 h cap; 14 h with no clock-out',
    without: ['S$2,630 overpaid; OT above the legal cap', 'Found only if someone audits timesheets', 'Recovery from a worker is hard'],
    with: ['Flagged (score 60)', 'OT capped at 72 h; 14 h sent to his manager', 'Paid the right amount'], loss: 2630 },
  { who: 'Siti Rahmah', what: 'CPF worked out on the old S$7,400 ceiling',
    without: ['CPF short by S$120 this month', 'Found at a CPF audit, months later', 'Back-pay CPF plus late-payment interest'],
    with: ['Flagged: rule changed on 1 Jan 2026', 'Recalculated on S$8,000', 'Correct CPF, on time'], loss: 120 },
];

export function extraScenarios(h) {
  const { app, consoleApp, fmt, S } = h;
  return {
    compare: {
      label: 'Before / after', who: 'Same pay run, two endings',
      title: 'The same pay run, without and with PayShield', sub: 'Four problems hidden in the September run (sample data). Switch between the two endings.',
      init() { S.d = { mode: 'without', seenWith: false }; },
      steps: [
        { t: 'Switch the ending', you: 'Click <b>With PayShield</b> to compare.', sys: 'Without PayShield the pay run goes from set-up straight to Review &amp; Confirm. With it, every record is checked first.',
          screen: () => { const w = S.d.mode === 'with';
            return app('Pay Run › <b>September 2026</b>', `<div style="display:flex;justify-content:space-between;align-items:center;gap:10px;flex-wrap:wrap;margin-bottom:12px"><div><b style="font-size:16px">${w ? 'With PayShield' : 'Without PayShield'}</b><div class="small muted">${w ? 'Problems are found before salary leaves the company' : 'Problems are found after payday, by complaints and audits'}</div></div>
            <div class="tabs" role="tablist" aria-label="Ending"><button class="tab" role="tab" aria-selected="${!w}" data-act="cmp:without">Without PayShield</button><button class="tab ${w ? '' : 'pulse'}" role="tab" aria-selected="${w}" data-act="cmp:with">With PayShield</button></div></div>
            <div class="card"><div class="tblwrap"><table class="g" style="min-width:640px"><thead><tr><th style="width:26%">Problem</th><th>What happens</th><th class="num-r" style="width:16%">Paid wrongly</th></tr></thead><tbody>
            ${CASES.map((c) => `<tr><td><b>${c.who}</b><div class="small muted">${c.what}</div></td><td><ol style="margin:0;padding-left:18px;display:flex;flex-direction:column;gap:2px">${(w ? c.with : c.without).map((x) => `<li class="small">${x}</li>`).join('')}</ol></td><td class="num-r">${w ? '<span class="tag t-g">S$0</span>' : `<b style="color:var(--bad)">S$${fmt(c.loss)}</b>`}</td></tr>`).join('')}
            <tr><td><b>Total</b></td><td class="small muted">${w ? 'All four fixed or held before the run was locked' : 'All four found after salary was paid'}</td><td class="num-r"><b style="color:${w ? 'var(--good)' : 'var(--bad)'}">S$${w ? 0 : fmt(CASES.reduce((a, c) => a + c.loss, 0))}</b></td></tr></tbody></table></div></div>
            ${w ? '<div style="display:flex;justify-content:flex-end;margin-top:12px"><button class="btn p pulse" data-act="next">See the difference</button></div>' : ''}`); } },
        { t: 'The difference in one view', you: 'Done. Try <b>Test run</b> to see this measured on 500 records.', sys: 'Same company, same month, same mistakes. The only change is a check before the pay run is locked.',
          screen: () => app('Pay Run › <b>Before / after</b>', `<div class="split">
            <div class="card" style="padding:16px;border-color:var(--bad-line)"><span class="tag t-r">Without PayShield</span><div class="stats" style="margin-top:12px;grid-template-columns:1fr 1fr">
              <div class="card stat"><div class="l">Paid wrongly</div><div class="v" style="color:var(--bad)">S$15,070</div><div class="s">in one pay run</div></div>
              <div class="card stat"><div class="l">Found after payday</div><div class="v">4 of 4</div><div class="s">complaints, audits</div></div>
              <div class="card stat"><div class="l">Off-cycle fixes</div><div class="v">4</div><div class="s">repay, recover, back-pay CPF</div></div>
              <div class="card stat"><div class="l">Records checked</div><div class="v">by hand</div><div class="s">if there is time</div></div></div></div>
            <div class="card" style="padding:16px;border-color:var(--good-line)"><span class="tag t-g">With PayShield</span><div class="stats" style="margin-top:12px;grid-template-columns:1fr 1fr">
              <div class="card stat"><div class="l">Paid wrongly</div><div class="v" style="color:var(--good)">S$0</div><div class="s">held or fixed first</div></div>
              <div class="card stat"><div class="l">Found before payday</div><div class="v">4 of 4</div><div class="s">at Trust Check</div></div>
              <div class="card stat"><div class="l">Off-cycle fixes</div><div class="v">0</div><div class="s">nothing to undo</div></div>
              <div class="card stat"><div class="l">Records to look at</div><div class="v">7 of 219</div><div class="s">3.2%; the rest are Clear</div></div></div></div></div>
            <div class="small muted" style="margin-top:10px">Sample data from the Pay run scenario. Amounts: Daniel S$8,120 · Lim Hui Ling S$4,200 · Tan Wei Ming S$2,630 OT overpaid · Siti Rahmah S$120 CPF short.</div>
            <div style="display:flex;gap:8px;margin-top:12px;flex-wrap:wrap"><button class="btn p" data-act="go:proof">Open the Test run</button><button class="btn" data-act="restart">Replay</button></div>`) },
      ],
    },

    learn: {
      label: 'Learns from you', who: 'Payroll admin',
      title: 'PayShield learns from every decision', sub: 'When an admin accepts a flag with a reason, PayShield remembers it, so the same false alarm does not come back. It can suggest changes, but never applies them on its own.',
      init() { S.d = { g: graceScores(), accepted: false, approved: false, sug: sampleSuggestions() }; },
      steps: [
        { t: 'A pay change is flagged', you: 'Pick the reason: <b>Promotion, not yet recorded</b>.', sys: 'Grace’s pay is 12% above her 6-month normal and no reason code was entered, so Anomaly Guard flags it for review.',
          screen: () => { const g = S.d.g, a = S.d.accepted;
            return app('October run › <b>Trust Check</b>', `<div class="card" style="padding:14px"><div style="display:flex;justify-content:space-between;gap:10px;flex-wrap:wrap;align-items:center"><div><b style="font-size:15px">Grace Tan</b> <span class="small muted">· E-1150 · Sales</span><div class="small muted" style="margin-top:2px">6-month normal S$5,200 · October S$5,830 (+12%) · no reason code</div></div>${a ? '<span class="tag t-g">Accepted: promotion</span>' : tag(g.oct.status, g.oct.score)}</div>
            <div class="ai" style="margin-top:12px"><div class="h">WHY IT WAS FLAGGED</div>Pay is 12% above this person’s usual pay and no increment, bonus or proration was recorded.</div>
            <div style="margin-top:12px"><b class="small">Decision</b><div style="display:flex;gap:8px;flex-wrap:wrap;margin-top:6px">
            <button class="btn ${a ? '' : 'p pulse'}" data-act="acceptPromo" ${a ? 'disabled' : ''}>Accept: promotion, not yet recorded</button><span class="btn">Accept: one-off allowance</span><span class="btn">Not right: fix the pay</span></div></div>
            ${a ? '<div style="display:flex;justify-content:flex-end;margin-top:12px"><button class="btn p pulse" data-act="next">Next</button></div>' : ''}</div>`); } },
        { t: 'PayShield remembers', you: 'Click <b>Next</b> to jump to November.', sys: 'The new pay level becomes Grace’s normal for the next 3 pay runs, then the memory expires. Rule checks and bank checks are never switched off.',
          screen: () => app('PayShield › <b>Decisions</b>', `<div class="card"><div class="tblwrap"><table class="g" style="min-width:600px"><thead><tr><th>Employee</th><th>Decision</th><th>Effect</th><th>Valid</th><th>By</th></tr></thead><tbody>
            <tr class="hl"><td><b>Grace Tan</b></td><td>Promotion, not yet recorded</td><td>S$5,830 is the new normal</td><td>Nov 2026 – Jan 2027</td><td>Varnika R.</td></tr>
            <tr><td>Arjun Kumar</td><td>Joint account with spouse</td><td>Shared account verified by HR</td><td>until changed</td><td>Varnika R.</td></tr>
            <tr><td>Chen Jia Hui</td><td>New bank account, “it was me”</td><td>Confirmed on second channel</td><td>this account</td><td>Kevin L.</td></tr></tbody></table></div></div>
            <div class="split" style="margin-top:12px"><div class="card" style="padding:14px"><b>What memory changes</b><p class="small" style="margin:6px 0 0">Only the statistical “is this unusual for this person?” part, and only for the reason given.</p></div>
            <div class="card" style="padding:14px"><b>What it never changes</b><p class="small" style="margin:6px 0 0">Critical rules (CPF, ex-employees, OT cap), bank-change checks and the Fraud Network. Every decision is in the audit log.</p></div></div>
            <div style="display:flex;justify-content:flex-end;margin-top:12px"><button class="btn p pulse" data-act="next">Go to November</button></div>`) },
        { t: 'Next month: no repeat alarm', you: 'Compare the two columns, then click <b>Next</b>.', sys: 'Both columns use the same scoring code. The only difference is the remembered decision.',
          screen: () => { const g = S.d.g, t = S.d.test || (S.d.test = runTest());
            return app('November run › <b>Trust Check</b>', `<div class="split">
            <div class="card" style="padding:14px"><span class="tag t-n">Without learning</span><p style="margin:10px 0 4px"><b>Grace Tan</b> · S$5,832</p>${tag(g.novWithout.status, g.novWithout.score)}<p class="small muted" style="margin:8px 0 0">Flagged again: her old pay still dominates the 6-month history.</p></div>
            <div class="card" style="padding:14px;border-color:var(--good-line)"><span class="tag t-g">With learning</span><p style="margin:10px 0 4px"><b>Grace Tan</b> · S$5,832</p>${tag(g.novWith.status, g.novWith.score)}<p class="small muted" style="margin:8px 0 0">Clear: the promotion was accepted last month.</p></div></div>
            <div class="card" style="padding:14px;margin-top:12px"><b>In the 500-employee test run</b><p class="small" style="margin:6px 0 0">Admins accepted ${t.learning.accepted} false alarms in month 12. In month 13, repeat alarms fell from <b>${t.learning.without.repeatAlarms}</b> to <b>${t.learning.with.repeatAlarms}</b>. New, genuine changes are still flagged (${t.learning.with.newAlarms}).</p></div>
            <div style="display:flex;justify-content:flex-end;margin-top:12px"><button class="btn p pulse" data-act="next">See suggestions</button></div>`); } },
        { t: 'It suggests, you decide', you: 'Approve the first suggestion. Done.', sys: 'Suggestions come from patterns in admin decisions. Nothing changes until an admin approves it, and the approval is logged.',
          screen: () => { const s = S.d.sug;
            return app('PayShield › <b>Suggestions</b>', `<div class="card">${s.map((x, i) => `<div class="resolve"><div class="who2" style="min-width:0"><b>${x.action === 'soften' ? 'Reduce false alarms' : 'Hold automatically'}</b><span>${x.text}</span></div>
            <div style="display:flex;gap:8px;align-items:center">${i === 0 && S.d.approved ? '<span class="tag t-g">Approved</span>' : i === 0 ? '<button class="btn p pulse" data-act="approveSug">Approve</button><span class="btn">Dismiss</span>' : '<span class="btn">Approve</span><span class="btn">Dismiss</span>'}</div></div>`).join('')}</div>
            ${S.d.approved ? '<div class="card ok" style="margin-top:12px;background:var(--good-soft);border-color:var(--good-line)"><div class="ico" style="background:var(--surface);color:var(--good)">✓</div><div><b>Change approved by Varnika R.</b><div class="small muted">Salary changes now ask for a reason code at entry. Logged with the evidence behind it.</div></div></div>' : ''}
            <div style="display:flex;gap:8px;margin-top:12px;flex-wrap:wrap"><button class="btn" data-act="go:proof">Open the Test run</button><button class="btn" data-act="restart">Replay</button></div>`); } },
      ],
    },

    proof: {
      label: 'Test run', who: '500 employees, 25 hidden problems',
      title: 'Does it work? A measured test run', sub: 'A made-up company with 12 months of payroll and 25 problems hidden in it. The real PayShield code checks it live in your browser.',
      init() { S.d = { v1: null, v2: null, many: null, busy: false }; },
      steps: [
        { t: 'Build a test company', you: 'Click <b>Run the first design</b>.', sys: '500 employees (70% salaried, 30% shift workers), 12 months of pay with normal increments, OT swings, promotions and bank changes. Then 25 problems are hidden in month 12.',
          screen: () => consoleApp('Lab › <b>Test run</b>', `<div class="stats" style="margin-bottom:12px"><div class="card stat"><div class="l">Employees</div><div class="v">500</div><div class="s">salaried and shift</div></div><div class="card stat"><div class="l">History</div><div class="v">12 mo</div><div class="s">per employee</div></div><div class="card stat"><div class="l">Hidden problems</div><div class="v">25</div><div class="s">9 kinds</div></div><div class="card stat"><div class="l">Real data used</div><div class="v">None</div><div class="s">all generated</div></div></div>
            <div class="card"><div class="tblwrap"><table class="g" style="min-width:560px"><thead><tr><th>Hidden problem</th><th>Kind</th><th class="num-r">How many</th></tr></thead><tbody>
            ${PLANTED.map((p) => `<tr><td>${p.label}</td><td>${p.type.startsWith('BANK') || p.type.startsWith('GHOST') ? 'Fraud' : p.type.startsWith('OT') || p.type.startsWith('UNVER') ? 'Attendance' : 'Pay error'}</td><td class="num-r">${p.n}</td></tr>`).join('')}</tbody></table></div></div>
            <div style="display:flex;justify-content:flex-end;margin-top:12px"><button class="btn p pulse" data-act="runV1">Run the first design</button></div>`) },
        { t: 'First design: what it missed', you: 'Read the misses, then click <b>Apply the 4 fixes and rerun</b>.', sys: 'The first design is the one in our original proposal. The test shows exactly where it was weak.',
          screen: () => resultScreen(h, S.d.v1, 'First design', `<div class="card" style="padding:14px;margin-top:12px"><b>What the test taught us: 4 fixes</b><ol class="small" style="margin:8px 0 0;padding-left:18px;display:flex;flex-direction:column;gap:4px">
            <li><b>Shared account → always Review.</b> Two employees paid into one account is the classic ghost-employee pattern.</li>
            <li><b>OT paid without clock proof → Warning rule.</b> It is a pay error, not just an attendance note.</li>
            <li><b>Pay for hours never clocked out (3+ days) → Warning rule.</b></li>
            <li><b>Second-channel confirmation.</b> A new account from a new device is confirmed on the phone number on file before the change, or by an HR call, not by email alone. Also: hourly pay that matches verified clocked hours is not flagged, which removes most OT false alarms.</li></ol>
            <div style="display:flex;justify-content:flex-end;margin-top:12px"><button class="btn p pulse" data-act="runV2">Apply the 4 fixes and rerun</button></div></div>`) },
        { t: 'After the fixes', you: 'Click <b>Repeat on 50 companies</b>.', sys: 'Same company, same 25 problems, current design.',
          screen: () => resultScreen(h, S.d.v2, 'Current design', `<div style="display:flex;justify-content:flex-end;margin-top:12px"><button class="btn p pulse" data-act="runMany" ${S.d.busy ? 'disabled' : ''}>${S.d.busy ? 'Running 50 companies…' : 'Repeat on 50 companies'}</button></div>`, S.d.v1) },
        { t: '50 random companies', you: 'Done. This is what we will repeat on real, anonymised pay runs in the pilot.', sys: 'One good result can be luck, so the test is repeated on 50 different random companies.',
          screen: () => { const m = S.d.many;
            return consoleApp('Test run › <b>50 companies</b>', `<div class="stats" style="margin-bottom:12px">
            <div class="card stat"><div class="l">Caught, first design</div><div class="v">${m.v1.caughtAvg.toFixed(0)} / ${m.plantedPerRun}</div><div class="s">average; range ${m.v1.caughtMin}–${m.v1.caughtMax}</div></div>
            <div class="card stat"><div class="l">Caught, current design</div><div class="v" style="color:var(--good)">${m.v2.caughtAvg.toFixed(0)} / ${m.plantedPerRun}</div><div class="s">${m.v2.caughtMin === m.plantedPerRun ? 'in every one of the 50 runs' : 'lowest ' + m.v2.caughtMin}</div></div>
            <div class="card stat"><div class="l">False alarms</div><div class="v">${pct(m.v2.falseAlarmRate)}</div><div class="s">of clean records; was ${pct(m.v1.falseAlarmRate)}</div></div>
            <div class="card stat"><div class="l">Repeat alarms next month</div><div class="v">${m.learning.repeatWith.toFixed(0)}</div><div class="s">with learning; ${m.learning.repeatWithout.toFixed(1)} without</div></div></div>
            <div class="card" style="margin-bottom:12px"><div class="tblwrap"><table class="g" style="min-width:560px"><thead><tr><th>Hidden problem (all 50 companies)</th><th class="num-r">First design</th><th class="num-r">Current design</th></tr></thead><tbody>
            ${m.byType.map((t) => `<tr class="${t.v1 < t.planted ? 'hl' : ''}"><td>${t.label}</td><td class="num-r">${t.v1} / ${t.planted}</td><td class="num-r"><b style="color:var(--good)">${t.v2} / ${t.planted}</b></td></tr>`).join('')}</tbody></table></div></div>
            <div class="card" style="padding:14px"><b>Read this honestly</b><p class="small" style="margin:6px 0 0">We wrote both the hidden problems and the checks, so 25 of 25 shows the checks cover the patterns we know about. It is not a promise for real data. The next step is the same test on anonymised past pay runs from 2 pilot customers, where problems are already known.</p></div>
            <div style="display:flex;gap:8px;margin-top:12px;flex-wrap:wrap"><button class="btn" data-act="restart">Replay</button><button class="btn" data-act="go:compare">Before / after</button></div>`); } },
      ],
    },
  };
}

// The first design has no second-channel check, so an email-takeover catch there can only be a coincidence.
// (5 of 50 is the result of runMany({ runs: 50 }); see tests.)
const chance = (t, before) => !before && t.type === 'BANK_HIJACK_EMAIL_TAKEN' && t.caught > 0;
function resultScreen(h, r, name, extra, before) {
  const { consoleApp } = h;
  const rows = r.byType.map((t) => `<tr class="${t.caught < t.planted ? 'hl' : ''}"><td>${t.label}</td><td>${t.category}</td><td class="num-r">${t.caught} / ${t.planted}</td><td>${chance(t, before) ? '<span class="tag t-o">Caught by chance*</span>' : t.caught === t.planted ? '<span class="tag t-g">All caught</span>' : `<span class="tag t-r">${t.planted - t.caught} missed</span>`}</td></tr>`).join('');
  const note = r.byType.some((t) => chance(t, before)) ? '<div class="small muted" style="padding:8px 12px">* Caught only because the same person also had an unrelated pay swing. Across 50 companies the first design caught this case in 5 of 50 runs.</div>' : '';
  return consoleApp(`Test run › <b>${name}</b>`, `<div class="stats" style="margin-bottom:12px">
    <div class="card stat"><div class="l">Problems caught</div><div class="v" style="color:${r.caught === r.planted ? 'var(--good)' : 'var(--warn)'}">${r.caught} / ${r.planted}</div><div class="s">${before ? `was ${before.caught} / ${before.planted}` : `${r.held} held outright`}</div></div>
    <div class="card stat"><div class="l">False alarms</div><div class="v">${r.falseAlarms}</div><div class="s">${pct(r.falseAlarmRate)} of clean records${before ? `; was ${before.falseAlarms}` : ''}</div></div>
    <div class="card stat"><div class="l">Records to review</div><div class="v">${r.flagged}</div><div class="s">of ${r.records} (${pct(r.flagRate)})</div></div>
    <div class="card stat"><div class="l">Missed</div><div class="v" style="color:${r.missed.length ? 'var(--bad)' : 'var(--good)'}">${r.missed.length}</div><div class="s">${r.missed.length ? r.missed.map((m) => SHORT[m.type]).filter((v, i, a) => a.indexOf(v) === i).join(', ') : 'none'}</div></div></div>
    <div class="card"><div class="tblwrap"><table class="g" style="min-width:600px"><thead><tr><th>Hidden problem</th><th>Kind</th><th class="num-r">Caught</th><th>Result</th></tr></thead><tbody>${rows}</tbody></table></div>${note}</div>${extra}`);
}

export function extraActions(h) {
  const { S, render, go, addLog } = h;
  return {
    cmp(k) { S.d.mode = k; if (k === 'with') S.d.seenWith = true; addLog(k === 'with' ? 'Switched to: with PayShield' : 'Switched to: without PayShield'); render(); },
    acceptPromo() { S.d.accepted = true; addLog('Grace Tan accepted: promotion, not yet recorded (remembered for 3 runs)'); render(); },
    approveSug() { S.d.approved = true; addLog('Suggestion approved: ask for a reason code on salary changes'); render(); },
    runV1() { S.d.v1 = runTest().v1; addLog(`Test run, first design: caught ${S.d.v1.caught} of ${S.d.v1.planted}; ${S.d.v1.falseAlarms} false alarms`); go(1); },
    runV2() { S.d.v2 = runTest().v2; addLog(`Test run, current design: caught ${S.d.v2.caught} of ${S.d.v2.planted}; ${S.d.v2.falseAlarms} false alarms`); go(2); },
    runMany() {
      if (S.d.busy) return; S.d.busy = true; render();
      setTimeout(() => { S.d.many = runMany({ runs: 50 }); S.d.busy = false; addLog(`50 companies: current design caught ${S.d.many.v2.caughtAvg.toFixed(0)} of 25 on average`); go(3); }, 30);
    },
  };
}

export function extraNextBlocked(S) {
  const d = S.d, s = S.step;
  if (S.sc === 'compare') return (s === 0 && !d.seenWith) || s === 1;
  if (S.sc === 'learn') return (s === 0 && !d.accepted) || s === 3;
  if (S.sc === 'proof') return (s === 0 && !d.v1) || (s === 1 && !d.v2) || (s === 2 && !d.many) || s === 3;
  return null;
}
