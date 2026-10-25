// Times Intelligence: subscription, ML anomaly detection and per-company model training.
// Talks to the PayShield AI service (Python, "times-intelligence/payshield-ai") through the Vite proxy (/api, /dev).
import { ICON, statCard } from './chrome.js';

const env = import.meta.env || {};
const H = {
  'X-PayShield-Service-Key': env.VITE_TI_KEY || 'local-demo-only-secret',
  'X-Tenant-Uid': env.VITE_TI_TENANT || '5ab1c0de-0000-4000-8000-0000000000aa',
  'X-Company-Uid': env.VITE_TI_COMPANY || 'c4a1e7f0-0000-4000-8000-00000000c4a1',
  'Content-Type': 'application/json',
};
const esc = (s) => String(s ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
const num = (v) => (v == null ? '—' : Number(v).toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 }));
const SEV = { CRITICAL: 't-r', HIGH: 't-r', MEDIUM: 't-o', LOW: 't-b' };
const QUESTIONS = ['What are the highest-risk payroll anomalies this month?', 'How many employees have unusual overtime?', 'Which employees had a salary change without a revision?'];
const TRAIN_STEPS = [['Load payroll history', 'Approved pay records, own company only'], ['Build features', 'Each month vs the employee’s own prior months'],
  ['Train detectors', 'Isolation Forest + robust baseline'], ['Evaluate', 'Injected anomalies: recall and false-alert rate'], ['Register model', 'Quality gate, version, activate']];

async function api(path, opts = {}) {
  const r = await fetch(path, { headers: H, ...opts });
  const b = await r.json().catch(() => ({}));
  if (!r.ok) throw new Error(`${r.status} ${b.code || ''} ${b.detail || ''}`.trim());
  return b;
}

