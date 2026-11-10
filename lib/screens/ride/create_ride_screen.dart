import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/mock/mock_data.dart';
import '../../models/breakpoint_model.dart';
import '../../services/ride_service.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';

class CreateRideScreen extends StatefulWidget {
  const CreateRideScreen({super.key});

  @override
  State<CreateRideScreen> createState() => _CreateRideScreenState();
}

class _CreateRideScreenState extends State<CreateRideScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _startLocationController = TextEditingController();
  final _destinationController = TextEditingController();
  final RideService _rideService = RideService();

  final List<BreakpointModel> _breakpoints = [];
  bool _isLoading = false;

  // Controllers for adding breakpoint modal
  final _bpNameController = TextEditingController();
  final _bpLocationController = TextEditingController();
  String _selectedBpType = 'Refreshment';

  @override
  void dispose() {
    _titleController.dispose();
    _startLocationController.dispose();
    _destinationController.dispose();
    _bpNameController.dispose();
    _bpLocationController.dispose();
    super.dispose();
  }

  void _addBreakpoint() {
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
                    hint: 'e.g. Highway Fuel Stop / Coffee Break',
                  ),
                  const SizedBox(height: 14),
                  CustomTextField(
                    controller: _bpLocationController,
                    label: 'Location / Landmark',
                    hint: 'e.g. NH 44, Km 120',
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
                    text: 'Save Breakpoint',
                    onPressed: () {
                      if (_bpNameController.text.trim().isNotEmpty) {
                        setState(() {
                          _breakpoints.add(
                            BreakpointModel(
                              id: 'bp_${DateTime.now().millisecondsSinceEpoch}',
                              name: _bpNameController.text.trim(),
                              type: _selectedBpType.toLowerCase(),
                              location: _bpLocationController.text.trim().isNotEmpty
                                  ? _bpLocationController.text.trim()
                                  : 'En route stop',
                            ),
                          );
                        });
                        _bpNameController.clear();
                        _bpLocationController.clear();
                        Navigator.pop(context);
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

  Future<void> _handleCreateRide() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        final newRide = await _rideService.createRide(
          title: _titleController.text.trim(),
          startLocation: _startLocationController.text.trim(),
          destination: _destinationController.text.trim(),
          breakpoints: List.from(_breakpoints),
        );

        // Also add to MockDataState for offline/local fallback sync
        MockDataState().createRide(
          title: _titleController.text.trim(),
          startLocation: _startLocationController.text.trim(),
          destination: _destinationController.text.trim(),
          breakpoints: List.from(_breakpoints),
        );

        if (!mounted) return;

        setState(() {
          _isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Convoy created successfully! Ride Code: ${newRide.rideCode}'),
            backgroundColor: AppColors.success,
          ),
        );

        Navigator.pushReplacementNamed(context, '/ride-group', arguments: newRide.id);
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to create ride. Please check connection and try again.'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Create Convoy Ride'),
        backgroundColor: AppColors.background,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Ride Details',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Set up your group ride parameters. You will be assigned as Ride Admin.',
                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 20),

                CustomTextField(
                  controller: _titleController,
                  label: 'Ride Title',
                  hint: 'e.g. Weekend Coorg Mountain Expedition',
                  prefixIcon: Icons.two_wheeler_outlined,
                  validator: (val) => val == null || val.isEmpty ? 'Please enter a ride title' : null,
                ),
                const SizedBox(height: 16),

                CustomTextField(
                  controller: _startLocationController,
                  label: 'Starting Location',
                  hint: 'e.g. Bengaluru City Center',
                  prefixIcon: Icons.my_location_outlined,
                  validator: (val) => val == null || val.isEmpty ? 'Please enter starting location' : null,
                ),
                const SizedBox(height: 16),

                CustomTextField(
                  controller: _destinationController,
                  label: 'Destination',
                  hint: 'e.g. Coorg Peak Point',
                  prefixIcon: Icons.flag_outlined,
                  validator: (val) => val == null || val.isEmpty ? 'Please enter destination' : null,
                ),
                const SizedBox(height: 28),

                // Planned Breakpoints Section
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'PLANNED BREAKPOINTS',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                            color: AppColors.textMuted,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Stops here will not trigger false safety alerts',
                          style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_circle, color: AppColors.primary, size: 28),
                      onPressed: _addBreakpoint,
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                if (_breakpoints.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.info_outline, color: AppColors.textMuted, size: 20),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'No planned stops added yet. Tap + to add fuel, rest, or lunch stops.',
                            style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _breakpoints.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final bp = _breakpoints[index];
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.local_cafe_outlined, color: AppColors.primary, size: 18),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    bp.name,
                                    style: const TextStyle(
                                      color: AppColors.textPrimary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  Text(
                                    '${bp.type} • ${bp.location}',
                                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: AppColors.danger, size: 20),
                              onPressed: () {
                                setState(() {
                                  _breakpoints.removeAt(index);
                                });
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  ),

                const SizedBox(height: 32),
                CustomButton(
                  text: 'Generate Ride Code & Store in Firestore',
                  icon: Icons.check_circle_outline,
                  isLoading: _isLoading,
                  onPressed: _handleCreateRide,
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
