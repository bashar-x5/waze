import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

import 'models.dart';

/// Fixed simulation origin in central Baghdad, not the device's GPS location.
const LatLng baghdadCenter = LatLng(33.3249, 44.4201);

/// Landmark coordinates are approximate sample destinations. Service-category
/// examples are fictitious and intentionally say so in both languages.
/// Landmark references: https://www.wikidata.org/wiki/Q2562384,
/// https://www.wikidata.org/wiki/Q521251,
/// https://www.openstreetmap.org/way/83673023.
final List<Place> demoPlaces = List<Place>.unmodifiable(const [
  Place(
    id: 'demo-mutanabbi',
    name: 'Al-Mutanabbi Street',
    nameAr: 'شارع المتنبي',
    subtitle: 'Baghdad · sample destination',
    subtitleAr: 'بغداد · وجهة تجريبية',
    point: LatLng(33.340953, 44.388842),
  ),
  Place(
    id: 'demo-museum',
    name: 'Iraq Museum',
    nameAr: 'المتحف العراقي',
    subtitle: 'Baghdad · sample destination',
    subtitleAr: 'بغداد · وجهة تجريبية',
    point: LatLng(33.3286, 44.3858),
  ),
  Place(
    id: 'demo-zawraa',
    name: 'Al-Zawraa Park',
    nameAr: 'متنزه الزوراء',
    subtitle: 'Baghdad · sample destination',
    subtitleAr: 'بغداد · وجهة تجريبية',
    point: LatLng(33.31429, 44.37821),
  ),
  Place(
    id: 'demo-food',
    name: 'Sample cafe',
    nameAr: 'مقهى تجريبي',
    subtitle: 'Fictional example · no business listing',
    subtitleAr: 'مثال افتراضي · ليس نشاطاً تجارياً حقيقياً',
    point: LatLng(33.3197, 44.4236),
    category: PlaceCategory.food,
  ),
  Place(
    id: 'demo-fuel',
    name: 'Sample fuel stop',
    nameAr: 'محطة وقود تجريبية',
    subtitle: 'Fictional example · prices unavailable',
    subtitleAr: 'مثال افتراضي · لا تتوفر أسعار',
    point: LatLng(33.3103, 44.4308),
    category: PlaceCategory.fuel,
  ),
  Place(
    id: 'demo-parking',
    name: 'Sample parking',
    nameAr: 'موقف تجريبي',
    subtitle: 'Fictional example · availability unknown',
    subtitleAr: 'مثال افتراضي · التوفر غير معروف',
    point: LatLng(33.3276, 44.4114),
    category: PlaceCategory.parking,
  ),
  Place(
    id: 'demo-charging',
    name: 'Sample EV charger',
    nameAr: 'شاحن كهربائي تجريبي',
    subtitle: 'Fictional example · no verified charger',
    subtitleAr: 'مثال افتراضي · ليس شاحناً موثقاً',
    point: LatLng(33.3162, 44.4153),
    category: PlaceCategory.charging,
  ),
]);

/// Sample reports expire and never represent live road conditions.
List<RoadReport> demoReports(DateTime now) => [
  RoadReport(
    id: 'demo-traffic',
    type: ReportType.traffic,
    point: const LatLng(33.3292, 44.4135),
    createdAt: now.subtract(const Duration(minutes: 3)),
    expiresAt: now.add(const Duration(minutes: 12)),
    description: 'Sample traffic report / بلاغ ازدحام تجريبي',
    demo: true,
    confirmations: 3,
  ),
  RoadReport(
    id: 'demo-construction',
    type: ReportType.construction,
    point: const LatLng(33.3215, 44.4225),
    createdAt: now.subtract(const Duration(minutes: 8)),
    expiresAt: now.add(const Duration(minutes: 22)),
    description: 'Sample roadwork report / بلاغ أعمال طريق تجريبي',
    demo: true,
    confirmations: 1,
  ),
  RoadReport(
    id: 'demo-hazard',
    type: ReportType.hazard,
    point: const LatLng(33.3353, 44.4027),
    createdAt: now.subtract(const Duration(minutes: 1)),
    expiresAt: now.add(const Duration(minutes: 14)),
    description: 'Sample hazard report / بلاغ خطر تجريبي',
    demo: true,
  ),
];

