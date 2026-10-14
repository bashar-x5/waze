# Darb (درب) — 100% Free & Open-Source Waze Navigation Clone

A full-featured, community-driven GPS navigation app built with Flutter, designed to deliver the iconic **Waze** experience with **100% free, open-source infrastructure** and **zero paid API fees**.

---

## 🌟 100% Free & Open-Source Stack (Zero Paid Keys)

Unlike commercial navigation apps that rely on expensive Google Maps or Mapbox APIs, Darb is completely free to build, host, and run:

| Component | Free Solution | Details |
|---|---|---|
| **Map Rendering** | [OpenStreetMap](https://www.openstreetmap.org/) & [CartoDB Basemaps](https://carto.com/basemaps/) | Free vector-styled raster tiles with daytime and dark mode styles via `flutter_map`. |
| **Turn-by-Turn Routing** | [OSRM](http://project-osrm.org/) (Open Source Routing Machine) | Free routing with alternate routes, turn maneuvers, and realistic ETA calculation. |
| **Geocoding & Search** | [Photon](https://photon.komoot.io/) (Komoot) | Fast, open-source geocoding with location-biased search and categorized points of interest. |
| **Voice Navigation** | [Flutter TTS](https://pub.dev/packages/flutter_tts) | Device-native, on-device Text-to-Speech engine in Arabic and English (no cloud fees). |
| **Community Alerts** | [Supabase Free Tier](https://supabase.com/) & Local DB | Real-time crowdsourced road reports, confirmations, and alerts with offline-first support. |
| **GPS & Sensors** | Device Hardware (`geolocator`) | High-accuracy GPS positioning with smooth bearing heading orientation. |

---

## 🚗 Iconic Waze Features Included

1. **Waze Navigation Map**:
   - High-contrast day and night map styles.
   - Vibrant neon cyan active route line with dark navy casing and glow.
   - Alternate route comparisons (Fastest vs. Alternative).
   - Animated user vehicle puck that rotates with device heading.
   - Long-press anywhere on the map to drop a pin and navigate instantly.

2. **Top Maneuver HUD**:
   - Large maneuver icons (Turn Left, Turn Right, Roundabout, Merge, U-Turn, Arrive).
   - Remaining distance to maneuver (`300 m`, `1.5 km`).
   - Street names and maneuver instructions in English and Arabic (`شارع الرشيد`).
   - "Next step" preview (`Then: Turn right`).
   - Tap HUD to inspect the full **Turn-by-Turn Directions list**.

3. **Floating Speedometer**:
   - Circular Waze-style speedometer badge displaying real-time vehicle speed in `km/h` or `mph`.
   - Speed warning highlight.

4. **Crowdsourced Road Reporting (Iconic Orange Button)**:
   - Dedicated orange Waze floating action button (FAB).
   - 8 Community Report categories:
     - 👮 **Police** (`شرطة`)
     - 🚗 **Traffic Jam** (`ازدحام`)
     - ⚠️ **Hazard** (`خطر`)
     - 💥 **Crash** (`حادث سير`)
     - 📷 **Speed Camera** (`رادار سرعة`)
     - ⛔ **Road Closure** (`طريق مغلق`)
     - 🚧 **Construction** (`أعمال صيانة`)
     - 🌧️ **Bad Weather** (`طقس سيء`)
   - Interactive report pins on the map with confirmation badges.
   - **"Still there?"** interactive popup where nearby drivers can confirm (`👍 Still there`) or report absent (`✕ Not there`).

5. **Waze Bottom Control Sheet**:
   - **Idle Mode**: "Where to?" search trigger, one-tap Home and Work buttons, Saved Places, and recent destination chips.
   - **Route Preview**: Detailed destination card, multiple route choices, "+ Add Stop" waypoint support, and "Drive Now" button.
   - **Active Driving Mode**: Live ETA clock, remaining duration, remaining distance, and prominent red "End Navigation" button.

6. **Search & Discovery**:
   - Quick Category pills: ⛽ Gas Stations, 🍔 Food, 🅿️ Parking, ⚡ EV Charging, 🏛️ Landmarks.
   - Live location-biased geocoding.
   - Star places as Favorites.

7. **Bilingual & Accessibility**:
   - Full English and Arabic (`العربية`) UI with right-to-left (RTL) support.
   - Voice alerts with "Less Chatty" mode for essential directions only.
   - Built-in Baghdad demo simulation mode to test trips without requiring real physical driving.

---

## 🚀 Getting Started

### Prerequisites
- Flutter SDK 3.24+ (Dart 3.5+)
- Android Studio / Xcode / Windows build tools

### Installation
```bash
# Clone the repository
cd waze

# Fetch dependencies
flutter pub get

# Run static analysis
flutter analyze

# Run unit and widget tests
flutter test

# Launch the app
flutter run
```

---

## 📁 Architecture Overview

```
lib/
├── main.dart                  # Application entry point
├── app/
│   ├── app_controller.dart    # Main reactive state controller (GPS, routes, TTS, reports)
│   └── darb_app.dart          # App theme, localization, root ListenableBuilder
├── domain/
│   ├── demo_data.dart         # Baghdad demo simulation data & sample landmarks
│   ├── models.dart            # Place, RoadReport, DriveRoute, RouteStep, PlannedDrive
│   └── navigation_engine.dart # Turn progression, segment projection & ETA calculation
├── services/
│   ├── community_service.dart # Real-time Supabase community reports sync
│   ├── place_search_service.dart # Photon / Komoot geocoding service
│   └── routing_service.dart   # OSRM open-source routing engine client
└── ui/
    ├── home_screen.dart       # Main interactive map & navigation HUD container
    ├── waze_theme.dart        # Waze color palette, maneuver icons, incident styling
    └── widgets/
        ├── waze_bottom_panel.dart    # Idle search / Route preview / Active drive bottom sheets
        ├── waze_incident_popup.dart  # "Still there?" incident confirmation card
        ├── waze_nav_hud.dart         # Top navigation maneuver banner & turn list
        ├── waze_report_sheet.dart    # 8-grid road alert reporting modal
        ├── waze_search_modal.dart    # Place search & POI categories sheet
        ├── waze_settings_modal.dart  # Settings, audio, language, and demo toggles
        └── waze_speedometer.dart     # Circular real-time speedometer
```
