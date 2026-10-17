import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../domain/models.dart';
import '../domain/demo_data.dart';
import 'routing_service.dart'
    show ProviderException, ProviderRequestGate, providerUri,
        validateProviderPoint, parseProviderCoordinate;

/// Call only after an explicit search submission, never on every keystroke.
/// Photon permits reasonable public demo use without availability guarantees.
/// A larger deployment should run its own open-source Photon instance.
class PlaceSearchService {
  PlaceSearchService({http.Client? client, String? baseUrl})
      : _client = client ?? http.Client(),
        _ownsClient = client == null,
        _base = providerUri(baseUrl ??
            const String.fromEnvironment(
              'SEARCH_BASE_URL',
              defaultValue: 'https://photon.komoot.io/api',
            ));

  final http.Client _client;
  final bool _ownsClient;
  final Uri _base;
  final Map<String, _SearchCacheEntry> _cache = {};
  bool _disposed = false;

  Future<List<Place>> search(String query, {LatLng? near}) async {
    _checkActive();
    final text = query.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (text.length < 2) return const [];
    if (text.length > 200) {
      throw const ProviderException(
        'query',
        'Use a shorter place name or address (up to 200 characters).',
        'استخدم اسم مكان أو عنواناً أقصر (حتى ٢٠٠ حرف).',
      );
    }
    if (near != null) validateProviderPoint(near);
    // Coarsen the bias to about 100 m for repeat-search caching.
    final key = '${text.toLowerCase()}|'
        '${near?.latitude.toStringAsFixed(3)}|'
        '${near?.longitude.toStringAsFixed(3)}';
    final cached = _cached(key);
    if (cached != null) return cached;
    final biasLat = near?.latitude.toStringAsFixed(3) ?? '33.315';
    final biasLon = near?.longitude.toStringAsFixed(3) ?? '44.366';
    final uri = _base.replace(queryParameters: {
      ..._base.queryParameters,
      'q': text,
      'limit': '12',
      'lat': biasLat,
      'lon': biasLon,
      'location_bias_scale': '0.2',
    });
    return ProviderRequestGate.forUri(uri).run(() async {
      _checkActive();
      // A request queued behind an identical search can reuse its result.
      final previous = _cached(key);
      if (previous != null) return previous;
      try {
        final response = await _client.get(
          uri,
          headers: const {
            'Accept': 'application/json',
            'User-Agent': 'Darb-Baghdad-Navigator/1.0 (Android; OpenStreetMap)',
          },
        ).timeout(const Duration(seconds: 15));
        _checkActive();
        if (response.statusCode == 429) {
          throw const ProviderException(
            'rate_limit',
            'Place search is busy. Wait a moment and try again.',
            'خدمة البحث مشغولة. انتظر قليلاً ثم حاول مجدداً.',
          );
        }
        if (response.statusCode != 200) {
          final fallback = _localFallback(text);
          if (fallback.isNotEmpty) return fallback;
          throw ProviderException(
            'http_${response.statusCode}',
            'Place search is unavailable (${response.statusCode}). Try again later.',
            'البحث عن الأماكن غير متاح (${response.statusCode}). حاول لاحقاً.',
          );
        }
        final payload = jsonDecode(utf8.decode(response.bodyBytes));
        if (payload is! Map<String, dynamic> || payload['features'] is! List) {
          throw const FormatException('Invalid Photon response');
        }
        final places = <String, Place>{};
        for (final feature in payload['features'] as List) {
          try {
            final place = _parsePlace(feature);
            if (place != null) places.putIfAbsent(place.id, () => place);
          } on FormatException {
            // Skip a malformed result; it must not create an invalid map pin.
          }
        }
        final list = List<Place>.from(places.values);
        final result = List<Place>.unmodifiable(list);
        if (_cache.length >= 60) _cache.remove(_cache.keys.first);
        _cache[key] = _SearchCacheEntry(DateTime.now(), result);
        return result;
      } on ProviderException {
        rethrow;
      } on TimeoutException {
        throw const ProviderException(
          'timeout',
          'Place search took too long. Check your connection and try again.',
          'استغرق البحث وقتاً طويلاً. تحقّق من الاتصال وحاول مجدداً.',
        );
      } on http.ClientException {
        throw const ProviderException(
          'network',
          'Could not reach place search. Check your internet connection.',
          'تعذّر الاتصال بخدمة البحث. تحقّق من اتصال الإنترنت.',
        );
      } on FormatException {
        throw const ProviderException(
          'invalid_response',
          'The search server returned unreadable results. Try again later.',
          'أعاد خادم البحث نتائج غير صالحة. حاول لاحقاً.',
        );
      }
    });
  }

