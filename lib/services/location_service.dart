import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

/// Service managing device GPS location and Geolocator permissions
class LocationService {
  // Default fallback center (New York / Urban City Center) if GPS is disabled or running on desktop without location hardware
  static const LatLng defaultLocation = LatLng(40.7128, -74.0060);

  static Future<bool> checkAndRequestPermission() async {
    // Check permissions first, so the OS popup shows up regardless of GPS toggle state
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return false;
    }

    // Then check if the physical GPS is toggled on (but don't block the permission request above)
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // The user has given permission, but they need to turn on their GPS from the quick settings.
    }

    return true;
  }

  /// Get current GPS position with fallback
  static Future<Position?> getCurrentPosition() async {
    try {
      final hasPermission = await checkAndRequestPermission();
      if (!hasPermission) return null;

      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 8),
      );
    } catch (e) {
      return null;
    }
  }

  /// Convert Position to LatLng
  static LatLng positionToLatLng(Position pos) {
    return LatLng(pos.latitude, pos.longitude);
  }

  /// Open app settings for manually enabling permissions
  static Future<void> openAppSettings() async {
    await Geolocator.openAppSettings();
  }
}
