# payroll-api integration (optional, not applied)

PayShield works **without any change to times-payroll-api**: the sweeper (Azure Functions timer → `POST /api/v1/internal/sweep`)
detects settled pay runs from the database. These files are for a later, faster push trigger.

1. Reference `dotnet/src/Times.PayShield.Client` (or publish it to the `times-shared-components` feed).
2. `Program`/`DependencyInjection`: `services.AddPayShieldClient(configuration);` and register
   `ServiceBusClient` + `services.AddSingleton<IPayShieldAnalysisPublisher, PayShieldAnalysisPublisher>();`
3. Copy `PayShieldPayrollProcessCompletedHandler.cs` (check the company repository name noted in the file header).
4. appsettings (no secrets):
```json
"PayShield": { "Enabled": true, "BaseUrl": "https://payshield-api.internal", "Audience": "api://payshield-ai",
               "TimeoutSeconds": 120, "AnalysisQueueName": "payshield-analysis-requested" }
```
5. UI read path: call `GET /api/v1/payroll/runs/{payRunUid}/analysis` with the user's own Keycloak token
   (`PayShieldCallContext.User`) — PayShield applies the same company + PAY permission checks.
