import 'package:flutter/material.dart';
import '../../models/user_model.dart';
import '../../models/ride_model.dart';
import '../../models/breakpoint_model.dart';

class MockDataState extends ChangeNotifier {
  static final MockDataState _instance = MockDataState._internal();
  factory MockDataState() => _instance;
  MockDataState._internal();

  // Current logged in user
  UserModel _currentUser = const UserModel(
    id: 'user_001',
    name: 'Alex Mercer',
    email: 'alex.rider@convoyguard.com',
    phone: '+1 555-0198',
    bikeModel: 'Royal Enfield Himalayan 450',
    emergencyContact: EmergencyContact(
      name: 'Sarah Mercer',
      phone: '+1 555-0199',
      relation: 'Spouse',
    ),
  );

  UserModel get currentUser => _currentUser;

  bool _isLoggedIn = false;
  bool get isLoggedIn => _isLoggedIn;

  void login(String email, String password) {
    _isLoggedIn = true;
    _currentUser = UserModel(
      id: 'user_001',
      name: email.contains('@') ? email.split('@')[0].toUpperCase() : 'Rider Alex',
      email: email,
      phone: '+1 555-0198',
      bikeModel: 'Royal Enfield Himalayan 450',
      emergencyContact: _currentUser.emergencyContact ?? const EmergencyContact(
        name: 'Sarah Mercer',
        phone: '+1 555-0199',
        relation: 'Spouse',
      ),
    );
    notifyListeners();
  }

  void register({
    required String name,
    required String email,
    required String phone,
    required String emergencyName,
    required String emergencyPhone,
    required String emergencyRelation,
  }) {
    _isLoggedIn = true;
    _currentUser = UserModel(
      id: 'user_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      email: email,
      phone: phone,
      bikeModel: 'KTM Adventure 390',
      emergencyContact: EmergencyContact(
        name: emergencyName,
        phone: emergencyPhone,
        relation: emergencyRelation,
      ),
    );
    notifyListeners();
  }

  void updateEmergencyContact(EmergencyContact contact) {
    _currentUser = UserModel(
      id: _currentUser.id,
      name: _currentUser.name,
      email: _currentUser.email,
      phone: _currentUser.phone,
      bikeModel: _currentUser.bikeModel,
      emergencyContact: contact,
    );
    notifyListeners();
  }

  void updateProfile({required String name, required String phone, required String bikeModel}) {
    _currentUser = UserModel(
      id: _currentUser.id,
      name: name,
      email: _currentUser.email,
      phone: phone,
      bikeModel: bikeModel,
      emergencyContact: _currentUser.emergencyContact,
    );
    notifyListeners();
  }

  void logout() {
    _isLoggedIn = false;
    notifyListeners();
  }

  // Active & Mock Rides
  final List<RideModel> _rides = [
    RideModel(
      id: 'ride_101',
      rideCode: 'CG-8942',
      title: 'Western Ghats Weekend Expedition',
      startLocation: 'Bengaluru, KA',
      destination: 'Coorg Hills, KA',
      adminId: 'user_001',
      adminName: 'Alex Mercer',
      status: 'active',
      members: const ['user_001', 'user_002', 'user_003', 'user_004'],
      memberProfiles: const [
        UserModel(id: 'user_001', name: 'Alex Mercer (Admin)', email: 'alex@cg.com', phone: '555-0198'),
        UserModel(id: 'user_002', name: 'Rohan Sharma', email: 'rohan@cg.com', phone: '555-0123'),
        UserModel(id: 'user_003', name: 'Priya Nair', email: 'priya@cg.com', phone: '555-0144'),
        UserModel(id: 'user_004', name: 'Vikram Singh', email: 'vikram@cg.com', phone: '555-0167'),
      ],
      breakpoints: const [
        BreakpointModel(
          id: 'bp_1',
          name: 'Highway CCD Fuel & Coffee',
          type: 'fuel',
          location: 'NH 75, Km 45',
          isReached: true,
        ),
        BreakpointModel(
          id: 'bp_2',
          name: 'Hassan Dhaba Lunch Break',
          type: 'food',
          location: 'Hassan Bypass',
          isReached: false,
        ),
        BreakpointModel(
          id: 'bp_3',
          name: 'Scenic View Point Rest',
          type: 'rest',
          location: 'Chikmagalur Road',
          isReached: false,
        ),
      ],
    ),
    RideModel(
      id: 'ride_102',
      rideCode: 'CG-3410',
      title: 'Coastal Highway Sunday Cruise',
      startLocation: 'Chennai, TN',
      destination: 'Puducherry Beach',
      adminId: 'user_005',
      adminName: 'David Miller',
      status: 'scheduled',
      members: const ['user_005', 'user_001'],
      memberProfiles: const [
        UserModel(id: 'user_005', name: 'David Miller', email: 'david@cg.com', phone: '555-0899'),
        UserModel(id: 'user_001', name: 'Alex Mercer', email: 'alex@cg.com', phone: '555-0198'),
      ],
      breakpoints: const [
        BreakpointModel(
          id: 'bp_201',
          name: 'Mahabalipuram Tea Stop',
          type: 'refreshment',
          location: 'ECR Km 30',
        ),
      ],
    ),
  ];

  List<RideModel> get rides => List.unmodifiable(_rides);

  RideModel? getRideByCode(String code) {
    try {
      return _rides.firstWhere((r) => r.rideCode.toUpperCase() == code.trim().toUpperCase());
    } catch (_) {
      return null;
    }
  }

  RideModel createRide({
    required String title,
    required String startLocation,
    required String destination,
    required List<BreakpointModel> breakpoints,
  }) {
    final String code = 'CG-${(1000 + _rides.length * 37 + (DateTime.now().millisecond % 8999)).toInt()}';
    final newRide = RideModel(
      id: 'ride_${DateTime.now().millisecondsSinceEpoch}',
      rideCode: code,
      title: title,
      startLocation: startLocation,
      destination: destination,
      adminId: _currentUser.id,
      adminName: _currentUser.name,
      status: 'scheduled',
      members: [_currentUser.id],
      memberProfiles: [_currentUser],
      breakpoints: breakpoints,
    );

    _rides.insert(0, newRide);
    notifyListeners();
    return newRide;
  }

  bool joinRide(String code) {
    final rideIndex = _rides.indexWhere((r) => r.rideCode.toUpperCase() == code.trim().toUpperCase());
    if (rideIndex != -1) {
      final existingRide = _rides[rideIndex];
      if (!existingRide.members.contains(_currentUser.id)) {
        final updatedMembers = List<String>.from(existingRide.members)..add(_currentUser.id);
        final updatedProfiles = List<UserModel>.from(existingRide.memberProfiles)..add(_currentUser);
        _rides[rideIndex] = existingRide.copyWith(
          members: updatedMembers,
          memberProfiles: updatedProfiles,
        );
        notifyListeners();
      }
      return true;
    }
    return false;
  }
}
