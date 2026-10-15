using Microsoft.EntityFrameworkCore;
using Darb.Api.Data;
using Darb.Api.Models;

namespace Darb.Api.Services;

public interface ITrafficIntelligenceService
{
    Task<(bool Success, string? Error)> IngestObservationAsync(GpsObservationDto dto, CancellationToken cancellationToken = default);
    Task<List<TrafficConditionDto>> GetConditionsAsync(double? minLon, double? minLat, double? maxLon, double? maxLat, CancellationToken cancellationToken = default);
    Task<TrafficIncidentDto> ReportIncidentAsync(TrafficIncidentDto dto, CancellationToken cancellationToken = default);
    Task<bool> ConfirmIncidentAsync(string incidentId, string? userId = null, CancellationToken cancellationToken = default);
    Task<List<TrafficIncidentDto>> GetIncidentsAsync(double? minLon, double? minLat, double? maxLon, double? maxLat, CancellationToken cancellationToken = default);
    Task AggregateTrafficAsync(CancellationToken cancellationToken = default);
    Task<List<DarbUserDto>> GetUsersAsync(CancellationToken cancellationToken = default);
    Task<bool> ToggleUserBlockAsync(string userId, CancellationToken cancellationToken = default);
    Task<bool> ToggleUserTrustAsync(string userId, CancellationToken cancellationToken = default);
    Task<bool> DeleteIncidentAsync(string incidentId, CancellationToken cancellationToken = default);
    Task<bool> VerifyIncidentAsWarningAsync(string incidentId, CancellationToken cancellationToken = default);
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

