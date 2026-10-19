// Scenario: "Pre-flight check" — step-by-step verification of a 5-employee pay run, fixes, then a successful pay run.
import { CHECKS, EMPLOYEES, checkEmployee, evidence } from './preflight.js';

const esc = (s) => String(s ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
const money = (n) => 'S$' + Number(n).toLocaleString('en-SG');
const TOTAL = EMPLOYEES.length * CHECKS.length;
const PAY_STAGES = ['Locking 5 records', 'Calculating CPF and SDL', 'Generating 5 payslips', 'Creating the bank file', 'Sending to the bank'];
const ICON = { ok: '✓', warn: '!', fail: '✕', fixed: '✓', run: '', pend: '' };
const LABEL = { ok: 'passed', warn: 'needs review', fail: 'failed', fixed: 'fixed', run: 'checking', pend: 'waiting' };
const statusTag = (st, sc) => st === 'held' ? `<span class="tag t-r">${sc} · Held</span>` : st === 'review' ? `<span class="tag t-o">${sc} · Review</span>` : st === 'fixed' ? '<span class="tag t-g">Fixed · ready</span>' : `<span class="tag t-g">${sc} · Clear</span>`;

let timer = null;
const EV = Object.fromEntries(EMPLOYEES.map((e) => [e.id, evidence(e)]));
/** One parameter line: name, the value found (highlighted), the limit, the effect. */
const paramLine = (p, ck) => `<li class="pf-param ${p.hit ? 'hit' : ''}">${ck ? `<span class="pf-ck">${ck}</span>` : ''}<span class="pf-pl">${esc(p.label)}</span> <span class="pv">${esc(p.value)}</span> <span class="pf-lim">limit: ${esc(p.limit)}</span>${p.effect && p.effect !== '—' ? ` <span class="pf-eff">${esc(p.effect)}</span>` : ''}</li>`;
const hitParams = (id) => CHECKS.flatMap(([k, t]) => EV[id][k].filter((p) => p.hit).map((p) => [p, t]));
const stop = () => { if (timer) { clearInterval(timer); timer = null; } };

function bar(pct, label, tone = 'accent') {
  return `<div class="pf-bar" role="progressbar" aria-valuemin="0" aria-valuemax="100" aria-valuenow="${Math.round(pct)}" aria-label="${esc(label)}"><i style="width:${pct.toFixed(1)}%;background:var(--${tone})"></i></div>`;
}

export function extra4Scenarios(h) {
  const { app, S, stepper } = h;
  const R = () => S.d.results;
  const cellState = (ei, ci) => {
    const d = S.d, idx = ei * CHECKS.length + ci, key = CHECKS[ci][0], e = EMPLOYEES[ei];
    if (idx >= d.cursor) return idx === d.cursor && d.running ? 'run' : 'pend';
    const v = R()[e.id].checks[key];
    return d.fixed[e.id] && v !== 'ok' ? 'fixed' : v;
  };
  const empDone = (ei) => S.d.cursor >= (ei + 1) * CHECKS.length;
  const rowStatus = (e) => S.d.fixed[e.id] ? 'fixed' : R()[e.id].status;
  const ready = () => EMPLOYEES.filter((e) => ['clear', 'fixed'].includes(rowStatus(e))).length;
  const flagged = () => EMPLOYEES.filter((e) => R()[e.id].status !== 'clear');

  const table = () => `<div class="card"><div class="tblwrap"><table class="g pf-table" style="min-width:760px"><thead><tr><th style="width:24%">Employee</th>${CHECKS.map(([, t, d]) => `<th title="${esc(d)}" style="text-align:center">${t}</th>`).join('')}<th>Trust Score</th></tr></thead><tbody>
    ${EMPLOYEES.map((e, ei) => `<tr class="${S.d.current === ei ? 'hl' : ''}"><td><div style="display:flex;gap:10px;align-items:center"><span class="pf-av">${e.ini}</span><div><b>${e.name}</b><div class="small muted">${e.role}</div></div></div></td>
      ${CHECKS.map((c, ci) => { const s = cellState(ei, ci); return `<td style="text-align:center"><span class="pf-chip s-${s}" title="${esc(c[1])}: ${LABEL[s]}" aria-label="${esc(c[1])}: ${LABEL[s]}">${ICON[s]}</span></td>`; }).join('')}
      <td>${empDone(ei) ? statusTag(rowStatus(e), R()[e.id].score) : '<span class="small muted">…</span>'}</td></tr>
      ${S.d.showParams && empDone(ei) ? `<tr class="pf-prow"><td colspan="${CHECKS.length + 2}"><ul class="pf-params">${hitParams(e.id).length ? hitParams(e.id).map(([p, t]) => paramLine(p, t)).join('') : [['pay', 'Pay calculation'], ['bank', 'Bank details'], ['rules', 'Statutory rules']].map(([k, t]) => paramLine(EV[e.id][k][0], t)).join('')}</ul></td></tr>` : ''}`).join('')}</tbody></table></div>
    <div class="pf-legend small muted"><button class="btn sm" data-act="pfParams" aria-pressed="${!!S.d.showParams}" style="margin-right:10px">${S.d.showParams ? 'Hide parameters' : 'Show parameters'}</button><span class="pf-chip s-ok">✓</span> passed <span class="pf-chip s-warn">!</span> review <span class="pf-chip s-fail">✕</span> failed <span class="pf-chip s-fixed">✓</span> fixed</div></div>`;

  return {
    preflight: {
      label: 'Pre-flight check', who: '5 employees, step by step',
      title: 'Pre-flight check: is this pay run safe to pay?', sub: 'PayShield verifies each of 5 employees in 6 checks. Problems are fixed one by one, and the pay run goes through only when every record is ready.',
      init() { stop(); S.d = { showParams: false, results: Object.fromEntries(EMPLOYEES.map((e) => [e.id, checkEmployee(e)])), cursor: 0, running: false, current: null, fixed: {}, fixing: null, payStage: -1 }; },
      steps: [
        { t: 'Start the pre-flight check', you: 'Click <b>Run pre-flight check</b>.', sys: 'Nothing is paid yet. PayShield will check every employee before the pay run can be approved.',
          screen: () => app('Pay Run › September 2026 › <b>Pre-flight check</b>', stepper(3) + `<div class="card" style="padding:16px">
            <div style="display:flex;justify-content:space-between;align-items:flex-start;gap:12px;flex-wrap:wrap"><div><b style="font-size:15px">Sales &amp; Operations team · 5 employees</b><div class="small muted" style="margin-top:2px">September 2026 · pay date 30 Sep · gross ${money(EMPLOYEES.reduce((a, e) => a + e.pay, 0))}</div></div><span class="tag t-n">Not checked yet</span></div>
            <div class="pf-checks">${CHECKS.map(([, t, d], i) => `<div class="pf-check"><span class="pf-num">${i + 1}</span><div><b>${t}</b><div class="small muted">${d}</div></div></div>`).join('')}</div>
            <div style="display:flex;justify-content:flex-end;margin-top:14px"><button class="btn p pulse" data-act="pfRun">Run pre-flight check</button></div></div>`) },
        { t: 'Checks run employee by employee', you: 'Watch each check, then click <b>Fix the issues</b>.', sys: 'Each employee goes through 6 checks. The Trust Score comes from the real scoring code; the AI check uses our own model v1.',
          screen: () => { const d = S.d, pct = d.cursor / TOTAL * 100, done = d.cursor >= TOTAL;
            const cur = !done && d.current != null ? `Checking <b>${EMPLOYEES[d.current].name}</b> · ${CHECKS[d.cursor % CHECKS.length][1]}` : '';
            const f = flagged(), held = f.filter((e) => R()[e.id].status === 'held').length;
            return app('Pay Run › September 2026 › <b>Pre-flight check</b>', stepper(3) + `<div class="card" style="padding:14px 16px;margin-bottom:12px">
              <div style="display:flex;justify-content:space-between;gap:10px;flex-wrap:wrap;margin-bottom:8px"><b>${done ? 'Pre-flight complete' : 'Pre-flight running…'}</b><span class="small muted">${d.cursor} of ${TOTAL} checks · ${Math.round(pct)}%</span></div>
              ${bar(pct, 'Pre-flight progress', done ? 'good' : 'accent')}<div class="small muted" style="margin-top:8px;min-height:18px">${done ? `<b style="color:var(--ink)">${EMPLOYEES.length - f.length} clear · ${f.length - held} to review · ${held} held.</b> The pay run cannot be approved until these are resolved.` : cur}</div></div>
              ${table()}${done ? `<div style="display:flex;justify-content:flex-end;margin-top:12px"><button class="btn p pulse" data-act="next">Fix the ${f.length} issues</button></div>` : ''}`); } },
        { t: 'Fix what was found', you: 'Click the fix on each card. Each employee is checked again.', sys: 'A fix is applied and that employee is re-checked. The pay run unlocks only when all 5 are ready.',
          screen: () => { const d = S.d, n = ready(), all = n === EMPLOYEES.length;
            return app('Pay Run › September 2026 › <b>Pre-flight check</b>', stepper(3) + `<div class="card" style="padding:14px 16px;margin-bottom:12px">
              <div style="display:flex;justify-content:space-between;gap:10px;flex-wrap:wrap;margin-bottom:8px"><b>Ready to pay: ${n} of ${EMPLOYEES.length}</b><span class="small muted">${all ? 'All records ready' : `${EMPLOYEES.length - n} still need a decision`}</span></div>${bar(n / EMPLOYEES.length * 100, 'Ready to pay', all ? 'good' : 'accent')}</div>
              <div class="pf-issues">${flagged().map((e) => { const r = R()[e.id], fx = d.fixed[e.id], busy = d.fixing === e.id, ck = CHECKS.find(([k]) => k === e.issue.check);
                return `<div class="card pf-issue ${fx ? 'done' : ''}"><div style="display:flex;justify-content:space-between;gap:8px;align-items:center"><div style="display:flex;gap:10px;align-items:center"><span class="pf-av">${e.ini}</span><div><b>${e.name}</b><div class="small muted">${ck[1]}</div></div></div>${fx ? '<span class="tag t-g">Fixed · ready</span>' : statusTag(r.status, r.score)}</div>
                <p class="small" style="margin:10px 0 4px"><b>${esc(e.issue.title)}</b></p><div class="pf-pbox"><div class="pf-ptitle">Parameters checked</div><ul class="pf-params">${hitParams(e.id).map(([p]) => paramLine(p)).join('')}</ul></div><p class="small" style="margin:0;color:${fx ? 'var(--good)' : 'var(--bad)'}">${fx ? esc(e.issue.after) : 'Risk: ' + esc(e.issue.risk)}</p>
                ${fx ? '' : `<button class="btn ${busy ? '' : 'p pulse'}" style="margin-top:10px;width:100%" data-act="pfFix:${e.id}" ${busy || d.fixing ? 'disabled' : ''}>${busy ? 'Re-checking…' : esc(e.issue.fix)}</button>`}</div>`; }).join('')}</div>
              ${table()}${all ? `<div style="display:flex;justify-content:flex-end;margin-top:12px"><button class="btn p pulse" data-act="next">Continue to approval</button></div>` : ''}`); } },
        { t: 'Approve and run payroll', you: 'Click <b>Approve and run payroll</b>.', sys: 'Every record has passed or been fixed, so the approver can run the pay run. Each stage is logged.',
          screen: () => { const d = S.d, total = EMPLOYEES.reduce((a, e) => a + (e.fixedPay ?? e.pay), 0), st = d.payStage;
            return app('Pay Run › September 2026 › <b>Approve</b>', stepper(st >= 0 ? 4 : 4) + `<div class="split"><div class="card" style="padding:16px">
              <b style="font-size:15px">Ready to pay</b><div class="small muted" style="margin:2px 0 12px">5 of 5 records passed or fixed · gross ${money(total)}</div>
              <table class="g" style="min-width:0"><tbody>${EMPLOYEES.map((e) => `<tr><td><b>${e.name}</b></td><td class="num-r">${money(e.fixedPay ?? e.pay)}</td><td>${S.d.fixed[e.id] ? '<span class="tag t-g">Fixed</span>' : '<span class="tag t-g">Clear</span>'}</td></tr>`).join('')}</tbody></table></div>
              <div class="card" style="padding:16px;display:flex;flex-direction:column;gap:10px"><b style="font-size:15px">Run payroll</b>
              ${st < 0 ? `<p class="small muted" style="margin:0">Approver: Kevin Lim. Every hold and fix is in the audit log.</p><button class="btn p pulse" data-act="pfPay">Approve and run payroll</button>`
                : `${bar(Math.min(100, (st + 1) / PAY_STAGES.length * 100), 'Pay run progress')}<ol class="pf-stages">${PAY_STAGES.map((t, i) => `<li class="${i < st ? 'done' : i === st ? 'on' : ''}"><span>${i < st ? '✓' : i + 1}</span>${t}</li>`).join('')}</ol>`}</div></div>`, 'Pay Run', 'KL', 'Approver'); } },
        { t: 'Pay run successful', you: 'Done. Pick another scenario from the PayShield menu, or replay.', sys: 'Salaries are sent, payslips are out, and the full trail of checks and fixes is saved for audit.',
          screen: () => { const total = EMPLOYEES.reduce((a, e) => a + (e.fixedPay ?? e.pay), 0), saved = EMPLOYEES.reduce((a, e) => a + (e.issue?.saved || 0), 0);
            return app('Pay Run › September 2026 › <b>Done</b>', stepper(6) + `<div class="card pf-success"><div class="pf-big">✓</div><div><h3 style="margin:0;font-size:20px">Pay run successful</h3><p style="margin:4px 0 0">${money(total)} paid to 5 employees on 30 Sep. Every record passed or was fixed before payday.</p></div></div>
              <div class="stats" style="margin:12px 0">
               <div class="card stat"><div class="l">Kept from being paid wrongly</div><div class="v" style="color:var(--good)">${money(saved)}</div><div class="s">hijack, OT, CPF, salary creep</div></div>
               <div class="card stat"><div class="l">Issues fixed before payday</div><div class="v">4</div><div class="s">0 found after payday</div></div>
               <div class="card stat"><div class="l">Checks run</div><div class="v">${TOTAL}</div><div class="s">6 per employee</div></div>
               <div class="card stat"><div class="l">Audit trail</div><div class="v">Saved</div><div class="s">who checked, fixed, approved</div></div></div>
              <div class="card"><div class="tblwrap"><table class="g" style="min-width:560px"><thead><tr><th>Employee</th><th class="num-r">Paid</th><th>Bank</th><th>What PayShield did</th></tr></thead><tbody>
              ${EMPLOYEES.map((e) => `<tr><td><b>${e.name}</b></td><td class="num-r">${money(e.fixedPay ?? e.pay)}</td><td class="small">${e.id === 'daniel' ? 'OCBC ···· 2209 (usual)' : 'Usual account'}</td><td class="small">${e.issue ? esc(e.issue.after) : 'All 6 checks passed'}</td></tr>`).join('')}</tbody></table></div></div>
              <div style="display:flex;gap:8px;margin-top:12px;flex-wrap:wrap"><button class="btn" data-act="restart">Replay</button><button class="btn" data-act="go:compare">Compare: without PayShield</button></div>`); } },
      ],
    },
  };
}

export function extra4Actions(h) {
  const { S, render, go, addLog, reduce } = h;
  return {
    pfRun() {
      if (S.d.running) return;
      go(1); S.d.running = true; S.d.current = 0; addLog('Pre-flight check started: 5 employees × 6 checks');
      const step = () => {
        if (S.sc !== 'preflight') { stop(); return; }
        S.d.cursor++;
        const ei = Math.floor(S.d.cursor / CHECKS.length);
        if (S.d.cursor % CHECKS.length === 0) { const e = EMPLOYEES[ei - 1], r = S.d.results[e.id]; addLog(`${e.name}: ${r.status === 'clear' ? 'all checks passed' : r.status === 'held' ? 'held' : 'needs review'} (score ${r.score})`); }
        S.d.current = ei < EMPLOYEES.length ? ei : null;
        if (S.d.cursor >= TOTAL) { stop(); S.d.running = false; addLog('Pre-flight complete: 1 clear, 4 need a decision'); }
        if (S.step === 1) render();
      };
      stop();
      if (reduce) { while (S.d.cursor < TOTAL) step(); return; }
      timer = setInterval(step, 140);
    },
    pfParams() { S.d.showParams = !S.d.showParams; render(); },
    pfFix(id) {
      if (S.d.fixing || S.d.fixed[id]) return;
      const e = EMPLOYEES.find((x) => x.id === id); if (!e) return;
      S.d.fixing = id; render();
      setTimeout(() => {
        if (S.sc !== 'preflight') return;
        S.d.fixed[id] = true; S.d.fixing = null;
        addLog(`${e.name}: ${e.issue.after} Re-checked: ready.`);
        render();
      }, reduce ? 0 : 900);
    },
    pfPay() {
      if (S.d.payStage >= 0) return;
      S.d.payStage = 0; addLog('Kevin L. approved the September pay run'); render();
      stop();
      timer = setInterval(() => {
        if (S.sc !== 'preflight') { stop(); return; }
        S.d.payStage++;
        if (S.d.payStage >= 5) { stop(); addLog('Pay run successful: S$30,590 sent to 5 employees'); go(4); return; }
        render();
      }, reduce ? 10 : 650);
    },
  };
}

export function extra4NextBlocked(S) {
  if (S.sc !== 'preflight') return null;
  const d = S.d, s = S.step;
  const allReady = EMPLOYEES.every((e) => checkEmployeeStatus(d, e));
  return (s === 0 && d.cursor === 0) || (s === 1 && d.cursor < TOTAL) || (s === 2 && !allReady) || s === 3 || s === 4;
}
function checkEmployeeStatus(d, e) { return d.fixed[e.id] || d.results[e.id].status === 'clear'; }
