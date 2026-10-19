# PayShield clickable demo (Times Software Ideathon 2026)

A runnable prototype of **PayShield**, an AI pre-flight check for the Times Portal pay run.
It has fourteen clickable scenarios, plus the real Trust Score, test-run and AI-safety logic behind them.

All names, amounts and scores are **sample data**.

## Run it

### Quick view (no install)
Double-click **`PayShield_Demo.html`**. It is the whole demo in one file and opens in any browser.

> Opening `index.html` directly does not work: that is the source page and needs the dev server (`npm run dev`).

### In Bolt (bolt.new)
Bolt imports projects from GitHub:

1. Create a new GitHub repository (private is fine) and upload the contents of this folder (not `node_modules`).
2. Open bolt.new and click the **GitHub icon** on the home page.
3. Sign in to GitHub if asked, then choose the repository (or use **Import from URL**).
4. Bolt installs the packages and starts the app. If it doesn't, type `npm install` then `npm run dev` in Bolt's terminal.

### On your laptop
Needs Node.js 18 or newer.

```bash
npm install
npm run dev      # opens the demo at http://localhost:5173
npm test         # runs the 64 scoring, test-run, model, agent, learning, file-check and AI-safety tests
npm run build    # production build in dist/
```

## How the demo is organised

PayShield has three parts in its side menu:

* **PayShield**: **Trust Check** (analysis only: Pay Score, guard results with progress bars, pay alerts) and **PayShield Agent** (one prompt runs the whole check).
* **Guards**: Employment, Attendance, Bank Shield, Pay Structure, Compliance. This is the only place findings are fixed or accepted.
* **Audit**: Pay run records, Proof & test run, Rules & parameters.

**Guard switches.** Every guard page has an on/off toggle for the pay run. Turning a guard off needs a reason and a scope (this pay run only, or until turned back on); Bank Shield and Compliance also need a second person to approve. While a guard is off its checks do not run: no findings are raised, Trust Check shows it as “Off · not checked” and leaves it out of the Pay Score, and the agent reports the guard as skipped and does not ask about it. Each switch is logged in Pay run records (`GUARD_SWITCH` in `src/company.js`).

Trust Check never fixes anything. Each failing guard row has “Fix in <guard> →”, and each alert opens the guard page scrolled to that finding. After a fix, a notice shows the re-scored Pay Score with “Back to Trust Check”. Approve unlocks at Pay Score 100.

Each guard page shows its findings with Fix / Accept buttons, its validators and live parameters, and ▶ buttons that run the related step-by-step story. A red dot and count show pending work. Company data is in `src/company.js`; pages in `src/pages.js`. Set `VITE_COMPANY` to change the company name.

## Demo stories (▶)

| Scenario (under PayShield in the side menu) | What it shows |
|---|---|
| Pre-flight check (opens first) | 5 employees, 6 checks each with a progress bar; fix a bank hijack, OT without proof, CPF on the old ceiling and salary creep (found by our model); then approve and see the pay run succeed. **Show parameters** lists the exact values each check used |
| Payroll Validators | The six validators with every parameter they use (read from the code), their AI role, the Trust Score settings and the versioned rule library |
| PayShield Agent | Our payroll LLM agent: ask any payroll question; it answers from 36 verified Singapore answers, runs the validators on a named employee (masked), cites sources, checks numbers and says when it does not know. Step 2 shows training and the held-out test (81% first answer, 90% top 3) and downloads the training set |
| Pay run | Trust Check step, held record with AI summary, **live score breakdown** and **the exact masked payload the AI receives** |
| Bank-change attack | Stolen login changes the bank account; two endings |
| Fraud Network | Every company protects the others; only a keyed fingerprint (HMAC, key in an HSM) is shared |
| Attendance | Geofence, selfie liveness, buddy-punch block, missed clock-out fix |
| Rule updates | AI drafts a CPF rule change, a person verifies it, what-if shows the cost |
| Before / after | Same pay run, two endings: S$15,070 paid wrongly vs S$0 (sample data) |
| Learns from you | An accepted reason is remembered for 3 runs; suggestions need admin approval |
| Ask PayShield | Live AI answers questions from a masked record; every number is checked. Rule Watch drafts a rule from public text; a person publishes |
| Our own model | Train PayShield Risk Model v1 live, see what it learned, test it on 20 new companies, approve it (two people) |
| Test run | The real scoring code checks a synthetic 500-employee company with 25 hidden problems, then 50 companies |
| Check your own file | Scores an anonymised pay-run CSV in the browser. Nothing is uploaded; files with personal data are refused |

## Project structure

