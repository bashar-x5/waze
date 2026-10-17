import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

import 'models.dart';

class NavigationProgress {
  const NavigationProgress({
    required this.traveledMeters,
    required this.remainingMeters,
    required this.remainingSeconds,
    required this.distanceFromRouteMeters,
    required this.stepIndex,
    required this.arrived,
    this.stepRemainingMeters,
    this.snappedPoint,
    this.segmentBearing,
    this.headingDivergence,
  });

  final double traveledMeters;
  final double remainingMeters;
  final double remainingSeconds;
  final double distanceFromRouteMeters;
  final int stepIndex;
  final bool arrived;
  final double? stepRemainingMeters;
  final LatLng? snappedPoint;
  final double? segmentBearing;
  final double? headingDivergence;
}

/// Matches a location to the route's segments, rather than its vertices.
/// [previousMeters] belongs to this route and must reset when the route changes.
/// Progress cannot go backwards on noisy fixes. Fixes more than 75 m away do
/// not advance progress: rerouting is a separate, explicit provider operation.
/// Remaining time is proportional to the route estimate, not a traffic model.
NavigationProgress calculateProgress(
  DriveRoute route,
  LatLng position, {
  double previousMeters = 0,
  double? heading,
}) {
  const measure = Distance(roundResult: false);
  final segments = <_Segment>[];
  var geometryLength = 0.0;
  for (var index = 1; index < route.points.length; index++) {
    final from = route.points[index - 1];
    final to = route.points[index];
    final length = measure(from, to);
    if (!length.isFinite || length <= 0.001) continue;
    segments.add(_Segment(from, to, geometryLength, length));
    geometryLength += length;
  }
  final totalMeters = route.distanceMeters.isFinite && route.distanceMeters > 0
      ? route.distanceMeters
      : geometryLength;
  final durationSeconds =
      route.totalDurationSeconds.isFinite && route.totalDurationSeconds > 0
      ? route.totalDurationSeconds
      : (route.durationSeconds.isFinite && route.durationSeconds > 0
          ? route.durationSeconds
          : 0.0);
  final previous = previousMeters.isFinite
      ? previousMeters.clamp(0.0, totalMeters).toDouble()
      : 0.0;

  if (segments.isEmpty) {
    final distance = route.points.isEmpty
        ? double.infinity
        : measure(position, route.points.last);
    final arrived =
        route.points.isNotEmpty && totalMeters <= 30 && distance <= 25;
    final traveled = arrived ? totalMeters : previous;
    final remaining = math.max(0.0, totalMeters - traveled);
    final stepIdx = arrived ? math.max(0, route.steps.length - 1) : 0;
    return NavigationProgress(
      traveledMeters: traveled,
      remainingMeters: remaining,
      remainingSeconds: totalMeters > 0
          ? durationSeconds * remaining / totalMeters
          : 0,
      distanceFromRouteMeters: distance,
      stepIndex: stepIdx,
      stepRemainingMeters: _stepRemainingAt(route, traveled, stepIdx),
      arrived: arrived,
    );
  }

  final previousGeometry = previous / totalMeters * geometryLength;
  final matches = segments.map((segment) => segment.project(position)).toList();
  final nearestDistance = matches
      .map((match) => match.distance)
      .reduce(math.min);
  // At a crossing or overlapping stretch, prefer progress nearest the last
  // fix among similarly close segments. This avoids jumping to a later lap.
  final candidates = matches
      .where((match) => match.distance <= nearestDistance + 3)
      .toList();
  candidates.sort((a, b) {
    final continuity = (a.along - previousGeometry).abs().compareTo(
      (b.along - previousGeometry).abs(),
    );
    return continuity != 0 ? continuity : a.distance.compareTo(b.distance);
  });
  final matched = candidates.first;
  final projectedMeters = matched.along / geometryLength * totalMeters;
  var traveled = matched.distance <= 75
      ? math.max(previous, projectedMeters).clamp(0.0, totalMeters).toDouble()
      : previous;
  var remaining = math.max(0.0, totalMeters - traveled);
  final distanceToDestination = measure(position, route.points.last);
  final arrived =
      remaining <= 30 && distanceToDestination <= 25 && matched.distance <= 25;
  if (arrived) {
    traveled = totalMeters;
    remaining = 0;
  }
  double? headingDivergence;
  if (heading != null && heading.isFinite && heading >= 0) {
    headingDivergence =
        ((heading - matched.segmentBearing + 180) % 360 - 180).abs();
  }

  // Only snap vehicle if heading is roughly aligned (<= 50°) or if vehicle is stationary/heading unknown
  final allowSnap = headingDivergence == null || headingDivergence <= 50;
  final snapped = (matched.distance <= 45 && allowSnap) ? matched.snapped : null;
  final stepIdx = _stepAt(route, traveled, arrived);

  return NavigationProgress(
    traveledMeters: traveled,
    remainingMeters: remaining,
    remainingSeconds: durationSeconds * remaining / totalMeters,
    distanceFromRouteMeters: matched.distance,
    stepIndex: stepIdx,
    stepRemainingMeters: _stepRemainingAt(route, traveled, stepIdx),
    arrived: arrived,
    snappedPoint: snapped,
    segmentBearing: matched.segmentBearing,
    headingDivergence: headingDivergence,
  );
}

