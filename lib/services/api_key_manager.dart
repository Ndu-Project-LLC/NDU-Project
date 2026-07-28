import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:ndu_project/services/api_config_secure.dart';

/// Secure API Key Manager
/// This allows you to set your API key at runtime without exposing it in source code
class ApiKeyManager {
  static bool _isInitialized = false;
  static const String _usersCollection = 'users';
  static const String _keyField = 'openaiApiKey';
  static const String _legacyKeyField = 'claudeApiKey'; // backward compat
  
  /// Initialize the API key securely
  /// Call this method once when your app starts
  static void initializeApiKey() {
    if (!_isInitialized) {
      // Initialize once; actual key may be set later via setApiKey()
      debugPrint('ApiKeyManager initialized. Waiting for API key input.');
      _isInitialized = true;
    }
  }
  
  /// Set the API key securely
  static void setApiKey(String apiKey) {
    SecureAPIConfig.setApiKey(apiKey);
    _isInitialized = true;
    debugPrint('ApiKeyManager: API key updated successfully.');
  }
  
  /// Check if API key is properly configured
  static bool get isConfigured => _isInitialized && SecureAPIConfig.hasApiKey;
  
  /// Clear the API key (for logout or security)
  static void clearApiKey() {
    SecureAPIConfig.clearApiKey();
    _isInitialized = false;
  }

  /// Loads a previously saved key for the currently signed-in user (if any).
  /// Reads from 'openaiApiKey' first, falls back to legacy 'claudeApiKey' field.
  static Future<void> ensureLoadedForSignedInUser() async {
    if (SecureAPIConfig.hasApiKey) return; // env key already active
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      final doc = await FirebaseFirestore.instance
          .collection(_usersCollection)
          .doc(user.uid)
          .get();
      if (!doc.exists) return;
      final data = doc.data();
      final key = data?[_keyField] as String? ?? data?[_legacyKeyField] as String?;
      if (key != null && key.trim().isNotEmpty) {
        setApiKey(key.trim());
        debugPrint('ApiKeyManager: loaded API key from Firestore for user ${user.uid.substring(0, 6)}…');
      }
    } catch (e) {
      debugPrint('ApiKeyManager.ensureLoadedForSignedInUser error: $e');
    }
  }

  /// Persists the provided key under users/{uid}. Creates the document if missing.
  static Future<void> persistForCurrentUser(String apiKey) async {
    setApiKey(apiKey);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      final users = FirebaseFirestore.instance.collection(_usersCollection);
      await users.doc(user.uid).set(
        {
          _keyField: apiKey.trim(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
      debugPrint('ApiKeyManager: API key persisted to Firestore for user ${user.uid.substring(0, 6)}…');
    } catch (e) {
      debugPrint('ApiKeyManager.persistForCurrentUser error: $e');
    }
  }

  /// Removes the stored key for the current user and clears in-memory key.
  static Future<void> removeForCurrentUser() async {
    clearApiKey();
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      final users = FirebaseFirestore.instance.collection(_usersCollection);
      await users.doc(user.uid).set(
        {
          _keyField: FieldValue.delete(),
          _legacyKeyField: FieldValue.delete(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
      debugPrint('ApiKeyManager: API key removed from Firestore for user ${user.uid.substring(0, 6)}…');
    } catch (e) {
      debugPrint('ApiKeyManager.removeForCurrentUser error: $e');
    }
  }
}