```
index.html            page shell
src/main.js           clickable walkthrough (scenarios, steps, actions)
src/chrome.js         app shell: sidebar, top bar, icons, PayShield logo
src/style.css         original demo design (Plus Jakarta Sans, teal accent)
src/scoring.js        Trust Score: signals, weights, thresholds, overrides, rule checks, scoreRecord()
src/backtest.js       test run: seeded synthetic payroll, planted problems, results (runTest, runMany)
src/learning.js       learning loop: remembered decisions, tuning suggestions (never auto-applied)
src/extra.js          Before / after, Learns from you and Test run scenarios
src/extra2.js         Ask PayShield and Check your own file scenarios
src/model.js          our own risk model: feature allow-list, training, evaluation, explanations, model card
src/extra3.js         Our own model scenario
src/preflight.js      pre-flight data and checks for the 5-employee run (real scoring + approved model v1)
src/extra4.js         Pre-flight check scenario
src/ai.js             AI adapter: Claude artifact runtime when available, labelled built-in answers otherwise
src/csvcheck.js       CSV parser, personal-data guard, file scoring, sample and template files
samples/              payshield_template.csv and payshield_sample_payrun.csv (500 anonymised synthetic rows)
src/rules.js          versioned statutory rule library (CPF, SDL, MOM), verified October 2026
src/kb.js             PayShield Agent knowledge base: 41 verified answers, 144 training questions, 72 held-out questions, search, evaluation, JSONL export
src/agent.js          PayShield Agent: retrieval, validators tool with name masking, number check, "I don't know" fallback
src/extra5.js         Payroll Validators and PayShield Agent scenarios
samples/payshield_agent_training_set.jsonl  fine-tuning file (144 chat examples)
src/explain.js        AI layer: allow-listed payload, pseudonymous token, number check, template fallback
tests/scoring.test.js unit tests (Daniel example must score 23 and be held)
tests/agent.test.js   agent tests: held-out accuracy, age-band rewrite, masking, tool use, "I don't know"
tests/backtest.test.js test-run, design-fix and learning tests (numbers quoted in the proposal)
```

## How the Trust Score works (`src/scoring.js`)

* Three signals, each 0 (no risk) to 1 (high risk):
  * **Pay variance:** highest of rule severity (Critical 0.9, Warning 0.6, Info 0.3) and distance from the person's own 6-month median (robust, using the median absolute deviation). Known reasons such as an increment, bonus or proration cancel the statistical part.
  * **Bank-change risk:** changed in last 30 days +0.3, within 7 days of payday +0.2, new device +0.2, alert not confirmed +0.2, account shared with another employee +0.5, Fraud Network match = 1.0.
  * **Attendance:** missing punches, OT without clock proof, blocked buddy punches, geofence exceptions.
* `risk = 0.40·pay + 0.35·bank + 0.25·attendance + 0.03 for each extra signal ≥ 0.5`
* `Trust Score = round(100 × (1 − risk))`
* **Status:** 80–100 Clear · 50–79 Review · below 50 Held
* **Hard overrides:** any Critical rule → at least Review; a Fraud Network match, or a new bank account the employee hasn't confirmed close to payday → Held.
* Weights and thresholds sit in `DEFAULT_CONFIG` and are meant to be tuned per company (target: 3–5% of records flagged; 70%+ of flags acted on).

In the demo, each record's signal values are seeded. In production they come from the signal functions in `scoring.js`, run inside the payroll backend over the full data.

## Test run (`src/backtest.js`)

