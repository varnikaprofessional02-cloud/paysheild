// PayShield Agent knowledge base: verified Singapore payroll answers (checked against official pages, October 2026)
// plus PayShield how-to answers. `alts` are held-out paraphrases used ONLY to evaluate retrieval, never indexed.
// The same pairs, in chat format, are the starter fine-tuning set (samples/agent_training_set.jsonl).

const CPF = 'https://www.cpf.gov.sg';
const MOM = 'https://www.mom.gov.sg';

export const KB = [
  // ---------- CPF ----------
  { id: 'cpf-ow', train: ['What is the maximum salary CPF applies to each month?', 'CPF wage ceiling 2026', 'Up to what monthly amount do we compute CPF?'], cat: 'CPF', q: 'What is the CPF Ordinary Wage ceiling in 2026?', k: 'ow ceiling cap limit monthly ordinary wages 8000 7400',
    a: 'From 1 Jan 2026 the CPF Ordinary Wage ceiling is S$8,000 a month (it was S$7,400 in 2025). CPF is only payable on Ordinary Wages up to this amount.',
    src: CPF + '/service/article/what-is-the-ordinary-wage-ow-ceiling', alts: ['How much monthly salary is CPF calculated on at most?', 'Did the OW cap change this year?'] },
  { id: 'cpf-aw', train: ['How is CPF on bonus capped?', 'Annual limit for CPF on additional wages', 'CPF on 13th month bonus limit'], cat: 'CPF', q: 'What is the CPF Additional Wage ceiling?', k: 'aw ceiling bonus additional wages 102000 annual',
    a: 'The Additional Wage ceiling is S$102,000 minus the total Ordinary Wages subject to CPF in the calendar year. It applies per employee, per employer, per year.',
    src: CPF + '/service/article/what-is-the-additional-wage-aw-ceiling', alts: ['How much of a bonus attracts CPF?', 'What is the yearly cap for CPF on bonuses?'] },
  { id: 'cpf-rate', train: ['Employer and employee CPF percentage for staff under 55', 'CPF contribution rate for younger employees', 'How much CPF do we deduct from a 35 year old salary?'], cat: 'CPF', q: 'What are the CPF contribution rates for employees aged 55 and below?', k: 'rate percent employer employee 17 20 37 contribution',
    a: 'For Singapore citizens and PRs from their 3rd year, aged 55 and below, earning above S$750 a month: employer 17% and employee 20% (37% in total).',
    src: CPF + '/content/dam/web/employer/employer-obligations/documents/CPFcontributionratesfrom1Jan2026.pdf', alts: ['How much CPF does the employer pay for a 30-year-old?', 'What percentage is deducted for CPF from a young employee?'] },
  { id: 'cpf-senior', train: ['CPF rates for employees above 55', 'Contribution rates for staff aged 60 to 65', 'CPF percentage for elderly workers above 70'], cat: 'CPF', q: 'What are the CPF rates for older workers in 2026?', k: 'senior older age 55 60 65 70 rates changed 2026',
    a: 'From 1 Jan 2026 (employer / employee): above 55 to 60: 16% / 18%; above 60 to 65: 12.5% / 12.5%; above 65 to 70: 9% / 7.5%; above 70: 7.5% / 5%. The bands from 55 to 65 rose on 1 Jan 2026.',
    src: CPF + '/service/article/what-are-the-changes-to-the-cpf-contribution-rates-for-senior-workers-from-1-january-2026', alts: ['How much CPF for a 62-year-old employee?', 'Did senior worker CPF rates go up?'] },
  { id: 'cpf-low', train: ['CPF for part-time staff with small wages', 'Is CPF payable if an employee earns below S$500?', 'Reduced CPF for wages between 500 and 750'], cat: 'CPF', q: 'How is CPF calculated for low wages under S$750?', k: 'low wage 50 500 750 part-time factor 0.6',
    a: 'Wages of S$50 or less: no CPF. Above S$50 to S$500: only the employer contributes. Above S$500 to S$750: the employer pays its rate on total wages, and the employee pays a factor (0.6 for age 55 and below) × (total wages − S$500).',
    src: CPF + '/content/dam/web/employer/employer-obligations/documents/CPFcontributionratesfrom1Jan2026.pdf', alts: ['Does a part-timer earning S$400 pay CPF?', 'Employee CPF for someone earning S$600?'] },
  { id: 'cpf-owaw', train: ['Is an annual bonus an ordinary or additional wage?', 'Which payments are additional wages for CPF?', 'Is overtime pay an ordinary wage?'], cat: 'CPF', q: 'What is the difference between Ordinary Wages and Additional Wages?', k: 'definition ordinary additional bonus allowance leave pay',
    a: 'Ordinary Wages are wages due for work in that month, such as basic pay, monthly allowances and overtime. Additional Wages are payments not granted wholly for that month, such as annual bonuses, incentive payments and leave pay.',
    src: CPF + '/employer', alts: ['Is a year-end bonus OW or AW?', 'Which pay items count as additional wages?'] },
  { id: 'cpf-due', train: ['Last date to pay CPF for the month', 'CPF payment due date and grace period', 'When is CPF late?'], cat: 'CPF', q: 'When must CPF contributions be paid?', k: 'due date deadline 14th month pay cpf',
    a: 'CPF contributions are due at the end of each month, with a grace period to the 14th of the following month.',
    src: CPF + '/employer', alts: ['What is the deadline to submit CPF for September?', 'By which date should employers pay CPF?'] },
  // ---------- SDL & SHG ----------
  { id: 'sdl', train: ['Skills development levy rate and cap', 'How do we calculate SDL?', 'SDL minimum and maximum amount'], cat: 'Levies', q: 'How much is the Skills Development Levy?', k: 'sdl levy 0.25 4500 11.25 minimum 2',
    a: 'SDL is 0.25% of monthly pay, counting only the first S$4,500. The minimum is S$2 per employee (pay under S$800) and the maximum is S$11.25 (pay above S$4,500).',
    src: 'https://www.gobusiness.gov.sg/skills-development-levy-faqs/sdl-about', alts: ['What SDL do I pay for someone earning S$6,000?', 'Is there a cap on the skills levy?'] },
  { id: 'shg', train: ['CDAC SINDA MBMF ECF deductions', 'Opt out of self-help group contribution', 'Who pays self-help group funds?'], cat: 'Levies', q: 'What are the self-help group contributions?', k: 'cdac ecf mbmf sinda self help group deduction opt out',
    a: 'CDAC, ECF, MBMF and SINDA contributions are deducted from employee wages at tiered rates and paid with CPF. Which fund applies depends on race or religion and work pass type. To opt out or change the amount, the employee contacts the self-help group.',
    src: CPF + '/employer/employer-obligations/contributions-to-self-help-groups', alts: ['How does an employee stop the CDAC deduction?', 'Which employees pay MBMF?'] },
  // ---------- Employment Act ----------
  { id: 'ot-cover', train: ['Which employees are eligible for overtime?', 'Is a manager entitled to OT pay?', 'Salary threshold for overtime coverage'], cat: 'Overtime & pay', q: 'Who is entitled to overtime pay under the Employment Act?', k: 'part iv covered workman non-workman 4500 2600 eligible overtime',
    a: 'Part IV overtime rules cover workmen earning a basic monthly salary up to S$4,500 and non-workmen up to S$2,600. Managers and executives are not covered.',
    src: MOM + '/employment-practices/hours-of-work-overtime-and-rest-days', alts: ['Does an executive earning S$5,000 get OT?', 'What salary limit applies for overtime eligibility?'] },
  { id: 'ot-rate', train: ['How to calculate overtime pay rate', 'Overtime hourly rate formula', 'Is overtime paid at one and a half times?'], cat: 'Overtime & pay', q: 'What is the minimum overtime rate?', k: 'ot rate 1.5 times hourly basic 13.60',
    a: 'Overtime is paid at least 1.5 times the hourly basic rate. For non-workmen, the rate is worked out on a salary capped at S$2,600, which is S$13.60 an hour.',
    src: MOM + '/employment-practices/hours-of-work-overtime-and-rest-days', alts: ['How much is time-and-a-half?', 'What hourly rate do I use for OT?'] },
  { id: 'ot-cap', train: ['Overtime hours limit per month', 'Can staff work more than 72 hours OT?', 'Monthly OT cap in Singapore'], cat: 'Overtime & pay', q: 'What is the maximum overtime per month?', k: 'ot cap 72 hours limit exemption',
    a: 'Employees can work at most 72 overtime hours a month unless MOM grants an exemption. PayShield flags anything above 72 hours before the pay run.',
    src: MOM + '/employment-practices/hours-of-work-overtime-and-rest-days', alts: ['Can a worker do 88 hours of OT?', 'Is there a limit on monthly overtime hours?'] },
  { id: 'pay-due', train: ['How many days after month end must salary be paid?', 'When should overtime be paid?', 'Late salary payment rule'], cat: 'Overtime & pay', q: 'When must salary be paid?', k: 'salary payment deadline 7 days 14 days overtime late',
    a: 'Salary must be paid at least once a month, within 7 days after the end of the salary period. Overtime must be paid within 14 days.',
    src: MOM + '/employment-practices/salary/paying-salary', alts: ['How late can we pay September salaries?', 'Deadline for paying overtime?'] },
  { id: 'payslip', train: ['Payslip requirements in Singapore', 'When must we issue payslips?', 'What should be shown on a payslip?'], cat: 'Overtime & pay', q: 'What must an itemised payslip contain and when is it due?', k: 'payslip itemised 3 working days contents',
    a: 'Itemised payslips go out with the payment or within 3 working days. They show employer and employee names, payment date, basic salary, salary period, allowances, other payments, deductions, overtime hours and pay, and net salary.',
    src: MOM + '/employment-practices/salary/itemised-payslips', alts: ['How soon after payday must payslips be given?', 'What items are mandatory on a payslip?'] },
  { id: 'deduct', train: ['Maximum salary deduction allowed', 'Can we deduct more than half the salary?', 'Rules for recovering salary overpayment'], cat: 'Overtime & pay', q: 'How much can be deducted from salary?', k: 'deduction limit 50 percent advance loan overpayment',
    a: 'Total deductions in one salary period cannot exceed 50% of the salary. Exceptions include deductions for absence, recovering advances, loans or overpaid salary, and co-operative society payments. Final pay on termination may exceed 50%.',
    src: MOM + '/employment-practices/salary/salary-deductions', alts: ['Can we recover an overpayment in one month?', 'Is there a cap on payroll deductions?'] },
  { id: 'ph', train: ['Public holiday pay rules', 'Employee works on a public holiday, what to pay?', 'Number of paid public holidays'], cat: 'Overtime & pay', q: 'How is work on a public holiday paid?', k: 'public holiday 11 extra day off in lieu',
    a: 'There are 11 paid public holidays a year. Working on one earns an extra day of basic pay, or a day off in lieu by agreement, plus overtime beyond normal hours.',
    src: MOM + '/employment-practices/public-holidays-entitlement-and-pay', alts: ['Extra pay for working on National Day?', 'How many public holidays are there?'] },
  { id: 'notice', train: ['Statutory notice period by years of service', 'Notice period when resigning without a contract clause', 'How many weeks notice after 5 years?'], cat: 'Overtime & pay', q: 'What notice period applies if the contract does not say?', k: 'notice period resignation termination weeks service',
    a: 'Less than 26 weeks of service: 1 day. 26 weeks to under 2 years: 1 week. 2 to under 5 years: 2 weeks. 5 years or more: 4 weeks.',
    src: MOM + '/employment-practices/termination-of-employment/termination-with-notice', alts: ['Default notice for someone with 3 years of service?', 'How much notice if the contract is silent?'] },
  // ---------- Leave ----------
  { id: 'al', train: ['Annual leave entitlement first year', 'Statutory annual leave days by service', 'Maximum annual leave under Employment Act'], cat: 'Leave', q: 'How much annual leave does the Employment Act give?', k: 'annual leave days 7 14 entitlement',
    a: 'After 3 months of service: 7 days in the first year, plus 1 day for each further year, up to 14 days from year 8.',
    src: MOM + '/employment-practices/leave/annual-leave/eligibility-and-entitlement', alts: ['Leave days for a new hire?', 'What is the maximum statutory annual leave?'] },
  { id: 'sick', train: ['Sick leave entitlement in Singapore', 'Hospitalisation leave days', 'Paid medical leave after 6 months'], cat: 'Leave', q: 'How much sick leave and hospitalisation leave is given?', k: 'sick leave medical hospitalisation 14 60 outpatient',
    a: 'After 6 months of service: 14 days of outpatient sick leave and 60 days of hospitalisation leave (the 60 includes the 14). It is pro-rated from 3 months of service.',
    src: MOM + '/employment-practices/leave/sick-leave/eligibility-and-entitlement', alts: ['MC days for a staff with 1 year of service?', 'Is hospitalisation leave separate from sick leave?'] },
  { id: 'mat', train: ['Maternity leave entitlement', 'Government paid maternity leave reimbursement', 'How many weeks maternity leave for 3rd child?'], cat: 'Leave', q: 'How long is maternity leave?', k: 'maternity leave 16 weeks government paid',
    a: '16 weeks of government-paid maternity leave for a Singapore-citizen child. For the 1st and 2nd child the employer pays the first 8 weeks and is reimbursed for the last 8; from the 3rd child the government reimburses all 16.',
    src: MOM + '/employment-practices/leave/maternity-leave/eligibility-and-entitlement', alts: ['Who pays for maternity leave?', 'Weeks of maternity leave in Singapore?'] },
  { id: 'pat', train: ['Paternity leave entitlement 2026', 'Shared parental leave weeks', 'Father leave after child birth'], cat: 'Leave', q: 'How much paternity and shared parental leave is there?', k: 'paternity shared parental leave weeks 4 10',
    a: 'Fathers get 4 weeks of government-paid paternity leave. Shared parental leave is 10 weeks for Singapore-citizen children born on or after 1 Apr 2026 (6 weeks for births from 1 Apr 2025 to 31 Mar 2026).',
    src: MOM + '/employment-practices/leave/shared-parental-leave', alts: ['How many weeks can a father take off?', 'Did shared parental leave increase in 2026?'] },
  { id: 'cc', train: ['Childcare leave entitlement', 'Days of leave for parents of children under 7', 'Extended childcare leave'], cat: 'Leave', q: 'How many days of childcare leave are there?', k: 'childcare leave days 6 2 child under 7',
    a: '6 days a year per parent for a Singapore-citizen child under 7 (2 days for a non-citizen child), plus 2 days of extended childcare leave when the youngest child is 7 to 12.',
    src: MOM + '/employment-practices/leave/childcare-leave/eligibility-and-entitlement', alts: ['Childcare leave for a parent of a 5-year-old?', 'How much leave to care for young kids?'] },
  // ---------- Tax & other ----------
  { id: 'ir8a', train: ['IR8A submission deadline', 'Auto inclusion scheme employment income filing', 'When must employers submit IR8A to IRAS?'], cat: 'Tax & compliance', q: 'When is the IR8A / Auto-Inclusion Scheme deadline?', k: 'ir8a ais deadline 1 march employment income submission',
    a: 'Employment income for the previous year must be submitted by 1 March. The Auto-Inclusion Scheme is compulsory for employers with 5 or more employees.',
    src: 'https://ask.gov.sg/iras/questions/cmrjqb90800ch2o01cdvxauf4', alts: ['When do we file employee income with IRAS?', 'Is AIS compulsory for us?'] },
  { id: 'ir21', train: ['IR21 tax clearance rules', 'Foreign employee leaving Singapore tax clearance', 'Withhold money for foreign worker resigning'], cat: 'Tax & compliance', q: 'What must we do when a foreign employee leaves (IR21)?', k: 'ir21 tax clearance foreign leaving withhold money',
    a: 'File Form IR21 at least 1 month before the employee stops work or leaves Singapore, and withhold all money due to the employee from the day you know they are leaving.',
    src: 'https://ask.gov.sg/iras/questions/clq62gh08001613sh2j8en8zv', alts: ['Tax clearance for an Employment Pass holder resigning?', 'Do we hold the final pay of a departing foreigner?'] },
  { id: 'retire', train: ['Retirement age 2026', 'Re-employment age Singapore', 'What age can an employee be retired?'], cat: 'Tax & compliance', q: 'What are the retirement and re-employment ages?', k: 'retirement age 64 re-employment 69 july 2026',
    a: 'Since 1 Jul 2026 the minimum retirement age is 64 and the re-employment age is 69 (previously 63 and 68).',
    src: MOM + '/employment-practices/retirement', alts: ['Can we retire a 63-year-old now?', 'Until what age must we offer re-employment?'] },
  { id: 'lqs', train: ['Local qualifying salary 2026', 'LQS amount for work pass quota', 'Minimum salary for local workers to count for quota'], cat: 'Tax & compliance', q: 'What is the Local Qualifying Salary?', k: 'lqs local qualifying salary 1800 quota part-time 10.50',
    a: 'Since 1 Jul 2026 the Local Qualifying Salary is S$1,800 a month for full-time local workers and S$10.50 an hour for part-timers.',
    src: MOM + '/employment-practices/progressive-wage-model/local-qualifying-salary', alts: ['Minimum pay to count a local towards work pass quota?', 'Did LQS go up in July?'] },
  { id: 'wfa', train: ['Workplace Fairness Act start date', 'When will the Workplace Fairness Legislation apply?', 'Workplace fairness law effective date'], cat: 'Tax & compliance', q: 'When does the Workplace Fairness Act take effect?', k: 'workplace fairness act grievance 2027',
    a: 'It is expected to take effect at the end of 2027. Rule Watch is tracking it and will draft the changes when the date is confirmed.',
    src: 'https://www.tal.sg/tafep/resources/articles/2026/are-you-ready-for-the-workplace-fairness-act', alts: ['Is the fairness law in force yet?', 'When do workplace fairness rules start?'] },
  // ---------- PayShield ----------
  { id: 'ps-score', train: ['Trust Score formula', 'How does PayShield score a record?', 'What do Clear, Review and Held thresholds mean?'], cat: 'Using PayShield', q: 'How is the Trust Score calculated?', k: 'trust score formula weights 40 35 25 thresholds clear review held',
    a: 'Risk = 0.40 × pay signal + 0.35 × bank signal + 0.25 × attendance signal, plus 0.03 for each extra strong signal. Trust Score = 100 × (1 − risk). 80–100 is Clear, 50–79 Review, below 50 Held. Hard overrides always win.',
    src: 'PayShield · Validators › Trust Score', alts: ['Why did someone get a score of 64?', 'What score means a record is held?'] },
  { id: 'ps-held', train: ['Why did PayShield hold a payment?', 'Reasons a salary is put on hold', 'Does a held record stop other employees being paid?'], cat: 'Using PayShield', q: 'Why is a salary held?', k: 'held hold force override unconfirmed bank fraud network',
    a: 'A record is held when its Trust Score is below 50, or by a hard override: a Fraud Network match, or a new bank account the employee has not confirmed close to payday. Only that record waits; everyone else is paid.',
    src: 'PayShield · Validators › Bank change', alts: ['What makes PayShield stop a payment?', 'Will a hold delay the whole pay run?'] },
  { id: 'ps-release', train: ['How to release a held payment', 'Approve a held salary', 'Who approves the release of a hold?'], cat: 'Using PayShield', q: 'How do I release a held salary?', k: 'release held approver second confirm employee',
    a: 'Confirm with the employee on a second channel (the phone number on file before the change, or an HR call). Then a second approver releases or rejects it. Every step is logged.',
    src: 'PayShield · Approvals', alts: ['Who can unlock a held payment?', 'Steps to pay a held employee?'] },
  { id: 'ps-bank', train: ['How does the bank change check work?', 'Bank account change risk points', 'Why was a new bank account flagged?'], cat: 'Using PayShield', q: 'What does the bank-change check look at?', k: 'bank change points 30 days device confirm shared cooling off',
    a: 'Change in the last 30 days +0.3; within 7 days of payday +0.2; from a new device +0.2; not confirmed on a second channel +0.2. A shared account always goes to Review; a Fraud Network match is held. New accounts have a 3-day cooling-off.',
    src: 'PayShield · Validators › Bank change', alts: ['Why was Daniel’s bank change flagged?', 'What signals the bank check uses?'] },
  { id: 'ps-network', train: ['How does the Fraud Network work?', 'Is the Fraud Network sharing our data?', 'What is shared with other companies?'], cat: 'Using PayShield', q: 'What is the Fraud Network and is it private?', k: 'fraud network fingerprint hmac share companies privacy',
    a: 'When a company confirms an account was used in fraud, PayShield shares only a keyed one-way fingerprint (HMAC) of the account number, never the number, a name or the company. Another company adding that account is held for review.',
    src: 'PayShield · Fraud Network', alts: ['Do other companies see our employee data?', 'How does one company warn the others?'] },
  { id: 'ps-ai', train: ['Does PayShield send salary data to the AI?', 'Is the AI safe for personal data?', 'What data does the language model receive?'], cat: 'Using PayShield', q: 'Does the AI see personal data?', k: 'ai personal data masked privacy token pdpa',
    a: 'No. Checks run inside PayShield. The language model only receives a masked record (a token, flag codes and a few numbers), and every number in its answer is checked. Payroll works with the AI switched off.',
    src: 'PayShield · Security', alts: ['Is employee salary sent to the AI?', 'Is the assistant PDPA safe?'] },
  { id: 'ps-model', train: ['What does PayShield Risk Model find?', 'How does the model detect salary creep?', 'Can the model hold or change pay?'], cat: 'Using PayShield', q: 'What does our own model check?', k: 'model risk creep peers approver machine learning own',
    a: 'PayShield Risk Model v1 re-checks records the rules cleared and finds slow patterns such as salary creep and raises far above peers. It can only add a Review flag; it never clears, holds or changes pay.',
    src: 'PayShield · Our own model', alts: ['How did PayShield catch Ravi’s raise?', 'What is the machine-learning model for?'] },
  { id: 'ps-rulewatch', train: ['How does Rule Watch work?', 'Who approves rule updates?', 'How are CPF rule changes applied in PayShield?'], cat: 'Using PayShield', q: 'How does PayShield keep up with MOM, CPF and IRAS changes?', k: 'rule watch update draft verify what-if version',
    a: 'Rule Watch reads official updates and drafts the rule change. A named compliance owner checks value, date and source before it is published. A what-if shows each company the cost before the rule starts.',
    src: 'PayShield · Rule Watch', alts: ['Who updates the CPF ceiling in the system?', 'How are new rules approved?'] },
  { id: 'ps-preflight', train: ['What checks run in the pre-flight check?', 'What happens before the pay run is approved?', 'List the six PayShield checks'], cat: 'Using PayShield', q: 'What does the pre-flight check do?', k: 'pre-flight checks six employee pay rules bank attendance ai',
    a: 'Before a pay run can be approved, every employee goes through 6 checks: employee record, pay calculation, statutory rules, bank details, attendance proof and the AI pattern check. Problems are fixed and re-checked first.',
    src: 'PayShield · Pre-flight check', alts: ['What is checked before payroll is approved?', 'Which validations run before pay day?'] },
  // ---------- added with the guard pages (checked against MOM, CPF and IRAS pages, October 2026) ----------
  { id: 'share-award', train: ['Do we pay CPF on employee stock awards?', 'CPF on RSU vesting', 'Are share options subject to CPF?'], cat: 'CPF', q: 'Is CPF due on share awards or share options?', k: 'share award stock options rsu esop esow shares appendix 8b cash proceeds',
    a: 'If the shares are given in the employee’s own name, no CPF is due. If the employer sells the shares and pays the employee the cash, CPF is due on that cash. Either way the gain is taxable and reported in IR8A Appendix 8B.',
    src: 'https://www.iras.gov.sg', alts: ['Is CPF payable when RSUs vest in shares?', 'Do share option gains attract CPF contributions?'] },
  { id: 'aws', train: ['Is the 13th month bonus compulsory by law?', 'Do we have to pay AWS?', 'How is AWS prorated for new staff?'], cat: 'Overtime & pay', q: 'Is the Annual Wage Supplement (AWS) required by law?', k: 'aws 13th month annual wage supplement mandatory compulsory law legal requirement required prorate contract',
    a: 'No. AWS is not required by law. It is paid when the employment contract, company handbook or collective agreement says so, and proration for less than 12 months follows those terms. For CPF it counts as an Additional Wage.',
    src: MOM + '/faq/salary/am-i-entitled-to-aws-and-how-is-it-calculated', alts: ['Must employers give a 13th month salary?', 'Is AWS a legal requirement in Singapore?'] },
  { id: 'prorate', train: ['How do I prorate a new joiner?', 'Salary for someone who started partway through the month', 'Pay for an incomplete month formula'], cat: 'Overtime & pay', q: 'How is pay worked out for an incomplete month?', k: 'prorate proration incomplete month joiner joined started start new employee mid month working days formula',
    a: 'Monthly gross rate of pay × number of days actually worked in the month ÷ number of working days in that month. Example: S$4,800 × 12 ÷ 22 = S$2,618.18.',
    src: MOM + '/employment-practices/salary/monthly-and-daily-salary', alts: ['What is the MOM formula for partial month salary?', 'How much do we pay an employee who started on the 15th?'] },
  { id: 'final-pay', train: ['When must final salary be paid after resignation?', 'Payment deadline for staff who quit without notice', 'Deadline for final salary on dismissal'], cat: 'Overtime & pay', q: 'When is final salary due when someone leaves?', k: 'final salary resign resignation quit leaver dismissed termination notice deadline',
    a: 'If the employee resigns and serves notice, on the last day of employment. If they resign without notice, within 7 days after the last day. If dismissed or terminated by the employer, on the last day, or within 3 working days if that is not possible.',
    src: MOM + '/employment-practices/salary/paying-salary', alts: ['By when do we pay someone who quit?', 'How soon must a leaver be paid?'] },
  { id: 'ps-agent-run', train: ['Can the agent check all of payroll for me?', 'What does the agent do when I ask it to check payroll?', 'Can PayShield Agent approve the pay run?'], cat: 'Using PayShield', q: 'What happens when I ask the agent to check the pay run?', k: 'agent check pay run score tools apply fixes record',
    a: 'It runs every guard, our own model, compliance and the last 6 runs as read-only tools, then reports a Pay Score and suggested fixes with their rule and history. You confirm and apply the fixes; a second person approves. Every run is recorded.',
    src: 'PayShield · Agent', alts: ['Does the agent pay employees by itself?', 'How does the agent run PayShield?'] },
];

