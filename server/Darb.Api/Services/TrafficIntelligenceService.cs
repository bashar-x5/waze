using Microsoft.EntityFrameworkCore;
using Darb.Api.Data;
using Darb.Api.Models;

namespace Darb.Api.Services;

public interface ITrafficIntelligenceService
{
    Task<(bool Success, string? Error)> IngestObservationAsync(GpsObservationDto dto, CancellationToken cancellationToken = default);
    Task<List<TrafficConditionDto>> GetConditionsAsync(double? minLon, double? minLat, double? maxLon, double? maxLat, CancellationToken cancellationToken = default);
    Task<TrafficIncidentDto> ReportIncidentAsync(TrafficIncidentDto dto, CancellationToken cancellationToken = default);
    Task<bool> ConfirmIncidentAsync(string incidentId, CancellationToken cancellationToken = default);
    Task<List<TrafficIncidentDto>> GetIncidentsAsync(double? minLon, double? minLat, double? maxLon, double? maxLat, CancellationToken cancellationToken = default);
    Task AggregateTrafficAsync(CancellationToken cancellationToken = default);
}

public class TrafficIntelligenceService : ITrafficIntelligenceService
{
    private readonly DarbDbContext _db;
    private readonly ILogger<TrafficIntelligenceService> _logger;

    public TrafficIntelligenceService(DarbDbContext db, ILogger<TrafficIntelligenceService> logger)
    {
        _db = db;
        _logger = logger;
    }

    public async Task<(bool Success, string? Error)> IngestObservationAsync(GpsObservationDto dto, CancellationToken cancellationToken = default)
    {
        // 1. Geographic bounds validation (Iraq boundary: Lat 29.0 to 38.5, Lon 38.5 to 49.0)
        if (dto.Latitude < 29.0 || dto.Latitude > 38.5 || dto.Longitude < 38.5 || dto.Longitude > 49.0)
        {
            return (false, "Coordinates are outside Iraq boundary.");
        }

        // 2. Realistic speed limits validation (0 to 220 km/h)
        if (dto.SpeedKmh < 0 || dto.SpeedKmh > 220.0)
        {
            return (false, "Unrealistic speed value detected.");
        }

        // 3. Stale or future timestamp validation (within last 10 minutes, not future > 2 mins)
        var now = DateTime.UtcNow;
        if (dto.ObservedAt < now.AddMinutes(-10) || dto.ObservedAt > now.AddMinutes(2))
        {
            return (false, "Observation timestamp is stale or in the future.");
        }

        // 4. Rate-limiting check per anonymous session (maximum 1 observation per 3 seconds)
        if (!string.IsNullOrEmpty(dto.SessionId))
        {
            var recentCount = await _db.GpsObservations
                .Where(o => o.SessionId == dto.SessionId && o.ReceivedAt > now.AddSeconds(-3))
                .CountAsync(cancellationToken);

            if (recentCount > 0)
            {
                return (false, "Submission rate limit exceeded. Please wait.");
            }
        }

        var observation = new GpsObservation
        {
            Latitude = dto.Latitude,
            Longitude = dto.Longitude,
            SpeedKmh = dto.SpeedKmh,
            Heading = dto.Heading,
            ObservedAt = dto.ObservedAt,
            ReceivedAt = now,
            SessionId = dto.SessionId
        };

        _db.GpsObservations.Add(observation);
        await _db.SaveChangesAsync(cancellationToken);

        return (true, null);
    }

    public async Task<List<TrafficConditionDto>> GetConditionsAsync(double? minLon, double? minLat, double? maxLon, double? maxLat, CancellationToken cancellationToken = default)
    {
        var query = _db.RoadTrafficAggregates.AsNoTracking();

        if (minLat.HasValue && maxLat.HasValue && minLon.HasValue && maxLon.HasValue)
        {
            query = query.Where(a =>
                a.Latitude >= minLat.Value && a.Latitude <= maxLat.Value &&
                a.Longitude >= minLon.Value && a.Longitude <= maxLon.Value);
        }

        var list = await query
            .Where(a => a.UpdatedAt > DateTime.UtcNow.AddMinutes(-20))
            .OrderByDescending(a => a.UpdatedAt)
            .Take(200)
            .ToListAsync(cancellationToken);

        return list.Select(a => new TrafficConditionDto
        {
            SegmentKey = a.SegmentKey,
            RoadName = a.RoadName,
            Latitude = a.Latitude,
            Longitude = a.Longitude,
            SpeedKmh = a.AverageSpeedKmh,
            CongestionLevel = a.CongestionLevel,
            DelaySeconds = a.DelaySeconds,
            Confidence = a.Confidence,
            UpdatedAt = a.UpdatedAt
        }).ToList();
    }

    public async Task<TrafficIncidentDto> ReportIncidentAsync(TrafficIncidentDto dto, CancellationToken cancellationToken = default)
    {
        var incident = new TrafficIncident
        {
            Id = Guid.NewGuid().ToString("N")[..12],
            Type = dto.Type.ToLowerInvariant(),
            Latitude = dto.Latitude,
            Longitude = dto.Longitude,
            Description = dto.Description?.Trim() ?? "",
            CreatedAt = DateTime.UtcNow,
            ExpiresAt = DateTime.UtcNow.AddHours(1),
            Confirmations = 1
        };

        _db.TrafficIncidents.Add(incident);
        await _db.SaveChangesAsync(cancellationToken);

        return new TrafficIncidentDto
        {
            Id = incident.Id,
            Type = incident.Type,
            Latitude = incident.Latitude,
            Longitude = incident.Longitude,
            Description = incident.Description,
            CreatedAt = incident.CreatedAt,
            ExpiresAt = incident.ExpiresAt,
            Confirmations = incident.Confirmations
        };
    }

