import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../../core/theme/app_colors.dart';
import '../../core/mock/mock_data.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/location_service.dart';
import '../../services/user_service.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final UserService _userService = UserService();
  final AuthService _authService = AuthService();

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _bikeController = TextEditingController();

  final _emergencyNameController = TextEditingController();
  final _emergencyPhoneController = TextEditingController();
  final _emergencyRelationController = TextEditingController(text: 'Spouse/Family');

  bool _isEditingEmergency = false;
  bool _isSaving = false;
  bool _initializedWithFirestore = false;

  bool _isFetchingLocation = false;
  Position? _currentPosition;
  String? _locationError;

  Future<void> _testGetLocation() async {
    setState(() {
      _isFetchingLocation = true;
      _locationError = null;
    });

    try {
      final position = await LocationService().getCurrentLocation();
      if (!mounted) return;
      setState(() {
        _currentPosition = position;
        _isFetchingLocation = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'GPS acquired: Lat ${position.latitude.toStringAsFixed(4)}, Lng ${position.longitude.toStringAsFixed(4)}',
          ),
          backgroundColor: AppColors.success,
        ),
      );
    } on GpsServiceDisabledException catch (e) {
      if (!mounted) return;
      setState(() {
        _locationError = e.message;
        _isFetchingLocation = false;
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
        _locationError = e.message;
        _isFetchingLocation = false;
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
        _locationError = e.message;
        _isFetchingLocation = false;
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
        _locationError = 'Failed to get location: ${e.toString()}';
        _isFetchingLocation = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to get location: ${e.toString()}'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _bikeController.dispose();
    _emergencyNameController.dispose();
    _emergencyPhoneController.dispose();
    _emergencyRelationController.dispose();
    super.dispose();
  }

  void _populateFields(UserModel user) {
    if (_initializedWithFirestore) return;
    _nameController.text = user.name;
    _phoneController.text = user.phone;
    _bikeController.text = user.bikeModel;

    if (user.emergencyContact != null) {
      _emergencyNameController.text = user.emergencyContact!.name;
      _emergencyPhoneController.text = user.emergencyContact!.phone;
      _emergencyRelationController.text = user.emergencyContact!.relation;
    }
    _initializedWithFirestore = true;
  }

  Future<void> _saveProfile() async {
    final firebaseUser = _authService.currentUser;
    final uid = firebaseUser?.uid;

    setState(() {
      _isSaving = true;
    });

    try {
      if (uid != null && uid.isNotEmpty) {
        // Save to Firestore
        await _userService.updateUserProfile(uid, {
          'name': _nameController.text.trim(),
          'phone': _phoneController.text.trim(),
          'bikeModel': _bikeController.text.trim(),
        });

        if (_emergencyNameController.text.trim().isNotEmpty) {
          await _userService.updateEmergencyContact(
            uid,
            name: _emergencyNameController.text.trim(),
            phone: _emergencyPhoneController.text.trim(),
            relation: _emergencyRelationController.text.trim(),
          );
        }
      }

      // Also update mock state for local fallback sync
      MockDataState().updateProfile(
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        bikeModel: _bikeController.text.trim(),
      );

      if (_emergencyNameController.text.trim().isNotEmpty) {
        MockDataState().updateEmergencyContact(
          EmergencyContact(
            name: _emergencyNameController.text.trim(),
            phone: _emergencyPhoneController.text.trim(),
            relation: _emergencyRelationController.text.trim(),
          ),
        );
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile & Emergency Contact saved to Firestore!'),
          backgroundColor: AppColors.success,
        ),
      );

      setState(() {
        _isSaving = false;
        _isEditingEmergency = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to update profile. Please try again.'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  void _handleLogout() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Log Out'),
        content: const Text('Are you sure you want to log out of ConvoyGuard?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
              minimumSize: const Size(80, 40),
            ),
            onPressed: () async {
              Navigator.pop(context);
              await AuthService().logout();
              MockDataState().logout();
              if (context.mounted) {
                Navigator.pushNamedAndRemoveUntil(context, '/welcome', (route) => false);
              }
            },
            child: const Text('Log Out'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final firebaseUser = _authService.currentUser;
    final uid = firebaseUser?.uid ?? '';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Rider Profile'),
        backgroundColor: AppColors.background,
      ),
      body: SafeArea(
        child: uid.isEmpty
            ? _buildProfileContent(MockDataState().currentUser)
            : StreamBuilder<UserModel?>(
                stream: _userService.streamUserProfile(uid),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting && !_initializedWithFirestore) {
                    return const Center(
                      child: CircularProgressIndicator(color: AppColors.primary),
                    );
                  }

                  final user = snapshot.data ??
                      UserModel(
                        id: uid,
                        name: firebaseUser?.displayName ?? MockDataState().currentUser.name,
                        email: firebaseUser?.email ?? MockDataState().currentUser.email,
                        phone: MockDataState().currentUser.phone,
                        bikeModel: MockDataState().currentUser.bikeModel,
                        emergencyContact: MockDataState().currentUser.emergencyContact,
                      );

                  _populateFields(user);

                  return _buildProfileContent(user);
                },
              ),
      ),
    );
  }

  Widget _buildProfileContent(UserModel user) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar & Name Card
          Center(
            child: Column(
              children: [
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 46,
                      backgroundColor: AppColors.primary.withValues(alpha: 0.2),
                      child: Text(
                        user.name.isNotEmpty ? user.name[0].toUpperCase() : 'R',
                        style: const TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.two_wheeler, size: 16, color: Colors.black),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  user.name.isNotEmpty ? user.name : 'Rider',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  user.email,
                  style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),

          // Personal Information Section
          const Text(
            'PERSONAL DETAILS',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 12),

          CustomTextField(
            controller: _nameController,
            label: 'Full Name',
            prefixIcon: Icons.person_outline,
          ),
          const SizedBox(height: 14),

          CustomTextField(
            controller: _phoneController,
            label: 'Phone Number',
            prefixIcon: Icons.phone_outlined,
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 14),

          CustomTextField(
            controller: _bikeController,
            label: 'Motorcycle Model',
            prefixIcon: Icons.two_wheeler_outlined,
            hint: 'e.g. Royal Enfield Himalayan 450',
          ),
          const SizedBox(height: 28),

          // Emergency Contact Section
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.shield, color: AppColors.warning, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'EMERGENCY CONTACT',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.0,
                            color: AppColors.warning,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: Icon(
                        _isEditingEmergency ? Icons.close : Icons.edit,
                        color: AppColors.primary,
                        size: 20,
                      ),
                      onPressed: () {
                        setState(() {
                          _isEditingEmergency = !_isEditingEmergency;
                        });
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                if (!_isEditingEmergency && user.emergencyContact != null && user.emergencyContact!.name.isNotEmpty) ...[
                  _buildInfoRow('Name:', user.emergencyContact!.name),
                  const SizedBox(height: 6),
                  _buildInfoRow('Phone:', user.emergencyContact!.phone),
                  const SizedBox(height: 6),
                  _buildInfoRow('Relation:', user.emergencyContact!.relation),
                ] else ...[
                  CustomTextField(
                    controller: _emergencyNameController,
                    label: 'Contact Name',
                    hint: 'e.g. Sarah Mercer',
                    prefixIcon: Icons.contact_phone_outlined,
                  ),
                  const SizedBox(height: 12),
                  CustomTextField(
                    controller: _emergencyPhoneController,
                    label: 'Emergency Phone',
                    hint: '+1 555-0199',
                    prefixIcon: Icons.phone_android_outlined,
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 12),
                  CustomTextField(
                    controller: _emergencyRelationController,
                    label: 'Relationship',
                    hint: 'Spouse, Parent, Friend',
                    prefixIcon: Icons.people_outline,
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 28),

          // GPS Location Test Section (Phase 4A)
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.location_on_rounded, color: AppColors.primary, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'GPS LOCATION TEST (PHASE 4A)',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (_currentPosition != null) ...[
                  _buildInfoRow('Latitude:', '${_currentPosition!.latitude.toStringAsFixed(6)}°'),
                  const SizedBox(height: 6),
                  _buildInfoRow('Longitude:', '${_currentPosition!.longitude.toStringAsFixed(6)}°'),
                  const SizedBox(height: 6),
                  _buildInfoRow('Accuracy:', '${_currentPosition!.accuracy.toStringAsFixed(1)} meters'),
                  const SizedBox(height: 6),
                  _buildInfoRow(
                    'Timestamp:',
                    '${_currentPosition!.timestamp.hour.toString().padLeft(2, '0')}:${_currentPosition!.timestamp.minute.toString().padLeft(2, '0')}:${_currentPosition!.timestamp.second.toString().padLeft(2, '0')}',
                  ),
                  const SizedBox(height: 14),
                ] else if (_locationError != null) ...[
                  Text(
                    _locationError!,
                    style: const TextStyle(color: AppColors.danger, fontSize: 13),
                  ),
                  const SizedBox(height: 14),
                ] else ...[
                  const Text(
                    'No location data acquired yet. Tap below to check permissions and test GPS location.',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                  ),
                  const SizedBox(height: 14),
                ],
                CustomButton(
                  text: _isFetchingLocation ? 'Acquiring GPS...' : 'Test GPS Location',
                  icon: Icons.my_location_rounded,
                  isLoading: _isFetchingLocation,
                  onPressed: _testGetLocation,
                ),
              ],
            ),
          ),

          const SizedBox(height: 28),

          CustomButton(
            text: 'Save Changes',
            icon: Icons.save_outlined,
            isLoading: _isSaving,
            onPressed: _saveProfile,
          ),

          const SizedBox(height: 14),

          CustomButton(
            text: 'Log Out',
            isDanger: true,
            icon: Icons.logout_rounded,
            onPressed: _handleLogout,
          ),

          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }
}
