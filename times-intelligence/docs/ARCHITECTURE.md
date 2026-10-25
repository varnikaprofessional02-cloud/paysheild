# PayShield AI — Architecture & Implementation Contract

This document is the binding contract for every module. Read `01_TECHNICAL_ASSESSMENT.md` first for the
facts about the existing system. Shared types live in:
`payshield-ai/app/domain/enums.py`, `app/domain/models.py`, `app/core/config.py`, `app/core/tenant_context.py`,
`app/db/interfaces.py`, and the DB contract `database/migrations/V001__payshield_schema.sql`.
**Do not change those files' public names/signatures without updating every user**; adding optional fields is fine.

## 0. Ground rules (apply to all code)
1. Python 3.12, type hints everywhere, `from __future__ import annotations`. pandas 3.x / numpy 2.x / scikit-learn 1.9 / xgboost 3.x / FastAPI 0.14x / pydantic 2 / psycopg 3.
2. No payroll values, names, emails, NRIC or salaries in logs. Log ids (uids), counts, durations, statuses only. Use `logging.getLogger(__name__)` with `extra={...}` structured fields.
3. `None` = not available. Never coerce missing money to 0 except where a formula explicitly documents it.
4. All SQL is parameterised (`%(name)s` with psycopg). No string-formatted identifiers except from fixed allow-lists.
5. Every company-scoped DB method includes `company_id` in its WHERE clause.
6. Code comments are lowercase explanatory sentences saying *why* (house style). Keep functions small; no dead code; no pseudocode; no `TODO` without an issue reason.
7. Tests: pytest, synthetic data only (`tests/factories.py`), no network. DB integration tests are marked `@pytest.mark.pg` and use the fixture in `tests/pg/conftest.py` (skipped when PostgreSQL binaries are unavailable).

## 1. Layout (`AI Model/`)
```
docs/                         assessment, architecture, ML design, risk scoring, API, deployment, integration, evaluation
database/
  migrations/V001__payshield_schema.sql
  grants/payshield_svc_grants.sql          role + least-privilege grants (per tenant DB + template)
  rollback/V001__rollback.sql
  tenantstore/payshield_svc_tenantstore_grants.sql
  test/                                     local-only helpers: missing newer columns, tenant-store minimal DDL
  README.md
payshield-ai/
  app/
    main.py                     FastAPI app factory (create_app), exception handlers, routers
    core/config.py              Settings (given)
    core/tenant_context.py      TenantContext (given)
    core/logging.py             JSON logging + correlation id + optional App Insights
    core/errors.py              PayShieldError hierarchy -> problem+json
    core/security.py            Keycloak + Entra + shared-secret token validation (JWKS cache)
    security/permissions.py     PAY permission + company access checks via tenant DB
    security/access_filter.py   port of Times.AccessFilter.Engine (Data Security rules)
    db/interfaces.py            Protocols + record dataclasses (given)
    db/connection.py            per-database psycopg pools (lazy, bounded), Entra token password option
    db/tenant_resolver.py       tenant-store lookup with TTL cache
    db/payroll_repository.py    PostgresPayrollReadRepository
    db/payshield_repository.py  PostgresPayShieldRepository
    db/sql/                     .sql files loaded by name (optional)
    data/parsing.py             data_processed JSON -> PayRecordSnapshot/PayItem
    data/observations.py        group records into Observations (user, contract, cycle, period)
    data/feature_extractor.py   FEATURE_COLUMNS + build_features(current, history)
    data/dataset_builder.py     chronological training dataset from history (no leakage)
    data/preprocessing.py       sklearn ColumnTransformer/pipeline pieces
    data/synthetic.py           synthetic company generator (snapshots) + data_processed JSON builder
    ml/baseline.py              robust statistics (median/MAD), robust z, expected value + interval
    ml/anomaly_detector.py      IsolationForest wrapper + percentile calibration + contributions
    ml/expected_value.py        optional XGBoost quantile regressor for expected net/gross
    ml/injection.py             synthetic anomaly injection for evaluation
    ml/evaluator.py             chronological evaluation, IF vs baseline, gate decision
    ml/trainer.py               end-to-end company training -> ModelBundle
    ml/model_bundle.py          ModelBundle dataclass + (de)serialisation with manifest
    ml/artifact_store.py        LocalArtifactStore / AzureBlobArtifactStore
    ml/model_registry.py        versioning, activation gate, rollback, secure cached loading
    ml/predictor.py             score observations with a bundle (or baseline only)
    rules/engine.py             RuleEngine running all rules; rules/*.py one module per family
    services/risk_engine.py     combine rule + ML + baseline into Findings with risk scores
    services/payroll_analyzer.py  orchestrates one pay-run analysis (pure; repositories injected)
    services/analysis_service.py  persistence + idempotency + fingerprint around the analyzer
    services/training_service.py  job lifecycle (claim, heartbeat, train, register, gate, activate)
    services/feedback_service.py
    services/sweeper_service.py   detect settled pay runs, enqueue analysis
    services/scheduler_service.py scheduled retraining fan-out, stale job recovery
    llm/client.py               LlmClient protocol, AzureOpenAiClient, DisabledLlmClient
    llm/redaction.py            pseudonymous employee refs + PII scrubbing
    llm/tools.py                read-only assistant tools bound to a TenantContext
    llm/prompts.py
    services/explanation_service.py  deterministic + LLM explanation of a finding
    services/assistant_service.py    question answering with tool loop + audit + fallback
    messaging/publisher.py      ServiceBusPublisher / InlinePublisher
    messaging/worker.py         Service Bus consumer process (analysis + training queues)
    api/deps.py                 FastAPI dependencies: settings, context, repositories, services
    api/routes/{health,models,training,prediction,feedback,assistant,internal}.py
    schemas/{requests,responses}.py  pydantic API models (camelCase aliases)
  tests/ ...  scripts/ ...  Dockerfile  requirements.txt  requirements-dev.txt  pyproject.toml  .env.example  README.md
dotnet/
  Times.PayShield.sln
  src/Times.PayShield.Client/        IPayShieldService, typed HttpClient, token providers, ErrorOr results
  src/Times.PayShield.Functions/     .NET 8 isolated Functions: sweeper/retraining/recovery timers
  tests/Times.PayShield.Client.UnitTests/   MSTest + Moq + FluentAssertions
  integration/payroll-api/           drop-in files for times-payroll-api (NOT compiled here)
deploy/  bicep/, pipelines/, env/
```

