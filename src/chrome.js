/* PayShield demo shell: an original, generic enterprise-SaaS layout.
   Dark navy sidebar with workspace switcher, white top bar with breadcrumb,
   command search and user menu, page header. Plus Jakarta Sans, teal accent.
   Icons are generic Lucide-style outlines (ISC licence). */

const L = (paths, w = 1.75) => `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="${w}" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">${paths}</svg>`;
export const ICON = {
  bot: L('<path d="M12 8V4H8"/><rect width="16" height="12" x="4" y="8" rx="2"/><path d="M2 14h2"/><path d="M20 14h2"/><path d="M15 13v2"/><path d="M9 13v2"/>'),
  flask: L('<path d="M9 3h6"/><path d="M10 3v6L5 18a2 2 0 0 0 1.7 3h10.6A2 2 0 0 0 19 18l-5-9V3"/><path d="M7.5 14h9"/>'),
  spark: L('<path d="M12 3l1.9 5.8L20 11l-6.1 2.2L12 19l-1.9-5.8L4 11l6.1-2.2z"/>'),
  rocket: L('<path d="M4.5 16.5c-1.5 1.26-2 5-2 5s3.74-.5 5-2c.71-.84.7-2.13-.09-2.91a2.18 2.18 0 0 0-2.91-.09z"/><path d="m12 15-3-3a22 22 0 0 1 2-3.95A12.88 12.88 0 0 1 22 2c0 2.72-.78 7.5-6 11a22.35 22.35 0 0 1-4 2z"/><path d="M9 12H4s.55-3.03 2-4c1.62-1.08 5 0 5 0"/><path d="M12 15v5s3.03-.55 4-2c1.08-1.62 0-5 0-5"/>'),
  home: L('<path d="M15 21v-8a1 1 0 0 0-1-1h-4a1 1 0 0 0-1 1v8"/><path d="M3 10a2 2 0 0 1 .709-1.528l7-5.999a2 2 0 0 1 2.582 0l7 5.999A2 2 0 0 1 21 10v9a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z"/>'),
  users: L('<path d="M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2"/><circle cx="9" cy="7" r="4"/><path d="M22 21v-2a4 4 0 0 0-3-3.87"/><path d="M16 3.13a4 4 0 0 1 0 7.75"/>'),
  wallet: L('<path d="M19 7V4a1 1 0 0 0-1-1H5a2 2 0 0 0 0 4h15a1 1 0 0 1 1 1v4h-3a2 2 0 0 0 0 4h3a1 1 0 0 0 1-1v-2a1 1 0 0 0-1-1"/><path d="M3 5v14a2 2 0 0 0 2 2h15a1 1 0 0 0 1-1v-4"/>'),
  clock: L('<circle cx="12" cy="12" r="10"/><path d="M12 6v6l4 2"/>'),
  calendar: L('<path d="M8 2v4"/><path d="M16 2v4"/><rect width="18" height="18" x="3" y="4" rx="2"/><path d="M3 10h18"/>'),
  receipt: L('<path d="M4 2v20l2-1 2 1 2-1 2 1 2-1 2 1 2-1 2 1V2l-2 1-2-1-2 1-2-1-2 1-2-1-2 1Z"/><path d="M16 8h-6a2 2 0 1 0 0 4h4a2 2 0 1 1 0 4H8"/><path d="M12 17.5v-11"/>'),
  shield: L('<path d="M20 13c0 5-3.5 7.5-7.66 8.95a1 1 0 0 1-.67-.01C7.5 20.5 4 18 4 13V6a1 1 0 0 1 1-1c2 0 4.5-1.2 6.24-2.72a1.17 1.17 0 0 1 1.52 0C14.51 3.81 17 5 19 5a1 1 0 0 1 1 1z"/><path d="m9 12 2 2 4-4"/>'),
  check2: L('<path d="M21.801 10A10 10 0 1 1 17 3.335"/><path d="m9 11 3 3L22 4"/>'),
  chart: L('<path d="M3 3v16a2 2 0 0 0 2 2h16"/><path d="M18 17V9"/><path d="M13 17V5"/><path d="M8 17v-3"/>'),
  settings: L('<path d="M12.22 2h-.44a2 2 0 0 0-2 2v.18a2 2 0 0 1-1 1.73l-.43.25a2 2 0 0 1-2 0l-.15-.08a2 2 0 0 0-2.73.73l-.22.38a2 2 0 0 0 .73 2.73l.15.1a2 2 0 0 1 1 1.72v.51a2 2 0 0 1-1 1.74l-.15.09a2 2 0 0 0-.73 2.73l.22.38a2 2 0 0 0 2.73.73l.15-.08a2 2 0 0 1 2 0l.43.25a2 2 0 0 1 1 1.73V20a2 2 0 0 0 2 2h.44a2 2 0 0 0 2-2v-.18a2 2 0 0 1 1-1.73l.43-.25a2 2 0 0 1 2 0l.15.08a2 2 0 0 0 2.73-.73l.22-.39a2 2 0 0 0-.73-2.73l-.15-.08a2 2 0 0 1-1-1.74v-.5a2 2 0 0 1 1-1.74l.15-.09a2 2 0 0 0 .73-2.73l-.22-.38a2 2 0 0 0-2.73-.73l-.15.08a2 2 0 0 1-2 0l-.43-.25a2 2 0 0 1-1-1.73V4a2 2 0 0 0-2-2z"/><circle cx="12" cy="12" r="3"/>'),
  search: L('<circle cx="11" cy="11" r="8"/><path d="m21 21-4.3-4.3"/>'),
  bell: L('<path d="M10.268 21a2 2 0 0 0 3.464 0"/><path d="M3.262 15.326A1 1 0 0 0 4 17h16a1 1 0 0 0 .74-1.673C19.41 13.956 18 12.499 18 8A6 6 0 0 0 6 8c0 4.499-1.411 5.956-2.738 7.326"/>'),
  help: L('<circle cx="12" cy="12" r="10"/><path d="M9.09 9a3 3 0 0 1 5.83 1c0 2-3 3-3 3"/><path d="M12 17h.01"/>'),
  updown: L('<path d="m7 15 5 5 5-5"/><path d="m7 9 5-5 5 5"/>'),
  panel: L('<rect width="18" height="18" x="3" y="3" rx="2"/><path d="M9 3v18"/>'),
  chevD: L('<path d="m6 9 6 6 6-6"/>'),
  circleCheck: L('<circle cx="12" cy="12" r="10"/><path d="m9 12 2 2 4-4"/>'),
  alert: L('<path d="m21.73 18-8-14a2 2 0 0 0-3.48 0l-8 14A2 2 0 0 0 4 21h16a2 2 0 0 0 1.73-3"/><path d="M12 9v4"/><path d="M12 17h.01"/>'),
  pause: L('<circle cx="12" cy="12" r="10"/><path d="M10 15V9"/><path d="M14 15V9"/>'),
  gauge: L('<path d="m12 14 4-4"/><path d="M3.34 19a10 10 0 1 1 17.32 0"/>'),
  library: L('<path d="m16 6 4 14"/><path d="M12 6v14"/><path d="M8 8v12"/><path d="M4 4v16"/>'),
  network: L('<rect x="16" y="16" width="6" height="6" rx="1"/><rect x="2" y="16" width="6" height="6" rx="1"/><rect x="9" y="2" width="6" height="6" rx="1"/><path d="M5 16v-3a1 1 0 0 1 1-1h12a1 1 0 0 1 1 1v3"/><path d="M12 12V8"/>'),
  building: L('<path d="M6 22V4a2 2 0 0 1 2-2h8a2 2 0 0 1 2 2v18Z"/><path d="M6 12H4a2 2 0 0 0-2 2v6a2 2 0 0 0 2 2h2"/><path d="M18 9h2a2 2 0 0 1 2 2v9a2 2 0 0 1-2 2h-2"/><path d="M10 6h4"/><path d="M10 10h4"/><path d="M10 14h4"/><path d="M10 18h4"/>'),
  radar: L('<path d="M19.07 4.93A10 10 0 0 0 6.99 3.34"/><path d="M4 6h.01"/><path d="M2.29 9.62A10 10 0 1 0 21.31 8.35"/><path d="M16.24 7.76A6 6 0 1 0 8.23 16.67"/><path d="M12 18h.01"/><path d="M17.99 11.66A6 6 0 0 1 15.77 16.67"/><circle cx="12" cy="12" r="2"/><path d="m13.41 10.59 5.66-5.66"/>'),
};

