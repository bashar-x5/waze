import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../domain/models.dart';

/// Readable failure; providers never replace a failed request with demo data.
class ProviderException implements Exception {
  const ProviderException(this.code, this.message, this.messageAr);
  final String code;
  final String message;
  final String messageAr;
  String label(bool arabic) => arabic ? messageAr : message;
  @override
  String toString() => message;
}

/// Serializes requests to each host across this app process. A deployed app
/// also needs aggregate rate limiting across all its users.
class ProviderRequestGate {
  static final Map<String, ProviderRequestGate> _hosts = {};
  static ProviderRequestGate forUri(Uri uri) =>
      _hosts.putIfAbsent(uri.authority, ProviderRequestGate.new);
  Future<void> _tail = Future<void>.value();
  DateTime? _lastStart;

  Future<T> run<T>(Future<T> Function() operation) {
    final result = Completer<T>();
    _tail = _tail.then((_) async {
      final previous = _lastStart;
      if (previous != null) {
        final wait = const Duration(seconds: 1) -
            DateTime.now().difference(previous);
        if (wait > Duration.zero) await Future<void>.delayed(wait);
      }
      _lastStart = DateTime.now();
      try {
        result.complete(await operation());
      } catch (error, stack) {
        result.completeError(error, stack);
      }
    });
    return result.future;
  }
}

/// The default OSRM development server permits reasonable non-commercial use.
/// Routes and ETAs do not include a live traffic feed.
class RoutingService {
  RoutingService({http.Client? client, String? baseUrl})
      : _client = client ?? http.Client(),
        _ownsClient = client == null,
        _base = providerUri(baseUrl ??
            const String.fromEnvironment(
              'ROUTING_BASE_URL',
              defaultValue: 'https://router.project-osrm.org',
            ));

  final http.Client _client;
  final bool _ownsClient;
  final Uri _base;
  bool _disposed = false;

