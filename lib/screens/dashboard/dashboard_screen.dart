import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/mock/mock_data.dart';
import '../../models/ride_model.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/ride_service.dart';
import '../../services/user_service.dart';
import '../../services/notification_service.dart';
import '../../widgets/status_badge.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final UserService _userService = UserService();
  final RideService _rideService = RideService();
  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();
    final firebaseUser = _authService.currentUser;
    if (firebaseUser != null && firebaseUser.uid.isNotEmpty) {
      NotificationService().setCurrentUser(firebaseUser.uid);
    }
  }

  @override
  Widget build(BuildContext context) {
    final firebaseUser = _authService.currentUser;
    final uid = firebaseUser?.uid ?? '';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.two_wheeler_rounded, color: AppColors.primary, size: 22),
            ),
            const SizedBox(width: 10),
            const Text('CONVOYGUARD'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none_rounded),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('No new safety alerts.')),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Real-time User Greeting Banner from Firestore
              StreamBuilder<UserModel?>(
                stream: _userService.streamUserProfile(uid),
                builder: (context, userSnap) {
                  final user = userSnap.data ??
                      UserModel(
                        id: uid,
                        name: firebaseUser?.displayName ?? MockDataState().currentUser.name,
                        email: firebaseUser?.email ?? MockDataState().currentUser.email,
                        phone: MockDataState().currentUser.phone,
                        bikeModel: MockDataState().currentUser.bikeModel,
                      );

                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: AppColors.cardGradient,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: AppColors.border),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 26,
                          backgroundColor: AppColors.primary.withValues(alpha: 0.2),
                          child: Text(
                            user.name.isNotEmpty ? user.name[0].toUpperCase() : 'R',
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
                              fontSize: 22,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Welcome, ${user.name.isNotEmpty ? user.name : "Rider"}!',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(Icons.directions_bike_rounded, size: 14, color: AppColors.textSecondary),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      user.bikeModel.isNotEmpty ? user.bikeModel : 'Convoy Rider',
                                      style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                                      overflow: TextOverflow.ellipsis,
                                    ),
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
              const SizedBox(height: 24),

              // Quick Actions: Create Ride & Join Ride
              const Text(
                'QUICK ACTIONS',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildActionCard(
                      context,
                      title: 'Create Ride',
                      subtitle: 'Start new convoy',
                      icon: Icons.add_circle_outline_rounded,
                      color: AppColors.primary,
                      onTap: () => Navigator.pushNamed(context, '/create-ride'),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _buildActionCard(
                      context,
                      title: 'Join Ride',
                      subtitle: 'Enter ride code',
                      icon: Icons.qr_code_scanner_rounded,
                      color: AppColors.secondary,
                      onTap: () => Navigator.pushNamed(context, '/join-ride'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Real-time Firestore My Rides Section (Active, Scheduled, Completed)
              StreamBuilder<List<RideModel>>(
                stream: _rideService.streamUserRides(uid),
                builder: (context, ridesSnap) {
                  List<RideModel> rides = ridesSnap.data ?? [];
                  if (rides.isEmpty && uid.isEmpty) {
                    rides = MockDataState().rides;
                  }

                  final activeRides = rides.where((r) => r.status.toLowerCase() == 'active').toList();
                  final upcomingRides = rides.where((r) => r.status.toLowerCase() == 'scheduled').toList();
                  final completedRides = rides.where((r) => r.status.toLowerCase() == 'completed').toList();

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Active Rides Section
                      if (activeRides.isNotEmpty) ...[
                        _buildSectionHeader('ACTIVE RIDES (${activeRides.length})', AppColors.success),
                        const SizedBox(height: 10),
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: activeRides.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 10),
                          itemBuilder: (context, index) => _buildRideCard(context, activeRides[index]),
                        ),
                        const SizedBox(height: 20),
                      ],

                      // Upcoming Rides Section
                      if (upcomingRides.isNotEmpty) ...[
                        _buildSectionHeader('UPCOMING RIDES (${upcomingRides.length})', AppColors.info),
                        const SizedBox(height: 10),
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: upcomingRides.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 10),
                          itemBuilder: (context, index) => _buildRideCard(context, upcomingRides[index]),
                        ),
                        const SizedBox(height: 20),
                      ],

                      // Completed Rides Section
                      if (completedRides.isNotEmpty) ...[
                        _buildSectionHeader('COMPLETED RIDES (${completedRides.length})', AppColors.textMuted),
                        const SizedBox(height: 10),
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: completedRides.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 10),
                          itemBuilder: (context, index) => _buildRideCard(context, completedRides[index]),
                        ),
                        const SizedBox(height: 20),
                      ],

                      // Empty state
                      if (activeRides.isEmpty && upcomingRides.isEmpty && completedRides.isEmpty) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: const [
                            Text(
                              'MY CONVOY RIDES',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.2,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: const Center(
                            child: Text(
                              'No rides found. Tap Create Ride or Join Ride to get started!',
                              style: TextStyle(color: AppColors.textSecondary),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                    ],
                  );
                },
              ),

              // Emergency Contact Safety Card
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'SAFETY & ASSISTANCE',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                      color: AppColors.textMuted,
                    ),
                  ),
                  InkWell(
                    onTap: () => Navigator.pushNamed(context, '/emergency-assistance'),
                    child: const Row(
                      children: [
                        Text(
                          'Emergency Dashboard',
                          style: TextStyle(fontSize: 12, color: AppColors.danger, fontWeight: FontWeight.bold),
                        ),
                        Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.danger),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              StreamBuilder<UserModel?>(
                stream: _userService.streamUserProfile(uid),
                builder: (context, userSnap) {
                  final user = userSnap.data ?? MockDataState().currentUser;
                  final contact = user.emergencyContact;

                  return GestureDetector(
                    onTap: () => Navigator.pushNamed(context, '/emergency-assistance'),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.danger.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.shield_rounded, color: AppColors.danger, size: 24),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Emergency Assistance Dashboard',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  contact != null && contact.name.isNotEmpty
                                      ? 'Linked Contact: ${contact.name} (${contact.relation})'
                                      : 'Tap to view live convoy emergency status & assistance',
                                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.arrow_forward_ios_rounded, color: AppColors.danger, size: 16),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, Color color) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildActionCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRideCard(BuildContext context, RideModel ride) {
    final bool isCompleted = ride.status.toLowerCase() == 'completed';
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          if (isCompleted) {
            Navigator.pushNamed(context, '/ride-summary', arguments: ride.id);
          } else {
            Navigator.pushNamed(context, '/ride-group', arguments: ride.id);
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  StatusBadge(status: ride.status),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceLight,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'CODE: ${ride.rideCode}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                ride.title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.location_on_outlined, size: 16, color: AppColors.primary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '${ride.startLocation} ➔ ${ride.destination}',
                      style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(color: AppColors.border, height: 1),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(Icons.people_outline_rounded, size: 16, color: AppColors.textMuted),
                  const SizedBox(width: 6),
                  Text(
                    '${ride.members.length} Riders',
                    style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                  ),
                  const SizedBox(width: 16),
                  const Icon(Icons.alt_route_rounded, size: 16, color: AppColors.textMuted),
                  const SizedBox(width: 6),
                  Text(
                    '${ride.breakpoints.length} Breakpoints',
                    style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                  ),
                  const Spacer(),
                  const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.primary),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
