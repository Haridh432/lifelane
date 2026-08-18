import 'dart:async';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../models/user_model.dart';
import '../models/tracker_device_model.dart';
import '../services/storage_service.dart';
import '../services/location_service.dart';
import '../services/sharing_hub_service.dart';
import '../services/notification_service.dart';

/// State Manager for LifeLane Alert managing local user GPS, real-time ESP32 RTDB hardware sync, Dead Reckoning extrapolation, and user 500m Geofence alerts
class LocationProvider extends ChangeNotifier {
  final SharingHubService _hubService = SharingHubService();
  final NotificationService _notificationService = NotificationService();

  UserRole _userRole = UserRole.receiverUser;
  String _userId = '';
  bool _isInitialized = false;
  bool _hasLocationPermission = false;

  bool _isTrackingActive = true;
  bool _isSharing = false;
  bool _isSirenActive = true;

  LatLng _currentPosition = LocationService.defaultLocation;
  double _currentSpeed = 0.0;
  double _currentAccuracy = 5.0;
  DateTime? _lastUpdated;

  Timer? _updateTimer;
  Timer? _tickTimer;

  TrackerDevice? _selectedTarget;
  bool _isProximityAlertActive = false;

  // Getters
  UserRole get userRole => _userRole;
  String get userId => _userId;
  bool get isInitialized => _isInitialized;
  bool get hasLocationPermission => _hasLocationPermission;
  bool get isSharing => _isSharing;
  bool get isTrackingActive => _isTrackingActive;
  bool get isSirenActive => _isSirenActive;

  LatLng get currentPosition => _currentPosition;
  double get currentSpeed => _currentSpeed;
  double get currentAccuracy => _currentAccuracy;
  DateTime? get lastUpdated => _lastUpdated;

  List<TrackerDevice> get trackerDevices => _hubService.trackerDevices;
  List<TrackerDevice> get filteredActiveUsers => _hubService.trackerDevices;

  TrackerDevice? get selectedTarget => _selectedTarget;
  double? get distanceToTarget => _selectedTarget?.distanceFromUser;
  double? get bearingToTarget => _selectedTarget?.bearingFromUser;
  String? get cardinalDirection => _selectedTarget?.bearingFromUser != null
      ? _hubService.getCardinalDirection(_selectedTarget!.bearingFromUser!)
      : null;
  String? get etaToTarget => _selectedTarget?.eta;
  bool get isProximityAlertActive => _isProximityAlertActive;

  /// Hardware trackers currently within 500m radius of the user
  List<TrackerDevice> get devicesWithin500m => _hubService.getDevicesWithin500m();

  String get formattedDistanceToTarget {
    if (distanceToTarget == null) return '--';
    return _hubService.formatDistance(distanceToTarget!);
  }

  /// Initialize application state, location permissions, & push notifications
  Future<void> initialize() async {
    _userId = await StorageService.getOrCreateUserId();
    final role = await StorageService.getUserRole();
    if (role != null) _userRole = role;

    // Request location permission on startup
    await requestLocationPermission();

    // Initialize local notification service
    await _notificationService.initialize();

    // Perform initial fetch of ESP32 trackers from Firebase RTDB
    await _performPeriodicUpdate();

    // Start real-time sync loop
    startTracking();

    _isInitialized = true;
    notifyListeners();
  }

  /// Explicitly request location permission
  Future<bool> requestLocationPermission() async {
    _hasLocationPermission = await LocationService.checkAndRequestPermission();
    if (_hasLocationPermission) {
      await fetchLocation();
    }
    notifyListeners();
    return _hasLocationPermission;
  }

  /// Set application role
  Future<void> setUserRole(UserRole role) async {
    _userRole = role;
    await StorageService.saveUserRole(role);
    await StorageService.completeFirstLaunch();
    notifyListeners();
  }

  /// Toggle siren indicator locally
  void toggleSiren() {
    _isSirenActive = !_isSirenActive;
    notifyListeners();
  }

