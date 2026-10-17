using Darb.Api.Data;
using Darb.Api.Models;
using Darb.Api.Services;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.StaticFiles;
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
builder.Services.AddHttpClient<ITomTomTrafficHarvester, TomTomTrafficHarvester>();
builder.Services.AddScoped<ITomTomTrafficHarvester, TomTomTrafficHarvester>();
builder.Services.AddHostedService<TrafficAggregationWorker>();

// 3.1 Live Convoy & Family Room Tracking Service
builder.Services.AddSingleton<ILiveRoomService, LiveRoomService>();

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
app.UseDefaultFiles();

var contentTypeProvider = new FileExtensionContentTypeProvider();
contentTypeProvider.Mappings[".apk"] = "application/vnd.android.package-archive";
app.UseStaticFiles(new StaticFileOptions
{
    ContentTypeProvider = contentTypeProvider,
    ServeUnknownFileTypes = true
});

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
// AUTHENTICATION & DASHBOARD SECURITY CONFIGURATION
// -------------------------------------------------------------
var adminUser = app.Configuration["AdminAuth:Username"] ?? "admin";
var adminPass = app.Configuration["AdminAuth:Password"] ?? "darb_admin_2026";
var adminToken = app.Configuration["AdminAuth:Token"] ?? "darb_secret_token_ops_2026_authorized";

bool IsAuthorized(HttpContext context)
{
    var authHeader = context.Request.Headers["Authorization"].FirstOrDefault();
    if (!string.IsNullOrEmpty(authHeader) && authHeader.StartsWith("Bearer ", StringComparison.OrdinalIgnoreCase))
    {
        var token = authHeader["Bearer ".Length..].Trim();
        if (token == adminToken) return true;
    }
    if (context.Request.Query.TryGetValue("token", out var qToken) && qToken == adminToken)
    {
        return true;
    }
    return false;
}

// Admin login endpoint
app.MapPost("/api/auth/login", async (HttpContext context) =>
{
    try
    {
        var req = await context.Request.ReadFromJsonAsync<LoginRequest>();
        if (req != null && req.Username == adminUser && req.Password == adminPass)
        {
            return Results.Ok(new
            {
                success = true,
                token = adminToken,
                username = adminUser,
                message = "Authenticated successfully."
            });
        }
    }
    catch { }
    return Results.Json(new { success = false, error = "اسم المستخدم أو كلمة المرور غير صحيحة" }, statusCode: 401);
})
.WithName("AdminLogin");

app.MapGet("/api/auth/verify", (HttpContext ctx) =>
{
    if (IsAuthorized(ctx))
    {
        return Results.Ok(new { valid = true, username = adminUser });
    }
    return Results.Unauthorized();
})
.WithName("VerifyAdminAuth");

// App version & update info endpoint (100% Public)
app.MapGet("/api/app/version", () => Results.Ok(new
{
    versionCode = 7,
    versionName = "1.0.7",
    apkUrl = "http://139.185.47.123:5000/darb.apk",
    apkSizeBytes = 87000000,
    publishedAt = DateTime.UtcNow,
    releaseNotesAr = "تكبير وتغميق الخطوط، جعل أزرار الإجراءات قابلة للتمرير والتجاوب، تصغير اللوحة السفلية لرؤية الخريطة بحجم كامل، ترتيب الأماكن الأقرب أولاً، ونقل زر البلاغات فوق عداد السرعة",
    releaseNotesEn = "Bolder typography, responsive scrollable pills, minimizable bottom sheet for full map view, nearest-first places sorting, and report button above speedometer"
}))
.WithName("GetAppVersion");

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
    [FromQuery] double? bearing,
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
        var routes = await routingService.GetRoutesAsync(fromLon, fromLat, toLon, toLat, alternatives, bearing, cancellationToken);
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
    [FromBody] ConfirmIncidentRequest? request,
    ITrafficIntelligenceService trafficService,
    CancellationToken cancellationToken) =>
{
    var confirmed = await trafficService.ConfirmIncidentAsync(id, request?.UserId, cancellationToken);
    if (!confirmed)
    {
        return Results.NotFound(new { error = $"Incident with ID '{id}' not found or user blocked." });
    }

    return Results.Ok(new { message = "Incident confirmed." });
})
.WithName("ConfirmIncident");

