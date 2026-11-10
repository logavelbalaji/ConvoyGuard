import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../../core/theme/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/mock/mock_data.dart';
import '../../models/breakpoint_model.dart';
import '../../models/live_location_model.dart';
import '../../models/ride_model.dart';
import '../../models/safety_alert_model.dart';
import '../../models/tracking_state.dart';
import '../../services/auth_service.dart';
import '../../services/live_location_service.dart';
import '../../services/location_service.dart';
import '../../services/ride_service.dart';
import '../../services/safety_service.dart';
import '../../services/notification_service.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/status_badge.dart';

class RideGroupScreen extends StatefulWidget {
  final String rideId;
  const RideGroupScreen({super.key, required this.rideId});

  @override
  State<RideGroupScreen> createState() => _RideGroupScreenState();
}

class _RideGroupScreenState extends State<RideGroupScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final RideService _rideService = RideService();
  final AuthService _authService = AuthService();
  final SafetyService _safetyService = SafetyService();

  RideModel? _currentRide;
  bool _isStartingRide = false;

  // Phase 5: Safety Monitoring State
  DateTime? _stillnessStartTime;
  bool _isSafetyCheckActive = false;
  Timer? _safetyCheckTimer;
  int _countdownSeconds = AppConstants.safetyCheckTimeoutSeconds;
  String _selectedStopReason = 'Refreshment';

  // Phase 4B: Live GPS Tracking State & Subscription
  StreamSubscription<Position>? _positionSubscription;
  TrackingState _trackingState = const TrackingState();
  bool _isInitializingTracking = false;

  // Phase 4C: Firestore Location Upload Throttling State
  Position? _lastUploadedPosition;
  DateTime? _lastUploadTime;

  bool _shouldUploadLocation(Position newPos) {
    if (_lastUploadedPosition == null || _lastUploadTime == null) {
      return true;
    }
    final timeDiff = DateTime.now().difference(_lastUploadTime!).inSeconds;
    if (timeDiff >= 10) return true;

    final distanceMeters = Geolocator.distanceBetween(
      _lastUploadedPosition!.latitude,
      _lastUploadedPosition!.longitude,
      newPos.latitude,
      newPos.longitude,
    );
    return distanceMeters >= 10.0;
  }

  // Controllers for adding breakpoint modal
  final _bpNameController = TextEditingController();
  final _bpLocationController = TextEditingController();
  String _selectedBpType = 'Refreshment';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    final currentUid = _authService.currentUser?.uid ?? MockDataState().currentUser.id;
    NotificationService().startListeningForConvoyAlerts(
      rideId: widget.rideId,
      currentUserId: currentUid,
    );
  }

  @override
  void dispose() {
    NotificationService().stopListeningForConvoyAlerts();
    _safetyCheckTimer?.cancel();
    if (_trackingState.isTracking) {
      final currentUid = _authService.currentUser?.uid ?? MockDataState().currentUser.id;
      LiveLocationService().stopLiveTracking(widget.rideId, currentUid);
    }
    _positionSubscription?.cancel();
    _positionSubscription = null;
    _tabController.dispose();
    _bpNameController.dispose();
    _bpLocationController.dispose();
    super.dispose();
  }

  Future<void> _startLiveTracking() async {
    if (_trackingState.isTracking) return;

    setState(() {
      _isInitializingTracking = true;
    });

    try {
      // 1. Verify location service and permissions
      await LocationService().getCurrentLocation();

      // 2. Safely cancel any active subscription
      await _positionSubscription?.cancel();
      _positionSubscription = null;

      final now = DateTime.now();
      setState(() {
        _trackingState = TrackingState(
          isTracking: true,
          startTime: now,
          lastUpdateTime: now,
          updateCount: 0,
        );
        _isInitializingTracking = false;
      });

      // 3. Subscribe to real-time position stream
      _positionSubscription = LocationService().getPositionStream().listen(
        (Position pos) {
          if (!mounted) return;
          setState(() {
            _trackingState = _trackingState.copyWith(
              currentPosition: pos,
              updateCount: _trackingState.updateCount + 1,
              lastUpdateTime: DateTime.now(),
            );
          });

          // Phase 5: Continuous Stillness & Safety Monitoring
          _processSafetyMonitoring(pos);

          // Phase 4C: Throttled Firestore real-time location upload
          if (_shouldUploadLocation(pos)) {
            final currentUid = _authService.currentUser?.uid ?? MockDataState().currentUser.id;
            final currentName = _authService.currentUser?.displayName ?? MockDataState().currentUser.name;
            LiveLocationService().updateLiveLocation(
              widget.rideId,
              currentUid,
              pos,
              userName: currentName,
            );
            _lastUploadedPosition = pos;
            _lastUploadTime = DateTime.now();
          }
        },
        onError: (error) {
          if (!mounted) return;
          _stopLiveTracking();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('GPS Stream Error: ${error.toString()}'),
              backgroundColor: AppColors.danger,
            ),
          );
        },
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🟢 Live GPS Tracking Activated! Sharing with convoy.'),
          backgroundColor: AppColors.success,
        ),
      );
    } on GpsServiceDisabledException catch (e) {
      if (!mounted) return;
      setState(() {
        _isInitializingTracking = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          backgroundColor: AppColors.warning,
          action: SnackBarAction(
            label: 'Enable GPS',
            textColor: Colors.black,
            onPressed: () => LocationService().openLocationSettings(),
          ),
        ),
      );
    } on GpsPermissionDeniedException catch (e) {
      if (!mounted) return;
      setState(() {
        _isInitializingTracking = false;
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
        _isInitializingTracking = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          backgroundColor: AppColors.danger,
          action: SnackBarAction(
            label: 'Settings',
            textColor: Colors.white,
            onPressed: () => LocationService().openAppSettings(),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isInitializingTracking = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to start tracking: ${e.toString()}'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  void _stopLiveTracking() {
    _positionSubscription?.cancel();
    _positionSubscription = null;

    // Phase 4C: Set isTracking = false in Firestore while retaining last known location
    final currentUid = _authService.currentUser?.uid ?? MockDataState().currentUser.id;
    LiveLocationService().stopLiveTracking(widget.rideId, currentUid);

    if (!mounted) return;
    setState(() {
      _trackingState = _trackingState.copyWith(isTracking: false);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('🔴 Live GPS Tracking Stopped. Last location saved.'),
        backgroundColor: AppColors.warning,
      ),
    );
  }

  Future<void> _handleStartRide(String rideId) async {
    setState(() {
      _isStartingRide = true;
    });

    try {
      await _rideService.startRide(rideId);
      if (!mounted) return;

      setState(() {
        _isStartingRide = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ride status updated to ACTIVE! Convoy tracking initiated.'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isStartingRide = false;
      });

      final msg = e.toString().replaceAll('Exception: ', '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  void _showAddBreakpointModal(String rideId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Add Planned Breakpoint',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: AppColors.textMuted),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  CustomTextField(
                    controller: _bpNameController,
                    label: 'Breakpoint Name',
                    hint: 'e.g. Fuel Stop / Lunch Break',
                  ),
                  const SizedBox(height: 14),
                  CustomTextField(
                    controller: _bpLocationController,
                    label: 'Location / Landmark',
                    hint: 'e.g. NH 44, Exit 12',
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Stop Category',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: AppConstants.breakpointTypes.map((type) {
                      final isSelected = _selectedBpType == type;
                      return ChoiceChip(
                        label: Text(type),
                        selected: isSelected,
                        selectedColor: AppColors.primary,
                        backgroundColor: AppColors.surfaceLight,
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.black : AppColors.textPrimary,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                        onSelected: (selected) {
                          if (selected) {
                            setModalState(() {
                              _selectedBpType = type;
                            });
                          }
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),
                  CustomButton(
                    text: 'Save Breakpoint to Ride',
                    onPressed: () async {
                      if (_bpNameController.text.trim().isNotEmpty) {
                        final bp = BreakpointModel(
                          id: 'bp_${DateTime.now().millisecondsSinceEpoch}',
                          name: _bpNameController.text.trim(),
                          type: _selectedBpType.toLowerCase(),
                          location: _bpLocationController.text.trim().isNotEmpty
                              ? _bpLocationController.text.trim()
                              : 'En route stop',
                        );

                        await _rideService.addBreakpoint(rideId, bp);
                        _bpNameController.clear();
                        _bpLocationController.clear();

                        if (context.mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Breakpoint added to Firestore!'),
                              backgroundColor: AppColors.success,
                            ),
                          );
                        }
                      }
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<RideModel?>(
      stream: _rideService.streamRide(widget.rideId),
      builder: (context, snapshot) {
        RideModel? ride = snapshot.data;

        // Fallback to local mock data if stream has no data yet
        if (ride == null) {
          try {
            ride = MockDataState().rides.firstWhere((r) => r.id == widget.rideId);
          } catch (_) {
            ride = MockDataState().rides.isNotEmpty ? MockDataState().rides.first : null;
          }
        }

        if (ride == null && snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
          );
        }

        if (ride == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Ride Group')),
            body: const Center(child: Text('Ride details not found.')),
          );
        }

        _currentRide = ride;

        final currentUid = _authService.currentUser?.uid ?? MockDataState().currentUser.id;
        final bool isAdmin = ride.adminId == currentUid;
        final bool isScheduled = ride.status.toLowerCase() == 'scheduled';

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            title: Text(ride.title),
            backgroundColor: AppColors.background,
            actions: [
              if (isAdmin && ride.status.toLowerCase() == 'active')
                IconButton(
                  icon: const Icon(Icons.flag_rounded, color: AppColors.warning),
                  tooltip: 'End Ride (Admin)',
                  onPressed: () => _handleEndRide(ride!),
                ),
              IconButton(
                icon: const Icon(Icons.emergency_outlined, color: AppColors.danger),
                tooltip: 'Emergency SOS',
                onPressed: _triggerManualSOS,
              ),
              IconButton(
                icon: const Icon(Icons.map_rounded, color: AppColors.primary),
                tooltip: 'Live Map',
                onPressed: () {
                  Navigator.pushNamed(context, '/live-map', arguments: ride?.id ?? widget.rideId);
                },
              ),
              IconButton(
                icon: const Icon(Icons.share_outlined, color: AppColors.primary),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Ride Code: ${ride?.rideCode}')),
                  );
                },
              ),
            ],
          ),
          body: SafeArea(
            child: Column(
              children: [
                // Top Ride Summary Banner
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          StatusBadge(status: ride.status),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.key, size: 14, color: AppColors.primary),
                                const SizedBox(width: 4),
                                Text(
                                  ride.rideCode,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primary,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Icon(Icons.navigation, size: 18, color: AppColors.primary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${ride.startLocation} ➔ ${ride.destination}',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.person, size: 14, color: AppColors.textMuted),
                          const SizedBox(width: 4),
                          Text(
                            'Admin: ${ride.adminName}',
                            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                          ),
                          const Spacer(),
                          const Icon(Icons.group, size: 14, color: AppColors.textMuted),
                          const SizedBox(width: 4),
                          Text(
                            '${ride.members.length} Riders Enrolled',
                            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Live Location Tracking Section (Phase 4B)
                if (ride.status.toLowerCase() == 'active') _buildLiveTrackingCard(),

                // Phase 5: Group Safety Alerts Section
                if (ride.status.toLowerCase() == 'active') _buildGroupSafetyAlertsSection(),

                // Group Live Rider Status Section (Phase 4C)
                if (ride.status.toLowerCase() == 'active') _buildLiveGroupRiderStatusSection(),

                // Tab Bar
                TabBar(
                  controller: _tabController,
                  indicatorColor: AppColors.primary,
                  labelColor: AppColors.primary,
                  unselectedLabelColor: AppColors.textMuted,
                  tabs: const [
                    Tab(text: 'Group Members'),
                    Tab(text: 'Planned Breakpoints'),
                  ],
                ),

                // Tab Content
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      // Tab 1: Group Members List (Real-time Firestore stream)
                      ride.memberProfiles.isEmpty && ride.members.isNotEmpty
                          ? ListView.separated(
                              padding: const EdgeInsets.all(16),
                              itemCount: ride.members.length,
                              separatorBuilder: (context, index) => const SizedBox(height: 10),
                              itemBuilder: (context, index) {
                                final memberUid = ride!.members[index];
                                final isMemberAdmin = memberUid == ride.adminId;
                                return _buildMemberTile(
                                  name: isMemberAdmin ? ride.adminName : 'Rider ${index + 1}',
                                  bikeModel: 'Convoy Member',
                                  isAdmin: isMemberAdmin,
                                );
                              },
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.all(16),
                              itemCount: ride.memberProfiles.length,
                              separatorBuilder: (context, index) => const SizedBox(height: 10),
                              itemBuilder: (context, index) {
                                final member = ride!.memberProfiles[index];
                                final bool memberIsAdmin = member.id == ride.adminId;
                                return _buildMemberTile(
                                  name: member.name.isNotEmpty ? member.name : 'Rider',
                                  bikeModel: member.bikeModel.isNotEmpty ? member.bikeModel : 'Convoy Member',
                                  isAdmin: memberIsAdmin,
                                );
                              },
                            ),

                      // Tab 2: Breakpoints List
                      Column(
                        children: [
                          if (isAdmin)
                            Padding(
                              padding: const EdgeInsets.only(left: 16, right: 16, top: 12),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Admin Breakpoint Controls',
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textMuted),
                                  ),
                                  TextButton.icon(
                                    icon: const Icon(Icons.add, size: 16, color: AppColors.primary),
                                    label: const Text('Add Stop', style: TextStyle(color: AppColors.primary, fontSize: 13)),
                                    onPressed: () => _showAddBreakpointModal(ride!.id),
                                  ),
                                ],
                              ),
                            ),
                          Expanded(
                            child: ride.breakpoints.isEmpty
                                ? const Center(
                                    child: Text(
                                      'No planned breakpoints added.',
                                      style: TextStyle(color: AppColors.textMuted),
                                    ),
                                  )
                                : ListView.separated(
                                    padding: const EdgeInsets.all(16),
                                    itemCount: ride.breakpoints.length,
                                    separatorBuilder: (context, index) => const SizedBox(height: 10),
                                    itemBuilder: (context, index) {
                                      final bp = ride!.breakpoints[index];
                                      return Container(
                                        padding: const EdgeInsets.all(14),
                                        decoration: BoxDecoration(
                                          color: AppColors.surface,
                                          borderRadius: BorderRadius.circular(14),
                                          border: Border.all(color: AppColors.border),
                                        ),
                                        child: Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(10),
                                              decoration: BoxDecoration(
                                                color: AppColors.primary.withValues(alpha: 0.15),
                                                shape: BoxShape.circle,
                                              ),
                                              child: Text(
                                                '${index + 1}',
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  color: AppColors.primary,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 14),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    bp.name,
                                                    style: const TextStyle(
                                                      fontSize: 15,
                                                      fontWeight: FontWeight.bold,
                                                      color: AppColors.textPrimary,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    'Category: ${bp.type} • ${bp.location}',
                                                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            if (isAdmin)
                                              IconButton(
                                                icon: const Icon(Icons.delete_outline, color: AppColors.danger, size: 20),
                                                onPressed: () async {
                                                  await _rideService.removeBreakpoint(ride!.id, bp.id);
                                                  if (context.mounted) {
                                                    ScaffoldMessenger.of(context).showSnackBar(
                                                      const SnackBar(content: Text('Breakpoint removed from Firestore.')),
                                                    );
                                                  }
                                                },
                                              )
                                            else if (bp.isReached)
                                              const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 22)
                                            else
                                              const Icon(Icons.radio_button_unchecked_rounded, color: AppColors.textMuted, size: 22),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Bottom Action Footer
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: isAdmin && isScheduled
                            ? CustomButton(
                                text: 'Start Ride',
                                icon: Icons.play_arrow_rounded,
                                isLoading: _isStartingRide,
                                onPressed: () => _handleStartRide(ride!.id),
                              )
                            : ride.status.toLowerCase() == 'active'
                                ? Row(
                                    children: [
                                      Expanded(
                                        child: _trackingState.isTracking
                                            ? CustomButton(
                                                text: 'STOP TRACKING',
                                                icon: Icons.stop_circle_outlined,
                                                isDanger: true,
                                                onPressed: _stopLiveTracking,
                                              )
                                            : CustomButton(
                                                text: 'START TRACKING',
                                                icon: Icons.my_location_rounded,
                                                isLoading: _isInitializingTracking,
                                                onPressed: _startLiveTracking,
                                              ),
                                      ),
                                      if (isAdmin) ...[
                                        const SizedBox(width: 8),
                                        ElevatedButton.icon(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: AppColors.warning,
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                          ),
                                          icon: const Icon(Icons.flag_rounded, color: Colors.black, size: 18),
                                          label: const Text('END RIDE', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12)),
                                          onPressed: () => _handleEndRide(ride!),
                                        ),
                                      ],
                                    ],
                                  )
                                : CustomButton(
                                    text: 'VIEW RIDE SUMMARY',
                                    icon: Icons.assessment_rounded,
                                    onPressed: () {
                                      Navigator.pushNamed(context, '/ride-summary', arguments: ride!.id);
                                    },
                                  ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        height: 52,
                        width: 52,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceLight,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.chat_bubble_outline_rounded, color: AppColors.primary),
                          onPressed: () {
                            Navigator.pushNamed(context, '/main', arguments: 1); // Open Chat tab
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ==========================================
  // PHASE 5 SAFETY MONITORING HELPER METHODS
  // ==========================================

  bool _isNearBreakpoint(Position pos, List<BreakpointModel> breakpoints) {
    for (final bp in breakpoints) {
      if (bp.latitude != 0.0 && bp.longitude != 0.0) {
        final dist = Geolocator.distanceBetween(
          pos.latitude,
          pos.longitude,
          bp.latitude,
          bp.longitude,
        );
        if (dist <= AppConstants.safetyBreakpointProximityMeters) {
          return true;
        }
      }
    }
    return false;
  }

  void _processSafetyMonitoring(Position pos) {
    if (!_trackingState.isTracking || _isSafetyCheckActive) return;

    final speedKmH = pos.speed > 0 ? (pos.speed * 3.6) : 0.0;
    final nearBp = _isNearBreakpoint(pos, _currentRide?.breakpoints ?? []);

    if (speedKmH <= AppConstants.safetyStillnessSpeedThresholdKmH && !nearBp) {
      _stillnessStartTime ??= DateTime.now();
      final stillnessDurationSeconds = DateTime.now().difference(_stillnessStartTime!).inSeconds;

      if (stillnessDurationSeconds >= AppConstants.safetyStillnessDurationSecondsDev) {
        _triggerSafetyCheck(pos);
      }
    } else {
      _stillnessStartTime = null;
    }
  }

  void _triggerSafetyCheck(Position pos) {
    if (_isSafetyCheckActive) return;

    setState(() {
      _isSafetyCheckActive = true;
      _countdownSeconds = AppConstants.safetyCheckTimeoutSeconds;
      _selectedStopReason = 'Refreshment';
    });

    _safetyCheckTimer?.cancel();
    _safetyCheckTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_countdownSeconds > 1) {
        setState(() {
          _countdownSeconds--;
        });
      } else {
        timer.cancel();
        _handleNoResponseTimeout(pos);
      }
    });

    _showAreYouSafeDialog(pos);
  }

  void _showAreYouSafeDialog(Position currentPos) {
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.shield_outlined,
                      size: 44,
                      color: AppColors.warning,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'ARE YOU SAFE?',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textPrimary,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Prolonged inactivity detected (${AppConstants.safetyStillnessDurationSecondsDev}s stillness). Please confirm your safety status.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.warning.withValues(alpha: 0.5)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.timer_outlined, size: 16, color: AppColors.warning),
                        const SizedBox(width: 6),
                        Text(
                          'Auto-alerting convoy in $_countdownSeconds s',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppColors.warning,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Stop Reason (Optional):',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textMuted),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: AppConstants.stopReasons.take(6).map((reason) {
                      final isSel = _selectedStopReason == reason;
                      return ChoiceChip(
                        label: Text(reason, style: const TextStyle(fontSize: 12)),
                        selected: isSel,
                        selectedColor: AppColors.primary,
                        backgroundColor: AppColors.surfaceLight,
                        labelStyle: TextStyle(
                          color: isSel ? Colors.black : AppColors.textPrimary,
                        ),
                        onSelected: (sel) {
                          if (sel) {
                            setModalState(() {
                              _selectedStopReason = reason;
                            });
                            setState(() {
                              _selectedStopReason = reason;
                            });
                          }
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppColors.danger),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: const Icon(Icons.warning_amber_rounded, color: AppColors.danger),
                          label: const Text('I NEED HELP', style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.bold)),
                          onPressed: () {
                            Navigator.pop(ctx);
                            _handleNeedHelpPressed(currentPos);
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.success,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: const Icon(Icons.check_circle_outline, color: Colors.black),
                          label: const Text("YES, I'M SAFE", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                          onPressed: () {
                            Navigator.pop(ctx);
                            _handleSafeConfirmed();
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _handleSafeConfirmed() {
    _safetyCheckTimer?.cancel();
    setState(() {
      _isSafetyCheckActive = false;
      _stillnessStartTime = null;
    });

    final currentUid = _authService.currentUser?.uid ?? MockDataState().currentUser.id;
    _safetyService.resolveActiveAlertsForUser(widget.rideId, currentUid);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("🟢 Safety status confirmed! Returning to normal monitoring."),
        backgroundColor: AppColors.success,
      ),
    );
  }

  Future<void> _handleNoResponseTimeout(Position pos) async {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    }

    _safetyCheckTimer?.cancel();
    setState(() {
      _isSafetyCheckActive = false;
      _stillnessStartTime = null;
    });

    final currentUid = _authService.currentUser?.uid ?? MockDataState().currentUser.id;
    final currentName = _authService.currentUser?.displayName ?? MockDataState().currentUser.name;

    await _safetyService.createSafetyAlert(
      rideId: widget.rideId,
      userId: currentUid,
      userName: currentName,
      type: AppConstants.alertTypeNoResponse,
      message: 'Rider did not respond to the safety check.',
      latitude: pos.latitude,
      longitude: pos.longitude,
      speed: pos.speed > 0 ? (pos.speed * 3.6) : 0.0,
      stopReason: _selectedStopReason,
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('⚠️ No response detected! Safety alert broadcasted to convoy.'),
        backgroundColor: AppColors.danger,
        duration: Duration(seconds: 4),
      ),
    );
  }

  Future<void> _handleNeedHelpPressed(Position pos) async {
    _safetyCheckTimer?.cancel();
    setState(() {
      _isSafetyCheckActive = false;
      _stillnessStartTime = null;
    });

    final currentUid = _authService.currentUser?.uid ?? MockDataState().currentUser.id;
    final currentName = _authService.currentUser?.displayName ?? MockDataState().currentUser.name;

    await _safetyService.createSafetyAlert(
      rideId: widget.rideId,
      userId: currentUid,
      userName: currentName,
      type: AppConstants.alertTypeEmergency,
      message: 'Emergency assistance requested by $currentName.',
      latitude: pos.latitude,
      longitude: pos.longitude,
      speed: pos.speed > 0 ? (pos.speed * 3.6) : 0.0,
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('🚨 Emergency alert sent to convoy members!'),
        backgroundColor: AppColors.danger,
        duration: Duration(seconds: 4),
      ),
    );
  }

  void _handleEndRide(RideModel ride) {
    final currentUid = _authService.currentUser?.uid ?? MockDataState().currentUser.id;
    if (ride.adminId != currentUid) return;

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.flag_rounded, color: AppColors.warning, size: 28),
              SizedBox(width: 10),
              Text('END RIDE?', style: TextStyle(color: AppColors.warning, fontWeight: FontWeight.bold)),
            ],
          ),
          content: const Text(
            'Are you sure you want to complete this convoy ride? Live tracking will be stopped and the ride summary will be generated.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('CANCEL', style: TextStyle(color: AppColors.textMuted)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.warning,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () async {
                Navigator.pop(ctx);
                await _executeEndRideWorkflow(ride);
              },
              child: const Text('END RIDE', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _executeEndRideWorkflow(RideModel ride) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final currentUid = _authService.currentUser?.uid ?? MockDataState().currentUser.id;

    // 1. Stop live tracking safely
    if (_trackingState.isTracking) {
      _stopLiveTracking();
    }

    // 2. Resolve active safety alerts for this user
    await _safetyService.resolveActiveAlertsForUser(ride.id, currentUid);

    // 3. Compute telemetry analytics from live locations subcollection snapshots
    double maxSpeed = 0.0;
    double totalSpeed = 0.0;
    int speedCount = 0;

    try {
      final locsSnap = await LiveLocationService().streamRideLocations(ride.id).first;
      if (locsSnap.isNotEmpty) {
        for (final loc in locsSnap) {
          if (loc.speed > maxSpeed) {
            maxSpeed = loc.speed;
          }
          if (loc.speed > 0) {
            totalSpeed += loc.speed;
            speedCount++;
          }
        }
      }
    } catch (_) {}

    final avgSpeed = speedCount > 0 ? (totalSpeed / speedCount) : 0.0;
    final startTime = ride.startedAt ?? ride.createdAt ?? DateTime.now();
    final endTime = DateTime.now();
    final durationMinutes = endTime.difference(startTime).inMinutes;

    final summaryData = <String, dynamic>{
      if (maxSpeed > 0) 'maxSpeedKmH': double.parse(maxSpeed.toStringAsFixed(1)),
      if (avgSpeed > 0) 'averageSpeedKmH': double.parse(avgSpeed.toStringAsFixed(1)),
      if (durationMinutes >= 0) 'durationMinutes': durationMinutes,
    };

    // 4. Update ride status in Firestore: active -> completed
    await _rideService.endRide(ride.id, summaryData: summaryData);

    if (!mounted) return;
    messenger.showSnackBar(
      const SnackBar(
        content: Text('🏁 Convoy Ride completed! Redirecting to Ride Summary...'),
        backgroundColor: AppColors.success,
      ),
    );

    // 5. Navigate to Ride Summary Screen
    navigator.pushReplacementNamed('/ride-summary', arguments: ride.id);
  }

  void _triggerManualSOS() {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.warning_rounded, color: AppColors.danger, size: 28),
              SizedBox(width: 10),
              Text('EMERGENCY SOS', style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.bold)),
            ],
          ),
          content: const Text(
            'Are you sure you want to send an emergency SOS alert to all convoy members?',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('CANCEL', style: TextStyle(color: AppColors.textMuted)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.danger,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () async {
                Navigator.pop(ctx);
                final currentUid = _authService.currentUser?.uid ?? MockDataState().currentUser.id;
                final currentName = _authService.currentUser?.displayName ?? MockDataState().currentUser.name;
                final pos = _trackingState.currentPosition;

                await _safetyService.createSafetyAlert(
                  rideId: widget.rideId,
                  userId: currentUid,
                  userName: currentName,
                  type: AppConstants.alertTypeManualSOS,
                  message: 'Emergency assistance requested by $currentName.',
                  latitude: pos?.latitude,
                  longitude: pos?.longitude,
                  speed: pos != null && pos.speed > 0 ? (pos.speed * 3.6) : 0.0,
                );

                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('🚨 SOS Alert Sent! Convoy has been notified.'),
                    backgroundColor: AppColors.danger,
                  ),
                );
              },
              child: const Text('SEND EMERGENCY ALERT', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildGroupSafetyAlertsSection() {
    return StreamBuilder<List<SafetyAlertModel>>(
      stream: _safetyService.streamActiveAlerts(widget.rideId),
      builder: (context, snapshot) {
        final alerts = snapshot.data ?? [];
        final currentUid = _authService.currentUser?.uid ?? MockDataState().currentUser.id;

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: alerts.isNotEmpty ? AppColors.danger.withValues(alpha: 0.1) : AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: alerts.isNotEmpty ? AppColors.danger.withValues(alpha: 0.5) : AppColors.border,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        alerts.isNotEmpty ? Icons.warning_amber_rounded : Icons.shield_rounded,
                        color: alerts.isNotEmpty ? AppColors.danger : AppColors.success,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'SAFETY ALERTS',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                  if (alerts.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.danger,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${alerts.length} ACTIVE',
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    )
                  else
                    const Text(
                      '🟢 Convoy Safe',
                      style: TextStyle(fontSize: 12, color: AppColors.success, fontWeight: FontWeight.w600),
                    ),
                ],
              ),
              if (alerts.isEmpty) ...[
                const SizedBox(height: 6),
                const Text(
                  'No active safety alerts. All tracked riders operating normally.',
                  style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                ),
              ] else ...[
                const SizedBox(height: 12),
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: alerts.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final alert = alerts[index];
                    final isUserAlert = alert.userId == currentUid;

                    return Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: alert.isEmergency || alert.isManualSOS
                              ? AppColors.danger.withValues(alpha: 0.8)
                              : AppColors.warning.withValues(alpha: 0.6),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                alert.userName,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: alert.isEmergency || alert.isManualSOS ? AppColors.danger : AppColors.warning,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  alert.type.replaceAll('_', ' ').toUpperCase(),
                                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black),
                                ),
                              ),
                              const Spacer(),
                              Text(
                                alert.status.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: alert.isAcknowledged ? AppColors.info : AppColors.danger,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            alert.message,
                            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                          ),
                          if (alert.stopReason != null && alert.stopReason!.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              'Reason: ${alert.stopReason}',
                              style: const TextStyle(fontSize: 11, color: AppColors.textMuted, fontStyle: FontStyle.italic),
                            ),
                          ],
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              if (alert.status == AppConstants.alertStatusActive && !isUserAlert)
                                TextButton(
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    minimumSize: Size.zero,
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  onPressed: () {
                                    _safetyService.acknowledgeSafetyAlert(widget.rideId, alert.alertId, currentUid);
                                  },
                                  child: const Text('ACKNOWLEDGE', style: TextStyle(fontSize: 11, color: AppColors.info, fontWeight: FontWeight.bold)),
                                ),
                              const SizedBox(width: 8),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.success,
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                onPressed: () {
                                  _safetyService.resolveSafetyAlert(widget.rideId, alert.alertId, currentUid);
                                },
                                child: const Text('RESOLVE', style: TextStyle(fontSize: 11, color: Colors.black, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildMemberTile({
    required String name,
    required String bikeModel,
    required bool isAdmin,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: isAdmin ? AppColors.primary.withValues(alpha: 0.2) : AppColors.surfaceLight,
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : 'M',
              style: TextStyle(
                color: isAdmin ? AppColors.primary : AppColors.textPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (isAdmin) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'ADMIN',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  bikeModel,
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          const Icon(Icons.signal_cellular_alt, color: AppColors.success, size: 18),
        ],
      ),
    );
  }

  Widget _buildLiveTrackingCard() {
    final pos = _trackingState.currentPosition;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _trackingState.isTracking ? AppColors.surface : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _trackingState.isTracking ? AppColors.success.withValues(alpha: 0.6) : AppColors.border,
          width: _trackingState.isTracking ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: _trackingState.isTracking ? AppColors.success : AppColors.textMuted,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _trackingState.isTracking ? '🟢 LIVE GPS TRACKING ACTIVE' : 'LIVE GPS TRACKING INACTIVE',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                      color: _trackingState.isTracking ? AppColors.success : AppColors.textMuted,
                    ),
                  ),
                ],
              ),
              if (_trackingState.isTracking)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${_trackingState.updateCount} Updates',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppColors.success,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (_trackingState.isTracking && pos != null) ...[
            Row(
              children: [
                Expanded(
                  child: _buildMetricTile(
                    label: 'LATITUDE',
                    value: '${pos.latitude.toStringAsFixed(5)}° N',
                    icon: Icons.location_on_outlined,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildMetricTile(
                    label: 'LONGITUDE',
                    value: '${pos.longitude.toStringAsFixed(5)}° E',
                    icon: Icons.explore_outlined,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _buildMetricTile(
                    label: 'SPEED',
                    value: '${_trackingState.speedInKmH.toStringAsFixed(1)} km/h',
                    icon: Icons.speed_rounded,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildMetricTile(
                    label: 'ACCURACY',
                    value: '±${pos.accuracy.toStringAsFixed(1)} m',
                    icon: Icons.gps_fixed_rounded,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Last Update: ${_trackingState.lastUpdateTime != null ? "${_trackingState.lastUpdateTime!.hour.toString().padLeft(2, '0')}:${_trackingState.lastUpdateTime!.minute.toString().padLeft(2, '0')}:${_trackingState.lastUpdateTime!.second.toString().padLeft(2, '0')}" : "--:--:--"}',
                  style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                ),
                Text(
                  'Duration: ${_trackingState.trackingDuration.inMinutes}m ${_trackingState.trackingDuration.inSeconds % 60}s',
                  style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                ),
              ],
            ),
            const SizedBox(height: 12),
            CustomButton(
              text: 'OPEN LIVE MAP',
              icon: Icons.map_rounded,
              onPressed: () {
                Navigator.pushNamed(context, '/live-map', arguments: widget.rideId);
              },
            ),
          ] else if (_trackingState.isTracking) ...[
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.success),
                    ),
                    SizedBox(width: 10),
                    Text(
                      'Acquiring first GPS position...',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
          ] else ...[
            const Text(
              'Ride is active! Tap Start Live Tracking below to start real-time GPS streaming.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMetricTile({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.primary),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.textMuted),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveGroupRiderStatusSection() {
    return StreamBuilder<List<LiveLocationModel>>(
      stream: LiveLocationService().streamRideLocations(widget.rideId),
      builder: (context, snapshot) {
        final liveLocations = snapshot.data ?? [];
        if (liveLocations.isEmpty) {
          return const SizedBox.shrink();
        }

        final activeCount = liveLocations.where((l) => l.isTracking).length;

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.radar_rounded, color: AppColors.primary, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'LIVE RIDER STATUS (PHASE 4C)',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.8,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '$activeCount/${liveLocations.length} Tracking',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: liveLocations.length,
                separatorBuilder: (context, index) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final loc = liveLocations[index];
                  final ts = loc.timestamp;
                  final timeStr = ts != null
                      ? '${ts.hour.toString().padLeft(2, '0')}:${ts.minute.toString().padLeft(2, '0')}:${ts.second.toString().padLeft(2, '0')}'
                      : 'Just now';

                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: loc.isTracking ? AppColors.success.withValues(alpha: 0.08) : AppColors.surfaceLight,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: loc.isTracking ? AppColors.success.withValues(alpha: 0.4) : AppColors.border,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 14,
                                  backgroundColor: loc.isTracking
                                      ? AppColors.success.withValues(alpha: 0.2)
                                      : AppColors.surface,
                                  child: Text(
                                    loc.userName.isNotEmpty ? loc.userName[0].toUpperCase() : 'R',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: loc.isTracking ? AppColors.success : AppColors.textMuted,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  loc.userName,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: loc.isTracking
                                    ? AppColors.success.withValues(alpha: 0.2)
                                    : AppColors.surfaceLight,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: BoxDecoration(
                                      color: loc.isTracking ? AppColors.success : AppColors.textMuted,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    loc.isTracking ? 'LIVE' : 'INACTIVE',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: loc.isTracking ? AppColors.success : AppColors.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${loc.latitude.toStringAsFixed(5)}° N, ${loc.longitude.toStringAsFixed(5)}° E',
                                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                              ),
                            ),
                            Text(
                              '${loc.speed.toStringAsFixed(1)} km/h',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Accuracy: ±${loc.accuracy.toStringAsFixed(1)} m',
                              style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
                            ),
                            Text(
                              'Updated: $timeStr',
                              style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
