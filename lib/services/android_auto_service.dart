import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';

import '../app/app_controller.dart';
import '../domain/models.dart';
import '../domain/voice_command_parser.dart';

/// Bridges active navigation state, routes, voice navigation, and saved places to Android Auto
class AndroidAutoService {
  AndroidAutoService(this.controller) {
    _channel.setMethodCallHandler(_handleMethodCall);
    controller.addListener(_onControllerChanged);
    _onControllerChanged();
  }

  @visibleForTesting
  Future<dynamic> handleMethodCall(MethodCall call) => _handleMethodCall(call);

  final AppController controller;
  static const MethodChannel _channel = MethodChannel('app.darb.darb/android_auto');

  Place? _getHome() {
    if (controller.homeId == null) return null;
    try {
      return controller.saved.firstWhere((p) => p.id == controller.homeId);
    } catch (_) {
      return null;
    }
  }

  Place? _getWork() {
    if (controller.workId == null) return null;
    try {
      return controller.saved.firstWhere((p) => p.id == controller.workId);
    } catch (_) {
      return null;
    }
  }

  Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onDestinationSelected':
        final args = call.arguments as Map?;
        if (args != null) {
          final id = args['id'] as String?;
          final lat = (args['lat'] as num?)?.toDouble() ?? 0.0;
          final lon = (args['lon'] as num?)?.toDouble() ?? 0.0;

          Place? target;
          for (final p in controller.saved) {
            if (p.id == id) {
              target = p;
              break;
            }
          }

          target ??= Place(
            id: id ?? 'car-dest',
            name: 'Car Destination',
            nameAr: 'الوجهة المحددة',
            subtitle: '',
            subtitleAr: '',
            point: LatLng(lat, lon),
          );

          await controller.chooseDestination(target);
          if (controller.routes.isNotEmpty) {
            await controller.startNavigation();
          }
        }
        break;

      case 'onStopNavigation':
        controller.stopNavigation();
        break;

      case 'onVoiceSearchSubmitted':
        final args = call.arguments as Map?;
        final rawQuery = args?['query'] as String? ?? '';
        if (rawQuery.trim().isEmpty) return false;

        final parser = const VoiceCommandParser();
        final result = parser.parse(rawQuery);

        // 1. Non-navigation voice commands (Cancel, Mute, Hazard, etc.)
        if (result.intent != VoiceIntentType.navigate) {
          await controller.executeVoiceCommand(result);
          final statusMsg = result.intent == VoiceIntentType.reportHazard
              ? (controller.arabic ? 'تم تسجيل البلاغ بنجاح' : 'Hazard reported')
              : (controller.arabic ? 'تم تنفيذ الأمر الصوتي' : 'Command executed');
          try {
            await _channel.invokeMethod('setSearchStatus', statusMsg);
          } catch (_) {}
          return {'action': 'command_executed', 'intent': result.intent.name};
        }

        // 2. Navigation Intent: Extract clean destination query
        final targetQuery = result.destinationQuery.isNotEmpty ? result.destinationQuery : rawQuery;
        final places = await controller.searchPlacesDirect(targetQuery);

        if (places.isNotEmpty) {
          // Send all matching places to Android Auto
          _sendSearchResults(places);

          // Immediately navigate to the highest confidence match
          final bestMatch = places.first;
          await controller.navigateToPlaceFromVoice(bestMatch);
          return {'action': 'navigating', 'placeId': bestMatch.id};
        } else {
          final notFoundMsg = controller.arabic
              ? 'لم نعثر على "$targetQuery". حاول تحديد المكان بشكل أدق.'
              : 'No places found for "$targetQuery". Please try again.';
          try {
            await _channel.invokeMethod('setSearchStatus', notFoundMsg);
          } catch (_) {}
          return {'action': 'not_found', 'query': targetQuery};
        }

