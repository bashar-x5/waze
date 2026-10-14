using System.Text.Json.Serialization;

namespace Darb.Api.Models;

public class GpsObservation
{
    public long Id { get; set; }
    public double Latitude { get; set; }
    public double Longitude { get; set; }
    public double SpeedKmh { get; set; }
    public double? Heading { get; set; }
    public DateTime ObservedAt { get; set; }
    public DateTime ReceivedAt { get; set; } = DateTime.UtcNow;
    public string? SessionId { get; set; }
}

public class GpsObservationDto
{
    [JsonPropertyName("latitude")]
    public double Latitude { get; set; }

    [JsonPropertyName("longitude")]
    public double Longitude { get; set; }

    [JsonPropertyName("speedKmh")]
    public double SpeedKmh { get; set; }

    [JsonPropertyName("heading")]
    public double? Heading { get; set; }

    [JsonPropertyName("observedAt")]
    public DateTime ObservedAt { get; set; }

    [JsonPropertyName("sessionId")]
    public string? SessionId { get; set; }
}

public class TrafficIncident
{
    public string Id { get; set; } = string.Empty;
    public string Type { get; set; } = string.Empty; // police, traffic, hazard, crash, closure, construction, weather, camera
    public double Latitude { get; set; }
    public double Longitude { get; set; }
    public string Description { get; set; } = string.Empty;
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    public DateTime ExpiresAt { get; set; } = DateTime.UtcNow.AddHours(1);
    public int Confirmations { get; set; } = 0;
    public bool IsVerified { get; set; } = false;
    public DateTime? LastConfirmedAt { get; set; }
}

public class TrafficIncidentDto
{
    [JsonPropertyName("id")]
    public string? Id { get; set; }

    [JsonPropertyName("type")]
    public string Type { get; set; } = string.Empty;

    [JsonPropertyName("latitude")]
    public double Latitude { get; set; }

    [JsonPropertyName("longitude")]
    public double Longitude { get; set; }

    [JsonPropertyName("description")]
    public string Description { get; set; } = string.Empty;

    [JsonPropertyName("createdAt")]
    public DateTime? CreatedAt { get; set; }

    [JsonPropertyName("expiresAt")]
    public DateTime? ExpiresAt { get; set; }

    [JsonPropertyName("confirmations")]
    public int Confirmations { get; set; } = 0;
}

public class RoadTrafficAggregate
{
    public string Id { get; set; } = string.Empty;
    public string RoadName { get; set; } = string.Empty;
    public string SegmentKey { get; set; } = string.Empty;
    public double Latitude { get; set; }
    public double Longitude { get; set; }
    public double AverageSpeedKmh { get; set; }
    public double NormalSpeedKmh { get; set; } = 50.0;
    public int SampleCount { get; set; }
    public string CongestionLevel { get; set; } = "free"; // free, moderate, heavy, standstill
    public double DelaySeconds { get; set; } = 0;
    public double Confidence { get; set; } = 0; // 0.0 to 1.0
    public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;
}

public class TrafficConditionDto
{
    [JsonPropertyName("segmentKey")]
    public string SegmentKey { get; set; } = string.Empty;

    [JsonPropertyName("roadName")]
    public string RoadName { get; set; } = string.Empty;

    [JsonPropertyName("latitude")]
    public double Latitude { get; set; }

    [JsonPropertyName("longitude")]
    public double Longitude { get; set; }

    [JsonPropertyName("speedKmh")]
    public double SpeedKmh { get; set; }

    [JsonPropertyName("congestionLevel")]
    public string CongestionLevel { get; set; } = "free";

    [JsonPropertyName("delaySeconds")]
    public double DelaySeconds { get; set; }

    [JsonPropertyName("confidence")]
    public double Confidence { get; set; }

    [JsonPropertyName("updatedAt")]
    public DateTime UpdatedAt { get; set; }
}

public class RouteStepDto
{
    [JsonPropertyName("instruction")]
    public string Instruction { get; set; } = string.Empty;

    [JsonPropertyName("instructionAr")]
    public string InstructionAr { get; set; } = string.Empty;

    [JsonPropertyName("type")]
    public string Type { get; set; } = "straight";

    [JsonPropertyName("latitude")]
    public double Latitude { get; set; }

    [JsonPropertyName("longitude")]
    public double Longitude { get; set; }

    [JsonPropertyName("distanceMeters")]
    public double DistanceMeters { get; set; }

    [JsonPropertyName("roadName")]
    public string RoadName { get; set; } = string.Empty;
}

public class RouteResultDto
{
    [JsonPropertyName("id")]
    public string Id { get; set; } = string.Empty;

    [JsonPropertyName("name")]
    public string Name { get; set; } = string.Empty;

    [JsonPropertyName("nameAr")]
    public string NameAr { get; set; } = string.Empty;

    [JsonPropertyName("distanceMeters")]
    public double DistanceMeters { get; set; }

    [JsonPropertyName("durationSeconds")]
    public double DurationSeconds { get; set; }

    [JsonPropertyName("trafficDelaySeconds")]
    public double TrafficDelaySeconds { get; set; }

    [JsonPropertyName("totalDurationSeconds")]
    public double TotalDurationSeconds => DurationSeconds + TrafficDelaySeconds;

    [JsonPropertyName("isFastest")]
    public bool IsFastest { get; set; } = false;

    [JsonPropertyName("coordinates")]
    public List<List<double>> Coordinates { get; set; } = []; // [ [lon, lat], ... ]

    [JsonPropertyName("steps")]
    public List<RouteStepDto> Steps { get; set; } = [];

    [JsonPropertyName("trafficPoints")]
    public List<List<double>> TrafficPoints { get; set; } = [];
}
