// Scenarios: "Payroll Validators" (every check, its parameters and its AI) and "PayShield Agent" (our payroll LLM agent).
import { DEFAULT_CONFIG } from './scoring.js';
import { RULES, rule } from './rules.js';
import { MODEL_V1 } from './model.js';
import { KB, CATEGORIES, evaluateRetrieval, trainingJSONL } from './kb.js';
import { askAgent } from './agent.js';
import { getSample, saveText } from './ai.js';

const esc = (s) => String(s ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
const C = DEFAULT_CONFIG, B = C.bankPoints;
const money = (n) => 'S$' + Number(n).toLocaleString('en-SG');

/** Every validator, with the parameters it uses (read from the code) and how AI helps it. */
export const VALIDATORS = [
  { id: 'emp', name: 'Employee record', q: 'Is this person really due pay this period?', ai: 'Explains each flag in plain English, from masked data',
    params: [['Last working day', 'in or after the pay period', 'Critical if before'], ['Contract and work pass', 'active on pay date', 'Critical if expired']], caught: 'Ex-employees still in the run' },
  { id: 'pay', name: 'Pay calculation', q: 'Is this pay normal for this person?', ai: 'Learns reasons admins accept, for 3 pay runs',
    params: [['Baseline', 'own 6-month median', '—'], ['Unusual if', 'more than 2 robust spreads (MAD) away', 'signal 0.30–0.95'], ['Known reasons', 'increment, bonus, proration', 'cancel the check'], ['Weight in Trust Score', C.weights.pay.toFixed(2), '—']], caught: 'Pay spikes, unrecorded promotions' },
  { id: 'rules', name: 'Statutory rules', q: 'Are we using today’s CPF, MOM and IRAS rules?', ai: 'Rule Watch drafts updates from official sources; a named reviewer publishes',
    params: [['CPF Ordinary Wage ceiling', money(rule('CPF_OW_CEILING').value) + ' / month', rule('CPF_OW_CEILING').version], ['CPF Additional Wage ceiling', rule('CPF_AW_CEILING').value, 'per year'], ['CPF rate, 55 and below', rule('CPF_RATE_55').value, 'from 1 Jan 2026'], ['SDL', rule('SDL').value, '—'], ['Deduction limit', rule('MOM_DEDUCTION_CAP').value + ' of salary', 'with exceptions']], caught: 'CPF on an old ceiling, wrong rates' },
  { id: 'bank', name: 'Bank details', q: 'Is the salary going to the right account?', ai: 'Fraud Network: keyed fingerprints shared across companies',
    params: [['Changed in last 30 days', `+${B.changedWithin30Days.toFixed(2)}`, '—'], ['Within 7 days of payday', `+${B.within7DaysOfPayday.toFixed(2)}`, '—'], ['From a new device', `+${B.newDevice.toFixed(2)}`, '—'], ['Not confirmed on 2nd channel', `+${B.alertUnconfirmed.toFixed(2)}`, 'Held near payday'], ['Shared with another employee', 'always Review', '—'], ['Fraud Network match', 'Held', '—'], ['Weight in Trust Score', C.weights.bank.toFixed(2), '—']], caught: 'Salary diversion, ghost employees' },
  { id: 'att', name: 'Attendance proof', q: 'Were the paid hours really worked?', ai: 'Suggests the usual clock-out time for a missed punch',
    params: [['Overtime cap', `${rule('MOM_OT_CAP').value} h / month`, 'MOM'], ['Minimum OT rate', `${rule('MOM_OT_RATE').value}× hourly basic`, 'MOM'], ['OT without clock proof', '> 0 h', 'Warning'], ['Days without clock-out', '≥ 3', 'Warning'], ['Weight in Trust Score', C.weights.attendance.toFixed(2), '—']], caught: 'OT over cap, unproven hours, buddy punching' },
  { id: 'ai', name: 'AI pattern check', q: 'Is there a slow pattern the rules miss?', ai: 'Our own model v1, trained on de-identified features',
    params: [['Inputs', '15 allow-listed numbers', 'no ids or protected attributes'], ['Flag threshold', MODEL_V1.threshold.toFixed(2), 'probability'], ['Strongest inputs', 'unexplained growth (+4.22), small steps (+2.74)', 'weights'], ['Power', 'can only add Review', 'never clears or holds']], caught: 'Salary creep, raises far above peers' },
];

export function extra5Scenarios(h) {
  const { app, S } = h;
  return {
    validators: {
      label: 'Payroll Validators', who: 'Every check and its parameters',
      title: 'Payroll Validators: what is checked, and with which parameters', sub: 'Six validators run on every employee before a pay run. Each shows the exact parameters it uses and where AI helps. The values come straight from the code and the rule library.',
      init() { S.d = {}; },
      steps: [
        { t: 'Six validators and their parameters', you: 'Read each validator, then click <b>Next</b> for the Trust Score settings.', sys: 'These are the live values the pre-flight check uses. Changing any of them needs an admin and is logged.',
          screen: () => app('PayShield › <b>Payroll Validators</b>', `<div class="val-grid">${VALIDATORS.map((v, i) => `<div class="card val">
            <div class="val-head"><span class="pf-num">${i + 1}</span><div style="min-width:0"><b style="font-size:15px">${v.name}</b><div class="small muted">${v.q}</div></div><span class="tag t-g" style="margin-left:auto">On</span></div>
            <table class="g val-t" style="min-width:0"><tbody>${v.params.map(([n, val, note]) => `<tr><td class="small">${esc(n)}</td><td><span class="pv">${esc(val)}</span></td><td class="small muted">${note === '—' ? '' : esc(note)}</td></tr>`).join('')}</tbody></table>
            <div class="val-ai"><span class="tag t-b">AI</span> <span class="small">${esc(v.ai)}</span></div>
            <div class="small muted">Catches: ${esc(v.caught)}</div></div>`).join('')}</div>`, 'PayShield') },
        { t: 'Trust Score and rule library', you: 'Done. Try <b>PayShield Agent</b> next.', sys: 'The Trust Score combines the validators. The rule library holds the versioned statutory values.',
          screen: () => app('PayShield › Payroll Validators › <b>Trust Score</b>', `<div class="split">
            <div class="card" style="padding:16px"><b style="font-size:15px">Trust Score</b>
             <div class="calc" style="margin-top:10px"><span>Pay weight</span><b class="pv">${C.weights.pay.toFixed(2)}</b><span>Bank weight</span><b class="pv">${C.weights.bank.toFixed(2)}</b><span>Attendance weight</span><b class="pv">${C.weights.attendance.toFixed(2)}</b><span>Extra strong signal (≥ ${C.comboThreshold})</span><b class="pv">+${C.comboBonus}</b><span>Clear</span><b class="pv">≥ ${C.thresholds.clear}</b><span>Review</span><b class="pv">${C.thresholds.review}–${C.thresholds.clear - 1}</b><span>Held</span><b class="pv">&lt; ${C.thresholds.review}</b></div>
             <p class="small muted" style="margin:10px 0 0">Score = 100 × (1 − risk). Overrides: Critical rule → at least Review; Fraud Network match or unconfirmed new account near payday → Held. Our model can only add Review.</p></div>
            <div class="card" style="padding:0;overflow:hidden"><div style="padding:12px 14px;border-bottom:1px solid var(--line)"><b style="font-size:15px">Rule library</b> <span class="small muted">· versioned, verified October 2026</span></div><div class="tblwrap" style="max-height:360px;overflow:auto"><table class="g" style="min-width:0"><tbody>
             ${RULES.map((r) => `<tr><td class="small"><b>${esc(r.name)}</b><div class="muted">${esc(r.version)} · from ${esc(r.from)} · ${esc(r.src)}</div></td><td><span class="pv">${esc(typeof r.value === 'number' ? (r.code.startsWith('CPF') ? money(r.value) : r.value) : r.value)}</span><div class="small muted">${esc(r.unit)}</div></td></tr>`).join('')}</tbody></table></div></div></div>
            <div style="display:flex;gap:8px;margin-top:12px;flex-wrap:wrap"><button class="btn p" data-act="go:agent">Open PayShield Agent</button><button class="btn" data-act="go:preflight">See them in the pre-flight check</button></div>`, 'PayShield') },
      ],
    },

    agent: {
      label: 'PayShield Agent', who: 'Our payroll LLM agent',
      title: 'PayShield Agent: ask any payroll question', sub: 'Our own payroll agent answers from verified Singapore rules and can run the validators on an employee. It cites every answer and says so when it does not know.',
      init() { S.d = { msgs: [], busy: false, mode: null, q: '', ev: evaluateRetrieval() }; getSample().then((s) => { if (S.sc === 'agent') { S.d.mode = !!s; h.render(); } }); },
      steps: [
        { t: 'Ask the agent', you: 'Pick a question or type your own, then press <b>Ask</b>. Try “Why is Ravi under review?”.', sys: 'The agent finds the verified answers, runs validators if you name an employee, and cites its sources. Names are masked before anything reaches the language model.',
          screen: () => { const d = S.d;
            const chips = ['What is the CPF Ordinary Wage ceiling in 2026?', 'What is the maximum overtime per month?', 'How much CPF for a 62 year old?', 'Why is Ravi under review?', 'Why is Daniel held?', 'When must salary be paid?', 'How much shared parental leave is there?', 'Does the AI see personal data?'];
            return app('PayShield › <b>Agent</b>', `<div class="agent-wrap">
             <div class="card agent-chat"><div class="agent-msgs" id="agentMsgs">${d.msgs.length ? d.msgs.map(msgHtml).join('') : `<div class="agent-empty"><b>Hi, I’m PayShield Agent.</b><span class="small muted">Ask about CPF, overtime, leave, payslips, tax deadlines, or why an employee was flagged.</span></div>`}
              ${d.busy ? '<div class="msg bot"><div class="bubble muted" id="agentLive">Thinking…</div></div>' : ''}</div>
              <div class="agent-chips">${chips.map((c) => `<button class="chip-btn" data-act="agentAsk:${encodeURIComponent(c)}" ${d.busy ? 'disabled' : ''}>${esc(c)}</button>`).join('')}</div>
              <div class="agent-input"><label for="agentQ" class="sr">Your question</label><input id="agentQ" type="text" placeholder="Ask a payroll question…" value="${esc(d.q)}" autocomplete="off"><button class="btn p" data-act="agentSend" ${d.busy ? 'disabled' : ''}>Ask</button></div></div>
             <div class="agent-side">
              <div class="card" style="padding:14px"><div style="display:flex;justify-content:space-between;gap:8px;align-items:center"><b>PayShield Agent v1</b>${d.mode == null ? '<span class="tag t-n">…</span>' : d.mode ? '<span class="tag t-b">Live AI</span>' : '<span class="tag t-n">Offline</span>'}</div>
               <p class="small muted" style="margin:6px 0 0">Our own payroll model, fine-tuned on verified Q&amp;A and hosted in our tenant. ${d.mode ? 'In this view, Claude writes the wording from the same sources.' : 'In this view, answers are the verified text itself.'}</p></div>
              <div class="card" style="padding:14px"><b class="small">Knows</b><div class="small muted" style="margin-top:4px">${KB.length} verified answers · ${KB.reduce((a, x) => a + 1 + (x.train || []).length, 0)} training questions</div><div style="display:flex;gap:6px;flex-wrap:wrap;margin-top:8px">${CATEGORIES.map((c) => `<span class="tag t-n">${esc(c)}</span>`).join('')}</div></div>
              <div class="card" style="padding:14px"><b class="small">Tools it can use</b><ul class="small agent-ul"><li>Run the 6 validators on an employee</li><li>Look up the versioned rule library</li></ul></div>
              <div class="card" style="padding:14px"><b class="small">Guardrails</b><ul class="small agent-ul"><li>Answers only from verified sources, with citations</li><li>Numbers not in the sources → answer replaced</li><li>Names masked before the language model</li><li>Low confidence → “I don’t know”, question logged</li></ul></div>
             </div></div>`, 'PayShield'); } },
        { t: 'How it is trained and tested', you: 'Done. Download the training set if you want to see it.', sys: 'Questions it has never seen are used to test it. The same set grows from support tickets and is re-tested every release.',
          screen: () => { const e = S.d.ev, nTrain = KB.reduce((a, x) => a + 1 + (x.train || []).length, 0);
            return app('PayShield › Agent › <b>Training and tests</b>', `<div class="stats" style="margin-bottom:12px">
             <div class="card stat"><div class="l">Training examples</div><div class="v">${nTrain}</div><div class="s">${KB.length} verified answers × phrasings</div></div>
             <div class="card stat"><div class="l">Unseen test questions</div><div class="v">${e.total}</div><div class="s">paraphrases never used in training</div></div>
             <div class="card stat"><div class="l">Right answer first</div><div class="v">${Math.round(e.rate * 100)}%</div><div class="s">${e.ok} of ${e.total}</div></div>
             <div class="card stat"><div class="l">Right answer in top 3</div><div class="v" style="color:var(--good)">${Math.round(e.top3Rate * 100)}%</div><div class="s">what the model reads before answering</div></div></div>
            <div class="split"><div class="card"><div class="tblwrap"><table class="g" style="min-width:0"><thead><tr><th>Topic</th><th class="num-r">Answers</th><th class="num-r">Test: right first</th></tr></thead><tbody>
              ${CATEGORIES.map((c) => `<tr><td>${esc(c)}</td><td class="num-r">${KB.filter((x) => x.cat === c).length}</td><td class="num-r">${e.byCat[c].ok} / ${e.byCat[c].total}</td></tr>`).join('')}</tbody></table></div></div>
             <div class="card" style="padding:14px;display:flex;flex-direction:column;gap:8px"><b>How we train it</b><ol class="small agent-ul" style="list-style:decimal">
              <li>Payroll experts write and verify each answer against MOM, CPF Board or IRAS.</li><li>Each answer gets several real-world phrasings (from support tickets in production).</li><li>A base model is fine-tuned on this set inside our Azure tenant; no customer data is used.</li><li>Unseen questions test it every release; anything below 90% in top 3 blocks the release.</li><li>Questions it cannot answer are logged and become new training examples.</li></ol>
              <button class="btn" data-act="agentDl">Download training set (JSONL)</button><span class="small muted">Honest note: we wrote the test questions too. Next: test on real questions from our support desk.</span></div></div>`, 'PayShield'); } },
      ],
    },
  };
}

function msgHtml(m) {
  if (m.role === 'user') return `<div class="msg me"><div class="bubble">${esc(m.text)}</div></div>`;
  const r = m.res;
  const srcs = (r.hits || []).slice(0, 2).map((x, i) => /^https?:/.test(x.entry.src) ? `<a href="${esc(x.entry.src)}" target="_blank" rel="noopener">[${i + 1}] ${esc(new URL(x.entry.src).hostname.replace('www.', ''))}</a>` : `<span>[${i + 1}] ${esc(x.entry.src)}</span>`).join(' · ');
  const tag = r.source === 'ai' ? '<span class="tag t-b">Live AI</span>' : r.source === 'none' ? '<span class="tag t-n">No verified answer</span>' : r.source === 'tool' ? '<span class="tag t-n">Validators</span>' : '<span class="tag t-n">Verified answer</span>';
  return `<div class="msg bot"><div class="bubble">${esc(r.text)}
    ${r.tool ? `<div class="tool-note"><b>Tool used:</b> ran 6 validators on ${esc(r.employee.name)} (sent to the model as ${esc(r.tool.token)}): Trust Score ${r.tool.score}, ${esc(r.tool.status)}.</div>` : ''}
    <div class="bubble-meta">${tag}${r.checked && r.source !== 'none' ? ' <span class="small" style="color:var(--good)">✓ numbers checked</span>' : ''}${srcs ? ` <span class="small muted">Sources: ${srcs}</span>` : ''}</div></div></div>`;
}

export function extra5Actions(h) {
  const { S, render, addLog } = h;
  let ctl = null;
  const scrollDown = () => { const el = document.getElementById('agentMsgs'); if (el) el.scrollTop = el.scrollHeight; };
  const ask = async (q) => {
    q = String(q || '').trim(); if (!q || S.d.busy) return;
    S.d.msgs.push({ role: 'user', text: q }); S.d.busy = true; S.d.q = ''; render(); scrollDown();
    ctl = new AbortController();
    try {
      const res = await askAgent(q, { signal: ctl.signal, onText: (t) => { const el = document.getElementById('agentLive'); if (el) { el.textContent = t; el.classList.remove('muted'); } scrollDown(); } });
      S.d.msgs.push({ role: 'bot', res });
      addLog(`Agent answered (${res.source === 'ai' ? 'live AI' : res.source === 'tool' ? 'validators' : res.source === 'none' ? 'no verified answer' : 'verified answer'})${res.tool ? ' after running validators on ' + res.employee.name : ''}`);
    } catch { /* cancelled */ }
    S.d.busy = false; if (S.sc === 'agent') { render(); scrollDown(); const i = document.getElementById('agentQ'); if (i) i.focus(); }
  };
  document.addEventListener('input', (e) => { if (e.target && e.target.id === 'agentQ') S.d.q = e.target.value; });
  document.addEventListener('keydown', (e) => { if (e.key === 'Enter' && e.target && e.target.id === 'agentQ') { e.preventDefault(); ask(e.target.value); } });
  return {
    agentAsk(enc) { ask(decodeURIComponent(enc)); },
    agentSend() { const i = document.getElementById('agentQ'); ask(i ? i.value : S.d.q); },
    async agentDl() { await saveText('payshield_agent_training_set.jsonl', trainingJSONL(), 'application/jsonl'); addLog('Downloaded the agent training set'); render(); },
  };
}

export function extra5NextBlocked(S) {
  if (S.sc === 'validators') return S.step === 1;
  if (S.sc === 'agent') return S.step === 1;
  return null;
}
