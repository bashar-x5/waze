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
  });

  final String id;
  final ReportType type;
  final LatLng point;
  final DateTime createdAt;
  final DateTime expiresAt;
  final String description;
  final bool demo;
  final int confirmations;

  bool get isActive {
    final now = DateTime.now();
    return !createdAt.isAfter(now) && expiresAt.isAfter(now);
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
  };

  factory RoadReport.fromJson(Map<String, dynamic> json) => RoadReport(
    id: json['id'] as String,
    type: ReportType.values.byName(json['type'] as String),
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