// Reject traffic incident / Still there? (Mobile driver vote: Not there / Gone)
app.MapPost("/api/traffic/incidents/{id}/reject", async (
    [FromRoute] string id,
    [FromBody] ConfirmIncidentRequest? request,
    ITrafficIntelligenceService trafficService,
    CancellationToken cancellationToken) =>
{
    var rejected = await trafficService.RejectIncidentAsync(id, request?.UserId, cancellationToken);
    if (!rejected)
    {
        return Results.NotFound(new { error = $"Incident with ID '{id}' not found." });
    }
    return Results.Ok(new { message = "Incident marked as not there." });
})
.WithName("RejectIncident");

// Delete traffic incident (Dashboard Admin control)
app.MapDelete("/api/traffic/incidents/{id}", async (
    [FromRoute] string id,
    HttpContext ctx,
    ITrafficIntelligenceService trafficService,
    CancellationToken cancellationToken) =>
{
    if (!IsAuthorized(ctx)) return Results.Unauthorized();
    var deleted = await trafficService.DeleteIncidentAsync(id, cancellationToken);
    if (!deleted)
    {
        return Results.NotFound(new { error = $"Incident '{id}' not found." });
    }
    return Results.Ok(new { message = "Incident deleted successfully." });
})
.WithName("DeleteIncident");

// Verify incident as permanent/long-term road warning (Speed Bump)
app.MapPost("/api/traffic/incidents/{id}/verify-warning", async (
    [FromRoute] string id,
    HttpContext ctx,
    ITrafficIntelligenceService trafficService,
    CancellationToken cancellationToken) =>
{
    if (!IsAuthorized(ctx)) return Results.Unauthorized();
    var verified = await trafficService.VerifyIncidentAsWarningAsync(id, cancellationToken);
    if (!verified)
    {
        return Results.NotFound(new { error = $"Incident '{id}' not found." });
    }
    return Results.Ok(new { message = "Incident verified as road warning." });
})
.WithName("VerifyIncidentAsWarning");

// User management endpoints (Dashboard Controls)
app.MapGet("/api/dashboard/users", async (
    HttpContext ctx,
    ITrafficIntelligenceService trafficService,
    CancellationToken cancellationToken) =>
{
    if (!IsAuthorized(ctx)) return Results.Unauthorized();
    var users = await trafficService.GetUsersAsync(cancellationToken);
    return Results.Ok(users);
})
.WithName("GetDashboardUsers");

app.MapPost("/api/dashboard/users/{userId}/toggle-block", async (
    [FromRoute] string userId,
    HttpContext ctx,
    ITrafficIntelligenceService trafficService,
    CancellationToken cancellationToken) =>
{
    if (!IsAuthorized(ctx)) return Results.Unauthorized();
    var success = await trafficService.ToggleUserBlockAsync(userId, cancellationToken);
    return Results.Ok(new { message = "User block status toggled.", success });
})
.WithName("ToggleUserBlock");

app.MapPost("/api/dashboard/users/{userId}/toggle-trust", async (
    [FromRoute] string userId,
    HttpContext ctx,
    ITrafficIntelligenceService trafficService,
    CancellationToken cancellationToken) =>
{
    if (!IsAuthorized(ctx)) return Results.Unauthorized();
    var success = await trafficService.ToggleUserTrustAsync(userId, cancellationToken);
    return Results.Ok(new { message = "User trust status toggled.", success });
})
.WithName("ToggleUserTrust");

app.MapDelete("/api/dashboard/users/{userId}", async (
    [FromRoute] string userId,
    HttpContext ctx,
    DarbDbContext db,
    CancellationToken ct) =>
{
    if (!IsAuthorized(ctx)) return Results.Unauthorized();
    var user = await db.Users.FindAsync([userId], ct);
    if (user != null)
    {
        db.Users.Remove(user);
        await db.SaveChangesAsync(ct);
        return Results.Ok(new { message = $"User '{userId}' deleted successfully." });
    }
    return Results.NotFound(new { error = $"User '{userId}' not found." });
})
.WithName("DeleteDashboardUser");

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

