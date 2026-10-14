import 'dart:async';
import 'dart:convert';

import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/models.dart';

/// A readable error that never includes backend keys or request headers.
class CommunityException implements Exception {
  const CommunityException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Optional, explicitly enabled community reports. There is no background GPS
/// upload. Reads use a rounded area center and a server-enforced 30 km radius.
///
/// Authentication stays in memory. Dispose this instance when sharing is disabled
/// and construct a new instance if the user opts in again.
class CommunityService {
  static const _url = String.fromEnvironment('SUPABASE_URL');
  static const _key = String.fromEnvironment('SUPABASE_ANON_KEY');
  static const _pollInterval = Duration(seconds: 30);
  static const _requestTimeout = Duration(seconds: 15);

  SupabaseClient? _client;
  Future<void>? _connecting;
  bool _disposed = false;
  final Set<_ReportWatch> _watches = {};

  bool get configured => _url.trim().isNotEmpty && _key.trim().isNotEmpty;
  bool get connected => !_disposed && _client?.auth.currentUser != null;

  Future<void> connect() {
    if (_disposed) {
      return Future.error(const CommunityException('Community reports are closed.'));
    }
    if (connected) return Future.value();
    return _connecting ??= _connect().whenComplete(() => _connecting = null);
  }

  Future<void> _connect() async {
    if (!configured) {
      throw const CommunityException(
        'Shared reports need a configured server. Your local reports still work.',
      );
    }
    final uri = Uri.tryParse(_url);
    final local = uri != null &&
        {'localhost', '127.0.0.1', '::1', '10.0.2.2'}.contains(uri.host);
    if (uri == null ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        (uri.scheme != 'https' && !(uri.scheme == 'http' && local))) {
      throw const CommunityException('The community server needs a valid HTTPS URL.');
    }
    if (_key.startsWith('sb_secret_') || _isServiceRoleKey(_key)) {
      throw const CommunityException(
        'Use a public anonymous/publishable key, never a service-role secret.',
      );
    }

    final client = SupabaseClient(_url, _key);
    _client = client;
    try {
      await client.auth.signInAnonymously().timeout(_requestTimeout);
      if (_disposed) throw const CommunityException('Community reports are closed.');
      if (client.auth.currentUser == null) {
        throw const CommunityException('The community server did not create a session.');
      }
    } catch (error) {
      if (identical(_client, client)) {
        _client = null;
        await client.dispose();
      }
      throw _readableError(error);
    }
  }

  /// Polls only while listened to. Calling this does not silently connect or sign in.
  /// Cancelling the subscription stops all further area requests.
  Stream<List<RoadReport>> watchReports(LatLng center) {
    if (!connected) {
      return Stream.error(const CommunityException('Enable shared reports first.'));
    }
    if (!_insideIraqBounds(center)) {
      return Stream.error(const CommunityException('Shared reports currently cover Iraq.'));
    }
    // About 1 km precision; the backend receives this area center, not a trace.
    final latitude = (center.latitude * 100).round() / 100;
    final longitude = (center.longitude * 100).round() / 100;
    late final _ReportWatch watch;
    late final StreamController<List<RoadReport>> controller;
    var fetching = false;

    Future<void> refresh() async {
      if (fetching || watch.stopped || _disposed) return;
      fetching = true;
      try {
        final rows = await _requireClient().rpc(
          'darb_nearby_reports',
          params: {'p_latitude': latitude, 'p_longitude': longitude},
        ).timeout(_requestTimeout);
        if (!watch.stopped && !controller.isClosed) {
          final reports = (rows as List)
              .map((row) => _decodeReport(Map<String, dynamic>.from(row as Map)))
              .toList(growable: false);
          controller.add(reports);
        }
      } catch (error) {
        if (!watch.stopped && !controller.isClosed) {
          controller.addError(_readableError(error));
        }
      } finally {
        fetching = false;
      }
    }

    controller = StreamController<List<RoadReport>>(
      onListen: () {
        if (_disposed) {
          controller.addError(const CommunityException('Community reports are closed.'));
          unawaited(controller.close());
          return;
        }
        _watches.add(watch);
        unawaited(refresh());
        watch.timer = Timer.periodic(_pollInterval, (_) => unawaited(refresh()));
      },
      onPause: () => watch.timer?.cancel(),
      onResume: () {
        unawaited(refresh());
        watch.timer = Timer.periodic(_pollInterval, (_) => unawaited(refresh()));
      },
      onCancel: () {
        watch.stopped = true;
        watch.timer?.cancel();
        _watches.remove(watch);
      },
    );
    watch = _ReportWatch(controller);
    return controller.stream;
  }