## 2. Request context & security (core/security.py, security/*, api/deps.py)
### 2.1 User calls (Keycloak)
1. `Authorization: Bearer <keycloak access token>`; header `X-Company-Uid: <company.company.uid>` (required for company-scoped endpoints).
2. Decode **unverified** claims only to read `tenant_id` and `iss`. Resolve `TenantInfo` via `TenantResolver.get_by_uid(tenant_id)`; unknown → 401.
3. Expected issuer = `{keycloak.authority}/realms/{tenant.realm}`. Verify signature with that realm's JWKS (cache by realm, TTL, refetch once on unknown `kid`), `exp`/`nbf` with skew, `iss == expected` exactly, audience only if `keycloak.audiences` non-empty, alg in {RS256, RS384, RS512, PS256} (never `none`/HS*).
   ⇒ A token from realm A carrying `tenant_id` of B fails because B's issuer differs.
4. User uid = first present claim from `keycloak.user_uid_claims` (default `["sub"]`, matching
   `CurrentUserProvider` in times-employee-api: `NameIdentifier ?? sub`). The value must be a GUID that exists in
   `security."user".uid` (`PayrollReadRepository.get_user_id_by_uid`) or → 403.
5. Company: `get_company_by_uid(X-Company-Uid)`; must exist and `subscription_uid == tenant_uid` → else 403 (same response for "not found" and "other tenant": `COMPANY_NOT_ACCESSIBLE`).
6. `user_has_company_access(user_uid, company_id)` (security.user_company active) → else 403.
7. Permissions: `get_function_permissions(settings.pay_function_code, [user_uid, f"{user_uid}@{company_uid}", *role_names], company_uid)`.
   Role names come from token claim `realm_access.roles` **and** DB roles are resolved by the DB function itself (it accepts role names as principals).
   Require `view` for read endpoints and `edit` (settings.manage_permission) for train/activate/rollback/feedback.
8. Access scope: `AccessFilterService.visible_user_ids(user_uid, company, module=settings.data_security_module)` → `AccessScope`.

