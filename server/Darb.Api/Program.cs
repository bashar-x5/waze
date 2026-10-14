using Darb.Api.Data;
using Darb.Api.Models;
using Darb.Api.Services;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

var builder = WebApplication.CreateBuilder(args);

// 1. Database Configuration (PostgreSQL + PostGIS)
var connectionString = builder.Configuration.GetConnectionString("DefaultConnection") 
    ?? "Host=localhost;Port=5432;Database=darb_traffic;Username=darb_user;Password=darb_secure_pass_2026";

builder.Services.AddDbContext<DarbDbContext>(options =>
{
    options.UseNpgsql(connectionString, npgsqlOptions =>
    {
        npgsqlOptions.EnableRetryOnFailure(maxRetryCount: 3, maxRetryDelay: TimeSpan.FromSeconds(5), errorCodesToAdd: null);
    });
});

// 2. Routing Service (OSRM HTTP Client Proxy)
var osrmBaseUrl = builder.Configuration.GetValue<string>("Osrm:BaseUrl") ?? "http://localhost:5001";
builder.Services.AddHttpClient<IOsrmRoutingService, OsrmRoutingService>(client =>
{
    client.BaseAddress = new Uri(osrmBaseUrl);
    client.Timeout = TimeSpan.FromSeconds(8);
});

// 3. Traffic Intelligence & Background Aggregation
builder.Services.AddScoped<ITrafficIntelligenceService, TrafficIntelligenceService>();
builder.Services.AddHostedService<TrafficAggregationWorker>();

// 4. CORS Policy for mobile and web clients
builder.Services.AddCors(options =>
{
    options.AddPolicy("AllowAll", policy =>
    {
        policy.AllowAnyOrigin()
              .AllowAnyMethod()
              .AllowAnyHeader();
    });
});

builder.Services.AddOpenApi();

var app = builder.Build();

app.UseCors("AllowAll");

if (app.Environment.IsDevelopment())
{
    app.MapOpenApi();
}

// Ensure database schema and PostGIS extensions are initialized on startup
using (var scope = app.Services.CreateScope())
{
    var logger = scope.ServiceProvider.GetRequiredService<ILogger<Program>>();
    try
    {
        var db = scope.ServiceProvider.GetRequiredService<DarbDbContext>();
        await db.Database.EnsureCreatedAsync();
        await db.InitializePostGisAsync();
        logger.LogInformation("Database and PostGIS extensions verified.");
    }
    catch (Exception ex)
    {
        logger.LogWarning("Database initialization deferred: {Message}", ex.Message);
    }
}

// -------------------------------------------------------------
// ENDPOINTS
// -------------------------------------------------------------

// Health check endpoint
app.MapGet("/health", async (DarbDbContext db, IHttpClientFactory httpClientFactory) =>
{
    var dbStatus = "Offline";
    try
    {
        if (await db.Database.CanConnectAsync())
        {
            dbStatus = "Online";
        }
    }
    catch
    {
        dbStatus = "Error/Connecting";
    }

    var osrmStatus = "Offline";
    try
    {
        var osrmClient = httpClientFactory.CreateClient(nameof(IOsrmRoutingService));
        var osrmRes = await osrmClient.GetAsync("/route/v1/driving/44.3661,33.3152;44.4009,33.3406?overview=false");
        if (osrmRes.IsSuccessStatusCode)
        {
            osrmStatus = "Online";
        }
    }
    catch
    {
        osrmStatus = "Unavailable";
    }

    return Results.Ok(new
    {
        status = dbStatus == "Online" ? "Healthy" : "Degraded",
        timestamp = DateTime.UtcNow,
        targetArea = "Baghdad, Iraq",
        services = new
        {
            database = dbStatus,
            routingEngine = osrmStatus
        }
    });
})
.WithName("HealthCheck");

