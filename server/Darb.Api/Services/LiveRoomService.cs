using System.Collections.Concurrent;
using System.Security.Cryptography;
using Darb.Api.Models;

namespace Darb.Api.Services;

public interface ILiveRoomService
{
    LiveRoom CreateRoom(CreateLiveRoomRequest req, string baseUrl);
    LiveRoom? GetRoom(string code);
    LiveRoom? PingMember(string code, PingLiveRoomRequest req);
    bool LeaveRoom(string code, string memberId);
    bool EndRoom(string code, string requesterId);
    LiveRoom? SetDestination(string code, SetDestinationRequest req);
    IEnumerable<LiveRoom> GetAllActiveRooms();
}

public class LiveRoomService : ILiveRoomService
{
    private readonly ConcurrentDictionary<string, LiveRoomInternal> _rooms = new(StringComparer.OrdinalIgnoreCase);
    private readonly ILogger<LiveRoomService> _logger;

    // 6-digit alphanumeric characters (avoiding easily confused 0/O and 1/I)
    private const string CodeAlphabet = "23456789ABCDEFGHJKLMNPQRSTUVWXYZ";

    public LiveRoomService(ILogger<LiveRoomService> logger)
    {
        _logger = logger;
    }

    public LiveRoom CreateRoom(CreateLiveRoomRequest req, string baseUrl)
    {
        var code = GenerateUniqueCode();
        var duration = Math.Clamp(req.DurationMinutes, 15, 1440); // 15 mins to 24 hours
        var now = DateTime.UtcNow;

        var avatarColor = string.IsNullOrWhiteSpace(req.AvatarColor)
            ? GetRandomColor()
            : req.AvatarColor;

        var member = new LiveRoomMember
        {
            MemberId = string.IsNullOrWhiteSpace(req.CreatorId) ? Guid.NewGuid().ToString("N")[..8] : req.CreatorId,
            DisplayName = string.IsNullOrWhiteSpace(req.CreatorName) ? "المنشئ" : req.CreatorName.Trim(),
            AvatarColor = avatarColor,
            Latitude = req.Latitude,
            Longitude = req.Longitude,
            SpeedKmh = req.SpeedKmh,
            Heading = req.Heading,
            BatteryPercent = req.BatteryPercent,
            UpdatedAt = now,
            IsCreator = true
        };

        var room = new LiveRoomInternal
        {
            Code = code,
            Name = string.IsNullOrWhiteSpace(req.Name) ? $"شلّة {code}" : req.Name.Trim(),
            Mode = req.Mode ?? "convoy",
            CreatorId = member.MemberId,
            CreatorName = member.DisplayName,
            CreatedAt = now,
            ExpiresAt = now.AddMinutes(duration),
            IsActive = true,
            DestinationName = req.DestinationName,
            DestinationLat = req.DestinationLat,
            DestinationLon = req.DestinationLon,
            ShareUrl = $"{baseUrl.TrimEnd('/')}/track/{code}"
        };

        room.Members[member.MemberId] = member;
        _rooms[code] = room;

        _logger.LogInformation("Live Room created: {Code} ({Name}) expires at {ExpiresAt}", code, room.Name, room.ExpiresAt);
        return room.ToDto();
    }

    public LiveRoom? GetRoom(string code)
    {
        if (string.IsNullOrWhiteSpace(code)) return null;
        var cleanCode = code.Trim().ToUpperInvariant();

        if (!_rooms.TryGetValue(cleanCode, out var room)) return null;

        if (DateTime.UtcNow > room.ExpiresAt)
        {
            room.IsActive = false;
        }

        return room.ToDto();
    }

    public LiveRoom? PingMember(string code, PingLiveRoomRequest req)
    {
        if (string.IsNullOrWhiteSpace(code)) return null;
        var cleanCode = code.Trim().ToUpperInvariant();

        if (!_rooms.TryGetValue(cleanCode, out var room)) return null;

        if (!room.IsActive || DateTime.UtcNow > room.ExpiresAt)
        {
            room.IsActive = false;
            return room.ToDto();
        }

        var memberId = string.IsNullOrWhiteSpace(req.MemberId) ? Guid.NewGuid().ToString("N")[..8] : req.MemberId;
        var now = DateTime.UtcNow;

        if (room.Members.TryGetValue(memberId, out var existing))
        {
            existing.Latitude = req.Latitude;
            existing.Longitude = req.Longitude;
            existing.SpeedKmh = req.SpeedKmh;
            existing.Heading = req.Heading;
            existing.BatteryPercent = req.BatteryPercent ?? existing.BatteryPercent;
            existing.DistanceToDestMeters = req.DistanceToDestMeters;
            existing.EtaSeconds = req.EtaSeconds;
            existing.UpdatedAt = now;
            if (!string.IsNullOrWhiteSpace(req.DisplayName))
            {
                existing.DisplayName = req.DisplayName.Trim();
            }
        }
        else
        {
            var newMember = new LiveRoomMember
            {
                MemberId = memberId,
                DisplayName = string.IsNullOrWhiteSpace(req.DisplayName) ? $"صديق {room.Members.Count + 1}" : req.DisplayName.Trim(),
                AvatarColor = string.IsNullOrWhiteSpace(req.AvatarColor) ? GetRandomColor() : req.AvatarColor,
                Latitude = req.Latitude,
                Longitude = req.Longitude,
                SpeedKmh = req.SpeedKmh,
                Heading = req.Heading,
                BatteryPercent = req.BatteryPercent,
                DistanceToDestMeters = req.DistanceToDestMeters,
                EtaSeconds = req.EtaSeconds,
                UpdatedAt = now,
                IsCreator = false
            };
            room.Members[memberId] = newMember;
        }

        return room.ToDto();
    }