### 2.2 Service calls (Entra client credentials)
`Authorization: Bearer <entra token>`; headers `X-Tenant-Uid`, `X-Company-Uid`. Token must be valid for
`https://login.microsoftonline.com/{entra_tenant_id}/v2.0` (also accept v1 issuer `https://sts.windows.net/{tid}/`),
`aud == service_auth.entra_audience`, `roles` contains `service_auth.required_role`, and `azp`/`appid` in `allowed_app_ids`.
Then tenant from `X-Tenant-Uid` (must exist in tenant store), company via (5). AccessScope(all_users=True).
`shared_secret` mode (local/dev only): header `X-PayShield-Service-Key` compared with `hmac.compare_digest`; refused in production by Settings.

### 2.3 Errors
`app/core/errors.py`: `PayShieldError(code, message, status)` subclasses: `Unauthorized(401)`, `Forbidden(403)`,
`NotFound(404)`, `Conflict(409)`, `ValidationFailed(422)`, `DependencyUnavailable(503)`. Rendered as RFC 7807
`application/problem+json` with `type`, `title`, `status`, `detail`, `code`, `correlationId`. Cross-tenant/company ids always produce
`404 NOT_FOUND` (never reveal existence).

## 3. Data extraction (db/payroll_repository.py, data/parsing.py)
- Records query: `payroll.pay_record pr JOIN payroll.pay_run r ON r.id = pr.pay_run_id JOIN payroll.pay_period pp ON pp.id = r.pay_period_id JOIN payroll.lk_payroll_cycle c ON c.id = r.pay_cycle_id LEFT JOIN employee.user_company_contract ucc ON ucc.id = pr.contract_id LEFT JOIN security."user" u ON u.id = pr.user_id WHERE pp.company_id = %(company_id)s ...`
  Period = `to_date(pp.value, 'MM/YYYY')`. Trial filter only if `capabilities().has_pay_run_is_trial` (`COALESCE(r.is_trial,false)`), else treat all as non-trial.
- Project only needed JSON paths in SQL (data_processed can be MBs): use `pr.data_processed #> '{payRecord,allowanceDeductionCalculationResult,payComponentResults}'` (json) and `#>>` scalars:
  `{payRecord,basicSalaryCalculationResult,basicSalary,amount}`, `{payRecord,backPayCalculationResult,amount,amount}`, `{payRecord,grossPay,amount}`, `{payRecord,nettPay,amount}`,
  `{payRecord,cpfCalculationResult}` IS NULL check via `(pr.data_processed #> '{payRecord,cpfCalculationResult}') IS NULL OR json_typeof(...) = 'null'`,
  `{payRecord,cpfCalculationResult,totalEmployeeContribution,amount}`, `{...,totalEmployerContribution,amount}`, `{...,eligibleOW,amount}`, `{...,eligibleAW,amount}`, `{...,isAdjustment}`,
  `{payRecord,communityFundsCalculationResult,totalAmount,amount}`, `{payRecord,sdlCalculationResult,amount,amount}`, `{payRecord,donationCalculationResult,amount,amount}`,
  `{payRecord,grossPay,currency}`, `{employeeContract,hiredDate}`, `{employeeContract,resignationDate}`,
  `{employee,statutorySummary,hasAWExcess}`, `awExcess`, `hasAWShortfall`, `awShortfall`, and `pr.data_processed #> '{payRecord}' IS NULL/json null` → `has_payload`.
  Columns: `pr.basic_salary, total_allowance, total_deduction, total_cpf, total_payout, status_id, is_new_hire, is_resignee, created_on, updated_on`.
- `data/parsing.py` exposes `parse_pay_items(component_results_json, master, overtime_codes) -> list[PayItem]` and
  `snapshot_from_row(row: Mapping, master, overtime_codes) -> PayRecordSnapshot` (row keys = SQL aliases listed in the module docstring). Also `snapshot_from_data_processed(doc: dict, **columns)` for synthetic data and tests. Tolerate: missing keys, enums as int **or** string, numbers as strings, `endDate` = DateTime.MaxValue, `Money` objects or plain numbers.
