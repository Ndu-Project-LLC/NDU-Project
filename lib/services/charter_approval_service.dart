// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// CharterApprovalService
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// Resolves who should approve the Project Charter and provides a
// best-effort email-notification path.
//
// Resolution rules (per user spec, Task 3):
//   1. If the charter has a named sponsor (`charterProjectSponsorName`) AND
//      that name maps to a registered user (matched by email or display
//      name), that user is the approver.
//   2. Else if the charter has a named project manager
//      (`charterProjectManagerName`) AND that name maps to a registered
//      user, that user is the approver.
//   3. Else (the named approver is NOT a registered user of the site),
//      fall back to the highest-role user on the site: the first admin
//      (isAdmin == true) found in `UserService.watchAllUsers()`. If no
//      admin exists, fall back to the first active user. This person is
//      identified as the sponsor.
//
// Email path:
//   - Primary: writes a document to Firestore `charter_approval_emails`
//     collection so a backend Cloud Function / email worker can pick it
//     up and send a real email.
//   - Fallback: returns a `mailto:` URI with a pre-filled subject and
//     body so the user's email client can handle it client-side. This
//     works on Flutter web and mobile without any backend dependency.
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:ndu_project/models/project_data_model.dart';
import 'package:ndu_project/models/user_model.dart';
import 'package:ndu_project/services/team_invitation_service.dart';

/// The resolved charter approver.
class ResolvedApprover {
  /// Display name (e.g. "Jane Doe" or "Pending Assignment").
  final String name;

  /// Email to send the approval request to. May be empty if the approver
  /// is a fallback admin whose email is not exposed.
  final String email;

  /// Role label for display ("Project Sponsor", "Project Owner",
  /// "Site Administrator (fallback)", or "Active User (fallback)").
  final String role;

  /// True if this approver maps to a registered user in `users` collection.
  final bool isRegisteredUser;

  /// True if the approver was resolved via the fallback path (i.e. the
  /// named sponsor/manager is NOT a registered site user).
  final bool isFallback;

  /// The UID of the registered user, if `isRegisteredUser` is true.
  final String? uid;

  const ResolvedApprover({
    required this.name,
    required this.email,
    required this.role,
    required this.isRegisteredUser,
    required this.isFallback,
    this.uid,
  });

  bool get hasEmail => email.trim().isNotEmpty;

  static const empty = ResolvedApprover(
    name: 'Pending Assignment',
    email: '',
    role: 'Sponsor',
    isRegisteredUser: false,
    isFallback: false,
  );
}

/// Result of an email-send attempt.
enum CharterEmailSendResult {
  /// Email was queued to Firestore successfully.
  queued,
  /// Mailto URI was generated for client-side send.
  mailtoGenerated,
  /// No approver email available — nothing was sent.
  noApproverEmail,
  /// Firestore write failed.
  failed,
}

class CharterApprovalService {
  static final _firestore = FirebaseFirestore.instance;
  static const _emailsCollection = 'charter_approval_emails';

