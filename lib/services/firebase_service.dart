import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../models/tracker_device_model.dart';

/// Tracks last signal timestamp and payload state for a Firebase node
class _SignalTracker {
  final String path;
  final DateTime firstSeen;
  DateTime lastSignalTime;
  String lastPayloadHash;

  _SignalTracker({
    required this.path,
    required this.firstSeen,
    required this.lastSignalTime,
    required this.lastPayloadHash,
  });
}

/// Firebase Realtime Database Service
class FirebaseService {
  /// Firebase Realtime Database Base URL
  static const String databaseUrl =
      'https://locationsharing-1a5bc-default-rtdb.asia-southeast1.firebasedatabase.app';

  /// Monitored Firebase RTDB endpoints
  static const List<String> monitoredEndpoints = [
    '$databaseUrl/devices.json',
    '$databaseUrl/Lifelane/Users.json',
    '$databaseUrl/Users.json',
  ];

  /// In-memory tracker for signal freshness across poll cycles
  static final Map<String, _SignalTracker> _signalTrackers = {};

  /// Automatically delete a node directly from Firebase Realtime Database
  static Future<bool> deleteDeviceFromFirebase(String relativePath) async {
    try {
      final String cleanPath = relativePath.startsWith('/')
          ? relativePath.substring(1)
          : relativePath;
      final Uri deleteUrl = Uri.parse('$databaseUrl/$cleanPath.json');
      final response =
          await http.delete(deleteUrl).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200 || response.statusCode == 204) {
        debugPrint(
            '[FirebaseService] Successfully auto-deleted stale node from Firebase: $cleanPath');
        return true;
      }
    } catch (e) {
      debugPrint('[FirebaseService] Error deleting stale node $relativePath: $e');
    }
    return false;
  }

  /// Fetch active GPS hardware trackers & user locations from Firebase RTDB.
  /// Automatically DELETES nodes from Firebase and App if no data signals are received for >= 10 seconds.
  static Future<List<TrackerDevice>> fetchTrackerDevices() async {
    final List<TrackerDevice> activeDevices = [];
    final Set<String> currentSeenPaths = {};
    final DateTime now = DateTime.now();

    for (final endpoint in monitoredEndpoints) {
      try {
        final Uri url = Uri.parse(endpoint);
        final response =
            await http.get(url).timeout(const Duration(seconds: 6));

        if (response.statusCode != 200 ||
            response.body.isEmpty ||
            response.body == 'null') {
          continue;
        }

        final dynamic decoded = json.decode(response.body);
        if (decoded is! Map<String, dynamic>) {
          continue;
        }

        // Determine parent path (e.g. "devices", "Lifelane/Users", "Users")
        final Uri parsedEndpoint = Uri.parse(endpoint);
        String parentPath = parsedEndpoint.path;
        if (parentPath.endsWith('.json')) {
          parentPath = parentPath.substring(0, parentPath.length - 5);
        }
        if (parentPath.startsWith('/')) {
          parentPath = parentPath.substring(1);
        }

        decoded.forEach((key, value) {
          if (value is Map) {
            final String fullPath = '$parentPath/$key';
            currentSeenPaths.add(fullPath);

            final Map<String, dynamic> map =
                Map<String, dynamic>.from(value);
            final String payloadHash = jsonEncode(map);

            // Extract explicit timestamp from Firebase node if available
            DateTime? explicitTimestamp;
            final dynamic tsVal =
                map['Timestamp'] ?? map['timestamp'] ?? map['lastUpdated'];
            if (tsVal != null) {
              if (tsVal is int) {
                if (tsVal > 100000000000) {
                  explicitTimestamp =
                      DateTime.fromMillisecondsSinceEpoch(tsVal);
                } else if (tsVal > 100000000) {
                  explicitTimestamp =
                      DateTime.fromMillisecondsSinceEpoch(tsVal * 1000);
                }
              } else {
                try {
                  explicitTimestamp = DateTime.parse(tsVal.toString());
                } catch (_) {}
              }
            }

            _SignalTracker? tracker = _signalTrackers[fullPath];
            if (tracker == null) {
              tracker = _SignalTracker(
                path: fullPath,
                firstSeen: now,
                lastSignalTime: explicitTimestamp ?? now,
                lastPayloadHash: payloadHash,
              );
              _signalTrackers[fullPath] = tracker;
            } else {
              if (explicitTimestamp != null) {
                tracker.lastSignalTime = explicitTimestamp;
              } else if (payloadHash != tracker.lastPayloadHash) {
                // New location data payload received!
                tracker.lastSignalTime = now;
                tracker.lastPayloadHash = payloadHash;
              }
            }

            final int elapsedSeconds =
                now.difference(tracker.lastSignalTime).inSeconds;

            // --- 10-SECOND SIGNAL DROPOUT AUTOMATIC DELETION ---
            if (elapsedSeconds >= 10) {
              debugPrint(
                  '[FirebaseService] No data signal received from $fullPath for $elapsedSeconds seconds. Deleting from Firebase & App...');
              // 1. Auto-delete node from Firebase RTDB
              deleteDeviceFromFirebase(fullPath);
              // 2. Remove signal tracker entry
              _signalTrackers.remove(fullPath);
              // 3. Skip adding to activeDevices (Auto-deleted from App UI)
              return;
            }

            try {
              final TrackerDevice device =
                  TrackerDevice.fromFirebase(key, map);

              if (device.hasValidLocation && device.isSharing) {
                activeDevices.add(device);
              }
            } catch (e) {
              debugPrint('Error parsing device $key at $fullPath: $e');
            }
          }
        });
      } catch (e) {
        debugPrint('Firebase fetch error for $endpoint: $e');
      }
    }

    // Clean up trackers for nodes that no longer exist in Firebase
    _signalTrackers
        .removeWhere((path, tracker) => !currentSeenPaths.contains(path));

    return activeDevices;
  }
}