- Pay code master: `SELECT DISTINCT ON (ad.code) ad.code, ad.description, t.code AS type_code, cpf.code AS cpf_code, bt.code AS bonus_type_code, un.name AS unit_name FROM company.allowance_deduction ad LEFT JOIN company.allowance_deduction_type t ON t.id = ad.type_id LEFT JOIN company.allowance_deduction_cpf cpf ON cpf.id = ad.cpf_id LEFT JOIN company.allowance_deduction_bonus_type bt ON bt.id = ad.bonus_type_id LEFT JOIN company.allowance_deduction_unit un ON un.id = ad.unit_id WHERE ad.company_id = %(company_id)s ORDER BY ad.code, ad.year DESC, ad.id DESC`.
- Salary revisions: `employee.career_progression cp JOIN employee.user_company_contract ucc ON ucc.id = cp.contract_id JOIN company.code_setup cs ON cs.id = cp.career_progression_code_id WHERE ucc.company_id = %(company_id)s AND ucc.user_id = ANY(%(user_ids)s) AND cs.code <> 'CONSTART' AND (cp.effective_date >= %(since)s OR cp.pay_effective_date >= %(since)s)`.
- Configured items: `employee.contract_allowance_deduction cad JOIN employee.user_company_contract ucc ON ucc.id = cad.contract_id JOIN company.allowance_deduction ad ON ad.id = cad.pay_code_id LEFT JOIN company.allowance_deduction_type t ON t.id = ad.type_id LEFT JOIN employee.lk_recurring_method rm ON rm.id = cad.recurring_method_id LEFT JOIN payroll.lk_payroll_cycle c ON c.id = cad.payroll_cycle_id WHERE ucc.company_id = ... AND ucc.user_id = ANY(...) AND cad.effective_date <= period_end AND (cad.end_date IS NULL OR cad.end_date >= period_start)`. `is_earning` from `t.code` (`EARNING`→True, `DEDUCTION`→False, else None).
- Run states (sweeper): per pay_run in periods ≥ since: `count(*)`, `count(*) FILTER (WHERE status_id = 1)`, fingerprint = md5 of `string_agg(pr.id || ':' || COALESCE(pr.total_payout::text,'') || ':' || COALESCE(pr.total_allowance::text,'') || ':' || COALESCE(pr.total_deduction::text,'') || ':' || COALESCE(pr.basic_salary::text,'') || ':' || CASE WHEN pr.status_id IN (2,4) THEN 'ok' ELSE pr.status_id::text END, ',' ORDER BY pr.id)` (2↔4 lock transitions do not change it), `max(COALESCE(pr.updated_on, pr.created_on))`.
  The same fingerprint function is used by `analysis_service` for idempotency (`RunFingerprint.from_snapshots(records)` must produce the identical md5 in Python — implement both and test equality).

## 4. Observations & features (data/observations.py, data/feature_extractor.py, data/dataset_builder.py)
**Observation** = one (user_id, contract_id, cycle_code, period) aggregate of records:
- For the analysed run: the run's own records for that (user, contract) (a second run of the same cycle in the same period is flagged by rule `DUPLICATE_PAY_RUN`, not merged).
- For history: sum over all history records with the same key (multiple same-cycle runs in one period are summed).
- Money fields summed with "None if all None". Items concatenated. `cpf_assessed` = any. `is_new_hire`/`is_resignee` = any.
- History lookup key: (user_id, contract_id, cycle_code); fallback (user_id, cycle_code) across contracts when the contract has < `min_history_periods_for_scoring` periods (renewals) — record `history_key = "contract" | "user"`.
- History window: the `history_window_periods` (12) most recent periods strictly **before** the observation's period. The current period is never part of its own baseline (no leakage).

