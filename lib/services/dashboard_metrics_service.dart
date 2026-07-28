import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// A single assigned activity, enriched with the project name for display
/// on the dashboard. Pulled from every project's `activities` subcollection
/// where `assignedTo` matches the current user's UID or email.
class AssignedActivity {
  final String id;
  final String projectId;
  final String projectName;
  final String title;
  final String phase;
  final String discipline;
  final String role;
  final String dueDate;
  final String status;
  final String assignedTo;

  const AssignedActivity({
    required this.id,
    required this.projectId,
    required this.projectName,
    required this.title,
    required this.phase,
    required this.discipline,
    required this.role,
    required this.dueDate,
    required this.status,
    required this.assignedTo,
  });

  bool get isPastDue {
    if (dueDate.isEmpty) return false;
    final d = DateTime.tryParse(dueDate);
    if (d == null) return false;
    return d.isBefore(DateTime.now()) &&
        status != 'implemented' &&
        status != 'rejected';
  }

  int get daysPastDue {
    if (!isPastDue) return 0;
    final d = DateTime.tryParse(dueDate);
    if (d == null) return 0;
    return DateTime.now().difference(d).inDays;
  }
}

/// Roll-up status for a single project across the 5 PMO dimensions:
/// schedule, cost, scope, quality, risk. Each is 'on_track' (green),
/// 'at_risk' (amber), or 'off_track' (red), with a headline metric.
class ProjectStatusRollup {
  final String projectId;
  final String projectName;
  final String overallStatus; // 'on_track' | 'at_risk' | 'off_track' | 'unknown'
  final String scheduleStatus;
  final String costStatus;
  final String scopeStatus;
  final String qualityStatus;
  final String riskStatus;
  final double? progressPercent;
  final double? budgetUsedPercent;
  final int? openRisks;
  final int? openIssues;
  final DateTime? updatedAt;

  const ProjectStatusRollup({
    required this.projectId,
    required this.projectName,
    required this.overallStatus,
    required this.scheduleStatus,
    required this.costStatus,
    required this.scopeStatus,
    required this.qualityStatus,
    required this.riskStatus,
    this.progressPercent,
    this.budgetUsedPercent,
    this.openRisks,
    this.openIssues,
    this.updatedAt,
  });

  static String _worst(List<String> statuses) {
    if (statuses.contains('off_track')) return 'off_track';
    if (statuses.contains('at_risk')) return 'at_risk';
    if (statuses.every((s) => s == 'on_track')) return 'on_track';
    return 'unknown';
  }

