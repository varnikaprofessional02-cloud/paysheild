# PayShield AI — Phase 1 Technical Assessment

Date: 2026-10-16. Scope: read-only analysis of `times-payroll-api`, `times-pay-engine-api`,
`times-workerprocessor`, `times-employee-api`, `times-tenantstore-api`, `times-identity-provider-api`,
`times-portal-ui`, `times-data-workspace`, and the tenant DB schema snapshot (pg_dump 2026-09-28).

**Hard constraint:** all PayShield code lives in `SourceCodes/AI Model`. No other repository is
modified. Integration into existing services ships as drop-in projects plus guides (see `docs/05_INTEGRATION_GUIDE.md`).

---

## 1. How the existing system works (facts the design relies on)

### 1.1 Tenancy
| Concept | Reality in code |
|---|---|
| Tenant | A **subscription**. One row in tenant-store `tenant.tenant` (`identifier` = subscription uid, immutable; `db_name` = `times-{subdomain}`). |
| Database | **One PostgreSQL database per subscription**, cloned from template `times-template-db-readonly` (`TenantRepository.cs:78-100`). All tenant DBs sit on one Azure PG server. |
| Company | A tenant DB holds **many** `company.company` rows (master + subsidiaries). `company.uid` is immutable; `code` and `uen` are mutable/business keys. |
| Keycloak | One realm per tenant (`tenant.tenant_identity_provider.instance_code`). Access tokens carry `tenant_id` (= subscription uid). |
| Company context | Fixed by the IdP's second token (`times-authorization-token`, claim `CompanyId` = company uid, `Functions`, `Roles`). |

**Consequence:** "Each company has its own model" is implemented as one model per
`(subscription uid, company uid)`. Both are immutable GUIDs; domain/subdomain/company code are never used as keys.
Training data for a company is read with `WHERE pay_period.company_id = :company_id` inside that tenant's DB,
so neither another company's nor another tenant's records can enter a training set.

### 1.2 Payroll workflow
```
POST /PayRun (payroll-api) ─► payroll.pay_run + pay_period ─► Service Bus "payroll-process-requested"
     ─► times-workerprocessor (Azure Function, isolated) ─► times-pay-engine-api POST /api/Transactions
     ─► worker POSTs result to payroll-api /PayRecord (AllowAnonymous)
     ─► CreatePayRecordCommandHandler: one TX writes all payroll.pay_record rows (+ pay_period_contribution)
     ─► MediatR PayrollProcessCompletedEvent  (in-process only)
Lock: pay_record.status Completed(2) → Locked(4) per record (emailed code); pay_period.is_lock per period.
No approval workflow exists. Re-run/modify/trial-convert: records → Processing(1) → worker → /PayRecord/reprocess.
```
- Statuses (`PayRunStatusEnum`): 1 Processing, 2 Completed, 3 Failed, 4 Locked, 5 Trial (derived for runs only), 6 Skipped.
- Pay run status is **derived** from its records; `pay_run.is_trial` flags trial runs (column is newer than the schema dump).
- Period = `payroll.pay_period.value` (`'MM/YYYY'` text). Ordering must use `to_date(value,'MM/YYYY')`.
- Cycles (`payroll.lk_payroll_cycle.code`): `MID`, `END`, `SPECIAL`, `BONUS`, `WEEK`, `CUSTOM`.

### 1.3 Where payroll figures live
`payroll.pay_record` (one row per user + contract + run) has columns `basic_salary` (earned this cycle),
`total_allowance`, `total_deduction` (non-statutory), `total_cpf` (**employee + employer**), `total_payout` (net),
`is_new_hire`, `is_resignee`, and `data_processed` (json, camelCase) with:

| Need | JSON path (verified in `PayRecordFactory`, `PayPeriodContributionWriter`, DB functions) |
|---|---|
| Contractual basic | `payRecord.basicSalaryCalculationResult.basicSalary.amount` |
| Earned basic | `payRecord.basicSalaryCalculationResult.amount.amount` (= column `basic_salary`) |
| Allowance/deduction lines | `payRecord.allowanceDeductionCalculationResult.payComponentResults[]` → `amount.amount`, `payComponent.payCode.code/description`, `payComponent.isEarning`, `cpfWageType` (string), `recurringMethodType.recurringMethodType` (int), `amountType.*` |
| Back pay | `payRecord.backPayCalculationResult.amount.amount` |
| Engine gross | `payRecord.grossPay.amount` (= basic + allowances − deductions + back pay) |
| Net | `payRecord.nettPay.amount` (= column `total_payout`) |
| CPF | `payRecord.cpfCalculationResult.totalEmployeeContribution.amount` / `totalEmployerContribution.amount`; **null object ⇒ not assessed (Mid Month policy)** |
| Funds / SDL | `payRecord.communityFundsCalculationResult.totalAmount.amount`, `payRecord.sdlCalculationResult.amount.amount` |
| Engine statutory flags | `employee.statutorySummary.hasAWExcess / hasAWShortfall / awExcess / awShortfall` (employee-level, duplicated on every contract row) |
| Contract facts | `employeeContract.hiredDate`, `resignationDate`, `residencyStatus`, `dateOfBirth` (PII — never leaves the service) |

