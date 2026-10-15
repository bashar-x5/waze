# 🚀 Darb (درب) — Features & Capabilities Guide

Comprehensive documentation of all features, services, and architectures in the Darb navigation ecosystem.

---

## 📋 Table of Contents

1. [🅿️ Smart Parking Slot & Find My Car Navigation](#1-smart-parking-slot--find-my-car-navigation)
2. [🧭 Instant Heading-Aware Rerouting](#2-instant-heading-aware-rerouting)
3. [🚦 Real-Time Traffic Engine & TomTom Harvester](#3-real-time-traffic-engine--tomtom-harvester)
4. [🗺️ 3D Vector Map & OpenGL Engine](#4-3d-vector-map--opengl-engine)
5. [📢 Crowdsourced Incident Reporting](#5-crowdsourced-incident-reporting)
6. [🚘 Android Auto Integration](#6-android-auto-integration)
7. [🌐 Web Live Traffic Dashboard](#7-web-live-traffic-dashboard)
8. [📲 Direct APK Distribution & Production Server](#8-direct-apk-distribution--production-server)
9. [🇮🇶 Bilingual Arabization & Voice Engine](#9-bilingual-arabization--voice-engine)

---

## 1. 🅿️ Smart Parking Slot & Find My Car Navigation

Never lose your parked car again. Darb includes intelligent parking location detection and 1-tap navigation:

- **Automatic Arrival Prompt**: When navigation arrives at destination (rrived == true), Darb immediately asks:
  > *وصلت إلى وجهتك! هل ترغب في حفظ موقع ركن السيارة للرجوع إليها لاحقاً؟*
  > *(You've arrived! Would you like to save this parking spot to find your car later?)*
- **1-Tap Manual Save**: Quick pill on the bottom sheet (**ركنت هنا / Park Here**) saves current GPS coordinates anytime.
- **Find My Car Card**:
  - Live distance to car: e.g., على بُعد 85 م من موقعك / 85 m from your location.
  - Elapsed time tracker: e.g., منذ 15 د / 15m ago.
  - **انطلق (Go)**: Plots immediate walking or driving route back to the saved spot.
  - **مسح (Clear)**: Deletes the saved spot with one tap.
- **Persistent Storage**: Survives app restarts and phone reboots via encrypted local preferences.
- **Visual Map Badge**: High-visibility cyan parking badge on the OpenGL vector map.

---

## 2. 🧭 Instant Heading-Aware Rerouting

Traditional GPS apps struggle when you make a wrong turn, insisting on U-turns or delaying route recalculation. Darb implements **Instant Heading-Aware Divergence Detection**:

- **Real-Time Divergence Detection**: Compares current vehicle bearing against the active road segment bearing (headingDivergence > 65°).
- **Bearing-Constrained Reroute**: Injects the driver's current heading (earings={heading},45) into the backend routing engine (OSRM/Darb.Api).
- **Zero U-Turn Logic**: Forces the routing engine to look ahead in the actual direction of travel rather than telling the driver to turn backwards into oncoming traffic.
- **Instant Alternative Route**: Generates alternate routes dynamically with real-time ETA comparison (Faster route saves X min).

---

## 3. 🚦 Real-Time Traffic Engine & TomTom Harvester

To minimize API cost and provide fast local responses, Darb employs a **Server-Side Traffic Harvester Architecture**:

- **TomTom Traffic Aggregation Worker**: The server polls Baghdad's 8 major arterial corridors every 5 minutes using TomTom Flow API.
- **Traffic Congestion Levels**:
  - 🟢 **Free Flow**: High-speed normal transit.
  - 🟡 **Moderate**: Amber highlight with proportional delay.
  - 🔴 **Heavy**: Bright red congestion alert.
  - 🛑 **Standstill**: Dark burgundy alert with Waze-style Bottleneck Pill.
- **Cached PostGIS Database**: Users query the local Darb server (/api/traffic/conditions), eliminating direct client-side external API queries and staying within free tier allowances.
- **Ahead-of-Route Traffic Warnings**: Displays floating alerts for upcoming traffic bottlenecks (e.g. ازدحام شديد بعد 800 م).

---

## 4. 🗺️ 3D Vector Map & OpenGL Engine

Powered by native OpenGL MapLibre GL rendering with OpenFreeMap vector tiles:

- **Full 3D Perspective**: Interactive 3D tilt mode (60° tilt) for realistic driving perspective.
- **3D Building Extrusions**: Dynamic height-interpolated buildings (ender_height / height).
- **Dynamic Day & Night Styling**:
  - Automatic or manual Dark Mode with customized contrast for night driving.
- **Pulsing Radar Car Puck**: Direction-aware car icon with animated pulsing GPS radar wave.
- **Map Controls**: 1-tap recenter, compass orientation, 3D tilt toggle, and smooth zoom gestures.

---

## 5. 📢 Crowdsourced Incident Reporting

Iconic Waze-style community reporting allows drivers to share live road conditions:

- **Iconic Orange FAB**: 1-tap access to 8 categorized road events:
  - 👮 Police / Checkpoint (شرطة / سيطرة)
  - 🚗 Traffic Jam (ازدحام)
  - ⚠️ Road Hazard (خطر في الطريق)
  - 💥 Crash / Accident (حادث سير)
  - 📷 Speed Camera / Radar (رادار سرعة)
  - ⛔ Road Closure (طريق مغلق)
  - 🚧 Maintenance / Construction (أعمال صيانة)
  - 🌧️ Bad Weather (طقس سيء / أمطار)
- **Still There? Verification**: Nearby drivers receive interactive popups to vote 👍 Still There or ✕ Not There, automatically cleaning up expired incidents.

---

## 6. 🚘 Android Auto Integration

Full in-car infotainment display compatibility:

- **Android Auto Service**: Implements CarAppService and NavigationScreen.
- **Driver Distraction Compliance**: Clean, high-contrast maneuvers and turn cards optimized for car dashboards.
- **Voice Guidance**: Routes audio prompts seamlessly through vehicle speakers via Bluetooth/USB.

---

## 7. 🌐 Web Live Traffic Dashboard

Operational control center accessible in real-time via web browser:

- **URL**: http://139.185.47.123:5000/
- **Multi-Basemap Switcher**:
  - Darb Dark (Premium dark mode).
  - OpenStreetMap Dark.
  - Esri World Imagery (Satellite).
  - OpenStreetMap Light.
- **Live Incidents & Heatmap**: Real-time display of active road reports, traffic segments, and corridor speeds.
- **Clean Interface**: Watermark-free professional layout using Esri and OSM tile providers.

---

## 8. 📲 Direct APK Distribution & Production Server

Seamless over-the-air installation without store hurdles:

- **Direct Download URL**: http://139.185.47.123:5000/darb.apk
- **Configured MIME Type**: Native .apk (pplication/vnd.android.package-archive) served with HTTP 200 chunked range support.
- **Architecture**: ASP.NET Core 9 Minimal API hosted on Ubuntu Linux with Kestrel reverse proxy.

---

## 9. 🇮🇶 Bilingual Arabization & Voice Engine

Designed from the ground up for Iraqi and regional drivers:

- **Full Arabic / English Support**: Instant 1-tap language switcher with complete RTL UI layout.
- **Local On-Device TTS**: Clear spoken voice instructions (*بعد 300 متر، انعطف يساراً نحو شارع الرشيد*).
- **Less Chatty Mode**: Option to suppress minor alerts and focus purely on critical maneuvers.
- **Local Baghdad POIs**: Pre-indexed Iraqi landmarks, gas stations, hospitals, and restaurants with offline fallback.
