using Microsoft.EntityFrameworkCore;
using Darb.Api.Models;

namespace Darb.Api.Data;

public class DarbDbContext : DbContext
{
    public DarbDbContext(DbContextOptions<DarbDbContext> options) : base(options) { }

    public DbSet<GpsObservation> GpsObservations => Set<GpsObservation>();
    public DbSet<RoadTrafficAggregate> RoadTrafficAggregates => Set<RoadTrafficAggregate>();
    public DbSet<TrafficIncident> TrafficIncidents => Set<TrafficIncident>();
    public DbSet<DarbUser> Users => Set<DarbUser>();
    public DbSet<IncidentConfirmation> IncidentConfirmations => Set<IncidentConfirmation>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        base.OnModelCreating(modelBuilder);

        modelBuilder.Entity<GpsObservation>(b =>
        {
            b.HasKey(e => e.Id);
            b.HasIndex(e => e.ObservedAt);
            b.HasIndex(e => new { e.Latitude, e.Longitude });
            b.HasIndex(e => e.SessionId);
        });

        modelBuilder.Entity<RoadTrafficAggregate>(b =>
        {
            b.HasKey(e => e.Id);
            b.HasIndex(e => e.SegmentKey).IsUnique();
            b.HasIndex(e => new { e.Latitude, e.Longitude });
            b.HasIndex(e => e.UpdatedAt);
        });

        modelBuilder.Entity<TrafficIncident>(b =>
        {
            b.HasKey(e => e.Id);
            b.HasIndex(e => e.Type);
            b.HasIndex(e => e.ExpiresAt);
            b.HasIndex(e => e.UserId);
            b.HasIndex(e => e.IsRoadWarning);
            b.HasIndex(e => new { e.Latitude, e.Longitude });
        });

        modelBuilder.Entity<DarbUser>(b =>
        {
            b.HasKey(e => e.UserId);
            b.HasIndex(e => e.LastSeenAt);
            b.HasIndex(e => e.Status);
        });

        modelBuilder.Entity<IncidentConfirmation>(b =>
        {
            b.HasKey(e => e.Id);
            b.HasIndex(e => new { e.IncidentId, e.UserId }).IsUnique();
        });
    }

    /// <summary>
    /// Executes PostGIS extension creation, spatial indexes, and retention policy.
    /// </summary>
    public async Task InitializePostGisAsync(CancellationToken cancellationToken = default)
    {
        try
        {
            // Enable PostGIS extension if available
            await Database.ExecuteSqlRawAsync("CREATE EXTENSION IF NOT EXISTS postgis;", cancellationToken);

            // Create spatial geometry columns & GIST indexes if PostGIS is installed
            await Database.ExecuteSqlRawAsync(@"
                DO $$
                BEGIN
                    IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'postgis') THEN
                        -- Create spatial index on GPS observations
                        IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE indexname = 'idx_gps_geom') THEN
                            CREATE INDEX idx_gps_geom ON ""GpsObservations"" USING GIST (
                                ST_SetSRID(ST_MakePoint(""Longitude"", ""Latitude""), 4326)
                            );
                        END IF;

                        -- Create spatial index on Incidents
                        IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE indexname = 'idx_incidents_geom') THEN
                            CREATE INDEX idx_incidents_geom ON ""TrafficIncidents"" USING GIST (
                                ST_SetSRID(ST_MakePoint(""Longitude"", ""Latitude""), 4326)
                            );
                        END IF;
                    END IF;
                END $$;
            ", cancellationToken);
        }
        catch
        {
            // Fall back gracefully if DB user doesn't have superuser for extension creation
        }
    }
}
