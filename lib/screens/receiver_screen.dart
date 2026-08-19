import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmaps;
import 'package:flutter_map/flutter_map.dart' as fmap;
import 'package:latlong2/latlong.dart' as latlong;
import 'package:provider/provider.dart';
import '../providers/location_provider.dart';

const Color textDark = Color(0xFF0F172A);
const Color textMuted = Color(0xFF64748B);
const Color crimsonEmergency = Color(0xFFDC2626);
const Color emeraldPrimary = Color(0xFF059669);

enum MapEngine { googleMaps, openStreetMap }

/// Receiver (User) Screen: Displays Maps tracking active emergency vehicles with 500m geofence alerts
class ReceiverScreen extends StatefulWidget {
  const ReceiverScreen({super.key});

  @override
  State<ReceiverScreen> createState() => _ReceiverScreenState();
}

class _ReceiverScreenState extends State<ReceiverScreen> {
  gmaps.GoogleMapController? _googleMapController;
  fmap.MapController? _osmMapController;
  MapEngine _activeEngine = MapEngine.googleMaps;

  @override
  void initState() {
    super.initState();
    _osmMapController = fmap.MapController();
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
    _googleMapController?.dispose();
    _osmMapController?.dispose();
    super.dispose();
  }

  void _recenterOnReceiver(double lat, double lng) {
    if (_activeEngine == MapEngine.googleMaps) {
      _googleMapController?.animateCamera(
        gmaps.CameraUpdate.newLatLngZoom(gmaps.LatLng(lat, lng), 15.5),
      );
    } else {
      _osmMapController?.move(latlong.LatLng(lat, lng), 15.5);
    }
  }