      case 'onSearchQueryChanged':
        final args = call.arguments as Map?;
        final query = args?['query'] as String? ?? '';
        if (query.trim().length >= 2) {
          final parser = const VoiceCommandParser();
          final cleanQuery = parser.extractDestination(query);
          final places = await controller.searchPlacesDirect(
            cleanQuery.isNotEmpty ? cleanQuery : query,
          );
          _sendSearchResults(places);
        }
        break;
    }
  }

  void _sendSearchResults(List<Place> places) {
    final arabic = controller.arabic;
    final results = places.take(6).map((p) {
      final distMeters = const Distance().as(
        LengthUnit.Meter,
        controller.position,
        p.point,
      );
      return {
        'id': p.id,
        'title': p.label(arabic),
        'subtitle': p.detail(arabic),
        'lat': p.point.latitude,
        'lon': p.point.longitude,
        'distanceText': controller.distance(distMeters),
      };
    }).toList();

    try {
      _channel.invokeMethod('updateSearchResults', results);
    } catch (_) {}
  }

  void _onControllerChanged() {
    _syncNavState();
    _syncSavedPlaces();
  }

  void _syncNavState() {
    final navigating = controller.navigating;
    final r = controller.route;
    final p = controller.progress;
    final arabic = controller.arabic;

    RouteStep? step;
    var etaText = '';
    var remainingDistanceText = '';
    var stepDistMeters = 0.0;

    if (r != null && p != null && r.steps.isNotEmpty) {
      final stepIdx = p.stepIndex.clamp(0, r.steps.length - 1);
      step = r.steps[stepIdx];
      etaText = controller.duration(p.remainingSeconds);
      remainingDistanceText = controller.distance(p.remainingMeters);
      stepDistMeters = p.stepRemainingMeters ?? step.distanceMeters;
    }

    var maneuverCode = 1; // Default Straight
    if (step != null) {
      final t = step.type.toLowerCase();
      if (t.contains('slight_left') || t.contains('slight left')) {
        maneuverCode = 2;
      } else if (t.contains('sharp_left') || t.contains('sharp left')) {
        maneuverCode = 4;
      } else if (t.contains('left')) {
        maneuverCode = 3;
      } else if (t.contains('slight_right') || t.contains('slight right')) {
        maneuverCode = 5;
      } else if (t.contains('sharp_right') || t.contains('sharp right')) {
        maneuverCode = 7;
      } else if (t.contains('right')) {
        maneuverCode = 6;
      } else if (t.contains('u-turn') || t.contains('uturn')) {
        maneuverCode = 8;
      } else if (t.contains('destination') || t.contains('arrive')) {
        maneuverCode = 9;
      }
    }

    try {
      _channel.invokeMethod('updateNavState', {
        'isNavigating': navigating,
        'instruction': step != null ? step.label(arabic) : '',
        'distanceText': step != null ? controller.distance(step.distanceMeters) : '',
        'stepDistanceMeters': stepDistMeters,
        'etaText': etaText,
        'remainingDistanceText': remainingDistanceText,
        'roadName': step?.roadName ?? '',
        'maneuverType': maneuverCode,
      });
    } catch (_) {}
  }

  void _syncSavedPlaces() {
    final places = <Map<String, dynamic>>[];
    final arabic = controller.arabic;
    final home = _getHome();
    final work = _getWork();

    if (home != null) {
      places.add({
        'id': home.id,
        'title': arabic ? 'المنزل' : 'Home',
        'subtitle': home.label(arabic),
        'lat': home.point.latitude,
        'lon': home.point.longitude,
      });
    }

    if (work != null) {
      places.add({
        'id': work.id,
        'title': arabic ? 'العمل' : 'Work',
        'subtitle': work.label(arabic),
        'lat': work.point.latitude,
        'lon': work.point.longitude,
      });
    }

    for (final p in controller.saved) {
      if (p.id == home?.id || p.id == work?.id) continue;
      places.add({
        'id': p.id,
        'title': p.label(arabic),
        'subtitle': p.detail(arabic),
        'lat': p.point.latitude,
        'lon': p.point.longitude,
      });
    }

    try {
      _channel.invokeMethod('updateSavedPlaces', places);
    } catch (_) {}
  }

  void dispose() {
    controller.removeListener(_onControllerChanged);
    _channel.setMethodCallHandler(null);
  }
}
