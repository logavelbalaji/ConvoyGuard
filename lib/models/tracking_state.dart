import 'package:geolocator/geolocator.dart';

/// Immutable model holding real-time continuous GPS tracking state and metrics.
class TrackingState {
  final bool isTracking;
  final Position? currentPosition;
  final int updateCount;
  final DateTime? startTime;
  final DateTime? lastUpdateTime;

  const TrackingState({
    this.isTracking = false,
    this.currentPosition,
    this.updateCount = 0,
    this.startTime,
    this.lastUpdateTime,
  });

  TrackingState copyWith({
    bool? isTracking,
    Position? currentPosition,
    int? updateCount,
    DateTime? startTime,
    DateTime? lastUpdateTime,
  }) {
    return TrackingState(
      isTracking: isTracking ?? this.isTracking,
      currentPosition: currentPosition ?? this.currentPosition,
      updateCount: updateCount ?? this.updateCount,
      startTime: startTime ?? this.startTime,
      lastUpdateTime: lastUpdateTime ?? this.lastUpdateTime,
    );
  }

  /// Total duration since tracking was initiated.
  Duration get trackingDuration {
    if (startTime == null) return Duration.zero;
    final end = lastUpdateTime ?? DateTime.now();
    return end.difference(startTime!);
  }

  /// Formatted current speed in kilometers per hour (km/h).
  /// Position.speed is in meters per second (m/s).
  double get speedInKmH {
    if (currentPosition == null) return 0.0;
    final speedInMps = currentPosition!.speed;
    return speedInMps > 0 ? (speedInMps * 3.6) : 0.0;
  }
}
