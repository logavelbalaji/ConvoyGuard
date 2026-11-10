class BreakpointModel {
  final String id;
  final String name;
  final String type; // fuel, food, refreshment, rest, meetingPoint, other
  final String location; // text location/landmark
  final double latitude;
  final double longitude;
  final bool isReached;

  const BreakpointModel({
    required this.id,
    required this.name,
    required this.type,
    required this.location,
    this.latitude = 0.0,
    this.longitude = 0.0,
    this.isReached = false,
  });

  // Backward compatibility alias for locationName
  String get locationName => location;

  factory BreakpointModel.fromMap(Map<String, dynamic> map) {
    return BreakpointModel(
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? '',
      type: map['type'] as String? ?? 'other',
      location: (map['location'] ?? map['locationName']) as String? ?? '',
      latitude: (map['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (map['longitude'] as num?)?.toDouble() ?? 0.0,
      isReached: map['isReached'] as bool? ?? false,
    );
  }

  factory BreakpointModel.fromJson(Map<String, dynamic> json) => BreakpointModel.fromMap(json);

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'location': location,
      'latitude': latitude,
      'longitude': longitude,
      'isReached': isReached,
    };
  }

  Map<String, dynamic> toJson() => toMap();
}
