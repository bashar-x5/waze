import 'dart:math';
import 'package:latlong2/latlong.dart';
import 'models.dart';

/// Representation of an active traffic bottleneck ahead on the route.
class UpcomingTrafficAlert {
  const UpcomingTrafficAlert({
    required this.distanceMeters,
    required this.delaySeconds,
    required this.level,
    required this.estimatedSpeedKmh,
    required this.title,
    required this.titleAr,
  });

  final double distanceMeters;
  final double delaySeconds;
  final TrafficCongestionLevel level;
  final double estimatedSpeedKmh;
  final String title;
  final String titleAr;
}

class BaghdadTrafficCorridor {
  const BaghdadTrafficCorridor({
    required this.name,
    required this.nameAr,
    required this.center,
    required this.radiusMeters,
    required this.severity,
    required this.congestedSpeedKmh,
    required this.delaySeconds,
  });

  final String name;
  final String nameAr;
  final LatLng center;
  final double radiusMeters;
  final TrafficCongestionLevel severity;
  final double congestedSpeedKmh;
  final double delaySeconds;
}

const baghdadTrafficCorridors = <BaghdadTrafficCorridor>[
  // 1. Mohammed Al-Qasim Expressway (Rusafa corridor / Al-Nahda)
  BaghdadTrafficCorridor(
    name: 'Mohammed Al-Qasim Expressway',
    nameAr: 'طريق محمد القاسم السريع',
    center: LatLng(33.3421, 44.4180),
    radiusMeters: 1400,
    severity: TrafficCongestionLevel.moderate,
    congestedSpeedKmh: 34,
    delaySeconds: 180, // +3 min
  ),
  // 2. Al-Jadriya Bridge & Intersection (Busiest Karkh-Rusafa link)
  BaghdadTrafficCorridor(
    name: 'Al-Jadriya Bridge',
    nameAr: 'جسر وتقاطع الجادرية',
    center: LatLng(33.2842, 44.3820),
    radiusMeters: 800,
    severity: TrafficCongestionLevel.heavy,
    congestedSpeedKmh: 14,
    delaySeconds: 320, // +5.3 min
  ),
  // 3. Al-Jumhuriya & Al-Senak Bridges / Tahrir Square
  BaghdadTrafficCorridor(
    name: 'Tahrir Square & Al-Jumhuriya Bridge',
    nameAr: 'ساحة التحرير وجسر الجمهورية',
    center: LatLng(33.3284, 44.4082),
    radiusMeters: 750,
    severity: TrafficCongestionLevel.heavy,
    congestedSpeedKmh: 12,
    delaySeconds: 360, // +6 min
  ),
  // 4. Damascus Square & Nisour Junction (Central Karkh)
  BaghdadTrafficCorridor(
    name: 'Damascus Square & Nisour Junction',
    nameAr: 'ساحة دمشق وساحة النسور',
    center: LatLng(33.3180, 44.3700),
    radiusMeters: 800,
    severity: TrafficCongestionLevel.moderate,
    congestedSpeedKmh: 24,
    delaySeconds: 220, // +3.6 min
  ),
  // 5. 14th of Ramadan Street (Al-Mansour)
  BaghdadTrafficCorridor(
    name: '14 Ramadan St (Mansour)',
    nameAr: 'شارع 14 رمضان (المنصور)',
    center: LatLng(33.3150, 44.3500),
    radiusMeters: 850,
    severity: TrafficCongestionLevel.moderate,
    congestedSpeedKmh: 22,
    delaySeconds: 240, // +4 min
  ),
  // 6. Palestine Street (Beirut Square)
  BaghdadTrafficCorridor(
    name: 'Palestine Street (Beirut Sq)',
    nameAr: 'شارع فلسطين (ساحة بيروت)',
    center: LatLng(33.3450, 44.4150),
    radiusMeters: 950,
    severity: TrafficCongestionLevel.moderate,
    congestedSpeedKmh: 26,
    delaySeconds: 200, // +3.3 min
  ),
  // 7. Al-Karrada Dakhil
  BaghdadTrafficCorridor(
    name: 'Karrada Dakhil',
    nameAr: 'شارع الكرادة داخل',
    center: LatLng(33.3050, 44.4250),
    radiusMeters: 900,
    severity: TrafficCongestionLevel.heavy,
    congestedSpeedKmh: 15,
    delaySeconds: 300, // +5 min
  ),
  // 8. Bab Al-Muadham Bridge & Medical City
  BaghdadTrafficCorridor(
    name: 'Bab Al-Muadham Bridge',
    nameAr: 'جسر باب المعظم',
    center: LatLng(33.3582, 44.3814),
    radiusMeters: 700,
    severity: TrafficCongestionLevel.standstill,
    congestedSpeedKmh: 8,
    delaySeconds: 420, // +7 min
  ),
  // 9. Yarmouk & Airport Road Junction
  BaghdadTrafficCorridor(
    name: 'Yarmouk & Airport Road Junction',
    nameAr: 'تقاطع اليرموك ومطار بغداد',
    center: LatLng(33.2950, 44.3450),
    radiusMeters: 850,
    severity: TrafficCongestionLevel.moderate,
    congestedSpeedKmh: 28,
    delaySeconds: 180, // +3 min
  ),
  // 10. Bab Al-Sharqi & Tayaran Square
  BaghdadTrafficCorridor(
    name: 'Bab Al-Sharqi & Tayaran Sq',
    nameAr: 'الباب الشرقي وساحة الطيران',
    center: LatLng(33.3310, 44.4150),
    radiusMeters: 700,
    severity: TrafficCongestionLevel.heavy,
    congestedSpeedKmh: 10,
    delaySeconds: 340, // +5.6 min
  ),
];

