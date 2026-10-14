using Darb.Api.Services;

namespace Darb.Api.Services;

public class TrafficAggregationWorker : BackgroundService
{
    private readonly IServiceScopeFactory _scopeFactory;
    private readonly ILogger<TrafficAggregationWorker> _logger;
    private readonly TimeSpan _interval = TimeSpan.FromSeconds(30);

    public TrafficAggregationWorker(IServiceScopeFactory scopeFactory, ILogger<TrafficAggregationWorker> logger)
    {
        _scopeFactory = scopeFactory;
        _logger = logger;
    }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        _logger.LogInformation("Traffic Aggregation Background Worker started (interval: {Interval}s).", _interval.TotalSeconds);

        using var timer = new PeriodicTimer(_interval);

        while (!stoppingToken.IsCancellationRequested && await timer.WaitForNextTickAsync(stoppingToken))
        {
            try
            {
                using var scope = _scopeFactory.CreateScope();
                var trafficService = scope.ServiceProvider.GetRequiredService<ITrafficIntelligenceService>();
                await trafficService.AggregateTrafficAsync(stoppingToken);
            }
            catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested)
            {
                break;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error occurred during background traffic aggregation.");
            }
        }

        _logger.LogInformation("Traffic Aggregation Background Worker stopped.");
    }
}
