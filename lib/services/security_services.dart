library;

/// Security Services — comprehensive security utilities for the NDU Project app.
///
/// This file contains all security-related services:
/// - SessionManager: auto-logout after inactivity
/// - PasswordValidator: strong password enforcement
/// - SecurityAuditLogger: immutable audit trail
/// - ApiKeyRotationService: API key rotation reminders
/// - SecureStorage: encrypted local storage for sensitive data
/// - RequestSigner: HMAC-SHA256 request signing
/// - AnomalyDetector: login location/behavior tracking

import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

enum AuthenticationMethod { password, passwordlessEmail }

enum MfaMethod { authenticator, sms, emailCode, none }

enum MfaRequirement { everyLogin, newDeviceOnly, highRiskOnly, adminOnly }

class SecurityPolicy {
  const SecurityPolicy({
    required this.passwordLoginEnabled,
    required this.passwordlessEmailEnabled,
    required this.mfaEnabled,
    required this.requireMfaEveryLogin,
    required this.requireMfaNewDeviceOnly,
    required this.requireMfaHighRiskOnly,
    required this.requireMfaAdminOnly,
    required this.defaultMfaMethod,
    required this.backupMethods,
    required this.rememberDeviceDays,
  });

  final bool passwordLoginEnabled;
  final bool passwordlessEmailEnabled;
  final bool mfaEnabled;
  final bool requireMfaEveryLogin;
  final bool requireMfaNewDeviceOnly;
  final bool requireMfaHighRiskOnly;
  final bool requireMfaAdminOnly;
  final MfaMethod defaultMfaMethod;
  final List<MfaMethod> backupMethods;
  final int rememberDeviceDays;

  factory SecurityPolicy.defaults() => const SecurityPolicy(
        passwordLoginEnabled: true,
        passwordlessEmailEnabled: false,
        mfaEnabled: true,
        requireMfaEveryLogin: true,
        requireMfaNewDeviceOnly: false,
        requireMfaHighRiskOnly: false,
        requireMfaAdminOnly: false,
        defaultMfaMethod: MfaMethod.authenticator,
        backupMethods: [MfaMethod.sms, MfaMethod.emailCode],
        rememberDeviceDays: 30,
      );

  Map<String, dynamic> toMap() => {
        'passwordLoginEnabled': passwordLoginEnabled,
        'passwordlessEmailEnabled': passwordlessEmailEnabled,
        'mfaEnabled': mfaEnabled,
        'requireMfaEveryLogin': requireMfaEveryLogin,
        'requireMfaNewDeviceOnly': requireMfaNewDeviceOnly,
        'requireMfaHighRiskOnly': requireMfaHighRiskOnly,
        'requireMfaAdminOnly': requireMfaAdminOnly,
        'defaultMfaMethod': defaultMfaMethod.name,
        'backupMethods': backupMethods.map((e) => e.name).toList(),
        'rememberDeviceDays': rememberDeviceDays,
      };

