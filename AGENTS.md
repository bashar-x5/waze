# AGENTS.md — Development & Architecture Context for AI Agents & Developers

This document provides complete operational, architectural, and development context for any AI assistant (Antigravity, Cursor, Claude Code, Copilot) or developer working on the **Darb** codebase.

---

## 🧭 Project Essence

- **App Name**: Darb (درب) — An Iraq-first, bilingual (Arabic & English), 100% free & open-source community navigation app (Waze alternative).
- **Core Philosophy**: Zero user-side API fees, native 3D OpenGL vector maps, crowd-sourced road reporting, smart parking memory, and server-side traffic caching.
- **Git Repository**: https://github.com/bashar-x5/waze.git (Default branch: main).

---

## 🌐 Production Server & Live Infrastructure

- **Server IP**: 139.185.47.123
- **Port**: 5000 (HTTP)
- **Live Web Traffic Dashboard**: http://139.185.47.123:5000/ (Esri Dark Gray + OSM multi-basemap, live incidents, traffic flow).
- **Direct APK Download**: http://139.185.47.123:5000/darb.apk (Configured MIME type pplication/vnd.android.package-archive).
- **Server Stack**: ASP.NET Core 9 Minimal API (server/Darb.Api), PostgreSQL 16 + PostGIS, Docker, systemd.
- **TomTom Traffic Harvester**: Runs server-side (TrafficAggregationWorker.cs and TomTomTrafficHarvester.cs), harvesting Baghdad's 8 major corridors every 5 minutes into PostGIS. Client queries /api/traffic/conditions directly from this local database, never consuming external API quotas on user devices.
- **SSH Access**: ssh -i <a> ubuntu@139.185.47.123 (Private key file  is stored locally and excluded in .gitignore).
- **Live Container**: Web and API run inside Docker container darb-api.

---

## 📁 Key File Map

| Path | Purpose |
|---|---|
| lib/app/app_controller.dart | Primary reactive controller (ChangeNotifier): GPS tracking, OSRM routing, parking state, reports, audio/TTS. |
| lib/domain/models.dart | Immutable domain models: Place, DriveRoute, RouteStep, RoadReport, ParkedCarLocation, PlannedDrive. |
| lib/domain/navigation_engine.dart | Pure navigation math: turn progression, segment projection, heading divergence calculation, road snapping. |
| lib/domain/traffic_engine.dart | Traffic level classification, route segment coloring, and upcoming bottleneck alert detection. |
| lib/services/darb_api_service.dart | Client HTTP client for the Darb ASP.NET backend (traffic conditions, observations, reports). |
| lib/services/routing_service.dart | OSRM routing client with compass bearing support (earings={heading},45). |
| lib/services/android_auto_service.dart | Android Auto integration for in-car dashboard infotainment. |
| lib/ui/home_screen.dart | MapLibre GL 3D vector map, car puck overlay, navigation HUD, parking prompt floating card. |
| lib/ui/widgets/waze_bottom_panel.dart | Bottom sliding sheet: Idle search, Quick Pills (Home, Work, Saved, Park Spot, Settings), Find My Car card, route preview. |
| server/Darb.Api/ | ASP.NET Core 9 backend, TomTom harvester, Web dashboard (wwwroot/index.html). |

---

## 🛠️ Essential Commands

### 1. Run Tests (Mandatory before committing)
`ash
flutter test
`
*Current test suite: 35 passing tests in 	est/ verifying navigation math, UI widgets, traffic engine, API services, and parking slot logic.*

### 2. Run App Locally
`ash
flutter run
`

### 3. Build Release APK
`ash
flutter build apk --release
`
*Output binary located at uild/app/outputs/flutter-apk/app-release.apk.*

### 4. Deploy APK & Web Updates to Server
`ash
# Upload APK to host and copy into running container
Copy-Item -Path 'build\app\outputs\flutter-apk\app-release.apk' -Destination 'Darb-release.apk' -Force
scp -i a build/app/outputs/flutter-apk/app-release.apk ubuntu@139.185.47.123:/home/ubuntu/darb/server/Darb.Api/wwwroot/darb.apk
ssh -i a ubuntu@139.185.47.123 sudo docker cp /home/ubuntu/darb/server/Darb.Api/wwwroot/darb.apk darb-api:/app/wwwroot/darb.apk

# Upload web dashboard index.html into running container
scp -i a server/Darb.Api/wwwroot/index.html ubuntu@139.185.47.123:/home/ubuntu/darb/server/Darb.Api/wwwroot/index.html
ssh -i a ubuntu@139.185.47.123 sudo docker cp /home/ubuntu/darb/server/Darb.Api/wwwroot/index.html darb-api:/app/wwwroot/index.html
`

---

## ⚠️ Critical Development Rules

1. **Bilingual Requirement**: Every user-facing string must support both Arabic and English:
   `dart
   arabic ? 'النص بالعربية' : 'English Text'
   `
2. **Heading-Aware Rerouting**: When requesting routes after divergence, always transmit the current vehicle heading to prevent the routing engine from demanding backward U-turns:
   `dart
   final bearing = c.heading;
   await routingService.routes(origin, dest, bearing: bearing);
   `
3. **Parking Persistence**: The parkedLocation (ParkedCarLocation) is stored in SharedPreferences under key darb.preferences.v1. Do not mutate this key structure without maintaining backwards compatibility.
4. **Offline & Zero Cloud Cost**: Never add paid client-side API keys (Google Maps, Mapbox). Use OpenFreeMap vector tiles, OSRM routing, and local server caching.
