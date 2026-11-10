import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

class UserService {
  static final UserService _instance = UserService._internal();
  factory UserService() => _instance;
  UserService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _usersCollection => _db.collection('users');

  /// Create a new user profile document in Firestore collection `users` using [uid] as document ID.
  Future<void> createUserProfile({
    required String uid,
    required String name,
    required String email,
    required String phone,
    String? bikeModel,
    Map<String, String>? emergencyContact,
  }) async {
    try {
      final docRef = _usersCollection.doc(uid);
      await docRef.set({
        'name': name.trim(),
        'email': email.trim(),
        'phone': phone.trim(),
        'bikeModel': bikeModel?.trim() ?? '',
        'emergencyContact': {
          'name': emergencyContact?['name']?.trim() ?? '',
          'phone': emergencyContact?['phone']?.trim() ?? '',
          'relation': (emergencyContact?['relation'] ?? emergencyContact?['relationship'])?.trim() ?? '',
        },
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to create user profile in Firestore: ${e.toString()}');
    }
  }

  /// Get user profile by [uid]
  Future<UserModel?> getUserProfile(String uid) async {
    try {
      final doc = await _usersCollection.doc(uid).get();
      if (!doc.exists || doc.data() == null) {
        return null;
      }
      return UserModel.fromMap(doc.data()!, doc.id);
    } catch (e) {
      return null;
    }
  }

  /// Real-time stream of user profile by [uid]
  Stream<UserModel?> streamUserProfile(String uid) {
    if (uid.isEmpty) return Stream.value(null);
    return _usersCollection.doc(uid).snapshots().map((snapshot) {
      if (!snapshot.exists || snapshot.data() == null) {
        return null;
      }
      return UserModel.fromMap(snapshot.data()!, snapshot.id);
    }).handleError((error) {
      return null;
    });
  }

  /// Update user profile details
  Future<void> updateUserProfile(String uid, Map<String, dynamic> data) async {
    try {
      final updateData = Map<String, dynamic>.from(data);
      updateData['updatedAt'] = FieldValue.serverTimestamp();
      await _usersCollection.doc(uid).set(updateData, SetOptions(merge: true));
    } catch (e) {
      throw Exception('Failed to update profile: ${e.toString()}');
    }
  }

  /// Update emergency contact details for user [uid]
  Future<void> updateEmergencyContact(
    String uid, {
    required String name,
    required String phone,
    required String relation,
  }) async {
    try {
      await _usersCollection.doc(uid).set({
        'emergencyContact': {
          'name': name.trim(),
          'phone': phone.trim(),
          'relation': relation.trim(),
        },
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      throw Exception('Failed to update emergency contact: ${e.toString()}');
    }
  }

  /// Fetch multiple user profiles by list of UIDs
  Future<List<UserModel>> getUsersByIds(List<String> uids) async {
    if (uids.isEmpty) return [];
    try {
      final List<UserModel> users = [];
      // Firestore `whereIn` accepts max 30 items per query batch
      for (var i = 0; i < uids.length; i += 30) {
        final end = (i + 30 < uids.length) ? i + 30 : uids.length;
        final chunk = uids.sublist(i, end);
        final querySnap = await _usersCollection.where(FieldPath.documentId, whereIn: chunk).get();
        for (var doc in querySnap.docs) {
          users.add(UserModel.fromMap(doc.data(), doc.id));
        }
      }
      return users;
    } catch (_) {
      return [];
    }
  }

  /// Update FCM device notification token for user [uid]
  Future<void> updateFcmToken(String uid, String token) async {
    if (uid.isEmpty || token.isEmpty) return;
    try {
      await _usersCollection.doc(uid).set({
        'fcmToken': token,
        'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {}
  }
}