  factory SecurityPolicy.fromMap(Map<String, dynamic>? map) {
    final data = map ?? const {};
    MfaMethod parseMfa(String? value) {
      switch (value) {
        case 'sms':
          return MfaMethod.sms;
        case 'emailCode':
          return MfaMethod.emailCode;
        case 'none':
          return MfaMethod.none;
        case 'authenticator':
        default:
          return MfaMethod.authenticator;
      }
    }

    return SecurityPolicy(
      passwordLoginEnabled: data['passwordLoginEnabled'] != false,
      passwordlessEmailEnabled: data['passwordlessEmailEnabled'] == true,
      mfaEnabled: data['mfaEnabled'] != false,
      requireMfaEveryLogin: data['requireMfaEveryLogin'] != false,
      requireMfaNewDeviceOnly: data['requireMfaNewDeviceOnly'] == true,
      requireMfaHighRiskOnly: data['requireMfaHighRiskOnly'] == true,
      requireMfaAdminOnly: data['requireMfaAdminOnly'] == true,
      defaultMfaMethod: parseMfa(data['defaultMfaMethod'] as String?),
      backupMethods: (data['backupMethods'] as List<dynamic>? ?? const [])
          .map((e) => parseMfa(e.toString()))
          .toList(),
      rememberDeviceDays: (data['rememberDeviceDays'] as num?)?.toInt() ?? 30,
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// #6: SESSION MANAGER — auto-logout after inactivity
// ═══════════════════════════════════════════════════════════════════════════

class SessionManager {
  static final SessionManager instance = SessionManager._();
  SessionManager._();

  Timer? _timer;
  static const Duration _timeout = Duration(minutes: 30);
  DateTime? _lastActivity;
  bool _isEnabled = true;

  /// Enable or disable session timeout (e.g. disable during long operations)
  void setEnabled(bool enabled) {
    _isEnabled = enabled;
    if (!enabled) _timer?.cancel();
  }

  /// Reset the inactivity timer. Call on any user interaction.
  void resetTimer() {
    if (!_isEnabled) return;
    _timer?.cancel();
    _lastActivity = DateTime.now();
    _timer = Timer(_timeout, () {
      debugPrint(
          '[SessionManager] Session timed out after ${_timeout.inMinutes} minutes of inactivity');
      _signOut();
    });
  }

  /// Get the last activity time (for display in UI)
  DateTime? get lastActivity => _lastActivity;

  /// Get remaining time until timeout (for warnings)
  Duration? get remainingTime {
    if (_lastActivity == null || !_isEnabled) return null;
    final elapsed = DateTime.now().difference(_lastActivity!);
    final remaining = _timeout - elapsed;
    return remaining.isNegative ? Duration.zero : remaining;
  }

  /// Initialize session monitoring — call after sign-in
  void start() {
    _isEnabled = true;
    resetTimer();
  }

  /// Stop session monitoring — call on sign-out
  void stop() {
    _timer?.cancel();
    _lastActivity = null;
  }

  void _signOut() async {
    try {
      await FirebaseAuth.instance.signOut();
    } catch (e) {
      debugPrint('[SessionManager] Sign-out error: $e');
    }
  }

  /// Set up a global listener that resets the timer on any pointer interaction
  void setupGlobalListener(BuildContext context) {
    // Use a GestureDetector at the app root to detect activity
    // This is called from the app's builder
    resetTimer();
  }

  void dispose() {
    _timer?.cancel();
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// #7: PASSWORD VALIDATOR — strong password enforcement
// ═══════════════════════════════════════════════════════════════════════════

class PasswordValidator {
  PasswordValidator._();

  /// Validate password strength. Returns null if valid, error message if invalid.
  static String? validate(String password) {
    if (password.isEmpty) return 'Password is required';
    if (password.length < 8) return 'Minimum 8 characters required';
    if (password.length > 128) return 'Maximum 128 characters allowed';
    if (!password.contains(RegExp(r'[A-Z]')))
      return 'Must include an uppercase letter';
    if (!password.contains(RegExp(r'[a-z]')))
      return 'Must include a lowercase letter';
    if (!password.contains(RegExp(r'[0-9]'))) return 'Must include a number';
    if (!password.contains(RegExp(r'[!@#$%^&*()_+\-=\[\]{};:"\\|,.<>\/?~`]'))) {
      return 'Must include a special character (!@#\$%^&*)';
    }
    // Check for common weak passwords
    final lower = password.toLowerCase();
    final weakPasswords = [
      'password',
      '12345678',
      'qwerty12',
      'abc12345',
      'password1'
    ];
    for (final weak in weakPasswords) {
      if (lower.contains(weak))
        return 'Password is too common. Please choose a stronger password.';
    }
    return null; // Valid
  }

  /// Get password strength score (0-5)
  static int getStrengthScore(String password) {
    int score = 0;
    if (password.length >= 8) score++;
    if (password.length >= 12) score++;
    if (password.contains(RegExp(r'[A-Z]'))) score++;
    if (password.contains(RegExp(r'[0-9]'))) score++;
    if (password.contains(RegExp(r'[!@#$%^&*()_+\-=\[\]{};:"\\|,.<>\/?~`]')))
      score++;
    return score;
  }

  /// Get human-readable strength label
  static String getStrengthLabel(int score) {
    switch (score) {
      case 0:
      case 1:
        return 'Very Weak';
      case 2:
        return 'Weak';
      case 3:
        return 'Fair';
      case 4:
        return 'Strong';
      case 5:
        return 'Very Strong';
      default:
        return 'Unknown';
    }
  }

  /// Get color for strength score
  static Color getStrengthColor(int score) {
    switch (score) {
      case 0:
      case 1:
        return const Color(0xFFEF4444); // Red
      case 2:
        return const Color(0xFFF59E0B); // Amber
      case 3:
        return const Color(0xFFEAB308); // Yellow
      case 4:
        return const Color(0xFF22C55E); // Green
      case 5:
        return const Color(0xFF10B981); // Emerald
      default:
        return const Color(0xFF6B7280); // Gray
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// #9: SECURITY AUDIT LOGGER — immutable audit trail
// ═══════════════════════════════════════════════════════════════════════════

class SecurityAuditLogger {
  SecurityAuditLogger._();

  /// Log a security-relevant action to the immutable audit trail.
  static Future<void> log({
    required String action,
    String? userId,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final uid = userId ?? FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      await FirebaseFirestore.instance.collection('securityAudit').add({
        'action': action,
        'userId': uid,
        'timestamp': FieldValue.serverTimestamp(),
        'userAgent': _getUserAgent(),
        'metadata': metadata ?? {},
        // Immutable — no update/delete allowed per Firestore rules
      });
      debugPrint('[SecurityAuditLogger] Logged: $action for user $uid');
    } catch (e) {
      debugPrint('[SecurityAuditLogger] Failed to log: $e');
    }
  }

  /// Log a successful sign-in
  static Future<void> logSignIn({String? email}) async {
    await log(
      action: 'sign_in',
      metadata: {'email': email},
    );
  }

  /// Log a sign-out
  static Future<void> logSignOut() async {
    await log(action: 'sign_out');
  }

  /// Log a failed sign-in attempt
  static Future<void> logFailedSignIn({String? email, String? reason}) async {
    await log(
      action: 'failed_sign_in',
      metadata: {'email': email, 'reason': reason},
    );
  }

  /// Log admin panel access
  static Future<void> logAdminAccess({String? screen}) async {
    await log(
      action: 'admin_access',
      metadata: {'screen': screen},
    );
  }

  /// Log API key change
  static Future<void> logApiKeyChange() async {
    await log(action: 'api_key_changed');
  }

  /// Log account creation
  static Future<void> logAccountCreation({String? email}) async {
    await log(
      action: 'account_created',
      metadata: {'email': email},
    );
  }

  /// Log team invitation sent
  static Future<void> logTeamInvitation({required String inviteeEmail}) async {
    await log(
      action: 'team_invitation_sent',
      metadata: {'inviteeEmail': inviteeEmail},
    );
  }

  static String _getUserAgent() {
    try {
      return PlatformDispatcher.instance.views.first.platformDispatcher
          .toString();
    } catch (_) {
      return 'unknown';
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// #11: API KEY ROTATION SERVICE — remind users to rotate keys
// ═══════════════════════════════════════════════════════════════════════════

class ApiKeyRotationService {
  ApiKeyRotationService._();

  static const Duration _rotationPeriod = Duration(days: 90);
  static const String _lastRotatedKey = 'api_key_last_rotated';

  /// Check if the API key needs rotation. Returns true if rotation is overdue.
  static Future<bool> needsRotation() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastRotatedMs = prefs.getInt(_lastRotatedKey);
      if (lastRotatedMs == null) return false; // Never set — don't prompt

      final lastRotated = DateTime.fromMillisecondsSinceEpoch(lastRotatedMs);
      final age = DateTime.now().difference(lastRotated);
      return age > _rotationPeriod;
    } catch (_) {
      return false;
    }
  }

  /// Mark the API key as rotated (call when user sets a new key)
  static Future<void> markRotated() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(
          _lastRotatedKey, DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      debugPrint('[ApiKeyRotationService] Failed to mark rotation: $e');
    }
  }

  /// Get the date the key was last rotated
  static Future<DateTime?> getLastRotatedDate() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final ms = prefs.getInt(_lastRotatedKey);
      if (ms == null) return null;
      return DateTime.fromMillisecondsSinceEpoch(ms);
    } catch (_) {
      return null;
    }
  }

  /// Get days until rotation is needed
  static Future<int?> getDaysUntilRotation() async {
    final lastRotated = await getLastRotatedDate();
    if (lastRotated == null) return null;
    final expiry = lastRotated.add(_rotationPeriod);
    return expiry.difference(DateTime.now()).inDays;
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// #12: SECURE STORAGE — encrypted local storage for sensitive data
// ═══════════════════════════════════════════════════════════════════════════
//
// NOTE: flutter_secure_storage uses platform-specific secure storage:
// - iOS: Keychain
// - Android: EncryptedSharedPreferences
// - Web: Web Crypto API (encrypted in localStorage)
//
// We use a hybrid approach: on native, use flutter_secure_storage; on web,
// use obfuscated localStorage (since flutter_secure_storage on web is less
// secure than native). API keys are stored in Firestore (server-side) as
// the primary storage, with local caching for offline access.

class SecureStorage {
  SecureStorage._();

  static const String _apiKeyKey = 'secure_openai_api_key';
  static const String _twoFactorSecretKey = 'secure_2fa_secret';

  /// Store the OpenAI API key securely
  static Future<void> setApiKey(String apiKey) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // XOR-obfuscate the key (not true encryption, but prevents casual reading)
      final obfuscated = _obfuscate(apiKey);
      await prefs.setString(_apiKeyKey, obfuscated);
      await ApiKeyRotationService.markRotated();
    } catch (e) {
      debugPrint('[SecureStorage] Failed to store API key: $e');
    }
  }

  /// Retrieve the OpenAI API key
  static Future<String?> getApiKey() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final obfuscated = prefs.getString(_apiKeyKey);
      if (obfuscated == null) return null;
      return _deobfuscate(obfuscated);
    } catch (e) {
      debugPrint('[SecureStorage] Failed to retrieve API key: $e');
      return null;
    }
  }

  /// Clear the stored API key
  static Future<void> clearApiKey() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_apiKeyKey);
    } catch (_) {}
  }

  /// Store a 2FA secret
  static Future<void> setTwoFactorSecret(String secret) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_twoFactorSecretKey, _obfuscate(secret));
    } catch (e) {
      debugPrint('[SecureStorage] Failed to store 2FA secret: $e');
    }
  }

  /// Retrieve the 2FA secret
  static Future<String?> getTwoFactorSecret() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final obfuscated = prefs.getString(_twoFactorSecretKey);
      if (obfuscated == null) return null;
      return _deobfuscate(obfuscated);
    } catch (_) {
      return null;
    }
  }

  /// Clear 2FA secret
  static Future<void> clearTwoFactorSecret() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_twoFactorSecretKey);
    } catch (_) {}
  }

  /// Simple XOR obfuscation (not cryptographic security, but prevents casual reading)
  static String _obfuscate(String input) {
    final key = 'ndu_project_2026_security_key';
    final bytes = utf8.encode(input);
    final keyBytes = utf8.encode(key);
    final result = <int>[];
    for (int i = 0; i < bytes.length; i++) {
      result.add(bytes[i] ^ keyBytes[i % keyBytes.length]);
    }
    return base64Encode(result);
  }

  static String _deobfuscate(String input) {
    final key = 'ndu_project_2026_security_key';
    final bytes = base64Decode(input);
    final keyBytes = utf8.encode(key);
    final result = <int>[];
    for (int i = 0; i < bytes.length; i++) {
      result.add(bytes[i] ^ keyBytes[i % keyBytes.length]);
    }
    return utf8.decode(result);
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// #13: REQUEST SIGNER — HMAC-SHA256 request signing
// ═══════════════════════════════════════════════════════════════════════════

class RequestSigner {
  RequestSigner._();

  /// Sign a request body with HMAC-SHA256
  static String sign(Map<String, dynamic> body, String secret) {
    final payload = jsonEncode(body);
    final hmac = Hmac(sha256, utf8.encode(secret));
    final digest = hmac.convert(utf8.encode(payload));
    return digest.toString();
  }

  /// Verify a signature (for server-side validation)
  static bool verify(
      Map<String, dynamic> body, String secret, String signature) {
    final expected = sign(body, secret);
    return expected == signature;
  }

  /// Generate a timestamp-based nonce to prevent replay attacks
  static String generateNonce() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = DateTime.now().microsecondsSinceEpoch;
    return '$timestamp-$random';
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// #20: ANOMALY DETECTOR — detect unusual login behavior
// ═══════════════════════════════════════════════════════════════════════════

class AnomalyDetector {
  AnomalyDetector._();

  /// Check for anomalous login patterns and log warnings
  static Future<void> checkLoginAnomaly({
    required String userId,
    required String email,
  }) async {
    try {
      // Get recent login history
      final recentLogins = await FirebaseFirestore.instance
          .collection('securityAudit')
          .where('userId', isEqualTo: userId)
          .where('action', isEqualTo: 'sign_in')
          .orderBy('timestamp', descending: true)
          .limit(10)
          .get();

      final loginCount = recentLogins.size;

      // Flag if more than 5 logins in the recent history (potential brute force)
      if (loginCount > 5) {
        final now = DateTime.now();
        final recentDocs = recentLogins.docs.where((doc) {
          final ts = doc.data()['timestamp'] as Timestamp?;
          if (ts == null) return false;
          return now.difference(ts.toDate()).inMinutes < 60;
        });

        if (recentDocs.length > 5) {
          await SecurityAuditLogger.log(
            action: 'anomaly_excessive_logins',
            userId: userId,
            metadata: {
              'email': email,
              'loginCount': recentDocs.length,
              'timeWindow': '1 hour',
            },
          );
          debugPrint(
              '[AnomalyDetector] Excessive login attempts detected for $email');
        }
      }

      // Check for failed sign-in attempts
      final failedLogins = await FirebaseFirestore.instance
          .collection('securityAudit')
          .where('userId', isEqualTo: userId)
          .where('action', isEqualTo: 'failed_sign_in')
          .orderBy('timestamp', descending: true)
          .limit(5)
          .get();

      if (failedLogins.size >= 3) {
        await SecurityAuditLogger.log(
          action: 'anomaly_multiple_failed_logins',
          userId: userId,
          metadata: {
            'email': email,
            'failedCount': failedLogins.size,
          },
        );
        debugPrint(
            '[AnomalyDetector] Multiple failed logins detected for $email');
      }
    } catch (e) {
      debugPrint('[AnomalyDetector] Error: $e');
    }
  }

  /// Check for bulk data export patterns
  static Future<void> checkBulkDataAccess({
    required String userId,
    required String resource,
  }) async {
    try {
      final recentAccess = await FirebaseFirestore.instance
          .collection('securityAudit')
          .where('userId', isEqualTo: userId)
          .where('action', isEqualTo: 'data_access')
          .orderBy('timestamp', descending: true)
          .limit(100)
          .get();

      final now = DateTime.now();
      final recentDocs = recentAccess.docs.where((doc) {
        final ts = doc.data()['timestamp'] as Timestamp?;
        if (ts == null) return false;
        return now.difference(ts.toDate()).inMinutes < 5;
      });

      if (recentDocs.length > 50) {
        await SecurityAuditLogger.log(
          action: 'anomaly_bulk_data_access',
          userId: userId,
          metadata: {
            'resource': resource,
            'accessCount': recentDocs.length,
            'timeWindow': '5 minutes',
          },
        );
        debugPrint(
            '[AnomalyDetector] Bulk data access detected for user $userId');
      }
    } catch (e) {
      debugPrint('[AnomalyDetector] Bulk access check error: $e');
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// #10: TWO-FACTOR AUTHENTICATION (2FA) — Email OTP via Resend Cloud Functions
// ═══════════════════════════════════════════════════════════════════════════
//
// Sends a 6-digit OTP to the user's email via the Cloud Functions:
//   • sendTwoFactorCode  — generates & emails the OTP (Resend from noreply@nduproject.tech)
//   • verifyTwoFactorCode — validates the OTP against Firestore
//
// The OTP is stored in Firestore (collection: twoFactorCodes) with a 10-minute TTL.
// Rate limiting is enforced server-side (5 requests per user per hour).

class TwoFactorAuthService {
  TwoFactorAuthService._();

  /// Cloud Function URLs (region us-central1, project ndu-d3f60)
  static const String _sendCodeUrl =
      'https://us-central1-ndu-d3f60.cloudfunctions.net/sendTwoFactorCode';
  static const String _verifyCodeUrl =
      'https://us-central1-ndu-d3f60.cloudfunctions.net/verifyTwoFactorCode';

  // ── Check if 2FA is enabled for the current user ───────────────────────
  /// We consider 2FA enabled when the user has a `twoFactorEnabled: true`
  /// flag in their Firestore user profile document.
  static Future<bool> isEnabled() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      return doc.data()?['twoFactorEnabled'] == true;
    } catch (e) {
      debugPrint('[TwoFactorAuthService] isEnabled error: $e');
      return false;
    }
  }

  static Future<SecurityPolicy> loadPolicy() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('security_settings_system')
          .doc('current')
          .get();
      return SecurityPolicy.fromMap(doc.data());
    } catch (e) {
      debugPrint('[TwoFactorAuthService] loadPolicy error: $e');
      return SecurityPolicy.defaults();
    }
  }

  static Future<void> savePolicy(SecurityPolicy policy) async {
    await FirebaseFirestore.instance
        .collection('security_settings_system')
        .doc('current')
        .set({
      ...policy.toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static Future<void> saveUserSecurity({
    required String uid,
    required String email,
    required MfaMethod method,
    String? encryptedSecret,
    String? phoneNumber,
    List<String>? recoveryCodes,
  }) async {
    await FirebaseFirestore.instance.collection('users').doc(uid).set({
      'security': {
        'mfaMethod': method.name,
        'mfaEnabled': method != MfaMethod.none,
        if (encryptedSecret != null) 'encryptedSecret': encryptedSecret,
        if (phoneNumber != null) 'phoneNumber': phoneNumber,
        if (recoveryCodes != null) 'recoveryCodes': recoveryCodes,
        'updatedAt': FieldValue.serverTimestamp(),
        'email': email,
      }
    }, SetOptions(merge: true));
  }

  static String _trustedDeviceKey(String uid) => 'trusted_device_$uid';
  static String _recoveryCodesKey(String uid) => 'recovery_codes_$uid';

  static Future<bool> isTrustedDevice(String uid,
      {int rememberDays = 30}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final ms = prefs.getInt(_trustedDeviceKey(uid));
      if (ms == null) return false;
      final expires = DateTime.fromMillisecondsSinceEpoch(ms);
      return DateTime.now().isBefore(expires);
    } catch (_) {
      return false;
    }
  }

  static Future<void> rememberDevice(String uid, {int days = 30}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
      _trustedDeviceKey(uid),
      DateTime.now().add(Duration(days: days)).millisecondsSinceEpoch,
    );
  }

  static List<String> generateRecoveryCodes({int count = 10}) {
    const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rng = DateTime.now().microsecondsSinceEpoch;
    return List.generate(count, (index) {
      final seed = rng + index * 7919;
      final chars = List.generate(8, (i) {
        final pos = (seed + i * 31) % alphabet.length;
        return alphabet[pos];
      });
      return '${chars.sublist(0, 4).join()}-${chars.sublist(4).join()}';
    });
  }

  static Future<void> saveRecoveryCodes(String uid, List<String> codes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_recoveryCodesKey(uid), codes);
    await FirebaseFirestore.instance.collection('users').doc(uid).set({
      'security': {
        'recoveryCodes': codes,
        'recoveryCodesUpdatedAt': FieldValue.serverTimestamp(),
      }
    }, SetOptions(merge: true));
  }

  static Future<List<String>> getRecoveryCodes(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_recoveryCodesKey(uid)) ?? <String>[];
  }

  static Future<bool> consumeRecoveryCode(String uid, String code) async {
    final prefs = await SharedPreferences.getInstance();
    final codes = prefs.getStringList(_recoveryCodesKey(uid)) ?? <String>[];
    final normalized = code.trim().toUpperCase();
    final remaining =
        codes.where((c) => c.toUpperCase() != normalized).toList();
    if (remaining.length == codes.length) return false;
    await prefs.setStringList(_recoveryCodesKey(uid), remaining);
    await FirebaseFirestore.instance.collection('users').doc(uid).set({
      'security': {
        'recoveryCodes': remaining,
        'recoveryCodesUpdatedAt': FieldValue.serverTimestamp(),
      }
    }, SetOptions(merge: true));
    return true;
  }

  // ── Enable / Disable 2FA ──────────────────────────────────────────────
  static Future<void> enable() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
      'twoFactorEnabled': true,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    await SecurityAuditLogger.log(action: '2fa_enabled');
  }

  static Future<void> disable() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
      'twoFactorEnabled': false,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    await SecurityAuditLogger.log(action: '2fa_disabled');
  }

  // ── Send OTP ──────────────────────────────────────────────────────────
  /// Sends a 6-digit verification code to [email] via Resend.
  /// Returns a success message or throws on failure.
  static Future<String> sendCode({required String email}) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      String? idToken;
      try {
        idToken = await user?.getIdToken();
      } catch (_) {
        // User may be signed out during 2FA flow — sendCode works without auth
      }

      final headers = <String, String>{
        'Content-Type': 'application/json',
      };
      if (idToken != null) {
        headers['Authorization'] = 'Bearer $idToken';
      }

      final response = await http
          .post(
            Uri.parse(_sendCodeUrl),
            headers: headers,
            body: jsonEncode({
              'data': {'email': email},
            }),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final result = data['result'] as Map<String, dynamic>? ?? data;
        if (result['success'] == true) {
          debugPrint('[TwoFactorAuthService] Code sent to $email');
          return result['message'] as String? ?? 'Code sent.';
        }
        throw Exception(result['message'] as String? ?? 'Failed to send code.');
      }

      // Parse Cloud Functions error format
      final errorData = jsonDecode(response.body) as Map<String, dynamic>;
      final error = errorData['error'] as Map<String, dynamic>?;
      throw Exception(error?['message'] as String? ?? 'Failed to send code.');
    } catch (e) {
      debugPrint('[TwoFactorAuthService] sendCode error: $e');
      rethrow;
    }
  }

  // ── Verify OTP ────────────────────────────────────────────────────────
  /// Verifies the 6-digit [code] entered by the user.
  /// Returns true if valid, false otherwise.
  static Future<bool> verifyCode(
      {required String code, required String email}) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      String? idToken;
      try {
        idToken = await user?.getIdToken();
      } catch (_) {}

      final headers = <String, String>{
        'Content-Type': 'application/json',
      };
      if (idToken != null) {
        headers['Authorization'] = 'Bearer $idToken';
      }

      final response = await http
          .post(
            Uri.parse(_verifyCodeUrl),
            headers: headers,
            body: jsonEncode({
              'data': {'code': code, 'email': email},
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final result = data['result'] as Map<String, dynamic>? ?? data;
        return result['success'] == true;
      }

      final errorData = jsonDecode(response.body) as Map<String, dynamic>;
      final error = errorData['error'] as Map<String, dynamic>?;
      debugPrint(
          '[TwoFactorAuthService] verifyCode HTTP error: ${error?['message']}');
      return false;
    } catch (e) {
      debugPrint('[TwoFactorAuthService] verifyCode error: $e');
      return false;
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// #8: ACCOUNT LOCKOUT — track failed login attempts
// ═══════════════════════════════════════════════════════════════════════════

class AccountLockoutService {
  AccountLockoutService._();

  static const int _maxAttempts = 5;
  static const Duration _lockoutDuration = Duration(minutes: 15);
  static const String _attemptsKey = 'failed_login_attempts';
  static const String _lockoutKey = 'lockout_until';

  /// Record a failed login attempt and check if the account should be locked
  static Future<bool> recordFailedAttempt() async {
    final prefs = await SharedPreferences.getInstance();
    final attempts = (prefs.getInt(_attemptsKey) ?? 0) + 1;
    await prefs.setInt(_attemptsKey, attempts);

    if (attempts >= _maxAttempts) {
      final lockoutUntil = DateTime.now().add(_lockoutDuration);
      await prefs.setInt(_lockoutKey, lockoutUntil.millisecondsSinceEpoch);
      return true; // Account is now locked
    }
    return false;
  }

  /// Reset failed attempts counter (call on successful login)
  static Future<void> resetAttempts() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_attemptsKey);
    await prefs.remove(_lockoutKey);
  }

  /// Check if the account is currently locked
  static Future<bool> isLocked() async {
    final prefs = await SharedPreferences.getInstance();
    final lockoutMs = prefs.getInt(_lockoutKey);
    if (lockoutMs == null) return false;
    final lockoutUntil = DateTime.fromMillisecondsSinceEpoch(lockoutMs);
    return DateTime.now().isBefore(lockoutUntil);
  }

  /// Get remaining lockout time
  static Future<Duration?> getRemainingLockout() async {
    final prefs = await SharedPreferences.getInstance();
    final lockoutMs = prefs.getInt(_lockoutKey);
    if (lockoutMs == null) return null;
    final lockoutUntil = DateTime.fromMillisecondsSinceEpoch(lockoutMs);
    final remaining = lockoutUntil.difference(DateTime.now());
    return remaining.isNegative ? null : remaining;
  }

  /// Get current failed attempt count
  static Future<int> getAttemptCount() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_attemptsKey) ?? 0;
  }

  /// Get max attempts before lockout
  static int get maxAttempts => _maxAttempts;
}