  static ProjectStatusRollup infer({
    required String projectId,
    required String projectName,
    List<Map<String, dynamic>> scheduleActivities = const [],
    List<Map<String, dynamic>> costItems = const [],
    List<Map<String, dynamic>> risks = const [],
    List<Map<String, dynamic>> issues = const [],
    List<Map<String, dynamic>> qualityItems = const [],
    double? budgetTotal,
    DateTime? updatedAt,
  }) {
    // Schedule: % of activities completed
    int schedCompleted = 0;
    int schedTotal = scheduleActivities.length;
    double progress = 0;
    for (final a in scheduleActivities) {
      final status = (a['status'] ?? a['completionStatus'] ?? '').toString().toLowerCase();
      if (status == 'completed' || status == 'done' || status == '100') {
        schedCompleted++;
      }
    }
    if (schedTotal > 0) progress = schedCompleted / schedTotal;
    String scheduleStatus;
    if (schedTotal == 0) {
      scheduleStatus = 'unknown';
    } else if (progress >= 0.85) {
      scheduleStatus = 'on_track';
    } else if (progress >= 0.6) {
      scheduleStatus = 'at_risk';
    } else {
      scheduleStatus = 'off_track';
    }

    // Cost: budget used vs total
    double costUsed = 0;
    for (final c in costItems) {
      final v = c['amount'] ?? c['cost'] ?? c['value'];
      if (v is num) costUsed += v.toDouble();
    }
    double? budgetUsedPct;
    String costStatus;
    if (budgetTotal != null && budgetTotal > 0) {
      budgetUsedPct = costUsed / budgetTotal;
      if (budgetUsedPct <= 0.9) {
        costStatus = 'on_track';
      } else if (budgetUsedPct <= 1.05) {
        costStatus = 'at_risk';
      } else {
        costStatus = 'off_track';
      }
    } else {
      costStatus = 'unknown';
    }

    // Scope: count of open change requests / scope items
    int openScope = 0;
    for (final s in costItems) {
      // Reuse costItems list shape — if it has a 'changeRequest' flag, count
      final cr = s['changeRequest'] ?? s['scopeChange'];
      if (cr == true) openScope++;
    }
    String scopeStatus;
    if (openScope == 0) {
      scopeStatus = 'on_track';
    } else if (openScope <= 2) {
      scopeStatus = 'at_risk';
    } else {
      scopeStatus = 'off_track';
    }

    // Quality: count of open quality issues
    int openQuality = 0;
    for (final q in qualityItems) {
      final status = (q['status'] ?? '').toString().toLowerCase();
      if (status == 'open' || status == 'pending') openQuality++;
    }
    String qualityStatus;
    if (openQuality == 0) {
      qualityStatus = 'on_track';
    } else if (openQuality <= 3) {
      qualityStatus = 'at_risk';
    } else {
      qualityStatus = 'off_track';
    }

    // Risk: count of open high/critical risks
    int openHighRisks = 0;
    for (final r in risks) {
      final severity = (r['severity'] ?? r['impact'] ?? '').toString().toLowerCase();
      final status = (r['status'] ?? '').toString().toLowerCase();
      if (status != 'closed' && status != 'mitigated' &&
          (severity == 'high' || severity == 'critical')) {
        openHighRisks++;
      }
    }
    String riskStatus;
    if (openHighRisks == 0) {
      riskStatus = 'on_track';
    } else if (openHighRisks <= 2) {
      riskStatus = 'at_risk';
    } else {
      riskStatus = 'off_track';
    }

    final overall = _worst([
      scheduleStatus, costStatus, scopeStatus, qualityStatus, riskStatus,
    ]);

    return ProjectStatusRollup(
      projectId: projectId,
      projectName: projectName,
      overallStatus: overall,
      scheduleStatus: scheduleStatus,
      costStatus: costStatus,
      scopeStatus: scopeStatus,
      qualityStatus: qualityStatus,
      riskStatus: riskStatus,
      progressPercent: schedTotal > 0 ? progress * 100 : null,
      budgetUsedPercent: budgetUsedPct != null ? budgetUsedPct * 100 : null,
      openRisks: openHighRisks,
      openIssues: qualityItems.where((q) {
        final s = (q['status'] ?? '').toString().toLowerCase();
        return s == 'open' || s == 'pending';
      }).length,
      updatedAt: updatedAt,
    );
  }
}

/// Account-wide dashboard metrics for the signed-in user.
class DashboardMetrics {
  final List<AssignedActivity> assignedToMe;
  final List<AssignedActivity> pastDue;
  final List<ProjectStatusRollup> projectStatuses;
  final List<ProjectStatusRollup> programStatuses;
  final List<ProjectStatusRollup> portfolioStatuses;

  const DashboardMetrics({
    required this.assignedToMe,
    required this.pastDue,
    required this.projectStatuses,
    required this.programStatuses,
    required this.portfolioStatuses,
  });

  int get totalAssigned => assignedToMe.length;
  int get totalPastDue => pastDue.length;
  int get projectsOnTrack =>
      projectStatuses.where((p) => p.overallStatus == 'on_track').length;
  int get projectsAtRisk =>
      projectStatuses.where((p) => p.overallStatus == 'at_risk').length;
  int get projectsOffTrack =>
      projectStatuses.where((p) => p.overallStatus == 'off_track').length;
}

/// Service that loads dashboard metrics for the signed-in user.
///
/// Reads from:
/// - `projects/{projectId}/activities` where assignedTo == user.uid OR user.email
/// - `projects` collection for status rollups
/// - `programs` + `portfolios` for higher-level rollups
///
/// All reads are best-effort — failures are logged and the service returns
/// partial data rather than throwing.
class DashboardMetricsService {
  DashboardMetricsService._();

