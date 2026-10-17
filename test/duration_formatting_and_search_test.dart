import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';
import 'package:darb/app/app_controller.dart';
import 'package:darb/services/place_search_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Duration Formatting Tests (Hours & Minutes)', () {
    test('Formats sub-hour durations correctly in English and Arabic', () {
      final controller = AppController();
      controller.arabic = false;
      expect(controller.duration(300), '5 min');
      expect(controller.duration(2700), '45 min');

      controller.arabic = true;
      expect(controller.duration(300), '5 د');
      expect(controller.duration(2700), '45 د');
    });

    test('Formats exact hour durations (e.g. 60 min -> 1h)', () {
      final controller = AppController();
      controller.arabic = false;
      expect(controller.duration(3600), '1h');
      expect(controller.duration(7200), '2h');

      controller.arabic = true;
      expect(controller.duration(3600), '1 س');
      expect(controller.duration(7200), '2 س');
    });

    test('Formats 90 minutes as 1h 30min and 1 س 30 د', () {
      final controller = AppController();
      controller.arabic = false;
      expect(controller.duration(5400), '1h 30min');

      controller.arabic = true;
      expect(controller.duration(5400), '1 س 30 د');
    });

    test('Formats multi-hour multi-minute durations (e.g. 125 min -> 2h 5min)', () {
      final controller = AppController();
      controller.arabic = false;
      expect(controller.duration(7500), '2h 5min');

      controller.arabic = true;
      expect(controller.duration(7500), '2 س 5 د');
    });
  });

  group('Out of Iraq Place Search Tests', () {
    test('Search returns international destinations outside Iraq borders', () async {
      final photonAmmanResponse = jsonEncode({
        'type': 'FeatureCollection',
        'features': [
          {
            'type': 'Feature',
            'properties': {
              'osm_type': 'N',
              'osm_id': 1643504896,
              'osm_key': 'place',
              'osm_value': 'city',
              'type': 'city',
              'name': 'عمان',
              'name:en': 'Amman',
              'name:ar': 'عمان',
              'city': 'عمان',
              'state': 'محافظة العاصمة',
              'country': 'الأردن',
              'countrycode': 'JO',
            },
            'geometry': {
              'type': 'Point',
              'coordinates': [35.9239625, 31.9515694],
            },
          }
        ]
      });

      final client = MockClient((request) async {
        expect(request.url.queryParameters['q'], 'Amman');
        // Verify countrycode=IQ and restrictive Iraq bbox are NOT present
        expect(request.url.queryParameters.containsKey('countrycode'), isFalse);
        expect(request.url.queryParameters.containsKey('bbox'), isFalse);
        return http.Response(photonAmmanResponse, 200, headers: {'content-type': 'application/json'});
      });

      final service = PlaceSearchService(client: client);
      final results = await service.search('Amman', near: const LatLng(33.315, 44.366));

      expect(results, isNotEmpty);
      final place = results.first;
      expect(place.name, 'Amman');
      expect(place.nameAr, 'عمان');
      expect(place.point.latitude, closeTo(31.9515, 0.001));
      expect(place.point.longitude, closeTo(35.9239, 0.001));
      expect(place.subtitle, contains('الأردن'));
      service.dispose();
    });
  });
}
