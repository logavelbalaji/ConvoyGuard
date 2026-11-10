import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import '../models/live_location_model.dart';

/// Dedicated service for managing Firestore real-time live location uploads and subscriptions
/// under subcollection `rides/{rideId}/live_locations/{userUID}`.
class LiveLocationService {
  static final LiveLocationService _instance = LiveLocationService._internal();
  factory LiveLocationService() => _instance;
  LiveLocationService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _liveLocationsRef(String rideId) {
    return _db.collection('rides').doc(rideId).collection('live_locations');
  }

  /// Write or merge rider's live GPS telemetry into Firestore document `rides/{rideId}/live_locations/{userUID}`.
  Future<void> updateLiveLocation(
    String rideId,
    String userId,
    Position position, {
    String? userName,
  }) async {
    if (rideId.isEmpty || userId.isEmpty) return;

    try {
      final docRef = _liveLocationsRef(rideId).doc(userId);
      final speedKmH = position.speed > 0 ? (position.speed * 3.6) : 0.0;

      await docRef.set({
        'userId': userId,
        'userName': (userName != null && userName.isNotEmpty) ? userName : 'Rider',
        'latitude': position.latitude,
        'longitude': position.longitude,
        'accuracy': position.accuracy,
        'speed': speedKmH,
        'isTracking': true,
        'timestamp': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {
      // Ignore network failures gracefully to prevent UI crashes during rides
    }
  }

  /// Mark rider tracking as inactive (`isTracking: false`) while preserving last known coordinates.
  Future<void> stopLiveTracking(String rideId, String userId) async {
    if (rideId.isEmpty || userId.isEmpty) return;

    try {
      final docRef = _liveLocationsRef(rideId).doc(userId);
      await docRef.set({
        'isTracking': false,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  /// Stream all active and last known rider locations for a specific ride in real time.
  Stream<List<LiveLocationModel>> streamRideLocations(String rideId) {
    if (rideId.isEmpty) return Stream.value([]);
    return _liveLocationsRef(rideId).snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => LiveLocationModel.fromMap(doc.data(), doc.id)).toList();
    }).handleError((_) => <LiveLocationModel>[]);
  }

  /// Stream single user's live location document in real time.
  Stream<LiveLocationModel?> streamUserLocation(String rideId, String userId) {
    if (rideId.isEmpty || userId.isEmpty) return Stream.value(null);
    return _liveLocationsRef(rideId).doc(userId).snapshots().map((docSnap) {
      if (!docSnap.exists || docSnap.data() == null) return null;
      return LiveLocationModel.fromMap(docSnap.data()!, docSnap.id);
    }).handleError((_) => null);
  }
}