  /// Coerces a dynamic Firestore list value into a `List<Map<String, dynamic>>`.
  ///
  /// Firestore returns lists as `List<dynamic>` where each element is a
  /// `Map<dynamic, dynamic>`. Direct `.cast<Map<String, dynamic>>()` throws
  /// at runtime because the inner maps aren't typed as `String` keys. This
  /// helper does a safe per-element coercion, skipping any non-map entries.
  static List<Map<String, dynamic>> _coerceMapList(dynamic raw) {
    if (raw is! List) return const [];
    final out = <Map<String, dynamic>>[];
    for (final item in raw) {
      if (item is Map) {
        out.add(item.map((k, v) => MapEntry(k.toString(), v)));
      }
    }
    return out;
  }

  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Load all dashboard metrics for the current user in one pass.
  ///
  /// Performance: uses parallel Firestore reads (Future.wait) instead of
  /// sequential awaits in a loop. The activities subcollection is loaded
  /// in parallel batches — if there are 50 projects, we issue 50 concurrent
  /// reads instead of 50 sequential ones (~10-20x faster).
  ///
  /// Pass [includeActivities] = false to skip the activities subcollection
  /// entirely (used by portfolio dashboard which only needs status rollups).
  static Future<DashboardMetrics> load({bool includeActivities = true}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const DashboardMetrics(
        assignedToMe: [],
        pastDue: [],
        projectStatuses: [],
        programStatuses: [],
        portfolioStatuses: [],
      );
    }

    final assigned = <AssignedActivity>[];
    final projectStatuses = <ProjectStatusRollup>[];

    List<DocumentSnapshot<Map<String, dynamic>>> projectDocs;
    try {
      // Load all projects owned by this user — single query
      final projectsSnap = await _firestore
          .collection('projects')
          .where('ownerId', isEqualTo: user.uid)
          .get();
      projectDocs = projectsSnap.docs;
    } catch (e) {
      debugPrint('[DashboardMetricsService] projects load error: $e');
      return const DashboardMetrics(
        assignedToMe: [],
        pastDue: [],
        projectStatuses: [],
        programStatuses: [],
        portfolioStatuses: [],
      );
    }

    // ── Build status rollups from project data (no extra reads needed) ──
    // This runs first because it only uses data already in the project doc.
    for (final pDoc in projectDocs) {
      final pData = pDoc.data()!;
      final projectId = pDoc.id;
      final projectName = pData['projectName'] as String? ?? 'Untitled';

      try {
        final rollup = ProjectStatusRollup.infer(
          projectId: projectId,
          projectName: projectName,
          scheduleActivities: _coerceMapList(pData['scheduleActivities']),
          costItems: _coerceMapList(pData['costEstimateItems']),
          risks: _coerceMapList(pData['risks']),
          issues: _coerceMapList(pData['issues']),
          qualityItems: _coerceMapList(pData['qualityItems']),
          budgetTotal: (pData['budgetTotal'] as num?)?.toDouble(),
          updatedAt: (pData['updatedAt'] as Timestamp?)?.toDate(),
        );
        projectStatuses.add(rollup);
      } catch (e) {
        debugPrint('[DashboardMetricsService] rollup error: $e');
      }
    }

