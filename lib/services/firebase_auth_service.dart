import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';
import 'google_sign_in_adapter.dart' as gadapter;

/// Centralized Firebase authentication helpers
class FirebaseAuthService {
  static FirebaseAuth get _auth => FirebaseAuth.instance;
  static const String _rememberMeKey = 'remember_me_enabled';

  /// Get Remember Me preference
  static Future<bool> getRememberMe() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_rememberMeKey) ?? false;
  }

  /// Set Remember Me preference
  static Future<void> setRememberMe(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_rememberMeKey, value);
  }

  /// Email/password sign in with optional persistence
  static Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
    bool rememberMe = false,
  }) async {
    if (kIsWeb) {
      // FirebaseAuth.setPersistence can hang on web in certain
      // configurations (e.g. when Firebase isn't fully initialised).
      // Firebase Auth web already defaults to LOCAL persistence, so
      // wrap in a non-blocking try-catch with a short timeout to
      // prevent the sign-in button from spinning forever.
      try {
        await _auth
            .setPersistence(
              rememberMe ? Persistence.LOCAL : Persistence.SESSION,
            )
            .timeout(const Duration(seconds: 3));
      } catch (e) {
        debugPrint('[FirebaseAuthService] setPersistence ignored: $e');
      }
    }
    await setRememberMe(rememberMe);
    final cred = await _auth.signInWithEmailAndPassword(
        email: email, password: password);
    return cred;
  }

  /// Send password reset email
  static Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  /// Cross-platform Google sign-in
  static Future<UserCredential> signInWithGoogle() async {
    return await gadapter.signIn();
  }

  /// Signs out from Firebase (and Google if needed)
  static Future<void> signOut() async {
    await _auth.signOut();
  }

  /// Display name helper with graceful fallback
  static String displayNameOrEmail({String fallback = 'User'}) {
    try {
      final u = _auth.currentUser;
      if (u == null) return fallback;
      final dn = u.displayName?.trim();
      if (dn != null && dn.isNotEmpty) return dn;
      final em = u.email?.trim();
      if (em != null && em.isNotEmpty) return em;
      return fallback;
    } catch (_) {
      return fallback;
    }
  }
}
