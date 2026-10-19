// PayShield's own trainable risk model.
// A small logistic-regression model trained on de-identified payroll features and admin decisions.
// Why this design: it runs inside our own system (no data leaves), every score can be explained
// feature by feature, its 15 weights can be audited, and it trains in seconds on a laptop.
// Governance: the model can only ADD a Review flag. It never clears a rule flag, never holds pay, never changes pay.

import { scoreRecord, robustZ, deviationToSignal } from './scoring.js';
import { rng, generateCompany, addLegitEvents, plant, toRecord, PLANTED, CATEGORY, RUN_TO_PAYDAY } from './backtest.js';

/* ---------- 1. Feature allow-list: the ONLY inputs the model ever sees ---------- */
// No employee id, name, NRIC/FIN, bank number, gender, age, race, religion or nationality, by design.
export const FEATURES = [
  ['pay_unusual', 'Pay unusual for this person (vs own 6 months)'],
  ['reason_recorded', 'A reason was recorded for the change'],
  ['raise_vs_peers', 'Raise compared with peers in the same grade'],
  ['growth_steps', 'Small unexplained pay steps over 10 months'],
  ['unexplained_growth', 'Pay growth over 10 months not covered by approved increments'],
  ['offcycle_raise', 'Raise outside the company’s increment cycle'],
  ['approver_offcycle', 'Same approver signed several off-cycle raises this month'],
  ['bank_recent', 'Bank account changed in the last 30 days'],
  ['bank_new_device', 'Bank change from a new device'],
  ['bank_unconfirmed', 'Bank change not confirmed on a second channel'],
  ['shared_account', 'Account shared with another employee'],
  ['ot_proof_gap', 'Share of OT with no clock proof'],
  ['missing_punches', 'Days with a missing clock-out'],
  ['cpf_mismatch', 'CPF calculation check failed'],
  ['paid_after_exit', 'Paid after last working day'],
];
export const PROTECTED = ['name', 'nric', 'fin', 'gender', 'sex', 'age', 'dob', 'race', 'religion', 'nationality', 'marital', 'employee_id', 'bank_account'];

/* ---------- 2. Synthetic companies, now with salary-increase patterns ---------- */
export const INCREMENT_PLANTED = [
  { type: 'SALARY_CREEP', n: 3, label: 'Salary creep: +2% every 2 months, never approved' },
  { type: 'RAISE_ABOVE_PEERS', n: 3, label: 'Off-cycle raise of 18–26%, far above peers, signed by one approver' },
];
export const ALL_PLANTED = [...PLANTED, ...INCREMENT_PLANTED];
const CAT = { ...CATEGORY, SALARY_CREEP: 'Salary increase', RAISE_ABOVE_PEERS: 'Salary increase' };

const M = 11; // the month being checked; increments happen in April (month 5)
const clamp = (v, lo, hi) => Math.max(lo, Math.min(hi, v));
const median = (xs) => { const s = [...xs].sort((a, b) => a - b), m = s.length >> 1; return s.length ? (s.length % 2 ? s[m] : (s[m - 1] + s[m]) / 2) : 0; };
const gradeOf = (e) => Math.max(0, Math.floor(Math.log(e.base / 1800) / Math.log(1.4)));

