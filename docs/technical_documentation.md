# LifeLane Alert
## Complete Technical & Product Documentation

### Table of Contents
1. Project Overview
2. How It Started
3. Core Problem
4. Inspiration & Product Direction
5. Approach & Core Solution
6. Features & Functionalities
7. Current Version Features (v1.0.0)
8. UI/UX Documentation
9. User Workflows
10. Step-by-Step Instructions
11. Troubleshooting
12. Technical Architecture
13. Source Code Documentation
14. Development Environment & Versions
15. Build & Deployment
16. Configuration & Environment Setup
17. Testing & Validation
18. Next Version / Future Scope
19. Maintenance & Support
20. Hardware Firmware Documentation (ESP32-S3)

---

### 1. Project Overview
#### Executive Summary
LifeLane Alert is a cross-platform mobile application (Android & iOS) built with Flutter that provides real-time proximity awareness of approaching emergency vehicles—primarily ambulances equipped with ESP32 GPS hardware trackers. The app continuously monitors a Firebase Realtime Database (RTDB) for live telemetry from ESP32 hardware devices and triggers high-priority proximity alerts when any emergency vehicle enters within 500 meters of the app user’s GPS location.
The application is fully receiver-side: the general public runs LifeLane Alert on their smartphones and are passively alerted when an ambulance is approaching nearby, enabling them to clear the road proactively rather than reactively.

#### Mission Statement
To reduce emergency vehicle response time delays by giving the general public real-time awareness of approaching ambulances—without requiring any action from the driver.

#### Target Audience & User Personas
| Persona | Description |
|---|---|
| General Public (Receiver) | Everyday smartphone users who want to be notified when an ambulance is approaching within 500m so they can clear the road |
| Traffic Authorities | Municipal traffic managers monitoring emergency vehicle corridors |
| Fleet Operators | Emergency dispatch centers tracking multiple ambulance units simultaneously |
| Developers / Integrators | Engineers building ESP32 GPS hardware that publishes to Firebase RTDB |

#### Key Value Propositions
* Zero friction for the public: Install once, runs in background, no logins or accounts required
* Dual map engine: Switch between Google Maps and OpenStreetMap (no API key required for OSM)
* Smart dead reckoning: Continues extrapolating vehicle position during Firebase signal dropout (up to 120 seconds)
* Auto-cleanup: Stale Firebase nodes are automatically deleted after 10 seconds of signal silence—no ghost markers
* High-priority alerts: Full-screen intent notifications with alarm-level audio on Android 13+, time-sensitive interruption on iOS

---

### 2. How It Started
#### Origin Story
LifeLane Alert originated from a real-world observation: ambulances in dense urban traffic frequently face severe delays because drivers ahead have no warning until the siren is audible at close range—often too late to safely clear the lane. Existing solutions (FM radio broadcasts, flashing overhead signs) are infrastructure-heavy and geographically limited.
The core insight was that every ambulance can carry an inexpensive ESP32 microcontroller with GPS. If that hardware publishes location to a cloud database, any smartphone running a lightweight Flutter app can compute the approaching vehicle’s distance in real time and alert the driver.

#### Evolution from Initial Vision
| Phase | Description |
|---|---|
| Concept | A simple map pin showing ambulance location from Firebase |
| v0.1 | Flutter app polling Firebase REST API, Google Maps only |
| v0.5 | Provider state management, SharingHubService for distance/bearing math |
| v0.8 | Dead reckoning extrapolation algorithm added to TrackerDevice model |
| v1.0.0 | Dual map engine (Google Maps + OpenStreetMap), local notifications, auto-node deletion, full UI polish |

#### Key Development Milestones
* Firebase RTDB REST integration: Chose REST over Firebase SDK to avoid native plugin conflicts with google_maps_flutter
* Linear interpolation (lerp) smooth marker movement: Eliminated jittery marker jumps between GPS polling cycles
* Signal staleness auto-deletion: 10-second countdown triggers HTTP DELETE on Firebase to prevent ghost devices
* Dual map provider abstraction: MapEngine enum in ReceiverScreen allows runtime switching without state loss

