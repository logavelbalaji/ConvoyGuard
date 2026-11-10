import 'package:cloud_firestore/cloud_firestore.dart';

/// Data model representing a safety alert document in Firestore.
/// Path: `rides/{rideId}/safety_alerts/{alertId}`
class SafetyAlertModel {
  final String alertId;
  final String rideId;
  final String userId;
  final String userName;
  final String type; // 'stillness', 'no_response', 'manual_sos', 'emergency'
  final String message;
  final String status; // 'active', 'acknowledged', 'resolved'
  final double? latitude;
  final double? longitude;
  final double? speed;
  final String? stopReason;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? acknowledgedBy;
  final String? resolvedBy;

  const SafetyAlertModel({
    required this.alertId,
    required this.rideId,
    required this.userId,
    required this.userName,
    required this.type,
    required this.message,
    this.status = 'active',
    this.latitude,
    this.longitude,
    this.speed,
    this.stopReason,
    this.createdAt,
    this.updatedAt,
    this.acknowledgedBy,
    this.resolvedBy,
  });

  bool get isActive => status == 'active';
  bool get isAcknowledged => status == 'acknowledged';
  bool get isResolved => status == 'resolved';

  bool get isStillness => type == 'stillness';
  bool get isNoResponse => type == 'no_response';
  bool get isManualSOS => type == 'manual_sos';
  bool get isEmergency => type == 'emergency';

  factory SafetyAlertModel.fromMap(Map<String, dynamic> map, String id) {
    DateTime? parseDateTime(dynamic value) {
      if (value is Timestamp) {
        return value.toDate();
      } else if (value is String) {
        return DateTime.tryParse(value);
      }
      return null;
    }

    return SafetyAlertModel(
      alertId: map['alertId'] as String? ?? id,
      rideId: map['rideId'] as String? ?? '',
      userId: map['userId'] as String? ?? '',
      userName: map['userName'] as String? ?? 'Rider',
      type: map['type'] as String? ?? 'stillness',
      message: map['message'] as String? ?? 'Safety check triggered.',
      status: map['status'] as String? ?? 'active',
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
      speed: (map['speed'] as num?)?.toDouble(),
      stopReason: map['stopReason'] as String?,
      createdAt: parseDateTime(map['createdAt']),
      updatedAt: parseDateTime(map['updatedAt']),
      acknowledgedBy: map['acknowledgedBy'] as String?,
      resolvedBy: map['resolvedBy'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'alertId': alertId,
      'rideId': rideId,
      'userId': userId,
      'userName': userName,
      'type': type,
      'message': message,
      'status': status,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (speed != null) 'speed': speed,
      if (stopReason != null) 'stopReason': stopReason,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      if (acknowledgedBy != null) 'acknowledgedBy': acknowledgedBy,
      if (resolvedBy != null) 'resolvedBy': resolvedBy,
    };
  }

  SafetyAlertModel copyWith({
    String? alertId,
    String? rideId,
    String? userId,
    String? userName,
    String? type,
    String? message,
    String? status,
    double? latitude,
    double? longitude,
    double? speed,
    String? stopReason,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? acknowledgedBy,
    String? resolvedBy,
  }) {
    return SafetyAlertModel(
      alertId: alertId ?? this.alertId,
      rideId: rideId ?? this.rideId,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      type: type ?? this.type,
      message: message ?? this.message,
      status: status ?? this.status,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      speed: speed ?? this.speed,
      stopReason: stopReason ?? this.stopReason,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      acknowledgedBy: acknowledgedBy ?? this.acknowledgedBy,
      resolvedBy: resolvedBy ?? this.resolvedBy,
    );
  }
}