**Implemented (source of truth): `app/data/observations.py`, `app/data/feature_extractor.py`, `app/ml/baseline.py`.**
`FEATURE_COLUMNS` (ordered; all floats, NaN = missing; the code list also has `period_month_sin/cos`). Names are a public contract (stored in anomalies.features and the model manifest):
```
basic_contractual, basic_earned, proration_ratio, earnings_gross, net_pay, allowance_total, deduction_total,
bonus_total, aw_total, ordinary_allowance_total, back_pay, cpf_employee, cpf_employer, cpf_rate_employee,
overtime_amount, overtime_hours, hourly_item_hours, item_count, earning_item_count, deduction_item_count,
adhoc_item_count, duplicate_code_count,
prev_basic_contractual, prev_earnings_gross, prev_net_pay,
median_basic_contractual, median_earnings_gross, median_net_pay, median_allowance_total, median_deduction_total, median_overtime_amount,
mean_earnings_gross_3, mean_earnings_gross_6, mean_overtime_amount_6,
basic_change_pct, earnings_gross_change_pct, net_pay_change_pct, allowance_change_pct, deduction_change_pct,
rz_basic_contractual, rz_earnings_gross, rz_net_pay, rz_allowance_total, rz_deduction_total, rz_overtime_amount, rz_cpf_rate_employee,
log_ratio_net_pay, log_ratio_earnings_gross, log_ratio_allowance_total, log_ratio_deduction_total,
new_code_count, missing_recurring_code_count, history_periods, tenure_months, period_month, is_mid_cycle, is_bonus_cycle,
is_new_hire, is_resignee, contract_count
```
Definitions: `*_change_pct` = (current − prev)/|prev| × 100 vs the immediately previous history period (NaN if prev missing or 0);
`median_*` over the window; `rz_x` = (current − median)/(1.4826·MAD), MAD floored at max(1% of |median|, 1.0) to avoid division blow-ups;
`log_ratio_x` = ln((current+1)/(median+1)) for non-negative metrics; `cpf_rate_employee` = cpf_employee/(eligible_ow+eligible_aw) when assessed and denominator>0;
`new_code_count` = item codes (earning or deduction) present now but in none of the window periods; `missing_recurring_code_count` = earning codes with recurring_method MONTH present in each of the last 3 window periods but absent now;
`tenure_months` from hired_date to period (NaN if unknown); `period_month` 1–12; `contract_count` = distinct contracts of this user in the analysed run/period.
**Model input** = the subset `MODEL_FEATURES` (relative/robust features, scale-free) defined in feature_extractor: all `rz_*`, `log_ratio_*`, `*_change_pct` clipped to [−500, 500], `proration_ratio`, `cpf_rate_employee`, counts, `new_code_count`, `missing_recurring_code_count`, `is_*` flags, `period_month` (cyclical sin/cos), `history_periods`. Raw money levels are NOT model inputs (they would make high earners look anomalous).

Dataset builder: for every history observation with ≥ `min_history_periods_for_scoring` prior periods, compute features from strictly earlier periods → rows with `period`. Chronological split: last `ceil(validation_fraction × n_periods)` (min 2) periods = validation.

## 5. ML (ml/*) — see `docs/02_ML_DESIGN.md` written by the ML module
- Detector A: robust baseline score = max(|rz_*|) over key metrics (basic, earnings_gross, net, allowance, deduction, overtime).
- Detector B: `IsolationForest(n_estimators, max_samples, contamination="auto", random_state)` on `MODEL_FEATURES` after `SimpleImputer(strategy="median", add_indicator=True)` + `RobustScaler`. Raw score = `-score_samples(x)` (higher = more anomalous).
- **ml_percentile** = empirical percentile of the raw score within the training scores (stored as 1001 quantiles in the bundle). Semantics: "more unusual than P % of this company's historical pay observations". It is NOT a probability of error.
- Contributions: for a flagged observation, top features by |robust z of the feature vs training distribution| (median/MAD of each model feature in training) — reported as `top_contributors` [{feature, value, typical, z}].
- Optional expected-value model: `XGBRegressor(objective="reg:quantileerror", quantile_alpha=[0.1,0.5,0.9])` predicting `net_pay` and `earnings_gross` from lag features only (prev, medians, means, period_month, tenure, revision flag). Used only if validation MAE improves ≥ `expected_value_min_improvement` over the median baseline; otherwise disabled in the bundle.
- Evaluation (no labels needed): inject synthetic anomalies (`ml/injection.py`: salary +50 %, duplicate allowance, missing recurring allowance, deduction spike ×3, net jump +55 %, overtime ×4 when overtime present, cpf drop to 0) into validation observations, recompute features with the same history, score both detectors. Metrics: ROC-AUC, average precision, recall@alert_percentile, clean alert rate (share of clean validation rows ≥ alert percentile), per-scenario recall. Also precision on reviewer-labelled anomalies when ≥ 20 labels.
- Champion: detector with higher average precision (tie → ROBUST_BASELINE). Stored as `detector` in the registry.
- **Activation gate** (all must hold, else status TRAINED with reason, or REJECTED if the first two fail):
  champion AP ≥ `gate_min_average_precision`; clean alert rate ≤ `gate_max_clean_alert_rate`;
  if an ACTIVE model exists with the same feature schema, re-score the new validation set with it: new AP ≥ active AP − `gate_max_ap_regression`;
  company setting `auto_activate_models` true (manual activation otherwise).
- Insufficient data (observations < `min_training_observations` or periods < `min_training_periods`) → job `INSUFFICIENT_DATA`, no model; analysis runs with rules + baseline (`ml_status=NO_ACTIVE_MODEL`).

