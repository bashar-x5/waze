import 'package:darb/domain/models.dart';
import 'package:darb/domain/traffic_engine.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

void main() {
  group('Traffic Engine', () {
    test('calculates traffic delay and ranks the faster route first', () {
      final now = DateTime.now();

      // Route A passes through the traffic point (0.005, 0.005)
      const routeA = DriveRoute(
        id: 'route-a',
        name: 'Highway Route',
        nameAr: 'طريق السريع',
        points: [
          LatLng(0.0, 0.0),
          LatLng(0.005, 0.005),
          LatLng(0.01, 0.01),
        ],
        steps: [],
        distanceMeters: 2000,
        durationSeconds: 300, // 5 min base
      );

      // Route B is longer base duration but avoids the traffic jam
      const routeB = DriveRoute(
        id: 'route-b',
        name: 'Local Route',
        nameAr: 'طريق محلي',
        points: [
          LatLng(0.0, 0.0),
          LatLng(0.0, 0.01),
          LatLng(0.01, 0.01),
        ],
        steps: [],
        distanceMeters: 2500,
        durationSeconds: 400, // 6.6 min base
      );

      // Traffic report on Route A
      final trafficReport = RoadReport(
        id: 'jam-1',
        type: ReportType.traffic,
        point: const LatLng(0.00501, 0.00501),
        createdAt: now.subtract(const Duration(minutes: 5)),
        expiresAt: now.add(const Duration(minutes: 20)),
        confirmations: 2,
      );

      final ranked = calculateTrafficAndRankRoutes(
        [routeA, routeB],
        [trafficReport],
      );

      expect(ranked.length, 2);

      // Route A has traffic delay added (base 300s + delay >= 300s = >= 600s)
      final rA = ranked.firstWhere((r) => r.id == 'route-a');
      expect(rA.hasTraffic, isTrue);
      expect(rA.trafficDelaySeconds, greaterThan(300));
      expect(rA.incidentAlerts.length, 1);
      expect(rA.trafficPoints.isNotEmpty, isTrue);

      // Route B has no traffic delay (400s)
      final rB = ranked.firstWhere((r) => r.id == 'route-b');
      expect(rB.hasTraffic, isFalse);
      expect(rB.trafficDelaySeconds, 0);

      // Therefore Route B (400s) is FASTER than Route A (>= 600s) and ranked #1!
      expect(ranked.first.id, 'route-b');
      expect(ranked.last.id, 'route-a');
    });

    test('ignores expired traffic reports', () {
      final now = DateTime.now();

      const routeA = DriveRoute(
        id: 'route-a',
        name: 'Route A',
        nameAr: 'مسار أ',
        points: [
          LatLng(0.0, 0.0),
          LatLng(0.01, 0.01),
        ],
        steps: [],
        distanceMeters: 1000,
        durationSeconds: 200,
      );

      final expiredReport = RoadReport(
        id: 'old-jam',
        type: ReportType.traffic,
        point: const LatLng(0.005, 0.005),
        createdAt: now.subtract(const Duration(hours: 2)),
        expiresAt: now.subtract(const Duration(hours: 1)),
      );

      final ranked = calculateTrafficAndRankRoutes([routeA], [expiredReport]);
      expect(ranked.first.hasTraffic, isFalse);
      expect(ranked.first.trafficDelaySeconds, 0);
    });

    test('creates multi-point RouteTrafficSegment with severity levels and detects upcoming alerts', () {
      final now = DateTime.now();

      const route = DriveRoute(
        id: 'route-baghdad',
        name: 'Al-Jadriya Route',
        nameAr: 'مسار الجادرية',
        points: [
          LatLng(33.28, 44.38),
          LatLng(33.29, 44.38),
          LatLng(33.30, 44.38), // Jam here
          LatLng(33.31, 44.38),
          LatLng(33.32, 44.38),
        ],
        steps: [],
        distanceMeters: 4000,
        durationSeconds: 400,
      );

      final jam = RoadReport(
        id: 'jam-jadriya',
        type: ReportType.traffic,
        point: const LatLng(33.30, 44.38),
        createdAt: now.subtract(const Duration(minutes: 2)),
        expiresAt: now.add(const Duration(minutes: 30)),
        confirmations: 3,
      );

      final ranked = calculateTrafficAndRankRoutes([route], [jam]);
      final annotated = ranked.first;

      expect(annotated.trafficSegments.isNotEmpty, isTrue);
      final segment = annotated.trafficSegments.first;
      expect(segment.level, TrafficCongestionLevel.heavy);
      expect(segment.estimatedSpeedKmh, 16.0);
      expect(segment.points.length, greaterThanOrEqualTo(2));

      // Test upcoming traffic detection when user is 1km away
      final alert = detectUpcomingTrafficJam(annotated, const LatLng(33.29, 44.38));
      expect(alert, isNotNull);
      expect(alert!.level, TrafficCongestionLevel.heavy);
      expect(alert.delaySeconds, greaterThan(300));
    });
  });
}
