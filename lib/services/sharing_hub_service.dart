import 'dart:math';
import 'package:latlong2/latlong.dart';
import '../models/tracker_device_model.dart';
import 'firebase_service.dart';

/// Lerp state tracking smooth real-time marker movement
class _PositionLerpState {
  double currentLat;
  double currentLng;
  double targetLat;
  double targetLng;

  _PositionLerpState({
    required this.currentLat,
    required this.currentLng,
    required this.targetLat,
    required this.targetLng,
  });
}

/// Central Hub Service managing ESP32 hardware tracker synchronization, local distance calculations, and smooth real-time marker movement
class SharingHubService {
  final Distance _distanceCalculator = const Distance();
  final Map<String, _PositionLerpState> _lerpStates = {};

  // Active ESP32 hardware trackers synced from Firebase RTDB (/devices)
  List<TrackerDevice> _trackerDevices = [];

  List<TrackerDevice> get trackerDevices => List.unmodifiable(_trackerDevices);

  /// Synchronize real ESP32 hardware trackers from Firebase Realtime Database
  Future<List<TrackerDevice>> syncTrackerDevices(LatLng userLocation, double radiusMeters) async {
    final fetched = await FirebaseService.fetchTrackerDevices();
    final Set<String> activeIds = {};

    _trackerDevices = fetched.map((device) {
      activeIds.add(device.id);

      _PositionLerpState? lerp = _lerpStates[device.id];
      if (lerp == null) {
        lerp = _PositionLerpState(
          currentLat: device.latitude,
          currentLng: device.longitude,
          targetLat: device.latitude,
          targetLng: device.longitude,
        );
        _lerpStates[device.id] = lerp;
      } else {
        // Set target coordinates for smooth real-time marker movement
        lerp.targetLat = device.latitude;
        lerp.targetLng = device.longitude;
      }

      // Smooth position interpolation step
      lerp.currentLat += (lerp.targetLat - lerp.currentLat) * 0.4;
      lerp.currentLng += (lerp.targetLng - lerp.currentLng) * 0.4;

      final deviceLatLng = LatLng(lerp.currentLat, lerp.currentLng);
      final double distMeters = calculateDistanceMeters(userLocation, deviceLatLng);
      final double bearing = calculateBearing(userLocation, deviceLatLng);
      final String etaStr = calculateETA(distMeters, device.speed);
      final bool isWithinGeofence = distMeters <= radiusMeters;

      return device.copyWithMetrics(
        latitude: lerp.currentLat,
        longitude: lerp.currentLng,
        distanceFromUser: distMeters,
        bearingFromUser: bearing,
        eta: etaStr,
        isWithin500m: isWithinGeofence,
        isExtrapolated: false,
      );
    }).toList();

    // Remove lerp states for auto-deleted/removed devices
    _lerpStates.removeWhere((id, state) => !activeIds.contains(id));

    return trackerDevices;
  }

  /// Update marker positions smoothly during 1-second ticks
  List<TrackerDevice> tickExtrapolation(LatLng userLocation, double radiusMeters) {
    if (_trackerDevices.isEmpty) return _trackerDevices;

    _trackerDevices = _trackerDevices.map((device) {
      final lerp = _lerpStates[device.id];
      if (lerp != null) {
        final double latDiff = (lerp.targetLat - lerp.currentLat).abs();
        final double lngDiff = (lerp.targetLng - lerp.currentLng).abs();

        if (latDiff > 0.000001 || lngDiff > 0.000001) {
          lerp.currentLat += (lerp.targetLat - lerp.currentLat) * 0.4;
          lerp.currentLng += (lerp.targetLng - lerp.currentLng) * 0.4;
        } else {
          lerp.currentLat = lerp.targetLat;
          lerp.currentLng = lerp.targetLng;
        }

        final deviceLatLng = LatLng(lerp.currentLat, lerp.currentLng);
        final double distMeters = calculateDistanceMeters(userLocation, deviceLatLng);
        final double bearing = calculateBearing(userLocation, deviceLatLng);
        final String etaStr = calculateETA(distMeters, device.speed);
        final bool isWithinGeofence = distMeters <= radiusMeters;

        return device.copyWithMetrics(
          latitude: lerp.currentLat,
          longitude: lerp.currentLng,
          distanceFromUser: distMeters,
          bearingFromUser: bearing,
          eta: etaStr,
          isWithin500m: isWithinGeofence,
        );
      }
      return device;
    }).toList();

    return trackerDevices;
  }

  /// Get list of hardware trackers currently inside 500m radius of the user
  List<TrackerDevice> getDevicesWithin500m() {
    return _trackerDevices.where((d) => d.isWithin500m).toList();
  }

  /// Get closest hardware emergency vehicle to the user
  TrackerDevice? getNearestDevice() {
    if (_trackerDevices.isEmpty) return null;
    TrackerDevice nearest = _trackerDevices.first;
    for (final device in _trackerDevices) {
      if ((device.distanceFromUser ?? double.infinity) < (nearest.distanceFromUser ?? double.infinity)) {
        nearest = device;
      }
    }
    return nearest;
  }

  /// Calculate distance in meters between two coordinates
  double calculateDistanceMeters(LatLng from, LatLng to) {
    return _distanceCalculator.as(LengthUnit.Meter, from, to);
  }

  /// Calculate distance formatted string (e.g., "1.4 km" or "350 m")
  String formatDistance(double meters) {
    if (meters >= 1000) {
      return '${(meters / 1000).toStringAsFixed(1)} km';
    } else {
      return '${meters.toStringAsFixed(0)} m';
    }
  }

  /// Calculate bearing (direction in degrees 0..360) from standard coordinates
  double calculateBearing(LatLng start, LatLng end) {
    final double startLat = start.latitudeInRad;
    final double startLng = start.longitudeInRad;
    final double endLat = end.latitudeInRad;
    final double endLng = end.longitudeInRad;

    final double dLng = endLng - startLng;

    final double y = sin(dLng) * cos(endLat);
    final double x = cos(startLat) * sin(endLat) - sin(startLat) * cos(endLat) * cos(dLng);

    double brng = atan2(y, x);
    brng = brng * (180 / pi);
    return (brng + 360) % 360;
  }

  /// Convert bearing angle to cardinal direction (e.g. N, NE, E, SE, S, SW, W, NW)
  String getCardinalDirection(double bearing) {
    const directions = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];
    final index = ((bearing + 22.5) % 360 / 45).floor();
    return directions[index % 8];
  }

  /// Estimate travel / ETA time in minutes based on distance & speed
  String calculateETA(double meters, double speedKmH) {
    double speedMetersPerSec = (speedKmH > 5 ? speedKmH : 40.0) * 1000 / 3600;
    double seconds = meters / speedMetersPerSec;
    int minutes = (seconds / 60).round();
    if (minutes <= 1) return '< 1 min';
    return '$minutes mins';
  }
}
