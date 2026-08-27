# 🚑 LifeLane — Emergency Vehicle Proximity Alert System

> **Real-time ambulance tracking with a 500-meter geofence alert — giving drivers advance warning before the siren reaches them.**

LifeLane is a full-stack IoT + mobile solution that connects physical GPS tracker hardware mounted on emergency vehicles directly to a Flutter mobile app carried by ordinary drivers. When an ambulance comes within **500 meters**, the app fires a high-priority push notification — giving the driver 30–60 seconds to clear the lane.

---

## 📋 Table of Contents

- [The Problem](#-the-problem)
- [How It Works](#-how-it-works)
- [System Architecture](#-system-architecture)
- [Repository Structure](#-repository-structure)
- [Flutter Mobile App](#-flutter-mobile-app)
  - [Features](#features)
  - [Tech Stack](#tech-stack)
  - [Project Structure](#project-structure)
  - [Getting Started](#getting-started)
- [ESP32 Firmware (LL\_Src\_Code)](#-esp32-firmware-ll_src_code)
  - [Hardware](#hardware)
  - [Firmware Structure](#firmware-structure)
  - [Firebase Data Model](#firebase-data-model)
- [Firebase RTDB Schema](#-firebase-rtdb-schema)
- [Key Algorithms](#-key-algorithms)
- [Roadmap](#-roadmap)
- [License](#-license)

---

## 🚧 The Problem

Every day, ambulances get stuck in traffic because drivers don't know they're coming until the siren is right behind them. By then, there's no space to pull over. **LifeLane solves this with advance warning** — alerting drivers on their phones before the ambulance even enters their street.

---

## ⚙️ How It Works

```
ESP32 GPS Device (on ambulance)
        │
        │  GPS reads: lat, lng, speed, heading
        │  every ~5 seconds via SIM7670G 4G modem
        ▼
Firebase Realtime Database
        │
        │  Flutter app polls every 3 seconds
        ▼
LifeLane Mobile App (driver's phone)
        │
        │  Calculates distance from user to ambulance
        │  Is it within 500m?
        ▼
   YES → 🚨 Push Notification + Red Alert Banner on Map
```

---

## 🏗️ System Architecture

```
┌─────────────────────────────────────────────────────────┐
│                   HARDWARE LAYER                        │
│  Waveshare ESP32-S3 + SIM7670G 4G + GNSS               │
│  Reads GPS → Uploads to Firebase via 4G every ~5s       │
└────────────────────────┬────────────────────────────────┘
                         │ HTTP PUT (JSON)
                         ▼
┌─────────────────────────────────────────────────────────┐
│                   CLOUD LAYER                           │
│  Firebase Realtime Database (asia-southeast1)           │
│  /devices/tracker001  →  { lat, lng, speed, heading }   │
│  /devices/tracker002  →  { lat, lng, speed, heading }   │
└────────────────────────┬────────────────────────────────┘
                         │ HTTP GET (polling every 3s)
                         ▼
┌─────────────────────────────────────────────────────────┐
│                   MOBILE APP LAYER                      │
│  Flutter App (Android / iOS)                            │
│  ├── FirebaseService    → Fetch + auto-delete stale nodes│
│  ├── SharingHubService  → Lerp + distance + bearing      │
│  ├── LocationProvider   → State + timers                 │
│  ├── NotificationService→ 500m push alerts               │
│  └── ReceiverScreen     → Live map UI (GMaps / OSM)      │
└─────────────────────────────────────────────────────────┘
```

---

## 📁 Repository Structure

```
lifelane/
├── lib/                        # Flutter app source
│   ├── main.dart               # App entry point
│   ├── models/
│   │   ├── tracker_device_model.dart   # ESP32 device data model
│   │   └── user_model.dart             # User role model
│   ├── providers/
│   │   └── location_provider.dart      # Central state manager
│   ├── screens/
│   │   ├── splash_screen.dart          # Launch screen
│   │   └── receiver_screen.dart        # Main map + alert UI
│   └── services/
│       ├── firebase_service.dart       # Firebase RTDB polling & cleanup
│       ├── sharing_hub_service.dart    # Lerp, distance, bearing, ETA
│       ├── location_service.dart       # Device GPS (Geolocator)
│       ├── notification_service.dart   # Push notification alerts
│       └── storage_service.dart        # SharedPreferences persistence
│
├── LL_Src_Code/                # ESP32 Arduino firmware
│   ├── LL_Src_Code.ino         # Main sketch (setup + loop)
│   ├── config.h                # All pins, Firebase config, intervals
│   ├── modem.h / modem.cpp     # SIM7670G AT command interface
│   ├── gnss.h / gnss.cpp       # GNSS acquisition & coordinate parsing
│   ├── firebase.h / firebase.cpp # HTTP PUT to Firebase RTDB
│   ├── status_led.h / .cpp     # WS2812B RGB LED status indicator
│   └── README.md               # Detailed firmware documentation
│
├── android/                    # Android platform files
├── ios/                        # iOS platform files
├── assets/
│   └── images/logo.png
└── pubspec.yaml                # Flutter dependencies
```

---

## 📱 Flutter Mobile App

### Features

| Feature | Description |
|---|---|
| 🗺️ **Dual Map Engine** | Switch between Google Maps and OpenStreetMap (keyless) at runtime |
| 📍 **Live Tracker Markers** | Red ambulance markers move smoothly in real time |
| ⭕ **500m Geofence Circle** | Visual radius around the user — turns red when ambulance is inside |
| 📏 **Dashed Polyline** | Live distance line connecting user to nearest ambulance |
| 🚨 **500m Push Alert** | Heads-up notification with ambulance name, distance, and ETA |
| 🔔 **In-app Banner** | Pulsing red emergency banner with animated warning icon |
| 🧭 **Compass Direction** | Cardinal direction (N/NE/E...) from user to ambulance |
| ⏱️ **ETA Calculation** | Estimated arrival time in minutes based on live speed |
| 💀 **Dead Reckoning** | Predicts ambulance position during GPS signal gaps |
| 🎞️ **Marker Lerp** | Smooth linear interpolation between GPS coordinate updates |
| 🗑️ **Auto Cleanup** | Stale Firebase nodes (>10s no signal) are auto-deleted from DB and map |
| 📴 **Offline Graceful** | Defaults to last known state; no crashes on connectivity loss |

### Tech Stack

```yaml
Framework:       Flutter (Dart) — cross-platform (Android, iOS, Web, Desktop)
State Management: Provider (ChangeNotifier)
Maps:            google_maps_flutter + flutter_map (OpenStreetMap)
Location:        geolocator
Animations:      flutter_animate
Notifications:   flutter_local_notifications
Storage:         shared_preferences
Networking:      http
Coordinates:     latlong2
Date/Time:       intl
```

### Project Structure

#### `LocationProvider` — Central State Manager
The single source of truth for the entire app. It manages:
- User's live GPS coordinates (updated each poll cycle)
- List of all active `TrackerDevice` objects fetched from Firebase
- The currently selected target ambulance (defaults to nearest)
- Proximity alert state (`isProximityAlertActive`)
- Two periodic timers:
  - **3-second timer** — polls Firebase RTDB for new ESP32 data
  - **1-second timer** — smooth lerp tick for marker animation

#### `FirebaseService` — Data Fetcher & Janitor
Polls three Firebase endpoints:
- `/devices.json` — primary ESP32 hardware trackers
- `/Lifelane/Users.json` — app-shared users
- `/Users.json` — legacy fallback path

Tracks signal freshness per node using an in-memory `_SignalTracker`. Any node that stops sending new data for **≥ 10 seconds** is automatically **HTTP DELETE**d from Firebase and removed from the UI.

#### `SharingHubService` — Geometry & Smoothing Engine
- **Lerp (Linear Interpolation):** Each tracker has a `_PositionLerpState`. When a new coordinate arrives, the marker smoothly slides to it at 40% of the gap per tick — no jarring jumps.
- **Distance:** Uses `latlong2` Haversine formula.
- **Bearing:** Standard spherical trigonometry (atan2).
- **ETA:** Distance ÷ speed (defaults to 40 km/h if speed < 5 km/h).
- **Cardinal Direction:** Converts bearing degrees to N/NE/E/SE/S/SW/W/NW.

#### `NotificationService` — Smart Alert Engine
- Fires a **high-priority heads-up notification** the moment a tracker crosses into 500m.
- Uses Android `fullScreenIntent` + alarm audio category — cuts through Do Not Disturb.
- **De-duplicates:** One alert per proximity session per device. Resets only when the ambulance exits 500m.
- iOS: `InterruptionLevel.timeSensitive` for equivalent behavior.

### Getting Started

#### Prerequisites

- Flutter SDK `^3.12.2`
- Dart SDK `^3.12.2`
- A Google Maps API key (for Google Maps engine)
- Firebase project with Realtime Database enabled

#### Installation

```bash
# 1. Clone the repository
git clone https://github.com/Haridh432/lifelane.git
cd lifelane

# 2. Install dependencies
flutter pub get

# 3. Add your Google Maps API key
#    Android: android/app/src/main/AndroidManifest.xml
#    iOS:     ios/Runner/AppDelegate.swift

# 4. Run the app
flutter run
```

#### Map Engine — No API Key Option

The app supports **OpenStreetMap** via `flutter_map` with no API key required. Switch to it from the map icon in the top-right corner of the app at any time.

---

## 🔌 ESP32 Firmware (`LL_Src_Code`)

The firmware runs on a **Waveshare ESP32-S3 SIM7670G 4G board** — a compact all-in-one board with an ESP32-S3 MCU, SIM7670G 4G modem, built-in GNSS, SIM card slot, and a WS2812B RGB LED.

### Hardware

| Component | Detail |
|---|---|
| **MCU** | ESP32-S3 |
| **Modem** | SIM7670G (4G LTE + GNSS) |
| **Connectivity** | SIM card (cellular data) |
| **LED** | WS2812B RGB (GPIO 38) |
| **UART RX** | GPIO 17 |
| **UART TX** | GPIO 18 |

### Firmware Structure

```
LL_Src_Code.ino      Main sketch — setup() + loop()
config.h             Central config: pins, Firebase URL, device ID, timeouts
modem.h/cpp          SIM7670G AT command interface (UART communication)
gnss.h/cpp           GNSS location acquisition & NMEA coordinate parsing
firebase.h/cpp       HTTP PUT to Firebase RTDB with retry logic (up to 3x)
status_led.h/cpp     WS2812B LED control (Blue=working, Green=success, Red=error)
```

### How the Firmware Runs

```
setup()
  ├── Init WS2812B LED (Blue)
  ├── Init SIM7670G modem (UART 115200)
  │     ├── AT → OK
  │     ├── Check SIM (AT+CPIN?)
  │     ├── Check signal (AT+CSQ)
  │     ├── Check network (AT+CEREG?)
  │     └── Activate PDP context (AT+CGACT?)
  └── Init GNSS

loop() — every 5 seconds:
  ├── GNSS::getLocation() → lat, lng, speed, heading, timestamp
  ├── Validate coordinates
  └── Firebase::uploadLocation()
        ├── Build JSON payload
        ├── HTTP PUT to /devices/tracker001.json
        ├── HTTP 200 → Green LED ✅
        └── HTTP error → Retry (×3, 500ms delay) → Red LED ❌
```

### Firebase Data Model

The firmware writes a single node — current location only (no history stored):

```json
{
  "latitude": 11.081192,
  "longitude": 76.989157,
  "Speed": 42.5,
  "heading": 315.5,
  "altitude": 432.6,
  "Date": "2026-08-27",
  "Time": "10:45:30",
  "Timestamp": 1786096705000,
  "isSirenActive": true,
  "isSharing": true
}
```

### Status LED

| Condition | LED Color |
|---|---|
| System initializing / GNSS working | 🔵 Blue |
| Firebase upload successful (HTTP 200) | 🟢 Green |
| GNSS failure | 🔴 Red |
| HTTP / network failure | 🔴 Red |

---

## 🗄️ Firebase RTDB Schema

```
Firebase Realtime Database
└── devices/
    ├── tracker001/
    │   ├── latitude: 11.081192
    │   ├── longitude: 76.989157
    │   ├── Speed: 42.5
    │   ├── heading: 315.5
    │   ├── Date: "2026-08-27"
    │   ├── Time: "10:45:30"
    │   ├── Timestamp: 1786096705000
    │   ├── isSirenActive: true
    │   └── isSharing: true
    │
    └── tracker002/
        └── { ... same structure ... }
```

> **Auto-deletion:** The Flutter app automatically deletes any `/devices/trackerXXX` node that stops receiving new data for more than 10 seconds via HTTP DELETE — keeping the database clean.

---

## 🧠 Key Algorithms

### 1. Dead Reckoning (Position Prediction)
When Firebase signal is delayed > 10 seconds, the app predicts the ambulance's current position using spherical vector math:

```
predicted_position = last_known_position
                   + (speed × elapsed_time)
                   × direction_vector(heading)
```
Uses Haversine/spherical trig. Capped at 120 seconds of extrapolation. Effective speed defaults to 40 km/h if last reading was 0.

### 2. Marker Lerp (Smooth Animation)
Each tracker maintains a lerp state `(currentLat, currentLng) → (targetLat, targetLng)`:
```
current += (target - current) × 0.4   // per tick (1s)
```
This creates buttery-smooth marker movement instead of teleporting on each Firebase update.

### 3. 10-Second Signal Stale Detection
Per-node signal tracker compares:
- Explicit `Timestamp` from payload (if present), OR
- Payload hash change (detects any data update)

If no change for ≥ 10 seconds → HTTP DELETE the node from Firebase RTDB → remove from app UI.

---

## 🗺️ Roadmap

### Flutter App
- [ ] Ambulance-side sender mode (broadcast from phone without ESP32 hardware)
- [ ] Route prediction — show the ambulance's likely path on the map
- [ ] Multiple ambulance selection panel
- [ ] Speed and ETA history graph
- [ ] Dark mode UI

### ESP32 Firmware
- [ ] `v0.2.0` — FreeRTOS dual-core architecture (GNSS on Core 0, HTTP on Core 1)
- [ ] `v0.3.0` — Shared location buffer with FreeRTOS mutex
- [ ] `v0.4.0` — Parallel GNSS + Firebase (sub-5s upload)
- [ ] `v0.5.0` — SIM7670G HTTP latency optimization
- [ ] `v1.0.0` — Production candidate

---

## 📄 License

This project is currently an internal development/prototype project.  
Add an appropriate open-source license before public distribution.

---

<div align="center">

**Built with ❤️ for saving lives on the road**

*LifeLane — Clear the Lane. Save a Life.*

</div>