double _stepRemainingAt(DriveRoute route, double traveled, int stepIndex) {
  if (route.steps.isEmpty) return 0.0;
  if (stepIndex >= route.steps.length - 1) {
    return math.max(0.0, route.distanceMeters - traveled);
  }
  var cumulative = 0.0;
  for (var index = 0; index <= stepIndex && index < route.steps.length; index++) {
    final distance = route.steps[index].distanceMeters;
    if (distance.isFinite && distance > 0) cumulative += distance;
  }
  return math.max(0.0, cumulative - traveled);
}

int _stepAt(DriveRoute route, double traveled, bool arrived) {
  if (route.steps.isEmpty) return 0;
  if (arrived) return route.steps.length - 1;
  var cumulative = 0.0;
  for (var index = 0; index < route.steps.length; index++) {
    final distance = route.steps[index].distanceMeters;
    if (distance.isFinite && distance > 0) cumulative += distance;
    if (traveled < cumulative || index == route.steps.length - 1) return index;
  }
  return route.steps.length - 1;
}

class _Segment {
  const _Segment(this.from, this.to, this.startMeters, this.lengthMeters);

  final LatLng from;
  final LatLng to;
  final double startMeters;
  final double lengthMeters;

  double get bearing {
    const radians = math.pi / 180;
    final dy = (to.latitude - from.latitude) * radians;
    final dx = _longitudeDelta(to.longitude - from.longitude) *
        radians *
        math.cos((from.latitude + to.latitude) / 2 * radians);
    final deg = math.atan2(dx, dy) * 180 / math.pi;
    return (deg + 360) % 360;
  }

  _Match project(LatLng position) {
    const radians = math.pi / 180;
    const radius = 6371000.0;
    final cosine = math.max(
      1e-8,
      math.cos((from.latitude + to.latitude) / 2 * radians),
    );
    final segmentX =
        _longitudeDelta(to.longitude - from.longitude) *
        radians *
        radius *
        cosine;
    final segmentY = (to.latitude - from.latitude) * radians * radius;
    final positionX =
        _longitudeDelta(position.longitude - from.longitude) *
        radians *
        radius *
        cosine;
    final positionY = (position.latitude - from.latitude) * radians * radius;
    final lengthSquared = segmentX * segmentX + segmentY * segmentY;
    final fraction = lengthSquared == 0
        ? 0.0
        : ((positionX * segmentX + positionY * segmentY) / lengthSquared)
              .clamp(0.0, 1.0)
              .toDouble();
    final deltaX = positionX - segmentX * fraction;
    final deltaY = positionY - segmentY * fraction;
    final snappedLat = from.latitude + (to.latitude - from.latitude) * fraction;
    final snappedLng = from.longitude + (to.longitude - from.longitude) * fraction;
    return _Match(
      startMeters + lengthMeters * fraction,
      math.sqrt(deltaX * deltaX + deltaY * deltaY),
      LatLng(snappedLat, snappedLng),
      bearing,
    );
  }
}

class _Match {
  const _Match(this.along, this.distance, this.snapped, this.segmentBearing);
  final double along;
  final double distance;
  final LatLng snapped;
  final double segmentBearing;
}

double _longitudeDelta(double value) => (value + 180) % 360 - 180;