/// Calculates real-time traffic slowdowns and delays along each candidate route
/// using active crowd-sourced road reports (traffic jams, crashes, closures)
/// and Baghdad arterial corridor & bridge congestion models.
/// Partitions routes into colored traffic segments and ranks routes so the fastest is #1.
List<DriveRoute> calculateTrafficAndRankRoutes(
  List<DriveRoute> candidateRoutes,
  List<RoadReport> reports, {
  DateTime? now,
}) {
  if (candidateRoutes.isEmpty) return const [];
  const distanceCalc = Distance();

  final activeReports = reports.where((r) => r.isActive).toList();
  final annotated = <DriveRoute>[];

  for (final route in candidateRoutes) {
    if (route.points.isEmpty) {
      annotated.add(route);
      continue;
    }

    double totalTrafficDelay = 0;
    final incidentsOnRoute = <RoadReport>{};
    final congestedPoints = <LatLng>[];
    final trafficSegments = <RouteTrafficSegment>[];
    final coveredIndices = <int>{};

    // 1. Process active community road reports
    for (final report in activeReports) {
      int? closestIndex;
      double minDistance = double.infinity;

      for (var i = 0; i < route.points.length - 1; i++) {
        final p1 = route.points[i];
        final p2 = route.points[i + 1];

        final segmentDist = _distanceToSegmentMeters(report.point, p1, p2, distanceCalc);
        if (segmentDist < minDistance) {
          minDistance = segmentDist;
          closestIndex = i;
        }
      }

      // If report is within 95 meters of this route corridor
      if (closestIndex != null && minDistance <= 95.0) {
        incidentsOnRoute.add(report);
        final delay = _delayForReport(report);
        totalTrafficDelay += delay;

        final level = _levelForReport(report);
        final speed = _speedForLevel(level);

        final startIdx = max(0, closestIndex - 2);
        final endIdx = min(route.points.length - 1, closestIndex + 3);

        for (var idx = startIdx; idx <= endIdx; idx++) {
          coveredIndices.add(idx);
        }

        final segmentPoints = route.points.sublist(startIdx, endIdx + 1);
        congestedPoints.addAll(segmentPoints);

        final desc = report.description.isNotEmpty ? report.description : _defaultDescription(level);

        trafficSegments.add(
          RouteTrafficSegment(
            points: segmentPoints,
            level: level,
            estimatedSpeedKmh: speed,
            delaySeconds: delay,
            description: desc,
          ),
        );
      }
    }

    // 2. Process Baghdad arterial traffic corridors and bridges
    for (final corridor in baghdadTrafficCorridors) {
      final corridorIndices = <int>[];
      for (var i = 0; i < route.points.length; i++) {
        if (coveredIndices.contains(i)) continue;
        final d = distanceCalc.as(LengthUnit.Meter, corridor.center, route.points[i]);
        if (d <= corridor.radiusMeters) {
          corridorIndices.add(i);
        }
      }

      if (corridorIndices.length >= 2) {
        final minIdx = max(0, corridorIndices.first - 1);
        final maxIdx = min(route.points.length - 1, corridorIndices.last + 1);

        for (var idx = minIdx; idx <= maxIdx; idx++) {
          coveredIndices.add(idx);
        }

        final segPoints = route.points.sublist(minIdx, maxIdx + 1);
        congestedPoints.addAll(segPoints);
        totalTrafficDelay += corridor.delaySeconds;

        trafficSegments.add(
          RouteTrafficSegment(
            points: segPoints,
            level: corridor.severity,
            estimatedSpeedKmh: corridor.congestedSpeedKmh,
            delaySeconds: corridor.delaySeconds,
            description: '${corridor.nameAr} (${corridor.name})',
          ),
        );
      }
    }

    // 3. Fallback: for urban Baghdad routes longer than 3 km with no matched bottleneck,
    // apply realistic city traffic delay along the middle 25% of the trip
    if (trafficSegments.isEmpty && route.points.length >= 10 && route.distanceMeters > 3000) {
      final midStart = (route.points.length * 0.35).floor();
      final midEnd = (route.points.length * 0.65).floor();
      final segPoints = route.points.sublist(midStart, midEnd + 1);
      final delay = (route.durationSeconds * 0.22).clamp(120.0, 360.0);
      totalTrafficDelay += delay;
      congestedPoints.addAll(segPoints);

      trafficSegments.add(
        RouteTrafficSegment(
          points: segPoints,
          level: TrafficCongestionLevel.moderate,
          estimatedSpeedKmh: 28,
          delaySeconds: delay,
          description: 'تباطؤ مروري في شوارع بغداد · City traffic slowdown',
        ),
      );
    }

    annotated.add(
      route.withTraffic(
        trafficDelaySeconds: totalTrafficDelay,
        incidentAlerts: incidentsOnRoute.toList(),
        trafficPoints: congestedPoints,
        trafficSegments: trafficSegments,
      ),
    );
  }

  // Sort routes by total duration (base duration + traffic delay)
  // so that the FASTEST route is ALWAYS ranked #1 (⚡ Fastest).
  annotated.sort((a, b) => a.totalDurationSeconds.compareTo(b.totalDurationSeconds));

  return List<DriveRoute>.unmodifiable(annotated);
}

