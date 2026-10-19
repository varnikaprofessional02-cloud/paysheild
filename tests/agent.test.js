import { describe, it, expect } from 'vitest';
import { evaluateRetrieval, search, trainingJSONL, KB } from '../src/kb.js';
import { askAgent, runValidatorsTool } from '../src/agent.js';
import { EMPLOYEES } from '../src/preflight.js';

describe('PayShield Agent knowledge base', () => {
  it('answers held-out phrasings it was never trained on (top-1 ≥ 80%, top-3 ≥ 88%)', () => {
    const r = evaluateRetrieval();
    expect(r.total).toBe(KB.length * 2);
    expect(r.rate).toBeGreaterThanOrEqual(0.8);
    expect(r.top3Rate).toBeGreaterThanOrEqual(0.88);
  });
  it('uses the age in a CPF question to pick the right band', () => {
    expect(search('CPF rate for a 62 year old')[0].entry.a).toMatch(/above 60 to 65/i);
  });
  it('exports four questions per answer (main + 3 phrasings) as chat JSONL', () => {
    const lines = trainingJSONL().trim().split('\n');
    expect(lines.length).toBe(KB.length * 4);
    expect(JSON.parse(lines[0]).messages.length).toBeGreaterThanOrEqual(2);
  });
});

describe('PayShield Agent behaviour', () => {
  it('sends a masked token to the model, never the employee name', () => {
    const ravi = EMPLOYEES.find((e) => e.name.startsWith('Ravi'));
    const t = runValidatorsTool(ravi);
    expect(JSON.stringify(t)).not.toMatch(/Ravi/);
    expect(t.status).toBe('review');
  });
  it('uses the validators tool for an employee question', async () => {
    const r = await askAgent('Why is Daniel on hold?');
    expect(r.source).toBe('tool');
    expect(r.text).toMatch(/held/);
  });
  it('says it does not know rather than guessing', async () => {
    const r = await askAgent('Who won the football last night?');
    expect(r.source).toBe('none');
    expect(r.text).toMatch(/don.t have a verified answer/);
  });
});