// Harvest live traffic from TomTom into PostGIS database
app.MapPost("/api/traffic/harvest", async (
    HttpContext ctx,
    ITomTomTrafficHarvester harvester,
    CancellationToken ct) =>
{
    if (!IsAuthorized(ctx)) return Results.Unauthorized();
    await harvester.HarvestBaghdadTrafficAsync(ct);
    return Results.Ok(new { message = "Baghdad traffic harvested successfully from TomTom into local database." });
})
.WithName("HarvestTraffic");

// -------------------------------------------------------------
// DASHBOARD & TELEMETRY ENDPOINTS
// -------------------------------------------------------------

app.MapGet("/dashboard", () => Results.Redirect("/index.html"))
   .WithName("DashboardRedirect");

app.MapGet("/darb.apk", (IWebHostEnvironment env) =>
{
    var candidates = new[]
    {
        Path.Combine(env.WebRootPath ?? "wwwroot", "darb.apk"),
        Path.Combine(AppContext.BaseDirectory, "wwwroot", "darb.apk"),
        "/app/wwwroot/darb.apk",
        "wwwroot/darb.apk"
    };

    var found = candidates.FirstOrDefault(File.Exists);
    if (found == null)
    {
        return Results.NotFound(new { error = "Darb APK file not found on server." });
    }

    return Results.File(found, "application/vnd.android.package-archive", "darb.apk");
})
.WithName("DownloadDarbApk");

app.MapGet("/qr", () => Results.Redirect("/qr.png"))
   .WithName("QrRedirect");

app.MapGet("/qr.png", (IWebHostEnvironment env) =>
{
    var candidates = new[]
    {
        Path.Combine(env.WebRootPath ?? "wwwroot", "qr.png"),
        Path.Combine(AppContext.BaseDirectory, "wwwroot", "qr.png"),
        "/app/wwwroot/qr.png",
        "wwwroot/qr.png"
    };
    var found = candidates.FirstOrDefault(File.Exists);
    return found != null ? Results.File(found, "image/png", "darb-qr.png") : Results.NotFound(new { error = "QR code not found." });
})
.WithName("GetQrPng");

app.MapGet("/qr.svg", (IWebHostEnvironment env) =>
{
    var candidates = new[]
    {
        Path.Combine(env.WebRootPath ?? "wwwroot", "qr.svg"),
        Path.Combine(AppContext.BaseDirectory, "wwwroot", "qr.svg"),
        "/app/wwwroot/qr.svg",
        "wwwroot/qr.svg"
    };
    var found = candidates.FirstOrDefault(File.Exists);
    return found != null ? Results.File(found, "image/svg+xml", "darb-qr.svg") : Results.NotFound(new { error = "QR SVG not found." });
})
.WithName("GetQrSvg");

