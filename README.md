# Darb (درب) — Iraq-First Open-Source Community Navigation (Waze Alternative)

A full-featured, community-driven GPS navigation ecosystem built with Flutter, MapLibre GL 3D vector maps, and an ASP.NET Core 9 / PostGIS backend, delivering the iconic **Waze** experience with **100% free, open-source infrastructure** and **zero user-side API fees**.

---

## 📲 Download & Live Links

| Direct APK | Permanent QR Code | Web Operations Dashboard |
|:---:|:---:|:---:|
| [**Download Darb APK**](http://139.185.47.123:5000/darb.apk)<br/>*(86 MB • Android 8.0+)* | <img src="assets/images/darb_qr.png" width="180" alt="Darb Permanent QR Code"/><br/>*(Scan with phone camera)* | [**Live Traffic Dashboard**](http://139.185.47.123:5000/)<br/>*(Interactive Baghdad Telemetry)* |

- 📱 **Direct APK Download**: [http://139.185.47.123:5000/darb.apk](http://139.185.47.123:5000/darb.apk)
- 📷 **Permanent QR Image (PNG)**: [http://139.185.47.123:5000/qr.png](http://139.185.47.123:5000/qr.png)
- 📐 **Scalable Vector QR (SVG)**: [http://139.185.47.123:5000/qr.svg](http://139.185.47.123:5000/qr.svg)
- 🎴 **Branded Share & Print Card**: [http://139.185.47.123:5000/darb_qr_card.png](http://139.185.47.123:5000/darb_qr_card.png)
- 🌐 **Live Web Traffic Dashboard**: [http://139.185.47.123:5000/](http://139.185.47.123:5000/)
- 📖 **Complete Features Guide**: [FEATURES.md](FEATURES.md)

---

## 🌟 Modern Open-Source Architecture

| Component | Solution | Details |
|---|---|---|
| **Map Rendering** | [MapLibre GL](https://maplibre.org/) & [OpenFreeMap](https://openfreemap.org/) | Full-bleed native OpenGL 3D vector tiles with 60° tilt and dynamic 3D building extrusions. |
| **Turn-by-Turn Routing** | [OSRM](http://project-osrm.org/) & Darb Backend | Compass bearing-aware routing, instant rerouting on wrong turns without U-turns, and multiple alternative routes. |
| **Live Traffic Engine** | Server-Side TomTom Harvester + PostGIS | Periodic corridor harvesting (every 5 min) cached in PostGIS, avoiding client API costs while delivering live congestion. |
| **Parking Intelligence** | Smart Parking & Find My Car | Auto-prompt on arrival, 1-tap manual parking saving, live distance/elapsed time, and walking/driving route back. |
| **Geocoding & Search** | [Photon](https://photon.komoot.io/) (Komoot) | Fast geocoding with Iraq bounding box, location-biased search, and offline landmark fallbacks. |
| **Voice Navigation** | [Flutter TTS](https://pub.dev/packages/flutter_tts) | Device-native, on-device Arabic and English Text-to-Speech engine without cloud latency or fees. |
| **Community Alerts** | Darb API + PostGIS / Supabase | Real-time crowdsourced road reports (Police, Crash, Traffic, Hazard) with Still there? verification. |
| **In-Car Platform** | [Android Auto](https://developer.android.com/training/cars/apps) | Native Android Auto CarAppService and NavigationScreen for dashboard infotainment. |

---

## 🚗 Key Capabilities

1. **🅿️ Smart Parking Slot & Find My Car**:
   - Automatic arrival prompt: *وصلت إلى وجهتك! هل ترغب في حفظ موقع ركن السيارة؟*
   - 1-tap quick button (ركنت هنا) anytime.
   - Dedicated dashboard card showing live distance (على بُعد 85 م) and time elapsed (منذ 15 د).
   - 1-tap Go (انطلق) navigation directly back to your vehicle.

2. **🧭 Instant Heading-Aware Rerouting**:
   - Detects divergence when turning onto an unexpected road (headingDivergence > 65°).
   - Immediately requests new paths with earings parameter, guiding drivers forward instead of insisting on dangerous U-turns.

3. **🚦 Real-Time Traffic Bottleneck Warnings**:
   - Multi-tier color coding: Free (Cyan/Blue), Moderate (Amber), Heavy (Red), Standstill (Burgundy).
   - Waze-style floating bottleneck pills alerting of upcoming slowdowns ahead of time.

4. **📢 8-Category Crowdsourced Reports**:
   - Police / Checkpoints (شرطة), Traffic (ازدحام), Hazards (خطر), Crashes (حادث سير), Speed Cameras (رادار), Road Closures (طريق مغلق), Maintenance (صيانة), Weather (أمطار).
   - Interactive popups for nearby drivers to confirm or report cleared.

5. **🗺️ 3D Perspective & Dark Mode**:
   - Native 3D perspective driving mode with building extrusions.
   - Automatic and manual Day/Night theme switching.

6. **🇮🇶 100% Bilingual**:
   - Complete Arabic (العربية) and English UI, RTL formatting, and native voice guidance.

---

## 🚀 Getting Started

### Prerequisites
- Flutter SDK 3.24+ (Dart 3.5+)
- Android Studio / VS Code
- Android device or emulator (Android 8.0+)

### Quick Start
`ash
# Clone the repository
git clone https://github.com/bashar-x5/waze.git
cd waze

# Install dependencies
flutter pub get

# Run test suite
flutter test

# Run app on connected device
flutter run
`

---

## 📁 Repository Structure

`
├── assets/
│   └── map_styles/              # OpenFreeMap vector styles & configs
├── lib/
│   ├── main.dart                # Application entry point
│   ├── app/
│   │   ├── app_controller.dart  # Reactive state controller (GPS, routes, parking, traffic)
│   │   └── darb_app.dart        # App theme, localization, root ListenableBuilder
│   ├── domain/
│   │   ├── demo_data.dart       # Baghdad landmarks, demo routes & simulation points
│   │   ├── models.dart          # Domain models: Place, DriveRoute, ParkedCarLocation, etc.
│   │   ├── navigation_engine.dart # Turn-by-turn progression, heading divergence, snapping
│   │   └── traffic_engine.dart  # Congestion segmentation, bottleneck detection, severity
│   ├── services/
│   │   ├── android_auto_service.dart # Android Auto CarApp integration
│   │   ├── darb_api_service.dart     # Darb backend client (Traffic, corridors, observations)
│   │   ├── place_search_service.dart # Photon geocoding client
│   │   └── routing_service.dart      # OSRM bearing-constrained routing client
│   └── ui/
│       ├── home_screen.dart     # MapLibre 3D map, car puck, HUD, parking banners
│       ├── waze_theme.dart      # Theme colors, badges, maneuver icons
│       └── widgets/             # Panels, modals, speedometer, incident popups
├── server/
│   └── Darb.Api/                # ASP.NET Core 9 backend, TomTom harvester, Web dashboard
├── test/                        # Comprehensive unit & widget test suite
├── FEATURES.md                  # Complete technical features documentation
└── README.md                    # Project overview & quick start
`

---

## 📄 License

Open-source under the MIT License.