  /// Resolve the charter approver for the given project data, using the
  /// list of registered site users to determine whether the named
  /// sponsor/manager is a real user.
  ///
  /// [allUsers] should come from `UserService.watchAllUsers()` (or a
  /// one-shot `get()` on the same collection).
  ///
  /// Resolution order (per user spec):
  ///   1. Named sponsor that maps to a registered user (matched by
  ///      email, display name, OR the currently signed-in user if
  ///      their display name / email matches the named sponsor).
  ///   2. Named project manager that maps to a registered user (same
  ///      matching rules).
  ///   3. The currently signed-in user, if their display name matches
  ///      the named sponsor or PM (covers the case where the user just
  ///      added themselves as PM but the users collection hasn't
  ///      refreshed yet).
  ///   4. Fallback: highest-role user on the site — first admin,
  ///      then first active user. This is the "suggest a sponsor
  ///      based on the highest role-based authority" behaviour.
  static ResolvedApprover resolveApprover({
    required ProjectDataModel data,
    required List<UserModel> allUsers,
  }) {
    final sponsorName = data.charterProjectSponsorName.trim();
    final managerName = data.charterProjectManagerName.trim();
    final sponsorEmail = data.charterEmail.trim();

    // Currently signed-in user — used to recognise the case where the
    // user just added themselves as PM/sponsor but the users
    // collection hasn't refreshed yet.
    final currentUser = FirebaseAuth.instance.currentUser;
    final currentUserName =
        (currentUser?.displayName ?? '').trim();
    final currentUserEmail = (currentUser?.email ?? '').trim();

    // 1. Try to match the named sponsor against registered users,
    //    including the currently signed-in user.
    if (sponsorName.isNotEmpty) {
      final match = _findUserByName(allUsers, sponsorName) ??
          _matchCurrentUser(sponsorName, currentUserName, currentUserEmail);
      if (match != null) {
        return ResolvedApprover(
          name: match.displayName.isNotEmpty ? match.displayName : match.email,
          email: match.email,
          role: 'Project Sponsor',
          isRegisteredUser: true,
          isFallback: false,
          uid: match.uid,
        );
      }
      // Named sponsor exists but is NOT a registered user. If we have
      // an email on file (data.charterEmail), use it for the email send
      // but still flag that the site-admin fallback owns the approval
      // workflow.
      if (sponsorEmail.isNotEmpty) {
        return ResolvedApprover(
          name: sponsorName,
          email: sponsorEmail,
          role: 'Project Sponsor (external)',
          isRegisteredUser: false,
          isFallback: false,
        );
      }
    }

    // 2. Try to match the named project manager, including the
    //    currently signed-in user.
    if (managerName.isNotEmpty) {
      final match = _findUserByName(allUsers, managerName) ??
          _matchCurrentUser(managerName, currentUserName, currentUserEmail);
      if (match != null) {
        return ResolvedApprover(
          name: match.displayName.isNotEmpty ? match.displayName : match.email,
          email: match.email,
          role: 'Project Owner',
          isRegisteredUser: true,
          isFallback: false,
          uid: match.uid,
        );
      }
    }

    // 3. Fallback: highest-role user on the site.
    // Prefer admins, then any active user. This is the "suggest a
    // sponsor based on the highest role-based authority" behaviour.
    final admins = allUsers.where((u) => u.isAdmin && u.isActive).toList();
    if (admins.isNotEmpty) {
      final admin = admins.first;
      return ResolvedApprover(
        name: admin.displayName.isNotEmpty ? admin.displayName : admin.email,
        email: admin.email,
        role: 'Site Administrator (sponsor fallback)',
        isRegisteredUser: true,
        isFallback: true,
        uid: admin.uid,
      );
    }

    final activeUsers = allUsers.where((u) => u.isActive).toList();
    if (activeUsers.isNotEmpty) {
      final user = activeUsers.first;
      return ResolvedApprover(
        name: user.displayName.isNotEmpty ? user.displayName : user.email,
        email: user.email,
        role: 'Active User (sponsor fallback)',
        isRegisteredUser: true,
        isFallback: true,
        uid: user.uid,
      );
    }

    // 4. Last resort: if the currently signed-in user is available,
    //    use them as the sponsor fallback. This covers the case where
    //    the users collection is empty or unreachable but the user is
    //    clearly signed in.
    if (currentUserName.isNotEmpty || currentUserEmail.isNotEmpty) {
      return ResolvedApprover(
        name: currentUserName.isNotEmpty ? currentUserName : currentUserEmail,
        email: currentUserEmail,
        role: 'Project Owner (signed-in user)',
        isRegisteredUser: true,
        isFallback: true,
        uid: currentUser?.uid,
      );
    }

    // 5. No users at all — return empty.
    return ResolvedApprover.empty;
  }

  /// Match the named sponsor/PM against the currently signed-in user.
  /// Returns a synthetic [UserModel] if the name or email matches, so
  /// the caller can treat it as a registered user. This covers the
  /// case where the user just added themselves as PM but the users
  /// collection hasn't refreshed yet (the bug where the bottom bar
  /// shows "Pending Assignment (Project Owner)" right after the user
  /// adds themselves and approves the charter).
  static UserModel? _matchCurrentUser(
      String name, String currentUserName, String currentUserEmail) {
    final needle = name.toLowerCase().trim();
    if (needle.isEmpty) return null;
    if (currentUserName.toLowerCase().trim() == needle ||
        currentUserEmail.toLowerCase().trim() == needle ||
        currentUserEmail.toLowerCase().split('@').first == needle) {
      return UserModel(
        uid: FirebaseAuth.instance.currentUser?.uid ?? '',
        email: currentUserEmail,
        displayName: currentUserName,
        isActive: true,
        isAdmin: false,
        createdAt: DateTime.now(),
      );
    }
    return null;
  }