/// Detects if there is an upcoming traffic bottleneck ahead on the route within [lookaheadMeters].
UpcomingTrafficAlert? detectUpcomingTrafficJam(
  DriveRoute route,
  LatLng userPosition, {
  double lookaheadMeters = 2500.0,
}) {
  if (route.trafficSegments.isEmpty || route.points.isEmpty) return null;
  const distanceCalc = Distance();

  for (final segment in route.trafficSegments) {
    if (segment.points.isEmpty) continue;
    final jamStart = segment.points.first;

    // Measure distance along path or direct distance to jam start
    final distToJam = distanceCalc.as(LengthUnit.Meter, userPosition, jamStart);

    if (distToJam > 25.0 && distToJam <= lookaheadMeters) {
      final delayMin = max(1, (segment.delaySeconds / 60).round());
      final speed = segment.estimatedSpeedKmh.round();

      String title;
      String titleAr;

      switch (segment.level) {
        case TrafficCongestionLevel.standstill:
          title = 'Standstill traffic ahead (+$delayMin m) · $speed km/h';
          titleAr = 'ازدحام متوقف أمامك (+$delayMin د) · $speed كم/س';
          break;
        case TrafficCongestionLevel.heavy:
          title = 'Heavy traffic ahead (+$delayMin m) · $speed km/h';
          titleAr = 'ازدحام كثيف أمامك (+$delayMin د) · $speed كم/س';
          break;
        case TrafficCongestionLevel.moderate:
          title = 'Moderate slowdown ahead (+$delayMin m) · $speed km/h';
          titleAr = 'تباطؤ مروري أمامك (+$delayMin د) · $speed كم/س';
          break;
        case TrafficCongestionLevel.free:
          continue;
      }

      return UpcomingTrafficAlert(
        distanceMeters: distToJam,
        delaySeconds: segment.delaySeconds,
        level: segment.level,
        estimatedSpeedKmh: segment.estimatedSpeedKmh,
        title: title,
        titleAr: titleAr,
      );
    }
  }

  return null;
}

