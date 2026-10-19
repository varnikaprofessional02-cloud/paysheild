// Live AI for the demo. Inside a Claude artifact viewer it asks Claude (the viewer approves the first call);
// everywhere else (the offline HTML file, npm run dev, Bolt) it falls back to built-in answers, clearly labelled.
// Only the masked payload or public rule text is ever sent. In production this adapter points at Azure OpenAI.

import { numbersMatch, templateSentence } from './explain.js';

let samplePromise = null;
/** Resolves the sample function, or null when no AI is available in this view. */
export function getSample() {
  if (!samplePromise) {
    samplePromise = (async () => {
      try {
        if (typeof window === 'undefined' || !window.claude || typeof window.claude.use !== 'function') return null;
        return await window.claude.use('sample');
      } catch { return null; }
    })();
  }
  return samplePromise;
}


/** The exact prompt sent for an "Ask PayShield" question. Shown on screen for transparency. */
export function askPrompt(question, payload) {
  return [
    'You are PayShield, a payroll assurance assistant for a payroll admin in Singapore.',
    'Answer the admin\'s question using ONLY the facts in the masked JSON record below.',
    'Rules:',
    '- At most 3 short sentences, plain English, no markdown, no lists.',
    '- Use only numbers that appear in the record. Do not write any other number, amount or date.',
    '- Call the person "this employee". The subject token is not a name; never guess names or personal details.',
    '- If the record does not answer the question, say what the admin should check instead.',
    '- Never tell the admin to change pay yourself; a person decides.',
    '',
    'Record:',
    JSON.stringify(payload),
    '',
    'Question: ' + String(question).slice(0, 500),
  ].join('\n');
}

/** Built-in answers used when no AI is available. */
export function offlineAnswer(kind, payload) {
  if (kind === 'check') return `Before releasing, confirm the bank change with this employee on the phone number held before the change, check why pay is ${payload.values.pay_change_pct}% higher, and get a second approver. The score is ${payload.score}.`;
  if (kind === 'employee') return `We have paused part of this month's salary while we confirm a recent change to your bank details. Please contact HR on the number you already have for us; no action is needed through links in emails or messages.`;
  return `This record is ${payload.status.toLowerCase()} with a score of ${payload.score}: ${templateSentence(payload).replace(/\.$/, '')}.`;
}

/**
 * Ask a question about one masked record. Returns {text, source:'ai'|'offline', checked:boolean, fallback?:string}.
 * `onText` streams the answer. Throws only on cancel.
 */
export async function askPayShield({ kind, question, payload, onText, signal }) {
  const sample = await getSample();
  if (!sample) {
    const text = offlineAnswer(kind, payload);
    onText?.(text);
    return { text, source: 'offline', checked: numbersMatch(text, payload) };
  }
  try {
    const { text } = await sample(askPrompt(question, payload), { modelTier: 'quick', signal, onText: ({ text: t }) => onText?.(t) });
    const ok = numbersMatch(text, payload);
    return { text, source: 'ai', checked: ok, fallback: ok ? undefined : templateSentence(payload) };
  } catch (e) {
    if (e && e.code === 'cancelled') throw e;
    const text = offlineAnswer(kind, payload);
    return { text, source: 'offline', checked: numbersMatch(text, payload), error: e && e.code };
  }
}

/* ---------- Rule Watch: draft a rule from public announcement text ---------- */

const MONTHS = ['january', 'february', 'march', 'april', 'may', 'june', 'july', 'august', 'september', 'october', 'november', 'december'];
const digits = (s) => String(s ?? '').replace(/[^\d.]/g, '');

