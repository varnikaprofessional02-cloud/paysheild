// PayShield Agent: answers payroll questions from the verified knowledge base, and can run the validators
// on an employee as a tool. Production: our own fine-tuned model hosted in our Azure tenant.
// In this demo: retrieval, tools and guardrails are real; the wording comes from Claude when the page runs
// as a Claude artifact, otherwise from the verified answer itself (labelled on screen).
import { search } from './kb.js';
import { EMPLOYEES, checkEmployee, evidence, CHECKS } from './preflight.js';
import { getSample } from './ai.js';
import { subjectToken } from './explain.js';

const MIN_SCORE = 6; // below this the agent says it has no verified answer

function findEmployee(q) {
  const t = q.toLowerCase();
  return EMPLOYEES.find((e) => t.includes(e.name.toLowerCase()) || t.includes(e.name.split(' ')[0].toLowerCase()));
}

/** Tool: run all validators for one employee. Returns a masked summary (token, not the name) for the LLM. */
export function runValidatorsTool(e) {
  const r = checkEmployee(e), ev = evidence(e);
  const flags = [];
  const hits = [];
  for (const [k, label] of CHECKS) for (const p of ev[k]) if (p.hit) { flags.push(`${label}: ${p.label} = ${p.value} (limit ${p.limit}) → ${p.effect}`); hits.push({ check: label, ...p }); }
  return { token: subjectToken(e.id, 'agent'), status: r.status, score: r.score, flags, hits, fix: e.issue ? e.issue.fix : null };
}

function numbersOk(text, context) {
  const ctx = context.replace(/,/g, '');
  const nums = (text.replace(/,/g, '').match(/\d+(?:\.\d+)?/g) || []).filter((n) => !/^\d$/.test(n)); // single digits (list markers, "3 checks") allowed
  return nums.every((n) => ctx.includes(n));
}

export function agentPrompt(question, hits, tool) {
  return [
    'You are PayShield Agent, a payroll assistant for Singapore payroll admins.',
    'Answer ONLY from the numbered sources and the tool result below. Rules:',
    '- At most 4 short sentences, plain English, no markdown.',
    '- Cite sources like [1]. Do not use any number that is not in the sources or tool result.',
    '- If the sources do not answer the question, say you do not have a verified answer and suggest checking with MOM, CPF Board or IRAS.',
    '- Refer to an employee only by the token given; never guess names, NRIC or bank numbers.',
    '',
    ...hits.map((h, i) => `[${i + 1}] ${h.entry.q} — ${h.entry.a} (source: ${h.entry.src})`),
    tool ? `\nTool result (validators for ${tool.token}): status ${tool.status}, Trust Score ${tool.score}. ${tool.flags.join('; ') || 'All checks passed.'}${tool.fix ? ` Suggested fix: ${tool.fix}.` : ''}` : '',
    '',
    'Question: ' + String(question).slice(0, 500),
  ].join('\n');
}

/**
 * Answer a question. Returns {text, source:'ai'|'kb'|'none', hits, employee, tool, checked}.
 */
export async function askAgent(question, { onText, signal } = {}) {
  const emp = findEmployee(question);
  const tool = emp ? runValidatorsTool(emp) : null;
  const hits = search(question, 3);
  const confident = hits[0] && hits[0].score >= MIN_SCORE;
  const usable = confident ? hits : [];
  const unmask = (t) => (emp ? t.split(tool.token).join(emp.name) : t);

  if (!confident && !tool) {
    const text = 'I don’t have a verified answer for that yet. Please check with MOM, CPF Board or IRAS, or ask your payroll specialist. I’ve logged the question so it can be added to my training set.';
    return { text, source: 'none', hits: [], employee: null, tool: null, checked: true };
  }
  const sample = await getSample();
  const offline = () => {
    if (tool) {
      const word = tool.status === 'clear' ? 'is clear to pay' : tool.status === 'held' ? 'is held' : 'needs review';
      const head = `${emp.name} ${word} (Trust Score ${tool.score}).`;
      const groups = {};
      tool.hits.forEach((p) => { (groups[p.check] = groups[p.check] || []).push(`${p.label}: ${p.value}${p.limit && p.limit !== 'model input' ? ` (limit ${p.limit})` : ''}`); });
      const why = Object.entries(groups).slice(0, 3).map(([c, items]) => ` ${c}: ${items.join('; ')}.`).join('');
      const body = why || ' All 6 checks passed.';
      const fix = tool.fix ? ` Suggested fix: ${tool.fix.replace(/\.$/, '')}.` : '';
      return head + body + fix;
    }
    return usable[0].entry.a;
  };
  if (!sample) { const text = offline(); onText?.(text); return { text, source: tool ? 'tool' : 'kb', hits: usable, employee: emp, tool, checked: true }; }
  try {
    const prompt = agentPrompt(question, usable, tool);
    const { text } = await sample(prompt, { modelTier: 'quick', signal, cache: false, onText: ({ text: t }) => onText?.(unmask(t)) });
    const ok = numbersOk(text, prompt);
    return { text: ok ? unmask(text) : offline(), source: ok ? 'ai' : (tool ? 'tool' : 'kb'), hits: usable, employee: emp, tool, checked: ok, rejected: ok ? null : unmask(text) };
  } catch (e) {
    if (e && e.code === 'cancelled') throw e;
    const text = offline(); return { text, source: tool ? 'tool' : 'kb', hits: usable, employee: emp, tool, checked: true, error: e && e.code };
  }
}
