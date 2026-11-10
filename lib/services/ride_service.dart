import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/breakpoint_model.dart';
import '../models/ride_model.dart';
import 'user_service.dart';

class RideService {
  static final RideService _instance = RideService._internal();
  factory RideService() => _instance;
  RideService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final UserService _userService = UserService();

  CollectionReference<Map<String, dynamic>> get _ridesCollection => _db.collection('rides');

  /// Generate a unique 6-character alphanumeric uppercase Ride Code
  String _generateRideCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rnd = math.Random();
    return List.generate(6, (_) => chars[rnd.nextInt(chars.length)]).join();
  }

  /// Create a new ride in Firestore
  Future<RideModel> createRide({
    required String title,
    required String startLocation,
    required String destination,
    required List<BreakpointModel> breakpoints,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('Rider authentication required to create a ride.');
    }

    final adminUid = user.uid;
    // Fetch admin user profile or fall back to auth display name / Email
    final profile = await _userService.getUserProfile(adminUid);
    final adminName = profile?.name.isNotEmpty == true
        ? profile!.name
        : (user.displayName?.isNotEmpty == true ? user.displayName! : 'Ride Admin');

    final rideCode = _generateRideCode();
    final docRef = _ridesCollection.doc();

    final Map<String, dynamic> rideData = {
      'title': title.trim(),
      'adminId': adminUid,
      'adminName': adminName,
      'startLocation': startLocation.trim(),
      'destination': destination.trim(),
      'rideCode': rideCode,
      'status': 'scheduled',
      'members': [adminUid],
      'breakpoints': breakpoints.map((b) => b.toMap()).toList(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    await docRef.set(rideData);

    return RideModel(
      id: docRef.id,
      rideCode: rideCode,
      title: title.trim(),
      startLocation: startLocation.trim(),
      destination: destination.trim(),
      adminId: adminUid,
      adminName: adminName,
      status: 'scheduled',
      members: [adminUid],
      breakpoints: breakpoints,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  /// Search and Join a ride using 6-character Ride Code
  Future<RideModel> joinRideByCode(String rawCode) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('Rider authentication required to join a ride.');
    }

    final code = rawCode.trim().toUpperCase();
    if (code.isEmpty) {
      throw Exception('Please enter a valid Ride Code.');
    }

    final query = await _ridesCollection.where('rideCode', isEqualTo: code).get();

    if (query.docs.isEmpty) {
      throw Exception('Ride code "$code" not found. Please check the code and try again.');
    }

    final docSnap = query.docs.first;
    final data = docSnap.data();
    final rideId = docSnap.id;

    final status = (data['status'] as String? ?? 'scheduled').toLowerCase();
    if (status == 'completed') {
      throw Exception('This ride has already been completed and cannot be joined.');
    }

    final members = List<String>.from(data['members'] as List<dynamic>? ?? []);

    if (members.contains(user.uid)) {
      // User is already a member
      return RideModel.fromMap(data, rideId);
    }

    // Add user to members array
    await _ridesCollection.doc(rideId).update({
      'members': FieldValue.arrayUnion([user.uid]),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    members.add(user.uid);
    final updatedMap = Map<String, dynamic>.from(data);
    updatedMap['members'] = members;

    return RideModel.fromMap(updatedMap, rideId);
  }

  /// Change ride status from scheduled -> active (Admin only)
  Future<void> startRide(String rideId) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('Rider authentication required.');
    }

    final docSnap = await _ridesCollection.doc(rideId).get();
    if (!docSnap.exists || docSnap.data() == null) {
      throw Exception('Ride not found.');
    }

    final data = docSnap.data()!;
    final adminId = data['adminId'] as String? ?? '';

    if (adminId != user.uid) {
      throw Exception('Only the ride admin can start this convoy ride.');
    }

    await _ridesCollection.doc(rideId).update({
      'status': 'active',
      'startedAt': data['startedAt'] ?? FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Change ride status from active -> completed (Admin only) and save summary analytics
  Future<void> endRide(String rideId, {Map<String, dynamic>? summaryData}) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('Rider authentication required.');
    }

    final docSnap = await _ridesCollection.doc(rideId).get();
    if (!docSnap.exists || docSnap.data() == null) {
      throw Exception('Ride not found.');
    }

    final data = docSnap.data()!;
    final adminId = data['adminId'] as String? ?? '';

    if (adminId != user.uid) {
      throw Exception('Only the ride admin can complete this convoy ride.');
    }

    final Map<String, dynamic> updatePayload = {
      'status': 'completed',
      'completedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      if (summaryData != null) ...summaryData,
    };

    await _ridesCollection.doc(rideId).update(updatePayload);
  }


  /// Add breakpoint to ride (Admin)
  Future<void> addBreakpoint(String rideId, BreakpointModel breakpoint) async {
    await _ridesCollection.doc(rideId).update({
      'breakpoints': FieldValue.arrayUnion([breakpoint.toMap()]),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Remove breakpoint from ride (Admin)
  Future<void> removeBreakpoint(String rideId, String breakpointId) async {
    final docSnap = await _ridesCollection.doc(rideId).get();
    if (!docSnap.exists || docSnap.data() == null) return;

    final data = docSnap.data()!;
    final breakpoints = List<Map<String, dynamic>>.from(
      (data['breakpoints'] as List<dynamic>? ?? []).map((e) => Map<String, dynamic>.from(e as Map)),
    );

    breakpoints.removeWhere((bp) => bp['id'] == breakpointId);

    await _ridesCollection.doc(rideId).update({
      'breakpoints': breakpoints,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Stream single ride real-time document snapshot
  Stream<RideModel?> streamRide(String rideId) {
    if (rideId.isEmpty) return Stream.value(null);
    return _ridesCollection.doc(rideId).snapshots().asyncMap((snapshot) async {
      if (!snapshot.exists || snapshot.data() == null) {
        return null;
      }
      final data = snapshot.data()!;
      final ride = RideModel.fromMap(data, snapshot.id);

      // Populate member user profiles for UI display
      if (ride.members.isNotEmpty) {
        final profiles = await _userService.getUsersByIds(ride.members);
        return ride.copyWith(memberProfiles: profiles);
      }
      return ride;
    });
  }

  /// Stream real-time list of rides where current user is a member
  Stream<List<RideModel>> streamUserRides(String uid) {
    if (uid.isEmpty) return Stream.value([]);
    return _ridesCollection.where('members', arrayContains: uid).snapshots().map((snapshot) {
      final list = snapshot.docs.map((doc) => RideModel.fromMap(doc.data(), doc.id)).toList();
      // Sort descending by createdAt or status
      list.sort((a, b) {
        final aTime = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bTime = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bTime.compareTo(aTime);
      });
      return list;
    }).handleError((_) => <RideModel>[]);
  }
}
