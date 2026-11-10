import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/mock/mock_data.dart';
import '../../models/ride_model.dart';
import '../../models/safety_alert_model.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/ride_service.dart';
import '../../services/safety_service.dart';
import '../../services/user_service.dart';
import '../../widgets/custom_button.dart';

class EmergencyAssistanceScreen extends StatefulWidget {
  final String? rideId;
  const EmergencyAssistanceScreen({super.key, this.rideId});

  @override
  State<EmergencyAssistanceScreen> createState() => _EmergencyAssistanceScreenState();
}

class _EmergencyAssistanceScreenState extends State<EmergencyAssistanceScreen> {
  final SafetyService _safetyService = SafetyService();
  final RideService _rideService = RideService();
  final AuthService _authService = AuthService();
  final UserService _userService = UserService();

  String? _selectedRideId;

  @override
  void initState() {
    super.initState();
    _selectedRideId = widget.rideId;
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final cleanPhone = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
    if (cleanPhone.isEmpty) return;

    final Uri phoneUri = Uri(scheme: 'tel', path: cleanPhone);
    try {
      if (await canLaunchUrl(phoneUri)) {
        await launchUrl(phoneUri);
      } else {
        // Fallback: Copy phone number to clipboard
        await Clipboard.setData(ClipboardData(text: cleanPhone));
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Phone dialer unavailable. Copied $cleanPhone to clipboard.'),
            backgroundColor: AppColors.info,
          ),
        );
      }
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: cleanPhone));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Copied $cleanPhone to clipboard.'),
          backgroundColor: AppColors.info,
        ),
      );
    }
  }

  Future<void> _shareEmergencyMessage(SafetyAlertModel alert) async {
    final timeStr = alert.createdAt != null
        ? '${alert.createdAt!.hour.toString().padLeft(2, '0')}:${alert.createdAt!.minute.toString().padLeft(2, '0')}'
        : 'Just now';

    final latStr = alert.latitude != null ? alert.latitude!.toStringAsFixed(5) : 'Unknown';
    final lngStr = alert.longitude != null ? alert.longitude!.toStringAsFixed(5) : 'Unknown';
    final speedStr = alert.speed != null ? '${alert.speed!.toStringAsFixed(1)} km/h' : '0.0 km/h';

    final msg = '''
🚨 CONVOYGUARD EMERGENCY ALERT 🚨
Rider: ${alert.userName}
Alert Type: ${alert.type.replaceAll('_', ' ').toUpperCase()}
Status: ${alert.status.toUpperCase()}
Location: Lat $latStr, Lng $lngStr
Speed: $speedStr
Time: $timeStr
Message: ${alert.message}
''';

    await Clipboard.setData(ClipboardData(text: msg));

    final Uri smsUri = Uri(
      scheme: 'sms',
      path: '',
      queryParameters: <String, String>{
        'body': msg,
      },
    );

    try {
      if (await canLaunchUrl(smsUri)) {
        await launchUrl(smsUri);
      }
    } catch (_) {}

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('📋 Emergency details copied to clipboard & SMS prompt prepared.'),
        backgroundColor: AppColors.success,
        duration: Duration(seconds: 3),
      ),
    );
  }

  void _showCallForHelpDialog(UserModel? userProfile) {
    final contact = userProfile?.emergencyContact;
    final bool hasContact = contact != null && contact.phone.trim().isNotEmpty;

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.phone_in_talk_rounded, color: AppColors.danger, size: 28),
              SizedBox(width: 10),
              Text('CALL FOR HELP', style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Select who you want to call for immediate assistance:',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
              ),
              const SizedBox(height: 16),
              if (hasContact) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.person_pin_rounded, color: AppColors.primary, size: 24),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              contact.name,
                              style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary, fontSize: 14),
                            ),
                            Text(
                              '${contact.relation.isNotEmpty ? contact.relation : "Contact"} • ${contact.phone}',
                              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
              ] else ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline_rounded, color: AppColors.warning, size: 20),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'No emergency contact linked in profile.',
                          style: TextStyle(color: AppColors.warning, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
              ],
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.local_hospital_rounded, color: AppColors.danger, size: 24),
                    SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'National Emergency Helpline',
                            style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary, fontSize: 14),
                          ),
                          Text(
                            'Police / Ambulance / SOS • 112',
                            style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('CANCEL', style: TextStyle(color: AppColors.textMuted)),
            ),
            if (!hasContact)
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.pushNamed(context, '/main', arguments: 2); // Go to Profile tab
                },
                child: const Text('SETUP CONTACT', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
              ),
            if (hasContact)
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.phone_rounded, color: Colors.black, size: 18),
                label: const Text('CALL CONTACT', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                onPressed: () {
                  Navigator.pop(ctx);
                  _makePhoneCall(contact.phone);
                },
              ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.danger,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.emergency_rounded, color: Colors.white, size: 18),
              label: const Text('CALL 112', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              onPressed: () {
                Navigator.pop(ctx);
                _makePhoneCall('112');
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final firebaseUser = _authService.currentUser;
    final currentUid = firebaseUser?.uid ?? MockDataState().currentUser.id;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.shield_rounded, color: AppColors.danger, size: 24),
            SizedBox(width: 8),
            Text('EMERGENCY ASSISTANCE'),
          ],
        ),
        backgroundColor: AppColors.background,
        actions: [
          IconButton(
            icon: const Icon(Icons.chat_bubble_outline_rounded, color: AppColors.primary),
            tooltip: 'Convoy Chat',
            onPressed: () {
              Navigator.pushNamed(context, '/main', arguments: 1); // Switch to Chat tab
            },
          ),
        ],
      ),
      body: SafeArea(
        child: StreamBuilder<UserModel?>(
          stream: _userService.streamUserProfile(currentUid),
          builder: (context, userSnap) {
            final userProfile = userSnap.data;

            return StreamBuilder<List<RideModel>>(
              stream: _rideService.streamUserRides(currentUid),
              builder: (context, ridesSnap) {
                final rides = ridesSnap.data ?? [];
                
                // Determine target rideId (either selected, parameter, active, or first)
                String targetRideId = _selectedRideId ?? '';
                if (targetRideId.isEmpty && rides.isNotEmpty) {
                  final active = rides.where((r) => r.status.toLowerCase() == 'active');
                  targetRideId = active.isNotEmpty ? active.first.id : rides.first.id;
                }

                return StreamBuilder<List<SafetyAlertModel>>(
                  stream: _safetyService.streamActiveAlerts(targetRideId),
                  builder: (context, alertsSnap) {
                    final activeAlerts = alertsSnap.data ?? [];
                    final userActiveAlert = activeAlerts.firstWhere(
                      (a) => a.userId == currentUid,
                      orElse: () => const SafetyAlertModel(alertId: '', rideId: '', userId: '', userName: '', type: '', message: ''),
                    );
                    final bool hasUserActiveAlert = userActiveAlert.alertId.isNotEmpty;

                    return SingleChildScrollView(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 1. Ride Selector if multiple rides exist
                          if (rides.length > 1) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: targetRideId.isNotEmpty ? targetRideId : rides.first.id,
                                  isExpanded: true,
                                  dropdownColor: AppColors.surface,
                                  icon: const Icon(Icons.arrow_drop_down, color: AppColors.primary),
                                  items: rides.map((r) {
                                    return DropdownMenuItem<String>(
                                      value: r.id,
                                      child: Text(
                                        'Ride: ${r.title} (${r.status.toUpperCase()})',
                                        style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (val) {
                                    if (val != null) {
                                      setState(() {
                                        _selectedRideId = val;
                                      });
                                    }
                                  },
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],

                          // 2. Convoy Safety Status Top Banner
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: activeAlerts.isNotEmpty
                                  ? AppColors.danger.withValues(alpha: 0.15)
                                  : AppColors.success.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: activeAlerts.isNotEmpty
                                    ? AppColors.danger.withValues(alpha: 0.6)
                                    : AppColors.success.withValues(alpha: 0.4),
                                width: 1.5,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: activeAlerts.isNotEmpty ? AppColors.danger : AppColors.success,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    activeAlerts.isNotEmpty ? Icons.warning_rounded : Icons.shield_rounded,
                                    color: Colors.black,
                                    size: 28,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        activeAlerts.isNotEmpty ? '🔴 EMERGENCY / NEEDS ATTENTION' : '🟢 Convoy Safe',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: activeAlerts.isNotEmpty ? AppColors.danger : AppColors.success,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        activeAlerts.isNotEmpty
                                            ? '${activeAlerts.length} active safety alert(s) reported in convoy.'
                                            : 'No active emergency alerts. All tracked riders operating normally.',
                                        style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),

                          // 3. Rider Self-Service Banner if current rider has an active alert
                          if (hasUserActiveAlert) ...[
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppColors.warning.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: AppColors.warning),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Row(
                                    children: [
                                      Icon(Icons.person_pin_circle_rounded, color: AppColors.warning, size: 22),
                                      SizedBox(width: 8),
                                      Text(
                                        'YOUR ACTIVE SAFETY ALERT',
                                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.warning),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'An active ${userActiveAlert.type.replaceAll("_", " ")} alert is broadcasted for you: "${userActiveAlert.message}"',
                                    style: const TextStyle(fontSize: 12, color: AppColors.textPrimary),
                                  ),
                                  const SizedBox(height: 12),
                                  CustomButton(
                                    text: "YES, I'M SAFE NOW (RESOLVE MY ALERT)",
                                    icon: Icons.check_circle_rounded,
                                    onPressed: () async {
                                      final messenger = ScaffoldMessenger.of(context);
                                      await _safetyService.resolveActiveAlertsForUser(targetRideId, currentUid);
                                      if (!mounted) return;
                                      messenger.showSnackBar(
                                        const SnackBar(
                                          content: Text("🟢 Safety status confirmed! Alert resolved."),
                                          backgroundColor: AppColors.success,
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                          ],

                          // 4. Emergency Quick Action Controls
                          const Text(
                            'EMERGENCY CONTROLS',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2, color: AppColors.textMuted),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: CustomButton(
                                  text: 'CALL FOR HELP',
                                  icon: Icons.phone_in_talk_rounded,
                                  isDanger: true,
                                  onPressed: () => _showCallForHelpDialog(userProfile),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: CustomButton(
                                  text: 'CONVOY CHAT',
                                  icon: Icons.chat_bubble_outline_rounded,
                                  onPressed: () {
                                    Navigator.pushNamed(context, '/main', arguments: 1);
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),

                          // 5. Active Safety & Emergency Alerts List
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'ACTIVE CONVOY ALERTS',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2, color: AppColors.textMuted),
                              ),
                              Text(
                                '${activeAlerts.length} Active',
                                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),

                          if (activeAlerts.isEmpty)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: const Column(
                                children: [
                                  Icon(Icons.check_circle_outline_rounded, color: AppColors.success, size: 40),
                                  SizedBox(height: 10),
                                  Text(
                                    'No Active Convoy Emergency Alerts',
                                    style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary, fontSize: 15),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'If a rider experiences stillness or triggers an SOS, real-time alerts will display here.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                                  ),
                                ],
                              ),
                            )
                          else
                            ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: activeAlerts.length,
                              separatorBuilder: (context, index) => const SizedBox(height: 12),
                              itemBuilder: (context, index) {
                                final alert = activeAlerts[index];
                                final isUserAlert = alert.userId == currentUid;
                                final timeStr = alert.createdAt != null
                                    ? '${alert.createdAt!.hour.toString().padLeft(2, '0')}:${alert.createdAt!.minute.toString().padLeft(2, '0')}'
                                    : 'Just now';

                                return Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: AppColors.surface,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: alert.isEmergency || alert.isManualSOS
                                          ? AppColors.danger
                                          : AppColors.warning,
                                      width: 1.5,
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          CircleAvatar(
                                            backgroundColor: alert.isEmergency || alert.isManualSOS
                                                ? AppColors.danger.withValues(alpha: 0.2)
                                                : AppColors.warning.withValues(alpha: 0.2),
                                            child: Text(
                                              alert.userName.isNotEmpty ? alert.userName[0].toUpperCase() : 'R',
                                              style: TextStyle(
                                                color: alert.isEmergency || alert.isManualSOS ? AppColors.danger : AppColors.warning,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    Text(
                                                      alert.userName,
                                                      style: const TextStyle(
                                                        fontSize: 15,
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
                                                  ],
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  'Triggered at $timeStr • Status: ${alert.status.toUpperCase()}',
                                                  style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        alert.message,
                                        style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                                      ),
                                      if (alert.stopReason != null && alert.stopReason!.isNotEmpty) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          'Reason: ${alert.stopReason}',
                                          style: const TextStyle(fontSize: 12, color: AppColors.textMuted, fontStyle: FontStyle.italic),
                                        ),
                                      ],
                                      const SizedBox(height: 12),
                                      // Telemetry Data Box
                                      Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: AppColors.card,
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                                          children: [
                                            Column(
                                              children: [
                                                const Text('LATITUDE', style: TextStyle(fontSize: 9, color: AppColors.textMuted, fontWeight: FontWeight.bold)),
                                                const SizedBox(height: 2),
                                                Text(
                                                  alert.latitude != null ? '${alert.latitude!.toStringAsFixed(4)}°' : 'N/A',
                                                  style: const TextStyle(fontSize: 12, color: AppColors.textPrimary, fontWeight: FontWeight.bold),
                                                ),
                                              ],
                                            ),
                                            Column(
                                              children: [
                                                const Text('LONGITUDE', style: TextStyle(fontSize: 9, color: AppColors.textMuted, fontWeight: FontWeight.bold)),
                                                const SizedBox(height: 2),
                                                Text(
                                                  alert.longitude != null ? '${alert.longitude!.toStringAsFixed(4)}°' : 'N/A',
                                                  style: const TextStyle(fontSize: 12, color: AppColors.textPrimary, fontWeight: FontWeight.bold),
                                                ),
                                              ],
                                            ),
                                            Column(
                                              children: [
                                                const Text('SPEED', style: TextStyle(fontSize: 9, color: AppColors.textMuted, fontWeight: FontWeight.bold)),
                                                const SizedBox(height: 2),
                                                Text(
                                                  alert.speed != null ? '${alert.speed!.toStringAsFixed(1)} km/h' : '0 km/h',
                                                  style: const TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.bold),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 12),

                                      // Alert Action Buttons
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: [
                                          OutlinedButton.icon(
                                            style: OutlinedButton.styleFrom(
                                              side: const BorderSide(color: AppColors.primary),
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                            ),
                                            icon: const Icon(Icons.map_rounded, size: 16, color: AppColors.primary),
                                            label: const Text('LOCATE RIDER', style: TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.bold)),
                                            onPressed: () {
                                              Navigator.pushNamed(context, '/live-map', arguments: targetRideId);
                                            },
                                          ),
                                          OutlinedButton.icon(
                                            style: OutlinedButton.styleFrom(
                                              side: const BorderSide(color: AppColors.textSecondary),
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                            ),
                                            icon: const Icon(Icons.share_outlined, size: 16, color: AppColors.textPrimary),
                                            label: const Text('SHARE DETAILS', style: TextStyle(fontSize: 11, color: AppColors.textPrimary)),
                                            onPressed: () => _shareEmergencyMessage(alert),
                                          ),
                                          if (alert.status == AppConstants.alertStatusActive && !isUserAlert)
                                            ElevatedButton(
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: AppColors.info,
                                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                              ),
                                              onPressed: () {
                                                _safetyService.acknowledgeSafetyAlert(targetRideId, alert.alertId, currentUid);
                                              },
                                              child: const Text('ACKNOWLEDGE', style: TextStyle(fontSize: 11, color: Colors.black, fontWeight: FontWeight.bold)),
                                            ),
                                          ElevatedButton(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: AppColors.success,
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                            ),
                                            onPressed: () {
                                              _safetyService.resolveSafetyAlert(targetRideId, alert.alertId, currentUid);
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
                      ),
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }
}
