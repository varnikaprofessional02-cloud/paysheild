using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json;
using System.Text.Json.Serialization;
using Azure.Core;
using Azure.Identity;
using Azure.Messaging.ServiceBus;
using ErrorOr;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;

namespace Times.PayShield.Client;

public sealed class PayShieldOptions
{
    public const string Section = "PayShield";
    public bool Enabled { get; set; }
    public string BaseUrl { get; set; } = string.Empty;
    public string Audience { get; set; } = "api://payshield-ai";
    public int TimeoutSeconds { get; set; } = 120;
    public string AnalysisQueueName { get; set; } = "payshield-analysis-requested";
}

/// <summary>Who the call is made for. User calls never send a tenant: PayShield reads it from the verified token.</summary>
public abstract record PayShieldCallContext(Guid CompanyUid)
{
    public sealed record Service(Guid TenantUid, Guid CompanyUid) : PayShieldCallContext(CompanyUid);
    public sealed record User(string BearerToken, Guid CompanyUid) : PayShieldCallContext(CompanyUid);
}

public sealed record PayrollAnomaly(Guid AnomalyId, Guid? EmployeeUid, string? EmployeeNo, string AnomalyType, string Source,
    string? RuleId, string Severity, int RiskScore, decimal? MlPercentile, string Confidence, decimal? CurrentValue,
    decimal? ExpectedValue, string? ExpectedMethod, decimal? ChangePct, bool IsExplained, string Description,
    string? RecommendedAction, string? LatestFeedback);

public sealed record PayrollAnalysisResult(Guid AnalysisId, Guid PayRunId, string PayrollPeriod, string? CycleCode, string Status,
    string? ModelVersion, string? Detector, string? MlStatus, int TotalEmployees, int FlaggedEmployees, int AnomalyCount,
    string? MaxSeverity, IReadOnlyList<string> Warnings, string RiskScoreSemantics, IReadOnlyList<PayrollAnomaly> Anomalies);

public sealed record TrainingJobResult(Guid JobId, string Status);

public enum FeedbackOutcome { CONFIRMED_ERROR, EXPECTED_CHANGE, FALSE_POSITIVE, NEEDS_INVESTIGATION }

public interface IPayShieldService
{
    Task<ErrorOr<PayrollAnalysisResult>> AnalyzePayrollAsync(Guid payRunUid, PayShieldCallContext context, CancellationToken cancellationToken);
    Task<ErrorOr<PayrollAnalysisResult>> GetAnalysisAsync(Guid analysisId, PayShieldCallContext context, CancellationToken cancellationToken);
    Task<ErrorOr<PayrollAnalysisResult>> GetLatestAnalysisForRunAsync(Guid payRunUid, PayShieldCallContext context, CancellationToken cancellationToken);
    Task<ErrorOr<TrainingJobResult>> RequestTrainingAsync(PayShieldCallContext context, CancellationToken cancellationToken);
    Task<ErrorOr<Success>> SubmitFeedbackAsync(Guid anomalyId, FeedbackOutcome outcome, string? comment, PayShieldCallContext.User context, CancellationToken cancellationToken);
}

