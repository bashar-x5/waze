using System.Text.Json.Serialization;

namespace Darb.Api.Models;

public class LiveRoom
{
    [JsonPropertyName("code")]
    public string Code { get; set; } = string.Empty;

    [JsonPropertyName("name")]
    public string Name { get; set; } = string.Empty;

    [JsonPropertyName("mode")]
    public string Mode { get; set; } = "convoy"; // "convoy" or "family"

    [JsonPropertyName("creatorId")]
    public string CreatorId { get; set; } = string.Empty;

    [JsonPropertyName("creatorName")]
    public string CreatorName { get; set; } = string.Empty;

    [JsonPropertyName("createdAt")]
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

    [JsonPropertyName("expiresAt")]
    public DateTime ExpiresAt { get; set; }

    [JsonPropertyName("isActive")]
    public bool IsActive { get; set; } = true;

    [JsonPropertyName("destinationName")]
    public string? DestinationName { get; set; }

    [JsonPropertyName("destinationLat")]
    public double? DestinationLat { get; set; }

    [JsonPropertyName("destinationLon")]
    public double? DestinationLon { get; set; }

    [JsonPropertyName("shareUrl")]
    public string ShareUrl { get; set; } = string.Empty;

    [JsonPropertyName("members")]
    public List<LiveRoomMember> Members { get; set; } = new();

    [JsonPropertyName("remainingSeconds")]
    public int RemainingSeconds => Math.Max(0, (int)(ExpiresAt - DateTime.UtcNow).TotalSeconds);
}

public class LiveRoomMember
{
    [JsonPropertyName("memberId")]
    public string MemberId { get; set; } = string.Empty;

    [JsonPropertyName("displayName")]
    public string DisplayName { get; set; } = string.Empty;

    [JsonPropertyName("avatarColor")]
    public string AvatarColor { get; set; } = "#00E676";

    [JsonPropertyName("latitude")]
    public double Latitude { get; set; }

    [JsonPropertyName("longitude")]
    public double Longitude { get; set; }

    [JsonPropertyName("speedKmh")]
    public double SpeedKmh { get; set; }

    [JsonPropertyName("heading")]
    public double? Heading { get; set; }

    [JsonPropertyName("batteryPercent")]
    public int? BatteryPercent { get; set; }

    [JsonPropertyName("updatedAt")]
    public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;

    [JsonPropertyName("isCreator")]
    public bool IsCreator { get; set; }

    [JsonPropertyName("distanceToDestMeters")]
    public double? DistanceToDestMeters { get; set; }

    [JsonPropertyName("etaSeconds")]
    public double? EtaSeconds { get; set; }

    [JsonPropertyName("isOnline")]
    public bool IsOnline => (DateTime.UtcNow - UpdatedAt).TotalSeconds <= 30;
}

public class CreateLiveRoomRequest
{
    [JsonPropertyName("name")]
    public string? Name { get; set; }

    [JsonPropertyName("mode")]
    public string? Mode { get; set; }

    [JsonPropertyName("durationMinutes")]
    public int DurationMinutes { get; set; } = 120; // default 2 hours

    [JsonPropertyName("creatorId")]
    public string CreatorId { get; set; } = string.Empty;

    [JsonPropertyName("creatorName")]
    public string CreatorName { get; set; } = string.Empty;

    [JsonPropertyName("avatarColor")]
    public string? AvatarColor { get; set; }

    [JsonPropertyName("latitude")]
    public double Latitude { get; set; }

    [JsonPropertyName("longitude")]
    public double Longitude { get; set; }

    [JsonPropertyName("speedKmh")]
    public double SpeedKmh { get; set; }

    [JsonPropertyName("heading")]
    public double? Heading { get; set; }

    [JsonPropertyName("batteryPercent")]
    public int? BatteryPercent { get; set; }

    [JsonPropertyName("destinationName")]
    public string? DestinationName { get; set; }

    [JsonPropertyName("destinationLat")]
    public double? DestinationLat { get; set; }

    [JsonPropertyName("destinationLon")]
    public double? DestinationLon { get; set; }
}

public class PingLiveRoomRequest
{
    [JsonPropertyName("memberId")]
    public string MemberId { get; set; } = string.Empty;

    [JsonPropertyName("displayName")]
    public string? DisplayName { get; set; }

    [JsonPropertyName("avatarColor")]
    public string? AvatarColor { get; set; }

    [JsonPropertyName("latitude")]
    public double Latitude { get; set; }

    [JsonPropertyName("longitude")]
    public double Longitude { get; set; }

    [JsonPropertyName("speedKmh")]
    public double SpeedKmh { get; set; }

    [JsonPropertyName("heading")]
    public double? Heading { get; set; }

    [JsonPropertyName("batteryPercent")]
    public int? BatteryPercent { get; set; }

    [JsonPropertyName("distanceToDestMeters")]
    public double? DistanceToDestMeters { get; set; }

    [JsonPropertyName("etaSeconds")]
    public double? EtaSeconds { get; set; }
}

public class EndLiveRoomRequest
{
    [JsonPropertyName("requesterId")]
    public string RequesterId { get; set; } = string.Empty;
}

public class SetDestinationRequest
{
    [JsonPropertyName("requesterId")]
    public string RequesterId { get; set; } = string.Empty;

    [JsonPropertyName("destinationName")]
    public string? DestinationName { get; set; }

    [JsonPropertyName("destinationLat")]
    public double DestinationLat { get; set; }

    [JsonPropertyName("destinationLon")]
    public double DestinationLon { get; set; }
}