/** PayShield mark: original logo (teal tile, white shield, check). */
export const MARK = (size = 32) => `<svg width="${size}" height="${size}" viewBox="0 0 32 32" aria-hidden="true"><defs><linearGradient id="psg" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#2b8ff0"/><stop offset="1" stop-color="#0b4f8a"/></linearGradient></defs><rect width="32" height="32" rx="9" fill="url(#psg)"/><path d="M16 6.5 8.5 9.3v5.4c0 4.6 3.1 8.6 7.5 9.8 4.4-1.2 7.5-5.2 7.5-9.8V9.3z" fill="#fff"/><path d="m12.4 15.6 2.5 2.5 4.8-5" fill="none" stroke="#ff6b5b" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round"/></svg>`;
export const logo = 'data:image/svg+xml;utf8,' + encodeURIComponent(MARK(32).replace('<svg ', '<svg xmlns="http://www.w3.org/2000/svg" '));

const PEOPLE = {
  VR: ['Varnika Raghav', 'Payroll Admin'], KL: ['Kevin Lim', 'Approver'], AN: ['Aisha Noor', 'Approver'],
  BT: ['Ben Tan', 'Payroll Admin'], DL: ['Daniel Lim', 'Employee'], PN: ['Priya Nair', 'Compliance Owner'], MF: ['Mohd Faizal', 'Site worker'],
};

