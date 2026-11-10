import 'package:cloud_firestore/cloud_firestore.dart';

/// Data model representing a rider's real-time live GPS telemetry in Firestore.
class LiveLocationModel {
  final String userId;
  final String userName;
  final double latitude;
  final double longitude;
  final double accuracy;
  final double speed; // Speed in km/h
  final bool isTracking;
  final DateTime? timestamp;

  const LiveLocationModel({
    required this.userId,
    this.userName = 'Rider',
    required this.latitude,
    required this.longitude,
    this.accuracy = 0.0,
    this.speed = 0.0,
    this.isTracking = false,
    this.timestamp,
  });

  factory LiveLocationModel.fromMap(Map<String, dynamic> map, String docId) {
    DateTime? ts;
    if (map['timestamp'] is Timestamp) {
      ts = (map['timestamp'] as Timestamp).toDate();
    } else if (map['timestamp'] is String) {
      ts = DateTime.tryParse(map['timestamp'] as String);
    } else if (map['updatedAt'] is Timestamp) {
      ts = (map['updatedAt'] as Timestamp).toDate();
    }

    return LiveLocationModel(
      userId: map['userId'] ?? docId,
      userName: map['userName'] ?? map['name'] ?? 'Rider',
      latitude: (map['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (map['longitude'] as num?)?.toDouble() ?? 0.0,
      accuracy: (map['accuracy'] as num?)?.toDouble() ?? 0.0,
      speed: (map['speed'] as num?)?.toDouble() ?? 0.0,
      isTracking: map['isTracking'] ?? false,
      timestamp: ts,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'userName': userName,
      'latitude': latitude,
      'longitude': longitude,
      'accuracy': accuracy,
      'speed': speed,
      'isTracking': isTracking,
      'timestamp': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}
