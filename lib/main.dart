import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'providers/location_provider.dart';
import 'screens/splash_screen.dart';

/// Entry Point for LifeLane Alert Mobile Application
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

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
