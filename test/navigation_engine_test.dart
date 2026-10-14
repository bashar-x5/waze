import 'package:darb/domain/demo_data.dart';
import 'package:darb/domain/models.dart';
import 'package:darb/domain/navigation_engine.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

void main() {
  group('route progress', () {
    test('projects between sparse vertices and computes proportional ETA', () {
      final progress = calculateProgress(_route(), const LatLng(0, 0.005));
      expect(progress.traveledMeters, closeTo(500, 2));
      expect(progress.remainingMeters, closeTo(1500, 2));
      expect(progress.remainingSeconds, closeTo(450, 1));
      expect(progress.distanceFromRouteMeters, closeTo(0, 0.1));
      expect(progress.stepIndex, 0);
      expect(progress.arrived, isFalse);
    });

    test('computes proportional remaining time using totalDurationSeconds with traffic delay', () {
      final routeWithTraffic = _route().withTraffic(trafficDelaySeconds: 200);
      expect(routeWithTraffic.totalDurationSeconds, 800);
      final progress = calculateProgress(routeWithTraffic, const LatLng(0, 0.005));
      expect(progress.traveledMeters, closeTo(500, 2));
      expect(progress.remainingMeters, closeTo(1500, 2));
      // 800 * (1500 / 2000) = 600s, reflecting traffic delay in the total time at once
      expect(progress.remainingSeconds, closeTo(600, 1));
    });

    test('advances to the next maneuver after passing a bend', () {
      final progress = calculateProgress(
        _route(),
        const LatLng(0.005, 0.01),
        previousMeters: 950,
      );
      expect(progress.traveledMeters, closeTo(1500, 2));
      expect(progress.stepIndex, 1);
    });

    test('a backward GPS drift never rewinds progress or the current step', () {
      final progress = calculateProgress(
        _route(),
        const LatLng(0, 0.009),
        previousMeters: 1100,
      );
      expect(progress.traveledMeters, 1100);
      expect(progress.remainingMeters, 900);
      expect(progress.stepIndex, 1);
      expect(progress.arrived, isFalse);
    });

    test('nearby lateral drift still follows the matched segment', () {
      final progress = calculateProgress(
        _route(),
        const LatLng(0.0002, 0.005),
        previousMeters: 400,
      );
      expect(progress.traveledMeters, closeTo(500, 2));
      expect(progress.distanceFromRouteMeters, closeTo(22.24, 0.5));
      expect(progress.arrived, isFalse);
    });

    test('a fix far off route cannot advance the trip', () {
      final progress = calculateProgress(
        _route(),
        const LatLng(0.008, 0.012),
        previousMeters: 1200,
      );
      expect(progress.distanceFromRouteMeters, greaterThan(200));
      expect(progress.traveledMeters, 1200);
      expect(progress.remainingMeters, 800);
      expect(progress.arrived, isFalse);
    });

    test('overlapping route sections do not jump to the final lap', () {
      const route = DriveRoute(
        id: 'loop',
        name: 'Loop',
        nameAr: '',
        points: [
          LatLng(0, 0),
          LatLng(0, 0.02),
          LatLng(0.02, 0.02),
          LatLng(0.02, 0),
          LatLng(0, 0),
          LatLng(0, 0.02),
        ],
        steps: [],
        distanceMeters: 10000,
        durationSeconds: 1200,
      );
      final progress = calculateProgress(
        route,
        const LatLng(0, 0.005),
        previousMeters: 300,
      );
      expect(progress.traveledMeters, closeTo(500, 5));
      expect(progress.remainingMeters, greaterThan(9000));
      expect(progress.arrived, isFalse);
    });

    test(
      'arrives near the destination only after reaching the final segment',
      () {
        final progress = calculateProgress(
          _route(),
          const LatLng(0.0099, 0.01),
          previousMeters: 1970,
        );
        expect(progress.arrived, isTrue);
        expect(progress.traveledMeters, 2000);
        expect(progress.remainingMeters, 0);
        expect(progress.remainingSeconds, 0);
        expect(progress.stepIndex, 2);
      },
    );

    test('100 m before the destination is not arrival', () {
      final progress = calculateProgress(
        _route(),
        const LatLng(0.009, 0.01),
        previousMeters: 1850,
      );
      expect(progress.arrived, isFalse);
      expect(progress.remainingMeters, greaterThan(90));
    });

    test(
      'a completed distance alone cannot trigger arrival away from route',
      () {
        final progress = calculateProgress(
          _route(),
          const LatLng(0.02, 0.02),
          previousMeters: 2000,
        );
        expect(progress.arrived, isFalse);
      },
    );

    test('handles repeated vertices without NaN progress', () {
      final route = _route(
        points: const [
          LatLng(0, 0),
          LatLng(0, 0),
          LatLng(0, 0.01),
          LatLng(0, 0.01),
          LatLng(0.01, 0.01),
        ],
      );
      final progress = calculateProgress(route, const LatLng(0, 0.005));
      expect(progress.traveledMeters, closeTo(500, 2));
      expect(progress.remainingSeconds.isFinite, isTrue);
    });

    test('empty geometry never claims arrival', () {
      final progress = calculateProgress(
        _route(points: const []),
        const LatLng(0, 0),
      );
      expect(progress.arrived, isFalse);
      expect(progress.traveledMeters, 0);
      expect(progress.remainingMeters, 2000);
      expect(progress.distanceFromRouteMeters, double.infinity);
    });

    test('one-point route at destination has finite progress', () {
      const route = DriveRoute(
        id: 'single',
        name: 'Single',
        nameAr: '',
        points: [LatLng(0, 0)],
        steps: [],
        distanceMeters: 0,
        durationSeconds: 0,
      );
      final progress = calculateProgress(route, const LatLng(0, 0));
      expect(progress.arrived, isTrue);
      expect(progress.remainingSeconds, 0);
      expect(progress.traveledMeters.isFinite, isTrue);
    });
  });

  group('sample data and persistence', () {
    test('all sample categories exist and every route is explicitly demo', () {
      expect(
        demoPlaces.map((place) => place.category).toSet(),
        containsAll(PlaceCategory.values),
      );
      for (final destination in demoPlaces) {
        final routes = demoRoutes(destination);
        expect(routes.length, 3);
        for (final route in routes) {
          expect(route.demo, isTrue);
          expect(route.points.first, baghdadCenter);
          expect(route.points.last, destination.point);
          expect(route.points.length, greaterThan(8));
          expect(route.distanceMeters, greaterThan(0));
          expect(route.durationSeconds, greaterThan(0));
        }
      }
    });

    test('optional stop is included before the final destination', () {
      final destination = demoPlaces.first;
      final stop = demoPlaces[3];
      final route = demoRoutes(destination, stop: stop).first;
      final stopPosition = route.points.indexWhere(
        (point) =>
            (point.latitude - stop.point.latitude).abs() < 1e-8 &&
            (point.longitude - stop.point.longitude).abs() < 1e-8,
      );
      expect(stopPosition, greaterThan(0));
      expect(stopPosition, lessThan(route.points.length - 1));
      expect(route.points.last, destination.point);
    });

    test('unknown destinations never receive fabricated demo routes', () {
      const livePlace = Place(
        id: 'live-result',
        name: 'Real destination',
        nameAr: '',
        subtitle: '',
        subtitleAr: '',
        point: LatLng(33.3, 44.4),
      );
      expect(() => demoRoutes(livePlace), throwsArgumentError);
    });

    test('sample reports have bounded lifetimes and a demo flag', () {
      final now = DateTime.utc(2026, 10, 11, 12);
      for (final report in demoReports(now)) {
        expect(report.demo, isTrue);
        expect(report.createdAt.isBefore(now), isTrue);
        expect(report.expiresAt.isAfter(now), isTrue);
        expect(
          report.expiresAt.difference(now),
          lessThan(const Duration(hours: 1)),
        );
        final saved = RoadReport.fromJson(report.toJson());
        expect(saved.point, report.point);
        expect(saved.expiresAt, report.expiresAt);
        expect(saved.type, report.type);
        expect(saved.demo, isTrue);
      }
    });

    test('planned drives preserve the Arabic destination and arrival time', () {
      final plan = PlannedDrive(
        id: 'planned',
        destination: demoPlaces.first,
        arriveAt: DateTime.utc(2026, 10, 12, 7, 30),
      );
      final saved = PlannedDrive.fromJson(plan.toJson());
      expect(saved.destination.nameAr, plan.destination.nameAr);
      expect(saved.destination.point, plan.destination.point);
      expect(saved.arriveAt, plan.arriveAt);
    });
  });
}

DriveRoute _route({List<LatLng>? points}) => DriveRoute(
  id: 'test',
  name: 'Test route',
  nameAr: 'مسار اختباري',
  points: points ?? const [LatLng(0, 0), LatLng(0, 0.01), LatLng(0.01, 0.01)],
  steps: const [
    RouteStep(
      instruction: 'Depart',
      instructionAr: 'انطلق',
      type: 'depart',
      point: LatLng(0, 0),
      distanceMeters: 1000,
    ),
    RouteStep(
      instruction: 'Turn left',
      instructionAr: 'انعطف يساراً',
      type: 'left',
      point: LatLng(0, 0.01),
      distanceMeters: 1000,
    ),
    RouteStep(
      instruction: 'Arrive',
      instructionAr: 'وصلت',
      type: 'arrive',
      point: LatLng(0.01, 0.01),
      distanceMeters: 0,
    ),
  ],
  distanceMeters: 2000,
  durationSeconds: 600,
);