    public bool LeaveRoom(string code, string memberId)
    {
        if (string.IsNullOrWhiteSpace(code) || string.IsNullOrWhiteSpace(memberId)) return false;
        var cleanCode = code.Trim().ToUpperInvariant();

        if (!_rooms.TryGetValue(cleanCode, out var room)) return false;

        var removed = room.Members.TryRemove(memberId, out _);
        if (room.Members.IsEmpty)
        {
            room.IsActive = false;
            _rooms.TryRemove(cleanCode, out _);
        }
        return removed;
    }

    public bool EndRoom(string code, string requesterId)
    {
        if (string.IsNullOrWhiteSpace(code)) return false;
        var cleanCode = code.Trim().ToUpperInvariant();

        if (!_rooms.TryGetValue(cleanCode, out var room)) return false;

        room.IsActive = false;
        _logger.LogInformation("Live Room ended: {Code} by {RequesterId}", cleanCode, requesterId);
        _rooms.TryRemove(cleanCode, out _);
        return true;
    }

    public LiveRoom? SetDestination(string code, SetDestinationRequest req)
    {
        if (string.IsNullOrWhiteSpace(code)) return null;
        var cleanCode = code.Trim().ToUpperInvariant();

        if (!_rooms.TryGetValue(cleanCode, out var room)) return null;

        room.DestinationName = string.IsNullOrWhiteSpace(req.DestinationName) ? room.DestinationName : req.DestinationName.Trim();
        room.DestinationLat = req.DestinationLat;
        room.DestinationLon = req.DestinationLon;

        _logger.LogInformation("Live Room destination set for {Code}: {Dest} ({Lat}, {Lon})", cleanCode, room.DestinationName, room.DestinationLat, room.DestinationLon);
        return room.ToDto();
    }

    public IEnumerable<LiveRoom> GetAllActiveRooms()
    {
        var now = DateTime.UtcNow;
        return _rooms.Values
            .Where(r => r.IsActive && r.ExpiresAt > now)
            .Select(r => r.ToDto());
    }

    private string GenerateUniqueCode()
    {
        for (int attempt = 0; attempt < 50; attempt++)
        {
            var chars = new char[6];
            for (int i = 0; i < 6; i++)
            {
                var idx = RandomNumberGenerator.GetInt32(CodeAlphabet.Length);
                chars[i] = CodeAlphabet[idx];
            }
            var code = new string(chars);
            if (!_rooms.ContainsKey(code))
            {
                return code;
            }
        }
        return Guid.NewGuid().ToString("N")[..6].ToUpperInvariant();
    }

    private static string GetRandomColor()
    {
        var colors = new[]
        {
            "#00E676", // Green
            "#29B6F6", // Cyan
            "#FFB300", // Amber
            "#E040FB", // Purple
            "#FF5252", // Coral Red
            "#00B0FF", // Blue
            "#76FF03", // Lime
            "#FF4081"  // Pink
        };
        return colors[RandomNumberGenerator.GetInt32(colors.Length)];
    }

    private class LiveRoomInternal
    {
        public string Code { get; set; } = string.Empty;
        public string Name { get; set; } = string.Empty;
        public string Mode { get; set; } = "convoy";
        public string CreatorId { get; set; } = string.Empty;
        public string CreatorName { get; set; } = string.Empty;
        public DateTime CreatedAt { get; set; }
        public DateTime ExpiresAt { get; set; }
        public bool IsActive { get; set; }
        public string? DestinationName { get; set; }
        public double? DestinationLat { get; set; }
        public double? DestinationLon { get; set; }
        public string ShareUrl { get; set; } = string.Empty;
        public ConcurrentDictionary<string, LiveRoomMember> Members { get; set; } = new();

        public LiveRoom ToDto()
        {
            return new LiveRoom
            {
                Code = Code,
                Name = Name,
                Mode = Mode,
                CreatorId = CreatorId,
                CreatorName = CreatorName,
                CreatedAt = CreatedAt,
                ExpiresAt = ExpiresAt,
                IsActive = IsActive,
                DestinationName = DestinationName,
                DestinationLat = DestinationLat,
                DestinationLon = DestinationLon,
                ShareUrl = ShareUrl,
                Members = Members.Values.OrderByDescending(m => m.IsCreator).ThenBy(m => m.DisplayName).ToList()
            };
        }
    }
}
