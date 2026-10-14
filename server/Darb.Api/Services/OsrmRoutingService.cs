using System.Text.Json;
using Microsoft.EntityFrameworkCore;
using Darb.Api.Data;
using Darb.Api.Models;

namespace Darb.Api.Services;

public interface IOsrmRoutingService
{
    Task<List<RouteResultDto>> GetRoutesAsync(double fromLon, double fromLat, double toLon, double toLat, bool alternatives = true, double? bearing = null, CancellationToken cancellationToken = default);
}

public class OsrmRoutingService : IOsrmRoutingService
{
    private readonly HttpClient _httpClient;
    private readonly IConfiguration _config;
    private readonly IServiceProvider _serviceProvider;
    private readonly ILogger<OsrmRoutingService> _logger;

    public OsrmRoutingService(
        HttpClient httpClient,
        IConfiguration config,
        IServiceProvider serviceProvider,
        ILogger<OsrmRoutingService> logger)
    {
        _httpClient = httpClient;
        _config = config;
        _serviceProvider = serviceProvider;
        _logger = logger;
    }

    public async Task<List<RouteResultDto>> GetRoutesAsync(
        double fromLon, double fromLat,
        double toLon, double toLat,
        bool alternatives = true,
        double? bearing = null,
        CancellationToken cancellationToken = default)
    {
        var osrmBaseUrl = _config["OSRM_BASE_URL"] ?? "http://osrm:5000";
        var coordStr = $"{fromLon.ToString(System.Globalization.CultureInfo.InvariantCulture)},{fromLat.ToString(System.Globalization.CultureInfo.InvariantCulture)};{toLon.ToString(System.Globalization.CultureInfo.InvariantCulture)},{toLat.ToString(System.Globalization.CultureInfo.InvariantCulture)}";

        string BuildUrl(bool withBearing)
        {
            var bearingParam = withBearing && bearing.HasValue ? $"&bearings={Math.Round((bearing.Value % 360 + 360) % 360)},60;" : "";
            return $"{osrmBaseUrl.TrimEnd('/')}/route/v1/driving/{coordStr}?alternatives={(alternatives ? "true" : "false")}&steps=true&geometries=geojson&overview=full{bearingParam}";
        }

        JsonDocument? doc = null;
        try
        {
            var response = await _httpClient.GetAsync(BuildUrl(bearing.HasValue), cancellationToken);
            if (response.IsSuccessStatusCode)
            {
                var content = await response.Content.ReadAsStringAsync(cancellationToken);
                var parsed = JsonDocument.Parse(content);
                if (parsed.RootElement.TryGetProperty("code", out var c) && c.GetString() == "Ok")
                {
                    doc = parsed;
                }
            }

            // Fallback without bearing if bearing was too strict or returned NoRoute / NoSegment
            if (doc == null && bearing.HasValue)
            {
                var fallbackRes = await _httpClient.GetAsync(BuildUrl(false), cancellationToken);
                if (fallbackRes.IsSuccessStatusCode)
                {
                    var content = await fallbackRes.Content.ReadAsStringAsync(cancellationToken);
                    doc = JsonDocument.Parse(content);
                }
            }

            if (doc == null)
            {
                _logger.LogWarning("OSRM could not find route for coordinates");
                return [];
            }
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to connect to OSRM service at {Url}", osrmBaseUrl);
            return [];
        }

        var root = doc.RootElement;
        if (!root.TryGetProperty("code", out var code) || code.GetString() != "Ok" ||
            !root.TryGetProperty("routes", out var routesElement) || routesElement.ValueKind != JsonValueKind.Array)
        {
            return [];
        }

        // Fetch active traffic alerts and aggregates to score each route
        List<RoadTrafficAggregate> trafficAggregates = [];
        List<TrafficIncident> incidents = [];
        using (var scope = _serviceProvider.CreateScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<DarbDbContext>();
            var now = DateTime.UtcNow;
            try
            {
                incidents = await db.TrafficIncidents
                    .Where(i => i.ExpiresAt > now)
                    .ToListAsync(cancellationToken);

                trafficAggregates = await db.RoadTrafficAggregates
                    .Where(a => a.UpdatedAt > now.AddMinutes(-30) && a.CongestionLevel != "free")
                    .ToListAsync(cancellationToken);
            }
            catch (Exception ex)
            {
                _logger.LogWarning(ex, "Could not fetch DB traffic aggregates for route calculation");
            }
        }

        var results = new List<RouteResultDto>();
        int routeIdx = 0;

        foreach (var route in routesElement.EnumerateArray())
        {
            var distance = route.GetProperty("distance").GetDouble();
            var duration = route.GetProperty("duration").GetDouble();

            var coordinates = new List<List<double>>();
            var trafficPoints = new List<List<double>>();
            double trafficDelay = 0;

            if (route.TryGetProperty("geometry", out var geom) &&
                geom.TryGetProperty("coordinates", out var coords) &&
                coords.ValueKind == JsonValueKind.Array)
            {
                foreach (var pt in coords.EnumerateArray())
                {
                    if (pt.GetArrayLength() >= 2)
                    {
                        var lon = pt[0].GetDouble();
                        var lat = pt[1].GetDouble();
                        coordinates.Add([lon, lat]);

                        // Check proximity to active incidents (within ~80m / 0.0008 deg)
                        foreach (var inc in incidents)
                        {
                            var dLat = Math.Abs(lat - inc.Latitude);
                            var dLon = Math.Abs(lon - inc.Longitude);
                            if (dLat < 0.0008 && dLon < 0.0008)
                            {
                                trafficDelay += inc.Type switch
                                {
                                    "closure" => 1800,
                                    "crash" => 480 + (inc.Confirmations * 60),
                                    "traffic" => 300 + (inc.Confirmations * 60),
                                    "construction" => 240,
                                    _ => 60
                                };
                                trafficPoints.Add([lon, lat]);
                            }
                        }

                        // Check proximity to detected slowdowns
                        foreach (var agg in trafficAggregates)
                        {
                            var dLat = Math.Abs(lat - agg.Latitude);
                            var dLon = Math.Abs(lon - agg.Longitude);
                            if (dLat < 0.0008 && dLon < 0.0008)
                            {
                                trafficDelay += agg.DelaySeconds;
                                trafficPoints.Add([lon, lat]);
                            }
                        }
                    }
                }
            }

            var steps = new List<RouteStepDto>();
            if (route.TryGetProperty("legs", out var legs) && legs.ValueKind == JsonValueKind.Array)
            {
                foreach (var leg in legs.EnumerateArray())
                {
                    if (leg.TryGetProperty("steps", out var stepsArray) && stepsArray.ValueKind == JsonValueKind.Array)
                    {
                        foreach (var s in stepsArray.EnumerateArray())
                        {
                            var stepDist = s.GetProperty("distance").GetDouble();
                            var roadName = s.TryGetProperty("name", out var n) ? n.GetString() ?? "" : "";
                            var maneuverType = "straight";
                            double stepLat = 0, stepLon = 0;

                            if (s.TryGetProperty("maneuver", out var m))
                            {
                                if (m.TryGetProperty("type", out var t)) maneuverType = t.GetString() ?? "straight";
                                if (m.TryGetProperty("modifier", out var mod)) maneuverType += $" {mod.GetString()}";
                                if (m.TryGetProperty("location", out var loc) && loc.GetArrayLength() >= 2)
                                {
                                    stepLon = loc[0].GetDouble();
                                    stepLat = loc[1].GetDouble();
                                }
                            }

                            var (en, ar) = FormatInstruction(maneuverType, roadName);

                            steps.Add(new RouteStepDto
                            {
                                Instruction = en,
                                InstructionAr = ar,
                                Type = maneuverType,
                                Latitude = stepLat,
                                Longitude = stepLon,
                                DistanceMeters = stepDist,
                                RoadName = roadName
                            });
                        }
                    }
                }
            }

            results.Add(new RouteResultDto
            {
                Id = $"route-{routeIdx}",
                Name = routeIdx == 0 ? "Main Route" : $"Alternative Route {routeIdx}",
                NameAr = routeIdx == 0 ? "المسار الرئيسي" : $"مسار بديل {routeIdx}",
                DistanceMeters = distance,
                DurationSeconds = duration,
                TrafficDelaySeconds = trafficDelay,
                Coordinates = coordinates,
                Steps = steps,
                TrafficPoints = trafficPoints
            });

            routeIdx++;
        }

        // Rank by Total Duration (Duration + Traffic Delay) so FASTEST route is #1
        results.Sort((a, b) => a.TotalDurationSeconds.CompareTo(b.TotalDurationSeconds));
        if (results.Count > 0)
        {
            results[0].IsFastest = true;
        }

        return results;
    }

    private static (string En, string Ar) FormatInstruction(string maneuver, string road)
    {
        var roadSuffix = string.IsNullOrWhiteSpace(road) ? "" : $" onto {road}";
        var roadSuffixAr = string.IsNullOrWhiteSpace(road) ? "" : $" إلى {road}";

        var lower = maneuver.ToLowerInvariant();
        if (lower.Contains("left"))
            return ($"Turn left{roadSuffix}", $"انعطف يساراً{roadSuffixAr}");
        if (lower.Contains("right"))
            return ($"Turn right{roadSuffix}", $"انعطف يميناً{roadSuffixAr}");
        if (lower.Contains("roundabout"))
            return ($"Enter roundabout{roadSuffix}", $"ادخل الدوار{roadSuffixAr}");
        if (lower.Contains("uturn") || lower.Contains("u-turn"))
            return ($"Make a U-turn{roadSuffix}", $"قم بالدوران للخلف{roadSuffixAr}");
        if (lower.Contains("arrive") || lower.Contains("destination"))
            return ("You have arrived at your destination", "لقد وصلت إلى وجهتك");

        return ($"Continue straight{roadSuffix}", $"تابع السير للأمام{roadSuffixAr}");
    }
}