// Routing endpoint (Proxies locally hosted OSRM with PostGIS live traffic overlay)
app.MapGet("/api/route", async (
    [FromQuery] double fromLon,
    [FromQuery] double fromLat,
    [FromQuery] double toLon,
    [FromQuery] double toLat,
    [FromQuery] bool alternatives,
    IOsrmRoutingService routingService,
    CancellationToken cancellationToken) =>
{
    // Validate Iraq/General coordinate bounds
    if (fromLat < -90 || fromLat > 90 || fromLon < -180 || fromLon > 180 ||
        toLat < -90 || toLat > 90 || toLon < -180 || toLon > 180)
    {
        return Results.BadRequest(new { error = "Invalid geographic coordinates provided." });
    }

    if (Math.Abs(fromLat - toLat) < 0.00001 && Math.Abs(fromLon - toLon) < 0.00001)
    {
        return Results.BadRequest(new { error = "Origin and destination coordinates are identical." });
    }

    try
    {
        var routes = await routingService.GetRoutesAsync(fromLon, fromLat, toLon, toLat, alternatives, cancellationToken);
        if (routes == null || routes.Count == 0)
        {
            return Results.NotFound(new { error = "No driving route could be found between the specified coordinates." });
        }
        return Results.Ok(routes);
    }
    catch (Exception ex)
    {
        return Results.Problem(detail: ex.Message, statusCode: 502);
    }
})
.WithName("GetDrivingRoute");

// GPS observation ingestion endpoint
app.MapPost("/api/traffic/observations", async (
    [FromBody] GpsObservationDto dto,
    ITrafficIntelligenceService trafficService,
    CancellationToken cancellationToken) =>
{
    if (dto == null)
    {
        return Results.BadRequest(new { error = "Observation payload is required." });
    }

    var (success, error) = await trafficService.IngestObservationAsync(dto, cancellationToken);
    if (!success)
    {
        return Results.BadRequest(new { error });
    }

    return Results.Accepted(value: new { message = "Observation received." });
})
.WithName("IngestGpsObservation");

// Live traffic conditions endpoint
app.MapGet("/api/traffic/conditions", async (
    [FromQuery] double? minLon,
    [FromQuery] double? minLat,
    [FromQuery] double? maxLon,
    [FromQuery] double? maxLat,
    ITrafficIntelligenceService trafficService,
    CancellationToken cancellationToken) =>
{
    var conditions = await trafficService.GetConditionsAsync(minLon, minLat, maxLon, maxLat, cancellationToken);
    return Results.Ok(conditions);
})
.WithName("GetTrafficConditions");

// Traffic incident reporting endpoint
app.MapPost("/api/traffic/incidents", async (
    [FromBody] TrafficIncidentDto dto,
    ITrafficIntelligenceService trafficService,
    CancellationToken cancellationToken) =>
{
    if (dto == null)
    {
        return Results.BadRequest(new { error = "Incident payload is required." });
    }

    if (string.IsNullOrWhiteSpace(dto.Type))
    {
        return Results.BadRequest(new { error = "Incident type is required." });
    }

    var created = await trafficService.ReportIncidentAsync(dto, cancellationToken);
    return Results.Created($"/api/traffic/incidents/{created.Id}", created);
})
.WithName("ReportIncident");

// Confirm existing traffic incident
app.MapPost("/api/traffic/incidents/{id}/confirm", async (
    [FromRoute] string id,
    ITrafficIntelligenceService trafficService,
    CancellationToken cancellationToken) =>
{
    var confirmed = await trafficService.ConfirmIncidentAsync(id, cancellationToken);
    if (!confirmed)
    {
        return Results.NotFound(new { error = $"Incident with ID '{id}' not found." });
    }

    return Results.Ok(new { message = "Incident confirmed." });
})
.WithName("ConfirmIncident");

// Retrieve traffic incidents
app.MapGet("/api/traffic/incidents", async (
    [FromQuery] double? minLon,
    [FromQuery] double? minLat,
    [FromQuery] double? maxLon,
    [FromQuery] double? maxLat,
    ITrafficIntelligenceService trafficService,
    CancellationToken cancellationToken) =>
{
    var incidents = await trafficService.GetIncidentsAsync(minLon, minLat, maxLon, maxLat, cancellationToken);
    return Results.Ok(incidents);
})
.WithName("GetTrafficIncidents");

app.Run();