let sideOpen = true;
let menuFn = null;
/** main.js registers the scenario list; the side menu shows it under PayShield. */
export function setScenarioMenu(fn) { menuFn = fn; }
const subBtn = (k, l, active, extra = '') =>
  `<button type="button" class="nv-sub ${k === active ? 'on' : ''}" data-act="go:${k}" ${k === active ? 'aria-current="page"' : ''}>${extra || '<span class="nv-dot"></span>'}<span>${l}</span></button>`;
/** Pay alerts: what an approver (HOD) must review before the pay run. Red dot while anything is pending. */
function alertsMenu() {
  if (!menuFn) return '';
  const { alerts, active } = menuFn();
  if (!alerts) return '';
  const pending = alerts.items.filter((x) => x.pending).length;
  const head = `<div title="Pay alerts" class="nv nv-parent open nv-alerts"><span class="nv-ic nv-ic-dot">${ICON.bell}${pending ? '<i class="red-dot" aria-hidden="true"></i>' : ''}</span><span class="nv-tx">Pay alerts</span>${pending ? `<span class="cnt cnt-red" aria-label="${pending} to review">${pending}</span>` : '<span class="cnt cnt-ok">✓</span>'}<span class="nv-chev">${ICON.chevD}</span></div>`;
  const items = alerts.items.map((x) => `<button type="button" class="nv-sub nv-alert ${x.k === active ? 'on' : ''} ${x.pending ? 'pending' : 'done'}" data-act="go:${x.k}" ${x.k === active ? 'aria-current="page"' : ''} title="${x.pending ? 'To review: ' + x.note : 'Reviewed'}">${x.pending ? '<span class="red-dot sm" aria-hidden="true"></span>' : '<span class="nv-ok" aria-hidden="true">✓</span>'}<span class="nv-al-tx">${x.label}${x.pending ? '' : '<span class="sr"> (reviewed)</span>'}</span><span class="nv-note">${x.pending ? x.note : 'Done'}</span></button>`).join('');
  return head + `<div class="nv-subwrap" role="group" aria-label="Pay alerts to review"><div class="nv-subgrp">Review before pay run</div>${items}</div>`;
}
export function pendingAlerts() { return psFn ? psFn().pending : 0; }
function scenarioMenu() {
  if (!menuFn) return '';
  const { groups, active } = menuFn();
  return `<div class="nv-subwrap" role="group" aria-label="PayShield scenarios">${groups.map((g) => `<div class="nv-subgrp">${g.label}</div>${g.items.map(([k, l]) => subBtn(k, l, active)).join('')}`).join('')}</div>`;
}
const parentItem = (label, icon, badge = '') =>
  `<div title="${label}" class="nv nv-parent open"><span class="nv-ic">${icon}</span><span class="nv-tx">${label}</span>${badge}<span class="nv-chev">${ICON.chevD}</span></div>`;