/** One synthetic company with 31 hidden problems (25 from the test run + 6 salary-increase patterns). */
/** `variant` makes the patterns harder than in training, to test how well the model generalises. */
export const STANDARD = { creepStep: 0.02, raiseMin: 0.18, raiseSpan: 0.08, rogueSigns: 3 };
export const HARDER = { creepStep: 0.015, raiseMin: 0.12, raiseSpan: 0.06, rogueSigns: 2 };
export function buildCompany(seed, employees = 500, variant = STANDARD) {
  const { employees: emps, r } = generateCompany({ employees, seed });
  addLegitEvents(emps, r, M);
  for (const e of emps) {
    e.grade = gradeOf(e);
    e.approver = 'APR-' + (1 + Math.floor(r() * 25));
    e.raiseApprovedBy = e.knownReasons.length ? e.approver : null; // recorded promotions are signed by the person's own manager
  }
  // honest counter-examples: approved off-cycle market adjustments of 5–9%
  for (const e of emps) if (!e.shift && e.joined === 0 && !e.legit.length && r() < 0.01) {
    const mult = 1.05 + r() * 0.04; e.pay[M] = Math.round(e.pay[M] * mult); e.knownReasons = ['INCREMENT']; e.raiseApprovedBy = e.approver; e.legit.push('APPROVED_ADJUSTMENT');
  }
  const pool = emps.filter((e) => e.joined === 0 && e.legit.length === 0);
  const pick = (needShift, needSalaried) => {
    for (let k = 0; k < 1000; k++) {
      const e = pool.splice(Math.floor(r() * pool.length), 1)[0];
      if ((needShift && !e.shift) || (needSalaried && e.shift)) { pool.push(e); continue; }
      return e;
    }
    throw new Error('pool exhausted');
  };
  for (const p of PLANTED) for (let k = 0; k < p.n; k++) {
    const e = pick(p.type === 'OT_WITHOUT_PROOF' || p.type === 'UNVERIFIED_HOURS', false);
    plant(e, p.type, r, M);
  }
  const rogue = 'APR-' + (1 + Math.floor(r() * 25));
  for (let k = 0; k < 3; k++) { // salary creep
    const e = pick(false, true); e.planted = 'SALARY_CREEP';
    for (let m = 2; m <= 12; m++) if (e.pay[m] != null) e.pay[m] = Math.round(e.pay[m] * Math.pow(1 + variant.creepStep, Math.floor(m / 2)));
  }
  for (let k = 0; k < 3; k++) { // raise far above peers, signed by one approver
    const e = pick(false, true); e.planted = 'RAISE_ABOVE_PEERS';
    e.pay[M] = Math.round(e.pay[M] * (1 + variant.raiseMin + r() * variant.raiseSpan)); e.knownReasons = ['INCREMENT']; e.raiseApprovedBy = k < variant.rogueSigns ? rogue : e.approver;
  }
  return { emps, rogue };
}

/** Feature vector for every employee of a company (numbers only). */
export function featurize({ emps }) {
  const change = (e) => { const h = e.pay.slice(M - 6, M).filter((x) => x != null); return h.length >= 3 ? e.pay[M] / median(h) - 1 : 0; };
  const byGrade = {};
  for (const e of emps) if (!e.shift) (byGrade[e.grade] = byGrade[e.grade] || []).push(change(e));
  const peerMed = Object.fromEntries(Object.entries(byGrade).map(([g, xs]) => [g, median(xs)]));
  const offcycleByApprover = {};
  for (const e of emps) if (e.raiseApprovedBy && change(e) >= 0.05) offcycleByApprover[e.raiseApprovedBy] = (offcycleByApprover[e.raiseApprovedBy] || 0) + 1;
  return emps.map((e) => {
    const hist = e.pay.slice(M - 6, M).filter((x) => x != null);
    const ch = change(e);
    const first = e.pay.findIndex((x) => x != null);
    let steps = 0;
    if (!e.shift) for (let m = Math.max(first + 1, M - 9); m <= M; m++) {
      const d = e.pay[m] / e.pay[m - 1] - 1;
      const explained = (e.incrementAt === m) || (m === M && e.knownReasons.length);
      if (d > 0.012 && !explained) steps++;
    }
    const recorded = (e.incrementAt != null && e.incrementAt > Math.max(first, M - 10) ? e.incPct : 0) + (e.knownReasons.length ? Math.max(0, ch) : 0);
    const growth = !e.shift && first >= 0 && first <= M - 10 ? e.pay[M] / e.pay[M - 10] - 1 - recorded : 0;
    const b = e.bank || {}, a = e.attendance || {};
    const recent = b.changedDaysAgo != null && b.changedDaysAgo <= 30;
    const x = [
      hist.length >= 3 ? deviationToSignal(robustZ(e.pay[M], hist)) : 0,
      e.knownReasons.length ? 1 : 0,
      e.shift ? 0 : clamp((ch - (peerMed[e.grade] || 0)) / 0.2, -1, 2),
      clamp(steps / 5, 0, 1),
      clamp(growth / 0.1, -1, 2),
      !e.shift && e.knownReasons.length && ch >= 0.05 ? 1 : 0,
      e.raiseApprovedBy && ch >= 0.05 ? clamp(((offcycleByApprover[e.raiseApprovedBy] || 1) - 1) / 2, 0, 1) : 0,
      recent ? 1 : 0,
      recent && b.newDevice ? 1 : 0,
      recent && (b.alertUnconfirmed || (b.newDevice && !b.secondChannelConfirmed)) ? 1 : 0,
      b.sharedWithOtherEmployee ? 1 : 0,
      a.otHours ? clamp((a.otHoursWithoutProof || 0) / a.otHours, 0, 1) : 0,
      clamp((a.missingPunches || 0) / Math.max(1, a.shifts || 22) * 4, 0, 1),
      e.cpfMismatch ? 1 : 0,
      e.paidAfterExit ? 1 : 0,
    ];
    const ruleClear = scoreRecord(toRecord(e, M)).status === 'clear';
    return { x, y: e.planted ? 1 : 0, type: e.planted, legit: e.legit[0] || null, ruleClear, e };
  });
}

