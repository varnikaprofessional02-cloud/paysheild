import { describe, it, expect } from 'vitest';
import { ISSUES, payScore, pendingIn } from '../src/company.js';
import { createSession, optionsFor, decide, nextId, finalRunPlan, applyPermanent } from '../src/agentsession.js';

// Mirrors the agent page: every decision is decided and then saved to PayShield.
const decideAndSave = (I, s, choose) => { while (nextId(s)) { const i = I.find((x) => x.id === nextId(s)); const k = choose(i); decide(s, i, k); applyPermanent(i, k); } };

describe('PayShield Agent: one by one, saved to PayShield', () => {
  it('asks about held findings first', () => {
    const I = ISSUES(), s = createSession(I);
    expect(s.queue.length).toBe(12);
    expect(s.queue.slice(0, 3).map((id) => I.find((i) => i.id === id).status)).toEqual(['held', 'held', 'held']);
  });
  it('offers three options with the recommended fix first', () => {
    const o = optionsFor(ISSUES().find((i) => i.id === 'daniel'));
    expect(o.map((x) => x.key)).toEqual(['A', 'B', 'C']);
    expect(o[0].recommended).toBe(true);
  });
  it('every decision changes PayShield itself, including “leave out of this run”', () => {
    const I = ISSUES(), s = createSession(I);
    decideAndSave(I, s, (i) => (i.id === 'kelvin' ? 'hold' : 'fix'));
    expect(pendingIn(I).length).toBe(0);
    expect(I.find((i) => i.id === 'kelvin').state).toBe('excluded');
    expect(payScore(I).score).toBe(100);
    expect(s.phase).toBe('ready');
  });
  it('final run plan counts employees left out of the run', () => {
    const I = ISSUES(), s = createSession(I);
    decideAndSave(I, s, (i) => (i.id === 'kelvin' ? 'hold' : 'fix'));
    const p = finalRunPlan(I, s);
    expect(p.leftOut).toBe(1);
    expect(p.paid).toBe(219 - 1 - 1); // Kelvin left out; Lim removed as a leaver
    expect(p.stages.length).toBe(7);
  });
});