---

### 3. Core Problem
#### Problem Statement
When an ambulance activates its siren and navigates through urban traffic:
* Drivers 400–800m ahead cannot hear the siren until the vehicle is within ~150 m.
* By the time drivers notice, they have insufficient space or time to safely maneuver.
* Narrow roads, high traffic density, and noise-cancelling car audio exacerbate the problem
* Delayed ambulance arrival directly correlates with increased patient mortality rates

#### Market Gaps & Competitor Limitations
| Solution | Limitation |
|---|---|
| Ambulance sirens only | Inaudible beyond ~150m, inaudible inside modern soundproofed vehicles |
| Overhead LED corridor signs | Require fixed infrastructure investment, only cover predefined corridors |
| Municipal FM broadcast | Coverage gap, requires in-car radio, no smartphone integration |
| Existing fleet apps (for dispatch) | Not designed for general public; not real-time proximity-aware |
| Google/Apple Maps | No emergency vehicle layer or real-time ambulance proximity API for consumers |

#### Downstream Impact
* Each minute of ambulance delay in cardiac arrest cases reduces survival by ~10%
* Fleet operators have no mechanism to notify public in advance
* Traffic signal preemption systems exist for intersections only—not for lane-clearance over 400–800m corridors

---

### 4. Inspiration & Product Direction
#### Product Philosophy & Guiding Principles
| Principle | Implementation |
|---|---|
| Zero-account onboarding | The app starts immediately, no login and no sign-up |
| Privacy-first | App users are purely receivers—their location is never uploaded to Firebase |
| Offline-graceful | OSM tile layer works without an API key; dead reckoning maintains awareness during signal dropout |
| Hardware-agnostic ingest | Firebase parser handles multiple field-name conventions (latitude, Latitude, lat, Lat) |
| Self-healing data | Stale nodes automatically deleted from Firebase RTDB—no manual cleanup needed |

#### Benchmark Products & Design Inspiration
* Waze: Community-driven real-time alerts for hazards inspired the proximity notification model
* Google Maps Live Traffic: Smooth polyline and vehicle overlay rendering inspired the dashed bearing line
* Apple Emergency Alerts: Full-screen intent notification style on critical proximity breach

#### Long-term Strategic Direction
* Expand from ambulances to police vehicles and fire engines
* Open an ESP32 firmware specification for hardware manufacturers
* Publish an SDK so third-party traffic apps (Waze, HERE Maps) can embed LifeLane alert data

---

### 5. Approach & Core Solution
#### Conceptual Framework
The system is structured around a one-way telemetry pipeline:
ESP32 Hardware (GPS) → Firebase RTDB → LifeLane Alert App (Flutter)
The app never writes location data to Firebase (except auto-deleting stale nodes). All computation—distance, bearing, ETA, and dead reckoning—happens locally on the user’s device.

#### Technical Innovations
**1. Linear Interpolation (Lerp) Smooth Marker Movement**
Each ESP32 device gets a `_PositionLerpState` in `SharingHubService`. On each 3-second Firebase poll, the marker’s rendered position moves 40% of the way toward the new target each tick (1-second ticker):
```dart
lerp.currentLat += (lerp.targetLat - lerp.currentLat) * 0.4;
lerp.currentLng += (lerp.targetLng - lerp.currentLng) * 0.4;
```
This eliminates the jarring snap-to-position visible in raw GPS polling.

**2. Dead Reckoning Extrapolation**
When a Firebase node’s payload hasn’t changed for >10 seconds (stale signal), `TrackerDevice.getPredictedLocation()` extrapolates the vehicle’s position using spherical trigonometry:
```dart
// Angular distance along heading vector
final double angularDist = distanceMeters / earthRadius;
final double predLatRad = math.asin(math.sin(latRad) * math.cos(angularDist) + math.cos(latRad) * math.sin(angularDist) * math.cos(headingRad));
```
Effective speed defaults to 40.0 km/h if the reported speed is ≤ 0.5 km/h (stationary). Elapsed time is capped at 120 seconds to prevent unbounded extrapolation.

