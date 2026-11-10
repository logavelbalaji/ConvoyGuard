import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../core/theme/app_colors.dart';
import '../../models/live_location_model.dart';
import '../../models/safety_alert_model.dart';
import '../../services/auth_service.dart';
import '../../services/live_location_service.dart';
import '../../services/location_service.dart';
import '../../services/safety_service.dart';
import '../../services/notification_service.dart';

class LiveMapScreen extends StatefulWidget {
  final String rideId;
  const LiveMapScreen({super.key, required this.rideId});

  @override
  State<LiveMapScreen> createState() => _LiveMapScreenState();
}

class _LiveMapScreenState extends State<LiveMapScreen> {
  GoogleMapController? _mapController;
  final LocationService _locationService = LocationService();
  final LiveLocationService _liveLocationService = LiveLocationService();
  final AuthService _authService = AuthService();

  // Fallback initial position (Bangalore, India)
  static const LatLng _defaultCenter = LatLng(12.9716, 77.5946);

  bool _isLocatingUser = false;
  bool _isPanelExpanded = true;

  @override
  void initState() {
    super.initState();
    final currentUid = _authService.currentUser?.uid ?? '';
    NotificationService().startListeningForConvoyAlerts(
      rideId: widget.rideId,
      currentUserId: currentUid,
    );
  }

  @override
  void dispose() {
    NotificationService().stopListeningForConvoyAlerts();
    _mapController?.dispose();
    super.dispose();
  }

