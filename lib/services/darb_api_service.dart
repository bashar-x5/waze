import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import '../domain/models.dart';

/// Client for the self-hosted ASP.NET Core 10 Darb Backend API.
/// Connects to self-hosted Ubuntu Server stack with Zero Paid APIs.
class DarbApiService {
  DarbApiService({
    http.Client? client,
    String? baseUrl,
  })  : _client = client ?? http.Client(),
        _ownsClient = client == null,
        _baseUrl = (baseUrl ??
                const String.fromEnvironment(
                  'DARB_API_URL',
                  defaultValue: 'http://139.185.47.123:5000',
                ))
            .replaceAll(RegExp(r'/+$'), '');

  final http.Client _client;
  final bool _ownsClient;
  final String _baseUrl;
  bool _disposed = false;

  String get baseUrl => _baseUrl;

  /// Ingests anonymous GPS observation for live speed calculation and road aggregation.
  Future<bool> sendObservation({
    required LatLng point,
    required double speedKmh,
    double? heading,
    required String sessionId,
    DateTime? observedAt,
    String? deviceModel,
    String? deviceName,
    String? osVersion,
  }) async {
    if (_disposed) return false;
    final uri = Uri.parse('$_baseUrl/api/traffic/observations');
    try {
      final response = await _client
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'latitude': point.latitude,
              'longitude': point.longitude,
              'speedKmh': speedKmh,
              'heading': heading,
              'observedAt': (observedAt ?? DateTime.now().toUtc()).toIso8601String(),
              'sessionId': sessionId,
              if (deviceModel != null && deviceModel.isNotEmpty) 'deviceModel': deviceModel,
              if (deviceName != null && deviceName.isNotEmpty) 'deviceName': deviceName,
              if (osVersion != null && osVersion.isNotEmpty) 'osVersion': osVersion,
            }),
          )
          .timeout(const Duration(seconds: 5));

      return response.statusCode == 200 || response.statusCode == 202;
    } catch (_) {
      return false;
    }
  }

  /// Fetches active road traffic incidents.
  Future<List<RoadReport>> fetchIncidents({
    LatLng? center,
    double radiusDeg = 0.5,
  }) async {
    if (_disposed) return [];
    var url = '$_baseUrl/api/traffic/incidents';
    if (center != null) {
      final minLon = center.longitude - radiusDeg;
      final maxLon = center.longitude + radiusDeg;
      final minLat = center.latitude - radiusDeg;
      final maxLat = center.latitude + radiusDeg;
      url += '?minLon=$minLon&minLat=$minLat&maxLon=$maxLon&maxLat=$maxLat';
    }

    try {
      final response = await _client
          .get(Uri.parse(url), headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 8));

      if (response.statusCode != 200) return [];
      final list = jsonDecode(utf8.decode(response.bodyBytes)) as List<dynamic>;

      return list.map((item) {
        final m = item as Map<String, dynamic>;
        ReportType type;
        switch (m['type']?.toString().toLowerCase()) {
          case 'police':
            type = ReportType.police;
            break;
          case 'traffic':
            type = ReportType.traffic;
            break;
          case 'closure':
            type = ReportType.closure;
            break;
          case 'hazard':
            type = ReportType.hazard;
            break;
          case 'camera':
            type = ReportType.camera;
            break;
          case 'construction':
            type = ReportType.construction;
            break;
          case 'weather':
            type = ReportType.weather;
            break;
          case 'bump':
            type = ReportType.bump;
            break;
          case 'crash':
          default:
            type = ReportType.crash;
            break;
        }

        final now = DateTime.now();
        final createdAt = DateTime.tryParse(m['createdAt']?.toString() ?? '') ?? now;
        final expiresAt = DateTime.tryParse(m['expiresAt']?.toString() ?? '') ?? now.add(const Duration(hours: 1));

        return RoadReport(
          id: m['id']?.toString() ?? '',
          type: type,
          point: LatLng(
            (m['latitude'] as num).toDouble(),
            (m['longitude'] as num).toDouble(),
          ),
          description: m['description']?.toString() ?? '',
          confirmations: (m['confirmations'] as num?)?.toInt() ?? 1,
          createdAt: createdAt,
          expiresAt: expiresAt,
          userId: m['userId']?.toString(),
          isVerified: m['isVerified'] == true,
          isRoadWarning: m['isRoadWarning'] == true,
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }

  /// Submits a new user incident report to the backend.
  Future<bool> reportIncident(
    RoadReport report, {
    String? userId,
    String? deviceModel,
    String? deviceName,
  }) async {
    if (_disposed) return false;
    final uri = Uri.parse('$_baseUrl/api/traffic/incidents');
    try {
      final response = await _client
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'id': report.id,
              'type': report.type.name,
              'latitude': report.point.latitude,
              'longitude': report.point.longitude,
              'description': report.description,
              'userId': userId ?? report.userId,
              if (deviceModel != null && deviceModel.isNotEmpty) 'deviceModel': deviceModel,
              if (deviceName != null && deviceName.isNotEmpty) 'deviceName': deviceName,
            }),
          )
          .timeout(const Duration(seconds: 8));

      return response.statusCode == 201 || response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Confirms an existing incident report (+1 verification).
  Future<bool> confirmIncident(String incidentId, {String? userId}) async {
    if (_disposed) return false;
    final uri = Uri.parse('$_baseUrl/api/traffic/incidents/$incidentId/confirm');
    try {
      final response = await _client
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'userId': userId}),
          )
          .timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Rejects an incident report (driver says 'Not there / Gone').
  Future<bool> rejectIncident(String incidentId, {String? userId}) async {
    if (_disposed) return false;
    final uri = Uri.parse('$_baseUrl/api/traffic/incidents/$incidentId/reject');
    try {
      final response = await _client
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'userId': userId}),
          )
          .timeout(const Duration(seconds: 5));
      return response.statusCode == 200 || response.statusCode == 202;
    } catch (_) {
      return false;
    }
  }

  /// Checks server for latest released APK version and update notifications.
  Future<Map<String, dynamic>?> checkAppVersion() async {
    if (_disposed) return null;
    final uri = Uri.parse('$_baseUrl/api/app/version');
    try {
      final response = await _client.get(uri).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        return jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
  }

  /// Fetches traffic-aware routes from the self-hosted Darb API.
  Future<List<DriveRoute>?> fetchRoutes(
    LatLng origin,
    LatLng destination, {
    bool alternatives = true,
    double? bearing,
  }) async {
    if (_disposed) return null;
    var url =
        '$_baseUrl/api/route?fromLon=${origin.longitude}&fromLat=${origin.latitude}&toLon=${destination.longitude}&toLat=${destination.latitude}&alternatives=$alternatives';
    if (bearing != null && bearing.isFinite && bearing >= 0) {
      url += '&bearing=${bearing.round()}';
    }
    final uri = Uri.parse(url);

    try {
      final response = await _client
          .get(uri, headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) return null;
      final list = jsonDecode(utf8.decode(response.bodyBytes)) as List<dynamic>;

      return list.map((item) {
        final m = item as Map<String, dynamic>;
        final rawCoords = m['coordinates'] as List<dynamic>? ?? [];
        final points = rawCoords
            .map((c) => LatLng(
                  ((c as List<dynamic>)[1] as num).toDouble(),
                  (c[0] as num).toDouble(),
                ))
            .toList();

        final rawTraffic = m['trafficPoints'] as List<dynamic>? ?? [];
        final trafficPts = rawTraffic
            .map((c) => LatLng(
                  ((c as List<dynamic>)[1] as num).toDouble(),
                  (c[0] as num).toDouble(),
                ))
            .toList();

        final rawSteps = m['steps'] as List<dynamic>? ?? [];
        final steps = rawSteps.map((s) {
          final sm = s as Map<String, dynamic>;
          final turnTypeStr = sm['type']?.toString().toLowerCase() ?? 'straight';

          return RouteStep(
            instruction: sm['instruction']?.toString() ?? '',
            instructionAr: sm['instructionAr']?.toString() ?? '',
            type: turnTypeStr,
            point: LatLng(
              (sm['latitude'] as num).toDouble(),
              (sm['longitude'] as num).toDouble(),
            ),
            distanceMeters: (sm['distanceMeters'] as num).toDouble(),
            roadName: sm['roadName']?.toString() ?? '',
          );
        }).toList();

        return DriveRoute(
          id: m['id']?.toString() ?? 'route_${DateTime.now().millisecondsSinceEpoch}',
          name: m['name']?.toString() ?? 'Baghdad Route',
          nameAr: m['nameAr']?.toString() ?? 'مسار بغداد',
          distanceMeters: (m['distanceMeters'] as num).toDouble(),
          durationSeconds: (m['durationSeconds'] as num).toDouble(),
          trafficDelaySeconds: (m['trafficDelaySeconds'] as num?)?.toDouble() ?? 0,
          trafficPoints: trafficPts,
          points: points,
          steps: steps,
        );
      }).toList();
    } catch (_) {
      return null;
    }
  }

  /// Creates a new live convoy or family tracking room.
  Future<LiveRoom?> createLiveRoom({
    String? name,
    String mode = 'convoy',
    int durationMinutes = 120,
    required String creatorId,
    required String creatorName,
    String? avatarColor,
    required LatLng point,
    double speedKmh = 0.0,
    double? heading,
    int? batteryPercent,
    String? destinationName,
    LatLng? destinationPoint,
  }) async {
    if (_disposed) return null;
    final uri = Uri.parse('$_baseUrl/api/rooms');
    try {
      final response = await _client
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              if (name != null && name.isNotEmpty) 'name': name,
              'mode': mode,
              'durationMinutes': durationMinutes,
              'creatorId': creatorId,
              'creatorName': creatorName,
              if (avatarColor != null) 'avatarColor': avatarColor,
              'latitude': point.latitude,
              'longitude': point.longitude,
              'speedKmh': speedKmh,
              if (heading != null) 'heading': heading,
              if (batteryPercent != null) 'batteryPercent': batteryPercent,
              if (destinationName != null) 'destinationName': destinationName,
              if (destinationPoint != null) ...{
                'destinationLat': destinationPoint.latitude,
                'destinationLon': destinationPoint.longitude,
              },
            }),
          )
          .timeout(const Duration(seconds: 8));

      if (response.statusCode != 200) return null;
      final map = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      return LiveRoom.fromJson(map);
    } catch (_) {
      return null;
    }
  }

  /// Fetches the live room status and active members.
  /// Room code is 6 characters alphanumeric, case-insensitive.
  Future<LiveRoom?> fetchLiveRoom(String code) async {
    if (_disposed) return null;
    final cleanCode = code.trim().toUpperCase();
    if (cleanCode.isEmpty) return null;
    final uri = Uri.parse('$_baseUrl/api/rooms/${Uri.encodeComponent(cleanCode)}');
    try {
      final response = await _client
          .get(uri, headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 6));

      if (response.statusCode != 200) return null;
      final map = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      return LiveRoom.fromJson(map);
    } catch (_) {
      return null;
    }
  }

  /// Updates member position, speed, battery, etc., and receives updated room snapshot.
  Future<LiveRoom?> pingLiveRoom({
    required String code,
    required String memberId,
    String? displayName,
    String? avatarColor,
    required LatLng point,
    double speedKmh = 0.0,
    double? heading,
    int? batteryPercent,
    double? distanceToDestMeters,
    double? etaSeconds,
  }) async {
    if (_disposed) return null;
    final cleanCode = code.trim().toUpperCase();
    final uri = Uri.parse('$_baseUrl/api/rooms/${Uri.encodeComponent(cleanCode)}/ping');
    try {
      final response = await _client
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'memberId': memberId,
              if (displayName != null) 'displayName': displayName,
              if (avatarColor != null) 'avatarColor': avatarColor,
              'latitude': point.latitude,
              'longitude': point.longitude,
              'speedKmh': speedKmh,
              if (heading != null) 'heading': heading,
              if (batteryPercent != null) 'batteryPercent': batteryPercent,
              if (distanceToDestMeters != null) 'distanceToDestMeters': distanceToDestMeters,
              if (etaSeconds != null) 'etaSeconds': etaSeconds,
            }),
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode != 200) return null;
      final map = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      return LiveRoom.fromJson(map);
    } catch (_) {
      return null;
    }
  }

  /// Leaves a live room.
  Future<bool> leaveLiveRoom({
    required String code,
    required String memberId,
  }) async {
    if (_disposed) return false;
    final cleanCode = code.trim().toUpperCase();
    final uri = Uri.parse(
        '$_baseUrl/api/rooms/${Uri.encodeComponent(cleanCode)}/leave?memberId=${Uri.encodeComponent(memberId)}');
    try {
      final response = await _client.post(uri).timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Ends a live room (creator only).
  Future<bool> endLiveRoom({
    required String code,
    required String requesterId,
  }) async {
    if (_disposed) return false;
    final cleanCode = code.trim().toUpperCase();
    final uri = Uri.parse('$_baseUrl/api/rooms/${Uri.encodeComponent(cleanCode)}/end');
    try {
      final response = await _client
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'requesterId': requesterId}),
          )
          .timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Sets or updates the destination for a live room (convoy).
  Future<LiveRoom?> setLiveRoomDestination({
    required String code,
    required String requesterId,
    required String destinationName,
    required LatLng destinationPoint,
  }) async {
    if (_disposed) return null;
    final cleanCode = code.trim().toUpperCase();
    final uri = Uri.parse('$_baseUrl/api/rooms/${Uri.encodeComponent(cleanCode)}/destination');
    try {
      final response = await _client
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'requesterId': requesterId,
              'destinationName': destinationName,
              'destinationLat': destinationPoint.latitude,
              'destinationLon': destinationPoint.longitude,
            }),
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode != 200) return null;
      final map = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      return LiveRoom.fromJson(map);
    } catch (_) {
      return null;
    }
  }

  void dispose() {
    _disposed = true;
    if (_ownsClient) {
      _client.close();
    }
  }
}
