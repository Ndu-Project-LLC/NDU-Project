import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Standard role options presented to the user during profile onboarding.
///
/// Kept for backwards compatibility with existing Firestore documents. New
/// onboarding flows use a free-form [ProfileOnboardingAnswers.position]
/// string instead, but the enum is still exported so legacy code can read
/// old documents.
enum UserRole {
  projectManager('Project Manager', 'PM, delivery lead, program owner'),
  engineer('Engineer', 'Software, civil, mechanical, electrical'),
  designer('Designer / UX', 'Product, UI/UX, service designer'),
  executive('Executive / Sponsor', 'Director, VP, C-level, sponsor'),
  consultant('Consultant / Advisor', 'External advisor, SME'),
  analyst('Analyst', 'Business, data, systems analyst'),
  other('Other', 'Anything else');

  const UserRole(this.label, this.description);
  final String label;
  final String description;

  String get firestoreValue => name;
}

/// Project methodology the user prefers to start with.
enum PreferredMethodology {
  agile('Agile', 'Sprints, iterations, backlogs'),
  waterfall('Waterfall', 'Sequential phases, gated'),
  hybrid('Hybrid', 'Mix of both — phased with iterative delivery'),
  notSure('Not sure yet', 'Help me decide based on my project');

  const PreferredMethodology(this.label, this.description);
  final String label;
  final String description;

  String get firestoreValue => name;
}

/// Project type the user is most likely to deliver with NDU.
enum PrimaryProjectType {
  software('Software / IT', 'Apps, platforms, SaaS, integrations'),
  construction('Construction', 'Build, civil, infrastructure'),
  hardware('Hardware / Product', 'Devices, manufacturing, IoT'),
  services('Services / Ops', 'Service delivery, operations, rollout'),
  hybrid('Hybrid / Cross-domain', 'More than one of the above');

  const PrimaryProjectType(this.label, this.description);
  final String label;
  final String description;

  String get firestoreValue => name;
}

/// Captured answers from the new profile-onboarding flow.
///
/// Persisted to Firestore at `users/{uid}/profile/onboarding`. Fields are
/// nullable because every step is skippable — only [completedAt] and
/// [skipped] are guaranteed once the flow finishes.
///
/// The new flow (2026 redesign) collects:
///   - position / positionOther (was: role enum)
///   - isDecisionMaker
///   - country / countryOther
///   - currency / currencyOther
///   - currentTools / currentToolsOther (multi-select)
///   - organizationOverview (long text)
///   - invitedEmails (team invitations — auto-link sent on submit)
///   - maxTeamSizePerProject (per-tier cap)
///   - tierAtSignup (which tier the user is on at the time of onboarding)
///
/// Legacy fields (role, experience, industry, teamSize, primaryUseCase,
/// projectType, methodology) are kept for backwards-compat with existing
/// Firestore documents but are no longer collected by the new UI.
class ProfileOnboardingAnswers {
  // ── New fields (2026 redesign) ──────────────────────────────────────────
  final String? position;
  final String? positionOther;
  final bool? isDecisionMaker;
  final String? country;
  final String? countryOther;
  final String? currency;
  final String? currencyOther;
  final List<String> currentTools;
  final String? currentToolsOther;
  final String? organizationOverview;
  final List<String> invitedEmails;
  final int? maxTeamSizePerProject;
  final String? tierAtSignup;

  // ── Legacy fields (kept for backwards compat) ──────────────────────────
  final UserRole? role;
  final String? experience;
  final String? industry;
  final int? teamSize;
  final String? primaryUseCase;
  final PrimaryProjectType? projectType;
  final PreferredMethodology? methodology;

  // ── Meta ───────────────────────────────────────────────────────────────
  final DateTime? completedAt;
  final bool skipped;

  const ProfileOnboardingAnswers({
    // New
    this.position,
    this.positionOther,
    this.isDecisionMaker,
    this.country,
    this.countryOther,
    this.currency,
    this.currencyOther,
    this.currentTools = const [],
    this.currentToolsOther,
    this.organizationOverview,
    this.invitedEmails = const [],
    this.maxTeamSizePerProject,
    this.tierAtSignup,
    // Legacy
    this.role,
    this.experience,
    this.industry,
    this.teamSize,
    this.primaryUseCase,
    this.projectType,
    this.methodology,
    // Meta
    this.completedAt,
    this.skipped = false,
  });

