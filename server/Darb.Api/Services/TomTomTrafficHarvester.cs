using System.Text.Json;
using Microsoft.EntityFrameworkCore;
using Darb.Api.Data;
using Darb.Api.Models;

namespace Darb.Api.Services;

public interface ITomTomTrafficHarvester
{
    Task HarvestBaghdadTrafficAsync(CancellationToken cancellationToken = default);
}

public class BaghdadCorridor
{
    public required string Key { get; set; }
    public required string NameAr { get; set; }
    public required string NameEn { get; set; }
    public required double FromLat { get; set; }
    public required double FromLon { get; set; }
    public required double ToLat { get; set; }
    public required double ToLon { get; set; }
    public required double MidLat { get; set; }
    public required double MidLon { get; set; }
    public required double BaseSpeedKmh { get; set; }
}

public class TomTomTrafficHarvester : ITomTomTrafficHarvester
{
    private readonly HttpClient _httpClient;
    private readonly IConfiguration _config;
    private readonly IServiceProvider _serviceProvider;
    private readonly ILogger<TomTomTrafficHarvester> _logger;

    public TomTomTrafficHarvester(
        HttpClient httpClient,
        IConfiguration config,
        IServiceProvider serviceProvider,
        ILogger<TomTomTrafficHarvester> logger)
    {
        _httpClient = httpClient;
        _config = config;
        _serviceProvider = serviceProvider;
        _logger = logger;
    }

    // Key Baghdad Arterials monitored continuously
    public static readonly List<BaghdadCorridor> Corridors = new()
    {
        new BaghdadCorridor
        {
            Key = "corridor_qasim",
            NameAr = "طريق محمد القاسم للمرور السريع",
            NameEn = "Muhammad Al-Qasim Expressway",
            FromLat = 33.3650, FromLon = 44.3900,
            ToLat = 33.3050, ToLon = 44.4450,
            MidLat = 33.3350, MidLon = 44.4170,
            BaseSpeedKmh = 80.0
        },
        new BaghdadCorridor
        {
            Key = "corridor_14july",
            NameAr = "شارع 14 تموز (المنطقة الخضراء - الكرخ)",
            NameEn = "14th of July Highway",
            FromLat = 33.2750, FromLon = 44.3800,
            ToLat = 33.3250, ToLon = 44.3850,
            MidLat = 33.3000, MidLon = 44.3820,
            BaseSpeedKmh = 60.0
        },
        new BaghdadCorridor
        {
            Key = "corridor_jadriya",
            NameAr = "جسر الجادرية ومجمع الكليات",
            NameEn = "Al-Jadriya Bridge & University Corridor",
            FromLat = 33.2750, FromLon = 44.3700,
            ToLat = 33.2850, ToLon = 44.3950,
            MidLat = 33.2800, MidLon = 44.3820,
            BaseSpeedKmh = 50.0
        },
        new BaghdadCorridor
        {
            Key = "corridor_jumhuriya",
            NameAr = "جسر الجمهورية وساحة التحرير",
            NameEn = "Al-Jumhuriya Bridge & Tahrir Square",
            FromLat = 33.3250, FromLon = 44.3980,
            ToLat = 33.3290, ToLon = 44.4080,
            MidLat = 33.3270, MidLon = 44.4030,
            BaseSpeedKmh = 45.0
        },
        new BaghdadCorridor
        {
            Key = "corridor_senak",
            NameAr = "جسر السنك وباب الشرقي",
            NameEn = "Al-Senak Bridge & Bab Al-Sharqi",
            FromLat = 33.3320, FromLon = 44.3950,
            ToLat = 33.3360, ToLon = 44.4040,
            MidLat = 33.3340, MidLon = 44.3990,
            BaseSpeedKmh = 40.0
        },
        new BaghdadCorridor
        {
            Key = "corridor_sarafiya",
            NameAr = "جسر الصرافية وباب المعظم",
            NameEn = "Al-Sarafiya Bridge & Bab Al-Muadham",
            FromLat = 33.3550, FromLon = 44.3800,
            ToLat = 33.3580, ToLon = 44.3950,
            MidLat = 33.3560, MidLon = 44.3880,
            BaseSpeedKmh = 50.0
        },
        new BaghdadCorridor
        {
            Key = "corridor_matar",
            NameAr = "طريق مطار بغداد الدولي",
            NameEn = "Baghdad Airport Road",
            FromLat = 33.2900, FromLon = 44.3500,
            ToLat = 33.2600, ToLon = 44.2500,
            MidLat = 33.2750, MidLon = 44.3000,
            BaseSpeedKmh = 90.0
        },
        new BaghdadCorridor
        {
            Key = "corridor_mansour",
            NameAr = "شارع 14 رمضان (المنصور)",
            NameEn = "14 Ramadan Street (Al-Mansour)",
            FromLat = 33.3150, FromLon = 44.3550,
            ToLat = 33.3300, ToLon = 44.3400,
            MidLat = 33.3220, MidLon = 44.3480,
            BaseSpeedKmh = 45.0
        }
    };

