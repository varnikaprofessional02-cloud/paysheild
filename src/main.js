import './style.css';
// The demo always uses the light theme, whatever the computer's dark-mode setting.
document.documentElement.setAttribute('data-theme', 'light');
document.getElementById('nodev')?.remove();
import { tenantApp, consoleShell, statCard, ICON, logo, toggleSide, MARK, setScenarioMenu, psShell, setPsMenu } from './chrome.js';
import { COMPANY, ISSUES, POLICIES, GUARDS, pendingIn, payScore, GUARD_SWITCH, HIGH_RISK_GUARDS, setGuardOff, resetGuards, RUN, isRemoval } from './company.js';
import { buildPages } from './pages.js';
import { intelligence } from './intelligence.js';
import { initAgentState, agentBody, recordsBody, agentActions, RUN_PROMPT } from './agentpage.js';
const CO = COMPANY.name;
const bm=document.getElementById('brandmark'); if(bm) bm.outerHTML=MARK(40);
import { trustScore, DEFAULT_CONFIG } from './scoring.js';
import { buildExplainPayload, templateSentence } from './explain.js';
import { extraScenarios, extraActions, extraNextBlocked } from './extra.js';
import { extra2Scenarios, extra2Actions, extra2NextBlocked } from './extra2.js';
import { extra3Scenarios, extra3Actions, extra3NextBlocked } from './extra3.js';
import { extra4Scenarios, extra4Actions, extra4NextBlocked } from './extra4.js';
import { extra5Scenarios, extra5Actions, extra5NextBlocked } from './extra5.js';

const $ = s => document.querySelector(s);
const fmt = n => n.toLocaleString('en-SG');
const reduce = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
let timer = null;
const clearTimer = () => { if (timer) { clearInterval(timer); timer = null; } };

/* ---------- state ---------- */
const S = { sc: 'payrun', step: 0, done: new Set(), log: [], d: {} };
const clock = { t: 0 };
function addLog(text){ S.log.unshift({ t: S.logTime(), text, fresh: true }); }

const RAW_ROWS = () => ([
  { n:'Daniel Lim', id:'E-1187', dept:'Logistics', aug:4980, sep:8120, sig:['Pay','Bank','Resigned'], sc:23, st:'held', why:'Bank changed 2 days ago from a new device; OT 3.1× usual; resignation filed' },
  { n:'Lim Hui Ling', id:'E-1033', dept:'HR', aug:4200, sep:4200, sig:['Pay'], sc:52, st:'review', why:'Last day was 31 Aug but she is still in this run', act:'Remove from this run (final pay already settled)', res:'removed' },
  { n:'Tan Wei Ming', id:'E-1102', dept:'Operations', aug:5120, sep:9840, sig:['Pay','Attendance'], sc:60, st:'review', why:'OT 88 h (cap 72 h); 14 h have no clock-out', act:'Cap OT at 72 h; send 14 h to manager', res:'fixed', after:{sep:7210, sc:88} },
  { n:'Siti Rahmah', id:'E-1015', dept:'Finance', aug:6412, sep:6412, sig:['Pay'], sc:64, st:'review', why:'CPF worked out on the S$7,400 ceiling; 2026 ceiling is S$8,000', act:'Recalculate CPF on the S$8,000 ceiling', res:'fixed', after:{sep:6292, sc:93} },
  { n:'Arjun Kumar', id:'E-1240', dept:'Production', aug:2350, sep:2350, sig:['Bank'], sc:66, st:'review', why:'Same bank account as employee E-1042', act:'Accept: joint account with spouse, verified by HR', res:'accepted' },
  { n:'Mohd Faizal', id:'E-1311', dept:'Warehouse', aug:2100, sep:2640, sig:['Attendance'], sc:70, st:'review', why:'Same phone clocked in 3 staff on 12 Sep', act:'Accept: site phone used during outage, supervisor confirmed', res:'accepted' },
  { n:'Chen Jia Hui', id:'E-1076', dept:'Marketing', aug:5800, sep:5950, sig:['Bank'], sc:76, st:'review', why:'New bank account in cooling-off (2 days left)', act:'Accept: employee confirmed “it was me”', res:'accepted' },
]);
/* Seed signals per record (0-1). In production these come from the signal
   functions in scoring.js run over the full pay, bank and timesheet data. */
const SEED = {
  'Daniel Lim':   { s:{ pay:0.82, bank:0.90, attendance:0.40 }, o:{ forceHold:true } },
  'Lim Hui Ling': { s:{ pay:0.90, attendance:0.48 }, o:{ critical:true } },
  'Tan Wei Ming': { s:{ pay:0.55, attendance:0.60 }, after:{ pay:0.20, attendance:0.16 } },
  'Siti Rahmah':  { s:{ pay:0.90 }, o:{ critical:true }, after:{ pay:0.175 } },
  'Arjun Kumar':  { s:{ bank:0.97 } },
  'Mohd Faizal':  { s:{ pay:0.20, attendance:0.88 } },
  'Chen Jia Hui': { s:{ bank:0.68 } },
};
const applyScore = (r) => { const sd = SEED[r.n]; const res = trustScore(sd.s, sd.o || {}); r.sc = res.score; r.st = res.status; r.result = res;
  if (r.after && sd.after) r.after.sc = trustScore(sd.after).score; return r; };
const ROWS = () => RAW_ROWS().map(applyScore);
function scoreBox(){
  const sd = SEED['Daniel Lim'], r = trustScore(sd.s, sd.o), w = DEFAULT_CONFIG.weights;
  const line = (l, v) => `<span>${l}</span><b>${v}</b>`;
  const payload = buildExplainPayload({ employeeId:'E-1187', runSalt:'run-2026-09',
    flags:['BANK_CHANGED_RECENT','NEW_DEVICE','ALERT_UNCONFIRMED','PAY_SPIKE'], values:{ days_before_payday:2, pay_change_pct:63 }, score:r.score, status:r.status });
  return `<div class="card" style="padding:10px 12px;margin-top:10px"><b style="font-size:12.5px">Score breakdown (live from scoring.js)</b><div class="calc">
  ${line(`Pay ${w.pay.toFixed(2)} × ${r.signals.pay.toFixed(2)}`, r.parts.pay.toFixed(3))}${line(`Bank ${w.bank.toFixed(2)} × ${r.signals.bank.toFixed(2)}`, r.parts.bank.toFixed(3))}
  ${line(`Attendance ${w.attendance.toFixed(2)} × ${r.signals.attendance.toFixed(2)}`, r.parts.attendance.toFixed(3))}${line('Two strong signals bonus', '+' + r.bonus.toFixed(2))}
  ${line('Risk', r.risk.toFixed(3))}${line('Trust Score = 100 × (1 − risk)', r.score + ' · ' + r.status.toUpperCase())}</div></div>
  <div class="card" style="padding:10px 12px;margin-top:10px"><b style="font-size:12.5px">What the AI receives (no name, ID or bank number)</b><pre class="payload">${JSON.stringify(payload, null, 2)}</pre>
  <div class="small muted" style="margin-top:6px">Checked fallback sentence: ${templateSentence(payload)}</div></div>`;
}


