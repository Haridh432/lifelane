import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'firebase_options.dart';
import 'providers/location_provider.dart';
import 'screens/splash_screen.dart';
import 'services/background_service.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // If you're going to use other Firebase services in the background, such as Firestore,
  // make sure you call `initializeApp` before using other Firebase services.
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint("Handling a background message: ${message.messageId}");
}

/// Entry Point for LifeLane Alert Mobile Application
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    await initializeBackgroundService();
  } catch (e) {
    debugPrint("Firebase initialization failed (please run flutterfire configure): $e");
  }

  // Dark status bar icons for clean light theme
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  runApp(
    ChangeNotifierProvider(
      create: (_) => LocationProvider()..initialize(),
      child: const LifeLaneAlertApp(),
    ),
  );
}

/// Root Application Widget configured with Vibrant Clean Light Theme
class LifeLaneAlertApp extends StatelessWidget {
  const LifeLaneAlertApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LifeLane Alert - Emergency Receiver & 500m Geofence',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0284C7), // Sky Blue / Cyan
          primary: const Color(0xFF0284C7),
          secondary: const Color(0xFFDC2626), // Emergency Crimson
          surface: Colors.white,
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
        appBarTheme: const AppBarTheme(
          centerTitle: false,
          elevation: 0,
          backgroundColor: Color(0xFFF8FAFC),
          foregroundColor: Color(0xFF0F172A),
        ),
      ),
      home: Consumer<LocationProvider>(
        builder: (context, provider, child) {
          if (!provider.isInitialized) {
            return const Scaffold(
              backgroundColor: Color(0xFFF8FAFC),
              body: Center(
                child: CircularProgressIndicator(color: Color(0xFF0284C7)),
              ),
            );
          }

          return const SplashScreen();
        },
      ),
    );
  }
}
