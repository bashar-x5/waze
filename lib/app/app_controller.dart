import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
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
  final String _sessionId = 'darb_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(99999)}';
  DateTime? _lastGpsObservationSent;
  SharedPreferences? _prefs;
  FlutterTts? _tts;
  CommunityService _community = CommunityService();
  StreamSubscription<Position>? _gps;
  StreamSubscription<List<RoadReport>>? _reportStream;
  Timer? _simulation;
  Timer? _expiry;
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
      final raw = _prefs!.getString('darb.preferences.v1');
      if (raw != null) {
        final p = jsonDecode(raw) as Map<String, dynamic>;
        arabic = p['arabic'] == true;
        dark = p['dark'] == true;
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
      'arabic': arabic, 'dark': dark, 'miles': miles, 'voice': voice,
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

  void setLanguage(bool value) { arabic = value; _spokenStep = -1; _save(); _emit(); }
  void setDark(bool value) { dark = value; _save(); _emit(); }
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
    searchResults = demoPlaces.where((p) =>
      (category == null || p.category == category) &&
      (q.isEmpty || '${p.name} ${p.nameAr} ${p.subtitle}'.toLowerCase().contains(q))).toList();
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
      searchResults = found;
      if (found.isEmpty) notice = tr('No places found. Try another name or hold the map to drop a pin.', 'لا توجد نتائج. جرّب اسماً آخر أو اضغط مطولاً على الخريطة.');
    } catch (e) {
      if (ticket != _searchRequest || _disposed) return;
      error = _message(e);
    } finally {
      if (ticket == _searchRequest && !_disposed) { searching = false; _emit(); }
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
        final totalMin = (routes.first.totalDurationSeconds / 60).ceil();
        final delayMin = (routes.first.trafficDelaySeconds / 60).round();
        notice = tr(
          'Total travel time: $totalMin min (includes +$delayMin min traffic delay).',
          'الوقت الإجمالي للرحلة: $totalMin دقيقة (شامل تأخير الازدحام +$delayMin د).',
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
      if (current.steps.isNotEmpty && p.stepIndex != _spokenStep) {
        _spokenStep = p.stepIndex;
        final step = current.steps[p.stepIndex.clamp(0, current.steps.length - 1)];
        if (!lessChatty || !step.type.contains('continue')) _speak(step.label(arabic));
      }

      // Instant auto-reroute when taking a wrong turn:
      // If heading is divergent (>50°) and vehicle moved 15m away, or if general distance > 30m
      final isOffRoute = (isHeadingDivergent && p.distanceFromRouteMeters > 15) ||
          p.distanceFromRouteMeters > 30;

      if (isOffRoute) {
        _offRouteSamples++;
        final now = DateTime.now();
        final canReroute = !busy &&
            (_lastReroute == null || now.difference(_lastReroute!).inSeconds >= 3);
        if ((_offRouteSamples >= 1 || p.distanceFromRouteMeters > 45) && canReroute) {
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
    }
    _emit();
  }

  Future<void> _speak(String text) async {
    if (!voice || !enableDeviceServices) return;
    try {
      _tts ??= FlutterTts();
      await _tts!.setLanguage(arabic ? 'ar' : 'en-US');
      await _tts!.setSpeechRate(0.48);
      await _tts!.speak(text);
    } catch (_) {
      notice = tr('Voice is unavailable on this device; visual directions remain available.',
        'الصوت غير متاح على هذا الجهاز؛ الإرشادات المرئية متاحة.'); _emit();
    }
  }

  void stopNavigation() {
    _simulation?.cancel(); _simulation = null; _tts?.stop();
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
    final report = RoadReport(id: _id('report'), type: type, point: position,
      createdAt: now, expiresAt: now.add(const Duration(hours: 1)),
      description: description.trim(), demo: demoMode);
    if (sharing && !demoMode) {
      unawaited(_api.reportIncident(report));
      try { await _community.submit(report); }
      catch (_) {
        localReports.insert(0, report); _save();
        error = tr('Saved on this device. Publishing failed; this report is not shared.',
          'تم الحفظ على هذا الجهاز. فشل النشر؛ البلاغ غير مشارك.'); _emit(); return;
      }
    } else {
      if (!demoMode) {
        unawaited(_api.reportIncident(report));
      }
      localReports.insert(0, report);
    }
    notice = demoMode ? tr('Demo report added.', 'تمت إضافة بلاغ تجريبي.')
      : sharing ? tr('Report shared with nearby drivers.', 'تمت مشاركة البلاغ مع السائقين القريبين.')
      : tr('Report saved on this device only.', 'تم حفظ البلاغ على هذا الجهاز فقط.');
    _save(); _emit();
  }

  Future<void> confirmReport(RoadReport report) async {
    if (confirmed.contains(report.id)) return;
    if (!demoMode) {
      unawaited(_api.confirmIncident(report.id));
    }
    if (sharedReports.any((r) => r.id == report.id) && sharing) {
      try { await _community.confirm(report.id); }
      catch (_) { error = tr('Could not confirm the report.', 'تعذر تأكيد البلاغ.'); _emit(); return; }
    }
    confirmed.add(report.id); _emit();
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
  String duration(double seconds) => max(1, (seconds / 60).ceil()).toString() + tr(' min', ' د');
  String _id(String prefix) => '$prefix-${DateTime.now().microsecondsSinceEpoch}-${Random().nextInt(99999)}';

  @override
  void dispose() {
    _disposed = true; _routeRequest++; _searchRequest++;
    _simulation?.cancel(); _expiry?.cancel(); _gps?.cancel(); _reportStream?.cancel();
    _tts?.stop(); _community.dispose(); _routing.dispose(); _search.dispose();
    _api.dispose();
    super.dispose();
  }
}
