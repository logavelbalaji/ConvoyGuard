import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'user_service.dart';

class AuthResult {
  final bool isSuccess;
  final String? errorMessage;
  final User? user;

  const AuthResult({
    required this.isSuccess,
    this.errorMessage,
    this.user,
  });

  factory AuthResult.success(User? user) {
    return AuthResult(isSuccess: true, user: user);
  }

  factory AuthResult.failure(String message) {
    return AuthResult(isSuccess: false, errorMessage: message);
  }
}

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  FirebaseAuth? _authInstance;

  FirebaseAuth get _auth {
    _authInstance ??= FirebaseAuth.instance;
    return _authInstance!;
  }

  // Stream of auth state changes (logged in vs logged out)
  Stream<User?> get authStateChanges {
    try {
      return _auth.authStateChanges();
    } catch (_) {
      return const Stream.empty();
    }
  }

  // Current logged in Firebase user
  User? get currentUser {
    try {
      return _auth.currentUser;
    } catch (_) {
      return null;
    }
  }

  // Check if Firebase is initialized
  bool get isFirebaseInitialized => Firebase.apps.isNotEmpty;

  // Login with Email & Password
  Future<AuthResult> login({
    required String email,
    required String password,
  }) async {
    try {
      final UserCredential credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      return AuthResult.success(credential.user);
    } on FirebaseAuthException catch (e) {
      return AuthResult.failure(_getFriendlyErrorMessage(e.code, e.message));
    } catch (e) {
      if (!isFirebaseInitialized) {
        return AuthResult.failure(
          'Firebase is not yet configured. Please add your google-services.json file from the Firebase Console to enable real authentication.',
        );
      }
      return AuthResult.failure('Login failed: ${e.toString()}');
    }
  }

  // Register with Email & Password and create Firestore User Profile
  Future<AuthResult> register({
    required String email,
    required String password,
    required String name,
    required String phone,
    String? bikeModel,
    Map<String, String>? emergencyContact,
  }) async {
    try {
      final UserCredential credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      if (credential.user != null) {
        final uid = credential.user!.uid;
        try {
          await credential.user!.updateDisplayName(name);
        } catch (_) {}

        // Create Firestore user profile doc `users/{uid}`
        try {
          await UserService().createUserProfile(
            uid: uid,
            name: name,
            email: email,
            phone: phone,
            bikeModel: bikeModel ?? '',
            emergencyContact: emergencyContact,
          );
        } catch (_) {}
      }

      return AuthResult.success(credential.user);
    } on FirebaseAuthException catch (e) {
      return AuthResult.failure(_getFriendlyErrorMessage(e.code, e.message));
    } catch (e) {
      if (!isFirebaseInitialized) {
        return AuthResult.failure(
          'Firebase is not yet configured. Please add your google-services.json file from the Firebase Console to enable real registration.',
        );
      }
      return AuthResult.failure('Registration failed: ${e.toString()}');
    }
  }

  // Logout current user
  Future<void> logout() async {
    try {
      await _auth.signOut();
    } catch (_) {}
  }

  // Translate technical Firebase Auth error codes into user-friendly messages
  String _getFriendlyErrorMessage(String errorCode, String? rawMessage) {
    switch (errorCode) {
      case 'invalid-email':
        return 'The email address format is invalid. Please check and try again.';
      case 'user-not-found':
        return 'No rider account found with this email address.';
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect password or email. Please double check your credentials.';
      case 'email-already-in-use':
        return 'An account already exists with this email address. Try logging in instead.';
      case 'weak-password':
        return 'The password is too weak. Please use at least 6 characters.';
      case 'network-request-failed':
        return 'Network connection failed. Please check your internet connection and try again.';
      case 'too-many-requests':
        return 'Access to this account has been temporarily disabled due to many failed login attempts. Please try again later.';
      case 'user-disabled':
        return 'This rider account has been disabled. Contact support for assistance.';
      case 'operation-not-allowed':
        return 'Email/Password sign-in is not enabled in your Firebase Console.';
      default:
        return rawMessage ?? 'An authentication error occurred. Please try again.';
    }
  }
}
