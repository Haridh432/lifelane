import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Represents an ESP32 GPS Tracker Hardware Device (e.g., tracker001, tracker002)
class TrackerDevice {
  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final double speed; // in km/h
  final double heading; // 0..360 degrees
  final bool isSharing; // If false, location will NOT be shared with the app
  final bool isSirenActive;
  final DateTime lastUpdated;
  final String? dateString;
  final String? timeString;
  final dynamic rawTimestamp;
  final String? vehicleDetails;
  final Color markerColor;

  // Local calculated metrics (not stored in Firebase)
  final double? distanceFromUser; // in meters
  final double? bearingFromUser; // 0..360 degrees
  final String? eta;
  final bool isWithin500m;
  final bool isExtrapolated; // True when position is dead-reckoned due to signal delay >10s

  const TrackerDevice({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.speed,
    this.heading = 0.0,
    this.isSharing = true,
    this.isSirenActive = true,
    required this.lastUpdated,
    this.dateString,
    this.timeString,
    this.rawTimestamp,
    this.vehicleDetails,
    this.markerColor = const Color(0xFFEF4444), // Emergency Crimson
    this.distanceFromUser,
    this.bearingFromUser,
    this.eta,
    this.isWithin500m = false,
    this.isExtrapolated = false,
  });

  /// True if signal from Firebase is delayed by more than 10 seconds
  bool get isSignalStale =>
      DateTime.now().difference(lastUpdated).inSeconds > 10;

  /// Elapsed seconds since last valid Firebase GPS signal update
  int get signalDelaySeconds =>
      DateTime.now().difference(lastUpdated).inSeconds;

  /// Formatted Date display string
  String get displayDate =>
      dateString ?? DateFormat('yyyy-MM-dd').format(lastUpdated);

  /// Formatted Time display string
  String get displayTime =>
      timeString ?? DateFormat('HH:mm:ss').format(lastUpdated);

  /// Raw or formatted Timestamp display string
  String get displayTimestamp =>
      rawTimestamp?.toString() ?? '${lastUpdated.millisecondsSinceEpoch}';

  /// True if valid GPS coordinates
  bool get hasValidLocation =>
      latitude != 0.0 &&
      longitude != 0.0 &&
      latitude >= -90.0 &&
      latitude <= 90.0 &&
      longitude >= -180.0 &&
      longitude <= 180.0;

  /// Extrapolate predicted coordinates along direction vector (speed + heading) during signal loss
  Map<String, double> getPredictedLocation([DateTime? targetTime]) {
    final now = targetTime ?? DateTime.now();
    final elapsedSec = now.difference(lastUpdated).inSeconds;

    // Return exact location if signal is fresh (<= 10s) or vehicle is stationary
    if (elapsedSec <= 10 || speed <= 0.5) {
      return {'latitude': latitude, 'longitude': longitude};
    }

    // Dead Reckoning Vector Math along heading angle
    // Use effective speed (defaults to 40 km/h for emergency vehicle motion if last speed was 0)
    final double effectiveSpeed = speed > 0.5 ? speed : 40.0;
    final cappedElapsed = elapsedSec.clamp(3, 120);
    final distanceMeters = (effectiveSpeed / 3.6) * cappedElapsed;

    const double earthRadius = 6371000.0; // Earth radius in meters
    final double latRad = latitude * (math.pi / 180.0);
    final double lngRad = longitude * (math.pi / 180.0);
    final double headingRad = heading * (math.pi / 180.0);
    final double angularDist = distanceMeters / earthRadius;

    final double predLatRad = math.asin(
      math.sin(latRad) * math.cos(angularDist) +
          math.cos(latRad) * math.sin(angularDist) * math.cos(headingRad),
    );

    final double predLngRad = lngRad +
        math.atan2(
          math.sin(headingRad) * math.sin(angularDist) * math.cos(latRad),
          math.cos(angularDist) - math.sin(latRad) * math.sin(predLatRad),
        );

    final double predLat = predLatRad * (180.0 / math.pi);
    final double predLng = predLngRad * (180.0 / math.pi);

    return {'latitude': predLat, 'longitude': predLng};
  }

