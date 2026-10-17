import 'dart:math' as math;
import 'dart:math' show Point;
import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:latlong2/latlong.dart' as ll;

import 'package:url_launcher/url_launcher.dart';

import '../app/app_controller.dart';
import '../domain/models.dart';
import '../domain/traffic_engine.dart';
import 'waze_theme.dart';
import 'widgets/waze_bottom_panel.dart';
import 'widgets/waze_nav_hud.dart';
import 'widgets/waze_report_sheet.dart';
import 'widgets/waze_search_modal.dart';
import 'widgets/waze_settings_modal.dart';
import 'widgets/waze_speedometer.dart';
import 'widgets/waze_voice_search_sheet.dart';
import 'widgets/waze_permission_sheet.dart';
import 'widgets/waze_live_room_sheet.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.controller,
    this.renderMapTiles = true,
  });

  final AppController controller;
  final bool renderMapTiles;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  MapLibreMapController? _mapController;
  bool _followUser = true;
  bool _headingUp = true;
  bool _is3D = false;
  bool _wasNavigating = false;
  bool _mapReady = false;
  bool _bottomPanelMinimized = false;
  bool _dismissedRouteSwitch = false;
  bool _dismissedTrafficAlert = false;
  Offset? _puckScreenOffset;

  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();
    _pulseAnimation = CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeOut,
    );

    widget.controller.addListener(_onControllerChange);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        showWazePermissionSheet(context, controller: widget.controller);
      }
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    widget.controller.removeListener(_onControllerChange);
    super.dispose();
  }

  /// Convert latlong2 LatLng to MapLibre LatLng
  LatLng _toMapLibre(ll.LatLng p) => LatLng(p.latitude, p.longitude);

  static const String _satelliteStyleJson = '''
{
  "version": 8,
  "name": "Darb 3D Satellite",
  "glyphs": "https://tiles.openfreemap.org/fonts/{fontstack}/{range}.pbf",
  "sources": {
    "openmaptiles": {
      "type": "vector",
      "url": "https://tiles.openfreemap.org/planet"
    },
    "esri-satellite": {
      "type": "raster",
      "tiles": [
        "https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}"
      ],
      "tileSize": 256,
      "maxzoom": 19,
      "attribution": "Esri World Imagery"
    },
    "esri-transportation": {
      "type": "raster",
      "tiles": [
        "https://services.arcgisonline.com/arcgis/rest/services/Reference/World_Transportation/MapServer/tile/{z}/{y}/{x}"
      ],
      "tileSize": 256,
      "maxzoom": 19
    },
    "esri-labels": {
      "type": "raster",
      "tiles": [
        "https://services.arcgisonline.com/arcgis/rest/services/Reference/World_Boundaries_and_Places/MapServer/tile/{z}/{y}/{x}"
      ],
      "tileSize": 256,
      "maxzoom": 19
    }
  },
  "layers": [
    {
      "id": "background",
      "type": "background",
      "paint": {
        "background-color": "#06090e"
      }
    },
    {
      "id": "satellite-base",
      "type": "raster",
      "source": "esri-satellite",
      "paint": {
        "raster-opacity": 1.0,
        "raster-contrast": 0.05
      }
    },
    {
      "id": "building-3d",
      "type": "fill-extrusion",
      "source": "openmaptiles",
      "source-layer": "building",
      "minzoom": 13,
      "paint": {
        "fill-extrusion-color": [
          "interpolate",
          ["linear"],
          ["coalesce", ["get", "render_height"], ["get", "height"], 12],
          0, "#1e293b",
          25, "#334155",
          50, "#475569",
          100, "#64748b"
        ],
        "fill-extrusion-height": [
          "interpolate",
          ["linear"],
          ["zoom"],
          13, 0,
          14.5, [
            "min",
            ["coalesce", ["get", "render_height"], ["get", "height"], 12],
            65
          ]
        ],
        "fill-extrusion-base": [
          "coalesce",
          ["get", "render_min_height"],
          ["get", "min_height"],
          0
        ],
        "fill-extrusion-opacity": 0.85
      }
    },
    {
      "id": "roads-overlay",
      "type": "raster",
      "source": "esri-transportation",
      "paint": {
        "raster-opacity": 0.85
      }
    },
    {
      "id": "labels-overlay",
      "type": "raster",
      "source": "esri-labels",
      "paint": {
        "raster-opacity": 0.95
      }
    }
  ]
}
''';

  /// Get the style URL or JSON based on dark mode and satellite view
  String _getStyleUrl(bool dark, bool satellite) {
    if (satellite) {
      return _satelliteStyleJson;
    }
    return dark
        ? 'https://tiles.openfreemap.org/styles/dark'
        : 'https://tiles.openfreemap.org/styles/bright';
  }


  void _onControllerChange() {
    if (!mounted || !_mapReady || _mapController == null) return;
    final c = widget.controller;
    final justStarted = !_wasNavigating && c.navigating;
    final justStopped = _wasNavigating && !c.navigating;
    _wasNavigating = c.navigating;

    if (justStarted) {
      _followUser = true;
      _headingUp = true;
      _is3D = true;
      _dismissedRouteSwitch = false;
      _dismissedTrafficAlert = false;
      _animateCamera(
        target: _toMapLibre(c.position),
        zoom: 17.5,
        bearing: _headingUp ? c.heading : 0.0,
        tilt: 60.0,
      );
      _updateMapOverlays();
      return;
    }

    if (justStopped) {
      _is3D = false;
      _dismissedRouteSwitch = false;
      _dismissedTrafficAlert = false;
      _animateCamera(
        target: _toMapLibre(c.position),
        zoom: 16.0,
        bearing: 0.0,
        tilt: 0.0,
      );
      _updateMapOverlays();
      return;
    }

    if (_followUser) {
      _animateCamera(
        target: _toMapLibre(c.position),
        zoom: c.navigating ? 17.5 : 16.0,
        bearing: (_headingUp && c.navigating) ? c.heading : 0.0,
        tilt: _is3D ? 60.0 : 0.0,
      );
    } else {
      _syncPuckScreenPosition();
    }

    // Update route and marker overlays
    _updateMapOverlays();
  }

  Future<void> _syncPuckScreenPosition() async {
    if (_mapController == null || !mounted) return;
    if (_followUser) {
      if (_puckScreenOffset != null) {
        setState(() => _puckScreenOffset = null);
      }
      return;
    }
    try {
      final point = await _mapController!.toScreenLocation(_toMapLibre(widget.controller.position));
      if (mounted) {
        setState(() {
          _puckScreenOffset = Offset(point.x.toDouble(), point.y.toDouble());
        });
      }
    } catch (_) {}
  }

  void _animateCamera({
    required LatLng target,
    double? zoom,
    double? bearing,
    double? tilt,
  }) {
    try {
      _mapController?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: target,
            zoom: zoom ?? 16.0,
            bearing: bearing ?? 0.0,
            tilt: tilt ?? 0.0,
          ),
        ),
        duration: const Duration(milliseconds: 600),
      );
    } catch (_) {}
  }

  void _recenter() {
    final c = widget.controller;
    setState(() {
      _followUser = true;
      _puckScreenOffset = null;
    });
    if (c.navigating) {
      _animateCamera(
        target: _toMapLibre(c.position),
        zoom: 17.5,
        bearing: _headingUp ? c.heading : 0.0,
        tilt: _is3D ? 60.0 : 0.0,
      );
    } else {
      _animateCamera(
        target: _toMapLibre(c.position),
        zoom: 16.0,
        bearing: 0.0,
        tilt: 0.0,
      );
    }
  }

  void _toggleHeadingUp() {
    setState(() => _headingUp = !_headingUp);
    final c = widget.controller;
    final targetBearing = _headingUp ? c.heading : 0.0;
    if (_followUser && c.navigating) {
      _animateCamera(
        target: _toMapLibre(c.position),
        zoom: 17.5,
        bearing: targetBearing,
        tilt: _is3D ? 60.0 : 0.0,
      );
    } else {
      _mapController?.animateCamera(
        CameraUpdate.bearingTo(targetBearing),
      );
    }
  }

  void _toggle3D() {
    setState(() {
      _is3D = !_is3D;
    });
    final c = widget.controller;
    _animateCamera(
      target: _toMapLibre(c.position),
      zoom: _is3D ? 17.5 : 16.0,
      bearing: _headingUp && c.navigating ? c.heading : 0.0,
      tilt: _is3D ? 60.0 : 0.0,
    );
  }

  void _openSearch({bool asStop = false}) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => WazeSearchModal(
        controller: widget.controller,
        asStop: asStop,
      ),
    );
  }

  void _openVoiceSearch() {
    WazeVoiceSearchSheet.show(context, widget.controller);
  }

  void _openSettings() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => WazeSettingsModal(controller: widget.controller),
    );
  }

  void _openReportSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => WazeReportSheet(
        arabic: widget.controller.arabic,
        dark: widget.controller.dark,
        onSubmit: (type, desc) async {
          await widget.controller.addReport(type, desc);
        },
      ),
    );
  }

  void _openLiveRoomSheet() {
    WazeLiveRoomSheet.show(
      context,
      controller: widget.controller,
      onFitTrack: _fitConvoyOverview,
    );
  }

  void _fitRouteBounds([List<ll.LatLng>? customPoints]) {
    final c = widget.controller;
    final List<ll.LatLng> points = customPoints ??
        (c.route?.points.isNotEmpty == true
            ? c.route!.points
            : (c.destination != null ? [c.position, c.destination!.point] : [c.position]));
    if (points.isEmpty || _mapController == null) return;

    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;

    for (final p in points) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }

    if ((maxLat - minLat).abs() < 0.005) {
      minLat -= 0.003;
      maxLat += 0.003;
    }
    if ((maxLng - minLng).abs() < 0.005) {
      minLng -= 0.003;
      maxLng += 0.003;
    }

    try {
      setState(() => _followUser = false);
      _mapController?.animateCamera(
        CameraUpdate.newLatLngBounds(
          LatLngBounds(
            southwest: LatLng(minLat, minLng),
            northeast: LatLng(maxLat, maxLng),
          ),
          left: 60,
          right: 60,
          top: 120,
          bottom: 340,
        ),
      );
    } catch (e) {
      debugPrint('Error fitting route bounds: $e');
    }
  }

  void _fitConvoyOverview() {
    final c = widget.controller;
    final room = c.activeLiveRoom;
    if (room == null || !room.isActive) {
      _fitRouteBounds();
      return;
    }
    final List<ll.LatLng> points = [c.position];
    for (final m in room.members) {
      points.add(m.point);
    }
    if (room.destinationPoint != null) {
      points.add(room.destinationPoint!);
    } else if (c.destination != null) {
      points.add(c.destination!.point);
    }
    _fitRouteBounds(points);
  }


  void _onMapLongPress(Point<double> point, LatLng coordinates) {
    final arabic = widget.controller.arabic;
    final llPoint = ll.LatLng(coordinates.latitude, coordinates.longitude);
    final droppedPlace = Place(
      id: 'dropped-${DateTime.now().millisecondsSinceEpoch}',
      name: arabic ? 'موقع مخصص' : 'Dropped Pin',
      nameAr: 'موقع مخصص',
      subtitle: '${coordinates.latitude.toStringAsFixed(4)}, ${coordinates.longitude.toStringAsFixed(4)}',
      subtitleAr: '${coordinates.latitude.toStringAsFixed(4)}, ${coordinates.longitude.toStringAsFixed(4)}',
      point: llPoint,
    );

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final dark = widget.controller.dark;
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: dark ? WazeColors.darkSurface : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Icon(Icons.pin_drop_rounded, color: WazeColors.red, size: 32),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            droppedPlace.label(arabic),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: dark ? Colors.white : Colors.black87,
                            ),
                          ),
                          Text(
                            droppedPlace.detail(arabic),
                            style: TextStyle(
                              fontSize: 12,
                              color: dark ? Colors.white60 : Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    IconButton.filledTonal(
                      icon: Icon(
                        widget.controller.isSaved(droppedPlace)
                            ? Icons.star_rounded
                            : Icons.star_outline_rounded,
                        color: widget.controller.isSaved(droppedPlace)
                            ? Colors.amber
                            : (dark ? Colors.white70 : Colors.black87),
                      ),
                      tooltip: arabic ? 'حفظ في المفضلة' : 'Save to Favorites',
                      onPressed: () {
                        widget.controller.toggleSaved(droppedPlace);
                        Navigator.of(ctx).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              arabic
                                  ? 'تم حفظ الموقع في المحفوظات'
                                  : 'Saved location to Favorites',
                            ),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: Text(arabic ? 'إلغاء' : 'Cancel'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton(
                        onPressed: () {
                          Navigator.of(ctx).pop();
                          widget.controller.chooseDestination(droppedPlace);
                        },
                        style: FilledButton.styleFrom(backgroundColor: WazeColors.cyan),
                        child: Text(
                          arabic ? 'انطلق إلى هنا' : 'Drive Here',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── MapLibre Route & Marker Overlay Management ──

  Future<void> _onMapCreated(MapLibreMapController controller) async {
    _mapController = controller;
  }

  Future<void> _onStyleLoaded() async {
    _mapReady = true;
    _setup3dBuildings();
    _updateMapOverlays();
  }

  /// Adds realistic 3D building extrusions like Mapbox/Google Maps 3D
  Future<void> _setup3dBuildings() async {
    if (_mapController == null) return;
    try {
      final dark = widget.controller.dark;
      await _mapController!.addFillExtrusionLayer(
        'openmaptiles',
        '3d-buildings',
        FillExtrusionLayerProperties(
          fillExtrusionColor: dark ? '#2A3340' : '#D0D5DD',
          fillExtrusionHeight: [
            'interpolate',
            ['linear'],
            ['zoom'],
            14.0,
            0.0,
            15.5,
            [
              'case',
              ['has', 'render_height'],
              ['get', 'render_height'],
              ['has', 'height'],
              ['get', 'height'],
              ['has', 'render_min_height'],
              ['get', 'render_min_height'],
              18.0,
            ],
          ],
          fillExtrusionBase: [
            'case',
            ['has', 'render_min_height'],
            ['get', 'render_min_height'],
            0.0,
          ],
          fillExtrusionOpacity: 0.88,
          fillExtrusionVerticalGradient: true,
        ),
        sourceLayer: 'building',
        minzoom: 14.0,
      );
    } catch (e) {
      debugPrint('3D building layer setup: $e');
    }
  }

  /// Build GeoJSON for route lines

  Future<void> _updateMapOverlays() async {
    if (!_mapReady || _mapController == null) return;
    final controller = _mapController!;
    final c = widget.controller;

    try {
      await controller.clearLines();
      await controller.clearCircles();

      // Render native user location puck directly on MapLibre OpenGL canvas
      // This guarantees the cursor is permanently anchored to the user's geographic coordinates,
      // sticking to the road even when dragging or rotating the map with fingers!
      await controller.addCircle(
        CircleOptions(
          geometry: _toMapLibre(c.position),
          circleColor: '#00C8F8',
          circleRadius: 18.0,
          circleOpacity: 0.30,
        ),
      );
      await controller.addCircle(
        CircleOptions(
          geometry: _toMapLibre(c.position),
          circleColor: '#FFFFFF',
          circleRadius: 11.0,
          circleStrokeColor: '#007AFF',
          circleStrokeWidth: 3.5,
          circleOpacity: 1.0,
        ),
      );
      await controller.addCircle(
        CircleOptions(
          geometry: _toMapLibre(c.position),
          circleColor: '#007AFF',
          circleRadius: 5.5,
          circleOpacity: 1.0,
        ),
      );

      // Render saved parked car indicator on map
      if (c.parkedLocation != null) {
        await controller.addCircle(
          CircleOptions(
            geometry: _toMapLibre(c.parkedLocation!.point),
            circleColor: '#00C8F8',
            circleRadius: 10.0,
            circleStrokeColor: '#FFFFFF',
            circleStrokeWidth: 3.0,
            circleOpacity: 0.95,
          ),
        );
      }

      // Render active live room members (Convoy & Family Tracking)
      if (c.activeLiveRoom != null && c.activeLiveRoom!.isActive) {
        final destPt = c.activeLiveRoom!.destinationPoint ?? c.destination?.point;
        for (final member in c.activeLiveRoom!.members) {
          if (member.memberId == c.userId) continue;
          final color = member.avatarColor.isNotEmpty ? member.avatarColor : '#00E676';

          // Trajectory track connecting convoy member to shared destination
          if (destPt != null) {
            await controller.addLine(
              LineOptions(
                geometry: [_toMapLibre(member.point), _toMapLibre(destPt)],
                lineColor: color,
                lineWidth: 3.5,
                lineOpacity: 0.65,
                lineJoin: 'round',
              ),
            );
          }

          await controller.addCircle(
            CircleOptions(
              geometry: _toMapLibre(member.point),
              circleColor: color,
              circleRadius: 12.0,
              circleStrokeColor: '#FFFFFF',
              circleStrokeWidth: 2.5,
              circleOpacity: 0.95,
            ),
          );
          await controller.addCircle(
            CircleOptions(
              geometry: _toMapLibre(member.point),
              circleColor: '#FFFFFF',
              circleRadius: 4.5,
              circleOpacity: 1.0,
            ),
          );
        }
      }

      // Render active road reports and verified speed bump warnings on map
      for (final report in c.reports) {
        if (!report.isActive) continue;
        String circleColor = '#FF9500';
        double radius = 8.0;
        double strokeWidth = 2.0;

        if (report.type == ReportType.bump || report.isRoadWarning) {
          circleColor = '#FFD600'; // Amber yellow for speed bump warning
          radius = 10.0;
          strokeWidth = 3.0;
        } else if (report.type == ReportType.police) {
          circleColor = '#00D2FF'; // Blue for police/checkpoint
        } else if (report.type == ReportType.crash || report.type == ReportType.traffic) {
          circleColor = '#FF3B30'; // Red for crash/congestion
        } else if (report.type == ReportType.camera) {
          circleColor = '#7C4DFF'; // Purple for speed camera
        } else if (report.type == ReportType.closure) {
          circleColor = '#FF1744'; // Bright red for road closure
        }

        await controller.addCircle(
          CircleOptions(
            geometry: _toMapLibre(report.point),
            circleColor: circleColor,
            circleRadius: radius,
            circleStrokeColor: '#FFFFFF',
            circleStrokeWidth: strokeWidth,
            circleOpacity: 0.95,
          ),
        );
      }

      if (c.routes.isEmpty) return;

      // 1. Render alternative routes underneath
      for (var i = 0; i < c.routes.length; i++) {
        if (i == c.routeIndex) continue;
        final altRoute = c.routes[i];
        if (altRoute.points.length >= 2) {
          await controller.addLine(
            LineOptions(
              geometry: altRoute.points.map(_toMapLibre).toList(),
              lineColor: '#90A4AE',
              lineWidth: 6.0,
              lineOpacity: 0.7,
              lineJoin: 'round',
            ),
          );
        }
      }

      // 2. Render active route (casing + core glowing line)
      final activeRoute = c.route;
      if (activeRoute != null && activeRoute.points.length >= 2) {
        final activeCoords = activeRoute.points.map(_toMapLibre).toList();

        // High-contrast outer casing (dark blue border)
        await controller.addLine(
          LineOptions(
            geometry: activeCoords,
            lineColor: '#0564A2',
            lineWidth: 10.0,
            lineOpacity: 1.0,
            lineJoin: 'round',
          ),
        );

        // Bright glowing core navigation line (Google/Waze cyan)
        await controller.addLine(
          LineOptions(
            geometry: activeCoords,
            lineColor: '#00C8F8',
            lineWidth: 6.5,
            lineOpacity: 1.0,
            lineJoin: 'round',
          ),
        );

        // 3. Render traffic congestion segments on top
        if (activeRoute.trafficSegments.isNotEmpty) {
          for (final seg in activeRoute.trafficSegments) {
            if (seg.points.length < 2) continue;
            String? hexColor;
            switch (seg.level) {
              case TrafficCongestionLevel.standstill:
                hexColor = '#8B0000'; // Dark burgundy
                break;
              case TrafficCongestionLevel.heavy:
                hexColor = '#FF3B30'; // Bright red
                break;
              case TrafficCongestionLevel.moderate:
                hexColor = '#FF9500'; // Amber
                break;
              case TrafficCongestionLevel.free:
                hexColor = null;
                break;
            }
            if (hexColor != null) {
              await controller.addLine(
                LineOptions(
                  geometry: seg.points.map(_toMapLibre).toList(),
                  lineColor: hexColor,
                  lineWidth: 7.5,
                  lineOpacity: 1.0,
                  lineJoin: 'round',
                ),
              );
            }
          }
        } else if (activeRoute.trafficPoints.isNotEmpty && activeRoute.trafficPoints.length >= 2) {
          await controller.addLine(
            LineOptions(
              geometry: activeRoute.trafficPoints.map(_toMapLibre).toList(),
              lineColor: '#FF3B30',
              lineWidth: 7.5,
              lineOpacity: 1.0,
              lineJoin: 'round',
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error drawing route lines: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final dark = c.dark;
    final arabic = c.arabic;
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    return Scaffold(
      body: Stack(
        children: [
          // MapLibre GL Map with Vector Tiles (Full Bleed Native OpenGL 3D)
          Positioned.fill(
            child: widget.renderMapTiles
                ? _buildMapWidget(c, dark)
                : Container(
                    color: dark ? const Color(0xFF1B232D) : const Color(0xFFE8EEF3),
                  ),
          ),

          // Car Puck Widget Overlay (sticks to user location whether following or panning)
          _buildPositionedCarPuck(c),

          // Top Nav HUD (Visible when navigating)
          if (c.navigating && c.route != null && c.progress != null)
            Positioned(
              top: isLandscape ? 8 : 0,
              left: isLandscape ? (arabic ? null : 12) : 0,
              right: isLandscape ? (arabic ? 12 : null) : 0,
              width: isLandscape ? 360 : null,
              child: WazeNavHud(
                route: c.route!,
                progress: c.progress!,
                arabic: arabic,
                miles: c.miles,
                isLandscape: isLandscape,
                onTapList: () {
                  showWazeTurnsSheet(
                    context,
                    route: c.route!,
                    progress: c.progress!,
                    arabic: arabic,
                    miles: c.miles,
                    dark: dark,
                  );
                },
              ),
            ),

          // Upcoming Traffic Bottleneck Alert Pill (Waze Traffic Bar)
          if (c.navigating && c.route != null && !_dismissedTrafficAlert) ...[
            if (detectUpcomingTrafficJam(c.route!, c.position) case final alert?)
              Positioned(
                top: isLandscape ? 66 : 156,
                left: isLandscape ? (arabic ? null : 12) : 16,
                right: isLandscape ? (arabic ? 12 : null) : 76,
                width: isLandscape ? 360 : null,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: alert.level == TrafficCongestionLevel.standstill
                        ? const Color(0xFF7F1D1D)
                        : (alert.level == TrafficCongestionLevel.heavy
                            ? const Color(0xFFDC2626)
                            : const Color(0xFFD97706)),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.25),
                      width: 1,
                    ),
                    boxShadow: const [
                      BoxShadow(color: Colors.black45, blurRadius: 8, offset: Offset(0, 3)),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Icon(
                            alert.causeType == ReportType.police
                                ? Icons.local_police_rounded
                                : (alert.causeType == ReportType.crash
                                    ? Icons.car_crash_rounded
                                    : (alert.causeType == ReportType.construction
                                        ? Icons.construction_rounded
                                        : (alert.causeType == ReportType.closure
                                            ? Icons.do_not_disturb_on_rounded
                                            : Icons.traffic_rounded))),
                            color: Colors.white,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              arabic ? alert.titleAr : alert.title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.35),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              c.distance(alert.distanceMeters),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          // Close button to dismiss traffic alert
                          InkWell(
                            onTap: () => setState(() => _dismissedTrafficAlert = true),
                            borderRadius: BorderRadius.circular(12),
                            child: const Padding(
                              padding: EdgeInsets.all(3),
                              child: Icon(Icons.close_rounded, color: Colors.white70, size: 16),
                            ),
                          ),
                        ],
                      ),
                      if (c.routes.length > 1) ...[
                        const SizedBox(height: 5),
                        InkWell(
                          onTap: () {
                            final nextIndex = (c.routeIndex + 1) % c.routes.length;
                            c.selectRoute(nextIndex);
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.22),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.alt_route_rounded, color: Colors.white, size: 14),
                                const SizedBox(width: 6),
                                Text(
                                  arabic ? 'تحويل لمسار بديل أسرع' : 'Switch to faster alternate route',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
          ],

          // Alternative Route Prompt Banner during navigation
          if (c.navigating && c.routes.length > 1 && c.route != null && !_dismissedRouteSwitch) ...[
            Builder(builder: (context) {
              final otherIdx = c.routeIndex == 0 ? 1 : 0;
              final otherRoute = c.routes[otherIdx];
              final diffSec = (otherRoute.totalDurationSeconds - c.route!.totalDurationSeconds).round();

              // ONLY show if the alternative route is FASTER by at least 60 seconds!
              // Never display a disruptive banner for routes with equal ETA or slower!
              if (diffSec >= -60) return const SizedBox.shrink();

              final label = arabic
                  ? 'مسار أسرع يوفر ${c.duration(diffSec.abs().toDouble())}'
                  : 'Faster route saves ${c.duration(diffSec.abs().toDouble())}';

              return Positioned(
                top: isLandscape ? 66 : 156,
                left: isLandscape ? (arabic ? null : 12) : 16,
                right: isLandscape ? (arabic ? 12 : null) : 76,
                width: isLandscape ? 360 : null,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D47A1),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: const [
                      BoxShadow(color: Colors.black45, blurRadius: 6, offset: Offset(0, 3)),
                    ],
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.bolt_rounded,
                        color: Colors.amber,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          label,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: WazeColors.blue,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                          minimumSize: const Size(0, 26),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () {
                          c.selectRoute(otherIdx);
                          setState(() => _dismissedRouteSwitch = true);
                        },
                        child: Text(
                          arabic ? 'تحويل' : 'Switch',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                        ),
                      ),
                      const SizedBox(width: 4),
                      // Prominent close / exit button
                      InkWell(
                        onTap: () {
                          setState(() => _dismissedRouteSwitch = true);
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: const Padding(
                          padding: EdgeInsets.all(4),
                          child: Icon(Icons.close_rounded, color: Colors.white70, size: 18),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ] else if (!c.navigating && c.routes.length > 1 && c.routeIndex != 0 && c.routes.first.totalDurationSeconds < c.route!.totalDurationSeconds - 60) ...[
            Positioned(
              top: 110,
              left: 16,
              right: 76,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: WazeColors.blue,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [
                    BoxShadow(color: Colors.black38, blurRadius: 6, offset: Offset(0, 3)),
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(Icons.bolt_rounded, color: Colors.amber, size: 22),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        arabic
                            ? 'مسار أسرع يوفر ${c.duration(c.route!.totalDurationSeconds - c.routes.first.totalDurationSeconds)}'
                            : 'Faster route saves ${c.duration(c.route!.totalDurationSeconds - c.routes.first.totalDurationSeconds)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: WazeColors.blue,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        minimumSize: const Size(0, 28),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () => c.selectRoute(0),
                      child: Text(
                        arabic ? 'تحويل' : 'Switch',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],

          // APK Update Available Banner
          if (c.updateAvailableInfo != null)
            Positioned(
              top: c.navigating ? 210 : 54,
              left: 16,
              right: 16,
              child: Material(
                elevation: 10,
                borderRadius: BorderRadius.circular(18),
                color: const Color(0xFF0F172A),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFF00D2FF), width: 1.5),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00D2FF).withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.system_update_rounded, color: Color(0xFF00D2FF), size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              arabic ? '🚀 تحديث جديد متوفر لدرب' : '🚀 New Darb Update Available',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              arabic
                                  ? (c.updateAvailableInfo!['releaseNotesAr'] ?? 'انقر لتحميل النسخة الأحدث الآن')
                                  : (c.updateAvailableInfo!['releaseNotesEn'] ?? 'Tap to download the latest APK'),
                              style: const TextStyle(color: Colors.white70, fontSize: 11),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF00D2FF),
                          foregroundColor: const Color(0xFF0A0E14),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          minimumSize: const Size(0, 32),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () async {
                          final apkUrl = c.updateAvailableInfo!['apkUrl']?.toString() ?? 'http://139.185.47.123:5000/darb.apk';
                          await c.onUpdateDownloaded();
                          await launchUrl(Uri.parse(apkUrl), mode: LaunchMode.externalApplication);
                        },
                        child: Text(
                          arabic ? 'تحديث' : 'Update',
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white54, size: 18),
                        onPressed: () => c.dismissUpdate(),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Waze-style "Still there?" Speed bump confirmation banner
          if (c.pendingPromptReport != null)
            Positioned(
              bottom: c.navigating ? 140 : 220,
              left: 16,
              right: 16,
              child: Material(
                elevation: 12,
                borderRadius: BorderRadius.circular(22),
                color: dark ? const Color(0xFF161F2E) : Colors.white,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: const Color(0xFFFFB300), width: 2),
                    boxShadow: const [
                      BoxShadow(color: Colors.black38, blurRadius: 16, offset: Offset(0, 4)),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: const BoxDecoration(
                              color: Color(0xFFFFB300),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.warning_amber_rounded, color: Colors.black87, size: 24),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  arabic ? '🛑 هل المطب الاصطناعي لا يزال موجوداً؟' : '🛑 Is this speed bump still there?',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: dark ? Colors.white : Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  arabic
                                      ? 'تأكيدك يحافظ على بقاء التنبيه للسائقين الآخرين'
                                      : 'Confirming keeps the alert active for other drivers',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: dark ? Colors.white60 : Colors.black54,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.close, color: dark ? Colors.white54 : Colors.black45, size: 18),
                            onPressed: () => c.dismissPromptReport(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => c.rejectPromptReport(),
                              icon: const Icon(Icons.close, size: 16, color: Colors.redAccent),
                              label: Text(
                                arabic ? 'غير موجود' : 'Not there',
                                style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Colors.redAccent),
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: () => c.confirmPromptReport(),
                              icon: const Icon(Icons.thumb_up_alt_rounded, size: 16),
                              label: Text(
                                arabic ? 'نعم، لا يزال موجوداً' : 'Yes, still there',
                                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                              ),
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFF00C8F8),
                                foregroundColor: Colors.black,
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Parking Arrival Prompt Banner
          if (c.showParkingPrompt)
            Positioned(
              top: c.navigating ? 156 : 54,
              left: 16,
              right: 16,
              child: _buildParkingPromptCard(context, c, dark, arabic),
            ),

          // Live Convoy Track Overview Badge (Top Left)
          if (c.activeLiveRoom != null && c.activeLiveRoom!.isActive)
            Positioned(
              top: c.navigating ? 156 : 56,
              left: 16,
              child: Material(
                elevation: 6,
                borderRadius: BorderRadius.circular(20),
                color: dark ? const Color(0xFF10281E) : const Color(0xFFE8F8F0),
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: _fitConvoyOverview,
                  onLongPress: _openLiveRoomSheet,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xFF00E676),
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.groups_rounded, color: Color(0xFF00E676), size: 18),
                        const SizedBox(width: 6),
                        Text(
                          arabic
                              ? 'موكب (${c.activeLiveRoom!.code}) • مسار الشلّة 🚗'
                              : 'Convoy (${c.activeLiveRoom!.code}) • Track 🚗',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: dark ? Colors.white : Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // Notification / Error banners
          if (c.error != null || c.notice != null)
            Positioned(
              top: c.navigating ? 156 : 54,
              left: 16,
              right: c.navigating ? 76 : 16,
              child: Material(
                elevation: 6,
                borderRadius: BorderRadius.circular(16),
                color: c.error != null ? const Color(0xFFD32F2F) : const Color(0xFF007DAF),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Row(
                    children: [
                      Icon(
                        c.error != null ? Icons.warning_rounded : Icons.info_outline_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          c.error ?? c.notice!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white, size: 18),
                        onPressed: () => c.clearMessage(),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Floating Controls (Side)
          Positioned(
            right: isLandscape ? (arabic ? null : 12) : 16,
            left: isLandscape ? (arabic ? 12 : null) : null,
            top: isLandscape ? 8 : (c.navigating ? 156 : 64),
            child: Column(
              children: [
                // Sound Toggle Button
                _buildCircularButton(
                  icon: c.voice
                      ? (c.lessChatty ? Icons.notifications_active_rounded : Icons.volume_up_rounded)
                      : Icons.volume_off_rounded,
                  color: c.voice ? WazeColors.blue : Colors.grey,
                  dark: dark,
                  size: isLandscape ? 36 : 44,
                  tooltip: arabic ? 'نقر: تبديل الصوت • مطول: اختبار الصوت' : 'Tap: Toggle voice • Long press: Test voice',
                  onPressed: () {
                    if (!c.voice) {
                      c.setVoice(true);
                      c.setLessChatty(false);
                      c.testVoice();
                    } else if (!c.lessChatty) {
                      c.setLessChatty(true);
                    } else {
                      c.setVoice(false);
                    }
                  },
                  onLongPress: () => c.testVoice(),
                ),
                SizedBox(height: isLandscape ? 5 : 10),

                // 3D Perspective Driving View Button
                _buildCircularButton(
                  icon: _is3D ? Icons.view_in_ar_rounded : Icons.layers_rounded,
                  color: _is3D ? WazeColors.cyan : (dark ? Colors.white60 : Colors.black54),
                  dark: dark,
                  size: isLandscape ? 36 : 44,
                  onPressed: _toggle3D,
                ),
                SizedBox(height: isLandscape ? 5 : 10),

                // 3D Satellite Layer Toggle Button
                _buildCircularButton(
                  icon: c.satellite ? Icons.satellite_alt_rounded : Icons.public_rounded,
                  color: c.satellite ? Colors.amber : (dark ? Colors.white60 : Colors.black54),
                  dark: dark,
                  size: isLandscape ? 36 : 44,
                  onPressed: () {
                    c.setSatellite(!c.satellite);
                    if (c.satellite && !_is3D) {
                      _toggle3D();
                    }
                  },
                ),
                SizedBox(height: isLandscape ? 5 : 10),

                // Zoom In
                _buildCircularButton(
                  icon: Icons.add_rounded,
                  color: dark ? Colors.white70 : Colors.black87,
                  dark: dark,
                  size: isLandscape ? 36 : 44,
                  onPressed: () {
                    _mapController?.animateCamera(CameraUpdate.zoomIn());
                  },
                ),
                SizedBox(height: isLandscape ? 4 : 6),

                // Zoom Out
                _buildCircularButton(
                  icon: Icons.remove_rounded,
                  color: dark ? Colors.white70 : Colors.black87,
                  dark: dark,
                  size: isLandscape ? 36 : 44,
                  onPressed: () {
                    _mapController?.animateCamera(CameraUpdate.zoomOut());
                  },
                ),
              ],
            ),
          ),

          // Speedometer & Orange Report Button
          Positioned(
            left: isLandscape ? (arabic ? null : 14) : 20,
            right: isLandscape ? (arabic ? 14 : null) : null,
            bottom: isLandscape
                ? 52
                : (c.navigating ? 150 : (_bottomPanelMinimized ? 76 : 205)),
            child: isLandscape
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Iconic Waze Orange Report Button
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _openReportSheet,
                          borderRadius: BorderRadius.circular(22),
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: WazeColors.orange,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: WazeColors.orange.withValues(alpha: 0.45),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.campaign_rounded,
                                color: Colors.white,
                                size: 22,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Speedometer
                      WazeSpeedometer(
                        speedKph: c.speedKph,
                        miles: c.miles,
                        dark: dark,
                      ),
                    ],
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Iconic Waze Orange Report Button (Directly above Speedometer)
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _openReportSheet,
                          borderRadius: BorderRadius.circular(32),
                          child: Container(
                            width: 58,
                            height: 58,
                            decoration: BoxDecoration(
                              color: WazeColors.orange,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: WazeColors.orange.withValues(alpha: 0.5),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.campaign_rounded,
                                color: Colors.white,
                                size: 30,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      // Speedometer
                      WazeSpeedometer(
                        speedKph: c.speedKph,
                        miles: c.miles,
                        dark: dark,
                      ),
                    ],
                  ),
          ),

          // Floating Recenter Pill when map is panned away from location
          if (!_followUser)
            Positioned(
              left: 0,
              right: 0,
              bottom: c.navigating ? 135 : (_bottomPanelMinimized ? 74 : 185),
              child: Center(
                child: Material(
                  elevation: 8,
                  borderRadius: BorderRadius.circular(20),
                  color: dark ? const Color(0xFF1E2835) : Colors.white,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: _recenter,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: WazeColors.cyan, width: 1.5),
                        boxShadow: const [
                          BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 3)),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.my_location_rounded, color: WazeColors.cyan, size: 17),
                          const SizedBox(width: 6),
                          Text(
                            arabic ? 'أعدني لموقعي' : 'Recenter',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                              color: dark ? Colors.white : Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

          // Bottom Navigation & Search Panel
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: WazeBottomPanel(
              controller: c,
              onTapSearch: () => _openSearch(),
              onTapSettings: _openSettings,
              onTapAddStop: () => _openSearch(asStop: true),
              onTapVoice: _openVoiceSearch,
              onOpenLiveRoom: _openLiveRoomSheet,
              onFitTrack: _fitConvoyOverview,
              isMinimized: _bottomPanelMinimized,
              onMinimizedChanged: (min) {
                setState(() => _bottomPanelMinimized = min);
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Build the MapLibre map widget
  Widget _buildMapWidget(AppController c, bool dark) {
    final styleUrl = _getStyleUrl(dark, c.satellite);

    return Listener(
      onPointerMove: (e) {
        if (e.delta.distanceSquared > 6) {
          if (_followUser) {
            final size = MediaQuery.of(context).size;
            setState(() {
              _followUser = false;
              _puckScreenOffset = Offset(size.width / 2, size.height / 2);
            });
          }
          if (_puckScreenOffset != null) {
            setState(() {
              _puckScreenOffset = _puckScreenOffset! + e.delta;
            });
          }
        }
      },
      onPointerUp: (_) => _syncPuckScreenPosition(),
      onPointerCancel: (_) => _syncPuckScreenPosition(),
      child: MapLibreMap(
        key: ValueKey('maplibre_${c.satellite}_$dark'),
        styleString: styleUrl,
        initialCameraPosition: CameraPosition(
          target: _toMapLibre(c.position),
          zoom: c.satellite ? 16.5 : 15.0,
          tilt: _is3D ? 60.0 : 0.0,
          bearing: _headingUp && c.navigating ? c.heading : 0.0,
        ),
        onMapCreated: _onMapCreated,
        onStyleLoadedCallback: _onStyleLoaded,
        onMapLongClick: _onMapLongPress,
        onCameraIdle: () {
          _syncPuckScreenPosition();
        },
        trackCameraPosition: true,
        myLocationEnabled: false,
        myLocationTrackingMode: MyLocationTrackingMode.none,
        myLocationRenderMode: MyLocationRenderMode.normal,
        compassEnabled: false,
        rotateGesturesEnabled: true,
        tiltGesturesEnabled: true,
        zoomGesturesEnabled: true,
        scrollGesturesEnabled: true,
        attributionButtonPosition: AttributionButtonPosition.bottomLeft,
        attributionButtonMargins: const Point(8, 8),
      ),
    );
  }

  /// Build positioned car puck widget (anchored to user location on screen)
  Widget _buildPositionedCarPuck(AppController c) {
    if (_followUser || _puckScreenOffset == null) {
      final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
      if (isLandscape && c.navigating) {
        final size = MediaQuery.of(context).size;
        // In landscape navigation, place car puck centered in the clear viewing area
        final startOffset = c.arabic ? -40.0 : 40.0;
        return Positioned(
          left: (size.width / 2 + startOffset) - 34,
          top: (size.height / 2 + 10) - 34,
          child: _buildCarPuck(c),
        );
      }
      return Center(
        child: _buildCarPuck(c),
      );
    }

    return Positioned(
      left: _puckScreenOffset!.dx - 34,
      top: _puckScreenOffset!.dy - 34,
      child: _buildCarPuck(c),
    );
  }

  /// Build the animated car puck widget overlay
  Widget _buildCarPuck(AppController c) {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        final pulse = _pulseAnimation.value;
        return SizedBox(
          width: 68,
          height: 68,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Outer animated pulsing radar halo
              Container(
                width: 36 + (28 * pulse),
                height: 36 + (28 * pulse),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: WazeColors.cyan.withValues(
                    alpha: (0.35 * (1.0 - pulse)).clamp(0.0, 1.0),
                  ),
                ),
              ),
              child!,
            ],
          ),
        );
      },
      child: Transform.rotate(
        angle: ((_headingUp && c.navigating) ? 0.0 : c.heading) * (math.pi / 180),
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
            border: Border.all(color: WazeColors.blue, width: 3.5),
            boxShadow: const [
              BoxShadow(
                color: Colors.black38,
                blurRadius: 8,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: const Center(
            child: Icon(
              Icons.navigation_rounded,
              color: WazeColors.blue,
              size: 24,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCircularButton({
    required IconData icon,
    required Color color,
    required bool dark,
    required VoidCallback onPressed,
    VoidCallback? onLongPress,
    String? tooltip,
    double size = 44,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: dark ? WazeColors.darkSurface : Colors.white,
        shape: BoxShape.circle,
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: Tooltip(
        message: tooltip ?? '',
        child: InkWell(
          borderRadius: BorderRadius.circular(size / 2),
          onTap: onPressed,
          onLongPress: onLongPress,
          child: Center(
            child: Icon(icon, color: color, size: size * 0.5),
          ),
        ),
      ),
    );
  }

  Widget _buildParkingPromptCard(
    BuildContext context,
    AppController c,
    bool dark,
    bool arabic,
  ) {
    return Material(
      elevation: 10,
      borderRadius: BorderRadius.circular(20),
      color: dark ? const Color(0xFF1E2835) : Colors.white,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: WazeColors.cyan,
            width: 1.5,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: WazeColors.cyan.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Text('🅿️', style: TextStyle(fontSize: 22)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        arabic ? 'وصلت إلى وجهتك!' : "You've Arrived!",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: dark ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        arabic
                            ? 'هل ترغب في حفظ موقع ركن السيارة للرجوع إليها لاحقاً؟'
                            : 'Would you like to save this parking spot to find your car later?',
                        style: TextStyle(
                          fontSize: 12,
                          color: dark ? Colors.white70 : Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  color: dark ? Colors.white54 : Colors.black45,
                  onPressed: () => c.dismissParkingPrompt(),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => c.dismissParkingPrompt(),
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(arabic ? 'ليس الآن' : 'Not Now'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => c.saveParkingLocation(),
                    icon: const Icon(Icons.bookmark_add_rounded, size: 18),
                    label: Text(arabic ? 'حفظ الموقف' : 'Save Spot'),
                    style: FilledButton.styleFrom(
                      backgroundColor: WazeColors.cyan,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