  /// Whether the new flow was completed with at least the core identity
  /// questions answered. Used by redirect logic.
  bool get isComplete =>
      !skipped &&
      (position != null || positionOther != null) &&
      isDecisionMaker != null &&
      (country != null || countryOther != null) &&
      (currency != null || currencyOther != null);

  /// Friendly display string for the position (uses custom text if "Other"
  /// was selected).
  String get positionDisplay {
    if (position == 'Other' && (positionOther?.isNotEmpty ?? false)) {
      return positionOther!.trim();
    }
    return position ?? '';
  }

  /// Friendly display string for the country.
  String get countryDisplay {
    if (country == 'Other' && (countryOther?.isNotEmpty ?? false)) {
      return countryOther!.trim();
    }
    return country ?? '';
  }

  /// Friendly display string for the currency.
  String get currencyDisplay {
    if (currency == 'Other' && (currencyOther?.isNotEmpty ?? false)) {
      return currencyOther!.trim();
    }
    return currency ?? '';
  }

  /// Combined list of selected tools plus any "Other" custom entry.
  List<String> get currentToolsDisplay {
    final out = <String>[...currentTools];
    final other = currentToolsOther?.trim();
    if (currentTools.contains('Other') && other != null && other.isNotEmpty) {
      out.remove('Other');
      out.add('Other: $other');
    }
    return out;
  }

  Map<String, dynamic> toFirestore() => {
        // New fields
        'position': position,
        'positionOther': positionOther,
        'isDecisionMaker': isDecisionMaker,
        'country': country,
        'countryOther': countryOther,
        'currency': currency,
        'currencyOther': currencyOther,
        'currentTools': currentTools,
        'currentToolsOther': currentToolsOther,
        'organizationOverview': organizationOverview,
        'invitedEmails': invitedEmails,
        'maxTeamSizePerProject': maxTeamSizePerProject,
        'tierAtSignup': tierAtSignup,
        // Legacy fields (written for backwards compat with old readers)
        'role': role?.firestoreValue,
        'experience': experience,
        'industry': industry,
        'teamSize': teamSize,
        'primaryUseCase': primaryUseCase,
        'projectType': projectType?.firestoreValue,
        'methodology': methodology?.firestoreValue,
        // Meta
        'completedAt': completedAt != null
            ? Timestamp.fromDate(completedAt!)
            : null,
        'skipped': skipped,
        'updatedAt': Timestamp.now(),
      };