**3. Auto-Node Deletion**
`FirebaseService` maintains an in-memory `_signalTrackers` map. If a node’s payload is unchanged for ≥10 seconds, the service fires an HTTP DELETE to `$databaseUrl/$fullPath.json` and removes the device from the active UI immediately—preventing ghost ambulance markers from persisting.

#### Technical Rationale
| Decision | Rationale |
|---|---|
| Firebase REST API (not Firebase SDK) | Avoids google_maps_flutter + Firebase native plugin conflicts on Android/iOS |
| Provider pattern (not Bloc/Riverpod) | Lightweight, sufficient for single-provider state tree in v1.0 |
| Dual map engines | Google Maps requires API key billing; OSM provides a zero-cost fallback |
| SharedPreferences (not SQLite) | Minimal persistent data (4 keys); SQLite would be over-engineered |

---

### 6. Features & Functionalities
#### Core Features
| # | Feature | Description |
|---|---|---|
| 1 | Real-time ESP32 tracker sync | Polls Firebase RTDB every 6 seconds across 3 monitored endpoints |
| 2 | 500m geofence proximity detection | Computes Haversine distance between user and each device on every tick |
| 3 | High-priority push notifications | Android full-screen intent + alarm audio; iOS time-sensitive notification on 500m breach |
| 4 | Smooth marker movement (lerp) | 40% linear interpolation per 2-second tick eliminates GPS jitter |
| 5 | Dead reckoning extrapolation | Spherical vector math to predict position during signal dropout (up to 120s) |
| 6 | Auto-stale node deletion | Automatically deletes Firebase nodes silent for ≥10 seconds |
| 7 | Dual map engine | Runtime switch between Google Maps and OpenStreetMap |
| 8 | Bearing & cardinal direction | Calculates bearing angle and N/NE/E/SE compass direction to target |
| 9 | ETA calculation | Distance ÷ speed (defaults to 50 km/h if speed ≤ 5 km/h) |
| 10 | Dashed bearing polyline | Visual line from user to selected target device on both map engines |

#### Secondary Features
| # | Feature | Description |
|---|---|---|
| 11 | Permission management | Graceful GPS permission request flow with amber warning overlay if denied |
| 12 | Map engine badge overlay | The floating badge always shows the active map engine name |
| 13 | Siren status display | InfoWindow / marker shows 🚨 [SIREN ACTIVE] when isSirenActive = true |
| 14 | Signal staleness indicator | isSignalStale getter marks device if Firebase last update >10s ago |
| 15 | Local-only user identity | StorageService.getOrCreateUserId() generates usr_{timestamp} ID—never uploaded |

#### Feature Matrix: User Roles vs Actions
| Action | Receiver (Public) | Ambulance (Hardware) |
|---|---|---|
| View live emergency vehicle positions | ✓ | ✓ |
| Receive 500m proximity push notification | ✓ | ✗ |
| Upload GPS location to Firebase | ✗ | ✓ (via ESP32 firmware) |
| Switch map engine | ✓ | ✓ |
| View bearing / ETA to vehicle | ✓ | ✗ |
| Trigger siren indicator | ✗ | ✓ (via ESP32 firmware flag) |

#### Edge Case Handling
| Scenario | Handling |
|---|---|
| GPS permission denied | Falls back to LocationService.defaultLocation (New York, 40.7128, -74.0060) |
| Firebase node returns null | The body was checked for 'null' string, endpoint skipped |
| Firebase node has no timestamp | Payload hash change detection used as freshness signal |
| Device speed = 0 in ETA calc | Defaults to 40.0 km/h for ETA to prevent division-edge cases. |
| isSharing = false in Firebase | Device parsed but excluded from activeDevices list |
| hasValidLocation = false | Lat/Lng out of valid range—device excluded from active list |
| Notification re-trigger on same device | _notifiedDeviceIds set prevents duplicate alerts during same proximity session |

---