/**
 * Training rows from many companies. The model is a second pair of eyes: it learns from records the RULES
 * CLEARED, so it specialises in what rules miss. In production, labels come from two-person decisions
 * and audits: a problem found later = 1, confirmed clean = 0.
 */
export function dataset(seeds, employees = 500) {
  const rows = [];
  for (const s of seeds) for (const r of featurize(buildCompany(s, employees))) if (r.ruleClear) rows.push(r);
  return rows;
}

/* ---------- 3. The model: weighted logistic regression, trained by gradient descent ---------- */
const sigmoid = (z) => 1 / (1 + Math.exp(-z));

export function initModel() { return { w: FEATURES.map(() => 0), b: 0, epochs: 0, loss: [] }; }

/** Train for `epochs` more passes. Deterministic. Returns the model (mutated). */
export function trainSteps(model, rows, { epochs = 50, lr = 0.8, l2 = 0.002 } = {}) {
  const pos = rows.filter((r) => r.y).length, neg = rows.length - pos;
  const wPos = neg / Math.max(1, pos); // positives are rare: weight them up
  const n = rows.length, k = FEATURES.length;
  for (let ep = 0; ep < epochs; ep++) {
    const gw = new Array(k).fill(0); let gb = 0, loss = 0, wsum = 0;
    for (const r of rows) {
      let z = model.b; for (let i = 0; i < k; i++) z += model.w[i] * r.x[i];
      const p = sigmoid(z), wt = r.y ? wPos : 1, err = (p - r.y) * wt;
      for (let i = 0; i < k; i++) gw[i] += err * r.x[i];
      gb += err; wsum += wt;
      loss += -wt * (r.y ? Math.log(p + 1e-12) : Math.log(1 - p + 1e-12));
    }
    for (let i = 0; i < k; i++) model.w[i] -= lr * (gw[i] / wsum + l2 * model.w[i]);
    model.b -= lr * gb / wsum;
    model.epochs++; model.loss.push(loss / wsum);
  }
  void n;
  return model;
}

export function predict(model, x) { let z = model.b; for (let i = 0; i < x.length; i++) z += model.w[i] * x[i]; return sigmoid(z); }

/** The three features that pushed this score up most, in plain words. */
export function explainRow(model, x) {
  return FEATURES.map(([key, label], i) => ({ key, label, c: model.w[i] * x[i] }))
    .filter((f) => f.c > 0.05).sort((a, b) => b.c - a.c).slice(0, 3);
}

/** Pick the threshold on TRAINING data: lowest that keeps model-only extra flags under `budget` of clean records. */
export function chooseThreshold(model, rows, budget = 0.01) {
  const cleanScores = rows.filter((r) => !r.y).map((r) => predict(model, r.x)).sort((a, b) => b - a);
  const idx = Math.floor(cleanScores.length * budget);
  return Math.min(0.99, Math.max(0.5, cleanScores[idx] ?? 0.5));
}

