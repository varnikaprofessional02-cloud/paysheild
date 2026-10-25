using System.Net;
using System.Text;
using Azure.Core;
using ErrorOr;
using FluentAssertions;
using Microsoft.Extensions.Logging.Abstractions;
using Microsoft.Extensions.Options;
using Microsoft.VisualStudio.TestTools.UnitTesting;
using Moq;

namespace Times.PayShield.Client.UnitTests;

[TestClass]
public class PayShieldServiceTests
{
    private const string Sample = """
    {"analysisId":"9b0c1f1e-1111-4111-8111-111111111111","payRunId":"9b0c1f1e-2222-4222-8222-222222222222",
     "payrollPeriod":"2026-10","cycleCode":"END","status":"COMPLETED","modelVersion":"1.1.0","detector":"ROBUST_BASELINE",
     "mlStatus":"BASELINE_PREFERRED","totalEmployees":60,"flaggedEmployees":1,"anomalyCount":1,"maxSeverity":"CRITICAL",
     "warnings":[],"riskScoreSemantics":"rank","anomalies":[{"anomalyId":"9b0c1f1e-3333-4333-8333-333333333333",
     "employeeUid":null,"employeeNo":"E00003","anomalyType":"UNUSUAL_SALARY_INCREASE","source":"RULE","ruleId":"SAL-001",
     "severity":"CRITICAL","riskScore":95,"mlPercentile":null,"confidence":"HIGH","currentValue":7820.0,"expectedValue":5210.0,
     "expectedMethod":"median_12_periods","changePct":50.1,"isExplained":false,"description":"d","recommendedAction":"a",
     "latestFeedback":null}]}
    """;

    private sealed class Handler(Func<HttpRequestMessage, HttpResponseMessage> respond) : HttpMessageHandler
    {
        public List<HttpRequestMessage> Requests { get; } = [];

        protected override Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken ct)
        {
            Requests.Add(request);
            return Task.FromResult(respond(request));
        }
    }

    private static (PayShieldService, Handler) Create(Func<HttpRequestMessage, HttpResponseMessage> respond, bool enabled = true)
    {
        var handler = new Handler(respond);
        var http = new HttpClient(handler) { BaseAddress = new Uri("https://payshield.test/") };
        var credential = new Mock<TokenCredential>();
        credential.Setup(c => c.GetTokenAsync(It.IsAny<TokenRequestContext>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync(new AccessToken("svc-token", DateTimeOffset.UtcNow.AddHours(1)));
        var options = Options.Create(new PayShieldOptions { Enabled = enabled, BaseUrl = "https://payshield.test" });
        return (new PayShieldService(http, options, credential.Object, NullLogger<PayShieldService>.Instance), handler);
    }

    private static HttpResponseMessage Json(HttpStatusCode code, string body) =>
        new(code) { Content = new StringContent(body, Encoding.UTF8, "application/json") };

    [TestMethod]
    public async Task Analyze_service_context_sends_service_token_and_tenant_headers()
    {
        var (svc, handler) = Create(_ => Json(HttpStatusCode.OK, Sample));
        var tenant = Guid.NewGuid();
        var company = Guid.NewGuid();

        var result = await svc.AnalyzePayrollAsync(Guid.NewGuid(), new PayShieldCallContext.Service(tenant, company), default);

        result.IsError.Should().BeFalse();
        result.Value.Anomalies.Should().ContainSingle(a => a.RuleId == "SAL-001" && a.RiskScore == 95);
        var req = handler.Requests.Single();
        req.Headers.Authorization!.Parameter.Should().Be("svc-token");
        req.Headers.GetValues("X-Tenant-Uid").Single().Should().Be(tenant.ToString());
        req.Headers.GetValues("X-Company-Uid").Single().Should().Be(company.ToString());
    }

    [TestMethod]
    public async Task User_context_forwards_user_token_and_never_sends_tenant()
    {
        var (svc, handler) = Create(_ => Json(HttpStatusCode.OK, Sample));

        await svc.GetAnalysisAsync(Guid.NewGuid(), new PayShieldCallContext.User("user-token", Guid.NewGuid()), default);

        var req = handler.Requests.Single();
        req.Headers.Authorization!.Parameter.Should().Be("user-token");
        req.Headers.Contains("X-Tenant-Uid").Should().BeFalse();
    }

    [TestMethod]
    public async Task Problem_details_map_to_errors_with_server_code()
    {
        var (svc, _) = Create(_ => Json(HttpStatusCode.NotFound, """{"code":"ANALYSIS_NOT_FOUND","status":404}"""));

        var result = await svc.GetAnalysisAsync(Guid.NewGuid(), new PayShieldCallContext.User("t", Guid.NewGuid()), default);

        result.FirstError.Type.Should().Be(ErrorType.NotFound);
        result.FirstError.Code.Should().Be("ANALYSIS_NOT_FOUND");
    }

    [TestMethod]
    public async Task Disabled_returns_error_without_http_call()
    {
        var (svc, handler) = Create(_ => throw new InvalidOperationException(), enabled: false);

        var result = await svc.AnalyzePayrollAsync(Guid.NewGuid(), new PayShieldCallContext.User("t", Guid.NewGuid()), default);

        result.FirstError.Code.Should().Be("PayShield.Disabled");
        handler.Requests.Should().BeEmpty();
    }

    [TestMethod]
    public async Task Network_failure_is_an_error_value_not_an_exception()
    {
        var (svc, _) = Create(_ => throw new HttpRequestException("down"));

        var result = await svc.AnalyzePayrollAsync(Guid.NewGuid(), new PayShieldCallContext.User("t", Guid.NewGuid()), default);

        result.FirstError.Code.Should().Be("PayShield.Unavailable");
    }
}
