// Scenario: "Our own model" — train PayShield's risk model live, see what it learned, test it, approve it.
import { FEATURES, PROTECTED, dataset, initModel, trainSteps, chooseThreshold, evaluate, modelCard, TRAIN_SEEDS, TEST_SEEDS, HARDER } from './model.js';

const esc = (s) => String(s ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
const pct = (a, b) => (b ? Math.round((a / b) * 100) : 0) + '%';
const EPOCHS = 400, CHUNK = 20;

function lossChart(loss) {
  const W = 520, H = 150, pad = 28, max = Math.max(...loss, 0.7), n = Math.max(EPOCHS, loss.length);
  const pts = loss.map((v, i) => `${(pad + (i / (n - 1)) * (W - pad - 8)).toFixed(1)},${(H - pad - (v / max) * (H - pad - 10)).toFixed(1)}`).join(' ');
  return `<svg role="img" aria-label="Training loss falling from ${loss[0]?.toFixed(2)} to ${loss[loss.length - 1]?.toFixed(2)}" viewBox="0 0 ${W} ${H}" style="width:100%;height:auto">
    <line x1="${pad}" y1="${H - pad}" x2="${W - 8}" y2="${H - pad}" stroke="var(--line)"/><line x1="${pad}" y1="10" x2="${pad}" y2="${H - pad}" stroke="var(--line)"/>
    <text x="${pad}" y="${H - 8}" font-size="11" fill="var(--mute)">0</text><text x="${W - 8}" y="${H - 8}" font-size="11" fill="var(--mute)" text-anchor="end">${EPOCHS} passes</text>
    <text x="${pad - 4}" y="16" font-size="11" fill="var(--mute)" text-anchor="end">${max.toFixed(1)}</text>
    <polyline points="${pts}" fill="none" stroke="var(--accent)" stroke-width="2.5" stroke-linejoin="round"/></svg>`;
}
function weightBars(model) {
  const rows = FEATURES.map(([k, label], i) => ({ label, w: model.w[i] })).sort((a, b) => b.w - a.w);
  const max = Math.max(...rows.map((r) => Math.abs(r.w)), 0.01);
  return rows.map((r) => `<div style="display:grid;grid-template-columns:minmax(0,1.4fr) minmax(120px,1fr) 48px;gap:10px;align-items:center;font-size:12.5px;padding:4px 0">
    <span>${esc(r.label)}</span><div style="position:relative;height:10px;background:var(--surface2);border-radius:5px"><div style="position:absolute;${r.w >= 0 ? 'left:50%' : 'right:50%'};width:${(Math.abs(r.w) / max) * 50}%;height:10px;border-radius:5px;background:${r.w >= 0 ? 'var(--accent)' : 'var(--mute)'}"></div></div>
    <span class="num-r" style="text-align:right;font-variant-numeric:tabular-nums">${r.w >= 0 ? '+' : ''}${r.w.toFixed(2)}</span></div>`).join('');
}

export function extra3Scenarios(h) {
  const { app, consoleApp, S, fmt } = h;
  return {
    model: {
      label: 'Our own model', who: 'Trains in your browser',
      title: 'Train PayShield’s own risk model', sub: 'A small model of our own, trained on de-identified payroll features. It looks again at records the rules cleared and finds patterns rules miss, such as salary creep. It can only add a Review flag.',
      init() { S.d = { rows: null, model: null, training: false, threshold: null, ev: null, hard: null, busy: false, approvals: {} }; },
      steps: [
        { t: 'What it learns from', you: 'Click <b>Train the model</b>.', sys: 'Training data is 20 synthetic companies. Each record is turned into 15 numbers; nothing that identifies a person goes in.',
          screen: () => consoleApp('PayShield Lab › <b>Our model</b>', `<div class="stats" style="margin-bottom:12px">
            <div class="card stat"><div class="l">Training records</div><div class="v">${S.d.rows ? fmt(S.d.rows.length) : '~9,300'}</div><div class="s">cleared by rules, 20 companies</div></div>
            <div class="card stat"><div class="l">Labelled problems</div><div class="v">${S.d.rows ? S.d.rows.filter((r) => r.y).length : '120'}</div><div class="s">salary creep, raises above peers</div></div>
            <div class="card stat"><div class="l">Inputs</div><div class="v">15</div><div class="s">allow-listed numbers</div></div>
            <div class="card stat"><div class="l">Identifiers used</div><div class="v" style="color:var(--good)">0</div><div class="s">no names, NRIC, bank numbers</div></div></div>
            <div class="split"><div class="card" style="padding:0;overflow:hidden"><div style="padding:10px 12px;border-bottom:1px solid var(--line)"><b class="small">The only inputs the model sees</b></div><div class="tblwrap" style="max-height:300px;overflow:auto"><table class="g" style="min-width:0"><tbody>${FEATURES.map(([k, l], i) => `<tr><td class="small" style="white-space:normal">${i + 1}. ${esc(l)}</td></tr>`).join('')}</tbody></table></div></div>
            <div style="display:flex;flex-direction:column;gap:10px"><div class="card" style="padding:14px"><b class="small">Never used, by design</b><div style="display:flex;gap:6px;flex-wrap:wrap;margin-top:8px">${PROTECTED.map((p) => `<span class="tag t-n">${esc(p.replace('_', ' '))}</span>`).join('')}</div><p class="small muted" style="margin:8px 0 0">A test fails the build if any of these ever becomes an input.</p></div>
            <div class="ai"><div class="h">WHERE IT RUNS</div>Inside our own payroll system. Training and scoring need no outside AI service, so no payroll data leaves.</div>
            <div style="display:flex;justify-content:flex-end"><button class="btn p pulse" data-act="modelTrain" ${S.d.busy ? 'disabled' : ''}>${S.d.busy ? 'Preparing data…' : 'Train the model'}</button></div></div></div>`) },
        { t: 'Training', you: 'Watch the error fall, then click <b>Test on 20 new companies</b>.', sys: 'Each pass nudges 15 weights so problems score high and clean records score low. Problems are rare, so they are weighted up.',
          screen: () => { const m = S.d.model; const done = m && m.epochs >= EPOCHS;
            return consoleApp('Our model › <b>Training</b>', `<div style="display:flex;flex-direction:column;gap:12px"><div class="card" style="padding:14px"><div style="display:flex;justify-content:space-between;gap:8px"><b class="small">Training error</b><span class="small muted">pass ${m ? m.epochs : 0} of ${EPOCHS}</span></div>${m && m.loss.length ? lossChart(m.loss) : ''}<p class="small muted" style="margin:6px 0 0">Lower is better. ${m && m.loss.length ? `From ${m.loss[0].toFixed(2)} to ${m.loss[m.loss.length - 1].toFixed(3)}.` : 'Starting…'}</p></div>
              <div class="card" style="padding:14px"><b class="small">What it learned (weight per input)</b><div style="margin-top:8px">${m ? weightBars(m) : ''}</div></div></div>
              ${done ? `<div class="card" style="padding:12px 14px;margin-top:12px"><span class="small">Biggest signals: unexplained pay growth, small repeated pay steps, raises far above peers, and one approver signing several off-cycle raises. The bank and attendance inputs stay near zero because rules already catch those.</span></div>
              <div style="display:flex;justify-content:flex-end;margin-top:12px"><button class="btn p pulse" data-act="modelTest" ${S.d.busy ? 'disabled' : ''}>${S.d.busy ? 'Testing…' : 'Test on 20 new companies'}</button></div>` : ''}`); } },
        { t: 'Results on new companies', you: 'Read the results, then click <b>Next</b>.', sys: 'The test companies were never used in training. The harder test uses smaller creep steps, smaller raises and a second approver.',
          screen: () => { const e = S.d.ev, hd = S.d.hard; if (!e) return '';
            const inc = (x) => x.byType.filter((t) => t.category === 'Salary increase');
            const sum = (xs, k) => xs.reduce((a, t) => a + t[k], 0);
            const ie = inc(e), ih = inc(hd);
            return consoleApp('Our model › <b>Results</b>', `<div class="stats" style="margin-bottom:12px">
              <div class="card stat"><div class="l">Rules alone</div><div class="v">${fmt(e.rules.caught)} / ${fmt(e.planted)}</div><div class="s">${pct(e.rules.caught, e.planted)} of hidden problems</div></div>
              <div class="card stat"><div class="l">Rules + our model</div><div class="v" style="color:var(--good)">${fmt(e.combined.caught)} / ${fmt(e.planted)}</div><div class="s">${pct(e.combined.caught, e.planted)}</div></div>
              <div class="card stat"><div class="l">Salary-increase patterns</div><div class="v">${sum(ie, 'rules')} → ${sum(ie, 'combined')}</div><div class="s">of ${sum(ie, 'planted')}; harder test: ${sum(ih, 'combined')}</div></div>
              <div class="card stat"><div class="l">False alarms</div><div class="v">${(e.combined.falseAlarmRate * 100).toFixed(1)}%</div><div class="s">was ${(e.rules.falseAlarmRate * 100).toFixed(1)}% with rules alone</div></div></div>
              <div class="card"><div class="tblwrap"><table class="g" style="min-width:600px"><thead><tr><th>Pattern (20 new companies)</th><th class="num-r">Rules alone</th><th class="num-r">Rules + model</th><th class="num-r">Harder test</th></tr></thead><tbody>
              ${ie.map((t, i) => `<tr class="hl"><td>${esc(t.label)}</td><td class="num-r">${t.rules} / ${t.planted}</td><td class="num-r"><b style="color:var(--good)">${t.combined} / ${t.planted}</b></td><td class="num-r">${ih[i].combined} / ${ih[i].planted}</td></tr>`).join('')}
              <tr><td>The other 9 problem types</td><td class="num-r">${e.rules.caught - sum(ie, 'rules')} / ${e.planted - sum(ie, 'planted')}</td><td class="num-r">${e.combined.caught - sum(ie, 'combined')} / ${e.planted - sum(ie, 'planted')}</td><td class="num-r">unchanged</td></tr></tbody></table></div></div>
              <div class="split" style="margin-top:12px">${e.examples.map((x) => `<div class="card" style="padding:14px"><span class="tag t-o">Model flag · ${x.p}</span><p class="small" style="margin:8px 0 4px"><b>${x.type === 'SALARY_CREEP' ? 'Salary creep' : 'Raise far above peers'}</b>: cleared by rules, flagged by the model.</p><ol class="small" style="margin:0;padding-left:18px">${x.why.map((w) => `<li>${esc(w)}</li>`).join('')}</ol></div>`).join('')}</div>
              <div style="display:flex;justify-content:flex-end;margin-top:12px"><button class="btn p pulse" data-act="next">Model card and approval</button></div>`); } },
        { t: 'Model card and approval', you: 'Approve as both reviewers. Done.', sys: 'A new model version goes live only after two named people approve it. Every version, its data and its results are kept for audit.',
          screen: () => { const c = S.d.card; const a = S.d.approvals; const both = a.priya && a.kevin; if (!c) return '';
            return consoleApp('Our model › <b>Model card</b>', `<div class="split"><div class="card"><div class="tblwrap"><table class="g" style="min-width:0"><tbody>
              ${[['Name', c.name], ['Version', c.version], ['Type', c.type], ['Trained on', c.trainedOn], ['Tested on', c.testedOn], ['Inputs', c.inputs], ['Can', c.canDo], ['Cannot', c.cannotDo], ['Flag threshold', c.threshold]].map(([k, v]) => `<tr><td class="small" style="white-space:nowrap"><b>${k}</b></td><td class="small" style="white-space:normal">${esc(v)}</td></tr>`).join('')}</tbody></table></div></div>
              <div style="display:flex;flex-direction:column;gap:10px"><div class="card">${[
                ['Retrained monthly', 'Only from two-person decisions and audits, so one person cannot teach it to ignore their own fraud.'],
                ['Drift alarm', 'If its flag rate moves outside 0.5–3%, it switches to rules-only and alerts the owner.'],
                ['Explained', 'Every flag shows its top 3 reasons; the 16 numbers of the model can be printed and audited.'],
                ['Fair', 'No protected attributes; flag rates are compared across departments every month.'],
              ].map(([t, d]) => `<div class="resolve"><div class="who2" style="min-width:0"><b>${t}</b><span>${d}</span></div><span class="tag t-g">On</span></div>`).join('')}</div>
              <div class="card" style="padding:12px 14px;display:flex;flex-direction:column;gap:8px"><b class="small">Two-person approval</b>
               <div style="display:flex;gap:8px;flex-wrap:wrap">${a.priya ? '<span class="tag t-g">Priya N., Compliance · approved</span>' : '<button class="btn p pulse" data-act="modelApprove:priya">Approve as Priya N. (Compliance)</button>'}${a.kevin ? '<span class="tag t-g">Kevin L., Head of Payroll · approved</span>' : `<button class="btn ${a.priya ? 'p pulse' : ''}" data-act="modelApprove:kevin">Approve as Kevin L. (Payroll)</button>`}</div>
               ${both ? '<div class="small" style="color:var(--good)"><b>v1 is active for the pilot.</b> Next review in 30 days.</div>' : '<div class="small muted">Not active until both approve.</div>'}</div></div></div>
              <div style="display:flex;gap:8px;margin-top:12px;flex-wrap:wrap"><button class="btn" data-act="restart">Replay</button><button class="btn" data-act="go:proof">See the rules test run</button></div>`); } },
      ],
    },
  };
}

export function extra3Actions(h) {
  const { S, render, go, addLog } = h;
  return {
    modelTrain() {
      if (S.d.busy) return; S.d.busy = true; render();
      setTimeout(() => {
        S.d.rows = S.d.rows || dataset(TRAIN_SEEDS);
        S.d.model = initModel(); S.d.busy = false;
        addLog(`Training started: ${S.d.rows.length.toLocaleString('en-SG')} de-identified records, 15 inputs`);
        go(1);
        const tick = () => {
          if (S.sc !== 'model' || !S.d.model) return;
          trainSteps(S.d.model, S.d.rows, { epochs: CHUNK });
          if (S.step === 1) render();
          if (S.d.model.epochs < EPOCHS) setTimeout(tick, 16);
          else { S.d.threshold = chooseThreshold(S.d.model, S.d.rows); addLog(`Training done: error ${S.d.model.loss[0].toFixed(2)} → ${S.d.model.loss[S.d.model.loss.length - 1].toFixed(3)}`); render(); }
        };
        setTimeout(tick, 16);
      }, 30);
    },
    modelTest() {
      if (S.d.busy || !S.d.model || S.d.model.epochs < EPOCHS) return; S.d.busy = true; render();
      setTimeout(() => {
        S.d.ev = evaluate(S.d.model, S.d.threshold, TEST_SEEDS);
        S.d.hard = evaluate(S.d.model, S.d.threshold, TEST_SEEDS, 500, HARDER);
        S.d.card = modelCard({ trainRows: S.d.rows.length, trainPositives: S.d.rows.filter((r) => r.y).length, ev: S.d.ev, threshold: S.d.threshold });
        S.d.busy = false;
        addLog(`Tested on 20 new companies: ${S.d.ev.combined.caught} of ${S.d.ev.planted} caught with the model (rules alone ${S.d.ev.rules.caught})`);
        go(2);
      }, 30);
    },
    modelApprove(who) { S.d.approvals[who] = true; addLog(`${who === 'priya' ? 'Priya N. (Compliance)' : 'Kevin L. (Head of Payroll)'} approved model v1`); if (S.d.approvals.priya && S.d.approvals.kevin) addLog('Model v1 active for the pilot'); render(); },
  };
}

export function extra3NextBlocked(S) {
  const d = S.d, s = S.step;
  if (S.sc !== 'model') return null;
  return (s === 0 && !d.model) || (s === 1 && !d.ev) || s === 3;
}