  /// Suggest a sponsor based on the highest role-based authority
  /// currently on the site. Returns the resolved approver (admin
  /// preferred, then active user, then signed-in user).
  ///
  /// Use this when the user hasn't named a sponsor yet but needs one
  /// to approve the charter. The caller can also call
  /// [inviteExternalSponsor] to invite a sponsor who isn't already a
  /// site user.
  static ResolvedApprover suggestSponsor({
    required List<UserModel> allUsers,
  }) {
    final admins = allUsers.where((u) => u.isAdmin && u.isActive).toList();
    if (admins.isNotEmpty) {
      final admin = admins.first;
      return ResolvedApprover(
        name: admin.displayName.isNotEmpty ? admin.displayName : admin.email,
        email: admin.email,
        role: 'Site Administrator (suggested sponsor)',
        isRegisteredUser: true,
        isFallback: true,
        uid: admin.uid,
      );
    }
    final activeUsers = allUsers.where((u) => u.isActive).toList();
    if (activeUsers.isNotEmpty) {
      final user = activeUsers.first;
      return ResolvedApprover(
        name: user.displayName.isNotEmpty ? user.displayName : user.email,
        email: user.email,
        role: 'Active User (suggested sponsor)',
        isRegisteredUser: true,
        isFallback: true,
        uid: user.uid,
      );
    }
    // Signed-in user fallback.
    final currentUser = FirebaseAuth.instance.currentUser;
    final name = (currentUser?.displayName ?? '').trim();
    final email = (currentUser?.email ?? '').trim();
    if (name.isNotEmpty || email.isNotEmpty) {
      return ResolvedApprover(
        name: name.isNotEmpty ? name : email,
        email: email,
        role: 'Project Owner (signed-in user)',
        isRegisteredUser: true,
        isFallback: true,
        uid: currentUser?.uid,
      );
    }
    return ResolvedApprover.empty;
  }

  /// Invite an external sponsor to join the project. Sends an
  /// invitation email via [TeamInvitationService] so the sponsor can
  /// sign in and approve the charter.
  ///
  /// Returns the result message from the team invitation service.
  /// Throws if the email fails to send.
  static Future<String> inviteExternalSponsor({
    required String email,
    String? sponsorName,
    String? projectName,
    String? inviteLink,
  }) async {
    return await TeamInvitationService.sendInvitation(
      email: email,
      inviterName: sponsorName,
      projectName: projectName ?? 'NDU Project',
      inviteLink: inviteLink,
    );
  }

  /// Try to find a registered user by display name (case-insensitive,
  /// trimmed) or by email prefix (e.g. "jane.doe" matches
  /// "jane.doe@example.com").
  static UserModel? _findUserByName(
      List<UserModel> users, String name) {
    final needle = name.toLowerCase().trim();
    if (needle.isEmpty) return null;

    // Exact display-name match.
    for (final u in users) {
      if (u.displayName.toLowerCase().trim() == needle) return u;
    }
    // Exact email match.
    for (final u in users) {
      if (u.email.toLowerCase().trim() == needle) return u;
    }
    // Email-prefix match ("jane.doe" → "jane.doe@example.com").
    for (final u in users) {
      final emailLocalPart = u.email.toLowerCase().split('@').first;
      if (emailLocalPart == needle) return u;
    }
    // Substring match (display name contains the needle, or vice versa).
    for (final u in users) {
      final dn = u.displayName.toLowerCase();
      if (dn.contains(needle) || needle.contains(dn)) {
        if (dn.isNotEmpty) return u;
      }
    }
    return null;
  }

  /// Send (or queue) an approval-request email to the resolved approver.
  ///
  /// Returns a [CharterEmailSendResult] indicating what happened. If
  /// [mailtoUri] is non-null in the returned record, the caller should
  /// launch it (e.g. via `url_launcher`) to open the user's email
  /// client with a pre-filled message.
  static Future<({
    CharterEmailSendResult result,
    String? mailtoUri,
    String? error,
  })> sendApprovalRequestEmail({
    required ProjectDataModel data,
    required ResolvedApprover approver,
    String? deepLinkUrl,
  }) async {
    if (!approver.hasEmail) {
      return (
        result: CharterEmailSendResult.noApproverEmail,
        mailtoUri: null,
        error: 'No email address on file for the resolved approver.',
      );
    }

    final projectName = data.projectName ?? 'Untitled Project';
    final subject = 'Action Required: Approve Project Charter — $projectName';
    final body = _buildEmailBody(
      projectName: projectName,
      approver: approver,
      data: data,
      deepLinkUrl: deepLinkUrl,
    );

    // 1. Try to queue to Firestore.
    try {
      await _firestore.collection(_emailsCollection).add({
        'toEmail': approver.email,
        'toName': approver.name,
        'toRole': approver.role,
        'subject': subject,
        'body': body,
        'projectId': data.projectId ?? '',
        'projectName': projectName,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'isFallbackApprover': approver.isFallback,
      });
      return (
        result: CharterEmailSendResult.queued,
        mailtoUri: null,
        error: null,
      );
    } catch (e) {
      debugPrint('CharterApprovalService: Firestore queue failed: $e');
      // Fall through to mailto.
    }

    // 2. Fallback: build a mailto: URI.
    final mailto = Uri(
      scheme: 'mailto',
      path: approver.email,
      query: {
        'subject': subject,
        'body': body,
      }.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&'),
    ).toString();

    return (
      result: CharterEmailSendResult.mailtoGenerated,
      mailtoUri: mailto,
      error: null,
    );
  }