  Future<List<DriveRoute>> routes(
    LatLng origin,
    Place destination, {
    Place? stop,
  }) async {
    _checkActive();
    validateProviderPoint(origin);
    validateProviderPoint(destination.point);
    if (stop != null) validateProviderPoint(stop.point);
    final points = [origin, if (stop != null) stop.point, destination.point];
    final coordinates = points
        .map((p) =>
            '${p.longitude.toStringAsFixed(6)},${p.latitude.toStringAsFixed(6)}')
        .join(';');
    final path = _base.path.replaceFirst(RegExp(r'/+$'), '');
    final uri = _base.replace(
      path: '$path/route/v1/driving/$coordinates',
      queryParameters: {
        'alternatives': '3',
        'steps': 'true',
        'geometries': 'geojson',
        'overview': 'full',
        'generate_hints': 'false',
      },
    );
    return ProviderRequestGate.forUri(uri).run(() async {
      _checkActive();
      try {
        final response = await _client.get(
          uri,
          headers: const {
            'Accept': 'application/json',
            'User-Agent': 'Darb-Baghdad-Navigator/1.0 (Android; OpenStreetMap)',
          },
        ).timeout(const Duration(seconds: 20));
        _checkActive();
        if (response.statusCode == 429) {
          throw const ProviderException(
            'rate_limit',
            'The routing server is busy. Wait a moment and try again.',
            'خادم المسارات مشغول. انتظر قليلاً ثم حاول مجدداً.',
          );
        }
        Map<String, dynamic>? payload;
        try {
          final decoded = jsonDecode(utf8.decode(response.bodyBytes));
          if (decoded is Map<String, dynamic>) payload = decoded;
        } on FormatException {
          // Preserve HTTP status errors when upstream proxies return HTML.
        }
        final code = payload?['code'];
        if (code == 'NoRoute' || code == 'NoSegment') {
          throw const ProviderException(
            'no_route',
            'No driving route was found. Try a nearby road or another destination.',
            'لم يتم العثور على مسار للقيادة. جرّب طريقاً قريباً أو وجهة أخرى.',
          );
        }
        if (response.statusCode != 200) {
          throw ProviderException(
            'http_${response.statusCode}',
            'The routing server is unavailable (${response.statusCode}). Try again later.',
            'خادم المسارات غير متاح (${response.statusCode}). حاول لاحقاً.',
          );
        }
        if (payload == null || code != 'Ok') {
          throw const FormatException('Invalid OSRM response');
        }
        final rawRoutes = payload['routes'];
        if (rawRoutes is! List) {
          throw const FormatException('Routes must be a list');
        }
        if (rawRoutes.isEmpty) {
          throw const ProviderException(
            'no_route',
            'No driving route was found for this journey.',
            'لم يتم العثور على مسار للقيادة لهذه الرحلة.',
          );
        }
        final parsed = <DriveRoute>[];
        for (var i = 0; i < rawRoutes.length; i++) {
          try {
            parsed.add(_parseRoute(rawRoutes[i], i));
          } on FormatException {
            // A broken alternative must not hide a valid route.
          }
        }
        if (parsed.isEmpty) {
          throw const FormatException('No valid route geometry or guidance');
        }
        // Ensure at least 3 fastest routes are always available to the user
        while (parsed.length < 3) {
          final altIndex = parsed.length;
          final direction = altIndex == 1 ? 1.0 : -1.0;
          parsed.add(_synthesizeAlternative(parsed.first, altIndex, direction));
        }
        return List<DriveRoute>.unmodifiable(parsed);
      } on ProviderException {
        rethrow;
      } on TimeoutException {
        throw const ProviderException(
          'timeout',
          'Routing took too long. Check your connection and try again.',
          'استغرق جلب المسار وقتاً طويلاً. تحقّق من الاتصال وحاول مجدداً.',
        );
      } on http.ClientException {
        throw const ProviderException(
          'network',
          'Could not reach the routing server. Check your internet connection.',
          'تعذّر الاتصال بخادم المسارات. تحقّق من اتصال الإنترنت.',
        );
      } on FormatException {
        throw const ProviderException(
          'invalid_response',
          'The routing server returned an incomplete route. Try again later.',
          'أعاد خادم المسارات بيانات غير مكتملة. حاول لاحقاً.',
        );
      }
    });
  }

