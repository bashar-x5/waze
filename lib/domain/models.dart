import 'package:latlong2/latlong.dart';

enum PlaceCategory { landmark, food, fuel, parking, charging }

class Place {
  const Place({
    required this.id,
    required this.name,
    required this.nameAr,
    required this.subtitle,
    required this.subtitleAr,
    required this.point,
    this.category = PlaceCategory.landmark,
  });

  final String id;
  final String name;
  final String nameAr;
  final String subtitle;
  final String subtitleAr;
  final LatLng point;
  final PlaceCategory category;

  String label(bool arabic) => arabic && nameAr.isNotEmpty ? nameAr : name;
  String detail(bool arabic) =>
      arabic && subtitleAr.isNotEmpty ? subtitleAr : subtitle;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'nameAr': nameAr,
    'subtitle': subtitle,
    'subtitleAr': subtitleAr,
    'latitude': point.latitude,
    'longitude': point.longitude,
    'category': category.name,
  };

  factory Place.fromJson(Map<String, dynamic> json) => Place(
    id: json['id'] as String,
    name: json['name'] as String,
    nameAr: (json['nameAr'] ?? json['name_ar'] ?? '') as String,
    subtitle: (json['subtitle'] ?? '') as String,
    subtitleAr: (json['subtitleAr'] ?? json['subtitle_ar'] ?? '') as String,
    point: _pointFromJson(json),
    category: PlaceCategory.values.firstWhere(
      (value) => value.name == json['category'],
      orElse: () => PlaceCategory.landmark,
    ),
  );
}

enum ReportType {
  traffic,
  crash,
  hazard,
  police,
  closure,
  construction,
  weather,
  camera,
  bump,
}

class RoadReport {
  const RoadReport({
    required this.id,
    required this.type,
    required this.point,
    required this.createdAt,
    required this.expiresAt,
    this.description = '',
    this.demo = false,
    this.confirmations = 0,
    this.userId,
    this.isVerified = false,
    this.isRoadWarning = false,
  });

  final String id;
  final ReportType type;
  final LatLng point;
  final DateTime createdAt;
  final DateTime expiresAt;
  final String description;
  final bool demo;
  final int confirmations;
  final String? userId;
  final bool isVerified;
  final bool isRoadWarning;

  bool get isActive {
    final now = DateTime.now();
    return !createdAt.isAfter(now) && expiresAt.isAfter(now);
  }

  RoadReport copyWith({
    String? id,
    ReportType? type,
    LatLng? point,
    DateTime? createdAt,
    DateTime? expiresAt,
    String? description,
    bool? demo,
    int? confirmations,
    String? userId,
    bool? isVerified,
    bool? isRoadWarning,
  }) {
    return RoadReport(
      id: id ?? this.id,
      type: type ?? this.type,
      point: point ?? this.point,
      createdAt: createdAt ?? this.createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
      description: description ?? this.description,
      demo: demo ?? this.demo,
      confirmations: confirmations ?? this.confirmations,
      userId: userId ?? this.userId,
      isVerified: isVerified ?? this.isVerified,
      isRoadWarning: isRoadWarning ?? this.isRoadWarning,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.name,
    'latitude': point.latitude,
    'longitude': point.longitude,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'expiresAt': expiresAt.toUtc().toIso8601String(),
    'description': description,
    'demo': demo,
    'confirmations': confirmations,
    if (userId != null) 'userId': userId,
    'isVerified': isVerified,
    'isRoadWarning': isRoadWarning,
  };

  factory RoadReport.fromJson(Map<String, dynamic> json) => RoadReport(
    id: json['id'] as String,
    type: ReportType.values.firstWhere(
      (value) => value.name == (json['type']?.toString().toLowerCase()),
      orElse: () => ReportType.hazard,
    ),
    point: _pointFromJson(json),
    createdAt: DateTime.parse(
      (json['createdAt'] ?? json['created_at']) as String,
    ),
    expiresAt: DateTime.parse(
      (json['expiresAt'] ?? json['expires_at']) as String,
    ),
    description: (json['description'] ?? '') as String,
    demo: (json['demo'] ?? false) as bool,
    confirmations: (json['confirmations'] as num?)?.toInt() ?? 0,
    userId: json['userId'] as String?,
    isVerified: json['isVerified'] == true,
    isRoadWarning: json['isRoadWarning'] == true,
  );
}

class RouteStep {
  const RouteStep({
    required this.instruction,
    required this.instructionAr,
    required this.type,
    required this.point,
    required this.distanceMeters,
    this.roadName = '',
  });

  final String instruction;
  final String instructionAr;
  final String type;
  final LatLng point;
  final double distanceMeters;
  final String roadName;

