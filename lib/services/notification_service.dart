import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../models/tracker_device_model.dart';

/// Notification Service handling system push notifications for LifeLane 500m Geofence Alerts (Foreground & Background Heads-Up)
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;

  /// Initialize local notification channels & background notification permissions
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/launcher_icon');

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
      
      // (Notification permissions are now exclusively requested by the UI in ReceiverScreen to prevent background isolate crashes)

      // FCM Integration Setup
      try {
        final messaging = FirebaseMessaging.instance;
        
        // (FCM permissions are exclusively requested by the UI, doing it here crashes the background isolate)
        
        final token = await messaging.getToken();
        debugPrint("[NotificationService] FCM Token: $token");

        // Listen for foreground FCM messages and display them locally
        FirebaseMessaging.onMessage.listen((RemoteMessage message) {
          if (message.notification != null) {
            _showForegroundFCMNotification(message.notification!);
          }
        });
      } catch (e) {
        debugPrint('[NotificationService] FCM setup error (likely missing configuration): $e');
      }

      _isInitialized = true;
    } catch (e) {
      debugPrint('Notification Service Initialization Error: $e');
    }
  }

  /// Process list of tracker devices and trigger alerts for any entering 500m radius
  Future<void> processProximityAlerts(List<TrackerDevice> devices, String Function(double) formatDistance) async {
    for (final device in devices) {
      if (device.isWithin500m && device.distanceFromUser != null) {
        final distanceStr = formatDistance(device.distanceFromUser!);
        await showProximityAlertNotification(
          deviceId: device.id,
          deviceName: device.name,
          distanceText: distanceStr,
        );
      }
    }
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

      // Use a dynamic time-based ID so Android treats each 10-second ping as a NEW alert rather than silently updating the old one
      final int notificationId = DateTime.now().millisecondsSinceEpoch.remainder(100000);

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

  /// Display an FCM notification while the app is in the foreground
  Future<void> _showForegroundFCMNotification(RemoteNotification notification) async {
    try {
      const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        'lifelane_fcm_channel',
        'FCM Push Alerts',
        channelDescription: 'Foreground alerts from Firebase Cloud Messaging',
        importance: Importance.max,
        priority: Priority.high,
        color: Color(0xFFEF4444),
        enableVibration: true,
        playSound: true,
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

      await _notifications.show(
        notification.hashCode,
        notification.title ?? '🚨 Lifelane Alert',
        notification.body ?? 'Emergency notification received.',
        platformDetails,
      );
    } catch (e) {
      debugPrint('Error showing FCM foreground notification: $e');
    }
  }
}
