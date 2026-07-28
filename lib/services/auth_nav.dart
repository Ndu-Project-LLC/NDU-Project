import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:ndu_project/services/firebase_auth_service.dart';

/// Centralized auth navigation helper
class AuthNav {
  /// Signs out the current user and clears the navigation stack,
  /// then sends the user to the SignInScreen.
  static Future<void> signOutAndExit(BuildContext context) async {
    try {
      await FirebaseAuthService.signOut();
    } catch (e) {
      // Best-effort: still attempt to navigate, but surface the error
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sign out failed: $e')),
        );
      }
    }

    if (context.mounted) {
      // Use go_router's context.go() to replace the entire navigation stack
      context.go('/sign-in');
    }
  }
}
