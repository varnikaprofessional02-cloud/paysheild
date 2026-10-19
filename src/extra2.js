// Scenarios: "Ask PayShield" (live AI with guardrails) and "Check your own file" (in-browser CSV scoring).

import { buildExplainPayload, templateSentence } from './explain.js';
import { getSample, askPayShield, askPrompt, draftRule, saveText } from './ai.js';
import { checkFile, sampleCSV, templateCSV, COLUMNS } from './csvcheck.js';

const esc = (s) => String(s ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
const tag = (st, sc) => st === 'held' ? `<span class="tag t-r">${sc} · Held</span>` : st === 'review' ? `<span class="tag t-o">${sc} · Review</span>` : `<span class="tag t-g">${sc} · Clear</span>`;

const DANIEL = buildExplainPayload({ employeeId: 'E-1187', runSalt: 'run-2026-09',
  flags: ['BANK_CHANGED_RECENT', 'NEW_DEVICE', 'ALERT_UNCONFIRMED', 'PAY_SPIKE'], values: { days_before_payday: 2, pay_change_pct: 63 }, score: 23, status: 'held' });
const QUESTIONS = [
  ['why', 'Why is this record held?'],
  ['check', 'What should I check before releasing it?'],
  ['employee', 'Draft a short note to the employee'],
];
const ANNOUNCEMENT = 'CPF Board update for employers: From 1 January 2026, the CPF Ordinary Wage (OW) ceiling will be raised from $7,400 to $8,000 per month. This is the last step of the increase announced in Budget 2023. Employers should apply the new ceiling to Ordinary Wages paid for January 2026 onwards.';

const modeBadge = (m) => m == null ? '<span class="tag t-n">Checking AI…</span>' : m ? '<span class="tag t-b">Live AI · asks Claude</span>' : '<span class="tag t-n">Offline · built-in answers</span>';

export function extra2Scenarios(h) {
  const { app, consoleApp, S, fmt } = h;
  return {
    ask: {
      label: 'Ask PayShield', who: 'Live AI with guardrails',
      title: 'Ask PayShield, and see the guardrails work', sub: 'The AI answers from a masked record only, and every number it writes is checked. Rule Watch drafts a rule from public text; a person verifies it.',
      init() {
        S.d = { mode: null, q: '', kind: 'why', answer: '', res: null, busy: false, ann: ANNOUNCEMENT, draft: null, dbusy: false, chk: { val: false, date: false, src: false }, published: false };
        getSample().then((s) => { if (S.sc === 'ask') { S.d.mode = !!s; h.render(); } });
      },
      steps: [
        { t: 'Ask about a held record', you: 'Pick a question (or type one) and click <b>Ask</b>.', sys: 'Only the masked record on the left is sent: a token, flag codes and two numbers. No name, NRIC, bank number or salary. The answer is checked before it is shown.',
          screen: () => { const d = S.d, r = d.res;
            return app('PayShield › <b>Ask</b>', `<div style="display:flex;justify-content:space-between;align-items:center;gap:8px;flex-wrap:wrap;margin-bottom:12px"><div><b style="font-size:16px">Daniel Lim · E-1187</b> <span class="small muted">· September run</span></div><div style="display:flex;gap:6px;align-items:center">${tag('held', 23)}${modeBadge(d.mode)}</div></div>
            <div class="split">
             <div class="card" style="padding:14px"><b class="small">What the AI receives</b><pre class="payload" style="margin-top:8px">${esc(JSON.stringify(DANIEL, null, 2))}</pre><div class="small muted" style="margin-top:6px">The name is swapped back in only inside PayShield, after the answer is checked.</div></div>
             <div class="card" style="padding:14px;display:flex;flex-direction:column;gap:10px">
              <div style="display:flex;gap:6px;flex-wrap:wrap">${QUESTIONS.map(([k, q]) => `<button class="chip ${d.kind === k && d.q === q ? 'on' : ''}" data-act="askq:${k}" style="border:1px solid var(--line);background:${d.kind === k && d.q === q ? 'var(--accent-soft)' : 'var(--surface)'};cursor:pointer">${q}</button>`).join('')}</div>
              <div style="display:flex;gap:8px"><label for="askQ" class="small muted" style="position:absolute;left:-9999px">Your question</label><input id="askQ" type="text" value="${esc(d.q)}" placeholder="Or type your own question" style="flex:1;min-width:0;padding:9px 10px;border:1px solid var(--line);border-radius:9px;font:inherit;background:var(--surface);color:var(--ink)"><button class="btn p ${r ? '' : 'pulse'}" data-act="ask" ${d.busy ? 'disabled' : ''}>${d.busy ? 'Thinking…' : 'Ask'}</button></div>
              <div class="ai" style="min-height:70px"><div class="h">PAYSHIELD ANSWER</div><div id="aiOut">${esc(d.answer) || '<span class="muted">The answer appears here.</span>'}</div></div>
              ${r ? (r.checked ? `<div class="small" style="color:var(--good)">✓ Every number in the answer matches the record.${r.source === 'offline' ? ' (Built-in answer: AI is not available in this view.)' : ''}</div>`
                : `<div class="small" style="color:var(--bad)">✗ The answer used a number that is not in the record, so it is not shown to the admin. Fallback: “${esc(r.fallback || templateSentence(DANIEL))}”</div>`) : ''}
              ${r ? '<div style="display:flex;justify-content:flex-end"><button class="btn p pulse" data-act="next">Next: Rule Watch</button></div>' : ''}
             </div></div>
            <details style="margin-top:12px"><summary class="small muted" style="cursor:pointer">Show the exact prompt that is sent</summary><pre class="payload" style="margin-top:8px;white-space:pre-wrap">${esc(askPrompt(d.q || QUESTIONS[0][1], DANIEL))}</pre></details>`); } },
        { t: 'Rule Watch reads an announcement', you: 'Edit or paste an announcement, click <b>Draft rule</b>, then tick the three checks.', sys: 'The AI turns public text into a structured draft. PayShield then checks that every number and the year really appear in the source. Only a named person can publish.',
          screen: () => { const d = S.d, x = d.draft, c = d.chk, all = c.val && c.date && c.src, ok = x && !x.problems.length;
            const box = (k, label) => `<label style="display:flex;gap:8px;align-items:center;padding:8px 12px;border-top:1px solid var(--line);cursor:pointer"><input type="checkbox" data-act="chk2:${k}" ${c[k] ? 'checked' : ''} ${x ? '' : 'disabled'}> <span>${label}</span></label>`;
            return consoleApp('Rule Watch › <b>New draft</b>', `<div style="display:flex;justify-content:flex-end;margin-bottom:8px">${modeBadge(d.mode)}</div><div class="split">
             <div class="card" style="padding:14px"><label for="annText"><b class="small">Official announcement (public text)</b></label><textarea id="annText" rows="9" style="width:100%;box-sizing:border-box;margin-top:8px;padding:10px;border:1px solid var(--line);border-radius:9px;font:inherit;font-size:13px;background:var(--surface);color:var(--ink)">${esc(d.ann)}</textarea>
              <div style="display:flex;justify-content:flex-end;margin-top:8px"><button class="btn p ${x ? '' : 'pulse'}" data-act="draftRule" ${d.dbusy ? 'disabled' : ''}>${d.dbusy ? 'Drafting…' : 'Draft rule'}</button></div></div>
             <div class="card" style="padding:14px">${x ? `<div class="ai"><div class="h">${x.source === 'ai' ? '✨ AI DRAFT' : 'RULE-BASED DRAFT (AI not available here)'}</div>Rule <b>${esc(x.draft.rule_code)}</b><br>${esc(x.draft.description || '')}<br>Old value: ${esc(x.draft.old_value ?? '—')} → <b>New value: ${esc(x.draft.new_value ?? '—')}</b> ${esc(x.draft.unit || '')}<br>Effective: <b>${esc(x.draft.effective_date || '—')}</b><br>Applies to: ${esc(x.draft.applies_to || '—')}<br><span class="small muted">Confidence: ${esc(x.draft.confidence || '—')}</span></div>
              <div class="small" style="margin-top:8px;color:${ok ? 'var(--good)' : 'var(--bad)'}">${ok ? '✓ Every number and the year appear in the source text.' : '✗ Not publishable: ' + esc(x.problems.join('; '))}</div>` : '<p class="small muted">The draft appears here. Nothing is applied to any company.</p>'}</div></div>
            <div class="card" style="margin-top:12px;overflow:hidden"><div style="padding:10px 12px"><b>Reviewer checklist</b> <span class="small muted">· Priya N., Compliance owner</span></div>
             ${box('val', 'Value matches the official source')}${box('date', 'Effective date matches')}${box('src', 'Source is official (cpf.gov.sg, mom.gov.sg, iras.gov.sg)')}
             <div style="padding:10px 12px;display:flex;justify-content:space-between;align-items:center;gap:8px;flex-wrap:wrap;background:var(--surface2)"><span class="small muted">${d.published ? '<b style="color:var(--good)">Published by Priya N.</b> Companies are notified with a what-if.' : 'The AI cannot publish. Only a named reviewer can.'}</span>
             <button class="btn p ${all && ok && !d.published ? 'pulse' : ''}" data-act="publish2" ${all && ok && !d.published ? '' : 'disabled'}>Approve and publish</button></div></div>
            ${d.published ? '<div style="display:flex;justify-content:flex-end;margin-top:12px"><button class="btn p pulse" data-act="next">Next</button></div>' : ''}`); } },
        { t: 'Why this is safe', you: 'Done. Try <b>Check your own file</b> next.', sys: 'Five guardrails, all working in this demo.',
          screen: () => app('PayShield › <b>AI guardrails</b>', `<div class="card">${[
            ['Masked input', 'The AI sees a token, flag codes and a few numbers. Never names, NRIC, bank numbers or salary history.'],
            ['Checked output', 'Every number in an answer must exist in the record; otherwise a fixed template sentence is shown.'],
            ['Source check for rules', 'A rule draft is blocked if its numbers or year are not in the official text.'],
            ['A person decides', 'The AI never changes pay and cannot publish a rule. Release and publish need named people.'],
            ['Works without AI', 'Scores, holds and rule-based drafts still work when the AI is off. In production the AI runs on Azure OpenAI in Singapore via a private endpoint.'],
          ].map(([t, d]) => `<div class="resolve"><div class="who2" style="min-width:0"><b>${t}</b><span>${d}</span></div><span class="tag t-g">Active</span></div>`).join('')}</div>
            <div style="display:flex;gap:8px;margin-top:12px;flex-wrap:wrap"><button class="btn p" data-act="go:csv">Check your own file</button><button class="btn" data-act="restart">Replay</button></div>`) },
      ],
    },

    csv: {
      label: 'Check your own file', who: 'Runs in your browser',
      title: 'Check an anonymised pay run', sub: 'Load a CSV with one row per employee. PayShield scores it right here in the browser. Nothing is uploaded, and files with personal data are refused.',
      init() { S.d = { result: null, error: '', ms: 0, name: '' }; },
      steps: [
        { t: 'Choose a file', you: 'Click <b>Use the sample file</b>, or choose your own anonymised CSV.', sys: 'Columns that look like names, NRIC/FIN, emails, phones or bank numbers are refused before anything is checked.',
          screen: () => { const d = S.d;
            return app('Pay Run › <b>Check a file</b>', `<div class="split">
             <div class="card" style="padding:16px;display:flex;flex-direction:column;gap:12px"><b style="font-size:15px">Load a pay run</b>
              <button class="btn p pulse" data-act="csvSample">Use the sample file (500 anonymised rows)</button>
              <label class="btn" style="text-align:center;cursor:pointer">Choose your own CSV…<input id="csvFile" type="file" accept=".csv,text/csv" style="position:absolute;left:-9999px"></label>
              <div style="display:flex;gap:8px;flex-wrap:wrap"><button class="btn" data-act="csvDl:template">Download template</button><button class="btn" data-act="csvDl:sample">Download sample</button></div>
              ${d.error ? `<div class="small" style="color:var(--bad);background:var(--bad-soft);border:1px solid var(--bad-line);border-radius:9px;padding:10px">${esc(d.error)}</div>` : ''}
              <div class="ai"><div class="h">PRIVACY</div>The file is read by this page only. No upload, no AI, no server. Use references like A001, never names.</div></div>
             <div class="card" style="padding:0;overflow:hidden"><div style="padding:10px 12px;border-bottom:1px solid var(--line)"><b class="small">Columns</b></div><div class="tblwrap" style="max-height:340px;overflow:auto"><table class="g" style="min-width:0"><tbody>${COLUMNS.map(([c, x]) => `<tr><td style="white-space:nowrap"><code>${c}</code></td><td class="small" style="white-space:normal">${x}</td></tr>`).join('')}</tbody></table></div></div></div>`); } },
        { t: 'Results', you: 'Done. Try your own file next, or replay.', sys: 'Every row was scored with the same code as the pay run and the test run.',
          screen: () => { const r = S.d.result; if (!r) return '';
            return app('Check a file › <b>Results</b>', `<div class="stats" style="margin-bottom:12px">
             <div class="card stat"><div class="l">Records</div><div class="v">${fmt(r.rows)}</div><div class="s">${esc(S.d.name)}</div></div>
             <div class="card stat"><div class="l">Clear</div><div class="v" style="color:var(--good)">${fmt(r.clear)}</div><div class="s">${(r.clear / r.rows * 100).toFixed(1)}%</div></div>
             <div class="card stat"><div class="l">Review</div><div class="v" style="color:var(--warn)">${fmt(r.review)}</div><div class="s">admin fixes or accepts</div></div>
             <div class="card stat"><div class="l">Held</div><div class="v" style="color:var(--bad)">${fmt(r.held)}</div><div class="s">checked in ${S.d.ms} ms, nothing uploaded</div></div></div>
            <div class="card"><div class="tblwrap" style="max-height:440px;overflow:auto"><table class="g" style="min-width:560px"><thead><tr><th>Ref</th><th>Trust Score</th><th>Why</th></tr></thead><tbody>
            ${r.flagged.slice(0, 60).map((x) => `<tr><td><b>${esc(x.ref)}</b></td><td>${tag(x.status, x.score)}</td><td class="small">${esc(x.reasons.join(' · ') || 'Combination of small signals')}</td></tr>`).join('')}</tbody></table></div>
            ${r.flagged.length > 60 ? `<div class="small muted" style="padding:8px 12px">Showing 60 of ${r.flagged.length} flagged records.</div>` : ''}</div>
            <div style="display:flex;gap:8px;margin-top:12px;flex-wrap:wrap"><button class="btn" data-act="restart">Check another file</button><button class="btn" data-act="go:proof">See the test run</button></div>`); } },
      ],
    },
  };
}

export function extra2Actions(h) {
  const { S, render, go, addLog } = h;
  let ctl = null;
  const runCheck = (text, name) => {
    const t0 = performance.now();
    try {
      const r = checkFile(text);
      S.d.result = r; S.d.error = ''; S.d.ms = Math.max(1, Math.round(performance.now() - t0)); S.d.name = name;
      addLog(`${name}: ${r.rows} records checked in the browser; ${r.review} to review, ${r.held} held`);
      go(1);
    } catch (e) {
      S.d.error = e.message; addLog(e.privacy ? 'File refused: it looks like it contains personal data' : 'File could not be read'); render();
    }
  };
  document.addEventListener('change', (e) => {
    const el = e.target;
    if (el && el.id === 'csvFile' && el.files && el.files[0]) {
      const f = el.files[0];
      if (f.size > 10 * 1024 * 1024) { S.d.error = 'Files up to 10 MB.'; render(); return; }
      const fr = new FileReader();
      fr.onload = () => runCheck(String(fr.result), f.name.slice(0, 60));
      fr.readAsText(f);
    }
  });
  document.addEventListener('input', (e) => {
    if (e.target && e.target.id === 'askQ') { S.d.q = e.target.value; S.d.kind = 'custom'; }
    if (e.target && e.target.id === 'annText') { S.d.ann = e.target.value; }
  });
  document.addEventListener('keydown', (e) => {
    if (e.key === 'Enter' && e.target && e.target.id === 'askQ') { e.preventDefault(); actions.ask(); }
  });
  const actions = {
    askq(k) { const q = QUESTIONS.find(([kk]) => kk === k); if (!q) return; S.d.kind = k; S.d.q = q[1]; actions.ask(); },
    async ask() {
      if (S.d.busy) return;
      const q = (S.d.q || '').trim() || QUESTIONS[0][1];
      S.d.q = q; S.d.busy = true; S.d.answer = ''; S.d.res = null; render();
      ctl = new AbortController();
      try {
        const res = await askPayShield({ kind: S.d.kind === 'custom' ? 'why' : S.d.kind, question: q, payload: DANIEL, signal: ctl.signal,
          onText: (t) => { S.d.answer = t; const el = document.getElementById('aiOut'); if (el) el.textContent = t; } });
        S.d.answer = res.text; S.d.res = res;
        addLog(`Asked PayShield (${res.source === 'ai' ? 'live AI' : 'built-in'}): number check ${res.checked ? 'passed' : 'failed, template shown'}`);
      } catch { /* cancelled */ }
      S.d.busy = false; if (S.sc === 'ask') render();
    },
    async draftRule() {
      if (S.d.dbusy) return;
      const el = document.getElementById('annText'); if (el) S.d.ann = el.value;
      S.d.dbusy = true; S.d.draft = null; S.d.chk = { val: false, date: false, src: false }; S.d.published = false; render();
      try {
        const x = await draftRule(S.d.ann);
        S.d.draft = x; addLog(`Rule Watch drafted ${x.draft.rule_code} (${x.source === 'ai' ? 'AI' : 'rule-based'}); source check ${x.problems.length ? 'failed' : 'passed'}`);
      } catch { /* cancelled */ }
      S.d.dbusy = false; if (S.sc === 'ask') render();
    },
    chk2(k) { if (!S.d.draft) return; S.d.chk[k] = !S.d.chk[k]; render(); },
    publish2() { const c = S.d.chk; if (!(c.val && c.date && c.src) || !S.d.draft || S.d.draft.problems.length) return; S.d.published = true; addLog(`Priya N. verified and published ${S.d.draft.draft.rule_code}`); render(); },
    csvSample() { runCheck(sampleCSV(), 'payshield_sample_payrun.csv'); },
    async csvDl(which) { await saveText(which === 'template' ? 'payshield_template.csv' : 'payshield_sample_payrun.csv', which === 'template' ? templateCSV() : sampleCSV()); addLog(`Downloaded the ${which} file`); render(); },
  };
  return actions;
}

export function extra2NextBlocked(S) {
  const d = S.d, s = S.step;
  if (S.sc === 'ask') return (s === 0 && !d.res) || (s === 1 && !d.published) || s === 2;
  if (S.sc === 'csv') return (s === 0 && !d.result) || s === 1;
  return null;
}
