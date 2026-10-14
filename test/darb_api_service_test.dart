import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';
import 'package:darb/domain/models.dart';
import 'package:darb/services/darb_api_service.dart';

void main() {
  group('DarbApiService', () {
    test('sendObservation sends formatted JSON and returns true on 200', () async {
      final client = MockClient((request) async {
        expect(request.url.path, '/api/traffic/observations');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['latitude'], 33.3152);
        expect(body['longitude'], 44.3661);
        expect(body['speedKmh'], 45.0);
        expect(body['sessionId'], 'test_session');
        return http.Response('{"message":"Observation received."}', 200);
      });

      final service = DarbApiService(client: client, baseUrl: 'http://localhost:5000');
      final result = await service.sendObservation(
        point: const LatLng(33.3152, 44.3661),
        speedKmh: 45.0,
        sessionId: 'test_session',
      );

      expect(result, isTrue);
      service.dispose();
    });

    test('fetchRoutes parses server routes with traffic delay', () async {
      final mockJson = jsonEncode([
        {
          'id': 'route_baghdad_1',
          'name': '14th of July Highway',
          'nameAr': 'طريق 14 تموز',
          'distanceMeters': 4500.0,
          'durationSeconds': 500.0,
          'trafficDelaySeconds': 180.0,
          'coordinates': [
            [44.3661, 33.3152],
            [44.4009, 33.3406],
          ],
          'trafficPoints': [
            [44.3700, 33.3200],
          ],
          'steps': [
            {
              'instruction': 'Head north on 14th of July',
              'instructionAr': 'اتجه شمالاً على طريق 14 تموز',
              'type': 'straight',
              'latitude': 33.3152,
              'longitude': 44.3661,
              'distanceMeters': 2000.0,
              'roadName': '14th of July',
            }
          ]
        }
      ]);

      final client = MockClient((request) async {
        expect(request.url.path, '/api/route');
        return http.Response.bytes(
          utf8.encode(mockJson),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      final service = DarbApiService(client: client, baseUrl: 'http://localhost:5000');
      final routes = await service.fetchRoutes(
        const LatLng(33.3152, 44.3661),
        const LatLng(33.3406, 44.4009),
      );

      expect(routes, isNotNull);
      expect(routes!.length, 1);
      final r = routes.first;
      expect(r.id, 'route_baghdad_1');
      expect(r.trafficDelaySeconds, 180.0);
      expect(r.hasTraffic, isTrue);
      expect(r.trafficPoints.length, 1);
      expect(r.steps.length, 1);
      expect(r.steps.first.roadName, '14th of July');

      service.dispose();
    });

    test('reportIncident and confirmIncident invoke correct endpoints', () async {
      final client = MockClient((request) async {
        if (request.url.path == '/api/traffic/incidents') {
          return http.Response('{"id":"inc_99"}', 201);
        }
        if (request.url.path == '/api/traffic/incidents/inc_99/confirm') {
          return http.Response('{"message":"confirmed"}', 200);
        }
        return http.Response('Not found', 404);
      });

      final service = DarbApiService(client: client, baseUrl: 'http://localhost:5000');
      final now = DateTime.now();
      final reported = await service.reportIncident(RoadReport(
        id: 'inc_99',
        type: ReportType.crash,
        point: const LatLng(33.3152, 44.3661),
        createdAt: now,
        expiresAt: now.add(const Duration(hours: 1)),
        description: 'Test crash',
      ));
      expect(reported, isTrue);

      final confirmed = await service.confirmIncident('inc_99');
      expect(confirmed, isTrue);

      service.dispose();
    });
  });
}
