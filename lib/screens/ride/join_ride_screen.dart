import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/mock/mock_data.dart';
import '../../services/ride_service.dart';
import '../../widgets/custom_button.dart';

class JoinRideScreen extends StatefulWidget {
  const JoinRideScreen({super.key});

  @override
  State<JoinRideScreen> createState() => _JoinRideScreenState();
}

class _JoinRideScreenState extends State<JoinRideScreen> {
  final _codeController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final RideService _rideService = RideService();

  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _handleJoin() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final code = _codeController.text.trim();

      try {
        final ride = await _rideService.joinRideByCode(code);

        // Also update local mock state for offline/demo fallback
        MockDataState().joinRide(code);

        if (!mounted) return;

        setState(() {
          _isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Joined ride "${ride.title}"!'),
            backgroundColor: AppColors.success,
          ),
        );

        Navigator.pushReplacementNamed(context, '/ride-group', arguments: ride.id);
      } catch (e) {
        if (!mounted) return;

        // Fallback check against MockDataState if Firestore search returned error
        final mockSuccess = MockDataState().joinRide(code);
        if (mockSuccess) {
          final mockRide = MockDataState().getRideByCode(code);
          setState(() {
            _isLoading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Joined ride "${mockRide?.title}"!'),
              backgroundColor: AppColors.success,
            ),
          );
          Navigator.pushReplacementNamed(context, '/ride-group', arguments: mockRide?.id);
          return;
        }

        final rawError = e.toString().replaceAll('Exception: ', '');
        setState(() {
          _isLoading = false;
          _errorMessage = rawError;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Join Convoy Ride'),
        backgroundColor: AppColors.background,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Enter Ride Code',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Ask your ride leader/admin for the 6-character convoy code.',
                  style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 32),

                TextFormField(
                  controller: _codeController,
                  textCapitalization: TextCapitalization.characters,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 4,
                    color: AppColors.primary,
                  ),
                  textAlign: TextAlign.center,
                  decoration: InputDecoration(
                    hintText: 'e.g. CG8942',
                    hintStyle: TextStyle(
                      fontSize: 20,
                      letterSpacing: 2,
                      color: AppColors.textMuted.withValues(alpha: 0.6),
                    ),
                    filled: true,
                    fillColor: AppColors.surface,
                    contentPadding: const EdgeInsets.symmetric(vertical: 20),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Please enter a valid ride code';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),

                if (_errorMessage != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.danger.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.danger),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: AppColors.danger, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(color: AppColors.danger, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 24),
                CustomButton(
                  text: 'Join Convoy Group',
                  isLoading: _isLoading,
                  icon: Icons.login_rounded,
                  onPressed: _handleJoin,
                ),

                const Spacer(),
                // Demo Hint Box
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.lightbulb_outline_rounded, color: AppColors.warning, size: 18),
                          SizedBox(width: 8),
                          Text(
                            'DEMO RIDE CODES',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppColors.warning,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Western Ghats Ride:', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                          ActionChip(
                            label: const Text('CG-8942', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
                            backgroundColor: AppColors.surfaceLight,
                            onPressed: () {
                              _codeController.text = 'CG-8942';
                            },
                          ),
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Coastal Sunday Ride:', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                          ActionChip(
                            label: const Text('CG-3410', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
                            backgroundColor: AppColors.surfaceLight,
                            onPressed: () {
                              _codeController.text = 'CG-3410';
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
