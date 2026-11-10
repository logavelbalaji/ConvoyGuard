import 'breakpoint_model.dart';
import 'user_model.dart';

class RideModel {
  final String id;
  final String rideCode; // Unique 6-character ride code
  final String title;
  final String startLocation;
  final String destination;
  final String adminId;
  final String adminName;
  final String status; // scheduled, active, completed
  final List<String> members; // List of User UIDs
  final List<UserModel> memberProfiles; // Populated user profiles for UI display
  final List<BreakpointModel> breakpoints;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final double? totalDistanceKm;
  final double? averageSpeedKmH;
  final double? maxSpeedKmH;
  final int? durationMinutes;

  const RideModel({
    required this.id,
    required this.rideCode,
    required this.title,
    required this.startLocation,
    required this.destination,
    required this.adminId,
    required this.adminName,
    required this.status,
    required this.members,
    this.memberProfiles = const [],
    this.breakpoints = const [],
    this.createdAt,
    this.updatedAt,
    this.startedAt,
    this.completedAt,
    this.totalDistanceKm,
    this.averageSpeedKmH,
    this.maxSpeedKmH,
    this.durationMinutes,
  });

  // Backward compatibility getter for `code`
  String get code => rideCode;

  factory RideModel.fromMap(Map<String, dynamic> map, String documentId, {List<UserModel>? memberProfiles}) {
    // Parse members: can be list of strings (UIDs) or legacy list of user maps
    final rawMembers = map['members'] as List<dynamic>? ?? [];
    final List<String> uids = [];
    final List<UserModel> profilesFromMap = [];

    for (final item in rawMembers) {
      if (item is String) {
        uids.add(item);
      } else if (item is Map<String, dynamic>) {
        final u = UserModel.fromMap(item, item['id'] as String? ?? '');
        uids.add(u.id);
        profilesFromMap.add(u);
      }
    }

    DateTime? parseDt(dynamic val) {
      if (val == null) return null;
      if (val is DateTime) return val;
      if (val is String) return DateTime.tryParse(val);
      try {
        return (val as dynamic).toDate() as DateTime;
      } catch (_) {
        return null;
      }
    }

    return RideModel(
      id: documentId,
      rideCode: (map['rideCode'] ?? map['code']) as String? ?? '',
      title: map['title'] as String? ?? '',
      startLocation: map['startLocation'] as String? ?? '',
      destination: map['destination'] as String? ?? '',
      adminId: map['adminId'] as String? ?? '',
      adminName: map['adminName'] as String? ?? '',
      status: map['status'] as String? ?? 'scheduled',
      members: uids,
      memberProfiles: memberProfiles ?? profilesFromMap,
      breakpoints: (map['breakpoints'] as List<dynamic>?)
              ?.map((e) => BreakpointModel.fromMap(e as Map<String, dynamic>))
              .toList() ??
          [],
      createdAt: parseDt(map['createdAt']),
      updatedAt: parseDt(map['updatedAt']),
      startedAt: parseDt(map['startedAt']),
      completedAt: parseDt(map['completedAt']),
      totalDistanceKm: (map['totalDistanceKm'] as num?)?.toDouble(),
      averageSpeedKmH: (map['averageSpeedKmH'] as num?)?.toDouble(),
      maxSpeedKmH: (map['maxSpeedKmH'] as num?)?.toDouble(),
      durationMinutes: (map['durationMinutes'] as num?)?.toInt(),
    );
  }

  factory RideModel.fromJson(Map<String, dynamic> json) {
    return RideModel.fromMap(json, json['id'] as String? ?? '');
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'adminId': adminId,
      'adminName': adminName,
      'startLocation': startLocation,
      'destination': destination,
      'rideCode': rideCode,
      'status': status,
      'members': members,
      'breakpoints': breakpoints.map((b) => b.toMap()).toList(),
      if (startedAt != null) 'startedAt': startedAt!.toIso8601String(),
      if (completedAt != null) 'completedAt': completedAt!.toIso8601String(),
      if (totalDistanceKm != null) 'totalDistanceKm': totalDistanceKm,
      if (averageSpeedKmH != null) 'averageSpeedKmH': averageSpeedKmH,
      if (maxSpeedKmH != null) 'maxSpeedKmH': maxSpeedKmH,
      if (durationMinutes != null) 'durationMinutes': durationMinutes,
    };
  }

  Map<String, dynamic> toJson() {
    final map = toMap();
    map['id'] = id;
    return map;
  }

  RideModel copyWith({
    String? id,
    String? rideCode,
    String? title,
    String? startLocation,
    String? destination,
    String? adminId,
    String? adminName,
    String? status,
    List<String>? members,
    List<UserModel>? memberProfiles,
    List<BreakpointModel>? breakpoints,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? startedAt,
    DateTime? completedAt,
    double? totalDistanceKm,
    double? averageSpeedKmH,
    double? maxSpeedKmH,
    int? durationMinutes,
  }) {
    return RideModel(
      id: id ?? this.id,
      rideCode: rideCode ?? this.rideCode,
      title: title ?? this.title,
      startLocation: startLocation ?? this.startLocation,
      destination: destination ?? this.destination,
      adminId: adminId ?? this.adminId,
      adminName: adminName ?? this.adminName,
      status: status ?? this.status,
      members: members ?? this.members,
      memberProfiles: memberProfiles ?? this.memberProfiles,
      breakpoints: breakpoints ?? this.breakpoints,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      totalDistanceKm: totalDistanceKm ?? this.totalDistanceKm,
      averageSpeedKmH: averageSpeedKmH ?? this.averageSpeedKmH,
      maxSpeedKmH: maxSpeedKmH ?? this.maxSpeedKmH,
      durationMinutes: durationMinutes ?? this.durationMinutes,
    );
  }
}