## 6. Bundle, storage, registry (ml/model_bundle.py, artifact_store.py, model_registry.py)
- `ModelBundle`: tenant_uid, company_uid, model_version, feature_schema_version, feature_columns, model_features, pipeline (sklearn), score_quantiles, feature_medians/mads, detector, expected_value models (optional), metrics, training period, created_at, library versions.
- Serialisation: `joblib.dump` to bytes + `manifest.json`; stored as one `.joblib` file. SHA-256 of bytes saved in `payshield.model_registry.artifact_sha256`. **Load path:** registry row (company-scoped query) → `ArtifactStore.load(tenant, company, location, sha)` (verifies prefix + hash) → `joblib.load` → assert bundle.tenant_uid/company_uid equal the context's → cache.
- Blob path: `tenants/{tenant_uid}/companies/{company_uid}/models/{model_version}/model.joblib` in container `payshield-models`. Local backend mirrors it under `storage.local_root`. Paths are built from validated GUIDs/semver only.
- Cache: LRU keyed by `(tenant_uid, company_uid, model_uid, sha256)`; a cache hit for one tenant can never satisfy another because the key includes the tenant.
- Version: `f"{feature_schema_version}.{sequence}.0"` where sequence = `next_model_sequence(company_id)`.
- Rollback = `activate_model` on a previous model uid of the same company (RETIRED/TRAINED with same feature schema).

## 7. Rules (rules/*) — defaults are configurable via `company_setting.thresholds` (flat keys below)
| rule_id | Type | Default logic | Severity |
|---|---|---|---|
| `SAL-001` | UNUSUAL_SALARY_INCREASE / DECREASE | contractual basic change vs previous same-contract period ≥ `salary_change_pct` (10) and no revision with `effective_date` in (prev_period_start, period_end] | HIGH (≥ `salary_change_high_pct` 30 → CRITICAL) |
| `SAL-002` | LARGE_SALARY_REVISION (is_explained) | revision exists but change ≥ `large_revision_pct` (30) or revision created ≤ `late_revision_days` (3) before the run date with effective date in a past period | MEDIUM |
| `SAL-003` | (explained, no finding) | revision exists and new_salary ≈ contractual basic (±0.01) and change < large_revision_pct | — (evidence only, recorded in summary) |
| `ALW-001` | DUPLICATE_ALLOWANCE | ≥2 earning lines with same code and same amount (±0.01) in one record, or across the user's contracts in the run | HIGH |
| `ALW-002` | DUPLICATE_ALLOWANCE | same code different amounts in one record (not adhoc) | LOW |
| `ALW-003` | MISSING_RECURRING_ALLOWANCE | earning code with recurring MONTH paid in each of the last `missing_allowance_periods` (3) same-cycle periods, absent now, employee not resignee, and (if configured items available) a configured line for the code is still active in the period or no config info | MEDIUM (HIGH if amount ≥ `missing_allowance_high_amount` 500) |
| `ALW-004` | UNUSUAL_ALLOWANCE | per-code amount robust z ≥ `amount_rz` (4) and change ≥ `allowance_change_pct` (50) | MEDIUM |
| `OT-001` | UNUSUAL_OVERTIME | overtime hours (or amount when hours unknown) robust z ≥ `amount_rz` and ≥ `overtime_ratio` (2.5)× employee median; company-level: above company P99 of history | MEDIUM (HIGH if ≥ 4×) |
| `NET-001` | UNEXPECTED_NET_PAY_CHANGE | |net change vs median| ≥ `net_change_pct` (25) **and** unexplained remainder (after subtracting explained components: revisions, bonus/AW items, back pay, new-hire/resignee proration) ≥ `net_unexplained_pct` (15) of median | HIGH if unexplained ≥ 40 %, else MEDIUM |
| `DED-001` | NEW_DEDUCTION | deduction code not seen in window and amount ≥ `new_deduction_min_pct_of_gross` (5) % of earnings gross | MEDIUM |
| `DED-002` | UNUSUAL_DEDUCTION | deduction total rz ≥ `amount_rz` and change ≥ `deduction_change_pct` (50) | MEDIUM (HIGH if ≥ 200 %) |
| `STA-001` | STATUTORY_MISSING_CONTRIBUTION | END cycle, CPF assessed in ≥ 3 of last window END periods, now not assessed or both employee & employer = 0 while eligible wage > 0 | HIGH |
| `STA-002` | STATUTORY_CONTRIBUTION_CHANGE | `cpf_rate_employee` differs from employee's median rate by ≥ `cpf_rate_change_pp` (2.0) percentage points and no change in age band/residency is observable → "verify with pay engine" | MEDIUM |
| `STA-003` | STATUTORY_ENGINE_FLAG | engine `hasAWExcess`/`hasAWShortfall` true | LOW (surfaced; engine is authoritative) |
| `NET-002` | NEGATIVE_OR_ZERO_NET_PAY | net ≤ 0 while earnings gross > 0 | HIGH |
| `RUN-001` | DUPLICATE_PAY_RUN | another non-trial Completed/Locked run with the same cycle code in the same period contains this user/contract | HIGH |
| `DQ-001` | DATA_QUALITY | record status Failed (3) / missing payload / currency ≠ company's usual / negative component amounts | MEDIUM (Failed → HIGH) |

