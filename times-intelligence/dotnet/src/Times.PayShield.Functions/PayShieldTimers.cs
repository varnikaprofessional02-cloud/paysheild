using System.Net.Http.Headers;
using Azure.Core;
using Azure.Identity;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;

namespace Times.PayShield.Functions;

/// <summary>Thin timers: all tenant iteration and business logic lives in the PayShield service (internal endpoints).</summary>
public sealed class PayShieldTimers(IHttpClientFactory httpFactory, TokenCredential credential, ILogger<PayShieldTimers> logger)
{
    [Function("PayShieldPayRunSweeper")]
    public Task Sweep([TimerTrigger("%PayShield:SweeperSchedule%")] TimerInfo timer, CancellationToken ct) =>
        CallAsync("api/v1/internal/sweep", ct);

    [Function("PayShieldScheduledRetraining")]
    public Task Retrain([TimerTrigger("%PayShield:RetrainingSchedule%")] TimerInfo timer, CancellationToken ct) =>
        CallAsync("api/v1/internal/retraining", ct);

    private async Task CallAsync(string path, CancellationToken ct)
    {
        // same gate style as the house ServiceBusTriggerEnabled switch
        if (!string.Equals(Environment.GetEnvironmentVariable("PayShieldTimersEnabled"), "true", StringComparison.OrdinalIgnoreCase))
            return;
        var audience = Environment.GetEnvironmentVariable("PayShield:Audience") ?? "api://payshield-ai";
        var token = await credential.GetTokenAsync(new TokenRequestContext([$"{audience}/.default"]), ct);
        using var request = new HttpRequestMessage(HttpMethod.Post, path);
        request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", token.Token);
        using var response = await httpFactory.CreateClient("payshield").SendAsync(request, ct);
        var body = await response.Content.ReadAsStringAsync(ct);
        // response holds counts only (tenants/analysed/skipped/failed), never payroll data
        logger.LogInformation("PayShield {Path} returned {Status}: {Counts}", path, (int)response.StatusCode, body);
        response.EnsureSuccessStatusCode();
    }
}

public static class Program
{
    public static void Main() =>
        new HostBuilder()
            .ConfigureFunctionsWorkerDefaults()
            .ConfigureServices(s =>
            {
                s.AddSingleton<TokenCredential>(_ => new DefaultAzureCredential());
                s.AddHttpClient("payshield", c =>
                {
                    c.BaseAddress = new Uri((Environment.GetEnvironmentVariable("PayShield:BaseUrl") ?? "http://localhost:8080").TrimEnd('/') + "/");
                    c.Timeout = TimeSpan.FromMinutes(9);
                });
            })
            .Build()
            .Run();
}