            // Track user device in DarbUser table
            var user = await _db.Users.FindAsync([dto.SessionId], cancellationToken);
            if (user == null)
            {
                user = new DarbUser
                {
                    UserId = dto.SessionId,
                    DeviceModel = dto.DeviceModel,
                    DeviceName = dto.DeviceName,
                    OsVersion = dto.OsVersion,
                    FirstSeenAt = now,
                    LastSeenAt = now,
                    Status = "active",
                    LastLatitude = dto.Latitude,
                    LastLongitude = dto.Longitude,
                    LastSpeedKmh = dto.SpeedKmh
                };
                _db.Users.Add(user);
            }
            else
            {
                if (user.Status == "blocked")
                {
                    return (false, "User device is blocked.");
                }
                user.LastSeenAt = now;
                user.LastLatitude = dto.Latitude;
                user.LastLongitude = dto.Longitude;
                user.LastSpeedKmh = dto.SpeedKmh;
                if (!string.IsNullOrEmpty(dto.DeviceModel)) user.DeviceModel = dto.DeviceModel;
                if (!string.IsNullOrEmpty(dto.DeviceName)) user.DeviceName = dto.DeviceName;
                if (!string.IsNullOrEmpty(dto.OsVersion)) user.OsVersion = dto.OsVersion;
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
        var rawType = dto.Type?.Trim().ToLowerInvariant() ?? "traffic";
        var isBumpReport = rawType == "bump" ||
            (!string.IsNullOrEmpty(dto.Description) && (
                dto.Description.Contains("pump", StringComparison.OrdinalIgnoreCase) ||
                dto.Description.Contains("bump", StringComparison.OrdinalIgnoreCase) ||
                dto.Description.Contains("طسة", StringComparison.OrdinalIgnoreCase) ||
                dto.Description.Contains("طسه", StringComparison.OrdinalIgnoreCase) ||
                dto.Description.Contains("مطب", StringComparison.OrdinalIgnoreCase)
            ));

        var type = isBumpReport ? "bump" : rawType;
        var now = DateTime.UtcNow;

        // User tracking and status verification
        var isTrustedUser = false;
        if (!string.IsNullOrEmpty(dto.UserId))
        {
            var user = await _db.Users.FindAsync([dto.UserId], cancellationToken);
            if (user == null)
            {
                user = new DarbUser
                {
                    UserId = dto.UserId,
                    DeviceModel = dto.DeviceModel,
                    DeviceName = dto.DeviceName,
                    FirstSeenAt = now,
                    LastSeenAt = now,
                    ReportCount = 1,
                    Status = "active",
                    LastLatitude = dto.Latitude,
                    LastLongitude = dto.Longitude
                };
                _db.Users.Add(user);
            }
            else
            {
                if (user.Status == "blocked")
                {
                    throw new InvalidOperationException("User device is blocked.");
                }
                user.ReportCount++;
                user.LastSeenAt = now;
                user.LastLatitude = dto.Latitude;
                user.LastLongitude = dto.Longitude;
                if (!string.IsNullOrEmpty(dto.DeviceModel)) user.DeviceModel = dto.DeviceModel;
                if (!string.IsNullOrEmpty(dto.DeviceName)) user.DeviceName = dto.DeviceName;
                if (user.Status == "trusted") isTrustedUser = true;
            }
        }

        var incident = new TrafficIncident
        {
            Id = Guid.NewGuid().ToString("N")[..12],
            Type = type,
            Latitude = dto.Latitude,
            Longitude = dto.Longitude,
            Description = dto.Description?.Trim() ?? "",
            CreatedAt = now,
            ExpiresAt = now.AddHours(isBumpReport ? 24 : 1),
            Confirmations = 1,
            UserId = dto.UserId,
            IsVerified = isTrustedUser,
            IsRoadWarning = isTrustedUser && isBumpReport
        };

        // 3-Users Speed Bump / Warning Rule:
        // If 3 users report pump/bump in the same place with different times it should be saved as warning in the map
        if (isBumpReport)
        {
            const double thresholdDeg = 0.00065; // ~70 meters
            var nearbyBumps = await _db.TrafficIncidents
                .Where(i => i.Type == "bump" &&
                            Math.Abs(i.Latitude - dto.Latitude) < thresholdDeg &&
                            Math.Abs(i.Longitude - dto.Longitude) < thresholdDeg)
                .ToListAsync(cancellationToken);

            var reportingUsers = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
            if (!string.IsNullOrEmpty(dto.UserId)) reportingUsers.Add(dto.UserId);

            foreach (var nb in nearbyBumps)
            {
                if (!string.IsNullOrEmpty(nb.UserId)) reportingUsers.Add(nb.UserId);
                var confs = await _db.IncidentConfirmations
                    .Where(c => c.IncidentId == nb.Id)
                    .Select(c => c.UserId)
                    .ToListAsync(cancellationToken);
                foreach (var cu in confs)
                {
                    if (!string.IsNullOrEmpty(cu)) reportingUsers.Add(cu);
                }
            }

            var distinctUserCount = Math.Max(reportingUsers.Count, nearbyBumps.Count + 1);

            if (distinctUserCount >= 3)
            {
                incident.IsVerified = true;
                incident.IsRoadWarning = true;
                incident.ExpiresAt = now.AddDays(90); // Long-term saved road warning
                incident.Confirmations = distinctUserCount;
                if (string.IsNullOrWhiteSpace(incident.Description) || !incident.Description.Contains("مطب"))
                {
                    incident.Description = "⚠️ مطب اصطناعي معتمد (تأكيد 3 سائقين) | Verified Speed Bump";
                }

                foreach (var nb in nearbyBumps)
                {
                    nb.IsVerified = true;
                    nb.IsRoadWarning = true;
                    nb.ExpiresAt = incident.ExpiresAt;
                }
                _logger.LogInformation("Speed bump cluster at {Lat},{Lon} reached {Count} unique users. Saved as road warning.", dto.Latitude, dto.Longitude, distinctUserCount);
            }
        }

        _db.TrafficIncidents.Add(incident);

        if (!string.IsNullOrEmpty(dto.UserId))
        {
            _db.IncidentConfirmations.Add(new IncidentConfirmation
            {
                IncidentId = incident.Id,
                UserId = dto.UserId,
                ConfirmedAt = now
            });
        }

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
            Confirmations = incident.Confirmations,
            IsVerified = incident.IsVerified,
            IsRoadWarning = incident.IsRoadWarning,
            UserId = incident.UserId
        };
    }

    public async Task<bool> ConfirmIncidentAsync(string incidentId, string? userId = null, CancellationToken cancellationToken = default)
    {
        var incident = await _db.TrafficIncidents.FindAsync([incidentId], cancellationToken);
        if (incident == null || incident.ExpiresAt < DateTime.UtcNow) return false;

        var now = DateTime.UtcNow;

        if (!string.IsNullOrEmpty(userId))
        {
            var user = await _db.Users.FindAsync([userId], cancellationToken);
            if (user != null && user.Status == "blocked") return false;

            var alreadyConfirmed = await _db.IncidentConfirmations
                .AnyAsync(c => c.IncidentId == incidentId && c.UserId == userId, cancellationToken);

            if (!alreadyConfirmed)
            {
                _db.IncidentConfirmations.Add(new IncidentConfirmation
                {
                    IncidentId = incidentId,
                    UserId = userId,
                    ConfirmedAt = now
                });
                incident.Confirmations++;
                if (user != null)
                {
                    user.ConfirmationCount++;
                    user.LastSeenAt = now;
                }
            }
        }
        else
        {
            incident.Confirmations++;
        }

        incident.LastConfirmedAt = now;

        // Check if 3 users rule reached for bumps or general incidents
        if (incident.Type == "bump")
        {
            var totalUniqueUsers = await _db.IncidentConfirmations
                .Where(c => c.IncidentId == incidentId)
                .Select(c => c.UserId)
                .Distinct()
                .CountAsync(cancellationToken);

            if (!string.IsNullOrEmpty(incident.UserId)) totalUniqueUsers++;

            if (totalUniqueUsers >= 3 || incident.Confirmations >= 3)
            {
                incident.IsVerified = true;
                incident.IsRoadWarning = true;
                incident.ExpiresAt = now.AddDays(90);
                if (string.IsNullOrWhiteSpace(incident.Description) || !incident.Description.Contains("مطب"))
                {
                    incident.Description = "⚠️ مطب اصطناعي معتمد (تأكيد 3 سائقين) | Verified Speed Bump";
                }
            }
            else
            {
                incident.ExpiresAt = now.AddHours(2);
            }
        }
        else
        {
            if (incident.Confirmations >= 3)
            {
                incident.IsVerified = true;
            }
            incident.ExpiresAt = now.AddHours(1);
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
            .OrderByDescending(i => i.IsRoadWarning)
            .ThenByDescending(i => i.CreatedAt)
            .Take(150)
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
            Confirmations = i.Confirmations,
            IsVerified = i.IsVerified,
            IsRoadWarning = i.IsRoadWarning,
            UserId = i.UserId
        }).ToList();
    }

    public async Task<List<DarbUserDto>> GetUsersAsync(CancellationToken cancellationToken = default)
    {
        var users = await _db.Users
            .AsNoTracking()
            .OrderByDescending(u => u.LastSeenAt)
            .Take(100)
            .ToListAsync(cancellationToken);

        return users.Select(u => new DarbUserDto
        {
            UserId = u.UserId,
            DeviceModel = u.DeviceModel,
            DeviceName = u.DeviceName,
            OsVersion = u.OsVersion,
            FirstSeenAt = u.FirstSeenAt,
            LastSeenAt = u.LastSeenAt,
            ReportCount = u.ReportCount,
            ConfirmationCount = u.ConfirmationCount,
            Status = u.Status,
            LastLatitude = u.LastLatitude,
            LastLongitude = u.LastLongitude,
            LastSpeedKmh = u.LastSpeedKmh
        }).ToList();
    }

    public async Task<bool> ToggleUserBlockAsync(string userId, CancellationToken cancellationToken = default)
    {
        var user = await _db.Users.FindAsync([userId], cancellationToken);
        if (user == null)
        {
            user = new DarbUser { UserId = userId, Status = "blocked" };
            _db.Users.Add(user);
        }
        else
        {
            user.Status = (user.Status == "blocked") ? "active" : "blocked";
        }
        await _db.SaveChangesAsync(cancellationToken);
        return true;
    }

    public async Task<bool> ToggleUserTrustAsync(string userId, CancellationToken cancellationToken = default)
    {
        var user = await _db.Users.FindAsync([userId], cancellationToken);
        if (user == null)
        {
            user = new DarbUser { UserId = userId, Status = "trusted" };
            _db.Users.Add(user);
        }
        else
        {
            user.Status = (user.Status == "trusted") ? "active" : "trusted";
        }
        await _db.SaveChangesAsync(cancellationToken);
        return true;
    }

    public async Task<bool> DeleteIncidentAsync(string incidentId, CancellationToken cancellationToken = default)
    {
        var incident = await _db.TrafficIncidents.FindAsync([incidentId], cancellationToken);
        if (incident == null) return false;

        _db.TrafficIncidents.Remove(incident);
        var confs = await _db.IncidentConfirmations
            .Where(c => c.IncidentId == incidentId)
            .ToListAsync(cancellationToken);
        _db.IncidentConfirmations.RemoveRange(confs);

        await _db.SaveChangesAsync(cancellationToken);
        return true;
    }

    public async Task<bool> VerifyIncidentAsWarningAsync(string incidentId, CancellationToken cancellationToken = default)
    {
        var incident = await _db.TrafficIncidents.FindAsync([incidentId], cancellationToken);
        if (incident == null) return false;

        incident.IsVerified = true;
        incident.IsRoadWarning = true;
        incident.ExpiresAt = DateTime.UtcNow.AddDays(90);
        if (string.IsNullOrWhiteSpace(incident.Description) || !incident.Description.Contains("مطب"))
        {
            incident.Description = "⚠️ مطب اصطناعي معتمد | Verified Road Warning";
        }
        await _db.SaveChangesAsync(cancellationToken);
        return true;
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
            // Distinct active users/vehicles in this cluster to prevent 1 mobile from creating false congestion
            var distinctVehicles = cluster
                .Select(c => string.IsNullOrEmpty(c.SessionId) ? $"legacy_{c.Id}" : c.SessionId)
                .Distinct()
                .Count();

            // Require at least 2 distinct vehicles to aggregate an automated cell
            if (distinctVehicles < 2) continue;

            var cellKey = $"cell_{cluster.Key.LatCell}_{cluster.Key.LonCell}";
            var count = distinctVehicles;
            var speeds = cluster
                .GroupBy(c => string.IsNullOrEmpty(c.SessionId) ? $"legacy_{c.Id}" : c.SessionId)
                .Select(g => g.OrderByDescending(c => c.ObservedAt).First().SpeedKmh)
                .OrderBy(s => s)
                .ToList();

            // Calculate robust trimmed average speed across unique vehicles
            var avgSpeed = speeds.Count > 2
                ? speeds.Skip(speeds.Count / 5).Take(Math.Max(1, speeds.Count - 2 * (speeds.Count / 5))).Average()
                : speeds.Average();
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
