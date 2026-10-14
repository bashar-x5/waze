using System.Net;
using Darb.Api.Data;
using Darb.Api.Models;
using Darb.Api.Services;
using Microsoft.Data.Sqlite;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging.Abstractions;
using Xunit;

namespace Darb.Api.Tests;

public class OsrmRoutingServiceTests
{
    private class MockHttpMessageHandler : HttpMessageHandler
    {
        private readonly string _responseJson;

        public MockHttpMessageHandler(string responseJson)
        {
            _responseJson = responseJson;
        }

        protected override Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken cancellationToken)
        {
            var response = new HttpResponseMessage(HttpStatusCode.OK)
            {
                Content = new StringContent(_responseJson, System.Text.Encoding.UTF8, "application/json")
            };
            return Task.FromResult(response);
        }
    }

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
    public async Task GetRoutesAsync_ParsesOsrmResponseAndAppliesTrafficDelays()
    {
        var (db, conn) = CreateContext();
        using (conn)
        using (db)
        {
            // Seed a traffic delay corridor in Baghdad
            db.RoadTrafficAggregates.Add(new RoadTrafficAggregate
            {
                Id = "agg_1",
                SegmentKey = "cell_33.315_44.366",
                RoadName = "Baghdad 14th of July",
                Latitude = 33.3152,
                Longitude = 44.3661,
                AverageSpeedKmh = 10,
                NormalSpeedKmh = 50,
                CongestionLevel = "heavy",
                DelaySeconds = 360,
                Confidence = 0.9,
                UpdatedAt = DateTime.UtcNow
            });

            // Seed an incident on the route
            db.TrafficIncidents.Add(new TrafficIncident
            {
                Id = "inc_1",
                Type = "crash",
                Latitude = 33.3152,
                Longitude = 44.3661,
                Description = "Accident reported on route",
                CreatedAt = DateTime.UtcNow,
                ExpiresAt = DateTime.UtcNow.AddHours(1),
                Confirmations = 3,
                IsVerified = true
            });

            await db.SaveChangesAsync();

            var osrmMockJson = @"{
              ""code"": ""Ok"",
              ""routes"": [
                {
                  ""geometry"": {
                    ""coordinates"": [
                      [44.3661, 33.3152],
                      [44.3700, 33.3200],
                      [44.4009, 33.3406]
                    ],
                    ""type"": ""LineString""
                  },
                  ""legs"": [
                    {
                      ""steps"": [
                        {
                          ""name"": ""14th of July Bridge"",
                          ""distance"": 1200.5,
                          ""duration"": 140.0,
                          ""maneuver"": {
                            ""type"": ""depart"",
                            ""modifier"": ""straight"",
                            ""location"": [44.3661, 33.3152]
                          }
                        },
                        {
                          ""name"": ""Al-Kindi Street"",
                          ""distance"": 2500.0,
                          ""duration"": 300.0,
                          ""maneuver"": {
                            ""type"": ""turn"",
                            ""modifier"": ""right"",
                            ""location"": [44.3700, 33.3200]
                          }
                        }
                      ],
                      ""distance"": 3700.5,
                      ""duration"": 440.0
                    }
                  ],
                  ""distance"": 3700.5,
                  ""duration"": 440.0
                }
              ]
            }";

            var handler = new MockHttpMessageHandler(osrmMockJson);
            var httpClient = new HttpClient(handler) { BaseAddress = new Uri("http://localhost:5001") };

            var config = new ConfigurationBuilder().Build();

            var services = new ServiceCollection();
            services.AddScoped(_ => db);
            var serviceProvider = services.BuildServiceProvider();

            var routingService = new OsrmRoutingService(
                httpClient,
                config,
                serviceProvider,
                NullLogger<OsrmRoutingService>.Instance
            );

            var routes = await routingService.GetRoutesAsync(44.3661, 33.3152, 44.4009, 33.3406);

            Assert.NotNull(routes);
            Assert.Single(routes);

            var route = routes[0];
            Assert.Equal(3700.5, route.DistanceMeters);
            Assert.Equal(440.0, route.DurationSeconds);
            Assert.True(route.TrafficDelaySeconds > 0, "Route should include traffic delay from RoadTrafficAggregates and Incidents.");
            Assert.Equal(route.DurationSeconds + route.TrafficDelaySeconds, route.TotalDurationSeconds);
            Assert.NotEmpty(route.Coordinates);
            Assert.Equal(2, route.Steps.Count);
            Assert.Equal("14th of July Bridge", route.Steps[0].RoadName);
            Assert.NotEmpty(route.TrafficPoints);
        }
    }
}