Gaps that shape the anomaly design:
- **There is no overtime data anywhere** (no OT hours/amount in the engine; `PayslipDataBuilder` has a TODO). `allowance_deduction.ot` means "affects OT rate", not "is overtime".
  ⇒ Overtime detection works only for pay codes configured per company in `payshield.company_setting.overtime_pay_codes`
  (hours = `amountType.frequency` when the code's unit is Hour), or when a caller supplies `overtimeHours`. Otherwise it reports "not available".
- Bonus = `company.allowance_deduction.bonus_type_id → allowance_deduction_bonus_type.code IN ('BONU','PREBONU')` (latest year per code); AW = `cpfWageType == 'Additional'`.
- Stable per-item key across months = **`payCode.code`** (company scoped). `payComponent.uid` changes on contract renewal.
- **Salary revisions have no approval state.** A revision = a non-`CONSTART` `employee.career_progression` row. Base salary follows `effective_date`; back pay follows `pay_effective_date`.
- Statutory (CPF/funds/SDL) is computed deterministically by `EmployerStatutoryService` in the pay engine. PayShield **never recomputes CPF**; it only checks consistency of engine output against the employee's own history and surfaces the engine's own flags.

### 1.4 Auth & authorization
- Keycloak RS256 tokens validated per realm (`{authority}/realms/{realm}`), audience validation is off today.
- payroll-api has **no function/permission checks** (roles only); the only Pay-module code is function `PAY` with `View`
  (`ProcessingRequestLiveEvents.PayFunctionCode`). Permission is evaluated by DB function
  `security.get_permissions_for_principle_on_resource(resource, 'function', principle, company_uid)` over principles
  `user_uid`, `user_uid@company_uid` and role names.
- Employee-level visibility = Data Security rules evaluated by `Times.AccessFilter.Engine` (module `Pay`); no rule ⇒ nobody visible; Owner/Sub Owner exempt.
- Worker → payroll-api callbacks are anonymous and pick the tenant from the body. **PayShield does not copy that pattern.**

### 1.5 Messaging, hosting, conventions
- Azure Functions v4, .NET 8 isolated, `ServiceBusTrigger` on plain queues, `AutoCompleteMessages=false`, dead-letter on bad body, `IsLastAttempt` from `DeliveryCount`.
- Publishers: singleton `ServiceBusClient`, camelCase JSON, `ApplicationProperties` `tenantUid`/`actorUid`, deterministic `MessageId`.
- APIs: Clean Architecture, MediatR + ErrorOr + FluentValidation + Dapper (no EF), Serilog. Tests: MSTest + Moq + FluentAssertions.
- Deploy: Azure DevOps YAML → Docker Hub image per environment → Azure App Service. Secrets are committed in appsettings today (PayShield must not do this).
- DB changes ship as hand-run, idempotent SQL scripts per tenant DB. New tenants clone `times-template-db-readonly`, so **PayShield DDL must also be applied to the template**.
- No Python, ML or Azure OpenAI code exists. LLM prior art: `times-data-workspace` (OpenAI SDK, strict JSON output, redaction placeholders, "context is data, not instructions").

---

## 2. Reusable components
| Existing | How PayShield reuses it |
|---|---|
| `payroll.pay_record.data_processed` + columns | Sole source of payroll figures (no duplication of payroll data). |
| `payroll.pay_period` / `pay_run` / `lk_payroll_cycle` | Period ordering, cycle-aware baselines, trial exclusion. |
| `employee.career_progression` | Salary-revision evidence (effective vs pay-effective dates). |
| `employee.contract_allowance_deduction` + `company.allowance_deduction` (+ bonus type, unit) | Configured recurring lines (missing-allowance), bonus/AW/hourly classification. |
| Engine statutory output + `statutorySummary` flags | Authoritative CPF; PayShield only checks consistency. |
| `security.get_permissions_for_principle_on_resource` | PAY permission check, evaluated in the tenant DB. |
| `Times.AccessFilter.Engine` | Ported to Python (`app/security/access_filter.py`) for employee-level filtering. |
| tenant-store `tenant.tenant` (+ `tenant_identity_provider`) | Tenant → DB name and Keycloak realm. |
| Worker/publisher conventions | Copied in the drop-in .NET projects. |

## 3. New components (all under `AI Model/`)
| Component | Path |
|---|---|
| Python FastAPI service (training, inference, rules, risk engine, assistant, feedback) | `payshield-ai/` |
| Service Bus worker (analysis + training queues) | `payshield-ai/app/messaging/worker.py` (same image, different command) |
| Tenant DB migration `payshield` schema + grants + rollback | `database/` |
| .NET client library (`IPayShieldService`) | `dotnet/src/Times.PayShield.Client` |
| .NET Azure Functions (sweeper, scheduled retraining, job recovery) | `dotnet/src/Times.PayShield.Functions` |
| Drop-in payroll-api push trigger + proxy controller (not compiled into payroll-api) | `dotnet/integration/payroll-api` |
| Deployment (Dockerfile, Container Apps Bicep, pipeline, env examples) | `deploy/`, `payshield-ai/Dockerfile` |

## 4. Database changes
New schema `payshield` in every tenant DB (and the template DB). Nothing in existing schemas is altered.
Tables: `company_setting`, `model_registry`, `training_job`, `analysis`, `anomaly`, `feedback`, `lk_feedback_outcome`,
`run_watermark`, `assistant_audit`. A dedicated login `payshield_svc` gets SELECT on the payroll/employee/company/security
tables it reads and DML only on `payshield.*`. See `database/README.md`.

## 5. Integration points
1. **Trigger (no change to payroll-api):** a DB sweeper detects runs whose `pay_record` set has settled
   (no `status_id = 1`, fingerprint changed) and enqueues `payshield-analysis-requested`. This uses the same marker
   payroll-api already uses for derived run status.
2. **Push trigger (optional, later):** drop-in `INotificationHandler<PayrollProcessCompletedEvent>` for payroll-api that publishes the same message.
3. **Read path for UI:** payroll-api (or the portal directly) calls PayShield `GET /api/v1/payroll/runs/{payRunUid}/analysis`.
4. **Finalization stays untouched:** PayShield never blocks lock/approval; findings are advisory.

## 6. Security considerations
- Tenant from the **verified** token only (Keycloak issuer must equal the tenant's realm issuer); company from header, then validated in DB (company belongs to this subscription and the user has `PAY:View` on it).
- Service calls use Entra client-credentials (app role `PayShield.Service`, allow-listed app ids); tenant headers are honoured only for those principals. A shared-secret mode exists for local dev and is refused when `PAYSHIELD_ENV=production`.
- Model artifacts: tenant/company-scoped blob paths, SHA-256 recorded in the tenant DB registry and checked before deserialisation, cache keyed by `(tenant, company, model uid, sha256)`.
- Employee-level filtering on every list/count/assistant tool; the LLM gets pseudonymous employee refs and no names, emails, NRIC, DOB, bank data.
- The assistant is read-only, has a fixed tool set (no SQL generation), and cannot lock, approve or modify payroll.
- No payroll values in logs (only ids, counts, durations).

## 7. Implementation sequence
1. DB migration + local test harness (PG 18 + schema dump).
2. Domain model, parsing of `data_processed`, payroll read repository.
3. Feature engineering, baselines, Isolation Forest, evaluation, registry, artifact store.
4. Deterministic rules + risk engine + analyzer orchestration.
5. Security (Keycloak, Entra, permissions, access filter), FastAPI routes, worker.
6. LLM explanations + assistant.
7. Feedback + controlled retraining + sweeper + schedules.
8. .NET client/functions/drop-ins, Docker/Azure deployment, tests, docs, evaluation report.

## 8. Open product questions (do not block the build)
1. Which pay codes are overtime for each company? (configure `overtime_pay_codes`; detection is off until set)
2. Should salary revisions get an approval workflow? Today "approved" can only mean "row exists".
3. Should a dedicated `PAY_PAYSHIELD` feature be created instead of reusing `PAY:View` (+ `PAY:Edit` for training/feedback)?
4. Worker relay drops `basicSalaryCalculationResult.adjustments` and `payrollCycleType` (`IPayrollProcessApi.cs:180-206`); PayShield uses `pay_run.pay_cycle_id` instead.