Rules never block payroll; they produce `Finding`s with `source=RULE|STATUTORY|DATA_QUALITY`, evidence and a recommended action.
Bonus/AW handling: bonus/AW items are excluded from `ordinary_allowance_total` and explain net/gross jumps (so a legitimate bonus does not raise NET-001 but appears in evidence).
New hires / resignees / proration_ratio < 0.95: salary and net rules compare **contractual** basic, and NET-001 raises severity only if unexplained after proration.

## 8. Risk scoring (services/risk_engine.py) — documented in `docs/03_RISK_SCORING.md`
- Severity base scores: LOW 25, MEDIUM 50, HIGH 75, CRITICAL 90.
- Rule finding risk = base + min(10, history_confidence_bonus) where bonus = 5 if ≥ 6 history periods and evidence numeric.
- ML-only finding (no rule fired for that observation): created only when `ml_percentile ≥ alert_percentile` (97) and detector is IF and model ACTIVE; severity MEDIUM if percentile ≥ 99.5 else LOW; risk = round(ml_percentile × 0.6) capped at 70. Type `UNUSUAL_PAY_PATTERN`, evidence = top contributors.
- Baseline-only findings (no active model or detector = ROBUST_BASELINE): created when baseline_score ≥ `baseline_alert_rz` (6) and no rule fired; severity LOW/MEDIUM (≥ 10); risk ≤ 65.
- When a rule fires for an observation that also scored high in ML, the rule finding gets `ml_percentile` attached and risk +5 (cap 100). Rule severity always outranks ML.
- Confirmed rule violations are never downgraded by ML. `is_explained=True` findings are capped at MEDIUM / risk 45.
- Confidence: HIGH if ≥ 6 history periods (contract key), MEDIUM if 3–5 or user-key fallback, LOW otherwise.
- Analysis status `COMPLETED_WITH_WARNINGS` when ML was unavailable, a rule raised an exception (isolated), or data-quality issues exist.

## 9. Analysis flow (services/analysis_service.py + payroll_analyzer.py)
```
analyze(ctx, pay_run_uid, trigger, supersede=False)
  run = repo.get_pay_run(ctx.company_id, uid)            -> 404 if None
  records = list_run_records(...); fingerprint = RunFingerprint.from_snapshots(records)
  if any record status 1 (processing): 409 RUN_NOT_SETTLED
  (analysis, created) = create_analysis(..., supersede)  -> existing live analysis returned if same fingerprint
  history = list_history_records(company, period - 13 months, period, user_ids, exclude_pay_run_id=run.id)
  + same-period other runs (for RUN-001) via list_history_records(company, period, period+1 month, exclude=run.id)
  revisions, configured items, master, settings
  bundle = registry.load_active(ctx) (errors -> ml_status MODEL_UNAVAILABLE, warning, continue)
  outcome = PayrollAnalyzer.analyze(...)  (pure)
  complete_analysis(... anomalies)  | on exception: fail_analysis + re-raise as PayShieldError (never silent)
```
Response DTO `PayrollAnalysisResponse` (camelCase): `analysisId, payRunId(uid), payrollPeriod ("YYYY-MM"), cycleCode, status, modelVersion, detector, mlStatus,
totalEmployees, flaggedEmployees, anomalyCount, maxSeverity, generatedAt, warnings[], riskScoreSemantics (string), anomalies[]` where anomaly =
`anomalyId, employeeUid, employeeNo, contractId, payRecordId(uid), anomalyType, source, ruleId, severity, riskScore, mlPercentile, confidence, metric,
currentValue, expectedValue, expectedLow, expectedHigh, expectedMethod, changePct, isExplained, description, recommendedAction, evidence[], latestFeedback`.
Anomaly lists are filtered by `ctx.access` (employee-level) at query time; counts in the response are recomputed over the visible set for users with restricted scope.