public sealed class PayShieldService(HttpClient http, IOptions<PayShieldOptions> options, TokenCredential credential,
    ILogger<PayShieldService> logger) : IPayShieldService
{
    internal static readonly JsonSerializerOptions Json = new(JsonSerializerDefaults.Web) { Converters = { new JsonStringEnumConverter() } };

    public Task<ErrorOr<PayrollAnalysisResult>> AnalyzePayrollAsync(Guid payRunUid, PayShieldCallContext context, CancellationToken ct) =>
        SendAsync<PayrollAnalysisResult>(HttpMethod.Post, "api/v1/payroll/analyze", new { payRunId = payRunUid }, context, ct);

    public Task<ErrorOr<PayrollAnalysisResult>> GetAnalysisAsync(Guid analysisId, PayShieldCallContext context, CancellationToken ct) =>
        SendAsync<PayrollAnalysisResult>(HttpMethod.Get, $"api/v1/payroll/analysis/{analysisId}", null, context, ct);

    public Task<ErrorOr<PayrollAnalysisResult>> GetLatestAnalysisForRunAsync(Guid payRunUid, PayShieldCallContext context, CancellationToken ct) =>
        SendAsync<PayrollAnalysisResult>(HttpMethod.Get, $"api/v1/payroll/runs/{payRunUid}/analysis", null, context, ct);

    public Task<ErrorOr<TrainingJobResult>> RequestTrainingAsync(PayShieldCallContext context, CancellationToken ct) =>
        SendAsync<TrainingJobResult>(HttpMethod.Post, "api/v1/models/train", new { trigger = "MANUAL" }, context, ct);

    public async Task<ErrorOr<Success>> SubmitFeedbackAsync(Guid anomalyId, FeedbackOutcome outcome, string? comment,
        PayShieldCallContext.User context, CancellationToken ct)
    {
        var result = await SendAsync<JsonElement>(HttpMethod.Post, "api/v1/payroll/feedback",
            new { anomalyId, outcome = outcome.ToString(), comment }, context, ct);
        return result.IsError ? result.Errors : Result.Success;
    }

    private async Task<ErrorOr<T>> SendAsync<T>(HttpMethod method, string path, object? body, PayShieldCallContext context, CancellationToken ct)
    {
        // payshield is advisory: disabled or unreachable returns an error value, never an exception that could break payroll
        if (!options.Value.Enabled)
            return Error.Failure("PayShield.Disabled", "PayShield is disabled.");
        using var request = new HttpRequestMessage(method, path);
        if (body is not null)
            request.Content = JsonContent.Create(body, options: Json);
        request.Headers.Add("X-Company-Uid", context.CompanyUid.ToString());
        try
        {
            switch (context)
            {
                case PayShieldCallContext.User user:
                    request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", user.BearerToken);
                    break;
                case PayShieldCallContext.Service service:
                    var token = await credential.GetTokenAsync(new TokenRequestContext([$"{options.Value.Audience}/.default"]), ct);
                    request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", token.Token);
                    request.Headers.Add("X-Tenant-Uid", service.TenantUid.ToString());
                    break;
            }
            using var response = await http.SendAsync(request, ct);
            if (response.IsSuccessStatusCode)
                return (await response.Content.ReadFromJsonAsync<T>(Json, ct))!;
            var code = await ReadCodeAsync(response, ct);
            logger.LogWarning("PayShield call failed with {StatusCode} {Code}", (int)response.StatusCode, code);
            return response.StatusCode switch
            {
                HttpStatusCode.NotFound => Error.NotFound(code, "Not found."),
                HttpStatusCode.Conflict => Error.Conflict(code, "Conflict."),
                HttpStatusCode.Forbidden => Error.Forbidden(code, "Forbidden."),
                HttpStatusCode.Unauthorized => Error.Unauthorized(code, "Unauthorized."),
                HttpStatusCode.UnprocessableEntity => Error.Validation(code, "Invalid request."),
                _ => Error.Unexpected(code, "PayShield is unavailable."),
            };
        }
        catch (Exception ex) when (ex is HttpRequestException or AuthenticationFailedException
                                       || (ex is TaskCanceledException && !ct.IsCancellationRequested))
        {
            logger.LogWarning(ex, "PayShield unreachable");
            return Error.Unexpected("PayShield.Unavailable", "PayShield is unavailable.");
        }
    }

    private static async Task<string> ReadCodeAsync(HttpResponseMessage response, CancellationToken ct)
    {
        try
        {
            var doc = await response.Content.ReadFromJsonAsync<JsonElement>(ct);
            return doc.TryGetProperty("code", out var c) ? c.GetString() ?? "PayShield.Error" : "PayShield.Error";
        }
        catch (Exception ex) when (ex is JsonException or NotSupportedException)
        {
            return "PayShield.Error";
        }
    }
}

/// <summary>Publishes analysis requests to Service Bus (mirrors the payroll-api publisher conventions).</summary>
public interface IPayShieldAnalysisPublisher
{
    Task PublishAsync(Guid tenantUid, Guid companyUid, Guid payRunUid, string fingerprint, string actor, CancellationToken cancellationToken);
}

public sealed class PayShieldAnalysisPublisher(ServiceBusClient client, IOptions<PayShieldOptions> options) : IPayShieldAnalysisPublisher
{
    public async Task PublishAsync(Guid tenantUid, Guid companyUid, Guid payRunUid, string fingerprint, string actor, CancellationToken ct)
    {
        await using var sender = client.CreateSender(options.Value.AnalysisQueueName);
        var body = new { tenantUid, companyUid, payRunUid, fingerprint, trigger = "EVENT", requestedBy = actor };
        var message = new ServiceBusMessage(BinaryData.FromObjectAsJson(body, PayShieldService.Json))
        {
            ContentType = "application/json",
            // deterministic id: service bus duplicate detection drops repeats of the same run state
            MessageId = $"analysis:{tenantUid}:{payRunUid}:{fingerprint}",
        };
        message.ApplicationProperties["tenantUid"] = tenantUid.ToString();
        message.ApplicationProperties["actorUid"] = actor;
        message.ApplicationProperties["messageType"] = "payshield.analysis.requested";
        await sender.SendMessageAsync(message, ct);
    }
}

public static class DependencyInjection
{
    public static IServiceCollection AddPayShieldClient(this IServiceCollection services, IConfiguration configuration)
    {
        services.Configure<PayShieldOptions>(configuration.GetSection(PayShieldOptions.Section));
        services.AddSingleton<TokenCredential>(_ => new DefaultAzureCredential());
        services.AddHttpClient<IPayShieldService, PayShieldService>((sp, client) =>
            {
                var o = sp.GetRequiredService<IOptions<PayShieldOptions>>().Value;
                if (!string.IsNullOrWhiteSpace(o.BaseUrl))
                    client.BaseAddress = new Uri(o.BaseUrl.TrimEnd('/') + "/");
                client.Timeout = TimeSpan.FromSeconds(o.TimeoutSeconds);
            })
            // analyze is idempotent server-side (run fingerprint), so transient retries are safe
            .AddStandardResilienceHandler(o =>
            {
                o.AttemptTimeout.Timeout = TimeSpan.FromSeconds(100);
                o.TotalRequestTimeout.Timeout = TimeSpan.FromSeconds(300);
                o.CircuitBreaker.SamplingDuration = TimeSpan.FromSeconds(200);
            });
        return services;
    }
}
