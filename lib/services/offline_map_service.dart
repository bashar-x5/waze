import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

/// Service that downloads, manages, and serves offline map tiles for Baghdad.
/// Uses MapLibre's built-in OfflineManager for vector tile caching.
class OfflineMapService extends ChangeNotifier {
  OfflineMapService();
  String? _baseDir;
  bool _isDownloading = false;
  double _progress = 0.0;
  int _downloadedCount = 0;
  int _totalCount = 0;
  bool _isOfflineReady = false;
  int _diskBytes = 0;

  bool get isDownloading => _isDownloading;
  double get progress => _progress;
  int get downloadedCount => _downloadedCount;
  int get totalCount => _totalCount;
  bool get isOfflineReady => _isOfflineReady;
  int get diskBytes => _diskBytes;

  String get diskSizeFormatted {
    if (_diskBytes < 1024) return '$_diskBytes B';
    if (_diskBytes < 1024 * 1024) {
      return '${(_diskBytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(_diskBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  // Baghdad Metropolitan Region bounds
  static const double minLat = 33.18;
  static const double maxLat = 33.45;
  static const double minLon = 44.20;
  static const double maxLon = 44.52;

  // Style URL for offline download
  static const String _lightStyleUrl = 'https://tiles.openfreemap.org/styles/bright';

  Future<void> init() async {
    try {
      final docDir = await getApplicationDocumentsDirectory();
      _baseDir = '${docDir.path}/offline_tiles/baghdad';
      await checkStatus();
    } catch (_) {}
  }

  Future<void> checkStatus() async {
    if (_baseDir == null) return;
    // Check if MapLibre offline region exists
    try {
      final regions = await getListOfRegions();
      _isOfflineReady = regions.isNotEmpty;
      // Estimate disk usage from cache
      final cacheDir = Directory(_baseDir!);
      if (await cacheDir.exists()) {
        var bytes = 0;
        await for (final entity in cacheDir.list(recursive: true, followLinks: false)) {
          if (entity is File) {
            bytes += await entity.length();
          }
        }
        _diskBytes = bytes;
      }
    } catch (_) {
      // Fallback: check old raster cache
      final dir = Directory(_baseDir!);
      if (await dir.exists()) {
        var bytes = 0;
        var fileCount = 0;
        await for (final entity in dir.list(recursive: true, followLinks: false)) {
          if (entity is File && entity.path.endsWith('.png')) {
            fileCount++;
            bytes += await entity.length();
          }
        }
        _diskBytes = bytes;
        _isOfflineReady = fileCount >= 50;
      } else {
        _isOfflineReady = false;
        _diskBytes = 0;
      }
    }
    notifyListeners();
  }

  /// Get list of downloaded offline regions
  Future<List<OfflineRegion>> fetchOfflineRegions() async {
    try {
      return await getListOfRegions();
    } catch (_) {
      return [];
    }
  }

  /// Download Baghdad offline map region using MapLibre's offline manager
  Future<void> downloadBaghdadTiles() async {
    if (_isDownloading) return;
    _isDownloading = true;
    _progress = 0.0;
    _downloadedCount = 0;
    _totalCount = 100; // Estimated
    notifyListeners();

    try {
      await downloadOfflineRegion(
        OfflineRegionDefinition(
          bounds: LatLngBounds(
            southwest: const LatLng(minLat, minLon),
            northeast: const LatLng(maxLat, maxLon),
          ),
          mapStyleUrl: _lightStyleUrl,
          minZoom: 10.0,
          maxZoom: 16.0,
        ),
        metadata: {
          'name': 'Baghdad Offline',
          'created': DateTime.now().toIso8601String(),
        },
        onEvent: (DownloadRegionStatus status) {
          if (status is Success) {
            _progress = 1.0;
            _downloadedCount = _totalCount;
            _isDownloading = false;
            _isOfflineReady = true;
            notifyListeners();
          } else if (status is InProgress) {
            _progress = status.progress / 100.0;
            _downloadedCount = (status.progress * _totalCount ~/ 100);
            notifyListeners();
          } else if (status is Error) {
            _isDownloading = false;
            notifyListeners();
          }
        },
      );
    } catch (e) {
      _isDownloading = false;
      notifyListeners();
      debugPrint('Offline download error: $e');
    }
  }

  void cancelDownload() {
    _isDownloading = false;
    notifyListeners();
  }

  Future<void> deleteOfflineMap() async {
    try {
      final regions = await getListOfRegions();
      for (final region in regions) {
        await deleteOfflineRegion(region.id);
      }
    } catch (_) {}
    
    // Also clean legacy raster cache
    if (_baseDir != null) {
      final dir = Directory(_baseDir!);
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
    }
    _isOfflineReady = false;
    _diskBytes = 0;
    _progress = 0.0;
    _downloadedCount = 0;
    notifyListeners();
  }
}