    public async Task<bool> ConfirmIncidentAsync(string incidentId, CancellationToken cancellationToken = default)
    {
        var incident = await _db.TrafficIncidents.FindAsync([incidentId], cancellationToken);
        if (incident == null || incident.ExpiresAt < DateTime.UtcNow) return false;

        incident.Confirmations++;
        incident.LastConfirmedAt = DateTime.UtcNow;
        incident.ExpiresAt = DateTime.UtcNow.AddHours(1); // Extend lifetime on confirmation

        if (incident.Confirmations >= 3)
        {
            incident.IsVerified = true;
        }

        await _db.SaveChangesAsync(cancellationToken);
        return true;
    }

    public async Task<List<TrafficIncidentDto>> GetIncidentsAsync(double? minLon, double? minLat, double? maxLon, double? maxLat, CancellationToken cancellationToken = default)
    {
        var now = DateTime.UtcNow;
        var query = _db.TrafficIncidents
            .AsNoTracking()
            .Where(i => i.ExpiresAt > now);

        if (minLat.HasValue && maxLat.HasValue && minLon.HasValue && maxLon.HasValue)
        {
            query = query.Where(i =>
                i.Latitude >= minLat.Value && i.Latitude <= maxLat.Value &&
                i.Longitude >= minLon.Value && i.Longitude <= maxLon.Value);
        }

        var list = await query
            .OrderByDescending(i => i.CreatedAt)
            .Take(100)
            .ToListAsync(cancellationToken);

        return list.Select(i => new TrafficIncidentDto
        {
            Id = i.Id,
            Type = i.Type,
            Latitude = i.Latitude,
            Longitude = i.Longitude,
            Description = i.Description,
            CreatedAt = i.CreatedAt,
            ExpiresAt = i.ExpiresAt,
            Confirmations = i.Confirmations
        }).ToList();
    }

    public async Task AggregateTrafficAsync(CancellationToken cancellationToken = default)
    {
        var now = DateTime.UtcNow;
        var windowStart = now.AddMinutes(-10);

        // Fetch observations from the last 10 minutes
        var recentObs = await _db.GpsObservations
            .Where(o => o.ObservedAt >= windowStart)
            .ToListAsync(cancellationToken);

        if (recentObs.Count == 0) return;

        // Group observations into spatial cells (~200m grid: step of ~0.002 deg)
        var clusters = recentObs
            .GroupBy(o => (
                LatCell: Math.Round(o.Latitude * 500) / 500,
                LonCell: Math.Round(o.Longitude * 500) / 500
            ))
            .ToList();

        foreach (var cluster in clusters)
        {
            var cellKey = $"cell_{cluster.Key.LatCell}_{cluster.Key.LonCell}";
            var count = cluster.Count();
            var speeds = cluster.Select(c => c.SpeedKmh).OrderBy(s => s).ToList();

            // Calculate robust trimmed average speed
            var avgSpeed = speeds.Skip(speeds.Count / 5).Take(Math.Max(1, speeds.Count - 2 * (speeds.Count / 5))).Average();
            const double normalSpeed = 50.0;

            var congestionLevel = "free";
            double delaySec = 0;

            if (avgSpeed < 12.0)
            {
                congestionLevel = "standstill";
                delaySec = 600; // +10 min
            }
            else if (avgSpeed < 22.0)
            {
                congestionLevel = "heavy";
                delaySec = 360; // +6 min
            }
            else if (avgSpeed < 35.0)
            {
                congestionLevel = "moderate";
                delaySec = 180; // +3 min
            }

            var confidence = Math.Min(1.0, count / 5.0);

            var existing = await _db.RoadTrafficAggregates.FirstOrDefaultAsync(a => a.SegmentKey == cellKey, cancellationToken);
            if (existing == null)
            {
                _db.RoadTrafficAggregates.Add(new RoadTrafficAggregate
                {
                    Id = Guid.NewGuid().ToString("N")[..12],
                    SegmentKey = cellKey,
                    RoadName = "Baghdad Corridor",
                    Latitude = cluster.Key.LatCell,
                    Longitude = cluster.Key.LonCell,
                    AverageSpeedKmh = Math.Round(avgSpeed, 1),
                    NormalSpeedKmh = normalSpeed,
                    SampleCount = count,
                    CongestionLevel = congestionLevel,
                    DelaySeconds = delaySec,
                    Confidence = Math.Round(confidence, 2),
                    UpdatedAt = now
                });
            }
            else
            {
                existing.AverageSpeedKmh = Math.Round(avgSpeed, 1);
                existing.SampleCount = count;
                existing.CongestionLevel = congestionLevel;
                existing.DelaySeconds = delaySec;
                existing.Confidence = Math.Round(confidence, 2);
                existing.UpdatedAt = now;
            }
        }

        // Privacy Retention Policy: Delete raw GPS points older than 2 hours
        var cutoff = now.AddHours(-2);
        await _db.GpsObservations.Where(o => o.ObservedAt < cutoff).ExecuteDeleteAsync(cancellationToken);

        // Expire old incidents
        await _db.TrafficIncidents.Where(i => i.ExpiresAt < now).ExecuteDeleteAsync(cancellationToken);

        await _db.SaveChangesAsync(cancellationToken);
    }
}