* 500 synthetic employees (70% salaried, 30% shift), 12 months of pay with normal noise: increments, OT swings, promotions, bank changes.
* 25 hidden problems of 9 kinds: bank hijacks (including one where the attacker controls the employee's email), ghost employees sharing an account, pay spikes, wrong CPF, ex-employees paid, OT without proof, unverified hours.
* Across 50 seeded companies: the first design caught 18 of 25 on average (17-19); the current design caught 25 of 25 in every run. False alarms on clean records fell from 3.6% to 1.4%. Repeat alarms the next month fell from 6.1 to 0 with the learning loop.
* The four design fixes the test found: shared account always reviewed; OT without clock proof and 3+ days without clock-out raise Warning rules; a new account from a new device must be confirmed on a second channel; hourly pay matching verified clocked hours is not flagged.
* Honest limit: we wrote both the problems and the checks. The next step is the same test on anonymised past pay runs from pilot customers.

## Our own model (`src/model.js`)

* A weighted logistic-regression model (15 inputs, 16 numbers) that we train ourselves. It re-checks records the rules cleared and can only add a Review flag.
* Inputs are an allow-list of 15 numeric features. No ids, names, NRIC/FIN, bank numbers or protected attributes; a test fails if one is added.
* Trained on 9,344 rule-cleared records from 20 synthetic companies, with two salary-increase patterns added: salary creep, and off-cycle raises far above peers signed by one approver.
* On 20 companies it never saw: rules alone caught 500 of 620 hidden problems; rules plus the model caught 620 of 620 (salary-increase patterns 0 to 120 of 120). False alarms rose from 1.6% to 2.4% of clean records. On a harder variant it caught 103 of 120 salary-increase cases.
* Synthetic data: this shows the model can learn the patterns, not how it performs on real payroll.

## Live AI (`src/ai.js`)

* Opened as a Claude artifact, Ask PayShield asks Claude (the viewer allows it on first use). Opened anywhere else (the HTML file, `npm run dev`, Bolt), it shows built-in answers and says so on screen.
* Only the masked payload is sent for questions, and only public announcement text for Rule Watch drafts.
* Every number in an answer must be in the record, otherwise the template sentence is shown. A rule draft is blocked if its values or year are not in the source text, and only a named reviewer can publish.
* In production the same adapter would call Azure OpenAI in Singapore through a private endpoint.

## PayShield Agent: full pay run check (`src/agentrun.js`, `src/agentpage.js`)

* Plan of 10 read-only tools: payrun.read, guard.people, guard.time, guard.bank (+ Fraud Network), guard.pay, model.v1.score, guard.compliance, history.compare, payscore.compute, fixes.draft.
* Pay Score (0–100) = 50% records ready + 50% pay value safe to pay. Any held record caps it at 79, any open review at 89. Ready to approve = 100 with nothing open.
* After the check, the agent goes through the findings one by one (held first). For each it shows what it found, the rule, the employee’s history and the money at risk, recommends an option and explains why. The user answers A (recommended fix), B (alternative with evidence) or C (leave out of this run), by clicking or typing.
* Every decision the user confirms (A, B or C) is **saved to PayShield straight away** in its guard (`applyPermanent` in `src/agentsession.js`); Trust Check re-scores after each answer and the guard page shows “Decided with PayShield Agent” with who, when and Undo. There are no temporary fixes.
* When all are decided, the Pay Score is shown, an approver signs off, and the agent runs the pay run (lock inputs, use the saved decisions, calculate, CPF/SDL, GIRO file, payslips) and writes the audit record with every question and answer.
* The agent cannot release pay without the approver, and cannot change master data, bank details or rules.
* Only masked tokens and numbers reach the language model; any number not in the facts is rejected and the verified text is shown.

## PayShield Agent: questions (`src/kb.js`, `src/agent.js`)

* Knowledge: 41 verified answers on CPF, levies, overtime and pay, leave, tax and compliance, and using PayShield, each with its official source. Each answer has 4 training phrasings and 2 held-out phrasings it is never trained on.
* Held-out test: 67 of 82 (82%) right first time, 75 of 82 (91%) in the top 3. Run `npm test` to check.
* Steps: find matching verified answers; if an employee is named, run the six validators and pass only a masked token; write the answer from those sources with citations; check every number against the sources, otherwise show the verified text.
* Below the confidence bar it says it has no verified answer and logs the question for training.
* Production plan: fine-tune an open-weight model on `samples/payshield_agent_training_set.jsonl` plus audited Q&A from pilot customers, host it in our own Azure tenant, keep the same retrieval, masking and number checks. In this demo the wording comes from Claude (artifact) or the verified text (offline).

## Check your own file (`src/csvcheck.js`)

* One row per employee; see `samples/payshield_template.csv` for the columns.
* Files with columns such as name, NRIC/FIN, email, phone or bank account, or values that look like them, are refused before scoring.
* The file is read by the browser only: no upload, no AI.

## Security design (`src/explain.js`)

* **The AI never analyses personal data.** All checks run in the rules engine inside our payroll backend.
* The AI only gets an **allow-listed payload**: flag codes, the few numbers the sentence needs, the score and a **pseudonymous token**. It never gets a name, NRIC/FIN, bank number or salary history. In production the token is HMAC-SHA256 with a key in Azure Key Vault; the demo uses a simple hash.
* **Output check:** every number in the AI's sentence must appear in the payload; otherwise a deterministic template sentence is used.
* **No dependency on AI:** if the AI is off or fails, pay checks still work.
* Follows the OWASP Top 10 for LLM Applications 2025 (LLM01 Prompt Injection, LLM02 Sensitive Information Disclosure, LLM05 Improper Output Handling, LLM09 Misinformation). Free-text fields are never put into prompts.

* **Fraud Network fingerprints are keyed, not plain hashes.** Bank account numbers are short, so a plain hash could be reversed by hashing every possible number. Production uses HMAC-SHA256 with a network key held in an HSM.
* Data protection, account security, monitoring and compliance controls are listed on the "How PayShield stays secure" page of the proposal PDF.

The demo makes no network calls to any AI service.
