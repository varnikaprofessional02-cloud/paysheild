// DROP-IN for times-payroll-api (NOT compiled in this solution, NOT applied to that repo).
// Optional push trigger: without it, the PayShield sweeper still detects completed runs from the DB.
// Copy to src/Times.Payroll.Application/PayRuns/Events/ and register the client (see README.md here).
//
// Verified against the analysis of payroll-api main: PayrollProcessCompletedEvent carries SubscriptionUid,
// CompanyId (long, tenant-local id) and PayRun { PayRunUid, PayPeriod }. The company uid lookup below uses
// ICompanyRepository.GetByIdAsync -- CHECK the exact repository name/signature in payroll-api before use.

using MediatR;
using Microsoft.Extensions.Logging;
using Times.PayShield.Client;

namespace Times.Payroll.Application.PayRuns.Events;

public sealed class PayShieldPayrollProcessCompletedHandler(
    IPayShieldAnalysisPublisher publisher,
    ICompanyRepository companies,
    ILogger<PayShieldPayrollProcessCompletedHandler> logger) : INotificationHandler<PayrollProcessCompletedEvent>
{
    public async Task Handle(PayrollProcessCompletedEvent notification, CancellationToken cancellationToken)
    {
        // MediatR runs notification handlers sequentially: never let PayShield break the other handlers or payroll
        try
        {
            var company = await companies.GetByIdAsync(notification.CompanyId, notification.SubscriptionUid, cancellationToken);
            if (company is null)
                return;
            // fingerprint "event" + run uid: the service recomputes the real figure fingerprint and is idempotent
            await publisher.PublishAsync(notification.SubscriptionUid, company.Uid, notification.PayRun.PayRunUid,
                $"event-{DateTime.UtcNow:yyyyMMddHHmm}", "payroll-api", cancellationToken);
        }
        catch (Exception ex)
        {
            logger.LogWarning(ex, "PayShield analysis request for pay run {PayRunUid} was not published", notification.PayRun.PayRunUid);
        }
    }
}