/// Hand-authored, illustrative polylines for simulation only. These are not
/// verified roads and must never be used as a fallback for failed live routing.
List<DriveRoute> demoRoutes(Place destination, {Place? stop}) {
  final destinationSample = _sampleFor(destination);
  final stopSample = stop == null ? null : _sampleFor(stop);
  return List<DriveRoute>.generate(3, (variant) {
    final anchors = <LatLng>[baghdadCenter];
    int? stopIndex;
    if (stopSample != null && stopSample.id != destinationSample.id) {
      anchors.addAll(_legTo(stopSample, variant));
      stopIndex = anchors.length - 1;
      anchors.addAll(_connector(stopSample.point, destinationSample.point));
    } else {
      anchors.addAll(_legTo(destinationSample, variant));
    }
    final points = _densify(anchors);
    const measure = Distance(roundResult: false);
    final steps = <RouteStep>[];
    var totalDistance = 0.0;
    for (var index = 0; index < anchors.length - 1; index++) {
      final distance = measure(anchors[index], anchors[index + 1]);
      totalDistance += distance;
      final isStop = index == stopIndex;
      final turn = index == 0 ? 'depart' : _turn(anchors, index);
      final instruction = isStop
          ? 'Leave the sample stop and continue'
          : index == 0
          ? 'Start the drive'
          : turn == 'left'
          ? 'Turn left on route'
          : turn == 'right'
          ? 'Turn right on route'
          : 'Continue on route';
      final instructionAr = isStop
          ? 'غادر المحطة وتابع المسار'
          : index == 0
          ? 'ابدأ القيادة'
          : turn == 'left'
          ? 'انعطف يساراً'
          : turn == 'right'
          ? 'انعطف يميناً'
          : 'تابع على المسار';
      steps.add(
        RouteStep(
          instruction: instruction,
          instructionAr: instructionAr,
          type: turn,
          point: anchors[index],
          distanceMeters: distance,
          roadName: variant == 0 ? 'Direct Expressway' : (variant == 1 ? 'Ring Corridor' : 'Boulevard Route'),
        ),
      );
    }
    steps.add(
      RouteStep(
        instruction: 'Arrive at destination',
        instructionAr: 'الوصول إلى الوجهة',
        type: 'arrive',
        point: destinationSample.point,
        distanceMeters: 0,
      ),
    );
    final nameEn = variant == 0 ? 'Express Route' : (variant == 1 ? 'Corridor Route' : 'Alternative Route');
    final nameAr = variant == 0 ? 'المسار السريع' : (variant == 1 ? 'مسار الشريان' : 'المسار البديل');
    final speedDivisor = variant == 0 ? 8.5 : (variant == 1 ? 7.2 : 6.6);
    return DriveRoute(
      id: 'route-${destinationSample.id}-${stopSample?.id ?? 'direct'}-$variant',
      name: nameEn,
      nameAr: nameAr,
      points: List<LatLng>.unmodifiable(points),
      steps: List<RouteStep>.unmodifiable(steps),
      distanceMeters: totalDistance,
      durationSeconds: totalDistance / speedDivisor,
      demo: true,
    );
  });
}

Place _sampleFor(Place place) => demoPlaces.firstWhere(
  (sample) => sample.id == place.id,
  orElse: () => throw ArgumentError.value(
    place.id,
    'place',
    'Simulation is available only for the supplied sample destinations.',
  ),
);

List<LatLng> _legTo(Place destination, int variant) {
  final westbound = destination.point.longitude < 44.4;
  if (westbound) {
    return [
      if (variant == 0) ...[
        const LatLng(33.3270, 44.4172),
        const LatLng(33.3292, 44.4135),
        const LatLng(33.3320, 44.4091),
      ] else if (variant == 1) ...[
        const LatLng(33.3268, 44.4236),
        const LatLng(33.3315, 44.4205),
        const LatLng(33.3342, 44.4148),
      ] else ...[
        const LatLng(33.3255, 44.4190),
        const LatLng(33.3280, 44.4160),
        const LatLng(33.3330, 44.4110),
      ],
      const LatLng(33.3353, 44.4027),
      const LatLng(33.3340, 44.3957),
      ..._connector(const LatLng(33.3340, 44.3957), destination.point),
    ];
  }
  final latitude = destination.point.latitude;
  final longitude = destination.point.longitude;
  final offsetLon = variant == 0 ? 44.4210 : (variant == 1 ? 44.4248 : 44.4180);
  return [
    LatLng(33.3230, offsetLon),
    LatLng(latitude + 0.0017, offsetLon),
    LatLng(latitude + 0.0017, longitude),
    destination.point,
  ];
}

List<LatLng> _connector(LatLng from, LatLng to) => [
  LatLng(
    from.latitude + (to.latitude - from.latitude) * 0.45,
    from.longitude + (to.longitude - from.longitude) * 0.18,
  ),
  LatLng(
    from.latitude + (to.latitude - from.latitude) * 0.45,
    from.longitude + (to.longitude - from.longitude) * 0.75,
  ),
  LatLng(
    from.latitude + (to.latitude - from.latitude) * 0.88,
    from.longitude + (to.longitude - from.longitude) * 0.75,
  ),
  to,
];

List<LatLng> _densify(List<LatLng> anchors) {
  const measure = Distance(roundResult: false);
  final points = <LatLng>[anchors.first];
  for (var index = 1; index < anchors.length; index++) {
    final from = anchors[index - 1];
    final to = anchors[index];
    final divisions = math.max(1, (measure(from, to) / 65).ceil());
    for (var part = 1; part <= divisions; part++) {
      final t = part / divisions;
      points.add(
        LatLng(
          from.latitude + (to.latitude - from.latitude) * t,
          from.longitude + (to.longitude - from.longitude) * t,
        ),
      );
    }
  }
  return points;
}

String _turn(List<LatLng> anchors, int index) {
  final before = anchors[index - 1];
  final current = anchors[index];
  final after = anchors[index + 1];
  final x1 = current.longitude - before.longitude;
  final y1 = current.latitude - before.latitude;
  final x2 = after.longitude - current.longitude;
  final y2 = after.latitude - current.latitude;
  final angle = math.atan2(x1 * y2 - y1 * x2, x1 * x2 + y1 * y2);
  if (angle.abs() < math.pi / 7) return 'continue';
  return angle > 0 ? 'left' : 'right';
}