app.MapGet("/api/dashboard/stats", async (
    HttpContext ctx,
    DarbDbContext db,
    IHttpClientFactory httpClientFactory,
    CancellationToken ct) =>
{
    if (!IsAuthorized(ctx)) return Results.Unauthorized();
    var now = DateTime.UtcNow;
    var tenMinsAgo = now.AddMinutes(-10);

    // Measure PostGIS latency
    var dbWatch = System.Diagnostics.Stopwatch.StartNew();
    var dbOk = false;
    try { dbOk = await db.Database.CanConnectAsync(ct); } catch {}
    dbWatch.Stop();

    // Measure OSRM routing latency
    var osrmWatch = System.Diagnostics.Stopwatch.StartNew();
    var osrmOk = false;
    try
    {
        var osrmClient = httpClientFactory.CreateClient(nameof(IOsrmRoutingService));
        var res = await osrmClient.GetAsync("/route/v1/driving/44.3661,33.3152;44.4009,33.3406?overview=false", ct);
        osrmOk = res.IsSuccessStatusCode;
    } catch {}
    osrmWatch.Stop();

    // Observations metrics
    var totalObservations = await db.GpsObservations.CountAsync(ct);
    var recentObservations = await db.GpsObservations
        .Where(o => o.ReceivedAt >= tenMinsAgo)
        .OrderByDescending(o => o.ReceivedAt)
        .Take(100)
        .ToListAsync(ct);

    // Group by SessionId to return exactly ONE latest position per active vehicle (No duplicate measurements!)
    var activeSessionIds = recentObservations
        .Where(o => !string.IsNullOrEmpty(o.SessionId))
        .Select(o => o.SessionId!)
        .Distinct()
        .ToList();

    var activeUsersDict = await db.Users
        .Where(u => activeSessionIds.Contains(u.UserId))
        .ToDictionaryAsync(u => u.UserId, ct);

    var latestVehicleFixes = recentObservations
        .Where(o => !string.IsNullOrEmpty(o.SessionId))
        .GroupBy(o => o.SessionId)
        .Select(g => g.First())
        .Select(o => {
            activeUsersDict.TryGetValue(o.SessionId!, out var user);
            return new {
                userId = o.SessionId,
                deviceModel = user?.DeviceModel ?? "Android Device",
                deviceName = user?.DeviceName ?? user?.DeviceModel ?? "هاتف محمول",
                osVersion = user?.OsVersion ?? "",
                status = user?.Status ?? "active",
                reportCount = user?.ReportCount ?? 0,
                confirmationCount = user?.ConfirmationCount ?? 0,
                latitude = o.Latitude,
                longitude = o.Longitude,
                speedKmh = Math.Round(o.SpeedKmh, 1),
                heading = Math.Round(o.Heading ?? 0.0, 0),
                observedAt = o.ObservedAt,
                lastSeenSecondsAgo = Math.Max(0, (int)(now - o.ReceivedAt).TotalSeconds)
            };
        })
        .ToList();

    var activeVehicles = latestVehicleFixes.Count;

    var avgSpeed = latestVehicleFixes.Count > 0
        ? Math.Round(latestVehicleFixes.Average(o => o.speedKmh), 1)
        : 0.0;

    // User metrics
    var totalUsersCount = await db.Users.CountAsync(ct);
    var blockedUsersCount = await db.Users.CountAsync(u => u.Status == "blocked", ct);
    var roadWarningsCount = await db.TrafficIncidents.CountAsync(i => i.IsRoadWarning && i.ExpiresAt > now, ct);
    var speedBumpsCount = await db.TrafficIncidents.CountAsync(i => i.Type == "bump" && i.ExpiresAt > now, ct);

    // Active incidents & road warnings
    var activeIncidents = await db.TrafficIncidents
        .Where(i => i.ExpiresAt > now)
        .OrderByDescending(i => i.IsRoadWarning)
        .ThenByDescending(i => i.CreatedAt)
        .Take(100)
        .Select(i => new {
            i.Id,
            i.Type,
            i.Description,
            i.Latitude,
            i.Longitude,
            ReportedAt = i.CreatedAt,
            i.Confirmations,
            i.IsVerified,
            i.IsRoadWarning,
            i.UserId,
            ExpiresInMin = Math.Max(0, (int)(i.ExpiresAt - now).TotalMinutes)
        })
        .ToListAsync(ct);

    // Congestion segments
    var congestionSegments = await db.RoadTrafficAggregates
        .Where(a => a.UpdatedAt >= now.AddMinutes(-30))
        .OrderByDescending(a => a.UpdatedAt)
        .Take(100)
        .Select(a => new {
            a.SegmentKey,
            a.RoadName,
            a.Latitude,
            a.Longitude,
            a.AverageSpeedKmh,
            a.NormalSpeedKmh,
            a.CongestionLevel,
            a.DelaySeconds,
            SamplesCount = a.SampleCount,
            a.UpdatedAt
        })
        .ToListAsync(ct);

    return Results.Ok(new
    {
        status = dbOk && osrmOk ? "Operational" : "Degraded",
        serverTime = now,
        targetCity = "Baghdad, Iraq",
        metrics = new
        {
            totalObservations,
            activeObservations10m = recentObservations.Count,
            activeVehicles,
            avgSpeedKmh = avgSpeed,
            activeIncidentsCount = activeIncidents.Count,
            roadWarningsCount,
            speedBumpsCount,
            totalUsersCount,
            blockedUsersCount,
            congestedSegmentsCount = congestionSegments.Count(s => s.CongestionLevel != "Free")
        },
        health = new
        {
            database = new { status = dbOk ? "Online" : "Offline", latencyMs = dbWatch.ElapsedMilliseconds },
            routingEngine = new { status = osrmOk ? "Online" : "Offline", latencyMs = osrmWatch.ElapsedMilliseconds }
        },
        recentIncidents = activeIncidents,
        congestionSegments,
        recentObservations = latestVehicleFixes,
        activeVehiclesList = latestVehicleFixes
    });
})
.WithName("GetDashboardStats");

