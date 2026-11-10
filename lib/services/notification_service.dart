import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../models/safety_alert_model.dart';
import '../services/safety_service.dart';
import '../services/user_service.dart';
import '../core/constants/app_constants.dart';

/// Top-level background message handler required by FirebaseMessaging.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // FCM background message processing if needed.
}

/// Global navigator key for notification tap routing across the app.
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;
  String? _currentUserId;
  String? _activeRideId;
  StreamSubscription<List<SafetyAlertModel>>? _alertsSubscription;
  final Set<String> _handledAlertIds = {};

  static const String _channelId = 'convoyguard_safety_channel';
  static const String _channelName = 'ConvoyGuard Safety Alerts';
  static const String _channelDescription = 'Emergency and safety notifications for convoy riders';

  /// Initialize Firebase Messaging and Local Notifications.
  Future<void> initialize({String? userId}) async {
    if (userId != null) {
      _currentUserId = userId;
    }

    if (_isInitialized) {
      if (_currentUserId != null) {
        await _registerToken(_currentUserId!);
      }
      return;
    }

    // 1. Setup Firebase Messaging background handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // 2. Request Notification Permission
    try {
      await _fcm.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: true,
        provisional: false,
        sound: true,
      );
    } catch (_) {}

    // 3. Initialize Local Notifications Plugin
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    // Create high-priority Android notification channel
    final androidChannel = const AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDescription,
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);

    // 4. Token management
    if (_currentUserId != null && _currentUserId!.isNotEmpty) {
      await _registerToken(_currentUserId!);
    }

    _fcm.onTokenRefresh.listen((newToken) {
      if (_currentUserId != null && _currentUserId!.isNotEmpty) {
        UserService().updateFcmToken(_currentUserId!, newToken);
      }
    });

    // 5. Handle FCM message events
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      _showFcmRemoteNotification(message);
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _handleFcmNotificationTap(message);
    });

    // Check initial message if app opened from terminated state
    _fcm.getInitialMessage().then((RemoteMessage? message) {
      if (message != null) {
        _handleFcmNotificationTap(message);
      }
    });

    _isInitialized = true;
  }

  /// Register device token to Firestore user document
  Future<void> _registerToken(String userId) async {
    try {
      final token = await _fcm.getToken();
      if (token != null && token.isNotEmpty) {
        await UserService().updateFcmToken(userId, token);
      }
    } catch (_) {}
  }

  /// Update active user context
  void setCurrentUser(String userId) {
    _currentUserId = userId;
    if (userId.isNotEmpty) {
      _registerToken(userId);
    }
  }

  /// Start listening to real-time safety alerts for a specific active ride.
  /// Deduplicates alerts and triggers high-priority local notifications.
  void startListeningForConvoyAlerts({
    required String rideId,
    required String currentUserId,
  }) {
    if (rideId.isEmpty) return;

    _activeRideId = rideId;
    _currentUserId = currentUserId;

    // Cancel existing subscription if any
    stopListeningForConvoyAlerts();

    _alertsSubscription = SafetyService().streamActiveAlerts(rideId).listen((alerts) {
      for (final alert in alerts) {
        // Skip if alert already handled (Deduplication)
        if (_handledAlertIds.contains(alert.alertId)) continue;

        // Mark as handled
        _handledAlertIds.add(alert.alertId);

        // Skip self alerts (do not notify user of their own trigger)
        if (alert.userId == currentUserId) continue;

        // Skip resolved alerts
        if (alert.status == AppConstants.alertStatusResolved) continue;

        // Trigger Local Safety Notification
        showLocalSafetyNotification(alert: alert);
      }
    });
  }

  /// Stop listening to convoy safety alerts (e.g. when leaving ride screen or when ride is completed)
  void stopListeningForConvoyAlerts() {
    _alertsSubscription?.cancel();
    _alertsSubscription = null;
    _activeRideId = null;
  }

  String? get activeRideId => _activeRideId;

  /// Display a high-priority system notification banner for a safety alert.
  Future<void> showLocalSafetyNotification({required SafetyAlertModel alert}) async {
    String title = 'Convoy Safety Alert';
    String body = '${alert.userName} needs attention.';

    if (alert.type == AppConstants.alertTypeManualSOS ||
        alert.type == AppConstants.alertTypeEmergency ||
        alert.type.contains('sos') ||
        alert.type.contains('emergency')) {
      title = '🚨 Convoy Emergency';
      body = '${alert.userName} requested emergency assistance!';
    } else if (alert.type == AppConstants.alertTypeStillness ||
        alert.type == AppConstants.alertTypeNoResponse ||
        alert.type.contains('stillness') ||
        alert.type.contains('no_response')) {
      title = '⚠️ Rider Safety Check';
      body = '${alert.userName} did not respond to the safety check.';
    } else if (alert.message.isNotEmpty) {
      body = '${alert.userName}: ${alert.message}';
    }

    final androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.max,
      priority: Priority.high,
      ticker: title,
      color: Colors.red,
      icon: '@mipmap/ic_launcher',
    );

    final notificationDetails = NotificationDetails(android: androidDetails);

    final payload = '${alert.rideId}|${alert.alertId}';

    await _localNotifications.show(
      alert.alertId.hashCode,
      title,
      body,
      notificationDetails,
      payload: payload,
    );
  }

  /// Show FCM Remote Message Notification
  void _showFcmRemoteNotification(RemoteMessage message) {
    final notification = message.notification;
    if (notification == null) return;

    final rideId = message.data['rideId'] as String? ?? '';
    final alertId = message.data['alertId'] as String? ?? '';

    final androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.max,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    _localNotifications.show(
      notification.hashCode,
      notification.title ?? 'Convoy Notification',
      notification.body ?? 'Safety update received.',
      NotificationDetails(android: androidDetails),
      payload: '$rideId|$alertId',
    );
  }

  /// Handle Notification Tap Callback from Local Notification
  void _onNotificationTap(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null || payload.isEmpty) return;

    final parts = payload.split('|');
    final rideId = parts.isNotEmpty ? parts[0] : '';

    if (rideId.isNotEmpty) {
      _navigateToEmergencyScreen(rideId);
    }
  }

  /// Handle Notification Tap Callback from FCM
  void _handleFcmNotificationTap(RemoteMessage message) {
    final rideId = message.data['rideId'] as String? ?? '';
    if (rideId.isNotEmpty) {
      _navigateToEmergencyScreen(rideId);
    }
  }

  /// Navigate to EmergencyAssistanceScreen securely using top-level navigatorKey
  void _navigateToEmergencyScreen(String rideId) {
    if (navigatorKey.currentState != null) {
      navigatorKey.currentState?.pushNamed(
        '/emergency-assistance',
        arguments: rideId,
      );
    }
  }
}