## 10. API (FastAPI, prefix `/api/v1`)
| Method | Path | Auth | Notes |
|---|---|---|---|
| GET | `/health/live`, `/health/ready` | none | ready checks tenant store connectivity |
| POST | `/models/train` | user `edit` / service | body `{trigger?: "MANUAL"}` → 202 `{jobId, status}`; 409 if running |
| GET | `/models/status` | `view` | active model + latest job |
| GET | `/models/versions` | `view` | registry list |
| GET | `/models/training-jobs/{jobId}` | `view` | |
| POST | `/models/{modelId}/activate` | `edit` | rollback / manual activation; 404 cross-company |
| POST | `/payroll/analyze` | `view`+... user `edit` or service | body `{payRunId (uid), supersede?: bool, mode?: "sync"|"async"}` → 200 result (sync) / 202 `{analysisId?, status}` (async) |
| GET | `/payroll/analysis/{analysisId}` | `view` | |
| GET | `/payroll/runs/{payRunId}/analysis` | `view` | latest analysis for a run |
| POST | `/payroll/feedback` | `edit` | `{anomalyId, outcome, comment?}` |
| POST | `/assistant/ask` | `view` | `{question, analysisId?}` → `{answer, status, citations[], toolCalls[]}` |
| PUT/GET | `/settings` | `edit`/`view` | company_setting |
| POST | `/internal/sweep` , `/internal/retraining`, `/internal/recover-jobs` | service only | used by the Functions timers |

## 11. Assistant (llm/*, services/assistant_service.py, explanation_service.py)
- LLM never calculates payroll and never decides correctness: system prompt states this; answers are built from tool results only.
- Tools (JSON-schema function calling), all bound server-side to `ctx` (tenant, company, access scope) — the model cannot pass tenant/company ids:
  `get_analysis_summary(analysis_ref?)`, `list_anomalies(severity?, anomaly_type?, limit<=50)`, `get_employee_findings(employee_ref)`,
  `count_anomalies(group_by: "anomaly_type"|"severity")`, `compare_with_previous_analysis()`, `get_finding_evidence(anomaly_ref)`.
- Employees appear only as pseudonymous refs `E-xxxxxx` (HMAC-SHA256 of user_uid with a per-analysis salt, 6 hex); names, emails, NRIC, DOB, bank never included. Amounts are included (needed to explain) and are permitted because the caller has PAY View on the company and the employee is in scope.
- Tool outputs are wrapped as data (`<tool_result>` JSON) and the system prompt says retrieved content is untrusted data, not instructions. Output post-validation: answer must not contain raw user uids/emails (regex scrub); citations must reference anomaly refs returned by tools.
- Fallback when provider disabled/unavailable/time-out: deterministic templated answers for the supported intents (top risks, count by type, why employee X, summary) → `status="FALLBACK"`.
- Every question writes `payshield.assistant_audit` (hash only).
- The assistant has **no** write tools (cannot finalize, lock, approve, modify salaries, give feedback or train).

## 12. Messaging & schedules
- Messages (camelCase JSON, `ApplicationProperties`: `tenantUid`, `actorUid`, `messageType`): analysis `{tenantUid, companyUid, payRunUid, fingerprint, trigger, requestedBy}` MessageId = `analysis:{tenantUid}:{payRunUid}:{fingerprint}`;
  training `{tenantUid, companyUid, jobUid, requestedBy}` MessageId = `training:{jobUid}`.
- Worker: receive → validate body (dead-letter on schema error) → build service `TenantContext` (SERVICE principal, all users) → run → complete; transient errors → abandon; `delivery_count >= max_delivery_attempts` → mark failed + dead-letter.
- `execution_mode=inline`: publisher executes immediately in a background thread (dev/tests).
- Sweeper: for each tenant: `list_run_states(since=today-lookback)`, skip trial? **No** — trial runs are analysed (pre-finalisation is the point), skip runs with processing_count>0 or record_count=0, skip unchanged fingerprint (watermark), skip companies with `auto_analyze=false`; publish + upsert watermark.
- Scheduled retraining: for each tenant/company with `is_enabled`, create job (`SCHEDULED`) unless one is active, publish training message.
- Recovery: `recover_stale_training_jobs(stale_after=1800)`; re-queue once as `RECOVERY` if attempt < 2.
