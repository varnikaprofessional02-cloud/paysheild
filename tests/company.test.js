import { describe, it, expect } from 'vitest';
import { ISSUES, runSummary, prorate, hourlyBasic, GUARDS, RUN } from '../src/company.js';

describe('PayShield company run (guard pages)', () => {
  it('every finding belongs to a guard and gets its status from the real Trust Score code', () => {
    const I = ISSUES();
    expect(I.length).toBe(12);
    I.forEach((i) => { expect(GUARDS[i.guard]).toBeTruthy(); expect(['held', 'review']).toContain(i.status); });
    const held = I.filter((i) => i.status === 'held').map((i) => i.id).sort();
    expect(held).toEqual(['daniel', 'lim', 'tan']);
  });
  it('uses the MOM formulas for proration and hourly basic', () => {
    expect(prorate(4800, 12, 22)).toBeCloseTo(2618.18, 2);
    expect(hourlyBasic(2200)).toBeCloseTo(11.54, 2);
  });
  it('the run is ready only when every finding is fixed or accepted', () => {
    const I = ISSUES();
    let r = runSummary(I);
    expect(r.ready).toBe(RUN.headcount - 12);
    expect(r.held).toBe(3);
    I.forEach((i) => { i.state = 'fixed'; });
    r = runSummary(I);
    expect(r.open).toBe(0);
    expect(r.ready).toBe(RUN.headcount);
    expect(r.protectedAmt).toBeCloseTo(r.found, 2);
  });
});