// -------------------------------------------------------------
// LIVE CONVOY & FAMILY ROOM API
// -------------------------------------------------------------
app.MapPost("/api/rooms", ([FromBody] CreateLiveRoomRequest req, HttpContext ctx, ILiveRoomService roomService) =>
{
    var scheme = ctx.Request.Scheme;
    var host = ctx.Request.Host.Value;
    var baseUrl = $"{scheme}://{host}";
    var room = roomService.CreateRoom(req, baseUrl);
    return Results.Ok(room);
})
.WithName("CreateLiveRoom");

app.MapGet("/api/rooms/{code}", (string code, ILiveRoomService roomService) =>
{
    var room = roomService.GetRoom(code);
    if (room == null) return Results.NotFound(new { message = "الغرفة غير موجودة أو انتهت صلاحيتها." });
    return Results.Ok(room);
})
.WithName("GetLiveRoom");

app.MapPost("/api/rooms/{code}/ping", (string code, [FromBody] PingLiveRoomRequest req, ILiveRoomService roomService) =>
{
    var room = roomService.PingMember(code, req);
    if (room == null) return Results.NotFound(new { message = "الغرفة غير موجودة أو تم إغلاقها." });
    return Results.Ok(room);
})
.WithName("PingLiveRoom");

app.MapPost("/api/rooms/{code}/leave", (string code, [FromQuery] string memberId, ILiveRoomService roomService) =>
{
    var success = roomService.LeaveRoom(code, memberId);
    return Results.Ok(new { success });
})
.WithName("LeaveLiveRoom");

app.MapPost("/api/rooms/{code}/end", (string code, [FromBody] EndLiveRoomRequest req, ILiveRoomService roomService) =>
{
    var success = roomService.EndRoom(code, req?.RequesterId ?? "");
    return Results.Ok(new { success });
})
.WithName("EndLiveRoom");

app.MapPost("/api/rooms/{code}/destination", (string code, [FromBody] SetDestinationRequest req, ILiveRoomService roomService) =>
{
    var room = roomService.SetDestination(code, req);
    if (room == null) return Results.NotFound(new { message = "الغرفة غير موجودة أو تم إغلاقها." });
    return Results.Ok(room);
})
.WithName("SetLiveRoomDestination");

app.MapGet("/api/rooms", (ILiveRoomService roomService) =>
{
    return Results.Ok(roomService.GetAllActiveRooms());
})
.WithName("GetActiveRooms");

// Web tracker handler: /track/{code} -> serves track.html
app.MapGet("/track/{code}", async (string code, HttpContext ctx) =>
{
    ctx.Response.ContentType = "text/html; charset=utf-8";
    var filePath = Path.Combine(app.Environment.WebRootPath, "track.html");
    if (File.Exists(filePath))
    {
        await ctx.Response.SendFileAsync(filePath);
    }
    else
    {
        ctx.Response.Redirect($"/track.html?code={Uri.EscapeDataString(code)}");
    }
});

app.Run();
