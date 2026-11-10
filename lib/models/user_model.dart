class EmergencyContact {
  final String name;
  final String phone;
  final String relation;

  const EmergencyContact({
    required this.name,
    required this.phone,
    required this.relation,
  });

  String get relationship => relation;

  factory EmergencyContact.fromMap(Map<String, dynamic>? map) {
    if (map == null) {
      return const EmergencyContact(name: '', phone: '', relation: '');
    }
    return EmergencyContact(
      name: map['name'] as String? ?? '',
      phone: map['phone'] as String? ?? '',
      relation: (map['relation'] ?? map['relationship']) as String? ?? '',
    );
  }

  factory EmergencyContact.fromJson(Map<String, dynamic> json) => EmergencyContact.fromMap(json);

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'phone': phone,
      'relation': relation,
    };
  }

  Map<String, dynamic> toJson() => toMap();
}

class UserModel {
  final String id;
  final String name;
  final String email;
  final String phone;
  final String bikeModel;
  final EmergencyContact? emergencyContact;
  final String? fcmToken;
  final bool notificationsEnabled;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    this.bikeModel = '',
    this.emergencyContact,
    this.fcmToken,
    this.notificationsEnabled = true,
    this.createdAt,
    this.updatedAt,
  });

  static DateTime? _parseDateTime(dynamic val) {
    if (val == null) return null;
    if (val is DateTime) return val;
    if (val is String) return DateTime.tryParse(val);
    try {
      return (val as dynamic).toDate() as DateTime;
    } catch (_) {
      return null;
    }
  }

  factory UserModel.fromMap(Map<String, dynamic> map, String documentId) {
    return UserModel(
      id: documentId,
      name: map['name'] as String? ?? '',
      email: map['email'] as String? ?? '',
      phone: map['phone'] as String? ?? '',
      bikeModel: map['bikeModel'] as String? ?? '',
      emergencyContact: map['emergencyContact'] != null
          ? EmergencyContact.fromMap(map['emergencyContact'] as Map<String, dynamic>)
          : null,
      fcmToken: map['fcmToken'] as String?,
      notificationsEnabled: map['notificationsEnabled'] as bool? ?? true,
      createdAt: _parseDateTime(map['createdAt']),
      updatedAt: _parseDateTime(map['updatedAt']),
    );
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel.fromMap(json, json['id'] as String? ?? '');
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email,
      'phone': phone,
      'bikeModel': bikeModel,
      'emergencyContact': emergencyContact?.toMap(),
      if (fcmToken != null) 'fcmToken': fcmToken,
      'notificationsEnabled': notificationsEnabled,
    };
  }

  Map<String, dynamic> toJson() {
    final map = toMap();
    map['id'] = id;
    return map;
  }
}