export function rulePrompt(text) {
  return [
    'You draft payroll rule changes for a compliance reviewer in Singapore.',
    'Read the public announcement below and reply with ONLY one JSON object:',
    '{"rule_code": "UPPER_SNAKE", "description": "one short sentence", "old_value": number|null, "new_value": number, "unit": "SGD per month"|"percent"|"hours"|"other", "effective_date": "YYYY-MM-DD", "applies_to": "short phrase", "quote": "exact phrase copied from the text that states the new value", "confidence": "high"|"medium"|"low"}',
    'Use only values stated in the text. If something is not stated, use null and lower the confidence.',
    '',
    'Announcement:',
    String(text).slice(0, 6000),
  ].join('\n');
}

/** Rule-based fallback extractor (no AI): amounts and the first date in the text. */
export function offlineDraft(text) {
  const t = String(text);
  const amounts = [...t.matchAll(/(?:S\$|\$)\s?([\d,]+(?:\.\d+)?)/g)].map((m) => Number(m[1].replace(/,/g, '')));
  const dm = t.match(/(\d{1,2})\s+(January|February|March|April|May|June|July|August|September|October|November|December)\s+(\d{4})/i);
  const date = dm ? `${dm[3]}-${String(MONTHS.indexOf(dm[2].toLowerCase()) + 1).padStart(2, '0')}-${String(dm[1]).padStart(2, '0')}` : null;
  const code = /ordinary wage.{0,12}ceiling/i.test(t) ? 'CPF_OW_CEILING' : /additional wage.{0,12}ceiling/i.test(t) ? 'CPF_AW_CEILING' : /overtime|\bOT\b/i.test(t) ? 'MOM_OT_RULE' : 'RULE_DRAFT';
  return {
    rule_code: code, description: 'Draft from the rule-based reader (AI not available in this view).',
    old_value: amounts.length > 1 ? amounts[0] : null, new_value: amounts.length ? amounts[amounts.length > 1 ? 1 : 0] : null,
    unit: amounts.length ? 'SGD per month' : 'other', effective_date: date, applies_to: 'Check in the source', quote: '', confidence: 'low',
  };
}

/** Every number and the year in the draft must appear in the source text. Returns a list of problems. */
export function verifyDraft(draft, text) {
  const src = String(text).replace(/,/g, '');
  const out = [];
  for (const k of ['old_value', 'new_value']) {
    const v = draft[k];
    if (v == null) continue;
    if (!src.includes(digits(v).replace(/\.0+$/, ''))) out.push(`${k.replace('_', ' ')} ${v} is not in the source text`);
  }
  if (draft.new_value == null) out.push('no new value found');
  if (draft.effective_date && !src.includes(String(draft.effective_date).slice(0, 4))) out.push(`year ${String(draft.effective_date).slice(0, 4)} is not in the source text`);
  if (!draft.effective_date) out.push('no effective date found');
  return out;
}

export async function draftRule(text, { signal } = {}) {
  const sample = await getSample();
  if (!sample) { const d = offlineDraft(text); return { draft: d, source: 'offline', problems: verifyDraft(d, text) }; }
  try {
    const d = await sample.json(rulePrompt(text), { signal });
    const draft = d && typeof d === 'object' ? d : offlineDraft(text);
    return { draft, source: 'ai', problems: verifyDraft(draft, text) };
  } catch (e) {
    if (e && e.code === 'cancelled') throw e;
    const d = offlineDraft(text);
    return { draft: d, source: 'offline', problems: verifyDraft(d, text), error: e && e.code };
  }
}

/** Save a text file: the artifact's downloads capability when present, else a normal browser download. */
export async function saveText(filename, text, mime = 'text/csv') {
  try {
    if (window.claude && typeof window.claude.use === 'function') {
      const dl = await Promise.race([window.claude.use('downloads'), new Promise((r) => setTimeout(() => r(null), 1500))]);
      if (dl) { await dl.save({ filename, data: text }); return true; }
    }
  } catch { /* fall through */ }
  const url = URL.createObjectURL(new Blob([text], { type: mime }));
  const a = document.createElement('a'); a.href = url; a.download = filename; document.body.appendChild(a); a.click(); a.remove();
  setTimeout(() => URL.revokeObjectURL(url), 2000);
  return true;
}
