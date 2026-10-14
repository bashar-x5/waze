import 'dart:math' as math;
import 'dart:math' show Point;
import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:latlong2/latlong.dart' as ll;

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
  }

  @override
  void dispose() {
    _pulseController.dispose();
    widget.controller.removeListener(_onControllerChange);
    super.dispose();
  }

  /// Convert latlong2 LatLng to MapLibre LatLng
  LatLng _toMapLibre(ll.LatLng p) => LatLng(p.latitude, p.longitude);

  /// Get the style URL based on dark mode
  String _getStyleUrl(bool dark) {
    // Use OpenFreeMap styles - no API key required
    // We'll load our custom style from assets if available, otherwise use OpenFreeMap
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
    }

    // Update route and marker overlays
    _updateMapOverlays();
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
    setState(() => _followUser = true);
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

          // Car Puck Widget Overlay (positioned at screen center when following)
          if (_followUser)
            Center(
              child: _buildCarPuck(c),
            ),

          // Top Nav HUD (Visible when navigating)
          if (c.navigating && c.route != null && c.progress != null)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: WazeNavHud(
                route: c.route!,
                progress: c.progress!,
                arabic: arabic,
                miles: c.miles,
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
          if (c.navigating && c.route != null) ...[
            if (detectUpcomingTrafficJam(c.route!, c.position) case final alert?)
              Positioned(
                top: 156,
                left: 16,
                right: 76,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: alert.level == TrafficCongestionLevel.standstill
                        ? const Color(0xFF8B0000)
                        : (alert.level == TrafficCongestionLevel.heavy
                            ? WazeColors.red
                            : const Color(0xFFFF9500)),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: const [
                      BoxShadow(color: Colors.black38, blurRadius: 6, offset: Offset(0, 3)),
                    ],
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.traffic_rounded, color: Colors.white, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          arabic ? alert.titleAr : alert.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black26,
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
                    ],
                  ),
                ),
              ),
          ],

          // Alternative Route Prompt Banner during navigation
          if (c.navigating && c.routes.length > 1 && c.route != null) ...[
            Builder(builder: (context) {
              final otherIdx = c.routeIndex == 0 ? 1 : 0;
              final otherRoute = c.routes[otherIdx];
              final diffSec = (otherRoute.totalDurationSeconds - c.route!.totalDurationSeconds).round();
              final diffMin = (diffSec / 60).round();

              final String label;
              if (diffMin < 0) {
                label = arabic
                    ? 'مسار أسرع يوفر ${diffMin.abs()} د'
                    : 'Faster route saves ${diffMin.abs()} min';
              } else if (diffMin == 0) {
                label = arabic ? 'مسار بديل بنفس الوقت' : 'Alternative route (same ETA)';
              } else {
                label = arabic
                    ? 'مسار بديل (+ $diffMin د)'
                    : 'Alternative route (+ $diffMin min)';
              }

              return Positioned(
                top: 210,
                left: 16,
                right: 76,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: diffMin < 0 ? const Color(0xFF0D47A1) : const Color(0xFF37474F),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: const [
                      BoxShadow(color: Colors.black38, blurRadius: 6, offset: Offset(0, 3)),
                    ],
                  ),
                  child: Row(
                    children: [
                      Icon(
                        diffMin < 0 ? Icons.bolt_rounded : Icons.alt_route_rounded,
                        color: diffMin < 0 ? Colors.amber : Colors.lightBlueAccent,
                        size: 22,
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
                        ),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: diffMin < 0 ? WazeColors.blue : const Color(0xFF37474F),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          minimumSize: const Size(0, 28),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () => c.selectRoute(otherIdx),
                        child: Text(
                          arabic ? 'تحويل' : 'Switch',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
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
                            ? 'مسار أسرع يوفر ${((c.route!.totalDurationSeconds - c.routes.first.totalDurationSeconds) / 60).round()} د'
                            : 'Faster route saves ${((c.route!.totalDurationSeconds - c.routes.first.totalDurationSeconds) / 60).round()} min',
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

          // Floating Controls (Right Side)
          Positioned(
            right: 16,
            top: c.navigating ? 156 : 64,
            child: Column(
              children: [
                // Sound Toggle Button
                _buildCircularButton(
                  icon: c.voice
                      ? (c.lessChatty ? Icons.notifications_active_rounded : Icons.volume_up_rounded)
                      : Icons.volume_off_rounded,
                  color: c.voice ? WazeColors.blue : Colors.grey,
                  dark: dark,
                  onPressed: () {
                    if (!c.voice) {
                      c.setVoice(true);
                      c.setLessChatty(false);
                    } else if (!c.lessChatty) {
                      c.setLessChatty(true);
                    } else {
                      c.setVoice(false);
                    }
                  },
                ),
                const SizedBox(height: 10),

                // Recenter / Follow GPS Button
                _buildCircularButton(
                  icon: Icons.my_location_rounded,
                  color: _followUser ? WazeColors.cyan : (dark ? Colors.white60 : Colors.black54),
                  dark: dark,
                  onPressed: _recenter,
                ),
                const SizedBox(height: 10),

                // Compass / Heading-Up Toggle Button
                _buildCircularButton(
                  icon: _headingUp ? Icons.explore_rounded : Icons.north_rounded,
                  color: _headingUp ? WazeColors.cyan : (dark ? Colors.white60 : Colors.black54),
                  dark: dark,
                  onPressed: _toggleHeadingUp,
                ),
                const SizedBox(height: 10),

                // 3D Perspective Driving View Button
                _buildCircularButton(
                  icon: _is3D ? Icons.view_in_ar_rounded : Icons.layers_rounded,
                  color: _is3D ? WazeColors.cyan : (dark ? Colors.white60 : Colors.black54),
                  dark: dark,
                  onPressed: _toggle3D,
                ),
                const SizedBox(height: 10),

                // Zoom In
                _buildCircularButton(
                  icon: Icons.add_rounded,
                  color: dark ? Colors.white70 : Colors.black87,
                  dark: dark,
                  onPressed: () {
                    _mapController?.animateCamera(CameraUpdate.zoomIn());
                  },
                ),
                const SizedBox(height: 6),

                // Zoom Out
                _buildCircularButton(
                  icon: Icons.remove_rounded,
                  color: dark ? Colors.white70 : Colors.black87,
                  dark: dark,
                  onPressed: () {
                    _mapController?.animateCamera(CameraUpdate.zoomOut());
                  },
                ),
              ],
            ),
          ),

          // Speedometer (Bottom Left)
          Positioned(
            left: 20,
            bottom: c.navigating ? 160 : 210,
            child: WazeSpeedometer(
              speedKph: c.speedKph,
              miles: c.miles,
              dark: dark,
            ),
          ),

          // Iconic Waze Orange Report Button (Bottom Right)
          Positioned(
            right: 20,
            bottom: c.navigating ? 160 : 206,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _openReportSheet,
                borderRadius: BorderRadius.circular(32),
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: WazeColors.orange,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: WazeColors.orange.withValues(alpha: 0.5),
                        blurRadius: 14,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.campaign_rounded,
                      color: Colors.white,
                      size: 32,
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
            ),
          ),
        ],
      ),
    );
  }

  /// Build the MapLibre map widget
  Widget _buildMapWidget(AppController c, bool dark) {
    final styleUrl = _getStyleUrl(dark);

    return Listener(
      onPointerMove: (e) {
        if (e.delta.distanceSquared > 12) {
          if (_followUser) {
            setState(() => _followUser = false);
          }
        }
      },
      child: MapLibreMap(
        styleString: styleUrl,
        initialCameraPosition: CameraPosition(
          target: _toMapLibre(c.position),
          zoom: 15.0,
        ),
        onMapCreated: _onMapCreated,
        onStyleLoadedCallback: _onStyleLoaded,
        onMapLongClick: _onMapLongPress,
        onCameraIdle: () {
          // Camera finished moving
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
          child: Center(
            child: Icon(
              c.navigating
                  ? Icons.navigation_rounded
                  : Icons.directions_car_rounded,
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
  }) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: dark ? WazeColors.darkSurface : Colors.white,
        shape: BoxShape.circle,
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: IconButton(
        icon: Icon(icon, color: color, size: 22),
        onPressed: onPressed,
      ),
    );
  }
}
