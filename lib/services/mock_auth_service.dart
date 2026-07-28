import 'package:flutter/foundation.dart';

// Mock Authentication Service
// This is a temporary bypass to allow the app to work
// while Firebase authentication platform channel issues are resolved
class MockAuthService {
  static bool get _isAllowed => kDebugMode;
  static bool _isAuthenticated = false;
  static String? _currentUserEmail;
  static String? _currentUserName;

  // Check if user is authenticated
  static bool get isAuthenticated => _isAuthenticated;
  
  // Get current user email
  static String? get currentUserEmail => _currentUserEmail;
  
  // Get current user name
  static String? get currentUserName => _currentUserName;

  // Mock sign up with email and password
  static Future<bool> signUpWithEmailAndPassword({
    required String email,
    required String password,
    String? firstName,
    String? lastName,
  }) async {
    if (!_isAllowed) throw Exception('MockAuthService is not available in release builds');
    try {
      // Simulate API delay
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Mock validation
      if (!_isValidEmail(email)) {
        throw Exception('Invalid email address');
      }
      
      if (password.length < 6) {
        throw Exception('Password should be at least 6 characters');
      }
      
      // Simulate successful signup
      _isAuthenticated = true;
      _currentUserEmail = email;
      _currentUserName = firstName != null && lastName != null 
          ? '$firstName $lastName'
          : firstName ?? 'User';
      
      if (kDebugMode) debugPrint('Mock authentication successful for: $email');
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('Mock authentication failed: $e');
      rethrow;
    }
  }

  // Mock Google Sign In
  static Future<bool> signInWithGoogle() async {
    if (!_isAllowed) throw Exception('MockAuthService is not available in release builds');
    try {
      // Simulate API delay
      await Future.delayed(const Duration(milliseconds: 800));
      
      // Simulate successful Google sign in
      _isAuthenticated = true;
      _currentUserEmail = 'user@gmail.com';
      _currentUserName = 'Google User';
      
      if (kDebugMode) debugPrint('Mock Google authentication successful');
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('Mock Google authentication failed: $e');
      rethrow;
    }
  }

  // Mock sign in with email and password
  static Future<bool> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    if (!_isAllowed) throw Exception('MockAuthService is not available in release builds');
    try {
      // Simulate API delay
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Mock validation
      if (!_isValidEmail(email)) {
        throw Exception('Invalid email address');
      }
      
      // Simulate successful signin
      _isAuthenticated = true;
      _currentUserEmail = email;
      _currentUserName = 'Returning User';
      
      if (kDebugMode) debugPrint('Mock sign in successful for: $email');
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('Mock sign in failed: $e');
      rethrow;
    }
  }

  // Sign out
  static Future<void> signOut() async {
    _isAuthenticated = false;
    _currentUserEmail = null;
    _currentUserName = null;
    if (kDebugMode) debugPrint('Mock sign out successful');
  }

  // Email validation helper
  static bool _isValidEmail(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }

  // Get error message
  static String getErrorMessage(dynamic error) {
    if (error is Exception) {
      return error.toString().replaceAll('Exception: ', '');
    }
    return error.toString();
  }
}
