// Versioned statutory rule library (Singapore). Values verified against official pages in October 2026.
// Each pay run records which versions it used. Rule Watch proposes new versions; a named reviewer publishes them.
export const RULES = [
  { code: 'CPF_OW_CEILING', name: 'CPF Ordinary Wage ceiling', value: 8000, unit: 'S$ / month', version: 'v2026.1', from: '1 Jan 2026', prev: 'S$7,400 in 2025', src: 'cpf.gov.sg' },
  { code: 'CPF_AW_CEILING', name: 'CPF Additional Wage ceiling', value: 'S$102,000 − OW subject to CPF', unit: 'per year', version: 'v2026.1', from: '1 Jan 2026', src: 'cpf.gov.sg' },
  { code: 'CPF_RATE_55', name: 'CPF rate, age 55 and below', value: '17% employer · 20% employee', unit: 'wages > S$750', version: 'v2026.1', from: '1 Jan 2026', src: 'cpf.gov.sg' },
  { code: 'CPF_RATE_55_60', name: 'CPF rate, above 55 to 60', value: '16% employer · 18% employee', unit: 'wages > S$750', version: 'v2026.1', from: '1 Jan 2026', prev: '15.5% · 17% in 2025', src: 'cpf.gov.sg' },
  { code: 'CPF_RATE_60_65', name: 'CPF rate, above 60 to 65', value: '12.5% employer · 12.5% employee', unit: 'wages > S$750', version: 'v2026.1', from: '1 Jan 2026', prev: '12% · 11.5% in 2025', src: 'cpf.gov.sg' },
  { code: 'SDL', name: 'Skills Development Levy', value: '0.25% of first S$4,500 (min S$2, max S$11.25)', unit: 'per employee / month', version: 'v2024.1', from: 'current', src: 'gobusiness.gov.sg' },
  { code: 'MOM_OT_CAP', name: 'Overtime cap', value: 72, unit: 'hours / month', version: 'v2024.1', from: 'current', src: 'mom.gov.sg' },
  { code: 'MOM_OT_RATE', name: 'Minimum overtime rate', value: 1.5, unit: '× hourly basic rate', version: 'v2024.1', from: 'current', src: 'mom.gov.sg' },
  { code: 'MOM_PART4', name: 'Overtime coverage (Part IV)', value: 'Workmen ≤ S$4,500 · non-workmen ≤ S$2,600', unit: 'basic monthly salary', version: 'v2024.1', from: 'current', src: 'mom.gov.sg' },
  { code: 'MOM_PAY_DUE', name: 'Salary payment deadline', value: '7 days (salary) · 14 days (OT)', unit: 'after salary period', version: 'v2024.1', from: 'current', src: 'mom.gov.sg' },
  { code: 'MOM_DEDUCTION_CAP', name: 'Salary deduction limit', value: '50%', unit: 'of salary per period (with exceptions)', version: 'v2024.1', from: 'current', src: 'mom.gov.sg' },
];
export const rule = (code) => RULES.find((r) => r.code === code);