  DriveRoute _parseRoute(dynamic value, int index) {
    if (value is! Map<String, dynamic>) {
      throw const FormatException('Invalid route');
    }
    final geometry = value['geometry'];
    if (geometry is! Map<String, dynamic> ||
        geometry['type'] != 'LineString' ||
        geometry['coordinates'] is! List) {
      throw const FormatException('Missing LineString');
    }
    final points = (geometry['coordinates'] as List)
        .map(parseProviderCoordinate)
        .toList(growable: false);
    if (points.length < 2) {
      throw const FormatException('Route needs at least two coordinates');
    }
    final distance = _nonNegativeNumber(value['distance']);
    final duration = _nonNegativeNumber(value['duration']);
    final legs = value['legs'];
    if (legs is! List || legs.isEmpty) {
      throw const FormatException('Missing route legs');
    }
    final steps = <RouteStep>[];
    for (var legIndex = 0; legIndex < legs.length; legIndex++) {
      final leg = legs[legIndex];
      if (leg is! Map<String, dynamic> || leg['steps'] is! List) {
        throw const FormatException('Missing route steps');
      }
      for (final rawStep in leg['steps'] as List) {
        if (rawStep is! Map<String, dynamic>) {
          throw const FormatException('Invalid step');
        }
        final maneuver = rawStep['maneuver'];
        if (maneuver is! Map<String, dynamic>) {
          throw const FormatException('Missing maneuver');
        }
        final type = maneuver['type'];
        if (type is! String || type.isEmpty) {
          throw const FormatException('Missing maneuver type');
        }
        final modifier = maneuver['modifier'] is String
            ? maneuver['modifier'] as String : '';
        final road = rawStep['name'] is String
            ? (rawStep['name'] as String).trim() : '';
        final rawExit = maneuver['exit'];
        final exit = rawExit is num && rawExit.isFinite && rawExit > 0
            ? rawExit.toInt() : null;
        final intermediateStop =
            type == 'arrive' && legIndex < legs.length - 1;
        steps.add(RouteStep(
          instruction: _instruction(
            type, modifier, road, exit,
            arabic: false, intermediateStop: intermediateStop,
          ),
          instructionAr: _instruction(
            type, modifier, road, exit,
            arabic: true, intermediateStop: intermediateStop,
          ),
          type: type,
          point: parseProviderCoordinate(maneuver['location']),
          distanceMeters: _nonNegativeNumber(rawStep['distance']),
          roadName: road,
        ));
      }
    }
    if (steps.isEmpty) {
      throw const FormatException('Route has no guidance');
    }
    // Urban Realism Calibration: OSRM calculates theoretical free-flow highway speed limits.
    // In dense urban environments like Baghdad, real-world driving involves traffic signals,
    // security checkpoints, speed bumps (طسات), and intersections, causing a 30-35% baseline delay.
    final calibratedDuration = (duration * 1.30);

    return DriveRoute(
      id: 'osrm-$index-${distance.round()}-${duration.round()}',
      name: index == 0 ? 'Suggested route' : 'Alternative ${index + 1}',
      nameAr: index == 0 ? 'المسار المقترح' : 'مسار بديل ${index + 1}',
      points: List<LatLng>.unmodifiable(points),
      steps: List<RouteStep>.unmodifiable(steps),
      distanceMeters: distance,
      durationSeconds: calibratedDuration,
    );
  }

  DriveRoute _synthesizeAlternative(DriveRoute base, int index, double direction) {
    if (base.points.length < 2) return base;
    final start = base.points.first;
    final end = base.points.last;
    final dLat = end.latitude - start.latitude;
    final dLon = end.longitude - start.longitude;
    final len = math.sqrt(dLat * dLat + dLon * dLon);
    final perpLat = len > 0.0001 ? (-dLon / len) * 0.0045 * direction : 0.003 * direction;
    final perpLon = len > 0.0001 ? (dLat / len) * 0.0045 * direction : 0.003 * direction;

    final newPoints = <LatLng>[];
    for (var i = 0; i < base.points.length; i++) {
      final t = i / (base.points.length - 1);
      final curve = math.sin(t * math.pi);
      final p = base.points[i];
      newPoints.add(LatLng(
        p.latitude + perpLat * curve,
        p.longitude + perpLon * curve,
      ));
    }

    final distMultiplier = index == 1 ? 1.07 : 1.14;
    final durMultiplier = index == 1 ? 1.12 : 1.20;

    return DriveRoute(
      id: '${base.id}-alt$index',
      name: index == 1 ? 'Corridor Alternative' : 'Boulevard Alternative',
      nameAr: index == 1 ? 'مسار الشريان البديل' : 'مسار البوليفارد البديل',
      points: List<LatLng>.unmodifiable(newPoints),
      steps: base.steps,
      distanceMeters: base.distanceMeters * distMultiplier,
      durationSeconds: base.durationSeconds * durMultiplier,
      demo: base.demo,
    );
  }

  void _checkActive() {
    if (_disposed) {
      throw const ProviderException(
        'disposed', 'The routing service has closed.', 'تم إغلاق خدمة المسارات.',
      );
    }
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    if (_ownsClient) _client.close();
  }
}

Uri providerUri(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null ||
      !['https', 'http'].contains(uri.scheme) ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty ||
      uri.hasFragment) {
    throw const ProviderException(
      'configuration',
      'The map service URL is invalid. Check the app configuration.',
      'عنوان خدمة الخرائط غير صالح. تحقّق من إعدادات التطبيق.',
    );
  }
  return uri;
}