    public async Task HarvestBaghdadTrafficAsync(CancellationToken cancellationToken = default)
    {
        var apiKey = _config["TomTom:ApiKey"] ?? _config["TOMTOM_API_KEY"] ?? "CgwtGL5BO5Ud28PzXsFzxzH7xNgUxsij";
        if (string.IsNullOrWhiteSpace(apiKey))
        {
            _logger.LogWarning("No TomTom API Key configured. Skipping traffic harvesting.");
            return;
        }

        _logger.LogInformation("Harvesting real-time traffic for Baghdad key corridors using TomTom API...");

        using var scope = _serviceProvider.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<DarbDbContext>();
        var now = DateTime.UtcNow;

        foreach (var corridor in Corridors)
        {
            if (cancellationToken.IsCancellationRequested) break;

            try
            {
                var url = $"https://api.tomtom.com/routing/1/calculateRoute/{corridor.FromLat.ToString(System.Globalization.CultureInfo.InvariantCulture)},{corridor.FromLon.ToString(System.Globalization.CultureInfo.InvariantCulture)}:{corridor.ToLat.ToString(System.Globalization.CultureInfo.InvariantCulture)},{corridor.ToLon.ToString(System.Globalization.CultureInfo.InvariantCulture)}/json?traffic=true&computeTravelTimeFor=all&key={apiKey}";
                
                var res = await _httpClient.GetAsync(url, cancellationToken);
                if (!res.IsSuccessStatusCode)
                {
                    _logger.LogWarning("TomTom responded with status {Status} for corridor {Key}", res.StatusCode, corridor.Key);
                    continue;
                }

                var jsonStr = await res.Content.ReadAsStringAsync(cancellationToken);
                using var doc = JsonDocument.Parse(jsonStr);

                if (!doc.RootElement.TryGetProperty("routes", out var routes) || routes.GetArrayLength() == 0)
                    continue;

                var summary = routes[0].GetProperty("summary");
                var lengthMeters = summary.GetProperty("lengthInMeters").GetDouble();
                var travelTimeSec = summary.GetProperty("travelTimeInSeconds").GetDouble();
                var noTrafficSec = summary.GetProperty("noTrafficTravelTimeInSeconds").GetDouble();
                var delaySec = summary.TryGetProperty("trafficDelayInSeconds", out var d) ? d.GetDouble() : 0.0;

                // Calculate actual speed vs baseline speed
                var currentSpeedKmh = travelTimeSec > 0 ? (lengthMeters / 1000.0) / (travelTimeSec / 3600.0) : corridor.BaseSpeedKmh;
                var normalSpeedKmh = noTrafficSec > 0 ? (lengthMeters / 1000.0) / (noTrafficSec / 3600.0) : corridor.BaseSpeedKmh;

                string congestionLevel = "free";
                if (delaySec > 0 || currentSpeedKmh < normalSpeedKmh * 0.85)
                {
                    var speedRatio = currentSpeedKmh / Math.Max(1.0, normalSpeedKmh);
                    if (speedRatio < 0.35 || delaySec >= 600)
                        congestionLevel = "standstill";
                    else if (speedRatio < 0.65 || delaySec >= 300)
                        congestionLevel = "heavy";
                    else if (speedRatio < 0.85 || delaySec >= 60)
                        congestionLevel = "moderate";
                }

                // Upsert into local database
                var aggregate = await db.RoadTrafficAggregates
                    .FirstOrDefaultAsync(a => a.SegmentKey == corridor.Key, cancellationToken);

                if (aggregate == null)
                {
                    aggregate = new RoadTrafficAggregate
                    {
                        Id = Guid.NewGuid().ToString("N"),
                        SegmentKey = corridor.Key,
                        RoadName = corridor.NameAr,
                        Latitude = corridor.MidLat,
                        Longitude = corridor.MidLon,
                        AverageSpeedKmh = Math.Round(currentSpeedKmh, 1),
                        NormalSpeedKmh = Math.Round(normalSpeedKmh, 1),
                        SampleCount = 10,
                        CongestionLevel = congestionLevel,
                        DelaySeconds = Math.Round(delaySec, 0),
                        Confidence = 0.95,
                        UpdatedAt = now
                    };
                    db.RoadTrafficAggregates.Add(aggregate);
                }
                else
                {
                    aggregate.AverageSpeedKmh = Math.Round(currentSpeedKmh, 1);
                    aggregate.NormalSpeedKmh = Math.Round(normalSpeedKmh, 1);
                    aggregate.CongestionLevel = congestionLevel;
                    aggregate.DelaySeconds = Math.Round(delaySec, 0);
                    aggregate.UpdatedAt = now;
                    aggregate.Confidence = 0.95;
                }

                _logger.LogInformation("Updated traffic for {Name}: {Speed} km/h (Normal: {Normal} km/h) -> {Level} (Delay: {Delay}s)",
                    corridor.NameAr, Math.Round(currentSpeedKmh, 1), Math.Round(normalSpeedKmh, 1), congestionLevel, (int)delaySec);

                // Polite 500ms throttle between queries
                await Task.Delay(TimeSpan.FromMilliseconds(500), cancellationToken);
            }
            catch (Exception ex)
            {
                _logger.LogWarning(ex, "Failed to harvest traffic for corridor {Key}", corridor.Key);
            }
        }

        await db.SaveChangesAsync(cancellationToken);
    }
}
