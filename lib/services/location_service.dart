import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

/// Exception thrown when location service (GPS) is disabled on the device.
class GpsServiceDisabledException implements Exception {
  final String message;
  GpsServiceDisabledException([this.message = 'Location services (GPS) are disabled on device.']);
  @override
  String toString() => message;
}

/// Exception thrown when location permission is denied by the user.
class GpsPermissionDeniedException implements Exception {
  final String message;
  GpsPermissionDeniedException([this.message = 'Location permission was denied.']);
  @override
  String toString() => message;
}

/// Exception thrown when location permission is permanently denied.
class GpsPermissionPermanentlyDeniedException implements Exception {
  final String message;
  GpsPermissionPermanentlyDeniedException([
    this.message = 'Location permission is permanently denied. Please enable it in device settings.',
  ]);
  @override
  String toString() => message;
}

/// Dedicated modular service for managing GPS location permissions & current position.
class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  /// Check if device location services (GPS) are enabled.
  Future<bool> isLocationServiceEnabled() async {
    return await Geolocator.isLocationServiceEnabled();
  }

  /// Check current location permission state.
  Future<LocationPermission> checkPermission() async {
    return await Geolocator.checkPermission();
  }

  /// Prompt the user to grant location permission.
  Future<LocationPermission> requestPermission() async {
    return await Geolocator.requestPermission();
  }

  /// Open device App Settings so the user can grant permanently denied permissions.
  Future<bool> openAppSettings() async {
    return await Geolocator.openAppSettings();
  }

  /// Open device Location / GPS Settings so the user can turn on GPS.
  Future<bool> openLocationSettings() async {
    return await Geolocator.openLocationSettings();
  }

  /// Validates GPS state and permissions, then returns the current [Position].
  ///
  /// Throws:
  /// - [GpsServiceDisabledException] if GPS is turned off.
  /// - [GpsPermissionDeniedException] if permission was denied by user.
  /// - [GpsPermissionPermanentlyDeniedException] if permission is permanently denied.
  Future<Position> getCurrentLocation({
    LocationAccuracy accuracy = LocationAccuracy.high,
    Duration? timeLimit,
  }) async {
    // 1. Verify location service status
    final serviceEnabled = await isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw GpsServiceDisabledException();
    }

    // 2. Verify permission status
    LocationPermission permission = await checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await requestPermission();
      if (permission == LocationPermission.denied) {
        throw GpsPermissionDeniedException();
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw GpsPermissionPermanentlyDeniedException();
    }

    // 3. Fetch current coordinates
    return await Geolocator.getCurrentPosition(
      locationSettings: LocationSettings(
        accuracy: accuracy,
        timeLimit: timeLimit ?? const Duration(seconds: 15),
      ),
    );
  }

  /// Stream real-time location updates configured for motorcycle/group riding.
  Stream<Position> getPositionStream({
    LocationAccuracy accuracy = LocationAccuracy.high,
    int distanceFilter = 10,
    int intervalInSeconds = 5,
  }) {
    late LocationSettings locationSettings;

    if (defaultTargetPlatform == TargetPlatform.android) {
      locationSettings = AndroidSettings(
        accuracy: accuracy,
        distanceFilter: distanceFilter,
        forceLocationManager: false,
        intervalDuration: Duration(seconds: intervalInSeconds),
      );
    } else if (defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.macOS) {
      locationSettings = AppleSettings(
        accuracy: accuracy,
        activityType: ActivityType.otherNavigation,
        distanceFilter: distanceFilter,
        pauseLocationUpdatesAutomatically: false,
      );
    } else {
      locationSettings = LocationSettings(
        accuracy: accuracy,
        distanceFilter: distanceFilter,
      );
    }

    return Geolocator.getPositionStream(locationSettings: locationSettings);
  }
}