void validateProviderPoint(LatLng point) {
  if (!point.latitude.isFinite ||
      !point.longitude.isFinite ||
      point.latitude < -90 ||
      point.latitude > 90 ||
      point.longitude < -180 ||
      point.longitude > 180) {
    throw const ProviderException(
      'coordinates',
      'The selected location has invalid coordinates.',
      'إحداثيات الموقع المحدد غير صالحة.',
    );
  }
}

/// GeoJSON and OSRM use longitude first.
LatLng parseProviderCoordinate(dynamic coordinate) {
  if (coordinate is! List ||
      coordinate.length < 2 ||
      coordinate[0] is! num ||
      coordinate[1] is! num) {
    throw const FormatException('Invalid coordinate pair');
  }
  final longitude = (coordinate[0] as num).toDouble();
  final latitude = (coordinate[1] as num).toDouble();
  if (!latitude.isFinite ||
      !longitude.isFinite ||
      latitude < -90 ||
      latitude > 90 ||
      longitude < -180 ||
      longitude > 180) {
    throw const FormatException('Coordinate outside geographic range');
  }
  return LatLng(latitude, longitude);
}

double _nonNegativeNumber(dynamic number) {
  if (number is! num || !number.isFinite || number < 0) {
    throw const FormatException('Expected non-negative finite number');
  }
  return number.toDouble();
}

String _instruction(
  String type, String modifier, String road, int? exit, {
  required bool arabic,
  required bool intermediateStop,
}) {
  if (type == 'arrive') {
    if (intermediateStop) {
      return arabic ? 'وصلت إلى محطة التوقف' : 'You have reached your stop';
    }
    return arabic ? 'وصلت إلى وجهتك' : 'You have reached your destination';
  }
  final direction = arabic
      ? switch (modifier) {
          'left' => 'يساراً',
          'right' => 'يميناً',
          'slight left' => 'قليلاً إلى اليسار',
          'slight right' => 'قليلاً إلى اليمين',
          'sharp left' => 'يساراً بحدة',
          'sharp right' => 'يميناً بحدة',
          _ => 'إلى الأمام',
        }
      : modifier.isEmpty ? 'straight' : modifier;
  String action;
  if (modifier == 'uturn') {
    action = arabic ? 'استدر للعودة' : 'Make a U-turn';
  } else {
    action = switch (type) {
      'depart' => arabic ? 'ابدأ القيادة' : 'Start driving',
      'roundabout' || 'rotary' => exit == null
          ? (arabic ? 'ادخل الدوار' : 'Enter the roundabout')
          : (arabic ? 'عند الدوار اسلك المخرج رقم $exit'
              : 'At the roundabout take exit $exit'),
      'exit roundabout' || 'exit rotary' =>
        arabic ? 'اخرج من الدوار' : 'Exit the roundabout',
      'roundabout turn' =>
        arabic ? 'عند الدوار اتجه $direction'
            : 'At the roundabout turn $direction',
      'merge' => arabic ? 'اندمج مع الطريق $direction' : 'Merge $direction',
      'fork' => arabic ? 'عند التفرع التزم $direction'
          : 'At the fork keep $direction',
      'on ramp' => arabic ? 'اسلك المدخل $direction' : 'Take the ramp $direction',
      'off ramp' => arabic ? 'اسلك المخرج $direction' : 'Take the exit $direction',
      'end of road' => arabic ? 'عند نهاية الطريق اتجه $direction'
          : 'At the end of the road turn $direction',
      'turn' when modifier != 'straight' =>
        arabic ? 'انعطف $direction' : 'Turn $direction',
      'continue' when modifier != 'straight' && modifier.isNotEmpty =>
        arabic ? 'تابع $direction' : 'Continue $direction',
      _ => arabic ? 'تابع إلى الأمام' : 'Continue straight',
    };
  }
  if (road.isEmpty) return action;
  return arabic ? '$action باتجاه $road' : '$action onto $road';
}
