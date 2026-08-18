import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmaps;
import 'package:provider/provider.dart';
import '../providers/location_provider.dart';

const Color textDark = Color(0xFF0F172A);
const Color textMuted = Color(0xFF64748B);
const Color crimsonEmergency = Color(0xFFDC2626);
const Color emeraldPrimary = Color(0xFF059669);

/// Receiver (User) Screen: Displays Google Maps tracking active emergency vehicles with 500m geofence alerts & seamless direction extrapolation
class ReceiverScreen extends StatefulWidget {
  const ReceiverScreen({super.key});

  @override
  State<ReceiverScreen> createState() => _ReceiverScreenState();
}

class _ReceiverScreenState extends State<ReceiverScreen> {
  gmaps.GoogleMapController? _mapController;

  @override
  void initState() {
    super.initState();
    // Prompt location permission dialog immediately upon screen open
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<LocationProvider>(context, listen: false);
      if (!provider.hasLocationPermission) {
        provider.requestLocationPermission();
      }
    });
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  void _recenterOnReceiver(double lat, double lng) {
    _mapController?.animateCamera(
      gmaps.CameraUpdate.newLatLngZoom(gmaps.LatLng(lat, lng), 15.5),
    );
  }

  void _focusOnHardware(double lat, double lng) {
    _mapController?.animateCamera(
      gmaps.CameraUpdate.newLatLngZoom(gmaps.LatLng(lat, lng), 16.5),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<LocationProvider>(context);
    final userPos = provider.currentPosition;
    final trackerDevices = provider.trackerDevices;
    final targetDevice = provider.selectedTarget;
    final distanceText = provider.formattedDistanceToTarget;
    final isWithin500m = provider.isProximityAlertActive;

    // Build Map Markers
    final Set<gmaps.Marker> markers = {};

    // 1. App User Location Marker
    markers.add(
      gmaps.Marker(
        markerId: const gmaps.MarkerId('current_receiver_user'),
        position: gmaps.LatLng(userPos.latitude, userPos.longitude),
        icon: gmaps.BitmapDescriptor.defaultMarkerWithHue(gmaps.BitmapDescriptor.hueCyan),
        infoWindow: const gmaps.InfoWindow(
          title: 'Your Location',
          snippet: 'App User (500m Geofence Center)',
        ),
      ),
    );

    // 2. Active Emergency Hardware Trackers (only devices with isSharing == true)
    for (final device in trackerDevices) {
      markers.add(
        gmaps.Marker(
          markerId: gmaps.MarkerId(device.id),
          position: gmaps.LatLng(device.latitude, device.longitude),
          icon: gmaps.BitmapDescriptor.defaultMarkerWithHue(gmaps.BitmapDescriptor.hueRed),
          rotation: device.heading,
          infoWindow: gmaps.InfoWindow(
            title: '${device.name}${device.isSirenActive ? " 🚨 [SIREN ACTIVE]" : ""}',
            snippet: 'Speed: ${device.speed.toStringAsFixed(1)} km/h • Date: ${device.displayDate} ${device.displayTime} • Coords: (${device.latitude.toStringAsFixed(5)}, ${device.longitude.toStringAsFixed(5)})',
          ),
          onTap: () {
            provider.selectTargetDevice(device);
            _focusOnHardware(device.latitude, device.longitude);
          },
        ),
      );
    }

    // Build ONLY User 500m Geofence Circle (No geofence circles around emergency vehicles)
    final Set<gmaps.Circle> circles = {};

    circles.add(
      gmaps.Circle(
        circleId: const gmaps.CircleId('geofence_receiver_user_500m_only'),
        center: gmaps.LatLng(userPos.latitude, userPos.longitude),
        radius: 500.0, // 500 meters geofence radius around user ONLY
        fillColor: isWithin500m
            ? crimsonEmergency.withValues(alpha: 0.25)
            : const Color(0x1F0284C7),
        strokeColor: isWithin500m ? crimsonEmergency : const Color(0xFF0284C7),
        strokeWidth: 2,
      ),
    );

    // Direct line connecting User and Target Emergency Vehicle
    final Set<gmaps.Polyline> polylines = {};
    if (targetDevice != null) {
      polylines.add(
        gmaps.Polyline(
          polylineId: const gmaps.PolylineId('user_to_hardware_line'),
          points: [
            gmaps.LatLng(userPos.latitude, userPos.longitude),
            gmaps.LatLng(targetDevice.latitude, targetDevice.longitude),
          ],
          width: 5,
          color: crimsonEmergency,
          patterns: [
            gmaps.PatternItem.dash(20),
            gmaps.PatternItem.gap(10),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8FAFC),
        elevation: 0,
        title: Row(
          children: const [
            Icon(Icons.shield_rounded, color: Color(0xFF0284C7), size: 24),
            SizedBox(width: 10),
            Text(
              'Emergency Receiver - 500m Alert',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: textDark),
            ),
          ],
        ),
      ),
      body: Stack(
        children: [
          // Main Google Map View
          gmaps.GoogleMap(
            initialCameraPosition: gmaps.CameraPosition(
              target: gmaps.LatLng(userPos.latitude, userPos.longitude),
              zoom: 15.0,
            ),
            onMapCreated: (controller) {
              _mapController = controller;
            },
            markers: markers,
            circles: circles,
            polylines: polylines,
            myLocationEnabled: false,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapType: gmaps.MapType.normal,
          ),

          // Location Permission Alert Overlay if missing
          if (!provider.hasLocationPermission)
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.amber.shade100,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.amber.shade700),
                  boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10)],
                ),
                child: Row(
                  children: [
                    Icon(Icons.location_off_rounded, color: Colors.amber.shade900),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Location Permission Required for live map.',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.amber.shade900),
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () => provider.requestLocationPermission(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amber.shade800,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      child: const Text('ALLOW'),
                    ),
                  ],
                ),
              ),
            )
          else ...[
            // CONTINUOUS 500m GEOFENCING EMERGENCY ALERT BANNER (ONLY DISPLAYED WHEN WITHIN 500M)
            if (isWithin500m && targetDevice != null)
              Positioned(
                top: 16,
                left: 16,
                right: 16,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: crimsonEmergency,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: crimsonEmergency.withValues(alpha: 0.4),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 32)
                          .animate(onPlay: (controller) => controller.repeat(reverse: true))
                          .scale(begin: const Offset(1, 1), end: const Offset(1.2, 1.2), duration: 500.ms),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '🚨 ${targetDevice.name.toUpperCase()} WITHIN YOUR 500M GEOFENCE!',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Distance: $distanceText • ETA: ${provider.etaToTarget ?? "< 1 min"} • Please clear the lane!',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFFFEE2E2),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ).animate().shake(duration: 500.ms),
              ),
          ],

          // Floating Action Button Controls
          Positioned(
            right: 16,
            bottom: 30,
            child: Column(
              children: [
                FloatingActionButton.small(
                  heroTag: 'recenter_receiver',
                  backgroundColor: Colors.white,
                  foregroundColor: emeraldPrimary,
                  child: const Icon(Icons.my_location_rounded),
                  onPressed: () => _recenterOnReceiver(userPos.latitude, userPos.longitude),
                ),
                if (targetDevice != null) ...[
                  const SizedBox(height: 10),
                  FloatingActionButton.small(
                    heroTag: 'focus_hardware',
                    backgroundColor: Colors.white,
                    foregroundColor: crimsonEmergency,
                    child: const Icon(Icons.medical_services_rounded),
                    onPressed: () => _focusOnHardware(targetDevice.latitude, targetDevice.longitude),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
