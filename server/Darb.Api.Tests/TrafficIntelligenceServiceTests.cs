using Darb.Api.Data;
using Darb.Api.Models;
using Darb.Api.Services;
using Microsoft.Data.Sqlite;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging.Abstractions;
using Xunit;

namespace Darb.Api.Tests;

public class TrafficIntelligenceServiceTests
{
    private (DarbDbContext Db, SqliteConnection Connection) CreateContext()
    {
        var connection = new SqliteConnection("DataSource=:memory:");
        connection.Open();

        var options = new DbContextOptionsBuilder<DarbDbContext>()
            .UseSqlite(connection)
            .Options;

        var db = new DarbDbContext(options);
        db.Database.EnsureCreated();
        return (db, connection);
    }

    [Fact]
    public async Task IngestObservationAsync_ValidBaghdadCoordinate_Succeeds()
    {
        var (db, conn) = CreateContext();
        using (conn)
        using (db)
        {
            var service = new TrafficIntelligenceService(db, NullLogger<TrafficIntelligenceService>.Instance);

            var dto = new GpsObservationDto
            {
                Latitude = 33.3152,
                Longitude = 44.3661,
                SpeedKmh = 45.0,
                Heading = 180.0,
                ObservedAt = DateTime.UtcNow,
                SessionId = "user_baghdad_1"
            };

            var (success, error) = await service.IngestObservationAsync(dto);

            Assert.True(success);
            Assert.Null(error);
            Assert.Equal(1, await db.GpsObservations.CountAsync());
        }
    }

    [Fact]
    public async Task IngestObservationAsync_OutsideIraqBoundary_Rejects()
    {
        var (db, conn) = CreateContext();
        using (conn)
        using (db)
        {
            var service = new TrafficIntelligenceService(db, NullLogger<TrafficIntelligenceService>.Instance);

            var dto = new GpsObservationDto
            {
                Latitude = 51.5074, // London
                Longitude = -0.1278,
                SpeedKmh = 50.0,
                ObservedAt = DateTime.UtcNow,
                SessionId = "user_abroad"
            };

            var (success, error) = await service.IngestObservationAsync(dto);

            Assert.False(success);
            Assert.Contains("Iraq boundary", error);
            Assert.Equal(0, await db.GpsObservations.CountAsync());
        }
    }

    [Fact]
    public async Task IngestObservationAsync_ExcessiveSpeed_Rejects()
    {
        var (db, conn) = CreateContext();
        using (conn)
        using (db)
        {
            var service = new TrafficIntelligenceService(db, NullLogger<TrafficIntelligenceService>.Instance);

            var dto = new GpsObservationDto
            {
                Latitude = 33.3152,
                Longitude = 44.3661,
                SpeedKmh = 290.0, // > 220 km/h
                ObservedAt = DateTime.UtcNow,
                SessionId = "user_speeder"
            };

            var (success, error) = await service.IngestObservationAsync(dto);

            Assert.False(success);
            Assert.Contains("Unrealistic speed", error);
        }
    }

    [Fact]
    public async Task IngestObservationAsync_StaleTimestamp_Rejects()
    {
        var (db, conn) = CreateContext();
        using (conn)
        using (db)
        {
            var service = new TrafficIntelligenceService(db, NullLogger<TrafficIntelligenceService>.Instance);

            var dto = new GpsObservationDto
            {
                Latitude = 33.3152,
                Longitude = 44.3661,
                SpeedKmh = 40.0,
                ObservedAt = DateTime.UtcNow.AddMinutes(-20), // 20 mins ago
                SessionId = "user_stale"
            };

            var (success, error) = await service.IngestObservationAsync(dto);

            Assert.False(success);
            Assert.Contains("stale", error);
        }
    }

    [Fact]
    public async Task IngestObservationAsync_RateLimiting_RejectsImmediateSecondSubmission()
    {
        var (db, conn) = CreateContext();
        using (conn)
        using (db)
        {
            var service = new TrafficIntelligenceService(db, NullLogger<TrafficIntelligenceService>.Instance);

            var dto1 = new GpsObservationDto
            {
                Latitude = 33.3152,
                Longitude = 44.3661,
                SpeedKmh = 30.0,
                ObservedAt = DateTime.UtcNow,
                SessionId = "spam_session_1"
            };

            var (success1, _) = await service.IngestObservationAsync(dto1);
            Assert.True(success1);

            // Immediate second submission (< 3s)
            var dto2 = new GpsObservationDto
            {
                Latitude = 33.3153,
                Longitude = 44.3662,
                SpeedKmh = 30.0,
                ObservedAt = DateTime.UtcNow,
                SessionId = "spam_session_1"
            };

            var (success2, error2) = await service.IngestObservationAsync(dto2);
            Assert.False(success2);
            Assert.Contains("rate limit exceeded", error2);
        }
    }

    [Fact]
    public async Task ReportAndConfirmIncident_IncreasesConfirmationCount()
    {
        var (db, conn) = CreateContext();
        using (conn)
        using (db)
        {
            var service = new TrafficIntelligenceService(db, NullLogger<TrafficIntelligenceService>.Instance);

            var incident = await service.ReportIncidentAsync(new TrafficIncidentDto
            {
                Type = "crash",
                Latitude = 33.3152,
                Longitude = 44.3661,
                Description = "Minor collision on Al-Jadriya bridge"
            });

            Assert.NotNull(incident.Id);
            Assert.Equal(1, incident.Confirmations);

            var confirmed = await service.ConfirmIncidentAsync(incident.Id);
            Assert.True(confirmed);

            var incidents = await service.GetIncidentsAsync(44.0, 33.0, 45.0, 34.0);
            Assert.Single(incidents);
            Assert.Equal(2, incidents[0].Confirmations);
        }
    }

    [Fact]
    public async Task AggregateTrafficAsync_CalculatesCongestionAndPrunesOldData()
    {
        var (db, conn) = CreateContext();
        using (conn)
        using (db)
        {
            var service = new TrafficIntelligenceService(db, NullLogger<TrafficIntelligenceService>.Instance);

            // Insert observations in Baghdad
            var now = DateTime.UtcNow;
            for (int i = 0; i < 5; i++)
            {
                db.GpsObservations.Add(new GpsObservation
                {
                    Id = i + 1,
                    Latitude = 33.3152,
                    Longitude = 44.3661,
                    SpeedKmh = 10.0, // Slow traffic -> standstill congestion (<12 km/h)
                    ObservedAt = now.AddMinutes(-2),
                    ReceivedAt = now.AddMinutes(-2)
                });
            }

            // Insert an old GPS observation (> 3 hours ago) to test retention pruning
            db.GpsObservations.Add(new GpsObservation
            {
                Id = 9999,
                Latitude = 33.3152,
                Longitude = 44.3661,
                SpeedKmh = 60.0,
                ObservedAt = now.AddHours(-4),
                ReceivedAt = now.AddHours(-4)
            });

            await db.SaveChangesAsync();

            await service.AggregateTrafficAsync();

            // Check road traffic aggregates
            var aggregates = await db.RoadTrafficAggregates.ToListAsync();
            Assert.NotEmpty(aggregates);
            var corridor = aggregates.First();
            Assert.Equal("standstill", corridor.CongestionLevel);
            Assert.True(corridor.DelaySeconds >= 600);

            // Verify privacy retention policy deleted raw trace older than 2 hours
            var oldExists = await db.GpsObservations.AnyAsync(o => o.Id == 9999);
            Assert.False(oldExists);
        }
    }
}
