import { describe, it, expect, afterEach } from 'vitest';
import { ISSUES, payScore, pendingIn, setGuardOff, resetGuards } from '../src/company.js';
import { runPayShield } from '../src/agentrun.js';
import { createSession } from '../src/agentsession.js';

afterEach(() => resetGuards());
describe('Turning a guard off for a pay run', () => {
  it('its findings are not raised or scored', () => {
    const I = ISSUES();
    setGuardOff('bank', { by: 'test', reason: 'Handled in another system', scope: 'run' });
    expect(pendingIn(I).length).toBe(10);
    expect(pendingIn(I, 'bank').length).toBe(0);
    expect(payScore(I).held).toBe(2);
  });
  it('the agent skips that guard and does not ask about it', async () => {
    const I = ISSUES();
    setGuardOff('pay', { by: 'test', reason: 'Company does not use this check', scope: 'run' });
    const r = await runPayShield(I, { delay: false });
    expect(r.steps.find((s) => s.tool === 'guard.pay').skipped).toBe(true);
    expect(r.open.some((i) => i.guard === 'pay')).toBe(false);
    expect(createSession(I).queue.length).toBe(8);
  });
  it('turning it back on brings the checks back', () => {
    const I = ISSUES();
    setGuardOff('time', { by: 'test', reason: 'x', scope: 'run' });
    setGuardOff('time', null);
    expect(pendingIn(I).length).toBe(12);
  });
});
