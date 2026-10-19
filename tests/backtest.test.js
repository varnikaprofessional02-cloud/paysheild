import { describe, it, expect } from 'vitest';
import { runTest, runMany, rng } from '../src/backtest.js';
import { createMemory, acceptFlag, applyMemory, recordFix, tuningSuggestions } from '../src/learning.js';
import { scoreRecord } from '../src/scoring.js';

describe('test run (synthetic payroll, real scoring code)', () => {
  const t = runTest();
  it('is reproducible: same seed, same result', () => {
    expect(runTest().v2).toEqual(t.v2);
    expect(rng(1)()).toBe(rng(1)());
  });
  it('hides 25 problems in 500 records', () => {
    expect(t.v2.records).toBe(500);
    expect(t.v2.planted).toBe(25);
  });
  it('the first design missed ghost employees and attendance-only pay errors', () => {
    const missed = new Set(t.v1.missed.map((m) => m.type));
    expect(missed.has('GHOST_SHARED_ACCOUNT')).toBe(true);
    expect(missed.has('OT_WITHOUT_PROOF')).toBe(true);
  });
  it('the current design catches every planted problem with under 3% false alarms', () => {
    expect(t.v2.caught).toBe(25);
    expect(t.v2.falseAlarmRate).toBeLessThan(0.03);
  });
  it('the learning loop removes repeat false alarms next month', () => {
    expect(t.learning.without.repeatAlarms).toBeGreaterThan(0);
    expect(t.learning.with.repeatAlarms).toBe(0);
  });
  it('holds across 20 random companies', () => {
    const m = runMany({ runs: 20 });
    expect(m.v2.caughtMin).toBe(25);
    expect(m.v1.caughtAvg).toBeLessThan(m.v2.caughtAvg);
    expect(m.v2.falseAlarmRate).toBeLessThan(m.v1.falseAlarmRate);
  });
});

describe('design changes from the test run', () => {
  it('two employees sharing one account are always reviewed', () => {
    const r = scoreRecord({ current: 3000, history: [3000, 3000, 3000], bank: { sharedWithOtherEmployee: true } });
    expect(r.status).toBe('review');
  });
  it('email confirmation alone does not clear a new account set up from a new device', () => {
    const r = scoreRecord({ current: 3000, history: [3000, 3000, 3000], bank: { changedDaysAgo: 10, daysToPayday: 15, newDevice: true, alertUnconfirmed: false } });
    expect(r.status).toBe('review');
    const ok = scoreRecord({ current: 3000, history: [3000, 3000, 3000], bank: { changedDaysAgo: 10, daysToPayday: 15, newDevice: true, secondChannelConfirmed: true } });
    expect(ok.status).toBe('clear');
  });
  it('overtime paid without clock proof raises a warning', () => {
    const r = scoreRecord({ current: 3000, history: [3000, 3000, 3000], attendance: { shifts: 22, otHours: 30, otHoursWithoutProof: 15 } });
    expect(r.ruleHits.map((h) => h.code)).toContain('OT_WITHOUT_PROOF');
    expect(r.status).toBe('review');
  });
});

describe('learning loop', () => {
  it('a promotion becomes the new normal for 3 runs, then expires', () => {
    const m = createMemory();
    acceptFlag(m, { employeeId: 'E-1', reason: 'PROMOTION', month: 11 });
    expect(applyMemory(m, 'E-1', 12).baselineFrom).toBe(11);
    expect(applyMemory(m, 'E-1', 15).baselineFrom).toBe(null);
    expect(applyMemory(m, 'E-2', 12).baselineFrom).toBe(null);
  });
  it('suggests tuning but never applies it', () => {
    const m = createMemory();
    for (let i = 0; i < 5; i++) acceptFlag(m, { employeeId: 'E-' + i, reason: 'PROMOTION', month: 11, code: 'PAY_SPIKE' });
    for (let i = 0; i < 5; i++) recordFix(m, { code: 'BANK_CHANGE' });
    const s = tuningSuggestions(m);
    expect(s.find((x) => x.code === 'PAY_SPIKE').action).toBe('soften');
    expect(s.find((x) => x.code === 'BANK_CHANGE').action).toBe('escalate');
    expect(s.every((x) => x.text.includes('Needs admin approval'))).toBe(true);
  });
});

describe('50-company summary used in the demo and proposal', () => {
  const m = runMany({ runs: 50 });
  it('matches the published numbers', () => {
    expect(m.v1.caughtAvg).toBe(18);
    expect(m.v2.caughtMin).toBe(25);
    expect(m.byType.find((t) => t.type === 'BANK_HIJACK_EMAIL_TAKEN').v1).toBe(5);
    expect(Number((m.v1.falseAlarmRate * 100).toFixed(1))).toBe(3.6);
    expect(Number((m.v2.falseAlarmRate * 100).toFixed(1))).toBe(1.4);
  });
});
