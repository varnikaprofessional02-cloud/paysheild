import { describe, it, expect } from 'vitest';
import { parseCSV, privacyProblems, checkFile, sampleCSV, templateCSV } from '../src/csvcheck.js';
import { offlineDraft, verifyDraft, offlineAnswer, askPrompt, askPayShield } from '../src/ai.js';
import { buildExplainPayload, numbersMatch } from '../src/explain.js';

describe('check your own file', () => {
  it('parses quoted CSV', () => {
    expect(parseCSV('a,b\n"x, y","say ""hi"""\n')).toEqual([['a', 'b'], ['x, y', 'say "hi"']]);
  });
  it('refuses personal-data columns and values', () => {
    expect(privacyProblems(parseCSV('employee_ref,Full_Name,pay_current\nA1,Tan,3000\n'))[0]).toMatch(/full_name/);
    expect(privacyProblems(parseCSV('employee_ref,pay_current\nS1234567D,3000\n')).length).toBe(1);
    expect(privacyProblems(parseCSV('employee_ref,pay_current,note\nA1,3000,+65 9123 4567 89\n')).length).toBe(1);
    expect(() => checkFile('employee_ref,nric,pay_current\nA1,x,1\n')).toThrow(/personal data/);
  });
  it('the template passes the privacy check and scores', () => {
    const r = checkFile(templateCSV());
    expect(r.rows).toBe(2);
  });
  it('the anonymised sample gives the same result as the test run', () => {
    const r = checkFile(sampleCSV());
    expect(r.rows).toBe(500);
    expect(r.held + r.review).toBe(34);
    expect(r.flagged[0].status).toBe('held');
  });
});

describe('live AI guardrails (offline paths)', () => {
  const p = buildExplainPayload({ employeeId: 'E-1187', runSalt: 'r', flags: ['BANK_CHANGED_RECENT', 'NEW_DEVICE', 'ALERT_UNCONFIRMED', 'PAY_SPIKE'], values: { days_before_payday: 2, pay_change_pct: 63 }, score: 23, status: 'held' });
  it('the prompt carries the masked record, not the employee id', () => {
    const q = askPrompt('Why held?', p);
    expect(q).not.toContain('E-1187');
    expect(q).toContain(p.subject);
  });
  it('built-in answers pass the number check', () => {
    for (const k of ['why', 'check', 'employee']) expect(numbersMatch(offlineAnswer(k, p), p)).toBe(true);
  });
  it('without an AI the answer is labelled offline', async () => {
    const r = await askPayShield({ kind: 'why', question: 'Why?', payload: p });
    expect(r.source).toBe('offline');
    expect(r.checked).toBe(true);
  });
  it('rule drafts are checked against the source text', () => {
    const text = 'From 1 January 2026, the CPF Ordinary Wage (OW) ceiling will be raised from $7,400 to $8,000 per month.';
    const d = offlineDraft(text);
    expect(d.rule_code).toBe('CPF_OW_CEILING');
    expect(d.new_value).toBe(8000);
    expect(d.effective_date).toBe('2026-01-01');
    expect(verifyDraft(d, text)).toEqual([]);
    expect(verifyDraft({ ...d, new_value: 8500 }, text).length).toBe(1);
  });
});
