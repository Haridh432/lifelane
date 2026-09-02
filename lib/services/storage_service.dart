import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';

/// Storage Service managing persistent local data via SharedPreferences
class StorageService {
  static const String _keyUsername = 'lifelane_username';
  static const String _keyUserRole = 'lifelane_user_role';
  static const String _keyUserId = 'lifelane_user_id';
  static const String _keyFirstLaunch = 'lifelane_first_launch';

  /// Get stored username
  static Future<String?> getUsername() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyUsername);
  }

  /// Save username
  static Future<bool> saveUsername(String username) async {
    final prefs = await SharedPreferences.getInstance();
    return await prefs.setString(_keyUsername, username.trim());
  }

  /// Get stored user role
  static Future<UserRole?> getUserRole() async {
    final prefs = await SharedPreferences.getInstance();
    final index = prefs.getInt(_keyUserRole);
    if (index != null && index >= 0 && index < UserRole.values.length) {
      return UserRole.values[index];
    }
    return null;
  }

  /// Save user role
  static Future<bool> saveUserRole(UserRole role) async {
    final prefs = await SharedPreferences.getInstance();
    return await prefs.setInt(_keyUserRole, role.index);
  }

  /// Get unique persistent User ID or generate one
  static Future<String> getOrCreateUserId() async {
    final prefs = await SharedPreferences.getInstance();
    String? id = prefs.getString(_keyUserId);
    if (id == null || id.isEmpty) {
      id = 'usr_${DateTime.now().millisecondsSinceEpoch}';
      await prefs.setString(_keyUserId, id);
    }
    return id;
  }

  /// Check if user has completed onboarding
  static Future<bool> isFirstLaunch() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyFirstLaunch) ?? true;
  }

  /// Complete onboarding flag
  static Future<void> completeFirstLaunch() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyFirstLaunch, false);
  }

  /// Reset all stored settings
  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  // Settings
  static const String _keySirenEnabled = 'lifelane_siren_enabled';
  static const String _keyGeofenceRadius = 'lifelane_geofence_radius';

  static Future<bool> isSirenEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keySirenEnabled) ?? true;
  }

  static Future<void> setSirenEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keySirenEnabled, enabled);
  }

  static Future<double> getGeofenceRadius() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_keyGeofenceRadius) ?? 500.0;
  }

  static Future<void> setGeofenceRadius(double radius) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyGeofenceRadius, radius);
  }
}