  void _focusOnHardware(double lat, double lng) {
    if (_activeEngine == MapEngine.googleMaps) {
      _googleMapController?.animateCamera(
        gmaps.CameraUpdate.newLatLngZoom(gmaps.LatLng(lat, lng), 16.5),
      );
    } else {
      _osmMapController?.move(latlong.LatLng(lat, lng), 16.5);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<LocationProvider>(context);
    final userPos = provider.currentPosition;
    final trackerDevices = provider.trackerDevices;
    final targetDevice = provider.selectedTarget;
    final distanceText = provider.formattedDistanceToTarget;
    final isWithin500m = provider.isProximityAlertActive;

    // Google Maps Markers & Shapes
    final Set<gmaps.Marker> gMarkers = {};
    gMarkers.add(
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

    for (final device in trackerDevices) {
      gMarkers.add(
        gmaps.Marker(
          markerId: gmaps.MarkerId(device.id),
          position: gmaps.LatLng(device.latitude, device.longitude),
          icon: gmaps.BitmapDescriptor.defaultMarkerWithHue(gmaps.BitmapDescriptor.hueRed),
          rotation: device.heading,
          infoWindow: gmaps.InfoWindow(
            title: '${device.name}${device.isSirenActive ? " 🚨 [SIREN ACTIVE]" : ""}',
            snippet: 'Speed: ${device.speed.toStringAsFixed(1)} km/h • Coords: (${device.latitude.toStringAsFixed(5)}, ${device.longitude.toStringAsFixed(5)})',
          ),
          onTap: () {
            provider.selectTargetDevice(device);
            _focusOnHardware(device.latitude, device.longitude);
          },
        ),
      );
    }

    final Set<gmaps.Circle> gCircles = {
      gmaps.Circle(
        circleId: const gmaps.CircleId('geofence_receiver_user_500m_only'),
        center: gmaps.LatLng(userPos.latitude, userPos.longitude),
        radius: 500.0,
        fillColor: isWithin500m
            ? crimsonEmergency.withValues(alpha: 0.25)
            : const Color(0x1F0284C7),
        strokeColor: isWithin500m ? crimsonEmergency : const Color(0xFF0284C7),
        strokeWidth: 2,
      ),
    };

    final Set<gmaps.Polyline> gPolylines = {};
    if (targetDevice != null) {
      gPolylines.add(
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
        actions: [
          // Map Engine Switcher Button (Google Maps vs OpenStreetMap)
          PopupMenuButton<MapEngine>(
            icon: const Icon(Icons.map_rounded, color: Color(0xFF0284C7)),
            tooltip: 'Switch Map Provider',
            onSelected: (engine) {
              setState(() {
                _activeEngine = engine;
              });
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: MapEngine.googleMaps,
                child: Row(
                  children: [
                    Icon(Icons.g_mobiledata_rounded, 
                      color: _activeEngine == MapEngine.googleMaps ? const Color(0xFF0284C7) : textMuted),
                    const SizedBox(width: 8),
                    Text(
                      'Google Maps',
                      style: TextStyle(
                        fontWeight: _activeEngine == MapEngine.googleMaps ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: MapEngine.openStreetMap,
                child: Row(
                  children: [
                    Icon(Icons.map_outlined, 
                      color: _activeEngine == MapEngine.openStreetMap ? const Color(0xFF0284C7) : textMuted),
                    const SizedBox(width: 8),
                    Text(
                      'OpenStreetMap (Keyless)',
                      style: TextStyle(
                        fontWeight: _activeEngine == MapEngine.openStreetMap ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Stack(
        children: [
          // Render selected map engine
          if (_activeEngine == MapEngine.googleMaps)
            gmaps.GoogleMap(
              initialCameraPosition: gmaps.CameraPosition(
                target: gmaps.LatLng(userPos.latitude, userPos.longitude),
                zoom: 15.0,
              ),
              onMapCreated: (controller) {
                _googleMapController = controller;
              },
              markers: gMarkers,
              circles: gCircles,
              polylines: gPolylines,
              myLocationEnabled: false,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              mapType: gmaps.MapType.normal,
            )
          else
            fmap.FlutterMap(
              mapController: _osmMapController,
              options: fmap.MapOptions(
                initialCenter: latlong.LatLng(userPos.latitude, userPos.longitude),
                initialZoom: 15.0,
              ),
              children: [
                fmap.TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.lifelane.lifelane',
                ),
                fmap.CircleLayer(
                  circles: [
                    fmap.CircleMarker(
                      point: latlong.LatLng(userPos.latitude, userPos.longitude),
                      radius: 500.0,
                      useRadiusInMeter: true,
                      color: isWithin500m
                          ? crimsonEmergency.withValues(alpha: 0.25)
                          : const Color(0x1F0284C7),
                      borderColor: isWithin500m ? crimsonEmergency : const Color(0xFF0284C7),
                      borderStrokeWidth: 2,
                    ),
                  ],
                ),
                if (targetDevice != null)
                  fmap.PolylineLayer(
                    polylines: [
                      fmap.Polyline(
                        points: [
                          latlong.LatLng(userPos.latitude, userPos.longitude),
                          latlong.LatLng(targetDevice.latitude, targetDevice.longitude),
                        ],
                        strokeWidth: 5,
                        color: crimsonEmergency,
                      ),
                    ],
                  ),
                fmap.MarkerLayer(
                  markers: [
                    // Receiver User Marker
                    fmap.Marker(
                      point: latlong.LatLng(userPos.latitude, userPos.longitude),
                      width: 44,
                      height: 44,
                      child: Container(
                        decoration: const BoxDecoration(
                          color: Colors.cyan,
                          shape: BoxShape.circle,
                          boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 6)],
                        ),
                        child: const Icon(Icons.person_pin_circle_rounded, color: Colors.white, size: 28),
                      ),
                    ),
                    // Emergency Vehicle Trackers
                    for (final device in trackerDevices)
                      fmap.Marker(
                        point: latlong.LatLng(device.latitude, device.longitude),
                        width: 44,
                        height: 44,
                        child: GestureDetector(
                          onTap: () {
                            provider.selectTargetDevice(device);
                            _focusOnHardware(device.latitude, device.longitude);
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: crimsonEmergency,
                              shape: BoxShape.circle,
                              boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 8)],
                            ),
                            child: const Icon(Icons.medical_services_rounded, color: Colors.white, size: 24),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),

          // Active Map Badge Notice
          Positioned(
            top: 10,
            left: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(12),
                boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _activeEngine == MapEngine.googleMaps ? Icons.g_mobiledata_rounded : Icons.map_outlined,
                    size: 16,
                    color: const Color(0xFF0284C7),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _activeEngine == MapEngine.googleMaps ? 'Google Maps' : 'OpenStreetMap',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textDark),
                  ),
                ],
              ),
            ),
          ),

          // Location Permission Alert Overlay if missing
          if (!provider.hasLocationPermission)
            Positioned(
              top: 50,
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
            // CONTINUOUS 500m GEOFENCING EMERGENCY ALERT BANNER
            if (isWithin500m && targetDevice != null)
              Positioned(
                top: 50,
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