/* ---------- shared pieces ---------- */
// Employees see their own HR app; admins and approvers work in PayShield.
function app(crumb, body, active='Pay Run', user='VR', role){ return ['DL','MF'].includes(user) || role === 'Employee' ? tenantApp(CO.toLowerCase(), COMPANY.letter, crumb, body, active, user, role) : psShell(crumb, body, user, role); }
// Finishing a demo story resolves the matching findings on the guard pages.
const DEMO_RESOLVES = { preflight: ['daniel', 'tan', 'siti', 'ravi'], bank: ['daniel'], rules: ['siti'] };
function stepper(active){
  const steps=[['Details','Period and pay date'],['Employees','Who is in this run'],['Pay items','Earnings and deductions'],['Trust Check','PayShield pre-flight'],['Approve','Review and approve'],['Done','Paid and locked']];
  return `<div class="card stepper">` + steps.map(([t,d],i)=>{
    const c = i<active?'d':(i===active?'a':'');
    return `<div class="st ${c}"><i>${i<active?'✓':i+1}</i><div><b>${t}${t==='Trust Check'?' <span class="new">NEW</span>':''}</b><span>${d}</span></div></div>` + (i<steps.length-1?`<div class="conn ${i<active?'d':''}"></div>`:'');
  }).join('') + `</div>`;
}
function phone(title, body, cap){
  return `<div><div class="phone"><div class="scr"><div class="sbar"><span>9:41</span><span class="notch"></span><span>●●●</span></div><div class="ptop"><img src="${logo}" alt="" width="20" height="20">${title}</div><div class="pbody">${body}</div></div></div>${cap?`<div class="pcap">${cap}</div>`:''}</div>`;
}
const statusTag = r => r.st==='held' ? `<span class="tag t-r">${r.sc} · Held</span>` : r.st==='review' ? `<span class="tag t-o">${r.sc} · Review</span>` : r.st==='removed' ? `<span class="tag t-n">Removed</span>` : r.st==='accepted' ? `<span class="tag t-g">${r.sc} · Accepted</span>` : `<span class="tag t-g">${r.sc} · Clear</span>`;
function counts(){
  const rows = S.d.rows;
  const review = rows.filter(r=>r.st==='review').length, held = rows.filter(r=>r.st==='held').length, removed = rows.filter(r=>r.st==='removed').length;
  const clear = 219 - review - held - removed;
  const score = Math.min(97, 86 + (6 - review) * 1.5 | 0);
  return { review, held, removed, clear, score };
}
function stats(){
  const c = counts();
  return `<div class="rulever">Rules used: <b>CPF v2026.1</b> · MOM OT v2024.1 · verified by the compliance team</div><div class="stats">
  ${statCard(ICON.gauge, 'Run Trust Score', `${c.score}<span class="small muted">/100</span>`, 'September 2026 · 219 employees', 'blue')}
  ${statCard(ICON.circleCheck, 'Clear', c.clear, 'paid as normal', 'green')}
  ${statCard(ICON.alert, 'Review', c.review, 'fix or accept with a reason', 'orange')}
  ${statCard(ICON.pause, 'Held', c.held, 'waits for a second approval', 'red')}</div>`;
}
function table(opts={}){
  const rows = S.d.rows.map((r,i)=>{
    const ch = r.sep===r.aug?'0%':((r.sep>r.aug?'+':'')+Math.round((r.sep-r.aug)/r.aug*100)+'%');
    const pulse = opts.pulse===i ? ' pulse' : '';
    const hl = opts.hl===i ? ' hl' : '';
    return `<tr class="click${hl}" data-act="${opts.act||'open'}:${i}" tabindex="0"><td class="who2"><b>${r.n}</b><span>${r.id} · ${r.dept}</span></td>
    <td class="num-r">S$${fmt(r.aug)}</td><td class="num-r"><b>S$${fmt(r.sep)}</b> <span class="small" style="color:${parseInt(ch)>30?'var(--bad)':'var(--mute)'}">${ch}</span></td>
    <td>${r.sig.map(s=>`<span class="chip">${s}</span>`).join('')}</td><td>${statusTag(r)}</td><td class="small" style="color:var(--ink2)">${r.done||r.why}</td>
    <td><span class="btn${pulse}" style="min-height:28px;padding:0 10px">Open ›</span></td></tr>`;
  }).join('');
  return `<div class="card"><div style="display:flex;justify-content:space-between;align-items:center;padding:8px 10px;border-bottom:1px solid var(--line);gap:8px;flex-wrap:wrap">
  <div style="display:flex;gap:6px;flex-wrap:wrap"><span class="tag t-b">All flags (7)</span><span class="tag t-n">Review (${counts().review})</span><span class="tag t-n">Held (${counts().held})</span></div><span class="muted small">Only flagged records are listed</span></div>
  <div class="tblwrap"><table class="g"><thead><tr><th>Employee</th><th class="num-r">Net pay Aug</th><th class="num-r">Net pay Sep</th><th>Signals</th><th>Score</th><th>Why it's flagged (AI)</th><th></th></tr></thead><tbody>${rows}</tbody></table></div></div>`;
}
function sigBars(vals, anim){
  const names=[['Pay variance','pay'],['Bank-change risk','bank'],['Attendance integrity','att']];
  return names.map(([n,k])=>{
    const v = vals[k] ?? 0, c = v>=.5?'var(--bad)':(v>=.3?'var(--warn)':'var(--good)');
    return `<div class="sigrow"><div class="top2"><span>${n}</span><span style="color:${c}">${v.toFixed(2)}</span></div><div class="bar"><i style="width:${anim?0:v*100}%;background:${c}" data-w="${v*100}"></i></div></div>`;
  }).join('');
}
function danielDrawer(footer){
  const ev=[['28 Sep, 11:09 pm','Login from a device never seen on this account','var(--mute)'],['28 Sep, 11:14 pm','Bank account changed from the same device (OTP entered)','var(--bad)'],['28 Sep, 11:15 pm','Alert sent to old email and phone. No reply yet','var(--warn)'],['30 Sep, 10:40 am','Resignation filed, last day 31 Oct','var(--warn)'],['Sep timesheet','OT 41 h, of which 9 h have no clock-out','var(--warn)']];
  return `<div class="drawer" role="dialog" aria-label="Daniel Lim record"><div class="dh"><div style="display:flex;gap:10px;align-items:center"><div class="av" style="background:var(--bad-soft);color:var(--bad);width:36px;height:36px">DL</div><div><b style="font-size:15px">Daniel Lim</b><div class="small muted">E-1187 · Logistics Executive · September 2026</div></div></div>
  <div style="text-align:right"><div style="font-size:26px;font-weight:800;color:var(--bad);line-height:1">23<span class="small muted">/100</span></div><span class="tag t-r">Held</span></div></div>
  <div class="db"><div><div class="ai"><div class="h">✨ WHY THIS IS HELD (AI SUMMARY)</div><div style="font-size:13px">Daniel's salary account was changed <b>2 days before payday</b> from a device he has never used, and he hasn't confirmed it. His net pay is <b>S$8,120, 63% above his 6-month average</b>, mainly from 41 OT hours, and he filed his resignation on 30 Sep. Each signal can be innocent alone; together they match a payroll diversion pattern.</div>
  <div class="small" style="margin-top:6px"><b>Suggested check:</b> call Daniel on the number in his contract, not the one on the new profile.</div></div>
  ${scoreBox()}<div class="small muted" style="margin-top:10px">Numbers come from the rules engine. The AI writes the sentence, and every number in it is checked against the pay record.</div></div>
  <div><b style="font-size:13px">Signals</b><div style="margin-top:6px">${sigBars({pay:.82,bank:.90,att:.40})}</div><b style="font-size:13px">Evidence</b><div style="margin-top:6px">${ev.map(([d,t,c])=>`<div class="ev"><i style="background:${c}"></i><div><div class="muted" style="font-size:11px">${d}</div>${t}</div></div>`).join('')}</div></div></div>
  <div class="df">${footer}</div></div>`;
}

