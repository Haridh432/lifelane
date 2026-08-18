import 'package:flutter/material.dart';

/// Role assigned to a user in LifeLane Alert
enum UserRole {
  senderAmbulance, // Broadcasts live location & siren alert
  receiverUser, // Receives approaching ambulance alerts
}

extension UserRoleExtension on UserRole {
  String get name {
    switch (this) {
      case UserRole.senderAmbulance:
        return 'Ambulance (Sender)';
      case UserRole.receiverUser:
        return 'User (Receiver)';
    }
  }

  String get shortTag {
    switch (this) {
      case UserRole.senderAmbulance:
        return 'AMBULANCE';
      case UserRole.receiverUser:
        return 'RECEIVER';
    }
  }

  IconData get icon {
    switch (this) {
      case UserRole.senderAmbulance:
        return Icons.medical_services_rounded;
      case UserRole.receiverUser:
        return Icons.person_pin_circle_rounded;
    }
  }
}

/// Represents an active sharing user/vehicle in LifeLane Alert
class SharingUser {
  final String id;
  final String? username; // Optional fallback, omitted in UI
  final UserRole role;
  final double latitude;
  final double longitude;
  final double speed; // in km/h
  final double heading; // 0..360 degrees
  final bool isSirenActive;
  final DateTime lastUpdated;
  final bool isSharing;
  final Color avatarColor;
  final String? vehicleUnitNumber;

  const SharingUser({
    required this.id,
    this.username,
    required this.role,
    required this.latitude,
    required this.longitude,
    required this.speed,
    this.heading = 0.0,
    this.isSirenActive = false,
    required this.lastUpdated,
    this.isSharing = true,
    required this.avatarColor,
    this.vehicleUnitNumber,
  });

  bool get isAmbulance => role == UserRole.senderAmbulance;
  bool get isReceiver => role == UserRole.receiverUser;

  String get displayName => isAmbulance ? 'Emergency Ambulance' : 'Receiver';

  SharingUser copyWith({
    String? id,
    String? username,
    UserRole? role,
    double? latitude,
    double? longitude,
    double? speed,
    double? heading,
    bool? isSirenActive,
    DateTime? lastUpdated,
    bool? isSharing,
    Color? avatarColor,
    String? vehicleUnitNumber,
  }) {
    return SharingUser(
      id: id ?? this.id,
      username: username ?? this.username,
      role: role ?? this.role,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      speed: speed ?? this.speed,
      heading: heading ?? this.heading,
      isSirenActive: isSirenActive ?? this.isSirenActive,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      isSharing: isSharing ?? this.isSharing,
      avatarColor: avatarColor ?? this.avatarColor,
      vehicleUnitNumber: vehicleUnitNumber ?? this.vehicleUnitNumber,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'role': role.index,
      'latitude': latitude,
      'longitude': longitude,
      'speed': speed,
      'heading': heading,
      'isSirenActive': isSirenActive,
      'lastUpdated': lastUpdated.toIso8601String(),
      'isSharing': isSharing,
      'avatarColor': avatarColor.toARGB32(),
      'vehicleUnitNumber': vehicleUnitNumber,
    };
  }

  factory SharingUser.fromMap(Map<String, dynamic> map) {
    return SharingUser(
      id: map['id'] as String? ?? 'unknown',
      role: UserRole.values[(map['role'] as int? ?? 1).clamp(0, UserRole.values.length - 1)],
      latitude: (map['latitude'] as num).toDouble(),
      longitude: (map['longitude'] as num).toDouble(),
      speed: (map['speed'] as num).toDouble(),
      heading: (map['heading'] as num? ?? 0.0).toDouble(),
      isSirenActive: map['isSirenActive'] as bool? ?? false,
      lastUpdated: DateTime.parse(map['lastUpdated'] as String),
      isSharing: map['isSharing'] as bool? ?? true,
      avatarColor: Color(map['avatarColor'] as int? ?? 0xFF10B981),
      vehicleUnitNumber: map['vehicleUnitNumber'] as String?,
    );
  }
}
