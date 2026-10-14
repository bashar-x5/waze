# Darb implementation contract

Iraq-first Flutter navigation app, Arabic and English. Free/open-source components; no required paid API keys. Sample trips/reports visibly marked demo. Public community services are development conveniences, not free production infrastructure. Never silently replace a failed live route with a simulation.

## Shared Dart API
lib/domain/models.dart uses latlong2 LatLng.
- enum PlaceCategory { landmark, food, fuel, parking, charging }
- Place: const constructor; final String id, name, nameAr, subtitle, subtitleAr; final LatLng point; final PlaceCategory category (default landmark); label(bool arabic), detail(bool arabic); toJson(), factory fromJson(Map<String,dynamic>).
- enum ReportType { traffic, crash, hazard, police, closure, construction, weather, camera }
- RoadReport: const constructor; final String id; final ReportType type; final LatLng point; final DateTime createdAt, expiresAt; final String description (default ''); final bool demo (default false); final int confirmations (default 0); isActive getter; toJson(), factory fromJson.
- RouteStep: const constructor; final String instruction, instructionAr, type; final LatLng point; final double distanceMeters; final String roadName (default ''); label(bool arabic).
- DriveRoute: const constructor; final String id, name, nameAr; final List<LatLng> points; final List<RouteStep> steps; final double distanceMeters, durationSeconds; final bool demo (default false); label(bool arabic).
- PlannedDrive: const constructor; final String id; final Place destination; final DateTime arriveAt; toJson(), factory fromJson.

lib/domain/demo_data.dart: const LatLng baghdadCenter; final List<Place> demoPlaces; List<RoadReport> demoReports(DateTime now); List<DriveRoute> demoRoutes(Place destination, {Place? stop}); demo routes only for sample destinations, illustrative never real road guidance.

lib/domain/navigation_engine.dart: NavigationProgress calculateProgress(DriveRoute route, LatLng position, {double previousMeters = 0}); NavigationProgress has double traveledMeters, remainingMeters, remainingSeconds, distanceFromRouteMeters; int stepIndex; bool arrived. Segment projection, monotonic progress with drift; tests.

lib/services/routing_service.dart: RoutingService({http.Client? client, String? baseUrl}); Future<List<DriveRoute>> routes(LatLng origin, Place destination, {Place? stop}); dispose(). Default HTTPS OSRM demo endpoint development-only, serialize/throttle routing <=1/sec; typed readable errors; no fabricated fallback; configurable ROUTING_BASE_URL dart define. Include alternative route parsing and one stop; no unsupported preference toggles.

lib/services/place_search_service.dart: PlaceSearchService({http.Client? client, String? baseUrl}); Future<List<Place>> search(String query, {LatLng? near}); dispose(). Explicitly submitted searches only; default public Photon development endpoint https://photon.komoot.io/api ; configurable SEARCH_BASE_URL; Iraq bbox/country filter + location bias <=1/sec cache. Local sample search owned by root controller. Photon API permits reasonable projects; no public Nominatim.

lib/services/community_service.dart: CommunityService(); bool get configured; bool get connected; Future<void> connect(); Stream<List<RoadReport>> watchReports(LatLng center); Future<void> submit(RoadReport report); Future<void> confirm(String reportId); Future<void> dispose(). Optional SUPABASE_URL + SUPABASE_ANON_KEY defines. Anonymous auth + RLS + server rate bounds. Connect only on user enabling shared reports. No GPS trace upload. Local reports when backend unset. Spatial bounding about 30km.

Root owns lib/main.dart, lib/app/, lib/ui/, platform permissions, pubspec.yaml. Domain agent owns lib/domain/ and test/navigation_engine_test.dart. Provider agent owns routing/search services + test/provider_test.dart. Backend agent owns community_service.dart, supabase/, README.md and docs/.
All filesystem exec tools require sandbox_permissions=require_escalated with justification because default Windows sandbox setup is broken. apply_patch and node tools fail the same way. Use native PowerShell single-quoted here-strings with WriteAllText UTF8 for edits. No AGENTS.md found in cwd or parents. Flutter 3.44.4 / Dart 3.12.2 installed C:\flutter. No git repository. Root handles package resolution/build/test; agents should avoid concurrent flutter commands.