/* ---------- scenarios ---------- */
const SC = {
payrun: {
  label:'Pay run', who:'Payroll admin',
  title:'Run September payroll with a Trust Check', sub:'A payroll admin runs the monthly pay run. PayShield checks every record before anything is locked.',
  init(){ S.d = { rows: ROWS(), scanned:0, done:false }; },
  steps:[
  { t:'Start the pay run', you:'Click <b>Continue to Trust Check</b>.', sys:'Waiting. Pay components are set for 219 employees.',
    screen:()=>app('Pay › Pay Run › <b>September 2026 · Monthly</b>', stepper(3).replace('st a','st a')+`
      <div class="card" style="padding:16px"><b style="font-size:15px">Components configured</b><p class="muted small" style="margin:4px 0 12px">September 2026 · Monthly · 219 employees · pay date 30 Sep</p>
      <div style="display:flex;gap:6px;flex-wrap:wrap;margin-bottom:16px">${['Basic salary','Overtime','Allowances','Bonus','CPF','SDL','SHG funds','No-pay leave'].map(c=>`<span class="chip">${c} ✓</span>`).join('')}</div>
      <div class="ai" style="margin-bottom:16px"><div class="h">NEW STEP</div>Before Review &amp; Confirm, PayShield now checks every record for pay anomalies, bank-change risk and attendance problems.</div>
      <div style="display:flex;justify-content:flex-end;gap:8px"><span class="btn">Back</span><button class="btn p pulse" data-act="next">Continue to Trust Check</button></div></div>`) },
  { t:'PayShield checks every record', you:'Watch the check run, then click <b>See results</b>.', sys:'Compares each person with their 6-month pay history, looks at bank changes in the last 30 days and the September timesheet, then combines the three signals into one score.',
    enter(){ addLog('Trust Check started for 219 records'); runScan(); },
    screen:()=>{ const n=S.d.scanned, done=n>=219; const f=Math.round(n/219*7);
      const lane=(name,detail,found,col)=>`<div class="card lane"><div class="row"><span>${name}</span><span class="muted small">${detail}</span></div><div class="bar"><i style="width:${n/219*100}%;background:${col}"></i></div><div class="small muted" style="margin-top:5px">${fmt(n)} / 219 checked · <b style="color:var(--ink)">${Math.round(found*n/219)}</b> flagged</div></div>`;
      return app('Pay › Pay Run › September 2026 › <b>Trust Check</b>', stepper(3)+`<div class="split"><div class="scan">
      ${lane('Pay variance','vs 6-month history, OT caps, CPF',5,'var(--accent)')}${lane('Bank-change risk','changes, devices, shared accounts',3,'var(--accent)')}${lane('Attendance integrity','punches, devices, OT proof',3,'var(--accent)')}</div>
      <div class="card" style="padding:18px;display:flex;flex-direction:column;gap:10px;justify-content:center;align-items:flex-start"><span class="muted small">Records needing attention</span><div class="big">${f}</div><span class="muted small">${done?'Check complete in 4.2 seconds. Some people trip more than one signal.':'Checking…'}</span>
      <button class="btn p ${done?'pulse':''}" data-act="next" ${done?'':'disabled'}>See results</button></div></div>`); } },
  { t:'Review the flags', you:'Click <b>Daniel Lim</b>, the held record, to see why.', sys:'Scored 219 records: 212 clear, 6 to review, 1 held. Only the 7 flagged records are listed.',
    enter(){ if(!S.d.loggedResults){ addLog('Trust Check done: 212 clear, 6 review, 1 held'); S.d.loggedResults=true; } },
    screen:()=>app('Pay › Pay Run › September 2026 › <b>Trust Check</b>', stepper(3)+stats()+table({pulse:0})) },
  { t:'See why Daniel is held', you:'Read the AI summary, then click <b>Keep held, send to approver</b>.', sys:'Shows the three signal scores and the evidence behind them. The combination bonus is what pushed Daniel below 50.',
    screen:()=>app('Pay › Pay Run › September 2026 › <b>Trust Check</b>', `<div style="opacity:.35;pointer-events:none">${stepper(3)}${stats()}</div>`+danielDrawer(`<span class="btn" data-act="back">Close</span><span class="btn">Accept with reason</span><button class="btn d pulse" data-act="hold">Keep held, send to approver</button>`)) },
  { t:'Fix an overtime error', you:'Open <b>Tan Wei Ming</b> and click <b>Apply suggested fix</b>.', sys:'Tan has 88 OT hours against a 72-hour cap, and 14 hours have no clock-out. PayShield suggests capping OT and sending the 14 hours to his manager.',
    screen:()=>{ const r=S.d.rows[2]; const fixed=r.st!=='review';
      return app('Pay › Pay Run › September 2026 › <b>Trust Check</b>', stats()+table({pulse:fixed?undefined:2, hl:2})+`
      <div class="card" style="margin-top:12px;padding:12px;display:flex;justify-content:space-between;align-items:center;gap:10px;flex-wrap:wrap;border-color:${fixed?'var(--good-line)':'var(--accent-line)'}">
      <div><b>Tan Wei Ming · suggested fix</b><div class="small muted">${fixed?'Done. OT capped at 72 h (S$9,840 → S$7,210). Manager asked to confirm 14 h.':'Cap OT at 72 h (net pay S$9,840 → S$7,210) and ask his manager to confirm the 14 h without clock-out.'}</div></div>
      ${fixed?'<span class="tag t-g">Fixed · score 88</span>':'<button class="btn p pulse" data-act="fixTan">Apply suggested fix</button>'}</div>`); } },
  { t:'Clear the other reviews', you:'Check each suggestion, then click <b>Apply all</b>.', sys:'Each suggestion comes from the rules engine. Accepting one needs a reason, which goes into the audit log.',
    screen:()=>{ const rest=S.d.rows.filter((r,i)=>i>0&&i!==2); const left=rest.some(r=>r.st==='review');
      return app('Pay › Pay Run › September 2026 › <b>Trust Check</b>', stats()+`<div class="card"><div style="padding:10px 12px;border-bottom:1px solid var(--line);display:flex;justify-content:space-between;align-items:center;gap:8px;flex-wrap:wrap"><b>Suggested actions for ${rest.length} records</b>${left?'<button class="btn p pulse" data-act="applyAll">Apply all</button>':'<span class="tag t-g">All resolved</span>'}</div>
      ${rest.map(r=>`<div class="resolve"><div class="who2" style="min-width:0"><b>${r.n} ${statusTag(r)}</b><span>${r.why}</span></div><div class="small" style="max-width:300px;color:${r.st==='review'?'var(--ink2)':'var(--good)'}">${r.st==='review'?'→ '+r.act:'✓ '+r.act}</div></div>`).join('')}</div>`); } },
  { t:'Lock the pay run', you:'Click <b>Lock pay run</b>.', sys:'Only Daniel waits. Lim Hui Ling is out of the run. Everyone else is paid on 30 Sep as usual.',
    screen:()=>{ const c=counts(); return app('Pay › Pay Run › September 2026 › <b>Review &amp; Confirm</b>', stepper(4)+stats()+`
      <div class="card" style="padding:16px;display:grid;gap:10px"><b style="font-size:15px">Ready to lock</b>
      <div class="small">✓ <b>${c.clear}</b> records will be paid on 30 Sep<br>⏸ <b>1</b> record held for approval (Daniel Lim) and left out of this run<br>– <b>1</b> record removed (Lim Hui Ling, already settled)</div>
      <div style="display:flex;justify-content:flex-end;gap:8px"><span class="btn" data-act="back">Back</span><button class="btn p pulse" data-act="lock">Lock pay run</button></div></div>`); } },
  { t:'Done', you:'Try the bank-change attack next to see what happens to Daniel.', sys:'Pay run locked. Every flag, fix and reason is saved for audit.',
    screen:()=>{ const c=counts(); return app('Pay › Pay Run › September 2026 › <b>Completed</b>', stepper(6)+`
      <div class="card ok"><div class="ico" style="background:var(--good-soft);color:var(--good)">✓</div><div><b style="font-size:16px">September pay run locked</b><p class="muted" style="margin:4px 0 10px">${c.clear} employees paid on time. 1 held. 0 reruns needed.</p>
      <div style="display:flex;gap:8px;flex-wrap:wrap"><button class="btn p pulse" data-act="go:bank">Next: the bank-change attack</button><button class="btn" data-act="restart">Replay</button></div></div></div>
      <div class="card" style="margin-top:12px;padding:12px"><b>What changed vs a normal pay run</b><div class="small muted" style="margin-top:6px">2 pay errors fixed before payslips went out (Tan's OT, Siti's CPF). 1 ex-employee removed. 1 likely fraud stopped. Without the check, these become reruns or a lost salary after payday.</div></div>`); } },
  ]
},
bank: {
  label:'Bank-change attack', who:'Attacker, employee, approver',
  title:'Stop a payroll diversion attack', sub:'An attacker has stolen Daniel’s password and tries to send his salary to their own account.',
  init(){ S.d = { calls:false, branch:null, scoreAnim:false }; },
  steps:[
  { t:'Sign-in from a new device', you:'You are the attacker. Click <b>Sign in</b>.', sys:'Records the device. It has never been used on this account, so the bank-risk signal goes up a little.',
    screen:()=>app('Employee portal › <b>Sign in</b>', `<div class="attacker" style="max-width:380px;margin:0 auto">Attacker · stolen password · new Windows laptop</div>
      <div class="card login"><b style="font-size:17px">Sign in to your HR portal</b><p class="muted small" style="margin:4px 0 14px">${/ pte ltd$/i.test(CO) ? CO : CO + ' Pte Ltd'}</p>
      <div class="field"><label>Email</label><div class="in">daniel.lim@example.sg</div></div><div class="field"><label>Password</label><div class="in">••••••••••</div></div>
      <button class="btn p pulse" style="width:100%" data-act="next">Sign in</button></div>`, 'My Profile', 'DL', 'Employee') },
  { t:'Bank account changed', you:'Click <b>Verify and save</b>.', sys:'Saves the change and starts a 3-day cooling-off, so the new account can’t be paid this payday. Sends an alert to Daniel’s old phone and email, which the attacker can’t switch off.',
    screen:()=>app('My Profile › <b>Bank details</b>', `<div class="attacker" style="margin-bottom:12px">Attacker is signed in as Daniel</div>
      <div class="split"><div class="card" style="padding:16px"><b>Change salary account</b>
      <div class="field" style="margin-top:12px"><label>Current account</label><div class="in">OCBC ···· 2209</div></div><div class="field"><label>New account</label><div class="in">DBS ···· 7731</div></div>
      <div class="field"><label>One-time code</label><div class="otp"><span>3</span><span>8</span><span>1</span><span>5</span><span>0</span><span>6</span></div><span class="small muted">The attacker got this code through a SIM swap.</span></div>
      <button class="btn p pulse" data-act="next">Verify and save</button></div>
      <div class="card" style="padding:16px;background:var(--warn-soft);border-color:var(--warn-line)"><b style="color:var(--warn)">What the attacker sees next</b><p class="small" style="margin:6px 0 0">“For your safety, salary goes to a new account after a <b>3-day check</b>. This month’s pay may still go to your old account.”</p></div></div>`, 'My Profile', 'DL', 'Employee') },
  { t:'Daniel’s real phone gets an alert', you:'Choose what Daniel does. Try <b>He doesn’t reply</b> first.', sys:'The alert goes to the contacts on file before the change. If Daniel taps “Not me”, the change is frozen at once.',
    enter(){ if(!S.d.alerted){ addLog('Bank change on Daniel Lim: cooling-off started, alert sent to old phone and email'); S.d.alerted=true; } },
    screen:()=>`<div class="phones">${phone('Notifications', `<div class="notif"><div class="small muted">HR APP · now</div><b>Your salary account was changed</b><div class="small">28 Sep, 11:14 pm, from a new Windows device. Not you? Freeze it now.</div></div>
      <div class="card" style="padding:12px"><b>Was this you?</b><p class="small muted" style="margin:4px 0 10px">We also sent this to your old email address.</p>
      <button class="btn d" style="width:100%;margin-bottom:6px" data-act="notme">Not me, freeze it</button><button class="btn" style="width:100%" disabled>Yes, it was me</button></div>`, 'Daniel’s own phone (the number on file before the change)')}
      <div class="card" style="padding:16px;max-width:300px;align-self:center"><b>Simulate Daniel</b><p class="small muted" style="margin:6px 0 12px">Most people don’t see a late-night alert in time. What if Daniel is asleep?</p><button class="btn p pulse" style="width:100%" data-act="noreply">He doesn’t reply</button></div></div>` },
  { t:'Payday: Trust Check', you:'Watch the score build, then click <b>Send to approver</b>.', sys:'Pay variance 0.82 + bank risk 0.90 + attendance 0.40, plus a bonus because two strong signals hit the same person. Trust Score 23: held.',
    enter(){ animateBars(); },
    screen:()=>app('Pay › Pay Run › September 2026 › <b>Trust Check</b>', `<div class="split"><div class="card" style="padding:16px"><b>Daniel Lim · signals</b><div style="margin-top:10px">${sigBars({pay:.82,bank:.90,att:.40}, true)}</div>
      <div class="small muted">0.40×0.82 + 0.35×0.90 + 0.25×0.40 = 0.743<br>+ 0.03 combination bonus = 0.773 risk</div></div>
      <div class="card" style="padding:16px;display:flex;flex-direction:column;align-items:flex-start;gap:8px;background:var(--bad-soft);border-color:var(--bad-line)"><span class="small muted">Trust Score</span><div class="big" style="color:var(--bad)" id="scoreNum">100</div><span class="tag t-r">Held, left out of this run</span>
      <p class="small" style="margin:4px 0">The new DBS account is still in cooling-off, so it can’t be paid anyway.</p><button class="btn p pulse" data-act="next">Send to approver</button></div></div>`) },
  { t:'Approver checks with Daniel', you:'Click <b>Call Daniel</b>, then <b>Reject change and pay old account</b>.', sys:'The approver uses the phone number from Daniel’s contract, not the one on the changed profile.',
    screen:()=>app('Admin Center › Approval Flow › <b>PayShield approvals</b>', `<div class="card" style="padding:16px;border-color:var(--bad-line)">
      <div style="display:flex;justify-content:space-between;gap:8px;flex-wrap:wrap"><div><b style="font-size:15px">Daniel Lim · September 2026</b><div class="small muted">Held by Varnika R. · Trust Score 23</div></div><span class="tag t-r">Held</span></div>
      <div style="display:flex;gap:6px;flex-wrap:wrap;margin:10px 0"><span class="chip">Net pay S$8,120 (+63%)</span><span class="chip">Bank changed 28 Sep, new device</span><span class="chip">No reply to alert</span><span class="chip">Resignation 30 Sep</span></div>
      ${S.d.calls?`<div class="ai" style="margin-bottom:10px"><div class="h">CALL NOTE · 1 OCT, 3:05 PM</div>Daniel: “I didn’t change my bank account. I got an email about updating my payroll profile last week.”</div>`:''}
      <div style="display:flex;gap:8px;flex-wrap:wrap;justify-content:flex-end">${S.d.calls?'<span class="btn" disabled>Called ✓</span>':'<button class="btn p pulse" data-act="call">Call Daniel (contract number)</button>'}<button class="btn d ${S.d.calls?'pulse':''}" data-act="reject" ${S.d.calls?'':'disabled'}>Reject change and pay old account</button></div></div>`, 'Approval Flow', 'KL', 'Approver') },
  { t:'Salary protected', you:'Try the attendance scenario next.', sys:'Every step is in the audit trail for IT, HR and any IRAS or MOM query.',
    screen:()=>{ const nm=S.d.branch==='notme';
      return app('Admin Center › Approval Flow › <b>Outcome</b>', `<div class="card ok"><div class="ico" style="background:var(--good-soft);color:var(--good)">✓</div><div><b style="font-size:16px">${nm?'Change frozen by Daniel within minutes':'S$8,120 paid to Daniel’s real account'}</b>
      <p class="muted" style="margin:4px 0 10px">${nm?'Daniel tapped “Not me”. The DBS account was blocked, HR was alerted, and payday is not affected.':'Paid off-cycle to OCBC ···· 2209. The DBS ···· 7731 change is rejected and blocked for all employees.'}</p>
      <div style="display:flex;gap:8px;flex-wrap:wrap"><button class="btn p pulse" data-act="go:network">Next: Fraud Network</button><button class="btn" data-act="restart">Replay</button></div></div></div>
      <div class="card" style="margin-top:12px;padding:12px"><b>Follow-up done automatically</b><div class="small muted" style="margin-top:6px">Password reset forced · all sessions signed out · IT security notified · a keyed fingerprint of the DBS account can now be shared with the PayShield Fraud Network.</div></div>`, 'Approval Flow', 'KL', 'Approver'); } },
  ]
},
network: {
  label:'Fraud Network', who:'Two companies, approvers',
  title:'Fraud Network: every company protects the others', sub:'' + CO + ' confirmed that DBS ···· 7731 was used in a fraud. A week later, the same account turns up at another customer on the platform.',
  init(){ S.d = { shared:false, matched:false, resolved:false }; },
  steps:[
  { t:'' + CO + ' confirms and reports', you:'As ' + CO + '’s approver, click <b>Share fingerprint</b>.', sys:'Only a keyed one-way fingerprint (HMAC) of the account number is shared, never the number itself. No company names or employee data are shared, and customers agree to this in their contract.',
    screen:()=>app('Admin Center › Approval Flow › <b>Fraud report</b>', `<div class="card ok" style="margin-bottom:12px"><div class="ico" style="background:var(--good-soft);color:var(--good)">✓</div><div><b style="font-size:15px">Bank change on Daniel Lim rejected</b><div class="small muted">Daniel confirmed by phone that he did not make it · DBS ···· 7731</div></div></div>
      <div class="card" style="padding:16px"><b style="font-size:15px">Report this account to the PayShield Fraud Network?</b><p class="small muted" style="margin:4px 0 12px">Other companies will be warned if anyone adds this account. They will not know it came from ${CO}.</p>
      <div class="ai"><div class="h">PRIVACY</div>Only a keyed one-way fingerprint (HMAC) of the account number is shared, never the number itself. No company names or employee data are shared, and customers agree to this in their contract.</div>
      <div style="display:flex;justify-content:space-between;align-items:center;gap:8px;flex-wrap:wrap;margin-top:12px"><span class="small muted">Covered by ${CO}’s service agreement.</span><button class="btn p pulse" data-act="share">Share fingerprint</button></div></div>`, 'Approval Flow', 'KL', 'Approver') },
  { t:'The network keeps only a fingerprint', you:'Click <b>Next</b>.', sys:'The network keeps only the fingerprint, never the account number, company name or employee details.',
    screen:()=>consoleApp('Security › <b>Fraud Network</b>', `<div style="display:flex;justify-content:space-between;align-items:center;gap:8px;flex-wrap:wrap;margin-bottom:12px"><div><b style="font-size:16px">Fraud Network</b><div class="small muted">Confirmed fraud accounts across all customers on the platform · fingerprints only</div></div><span class="tag t-b">3 active entries (sample)</span></div>
      <div class="card"><div class="tblwrap"><table class="g"><thead><tr><th>Fingerprint</th><th>Type</th><th>Confirmed</th><th class="num-r">Reports</th><th>Status</th></tr></thead><tbody>
      <tr class="hl"><td><code>9f3a…c21e</code> <span class="new">NEW</span></td><td>Payroll diversion</td><td>1 Oct 2026</td><td class="num-r">1</td><td><span class="tag t-g">Active</span></td></tr>
      <tr><td><code>41bd…07a9</code></td><td>Payroll diversion</td><td>12 Aug 2026</td><td class="num-r">2</td><td><span class="tag t-g">Active</span></td></tr>
      <tr><td><code>c8e0…5f13</code></td><td>Payroll diversion</td><td>3 Jul 2026</td><td class="num-r">1</td><td><span class="tag t-g">Active</span></td></tr></tbody></table></div></div>
      <div class="ai" style="margin-top:12px"><div class="h">PRIVACY</div>Only a keyed one-way fingerprint (HMAC) of the account number is shared, never the number itself. No company names or employee data are shared, and customers agree to this in their contract.</div>
      <div style="display:flex;justify-content:flex-end;margin-top:12px"><button class="btn p pulse" data-act="next">A week later at another company</button></div>`) },
  { t:'Same account at another company', you:'You are now Brightline’s payroll admin. Click <b>Check new bank details</b>.', sys:'Every new bank account is checked against the network the moment it is entered. A match blocks the change before any pay run starts.',
    screen:()=>{ const m=S.d.matched; return appCo('Brightline Logistics<br>Pte Ltd','B','EPM › Nur Aisyah › <b>Bank details</b>', `<div class="card" style="padding:16px"><div style="display:flex;justify-content:space-between;gap:8px;flex-wrap:wrap"><div><b style="font-size:15px">Bank change request · Nur Aisyah</b><div class="small muted">8 Oct, 1:42 am · new device · OTP entered</div></div><span class="tag ${m?'t-r':'t-o'}">${m?'Blocked':'Pending checks'}</span></div>
      <div class="split" style="margin-top:12px"><div class="field"><label>Current account</label><div class="in">POSB ···· 5512</div></div><div class="field"><label>New account</label><div class="in">DBS ···· 7731</div></div></div>
      ${m?`<div class="card" style="padding:12px;background:var(--bad-soft);border-color:var(--bad-line)"><b style="color:var(--bad)">⛔ Matches a confirmed fraud report in the PayShield Fraud Network</b><p class="small" style="margin:4px 0 0">The change is blocked. Nur has been alerted on her old phone and email. Salary stays with POSB ···· 5512.</p><p class="small muted" style="margin:4px 0 0">No company names are shared.</p></div>
      <div style="display:flex;justify-content:flex-end;margin-top:12px"><button class="btn p pulse" data-act="next">Send to approver</button></div>`
      :`<div style="display:flex;justify-content:flex-end"><button class="btn p pulse" data-act="match">Check new bank details</button></div>`}</div>`, 'EPM', 'BT', 'Payroll Admin'); } },
  { t:'Stopped on day one', you:'Click <b>Confirm with Nur and reject</b>.', sys:'The network did its job before payroll was even started. Brightline’s approver closes the case, and the entry now has two confirmed reports.',
    screen:()=>{ const r=S.d.resolved; return appCo('Brightline Logistics<br>Pte Ltd','B','Admin Center › Approval Flow › <b>PayShield approvals</b>', `<div class="card" style="padding:16px;border-color:${r?'var(--good-line)':'var(--bad-line)'}"><div style="display:flex;justify-content:space-between;gap:8px;flex-wrap:wrap"><div><b style="font-size:15px">Nur Aisyah · bank change</b><div class="small muted">Bank-change risk 1.00 · Fraud Network match</div></div><span class="tag ${r?'t-g':'t-r'}">${r?'Resolved':'Blocked'}</span></div>
      ${r?`<div class="card ok" style="margin-top:12px;background:var(--good-soft);border-color:var(--good-line)"><div class="ico" style="background:var(--surface);color:var(--good)">✓</div><div><b>Fraud stopped before payroll started</b><div class="small muted">Nur confirmed she made no change · password reset · fingerprint now has 2 confirmed reports</div></div></div>
      <div style="display:flex;gap:8px;flex-wrap:wrap;margin-top:12px"><button class="btn p pulse" data-act="go:attend">Next: attendance</button><button class="btn" data-act="restart">Replay</button></div>`
      :`<div class="ai" style="margin-top:12px"><div class="h">✨ AI SUMMARY</div>A bank account confirmed as fraud at another company on the platform was added to Nur’s profile at 1:42 am from a new device. Call Nur on the number in her contract before doing anything else.</div>
      <div style="display:flex;justify-content:flex-end;margin-top:12px"><button class="btn d pulse" data-act="resolveNet">Confirm with Nur and reject</button></div>`}</div>
      <div class="card" style="margin-top:12px;padding:14px"><b>Without the Fraud Network</b><div class="small muted" style="margin-top:4px">Brightline would only see a routine bank change. The same attacker could take a salary from every company one at a time.</div></div>`, 'Approval Flow', 'AN', 'Approver'); } },
  ]
},
attend: {
  label:'Attendance', who:'Site worker, payroll admin',
  title:'Fix attendance before it becomes a pay error', sub:'Mohd Faizal works at Tuas Site A. PayShield checks clock-ins and fixes missing punches before payroll cutoff.',
  init(){ S.d = { loc:false, selfie:false, clocked:false, blocked:false, fixed:false }; },
  steps:[
  { t:'Clock in on site', you:'Click <b>Check location</b>, then <b>Take selfie</b>, then <b>Clock in</b>.', sys:'Checks that the phone is inside the site geofence, then runs a liveness check. Only the result is kept, not the photo.',
    screen:()=>{ const d=S.d;
      const btn = !d.loc ? '<button class="btn p pulse" style="width:100%" data-act="loc">Check location</button>' : !d.selfie ? '<button class="btn p pulse" style="width:100%" data-act="selfie">Take selfie</button>' : !d.clocked ? '<button class="btn p pulse" style="width:100%" data-act="clock">Clock in · 7:58 am</button>' : '<button class="btn p pulse" style="width:100%" data-act="next">Continue</button>';
      return `<div class="phones">${phone('Clock in', `<div class="map"><svg viewBox="0 0 240 170" width="100%" height="170" aria-hidden="true"><path d="M0 46H240M0 122H240M70 0V170M178 0V170" stroke="var(--line)" stroke-width="10" fill="none"/><circle cx="120" cy="84" r="52" fill="var(--accent)" fill-opacity=".12" stroke="var(--accent)" stroke-dasharray="4 3"/>${d.loc?'<circle cx="114" cy="90" r="7" fill="var(--accent)" stroke="var(--surface)" stroke-width="2"/>':''}</svg>
        <div style="position:absolute;left:8px;bottom:8px">${d.loc?'<span class="tag t-g">✓ Inside Tuas Site A</span>':'<span class="tag t-n">Location not checked</span>'}</div></div>
        <div class="card" style="padding:10px;display:flex;gap:10px;align-items:center"><div class="av" style="width:38px;height:38px">MF</div><div><b>${d.selfie?'Selfie check passed':'Selfie check'}</b><div class="small muted">${d.selfie?'Liveness ✓ · photo not stored':'Needed after location'}</div></div></div>
        ${d.clocked?'<div class="tag t-g" style="justify-content:center;padding:8px">✓ Clocked in at 7:58 am</div>':''}${btn}`, 'Mohd Faizal’s own phone')}</div>`; } },
  { t:'A buddy-punch attempt', you:'Ravi forgot his phone. Faizal tries to clock him in. Click <b>Clock in Ravi</b>.', sys:'This phone is registered to Faizal. A second person can’t clock in on it without a supervisor, and the attempt is logged on both records.',
    screen:()=>{ const b=S.d.blocked;
      return `<div class="phones">${phone('Clock in', `<div class="card" style="padding:10px"><div class="small muted">Signed in as</div><b>Ravi Kumar</b><div class="small muted">on Mohd Faizal’s phone</div></div>
      ${b?`<div class="card" style="padding:12px;background:var(--bad-soft);border-color:var(--bad-line)"><b style="color:var(--bad)">Clock-in blocked</b><p class="small" style="margin:4px 0 0">This phone is registered to Mohd Faizal. Ravi needs his own phone, or a supervisor can clock him in at the site kiosk.</p></div>
      <button class="btn p pulse" style="width:100%" data-act="next">Continue</button>`:`<button class="btn p pulse" style="width:100%" data-act="buddy">Clock in Ravi · 8:01 am</button>`}`, 'Same phone, different person')}</div>`; } },
  { t:'Fix a missed clock-out', you:'Click <b>Use 6:05 pm</b>.', sys:'Before payroll cutoff, PayShield spots a shift with no clock-out and suggests Faizal’s usual time. His manager approves the change.',
    screen:()=>{ const f=S.d.fixed;
      return `<div class="phones">${phone('My timesheet', `<div class="ai"><div class="h">✨ BEFORE PAYROLL CUTOFF</div><b>You didn’t clock out on Tue, 15 Sep</b><div class="small" style="margin-top:3px">You usually leave at <b>6:05 pm</b>. Use that time?</div>
      ${f?'<div class="tag t-g" style="margin-top:8px">✓ Sent to your manager</div>':'<div style="display:flex;gap:6px;margin-top:8px"><button class="btn p pulse" style="flex:1" data-act="usual">Use 6:05 pm</button><button class="btn" style="flex:1">Edit time</button></div>'}</div>
      <div class="card" style="padding:10px"><div class="small muted">Payroll cutoff</div><b>Fri, 25 Sep, 6:00 pm</b></div>
      <div class="card" style="padding:10px;font-size:12.5px"><div style="display:flex;justify-content:space-between"><span>Missing punches</span><b style="color:${f?'var(--good)':'var(--warn)'}">${f?0:1}</b></div><div style="display:flex;justify-content:space-between"><span>OT hours (approved)</span><b>12.5</b></div></div>
      ${f?'<button class="btn p pulse" style="width:100%" data-act="next">See the payroll view</button>':''}`, 'Faizal, three days before cutoff')}</div>`; } },
  { t:'Payroll sees a clean record', you:'Compare before and after. Then replay or pick another scenario.', sys:'The missing punch is fixed, so Faizal’s attendance signal drops and his record is clear. The blocked buddy punch stays in the log but doesn’t affect his pay.',
    screen:()=>app('Pay › Pay Run › September 2026 › <b>Trust Check</b>', `<div class="split">
      <div class="card" style="padding:14px"><span class="tag t-n">Without the fix</span><div style="display:flex;justify-content:space-between;align-items:center;margin-top:10px"><div class="who2"><b>Mohd Faizal</b><span>E-1311 · Warehouse</span></div><span class="tag t-o">70 · Review</span></div><p class="small muted" style="margin:8px 0 0">Missing clock-out on 15 Sep · OT can’t be confirmed · admin must chase the manager after cutoff</p></div>
      <div class="card" style="padding:14px;border-color:var(--good-line)"><span class="tag t-g">With PayShield</span><div style="display:flex;justify-content:space-between;align-items:center;margin-top:10px"><div class="who2"><b>Mohd Faizal</b><span>E-1311 · Warehouse</span></div><span class="tag t-g">91 · Clear</span></div><p class="small muted" style="margin:8px 0 0">Missing punch fixed by Faizal, approved by manager · 1 blocked buddy-punch attempt logged · no pay impact</p></div></div>
      <div class="card" style="margin-top:12px;padding:14px"><b>Across the whole site this month</b><div class="small muted" style="margin-top:6px">Missing punches at cutoff dropped from 23 to 4 (sample). Each one fixed before cutoff saves HR a follow-up and avoids an OT error in the pay run.</div>
      <div style="display:flex;gap:8px;margin-top:12px;flex-wrap:wrap"><button class="btn p pulse" data-act="go:rules">Next: rule updates</button><button class="btn" data-act="restart">Replay</button></div></div>`) },
  ]
},
rules: {
  label:'Rule updates', who:'Compliance owner, payroll admin',
  title:'Apply a new CPF rule safely', sub:'Replay of the 1 Jan 2026 CPF wage ceiling change. AI finds and drafts the update; a person verifies it before any company uses it.',
  init(){ S.d = { chk:{val:false,date:false,src:false}, published:false, fixed:false, whatif:false }; },
  steps:[
  { t:'AI spots an official update', you:'Click <b>Open draft</b>.', sys:'Rule Watch checks official MOM, CPF Board and IRAS pages on a schedule. It found a change and drafted it. Nothing is applied yet.',
    screen:()=>consoleApp('Rule Watch › <b>Inbox</b>', `<div style="display:flex;justify-content:space-between;align-items:center;gap:8px;flex-wrap:wrap;margin-bottom:12px"><div><b style="font-size:16px">Rule Watch inbox</b><div class="small muted">Updates found on official sources · nothing goes live without a reviewer</div></div><span class="tag t-o">1 needs review</span></div>
      <div class="card">${[
        ['CPF Board','CPF Ordinary Wage ceiling rises from S$7,400 to S$8,000','Effective 1 Jan 2026','review'],
        ['CPF Board','Contribution rates for workers aged 55 to 70 updated','Effective 1 Jan 2026','pub'],
        ['IRAS','Form IR21 explanatory notes updated','No rule change','pub'],
        ['MOM','Workplace Fairness Act: grievance process duties','Expected end 2027','watch']].map(([src,t,d,s],i)=>`<div class="resolve"><div class="who2" style="min-width:0"><b>${t}</b><span>${src} · ${d}</span></div>
        <div style="display:flex;gap:8px;align-items:center">${s==='review'?'<span class="tag t-o">AI draft · needs review</span><button class="btn p pulse" data-act="next">Open draft</button>':s==='pub'?'<span class="tag t-g">Published</span>':'<span class="tag t-n">Watching</span>'}</div></div>`).join('')}</div>`) },
  { t:'A person verifies the draft', you:'Tick all three checks, then click <b>Approve and publish</b>.', sys:'The AI draft sits next to the official source. The publish button stays locked until the compliance owner confirms the value, the date and the source.',
    screen:()=>{ const c=S.d.chk, all=c.val&&c.date&&c.src;
      const box=(k,label,detail)=>`<button class="resolve ${c[k]?'':'pulse'}" style="width:100%;border:0;background:${c[k]?'var(--good-soft)':'var(--surface)'};text-align:left" data-act="chk:${k}"><div><b>${c[k]?'☑':'☐'} ${label}</b><div class="small muted">${detail}</div></div>${c[k]?'<span class="tag t-g">Checked</span>':''}</button>`;
      return consoleApp('Rule Watch › <b>Review draft</b>', `<div class="split">
      <div class="card" style="padding:14px"><div class="ai" style="margin-bottom:10px"><div class="h">✨ AI DRAFT</div>Rule <b>CPF_OW_CEILING</b><br>Old value: S$7,400 → <b>New value: S$8,000</b> per month<br>Effective: <b>1 Jan 2026</b><br>Applies to: Singapore Citizens and PRs, all ages</div>
      <div class="small muted">Found on cpf.gov.sg (employer contribution page). AI confidence: high. Still needs a person.</div></div>
      <div class="card" style="padding:14px"><b>Official source (summary)</b><p class="small" style="margin:6px 0 0">CPF Board: from 1 January 2026, the Ordinary Wage ceiling is S$8,000 a month. CPF contributions are payable on Ordinary Wages up to this amount.</p></div></div>
      <div class="card" style="margin-top:12px;overflow:hidden"><div style="padding:10px 12px;border-bottom:1px solid var(--line)"><b>Reviewer checklist</b> <span class="small muted">· Priya N., Compliance owner</span></div>
      ${box('val','Value matches the source','S$8,000 a month')}${box('date','Effective date matches','1 Jan 2026')}${box('src','Source is official','cpf.gov.sg')}
      <div style="padding:10px 12px;display:flex;justify-content:space-between;align-items:center;gap:8px;flex-wrap:wrap;background:var(--surface2)"><span class="small muted">The AI cannot publish. Only a named reviewer can.</span><div style="display:flex;gap:8px"><span class="btn">Send back to AI</span><button class="btn p ${all?'pulse':''}" data-act="publish" ${all?'':'disabled'}>Approve and publish</button></div></div></div>`); } },
  { t:'Rule saved with a version', you:'Click <b>Next</b> to see what a company sees.', sys:'Old and new versions both stay. Each pay period uses the rule in force on its dates, so a December 2025 rerun still uses S$7,400.',
    screen:()=>consoleApp('Rule Watch › <b>Rule library</b>', `<div class="card ok" style="margin-bottom:12px"><div class="ico" style="background:var(--good-soft);color:var(--good)">✓</div><div><b style="font-size:15px">CPF_OW_CEILING v2026.1 published</b><div class="small muted">Approved by Priya N. · all 3 checks confirmed · companies notified</div></div></div>
      <div class="card"><div class="tblwrap"><table class="g"><thead><tr><th>Rule</th><th>Version</th><th class="num-r">Value</th><th>In force</th><th>Source</th><th>Status</th></tr></thead><tbody>
      <tr class="hl"><td><b>CPF_OW_CEILING</b></td><td>v2026.1</td><td class="num-r"><b>S$8,000</b></td><td>from 1 Jan 2026</td><td>cpf.gov.sg</td><td><span class="tag t-g">Published</span></td></tr>
      <tr><td>CPF_OW_CEILING</td><td>v2025.1</td><td class="num-r">S$7,400</td><td>1 Jan 2025 – 31 Dec 2025</td><td>cpf.gov.sg</td><td><span class="tag t-n">Past</span></td></tr>
      <tr><td>MOM_OT_MONTHLY_CAP</td><td>v2024.1</td><td class="num-r">72 h</td><td>current</td><td>mom.gov.sg</td><td><span class="tag t-g">Published</span></td></tr>
      <tr><td>MOM_OT_MIN_RATE</td><td>v2024.1</td><td class="num-r">1.5×</td><td>current</td><td>mom.gov.sg</td><td><span class="tag t-g">Published</span></td></tr></tbody></table></div></div>
      <div style="display:flex;justify-content:flex-end;margin-top:12px"><button class="btn p pulse" data-act="next">See the company view</button></div>`) },
  { t:'Company runs a what-if', you:'Click <b>Run what-if</b>, read the impact, then click <b>Review fix</b>.', sys:'Reruns ' + CO + '’s November 2025 payroll in a sandbox with the new rule. Nothing is saved; it only shows the difference, six weeks before the rule starts.',
    screen:()=>{ const w=S.d.whatif;
      const groups=[['Engineering',21,2050],['Operations',18,1690],['Finance & HR',7,470]], mx=2050;
      return app('Global Settings › <b>Compliance updates</b>', `<div style="margin-bottom:12px"><b style="font-size:16px">Compliance updates <span class="new">NEW</span></b><div class="small muted">Verified rule changes that affect ${CO}</div></div>
      <div class="card" style="padding:14px;border-color:var(--accent-line)"><div style="display:flex;justify-content:space-between;gap:8px;flex-wrap:wrap"><div><b style="font-size:14.5px">CPF Ordinary Wage ceiling: S$8,000 from 1 Jan 2026</b><div class="small muted">Verified by the compliance team · source cpf.gov.sg</div></div><span class="tag t-b">Starts in 6 weeks</span></div>
      ${!w ? `<div class="ai" style="margin-top:12px;display:flex;justify-content:space-between;align-items:center;gap:10px;flex-wrap:wrap"><div><div class="h">WHAT-IF</div>See what this rule would do to your payroll before it starts. Uses your last pay run; nothing is changed.</div><button class="btn p pulse" data-act="whatif">Run what-if on November 2025 payroll</button></div>`
      : `<div class="stats" style="margin:12px 0"><div class="card stat"><div class="l">Employees affected</div><div class="v">46</div><div class="s">earn above S$7,400 a month</div></div><div class="card stat"><div class="l">Employer CPF</div><div class="v" style="color:var(--warn)">+S$4,210</div><div class="s">per month</div></div><div class="card stat"><div class="l">Yearly effect</div><div class="v">+S$50,520</div><div class="s">employer cost, 12 months</div></div><div class="card stat"><div class="l">Employee take-home</div><div class="v">−S$4,950</div><div class="s">per month in total; it goes into their CPF</div></div></div>
      <div class="tblwrap"><table class="g" style="min-width:520px"><thead><tr><th>Pay group</th><th class="num-r">People affected</th><th>Extra employer CPF per month</th></tr></thead><tbody>
      ${groups.map(([g,n,v])=>`<tr><td><b>${g}</b></td><td class="num-r">${n}</td><td><div style="display:flex;gap:8px;align-items:center"><div style="height:10px;width:${v/mx*220}px;background:var(--accent);border-radius:4px"></div><span class="num-r">S$${fmt(v)}</span></div></td></tr>`).join('')}
      <tr><td><b>Total</b></td><td class="num-r"><b>46</b></td><td><b>S$4,210</b></td></tr></tbody></table></div>
      <div class="resolve" style="margin-top:12px;background:var(--warn-soft);border-radius:10px;border:1px solid var(--warn-line)"><div class="who2"><b>Config Doctor: custom CPF scheme “Legacy” still uses S$7,400</b><span>Used by pay group Operations (41 employees)</span></div><button class="btn p pulse" data-act="next">Review fix</button></div>`}</div>`, 'Dashboard'); } },
  { t:'Admin confirms the fix', you:'Check the change, then click <b>Apply from 1 Jan 2026</b>.', sys:'The change is scheduled for its effective date. Pay runs before January are not touched.',
    screen:()=>{ const f=S.d.fixed; return app('Global Settings › CPF Setup › <b>Custom scheme “Legacy”</b>', `<div class="card" style="padding:16px"><b style="font-size:15px">Suggested change</b>
      <div class="tblwrap" style="margin-top:10px"><table class="g"><thead><tr><th>Setting</th><th class="num-r">Now</th><th class="num-r">From 1 Jan 2026</th></tr></thead><tbody><tr class="hl"><td>Ordinary Wage ceiling</td><td class="num-r">S$7,400</td><td class="num-r"><b>S$8,000</b></td></tr><tr><td>Rule version</td><td class="num-r">v2025.1</td><td class="num-r">v2026.1</td></tr></tbody></table></div>
      ${f?'<div class="card ok" style="margin-top:12px;background:var(--good-soft);border-color:var(--good-line)"><div class="ico" style="background:var(--surface);color:var(--good)">✓</div><div><b>Scheduled for 1 Jan 2026</b><div class="small muted">Applied by Varnika R. · December payroll still uses S$7,400</div></div></div><div style="display:flex;justify-content:flex-end;margin-top:12px"><button class="btn p pulse" data-act="next">See January pay run</button></div>'
      :'<div style="display:flex;justify-content:flex-end;gap:8px;margin-top:12px"><span class="btn">Cancel</span><button class="btn p pulse" data-act="applyRule">Apply from 1 Jan 2026</button></div>'}</div>`, 'Dashboard'); } },
  { t:'Pay run uses the right rule', you:'Done. Pick another scenario or replay.', sys:'Every pay run records which rule versions it used, for audits and IRAS or MOM queries.',
    screen:()=>app('Pay › Pay Run › <b>January 2026 · Monthly</b>', stepper(3)+`<div class="rulever">Rules used: <b>CPF v2026.1</b> · MOM OT v2024.1 · all verified by the compliance team</div>
      <div class="split"><div class="card" style="padding:14px;border-color:var(--good-line)"><span class="tag t-g">January 2026 run</span><p style="margin:8px 0 0"><b>0 CPF flags.</b> All 46 affected employees use the S$8,000 ceiling.</p></div>
      <div class="card" style="padding:14px"><span class="tag t-n">December 2025 rerun</span><p style="margin:8px 0 0">Uses <b>CPF v2025.1</b> (S$7,400), because that rule was in force for December.</p></div></div>
      <div class="card" style="margin-top:12px;padding:14px"><b>Without Rule Watch</b><div class="small muted" style="margin-top:4px">A developer updates the rule in code, every company finds out on their own, and a missed setting shows up as short CPF after payday.</div>
      <div style="display:flex;gap:8px;margin-top:12px;flex-wrap:wrap"><button class="btn p" data-act="go:payrun">Back to the pay run scenario</button><button class="btn" data-act="restart">Replay</button></div></div>`) },
  ]
}
};
Object.assign(SC, extraScenarios({ app, consoleApp, fmt, S }), extra2Scenarios({ app, consoleApp, fmt, S, render }), extra3Scenarios({ app, consoleApp, fmt, S }), extra4Scenarios({ app, S, stepper }), extra5Scenarios({ app, S, render }));
const TAB_ORDER = ['preflight', 'payrun', 'compare', 'bank', 'attend', 'rules', 'validators', 'agent', 'network', 'learn', 'ask', 'model', 'proof', 'csv'];
const MENU = [];
setScenarioMenu(() => ({ active: S.sc, groups: [] }));
/* ---------- PayShield product: pages, menu, state ---------- */
const PAGES = buildPages({ S, company: CO });
// Which menu item is lit while a step-by-step demo runs.
const SC_MODULE = { preflight:'home', payrun:'home', compare:'proof', bank:'bank', network:'bank', attend:'time', rules:'compliance', validators:'validators', agent:'agent', ask:'agent', learn:'proof', model:'pay', proof:'proof', csv:'proof' };
const PAGE_LABEL = { home:'Trust Check', people:GUARDS.people.name, time:GUARDS.time.name, bank:GUARDS.bank.name, pay:GUARDS.pay.name, compliance:GUARDS.compliance.name, proof:'Proof', agent:'PayShield Agent', records:'Pay run records' };
S.mode = 'page'; S.page = 'home'; S.issues = ISSUES(); S.approved = false; initAgentState(S);
PAGES.agent = { crumb: 'PayShield › <b>PayShield Agent</b>', body: () => agentBody(S) };
PAGES.records = { crumb: 'PayShield › <b>Pay run records</b>', body: () => recordsBody(S) };
const TI = intelligence({ S, render: () => render() }); Object.assign(PAGES, TI.pages); Object.assign(PAGE_LABEL, TI.labels); S.policy = Object.fromEntries(POLICIES.map((p) => [p.id, p.on]));
const gCount = (k) => pendingIn(S.issues, k).length, gHeld = (k) => pendingIn(S.issues, k).some((i) => i.status === 'held');
const MENU_ITEMS = () => [
  { label: 'PayShield', items: [
    { k:'home', label:'Trust Check', icon:'gauge', act:'page:home', count: pendingIn(S.issues).length, held: pendingIn(S.issues).some((i) => i.status === 'held') },
    { k:'agent', label:'PayShield Agent', icon:'bot', act:'page:agent', tag:'<span class="new">AI</span>' } ] },
  { label: 'Guards', items: Object.entries(GUARDS).map(([k, g]) => ({ k, label: ({ people:'Employment', time:'Attendance' })[k] || g.name, icon: g.icon, act: 'page:' + k, ...(GUARD_SWITCH.off[k] ? { tag: '<span class="tag t-n ps-offtag">Off</span>' } : { count: gCount(k), held: gHeld(k) }) })) },
  { label: 'Audit', items: [ { k:'records', label:'Pay run records', icon:'receipt', act:'page:records' }, { k:'proof', label:'Proof & test run', icon:'flask', act:'page:proof' }, { k:'validators', label:'Rules & parameters', icon:'settings', act:'go:validators' } ] },
  ...TI.menu(),
];
setPsMenu(() => ({ company: CO, pending: pendingIn(S.issues).length, active: S.mode === 'page' ? S.page : SC_MODULE[S.sc], groups: MENU_ITEMS() }));
function logGuard(k, action, o){
  const t = new Date().toLocaleTimeString('en-SG', { hour: '2-digit', minute: '2-digit' });
  S.records.unshift({ id: 'GS-' + String(S.records.filter((r) => r.kind === 'config').length + 1).padStart(3, '0'), kind: 'config', period: RUN.name, by: 'Varnika R.', guard: GUARDS[k].name, action, reason: o.reason, scope: o.scope, approver: action === 'off' ? o.approver : null, at: t });
}
function turnOff(d, approver){
  const before = payScore(S.issues).score;
  const info = { by: 'Varnika R.', reason: d.reason, scope: d.scope, approver, at: new Date().toLocaleTimeString('en-SG', { hour: '2-digit', minute: '2-digit' }) };
  setGuardOff(d.key, info); logGuard(d.key, 'off', info); S.offDraft = null;
  S.toast = { html: `<b>${GUARDS[d.key].name} turned off</b> for ${d.scope === 'run' ? RUN.name : 'all runs until turned on'}${approver ? `, approved by ${approver}` : ''}. Its checks are skipped; Pay Score ${before} → <b>${payScore(S.issues).score}</b>` };
  render();
}
function rescored(before, what, warn){ const p = payScore(S.issues), left = pendingIn(S.issues).length;
  S.toast = { warn: !!warn, html: `<b>${what}.</b> Trust Check re-scored: Pay Score ${before} → <b>${p.score}</b>${left ? ` · ${left} alert${left > 1 ? 's' : ''} left` : ' · ready to approve'}` }; render(); }