/* ---------- 4. Evaluation on companies the model has never seen ---------- */
/** Rules alone vs rules + model. The model can only add Review; it never clears or holds. */
export function evaluate(model, threshold, seeds, employees = 500, variant = STANDARD) {
  const types = ALL_PLANTED.map((p) => p.type);
  const per = Object.fromEntries(types.map((t) => [t, { planted: 0, rules: 0, combined: 0 }]));
  let clean = 0, faRules = 0, faCombined = 0, planted = 0, cRules = 0, cComb = 0;
  const examples = [];
  for (const s of seeds) {
    const co = buildCompany(s, employees, variant);
    const feats = featurize(co);
    for (const f of feats) {
      const ruleFlag = !f.ruleClear;
      const p = predict(model, f.x);
      const modelFlag = p >= threshold;
      const comb = ruleFlag || modelFlag;
      if (f.y) {
        planted++; per[f.type].planted++;
        if (ruleFlag) { cRules++; per[f.type].rules++; }
        if (comb) { cComb++; per[f.type].combined++; }
        if (!ruleFlag && modelFlag && examples.length < 4 && !examples.some((x) => x.type === f.type)) examples.push({ type: f.type, p: Number(p.toFixed(2)), why: explainRow(model, f.x).map((z) => z.label) });
      } else {
        clean++;
        if (ruleFlag) faRules++;
        if (comb) faCombined++;
      }
    }
  }
  return {
    companies: seeds.length, records: clean + planted, planted,
    rules: { caught: cRules, falseAlarmRate: faRules / clean },
    combined: { caught: cComb, falseAlarmRate: faCombined / clean },
    byType: ALL_PLANTED.map((p) => ({ type: p.type, label: p.label, category: CAT[p.type], ...per[p.type] })),
    examples,
  };
}

export const TRAIN_SEEDS = Array.from({ length: 20 }, (_, i) => 101 + i);
export const TEST_SEEDS = Array.from({ length: 20 }, (_, i) => 201 + i);

/** Full pipeline used by the tests, the PDF numbers and (in steps) the demo. */
export function trainAndEvaluate({ epochs = 400, trainSeeds = TRAIN_SEEDS, testSeeds = TEST_SEEDS, employees = 500 } = {}) {
  const rows = dataset(trainSeeds, employees);
  const model = trainSteps(initModel(), rows, { epochs });
  const threshold = chooseThreshold(model, rows);
  const ev = evaluate(model, threshold, testSeeds, employees);
  const hard = evaluate(model, threshold, testSeeds, employees, HARDER);
  return { model, threshold, trainRows: rows.length, trainPositives: rows.filter((r) => r.y).length, ev, hard };
}

/** Model card: what an auditor or judge needs to see. */
export function modelCard(result) {
  return {
    name: 'PayShield Risk Model', version: 'v1 (pilot candidate)',
    type: 'Weighted logistic regression, 15 features, 16 numbers in total',
    trainedOn: `${result.trainRows.toLocaleString('en-SG')} de-identified records from ${TRAIN_SEEDS.length} synthetic companies (${result.trainPositives} labelled problems)`,
    testedOn: `${result.ev.records.toLocaleString('en-SG')} records from ${result.ev.companies} companies it never saw`,
    inputs: 'Only the 15 allow-listed features. No ids, names, NRIC/FIN, bank numbers or protected attributes.',
    canDo: 'Add a Review flag with its top 3 reasons.', cannotDo: 'Clear a rule flag, hold pay, change pay.',
    threshold: Number(result.threshold.toFixed(2)),
  };
}

/** The approved v1 weights (from trainAndEvaluate with the default seeds; a test checks they match). */
export const MODEL_V1 = {
  w: [0.9418, 0.6324, 2.4314, 2.7404, 4.2178, 0.6468, 1.9662, -0.2486, -0.0673, 0, 0, 0, -0.0894, 0, 0],
  b: -3.9372, threshold: 0.6313,
};