  Future<void> submit(RoadReport report) async {
    if (report.demo) {
      throw const CommunityException('Demo reports cannot be shared.');
    }
    if (!_insideIraqBounds(report.point)) {
      throw const CommunityException('Shared reports currently cover Iraq.');
    }
    if (report.description.trim().length > 280) {
      throw const CommunityException('Keep report descriptions within 280 characters.');
    }
    try {
      // The server assigns creation/expiry times and ignores client vote counts.
      await _requireClient().rpc('darb_submit_report', params: {
        'p_id': report.id,
        'p_type': report.type.name,
        'p_latitude': report.point.latitude,
        'p_longitude': report.point.longitude,
        'p_description': report.description.trim(),
      }).timeout(_requestTimeout);
    } catch (error) {
      throw _readableError(error);
    }
  }

  Future<void> confirm(String reportId) async {
    try {
      await _requireClient().rpc('darb_confirm_report', params: {
        'p_report_id': reportId,
      }).timeout(_requestTimeout);
    } catch (error) {
      throw _readableError(error);
    }
  }

  SupabaseClient _requireClient() {
    final client = _client;
    if (!connected || client == null) {
      throw const CommunityException('Enable shared reports first.');
    }
    return client;
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    final watches = _watches.toList(growable: false);
    _watches.clear();
    for (final watch in watches) {
      watch.stopped = true;
      watch.timer?.cancel();
      // Do not wait on a paused listener to consume a close event.
      unawaited(watch.controller.close());
    }
    final client = _client;
    _client = null;
    if (client != null) await client.dispose();
  }

  static bool _insideIraqBounds(LatLng point) =>
      point.latitude.isFinite &&
      point.longitude.isFinite &&
      point.latitude >= 29 &&
      point.latitude <= 38 &&
      point.longitude >= 38 &&
      point.longitude <= 49;

  static RoadReport _decodeReport(Map<String, dynamic> row) => RoadReport(
        id: row['id'] as String,
        type: ReportType.values.byName(row['type'] as String),
        point: LatLng(
          (row['latitude'] as num).toDouble(),
          (row['longitude'] as num).toDouble(),
        ),
        createdAt: DateTime.parse(row['created_at'] as String),
        expiresAt: DateTime.parse(row['expires_at'] as String),
        description: (row['description'] as String?) ?? '',
        confirmations: (row['confirmations'] as num?)?.toInt() ?? 0,
      );

  static bool _isServiceRoleKey(String key) {
    try {
      final parts = key.split('.');
      if (parts.length != 3) return false;
      final payload = jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))));
      return payload is Map && payload['role'] == 'service_role';
    } catch (_) {
      return false;
    }
  }

  static CommunityException _readableError(Object error) {
    if (error is CommunityException) return error;
    if (error is TimeoutException) {
      return const CommunityException('The community server timed out. Try again later.');
    }
    if (error is AuthException) {
      return const CommunityException(
        'Could not sign in to community reports. Check anonymous sign-in on your server.',
      );
    }
    if (error is PostgrestException) {
      final message = error.message;
      if (message.contains('DARB_RATE_LIMIT')) {
        return const CommunityException('Too many reports or confirmations. Please wait.');
      }
      if (message.contains('DARB_REPORT_UNAVAILABLE')) {
        return const CommunityException('This report has expired or was removed.');
      }
      if (message.contains('DARB_OWN_REPORT')) {
        return const CommunityException('You cannot confirm your own report.');
      }
      if (message.contains('DARB_INVALID')) {
        return const CommunityException('The server rejected this report. Check its details.');
      }
      if (error.code == 'PGRST202') {
        return const CommunityException('Install the Darb database migration on your server.');
      }
    }
    return const CommunityException('Community reports are unavailable. Local reports still work.');
  }
}

class _ReportWatch {
  _ReportWatch(this.controller);
  final StreamController<List<RoadReport>> controller;
  Timer? timer;
  bool stopped = false;
}