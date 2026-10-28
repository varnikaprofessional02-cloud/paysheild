// Times Intelligence: subscription, ML anomaly detection and per-company model training.
// Talks to the PayShield AI service (Python, "times-intelligence/payshield-ai") through the Vite proxy (/api, /dev).
import { ICON, statCard } from './chrome.js';
import { payShield, PAYSHIELD_CSS, FAB_CSS } from './tiPayShield.js';

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
const QUESTIONS = ['What are the highest-risk payroll anomalies this month?', 'How many employees have unusual overtime?', 'Any identity issues?', 'Who has salary below 5000?', 'Top 10 highest paid', 'List all employees', 'Total payroll for the last 6 pay runs', 'Compare this pay run with last month', 'Is CPF due on share awards?', 'Which employees had a salary change without a revision?'];
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

  const loadModel = async () => { T.status = await api('/api/v1/models/status'); T.versions = (await api('/api/v1/models/versions')).models; PS.reset(); };
  const loadRuns = async (select) => { T.runs = (await api('/api/v1/pay-runs')).payRuns; T.run = select || T.run || T.runs[0]?.uid || ''; };

  /* ---------- pages ---------- */
  const hero = (ic, title, sub, right = '', tone = '') => `<div class="ti-hero ${tone}"><span class="ti-hic">${ic}</span><div class="ti-ht"><h3>${title}</h3><p>${sub}</p></div><div class="ti-hr">${right}</div></div>`;
  const panel = (title, sub, content, right = '') => `<section class="ti-panel"><header><div><h4>${title}</h4>${sub ? `<p>${sub}</p>` : ''}</div>${right}</header>${content}</section>`;
  const kpis = (xs) => `<div class="ti-kpis">${xs.map(([ic, l, v, s, tone]) => `<div class="ti-kpi ${tone || ''}"><span class="ti-kic">${ic}</span><div><small>${l}</small><b>${v}</b><em>${s}</em></div></div>`).join('')}</div>`;
  const cap = (x) => String(x || '').replace(/^./, (c) => c.toUpperCase());
  const AREA_LIST = [
    ['PAYROLL', 'Payroll', '💰', 'Pay anomalies per employee vs their own history (ML model + 17 payroll rules)', false],
    ['IDENTIFICATION', 'Identification', '🪪', 'Duplicate NRIC/FIN, shared bank accounts, work pass expiry, missing IDs, changes since training', false],
    ['ATTENDANCE', 'Attendance', '🕒', 'Clock-in patterns, buddy punching, missed clock-outs', true],
    ['EPM', 'EPM', '🗂', 'Employee records: job, grade and contract consistency', true],
    ['TIMESHEET', 'Timesheet', '📋', 'Hours vs roster, unusual overtime claims', true],
    ['CLAIMS', 'Claims', '🧾', 'Unusual expense claims vs the employee’s and team’s history', true]];
  const areaOf = (k) => (T.status?.areas || []).find((a) => a.area === k);
  const isTrained = (k) => (k === 'PAYROLL' ? !!T.status?.activeModel : !!areaOf(k));
  const PS = payShield({ api, isTrained, render, toast: (html) => { S.toast = { html }; }, go: (k) => openPage(k) });
  const anyTrained = () => AREA_LIST.some(([k]) => isTrained(k));
  T.sel = new Set(['PAYROLL', 'IDENTIFICATION']); T.areaRun = [];
  const bar = (p, tone = '') => `<span class="ti-bar ${tone}"><i style="width:${Math.max(0, Math.min(100, p))}%"></i></span>`;

  function subscribeBody() {
    if (!T.sub) return `${errBox()}<div class="ti-empty"><span class="tr-spin"></span><br><b>Connecting to Times Intelligence…</b><p>Is the PayShield AI service running on :8080?</p></div>`;
    const on = T.sub.subscribed;
    const feats = [[ICON.spark, 'AI anomaly detection', 'Every pay record compared with the employee’s own history, plus 17 deterministic payroll rules.'],
      [ICON.flask, 'Your own model', 'Trained only on your company’s payroll. Evaluate, version and roll back any time.'],
      [ICON.bot, 'Ask PayShield', 'Plain-language answers about the findings. Read-only; never changes payroll.']];
    const how = ['Subscribe', 'Train your model', 'Analyse each pay run', 'Review the findings'];
    return `${errBox()}${hero(ICON.spark, 'Times Intelligence', 'Catch payroll errors before money moves, with a model that learns how <b>your</b> company pays.',
      `<span class="ti-pill ${on ? 'ok' : ''}">${on ? '● Subscribed' : 'Not subscribed'}</span>`)}
      <div class="ti-feats">${feats.map(([i, t, d]) => `<div class="ti-feat"><span class="ti-kic">${i}</span><b>${t}</b><p>${d}</p></div>`).join('')}</div>
      ${panel('How it works', '', `<ol class="ti-how">${how.map((x, i) => `<li><span>${i + 1}</span>${x}</li>`).join('')}</ol>`)}
      <div class="ti-cta">${on ? `<p>Subscribed on <b>${esc((T.sub.subscribedOn || '').slice(0, 10))}</b>${T.sub.subscribedBy ? ' by ' + esc(T.sub.subscribedBy) : ''}. Unsubscribing deletes all models, analyses and findings for this company.</p>${btn('tiUnsubscribe', 'Unsubscribe')}`
        : `<p>Your data stays in your own database. No payroll is changed.</p><button class="btn p ti-big" data-act="tiSubscribe" ${T.busy ? 'disabled' : ''}>${T.busy === 'tiSubscribe' ? 'Subscribing…' : 'Subscribe to Times Intelligence →'}</button>`}</div>`;
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
    const slow = !done && !T.failed && pct >= 90 ? `<div class="ti-warn" style="margin:12px 0 0">Still training: the server is still working on it. Large payrolls (thousands of employees) can take 5–10 minutes; this page updates by itself when it finishes.</div>` : '';
    return `<div class="tr-wrap">${ring}<div class="tr-list">${list}</div></div>${slow}`;
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
    const running = T.busy === 'tiTrain', n = T.sel.size;
    const top = hero(ICON.flask, 'Train Times Intelligence', 'Choose the areas to train. Each area learns from this company’s own data only; a new version goes live only if it passes its checks.',
      `<button class="btn p ti-big" data-act="tiTrain" ${T.busy || !n ? 'disabled' : ''}>${running ? 'Training…' : n ? `Train ${n} selected area${n > 1 ? 's' : ''}` : 'Select an area'}</button>`);
    const cards = AREA_LIST.map(([k, l, ic, d, mock]) => {
      const on = T.sel.has(k), a = k === 'PAYROLL' ? m : areaOf(k);
      const when = k === 'PAYROLL' ? m?.trainingCompletedAt : a?.trainedOn;
      return `<label class="ar-card ${on ? 'on' : ''}" data-act="tiArea:${k}"><span class="ar-cb">${on ? '✓' : ''}</span><span class="ar-ic">${ic}</span>
        <div class="ar-tx"><b>${l}</b>${mock ? '<span class="ar-demo">Demo</span>' : ''}<small>${esc(d)}</small>
        <span class="ti-pill ${a ? 'ok' : ''}">${a ? `Trained v${esc(k === 'PAYROLL' ? m.modelVersion : a.version)} · ${esc(String(when || '').slice(0, 10))}` : 'Not trained'}</span></div></label>`;
    }).join('');
    const pick = panel('Training areas', `${n} of ${AREA_LIST.length} selected · Demo areas train on mock data so the flow can be shown`,
      `<div class="ar-grid">${cards}</div>`, `<span><button class="linkbtn" data-act="tiAreaAll:1">Select all</button> · <button class="linkbtn" data-act="tiAreaAll:0">Clear</button></span>`);
    const runRows = T.areaRun.length ? `<div class="ar-run">${T.areaRun.map((x) => {
      const meta = AREA_LIST.find((a) => a[0] === x.k);
      const s = x.res?.summary || {};
      const sub = x.k === 'PAYROLL' ? (x.state === 'ok' ? 'Model trained and activated' : x.state === 'bad' ? 'Training failed' : 'Training in the background…')
        : x.k === 'IDENTIFICATION' && x.res ? `${(s.employees || 0).toLocaleString()} employees baselined · ${s.openFindings || 0} identity issue(s) found now`
          : x.res?.isMock ? 'Demo area: mock model recorded' : 'Training…';
      return `<div class="ar-row ${x.state}"><span class="tr-ic">${x.state === 'ok' ? '✓' : x.state === 'bad' ? '✕' : ''}</span><span>${meta[2]}</span><b>${meta[1]}</b><small>${sub}</small>${x.res ? `<em>${(x.res.durationMs / 1000).toFixed(1)}s</em>` : ''}</div>`;
    }).join('')}</div>` : '';
    const prog = (T.areaRun.some((x) => x.k === 'PAYROLL') ? progressPanel() : '') + runRows;
    const ident = areaOf('IDENTIFICATION');
    const others = (T.status?.areas || []).length ? panel('Other trained areas', '', `<div class="ar-grid">${(T.status.areas).map((a) => {
      const meta = AREA_LIST.find((x) => x[0] === a.area) || [a.area, a.label, '•'];
      const s = a.summary || {};
      return `<div class="ar-sum"><span class="ar-ic">${meta[2]}</span><div><b>${esc(a.label)} v${a.version}</b>${a.isMock ? '<span class="ar-demo">Demo</span>' : ''}
        <small>${a.area === 'IDENTIFICATION' ? `${(s.employees || 0).toLocaleString()} employees · ${s.withNric || 0} NRIC · ${s.withWorkPass || 0} work passes · ${s.withBankAccount || 0} bank accounts baselined` : esc(s.note || '')}</small>
        <small>${a.isMock ? `Mock recall ${Math.round((s.recallAtAlert || 0) * 100)}% · mock false alerts ${((s.falseAlertRate || 0) * 100).toFixed(1)}%` : `Trained ${esc(a.trainedOn.slice(0, 16).replace('T', ' '))} in ${(a.durationMs / 1000).toFixed(1)}s`}</small></div></div>`;
    }).join('')}</div>${ident ? `<button class="btn sm" data-act="page:tiIdentity" style="margin-top:12px">Open identity checks →</button>` : ''}`) : '';
    const model = !m ? `<div class="ti-empty"><span class="ti-kic">${ICON.flask}</span><b>Payroll model not trained yet</b><p>${j ? `Last job: ${esc(j.status)}. ` : ''}Tick <b>Payroll</b> above and train to build it.</p></div>` : `
      ${kpis([[ICON.chart, 'Active model', 'v' + m.modelVersion, cap(esc(m.detector.replace('_', ' ').toLowerCase())), 'violet'],
        [ICON.users, 'Training records', m.trainingRecordCount.toLocaleString(), 'employee-months'],
        [ICON.calendar, 'Training period', m.trainingPeriodStart.slice(0, 7), 'to ' + m.trainingPeriodEnd.slice(0, 7)],
        [ICON.clock, 'Training time', j?.durationMs ? (j.durationMs / 1000).toFixed(1) + 's' : '—', cap(esc((j?.status || '').toLowerCase())), 'green']])}
      ${panel('Detector evaluation', `Tested on ${ev.n_validation_rows} clean rows + ${ev.n_injected} injected anomalies · gate <b>${esc(j?.gate?.reason || 'passed')}</b>`,
        `<div class="ti-dets">${Object.entries(d).map(([k, v]) => `<div class="ti-det ${k === ev.champion ? 'win' : ''}"><div class="ti-dh"><b>${esc(k.replace('_', ' ').toLowerCase())}</b>${k === ev.champion ? '<span class="ti-pill ok">✓ Chosen</span>' : ''}</div>
          <div class="ti-dm"><small>Catches anomalies</small>${bar(v.recall_at_alert * 100, 'g')}<b>${(v.recall_at_alert * 100).toFixed(1)}%</b></div>
          <div class="ti-dm"><small>False alerts</small>${bar(v.clean_alert_rate * 1000, 'r')}<b>${(v.clean_alert_rate * 100).toFixed(1)}%</b></div>
          <div class="ti-dm"><small>ROC-AUC</small>${bar(v.roc_auc * 100)}<b>${v.roc_auc}</b></div></div>`).join('')}</div>`)}`;
    const vers = T.versions.length ? `<div class="ti-vers">${T.versions.map((x) => `<div class="ti-ver ${x.status === 'ACTIVE' ? 'on' : ''}"><span class="ti-vdot"></span><b>v${x.modelVersion}</b>
        <span class="ti-pill ${x.status === 'ACTIVE' ? 'ok' : x.status === 'REJECTED' ? 'bad' : ''}">${cap(esc(x.status.toLowerCase()))}</span><span class="cap">${esc(x.detector.replace('_', ' ').toLowerCase())}</span>
        <span class="muted">${x.trainingRecordCount.toLocaleString()} records</span><span class="muted">${esc(x.trainingCompletedAt.slice(0, 16).replace('T', ' '))}</span>
        ${x.status !== 'ACTIVE' && x.status !== 'REJECTED' ? `<button class="linkbtn" data-act="tiActivate:${x.modelId}">Roll back to this</button>` : '<span></span>'}</div>`).join('')}</div>` : '<p class="muted">No models yet.</p>';
    return `${errBox()}${top}${pick}${prog ? panel(running ? 'Training in progress' : T.failed ? 'Training failed' : 'Last training run', '', prog) : ''}${others}<h3 class="ar-h">Payroll model</h3>${model}${panel('Payroll model versions', 'Every version is kept; roll back in one click.', vers)}`;
  }

  /* ---------- AI anomaly detection: what the company model learned, and its findings per pay run month ---------- */
  const MON = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  const DET = { ROBUST_BASELINE: 'Robust baseline (each employee vs own history)', ISOLATION_FOREST: 'Isolation Forest (unusual pay patterns)' };
  const SCEN = { net_jump_55: 'Net pay jump', deduction_spike: 'Deduction spike', salary_increase_50: 'Salary increase', duplicate_allowance: 'Duplicate allowance', missing_recurring_allowance: 'Missing allowance' };
  const pctf = (v) => (v == null ? '—' : `${(v * 100).toFixed(1)}%`);
  const dmy = (d) => (d ? new Date(d).toLocaleDateString('en-SG', { day: 'numeric', month: 'short', year: 'numeric' }) : '—');
  const anRun = () => T.runs.find((r) => r.uid === T.run);
  // the saved result of the selected pay run (null = not analysed yet); analysing is only needed once per month
  async function loadSaved() {
    T.answer = null; T.learn = null; T.loaded.learn = false;
    T.analysis = T.run ? await api(`/api/v1/payroll/runs/${T.run}/analysis`).catch(() => null) : null;
    if (!T.names) T.names = Object.fromEntries((await api('/api/v1/lookup/employees?limit=200')).employees.map((e) => [e.employee_no, e.name]));
  }
  function modelPanel() {
    const m = T.status?.activeModel;
    if (!m) return '';
    const ev = m.evaluationMetrics || {}, champ = ev.champion || m.detector, cm = (ev.detectors || {})[champ] || {};
    const scen = Object.entries(ev.per_scenario_recall || {}).map(([k, v]) => [SCEN[k] || k, v[champ]]);
    const facts = [['Version', `v${esc(m.modelVersion)}`, `active since ${dmy(m.activatedOn)}`],
      ['Learned from', `${Number(m.trainingRecordCount).toLocaleString()} pay records`, `${dmy(m.trainingPeriodStart)} – ${dmy(m.trainingPeriodEnd)}`],
      ['Catches', pctf(cm.recall_at_alert), `of ${Number(ev.n_injected || 0).toLocaleString()} test anomalies`],
      ['False alerts', pctf(cm.clean_alert_rate), 'on normal pay records']];
    return panel(`<span class="ti-kic sm">${ICON.chart}</span> Your company model`, `Trained only on ${esc(T.ctx?.companyName || 'your company')}’s own payroll · picked detector: ${esc(DET[champ] || champ)}`,
      `<div class="an-facts">${facts.map(([l, v, sub]) => `<div><small>${l}</small><b>${v}</b><em>${sub}</em></div>`).join('')}</div>
      ${scen.length ? `<div class="an-scen"><small>How well it catches each kind of problem (tested before activation)</small>${scen.map(([n, v]) => `<div class="an-bar"><span>${esc(n)}</span><i><s style="width:${Math.round((v || 0) * 100)}%;background:${v >= 0.9 ? '#10b981' : v >= 0.6 ? '#f59e0b' : '#ef4444'}"></s></i><b>${pctf(v)}</b></div>`).join('')}</div>` : ''}`,
      '<button class="btn sm" data-act="page:tiTrain">Retrain</button>');
  }
  function learningPanel() {
    if (!T.learn && !T.loaded.learn) { T.loaded.learn = true; api('/api/v1/models/learning').then((r) => { T.learn = r; }).catch(() => {}).finally(render); }
    const L = T.learn;
    if (!L) return '';
    const typeName = (t) => cap(String(t || '').replaceAll('_', ' ').toLowerCase());
    const money = (m, v) => (v == null ? 'any value' : /hours/.test(m || '') ? `${num(v)} h` : `S$${num(v)}`);
    const rows = L.patterns.map((p) => `<div class="lrn-row"><span class="ti-kic sm">🧠</span><div><b>${esc(p.name)} · ${esc(typeName(p.anomaly_type))}</b>
        <small>${money(p.metric, p.accepted_value)} accepted as normal (±${Number(p.tolerance_pct)}%) by ${esc(String(p.learned_by).startsWith('svc:') ? 'Payroll Admin' : p.learned_by)} on ${dmy(p.learned_on)}</small></div>
        <span class="lrn-n">${p.applied_count ? `used ${p.applied_count}×` : 'not used yet'}</span><button class="btn sm" data-act="tiForget:${p.uid}" ${T.busy ? 'disabled' : ''}>Forget</button></div>`).join('');
    const cal = L.calibrations.map((c) => `<div class="lrn-row"><span class="ti-kic sm">↓</span><div><b>${esc(typeName(c.anomalyType))}: one severity lower</b><small>Reviewers accepted ${c.accepted} of ${c.reviews} findings like this, so new ones start lower.</small></div></div>`).join('');
    const how = `<div class="lrn-how"><div><b>✓ Accept</b>The accepted value becomes normal for that employee. The same finding at about the same value (±${L.rules.tolerancePct}%) is not raised again.</div>
      <div><b>✕ Fix (real error)</b>The finding stays a problem, and anything learned from it is removed.</div>
      <div><b>↓ Self-correction</b>If at least ${Math.round(L.rules.acceptShare * 100)}% of ${L.rules.minReviews}+ findings of one type are accepted, new ones of that type are lowered one level.</div></div>`;
    return panel('<span class="ti-kic sm">🧠</span> What your model learned from your decisions', `${L.patterns.length} learned pattern${L.patterns.length === 1 ? '' : 's'} · ${L.calibrations.length} self-correction${L.calibrations.length === 1 ? '' : 's'} · used in every new analysis`,
      `${rows || cal ? `<div class="lrn-list">${rows}${cal}</div>` : '<div class="muted" style="padding:4px 0 6px">Nothing learned yet. When a finding is really fine, click <b>Accept</b> on the PayShield page and the model learns it.</div>'}${how}`);
  }

  function anomalyBody() {
    if (!T.loaded.anRuns) { T.loaded.anRuns = true; loadRuns().then(loadSaved).catch((e) => { T.err = e.message; }).finally(render); }
    const a = T.analysis, run = anRun(), y = run ? +run.period.slice(3) : new Date().getFullYear(), m = run ? +run.period.slice(0, 2) - 1 : 0;
    const years = [...new Set(T.runs.map((r) => +r.period.slice(3)))].sort((p, q) => q - p);
    const runAt = (yy, mm) => T.runs.find((r) => r.period === `${String(mm + 1).padStart(2, '0')}/${yy}`);
    const sevCount = (s) => (a ? a.anomalies.filter((x) => x.severity === s).length : 0);
    const st = (x) => (['CONFIRMED_ERROR'].includes(x.latestFeedback) ? '<span class="an-st g">✓ Fixed</span>' : ['EXPECTED_CHANGE', 'FALSE_POSITIVE'].includes(x.latestFeedback) ? '<span class="an-st g">✓ Accepted</span>' : '<span class="an-st o">Open</span>');
    const how = (x) => [x.ruleId ? `📏 Payroll rule ${esc(x.ruleId)}` : '🤖 Found by your company model',
      x.mlPercentile != null ? `🤖 model: more unusual than ${Math.min(99.9, Number(x.mlPercentile)).toFixed(0)}% of this employee’s normal pay` : '',
      x.expectedLow != null ? `usual range ${num(x.expectedLow)} – ${num(x.expectedHigh)}` : ''].filter(Boolean).join(' · ');
    const findings = !a ? '' : !a.anomalies.length
      ? `<div class="ti-empty ok"><span class="ti-kic">✓</span><b>No anomalies found</b><p>All ${a.totalEmployees} employees in ${MON[m]} ${y} look consistent with their own pay history.</p></div>`
      : `<div class="ti-finds">${a.anomalies.map((x) => `<div class="ti-find s-${x.severity}"><div class="ti-risk"><b>${x.riskScore}</b><small>risk</small></div>
          <div class="ti-fb"><div class="ti-fh"><span class="ti-sev s-${x.severity}">${x.severity}</span><b>${esc((T.names || {})[x.employeeNo] || x.employeeNo)}</b><span class="muted">· ${esc(x.employeeNo)} · ${esc(cap(x.anomalyType.replaceAll('_', ' ').toLowerCase()))}</span>${st(x)}</div>
          <p>${esc(x.description)}</p><p class="an-how">${how(x)}</p><p class="ti-act">→ ${esc(x.recommendedAction)}</p></div>
          <div class="ti-vals"><small>Current</small><b>${num(x.currentValue)}</b><small>Usual</small><span>${num(x.expectedValue)}</span></div></div>`).join('')}</div>`;
    const open = a ? a.anomalies.filter((x) => !['CONFIRMED_ERROR', ...RESOLVED].includes(x.latestFeedback)).length : 0;
    const res = !run ? '' : !a ? `<div class="ti-empty"><span class="ti-kic">${ICON.search}</span><b>${MON[m]} ${y} has not been analysed yet</b><p>Click <b>Analyse</b> to check all ${run.records} employees against their own pay history with your company model.</p></div>` : `
      ${kpis([[ICON.users, 'Checked', a.totalEmployees, `employees · ${MON[m]} ${y}`],
        [ICON.alert, 'Flagged', a.flaggedEmployees, `${a.anomalyCount} findings · ${open} open`, a.flaggedEmployees ? 'red' : 'green'],
        [ICON.shield, 'Highest severity', cap(esc(a.maxSeverity ? a.maxSeverity.toLowerCase() : 'none')), `analysed ${dmy(a.generatedAt)}`, a.maxSeverity ? 'amber' : 'green'],
        [ICON.chart, 'Model', a.modelVersion ? 'v' + a.modelVersion : 'rules only', cap(esc(a.mlStatus.replaceAll('_', ' ').toLowerCase())), 'violet']])}
      ${a.warnings.length ? `<div class="ti-warn">${a.warnings.map(esc).join('<br>')}</div>` : ''}
      ${PS.learnedNote(a, T.names || {})}
      ${panel('Findings', a.anomalies.length ? `Sorted by risk · ${['CRITICAL', 'HIGH', 'MEDIUM', 'LOW'].map((s) => (sevCount(s) ? `<span class="ti-sev s-${s}">${sevCount(s)} ${s.toLowerCase()}</span>` : '')).join(' ')}` : '', findings,
        a.anomalies.length ? `<button class="btn sm p" data-act="tiAnResolve">Resolve in PayShield →</button>` : '')}
      ${panel(`<span class="ti-kic sm">${ICON.bot}</span> Ask about these findings`, 'Read-only assistant: it explains, it never changes payroll.',
        `<div class="ti-qs">${QUESTIONS.map((q, i) => `<button class="ti-q" data-act="tiAsk:${i}" ${T.busy ? 'disabled' : ''}>${esc(q)}</button>`).join('')}</div>
        ${T.busy === 'tiAsk' ? '<div class="ti-ans muted">Thinking…</div>' : T.answer ? `<div class="ti-ans"><span class="ti-pill">${cap(esc(T.answer.status.toLowerCase()))}</span><span>${esc(T.answer.answer)}</span></div>` : ''}`)}`;
    const ctl = !T.runs.length ? '<div class="muted">Loading pay runs…</div>' : `<div class="ti-ctl an-ctl"><label><small>Month</small><select id="tiAnMonth" ${T.busy ? 'disabled' : ''}>${MON.map((n, k) => `<option value="${k}" ${k === m ? 'selected' : ''} ${runAt(y, k) ? '' : 'disabled'}>${n}${runAt(y, k) ? '' : ' (no run)'}</option>`).join('')}</select></label>
        <label><small>Year</small><select id="tiAnYear" ${T.busy ? 'disabled' : ''}>${years.map((v) => `<option ${v === y ? 'selected' : ''}>${v}</option>`).join('')}</select></label>
        <div class="an-run">${run ? `<b>${esc(run.name)}</b> · ${run.records} employees${run.locked ? ' · <span class="an-st g">🔒 Paid</span>' : ''}<br><small>${a ? `Analysed ${dmy(a.generatedAt)}` : 'Not analysed yet'}</small>` : ''}</div>
        ${run?.locked ? '' : `<button class="btn p ti-big" data-act="tiAnalyze" ${T.busy ? 'disabled' : ''}>${T.busy === 'tiAnalyze' ? 'Analysing…' : a ? '↻ Analyse again' : '✦ Analyse'}</button>`}</div>`;
    return `${errBox()}${hero(ICON.spark, 'AI anomaly detection', 'Your company model and the payroll rules check each employee against their own pay history.', '', 'blue')}
      ${modelPanel()}${learningPanel()}${panel('Pay run month', '', ctl)}${res}`;
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
  .ti-live{display:flex;align-items:center;gap:8px;padding:9px 14px;margin-bottom:14px;border-radius:10px;font-size:13px;background:#ecfdf5;border:1px solid #a7f3d0;color:#065f46}
  .ti-live.wait{background:#eef2ff;border-color:#c7d2fe;color:#3730a3}.ti-live.bad{background:#fef2f2;border-color:#fecaca;color:#991b1b}.ti-live.off{background:#f9fafb;border-color:#e5e7eb;color:#6b7280}
  .ti-live .linkbtn{margin-left:auto;white-space:nowrap}.ti-dot{flex:none;width:8px;height:8px;border-radius:50%;background:currentColor;box-shadow:0 0 0 3px rgba(16,185,129,.2)}
  .an-facts{display:grid;grid-template-columns:repeat(auto-fit,minmax(170px,1fr));gap:10px}.an-facts div{background:#f9fafb;border-radius:12px;padding:10px 12px}
  .an-facts small{display:block;font-size:11px;color:#6b7280}.an-facts b{display:block;font-size:19px;margin:2px 0}.an-facts em{font-style:normal;font-size:11.5px;color:#9ca3af}
  .an-scen{margin-top:14px}.an-scen>small{display:block;color:#6b7280;margin-bottom:6px}.an-bar{display:grid;grid-template-columns:150px 1fr 56px;gap:10px;align-items:center;font-size:12.5px;margin:5px 0}
  .an-bar i{height:8px;border-radius:4px;background:#eef0f4;position:relative;overflow:hidden}.an-bar s{position:absolute;inset:0 auto 0 0;border-radius:4px}.an-bar b{text-align:right}
  .an-ctl{align-items:flex-end}.an-run{flex:1;min-width:180px;font-size:13px}.an-run small{color:#6b7280}
  .an-how{font-size:12px;color:#6b7280;margin:2px 0}.an-st{margin-left:auto;font-size:11px;font-weight:700;border-radius:999px;padding:2px 9px}.an-st.g{background:#d1fae5;color:#065f46}.an-st.o{background:#fef3c7;color:#92400e}
  .tch-sug{display:flex;gap:6px;flex-wrap:wrap;align-items:center;margin-top:10px}.tch-sug small{width:100%;color:#6b7280}.tch-sug .btn{border-color:#c4b5fd;color:#5b21b6;background:#f5f3ff}
  .ag-rs{display:grid;gap:6px;margin-top:8px}.ag-rsr{display:flex;align-items:center;gap:12px;border:1px solid #e5e7eb;border-left:4px solid #f59e0b;border-radius:10px;padding:8px 12px;background:#fff}
  .ag-rsr>div:first-child{flex:1}.ag-rsr small{display:block;color:#6b7280;font-size:11.5px}.ag-rsr.done{border-left-color:#10b981}.ag-rsr.ready{border-left-color:#6366f1}.ag-rsr.blocked{border-left-color:#ef4444}
  .ag-rst{font-size:11.5px;font-weight:700;border-radius:999px;padding:2px 9px}.ag-rst.done{background:#d1fae5;color:#065f46}.ag-rst.ready{background:#e0e7ff;color:#3730a3}.ag-rst.blocked{background:#fee2e2;color:#991b1b}.ag-rst.unchecked{background:#fef3c7;color:#92400e}
  .ag-rsm{margin-top:8px;font-size:12.5px;color:#6b7280;background:#f9fafb;border-radius:8px;padding:8px 10px}
  .tch-pill{background:#f5f3ff!important;color:#6d28d9!important}.tch-card{border-color:#ddd6fe}
  .tch-q{display:flex;gap:10px;align-items:flex-start;font-size:20px}.tch-q b{display:block;font-size:14px}.tch-q small{display:block;font-size:12.5px;color:#6b7280;font-weight:400}
  .tch{background:#faf5ff;border:1px solid #ede9fe;border-radius:12px;padding:12px;margin-top:10px;display:grid;gap:8px}.tch-t{font-size:13px}
  .tch-l{display:grid;gap:4px;font-size:12px;font-weight:600;color:#4c1d95}.tch-l small{font-weight:400;color:#7c3aed}
  .tch input,.tch textarea,.tch select{width:100%;box-sizing:border-box;border:1px solid #d8b4fe;border-radius:9px;padding:8px 10px;font:inherit;font-size:13px;background:#fff;font-weight:400;color:#111827}
  .tch-k{display:flex;gap:6px;flex-wrap:wrap}.tch-k button{flex:1;min-width:150px;border:1px solid #d8b4fe;background:#fff;border-radius:9px;padding:8px;font:inherit;font-size:12.5px;cursor:pointer;color:#6d28d9}
  .tch-k button.on{background:#7c3aed;color:#fff;border-color:#7c3aed}.tch-r{display:grid;gap:6px}.tch-b{display:flex;gap:8px;align-items:center;flex-wrap:wrap}
  .tch-saved{background:#ecfdf5;border:1px solid #a7f3d0;color:#065f46;border-radius:10px;padding:10px 12px;margin-top:10px;font-size:13px}
  .tch-ans{font-size:13.5px;line-height:1.55;background:#faf5ff;border-radius:10px;padding:10px 12px;margin:6px 0}
  .tch-meta{display:flex;justify-content:space-between;align-items:center;gap:8px;flex-wrap:wrap;color:#6b7280}
  .tch-fb{display:flex;align-items:center;gap:6px}.tch-fb button{border:1px solid #e5e7eb;background:#fff;border-radius:8px;padding:3px 8px;cursor:pointer}
  .tch-fbk{margin-top:8px;font-size:12px;color:#6b7280}.tch-fbk pre{white-space:pre-wrap;font-size:11.5px;max-height:160px;overflow:auto}
  .tch-row{display:flex;align-items:center;gap:10px;padding:10px 0;border-top:1px solid #f1f2f4}.tch-row>div{flex:1}.tch-row small{display:block;color:#6b7280}
  .tch-skill{border:1px solid #ede9fe;border-radius:12px;padding:12px;margin-bottom:10px}.tch-sh{display:flex;gap:10px;align-items:center;flex-wrap:wrap}.tch-sh>small{margin-left:auto;color:#6b7280}
  .tch-kind{font-size:11px;font-weight:800;border-radius:999px;padding:2px 9px}.tch-kind.ANSWER{background:#ede9fe;color:#5b21b6}.tch-kind.ROUTE{background:#e0f2fe;color:#075985}
  .tch-ph{display:flex;gap:6px;flex-wrap:wrap}.tch-ph span{background:#f3f4f6;border-radius:999px;padding:3px 10px;font-size:12px}
  .ti-hero{display:flex;gap:16px;align-items:center;padding:20px 22px;border-radius:14px;color:#fff;background:linear-gradient(120deg,#4f46e5,#7c3aed 55%,#a855f7);box-shadow:0 8px 24px rgba(124,58,237,.18);margin-bottom:16px}
  .ti-hero.blue{background:linear-gradient(120deg,#1d4ed8,#4f46e5 60%,#7c3aed)}.ti-hero h3{margin:0;font-size:18px;color:#fff}.ti-hero p{margin:3px 0 0;opacity:.92;font-size:13px}
  .ti-hic{width:46px;height:46px;border-radius:12px;background:rgba(255,255,255,.18);display:grid;place-items:center;flex-shrink:0}.ti-hic svg{width:24px;height:24px}
  .ti-ht{flex:1;min-width:0}.ti-hero .btn{background:#fff!important;color:#4f46e5!important;border-color:#fff!important}.ti-hero .ti-pill{background:rgba(255,255,255,.2);color:#fff;border-color:transparent}.ti-hero .ti-pill.ok{background:#dcfce7;color:#166534}
  .ti-big{padding:9px 16px!important;font-size:13px!important;border-radius:9px!important;font-weight:600}
  .ti-panel{background:#fff;border:1px solid #e5e7eb;border-radius:14px;padding:18px 20px;margin-bottom:16px;box-shadow:0 1px 2px rgba(16,24,40,.04)}
  .ti-panel>header{display:flex;justify-content:space-between;align-items:flex-start;gap:12px;margin-bottom:14px}.ti-panel h4{margin:0;font-size:14.5px;display:flex;align-items:center;gap:8px}.ti-panel header p{margin:4px 0 0;color:#6b7280;font-size:12px}
  .ti-pill{display:inline-flex;align-items:center;gap:4px;padding:2px 10px;border-radius:99px;font-size:11.5px;font-weight:600;background:#f3f4f6;color:#374151;border:1px solid #e5e7eb;white-space:nowrap}
  .ti-pill.ok{background:#dcfce7;color:#166534;border-color:#bbf7d0}.ti-pill.bad{background:#fee2e2;color:#991b1b;border-color:#fecaca}
  .ti-kpis{display:grid;grid-template-columns:repeat(4,minmax(0,1fr));gap:14px;margin-bottom:16px}
  .ti-kpi{display:flex;gap:12px;align-items:center;background:#fff;border:1px solid #e5e7eb;border-radius:14px;padding:16px;--k:#2563eb;--ks:#eff6ff}
  .ti-kpi.violet{--k:#7c3aed;--ks:#f5f3ff}.ti-kpi.green{--k:#16a34a;--ks:#f0fdf4}.ti-kpi.red{--k:#dc2626;--ks:#fef2f2}.ti-kpi.amber{--k:#d97706;--ks:#fffbeb}
  .ti-kpi small{display:block;color:#6b7280;font-size:12px}.ti-kpi b{display:block;font-size:22px;line-height:1.15;color:#111827;white-space:nowrap}.ti-kpi>div{min-width:0}.ti-kpi em{font-style:normal;color:#6b7280;font-size:11.5px}
  .ti-kic{width:40px;height:40px;border-radius:11px;background:var(--ks,#f5f3ff);color:var(--k,#7c3aed);display:grid;place-items:center;flex-shrink:0;font-weight:700;font-size:18px}.ti-kic svg{width:20px;height:20px}
  .ti-kic.sm{width:26px;height:26px;border-radius:8px}.ti-kic.sm svg{width:15px;height:15px}
  .ti-feats{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:14px;margin-bottom:16px}.ti-feat{background:#fff;border:1px solid #e5e7eb;border-radius:14px;padding:18px}
  .ti-feat b{display:block;margin:12px 0 4px;font-size:14px}.ti-feat p{margin:0;color:#6b7280;font-size:12.5px}
  @media(max-width:900px){.ti-kpis,.ti-feats{grid-template-columns:repeat(2,minmax(0,1fr))}}
  .ti-how{list-style:none;margin:0;padding:0;display:flex;gap:10px;flex-wrap:wrap}.ti-how li{flex:1;min-width:120px;display:flex;align-items:center;gap:10px;padding:10px 12px;border-radius:10px;background:#f9fafb;font-weight:600}
  .ti-how li span{width:24px;height:24px;border-radius:50%;background:#7c3aed;color:#fff;display:grid;place-items:center;font-size:12px;flex-shrink:0}
  .ti-cta{display:flex;justify-content:space-between;align-items:center;gap:16px;flex-wrap:wrap;padding:16px 20px;border-radius:14px;background:linear-gradient(135deg,#f5f3ff,#eef2ff);border:1px solid #ddd6fe}.ti-cta p{margin:0;color:#4c1d95}
  .ti-cta .ti-big.p{background:#7c3aed;border-color:#7c3aed}
  .ti-empty{text-align:center;padding:36px 20px;background:#fff;border:1px dashed #d1d5db;border-radius:14px;margin-bottom:16px}.ti-empty .ti-kic{margin:0 auto 10px}.ti-empty b{font-size:15px}.ti-empty p{margin:4px 0 0;color:#6b7280}
  .ti-empty.ok{border:1px solid #bbf7d0;background:#f0fdf4;margin:0}.ti-empty.ok .ti-kic{--ks:#dcfce7;--k:#16a34a}
  .ti-ctl{display:flex;gap:10px;align-items:flex-end;flex-wrap:wrap}.ti-ctl label{flex:1;min-width:260px}.ti-ctl small{display:block;color:#6b7280;margin-bottom:4px}
  .ti-ctl select{width:100%;padding:9px 10px;border:1px solid #d1d5db;border-radius:9px;font-size:13px;background:#fff}
  .ti-inj{margin-top:12px;padding:10px 12px;border-radius:10px;background:#f5f3ff;color:#4c1d95;display:flex;gap:6px;flex-wrap:wrap;align-items:center}
  .ti-warn{padding:10px 14px;border-radius:10px;background:#fffbeb;border:1px solid #fde68a;color:#92400e;margin-bottom:16px;font-size:12.5px}
  .ti-sev{display:inline-block;padding:1px 8px;border-radius:99px;font-size:10.5px;font-weight:700;letter-spacing:.3px;color:#fff;background:#3b82f6}
  .ti-sev.s-CRITICAL{background:#7f1d1d}.ti-sev.s-HIGH{background:#dc2626}.ti-sev.s-MEDIUM{background:#d97706}
  .ti-finds{display:grid;gap:10px}.ti-find{display:flex;gap:14px;padding:14px;border:1px solid #e5e7eb;border-left:4px solid #3b82f6;border-radius:12px}
  .ti-find.s-CRITICAL{border-left-color:#7f1d1d;background:#fef2f2}.ti-find.s-HIGH{border-left-color:#dc2626}.ti-find.s-MEDIUM{border-left-color:#d97706}
  .ti-risk{width:52px;text-align:center;flex-shrink:0}.ti-risk b{display:block;font-size:22px}.ti-risk small{color:#6b7280;font-size:10.5px}
  .ti-fb{flex:1;min-width:0}.ti-fh{display:flex;gap:8px;align-items:center;flex-wrap:wrap}.ti-fh b{text-transform:capitalize}.ti-fb p{margin:6px 0 0}.ti-fb .ti-act{color:#4f46e5;font-size:12.5px}
  .ti-vals{text-align:right;min-width:110px;display:grid;gap:1px;align-content:start}.ti-vals small{color:#6b7280;font-size:10.5px}.ti-vals b{font-size:15px}
  .ti-qs{display:flex;gap:8px;flex-wrap:wrap}.ti-q{border:1px solid #ddd6fe;background:#f5f3ff;color:#5b21b6;border-radius:99px;padding:7px 14px;cursor:pointer;font-size:12.5px;font-weight:600}.ti-q:hover{background:#ede9fe}
  .ti-ans{margin-top:12px;padding:12px 14px;border-radius:12px;background:#f9fafb;border:1px solid #e5e7eb;white-space:pre-wrap;display:flex;gap:8px;align-items:flex-start}
  .ti-dets{display:grid;grid-template-columns:repeat(auto-fit,minmax(260px,1fr));gap:12px}.ti-det{border:1px solid #e5e7eb;border-radius:12px;padding:14px}.ti-det.win{border-color:#86efac;background:#f0fdf4}
  .ti-dh{display:flex;justify-content:space-between;align-items:center;margin-bottom:8px}.ti-dh b{text-transform:capitalize}
  .ti-dm{display:grid;grid-template-columns:120px 1fr 56px;align-items:center;gap:8px;padding:3px 0}.ti-dm small{color:#6b7280}.ti-dm b{text-align:right}
  .ti-bar{height:8px;background:#e5e7eb;border-radius:99px;overflow:hidden}.ti-bar i{display:block;height:100%;background:#6366f1;border-radius:99px}.ti-bar.g i{background:#16a34a}.ti-bar.r i{background:#ef4444}
  .ti-vers{display:grid;gap:2px}.ti-ver{display:grid;grid-template-columns:14px 60px 90px minmax(120px,1fr) 110px 130px 120px;gap:10px;align-items:center;padding:9px 6px;border-radius:8px}.ti-ver.on{background:#f0fdf4}
  .ti-ver .cap{text-transform:capitalize}.ti-vdot{width:10px;height:10px;border-radius:50%;background:#d1d5db}.ti-ver.on .ti-vdot{background:#16a34a;box-shadow:0 0 0 4px #dcfce7}
  .tr-spin{display:inline-block;width:28px;height:28px;border-radius:50%;border:3px solid #ede9fe;border-top-color:#7c3aed;animation:trspin .8s linear infinite;margin-bottom:8px}
  .tp .db{display:grid;grid-template-columns:minmax(0,1fr);gap:20px;margin:0;padding:0;border:0;background:none}.tp .db-row{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:20px}@media(max-width:760px){.tp .db-row{grid-template-columns:minmax(0,1fr)}}
  .db-card{background:#fff;border:1px solid #e5e7eb;border-radius:14px;padding:20px 24px;box-shadow:0 1px 2px rgba(16,24,40,.04)}.db-card.p0{padding:0}.db-card a{color:#2563eb;cursor:pointer;font-weight:500}
  .db-hello{border-left:4px solid #2563eb}.db-hello h2{margin:14px 0 6px;font-size:24px}.db-hello p{margin:0;color:#374151;line-height:1.7}
  .db-wx{margin-top:18px;border:1px solid #e5e7eb;border-radius:12px;padding:16px 18px;background:#fbfcfe}.db-wt{display:flex;gap:12px;align-items:center}.db-wt>b{font-size:30px}
  .db-wn{margin-top:14px;padding-top:12px;border-top:1px dashed #e5e7eb;color:#374151}
  .db-h{display:flex;align-items:center;gap:12px;font-size:15px}.db-card.p0 .db-h{padding:18px 24px;border-bottom:1px solid #f0f1f3}.db-r{margin-left:auto;display:flex;gap:8px;align-items:center;color:#9ca3af}
  .db-ic{width:34px;height:34px;border-radius:9px;display:grid;place-items:center;background:#eff6ff;color:#2563eb;flex-shrink:0}.db-ic svg{width:17px;height:17px}
  .db-ic.o{background:#fff7ed;color:#ea580c}.db-ic.g{background:#f0fdf4;color:#16a34a}.db-ic.v{background:#f5f3ff;color:#7c3aed}
  .db-pill{padding:2px 9px;border-radius:99px;font-size:11.5px;border:1px solid}.db-pill.g{color:#15803d;border-color:#86efac;background:#f0fdf4}.db-pill.b{color:#2563eb;border-color:#bfdbfe;background:#eff6ff}
  .db-work{display:flex;gap:24px;align-items:center;margin:18px 0}.db-ring{position:relative;width:92px;height:92px;flex-shrink:0}.db-ring svg{width:100%;height:100%}
  .db-ring div{position:absolute;inset:0;display:grid;place-content:center;text-align:center}.db-ring b{font-size:15px}.db-ring small{color:#6b7280;font-size:10px}
  .db-work dl{flex:1;margin:0;display:grid;grid-template-columns:1fr auto;row-gap:0}.db-work dt,.db-work dd{margin:0;padding:9px 0;border-bottom:1px dashed #e5e7eb}.db-work dt{color:#6b7280;font-size:12px;letter-spacing:.4px}.db-work dd{font-weight:600;text-align:right}
  .db-week{display:grid;grid-template-columns:repeat(7,1fr);gap:8px;margin-bottom:16px}.db-week div{text-align:center;color:#6b7280}.db-week i{display:block;height:4px;border-radius:9px;background:#e5e7eb;margin-bottom:8px}
  .db-week .done i{background:#2563eb}.db-week .now i{background:linear-gradient(90deg,#2563eb 25%,#e5e7eb 25%)}.db-week .now{color:#2563eb;font-weight:700}
  .db-btn{border:0;border-radius:9px;padding:10px 18px;font-weight:600;cursor:pointer;font-size:13.5px}.db-btn.red{background:#dc2626;color:#fff}
  .db-cnt{width:24px;height:24px;border-radius:50%;border:1px solid #bfdbfe;color:#2563eb;display:inline-grid;place-items:center;font-size:12px}
  .db-tabs{display:flex;gap:6px;padding:12px 24px;border-bottom:1px solid #f0f1f3}.db-tabs span{padding:5px 12px;border-radius:8px;color:#6b7280}.db-tabs .on{background:#eff6ff;color:#2563eb;font-weight:600}
  .db-ap{display:flex;gap:14px;align-items:center;padding:14px 24px;border-bottom:1px solid #f0f1f3}.db-ap>div{flex:1}.db-av{width:38px;height:38px;border-radius:50%;background:#eff6ff;color:#2563eb;border:1px solid #bfdbfe;display:grid;place-items:center;font-weight:700}
  .db-tag{font-size:11px;padding:1px 7px;border-radius:5px;border:1px solid}.db-tag.o{color:#c2410c;border-color:#fdba74;background:#fff7ed}.db-tag.b{color:#2563eb;border-color:#93c5fd;background:#eff6ff}
  .db-ok,.db-no{width:30px;height:30px;border:1px solid #e5e7eb;border-radius:8px;display:grid;place-items:center;cursor:pointer}.db-ok{color:#16a34a}.db-no{color:#dc2626}
  .db-card footer{text-align:center;padding:14px}.db-an{display:flex;gap:14px;padding:18px 24px;border-bottom:1px solid #f0f1f3}.db-an p{margin:6px 0;color:#374151}
  .db-seg{display:flex;background:#f3f4f6;border-radius:9px;padding:3px}.db-seg span{padding:5px 12px;border-radius:7px;color:#6b7280}.db-seg .on{background:#fff;color:#111827;font-weight:600;box-shadow:0 1px 2px rgba(0,0,0,.08)}
  .db-kpis{display:grid;grid-template-columns:repeat(4,1fr);gap:16px;margin-top:18px}@media(max-width:900px){.db-kpis{grid-template-columns:repeat(2,1fr)}}
  .db-kpi{position:relative;border:1px solid #e5e7eb;border-radius:12px;padding:18px 20px;--c:#2563eb}.db-kpi.g{--c:#15803d}.db-kpi.o{--c:#c2410c}.db-kpi.v{--c:#7c3aed}
  .db-kpi>small:first-child{display:block;color:#6b7280}.db-kpi b{display:block;font-size:30px;color:var(--c);margin:4px 0}.db-ki{position:absolute;right:20px;top:46px;color:var(--c)}.db-ki svg{width:20px;height:20px}
  .db-ln{display:flex;gap:12px;align-items:center;padding:13px 24px;cursor:pointer}.db-ln:hover{background:#f9fafb}.db-li{color:#2563eb;display:grid}.db-li svg{width:16px;height:16px}
  .db-lv{padding:20px 24px;border-bottom:1px solid #f0f1f3}.db-lvh{display:flex;justify-content:space-between;align-items:center;margin-bottom:6px}.db-big{font-size:30px;font-weight:700}
  .db-bar{height:6px;background:#e5e7eb;border-radius:9px;overflow:hidden;display:flex;margin:12px 0 8px}.db-bar i{background:#2563eb;display:block}.db-bar i.p{background:#bfdbfe}
  .db-dot{display:inline-block;width:8px;height:8px;border-radius:2px;margin-right:3px}.db-dot.b{background:#2563eb}.db-dot.l{background:#bfdbfe}.db-dot.e{background:#e5e7eb}
  .db-warn{margin-top:14px;padding:10px 14px;border-radius:10px;background:#fffbeb;border:1px solid #fde68a;color:#92400e}.db-lv2{padding:16px 24px;border-bottom:1px solid #f0f1f3}
  .ag-chat{display:grid;gap:12px;background:#f8fafc}.ag-me{justify-self:end;max-width:75%;background:#2563eb;color:#fff;padding:12px 16px;border-radius:14px 14px 4px 14px}
  .ag-card{background:#fff;border:1px solid #e5e7eb;border-radius:14px;padding:16px 18px}.ag-h{display:flex;gap:8px;align-items:center;margin-bottom:8px}.ag-h svg{width:18px;height:18px;color:#2563eb}.ag-h>span{margin-left:auto}
  .ag-txt{white-space:pre-wrap;line-height:1.6}
  .ag-trace{border:1px solid #e5e7eb;border-radius:10px;padding:8px 12px;margin-bottom:12px;background:#fbfcfe}.ag-trace summary{cursor:pointer;color:#15803d}
  .ag-trace div{display:grid;grid-template-columns:150px 1fr;gap:2px 10px;padding:6px 0;border-top:1px dashed #eef0f3;margin-top:6px}.ag-trace em{grid-column:2;font-style:normal;color:#6b7280;font-size:12px}
  .ag-trace code,.ag-tools code{font-size:11.5px;color:#4f46e5}
  .ag-score{display:flex;gap:16px;align-items:center;border:1px solid #e5e7eb;border-radius:12px;padding:14px 16px;margin-bottom:12px}.ag-score h3{margin:2px 0;font-size:19px}
  .ag-ring{position:relative;width:72px;height:72px;flex-shrink:0}.ag-ring svg{width:100%;height:100%}.ag-ring b{position:absolute;inset:0;display:grid;place-items:center;font-size:20px}
  .ag-t{width:100%;border-collapse:collapse;font-size:12.5px;min-width:720px}.ag-t th{background:#f3f6fa;color:#6b7280;text-align:left;padding:8px;font-size:10.5px;text-transform:uppercase;letter-spacing:.04em}
  .ag-t td{padding:10px 8px;border-bottom:1px solid #eef0f3;vertical-align:top}.ag-t tr.ag-g td{background:#eef4ff;text-transform:capitalize}.ag-t tr.done td{opacity:.55}
  .ag-t td div{margin-top:3px}.ag-k{font-size:10px;font-weight:700;color:#6b7280;letter-spacing:.06em;margin-right:4px}.ag-risk{font-weight:700;white-space:nowrap}
  .ag-note{margin-top:12px;padding:10px 14px;border-radius:10px;background:#f0fdf4;border:1px solid #bbf7d0;color:#166534}
  .ag-rev{border-color:#c7d2fe;box-shadow:0 0 0 3px #eef2ff}.ag-opts{display:flex;gap:8px;flex-wrap:wrap;align-items:center;margin:6px 0 8px}.ag-opts .btn.on{outline:2px solid #16a34a}
  .ag-sugg{display:flex;gap:8px;flex-wrap:wrap}.ag-in{display:flex;gap:10px}.ag-in input{flex:1;padding:11px 14px;border:1px solid #d1d5db;border-radius:10px;font-size:13.5px;background:#fff}
  .ag-tools div{display:grid;grid-template-columns:160px 1fr;gap:10px;padding:8px 0;border-top:1px solid #f0f1f3}.ag-ul{margin:0;padding-left:18px;line-height:1.8}
  .ag-sum{display:flex;gap:12px;align-items:center;padding:12px 14px;border-radius:12px;background:linear-gradient(135deg,#eef2ff,#f5f3ff);border:1px solid #e0e7ff;margin-bottom:12px}
  .ag-sum.ok{background:linear-gradient(135deg,#f0fdf4,#ecfdf5);border-color:#bbf7d0}.ag-sum.no{background:#fff7ed;border-color:#fed7aa}
  .ag-sum b{display:block;font-size:14px;text-transform:none}.ag-sum small{display:block;color:#6b7280;margin-top:2px}
  .ag-si{width:36px;height:36px;border-radius:10px;background:#fff;display:grid;place-items:center;font-size:18px;box-shadow:0 1px 2px rgba(0,0,0,.06);flex-shrink:0}
  .ag-fl{display:grid;gap:10px}.ag-f{border:1px solid #e5e7eb;border-left:4px solid #3b82f6;border-radius:12px;padding:14px 16px;background:#fff}
  .ag-f.s-CRITICAL{border-left-color:#7f1d1d}.ag-f.s-HIGH{border-left-color:#dc2626}.ag-f.s-MEDIUM{border-left-color:#d97706}
  .ag-fh{display:flex;gap:12px;align-items:flex-start}.ag-fh>div:nth-child(2){flex:1;min-width:0}.ag-fh b{font-size:14px;text-transform:capitalize}
  .ag-fi{width:32px;height:32px;border-radius:9px;background:#fef2f2;display:grid;place-items:center;flex-shrink:0}.ag-f.s-MEDIUM .ag-fi{background:#fffbeb}.ag-f.s-LOW .ag-fi{background:#eff6ff}
  .ag-fm{display:flex;gap:6px;flex-wrap:wrap;margin-top:5px}.ag-chip{font-size:11px;padding:1px 8px;border-radius:99px;background:#f3f4f6;color:#374151}
  .ag-amt{text-align:right}.ag-amt small{display:block;color:#6b7280;font-size:10.5px}.ag-amt b{font-size:17px;color:#b91c1c}
  .ag-fd{margin:10px 0;color:#374151;line-height:1.55}
  .ag-cmp{display:grid;grid-template-columns:1fr auto;gap:6px 14px;align-items:center;padding:10px 12px;background:#f9fafb;border-radius:10px}
  .ag-cmp>div{display:grid;grid-template-columns:62px 1fr 90px;gap:10px;align-items:center;grid-column:1}.ag-cmp small{color:#6b7280}.ag-cmp b{text-align:right}
  .ag-cb{height:8px;background:#e5e7eb;border-radius:99px;overflow:hidden;display:block}.ag-cb i{display:block;height:100%;border-radius:99px;background:#3b82f6}
  .ag-cb i.e{background:#94a3b8}.ag-cb i.e2{background:#6366f1}.ag-cb i.s-CRITICAL{background:#7f1d1d}.ag-cb i.s-HIGH{background:#dc2626}.ag-cb i.s-MEDIUM{background:#d97706}
  .ag-delta{grid-column:2;grid-row:1/3;font-weight:700;padding:4px 10px;border-radius:99px;font-size:12.5px}.ag-delta.up{background:#fef2f2;color:#b91c1c}.ag-delta.down{background:#eff6ff;color:#1d4ed8}
  .ag-fix{display:flex;gap:10px;margin-top:10px;padding:10px 12px;border-radius:10px;background:#eef2ff;color:#3730a3}.ag-fix small{display:block;font-size:10.5px;font-weight:700;letter-spacing:.05em;text-transform:uppercase;color:#6366f1}
  .ag-bars{display:grid;gap:8px;margin-bottom:12px}.ag-bars>div{display:grid;grid-template-columns:200px 1fr 40px;gap:12px;align-items:center}.ag-bars span:first-child{text-transform:capitalize}.ag-bars b{text-align:right}
  .ag-li{margin:0;padding:0;list-style:none;display:grid;gap:6px}.ag-li li{padding:10px 12px;border:1px solid #e5e7eb;border-radius:10px;background:#fff}
  .ag-dir td:first-child{display:flex;gap:10px;align-items:center}.ag-dir small{display:block}.db-av.sm{width:30px;height:30px;font-size:11px;flex-shrink:0}
  .ag-spark{display:flex;gap:8px;align-items:flex-end;height:120px;padding:10px 6px 0;border-bottom:1px solid #e5e7eb}.ag-spark>div{flex:1;display:flex;flex-direction:column;align-items:center;height:100%;justify-content:flex-end}
  .ag-spark span{width:100%;max-width:34px;background:#c7d2fe;border-radius:6px 6px 0 0;display:flex;align-items:flex-end;overflow:hidden}.ag-spark i{display:block;width:100%;background:#4f46e5}
  .ag-spark small{font-size:10px;color:#6b7280;margin-top:4px}
  .ag-kp{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:10px}.ag-kp>div{border:1px solid #e5e7eb;border-radius:12px;padding:12px 14px;background:#fff}.ag-kp small{display:block;color:#6b7280}.ag-kp b{display:block;font-size:18px;margin:2px 0}
  .ag-mv{display:grid;grid-template-columns:1fr auto auto;gap:14px;align-items:center;padding:10px 14px;border:1px solid #e5e7eb;border-radius:10px;background:#fff}.ag-mv small{display:block}.ag-mv .ag-delta{grid-column:auto;grid-row:auto}
  .ag-txt a{color:#2563eb}
  .ar-grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(270px,1fr));gap:12px}
  .ar-card{display:flex;gap:12px;align-items:flex-start;padding:14px;border:1.5px solid #e5e7eb;border-radius:12px;cursor:pointer;background:#fff;transition:all .15s}
  .ar-card:hover{border-color:#c4b5fd}.ar-card.on{border-color:#7c3aed;background:#faf5ff;box-shadow:0 0 0 3px #ede9fe}
  .ar-cb{width:20px;height:20px;border-radius:6px;border:2px solid #d1d5db;display:grid;place-items:center;font-size:12px;font-weight:700;color:#fff;flex-shrink:0;margin-top:2px}
  .ar-card.on .ar-cb{background:#7c3aed;border-color:#7c3aed}.ar-ic{font-size:22px;line-height:1}.ar-tx{display:grid;gap:4px;min-width:0}.ar-tx small{color:#6b7280;font-size:12px}
  .ar-tx .ti-pill{justify-self:start}.ar-demo{justify-self:start;display:inline-block;font-size:10px;font-weight:700;color:#92400e;background:#fef3c7;border-radius:4px;padding:1px 6px;vertical-align:middle}
  .ar-run{display:grid;gap:8px;margin-top:14px}.ar-row{display:grid;grid-template-columns:28px 24px 120px 1fr auto;gap:10px;align-items:center;padding:8px 12px;border:1px solid #e5e7eb;border-radius:10px}
  .ar-row small{color:#6b7280}.ar-row em{font-style:normal;color:#6b7280;font-size:12px}.ar-row.ok .tr-ic{background:#16a34a;color:#fff;border-color:#16a34a}.ar-row.bad .tr-ic{background:#dc2626;color:#fff;border-color:#dc2626}
  .ar-row.run .tr-ic{border:3px solid #ede9fe;border-top-color:#7c3aed;background:#fff;animation:trspin .8s linear infinite}
  .ar-sum{display:flex;gap:12px;padding:14px;border:1px solid #e5e7eb;border-radius:12px}.ar-sum small{display:block;color:#6b7280;margin-top:3px}.ar-h{margin:6px 0 12px;font-size:15px}
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
  if (!document.getElementById('tp-css')) document.head.insertAdjacentHTML('beforeend', `<style id="tp-css">${CSS}${PAYSHIELD_CSS}${FAB_CSS}</style>`);
  const DOT = '<svg viewBox="0 0 16 16"><circle cx="8" cy="8" r="3" fill="currentColor"/></svg>';
  const STATIC = { 'BASIC v5': ['Dashboard', 'Company Policy'], PRODUCT: ['EPM', 'Pay', 'Leave', 'IRAS', 'Claim', 'Query Builder'] };
  function shell(crumb, body, groups, active) {
    document.body.classList.add('tp-mode');
    const on = !!T.sub?.subscribed, trained = anyTrained();
    if (on && !trained && T.status && !['tiTrain', 'tiOnboard', 'tiDash'].includes(active)) return shell(crumb, onboardBody(), groups, 'tiOnboard');
    const item = (it) => `<a class="it ${it.k === active ? 'on' : ''}" data-act="${it.act}">${ICON[it.icon] || DOT}<span>${esc(it.label)}</span>${it.count ? `<span class="n">${it.count}</span>` : ''}</a>`;
    const ti = on && !trained ? `<div class="sub">Get started</div>${item({ k: 'tiTrain', label: 'Train your model', icon: 'flask', act: 'page:tiTrain' })}<button class="tpbtn out" data-act="tiUnsubscribe" ${T.busy ? 'disabled' : ''}>Unsubscribe</button>`
      : on ? groups.map((g) => `<div class="sub">${esc(g.label)}</div>${g.items.map(item).join('')}`).join('')
      + `<button class="tpbtn out" data-act="tiUnsubscribe" ${T.busy ? 'disabled' : ''}>Unsubscribe</button>`
      : `<div class="subbox"><b>Times Intelligence</b><p>PayShield pay run assurance and ML anomaly detection trained on your own payroll.</p><button class="tpbtn" data-act="tiSubscribe" ${T.busy ? 'disabled' : ''}>${T.busy === 'tiSubscribe' ? 'Subscribing…' : 'Subscribe to Times Intelligence'}</button></div>`;
    const title = (crumb.match(/<b>(.*?)<\/b>/) || [, crumb])[1];
    return `<div class="tp"><aside><div class="co"><i></i>${esc(T.ctx?.companyName || 'CARLTON HOTEL (SINGAPORE) PTE LTD')}</div>
      ${Object.entries(STATIC).map(([h, xs]) => `<div class="${h === 'PRODUCT' ? 'sec' : 'plan'}">${h}</div>${xs.map((x) => x === 'Dashboard' ? `<a class="it ${active === 'tiDash' ? 'on' : ''}" data-act="page:tiDash">${ICON.home}<span>${x}</span></a>` : `<a class="it dim">${DOT}<span>${x}</span></a>`).join('')}`).join('')}
      <div class="sec ti">TIMES INTELLIGENCE <span class="new">NEW</span></div>${ti}
      <div class="ft">Times Portal · ${esc(T.ctx?.database || 'prod-is-down')} · <button data-act="resetRun">reset demo data</button></div></aside>
      <main><div class="top"><div><div style="color:#6b7280">Welcome back, Thilanka Potter!</div><b>October, 2026</b></div>
      <div class="who"><span class="av">TP</span><div><b>Thilanka Potter</b><div style="color:#6b7280;font-size:11px">Payroll Admin</div></div></div></div>
      <div class="content"><h2>${active === 'tiDash' ? '' : !on ? 'Times Intelligence' : active === 'tiOnboard' ? 'Welcome to Times Intelligence' : title}</h2>${active === 'tiDash' ? body : on || active === 'tiSubscribe' ? (on && !T.status ? '<div class="card muted">Checking your company model…</div>' : body) : subscribeBody()}</div></main>${on && trained && active === 'tiPayShield' ? fabHtml() : ''}</div>`;
  }

  /* ---------- portal dashboard (mock data, look-alike of the Times portal home) ---------- */
  function dashBody() {
    const d = new Date(), hr = d.getHours(), greet = hr < 12 ? 'Good morning' : hr < 18 ? 'Good afternoon' : 'Good evening';
    const C = 2 * Math.PI * 34, worked = 13.25;
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'], today = (d.getDay() + 6) % 7;
    const appr = [['DT', 'Daniel Tan', 'Leave', 'Annual leave · 13–15 Oct (3 days)'], ['SC', 'Shalini Chandran', 'Leave', 'Half day (PM) · 9 Oct'], ['KL', 'Kevin Lim', 'Claim', 'S$248.60 · Client lunch']];
    const kp = [['Headcount', '248', '+6.4% vs last period', ICON.users, 'b'], ['New hires', '9', '2 starting this month', ICON.users, 'g'],
      ['Attrition', '1.3%', '-0.4% vs last period', ICON.users, 'o'], ['Open roles', '12', '5 in final interviews', ICON.building || ICON.wallet, 'v']];
    const links = [['Apply Leave', ICON.calendar], ['Submit Claim', ICON.receipt], ['My Payslips', ICON.wallet], ['Timesheet', ICON.clock], ['Employee Directory', ICON.users]];
    const head = (ic, t, right = '', tone = 'b') => `<header class="db-h"><span class="db-ic ${tone}">${ic}</span><b>${t}</b><span class="db-r">${right}</span></header>`;
    return `<div class="db">
    <div class="db-row r1">
      <section class="db-card db-hello"><small class="muted">📅 ${d.toLocaleDateString('en-SG', { weekday: 'long', day: 'numeric', month: 'long', year: 'numeric' })}</small>
        <h2>${greet}, Thilanka Potter</h2><p>You have <b>5 pending approvals</b> and <b>2 events</b> coming up this week.<br>8 people are out today.</p>
        <div class="db-wx"><div class="db-wt"><span style="font-size:34px">⛅</span><b>31°</b><span>Partly cloudy<br><small class="muted">📍 Singapore · H 32° L 26°</small></span></div>
          <div class="db-wn">☂ Thunderstorms expected around 6 PM. Bring an umbrella.</div></div></section>
      <section class="db-card">${head(ICON.clock, 'My Workday', '<span class="db-pill g">Clocked in</span>')}
        <div class="db-work"><div class="db-ring"><svg viewBox="0 0 80 80"><circle cx="40" cy="40" r="34" stroke="#2563eb" stroke-width="6" fill="none" stroke-dasharray="${C}" stroke-dashoffset="${C * (1 - Math.min(1, worked / 9))}" transform="rotate(-90 40 40)"/></svg><div><b>13h 15m</b><small>of 9h 00m</small></div></div>
          <dl><dt>CLOCK IN</dt><dd>09:02 AM</dd><dt>SHIFT</dt><dd>9:00 – 18:00</dd><dt>THIS WEEK</dt><dd>36h 10m</dd></dl></div>
        <div class="db-week">${days.map((x, i) => `<div class="${i < today ? 'done' : i === today ? 'now' : ''}"><i></i><span>${x}</span></div>`).join('')}</div>
        <div style="text-align:right"><button class="db-btn red">⇥ Clock out</button></div></section>
    </div>
    <div class="db-row">
      <section class="db-card p0">${head(ICON.library || ICON.receipt, 'Pending Approvals', '<span class="db-cnt">5</span> <a>View all</a>')}
        <div class="db-tabs"><span class="on">All · 5</span><span>Leave · 2</span><span>Claims · 2</span><span>OT · 1</span></div>
        ${appr.map(([i, n, t, s]) => `<div class="db-ap"><span class="db-av">${i}</span><div><b>${n}</b><div><span class="db-tag ${t === 'Claim' ? 'b' : 'o'}">${t}</span> <small class="muted">${s}</small></div></div><span class="db-ok">✓</span><span class="db-no">✕</span></div>`).join('')}
        <footer><a>+2 more pending</a></footer></section>
      <section class="db-card p0">${head('📣', 'Announcements', '', 'o')}
        <div class="db-an"><span class="db-ic b">📣</span><div><b>Q4 Town Hall on 14 Oct</b> <span class="db-pill b">📌 Pinned</span><p>Join the CEO for the quarterly update, followed by Q&amp;A. Level 12 auditorium or via Teams.</p><small class="muted">HR Team · 23 Oct 2026</small></div></div>
        <div class="db-an"><span class="db-ic b">${ICON.shield}</span><div><b>2027 medical benefits enrolment opens</b><p>Review your coverage and add dependants before 31 Oct. New dental plan options are now available.</p><small class="muted">Benefits · 22 Oct 2026</small></div></div>
        <footer><a>View all announcements</a></footer></section>
    </div>
    <section class="db-card">${head(ICON.chart, 'HR Analytics', '<span class="db-seg"><span>3M</span><span>6M</span><span class="on">12M</span></span>')}
      <div class="db-kpis">${kp.map(([l, v, s, ic, t]) => `<div class="db-kpi ${t}"><small>${l}</small><b>${v}</b><span class="db-ki">${ic}</span><small class="muted">${s}</small></div>`).join('')}</div></section>
    <div class="db-row">
      <section class="db-card p0">${head('🔗', 'Quick Links', '<a>Edit</a>', 'v')}${links.map(([l, ic]) => `<div class="db-ln"><span class="db-li">${ic}</span>${l}<span class="db-r">›</span></div>`).join('')}</section>
      <section class="db-card p0">${head('✈', 'My Leave Balance', '<a>Apply leave</a>', 'g')}
        <div class="db-lv"><div class="db-lvh"><b>Annual leave</b><small class="muted">2026</small></div><div><span class="db-big">12</span> <span class="muted">of 18 days left</span></div>
          <div class="db-bar"><i style="width:22%"></i><i class="p" style="width:11%"></i></div>
          <small><span class="db-dot b"></span>Taken <b>4</b> &nbsp; <span class="db-dot l"></span>Pending <b>2</b> &nbsp; <span class="db-dot e"></span>Available <b>12</b></small>
          <div class="db-warn">⏱ Use 4 days by 31 Dec 2026 or they’ll expire</div></div>
        ${[['Medical leave', 11, 14], ['Childcare leave', 4, 6]].map(([n, l, t]) => `<div class="db-lv2"><div class="db-lvh"><span>${n}</span><span><b>${l}</b> <small class="muted">/ ${t} days left</small></span></div><div class="db-bar"><i style="width:${(t - l) / t * 100}%"></i></div></div>`).join('')}</section>
    </div></div>`;
  }

  /* ---------- PayShield Agent (real): fixed read-only tools on the Times Intelligence API, no LLM-written SQL ---------- */
  const A = (T.ag = { msgs: [], analysis: null, review: -1, demo: false });
  const MONTHS = ['jan', 'feb', 'mar', 'apr', 'may', 'jun', 'jul', 'aug', 'sep', 'oct', 'nov', 'dec'];
  const SEV_W = { CRITICAL: 8, HIGH: 4, MEDIUM: 2, LOW: 1 };
  const RESOLVED = ['EXPECTED_CHANGE', 'FALSE_POSITIVE'];
  const OUTCOMES = [['CONFIRMED_ERROR', 'Confirm error', 'p'], ['EXPECTED_CHANGE', 'Expected change', ''], ['FALSE_POSITIVE', 'False alarm', ''], ['NEEDS_INVESTIGATION', 'Investigate later', '']];
  const isRunAsk = (q) => /(check|analy[sz]e|review|audit|scan|validate|verify|go through)/i.test(q) && /(pay ?run|payroll|pay score|month|run|latest|this|last|\b(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec))/i.test(q);
  const atRisk = (x) => (/hour/i.test(x.metric || '') || x.currentValue == null || x.expectedValue == null ? 0 : Math.abs(x.currentValue - x.expectedValue));
  const open = (a) => a.anomalies.filter((x) => !RESOLVED.includes(x.latestFeedback));

  function payScore(a) {
    const o = open(a), flagged = new Set(o.map((x) => x.employeeNo)).size;
    const clean = a.totalEmployees ? 1 - flagged / a.totalEmployees : 1;
    const penalty = Math.min(40, o.reduce((s, x) => s + (SEV_W[x.severity] || 1), 0));
    const blocking = o.some((x) => x.severity === 'CRITICAL' || x.severity === 'HIGH');
    let score = Math.max(0, Math.round(100 * clean - penalty));
    if (blocking) score = Math.min(score, 79);
    const verdict = score >= 90 ? 'Ready' : score >= 80 ? 'Review' : 'Not ready';
    return { score, verdict, flagged, blocking, risk: o.reduce((s, x) => s + atRisk(x), 0), open: o.length };
  }

  function pickRun(q) {
    const t = q.toLowerCase();
    const mi = MONTHS.findIndex((m) => new RegExp(`\\b${m}`).test(t));
    const y = (t.match(/\b(20\d\d)\b/) || [])[1];
    if (mi >= 0) {
      const mm = String(mi + 1).padStart(2, '0');
      const r = T.runs.find((x) => x.period.startsWith(mm + '/') && (!y || x.period.endsWith(y)));
      if (r) return r;
    }
    return T.runs.find((x) => x.uid === T.run) || T.runs[0];
  }

  const say = (m) => { A.msgs.push(m); render(); if (document.querySelector('.fab-msgs')) return fabScroll(); setTimeout(() => document.querySelector('.ag-end')?.scrollIntoView({ block: 'end', behavior: 'smooth' }), 30); };
  async function tool(steps, name, label, fn) {
    const t0 = performance.now(); const out = await fn();
    steps.push({ name, label, ms: Math.round(performance.now() - t0), out: typeof out === 'string' ? out : '' });
    return out;
  }

  async function runCheck(q) {
    const steps = [];
    if (!isTrained('PAYROLL')) {
      if (isTrained('IDENTIFICATION')) return identityAnswer(steps);
      return say({ who: 'agent', kind: 'text', steps, src: 'error', text: 'The Payroll area is not trained yet. Train it on the Train model page to check pay runs.' });
    }
    if (!T.runs.length) await tool(steps, 'payrun.list', 'List pay runs for this company', loadRuns);
    const run = pickRun(q);
    if (!run) throw new Error('No pay runs found for this company.');
    steps.push({ name: 'payrun.read', label: `Read ${run.name} (${run.period})`, ms: 0, out: `${run.records} pay records` });
    const a = await tool(steps, 'payroll.analyze', 'Rules + company model on every employee vs their own history',
      () => api(`/api/v1/payroll/runs/${run.uid}/analysis`).catch(() => api('/api/v1/payroll/analyze', { method: 'POST', body: JSON.stringify({ payRunId: run.uid }) })));
    steps[steps.length - 1].out = `${a.anomalyCount} findings · ${a.flaggedEmployees}/${a.totalEmployees} employees · model ${a.modelVersion ? 'v' + a.modelVersion : 'none'} (${a.mlStatus.toLowerCase()})`;
    const p = payScore(a);
    steps.push({ name: 'payscore.compute', label: 'Compute the Pay Score', ms: 0, out: `${p.score}/100 · ${p.verdict}` });
    let identity = null;
    if (isTrained('IDENTIFICATION')) {
      identity = await tool(steps, 'identity.check', 'Identification checks (NRIC/FIN, bank accounts, work passes, changes since training)', () => api('/api/v1/identity/check'));
      steps[steps.length - 1].out = `${identity.findingCount} identity finding(s) on ${identity.flaggedEmployees} employee(s)`;
    }
    A.analysis = a; T.analysis = a; T.run = run.uid; A.review = -1;
    say({ who: 'agent', kind: 'report', steps, at: new Date(), identity });
  }

  /* ---------- lookup tools: fixed read-only queries on the AI service (no LLM, no generated SQL) ---------- */
  const qs = (o) => Object.entries(o).filter(([, v]) => v != null && v !== '').map(([k, v]) => `${k}=${encodeURIComponent(v)}`).join('&');
  const money = (v) => (v == null ? '—' : 'S$' + Number(v).toLocaleString(undefined, { minimumFractionDigits: 0, maximumFractionDigits: 0 }));
  const RULE_WORDS = /\b(cpf|iras|mom|sdl|levy|tax|ir8a|prorat|entitle|ceiling|share award|bonus rule|aws|annual wage|notice|overtime rule|work pass|ep |s pass|skillsfuture|nsman|maternity|paternity|childcare leave)\b/i;

  async function identityAnswer(steps) {
    const r = await tool(steps, 'identity.check', 'Identification checks (NRIC/FIN, bank accounts, work passes, changes since training)', () => api('/api/v1/identity/check'));
    steps[steps.length - 1].out = `${r.findingCount} finding(s)`;
    T.ident = r;
    return say({ who: 'agent', kind: 'findings', steps, src: 'identity', items: r.findings, emp: null,
      title: r.findingCount ? `${r.findingCount} identity issue${r.findingCount > 1 ? 's' : ''} on ${r.flaggedEmployees} employee${r.flaggedEmployees > 1 ? 's' : ''}` : `No identity issues across ${r.employees.toLocaleString()} employees`,
      empty: 'Every employee has a unique NRIC/FIN and bank account, valid work passes, and nothing changed since training.' });
  }

  // "who has salary below 5000", "net pay over 8k", "basic between 3000 and 4000", "top 10 highest paid"
  function amountFilter(q) {
    const t = q.toLowerCase().replace(/,/g, '');
    const num = (s) => { const m = s.match(/(\d+(?:\.\d+)?)\s*(k)?/); return m ? +m[1] * (m[2] ? 1000 : 1) : null; };
    const metric = /\bnet\b|take.?home/.test(t) ? 'net' : /\bgross\b/.test(t) ? 'gross' : 'basic';
    const money = /(salary|salaries|pay|paid|earn|basic|net|gross|wage|income)/.test(t);
    let m;
    if ((m = t.match(/between\s+\$?s?\$?(\d[\d.]*\s*k?)\s+(?:and|to|-)\s+\$?s?\$?(\d[\d.]*\s*k?)/))) return money && { metric, min: num(m[1]), max: num(m[2]) };
    if ((m = t.match(/(?:below|under|less than|lower than|<|not more than|up to)\s*\$?s?\$?\s*(\d[\d.]*\s*k?)/))) return money && { metric, max: num(m[1]) };
    if ((m = t.match(/(?:above|over|more than|greater than|higher than|>|at least|exceeds?)\s*\$?s?\$?\s*(\d[\d.]*\s*k?)/))) return money && { metric, min: num(m[1]) };
    if (/(top|highest|lowest|bottom|least)/.test(t) && /(paid|earn|salar|\bpay\b|\bpays\b)/.test(t) && !/(anomal|finding|risk|issue|problem)/.test(t)) {
      const n = (t.match(/(?:top|bottom|highest|lowest)\s+(\d+)/) || t.match(/\b(\d{1,3})\b/) || [])[1];
      return { metric, sort: /lowest|bottom|least/.test(t) ? 'asc' : 'desc', limit: Math.min(+(n || 10), 50) };
    }
    return null;
  }

  // "what are the pay runs not run in May?", "which pay runs are completed in 2026?", "is the October pay run done?"
  const FULL_MONTHS = ['january', 'february', 'march', 'april', 'may', 'june', 'july', 'august', 'september', 'october', 'november', 'december'];
  function runStatusIntent(q) {
    const t = q.toLowerCase();
    if (!/(pay ?runs?|payrolls?)/.test(t)) return null;
    if (/(total|gross|cost|compare|versus|\bvs\b|salary|anomal|finding|employee|staff|highest|lowest|identity)/.test(t)) return null;
    const notRun = /(\bnot\b|n['’]t|pending|outstanding|unrun|un-run|still to|yet to|waiting|open)/.test(t);
    const done = !notRun && /(completed?|done|finished|locked|paid|released|been run|\bran\b)/.test(t);
    if (!notRun && !done && !/(status|which|what|list|show)/.test(t)) return null;
    const months = FULL_MONTHS.map((m, i) => (new RegExp(`\\b(${m}|${m.slice(0, 3)})\\b`).test(t) ? i : -1)).filter((i) => i >= 0);
    const y = (t.match(/\b(20\d\d)\b/) || [])[1];
    const year = y ? +y : /this year/.test(t) ? new Date().getFullYear() : /last year/.test(t) ? new Date().getFullYear() - 1 : null;
    const yesno = /^\s*(is|are|has|have|was|were|did)\b/.test(t) && months.length > 0;
    return { months, year, want: yesno ? 'all' : notRun ? 'notrun' : done ? 'done' : 'all', yesno };
  }
  async function runStatus(f, steps) {
    const runs = (await tool(steps, 'payrun.status', 'Read every pay run with its PayShield check and lock status', () => api('/api/v1/pay-runs'))).payRuns;
    const now = new Date(), period = (r) => ({ m: +r.period.slice(0, 2) - 1, y: +r.period.slice(3) });
    const scope = runs.filter((r) => { const x = period(r); return (!f.months.length || f.months.includes(x.m)) && (!f.year || x.y === f.year); });
    const state = (r) => {
      if (r.locked) return ['done', 'Completed', `by ${String(r.released_by || '').startsWith('svc:') ? 'Payroll Admin' : r.released_by || '—'} on ${new Date(r.released_on || r.pay_run_date).toLocaleDateString('en-SG', { day: 'numeric', month: 'short', year: 'numeric' })}`];
      const ps = PS.scoreFor(r.uid);
      if (ps) return ps.score === 100 ? ['ready', 'Ready to run', 'PayShield 100'] : ['blocked', 'Not run · blocked', `PayShield ${ps.score} · ${ps.open} open`];
      if (r.analysis_id && !r.anomaly_count) return ['ready', 'Not run · ready', 'checked, no payroll findings'];
      return r.analysis_id ? ['blocked', 'Not run · checked', `${r.anomaly_count} payroll finding${r.anomaly_count === 1 ? '' : 's'} to review`] : ['unchecked', 'Not run · not checked', 'not processed in PayShield'];
    };
    const rows = scope.map((r) => ({ r, s: state(r) })).filter(({ s: st }) => f.want === 'all' || (f.want === 'done' ? st[0] === 'done' : st[0] !== 'done'));
    // past months in scope with no pay run at all also count as "not run"
    const missing = [], first = runs.length ? Math.min(...runs.map((r) => { const x = period(r); return x.y * 12 + x.m; })) : 0;
    if (f.want !== 'done' && (f.months.length || f.year)) {
      const years = f.year ? [f.year] : [...new Set(runs.map((r) => period(r).y))];
      for (const yy of years) for (const mm of f.months.length ? f.months : [...Array(12).keys()]) {
        if (new Date(yy, mm, 1) <= now && yy * 12 + mm >= first && !runs.some((r) => period(r).y === yy && period(r).m === mm)) missing.push(`${FULL_MONTHS[mm][0].toUpperCase()}${FULL_MONTHS[mm].slice(1, 3)} ${yy}`);
      }
    }
    steps[steps.length - 1].out = `${scope.length} pay run(s) in scope · ${rows.length} match`;
    const what = `${f.months.length ? f.months.map((m) => FULL_MONTHS[m][0].toUpperCase() + FULL_MONTHS[m].slice(1)).join(', ') + ' ' : ''}${f.year || ''}`.trim();
    return { who: 'agent', kind: 'runstatus', steps, src: 'lookup', rows, missing, want: f.want, what, yesno: f.yesno };
  }

  async function lookupIntent(q, steps) {
    const t = q.toLowerCase();
    const rs = runStatusIntent(q);
    if (rs) return runStatus(rs, steps);
    const af = amountFilter(q);
    if (af) {
      const label = af.sort ? `${af.sort === 'desc' ? 'Top' : 'Lowest'} ${af.limit} by ${af.metric} pay`
        : `${af.metric} pay ${af.min != null && af.max != null ? `between S$${af.min.toLocaleString()} and S$${af.max.toLocaleString()}` : af.max != null ? `below S$${af.max.toLocaleString()}` : `of S$${af.min.toLocaleString()} or more`}`;
      const r = await tool(steps, 'employee.filter', `Employees with ${label} (latest pay run)`,
        () => api(`/api/v1/lookup/employees?${qs({ metric: af.metric, min_amount: af.min, max_amount: af.max, sort: af.sort || 'asc', limit: af.limit || 50 })}`));
      steps[steps.length - 1].out = `${r.total} employee(s)`;
      return { who: 'agent', kind: 'directory', steps, src: 'lookup', data: r, label, ranked: !!af.sort };
    }
    if (/(identit|identification|nric|\bfin\b|work ?pass|bank account|ghost|duplicate (employee|id)|shared (bank|account|phone))/i.test(q)) {
      if (!isTrained('IDENTIFICATION')) return { who: 'agent', kind: 'text', steps, src: 'error', text: 'The Identification area is not trained yet. Tick Identification on the Train model page and train it.' };
      await identityAnswer(steps);
      return { skip: true };
    }
    const emp = (q.match(/\b[A-Z]{1,3}\d{3,}\b/i) || [])[0];
    if (emp && /(history|last \d+|months|pay of|salary|payslip|earn|paid|trend)/i.test(q) && !/(why|flag|anomal|finding|wrong)/i.test(q)) {
      const months = +(t.match(/last (\d+)/) || [])[1] || 6;
      const h = await tool(steps, 'employee.payHistory', `Pay history for ${emp.toUpperCase()} (${months} months)`, () => api(`/api/v1/lookup/employees/${encodeURIComponent(emp)}/pay-history?months=${months}`));
      steps[steps.length - 1].out = `${h.history.length} pay records`;
      return { who: 'agent', kind: 'history', steps, src: 'lookup', data: h };
    }
    if (/(compare|vs\.?|versus|difference|changed|change[sd]? (from|since)|biggest change|moved)/i.test(q)) {
      const c = await tool(steps, 'payrun.compare', 'Compare the latest pay run with the previous one', () => api(`/api/v1/lookup/pay-runs/compare?top=10`));
      steps[steps.length - 1].out = `${c.current.name} vs ${c.previous.name}`;
      return { who: 'agent', kind: 'compare', steps, src: 'lookup', data: c };
    }
    if (/(total|gross|payroll cost|how much (did|do) we pay|wage bill|cost of|run summary|pay run summary|trend)/i.test(q) && !RULE_WORDS.test(q)) {
      const n = +(t.match(/last (\d+)/) || [])[1] || 6;
      const r = await tool(steps, 'payrun.totals', `Totals for the last ${n} pay runs`, () => api(`/api/v1/lookup/pay-runs/totals?limit=${n}`));
      steps[steps.length - 1].out = `${r.runs.length} pay runs`;
      return { who: 'agent', kind: 'totals', steps, src: 'lookup', data: r.runs };
    }
    if (/^\s*(find|search|look ?up)\b/i.test(q) || (/(list|show|all|find|search|who are|directory|headcount|how many employees|staff|people)/i.test(q) && /(employee|staff|people|headcount|directory|worker)/i.test(q) && !/(overtime|flag|anomal|finding)/i.test(q))) {
      const term = (q.match(/(?:named|called|name|search|find|matching|like)\s+["']?([\w .-]{2,40})/i) || [])[1] || (emp || '');
      const r = await tool(steps, 'employee.directory', term ? `Search employees for “${term}”` : 'Employee directory', () => api(`/api/v1/lookup/employees?${qs({ q: term.trim(), limit: 25 })}`));
      steps[steps.length - 1].out = `${r.total} employee(s)`;
      return { who: 'agent', kind: 'directory', steps, src: 'lookup', data: r, term };
    }
    if (RULE_WORDS.test(q) || /^(how|what|when|is|are|do|does|can)\b/i.test(q.trim())) {
      const kb = await import('./kb.js');
      const hit = kb.search(q, 1)[0];
      if (hit && hit.score > 4 && RULE_WORDS.test(q + ' ' + hit.entry.k)) {
        steps.push({ name: 'rules.knowledge', label: 'Search the rule knowledge base (CPF, IRAS, MOM)', ms: 0, out: hit.entry.id });
        return { who: 'agent', kind: 'rule', steps, src: 'knowledge', data: hit.entry };
      }
    }
    return null;
  }

  function lookupHtml(m) {
    const d = m.data;
    if (m.kind === 'directory') {
      return `<div class="ag-sum"><span class="ag-si">👥</span><div><b>${m.ranked ? `${esc(m.label)} (latest pay run)` : `${d.total.toLocaleString()} employee${d.total === 1 ? '' : 's'}`}${m.ranked ? '' : m.label ? ` with ${esc(m.label)}` : m.term ? ` matching “${esc(m.term)}”` : ' in this company'}</b><small>${m.ranked ? `Out of ${d.total.toLocaleString()} employees` : d.total > d.employees.length ? `Showing the first ${d.employees.length}. Ask “find &lt;name or number&gt;” to narrow it down.` : 'Latest pay shown for each'}</small></div></div>
        <div class="tblwrap"><table class="ag-t ag-dir"><tr><th>Employee</th><th>Hired</th><th>Last pay run</th><th>Basic</th><th>Gross</th><th>Net pay</th></tr>
        ${d.employees.map((e) => `<tr><td><span class="db-av sm">${esc((e.name || '?').split(' ').pop().slice(0, 2))}</span><div><b>${esc(e.employee_no)}</b><small class="muted">${esc(e.name)}</small></div></td>
          <td>${esc(String(e.hired || '').slice(0, 10))}</td><td>${esc(e.last_period || '—')}</td><td>${money(e.basic)}</td><td>${money(e.gross)}</td><td><b>${money(e.net)}</b></td></tr>`).join('')}</table></div>`;
    }
    if (m.kind === 'history') {
      const h = [...d.history].reverse(), max = Math.max(1, ...h.map((x) => +x.gross || +x.net || 0));
      const last = d.history[0], prev = d.history[1];
      const ch = last && prev && +prev.net ? ((last.net - prev.net) / prev.net) * 100 : null;
      return `<div class="ag-sum"><span class="ag-si">👤</span><div><b>${esc(d.employee_no)} · ${esc(d.name)}</b><small>Hired ${esc(String(d.hired || '').slice(0, 10))} · last ${d.history.length} pay records</small></div>
          ${ch != null ? `<span class="ag-delta ${ch >= 0 ? 'up' : 'down'}" style="margin-left:auto">${ch >= 0 ? '▲' : '▼'} ${Math.abs(ch).toFixed(1)}% vs last month</span>` : ''}</div>
        <div class="ag-spark">${h.map((x) => `<div title="${esc(x.period)}: net ${money(x.net)}"><span style="height:${((+x.gross || +x.net) / max) * 100}%"><i style="height:${(+x.net / (+x.gross || +x.net || 1)) * 100}%"></i></span><small>${esc(x.period.slice(0, 2))}/${esc(x.period.slice(5))}</small></div>`).join('')}</div>
        <small class="muted"><span class="db-dot b"></span>net pay &nbsp; <span class="db-dot l"></span>gross pay</small>
        <div class="tblwrap" style="margin-top:10px"><table class="ag-t"><tr><th>Period</th><th>Basic</th><th>Allowances</th><th>Deductions</th><th>CPF</th><th>Gross</th><th>Net</th></tr>
        ${d.history.map((x) => `<tr><td><b>${esc(x.period)}</b><div><small class="muted">${esc(x.pay_run)}</small></div></td><td>${money(x.basic)}</td><td>${money(x.allowances)}</td><td>${money(x.deductions)}</td><td>${money(x.cpf)}</td><td>${money(x.gross)}</td><td><b>${money(x.net)}</b></td></tr>`).join('')}</table></div>`;
    }
    if (m.kind === 'totals') {
      const r = d[0], p = d[1], max = Math.max(1, ...d.map((x) => +x.gross));
      const dl = (a, b) => (b && +b ? `<span class="ag-delta ${a >= b ? 'up' : 'down'}" style="font-size:11px;padding:1px 7px">${a >= b ? '▲' : '▼'} ${Math.abs(((a - b) / b) * 100).toFixed(1)}%</span>` : '');
      return `<div class="ag-sum"><span class="ag-si">💰</span><div><b>${esc(r.name)}: ${money(r.gross)} gross, ${money(r.net)} net</b><small>${r.headcount.toLocaleString()} employees${p ? ` · compared with ${esc(p.name)}` : ''}</small></div></div>
        <div class="ag-kp">${[['Headcount', r.headcount.toLocaleString(), p && dl(r.headcount, p.headcount)], ['Gross pay', money(r.gross), p && dl(r.gross, p.gross)], ['Net pay', money(r.net), p && dl(r.net, p.net)],
          ['CPF (total)', money(r.cpf), p && dl(r.cpf, p.cpf)], ['Allowances', money(r.allowances), p && dl(r.allowances, p.allowances)], ['Joiners / leavers', `${r.new_hires} / ${r.leavers}`, '']].map(([l, v, x]) => `<div><small>${l}</small><b>${v}</b>${x || ''}</div>`).join('')}</div>
        <div class="ag-bars" style="margin-top:12px">${[...d].reverse().map((x) => `<div><span>${esc(x.name)}</span><span class="ag-cb"><i class="e2" style="width:${(+x.gross / max) * 100}%"></i></span><b style="width:auto">${money(x.gross)}</b></div>`).join('')}</div>`;
    }
    if (m.kind === 'compare') {
      const a = d.current, b = d.previous;
      const row = (l, k) => { const x = +a[k], y = +b[k], c = y ? ((x - y) / y) * 100 : 0; return `<tr><td>${l}</td><td>${k === 'headcount' ? y.toLocaleString() : money(y)}</td><td><b>${k === 'headcount' ? x.toLocaleString() : money(x)}</b></td><td><span class="ag-delta ${c >= 0 ? 'up' : 'down'}" style="font-size:11px;padding:1px 8px">${c >= 0 ? '▲' : '▼'} ${Math.abs(c).toFixed(2)}%</span></td></tr>`; };
      return `<div class="ag-sum"><span class="ag-si">⇄</span><div><b>${esc(a.name)} vs ${esc(b.name)}</b><small>${d.only_in_current} joined · ${d.only_in_previous} left · ${d.top_changes.length} biggest net-pay changes below</small></div></div>
        <div class="tblwrap"><table class="ag-t"><tr><th></th><th>${esc(b.name)}</th><th>${esc(a.name)}</th><th>Change</th></tr>${row('Headcount', 'headcount')}${row('Gross pay', 'gross')}${row('Net pay', 'net')}${row('CPF', 'cpf')}${row('Allowances', 'allowances')}${row('Deductions', 'deductions')}</table></div>
        ${d.top_changes.length ? `<h4 style="margin:14px 0 8px">Biggest net-pay changes</h4><div class="ag-fl">${d.top_changes.map((x) => `<div class="ag-mv"><div><b>${esc(x.employee_no)}</b><small class="muted">${esc(x.name)}</small></div><span>${money(x.previous)} → <b>${money(x.current)}</b></span><span class="ag-delta ${x.change >= 0 ? 'up' : 'down'}">${x.change >= 0 ? '▲' : '▼'} ${money(Math.abs(x.change))}${x.change_pct != null ? ` (${Math.abs(x.change_pct)}%)` : ''}</span></div>`).join('')}</div>` : ''}`;
    }
    if (m.kind === 'rule') {
      return `<div class="ag-sum"><span class="ag-si">📘</span><div><b>${esc(d.q)}</b><small>${esc(d.cat)} · from the PayShield rule knowledge base</small></div></div>
        <div class="ag-txt" style="padding:4px 2px">${esc(d.a)}</div>${d.src ? `<small class="muted">Source: <a href="${esc(d.src)}" target="_blank" rel="noopener">${esc(d.src)}</a> · check the official page for changes after the knowledge base date.</small>` : ''}`;
    }
    return '';
  }

  async function answer(q) {
    const steps = [];
    if (!A.analysis) {
      if (!T.runs.length) await tool(steps, 'payrun.list', 'List pay runs', loadRuns);
      const run = pickRun(q);
      A.analysis = T.analysis = await tool(steps, 'payroll.analyze', `Analyse ${run.name} first`, () => api('/api/v1/payroll/analyze', { method: 'POST', body: JSON.stringify({ payRunId: run.uid }) }));
    }
    const a = A.analysis;
    const emp = (q.match(/\b[A-Z]{1,3}\d{3,}\b/i) || [])[0];
    if (/pay ?score/i.test(q)) { const p = payScore(a); return say({ who: 'agent', kind: 'text', steps, text: `Pay Score for ${a.payrollPeriod}: ${p.score}/100 (${p.verdict}). ${p.open} open finding(s) on ${p.flagged} employee(s)${p.blocking ? '; high-severity findings cap the score at 79' : ''}.`, src: 'computed' }); }
    if (emp) {
      const f = a.anomalies.filter((x) => (x.employeeNo || '').toLowerCase() === emp.toLowerCase());
      steps.push({ name: 'findings.employee', label: `Findings for ${emp}`, ms: 0, out: `${f.length} finding(s)` });
      return say({ who: 'agent', kind: 'findings', steps, src: 'analysis', emp: emp.toUpperCase(), items: f,
        title: f.length ? `${emp.toUpperCase()} has ${f.length} finding${f.length > 1 ? 's' : ''} in ${a.payrollPeriod}` : `${emp.toUpperCase()} looks fine in ${a.payrollPeriod}`,
        empty: 'Their pay is consistent with their own history and all payroll rules.' });
    }
    if (/(highest|top|riskiest|worst|most risk|critical|biggest)/i.test(q)) {
      const top = [...a.anomalies].sort((x, y) => y.riskScore - x.riskScore).slice(0, 5);
      steps.push({ name: 'findings.top', label: 'Highest-risk findings', ms: 0, out: `${top.length} of ${a.anomalyCount}` });
      return say({ who: 'agent', kind: 'findings', steps, src: 'analysis', items: top, title: `Top ${top.length} highest-risk findings in ${a.payrollPeriod}`, empty: 'No findings in this run.' });
    }
    if (/(how many|count|number of|breakdown)/i.test(q)) {
      const key = /severity/i.test(q) ? 'severity' : 'anomalyType';
      let rows = Object.entries(a.anomalies.reduce((m, x) => ((m[x[key]] = (m[x[key]] || 0) + 1), m), {})).sort((x, y) => y[1] - x[1]);
      const topic = (q.toLowerCase().match(/overtime|salary|allowance|deduction|net pay|cpf|bonus/) || [])[0];
      if (topic) rows = rows.filter(([k]) => k.toLowerCase().replaceAll('_', ' ').includes(topic.replace('cpf', 'statutory'))).concat([]);
      const n = rows.reduce((s, r) => s + r[1], 0);
      steps.push({ name: 'findings.count', label: `Count findings by ${key === 'severity' ? 'severity' : 'type'}`, ms: 0, out: `${n} finding(s)` });
      return say({ who: 'agent', kind: 'counts', steps, src: 'analysis', rows: rows.length ? rows : [[topic ? 'unusual ' + topic : 'findings', 0]],
        title: topic ? `${n} employee finding${n === 1 ? '' : 's'} on ${topic} in ${a.payrollPeriod}` : `${n} findings in ${a.payrollPeriod} by ${key === 'severity' ? 'severity' : 'type'}`,
        items: topic ? a.anomalies.filter((x) => x.anomalyType.toLowerCase().replaceAll('_', ' ').includes(topic)) : [] });
    }
    const r = await tool(steps, 'assistant.ask', 'Read-only assistant over this analysis', () => api('/api/v1/assistant/ask', { method: 'POST', body: JSON.stringify({ question: q, analysisId: a.analysisId }) }));
    if (r.status === 'FALLBACK') return teachMe(q, steps, r.answer);
    say({ who: 'agent', kind: 'text', steps, text: r.answer, src: r.status });
  }

  /* rich answer cards */
  const SEV_ICON = { CRITICAL: '⛔', HIGH: '⚠', MEDIUM: '◆', LOW: 'ℹ' };
  function findingCard(x) {
    const cur = Number(x.currentValue), exp = Number(x.expectedValue), has = x.currentValue != null && x.expectedValue != null;
    const max = has ? Math.max(cur, exp, Number(x.expectedHigh) || 0) || 1 : 1;
    const ch = x.changePct != null ? Number(x.changePct) : has && exp ? ((cur - exp) / exp) * 100 : null;
    return `<div class="ag-f s-${x.severity}">
      <div class="ag-fh"><span class="ag-fi">${SEV_ICON[x.severity] || '•'}</span><div><b>${esc(x.anomalyType.replaceAll('_', ' ').toLowerCase())}</b>
        <div class="ag-fm"><span class="ti-sev s-${x.severity}">${x.severity}</span><span class="ag-chip">👤 ${esc(x.employeeNo)}</span><span class="ag-chip">${x.ruleId ? 'Rule ' + esc(x.ruleId) : 'AI model'}</span><span class="ag-chip">Risk ${x.riskScore}</span></div></div>
        ${atRisk(x) ? `<div class="ag-amt"><small>At risk</small><b>S$${Math.round(atRisk(x)).toLocaleString()}</b></div>` : ''}</div>
      <p class="ag-fd">${esc(x.description)}</p>
      ${has ? `<div class="ag-cmp"><div><small>Expected</small><span class="ag-cb"><i class="e" style="width:${(exp / max) * 100}%"></i></span><b>${num(exp)}</b></div>
        <div><small>This run</small><span class="ag-cb"><i class="c s-${x.severity}" style="width:${(cur / max) * 100}%"></i></span><b>${num(cur)}</b></div>
        ${ch != null && isFinite(ch) ? `<span class="ag-delta ${ch >= 0 ? 'up' : 'down'}">${ch >= 0 ? '▲' : '▼'} ${Math.abs(ch).toFixed(1)}%</span>` : ''}</div>` : ''}
      <div class="ag-fix"><span>💡</span><div><small>Suggested fix</small>${esc(x.recommendedAction)}</div></div></div>`;
  }
  function answerHtml(m) {
    if (['directory', 'history', 'totals', 'compare', 'rule'].includes(m.kind)) return lookupHtml(m);
    if (m.kind === 'runstatus') {
      const label = m.want === 'notrun' ? 'not run yet' : m.want === 'done' ? 'completed' : '';
      const n = m.rows.length + (m.want === 'notrun' ? m.missing.length : 0);
      const allDone = m.rows.length && m.rows.every(({ s: st }) => st[0] === 'done');
      const head = m.yesno ? (!m.rows.length ? `No, there is no ${m.what} pay run yet` : allDone ? `Yes, ${m.rows.map(({ r }) => r.name).join(', ')} ${m.rows.length === 1 ? 'is' : 'are'} completed` : `No, ${m.rows.filter(({ s: st }) => st[0] !== 'done').map(({ r }) => r.name).join(', ')} ${m.rows.length === 1 ? 'is' : 'are'} not run yet`)
        : `${n} ${m.what ? m.what + ' ' : ''}pay run${n === 1 ? '' : 's'} ${label || 'found'}`;
      const sub = m.yesno ? (allDone ? 'Released after PayShield reached 100, then locked.' : 'Open it in PayShield to resolve what is left, then run payroll.') : m.want === 'notrun' ? (n ? 'Not locked yet. Open one to check it in PayShield and run payroll.' : 'Every pay run in this period is completed.') : m.want === 'done' ? 'Released after PayShield reached 100, then locked.' : 'Completed, ready, blocked or not checked.';
      return `<div class="ag-sum ${(m.yesno ? allDone : !n || m.want === 'done') ? 'ok' : ''}"><span class="ag-si">${(m.yesno ? allDone : m.want === 'done' || !n) ? '✓' : '🗓'}</span><div><b>${esc(head)}</b><small>${esc(sub)}</small></div></div>
        ${m.rows.length ? `<div class="ag-rs">${m.rows.map(({ r, s: st }) => `<div class="ag-rsr ${st[0]}"><div><b>${esc(r.name)}</b><small>${r.records} employees · net S$${Math.round(r.net).toLocaleString()}</small></div>
          <div><span class="ag-rst ${st[0]}">${esc(st[1])}</span><small>${esc(st[2])}</small></div>${st[0] === 'done' ? '' : `<button class="btn sm" data-act="tiOpenMonth:${r.period}">Open in PayShield →</button>`}</div>`).join('')}</div>` : ''}
        ${m.want !== 'done' && m.missing.length ? `<div class="ag-rsm">No pay run created yet for: <b>${m.missing.map(esc).join(', ')}</b></div>` : ''}`;
    }
    if (m.kind === 'findings') {
      const risk = m.items.reduce((s, x) => s + atRisk(x), 0);
      return `<div class="ag-sum ${m.items.length ? '' : 'ok'}"><span class="ag-si">${m.items.length ? (m.emp ? '👤' : '🔎') : '✓'}</span><div><b>${esc(m.title)}</b><small>${m.items.length ? `${m.items.length} finding${m.items.length > 1 ? 's' : ''}${risk ? ` · about S$${Math.round(risk).toLocaleString()} at risk` : ''}` : esc(m.empty)}</small></div></div>
        <div class="ag-fl">${m.items.map(findingCard).join('')}</div>`;
    }
    if (m.kind === 'counts') {
      const max = Math.max(1, ...m.rows.map((r) => r[1]));
      return `<div class="ag-sum"><span class="ag-si">📊</span><div><b>${esc(m.title)}</b><small>From the latest analysis of this pay run</small></div></div>
        <div class="ag-bars">${m.rows.map(([k, n]) => `<div><span>${esc(String(k).replaceAll('_', ' ').toLowerCase())}</span><span class="ag-cb"><i class="${SEV_W[k] ? 's-' + k : 'e2'}" style="width:${(n / max) * 100}%"></i></span><b>${n}</b></div>`).join('')}</div>
        ${m.items?.length ? `<div class="ag-fl">${m.items.map(findingCard).join('')}</div>` : ''}`;
    }
    const lines = String(m.text || '').split('\n').filter((l) => l.trim());
    const bullets = lines.filter((l) => /^\s*[-•]/.test(l)), head = lines.filter((l) => !/^\s*[-•]/.test(l));
    return `${head.length ? `<div class="ag-sum ${m.src === 'REFUSED' ? 'no' : ''}"><span class="ag-si">${m.src === 'REFUSED' ? '🔒' : m.src === 'error' ? '⚠' : '💬'}</span><div><b>${esc(head[0])}</b>${head.slice(1).map((h) => `<small>${esc(h)}</small>`).join('')}</div></div>` : ''}
      ${bullets.length ? `<ul class="ag-li">${bullets.map((b) => `<li>${esc(b.replace(/^\s*[-•]\s*/, '').replaceAll('_', ' '))}</li>`).join('')}</ul>` : ''}`;
  }

  async function send(q, routed = false) {
    q = String(q || '').trim(); if (!q || T.busy) return;
    if (!routed) say({ who: 'me', text: q });
    let next = null;
    await act('tiAgent', async () => {
      try {
        // something a user taught the agent comes first (matched by meaning of the words, no LLM)
        if (!routed) {
          const m = await api('/api/v1/agent/skills/match', { method: 'POST', body: JSON.stringify({ question: q }) }).catch(() => ({}));
          if (m.skill) {
            say({ who: 'agent', kind: 'taught', src: 'taught', q, skill: m.skill, score: m.score });
            if (m.skill.kind === 'ROUTE') next = m.skill.route;
            return;
          }
        }
        if (isRunAsk(q)) await runCheck(q);
        else { const steps = []; const m = await lookupIntent(q, steps); if (m) { if (!m.skip) say(m); } else if (isTrained('PAYROLL')) await answer(q); else await teachMe(q, steps); }
      } catch (e) { say({ who: 'agent', kind: 'text', text: 'Sorry, that failed: ' + e.message, src: 'error' }); }
    });
    if (next) send(next, true);
  }
  // the agent does not know this yet: remember the question and offer to be taught
  async function teachMe(q, steps, fallbackText) {
    api('/api/v1/agent/gaps', { method: 'POST', body: JSON.stringify({ question: q }) }).catch(() => {});
    const key = 'm' + A.msgs.length;
    TCH[key] = { q, extra: '', kind: 'ANSWER', ans: '', route: '' };
    say({ who: 'agent', kind: 'teach', src: 'teach', steps, q, key, fallbackText });
  }

  const ago = (d) => d.toLocaleTimeString('en-SG', { hour: '2-digit', minute: '2-digit' });
  const traceBox = (steps) => (steps && steps.length ? `<details class="ag-trace"><summary>✓ Ran ${steps.length} read-only tool${steps.length > 1 ? 's' : ''} · names stay in your database</summary>
    ${steps.map((s) => `<div><code>${s.name}</code><span>${esc(s.label)}</span><em>${esc(s.out)}${s.ms ? ` · ${s.ms} ms` : ''}</em></div>`).join('')}</details>` : '');

  function reportHtml(m) {
    // when the run was processed on the PayShield page, show the same score as the page (it also counts identity findings)
    const a = A.analysis, ps = PS.scoreFor(a.payRunId), p = ps ? { ...payScore(a), ...ps } : payScore(a), C = 2 * Math.PI * 30, col = p.verdict === 'Ready' ? '#16a34a' : p.verdict === 'Review' ? '#d97706' : '#dc2626';
    const groups = {};
    a.anomalies.forEach((x) => { (groups[x.anomalyType] = groups[x.anomalyType] || []).push(x); });
    const row = (x) => `<tr class="${RESOLVED.includes(x.latestFeedback) ? 'done' : ''}"><td><b>${esc(x.employeeNo)}</b><div><span class="ti-sev s-${x.severity}">${x.severity}</span> <small class="muted">risk ${x.riskScore}</small></div></td>
      <td>${esc(x.description)}</td>
      <td><div><span class="ag-k">${x.ruleId ? 'RULE' : 'MODEL'}</span> ${x.ruleId ? esc(x.ruleId) : 'Unusual vs own history' + (x.mlPercentile != null ? ` (top ${Math.max(1, Math.round(100 - x.mlPercentile))}%)` : '')}</div>
        <div><span class="ag-k">HISTORY</span> expected ${num(x.expectedValue)}${x.expectedLow != null ? ` (${num(x.expectedLow)}–${num(x.expectedHigh)})` : ''}, now ${num(x.currentValue)}${x.changePct != null ? ` (${x.changePct > 0 ? '+' : ''}${Number(x.changePct).toFixed(1)}%)` : ''}</div></td>
      <td>${esc(x.recommendedAction)}${x.latestFeedback ? `<div><span class="ti-pill ${RESOLVED.includes(x.latestFeedback) ? 'ok' : ''}">${esc(x.latestFeedback.replaceAll('_', ' ').toLowerCase())}</span></div>` : ''}</td>
      <td class="ag-risk">${atRisk(x) ? 'S$' + Math.round(atRisk(x)).toLocaleString() : '—'}</td></tr>`;
    return `<div class="ag-card"><div class="ag-h">${ICON.bot}<b>PayShield Agent</b><span class="muted">Checked at ${ago(m.at)}</span></div>${traceBox(m.steps)}
      <div class="ag-score"><div class="ag-ring"><svg viewBox="0 0 72 72"><circle cx="36" cy="36" r="30" stroke="#e5e7eb" stroke-width="7" fill="none"/><circle cx="36" cy="36" r="30" stroke="${col}" stroke-width="7" fill="none" stroke-linecap="round" stroke-dasharray="${C}" stroke-dashoffset="${C * (1 - p.score / 100)}" transform="rotate(-90 36 36)"/></svg><b>${p.score}</b></div>
        <div><small style="color:${col};font-weight:700;letter-spacing:.5px">PAY SCORE</small><h3>${p.score}/100 · ${p.verdict}</h3><small class="muted">${a.totalEmployees - p.flagged}/${a.totalEmployees} employees clear · ${p.open} open finding(s)${p.blocking ? ' · high-severity findings cap it at 79' : ''}${ps ? ' · same score as the PayShield page (payroll + identity)' : ''}</small></div></div>
      <p>The ${esc(a.payrollPeriod)} run is <b>${p.verdict.toLowerCase()}</b>. ${a.anomalyCount ? `${p.open} open finding(s) on ${p.flagged} employee(s), about <b>S$${Math.round(p.risk).toLocaleString()}</b> away from each employee's expected pay. Each finding below has its rule, the employee's own history and a suggested fix.` : 'No findings: every employee is consistent with their own history and the payroll rules.'}</p>
      ${a.warnings.length ? `<div class="ti-warn">${a.warnings.map(esc).join('<br>')}</div>` : ''}
      ${a.anomalyCount ? `<div class="tblwrap"><table class="ag-t"><tr><th>Employee</th><th>What was found</th><th>Rule and history</th><th>Suggested fix</th><th>At risk</th></tr>
        ${Object.entries(groups).map(([k, xs]) => `<tr class="ag-g"><td colspan="5"><b>${esc(k.replaceAll('_', ' ').toLowerCase())}</b> · ${xs.length} finding${xs.length > 1 ? 's' : ''}</td></tr>${xs.map(row).join('')}`).join('')}</table></div>
        <button class="btn p ti-big" data-act="tiAgReview" style="margin-top:12px">Go through the ${a.anomalyCount} findings with me, one by one</button>
        <div class="ag-note">✓ Each decision you confirm is saved to Times Intelligence as reviewer feedback and used when the model is retrained.</div>` : ''}
      ${m.identity ? `<h4 class="ar-h" style="margin-top:18px">🪪 Identification · ${m.identity.findingCount} finding${m.identity.findingCount === 1 ? '' : 's'}</h4>${m.identity.findingCount ? `<div class="ag-fl">${m.identity.findings.slice(0, 6).map(findingCard).join('')}</div>${m.identity.findingCount > 6 ? `<button class="linkbtn" data-act="page:tiIdentity">See all ${m.identity.findingCount} identity findings →</button>` : ''}` : '<div class="ag-sum ok"><span class="ag-si">✓</span><div><b>No identity issues</b></div></div>'}` : ''}</div>`;
  }

  function reviewHtml() {
    const a = A.analysis, x = a && a.anomalies[A.review];
    if (!x) return '';
    return `<div class="ag-card ag-rev"><div class="ag-h">${ICON.bot}<b>Finding ${A.review + 1} of ${a.anomalies.length}</b><span class="muted">${esc(x.employeeNo)}</span></div>
      <div class="ti-find s-${x.severity}" style="margin:8px 0"><div class="ti-risk"><b>${x.riskScore}</b><small>risk</small></div><div class="ti-fb"><div class="ti-fh"><span class="ti-sev s-${x.severity}">${x.severity}</span><b>${esc(x.anomalyType.replaceAll('_', ' ').toLowerCase())}</b></div><p>${esc(x.description)}</p><p class="ti-act">→ ${esc(x.recommendedAction)}</p></div></div>
      <div class="ag-opts">${OUTCOMES.map(([k, l, c]) => `<button class="btn sm ${c} ${x.latestFeedback === k ? 'on' : ''}" data-act="tiAgDecide:${k}" ${T.busy ? 'disabled' : ''}>${l}</button>`).join('')}
        <button class="linkbtn" data-act="tiAgSkip">Skip</button><button class="linkbtn" data-act="tiAgStop">Stop review</button></div>
      <small class="muted">The agent never changes pay. Fixes are made in Pay by an authorised user; this only records your decision.</small></div>`;
  }

  /* ---------- teaching the agent ---------- */
  const TCH = (T.tch = {}); // form state per teach form (chat message, gap or skill), kept across re-renders
  const ROUTES = ['Which pay runs are not run yet?', 'Which pay runs are completed?', 'Check the latest pay run', 'Top 10 highest paid', 'Who has salary below 5000?', 'List all employees', 'Any identity issues?',
    'What are the highest-risk payroll anomalies this month?', 'How many employees have unusual overtime?', 'Total payroll for the last 6 pay runs',
    'Compare this pay run with last month', 'Pay history of E00001'];
  const rich = (t) => esc(t).replace(/\*\*(.+?)\*\*/g, '<b>$1</b>').replace(/\n/g, '<br>');
  function teachForm(key, title) {
    const f = TCH[key];
    if (!f) return '';
    if (f.saved) return `<div class="tch-saved">🎓 Learned. ${f.savedNote || ''}</div>`;
    return `<div class="tch">${title ? `<b class="tch-t">${title}</b>` : ''}
      <label class="tch-l">When someone asks<input data-tch="${key}:q" value="${esc(f.q)}" placeholder="e.g. Who are our big earners?"></label>
      <label class="tch-l">…or asks it like this <small>(optional, one per line)</small><textarea data-tch="${key}:extra" rows="2" placeholder="another way to ask">${esc(f.extra)}</textarea></label>
      <div class="tch-k"><button class="${f.kind === 'ANSWER' ? 'on' : ''}" data-act="tiTchKind:${key}~ANSWER">✍ Reply with my answer</button><button class="${f.kind === 'ROUTE' ? 'on' : ''}" data-act="tiTchKind:${key}~ROUTE">↪ Answer it like another question</button></div>
      ${f.kind === 'ANSWER' ? `<textarea data-tch="${key}:ans" rows="4" class="tch-a" placeholder="Type the answer. **bold** works.">${esc(f.ans)}</textarea>`
        : `<div class="tch-r"><select data-tch="${key}:route"><option value="">Pick something I can already do…</option>${ROUTES.map((x) => `<option ${x === f.route ? 'selected' : ''}>${esc(x)}</option>`).join('')}</select>
          <input data-tch="${key}:route" value="${esc(f.route)}" placeholder="…or type the question to use instead"></div>`}
      <div class="tch-b"><button class="btn sm p" data-act="tiTchSave:${key}" ${T.busy ? 'disabled' : ''}>🎓 Teach</button>${f.cancel ? `<button class="btn sm" data-act="tiTchCancel:${key}">Cancel</button>` : ''}</div></div>`;
  }
  function taughtHtml(m) {
    const sk = m.skill;
    const body = sk.kind === 'ANSWER' ? `<div class="tch-ans">${rich(sk.answer)}</div>` : `<div class="tch-ans">↪ I was taught to answer this as <b>“${esc(sk.route)}”</b>.</div>`;
    const fb = m.fb ? `<small class="muted">${m.fb === 'up' ? '👍 Thanks, I’ll also remember this way of asking.' : '👎 Noted. Teach me the right answer below.'}</small>`
      : `<span class="tch-fb"><small>Was this right?</small><button data-act="tiTchFb:${A.msgs.indexOf(m)}-up">👍</button><button data-act="tiTchFb:${A.msgs.indexOf(m)}-down">👎</button></span>`;
    return `${body}<div class="tch-meta"><small>🎓 Taught by ${esc(String(sk.created_by).startsWith('svc:') ? 'Payroll Admin' : sk.created_by)} · used ${sk.used_count}× · ${Math.round(m.score * 100)}% match</small>${fb}</div>${m.fixKey ? teachForm(m.fixKey) : ''}`;
  }
  // words of a question without filler, for "did you mean" suggestions (same idea as the server-side matching)
  const STOPW = new Set('a an the is are was were be do does did of to in on at for by with and or what which who how when where why can could should would will me my our we us you your i it this that there any all some show list tell give please'.split(' '));
  const qWords = (x) => new Set(String(x).toLowerCase().match(/[a-z0-9]+/g)?.filter((w) => !STOPW.has(w) && w.length > 1).map((w) => w.replace(/(ings?|ed|es|s)$/, '')) || []);
  function suggestRoutes(q) {
    const a = qWords(q);
    return ROUTES.map((x) => { const b = qWords(x); let both = 0; a.forEach((w) => { if (b.has(w)) both += 1; }); return [x, (2 * both) / (a.size + b.size || 1)]; })
      .filter(([, sc]) => sc > 0.15).sort((x, y) => y[1] - x[1]).slice(0, 3);
  }
  function teachHtml(m) {
    const sug = TCH[m.key] && !TCH[m.key].saved ? suggestRoutes(m.q) : [];
    return `<div class="tch-q">🎓 <div><b>I haven’t learned how to answer “${esc(m.q)}” yet.</b><small>Pick one of these and I’ll learn it, or teach me your own answer below.</small></div></div>
      ${sug.length ? `<div class="tch-sug"><small>I can probably answer it like this (one click teaches me):</small>${sug.map(([x], i) => `<button class="btn sm" data-act="tiTchUse:${m.key}~${i}">↪ ${esc(x)}</button>`).join('')}</div>` : ''}
      ${teachForm(m.key)}${m.fallbackText ? `<details class="tch-fbk"><summary>What I can tell you instead</summary><pre>${esc(m.fallbackText)}</pre></details>` : ''}`;
  }
  async function saveTeach(key) {
    const f = TCH[key];
    if (!f) return;
    const phrases = [f.q, ...String(f.extra || '').split('\n')].map((x) => x.trim()).filter(Boolean);
    if (!phrases.length || (f.kind === 'ANSWER' ? !f.ans.trim() : !f.route.trim())) { toast('Add the question and the answer (or pick what I should do).'); render(); return; }
    await act('tiTeach', async () => {
      if (f.editUid) await api(`/api/v1/agent/skills/${f.editUid}`, { method: 'PATCH', body: JSON.stringify({ answer: f.kind === 'ANSWER' ? f.ans : null, route: f.kind === 'ROUTE' ? f.route : null, addPhrase: f.q }) });
      else await api('/api/v1/agent/skills', { method: 'POST', body: JSON.stringify({ phrases, kind: f.kind, answer: f.kind === 'ANSWER' ? f.ans : null, route: f.kind === 'ROUTE' ? f.route : null }) });
      f.saved = true; f.savedNote = `Ask “${esc(phrases[0])}” again and I’ll answer it.`; T.teach = null; T.loaded.teach = false;
      if (!A.msgs.some((m) => m.key === key || m.fixKey === key)) delete TCH[key]; // forms on the Teach page start fresh
      toast(`🎓 <b>Agent taught.</b> “${esc(phrases[0])}”${phrases.length > 1 ? ` and ${phrases.length - 1} other way${phrases.length > 2 ? 's' : ''} to ask` : ''} will now be answered.`);
    });
    if (f.reask) send(f.q);
  }
  document.addEventListener('input', (e) => { const k = e.target?.dataset?.tch; if (!k) return; const [key, field] = k.split(':'); if (TCH[key]) TCH[key][field] = e.target.value; });
  document.addEventListener('change', (e) => { const k = e.target?.dataset?.tch; if (!k || e.target.tagName !== 'SELECT') return; const [key, field] = k.split(':'); if (TCH[key]) { TCH[key][field] = e.target.value; render(); } });

  /* ---------- Teach the agent page ---------- */
  function teachBody() {
    if (!T.teach && !T.loaded.teach) { T.loaded.teach = true; api('/api/v1/agent/skills').then((x) => { T.teach = x; }).catch((e) => { T.err = e.message; }).finally(render); }
    if (!TCH.new) TCH.new = { q: '', extra: '', kind: 'ANSWER', ans: '', route: '' };
    const d = T.teach;
    if (!d) return `${errBox()}<div class="card muted" style="padding:16px">Loading…</div>`;
    const uses = d.skills.reduce((t, x) => t + x.used_count, 0);
    const gaps = d.gaps.map((g) => { const k = 'g' + g.uid;
      return `<div class="tch-row"><div><b>“${esc(g.question)}”</b><small>asked ${g.times_asked}× · last ${new Date(g.last_asked).toLocaleString('en-SG', { day: 'numeric', month: 'short', hour: '2-digit', minute: '2-digit' })}</small></div>
        ${TCH[k] ? '' : `<button class="btn sm p" data-act="tiTchGap:${g.uid}">🎓 Teach</button><button class="btn sm" data-act="tiGapDismiss:${g.uid}">Dismiss</button>`}</div>${teachForm(k)}`; }).join('');
    const skills = d.skills.map((x) => { const k = 'e' + x.uid;
      return `<div class="tch-skill"><div class="tch-sh"><span class="tch-kind ${x.kind}">${x.kind === 'ANSWER' ? '✍ Answer' : '↪ Route'}</span><div class="tch-ph">${x.phrases.map((p) => `<span>${esc(p)}</span>`).join('')}</div>
          <small>used ${x.used_count}× · 👍 ${x.helpful} · 👎 ${x.not_helpful}</small></div>
        <div class="tch-ans">${x.kind === 'ANSWER' ? rich(x.answer) : `↪ answered as <b>“${esc(x.route)}”</b>`}</div>
        <div class="tch-b"><small class="muted">by ${esc(String(x.created_by).startsWith('svc:') ? 'Payroll Admin' : x.created_by)} on ${dmy(x.created_on)}</small>
          ${TCH[k] ? '' : `<button class="btn sm" data-act="tiTchEdit:${x.uid}">Edit / add a way to ask</button><button class="btn sm" data-act="tiTchDel:${x.uid}">Delete</button>`}</div>${teachForm(k)}</div>`; }).join('');
    return `${errBox()}${hero('🎓', 'Teach the agent', 'Teach PayShield Agent answers it does not know yet. Matched by the meaning of the words: no LLM, stays in your database.', '', 'blue')}
      ${kpis([['🎓', 'Taught', d.skills.length, 'answers and routes'], ['💬', 'Used', uses, 'times in chats'], ['❓', 'Waiting to be taught', d.gaps.length, 'questions it could not answer', d.gaps.length ? 'amber' : 'green']])}
      ${panel('❓ Questions I couldn’t answer', d.gaps.length ? 'Teach one and everyone gets the answer next time' : '', gaps || '<div class="muted">Nothing waiting. When someone asks the agent something new, it shows up here.</div>')}
      ${panel('✚ Teach something new', '', teachForm('new'))}
      ${panel('🎓 What I’ve been taught', `${d.skills.length} skill${d.skills.length === 1 ? '' : 's'}`, skills || '<div class="muted">Nothing taught yet.</div>')}`;
  }

  function msgsHtml() {
    return A.msgs.map((m) => (m.who === 'me' ? `<div class="ag-me">${esc(m.text)}</div>`
      : m.kind === 'report' ? reportHtml(m)
        : m.kind === 'taught' ? `<div class="ag-card tch-card"><div class="ag-h">${ICON.bot}<b>PayShield Agent</b><span class="ti-pill tch-pill">🎓 taught answer</span></div>${taughtHtml(m)}</div>`
        : m.kind === 'teach' ? `<div class="ag-card tch-card"><div class="ag-h">${ICON.bot}<b>PayShield Agent</b><span class="ti-pill tch-pill">🎓 not learned yet</span></div>${traceBox(m.steps)}${teachHtml(m)}</div>`
        : `<div class="ag-card"><div class="ag-h">${ICON.bot}<b>PayShield Agent</b><span class="ti-pill">${esc(({ FALLBACK: 'built-in answer', OK: 'AI answer', REFUSED: 'refused: read-only', computed: 'computed', analysis: 'from the analysis', lookup: 'payroll lookup', identity: 'identification checks', knowledge: 'rule knowledge base', error: 'error' })[m.src] || String(m.src || '').toLowerCase())}</span></div>${traceBox(m.steps)}${answerHtml(m)}</div>`)).join('');
  }

  /* ---------- floating agent chat on the PayShield page (drag it anywhere) ---------- */
  const FAB = (A.fab = { open: false, x: null, y: null });
  const fabSize = () => (FAB.open ? [Math.min(400, innerWidth - 16), Math.min(600, innerHeight - 16)] : [76, 76]);
  const fabQs = () => [`Check the ${PS.label()} pay run`, 'Any identity issues?', 'Highest-risk anomalies', 'Who has salary below 5000?', 'Top 5 highest paid', 'Compare this pay run with last month'];
  const BOT = `<svg viewBox="0 0 64 64" class="fab-bot"><line x1="32" y1="9" x2="32" y2="17" stroke="currentColor" stroke-width="3" stroke-linecap="round"/><circle class="fab-ant" cx="32" cy="8" r="4" fill="#fde047"/>
    <rect x="12" y="17" width="40" height="32" rx="12" fill="#fff"/><rect x="7" y="28" width="5" height="10" rx="2.5" fill="#c7d2fe"/><rect x="52" y="28" width="5" height="10" rx="2.5" fill="#c7d2fe"/>
    <g class="fab-eyes"><circle cx="24" cy="32" r="4.5" fill="#4f46e5"/><circle cx="40" cy="32" r="4.5" fill="#4f46e5"/></g><path d="M25 41q7 5 14 0" stroke="#4f46e5" stroke-width="3" fill="none" stroke-linecap="round"/></svg>`;
  function fabHtml() {
    const [W, Hh] = fabSize();
    const x = FAB.x == null ? innerWidth - W - 24 : Math.max(8, Math.min(FAB.x, innerWidth - W - 8));
    const y = FAB.y == null ? innerHeight - Hh - 24 : Math.max(8, Math.min(FAB.y, innerHeight - Hh - 8));
    if (!FAB.open) return `<div class="fab" id="tiFab" style="left:${x}px;top:${y}px"><span class="fab-tip">Hi! Ask me about this pay run 👋</span>
      <button class="fab-btn fab-drag" title="PayShield Agent: drag to move, click to chat"><span class="fab-ring"></span><span class="fab-ring r2"></span>${BOT}<span class="fab-spark">✦</span>${A.msgs.length ? `<span class="fab-n">${A.msgs.filter((m) => m.who !== 'me').length}</span>` : ''}</button></div>`;
    lazy('runs', () => loadRuns());
    return `<div class="fab open" id="tiFab" style="left:${x}px;top:${y}px;width:${W}px;height:${Hh}px">
      <header class="fab-drag"><span class="fab-av">${BOT}</span><div><b>PayShield Agent</b><small><i></i>Live on your pay runs &amp; identity data · read-only</small></div>
        <button class="fab-x" data-act="page:agent" title="Open full page">⤢</button><button class="fab-x" data-act="tiFabToggle" title="Close">✕</button></header>
      <div class="fab-msgs ag-chat">${msgsHtml() || `<div class="fab-hello">${BOT}<b>Hi, I’m your PayShield Agent</b><p>Ask me about ${esc(PS.label())} or any other pay run, employees, salaries or identity issues. I only read data; I never change pay.</p></div>`}
        ${reviewHtml()}${T.busy === 'tiAgent' ? '<div class="ag-card muted"><span class="tr-spin" style="width:16px;height:16px;margin:0 8px -3px 0"></span>Thinking…</div>' : ''}<div class="ag-end"></div></div>
      <div class="fab-sugg">${fabQs().map((s, i) => `<button data-act="tiFabAsk:${i}" ${T.busy ? 'disabled' : ''}>${esc(s)}</button>`).join('')}</div>
      <div class="fab-in"><input id="tiAgQ" placeholder="Ask about pay runs or identity…" autocomplete="off" ${T.busy ? 'disabled' : ''}><button data-act="tiAgSend" ${T.busy ? 'disabled' : ''} aria-label="Send">➤</button></div></div>`;
  }
  const fabScroll = () => setTimeout(() => { const m = document.querySelector('.fab-msgs'); if (m) m.scrollTop = m.scrollHeight; }, 30);
  // open / close keeping the bottom-right corner where the user left it
  function fabToggle() {
    const [w0, h0] = fabSize(), el = document.getElementById('tiFab'), r = el?.getBoundingClientRect();
    FAB.open = !FAB.open;
    const [w1, h1] = fabSize();
    if (r) { FAB.x = r.left + w0 - w1; FAB.y = r.top + h0 - h1; }
    render();
    if (FAB.open) { fabScroll(); setTimeout(() => document.getElementById('tiAgQ')?.focus(), 40); }
  }
  // drag the launcher or the chat header; a click on the launcher without moving opens the chat
  document.addEventListener('pointerdown', (e) => {
    const h = e.target.closest?.('.fab-drag'), el = h && document.getElementById('tiFab');
    if (!el || e.target.closest('.fab-x')) return;
    const r = el.getBoundingClientRect(), dx = e.clientX - r.left, dy = e.clientY - r.top, sx = e.clientX, sy = e.clientY;
    let moved = false;
    const mv = (ev) => {
      if (!moved && Math.hypot(ev.clientX - sx, ev.clientY - sy) < 5) return;
      moved = true; el.classList.add('dragging');
      FAB.x = Math.max(8, Math.min(ev.clientX - dx, innerWidth - r.width - 8)); FAB.y = Math.max(8, Math.min(ev.clientY - dy, innerHeight - r.height - 8));
      el.style.left = FAB.x + 'px'; el.style.top = FAB.y + 'px';
    };
    const up = () => {
      removeEventListener('pointermove', mv); removeEventListener('pointerup', up); el.classList.remove('dragging');
      if (!moved && !FAB.open) fabToggle();
    };
    addEventListener('pointermove', mv); addEventListener('pointerup', up);
    e.preventDefault();
  });
  addEventListener('resize', () => { if (document.getElementById('tiFab')) render(); });

  function agentBody(fallback) {
    if (A.demo || !T.sub?.subscribed || !anyTrained()) return fallback() + (anyTrained() ? `<div style="margin-top:12px"><button class="linkbtn" data-act="tiAgDemo">← Back to the live agent</button></div>` : '');
    lazy('runs', () => loadRuns());
    const sugg = ['Check the latest pay run and give the pay score', 'What are the highest-risk anomalies?', 'How many employees have unusual overtime?',
      ...(A.analysis?.anomalies[0] ? [`Show findings for ${A.analysis.anomalies[0].employeeNo}`] : []), 'What is the pay score?'];
    const msgs = msgsHtml();
    return `${errBox()}${hero(ICON.bot, 'PayShield Agent', `Live on your data: ${AREA_LIST.filter(([k]) => isTrained(k)).map(([k, l]) => (k === 'PAYROLL' ? `Payroll v${esc(T.status.activeModel.modelVersion)}` : `${l}${areaOf(k).isMock ? ' (demo)' : ''}`)).join(', ')}. Ask about any pay run, or let the agent check the whole run and give a Pay Score.`,
      `<button class="linkbtn" data-act="tiAgDemo" style="color:#fff">Sample demo →</button>`)}
      <section class="ti-panel ag-chat">${msgs || `<div class="ti-empty" style="margin:0"><span class="ti-kic">${ICON.bot}</span><b>Ask PayShield Agent anything about your pay runs</b><p>e.g. “Check the ${T.runs[0] ? esc(T.runs[0].name) : 'latest'} pay run”, “Why is E00002 flagged?”, “How many employees have unusual overtime?”</p></div>`}
        ${reviewHtml()}${T.busy === 'tiAgent' ? '<div class="ag-card muted"><span class="tr-spin" style="width:16px;height:16px;margin:0 8px -3px 0"></span>Working…</div>' : ''}<div class="ag-end"></div>
        <div class="ag-sugg">${sugg.map((s, i) => `<button class="ti-q" data-act="tiAgSugg:${i}" ${T.busy ? 'disabled' : ''}>${i === 0 ? '▶ ' : ''}${esc(s)}</button>`).join('')}</div>
        <div class="ag-in"><input id="tiAgQ" placeholder="Ask PayShield Agent, e.g. “check the October pay run”" ${T.busy ? 'disabled' : ''}><button class="btn p ti-big" data-act="tiAgSend" ${T.busy ? 'disabled' : ''}>Send</button></div></section>
      ${panel('What the agent runs', 'All read-only. None can change pay.', `<div class="ag-tools">${[['payrun.list', 'Pay runs for this company only'], ['payroll.analyze', '17 payroll rules + your trained model, each employee vs their own history'], ['payscore.compute', 'Share of clean employees minus severity penalty; high severity caps at 79'], ['findings.employee', 'One employee’s findings from the analysis'], ['assistant.ask', 'Read-only assistant: summary, counts, top risks (no SQL is generated)'], ['employee.directory', 'List or search employees with their latest pay'], ['employee.filter', 'Employees by basic / gross / net pay: below, above, between, top or lowest N'], ['employee.payHistory', 'One employee’s last N months: basic, allowances, CPF, gross, net'], ['payrun.totals', 'Headcount, gross, net, CPF per pay run, with trend'], ['payrun.compare', 'This run vs the previous one, joiners/leavers and biggest changes'], ['rules.knowledge', 'CPF / IRAS / MOM answers from the checked rule knowledge base, with source'], ['feedback.save', 'Your confirmed decision, saved for retraining']].map(([n, d]) => `<div><code>${n}</code><span>${d}</span></div>`).join('')}</div>`)}
      ${panel('Guardrails', '', `<ul class="ag-ul"><li>No SQL is written by a language model; every tool is a fixed, tested query scoped to this company.</li><li>Requests to approve, change or pay are refused; the agent only reads and records decisions.</li><li>Answers come from the analysis; if a language model is configured it sees pseudonymous references, never names.</li><li>Every analysis, question (hashed) and decision is recorded in the times_intelligence schema.</li></ul>`)}`;
  }

  const agentActions = {
    tiAgSend: () => { const el = document.getElementById('tiAgQ'); const q = el?.value; if (el) el.value = ''; send(q); },
    tiAgSugg: (i) => { const s = [...document.querySelectorAll('[data-act^="tiAgSugg:"]')][+i]; send(s?.textContent.replace(/^▶\s*/, '')); },
    tiAgReview: () => { A.review = 0; render(); setTimeout(() => document.querySelector('.ag-rev')?.scrollIntoView({ block: 'center', behavior: 'smooth' }), 30); },
    tiAgSkip: () => { A.review = A.review + 1 < A.analysis.anomalies.length ? A.review + 1 : -1; render(); },
    tiAgStop: () => { A.review = -1; render(); },
    tiAgDemo: () => { A.demo = !A.demo; render(); },
    tiFabToggle: () => fabToggle(),
    tiFabAsk: (i) => { send(fabQs()[+i]); fabScroll(); },
    tiAgDecide: (k) => act('tiAgDecide', async () => {
      const x = A.analysis.anomalies[A.review];
      await api('/api/v1/payroll/feedback', { method: 'POST', body: JSON.stringify({ anomalyId: x.anomalyId, outcome: k }) });
      x.latestFeedback = k;
      const p = payScore(A.analysis);
      toast(`<b>Saved:</b> ${esc(x.employeeNo)} · ${k.replaceAll('_', ' ').toLowerCase()}. Pay Score now <b>${p.score}/100 · ${p.verdict}</b>`);
      A.review = A.review + 1 < A.analysis.anomalies.length ? A.review + 1 : -1;
    }),
  };
  document.addEventListener('keydown', (e) => { if (e.key === 'Enter' && e.target?.id === 'tiAgQ') agentActions.tiAgSend(); });

  function identityBody() {
    if (!T.ident && !T.loaded.ident) { T.loaded.ident = true; api('/api/v1/identity/check').then((r) => { T.ident = r; }).catch((e) => { T.err = e.message; }).finally(render); }
    const r = T.ident;
    const head = hero('🪪', 'Identity checks', 'Duplicate NRIC/FIN, shared bank accounts and phones, work pass expiry, missing IDs, and identity details changed since Identification was trained.',
      `<button class="btn p ti-big" data-act="tiIdentRun" ${T.busy ? 'disabled' : ''}>${T.busy === 'tiIdentRun' ? 'Checking…' : '↻ Run checks'}</button>`, 'blue');
    if (!r) return `${errBox()}${head}<div class="ti-empty"><span class="tr-spin"></span><br><b>Checking every employee…</b></div>`;
    const max = Math.max(1, ...Object.values(r.byType));
    return `${errBox()}${head}${kpis([[ICON.users, 'Employees checked', r.employees.toLocaleString(), esc(r.payRun || '')], [ICON.alert, 'Flagged', r.flaggedEmployees, `${r.findingCount} findings`, r.findingCount ? 'red' : 'green'],
      [ICON.shield, 'Identification model', 'v' + r.modelVersion, 'trained ' + esc(r.trainedOn.slice(0, 10)), 'violet'], [ICON.clock, 'Check time', (r.durationMs / 1000).toFixed(1) + 's', 'live on your database', 'green']])}
      ${r.findingCount ? panel('By type', '', `<div class="ag-bars">${Object.entries(r.byType).sort((a, b) => b[1] - a[1]).map(([k, n]) => `<div><span>${esc(k.replaceAll('_', ' ').toLowerCase())}</span><span class="ag-cb"><i class="e2" style="width:${(n / max) * 100}%"></i></span><b>${n}</b></div>`).join('')}</div>`) : ''}
      ${panel('Findings', 'Highest risk first', r.findingCount ? `<div class="ag-fl">${r.findings.map(findingCard).join('')}</div>` : '<div class="ti-empty ok"><span class="ti-kic">✓</span><b>No identity issues</b></div>')}`;
  }

  const pages = {
    tiDash: { crumb: 'Home › <b>Dashboard</b>', body: dashBody },
    tiPayShield: { crumb: 'Times Intelligence › <b>PayShield</b>', body: () => PS.body() },
    tiTeach: { crumb: 'Times Intelligence › <b>Teach the agent</b>', body: teachBody },
    tiPayRun: { crumb: 'Times Intelligence › <b>Pay runs</b>', body: () => PS.payRunBody() },
    tiSubscribe: { crumb: 'Times Intelligence › <b>Subscription</b>', body: subscribeBody },
    tiAnomaly: { crumb: 'Times Intelligence › <b>AI anomaly detection</b>', body: anomalyBody },
    tiTrain: { crumb: 'Times Intelligence › <b>Train model</b>', body: trainBody },
    tiIdentity: { crumb: 'Times Intelligence › <b>Identity checks</b>', body: identityBody },
  };
  const labels = { tiTeach: 'Teach the agent', tiPayShield: 'PayShield', tiPayRun: 'Pay runs', tiDash: 'Dashboard', tiSubscribe: 'Times Intelligence', tiAnomaly: 'AI anomaly detection', tiTrain: 'Train model', tiIdentity: 'Identity checks' };

  const menu = () => [{ label: 'AI model', items: T.sub?.subscribed ? [
    ...(isTrained('PAYROLL') ? [{ k: 'tiAnomaly', label: 'AI anomaly detection', icon: 'spark', act: 'page:tiAnomaly', tag: '<span class="new">AI</span>' }] : []),
    ...(isTrained('IDENTIFICATION') ? [{ k: 'tiIdentity', label: 'Identity checks', icon: 'shield', act: 'page:tiIdentity' }] : []),
    { k: 'tiTrain', label: 'Train model', icon: 'flask', act: 'page:tiTrain' },
    { k: 'tiTeach', label: 'Teach the agent', icon: 'bot', act: 'page:tiTeach' },
  ] : [] }];

  const actions = {
    tiSubscribe: () => act('tiSubscribe', async () => { T.sub = await api('/api/v1/intelligence/subscribe', { method: 'POST' }); await loadModel(); toast(anyTrained() ? '<b>✓ Successfully subscribed to Times Intelligence.</b>' : '<b>✓ Successfully subscribed.</b> Choose the areas to train to unlock Times Intelligence'); }),
    tiUnsubscribe: () => {
      if (!confirm('Unsubscribe from Times Intelligence?\n\nThis permanently deletes all trained models, training history, analyses, findings and feedback for this company. If you subscribe again you will need to train a new model.')) return;
      act('tiUnsubscribe', async () => {
        const r = await api('/api/v1/intelligence/unsubscribe', { method: 'POST' });
        T.sub = r; T.analysis = T.answer = T.injected = null; Object.assign(A, { msgs: [], analysis: null, review: -1 }); T.status = null; T.versions = []; T.step = -1; T.loaded = {}; T.areaRun = []; T.ident = null; PS.reset();
        const x = r.removed || {};
        toast(`<b>Unsubscribed.</b> Times Intelligence data reset: ${x.model_registry || 0} model(s), ${x.model_files || 0} model file(s), ${x.training_job || 0} training job(s), ${x.analysis || 0} analysis(es) deleted`);
      });
    },
    tiArea: (k) => { if (T.busy) return; T.sel.has(k) ? T.sel.delete(k) : T.sel.add(k); render(); },
    tiAreaAll: (v) => { if (T.busy) return; T.sel = new Set(+v ? AREA_LIST.map((a) => a[0]) : []); render(); },
    tiTrain: () => act('tiTrain', async () => {
      const areas = AREA_LIST.map((a) => a[0]).filter((k) => T.sel.has(k));
      if (!areas.length) return;
      const wasLocked = !anyTrained();
      T.areaRun = areas.map((k) => ({ k, state: 'run' }));
      T.step = areas.includes('PAYROLL') ? 0 : -1; T.pct = 0; T.t0 = Date.now(); T.failed = false; render();
      const job = await api('/api/v1/models/train', { method: 'POST', body: JSON.stringify({ areas }) });
      (job.areas || []).forEach((res) => { const x = T.areaRun.find((y) => y.k === res.area); if (x) Object.assign(x, { state: 'ok', res }); });
      render();
      const names = areas.map((k) => AREA_LIST.find((a) => a[0] === k)[1]).join(', ');
      if (!job.jobId) { await loadModel(); toast(`<b>✓ Trained: ${esc(names)}.</b>${wasLocked ? ' Times Intelligence is unlocked.' : ''}`); return; }
      for (let tick = 0; ; tick++) {
        const j = await api(`/api/v1/models/training-jobs/${job.jobId}`);
        if (!['QUEUED', 'RUNNING'].includes(j.status)) { const px = T.areaRun.find((y) => y.k === 'PAYROLL'); if (px) Object.assign(px, { state: j.status === 'SUCCEEDED' ? 'ok' : 'bad', res: { durationMs: j.durationMs || 0 } }); T.failed = j.status !== 'SUCCEEDED'; T.step = T.failed ? T.step : 99; T.pct = T.failed ? T.pct : 100; T.secs = j.durationMs / 1000; toast(j.status === 'SUCCEEDED' ? `<b>✓ Trained: ${esc(names)}</b> (payroll model in ${(j.durationMs / 1000).toFixed(1)}s).${wasLocked ? ' Times Intelligence is unlocked.' : ''}` : `Payroll training ${j.status.toLowerCase()} in ${(j.durationMs / 1000).toFixed(1)}s`); break; }
        T.pct = Math.min(96, Math.round(100 * (1 - Math.exp(-(tick + 1) / 7)))); T.step = Math.min(4, Math.floor(T.pct / 20)); render();
        await new Promise((r) => setTimeout(r, 1200));
      }
      await loadModel();
    }),
    tiIdentRun: () => act('tiIdentRun', async () => { T.ident = await api('/api/v1/identity/check'); }),
    tiActivate: (id) => act('tiActivate', async () => { await api(`/api/v1/models/${id}/activate`, { method: 'POST' }); toast('Model activated'); await loadModel(); }),
    tiAnalyze: () => {
      if (T.analysis && !confirm('Analyse this pay run again?\n\nThe new result replaces the saved one; Fix / Accept decisions start again on the new findings.')) return;
      act('tiAnalyze', async () => { T.answer = null; T.analysis = await api('/api/v1/payroll/analyze', { method: 'POST', body: JSON.stringify({ payRunId: T.run, supersede: true }) }); PS.reset(); });
    },
    tiTchKind: (arg) => { const [key, kind] = String(arg).split('~'); if (TCH[key]) { TCH[key].kind = kind; render(); } },
    tiTchSave: (key) => { const m = A.msgs.find((x) => x.key === key); if (m) TCH[key].reask = true; saveTeach(key); },
    tiTchUse: (arg) => { const [key, i] = String(arg).split('~'), m = A.msgs.find((x) => x.key === key), pick = m && suggestRoutes(m.q)[+i];
      if (!pick) return; Object.assign(TCH[key], { kind: 'ROUTE', route: pick[0], reask: true }); saveTeach(key); },
    tiOpenMonth: (period) => { const [mm, yy] = String(period).split('/'); PS.openMonth(+yy, +mm - 1); },
    tiTchCancel: (key) => { delete TCH[key]; render(); },
    tiTchGap: (uid) => { const g = T.teach?.gaps.find((x) => x.uid === uid); if (g) { TCH['g' + uid] = { q: g.question, extra: '', kind: 'ANSWER', ans: '', route: '', cancel: true }; render(); } },
    tiGapDismiss: (uid) => act('tiTeach', async () => { await api(`/api/v1/agent/gaps/${uid}`, { method: 'DELETE' }); T.teach = null; T.loaded.teach = false; }),
    tiTchEdit: (uid) => { const x = T.teach?.skills.find((y) => y.uid === uid); if (x) { TCH['e' + uid] = { q: '', extra: '', kind: x.kind, ans: x.answer || '', route: x.route || '', editUid: uid, cancel: true }; render(); } },
    tiTchDel: (uid) => { if (confirm('Delete this taught answer? The agent will no longer answer it.')) act('tiTeach', async () => { await api(`/api/v1/agent/skills/${uid}`, { method: 'DELETE' }); T.teach = null; T.loaded.teach = false; toast('Deleted.'); }); },
    tiTchFb: (arg) => {
      const [i, v] = String(arg).split('-'), m = A.msgs[+i], prev = A.msgs[+i - 1];
      if (!m?.skill) return;
      m.fb = v;
      api(`/api/v1/agent/skills/${m.skill.uid}`, { method: 'PATCH', body: JSON.stringify({ helpful: v === 'up', addPhrase: v === 'up' && prev?.who === 'me' ? prev.text : null }) }).catch(() => {});
      if (v === 'down') { m.fixKey = 'f' + i; TCH[m.fixKey] = { q: m.q, extra: '', kind: m.skill.kind, ans: m.skill.answer || '', route: m.skill.route || '', editUid: m.skill.uid, reask: true }; }
      render();
    },
    tiForget: (uid) => act('tiForget', async () => { await api(`/api/v1/models/learning/${uid}/forget`, { method: 'POST' }); T.learn = null; T.loaded.learn = false; toast('🧠 Forgotten. That finding will be raised again next time.'); }),
    tiAnResolve: () => { const r = anRun(); if (r) PS.openMonth(+r.period.slice(3), +r.period.slice(0, 2) - 1); },
    tiAsk: (i) => act('tiAsk', async () => { T.answer = await api('/api/v1/assistant/ask', { method: 'POST', body: JSON.stringify({ question: QUESTIONS[+i], analysisId: T.analysis.analysisId }) }); }),
  };

  document.addEventListener('change', (e) => {
    if (!['tiAnMonth', 'tiAnYear'].includes(e.target?.id)) return;
    const mm = +document.getElementById('tiAnMonth').value, yy = document.getElementById('tiAnYear').value;
    const r = T.runs.find((x) => x.period === `${String(mm + 1).padStart(2, '0')}/${yy}`) || T.runs.find((x) => x.period.endsWith('/' + yy));
    if (!r) return;
    T.run = r.uid; act('tiAnLoad', loadSaved);
  });
  // the local API tells us which tenant/company it serves (run_local_db.py / run_portal_prototype.py)
  fetch('/dev/context').then((r) => (r.ok ? r.json() : null)).catch(() => null).then((ctx) => {
    if (ctx) { H['X-Tenant-Uid'] = ctx.tenantUid; H['X-Company-Uid'] = ctx.companyUid; T.ctx = ctx; }
    return api('/api/v1/intelligence/subscription'); }).then(async (s) => { T.sub = s; if (s.subscribed) { await loadModel(); T.loaded.model = true; } }).catch((e) => { T.err = e.message; }).finally(render);

  return { pages, labels, menu, actions: { ...actions, ...agentActions, ...PS.actions }, shell, agentPage: agentBody };
}