function openPage(k, keepFocus){ clearTimer(); if (!keepFocus) S.focus = null; if (k === 'home') S.toast = null; S.mode = 'page'; S.page = k; render();
  const el = S.focus && document.getElementById('iss-' + S.focus);
  if (el) el.scrollIntoView({ block: 'center', behavior: reduce ? 'auto' : 'smooth' }); else window.scrollTo?.({ top: 0 }); }
function runTrustCheck(){
  S.tc = { running: true, stage: 0 }; render();
  const tick = () => { S.tc.stage++; if (S.tc.stage >= 5) { S.tc = { running: false, at: new Date().toLocaleTimeString('en-SG', { hour: '2-digit', minute: '2-digit' }) }; } if (S.mode === 'page' && S.page === 'home') render(); if (S.tc.running) setTimeout(tick, reduce ? 0 : 450); };
  setTimeout(tick, reduce ? 0 : 450);
}
function renderPage(){
  const p = PAGES[S.page];
  document.querySelector('.grid').classList.add('noguide');
  $('#tabs').innerHTML = `<div class="hdr-hint"><label class="hint-narrow">Go to <select id="pgSel">${MENU_ITEMS().flatMap((g) => g.items).map((it) => `<option value="${it.act}" ${it.act === 'page:' + S.page ? 'selected' : ''}>${it.label}</option>`).join('')}</select></label></div>`;
  $('#guide').innerHTML = '';
  $('#stage').innerHTML = `<div class="stagebar ps-bar"><div class="sb-step"><span class="tag t-b">Product view</span><b>${PAGE_LABEL[S.page]}</b><span class="sb-who">· click around freely; ▶ buttons run a step-by-step story</span></div>
    <div class="sb-ctl"><button class="btn sm" data-act="resetRun">Reset demo data</button></div></div>` + psShell(p.crumb, p.body()) + (S.toast && S.page !== 'home' ? `<div class="ps-toast ${S.toast.warn ? 'warn' : ''}" role="status"><span>${S.toast.html}</span><button class="btn sm p" data-act="page:home">Back to Trust Check</button><button class="linkbtn" data-act="toastClose" aria-label="Close">✕</button></div>` : '');
}
function appCo(co, letter, crumb, body, active, user, role){ return tenantApp(co.replace('<br>', ' ').toLowerCase(), letter, crumb, body, active, user, role); }
function consoleApp(crumb, body){ return consoleShell(crumb, body); }