  static String _buildEmailBody({
    required String projectName,
    required ResolvedApprover approver,
    required ProjectDataModel data,
    String? deepLinkUrl,
  }) {
    final buf = StringBuffer();
    buf.writeln('Hello ${approver.name},');
    buf.writeln();
    buf.writeln(
        'A Project Charter is ready for your review and approval on the NDU Project platform.');
    buf.writeln();
    buf.writeln('Project: $projectName');
    if (data.businessCase.trim().isNotEmpty) {
      buf.writeln();
      buf.writeln('Business case summary:');
      buf.writeln(data.businessCase.trim());
    }
    buf.writeln();
    buf.writeln('Your role: ${approver.role}');
    if (approver.isFallback) {
      buf.writeln(
          'Note: You have been identified as the sponsor because the originally named sponsor/owner is not a registered user of the site. As the highest-role user, you are authorized to approve this charter on their behalf.');
    }
    buf.writeln();
    buf.writeln(
        'Please review the Front End Execution Plan and confirm that the applicable subject matter experts have reviewed all relevant sections before approving.');
    buf.writeln();
    if (deepLinkUrl != null && deepLinkUrl.isNotEmpty) {
      buf.writeln('Open the charter: $deepLinkUrl');
      buf.writeln();
    }
    buf.writeln('Thank you,');
    buf.writeln('NDU Project Platform');
    return buf.toString();
  }

  /// Carry stakeholders from the preferred solution's
  /// `coreStakeholdersData` into the planning-phase stakeholder register
  /// (`data.stakeholderEntries`). Idempotent: stakeholders already
  /// present (matched by name, case-insensitive) are not duplicated.
  ///
  /// Returns the merged list. Callers should write this back via
  /// `provider.updateField((d) => d.copyWith(stakeholderEntries: ...))`.
  static List<StakeholderEntry> carryStakeholdersFromPreferredSolution(
      ProjectDataModel data) {
    final existing = List<StakeholderEntry>.from(data.stakeholderEntries);
    final existingNames = existing
        .map((e) => e.name.toLowerCase().trim())
        .where((n) => n.isNotEmpty)
        .toSet();

    final preferredId = data.preferredSolutionId;
    final preferredSolution = preferredId == null
        ? null
        : data.potentialSolutions
            .where((s) => s.id == preferredId)
            .cast<PotentialSolution?>()
            .firstWhere((s) => s != null, orElse: () => null);

    final rows = data.coreStakeholdersData?.solutionStakeholderData ?? [];
    if (rows.isEmpty) return existing;

    // Match by title (case-insensitive) against the preferred solution.
    SolutionStakeholderData? matched;
    if (preferredSolution != null) {
      final titleNeedle = preferredSolution.title.trim().toLowerCase();
      try {
        matched = rows.where(
          (r) => r.solutionTitle.trim().toLowerCase() == titleNeedle,
        ).firstOrNull;
      } catch (_) {
        matched = null;
      }
    }
    // Fallback: first row.
    matched ??= rows.first;

    final now = DateTime.now();
    final newEntries = <StakeholderEntry>[];

    for (final name in _splitStakeholders(matched.internalStakeholders)) {
      final key = name.toLowerCase();
      if (existingNames.contains(key)) continue;
      existingNames.add(key);
      newEntries.add(StakeholderEntry(
        id: 'pref-int-${now.microsecondsSinceEpoch}-${newEntries.length}',
        name: name,
        organization: '',
        role: 'Internal Stakeholder',
        influence: 'Medium',
        interest: 'High',
        channel: '',
        contactInfo: '',
        owner: '',
        notes: 'Carried from preferred solution: ${matched.solutionTitle}',
        createdAt: now,
        updatedAt: now,
      ));
    }
    for (final name in _splitStakeholders(matched.externalStakeholders)) {
      final key = name.toLowerCase();
      if (existingNames.contains(key)) continue;
      existingNames.add(key);
      newEntries.add(StakeholderEntry(
        id: 'pref-ext-${now.microsecondsSinceEpoch}-${newEntries.length}',
        name: name,
        organization: '',
        role: 'External Stakeholder',
        influence: 'Medium',
        interest: 'High',
        channel: '',
        contactInfo: '',
        owner: '',
        notes: 'Carried from preferred solution: ${matched.solutionTitle}',
        createdAt: now,
        updatedAt: now,
      ));
    }

    return [...existing, ...newEntries];
  }

  /// Split a stakeholder blob (newline / comma / semicolon separated)
  /// into trimmed, non-empty names.
  static List<String> _splitStakeholders(String blob) {
    return blob
        .split(RegExp(r'[\n,;]'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }
}
