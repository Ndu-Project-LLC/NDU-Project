library;

/// Team Invitation Service
///
/// Sends invitation emails to team members via the Firebase Callable Cloud
/// Function `sendTeamInvitation`. The Cloud Function uses Resend to send
/// branded HTML emails with a sign-in link.
///
/// Setup (one-time, on the server):
///   firebase functions:secrets:set RESEND_API_KEY
///   firebase deploy --only functions:sendTeamInvitation
///
/// IMPORTANT: This service propagates errors to the caller so they can be
/// displayed to the user. Do NOT silently swallow errors here.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class TeamInvitationService {
  TeamInvitationService._();

  /// Send an invitation email to a team member.
  ///
  /// [email] — the recipient's email address
  /// [inviterName] — the name of the person sending the invitation
  /// [projectName] — the project name to include in the email
  /// [inviteLink] — optional custom sign-in link (defaults to staging URL)
  ///
  /// Returns a success message if the email was sent.
  /// Throws an exception if the email fails to send.
  static Future<String> sendInvitation({
    required String email,
    String? inviterName,
    String? projectName,
    String? inviteLink,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('You must be signed in to send invitations.');
    }

    // Use the inviter's display name or email if not provided
    final inviter = inviterName ??
        user.displayName ??
        user.email ??
        'A team member';

    // Default invite link — takes the recipient to the sign-in page
    final link = inviteLink ?? 'https://staging.nduproject.com/#/sign-in';

    try {
      // Call the Callable Cloud Function via the Firebase SDK.
      // This handles CORS, auth tokens, and data serialization automatically.
      final callable = FirebaseFunctions.instance.httpsCallable(
        'sendTeamInvitation',
        options: HttpsCallableOptions(timeout: const Duration(seconds: 30)),
      );

      final result = await callable.call<Map<String, dynamic>>({
        'email': email,
        'inviterName': inviter,
        'projectName': projectName ?? 'NDU Project',
        'inviteLink': link,
      });

      final data = result.data;
      if (data['success'] == true) {
        debugPrint('[TeamInvitationService] Invitation accepted for $email (messageId: ${data['messageId']})');
        return data['message'] as String? ?? 'Invitation accepted for delivery.';
      } else {
        throw Exception(data['message'] as String? ?? 'Failed to send invitation.');
      }
    } on FirebaseFunctionsException catch (e) {
      debugPrint('[TeamInvitationService] Firebase error: ${e.code} — ${e.message}');
      // Propagate the real error so callers can display it to the user
      throw Exception(_friendlyFirebaseError(e));
    } catch (e) {
      debugPrint('[TeamInvitationService] Error: $e');
      // Re-throw so the caller knows the email was NOT sent
      throw Exception('Failed to send invitation: $e');
    }
  }

  /// Send invitations to multiple email addresses at once.
  /// Returns a map of email → success/failure for each.
  static Future<Map<String, bool>> sendBatchInvitations({
    required List<String> emails,
    String? inviterName,
    String? projectName,
  }) async {
    final results = <String, bool>{};
    for (final email in emails) {
      try {
        await sendInvitation(
          email: email,
          inviterName: inviterName,
          projectName: projectName,
        );
        results[email] = true;
      } catch (e) {
        debugPrint('[TeamInvitationService] Batch: failed for $email: $e');
        results[email] = false;
      }
    }
    return results;
  }

  /// Returns a human-readable error message for Firebase Functions errors.
  static String _friendlyFirebaseError(FirebaseFunctionsException e) {
    switch (e.code) {
      case 'unauthenticated':
        return 'You must be signed in to send invitations.';
      case 'failed-precondition':
        if (e.message?.contains('not configured') == true) {
          return 'Email service is not configured. Please contact your administrator.';
        }
        return 'Invitation could not be sent: ${e.message ?? 'Service not ready'}.';
      case 'resource-exhausted':
        return 'Too many invitations sent. Please wait before trying again.';
      case 'invalid-argument':
        return e.message ?? 'Invalid email address.';
      case 'internal':
        return 'Email delivery failed on the server. Please try again later.';
      default:
        return e.message ?? 'Failed to send invitation (error: ${e.code}).';
    }
  }

  /// Get all invitations sent by the current user.
  static Stream<QuerySnapshot<Map<String, dynamic>>> streamUserInvitations() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Stream.empty();
    }
    return FirebaseFirestore.instance
        .collection('teamInvitations')
        .where('inviterUid', isEqualTo: user.uid)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }
}