/* ---------- engine ---------- */
let logClock = 0;
S.logTime = () => { const base = {payrun:[9,30],bank:[23,9],network:[9,0],attend:[7,57],rules:[10,0],compare:[9,30],learn:[9,40],proof:[14,0],ask:[10,15],csv:[11,0],model:[15,0],preflight:[9,0],validators:[9,5],agent:[9,10]}[S.sc]; const m = base[1] + logClock++ ; return String(base[0] + Math.floor(m/60)).padStart(2,'0') + ':' + String(m%60).padStart(2,'0'); };

function start(sc){
  if (S.mode === 'page') S.returnTo = S.page; S.mode = 'demo';
  clearTimer(); S.sc = sc; S.step = 0; S.done = new Set(); S.log = []; logClock = 0;
  SC[sc].init(); addLog({payrun:'September pay run opened by Varnika R.',bank:'Sign-in attempt on Daniel Lim’s account',network:'' + CO + ' rejected the bank change on Daniel Lim’s account',attend:'Faizal opens the HR app at Tuas Site A',rules:'Rule Watch found an update on cpf.gov.sg and drafted it',compare:'Same September run, two endings',learn:'October pay run opened by Varnika R.',proof:'Test company generated: 500 employees, 12 months of pay',ask:'Ask PayShield opened on Daniel Lim (held)',csv:'File check opened',model:'Model lab opened: PayShield Risk Model v1',preflight:'September pay run opened: Sales & Operations, 5 employees',validators:'Payroll Validators opened',agent:'PayShield Agent opened'}[sc]);
  go(0);
}
function go(i){
  clearTimer();
  const sc = SC[S.sc];
  if (i < 0 || i >= sc.steps.length) return;
  if (i > S.step) for (let k = S.step; k < i; k++) S.done.add(k);
  S.step = i;
  if (i === sc.steps.length - 1) (DEMO_RESOLVES[S.sc] || []).forEach((id) => { const x = S.issues.find((y) => y.id === id); if (x && x.state === 'open') x.state = 'fixed'; });
  const st = sc.steps[i];
  if (st.enter) st.enter();
  render();
}
function render(){
  if (S.mode === 'page') return renderPage();
  const sc = SC[S.sc], st = sc.steps[S.step];
  const idx = TAB_ORDER.indexOf(S.sc);
  const narrowPick = `<label class="hint-narrow">Scenario <select id="scSel">${TAB_ORDER.map((k) => `<option value="${k}" ${k === S.sc ? 'selected' : ''}>${SC[k].label}</option>`).join('')}</select></label>`;
  $('#tabs').innerHTML = `<div class="hdr-hint">${narrowPick}</div>`;
  document.querySelector('.grid').classList.toggle('noguide', !!S.guideHidden);
  $('#guide').innerHTML = `<div class="g-head"><div class="eyebrow">Demo story · ${PAGE_LABEL[SC_MODULE[S.sc]] || ({preflight:'Pre-flight check',agent:'PayShield Agent',model:'Our own model',learn:'Learns from you',validators:'Validators'})[SC_MODULE[S.sc]] || 'PayShield'}</div><h2>${sc.title}</h2><p class="sub">${sc.sub}</p></div>
  <ol class="steps">${sc.steps.map((s,i)=>`<li class="${i===S.step?'on':''} ${S.done.has(i)&&i!==S.step?'done':''}"><button data-act="jump:${i}" ${i>S.step&&!S.done.has(i)&&i!==S.step+1?'disabled':''}><span class="num">${S.done.has(i)&&i!==S.step?'✓':i+1}</span>${s.t}</button></li>`).join('')}</ol>
  <div class="now2"><div class="lbl">Your next action</div><div class="do">${st.you}</div><div class="bts"><b>Behind the scenes:</b> ${st.sys}</div></div>
  <div class="g-foot"><button class="linkbtn" data-act="restart">↺ Restart this scenario</button></div>
  <details class="log" ${S.logOpen ? 'open' : ''}><summary>Activity log <span class="cnt2">${S.log.length}</span></summary><ul>${S.log.map(l=>`<li class="${l.fresh?'new':''}"><time>${l.t}</time><span>${l.text}</span></li>`).join('')}</ul></details>`;
  S.log.forEach(l => l.fresh = false);
  let scr = st.screen();
  // Screens shown on an employee's phone or a sign-in page get the app shell too, so the PayShield menu is always there.
  if (!scr.includes('class="app2')) scr = tenantApp(CO.toLowerCase(), COMPANY.letter, `Employee view › <b>${st.t}</b>`,
    `<div class="preview-note"><span class="tag t-n">Preview</span> What <b>${viewer()}</b> sees</div>${scr}`, S.sc === 'attend' ? 'Time & attendance' : 'Home', S.sc === 'attend' ? 'MF' : 'DL');
  $('#stage').innerHTML = `<div class="stagebar"><div class="sb-step"><span class="tag t-b">Step ${S.step+1} of ${sc.steps.length}</span><b>${st.t}</b><span class="sb-who">· ${viewer()}</span></div>
    <div class="sb-ctl"><button class="btn sm" data-act="exitDemo">← ${PAGE_LABEL[S.returnTo] || 'Pay run readiness'}</button><button class="btn sm" data-act="guide" aria-pressed="${!S.guideHidden}">${S.guideHidden ? 'Show guide' : 'Hide guide'}</button><button class="btn sm" data-act="back" ${S.step===0?'disabled':''} aria-label="Previous step">← Back</button><button class="btn sm p" data-act="next" ${nextBlocked()?'disabled':''}>Next →</button></div></div>` + scr;
}
function viewer(){
  const map = { validators:'Payroll admin', agent:'Payroll admin', preflight:['Payroll admin','Payroll admin','Payroll admin','Approver','Approver'][S.step], model:'PayShield product team', ask:['Payroll admin (web)','Compliance owner (vendor console)','Payroll admin (web)'][S.step], csv:'Payroll admin (web)', compare:'Payroll admin (web)', learn:'Payroll admin (web)', proof:'PayShield product team', payrun:'Payroll admin (web)', bank:['Attacker on Daniel’s account','Attacker on Daniel’s account','Daniel’s phone','Payroll admin','Approver','Approver'][S.step], attend:['Mohd Faizal (mobile app)','Mohd Faizal’s phone','Mohd Faizal (mobile app)','Payroll admin'][S.step], network:['' + CO + ' approver','vendor console','Brightline payroll admin','Brightline approver'][S.step], rules:['Compliance owner (vendor console)','Compliance owner (vendor console)','Compliance owner (vendor console)','' + CO + ' payroll admin','' + CO + ' payroll admin','' + CO + ' payroll admin'][S.step] };
  return map[S.sc];
}
function nextBlocked(){
  const xb = extraNextBlocked(S); if (xb !== null) return xb;
  const xb2 = extra2NextBlocked(S); if (xb2 !== null) return xb2;
  const xb3 = extra3NextBlocked(S); if (xb3 !== null) return xb3;
  const xb4 = extra4NextBlocked(S); if (xb4 !== null) return xb4;
  const xb5 = extra5NextBlocked(S); if (xb5 !== null) return xb5;
  const d = S.d, s = S.step;
  if (S.sc==='payrun') return (s===1 && d.scanned<219) || (s===4 && d.rows[2].st==='review') || (s===5 && d.rows.some(r=>r.st==='review')) || s===7;
  if (S.sc==='bank') return (s===2 && !d.branch) || (s===4 && !d.done) || s===5;
  if (S.sc==='attend') return (s===0 && !d.clocked) || (s===1 && !d.blocked) || (s===2 && !d.fixed) || s===3;
  if (S.sc==='rules') return (s===1 && !d.published) || (s===3 && !d.whatif) || (s===4 && !d.fixed) || s===5;
  if (S.sc==='network') return (s===0 && !d.shared) || (s===2 && !d.matched) || s===3;
  return false;
}
function runScan(){
  S.d.scanned = 0;
  if (reduce){ S.d.scanned = 219; return; }
  timer = setInterval(() => { S.d.scanned = Math.min(219, S.d.scanned + 9); render(); if (S.d.scanned >= 219) clearTimer(); }, 70);
}
function animateBars(){
  requestAnimationFrame(() => requestAnimationFrame(() => {
    document.querySelectorAll('.bar i[data-w]').forEach(b => b.style.width = b.dataset.w + '%');
    const el = document.getElementById('scoreNum'); if (!el) return;
    if (reduce){ el.textContent = '23'; return; }
    let v = 100; const id = setInterval(() => { v -= 3; if (v <= 23){ v = 23; clearInterval(id); } if (el.isConnected) el.textContent = v; }, 30);
  }));
}

