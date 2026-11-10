import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../models/ride_model.dart';
import '../../models/safety_alert_model.dart';
import '../../services/ride_service.dart';
import '../../services/safety_service.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/status_badge.dart';

class RideSummaryScreen extends StatefulWidget {
  final String rideId;
  const RideSummaryScreen({super.key, required this.rideId});

  @override
  State<RideSummaryScreen> createState() => _RideSummaryScreenState();
}

class _RideSummaryScreenState extends State<RideSummaryScreen> {
  final RideService _rideService = RideService();
  final SafetyService _safetyService = SafetyService();

  String _formatDuration(DateTime? start, DateTime? end) {
    if (start == null) return 'N/A';
    final endTime = end ?? DateTime.now();
    final diff = endTime.difference(start);

    if (diff.isNegative) return '0m';

    final hours = diff.inHours;
    final minutes = diff.inMinutes.remainder(60);
    final seconds = diff.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    } else {
      return '${seconds}s';
    }
  }

  String _formatTime(DateTime? dt) {
    if (dt == null) return 'N/A';
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')} (${dt.day}/${dt.month}/${dt.year})';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.assessment_rounded, color: AppColors.primary, size: 24),
            SizedBox(width: 8),
            Text('CONVOY RIDE SUMMARY'),
          ],
        ),
        backgroundColor: AppColors.background,
        actions: [
          IconButton(
            icon: const Icon(Icons.map_rounded, color: AppColors.primary),
            tooltip: 'View Live Map',
            onPressed: () {
              Navigator.pushNamed(context, '/live-map', arguments: widget.rideId);
            },
          ),
        ],
      ),
      body: SafeArea(
        child: StreamBuilder<RideModel?>(
          stream: _rideService.streamRide(widget.rideId),
          builder: (context, snapshot) {
            final ride = snapshot.data;

            if (snapshot.connectionState == ConnectionState.waiting && ride == null) {
              return const Center(child: CircularProgressIndicator(color: AppColors.primary));
            }

            if (ride == null) {
              return Scaffold(
                body: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline_rounded, color: AppColors.danger, size: 48),
                      const SizedBox(height: 12),
                      const Text('Ride summary not found.', style: TextStyle(color: AppColors.textSecondary)),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Go Back'),
                      ),
                    ],
                  ),
                ),
              );
            }

            final startTime = ride.startedAt ?? ride.createdAt;
            final endTime = ride.completedAt ?? ride.updatedAt;
            final durationStr = _formatDuration(startTime, endTime);

            return SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Header Card (Ride Overview)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const StatusBadge(status: 'COMPLETED'),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
                              ),
                              child: Text(
                                'CODE: ${ride.rideCode}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                  letterSpacing: 1,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Text(
                          ride.title,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.navigation_rounded, size: 16, color: AppColors.primary),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                '${ride.startLocation} ➔ ${ride.destination}',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Divider(color: AppColors.border),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.person, size: 14, color: AppColors.textMuted),
                            const SizedBox(width: 4),
                            Text('Admin: ${ride.adminName}', style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                            const Spacer(),
                            const Icon(Icons.access_time_rounded, size: 14, color: AppColors.textMuted),
                            const SizedBox(width: 4),
                            Text(_formatTime(endTime), style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 2. Trip Statistics Section
                  const Text(
                    'TRIP TELEMETRY STATISTICS',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatTile(
                          title: 'TOTAL DISTANCE',
                          value: ride.totalDistanceKm != null && ride.totalDistanceKm! > 0
                              ? '${ride.totalDistanceKm!.toStringAsFixed(1)} km'
                              : 'No telemetry',
                          icon: Icons.straighten_rounded,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatTile(
                          title: 'TOTAL DURATION',
                          value: durationStr,
                          icon: Icons.timer_outlined,
                          color: AppColors.info,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatTile(
                          title: 'AVERAGE SPEED',
                          value: ride.averageSpeedKmH != null && ride.averageSpeedKmH! > 0
                              ? '${ride.averageSpeedKmH!.toStringAsFixed(1)} km/h'
                              : 'N/A',
                          icon: Icons.speed_rounded,
                          color: AppColors.success,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatTile(
                          title: 'MAX SPEED',
                          value: ride.maxSpeedKmH != null && ride.maxSpeedKmH! > 0
                              ? '${ride.maxSpeedKmH!.toStringAsFixed(1)} km/h'
                              : 'N/A',
                          icon: Icons.bolt_rounded,
                          color: AppColors.warning,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // 3. Convoy & Breakpoints Section
                  const Text(
                    'CONVOY & BREAKPOINTS',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.groups_rounded, color: AppColors.primary, size: 20),
                                SizedBox(width: 8),
                                Text('Total Convoy Riders', style: TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.bold)),
                              ],
                            ),
                            Text(
                              '${ride.members.length} Riders',
                              style: const TextStyle(color: AppColors.primary, fontSize: 14, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Divider(color: AppColors.border),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.pin_drop_rounded, color: AppColors.secondary, size: 20),
                                SizedBox(width: 8),
                                Text('Planned Breakpoints', style: TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.bold)),
                              ],
                            ),
                            Text(
                              '${ride.breakpoints.length} Total',
                              style: const TextStyle(color: AppColors.secondary, fontSize: 14, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        if (ride.breakpoints.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: ride.breakpoints.length,
                            separatorBuilder: (context, index) => const SizedBox(height: 6),
                            itemBuilder: (context, index) {
                              final bp = ride.breakpoints[index];
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: AppColors.card,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    Text('${index + 1}. ${bp.name}', style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
                                    const Spacer(),
                                    Text('(${bp.type})', style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
                                  ],
                                ),
                              );
                            },
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 4. Historical Safety Incident Recap
                  const Text(
                    'SAFETY & EMERGENCY LOG',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 10),
                  StreamBuilder<List<SafetyAlertModel>>(
                    stream: _safetyService.streamAllAlerts(widget.rideId),
                    builder: (context, alertsSnap) {
                      final alerts = alertsSnap.data ?? [];

                      return Container(
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
                                    Icon(Icons.shield_outlined, color: AppColors.warning, size: 20),
                                    SizedBox(width: 8),
                                    Text('Ride Safety Log', style: TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: alerts.isNotEmpty ? AppColors.warning.withValues(alpha: 0.15) : AppColors.success.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '${alerts.length} Incidents',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: alerts.isNotEmpty ? AppColors.warning : AppColors.success,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            if (alerts.isEmpty) ...[
                              const Text(
                                '🟢 Clean Ride Safety Record. No safety or emergency incidents logged during this trip.',
                                style: TextStyle(color: AppColors.success, fontSize: 12),
                              ),
                            ] else ...[
                              ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: alerts.length,
                                separatorBuilder: (context, index) => const SizedBox(height: 8),
                                itemBuilder: (context, index) {
                                  final alert = alerts[index];
                                  final timeStr = alert.createdAt != null
                                      ? '${alert.createdAt!.hour.toString().padLeft(2, '0')}:${alert.createdAt!.minute.toString().padLeft(2, '0')}'
                                      : 'N/A';

                                  return Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: AppColors.card,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: alert.isEmergency || alert.isManualSOS
                                            ? AppColors.danger.withValues(alpha: 0.5)
                                            : AppColors.warning.withValues(alpha: 0.4),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          alert.isEmergency || alert.isManualSOS ? Icons.warning_rounded : Icons.info_outline_rounded,
                                          color: alert.isEmergency || alert.isManualSOS ? AppColors.danger : AppColors.warning,
                                          size: 20,
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Text(alert.userName, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary, fontSize: 13)),
                                                  const SizedBox(width: 6),
                                                  Text('• ${alert.type.replaceAll('_', ' ').toUpperCase()}', style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
                                                ],
                                              ),
                                              const SizedBox(height: 2),
                                              Text(alert.message, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.end,
                                          children: [
                                            Text(alert.status.toUpperCase(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.success)),
                                            Text(timeStr, style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
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
                  ),
                  const SizedBox(height: 24),

                  // 5. Action Footer Buttons
                  CustomButton(
                    text: 'VIEW CONVOY LIVE MAP',
                    icon: Icons.map_rounded,
                    onPressed: () {
                      Navigator.pushNamed(context, '/live-map', arguments: widget.rideId);
                    },
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.primary),
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    icon: const Icon(Icons.dashboard_rounded, color: AppColors.primary),
                    label: const Text('RETURN TO DASHBOARD', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                    onPressed: () {
                      Navigator.pushNamedAndRemoveUntil(context, '/main', (route) => false);
                    },
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildStatTile({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textMuted, letterSpacing: 0.8),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
