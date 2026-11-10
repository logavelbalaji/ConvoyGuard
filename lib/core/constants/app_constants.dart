class AppConstants {
  static const String appName = 'CONVOYGUARD';
  static const String appTagline = 'Smart Group-Riding Safety & Emergency Assistance';
  
  // Storage keys (for future persistence)
  static const String keyIsLoggedIn = 'is_logged_in';
  static const String keyUserToken = 'user_token';

  // Ride status strings
  static const String rideStatusActive = 'ACTIVE';
  static const String rideStatusScheduled = 'SCHEDULED';
  static const String rideStatusCompleted = 'COMPLETED';

  // Breakpoint categories
  static const List<String> breakpointTypes = [
    'Refreshment',
    'Food',
    'Fuel',
    'Rest',
    'Meeting Point',
    'Other',
  ];

  // Stop reason options for Unexpected Stop Safety Check
  static const List<String> stopReasons = [
    'Fuel',
    'Food',
    'Refreshment',
    'Personal Break',
    'Vehicle Problem',
    'Traffic',
    'Phone Call',
    'Road Condition',
    'Other',
  ];

  // Phase 5 Safety Monitoring Constants
  static const double safetyStillnessSpeedThresholdKmH = 2.0; // 0 - 2 km/h
  static const int safetyStillnessDurationSecondsDev = 15; // 15s for dev testing
  static const int safetyStillnessDurationSecondsProd = 180; // 3 mins production
  static const int safetyCheckTimeoutSeconds = 30; // 30s countdown before auto alert
  static const double safetyBreakpointProximityMeters = 150.0; // Breakpoint exclusion radius

  // Safety Alert Types
  static const String alertTypeStillness = 'stillness';
  static const String alertTypeNoResponse = 'no_response';
  static const String alertTypeManualSOS = 'manual_sos';
  static const String alertTypeEmergency = 'emergency';

  // Safety Alert Statuses
  static const String alertStatusActive = 'active';
  static const String alertStatusAcknowledged = 'acknowledged';
  static const String alertStatusResolved = 'resolved';
}