export function toggleSide() { sideOpen = !sideOpen; }

const navItem = (label, icon, active, badge = '') =>
  `<div title="${label}" class="nv ${active ? 'on' : ''}"><span class="nv-ic">${icon}</span><span class="nv-tx">${label}</span>${badge}</div>`;
const navGroup = (label) => `<div class="nv-grp">${label}</div>`;

function crumbs(crumb) {
  const parts = crumb.split('›').map((p) => p.trim());
  return parts.map((p, i) => (i === parts.length - 1 ? `<span class="bc-now">${p.replace(/<\/?b>/g, '')}</span>` : `<span>${p}</span>`)).join('<span class="bc-sep">/</span>');
}
function pageHead(crumb) {
  const m = crumb.match(/<b>(.*?)<\/b>/);
  return `<div class="pghead"><h2>${m ? m[1] : crumb}</h2></div>`;
}

function shell({ ws, wsLetter, wsSub, nav, crumb, body, user, role, dark, brand, bell = true, agent = true }) {
  const [name, r] = PEOPLE[user] || [user, role];
  return `<div class="app2 ${sideOpen ? '' : 'collapsed'}">
  <nav class="sb2 ${dark || ''}" aria-label="Main menu">
    ${brand || ''}<div class="ws"><span class="ws-av">${wsLetter}</span><span class="ws-tx"><b>${ws}</b><small>${wsSub}</small></span><span class="ws-ud">${ICON.updown}</span></div>
    <div class="nv-list">${nav}</div>
    <div class="sb2-foot"><span class="sb2-mark">${MARK(22)}</span><span class="nv-tx">${brand ? 'PayShield v1 · sample data' : 'PayShield demo'}</span></div>
  </nav>
  <div class="main2">
    <header class="tb">
      <button class="tb-btn" data-act="side" aria-label="Toggle menu">${ICON.panel}</button>
      <nav class="bc" aria-label="Breadcrumb">${crumbs(crumb)}</nav>
      <div class="tb-search">${ICON.search}<span>Search people, pay runs…</span><kbd>⌘K</kbd></div>
      ${agent ? `<button type="button" class="tb-agent" data-act="page:agent">${ICON.bot}<span>Ask PayShield Agent</span></button>` : ''}
      ${bell ? `<button type="button" class="tb-btn tb-bell" data-act="page:home" aria-label="${pendingAlerts() ? pendingAlerts() + ' pay alerts to review' : 'No pay alerts'}" title="${pendingAlerts() ? pendingAlerts() + ' pay alerts to review' : 'All pay alerts reviewed'}">${ICON.bell}${pendingAlerts() ? '<i></i>' : ''}</button>` : ''}
      <span class="tb-user"><span class="tb-av">${user}</span><span class="tb-who"><b>${name}</b><small>${role || r}</small></span>${ICON.chevD}</span>
    </header>
    <div class="body">${pageHead(crumb)}${body}</div>
  </div></div>`;
}

