import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'core/theme/app_theme.dart';
import 'screens/splash/splash_screen.dart';
import 'screens/auth/welcome_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/main_navigation_screen.dart';
import 'screens/ride/create_ride_screen.dart';
import 'screens/ride/join_ride_screen.dart';
import 'screens/ride/ride_group_screen.dart';
import 'screens/ride/live_map_screen.dart';
import 'screens/safety/emergency_assistance_screen.dart';
import 'screens/ride/ride_summary_screen.dart';
import 'services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
    await NotificationService().initialize();
  } catch (_) {
    // Gracefully handle unconfigured Firebase during early setup
  }
  runApp(const ConvoyGuardApp());
}

class ConvoyGuardApp extends StatelessWidget {
  const ConvoyGuardApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'CONVOYGUARD',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      initialRoute: '/splash',
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case '/splash':
            return MaterialPageRoute(builder: (_) => const SplashScreen());
          case '/welcome':
            return MaterialPageRoute(builder: (_) => const WelcomeScreen());
          case '/login':
            return MaterialPageRoute(builder: (_) => const LoginScreen());
          case '/register':
            return MaterialPageRoute(builder: (_) => const RegisterScreen());
          case '/main':
            final int initialIndex = settings.arguments is int ? settings.arguments as int : 0;
            return MaterialPageRoute(builder: (_) => MainNavigationScreen(initialIndex: initialIndex));
          case '/create-ride':
            return MaterialPageRoute(builder: (_) => const CreateRideScreen());
          case '/join-ride':
            return MaterialPageRoute(builder: (_) => const JoinRideScreen());
          case '/ride-group':
            final String rideId = settings.arguments is String ? settings.arguments as String : '';
            return MaterialPageRoute(builder: (_) => RideGroupScreen(rideId: rideId));
          case '/live-map':
            final String rideId = settings.arguments is String ? settings.arguments as String : '';
            return MaterialPageRoute(builder: (_) => LiveMapScreen(rideId: rideId));
          case '/emergency-assistance':
            final String? rideId = settings.arguments is String ? settings.arguments as String : null;
            return MaterialPageRoute(builder: (_) => EmergencyAssistanceScreen(rideId: rideId));
          case '/ride-summary':
            final String rideId = settings.arguments is String ? settings.arguments as String : '';
            return MaterialPageRoute(builder: (_) => RideSummaryScreen(rideId: rideId));
          default:
            return MaterialPageRoute(builder: (_) => const SplashScreen());
        }
      },
    );
  }
}

