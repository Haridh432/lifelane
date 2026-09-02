import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../firebase_options.dart';
import 'location_service.dart';
import 'sharing_hub_service.dart';
import 'notification_service.dart';
import 'storage_service.dart';

Future<void> initializeBackgroundService() async {
  final service = FlutterBackgroundService();

  // MUST create the notification channel manually before configuring the service
  // Otherwise Android throws "Bad notification for startForeground"
  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'lifelane_alerts', // id
    'LifeLane Background Service', // title
    description: 'This channel is used for maintaining the background location engine.', // description
    importance: Importance.low, // importance must be at low or higher level
  );

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      autoStart: false,
      isForegroundMode: true,
      notificationChannelId: 'lifelane_alerts',
      initialNotificationTitle: 'LifeLane Alert',
      initialNotificationContent: 'Monitoring 500m geofence in background',
      foregroundServiceNotificationId: 888,
      foregroundServiceTypes: [AndroidForegroundType.location],
    ),
    iosConfiguration: IosConfiguration(
      autoStart: false,
      onForeground: onStart,
    ),
  );
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  // Initialize plugins for background isolate
  WidgetsFlutterBinding.ensureInitialized();
  // DartPluginRegistrant is no longer needed in modern Flutter and causes fatal SIGSEGV crashes on MIUI when run in background isolates.
  
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  } catch (e) {
    debugPrint("Firebase already initialized in background: $e");
  }

  if (service is AndroidServiceInstance) {
    service.on('setAsForeground').listen((event) {
      service.setAsForegroundService();
    });
    service.on('setAsBackground').listen((event) {
      service.setAsBackgroundService();
    });
  }
  service.on('stopService').listen((event) {
    service.stopSelf();
  });

  // Services instantiated outside the timer to maintain state (e.g. cooldowns)
  final hubService = SharingHubService();
  final notificationService = NotificationService();
  await notificationService.initialize();

  DateTime lastQueryTime = DateTime.fromMillisecondsSinceEpoch(0);

  // Run continuous tracking loop every 10 seconds
  Timer.periodic(const Duration(seconds: 10), (timer) async {
    try {
      // 1. Ensure we have location permissions in background
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        return;
      }

      // 2. Fetch Live Location safely (fallback to last known if GPS is slow/indoors)
      Position? pos;
      try {
        pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 5),
        );
      } catch (_) {
        pos = await Geolocator.getLastKnownPosition();
      }
      
      if (pos == null) return;
      
      final LatLng currentPosition = LatLng(pos.latitude, pos.longitude);

      lastQueryTime = DateTime.now();

      // 3. Query Firebase RTDB for active ESP32 devices
      double radius = await StorageService.getGeofenceRadius();
      final devices = await hubService.syncTrackerDevices(currentPosition, radius);

      // 4. Trigger notifications if within 500m
      await notificationService.processProximityAlerts(devices, hubService.formatDistance);

      // Optional: Update foreground notification to show it is active
      if (service is AndroidServiceInstance) {
        if (await service.isForegroundService()) {
          final devices500m = hubService.getDevicesWithin500m();
          String content = devices500m.isNotEmpty 
              ? 'WARNING: ${devices500m.length} vehicle(s) nearby!'
              : 'Tracking your 500m geofence in background';
              
          service.setForegroundNotificationInfo(
            title: "LifeLane is active",
            content: content,
          );
        }
      }
    } catch (e) {
      debugPrint("Background Tracking Error: $e");
    }
  });
}