  String label(bool arabic) =>
      arabic && instructionAr.isNotEmpty ? instructionAr : instruction;
}

enum TrafficCongestionLevel {
  free,
  moderate,
  heavy,
  standstill,
}

class RouteTrafficSegment {
  const RouteTrafficSegment({
    required this.points,
    required this.level,
    this.estimatedSpeedKmh = 25.0,
    this.delaySeconds = 0.0,
    this.description = '',
  });

  final List<LatLng> points;
  final TrafficCongestionLevel level;
  final double estimatedSpeedKmh;
  final double delaySeconds;
  final String description;
}

class DriveRoute {
  const DriveRoute({
    required this.id,
    required this.name,
    required this.nameAr,
    required this.points,
    required this.steps,
    required this.distanceMeters,
    required this.durationSeconds,
    this.demo = false,
    this.trafficDelaySeconds = 0.0,
    this.incidentAlerts = const [],
    this.trafficPoints = const [],
    this.trafficSegments = const [],
  });

  final String id;
  final String name;
  final String nameAr;
  final List<LatLng> points;
  final List<RouteStep> steps;
  final double distanceMeters;
  final double durationSeconds;
  final bool demo;
  final double trafficDelaySeconds;
  final List<RoadReport> incidentAlerts;
  final List<LatLng> trafficPoints;
  final List<RouteTrafficSegment> trafficSegments;

  double get totalDurationSeconds => durationSeconds + trafficDelaySeconds;
  bool get hasTraffic => trafficDelaySeconds > 15.0 || trafficSegments.any((s) => s.level != TrafficCongestionLevel.free);

  String label(bool arabic) => arabic && nameAr.isNotEmpty ? nameAr : name;

  DriveRoute withTraffic({
    double trafficDelaySeconds = 0.0,
    List<RoadReport> incidentAlerts = const [],
    List<LatLng> trafficPoints = const [],
    List<RouteTrafficSegment> trafficSegments = const [],
  }) => DriveRoute(
    id: id,
    name: name,
    nameAr: nameAr,
    points: points,
    steps: steps,
    distanceMeters: distanceMeters,
    durationSeconds: durationSeconds,
    demo: demo,
    trafficDelaySeconds: trafficDelaySeconds,
    incidentAlerts: incidentAlerts,
    trafficPoints: trafficPoints,
    trafficSegments: trafficSegments,
  );
}

class PlannedDrive {
  const PlannedDrive({
    required this.id,
    required this.destination,
    required this.arriveAt,
  });

  final String id;
  final Place destination;
  final DateTime arriveAt;

  Map<String, dynamic> toJson() => {
    'id': id,
    'destination': destination.toJson(),
    'arriveAt': arriveAt.toUtc().toIso8601String(),
  };

  factory PlannedDrive.fromJson(Map<String, dynamic> json) => PlannedDrive(
    id: json['id'] as String,
    destination: Place.fromJson(
      Map<String, dynamic>.from(json['destination'] as Map),
    ),
    arriveAt: DateTime.parse((json['arriveAt'] ?? json['arrive_at']) as String),
  );
}

LatLng _pointFromJson(Map<String, dynamic> json) {
  final latitude = (json['latitude'] ?? json['lat']) as num;
  final longitude = (json['longitude'] ?? json['lon'] ?? json['lng']) as num;
  if (!latitude.isFinite ||
      !longitude.isFinite ||
      latitude < -90 ||
      latitude > 90 ||
      longitude < -180 ||
      longitude > 180) {
    throw const FormatException('Invalid geographic coordinates.');
  }
  return LatLng(latitude.toDouble(), longitude.toDouble());
}

class ParkedCarLocation {
  const ParkedCarLocation({
    required this.point,
    required this.savedAt,
    this.note,
  });

  final LatLng point;
  final DateTime savedAt;
  final String? note;

  Map<String, dynamic> toJson() => {
    'latitude': point.latitude,
    'longitude': point.longitude,
    'savedAt': savedAt.toIso8601String(),
    'note': note,
  };

  factory ParkedCarLocation.fromJson(Map<String, dynamic> json) => ParkedCarLocation(
    point: _pointFromJson(json),
    savedAt: DateTime.parse((json['savedAt'] ?? json['saved_at']) as String),
    note: json['note'] as String?,
  );
}

class LiveRoomMember {
  const LiveRoomMember({
    required this.memberId,
    required this.displayName,
    this.avatarColor = '#00E676',
    required this.point,
    this.speedKmh = 0.0,
    this.heading,
    this.batteryPercent,
    required this.updatedAt,
    this.isCreator = false,
    this.distanceToDestMeters,
    this.etaSeconds,
  });

  final String memberId;
  final String displayName;
  final String avatarColor;
  final LatLng point;
  final double speedKmh;
  final double? heading;
  final int? batteryPercent;
  final DateTime updatedAt;
  final bool isCreator;
  final double? distanceToDestMeters;
  final double? etaSeconds;