### 7. Current Version Features (v1.0.0)
#### Scope & Deliverables
The v1.0.0+1 release delivers a fully functional emergency vehicle receiver application:
* ✓ Real-time ambulance position tracking via Firebase RTDB REST polling (3-second cadence)
* ✓ 500m geofence with crimson visual alert banner and animated warning icon
* ✓ High-priority local push notifications on geofence entry (Android 13+ heads-up, iOS time-sensitive)
* ✓ Smooth marker movement via linear interpolation (lerp at 0.4 factor per 1-second tick)
* ✓ Dead reckoning spherical extrapolation during signal dropout
* ✓ Google Maps and OpenStreetMap dual-engine with runtime switching
* ✓ Auto-deletion of stale Firebase nodes after 10-second silence
* ✓ Bearing, cardinal direction, distance, and ETA display for selected target
* ✓ Animated splash screen with flutter_animate fade/scale effects
* ✓ GitHub Actions CI/CD for unsigned iOS IPA generation

#### MVP Boundaries (Deferred to v1.1+)
* ✗ User onboarding / role selection screen (app currently defaults to receiverUser role)
* ✗ Multiple simultaneous target selection / lock
* ✗ Route corridor display (polyline from ambulance’s origin to destination)
* ✗ Offline tile caching for OSM
* ✗ Firebase authentication (currently unauthenticated public RTDB)
* ✗ Android background service (app must be in foreground or recent for polling to continue)

#### Platform & Performance Constraints
| Constraint | Detail |
|---|---|
| Firebase poll interval | 6 seconds (HTTP GET) — not WebSocket streaming |
| Dead reckoning cap | 120 seconds maximum extrapolation window |
| Notification deduplication | One notification per device per proximity session |
| Background polling | Not guaranteed on battery-saver mode on Android; no foreground service in v1.0 |
| iOS background | Timer-based polling may be throttled by iOS background app refresh limits |

---

### 8. UI/UX Documentation
#### Design System
**Color Tokens**
| Token Name | Hex Value | Usage |
|---|---|---|
| skyBluePrimary | #0284C7 | Primary brand color, markers, borders, badges |
| crimson emergency | #DC2626 | Emergency alert banner, emergency vehicle markers |
| emerald primary | #059669 | Re-center FAB icon |
| surfaceBase | #F8FAFC | Scaffold background, AppBar background |
| textDark | #0F172A | Primary text, app title |
| textMuted | #64748B | Secondary text, subtitles |

