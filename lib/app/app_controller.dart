import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../domain/demo_data.dart';
import '../domain/models.dart';
import '../domain/navigation_engine.dart';
import '../domain/traffic_engine.dart';
import '../services/routing_service.dart';
import '../services/place_search_service.dart';
import '../services/community_service.dart';
import '../services/darb_api_service.dart';
import '../domain/voice_command_parser.dart';

class AppController extends ChangeNotifier {
  AppController({
    this.enableDeviceServices = true,
    RoutingService? routing,
    PlaceSearchService? search,
    DarbApiService? api,
  })  : _routing = routing ?? RoutingService(),
        _search = search ?? PlaceSearchService(),
        _api = api ?? DarbApiService();

  final bool enableDeviceServices;
  final RoutingService _routing;
  final PlaceSearchService _search;
  final DarbApiService _api;
  String _sessionId = 'MAC-${Random().nextInt(0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';
  String? _deviceModel;
  String? _deviceName;
  String? _osVersion;
  final Set<String> _spokenManeuverSignatures = {};
  final Set<String> _announcedWarningIds = {};
  String? _lastSpokenPhrase;
  DateTime? _lastSpokenTimestamp;
  DateTime? _lastGpsObservationSent;
  SharedPreferences? _prefs;
  FlutterTts? _tts;
  bool? _ttsLanguageConfiguredForArabic;
  CommunityService _community = CommunityService();
  StreamSubscription<Position>? _gps;
  StreamSubscription<List<RoadReport>>? _reportStream;
  Timer? _simulation;
  Timer? _expiry;
  Timer? _serverIncidentsTimer;
  Timer? _updateCheckTimer;
  Timer? _liveRoomTimer;
  LiveRoom? activeLiveRoom;
  String? userDisplayName;
  VoidCallback? onFitConvoyTrack;
  void Function(LatLng point)? onAnimateCameraTo;

  void requestFitConvoyTrack() {
    onFitConvoyTrack?.call();
  }

  void animateCameraTo(LatLng point) {
    onAnimateCameraTo?.call(point);
  }

  static const int localAppVersionCode = 8;
  static const String localAppVersionName = '1.0.8';
  Map<String, dynamic>? updateAvailableInfo;
  RoadReport? pendingPromptReport;
  final Set<String> _promptedIncidentIds = {};

  String get userId => _sessionId;
  String? get deviceModel => _deviceModel;
  String? get deviceName => _deviceName;
  String? get osVersion => _osVersion;
  bool _disposed = false;
  int _routeRequest = 0;
  int _searchRequest = 0;
  int _spokenStep = -1;
  int _offRouteSamples = 0;
  DateTime? _lastReroute;
  double _demoProgress = 0;
  Future<void> _saveQueue = Future.value();

  bool arabic = false;
  bool dark = false;
  bool satellite = false;
  bool miles = false;
  bool voice = true;
  bool lessChatty = false;
  bool demoMode = false;
  bool sharing = true;
  bool busy = false;
  bool searching = false;
  bool locating = false;
  bool navigating = false;
  bool arrived = false;
  bool gpsReady = false;
  ParkedCarLocation? parkedLocation;
  bool showParkingPrompt = false;
  String? error;
  String? notice;
  LatLng position = baghdadCenter;
  double speedKph = 0;
  double heading = 0;
  Place? destination;
  Place? stop;
  List<DriveRoute> routes = [];
  int routeIndex = 0;
  NavigationProgress? progress;
  List<Place> searchResults = [];
  List<Place> saved = [];
  List<Place> recent = [];
  List<PlannedDrive> plans = [];
  List<RoadReport> localReports = [];
  List<RoadReport> sharedReports = [];
  final Set<String> confirmed = {};
  final Set<ReportType> muted = {};
  String? homeId;
  String? workId;