  bool get isOnline => DateTime.now().toUtc().difference(updatedAt).inSeconds <= 30;

  Map<String, dynamic> toJson() => {
    'memberId': memberId,
    'displayName': displayName,
    'avatarColor': avatarColor,
    'latitude': point.latitude,
    'longitude': point.longitude,
    'speedKmh': speedKmh,
    if (heading != null) 'heading': heading,
    if (batteryPercent != null) 'batteryPercent': batteryPercent,
    'updatedAt': updatedAt.toIso8601String(),
    'isCreator': isCreator,
    if (distanceToDestMeters != null) 'distanceToDestMeters': distanceToDestMeters,
    if (etaSeconds != null) 'etaSeconds': etaSeconds,
  };

  factory LiveRoomMember.fromJson(Map<String, dynamic> json) => LiveRoomMember(
    memberId: (json['memberId'] ?? json['member_id'] ?? '') as String,
    displayName: (json['displayName'] ?? json['display_name'] ?? 'عضو') as String,
    avatarColor: (json['avatarColor'] ?? json['avatar_color'] ?? '#00E676') as String,
    point: _pointFromJson(json),
    speedKmh: ((json['speedKmh'] ?? json['speed_kmh'] ?? 0) as num).toDouble(),
    heading: (json['heading'] as num?)?.toDouble(),
    batteryPercent: (json['batteryPercent'] ?? json['battery_percent'] as num?)?.toInt(),
    updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? '') ?? DateTime.now().toUtc(),
    isCreator: (json['isCreator'] ?? json['is_creator'] ?? false) as bool,
    distanceToDestMeters: (json['distanceToDestMeters'] as num?)?.toDouble(),
    etaSeconds: (json['etaSeconds'] as num?)?.toDouble(),
  );
}

class LiveRoom {
  const LiveRoom({
    required this.code,
    required this.name,
    this.mode = 'convoy',
    required this.creatorId,
    required this.creatorName,
    required this.createdAt,
    required this.expiresAt,
    this.isActive = true,
    this.destinationName,
    this.destinationPoint,
    required this.shareUrl,
    this.members = const [],
  });

  final String code;
  final String name;
  final String mode;
  final String creatorId;
  final String creatorName;
  final DateTime createdAt;
  final DateTime expiresAt;
  final bool isActive;
  final String? destinationName;
  final LatLng? destinationPoint;
  final String shareUrl;
  final List<LiveRoomMember> members;

  int get remainingSeconds =>
      expiresAt.difference(DateTime.now().toUtc()).inSeconds.clamp(0, 86400);

  bool get isExpired => remainingSeconds <= 0;

  Map<String, dynamic> toJson() => {
    'code': code,
    'name': name,
    'mode': mode,
    'creatorId': creatorId,
    'creatorName': creatorName,
    'createdAt': createdAt.toIso8601String(),
    'expiresAt': expiresAt.toIso8601String(),
    'isActive': isActive,
    if (destinationName != null) 'destinationName': destinationName,
    if (destinationPoint != null) ...{
      'destinationLat': destinationPoint!.latitude,
      'destinationLon': destinationPoint!.longitude,
    },
    'shareUrl': shareUrl,
    'members': members.map((m) => m.toJson()).toList(),
  };

  factory LiveRoom.fromJson(Map<String, dynamic> json) {
    LatLng? dest;
    final lat = json['destinationLat'] ?? json['destination_lat'];
    final lon = json['destinationLon'] ?? json['destination_lon'];
    if (lat is num && lon is num) {
      dest = LatLng(lat.toDouble(), lon.toDouble());
    }

    final rawMembers = json['members'] as List<dynamic>? ?? [];
    return LiveRoom(
      code: (json['code'] ?? '').toString().toUpperCase(),
      name: (json['name'] ?? 'غرفة درب').toString(),
      mode: (json['mode'] ?? 'convoy').toString(),
      creatorId: (json['creatorId'] ?? json['creator_id'] ?? '').toString(),
      creatorName: (json['creatorName'] ?? json['creator_name'] ?? '').toString(),
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ?? DateTime.now().toUtc(),
      expiresAt: DateTime.tryParse(json['expiresAt']?.toString() ?? '') ?? DateTime.now().toUtc().add(const Duration(hours: 2)),
      isActive: (json['isActive'] ?? json['is_active'] ?? true) as bool,
      destinationName: json['destinationName']?.toString(),
      destinationPoint: dest,
      shareUrl: (json['shareUrl'] ?? json['share_url'] ?? '').toString(),
      members: rawMembers
          .map((m) => LiveRoomMember.fromJson(Map<String, dynamic>.from(m as Map)))
          .toList(),
    );
  }
}