  /// Move map camera smoothly to the current rider's GPS location.
  Future<void> _centerOnMyLocation() async {
    setState(() {
      _isLocatingUser = true;
    });

    try {
      final pos = await _locationService.getCurrentLocation();
      if (!mounted) return;

      final latLng = LatLng(pos.latitude, pos.longitude);
      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(latLng, 16.0),
      );

      setState(() {
        _isLocatingUser = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Centered on your current location.'),
          duration: Duration(seconds: 2),
        ),
      );
    } on GpsServiceDisabledException catch (e) {
      if (!mounted) return;
      setState(() {
        _isLocatingUser = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          backgroundColor: AppColors.warning,
          action: SnackBarAction(
            label: 'Enable GPS',
            textColor: Colors.black,
            onPressed: () => _locationService.openLocationSettings(),
          ),
        ),
      );
    } on GpsPermissionDeniedException catch (e) {
      if (!mounted) return;
      setState(() {
        _isLocatingUser = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          backgroundColor: AppColors.danger,
        ),
      );
    } on GpsPermissionPermanentlyDeniedException catch (e) {
      if (!mounted) return;
      setState(() {
        _isLocatingUser = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          backgroundColor: AppColors.danger,
          action: SnackBarAction(
            label: 'Settings',
            textColor: Colors.white,
            onPressed: () => _locationService.openAppSettings(),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLocatingUser = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not get position: ${e.toString()}'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  /// Fit camera bounds so all active and last known ride members are visible.
  void _zoomToFitAllRiders(List<LiveLocationModel> riders) {
    final validRiders = riders.where((r) => r.latitude != 0.0 && r.longitude != 0.0).toList();

    if (validRiders.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No rider location coordinates available to fit.')),
      );
      return;
    }

    if (validRiders.length == 1) {
      final r = validRiders.first;
      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(LatLng(r.latitude, r.longitude), 15.0),
      );
      return;
    }

    double minLat = validRiders.first.latitude;
    double maxLat = validRiders.first.latitude;
    double minLng = validRiders.first.longitude;
    double maxLng = validRiders.first.longitude;

    for (var r in validRiders) {
      if (r.latitude < minLat) minLat = r.latitude;
      if (r.latitude > maxLat) maxLat = r.latitude;
      if (r.longitude < minLng) minLng = r.longitude;
      if (r.longitude > maxLng) maxLng = r.longitude;
    }

    final bounds = LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );

    _mapController?.animateCamera(
      CameraUpdate.newLatLngBounds(bounds, 70.0),
    );
  }

  /// Convert list of [LiveLocationModel] Firestore snapshots into Google Map Markers with Safety Status.
  Set<Marker> _buildRiderMarkers(
    List<LiveLocationModel> riders,
    List<SafetyAlertModel> alerts,
    String currentUid,
  ) {
    final Set<Marker> markers = {};

    for (var loc in riders) {
      if (loc.latitude == 0.0 && loc.longitude == 0.0) continue;

      final isMe = loc.userId == currentUid;
      final alertForRider = alerts.firstWhere(
        (a) => a.userId == loc.userId,
        orElse: () => const SafetyAlertModel(alertId: '', rideId: '', userId: '', userName: '', type: '', message: ''),
      );
      final hasAlert = alertForRider.alertId.isNotEmpty;

      String title;
      if (hasAlert) {
        title = '⚠️ ALERT: ${loc.userName} (${alertForRider.type.replaceAll('_', ' ').toUpperCase()})';
      } else if (isMe) {
        title = '📍 YOU (${loc.userName})';
      } else {
        title = '🏍️ ${loc.userName}';
      }

      final statusStr = hasAlert
          ? '⚠️ NEEDS ATTENTION'
          : loc.isTracking
              ? '🟢 LIVE'
              : '⚪ INACTIVE';
      final speedStr = '${loc.speed.toStringAsFixed(1)} km/h';
      final accStr = 'Acc: ±${loc.accuracy.toStringAsFixed(1)}m';

      double hue;
      if (hasAlert) {
        hue = BitmapDescriptor.hueOrange;
      } else if (isMe) {
        hue = BitmapDescriptor.hueAzure;
      } else if (loc.isTracking) {
        hue = BitmapDescriptor.hueGreen;
      } else {
        hue = BitmapDescriptor.hueRed;
      }

      markers.add(
        Marker(
          markerId: MarkerId(loc.userId),
          position: LatLng(loc.latitude, loc.longitude),
          icon: BitmapDescriptor.defaultMarkerWithHue(hue),
          infoWindow: InfoWindow(
            title: title,
            snippet: hasAlert ? 'Msg: ${alertForRider.message}' : '$statusStr | $speedStr | $accStr',
          ),
        ),
      );
    }

    return markers;
  }

  @override
  Widget build(BuildContext context) {
    final currentUid = _authService.currentUser?.uid ?? '';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.map_rounded, color: AppColors.primary, size: 22),
            SizedBox(width: 8),
            Text('LIVE CONVOY MAP'),
          ],
        ),
        backgroundColor: AppColors.background,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppColors.primary),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Live map streams updates automatically in real-time.'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<List<SafetyAlertModel>>(
        stream: SafetyService().streamActiveAlerts(widget.rideId),
        builder: (context, alertsSnapshot) {
          final activeAlerts = alertsSnapshot.data ?? [];

          return StreamBuilder<List<LiveLocationModel>>(
            stream: _liveLocationService.streamRideLocations(widget.rideId),
            builder: (context, snapshot) {
              final liveLocations = snapshot.data ?? [];
              final markers = _buildRiderMarkers(liveLocations, activeAlerts, currentUid);

              return Stack(
                children: [
                  // 1. Google Map Full-Screen
                  GoogleMap(
                initialCameraPosition: const CameraPosition(
                  target: _defaultCenter,
                  zoom: 14.0,
                ),
                markers: markers,
                myLocationEnabled: true,
                myLocationButtonEnabled: false, // Custom FAB button used instead
                zoomControlsEnabled: false,
                onMapCreated: (controller) {
                  _mapController = controller;
                  // Center on current rider position or first available location upon load
                  if (liveLocations.isNotEmpty) {
                    final firstLoc = liveLocations.firstWhere(
                      (l) => l.latitude != 0.0 && l.longitude != 0.0,
                      orElse: () => liveLocations.first,
                    );
                    if (firstLoc.latitude != 0.0 && firstLoc.longitude != 0.0) {
                      _mapController?.animateCamera(
                        CameraUpdate.newLatLngZoom(
                          LatLng(firstLoc.latitude, firstLoc.longitude),
                          14.5,
                        ),
                      );
                    }
                  } else {
                    _centerOnMyLocation();
                  }
                },
              ),

              // 2. Emergency Alert Overlay Banner (if any active safety alert exists)
              if (activeAlerts.isNotEmpty)
                Positioned(
                  top: 16,
                  left: 16,
                  right: 74,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.danger,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: const [
                        BoxShadow(color: Colors.black45, blurRadius: 8, offset: Offset(0, 4)),
                      ],
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 24),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${activeAlerts.first.userName.toUpperCase()}: ${activeAlerts.first.type.replaceAll('_', ' ').toUpperCase()}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              Text(
                                activeAlerts.first.message,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 11, color: Colors.white70),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        if (activeAlerts.first.latitude != null && activeAlerts.first.latitude != 0.0)
                          GestureDetector(
                            onTap: () {
                              _mapController?.animateCamera(
                                CameraUpdate.newLatLngZoom(
                                  LatLng(activeAlerts.first.latitude!, activeAlerts.first.longitude!),
                                  16.5,
                                ),
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.35),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'LOCATE',
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),

              // 3. Floating Action Controls (My Location & Show All Riders)
              Positioned(
                top: 16,
                right: 16,
                child: Column(
                  children: [
                    // 📍 MY LOCATION FAB
                    FloatingActionButton.small(
                      heroTag: 'fab_my_location',
                      backgroundColor: AppColors.surface,
                      foregroundColor: AppColors.primary,
                      tooltip: 'My Location',
                      onPressed: _isLocatingUser ? null : _centerOnMyLocation,
                      child: _isLocatingUser
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                            )
                          : const Icon(Icons.my_location_rounded),
                    ),
                    const SizedBox(height: 10),

                    // 👥 SHOW ALL RIDERS FAB
                    FloatingActionButton.small(
                      heroTag: 'fab_show_all',
                      backgroundColor: AppColors.surface,
                      foregroundColor: AppColors.secondary,
                      tooltip: 'Show All Riders',
                      onPressed: () => _zoomToFitAllRiders(liveLocations),
                      child: const Icon(Icons.groups_rounded),
                    ),
                  ],
                ),
              ),

              // 4. Live Riders Collapsible Bottom Panel
              Align(
                alignment: Alignment.bottomCenter,
                child: _buildBottomPanel(liveLocations, currentUid),
              ),
            ],
          );
        },
      );
    },
  ),
);
}

  Widget _buildBottomPanel(List<LiveLocationModel> riders, String currentUid) {
    final activeCount = riders.where((r) => r.isTracking).length;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      constraints: BoxConstraints(maxHeight: _isPanelExpanded ? 280 : 64),
      margin: const EdgeInsets.all(14),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 14,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row with Expand/Collapse Toggle
          GestureDetector(
            onTap: () {
              setState(() {
                _isPanelExpanded = !_isPanelExpanded;
              });
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.radar_rounded, color: AppColors.primary, size: 20),
                    const SizedBox(width: 8),
                    const Text(
                      'LIVE RIDERS',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '$activeCount/${riders.length} Active',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
                Icon(
                  _isPanelExpanded ? Icons.keyboard_arrow_down_rounded : Icons.keyboard_arrow_up_rounded,
                  color: AppColors.textMuted,
                ),
              ],
            ),
          ),

          if (_isPanelExpanded) ...[
            const SizedBox(height: 12),
            const Divider(color: AppColors.border, height: 1),
            const SizedBox(height: 10),

            // Rider Cards Stream List
            Expanded(
              child: riders.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(12.0),
                        child: Text(
                          'No live rider locations available yet.\nStart Live Tracking to broadcast your position!',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                        ),
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      itemCount: riders.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final r = riders[index];
                        final isMe = r.userId == currentUid;
                        final ts = r.timestamp;
                        final timeStr = ts != null
                            ? '${ts.hour.toString().padLeft(2, '0')}:${ts.minute.toString().padLeft(2, '0')}:${ts.second.toString().padLeft(2, '0')}'
                            : 'Just now';

                        return Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: r.isTracking
                                ? AppColors.success.withValues(alpha: 0.08)
                                : AppColors.surfaceLight,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: r.isTracking
                                  ? AppColors.success.withValues(alpha: 0.4)
                                  : AppColors.border,
                            ),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 14,
                                backgroundColor: isMe
                                    ? AppColors.primary.withValues(alpha: 0.2)
                                    : (r.isTracking
                                        ? AppColors.success.withValues(alpha: 0.2)
                                        : AppColors.surface),
                                child: Text(
                                  r.userName.isNotEmpty ? r.userName[0].toUpperCase() : 'R',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: isMe
                                        ? AppColors.primary
                                        : (r.isTracking ? AppColors.success : AppColors.textMuted),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          isMe ? '📍 YOU (${r.userName})' : '🏍️ ${r.userName}',
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.textPrimary,
                                          ),
                                        ),
                                        const Spacer(),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: r.isTracking
                                                ? AppColors.success.withValues(alpha: 0.2)
                                                : AppColors.surface,
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            r.isTracking ? '🟢 LIVE' : '⚪ INACTIVE',
                                            style: TextStyle(
                                              fontSize: 9,
                                              fontWeight: FontWeight.bold,
                                              color: r.isTracking ? AppColors.success : AppColors.textMuted,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 3),
                                    Row(
                                      children: [
                                        Text(
                                          '${r.latitude.toStringAsFixed(4)}°, ${r.longitude.toStringAsFixed(4)}°',
                                          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                        ),
                                        const Spacer(),
                                        Text(
                                          '⚡ ${r.speed.toStringAsFixed(1)} km/h',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.primary,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          '🎯 ±${r.accuracy.toStringAsFixed(1)}m',
                                          style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
                                        ),
                                        Text(
                                          '🕒 $timeStr',
                                          style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ],
      ),
    );
  }
}