  String tr(String en, String ar) => arabic ? ar : en;
  DriveRoute? get route => routes.isEmpty ? null : routes[routeIndex.clamp(0, routes.length - 1)];
  bool get backendConfigured => _community.configured;
  List<RoadReport> get reports {
    final values = <RoadReport>[
      ...localReports.where((r) => !r.demo),
      if (sharing) ...sharedReports.where((r) => !r.demo),
    ];
    final byId = <String, RoadReport>{};
    for (final r in values) {
      if (r.isActive && !r.demo && !muted.contains(r.type)) byId[r.id] = r;
    }
    return byId.values.toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Future<void> load() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      var savedId = _prefs!.getString('darb.device_user_id.v1');
      _deviceModel = _prefs!.getString('darb.device_model.v1');
      _deviceName = _prefs!.getString('darb.device_name.v1');
      _osVersion = _prefs!.getString('darb.device_os.v1');
      userDisplayName = _prefs!.getString('darb.user_display_name.v1');

      // Fetch real hardware Android ID & device info from native platform channel
      if (enableDeviceServices && defaultTargetPlatform == TargetPlatform.android) {
        try {
          const channel = MethodChannel('app.darb.darb/device');
          final info = await channel
              .invokeMethod<Map<dynamic, dynamic>>('getDeviceInfo')
              .timeout(const Duration(milliseconds: 500), onTimeout: () => null);

          if (info != null) {
            final rawId = info['androidId']?.toString();
            final model = info['deviceModel']?.toString();
            final name = info['deviceName']?.toString();
            final os = info['osVersion']?.toString();

            if (model != null && model.trim().isNotEmpty) {
              _deviceModel = model.trim();
              await _prefs!.setString('darb.device_model.v1', _deviceModel!);
            }
            if (name != null && name.trim().isNotEmpty) {
              _deviceName = name.trim();
              await _prefs!.setString('darb.device_name.v1', _deviceName!);
            }
            if (os != null && os.trim().isNotEmpty) {
              _osVersion = os.trim();
              await _prefs!.setString('darb.device_os.v1', _osVersion!);
            }

            if ((savedId == null || savedId.isEmpty) && rawId != null && rawId.trim().isNotEmpty) {
              final hex = rawId.replaceAll(RegExp(r'[^0-9a-fA-F]'), '').toUpperCase();
              if (hex.length >= 12) {
                final chunks = <String>[];
                for (var i = 0; i < 12; i += 2) {
                  chunks.add(hex.substring(i, i + 2));
                }
                savedId = 'MAC-${chunks.join(':')}';
              } else if (hex.isNotEmpty) {
                savedId = 'MAC-${hex.padRight(12, '0').substring(0, 12)}';
              }
            }
          }
        } catch (_) {}
      }

      // Fallback to stable generated MAC only if hardware platform ID is unavailable
      if (savedId == null || savedId.isEmpty) {
        final rand = Random();
        final macLike = List.generate(
          6,
          (_) => rand.nextInt(256).toRadixString(16).padLeft(2, '0'),
        ).join(':').toUpperCase();
        savedId = 'MAC-$macLike';
      }

      await _prefs!.setString('darb.device_user_id.v1', savedId);
      _sessionId = savedId;
      final raw = _prefs!.getString('darb.preferences.v1');
      if (raw != null) {
        final p = jsonDecode(raw) as Map<String, dynamic>;
        arabic = p['arabic'] == true;
        dark = p['dark'] == true;
        satellite = p['satellite'] == true;
        miles = p['miles'] == true;
        voice = p['voice'] != false;
        lessChatty = p['lessChatty'] == true;
        // A restart always begins in demo mode; GPS/sharing require fresh intent.
        saved = _decodeList(p['saved'], Place.fromJson);
        recent = _decodeList(p['recent'], Place.fromJson);
        plans = _decodeList(p['plans'], PlannedDrive.fromJson);
        localReports = _decodeList(p['reports'], RoadReport.fromJson)
            .where((r) => r.isActive).toList();
        homeId = p['homeId'] as String?;
        workId = p['workId'] as String?;
        if (p['parkedLocation'] != null) {
          try {
            parkedLocation = ParkedCarLocation.fromJson(
              Map<String, dynamic>.from(p['parkedLocation'] as Map),
            );
          } catch (_) { /* Skip damaged parking record */ }
        }
        for (final name in (p['muted'] as List? ?? [])) {
          for (final type in ReportType.values) {
            if (type.name == name) muted.add(type);
          }
        }
      }
    } catch (_) {
      notice = tr('Some saved data could not be loaded.', 'تعذر تحميل بعض البيانات المحفوظة.');
    }
    _expiry = Timer.periodic(const Duration(minutes: 1), (_) {
      localReports.removeWhere((r) => !r.isActive);
      _emit();
    });
    _serverIncidentsTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      unawaited(fetchServerIncidents());
    });
    _updateCheckTimer = Timer.periodic(const Duration(minutes: 2), (_) {
      unawaited(checkForUpdates());
    });
    unawaited(fetchServerIncidents());
    unawaited(checkForUpdates());
    unawaited(locate());
  }

  List<T> _decodeList<T>(Object? value, T Function(Map<String, dynamic>) decode) {
    final result = <T>[];
    if (value is List) {
      for (final item in value) {
        try { result.add(decode(Map<String, dynamic>.from(item as Map))); } catch (_) { /* Skip damaged record. */ }
      }
    }
    return result;
  }

  void _emit() { if (!_disposed) notifyListeners(); }
  void clearMessage() { error = null; notice = null; _emit(); }
  Future<void> _save() {
    final data = jsonEncode({
      'arabic': arabic, 'dark': dark, 'satellite': satellite, 'miles': miles, 'voice': voice,
      'lessChatty': lessChatty, 'homeId': homeId, 'workId': workId,
      'saved': saved.map((p) => p.toJson()).toList(),
      'recent': recent.take(10).map((p) => p.toJson()).toList(),
      'plans': plans.map((p) => p.toJson()).toList(),
      'reports': localReports.where((r) => r.isActive).map((p) => p.toJson()).toList(),
      'muted': muted.map((t) => t.name).toList(),
      'parkedLocation': parkedLocation?.toJson(),
    });
    _saveQueue = _saveQueue.then((_) async {
      try { await _prefs?.setString('darb.preferences.v1', data); }
      catch (_) { notice = tr('Could not save on this device.', 'تعذر الحفظ على هذا الجهاز.'); _emit(); }
    });
    return _saveQueue;
  }

  void setLanguage(bool value) { arabic = value; _spokenStep = -1; _spokenManeuverSignatures.clear(); _lastSpokenPhrase = null; _save(); _emit(); }
  void setDark(bool value) { dark = value; _save(); _emit(); }
  void setSatellite(bool value) { if (value == satellite) return; satellite = value; _save(); _emit(); }
  void setMiles(bool value) { miles = value; _save(); _emit(); }
  void setVoice(bool value) { voice = value; if (!value) _tts?.stop(); _save(); _emit(); }
  void setLessChatty(bool value) { lessChatty = value; _save(); _emit(); }
  void setAlert(ReportType type, bool value) { value ? muted.remove(type) : muted.add(type); _save(); _emit(); }

  void setDemoMode(bool value) {
    if (value == demoMode) return;
    stopNavigation();
    _routeRequest++;
    _searchRequest++;
    destination = null; stop = null; routes = []; searchResults = [];
    busy = false; searching = false; error = null; notice = null;
    demoMode = value;
    if (value) {
      _gps?.cancel(); _gps = null; gpsReady = false;
      position = baghdadCenter;
      if (sharing) setSharing(false);
    }
    _emit();
  }

  void filterSamples(String query, {PlaceCategory? category}) {
    final q = query.trim().toLowerCase();
    final list = demoPlaces.where((p) =>
      (category == null || p.category == category) &&
      (q.isEmpty || '${p.name} ${p.nameAr} ${p.subtitle}'.toLowerCase().contains(q))).toList();
    const dist = Distance();
    list.sort((a, b) => dist.as(LengthUnit.Meter, position, a.point).compareTo(dist.as(LengthUnit.Meter, position, b.point)));
    searchResults = list;
    _emit();
  }

  Future<void> searchPlaces(String query) async {
    if (demoMode) { filterSamples(query); return; }
    final ticket = ++_searchRequest;
    if (query.trim().length < 2) { searchResults = []; searching = false; _emit(); return; }
    searching = true; error = null; _emit();
    try {
      final found = await _search.search(query, near: position);
      if (ticket != _searchRequest || _disposed) return;
      final sortedFound = List<Place>.from(found);
      const dist = Distance();
      sortedFound.sort((a, b) => dist.as(LengthUnit.Meter, position, a.point).compareTo(dist.as(LengthUnit.Meter, position, b.point)));
      searchResults = sortedFound;
      if (sortedFound.isEmpty) notice = tr('No places found. Try another name or hold the map to drop a pin.', 'لا توجد نتائج. جرّب اسماً آخر أو اضغط مطولاً على الخريطة.');
    } catch (e) {
      if (ticket != _searchRequest || _disposed) return;
      error = _message(e);
    } finally {
      if (ticket == _searchRequest && !_disposed) { searching = false; _emit(); }
    }
  }

  Future<List<Place>> searchPlacesDirect(String query) async {
    final clean = query.trim();
    if (clean.isEmpty) return const [];
    const dist = Distance();
    if (demoMode) {
      final q = clean.toLowerCase();
      final localMatches = demoPlaces.where((p) =>
        '${p.name} ${p.nameAr} ${p.subtitle} ${p.subtitleAr}'.toLowerCase().contains(q)).toList();
      if (localMatches.isNotEmpty) {
        localMatches.sort((a, b) => dist.as(LengthUnit.Meter, position, a.point).compareTo(dist.as(LengthUnit.Meter, position, b.point)));
        return localMatches;
      }
    }
    try {
      final results = await _search.search(clean, near: position);
      if (results.isNotEmpty) {
        final sorted = List<Place>.from(results);
        sorted.sort((a, b) => dist.as(LengthUnit.Meter, position, a.point).compareTo(dist.as(LengthUnit.Meter, position, b.point)));
        return sorted;
      }
    } catch (e) {
      debugPrint('Voice search direct error: $e');
    }
    // Fallback to local demo places matching query words
    final words = clean.toLowerCase().split(RegExp(r'\s+'));
    final matches = demoPlaces.where((p) {
      final text = '${p.name} ${p.nameAr} ${p.subtitle} ${p.subtitleAr}'.toLowerCase();
      return words.any((w) => w.length > 2 && text.contains(w));
    }).toList();
    matches.sort((a, b) => dist.as(LengthUnit.Meter, position, a.point).compareTo(dist.as(LengthUnit.Meter, position, b.point)));
    return matches;
  }

  Future<void> executeVoiceCommand(VoiceCommandResult result) async {
    switch (result.intent) {
      case VoiceIntentType.cancelNavigation:
        stopNavigation();
        clearRoute();
        _speak(arabic ? 'تم إلغاء الملاحة' : 'Navigation cancelled');
        break;
      case VoiceIntentType.muteSound:
        voice = false;
        _save();
        _emit();
        break;
      case VoiceIntentType.unmuteSound:
        voice = true;
        _save();
        _emit();
        _speak(arabic ? 'تم تفعيل التوجيه الصوتي' : 'Voice guidance enabled');
        break;
      case VoiceIntentType.reportHazard:
        if (result.hazardType != null) {
          final type = _parseHazardType(result.hazardType!);
          await addReport(type, arabic ? 'بلاغ صوتي مباشر' : 'Voice report');
          _speak(arabic ? 'تم تسجيل البلاغ بنجاح' : 'Report submitted');
        }
        break;
      case VoiceIntentType.navigate:
      case VoiceIntentType.unknown:
        break;
    }
  }

  ReportType _parseHazardType(String hazard) {
    switch (hazard) {
      case 'crash':
        return ReportType.crash;
      case 'bump':
        return ReportType.bump;
      case 'police':
        return ReportType.police;
      default:
        return ReportType.hazard;
    }
  }

  Future<void> navigateToPlaceFromVoice(Place place) async {
    final placeName = arabic ? place.nameAr : place.name;
    _speak(arabic ? 'جارٍ التوجيه إلى $placeName' : 'Navigating to $placeName');
    await chooseDestination(place);
    if (routes.isNotEmpty) {
      await startNavigation();
    }
  }

  Future<void> chooseDestination(Place place, {bool asStop = false}) async {
    if (navigating) stopNavigation();
    if (asStop && destination != null) { stop = place; }
    else { destination = place; stop = null; }
    arrived = false; progress = null; error = null;
    recent.removeWhere((p) => p.id == place.id);
    recent.insert(0, place); recent = recent.take(10).toList(); _save();
    await refreshRoutes();
    if (activeLiveRoom != null && activeLiveRoom!.creatorId == _sessionId && !asStop) {
      setLiveRoomDestination(place);
    }
  }

  Future<void> setLiveRoomDestination(Place dest) async {
    final room = activeLiveRoom;
    if (room == null) return;
    try {
      final updated = await _api.setLiveRoomDestination(
        code: room.code,
        requesterId: _sessionId,
        destinationName: dest.label(arabic),
        destinationPoint: dest.point,
      );
      if (updated != null) {
        activeLiveRoom = updated;
        _emit();
      }
    } catch (_) {}
  }

  void saveParkingLocation({LatLng? point, String? note}) {
    parkedLocation = ParkedCarLocation(
      point: point ?? position,
      savedAt: DateTime.now(),
      note: (note != null && note.trim().isNotEmpty) ? note.trim() : null,
    );
    showParkingPrompt = false;
    notice = tr('Parking location saved.', 'تم حفظ موقع وقوف السيارة.');
    _speak(tr('Parking location saved.', 'تم حفظ موقع سيارتك.'));
    _save();
    _emit();
  }

  void clearParkingLocation() {
    parkedLocation = null;
    showParkingPrompt = false;
    notice = tr('Parking location cleared.', 'تم مسح موقع وقوف السيارة.');
    _save();
    _emit();
  }

  void dismissParkingPrompt() {
    showParkingPrompt = false;
    _emit();
  }

  Future<void> navigateToParkedCar() async {
    if (parkedLocation == null) return;
    showParkingPrompt = false;
    final noteText = parkedLocation!.note;
    final target = Place(
      id: 'parked_car_${parkedLocation!.savedAt.millisecondsSinceEpoch}',
      name: 'My Parked Car',
      nameAr: 'موقع سيارتي',
      category: PlaceCategory.parking,
      point: parkedLocation!.point,
      subtitle: (noteText != null && noteText.isNotEmpty) ? noteText : 'Saved parking spot',
      subtitleAr: (noteText != null && noteText.isNotEmpty) ? noteText : 'موقع السيارة المحفوظ',
    );
    await chooseDestination(target);
  }

  Future<void> removeStop() async { stop = null; await refreshRoutes(); }
  Future<void> refreshRoutes({bool rerouting = false, double? bearing}) async {
    if (destination == null) return;
    final ticket = ++_routeRequest;
    final target = destination!;
    busy = true; error = null;
    if (!rerouting) { routes = []; routeIndex = 0; }
    _emit();
    try {
      List<DriveRoute>? apiRoutes;
      if (!demoMode && stop == null) {
        apiRoutes = await _api.fetchRoutes(
          position,
          target.point,
          alternatives: true,
          bearing: bearing,
        );
      }
      final found = demoMode
          ? demoRoutes(target, stop: stop)
          : (apiRoutes != null && apiRoutes.isNotEmpty)
              ? apiRoutes
              : await _routing.routes(
                  position,
                  target,
                  stop: stop,
                  bearing: bearing,
                );
      if (ticket != _routeRequest || _disposed) return;
      routes = calculateTrafficAndRankRoutes(found, reports);
      routeIndex = 0;
      progress = null;
      _spokenStep = -1;
      if (rerouting) {
        if (routes.length > 1) {
          notice = tr(
            'Route updated. Alternative route available.',
            'تم تحديث المسار. يتوفر مسار بديل.',
          );
        } else {
          notice = tr('Route updated.', 'تم تحديث المسار.');
        }
      } else if (routes.isNotEmpty && routes.first.hasTraffic) {
        final totalStr = duration(routes.first.totalDurationSeconds);
        final delayStr = duration(routes.first.trafficDelaySeconds);
        notice = tr(
          'Total travel time: $totalStr (includes +$delayStr traffic delay).',
          'الوقت الإجمالي للرحلة: $totalStr (شامل تأخير الازدحام +$delayStr).',
        );
      }
    } catch (e) {
      if (ticket != _routeRequest || _disposed) return;
      error = _message(e);
    } finally {
      if (ticket == _routeRequest && !_disposed) { busy = false; _emit(); }
    }
  }

  String _message(Object e) {
    if (e is ProviderException) return e.label(arabic);
    return tr('This action could not be completed. Check your connection and try again.',
      'تعذر إكمال العملية. تحقق من اتصالك وحاول مرة أخرى.');
  }

  void selectRoute(int index) {
    if (index < 0 || index >= routes.length) return;
    routeIndex = index;
    if (navigating && route != null) {
      progress = calculateProgress(
        route!,
        position,
        heading: heading.isFinite && heading >= 0 ? heading : null,
      );
      _spokenStep = -1;
      _speak(tr('Switched to alternative route.', 'تم التبديل إلى المسار البديل.'));
      notice = tr('Switched to alternative route.', 'تم التبديل إلى المسار البديل.');
    } else {
      progress = null;
    }
    _emit();
  }
  void clearRoute() {
    stopNavigation(); _routeRequest++; busy = false; destination = null; stop = null;
    routes = []; progress = null; arrived = false; error = null; _emit();
  }

  Future<bool> locate() async {
    if (!enableDeviceServices) return false;
    if (demoMode) {
      position = baghdadCenter;
      notice = tr('Demo location: central Baghdad. Switch to live mode to use GPS.',
        'موقع العرض: وسط بغداد. انتقل إلى الوضع المباشر لاستخدام GPS.');
      _emit(); return false;
    }
    locating = true; error = null; _emit();
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        error = tr('Location is turned off. Enable location in your device settings.',
          'خدمة الموقع متوقفة. فعّلها في إعدادات الجهاز.'); return false;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        error = tr('Location permission is needed to start live navigation. Allow it in settings.',
          'إذن الموقع مطلوب لبدء الملاحة المباشرة. اسمح به من الإعدادات.'); return false;
      }
      final fix = await Geolocator.getCurrentPosition(locationSettings:
        const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 20)));
      if (_disposed || demoMode) return false;
      position = LatLng(fix.latitude, fix.longitude);
      final LocationSettings locationSettings;
      if (defaultTargetPlatform == TargetPlatform.android) {
        locationSettings = AndroidSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          distanceFilter: 0,
          forceLocationManager: false,
          intervalDuration: const Duration(seconds: 1),
        );
      } else if (defaultTargetPlatform == TargetPlatform.iOS ||
                 defaultTargetPlatform == TargetPlatform.macOS) {
        locationSettings = AppleSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          activityType: ActivityType.automotiveNavigation,
          distanceFilter: 1,
          pauseLocationUpdatesAutomatically: false,
        );
      } else {
        locationSettings = const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 1,
        );
      }
      _gps = Geolocator.getPositionStream(locationSettings: locationSettings)
        .listen(_onPosition, onError: (Object e) {
          gpsReady = false;
          if (navigating) stopNavigation();
          error = tr('GPS signal lost. Navigation is paused; restore location to continue.',
            'فُقدت إشارة GPS. توقفت الملاحة؛ استعد الموقع للمتابعة.'); _emit();
        });
      return true;
    } catch (_) {
      error = tr('Could not get your location. Check GPS and browser/device permissions.',
        'تعذر تحديد موقعك. تحقق من GPS وأذونات الجهاز أو المتصفح.');
      return false;
    } finally { locating = false; _emit(); }
  }

  Future<void> startNavigation() async {
    if (route == null || navigating) return;
    if (!demoMode) {
      if (!await locate()) return;
      await refreshRoutes();
      if (route == null || error != null || _disposed) return;
    }
    navigating = true; arrived = false; showParkingPrompt = false; _spokenStep = -1; _offRouteSamples = 0;
    _spokenManeuverSignatures.clear();
    _announcedWarningIds.clear();
    _lastSpokenPhrase = null;
    _lastSpokenTimestamp = null;
    progress = null;
    notice = null; // Clean screen for navigation HUD and map view
    if (demoMode) {
      _demoProgress = 0;
      position = route!.points.first;
      _advance();
      _simulation?.cancel();
      _simulation = Timer.periodic(const Duration(milliseconds: 650), (_) {
        final current = route;
        if (current == null || !navigating) return;
        _demoProgress = min(1, _demoProgress + 0.007);
        // Interpolate by geometric segment length rather than vertex count.
        final lengths = <double>[];
        double total = 0;
        for (var i = 1; i < current.points.length; i++) {
          final d = const Distance().as(LengthUnit.Meter, current.points[i - 1], current.points[i]);
          lengths.add(d); total += d;
        }
        var remaining = _demoProgress * total;
        for (var i = 0; i < lengths.length; i++) {
          if (remaining <= lengths[i] || i == lengths.length - 1) {
            final t = lengths[i] == 0 ? 0.0 : (remaining / lengths[i]).clamp(0.0, 1.0);
            final a = current.points[i], b = current.points[i + 1];
            position = LatLng(a.latitude + (b.latitude - a.latitude) * t,
              a.longitude + (b.longitude - a.longitude) * t);
            heading = const Distance().bearing(a, b);
            break;
          }
          remaining -= lengths[i];
        }
        speedKph = 38;
        _advance();
      });
    } else { _advance(); }
    _emit();
  }

  void _onPosition(Position fix) {
    if (_disposed || demoMode) return;
    // Ignore low-quality fixes rather than rerouting from a bad reading.
    if (fix.accuracy > 65) {
      notice = tr('GPS accuracy is low. Waiting for a clearer signal.',
        'دقة GPS منخفضة. بانتظار إشارة أوضح.'); _emit(); return;
    }
    position = LatLng(fix.latitude, fix.longitude);
    speedKph = fix.speed.isFinite && fix.speed >= 0 ? fix.speed * 3.6 : 0;
    if (fix.heading.isFinite && fix.heading > 0) {
      if (speedKph >= 2.5 || heading == 0) {
        heading = fix.heading;
      }
    }
    gpsReady = true;

    // Send anonymous GPS observation to self-hosted Darb API (throttled to at most once per 2s)
    final now = DateTime.now();
    if (_lastGpsObservationSent == null ||
        now.difference(_lastGpsObservationSent!).inSeconds >= 2) {
      _lastGpsObservationSent = now;
      unawaited(_api.sendObservation(
        point: position,
        speedKmh: speedKph,
        heading: heading,
        sessionId: _sessionId,
        deviceModel: _deviceModel,
        deviceName: _deviceName,
        osVersion: _osVersion,
      ));
    }

    if (navigating) {
      _advance();
    } else {
      _emit();
    }
  }

  void _advance() {
    final current = route;
    if (current == null) return;
    progress = calculateProgress(
      current,
      position,
      previousMeters: progress?.traveledMeters ?? 0,
      heading: heading.isFinite && heading >= 0 ? heading : null,
    );
    final p = progress!;

    // Heading Divergence check: if the car turned into a cross street while moving,
    // do not snap the vehicle to the old road.
    final isHeadingDivergent = heading.isFinite &&
        heading >= 0 &&
        speedKph >= 4 &&
        p.headingDivergence != null &&
        p.headingDivergence! > 50;

    // Street Map-Matching: only snap vehicle if heading aligns with the road and distance is small
    if (!isHeadingDivergent && p.snappedPoint != null && p.distanceFromRouteMeters <= 25) {
      position = p.snappedPoint!;
    }

    // Always orient the vehicle cursor and camera forward ahead along the route:
    if (!isHeadingDivergent && p.segmentBearing != null) {
      heading = p.segmentBearing!;
    }

    if (p.arrived) {
      _simulation?.cancel(); _simulation = null;
      navigating = false; arrived = true; speedKph = 0;
      showParkingPrompt = true;
      _speak(tr('Alhamdulillah for your safety, you have arrived at your destination.', 'الحمد لله على سلامتك'));
      notice = tr(
        'Alhamdulillah for your safety! You have arrived at your destination.',
        'الحمد لله على سلامتك! لقد وصلت إلى وجهتك بنجاح.',
      );
    } else {
      _checkManeuverVoiceGuidance(current, p);

      // Auto-reroute when taking a wrong turn:
      // Require confirmed heading divergence with distance > 25m or major off-route > 50m
      final isOffRoute = (isHeadingDivergent && p.distanceFromRouteMeters > 25) ||
          p.distanceFromRouteMeters > 50;

      if (isOffRoute) {
        _offRouteSamples++;
        final now = DateTime.now();
        final canReroute = !busy &&
            (_lastReroute == null || now.difference(_lastReroute!).inSeconds >= 5);
        if ((_offRouteSamples >= 2 || p.distanceFromRouteMeters > 60) && canReroute) {
          _lastReroute = now;
          _offRouteSamples = 0;
          _speak(tr('Rerouting in your direction...', 'جارٍ إعادة التوجيه في اتجاهك...'));
          notice = tr(
            'Wrong turn detected. Calculating route in your direction...',
            'تم رصد تغيير المسار. جارٍ إعادة الحساب في اتجاه سيرك...',
          );
          refreshRoutes(
            rerouting: true,
            bearing: heading.isFinite && heading >= 0 ? heading : null,
          );
        }
      } else {
        _offRouteSamples = 0;
      }
      _checkRouteAlerts(current, p);
    }
    _emit();
  }

  void _checkManeuverVoiceGuidance(DriveRoute currentRoute, NavigationProgress p) {
    if (!voice || currentRoute.steps.isEmpty) return;

    // 1. Initial departure announcement
    if (p.traveledMeters < 35) {
      const departKey = 'depart_start';
      if (!_spokenManeuverSignatures.contains(departKey)) {
        _spokenManeuverSignatures.add(departKey);
        final firstStep = currentRoute.steps.first;
        if (!lessChatty || !firstStep.type.contains('continue')) {
          _speak(firstStep.label(arabic));
        }
      }
    }

    final stepIdx = p.stepIndex.clamp(0, currentRoute.steps.length - 1);
    final distRemainingOnStep = p.stepRemainingMeters ?? 0.0;

    // 2. Upcoming turn / maneuver guidance in advance of the intersection
    if (stepIdx + 1 < currentRoute.steps.length) {
      final nextStep = currentRoute.steps[stepIdx + 1];
      final currentStepLen = currentRoute.steps[stepIdx].distanceMeters;

      // Far warning (~1 km) for long road stretches
      if (distRemainingOnStep <= 1000 && distRemainingOnStep > 500 && currentStepLen >= 1200) {
        final farKey = '${stepIdx + 1}_far';
        if (!_spokenManeuverSignatures.contains(farKey)) {
          _spokenManeuverSignatures.add(farKey);
          final msg = arabic
              ? 'بعد كيلومتر واحد، ${nextStep.label(true)}'
              : 'In 1 kilometer, ${nextStep.label(false)}';
          _speak(msg);
        }
      }

      // Medium advance warning (250m - 380m) before the turn
      if (distRemainingOnStep <= 350 && distRemainingOnStep > 80) {
        final nearKey = '${stepIdx + 1}_near';
        if (!_spokenManeuverSignatures.contains(nearKey)) {
          _spokenManeuverSignatures.add(nearKey);
          final roundedDist = distRemainingOnStep >= 250 ? 300 : 200;
          final msg = arabic
              ? 'بعد $roundedDist متر، ${nextStep.label(true)}'
              : 'In $roundedDist meters, ${nextStep.label(false)}';
          _speak(msg);
        }
      }

      // Imminent action prompt (45m - 65m) right before the intersection
      if (distRemainingOnStep <= 65 && distRemainingOnStep >= 15) {
        final nowKey = '${stepIdx + 1}_now';
        if (!_spokenManeuverSignatures.contains(nowKey)) {
          _spokenManeuverSignatures.add(nowKey);
          final msg = arabic
              ? '${nextStep.label(true)} الآن'
              : '${nextStep.label(false)} now';
          _speak(msg);
        }
      }
    } else {
      // 3. Destination approach warning
      if (p.remainingMeters <= 350 && p.remainingMeters > 80) {
        const destNearKey = 'dest_near';
        if (!_spokenManeuverSignatures.contains(destNearKey)) {
          _spokenManeuverSignatures.add(destNearKey);
          _speak(arabic ? 'الوجهة بعد 300 متر' : 'Destination ahead in 300 meters');
        }
      } else if (p.remainingMeters <= 65 && p.remainingMeters >= 20) {
        const destNowKey = 'dest_now';
        if (!_spokenManeuverSignatures.contains(destNowKey)) {
          _spokenManeuverSignatures.add(destNowKey);
          _speak(arabic ? 'اقتربت من وجهتك' : 'Approaching destination');
        }
      }
    }
  }

  void _checkRouteAlerts(DriveRoute currentRoute, NavigationProgress p) {
    if (!voice) return;
    const alertDistanceMeters = 350.0;
    const distCalc = Distance();

    for (final rep in reports) {
      if (!rep.isActive) continue;
      // Alert for bumps, road warnings, hazards, cameras, and crashes ahead
      if (rep.type != ReportType.bump &&
          !rep.isRoadWarning &&
          rep.type != ReportType.hazard &&
          rep.type != ReportType.camera &&
          rep.type != ReportType.crash) {
        continue;
      }

      final metersAway = distCalc.as(LengthUnit.Meter, position, rep.point);
      if (metersAway > alertDistanceMeters || metersAway < 25) continue;

      // Heading orientation filter: report must be ahead in the direction of vehicle travel
      if (heading.isFinite && heading >= 0) {
        final bearingToReport = distCalc.bearing(position, rep.point);
        final headingDiff = ((bearingToReport - heading + 180) % 360 - 180).abs();
        if (headingDiff > 75) {
          // Object is behind the vehicle or on a perpendicular cross street
          continue;
        }
      }

      final alertKey = '${rep.id}_${rep.type.name}';
      if (!_announcedWarningIds.contains(alertKey)) {
        _announcedWarningIds.add(alertKey);
        String warningMsg;
        if (rep.type == ReportType.bump || rep.isRoadWarning) {
          final roundedMeters = metersAway >= 200 ? 250 : 150;
          warningMsg = arabic
              ? 'انتبه: مطب اصطناعي بعد $roundedMeters متر'
              : 'Caution: Speed bump in $roundedMeters meters';

          // Ask driver if bump is still there
          if (pendingPromptReport == null && !_promptedIncidentIds.contains(rep.id)) {
            pendingPromptReport = rep;
          }
        } else if (rep.type == ReportType.camera) {
          warningMsg = arabic
              ? 'انتبه: رادار مراقبة سرعة أمامك'
              : 'Caution: Speed camera ahead';
        } else if (rep.type == ReportType.crash) {
          warningMsg = arabic
              ? 'انتبه: حادث سير أمامك'
              : 'Caution: Traffic accident ahead';
        } else {
          warningMsg = arabic
              ? 'انتبه: خطر على الطريق أمامك'
              : 'Caution: Road hazard ahead';
        }
        _speak(warningMsg);
        notice = '⚠️ $warningMsg';
      }
    }
  }

  Future<void> checkForUpdates() async {
    try {
      final info = await _api.checkAppVersion();
      if (info != null) {
        final serverCode = (info['versionCode'] as num?)?.toInt() ?? 0;
        final dismissedCode = _prefs?.getInt('darb.dismissed_update_version.v1') ?? 0;
        if (serverCode > localAppVersionCode && serverCode > dismissedCode) {
          updateAvailableInfo = info;
          _emit();
        }
      }
    } catch (_) {}
  }

  void dismissUpdate({bool remember = true}) {
    if (updateAvailableInfo != null && remember) {
      final serverCode = (updateAvailableInfo!['versionCode'] as num?)?.toInt() ?? 0;
      if (serverCode > 0) {
        _prefs?.setInt('darb.dismissed_update_version.v1', serverCode);
      }
    }
    updateAvailableInfo = null;
    _emit();
  }

  Future<void> onUpdateDownloaded() async {
    dismissUpdate(remember: true);
    notice = arabic
        ? 'تم بدء تحميل النسخة المحدثة. يرجى تثبيتها بعد انتهاء التحميل.'
        : 'Update download started. Please install it once complete.';
    _emit();
  }

  void dismissPromptReport() {
    if (pendingPromptReport != null) {
      _promptedIncidentIds.add(pendingPromptReport!.id);
    }
    pendingPromptReport = null;
    _emit();
  }

  Future<void> confirmPromptReport() async {
    if (pendingPromptReport == null) return;
    final rep = pendingPromptReport!;
    _promptedIncidentIds.add(rep.id);
    pendingPromptReport = null;
    await confirmReport(rep);
    notice = arabic
        ? 'شكراً لك! تم تأكيد المطب وبقاؤه على الخريطة.'
        : 'Thank you! Speed bump confirmed and will stay active.';
    _emit();
  }

  Future<void> rejectPromptReport() async {
    if (pendingPromptReport == null) return;
    final rep = pendingPromptReport!;
    _promptedIncidentIds.add(rep.id);
    pendingPromptReport = null;
    unawaited(_api.rejectIncident(rep.id, userId: _sessionId));
    notice = arabic
        ? 'شكراً لك على تحديث حالة الطريق.'
        : 'Thank you for updating road conditions.';
    _emit();
  }

  Future<void> testVoice() async {
    voice = true;
    final testMsg = arabic
        ? 'مرحباً بك في درب، نظام التوجيه الصوتي يعمل بنجاح.'
        : 'Welcome to Darb, voice guidance is working successfully.';
    await _speak(testMsg, force: true);
    notice = arabic ? '🔊 تم تشغيل الصوت التجريبي' : '🔊 Playing test voice';
    _emit();
  }

  Future<void> _speak(String text, {bool force = false}) async {
    if (!voice || !enableDeviceServices || text.trim().isEmpty) return;
    final now = DateTime.now();
    // Do not repeat identical phrase within 15 seconds unless forced
    if (!force && _lastSpokenPhrase == text) {
      if (_lastSpokenTimestamp != null &&
          now.difference(_lastSpokenTimestamp!).inSeconds < 15) {
        return;
      }
    }
    _lastSpokenPhrase = text;
    _lastSpokenTimestamp = now;

    try {
      if (_tts == null) {
        _tts = FlutterTts();
        await _tts!.setVolume(1.0);
        await _tts!.setSpeechRate(0.53);
        await _tts!.setPitch(1.0);
        await _tts!.awaitSpeakCompletion(false);
      }

      if (_ttsLanguageConfiguredForArabic != arabic) {
        if (arabic) {
          var langSet = false;
          for (final lang in const ['ar-SA', 'ar', 'ar-EG', 'ar-XA']) {
            try {
              final avail = await _tts!.isLanguageAvailable(lang);
              if (avail == 1 || avail == true) {
                await _tts!.setLanguage(lang);
                langSet = true;
                break;
              }
            } catch (_) {}
          }
          if (!langSet) {
            try { await _tts!.setLanguage('ar'); } catch (_) {}
          }
        } else {
          await _tts!.setLanguage('en-US');
        }
        _ttsLanguageConfiguredForArabic = arabic;
      }

      await _tts!.speak(text);
    } catch (_) {
      notice = tr('Voice is unavailable on this device; visual directions remain available.',
        'الصوت غير متاح على هذا الجهاز؛ الإرشادات المرئية متاحة.'); _emit();
    }
  }

  void stopNavigation() {
    _simulation?.cancel(); _simulation = null; _tts?.stop();
    _spokenManeuverSignatures.clear();
    _lastSpokenPhrase = null;
    _lastSpokenTimestamp = null;
    _spokenStep = -1;
    _offRouteSamples = 0;
    navigating = false; speedKph = 0; _emit();
  }

  bool isSaved(Place p) => saved.any((s) => s.id == p.id);
  void toggleSaved(Place p) {
    if (isSaved(p)) {
      saved.removeWhere((s) => s.id == p.id);
      if (homeId == p.id) homeId = null;
      if (workId == p.id) workId = null;
    } else { saved.add(p); }
    _save(); _emit();
  }

  void savePlace(Place p) {
    saved.removeWhere((s) => s.id == p.id);
    saved.insert(0, p);
    _save(); _emit();
  }

  void removeSaved(String id) {
    saved.removeWhere((s) => s.id == id);
    if (homeId == id) homeId = null;
    if (workId == id) workId = null;
    _save(); _emit();
  }

  void setHome(Place p) {
    savePlace(p);
    homeId = p.id;
    _save(); _emit();
  }

  void setWork(Place p) {
    savePlace(p);
    workId = p.id;
    _save(); _emit();
  }

  void setFavoriteRole(Place p, bool home) {
    if (!isSaved(p)) saved.add(p);
    if (home) { homeId = p.id; } else { workId = p.id; }
    _save(); _emit();
  }
  Place? get home => saved.where((p) => p.id == homeId).firstOrNull;
  Place? get work => saved.where((p) => p.id == workId).firstOrNull;

  void planDrive(Place place, DateTime arrival) {
    if (!arrival.isAfter(DateTime.now())) {
      error = tr('Choose an arrival time in the future.', 'اختر موعد وصول في المستقبل.'); _emit(); return;
    }
    plans.add(PlannedDrive(id: _id('trip'), destination: place, arriveAt: arrival));
    plans.sort((a, b) => a.arriveAt.compareTo(b.arriveAt)); _save(); _emit();
  }
  void removePlan(String id) { plans.removeWhere((p) => p.id == id); _save(); _emit(); }

  Future<void> addReport(ReportType type, String description) async {
    if (!demoMode && !gpsReady) {
      if (!await locate()) return;
    }
    final now = DateTime.now();
    final isBump = type == ReportType.bump;
    final report = RoadReport(
      id: _id('report'),
      type: type,
      point: position,
      createdAt: now,
      expiresAt: now.add(Duration(hours: isBump ? 24 : 1)),
      description: description.trim(),
      demo: demoMode,
      userId: _sessionId,
    );

    if (sharing && !demoMode) {
      unawaited(_api
          .reportIncident(
            report,
            userId: _sessionId,
            deviceModel: _deviceModel,
            deviceName: _deviceName,
          )
          .then((_) {
            unawaited(fetchServerIncidents());
          }));
      try { await _community.submit(report); } catch (_) {}
    } else {
      if (!demoMode) {
        unawaited(_api
            .reportIncident(
              report,
              userId: _sessionId,
              deviceModel: _deviceModel,
              deviceName: _deviceName,
            )
            .then((_) {
              unawaited(fetchServerIncidents());
            }));
      }
    }
    localReports.insert(0, report);
    notice = demoMode
        ? tr('Demo report added.', 'تمت إضافة بلاغ تجريبي.')
        : tr('Report shared with nearby drivers.', 'تمت مشاركة البلاغ مع السائقين القريبين.');
    _save();
    _emit();
  }

  Future<void> confirmReport(RoadReport report) async {
    if (confirmed.contains(report.id)) return;
    confirmed.add(report.id);

    // Update locally in sharedReports or localReports immediately
    final sharedIdx = sharedReports.indexWhere((r) => r.id == report.id);
    if (sharedIdx >= 0) {
      sharedReports[sharedIdx] = sharedReports[sharedIdx].copyWith(
        confirmations: sharedReports[sharedIdx].confirmations + 1,
      );
    }
    final localIdx = localReports.indexWhere((r) => r.id == report.id);
    if (localIdx >= 0) {
      localReports[localIdx] = localReports[localIdx].copyWith(
        confirmations: localReports[localIdx].confirmations + 1,
      );
    }

    if (!demoMode) {
      unawaited(_api.confirmIncident(report.id, userId: _sessionId).then((_) {
        unawaited(fetchServerIncidents());
      }));
    }
    if (sharedReports.any((r) => r.id == report.id) && sharing) {
      try { await _community.confirm(report.id); } catch (_) {}
    }
    notice = tr('Report confirmed (+1).', 'تم تأكيد البلاغ بنجاح (+1).');
    _save();
    _emit();
  }

  /// Fetches live crowdsourced reports from the self-hosted Darb server.
  Future<void> fetchServerIncidents() async {
    if (demoMode) return;
    try {
      final incidents = await _api.fetchIncidents(center: position, radiusDeg: 0.5);
      if (incidents.isNotEmpty) {
        final activeServerReports = incidents.where((r) => r.isActive).toList();
        final localIds = localReports.map((r) => r.id).toSet();
        sharedReports = activeServerReports.where((r) => !localIds.contains(r.id)).toList();

        for (final serverRep in activeServerReports) {
          final lIdx = localReports.indexWhere((r) => r.id == serverRep.id);
          if (lIdx >= 0) {
            localReports[lIdx] = localReports[lIdx].copyWith(
              confirmations: serverRep.confirmations,
              isVerified: serverRep.isVerified,
              isRoadWarning: serverRep.isRoadWarning,
              expiresAt: serverRep.expiresAt,
            );
          }
        }
        _emit();
      }
    } catch (_) {}
  }

  Future<void> setSharing(bool value) async {
    if (!value) {
      sharing = false; sharedReports = [];
      await _reportStream?.cancel(); _reportStream = null;
      await _community.dispose(); _community = CommunityService(); _emit(); return;
    }
    if (demoMode) { error = tr('Switch to live mode before sharing reports.', 'انتقل إلى الوضع المباشر قبل مشاركة البلاغات.'); _emit(); return; }
    if (!backendConfigured) {
      sharing = true;
      notice = tr(
        '100% Free local mode active: reports work with zero API keys or fees.',
        'الوضع المحلي المجاني 100% مفعّل: البلاغات تعمل بدون أي مفتاح API أو رسوم.',
      );
      _emit();
      return;
    }
    try {
      await _community.connect();
      if (_disposed || demoMode) return;
      sharing = true;
      _reportStream = _community.watchReports(position).listen((items) {
        sharedReports = items.where((r) => r.isActive).toList(); _emit();
      }, onError: (Object e) {
        error = tr('Community connection interrupted. Reports may be out of date.',
          'انقطع اتصال المجتمع. قد تكون البلاغات قديمة.'); _emit();
      });
    } catch (_) { error = tr('Could not connect to the community server.', 'تعذر الاتصال بخادم المجتمع.'); }
    _emit();
  }

  Future<void> clearPrivateData() async {
    await setSharing(false);
    await _gps?.cancel(); _gps = null;
    stopNavigation(); gpsReady = false;
    saved.clear(); recent.clear(); plans.clear(); localReports.clear(); confirmed.clear();
    homeId = null; workId = null;
    await _save();
    notice = tr('Local history, places, plans and reports cleared.', 'تم مسح السجل والأماكن والرحلات والبلاغات المحلية.');
    _emit();
  }

  String distance(double meters) {
    if (miles) return (meters / 1609.344).toStringAsFixed(1) + tr(' mi', ' ميل');
    if (meters < 1000) return meters.round().toString() + tr(' m', ' م');
    return (meters / 1000).toStringAsFixed(1) + tr(' km', ' كم');
  }
  String duration(double seconds) {
    final totalMinutes = max(1, (seconds / 60).ceil());
    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;

    if (hours > 0) {
      if (minutes > 0) {
        return arabic ? '$hours س $minutes د' : '${hours}h ${minutes}min';
      } else {
        return arabic ? '$hours س' : '${hours}h';
      }
    } else {
      return arabic ? '$minutes د' : '$minutes min';
    }
  }
  String _id(String prefix) => '$prefix-${DateTime.now().microsecondsSinceEpoch}-${Random().nextInt(99999)}';

  Future<void> setUserDisplayName(String name) async {
    userDisplayName = name.trim();
    await _prefs?.setString('darb.user_display_name.v1', userDisplayName!);
    _emit();
  }

  Future<LiveRoom?> createLiveRoom({
    String? name,
    String mode = 'convoy',
    int durationMinutes = 120,
    String? displayName,
    Place? convoyDestination,
  }) async {
    if (displayName != null && displayName.trim().isNotEmpty) {
      await setUserDisplayName(displayName);
    }
    final creatorName = (userDisplayName != null && userDisplayName!.isNotEmpty)
        ? userDisplayName!
        : (arabic ? 'أنا' : 'Me');
    final targetDest = convoyDestination ?? destination;
    final room = await _api.createLiveRoom(
      name: name,
      mode: mode,
      durationMinutes: durationMinutes,
      creatorId: _sessionId,
      creatorName: creatorName,
      point: position,
      speedKmh: speedKph,
      heading: heading,
      destinationName: targetDest?.label(arabic),
      destinationPoint: targetDest?.point,
    );
    if (room != null) {
      activeLiveRoom = room;
      _startLiveRoomPingTimer();
      if (targetDest != null && destination?.id != targetDest.id) {
        chooseDestination(targetDest);
      }
      _emit();
    }
    return room;
  }

  void _syncRoomDestination(LiveRoom room) {
    if (room.destinationPoint == null) return;
    final destPt = room.destinationPoint!;
    final alreadyMatches = destination != null &&
        (destination!.point.latitude - destPt.latitude).abs() < 0.0001 &&
        (destination!.point.longitude - destPt.longitude).abs() < 0.0001;
    if (!alreadyMatches) {
      chooseDestination(Place(
        id: 'convoy_${room.code}',
        name: room.destinationName?.isNotEmpty == true ? room.destinationName! : 'Convoy Destination',
        nameAr: room.destinationName?.isNotEmpty == true ? room.destinationName! : 'وجهة الشلّة',
        subtitle: 'Live Convoy Destination',
        subtitleAr: 'وجهة الموكب المشتركة',
        point: destPt,
        category: PlaceCategory.landmark,
      ));
    }
  }

  Future<LiveRoom?> joinLiveRoom(String code, {String? displayName}) async {
    if (displayName != null && displayName.trim().isNotEmpty) {
      await setUserDisplayName(displayName);
    }
    final memberName = (userDisplayName != null && userDisplayName!.isNotEmpty)
        ? userDisplayName!
        : (arabic ? 'صديق' : 'Friend');
    final cleanCode = code.trim().toUpperCase();
    final room = await _api.pingLiveRoom(
      code: cleanCode,
      memberId: _sessionId,
      displayName: memberName,
      point: position,
      speedKmh: speedKph,
      heading: heading,
      distanceToDestMeters: progress?.remainingMeters,
      etaSeconds: progress?.remainingSeconds,
    );
    if (room != null && room.isActive && !room.isExpired) {
      activeLiveRoom = room;
      _startLiveRoomPingTimer();
      if (room.destinationPoint != null && room.creatorId != _sessionId) {
        _syncRoomDestination(room);
      }
      _emit();
      return room;
    }
    return null;
  }

  Future<void> leaveLiveRoom() async {
    final room = activeLiveRoom;
    if (room != null) {
      _liveRoomTimer?.cancel();
      _liveRoomTimer = null;
      activeLiveRoom = null;
      _emit();
      await _api.leaveLiveRoom(code: room.code, memberId: _sessionId);
    }
  }

  Future<void> endLiveRoom() async {
    final room = activeLiveRoom;
    if (room != null) {
      _liveRoomTimer?.cancel();
      _liveRoomTimer = null;
      activeLiveRoom = null;
      _emit();
      await _api.endLiveRoom(code: room.code, requesterId: _sessionId);
    }
  }

  void _startLiveRoomPingTimer() {
    _liveRoomTimer?.cancel();
    _liveRoomTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      _pingLiveRoom();
    });
  }

  Future<void> _pingLiveRoom() async {
    final room = activeLiveRoom;
    if (room == null || !room.isActive || room.isExpired) {
      _liveRoomTimer?.cancel();
      _liveRoomTimer = null;
      if (activeLiveRoom != null) {
        activeLiveRoom = null;
        _emit();
      }
      return;
    }

    final updated = await _api.pingLiveRoom(
      code: room.code,
      memberId: _sessionId,
      displayName: userDisplayName,
      point: position,
      speedKmh: speedKph,
      heading: heading,
      distanceToDestMeters: progress?.remainingMeters,
      etaSeconds: progress?.remainingSeconds,
    );

    if (updated != null) {
      if (!updated.isActive || updated.isExpired) {
        _liveRoomTimer?.cancel();
        _liveRoomTimer = null;
        activeLiveRoom = null;
      } else {
        activeLiveRoom = updated;
        if (updated.destinationPoint != null && updated.creatorId != _sessionId) {
          _syncRoomDestination(updated);
        }
      }
      _emit();
    }
  }

  Future<bool> openAndroidAutoSettings() async {
    try {
      const channel = MethodChannel('app.darb.darb/device');
      final res = await channel.invokeMethod<bool>('openAndroidAutoSettings');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  @override
  void dispose() {
    _disposed = true; _routeRequest++; _searchRequest++;
    _liveRoomTimer?.cancel();
    _serverIncidentsTimer?.cancel();
    _updateCheckTimer?.cancel();
    _simulation?.cancel(); _expiry?.cancel(); _gps?.cancel(); _reportStream?.cancel();
    _tts?.stop(); _community.dispose(); _routing.dispose(); _search.dispose();
    _api.dispose();
    super.dispose();
  }
}
