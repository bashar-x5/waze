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
        DateTime? lastHarvest = null;

        // Perform initial harvest 5s after startup
        try
        {
            await Task.Delay(TimeSpan.FromSeconds(5), stoppingToken);
            using var scope = _scopeFactory.CreateScope();
            var harvester = scope.ServiceProvider.GetRequiredService<ITomTomTrafficHarvester>();
            await harvester.HarvestBaghdadTrafficAsync(stoppingToken);
            lastHarvest = DateTime.UtcNow;
        }
        catch (Exception ex)
        {
            _logger.LogWarning("Initial TomTom traffic harvest deferred: {Message}", ex.Message);
        }

        while (!stoppingToken.IsCancellationRequested && await timer.WaitForNextTickAsync(stoppingToken))
        {
            try
            {
                using var scope = _scopeFactory.CreateScope();
                
                // 1. Aggregate real-time crowdsourced GPS fixes from Darb mobile users
                var trafficService = scope.ServiceProvider.GetRequiredService<ITrafficIntelligenceService>();
                await trafficService.AggregateTrafficAsync(stoppingToken);

                // 2. Periodically harvest Baghdad traffic flow from TomTom (every 5 minutes)
                if (lastHarvest == null || DateTime.UtcNow - lastHarvest.Value >= TimeSpan.FromMinutes(5))
                {
                    var harvester = scope.ServiceProvider.GetRequiredService<ITomTomTrafficHarvester>();
                    await harvester.HarvestBaghdadTrafficAsync(stoppingToken);
                    lastHarvest = DateTime.UtcNow;
                }
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
