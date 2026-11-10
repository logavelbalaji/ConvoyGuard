import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/safety_alert_model.dart';
import '../core/constants/app_constants.dart';

/// Dedicated service for managing Firestore safety alerts under
/// subcollection `rides/{rideId}/safety_alerts/{alertId}`.
class SafetyService {
  static final SafetyService _instance = SafetyService._internal();
  factory SafetyService() => _instance;
  SafetyService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _alertsRef(String rideId) {
    return _db.collection('rides').doc(rideId).collection('safety_alerts');
  }

  /// Create a new safety alert in Firestore subcollection `rides/{rideId}/safety_alerts`.
  Future<String?> createSafetyAlert({
    required String rideId,
    required String userId,
    required String userName,
    required String type,
    required String message,
    double? latitude,
    double? longitude,
    double? speed,
    String? stopReason,
  }) async {
    if (rideId.isEmpty || userId.isEmpty) return null;

    try {
      final docRef = _alertsRef(rideId).doc();
      final alert = SafetyAlertModel(
        alertId: docRef.id,
        rideId: rideId,
        userId: userId,
        userName: userName,
        type: type,
        message: message,
        status: AppConstants.alertStatusActive,
        latitude: latitude,
        longitude: longitude,
        speed: speed,
        stopReason: stopReason,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await docRef.set(alert.toMap());
      return docRef.id;
    } catch (_) {
      // Gracefully return null on network/Firestore error
      return null;
    }
  }

  /// Acknowledge an active safety alert.
  Future<void> acknowledgeSafetyAlert(
    String rideId,
    String alertId,
    String currentUserId,
  ) async {
    if (rideId.isEmpty || alertId.isEmpty) return;

    try {
      await _alertsRef(rideId).doc(alertId).set({
        'status': AppConstants.alertStatusAcknowledged,
        'acknowledgedBy': currentUserId,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  /// Resolve a safety alert (mark as resolved).
  Future<void> resolveSafetyAlert(
    String rideId,
    String alertId,
    String currentUserId,
  ) async {
    if (rideId.isEmpty || alertId.isEmpty) return;

    try {
      await _alertsRef(rideId).doc(alertId).set({
        'status': AppConstants.alertStatusResolved,
        'resolvedBy': currentUserId,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  /// Resolve all active/acknowledged safety alerts for a specific user in a ride (e.g. when rider confirms safety).
  Future<void> resolveActiveAlertsForUser(String rideId, String userId) async {
    if (rideId.isEmpty || userId.isEmpty) return;

    try {
      final snapshot = await _alertsRef(rideId)
          .where('userId', isEqualTo: userId)
          .get();

      final batch = _db.batch();
      for (final doc in snapshot.docs) {
        final status = doc.data()['status'] as String?;
        if (status == AppConstants.alertStatusActive || status == AppConstants.alertStatusAcknowledged) {
          batch.update(doc.reference, {
            'status': AppConstants.alertStatusResolved,
            'resolvedBy': userId,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      }
      await batch.commit();
    } catch (_) {}
  }

  /// Stream all active and acknowledged safety alerts for a ride in real time.
  Stream<List<SafetyAlertModel>> streamActiveAlerts(String rideId) {
    if (rideId.isEmpty) return Stream.value([]);

    return _alertsRef(rideId).snapshots().map((snapshot) {
      final list = snapshot.docs
          .map((doc) => SafetyAlertModel.fromMap(doc.data(), doc.id))
          .where((alert) => alert.status != AppConstants.alertStatusResolved)
          .toList();

      // Sort newest first
      list.sort((a, b) {
        final tA = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final tB = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return tB.compareTo(tA);
      });

      return list;
    }).handleError((_) => <SafetyAlertModel>[]);
  }

  /// Stream all safety alerts (including resolved) for audit/history display.
  Stream<List<SafetyAlertModel>> streamAllAlerts(String rideId) {
    if (rideId.isEmpty) return Stream.value([]);

    return _alertsRef(rideId).snapshots().map((snapshot) {
      final list = snapshot.docs
          .map((doc) => SafetyAlertModel.fromMap(doc.data(), doc.id))
          .toList();

      list.sort((a, b) {
        final tA = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final tB = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return tB.compareTo(tA);
      });

      return list;
    }).handleError((_) => <SafetyAlertModel>[]);
  }

  /// Stream single user's current active safety alert, if any.
  Stream<SafetyAlertModel?> streamUserActiveAlert(String rideId, String userId) {
    if (rideId.isEmpty || userId.isEmpty) return Stream.value(null);

    return _alertsRef(rideId)
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
      for (final doc in snapshot.docs) {
        final alert = SafetyAlertModel.fromMap(doc.data(), doc.id);
        if (alert.status != AppConstants.alertStatusResolved) {
          return alert;
        }
      }
      return null;
    }).handleError((_) => null);
  }
}
