import { describe, it, expect } from 'vitest';
import { FEATURES, PROTECTED, featurize, buildCompany, trainAndEvaluate, predict, explainRow, modelCard } from '../src/model.js';

describe('our own model: security by design', () => {
  it('uses only allow-listed features, none of them identifying or protected', () => {
    const keys = FEATURES.map(([k]) => k).join(' ');
    for (const p of PROTECTED) expect(keys).not.toMatch(new RegExp('(^|_|\\s)' + p + '($|_|\\s)'));
  });
  it('feature rows are numbers only, with no ids', () => {
    const rows = featurize(buildCompany(7, 200));
    for (const r of rows.slice(0, 50)) {
      expect(r.x).toHaveLength(FEATURES.length);
      expect(r.x.every((v) => typeof v === 'number' && Number.isFinite(v))).toBe(true);
    }
  });
});

describe('our own model: results on companies it never saw', () => {
  const r = trainAndEvaluate();
  it('training is repeatable', () => {
    const again = trainAndEvaluate();
    expect(again.model.w).toEqual(r.model.w);
  });
  it('catches the salary-increase patterns that rules miss', () => {
    const creep = r.ev.byType.find((t) => t.type === 'SALARY_CREEP');
    const peers = r.ev.byType.find((t) => t.type === 'RAISE_ABOVE_PEERS');
    expect(creep.rules).toBe(0);
    expect(peers.rules).toBe(0);
    expect(creep.combined / creep.planted).toBeGreaterThan(0.95);
    expect(peers.combined / peers.planted).toBeGreaterThan(0.95);
  });
  it('never removes a rule flag, and adds under 1 point of false alarms', () => {
    for (const t of r.ev.byType) expect(t.combined).toBeGreaterThanOrEqual(t.rules);
    expect(r.ev.combined.falseAlarmRate - r.ev.rules.falseAlarmRate).toBeLessThan(0.01);
  });
  it('is weaker on harder patterns, and we report that', () => {
    const inc = r.hard.byType.filter((t) => t.category === 'Salary increase');
    const rate = inc.reduce((a, t) => a + t.combined, 0) / inc.reduce((a, t) => a + t.planted, 0);
    expect(rate).toBeGreaterThan(0.75);
    expect(rate).toBeLessThan(1);
  });
  it('explains every model flag with its top reasons', () => {
    for (const ex of r.ev.examples) expect(ex.why.length).toBeGreaterThan(0);
    expect(modelCard(r).cannotDo).toMatch(/hold pay/);
  });
});

import { MODEL_V1 } from '../src/model.js';
describe('approved model v1', () => {
  it('matches a fresh training run', () => {
    const r = trainAndEvaluate({ testSeeds: [201] });
    r.model.w.forEach((w, i) => expect(w).toBeCloseTo(MODEL_V1.w[i], 3));
    expect(r.model.b).toBeCloseTo(MODEL_V1.b, 3);
    expect(r.threshold).toBeCloseTo(MODEL_V1.threshold, 3);
  });
});
