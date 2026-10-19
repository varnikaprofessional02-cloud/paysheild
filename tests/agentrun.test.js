import { describe, it, expect } from 'vitest';
import { ISSUES, payScore } from '../src/company.js';
import { runPayShield, isRunRequest, maskedFacts, PLAN } from '../src/agentrun.js';

describe('PayShield Agent: full pay run check', () => {
  it('recognises a request to check the whole pay run', () => {
    expect(isRunRequest('Please check the pay run and suggest fixes as per compliance and history, and give the pay score')).toBe(true);
    expect(isRunRequest('Is CPF due on share awards?')).toBe(false);
  });
  it('runs every tool and reports Pay Score 79 (3 held cap it below 80)', async () => {
    const r = await runPayShield(ISSUES(), { delay: false, prompt: 'check the pay run' });
    expect(r.steps.map((s) => s.tool)).toEqual(PLAN.map((p) => p.tool));
    expect(r.ps.score).toBe(79);
    expect(r.ps.raw).toBeGreaterThan(79);
    expect(r.open.length).toBe(12);
    r.open.forEach((i) => { expect(i.ref).toBeTruthy(); expect(i.hist).toBeTruthy(); expect(i.fix.label).toBeTruthy(); });
  });
  it('never puts an employee name in what the language model sees', async () => {
    const I = ISSUES();
    const r = await runPayShield(I, { delay: false });
    const facts = JSON.stringify(maskedFacts(r)) + JSON.stringify(r.steps);
    I.forEach((i) => expect(facts).not.toContain(i.name));
  });
  it('reaches 100 and Ready to approve once every finding is fixed', () => {
    const I = ISSUES(); I.forEach((i) => { i.state = 'fixed'; });
    const p = payScore(I);
    expect(p.score).toBe(100); expect(p.verdict).toBe('Ready to approve');
  });
});