  /// Select specific ESP32 tracker device for camera targeting
  void selectTargetDevice(TrackerDevice device) {
    _selectedTarget = device;
    notifyListeners();
  }

  /// Select target user wrapper for backwards compatibility
  void selectTargetUser(dynamic user) {
    if (user is TrackerDevice) {
      selectTargetDevice(user);
    }
  }

  /// Fetch single location fix locally from device GPS
  Future<void> fetchLocation() async {
    Position? pos = await LocationService.getCurrentPosition();
    if (pos != null) {
      _currentPosition = LocationService.positionToLatLng(pos);
      _currentSpeed = (pos.speed * 3.6);
      _currentAccuracy = pos.accuracy;
      _lastUpdated = DateTime.now();
      _hasLocationPermission = true;
    } else {
      _lastUpdated = DateTime.now();
    }
    notifyListeners();
  }

  /// Enable Start Tracking
  Future<void> startSharing() async {
    _isSharing = true;
    _isTrackingActive = true;
    startTracking();
    notifyListeners();
  }

  /// Disable Stop Tracking
  Future<void> stopSharing() async {
    _isSharing = false;
    notifyListeners();
  }

  /// Start periodic sync loop (Fetches active ESP32 hardware locations from Firebase RTDB & updates local user 500m geofence)
  void startTracking() {
    _isTrackingActive = true;
    _updateTimer?.cancel();
    _tickTimer?.cancel();

    // Initial update
    _performPeriodicUpdate();

    // Poll Firebase RTDB every 3 seconds for continuous real-time ESP32 hardware updates
    _updateTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      _performPeriodicUpdate();
    });

    // Run 1-second ticker for smooth Dead Reckoning vector extrapolation during >10s signal delays
    _tickTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_isTrackingActive) {
        final updatedDevices = _hubService.tickExtrapolation(_currentPosition);
        _updateTargetSelection(updatedDevices);
        notifyListeners();
      }
    });

    notifyListeners();
  }

  /// Stop periodic sync loop
  void stopTracking() {
    _isTrackingActive = false;
    _updateTimer?.cancel();
    _tickTimer?.cancel();
    _updateTimer = null;
    _tickTimer = null;
    notifyListeners();
  }

  /// Internal periodic update step - reads ESP32 hardware from Firebase RTDB & computes 500m user geofence
  Future<void> _performPeriodicUpdate() async {
    // 1. Fetch current local device location via Geolocator
    Position? pos = await LocationService.getCurrentPosition();
    if (pos != null) {
      _currentPosition = LocationService.positionToLatLng(pos);
      _currentSpeed = (pos.speed * 3.6);
      _currentAccuracy = pos.accuracy;
      _hasLocationPermission = true;
    }
    _lastUpdated = DateTime.now();

    // 2. Read active ESP32 hardware trackers under /devices.json on Firebase RTDB (100% read-only)
    final devices = await _hubService.syncTrackerDevices(_currentPosition);

    // 3. Detect if ANY ESP32 tracker is within 500 meters of the user
    final devices500m = _hubService.getDevicesWithin500m();
    _isProximityAlertActive = devices500m.isNotEmpty;

    // 4. Trigger local push notification when an emergency vehicle enters 500m radius of the user
    await _notificationService.processProximityAlerts(devices, _hubService.formatDistance);

    // 5. Update active target selection (defaults to nearest approaching device)
    _updateTargetSelection(devices);

    notifyListeners();
  }

  void _updateTargetSelection(List<TrackerDevice> devices) {
    if (devices.isEmpty) {
      _selectedTarget = null;
      return;
    }

    if (_selectedTarget != null) {
      final updated = devices.firstWhere(
        (d) => d.id == _selectedTarget!.id,
        orElse: () => _hubService.getNearestDevice() ?? devices.first,
      );
      _selectedTarget = updated;
    } else {
      _selectedTarget = _hubService.getNearestDevice() ?? devices.first;
    }
  }

  @override
  void dispose() {
    _updateTimer?.cancel();
    _tickTimer?.cancel();
    super.dispose();
  }
}
