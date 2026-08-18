import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:lifelane/models/user_model.dart';
import 'package:lifelane/services/sharing_hub_service.dart';

void main() {
  test('SharingUser model serialization and role checks', () {
    final user = SharingUser(
      id: 'test_123',
      username: 'Alex Rivers',
      role: UserRole.senderAmbulance,
      latitude: 40.7128,
      longitude: -74.0060,
      speed: 60.0,
      lastUpdated: DateTime.now(),
      avatarColor: const Color(0xFFEF4444),
    );

    expect(user.isAmbulance, true);
    expect(user.isReceiver, false);
    expect(user.displayName, 'Emergency Ambulance');

    final map = user.toMap();
    final restoredUser = SharingUser.fromMap(map);
    expect(restoredUser.id, 'test_123');
    expect(restoredUser.role, UserRole.senderAmbulance);
  });

  test('Geodesic distance and ETA calculations', () {
    final hub = SharingHubService();
    const posA = LatLng(40.7128, -74.0060);
    const posB = LatLng(40.7200, -74.0000);

    final distanceMeters = hub.calculateDistanceMeters(posA, posB);
    expect(distanceMeters, greaterThan(0));

    final formattedDist = hub.formatDistance(distanceMeters);
    expect(formattedDist.contains('m') || formattedDist.contains('km'), true);

    final bearing = hub.calculateBearing(posA, posB);
    expect(bearing, greaterThanOrEqualTo(0));
    expect(bearing, lessThanOrEqualTo(360));
  });
}