/* ---------- actions ---------- */
const ACT = {
  next(){ go(S.step + 1); },
  page(k){ openPage(k); },
  goIssue(id){ const i = S.issues.find((x) => x.id === id); if (!i) return; S.focus = id; openPage(i.guard, true); },
  guardToggle(k){
    if (GUARD_SWITCH.off[k]) { const o = GUARD_SWITCH.off[k]; setGuardOff(k, null); logGuard(k, 'on', o); const p = payScore(S.issues); S.toast = { html: `<b>${GUARDS[k].name} is back on.</b> Its checks run again; Trust Check re-scored: Pay Score ${p.score}` }; render(); return; }
    S.offDraft = { key: k, reason: '', scope: 'run', stage: 'form' }; render();
  },
  guardOffReason(r){ if (S.offDraft) { S.offDraft.reason = decodeURIComponent(r); render(); } },
  guardOffScope(sc){ if (S.offDraft) { S.offDraft.scope = sc; render(); } },
  guardOffCancel(){ S.offDraft = null; render(); },
  guardOffConfirm(){ const d = S.offDraft; if (!d || !d.reason) return; if (HIGH_RISK_GUARDS.includes(d.key) && d.stage !== 'approval') { d.stage = 'approval'; render(); return; } turnOff(d, null); },
  guardOffApprove(){ const d = S.offDraft; if (d) turnOff(d, 'Grace Lim'); },
  tcRun(){ if (!S.tc || !S.tc.running) runTrustCheck(); },
  exitDemo(){ openPage(S.returnTo || 'home'); },
  fix(id){ const i = S.issues.find((x) => x.id === id); if (!i) return; const b = payScore(S.issues).score; i.state = 'fixed'; rescored(b, isRemoval(i) ? `⚠ ${i.name} removed from this pay run` : i.name + ' fixed', isRemoval(i)); },
  alt(id){ const i = S.issues.find((x) => x.id === id); if (!i) return; const b = payScore(S.issues).score; i.state = 'accepted'; rescored(b, i.name + ' accepted with reason'); },
  undo(id){ const i = S.issues.find((x) => x.id === id); if (!i) return; i.state = 'open'; render(); },
  fixAll(g){ const b = payScore(S.issues).score, n = pendingIn(S.issues, g).length; pendingIn(S.issues, g).forEach((i) => { i.state = 'fixed'; }); rescored(b, `${n} fixes applied`); },
  toastClose(){ S.toast = null; render(); },
  approveRun(){ if (pendingIn(S.issues).length) return; S.approved = true; render(); },
  agHome(n){ openPage('agent'); AA.send(n === 'run' ? RUN_PROMPT : ['Why is Daniel held?', 'How do I prorate a new joiner?', 'Is CPF due on share awards?'][+n]); },
  resetRun(){ S.issues = ISSUES(); S.approved = false; S.agentPaid = null; resetGuards(); S.offDraft = null; initAgentState(S); S.policy = Object.fromEntries(POLICIES.map((p) => [p.id, p.on])); render(); },
  back(){ go(S.step - 1); }, restart(){ start(S.sc); },
  open(i){
    i = +i;
    if (S.sc!=='payrun') return;
    if (S.step===2 && i===0) go(3);
    else if (S.step===4 && i===2) ACT.fixTan();
  },
  hold(){ const r=S.d.rows[0]; r.done='Held, sent to approver with note'; addLog('Daniel Lim kept on hold and sent to approver'); go(4); },
  fixTan(){ const r=S.d.rows[2]; if(r.st!=='review') return; r.st='fixed'; r.sep=r.after.sep; r.sc=r.after.sc; r.done='OT capped at 72 h; 14 h sent to manager'; addLog('Tan Wei Ming: OT capped at 72 h (S$9,840 → S$7,210)'); render(); },
  applyAll(){
    const rest = S.d.rows.filter((r,i)=>i>0&&i!==2&&r.st==='review');
    const step = () => { const r = rest.shift(); if(!r){ render(); return; } r.st = r.res; if(r.after){ r.sep=r.after.sep; r.sc=r.after.sc; } r.done = r.act; addLog(`${r.n}: ${r.act}`); render(); if(rest.length) setTimeout(step, reduce?0:260); };
    step();
  },
  lock(){ addLog('September pay run locked: 217 paid, 1 held, 1 removed'); go(7); },
  notme(){ S.d.branch='notme'; addLog('Daniel tapped “Not me”: change frozen, HR alerted'); S.done.add(2); S.done.add(3); S.done.add(4); S.d.done=true; go(5); },
  noreply(){ S.d.branch='noreply'; addLog('No reply from Daniel by payday'); addLog('Trust Check: Daniel Lim scored 23, held'); go(3); },
  call(){ S.d.calls=true; addLog('Approver called Daniel on his contract number: change not made by him'); render(); },
  reject(){ S.d.done=true; addLog('Bank change rejected; S$8,120 paid to OCBC ···· 2209 off-cycle'); addLog('Password reset forced; IT security notified'); go(5); },
  loc(){ S.d.loc=true; addLog('Location check: inside Tuas Site A geofence'); render(); },
  selfie(){ S.d.selfie=true; addLog('Liveness check passed (photo not stored)'); render(); },
  clock(){ S.d.clocked=true; addLog('Mohd Faizal clocked in at 7:58 am'); render(); },
  buddy(){ S.d.blocked=true; addLog('Blocked: Ravi Kumar clock-in on Mohd Faizal’s phone'); render(); },
  usual(){ S.d.fixed=true; addLog('Faizal set 15 Sep clock-out to 6:05 pm; sent to manager'); addLog('Manager approved the corrected time'); render(); },
  side(){ toggleSide(); render(); },
  guide(){ S.guideHidden = !S.guideHidden; render(); },
  chk(k){ S.d.chk[k]=!S.d.chk[k]; render(); },
  publish(){ const c=S.d.chk; if(!(c.val&&c.date&&c.src)) return; S.d.published=true; addLog('Priya N. verified value, date and source'); addLog('CPF_OW_CEILING v2026.1 published; companies notified'); go(2); },
  whatif(){ S.d.whatif=true; addLog('What-if run on November 2025 payroll: 46 people, +S$4,210 a month'); render(); },
  share(){ S.d.shared=true; addLog('' + CO + ' shared a keyed fingerprint of DBS ···· 7731 (confirmed fraud)'); go(1); },
  match(){ S.d.matched=true; addLog('Brightline: DBS ···· 7731 matched the Fraud Network; change blocked'); addLog('Nur Aisyah alerted on her old phone and email'); render(); },
  resolveNet(){ S.d.resolved=true; addLog('Brightline: Nur confirmed she made no change; change rejected'); render(); },
  applyRule(){ S.d.fixed=true; addLog('' + CO + ': CPF scheme “Legacy” set to S$8,000 from 1 Jan 2026'); render(); },
  jump(i){ i=+i; if (i<=S.step || S.done.has(i) || i===S.step+1 && !nextBlocked()) go(i); },
  go(k){ start(k); },
};
const AA = agentActions({ S, render: () => render(), reduce });
Object.assign(ACT, AA, extraActions({ S, render, go, addLog }), extra2Actions({ S, render, go, addLog }), extra3Actions({ S, render, go, addLog }), extra4Actions({ S, render, go, addLog, reduce }), extra5Actions({ S, render, go, addLog }));
Object.assign(ACT, TI.actions);
document.addEventListener('change', e => {
  if (e.target && e.target.id === 'scSel') start(e.target.value);
  if (e.target && e.target.id === 'pgSel') { const [a, k] = e.target.value.split(':'); ACT[a](k); }
  if (e.target && e.target.matches && e.target.matches('[data-agconfirm]')) { AA.agConfirm(e.target.checked); return; }
  if (e.target && e.target.dataset && e.target.dataset.pol) { S.policy[e.target.dataset.pol] = e.target.checked; render(); }
});
document.addEventListener('toggle', e => { if (e.target && e.target.matches && e.target.matches('details.log')) S.logOpen = e.target.open; }, true);
document.addEventListener('click', e => {
  const el = e.target.closest('[data-act]'); if (!el || el.disabled) return;
  const [a, arg] = el.dataset.act.split(':'); if (ACT[a]) ACT[a](arg);
});
document.addEventListener('input', e => { if (e.target && e.target.id === 'agQ') AA.agQ(e.target.value); });
document.addEventListener('keydown', e => {
  if (e.key === 'Enter' && e.target && e.target.id === 'agQ') { AA.send(e.target.value); return; }
  if (e.key === 'Enter' && e.target.matches('tr[data-act]')) { e.target.click(); return; }
  if (e.target.closest('input,textarea')) return;
  if (S.mode === 'page') return;
  if (e.key === 'ArrowRight' && !nextBlocked()) go(S.step + 1);
  if (e.key === 'ArrowLeft') go(S.step - 1);
});
S.guideHidden = true;
openPage('home');
