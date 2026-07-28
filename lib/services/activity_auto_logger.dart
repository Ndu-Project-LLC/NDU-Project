import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Lightweight auto-logger that records page visits and key project events
/// to the project's activity log at `projects/{projectId}/activityLog`.
///
/// Designed to be called from:
/// 1. The router's redirect callback — logs every navigation to a project
///    screen (so users can see "who visited what, when" without each screen
///    needing its own logging code).
/// 2. The `ProjectDataProvider.saveToFirebase` checkpoint save — logs every
///    data save with its checkpoint name.
/// 3. Individual screens — for high-signal events like status changes,
///    approvals, deliverable sign-offs.
///
/// All writes are fire-and-forget (failures are logged but never block the
/// UI). Writes are throttled per-(projectId, page, action) tuple so rapid
/// navigation doesn't spam the log — the same page visited twice within
/// 30 seconds only records one entry.
class ActivityAutoLogger {
  ActivityAutoLogger._();

  static final ActivityAutoLogger instance = ActivityAutoLogger._();

  /// Firestore collection for a project's activity log.
  static CollectionReference<Map<String, dynamic>> _coll(String projectId) =>
      FirebaseFirestore.instance
          .collection('projects')
          .doc(projectId)
          .collection('activityLog');

  /// Throttle window — same (projectId, page, action) within this many
  /// seconds is suppressed.
  static const Duration _throttleWindow = Duration(seconds: 30);

  /// In-memory throttle map: key = "$projectId|$page|$action", value =
  /// last-recorded timestamp. Cleared on app restart (acceptable — the
  /// throttle is only to prevent live-tap spam, not for correctness).
  final Map<String, DateTime> _lastRecorded = {};

  /// Returns true if a record for this tuple was made within the throttle
  /// window, so the caller can skip.
  bool _isThrottled(String key) {
    final last = _lastRecorded[key];
    if (last == null) return false;
    return DateTime.now().difference(last) < _throttleWindow;
  }

  /// Record a page-visit activity. Called from the router on every
  /// navigation to a project screen.
  ///
  /// [projectId] — the active project ID. Empty/null skips logging.
  /// [route] — the route path (e.g. '/cost-estimate').
  /// [pageTitle] — human-readable page name (e.g. 'Cost Estimate').
  /// [phase] — the phase this page belongs to (Design / Execution / etc.).
  Future<void> logPageVisit({
    required String projectId,
    required String route,
    required String pageTitle,
    required String phase,
  }) async {
    final normalizedProjectId = projectId.trim();
    if (normalizedProjectId.isEmpty) return;

    final key = '$normalizedProjectId|$route|page_visit';
    if (_isThrottled(key)) return;
    _lastRecorded[key] = DateTime.now();

    await _write(
      projectId: normalizedProjectId,
      phase: phase,
      page: pageTitle,
      action: 'Visited page',
      details: {'route': route, 'auto': true},
    );
  }

  /// Record a data-save activity. Called from `ProjectDataProvider` after
  /// every successful Firestore checkpoint save.
  Future<void> logDataSave({
    required String projectId,
    required String checkpoint,
    required String page,
    required String phase,
    Map<String, dynamic>? extraDetails,
  }) async {
    final normalizedProjectId = projectId.trim();
    if (normalizedProjectId.isEmpty) return;

    // Don't throttle saves — every save is meaningful.
    await _write(
      projectId: normalizedProjectId,
      phase: phase,
      page: page,
      action: 'Saved ${checkpoint.replaceAll('_', ' ')}',
      details: {
        'checkpoint': checkpoint,
        'auto': true,
        if (extraDetails != null) ...extraDetails,
      },
    );
  }

  /// Record a status-change activity (e.g. design deliverable approved,
  /// execution task marked complete). High-signal — never throttled.
  Future<void> logStatusChange({
    required String projectId,
    required String phase,
    required String page,
    required String itemName,
    required String fromStatus,
    required String toStatus,
    String? itemUrl,
  }) async {
    final normalizedProjectId = projectId.trim();
    if (normalizedProjectId.isEmpty) return;

    await _write(
      projectId: normalizedProjectId,
      phase: phase,
      page: page,
      action: 'Status changed: $itemName',
      details: {
        'itemName': itemName,
        'from': fromStatus,
        'to': toStatus,
        if (itemUrl != null) 'itemUrl': itemUrl,
        'requiresFollowUp': true,
      },
    );
  }

  /// Record a milestone / approval activity (e.g. design phase approved,
  /// execution plan locked). High-signal — never throttled.
  Future<void> logMilestone({
    required String projectId,
    required String phase,
    required String page,
    required String milestone,
    String? approver,
    Map<String, dynamic>? extraDetails,
  }) async {
    final normalizedProjectId = projectId.trim();
    if (normalizedProjectId.isEmpty) return;

    await _write(
      projectId: normalizedProjectId,
      phase: phase,
      page: page,
      action: 'Milestone: $milestone',
      details: {
        'milestone': milestone,
        if (approver != null) 'approver': approver,
        'requiresFollowUp': true,
        if (extraDetails != null) ...extraDetails,
      },
    );
  }

  /// Low-level write helper. Captures the signed-in user, normalizes the
  /// details map, and writes to Firestore. Never throws — all errors are
  /// caught and logged via [debugPrint].
  Future<void> _write({
    required String projectId,
    required String phase,
    required String page,
    required String action,
    required Map<String, dynamic> details,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final normalizedDetails = <String, dynamic>{};
    details.forEach((k, v) {
      if (v == null) return;
      if (v is num || v is bool || v is String) {
        normalizedDetails[k] = v;
      } else if (v is DateTime) {
        normalizedDetails[k] = v.toIso8601String();
      } else {
        normalizedDetails[k] = v.toString();
      }
    });

    try {
      await _coll(projectId).add({
        'timestamp': FieldValue.serverTimestamp(),
        'userId': user.uid,
        'userName': (user.displayName ?? user.email ?? 'Unknown User').trim(),
        'userEmail': (user.email ?? '').trim(),
        'phase': phase.trim().isEmpty ? 'Unknown Phase' : phase.trim(),
        'page': page.trim().isEmpty ? 'Unknown Page' : page.trim(),
        'action': action.trim().isEmpty ? 'Updated data' : action.trim(),
        'details': normalizedDetails,
      });
    } catch (e, st) {
      debugPrint('[ActivityAutoLogger] write failed: $e\n$st');
    }
  }
}