  List<Place>? _cached(String key) {
    final entry = _cache[key];
    if (entry == null) return null;
    if (DateTime.now().difference(entry.createdAt) >
        const Duration(minutes: 10)) {
      _cache.remove(key);
      return null;
    }
    return entry.places;
  }

  Place? _parsePlace(dynamic feature) {
    if (feature is! Map<String, dynamic>) {
      throw const FormatException('Invalid feature');
    }
    final geometry = feature['geometry'];
    final properties = feature['properties'];
    if (geometry is! Map<String, dynamic> ||
        geometry['type'] != 'Point' ||
        properties is! Map<String, dynamic>) {
      throw const FormatException('Invalid feature geometry');
    }
    final point = parseProviderCoordinate(geometry['coordinates']);
    final country = _text(properties['countrycode']).toUpperCase();
    final countryName = _text(properties['country']);
    final extra = properties['extra'] is Map<String, dynamic>
        ? properties['extra'] as Map<String, dynamic>
        : const <String, dynamic>{};
    final rawName = _first([
      properties['name'], properties['street'],
      properties['city'], properties['state'],
    ]);
    if (rawName.isEmpty) {
      throw const FormatException('Place has no name');
    }
    final english = _first([properties['name:en'], extra['name:en'], rawName]);
    final arabic = _first([properties['name:ar'], extra['name:ar'], rawName]);
    final details = [
      _text(properties['street']),
      _text(properties['district']),
      _text(properties['city']),
      _text(properties['state']),
      countryName,
    ].where((s) => s.isNotEmpty && s != rawName).toSet().join(', ');
    final osmId = properties['osm_id'];
    final osmType = _text(properties['osm_type']);
    final id = osmId is num || osmId is String
        ? 'photon-$osmType-$osmId'
        : 'photon-${point.latitude}-${point.longitude}-${Uri.encodeComponent(rawName)}';
    final tag = _text(properties['osm_value']);
    final category = switch (tag) {
      'fuel' => PlaceCategory.fuel,
      'parking' || 'parking_entrance' || 'parking_space' =>
        PlaceCategory.parking,
      'charging_station' => PlaceCategory.charging,
      'restaurant' || 'cafe' || 'fast_food' || 'food_court' =>
        PlaceCategory.food,
      _ => PlaceCategory.landmark,
    };
    return Place(
      id: id,
      name: english,
      nameAr: arabic,
      subtitle: details.isEmpty ? (countryName.isNotEmpty ? countryName : (country == 'IQ' ? 'Iraq' : country)) : details,
      subtitleAr: details.isEmpty ? (countryName.isNotEmpty ? countryName : (country == 'IQ' ? 'العراق' : country)) : details,
      point: point,
      category: category,
    );
  }

  List<Place> _localFallback(String query) {
    final q = query.trim().toLowerCase();
    return demoPlaces.where((p) =>
      p.name.toLowerCase().contains(q) ||
      p.nameAr.toLowerCase().contains(q) ||
      p.subtitle.toLowerCase().contains(q) ||
      p.subtitleAr.toLowerCase().contains(q)
    ).toList();
  }

  void _checkActive() {
    if (_disposed) {
      throw const ProviderException(
        'disposed', 'Place search has closed.', 'تم إغلاق خدمة البحث.',
      );
    }
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _cache.clear();
    if (_ownsClient) _client.close();
  }
}

class _SearchCacheEntry {
  const _SearchCacheEntry(this.createdAt, this.places);
  final DateTime createdAt;
  final List<Place> places;
}

String _text(dynamic value) => value is String ? value.trim() : '';

String _first(List<dynamic> values) {
  for (final value in values) {
    final text = _text(value);
    if (text.isNotEmpty) return text;
  }
  return '';
}