  /// Copy with updated computed metrics & optional dead reckoning prediction
  TrackerDevice copyWithMetrics({
    double? latitude,
    double? longitude,
    double? distanceFromUser,
    double? bearingFromUser,
    String? eta,
    bool? isWithin500m,
    bool? isExtrapolated,
  }) {
    return TrackerDevice(
      id: id,
      name: name,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      speed: speed,
      heading: heading,
      isSharing: isSharing,
      isSirenActive: isSirenActive,
      lastUpdated: lastUpdated,
      dateString: dateString,
      timeString: timeString,
      rawTimestamp: rawTimestamp,
      vehicleDetails: vehicleDetails,
      markerColor: markerColor,
      distanceFromUser: distanceFromUser ?? this.distanceFromUser,
      bearingFromUser: bearingFromUser ?? this.bearingFromUser,
      eta: eta ?? this.eta,
      isWithin500m: isWithin500m ?? this.isWithin500m,
      isExtrapolated: isExtrapolated ?? this.isExtrapolated,
    );
  }

  /// Parse Firebase RTDB JSON node into TrackerDevice model
  factory TrackerDevice.fromFirebase(String deviceId, Map<String, dynamic> rawMap) {
    // Hardware payload can be under 'current' node or flat
    final Map<String, dynamic> map = rawMap.containsKey('current') && rawMap['current'] is Map
        ? Map<String, dynamic>.from(rawMap['current'] as Map)
        : rawMap;

    // Helper to safely parse doubles from num or String
    double parseDouble(dynamic val, [double fallback = 0.0]) {
      if (val == null) return fallback;
      if (val is num) return val.toDouble();
      return double.tryParse(val.toString()) ?? fallback;
    }

    // Helper to safely parse bool
    bool parseBool(dynamic val, [bool fallback = false]) {
      if (val == null) return fallback;
      if (val is bool) return val;
      if (val is num) return val == 1;
      final str = val.toString().toLowerCase();
      return str == 'true' || str == '1' || str == 'active' || str == 'on';
    }

    final double lat = parseDouble(map['latitude'] ?? map['Latitude'] ?? map['lat'] ?? map['Lat']);
    final double lng = parseDouble(map['longitude'] ?? map['Longitude'] ?? map['lng'] ?? map['Lng'] ?? map['lon']);
    final double spd = parseDouble(map['Speed'] ?? map['speed'] ?? map['spd'], 0.0);
    final double hdg = parseDouble(map['heading'] ?? map['Heading'] ?? map['hdg'], 0.0);
    final bool sharing = map.containsKey('isSharing') ? parseBool(map['isSharing'], true) : true;
    final bool siren = parseBool(map['isSirenActive'] ?? map['siren'] ?? map['sirenActive'], true);

    final String? dateVal = map['Date']?.toString() ?? map['date']?.toString();
    final String? timeVal = map['Time']?.toString() ?? map['time']?.toString();
    final dynamic timestampVal = map['Timestamp'] ?? map['timestamp'] ?? map['lastUpdated'];

    DateTime timestamp = DateTime.now();
    if (timestampVal != null) {
      if (timestampVal is int) {
        if (timestampVal > 100000000000) {
          timestamp = DateTime.fromMillisecondsSinceEpoch(timestampVal);
        } else if (timestampVal > 100000000) {
          timestamp = DateTime.fromMillisecondsSinceEpoch(timestampVal * 1000);
        }
      } else {
        try {
          timestamp = DateTime.parse(timestampVal.toString());
        } catch (_) {}
      }
    }

    final String name = map['name'] as String? ??
        map['Name'] as String? ??
        map['username'] as String? ??
        map['Username'] as String? ??
        map['vehicleName'] as String? ??
        (deviceId.toLowerCase() == 'tracker001'
            ? 'Emergency Ambulance #001'
            : deviceId.toLowerCase() == 'tracker002'
                ? 'Emergency Ambulance #002'
                : deviceId);

    final String vehicleDetails = map['vehicleDetails'] as String? ??
        map['vehicleUnitNumber'] as String? ??
        map['unit'] as String? ??
        'Unit ID: $deviceId';

    return TrackerDevice(
      id: deviceId,
      name: name,
      latitude: lat,
      longitude: lng,
      speed: spd,
      heading: hdg,
      isSharing: sharing,
      isSirenActive: siren,
      lastUpdated: timestamp,
      dateString: dateVal,
      timeString: timeVal,
      rawTimestamp: timestampVal,
      vehicleDetails: vehicleDetails,
      markerColor: const Color(0xFFEF4444),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'Date': displayDate,
      'Time': displayTime,
      'Timestamp': displayTimestamp,
      'latitude': latitude,
      'longitude': longitude,
      'Speed': speed,
      'heading': heading,
      'isSharing': isSharing,
      'isSirenActive': isSirenActive,
      'lastUpdated': lastUpdated.toIso8601String(),
      'vehicleDetails': vehicleDetails,
    };
  }
}
