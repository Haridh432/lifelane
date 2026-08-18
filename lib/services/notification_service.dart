import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../models/tracker_device_model.dart';

/// Notification Service handling system push notifications for LifeLane 500m Geofence Alerts (Foreground & Background Heads-Up)
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;

  // Track devices that have already triggered a notification while inside 500m
  final Set<String> _notifiedDeviceIds = {};

  /// Initialize local notification channels & background notification permissions
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      const DarwinInitializationSettings initializationSettingsDarwin =
          DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const InitializationSettings initializationSettings = InitializationSettings(
        android: initializationSettingsAndroid,
        iOS: initializationSettingsDarwin,
      );

      await _notifications.initialize(initializationSettings);

      // Request notification permissions explicitly for Android 13+
      final androidImplementation =
          _notifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (androidImplementation != null) {
        await androidImplementation.requestNotificationsPermission();
      }

      _isInitialized = true;
    } catch (e) {
      debugPrint('Notification Service Initialization Error: $e');
    }
  }

  /// Process list of tracker devices and trigger alerts for any entering 500m radius
  Future<void> processProximityAlerts(List<TrackerDevice> devices, String Function(double) formatDistance) async {
    final Set<String> currentlyInsideIds = {};

    for (final device in devices) {
      if (device.isWithin500m && device.distanceFromUser != null) {
        currentlyInsideIds.add(device.id);

        // Notify if not already notified during this proximity session
        if (!_notifiedDeviceIds.contains(device.id)) {
          final distanceStr = formatDistance(device.distanceFromUser!);
          await showProximityAlertNotification(
            deviceId: device.id,
            deviceName: device.name,
            distanceText: distanceStr,
          );
          _notifiedDeviceIds.add(device.id);
        }
      }
    }

    // Reset notification state for devices that have moved outside 500m
    _notifiedDeviceIds.removeWhere((id) => !currentlyInsideIds.contains(id));
  }

  /// Trigger high-priority heads-up notification when an Emergency Tracker is within 500 meters
  Future<void> showProximityAlertNotification({
    required String deviceId,
    required String deviceName,
    required String distanceText,
  }) async {
    if (!_isInitialized) await initialize();

    try {
      const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        'lifelane_500m_channel',
        'Emergency Vehicle Alerts',
        channelDescription: 'Critical alerts when an emergency vehicle is within 500 meters',
        importance: Importance.max,
        priority: Priority.high,
        ticker: 'Emergency Vehicle Alert',
        color: Color(0xFFEF4444),
        enableVibration: true,
        playSound: true,
        fullScreenIntent: true,
        visibility: NotificationVisibility.public,
        category: AndroidNotificationCategory.alarm,
        audioAttributesUsage: AudioAttributesUsage.alarm,
      );

      const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentSound: true,
        presentBadge: true,
        interruptionLevel: InterruptionLevel.timeSensitive,
      );

      const NotificationDetails platformDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      final int notificationId = deviceId.hashCode.abs() % 10000;

      await _notifications.show(
        notificationId,
        '🚨 EMERGENCY VEHICLE NEARBY!',
        '$deviceName is $distanceText away from your location. Clear the road immediately!',
        platformDetails,
      );
    } catch (e) {
      debugPrint('Error triggering push notification: $e');
    }
  }
}