  factory ProfileOnboardingAnswers.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return ProfileOnboardingAnswers(
      // New
      position: data['position'] as String?,
      positionOther: data['positionOther'] as String?,
      isDecisionMaker: data['isDecisionMaker'] as bool?,
      country: data['country'] as String?,
      countryOther: data['countryOther'] as String?,
      currency: data['currency'] as String?,
      currencyOther: data['currencyOther'] as String?,
      currentTools: (data['currentTools'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      currentToolsOther: data['currentToolsOther'] as String?,
      organizationOverview: data['organizationOverview'] as String?,
      invitedEmails: (data['invitedEmails'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      maxTeamSizePerProject: (data['maxTeamSizePerProject'] as num?)?.toInt(),
      tierAtSignup: data['tierAtSignup'] as String?,
      // Legacy
      role: _parseUserRole(data['role'] as String?),
      experience: data['experience'] as String?,
      industry: data['industry'] as String?,
      teamSize: (data['teamSize'] as num?)?.toInt(),
      primaryUseCase: data['primaryUseCase'] as String?,
      projectType: _parseProjectType(data['projectType'] as String?),
      methodology: _parseMethodology(data['methodology'] as String?),
      // Meta
      completedAt: (data['completedAt'] as Timestamp?)?.toDate(),
      skipped: (data['skipped'] as bool?) ?? false,
    );
  }

  static UserRole? _parseUserRole(String? v) {
    if (v == null) return null;
    try {
      return UserRole.values.byName(v);
    } catch (_) {
      return null;
    }
  }

  static PrimaryProjectType? _parseProjectType(String? v) {
    if (v == null) return null;
    try {
      return PrimaryProjectType.values.byName(v);
    } catch (_) {
      return null;
    }
  }

  static PreferredMethodology? _parseMethodology(String? v) {
    if (v == null) return null;
    try {
      return PreferredMethodology.values.byName(v);
    } catch (_) {
      return null;
    }
  }

  ProfileOnboardingAnswers copyWith({
    String? position,
    String? positionOther,
    bool? isDecisionMaker,
    String? country,
    String? countryOther,
    String? currency,
    String? currencyOther,
    List<String>? currentTools,
    String? currentToolsOther,
    String? organizationOverview,
    List<String>? invitedEmails,
    int? maxTeamSizePerProject,
    String? tierAtSignup,
    UserRole? role,
    String? experience,
    String? industry,
    int? teamSize,
    String? primaryUseCase,
    PrimaryProjectType? projectType,
    PreferredMethodology? methodology,
    DateTime? completedAt,
    bool? skipped,
    bool clearPositionOther = false,
    bool clearCountryOther = false,
    bool clearCurrencyOther = false,
    bool clearToolsOther = false,
  }) {
    return ProfileOnboardingAnswers(
      position: position ?? this.position,
      positionOther:
          clearPositionOther ? null : (positionOther ?? this.positionOther),
      isDecisionMaker: isDecisionMaker ?? this.isDecisionMaker,
      country: country ?? this.country,
      countryOther:
          clearCountryOther ? null : (countryOther ?? this.countryOther),
      currency: currency ?? this.currency,
      currencyOther:
          clearCurrencyOther ? null : (currencyOther ?? this.currencyOther),
      currentTools: currentTools ?? this.currentTools,
      currentToolsOther:
          clearToolsOther ? null : (currentToolsOther ?? this.currentToolsOther),
      organizationOverview: organizationOverview ?? this.organizationOverview,
      invitedEmails: invitedEmails ?? this.invitedEmails,
      maxTeamSizePerProject:
          maxTeamSizePerProject ?? this.maxTeamSizePerProject,
      tierAtSignup: tierAtSignup ?? this.tierAtSignup,
      role: role ?? this.role,
      experience: experience ?? this.experience,
      industry: industry ?? this.industry,
      teamSize: teamSize ?? this.teamSize,
      primaryUseCase: primaryUseCase ?? this.primaryUseCase,
      projectType: projectType ?? this.projectType,
      methodology: methodology ?? this.methodology,
      completedAt: completedAt ?? this.completedAt,
      skipped: skipped ?? this.skipped,
    );
  }
}

/// Service that persists profile-onboarding answers to Firestore and exposes
/// a stream of the current user's answers for redirect logic.
///
/// Document path: `users/{uid}/profile/onboarding`
class ProfileOnboardingService {
  ProfileOnboardingService._();

  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Returns the current user's profile-onboarding document reference, or
  /// null if no user is signed in.
  static DocumentReference<Map<String, dynamic>>? _docRef() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('profile')
        .doc('onboarding');
  }

  /// Saves the given answers to Firestore. Merges with existing data so
  /// partial saves (one step at a time) don't wipe previously-answered
  /// fields.
  static Future<void> save(ProfileOnboardingAnswers answers) async {
    final ref = _docRef();
    if (ref == null) {
      debugPrint(
          '[ProfileOnboardingService] Cannot save — no authenticated user.');
      return;
    }
    await ref.set(answers.toFirestore(), SetOptions(merge: true));
  }

  /// Marks the onboarding flow as completed (with whatever answers were
  /// collected). Called when the user finishes the last step or explicitly
  /// skips the entire flow.
  static Future<void> markComplete(ProfileOnboardingAnswers answers) async {
    final complete = answers.copyWith(
      completedAt: DateTime.now(),
      skipped: answers.skipped,
    );
    await save(complete);
  }

  /// Reads the current user's profile-onboarding answers, or null if there
  /// is no document yet (first-time user).
  static Future<ProfileOnboardingAnswers?> load() async {
    final ref = _docRef();
    if (ref == null) return null;
    try {
      final snap = await ref.get();
      if (!snap.exists) return null;
      return ProfileOnboardingAnswers.fromFirestore(snap);
    } catch (e) {
      debugPrint('[ProfileOnboardingService] load error: $e');
      return null;
    }
  }

  /// Returns true if the user has completed profile onboarding (either by
  /// answering all questions or by explicitly skipping). Returns false for
  /// first-time users with no document.
  static Future<bool> hasCompleted() async {
    final answers = await load();
    if (answers == null) return false;
    return answers.completedAt != null;
  }
}