export function intelligence({ S, render, openPage }) {
  const T = (S.ti = { sub: null, status: null, versions: [], runs: [], run: '', analysis: null, answer: null, injected: null, step: -1, busy: '', err: '', loaded: {} });
  const toast = (html) => { S.toast = { html }; };
  async function act(name, fn) {
    if (T.busy) return;
    T.busy = name; T.err = ''; render();
    try { await fn(); } catch (e) { T.err = e.message; } finally { T.busy = ''; render(); }
  }
  const btn = (act, label, primary, name = act) => `<button class="btn sm ${primary ? 'p' : ''}" data-act="${act}" ${T.busy ? 'disabled' : ''}>${T.busy === name ? 'Working…' : label}</button>`;
  const errBox = () => (T.err ? `<div class="card" style="border-color:var(--bad);color:var(--bad)">${esc(T.err)}</div>` : '');
  const lazy = (k, fn) => { if (!T.loaded[k]) { T.loaded[k] = true; fn().catch((e) => { T.err = e.message; }).finally(render); } };

  const loadModel = async () => { T.status = await api('/api/v1/models/status'); T.versions = (await api('/api/v1/models/versions')).models; };
  const loadRuns = async (select) => { T.runs = await (await fetch('/dev/runs')).json(); T.run = select || T.run || T.runs[0]?.uid || ''; };

  /* ---------- pages ---------- */
  function subscribeBody() {
    if (!T.sub) return `${errBox()}<div class="card muted">Checking subscription… (is the PayShield AI service running on :8080?)</div>`;
    const on = T.sub.subscribed;
    return `${errBox()}<div class="card" style="max-width:720px">
      <div class="ps-ih"><span class="kpi-ic">${ICON.spark}</span><div><b>Times Intelligence</b><div class="small muted">ML anomaly detection trained on your own payroll history, one model per company.</div></div>
      <div class="ps-ir"><span class="tag ${on ? 't-g' : 't-n'}">${on ? 'Subscribed' : 'Not subscribed'}</span></div></div>
      <ul class="small" style="margin:12px 0 14px 18px;line-height:1.7">
        <li><b>Anomaly detection</b>: every pay record compared with the employee's own history, plus 17 deterministic payroll rules.</li>
        <li><b>Train model</b>: train, evaluate and roll back your company model.</li>
        <li><b>Assistant</b>: read-only questions about the findings.</li></ul>
      ${on ? `<p class="small muted">Subscribed ${esc((T.sub.subscribedOn || '').slice(0, 10))}${T.sub.subscribedBy ? ' by ' + esc(T.sub.subscribedBy) : ''}.</p>${btn('tiUnsubscribe', 'Unsubscribe')}`
        : btn('tiSubscribe', 'Subscribe to Times Intelligence', true)}</div>`;
  }


  function progressPanel() {
    if (T.step === -1 || T.step == null) return '';
    const done = T.step === 99, pct = T.pct || 0, C = 2 * Math.PI * 52;
    const col = T.failed ? '#dc2626' : done ? '#16a34a' : '#7c3aed';
    const secs = done ? T.secs : (Date.now() - T.t0) / 1000;
    const ring = `<div class="tr-ring"><svg viewBox="0 0 120 120"><defs><linearGradient id="trg" x1="0" x2="1"><stop offset="0" stop-color="#6366f1"/><stop offset="1" stop-color="${col}"/></linearGradient></defs>
      <circle cx="60" cy="60" r="52" stroke="#ede9fe" stroke-width="10" fill="none"/>
      <circle cx="60" cy="60" r="52" stroke="url(#trg)" stroke-width="10" fill="none" stroke-linecap="round" stroke-dasharray="${C}" stroke-dashoffset="${C * (1 - pct / 100)}" transform="rotate(-90 60 60)" class="tr-arc"/></svg>
      <div class="tr-mid"><b style="color:${col}">${T.failed ? '✕' : pct + '%'}</b><small>${T.failed ? 'failed' : done ? 'trained in ' + secs.toFixed(1) + 's' : secs.toFixed(0) + 's elapsed'}</small></div></div>`;
    const list = TRAIN_STEPS.map(([t, d], i) => { const st = done || T.step > i ? 'ok' : T.step === i ? (T.failed ? 'bad' : 'run') : 'wait';
      return `<div class="tr-st ${st}"><span class="tr-ic">${st === 'ok' ? '✓' : st === 'bad' ? '✕' : st === 'run' ? '' : i + 1}</span><div><b>${t}</b><small>${d}</small></div></div>`; }).join('');
    return `<div class="tr-wrap">${ring}<div class="tr-list">${list}</div></div>`;
  }

  function onboardBody() {
    const n = ['Load payroll history', 'Learn each employee’s normal pay', 'Unlock PayShield'];
    return `${errBox()}<div class="card" style="text-align:center;padding:40px 24px">
      <div style="font-size:42px">🧠</div><h3 style="margin:8px 0 4px;font-size:20px">Train your model</h3>
      <p class="muted" style="max-width:520px;margin:0 auto 18px">You're subscribed. Before PayShield can check pay runs, it needs to learn your company's own payroll history. This takes under a minute and uses only your data.</p>
      <div style="display:flex;gap:10px;justify-content:center;flex-wrap:wrap;margin-bottom:22px">${n.map((x, i) => `<span class="tag t-b">${i + 1}. ${x}</span>`).join('')}</div>
      <button class="btn p" data-act="page:tiTrain">Train your model →</button></div>`;
  }

  function trainBody() {
    lazy('model', loadModel);
    const m = T.status?.activeModel, j = T.status?.latestJob, ev = m?.evaluationMetrics, d = ev?.detectors || {};
    const steps = progressPanel();
    const model = !m ? `<div class="card muted">No active model yet${j ? ` (last job ${esc(j.status)})` : ''}. Click <b>Train model</b>.</div>` : `
      <div class="kpis" style="display:grid;grid-template-columns:repeat(4,minmax(0,1fr));gap:12px">
        ${statCard(ICON.chart, 'Active model', 'v' + m.modelVersion, esc(m.detector.replace('_', ' ')))}
        ${statCard(ICON.users, 'Training records', m.trainingRecordCount.toLocaleString(), 'employee-months')}
        ${statCard(ICON.calendar, 'Training period', m.trainingPeriodStart.slice(0, 7), 'to ' + m.trainingPeriodEnd.slice(0, 7))}
        ${statCard(ICON.clock, 'Training time', j?.durationMs ? (j.durationMs / 1000).toFixed(1) + 's' : '—', esc(j?.status || ''))}</div>
      <div class="card" style="margin-top:12px"><b>Detector evaluation</b><div class="tblwrap"><table class="g" style="margin-top:8px"><tr><th>Detector</th><th>ROC-AUC</th><th>Recall at alert</th><th>False alerts on clean data</th></tr>
        ${Object.entries(d).map(([k, v]) => `<tr><td>${k === ev.champion ? '✓ <b>' + k + '</b>' : k}</td><td>${v.roc_auc}</td><td>${(v.recall_at_alert * 100).toFixed(1)}%</td><td>${(v.clean_alert_rate * 100).toFixed(1)}%</td></tr>`).join('')}</table></div>
        <p class="small muted">Evaluated on ${ev.n_validation_rows} clean rows + ${ev.n_injected} injected anomalies. Gate: ${esc(j?.gate?.reason)}.</p></div>`;
    const vers = T.versions.length ? `<div class="tblwrap"><table class="g"><tr><th>Version</th><th>Status</th><th>Detector</th><th>Records</th><th>Trained</th><th></th></tr>${T.versions.map((x) => `<tr><td>${x.modelVersion}</td><td>${esc(x.status)}</td><td>${esc(x.detector)}</td><td>${x.trainingRecordCount}</td><td>${esc(x.trainingCompletedAt.slice(0, 16).replace('T', ' '))}</td><td>${x.status !== 'ACTIVE' && x.status !== 'REJECTED' ? `<button class="linkbtn" data-act="tiActivate:${x.modelId}">Roll back to this</button>` : ''}</td></tr>`).join('')}</table></div>` : '<span class="small muted">No models yet.</span>';
    return `${errBox()}<div class="card"><div class="ps-ih"><div><b>Train your company model</b><div class="small muted">Uses this company's own payroll history only. A new model is activated only if it passes the quality gate.</div></div><div class="ps-ir">${btn('tiTrain', 'Train model', true)}</div></div>${steps}</div>
      <div style="margin-top:12px">${model}</div><div class="card" style="margin-top:12px"><b>Model versions</b><div style="margin-top:8px">${vers}</div></div>`;
  }

  function anomalyBody() {
    lazy('runs', () => loadRuns());
    const a = T.analysis;
    const res = !a ? '' : `<div class="kpis" style="display:grid;grid-template-columns:repeat(4,minmax(0,1fr));gap:12px;margin-top:12px">
        ${statCard(ICON.users, 'Checked', a.totalEmployees, 'employees in ' + esc(a.payrollPeriod))}
        ${statCard(ICON.alert, 'Flagged', a.flaggedEmployees, a.anomalyCount + ' findings')}
        ${statCard(ICON.shield, 'Highest severity', esc(a.maxSeverity || '—'), esc(a.status))}
        ${statCard(ICON.chart, 'Model', a.modelVersion ? 'v' + a.modelVersion : 'none', 'ML ' + esc(a.mlStatus))}</div>
      ${a.warnings.length ? `<p class="small muted">${a.warnings.map(esc).join('; ')}</p>` : ''}
      <div class="card" style="margin-top:12px"><b>Findings</b><div class="tblwrap"><table class="g" style="margin-top:8px"><tr><th>Severity</th><th>Risk</th><th>Employee</th><th>Type</th><th>Finding</th><th>Current</th><th>Expected</th></tr>
      ${a.anomalies.map((x) => `<tr><td><span class="tag ${SEV[x.severity] || 't-n'}">${x.severity}</span></td><td><b>${x.riskScore}</b></td><td>${esc(x.employeeNo)}</td>
        <td>${esc(x.anomalyType.replaceAll('_', ' '))}<div class="small muted">${esc(x.source)}${x.ruleId ? ' · ' + esc(x.ruleId) : ''}</div></td>
        <td>${esc(x.description)}<div class="small muted">→ ${esc(x.recommendedAction)}</div></td><td>${num(x.currentValue)}</td><td>${num(x.expectedValue)}</td></tr>`).join('')}</table></div></div>
      <div class="card" style="margin-top:12px"><div class="ps-ih"><span class="kpi-ic">${ICON.bot}</span><b>Ask about these findings</b></div>
        <div style="display:flex;gap:8px;flex-wrap:wrap;margin:10px 0">${QUESTIONS.map((q, i) => `<button class="btn sm" data-act="tiAsk:${i}" ${T.busy ? 'disabled' : ''}>${esc(q)}</button>`).join('')}</div>
        ${T.answer ? `<div class="small" style="white-space:pre-wrap"><span class="tag t-b">${esc(T.answer.status)}</span> ${esc(T.answer.answer)}</div>` : ''}</div>`;
    return `${errBox()}<div class="card"><div class="ps-ih"><div><b>AI anomaly detection</b><div class="small muted">Rules + your company's model, checked against each employee's own pay history.</div></div></div>
      <div style="display:flex;gap:8px;flex-wrap:wrap;align-items:center;margin-top:10px">
        <select id="tiRunSel" style="min-width:280px;padding:6px">${T.runs.map((r) => `<option value="${r.uid}" ${r.uid === T.run ? 'selected' : ''}>${esc(r.name)} · ${esc(r.period)} · ${r.records} employees</option>`).join('')}</select>
        ${btn('tiAnalyze', 'Analyse pay run', true)}${T.ctx && !T.ctx.demo ? '' : btn('tiInject', '+ Test run with anomalies')}</div>
      ${T.injected ? `<p class="small muted" style="margin-top:8px">Test run ${esc(T.injected.period)} created. Injected: ${T.injected.injected.map((i) => `<span class="tag t-n">${esc(i.employeeNo)} · ${esc(i.scenario)}</span>`).join(' ')}</p>` : ''}</div>${res}`;
  }


  /* ---------- Times portal shell (same look as times-intelligence/payshield-ai/prototype/portal.html) ---------- */
  const CSS = `body.tp-mode{background:#f5f6f8}body.tp-mode .hdr,body.tp-mode .foot,body.tp-mode .ps-bar,body.tp-mode #guide{display:none}
  body.tp-mode .wrap{max-width:none;padding:0;margin:0}body.tp-mode .grid{display:block;padding:0;margin:0}
  .tp{display:flex;min-height:100vh;font:13px/1.45 "Segoe UI",system-ui,sans-serif;color:#1d2330;background:#f5f6f8;text-align:left}
  .tp aside{width:248px;background:#fff;border-right:1px solid #e5e7eb;display:flex;flex-direction:column;flex-shrink:0}
  .tp .co{display:flex;gap:10px;align-items:center;padding:18px 14px 14px;font-weight:600;font-size:15px;line-height:1.15}
  .tp .co i{width:30px;height:30px;border-radius:6px;background:linear-gradient(135deg,#f59e0b,#b45309);flex-shrink:0}
  .tp .plan{padding:8px 14px;font-size:11px;color:#6b7280;font-weight:600}
  .tp .sec{padding:16px 14px 6px;font-size:11px;font-weight:700;color:#374151;letter-spacing:.3px;display:flex;justify-content:space-between;align-items:center}
  .tp .sec.ti{color:#7c3aed}.tp .sub{padding:8px 14px 2px 22px;font-size:10.5px;font-weight:700;color:#9ca3af;text-transform:uppercase}
  .tp .new{background:#7c3aed;color:#fff;font-size:9px;padding:1px 5px;border-radius:4px}
  .tp a.it{display:flex;align-items:center;gap:10px;padding:8px 14px;margin:1px 6px;border-radius:6px;color:#1d2330;text-decoration:none;font-size:13.5px;cursor:pointer}
  .tp a.it:hover{background:#f3f4f6}.tp a.it.on{background:#eef2ff;font-weight:600}.tp a.it.dim{cursor:default;opacity:.85}
  .tp a.it svg{width:16px;height:16px;flex-shrink:0;color:#6b7280}.tp a.it .n{margin-left:auto;font-size:11px;font-weight:700;background:#fee2e2;color:#b91c1c;border-radius:99px;padding:0 7px}
  .tp .subbox{margin:16px 12px;padding:12px;border-radius:10px;background:linear-gradient(135deg,#ede9fe,#e0e7ff);border:1px solid #ddd6fe}
  .tp .subbox b{display:block;color:#4c1d95}.tp .subbox p{margin:4px 0 10px;color:#5b21b6;font-size:12px}
  .tp .tpbtn{width:100%;border-radius:7px;padding:8px 14px;font-weight:600;cursor:pointer;font-size:13px;background:#7c3aed;color:#fff;border:0}
  .tp .tpbtn.out{background:#fff;color:#dc2626;border:1px solid #fca5a5;margin:12px 12px 4px;width:calc(100% - 24px)}
  .tp .ft{margin-top:auto;padding:12px 14px;color:#6b7280;font-size:11px}.tp .ft button{background:none;border:0;color:#2f5bea;cursor:pointer;padding:0;font-size:11px}
  .tp main{flex:1;min-width:0}.tp .top{background:#fff;border-bottom:1px solid #e5e7eb;padding:12px 24px;display:flex;justify-content:space-between;align-items:center}
  .tp .who{display:flex;align-items:center;gap:10px}.tp .av{width:32px;height:32px;border-radius:50%;background:#cbd5e1;display:grid;place-items:center;font-weight:700}
  .tp .content{padding:20px 24px}.tp .content h2{margin:0 0 14px;font-size:20px}
  .tr-wrap{display:flex;gap:28px;align-items:center;margin-top:14px;flex-wrap:wrap}.tr-ring{position:relative;width:140px;height:140px;flex-shrink:0}
  .tr-ring svg{width:100%;height:100%}.tr-arc{transition:stroke-dashoffset 1.1s ease}.tr-mid{position:absolute;inset:0;display:grid;place-content:center;text-align:center}
  .tr-mid b{font-size:28px;line-height:1}.tr-mid small{color:#6b7280;font-size:11px;margin-top:4px}
  .tr-list{flex:1;min-width:260px;display:grid;gap:2px;position:relative}.tr-st{display:flex;gap:12px;align-items:flex-start;padding:6px 0;position:relative}
  .tr-st:not(:last-child):after{content:"";position:absolute;left:13px;top:34px;bottom:-8px;width:2px;background:#e5e7eb}.tr-st.ok:not(:last-child):after{background:#86efac}
  .tr-st b{display:block;font-size:13px}.tr-st small{color:#6b7280;font-size:11.5px}.tr-st.wait b{color:#9ca3af}
  .tr-ic{width:28px;height:28px;border-radius:50%;display:grid;place-items:center;font-size:12px;font-weight:700;flex-shrink:0;background:#f3f4f6;color:#9ca3af;border:2px solid #e5e7eb}
  .tr-st.ok .tr-ic{background:#16a34a;color:#fff;border-color:#16a34a}.tr-st.bad .tr-ic{background:#dc2626;color:#fff;border-color:#dc2626}
  .tr-st.run .tr-ic{border:3px solid #ede9fe;border-top-color:#7c3aed;background:#fff;animation:trspin .8s linear infinite}.tr-st.run b{color:#7c3aed}
  @keyframes trspin{to{transform:rotate(360deg)}}`;
  if (!document.getElementById('tp-css')) document.head.insertAdjacentHTML('beforeend', `<style id="tp-css">${CSS}</style>`);
  const DOT = '<svg viewBox="0 0 16 16"><circle cx="8" cy="8" r="3" fill="currentColor"/></svg>';
  const STATIC = { 'BASIC v5': ['Dashboard', 'Company Policy'], PRODUCT: ['EPM', 'Pay', 'Leave', 'IRAS', 'Claim', 'Query Builder'] };
  function shell(crumb, body, groups, active) {
    document.body.classList.add('tp-mode');
    const on = !!T.sub?.subscribed, trained = !!T.status?.activeModel;
    if (on && !trained && T.status && active !== 'tiTrain' && active !== 'tiOnboard') return shell(crumb, onboardBody(), groups, 'tiOnboard');
    const item = (it) => `<a class="it ${it.k === active ? 'on' : ''}" data-act="${it.act}">${ICON[it.icon] || DOT}<span>${esc(it.label)}</span>${it.count ? `<span class="n">${it.count}</span>` : ''}</a>`;
    const ti = on && !trained ? `<div class="sub">Get started</div>${item({ k: 'tiTrain', label: 'Train your model', icon: 'flask', act: 'page:tiTrain' })}<button class="tpbtn out" data-act="tiUnsubscribe" ${T.busy ? 'disabled' : ''}>Unsubscribe</button>`
      : on ? groups.map((g) => `<div class="sub">${esc(g.label)}</div>${g.items.map(item).join('')}`).join('')
      + `<button class="tpbtn out" data-act="tiUnsubscribe" ${T.busy ? 'disabled' : ''}>Unsubscribe</button>`
      : `<div class="subbox"><b>Times Intelligence</b><p>PayShield pay run assurance and ML anomaly detection trained on your own payroll.</p><button class="tpbtn" data-act="tiSubscribe" ${T.busy ? 'disabled' : ''}>${T.busy === 'tiSubscribe' ? 'Subscribing…' : 'Subscribe to Times Intelligence'}</button></div>`;
    const title = (crumb.match(/<b>(.*?)<\/b>/) || [, crumb])[1];
    return `<div class="tp"><aside><div class="co"><i></i>${esc(T.ctx?.companyName || 'CARLTON HOTEL (SINGAPORE) PTE LTD')}</div>
      ${Object.entries(STATIC).map(([h, xs]) => `<div class="${h === 'PRODUCT' ? 'sec' : 'plan'}">${h}</div>${xs.map((x) => `<a class="it dim">${DOT}<span>${x}</span></a>`).join('')}`).join('')}
      <div class="sec ti">TIMES INTELLIGENCE <span class="new">NEW</span></div>${ti}
      <div class="ft">Times Portal · ${esc(T.ctx?.database || 'prod-is-down')} · <button data-act="resetRun">reset demo data</button></div></aside>
      <main><div class="top"><div><div style="color:#6b7280">Welcome back, Thilanka Potter!</div><b>October, 2026</b></div>
      <div class="who"><span class="av">TP</span><div><b>Thilanka Potter</b><div style="color:#6b7280;font-size:11px">Payroll Admin</div></div></div></div>
      <div class="content"><h2>${!on ? 'Times Intelligence' : active === 'tiOnboard' ? 'Welcome to Times Intelligence' : title}</h2>${on || active === 'tiSubscribe' ? (on && !T.status ? '<div class="card muted">Checking your company model…</div>' : body) : subscribeBody()}</div></main></div>`;
  }

  const pages = {
    tiSubscribe: { crumb: 'Times Intelligence › <b>Subscription</b>', body: subscribeBody },
    tiAnomaly: { crumb: 'Times Intelligence › <b>AI anomaly detection</b>', body: anomalyBody },
    tiTrain: { crumb: 'Times Intelligence › <b>Train model</b>', body: trainBody },
  };
  const labels = { tiSubscribe: 'Times Intelligence', tiAnomaly: 'AI anomaly detection', tiTrain: 'Train model' };

  const menu = () => [{ label: 'AI model', items: T.sub?.subscribed ? [
    { k: 'tiAnomaly', label: 'AI anomaly detection', icon: 'spark', act: 'page:tiAnomaly', tag: '<span class="new">AI</span>' },
    { k: 'tiTrain', label: 'Train model', icon: 'flask', act: 'page:tiTrain' },
  ] : [] }];

  const actions = {
    tiSubscribe: () => act('tiSubscribe', async () => { T.sub = await api('/api/v1/intelligence/subscribe', { method: 'POST' }); await loadModel(); toast(T.status.activeModel ? '<b>✓ Successfully subscribed to Times Intelligence.</b>' : '<b>✓ Successfully subscribed.</b> Train your company model to unlock PayShield'); }),
    tiUnsubscribe: () => {
      if (!confirm('Unsubscribe from Times Intelligence? Trained models and past analyses are kept.')) return;
      act('tiUnsubscribe', async () => { T.sub = await api('/api/v1/intelligence/unsubscribe', { method: 'POST' }); T.analysis = T.answer = null; toast('Unsubscribed from Times Intelligence'); });
    },
    tiTrain: () => act('tiTrain', async () => {
      T.step = 0; T.pct = 0; T.t0 = Date.now(); T.failed = false; render();
      const job = await api('/api/v1/models/train', { method: 'POST', body: '{}' });
      for (let tick = 0; ; tick++) {
        const j = await api(`/api/v1/models/training-jobs/${job.jobId}`);
        if (!['QUEUED', 'RUNNING'].includes(j.status)) { T.failed = j.status !== 'SUCCEEDED'; T.step = T.failed ? T.step : 99; T.pct = T.failed ? T.pct : 100; T.secs = j.durationMs / 1000; toast(j.status === 'SUCCEEDED' && !T.status?.activeModel ? `<b>✓ Model trained in ${(j.durationMs / 1000).toFixed(1)}s.</b> Times Intelligence is unlocked — all PayShield menus are now available` : `Model training ${j.status.toLowerCase()} in ${(j.durationMs / 1000).toFixed(1)}s`); break; }
        T.pct = Math.min(96, Math.round(100 * (1 - Math.exp(-(tick + 1) / 7)))); T.step = Math.min(4, Math.floor(T.pct / 20)); render();
        await new Promise((r) => setTimeout(r, 1200));
      }
      await loadModel();
    }),
    tiActivate: (id) => act('tiActivate', async () => { await api(`/api/v1/models/${id}/activate`, { method: 'POST' }); toast('Model activated'); await loadModel(); }),
    tiInject: () => act('tiInject', async () => { T.injected = await (await fetch('/dev/inject-run', { method: 'POST' })).json(); await loadRuns(T.injected.payRunId); }),
    tiAnalyze: () => act('tiAnalyze', async () => { T.answer = null; T.analysis = await api('/api/v1/payroll/analyze', { method: 'POST', body: JSON.stringify({ payRunId: T.run }) }); }),
    tiAsk: (i) => act('tiAsk', async () => { T.answer = await api('/api/v1/assistant/ask', { method: 'POST', body: JSON.stringify({ question: QUESTIONS[+i], analysisId: T.analysis.analysisId }) }); }),
  };

  document.addEventListener('change', (e) => { if (e.target?.id === 'tiRunSel') T.run = e.target.value; });
  // the local API tells us which tenant/company it serves (run_local_db.py / run_portal_prototype.py)
  fetch('/dev/context').then((r) => (r.ok ? r.json() : null)).catch(() => null).then((ctx) => {
    if (ctx) { H['X-Tenant-Uid'] = ctx.tenantUid; H['X-Company-Uid'] = ctx.companyUid; T.ctx = ctx; }
    return api('/api/v1/intelligence/subscription'); }).then(async (s) => { T.sub = s; if (s.subscribed) { await loadModel(); T.loaded.model = true; } }).catch((e) => { T.err = e.message; }).finally(render);

  return { pages, labels, menu, actions, shell };
}
