import { describe, it, expect } from 'vitest';
import { trustScore, bankRiskSignal, payVarianceSignal, attendanceSignal, deviationToSignal, robustZ, median, mad } from '../src/scoring.js';
import { buildExplainPayload, templateSentence, numbersMatch, explain } from '../src/explain.js';

describe('trust score', () => {
  it('Daniel (demo): pay 0.82, bank 0.90, attendance 0.40 -> 23, held', () => {
    const r = trustScore({ pay: 0.82, bank: 0.9, attendance: 0.4 });
    expect(r.risk).toBeCloseTo(0.773, 3);
    expect(r.score).toBe(23);
    expect(r.status).toBe('held');
  });
  it('two strong signals add the combination bonus', () => {
    expect(trustScore({ pay: 0.55, attendance: 0.6 }).score).toBe(60);
    expect(trustScore({ pay: 0.55, attendance: 0.6 }).bonus).toBeCloseTo(0.03);
  });
  it('thresholds: >=80 clear, 50-79 review, <50 held', () => {
    expect(trustScore({}).status).toBe('clear');
    expect(trustScore({ bank: 0.68 }).status).toBe('review'); // 76
    expect(trustScore({ pay: 1, bank: 1 }).status).toBe('held');
  });
  it('a critical rule is never hidden by a good score', () => {
    const r = trustScore({ pay: 0.3 }, { critical: true });
    expect(r.score).toBe(88);
    expect(r.status).toBe('review');
    expect(r.overridesApplied).toContain('CRITICAL_RULE');
  });
  it('fraud network match always holds', () => {
    const b = bankRiskSignal({ fraudNetworkMatch: true });
    const r = trustScore({ bank: b.value }, { forceHold: b.forceHold });
    expect(r.score).toBe(65);
    expect(r.status).toBe('held');
  });
});

describe('signals', () => {
  it('bank points for Daniel add up to 0.90 and force a hold', () => {
    const b = bankRiskSignal({ changedDaysAgo: 2, daysToPayday: 2, newDevice: true, alertUnconfirmed: true });
    expect(b.value).toBe(0.9);
    expect(b.forceHold).toBe(true);
  });
  it('old bank change does not count', () => {
    expect(bankRiskSignal({ changedDaysAgo: 200, daysToPayday: 2, newDevice: true }).value).toBe(0);
  });
  it('robust baseline ignores normal month-to-month noise', () => {
    const hist = [4850, 4920, 5010, 4880, 4960, 4980];
    expect(median(hist)).toBe(4940);
    expect(mad(hist)).toBe(50);
    expect(deviationToSignal(robustZ(4990, hist))).toBe(0);
    expect(deviationToSignal(robustZ(8120, hist))).toBe(0.95);
  });
  it('a known reason (increment) cancels the statistical part', () => {
    const p = payVarianceSignal({ current: 8120, history: [4850, 4920, 5010, 4880, 4960, 4980], knownReasons: ['INCREMENT'] });
    expect(p.stat).toBe(0);
  });
  it('rule severity drives the pay signal and marks critical', () => {
    const p = payVarianceSignal({ current: 4200, history: [4200, 4200, 4200], ruleHits: [{ code: 'EX_EMPLOYEE_IN_RUN', severity: 'CRITICAL' }] });
    expect(p.value).toBe(0.9);
    expect(p.critical).toBe(true);
  });
  it('attendance signal is capped at 1', () => {
    expect(attendanceSignal({ shifts: 20, missingPunches: 20, otHours: 10, otHoursWithoutProof: 10, blockedAttempts: 5, geofenceExceptions: 5 }).value).toBe(1);
  });
});

describe('AI explanation safety', () => {
  const payload = buildExplainPayload({
    employeeId: 'E-1187', runSalt: 'run-2026-09',
    flags: ['OT_OVER_CAP', 'NO_CLOCKOUT', 'NAME_LEAK'],
    values: { ot_hours: 88, cap: 72, no_clockout_hours: 14, nric: 1234567, salary: 9840 },
    score: 60, status: 'review',
  });
  it('payload carries no personal data', () => {
    const json = JSON.stringify(payload);
    expect(json).not.toContain('E-1187');
    expect(json).not.toContain('nric');
    expect(json).not.toContain('salary');
    expect(payload.flags).not.toContain('NAME_LEAK');
    expect(payload.subject).toMatch(/^EMP_[0-9A-F]{6}$/);
  });
  it('template sentence uses only payload numbers', () => {
    const t = templateSentence(payload);
    expect(t).toBe('OT is 88 h against a 72 h cap; 14 h have no clock-out.');
    expect(numbersMatch(t, payload)).toBe(true);
  });
  it('an AI answer with a wrong number is rejected', async () => {
    const r = await explain(payload, async () => 'OT is 90 h against a 72 h cap.');
    expect(r.source).toBe('template');
  });
  it('pay spike sentence passes its own number check', () => {
    const p = buildExplainPayload({ employeeId: 'E-1', runSalt: 'r', flags: ['PAY_SPIKE'], values: { pay_change_pct: 63 }, score: 40, status: 'held' });
    expect(numbersMatch(templateSentence(p), p)).toBe(true);
  });
  it('a correct AI answer is used', async () => {
    const r = await explain(payload, async () => 'Overtime reached 88 h, above the 72 h cap.');
    expect(r.source).toBe('ai');
  });
});