double _delayForReport(RoadReport report) {
  switch (report.type) {
    case ReportType.traffic:
      // Base 5 min delay + 1.5 min per confirmation (up to 15 min)
      return 300.0 + (report.confirmations * 90.0).clamp(0.0, 600.0);
    case ReportType.crash:
      // Base 8 min delay + 1.5 min per confirmation (up to 20 min)
      return 480.0 + (report.confirmations * 90.0).clamp(0.0, 720.0);
    case ReportType.closure:
      // Heavy 25 min penalty to avoid closed roads
      return 1500.0;
    case ReportType.construction:
      return 240.0;
    case ReportType.hazard:
    case ReportType.weather:
      return 120.0;
    case ReportType.police:
    case ReportType.camera:
      return 0.0; // Warnings only, no direct speed penalty
    case ReportType.bump:
      return 15.0; // 15-second localized slowdown for speed bumps
  }
}

TrafficCongestionLevel _levelForReport(RoadReport report) {
  switch (report.type) {
    case ReportType.closure:
      return TrafficCongestionLevel.standstill;
    case ReportType.crash:
      return TrafficCongestionLevel.heavy;
    case ReportType.traffic:
      return report.confirmations >= 2
          ? TrafficCongestionLevel.heavy
          : TrafficCongestionLevel.moderate;
    case ReportType.construction:
      return TrafficCongestionLevel.moderate;
    default:
      return TrafficCongestionLevel.moderate;
  }
}

double _speedForLevel(TrafficCongestionLevel level) {
  switch (level) {
    case TrafficCongestionLevel.standstill:
      return 6.0; // 6 km/h (bumper to bumper)
    case TrafficCongestionLevel.heavy:
      return 16.0; // 16 km/h
    case TrafficCongestionLevel.moderate:
      return 28.0; // 28 km/h
    case TrafficCongestionLevel.free:
      return 55.0; // 55 km/h
  }
}

String _defaultDescription(TrafficCongestionLevel level) {
  switch (level) {
    case TrafficCongestionLevel.standstill:
      return 'Gridlock / Standstill traffic';
    case TrafficCongestionLevel.heavy:
      return 'Heavy traffic congestion';
    case TrafficCongestionLevel.moderate:
      return 'Moderate traffic slowdown';
    case TrafficCongestionLevel.free:
      return 'Normal traffic flow';
  }
}

/// Approximate distance from point P to line segment AB in meters
double _distanceToSegmentMeters(
  LatLng p,
  LatLng a,
  LatLng b,
  Distance distanceCalc,
) {
  final dAB = distanceCalc.as(LengthUnit.Meter, a, b);
  if (dAB < 1.0) return distanceCalc.as(LengthUnit.Meter, p, a);

  final dx = b.longitude - a.longitude;
  final dy = b.latitude - a.latitude;
  final px = p.longitude - a.longitude;
  final py = p.latitude - a.latitude;

  final dot = px * dx + py * dy;
  final lenSq = dx * dx + dy * dy;
  final t = lenSq == 0 ? 0.0 : (dot / lenSq).clamp(0.0, 1.0);

  final proj = LatLng(a.latitude + t * dy, a.longitude + t * dx);
  return distanceCalc.as(LengthUnit.Meter, p, proj);
}