export const CATEGORIES = [...new Set(KB.map((x) => x.cat))];

/* ---------- Retrieval (BM25) ---------- */
const STOP = new Set('a an the is are was were be to of for in on at by with and or what how much many when who whom which why do does did can could should must we our i my me it this that there their his her from as per about than into does any not no yes'.split(' '));
const SYN = { ot: 'overtime', mc: 'sick', ow: 'ordinary', aw: 'additional', bonus: 'additional', bonuses: 'additional', levy: 'sdl', hold: 'held', stop: 'held', unlock: 'release', mom: 'mom', salaries: 'salary', wages: 'wage', pay: 'pay' };
export function tokens(s) {
  return String(s).toLowerCase().replace(/[’']/g, '').split(/[^a-z0-9.$]+/).map((w) => w.replace(/^\$|\.$/g, ''))
    .filter((w) => w && !STOP.has(w)).map((w) => SYN[w] || w).map((w) => (w.length > 4 ? w.replace(/(ing|ed|es|s)$/, '') : w));
}
// Index: the answer, plus every training question (the "learned" phrasings). Score = best question match + answer match.
const QDOCS = KB.map((x) => [x.q, ...(x.train || [])].map((q) => tokens(`${q} ${x.k}`)));
const ADOCS = KB.map((x) => tokens(x.a));
const ALL = [...QDOCS.flat(), ...ADOCS];
const N = ALL.length, avgdl = ALL.reduce((a, d) => a + d.length, 0) / N;
const DF = {};
for (const d of ALL) for (const t of new Set(d)) DF[t] = (DF[t] || 0) + 1;
function bm25(qt, d) {
  let s = 0;
  for (const t of qt) {
    const f = d.filter((x) => x === t).length; if (!f) continue;
    const idf = Math.log(1 + (N - DF[t] + 0.5) / (DF[t] + 0.5));
    s += idf * (f * 2.2) / (f + 1.2 * (0.25 + 0.75 * d.length / avgdl));
  }
  return s;
}

/** Top matches for a question: [{entry, score}] */
/** Query understanding: an age in a CPF question picks the right age band. */
export function rewrite(q) {
  const m = String(q).match(/(\d{2})[- ]?(?:year|yr)s?[- ]?old|aged (\d{2})|age (\d{2})/i);
  if (!m || !/cpf|contribut/i.test(q)) return q;
  const age = Number(m[1] || m[2] || m[3]);
  return age > 55 ? `${q} senior older rates above 55` : `${q} aged 55 and below rate`;
}

export function search(question, k = 3) {
  const qt = tokens(rewrite(question));
  return KB.map((x, i) => ({ entry: x, score: Math.max(...QDOCS[i].map((d) => bm25(qt, d))) + 0.5 * bm25(qt, ADOCS[i]) }))
    .sort((a, b) => b.score - a.score).slice(0, k);
}

/** Held-out evaluation: do paraphrased questions retrieve the right answer first? */
export function evaluateRetrieval() {
  const byCat = {};
  let ok = 0, total = 0, top3 = 0;
  for (const x of KB) for (const alt of x.alts) {
    const r = search(alt, 3), hit = r[0]?.entry.id === x.id;
    total++; if (hit) ok++; if (r.some((m) => m.entry.id === x.id)) top3++;
    byCat[x.cat] = byCat[x.cat] || { ok: 0, total: 0 };
    byCat[x.cat].total++; if (hit) byCat[x.cat].ok++;
  }
  return { ok, total, rate: ok / total, top3, top3Rate: top3 / total, byCat };
}

/** Starter fine-tuning set (chat format, one JSON object per line). */
export function trainingJSONL() {
  const sys = 'You are PayShield Agent. Answer Singapore payroll questions from verified sources only, briefly, and cite the source.';
  return KB.flatMap((x) => [x.q, ...(x.train || [])].map((q) => JSON.stringify({ messages: [{ role: 'system', content: sys }, { role: 'user', content: q }, { role: 'assistant', content: `${x.a} Source: ${x.src}` }] }))).join('\n') + '\n';
}