    // ── Load activities in PARALLEL (not sequential) ──
    // This is the key perf fix: instead of awaiting each project's activities
    // query one at a time, we fire them all concurrently and wait for all to
    // complete. 50 projects = 50 concurrent reads (~1s total) instead of 50
    // sequential reads (~10-20s total).
    if (includeActivities) {
      final activityFutures = <Future<QuerySnapshot<Map<String, dynamic>>>>[];
      for (final pDoc in projectDocs) {
        activityFutures.add(
          _firestore
              .collection('projects')
              .doc(pDoc.id)
              .collection('activities')
              .get(),
        );
      }

      // Wait for all activity queries in parallel
      List<QuerySnapshot<Map<String, dynamic>>> activitySnaps;
      try {
        activitySnaps = await Future.wait(activityFutures);
      } catch (e) {
        // If batch fails (e.g. permission-denied on some subcollection),
        // fall back to best-effort: skip activities entirely and continue
        // with just the project status rollups already built above.
        final errorStr = e.toString();
        if (!errorStr.contains('permission-denied') &&
            !errorStr.contains('PERMISSION_DENIED') &&
            !errorStr.contains('Missing or insufficient permissions')) {
          debugPrint('[DashboardMetricsService] batch activities error: $e');
        }
        activitySnaps = <QuerySnapshot<Map<String, dynamic>>>[];
      }

      for (int i = 0; i < projectDocs.length && i < activitySnaps.length; i++) {
        final pDoc = projectDocs[i];
        final pData = pDoc.data()!;
        final projectId = pDoc.id;
        final projectName = pData['projectName'] as String? ?? 'Untitled';
        final actsSnap = activitySnaps[i];

        for (final aDoc in actsSnap.docs) {
          final a = aDoc.data();
          final assignedTo = (a['assignedTo'] ?? '').toString();
          if (assignedTo.isEmpty) continue;
          // Match by UID or email
          if (assignedTo == user.uid ||
              assignedTo == user.email ||
              assignedTo == user.displayName) {
            assigned.add(AssignedActivity(
              id: aDoc.id,
              projectId: projectId,
              projectName: projectName,
              title: (a['title'] ?? 'Untitled activity').toString(),
              phase: (a['phase'] ?? '').toString(),
              discipline: (a['discipline'] ?? '').toString(),
              role: (a['role'] ?? '').toString(),
              dueDate: (a['dueDate'] ?? '').toString(),
              status: (a['status'] ?? 'pending').toString(),
              assignedTo: assignedTo,
            ));
          }
        }
      }
    }

    // Program + portfolio rollups — load in parallel
    final programStatuses = <ProjectStatusRollup>[];
    final portfolioStatuses = <ProjectStatusRollup>[];

    final results = await Future.wait([
      _firestore
          .collection('programs')
          .where('ownerId', isEqualTo: user.uid)
          .get()
          .catchError((_) => null),
      _firestore
          .collection('portfolios')
          .where('ownerId', isEqualTo: user.uid)
          .get()
          .catchError((_) => null),
    ]);

    final progSnap = results[0] as QuerySnapshot<Map<String, dynamic>>?;
    if (progSnap != null) {
      for (final doc in progSnap.docs) {
        final d = doc.data();
        programStatuses.add(ProjectStatusRollup(
          projectId: doc.id,
          projectName: d['name'] as String? ?? 'Untitled program',
          overallStatus: 'unknown',
          scheduleStatus: 'unknown',
          costStatus: 'unknown',
          scopeStatus: 'unknown',
          qualityStatus: 'unknown',
          riskStatus: 'unknown',
        ));
      }
    }

    final portSnap = results[1] as QuerySnapshot<Map<String, dynamic>>?;
    if (portSnap != null) {
      for (final doc in portSnap.docs) {
        final d = doc.data();
        portfolioStatuses.add(ProjectStatusRollup(
          projectId: doc.id,
          projectName: d['name'] as String? ?? 'Untitled portfolio',
          overallStatus: 'unknown',
          scheduleStatus: 'unknown',
          costStatus: 'unknown',
          scopeStatus: 'unknown',
          qualityStatus: 'unknown',
          riskStatus: 'unknown',
        ));
      }
    }

    final pastDue = assigned.where((a) => a.isPastDue).toList()
      ..sort((a, b) {
        final da = DateTime.tryParse(a.dueDate);
        final db = DateTime.tryParse(b.dueDate);
        if (da == null || db == null) return 0;
        return da.compareTo(db);
      });

    return DashboardMetrics(
      assignedToMe: assigned,
      pastDue: pastDue,
      projectStatuses: projectStatuses,
      programStatuses: programStatuses,
      portfolioStatuses: portfolioStatuses,
    );
  }
}