const ACTIVE_MAP = { 'Pay Run': 'Payroll', 'Payroll Utility': 'Payroll', 'Generate Payslip': 'Payroll', Pay: 'Payroll', EPM: 'People', Dashboard: 'Home', 'Approval Flow': 'Approvals' };

/** Customer (tenant) app. */
export function tenantApp(company, letter, crumb, body, active = 'Pay Run', user = 'VR', role) {
  const a = ACTIVE_MAP[active] || active;
  const ws = company.replace(/\b\w/g, (c) => c.toUpperCase()).replace(/ Pte Ltd$/i, '');
  const nav = `${navGroup('Workspace')}${navItem('Home', ICON.home, a === 'Home')}${navItem('People', ICON.users, a === 'People')}${navItem('Payroll', ICON.wallet, a === 'Payroll')}
  ${navItem('Time & attendance', ICON.clock, a === 'Time & attendance')}
  ${navGroup('Self-service')}${navItem('My Profile', ICON.users, a === 'My Profile')}${navItem('Payslips', ICON.receipt, a === 'Payslips')}
`;
  return shell({ ws: ws + ' HR', wsLetter: letter, wsSub: 'Employee self-service', nav, crumb, body, user, role, bell: false, agent: false });
}

/** Vendor compliance console. */
export function consoleShell(crumb, body) {
  const on = (x) => crumb.includes(x) || (x === 'Rule Watch' && crumb.includes('Inbox'));
  const nav = `${navGroup('Compliance')}${navItem('Rule Watch', ICON.radar, on('Rule Watch'), '<span class="cnt">1</span>')}${navItem('Rule library', ICON.library, on('Rule library'))}
  ${navGroup('Security')}${navItem('Fraud Network', ICON.network, on('Fraud Network'))}`;
  return shell({ bell: false, agent: false, ws: 'Vendor console', wsLetter: 'V', wsSub: 'Compliance & security', nav, crumb, body, user: 'PN', role: 'Compliance Owner', dark: 'console' });
}

/** KPI card: label, big value, note, icon tile on the right. */
export function statCard(icon, label, value, note, tone = '') {
  return `<div class="card kpi ${tone}"><div class="kpi-top"><span class="l">${label}</span><span class="kpi-ic">${icon}</span></div><div class="v">${value}</div><div class="s">${note}</div></div>`;
}

/* ---------- PayShield product shell (its own app, not a menu inside the HRMS) ---------- */
let psFn = null;
/** main.js registers { active, pending, company, groups:[{label, items:[{k, label, icon, act, count, held}]}] }. */
export function setPsMenu(fn) { psFn = fn; }
const psItem = (it, active) => {
  const on = it.k === active;
  const badge = it.count ? `<span class="cnt ${it.held ? 'cnt-red' : 'cnt-amb'}" aria-label="${it.count} to review">${it.count}</span>` : (it.count === 0 ? '<span class="ps-ok" aria-label="all clear">✓</span>' : (it.tag || ''));
  return `<button type="button" class="nv ps-nv ${on ? 'on' : ''}" data-act="${it.act}" ${on ? 'aria-current="page"' : ''}><span class="nv-ic nv-ic-dot">${ICON[it.icon] || ICON.shield}${it.count ? '<i class="red-dot" aria-hidden="true"></i>' : ''}</span><span class="nv-tx">${it.label}</span>${badge}</button>`;
};
export function psShell(crumb, body, user = 'VR', role) {
  const m = psFn();
  const nav = m.groups.map((g) => `${navGroup(g.label)}${g.items.map((it) => psItem(it, m.active)).join('')}`).join('');
  const brand = `<div class="ps-brand">${MARK(30)}<div><b>PayShield</b><small>Pay run assurance</small></div></div>`;
  return shell({ ws: m.company, wsLetter: m.company.trim()[0].toUpperCase(), wsSub: 'Singapore · 219 people', nav, crumb, body, user, role, brand });
}