**Typography**
* Splash title: “LifeLane Alert" (32sp, w900, #0F172A)
* AppBar title (17sp, bold, #0F172A)
* Emergency alert banner headline (13sp, w900, White)

#### Navigation Patterns
**App Launch**
```
    └─ main() → LifeLaneAlertApp
          └─ Consumer<LocationProvider> (isInitialized check)
                └─ SplashScreen (2200ms delay)
                      └─ Navigator.pushReplacement → ReceiverScreen
```
The navigation stack is intentionally flat—only two screens, no back navigation. `ReceiverScreen` is the permanent root.

---

### 9. User Workflows
#### Workflow 1: App Launch & Initialization
* Open the app—permissions for location and notifications are requested automatically
* Splash screen appears for about 2 seconds while the app fetches live device data
* Live map loads, centered on your location with the 500m geofence already drawn

#### Workflow 2: Real-Time Emergency Vehicle Tracking
* The app checks for nearby emergency vehicles every 3 seconds
* Each vehicle’s position, distance, and ETA are recalculated automatically
* Markers glide smoothly between updates instead of jumping
* If a vehicle comes within 500m, you get a high-priority alert instantly

#### Workflow 3: Dead Reckoning During Signal Dropout
* 0–10 seconds of silence—the app estimates the vehicle’s position using its last known speed and heading
* 10+ seconds of silence—the vehicle is treated as offline and its marker is removed automatically

---

### 10. Step-by-Step Instructions
#### User Onboarding & First-Time Setup
1. Install the LifeLane Alert APK (Android) or IPA (iOS sideload)
2. Launch the app—the splash screen shows “Initializing Live Emergency Map…”
3. Grant Location Permission.
4. Grant Notification Permission.
5. App is ready.

---

### 11. Troubleshooting
#### Common Issues, Root Causes & Resolutions
| Symptom | Root Cause | Resolution |
|---|---|---|
| Map stuck at New York (40.71, -74.00) | Location permission denied or GPS disabled | Tap ALLOW banner → grant permission → restart app |
| No ambulance markers on the map. | Firebase RTDB empty, or all nodes were auto-deleted (stale >10s) | Verify ESP32 hardware is powered and publishing; check RTDB endpoints in the browser. |
| Ambulance markers not moving smoothly | 1-second tick timer being throttled by OS battery saver | Disable battery optimization for LifeLane Alert in device settings |
| 500m notification not appearing | Android notification permission denied, or POST_NOTIFICATIONS not granted | Settings → Apps → LifeLane Alert → Notifications → Enable All |
| App crashes on startup (Android) | Missing Google Maps API key or key misconfigured | Verify com.google.android.geo.API_KEY in AndroidManifest.xml |

---

### 12. Technical Architecture
#### Data Flow & State Management
State Management Pattern: `LocationProvider` extends `ChangeNotifier` (Provider package). Single provider registered at the root. All state mutations call `notifyListeners()`. `ReceiverScreen` uses `Provider.of<LocationProvider>(context)` with listen: true.

#### Storage Schema
SharedPreferences Keys:
* `lifelane_username`
* `lifelane_user_role`
* `lifelane_user_id`
* `lifelane_first_launch`

---

### 13. Source Code Documentation
#### Annotated Directory Tree
```
d:\Lifelane\
├── lib/
│   ├── main.dart # App entry point, theme config, root Provider setup
│   ├── models/
│   │   ├── tracker_device_model.dart # TrackerDevice entity + fromFirebase() parser + dead reckoning
│   │   └── user_model.dart # UserRole enum + SharingUser model (for future sender role)
│   ├── providers/
│   │   └── location_provider.dart # Central ChangeNotifier: GPS, Firebase sync, geofence, timers
│   ├── screens/
│   │   ├── splash_screen.dart # Animated 2200ms splash → ReceiverScreen navigation
│   │   └── receiver_screen.dart # Main UI: dual map engine, markers, alert banner, FABs
│   └── services/
│       ├── firebase_service.dart # Firebase RTDB REST client + signal tracker + auto-delete
│       ├── location_service.dart # Geolocator wrapper: permission check + GPS fix
│       ├── notification_service.dart # Singleton: FlutterLocalNotifications init + proximity alerts
│       ├── sharing_hub_service.dart # Lerp engine, distance/bearing/ETA calculation, 500m filter
│       └── storage_service.dart # SharedPreferences CRUD: userId, userRole, username, firstLaunch
```

---

### 14. Development Environment & Versions
#### Prerequisites & Tooling
* Flutter SDK >=3.12.2 (stable channel)
* Dart SDK ^3.12.2
* Java JDK 17 (Zulu)
* Android SDK API 34

---

### 15. Build & Deployment
#### Local Compilation Commands
```bash
# Install all dependencies
flutter pub get

# Run on connected device/emulator (debug mode, hot reload)
flutter run

# Build Android debug APK
flutter build apk --debug

# Build Android release APK 
flutter build apk --release
```

---

### 16. Configuration & Environment Setup
#### Environment Variables / Configuration Keys
* **Google Maps API Key**: `android/app/src/main/AndroidManifest.xml`
* **Firebase RTDB Base URL**: `lib/services/firebase_service.dart`

---

### 17. Testing & Validation
#### Test Execution Commands
```bash
# Run all unit + widget tests
flutter test

# Run with coverage
flutter test --coverage
```

---

### 18. Next Version / Future Scope
#### Product Roadmap
**v1.1 — Enhanced Reliability & UX**
* Android Foreground Service (Implemented)
* Firebase Authentication
* Multiple Target Lock

---

### 19. Maintenance & Support
*(This section was truncated by the chat system—please copy-paste the remainder of Section 19 here!)*

---

### 20. Hardware Firmware Documentation (ESP32-S3)
*(This section was truncated by the chat system—please copy-paste the remainder of Section 20 here!)*

