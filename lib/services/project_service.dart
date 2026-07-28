import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

enum ProjectProgressHealth {
  inProgress,
  behind,
  onTrack,
  completed,
}

class ProjectProgressSnapshot {
  const ProjectProgressSnapshot({
    required this.currentPhase,
    required this.completion,
    required this.completionPercent,
    required this.totalActivities,
    required this.implementedActivities,
    required this.pendingActivities,
    required this.approvedSections,
    required this.totalSections,
    required this.achievedMilestones,
    required this.totalMilestones,
    required this.overdueActivities,
    required this.health,
  });

  final String currentPhase;
  final double completion;
  final int completionPercent;
  final int totalActivities;
  final int implementedActivities;
  final int pendingActivities;
  final int approvedSections;
  final int totalSections;
  final int achievedMilestones;
  final int totalMilestones;
  final int overdueActivities;
  final ProjectProgressHealth health;

  static ProjectProgressSnapshot fromRaw({
    required Map<String, dynamic> source,
    required String fallbackStatus,
    required double fallbackProgress,
    required String fallbackMilestone,
    required String checkpointRoute,
  }) {
    final normalizedProgress = fallbackProgress.clamp(0.0, 1.0).toDouble();
    final activities = _parseMapList(source['projectActivities'],
        fieldName: 'projectActivities');

    var totalActivities = 0;
    var implementedActivities = 0;
    var pendingActivities = 0;
    var overdueActivities = 0;
    final today = DateTime.now();
    final todayFloor = DateTime(today.year, today.month, today.day);

    final allSections = <String>{};
    final approvedSections = <String>{};
    final phaseCandidates = <String>[];

    for (final activity in activities) {
      final title = (activity['title'] ?? '').toString().trim();
      final description = (activity['description'] ?? '').toString().trim();
      if (title.isEmpty && description.isEmpty) {
        continue;
      }

      totalActivities += 1;
      final statusToken = _normalizeToken(activity['status']);
      final implemented = _isImplementedToken(statusToken);
      final rejected = _isRejectedToken(statusToken);

      if (implemented) {
        implementedActivities += 1;
      } else if (!rejected) {
        pendingActivities += 1;
      }

      if (!implemented) {
        final dueDate = _tryParseDate(activity['dueDate']);
        if (dueDate != null && dueDate.isBefore(todayFloor)) {
          overdueActivities += 1;
        }
      }

      final sections = _parseStringList(activity['applicableSections']);
      if (sections.isEmpty) {
        final sourceSection =
            (activity['sourceSection'] ?? '').toString().trim();
        if (sourceSection.isNotEmpty) {
          sections.add(sourceSection);
        }
      }
      allSections.addAll(sections);

      final approvalToken = _normalizeToken(activity['approvalStatus']);
      if (_isApprovedToken(approvalToken)) {
        approvedSections.addAll(sections);
      }

      final phaseText = (activity['phase'] ?? '').toString().trim();
      if (phaseText.isNotEmpty) {
        phaseCandidates.add(phaseText);
      }
    }

    final milestoneStats = _resolveMilestoneStats(source, fallbackMilestone);

    final totalSections = allSections.length;
    final approvedSectionCount = approvedSections.length > totalSections
        ? totalSections
        : approvedSections.length;

    final hasActivitySignal = totalActivities > 0;
    final hasSectionSignal = totalSections > 0;
    final hasMilestoneSignal = milestoneStats.total > 0;
    final actionableActivities = implementedActivities + pendingActivities;
    final hasPaceSignal = actionableActivities > 0;

    final weightedParts = <MapEntry<double, double>>[];
    if (hasActivitySignal) {
      weightedParts.add(
        MapEntry(implementedActivities / totalActivities, 0.45),
      );
    }
    if (hasSectionSignal) {
      weightedParts.add(
        MapEntry(approvedSectionCount / totalSections, 0.25),
      );
    }
    if (hasMilestoneSignal) {
      weightedParts.add(
        MapEntry(milestoneStats.achieved / milestoneStats.total, 0.20),
      );
    }
    if (hasPaceSignal) {
      weightedParts.add(
        MapEntry(implementedActivities / actionableActivities, 0.10),
      );
    }

    double completion = normalizedProgress;
    if (weightedParts.isNotEmpty) {
      final weightSum = weightedParts.fold<double>(
        0,
        (totalWeight, part) => totalWeight + part.value,
      );
      if (weightSum > 0) {
        final weightedScore = weightedParts.fold<double>(
          0,
          (totalScore, part) => totalScore + (part.key * part.value),
        );
        completion = (weightedScore / weightSum).clamp(0.0, 1.0);
        if (!hasActivitySignal && normalizedProgress > completion) {
          completion = normalizedProgress;
        }
        // Blend with checkpoint-based progress when activities are all pending
        if (hasActivitySignal &&
            implementedActivities == 0 &&
            milestoneStats.achieved == 0 &&
            normalizedProgress > completion) {
          completion = (normalizedProgress * 0.6) + (completion * 0.4);
        }
      }
    }

    final currentPhase = _resolveCurrentPhase(
      fallbackStatus: fallbackStatus,
      checkpointRoute: checkpointRoute,
      phaseCandidates: phaseCandidates,
    );

    final health = _resolveHealth(
      completion: completion,
      implementedActivities: implementedActivities,
      pendingActivities: pendingActivities,
      overdueActivities: overdueActivities,
    );

    return ProjectProgressSnapshot(
      currentPhase: currentPhase,
      completion: completion,
      completionPercent: (completion * 100).round().clamp(0, 100),
      totalActivities: totalActivities,
      implementedActivities: implementedActivities,
      pendingActivities: pendingActivities,
      approvedSections: approvedSectionCount,
      totalSections: totalSections,
      achievedMilestones: milestoneStats.achieved,
      totalMilestones: milestoneStats.total,
      overdueActivities: overdueActivities,
      health: health,
    );
  }

  static ProjectProgressHealth _resolveHealth({
    required double completion,
    required int implementedActivities,
    required int pendingActivities,
    required int overdueActivities,
  }) {
    if (completion >= 0.995) {
      return ProjectProgressHealth.completed;
    }
    final stalledWork = pendingActivities > implementedActivities + 3;
    if (overdueActivities > 0 || (completion < 0.35 && stalledWork)) {
      return ProjectProgressHealth.behind;
    }
    if (completion >= 0.65 ||
        (implementedActivities > 0 &&
            implementedActivities >= pendingActivities)) {
      return ProjectProgressHealth.onTrack;
    }
    return ProjectProgressHealth.inProgress;
  }

  static String _resolveCurrentPhase({
    required String fallbackStatus,
    required String checkpointRoute,
    required List<String> phaseCandidates,
  }) {
    final statusPhase = _phaseFromToken(fallbackStatus);
    if (statusPhase.isNotEmpty) return statusPhase;

    final checkpointPhase = _phaseFromCheckpoint(checkpointRoute);
    if (checkpointPhase.isNotEmpty) return checkpointPhase;

    for (final candidate in phaseCandidates.reversed) {
      final resolved = _phaseFromToken(candidate);
      if (resolved.isNotEmpty) {
        return resolved;
      }
    }

    return 'Initiation';
  }

  static String _phaseFromCheckpoint(String checkpointRoute) {
    final token = _normalizeToken(checkpointRoute);
    if (token.isEmpty) return '';

    if (token.startsWith('fep_')) return 'Front End Planning';
    if (token.contains('launch') || token.contains('go_live')) return 'Launch';
    if (token.contains('execution') ||
        token.contains('progress_tracking') ||
        token.contains('vendor_tracking') ||
        token.contains('contracts_tracking')) {
      return 'Execution';
    }
    if (token.startsWith('design_') || token == 'design') return 'Design';
    if (token.contains('close_out') ||
        token.contains('closure') ||
        token.contains('finalize')) {
      return 'Close-out';
    }
    if (token.contains('project_') ||
        token.contains('schedule') ||
        token.contains('wbs') ||
        token.contains('scope_tracking') ||
        token.contains('cost_estimate')) {
      return 'Planning';
    }
    if (token.contains('business_case') ||
        token.contains('potential_solutions') ||
        token.contains('risk_identification') ||
        token.contains('it_considerations') ||
        token.contains('infrastructure_considerations') ||
        token.contains('core_stakeholders') ||
        token.contains('initiation')) {
      return 'Initiation';
    }

    return '';
  }

  static String _phaseFromToken(String value) {
    final token = _normalizeToken(value);
    if (token.isEmpty) return '';

    if (token.contains('complete') || token.contains('closed')) {
      return 'Completed';
    }
    if (token.contains('launch')) return 'Launch';
    if (token.contains('execution')) return 'Execution';
    if (token.contains('design')) return 'Design';
    if (token.contains('front end')) return 'Front End Planning';
    if (token.contains('planning') ||
        token.contains('project plan') ||
        token.contains('charter')) {
      return 'Planning';
    }
    if (token.contains('initiation') ||
        token.contains('idea') ||
        token.contains('business case')) {
      return 'Initiation';
    }
    return '';
  }

  static _MilestoneStats _resolveMilestoneStats(
    Map<String, dynamic> source,
    String fallbackMilestone,
  ) {
    var total = 0;
    var achieved = 0;

    void consumeMilestones(dynamic raw) {
      if (raw is! Iterable) return;
      for (final milestone in raw) {
        if (milestone is! Map) continue;
        final map = Map<String, dynamic>.from(milestone);

        final hasAnyValue = map.values.any((value) {
          final text = (value ?? '').toString().trim();
          return text.isNotEmpty && text.toLowerCase() != 'null';
        });
        if (!hasAnyValue) continue;

        total += 1;
        if (_isMilestoneAchieved(map)) {
          achieved += 1;
        }
      }
    }

    consumeMilestones(source['keyMilestones']);

    if (total == 0) {
      final planningGoals = source['planningGoals'];
      if (planningGoals is Iterable) {
        for (final goal in planningGoals) {
          if (goal is! Map) continue;
          final goalMap = Map<String, dynamic>.from(goal);
          consumeMilestones(goalMap['milestones']);
        }
      }
    }

    if (total == 0 && fallbackMilestone.trim().isNotEmpty) {
      total = 1;
      achieved = _looksCompletedDescriptor(fallbackMilestone) ? 1 : 0;
    }

    return _MilestoneStats(total: total, achieved: achieved);
  }

  static bool _isMilestoneAchieved(Map<String, dynamic> milestone) {
    final boolSignals = [
      milestone['completed'],
      milestone['isCompleted'],
      milestone['achieved'],
      milestone['isAchieved'],
    ];
    if (boolSignals.any((flag) => flag == true)) {
      return true;
    }

    final statusSignals = [
      milestone['status'],
      milestone['statusTag'],
      milestone['state'],
      milestone['result'],
    ];
    if (statusSignals.any((signal) => _looksCompletedDescriptor('$signal'))) {
      return true;
    }

    final completedDate = (milestone['completedDate'] ?? '').toString().trim();
    if (completedDate.isNotEmpty) {
      return true;
    }

    return false;
  }

  static bool _isImplementedToken(String token) {
    if (token.isEmpty) return false;
    return token.contains('implement') ||
        token.contains('complete') ||
        token == 'done' ||
        token.contains('closed');
  }

  static bool _isRejectedToken(String token) {
    if (token.isEmpty) return false;
    return token.contains('reject') || token.contains('cancel');
  }

  static bool _isApprovedToken(String token) {
    if (token.isEmpty) return false;
    return token.contains('approved') || token.contains('locked');
  }

  static bool _looksCompletedDescriptor(String value) {
    final token = _normalizeToken(value);
    if (token.isEmpty) return false;
    return token.contains('complete') ||
        token.contains('achiev') ||
        token == 'done' ||
        token.contains('approved') ||
        token.contains('closed');
  }

  static String _normalizeToken(dynamic value) {
    return (value ?? '').toString().trim().toLowerCase();
  }

  static List<Map<String, dynamic>> _parseMapList(
    dynamic raw, {
    required String fieldName,
  }) {
    if (raw is! Iterable) return const [];

    final parsed = <Map<String, dynamic>>[];
    for (final value in raw) {
      if (value is Map) {
        parsed.add(Map<String, dynamic>.from(value));
      } else {
        debugPrint(
          'Skipping non-map entry for $fieldName in progress snapshot',
        );
      }
    }
    return parsed;
  }

  static List<String> _parseStringList(dynamic raw) {
    if (raw is! Iterable) return <String>[];
    return raw
        .map((value) => value.toString().trim())
        .where((value) => value.isNotEmpty)
        .toList(growable: false);
  }

  static DateTime? _tryParseDate(dynamic raw) {
    if (raw == null) return null;
    if (raw is Timestamp) return raw.toDate();
    if (raw is DateTime) return raw;
    if (raw is num) {
      final milliseconds = raw.toInt();
      if (milliseconds > 0) {
        return DateTime.fromMillisecondsSinceEpoch(milliseconds);
      }
      return null;
    }

    final text = raw.toString().trim();
    if (text.isEmpty) return null;

    final parsed = DateTime.tryParse(text);
    if (parsed != null) return parsed;

    final slashPattern = RegExp(r'^(\d{1,2})/(\d{1,2})/(\d{2,4})$');
    final slashMatch = slashPattern.firstMatch(text);
    if (slashMatch != null) {
      final month = int.tryParse(slashMatch.group(1)!);
      final day = int.tryParse(slashMatch.group(2)!);
      var year = int.tryParse(slashMatch.group(3)!);
      if (month != null && day != null && year != null) {
        if (year < 100) year += 2000;
        return DateTime(year, month, day);
      }
    }

    final dashPattern = RegExp(r'^(\d{1,2})-(\d{1,2})-(\d{2,4})$');
    final dashMatch = dashPattern.firstMatch(text);
    if (dashMatch != null) {
      final month = int.tryParse(dashMatch.group(1)!);
      final day = int.tryParse(dashMatch.group(2)!);
      var year = int.tryParse(dashMatch.group(3)!);
      if (month != null && day != null && year != null) {
        if (year < 100) year += 2000;
        return DateTime(year, month, day);
      }
    }

    return null;
  }
}

class _MilestoneStats {
  const _MilestoneStats({
    required this.total,
    required this.achieved,
  });

  final int total;
  final int achieved;
}

class ProjectRecord {
  final String id;
  final String ownerId;
  final String ownerEmail;
  final String ownerName;
  final String name;
  final String solutionTitle;
  final String solutionDescription;
  final String businessCase;
  final String notes;
  final String status;
  final double progress;
  final double investmentMillions;
  final String milestone;
  final List<String> tags;
  final bool isBasicPlanProject;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String
      checkpointRoute; // identifies where to resume when opening from dashboard
  final DateTime? checkpointAt;
  final ProjectProgressSnapshot progressSnapshot;

  ProjectRecord({
    required this.id,
    required this.ownerId,
    required this.ownerEmail,
    required this.ownerName,
    required this.name,
    required this.solutionTitle,
    required this.solutionDescription,
    required this.businessCase,
    required this.notes,
    required this.status,
    required this.progress,
    required this.investmentMillions,
    required this.milestone,
    required this.tags,
    required this.isBasicPlanProject,
    required this.createdAt,
    required this.updatedAt,
    required this.checkpointRoute,
    required this.checkpointAt,
    required this.progressSnapshot,
  });

  factory ProjectRecord.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    final tagsRaw = data['tags'];
    final createdTs = data['createdAt'];
    final updatedTs = data['updatedAt'];

    List<String> parseTags(dynamic raw) {
      if (raw is Iterable) {
        return raw
            .map((e) => e.toString())
            .where((e) => e.isNotEmpty)
            .toList(growable: false);
      }
      return const [];
    }

    DateTime parseTimestamp(dynamic ts, {required DateTime fallback}) {
      if (ts is Timestamp) return ts.toDate();
      if (ts is DateTime) return ts;
      return fallback;
    }

    double parseDouble(dynamic value, {double fallback = 0}) {
      if (value is num) return value.toDouble();
      final parsed = double.tryParse(value?.toString() ?? '');
      return parsed ?? fallback;
    }

    final status = (data['status'] ?? 'Initiation').toString();
    final checkpointRoute = (data['checkpointRoute'] ?? '').toString();
    final milestone = (data['milestone'] ?? '').toString();
    final progress =
        parseDouble(data['progress'], fallback: 0.0).clamp(0.0, 1.0).toDouble();
    final progressSnapshot = ProjectProgressSnapshot.fromRaw(
      source: data,
      fallbackStatus: status,
      fallbackProgress: progress,
      fallbackMilestone: milestone,
      checkpointRoute: checkpointRoute,
    );

    return ProjectRecord(
      id: doc.id,
      ownerId: (data['ownerId'] ?? '').toString(),
      ownerEmail: (data['ownerEmail'] ?? '').toString(),
      ownerName: (data['ownerName'] ?? '').toString(),
      name: (data['name'] ?? data['projectName'] ?? '').toString(),
      solutionTitle: (data['solutionTitle'] ?? '').toString(),
      solutionDescription: (data['solutionDescription'] ?? '').toString(),
      businessCase: (data['businessCase'] ?? '').toString(),
      notes: (data['notes'] ?? '').toString(),
      status: status,
      progress: progress,
      investmentMillions:
          parseDouble(data['investmentMillions'], fallback: 0.0),
      milestone: milestone,
      tags: parseTags(tagsRaw),
      isBasicPlanProject: data['isBasicPlanProject'] == true,
      createdAt: parseTimestamp(createdTs,
          fallback: DateTime.fromMillisecondsSinceEpoch(0)),
      updatedAt: parseTimestamp(updatedTs,
          fallback: DateTime.fromMillisecondsSinceEpoch(0)),
      checkpointRoute: checkpointRoute,
      checkpointAt: data['checkpointAt'] is Timestamp
          ? (data['checkpointAt'] as Timestamp).toDate()
          : null,
      progressSnapshot: progressSnapshot,
    );
  }
}

class ProjectService {
  static final CollectionReference<Map<String, dynamic>> _projectsCol =
      FirebaseFirestore.instance.collection('projects');

  /// Check if a project name already exists for the given owner.
  /// Case-sensitive match on the stored `name` field.
  /// Throws StateError if check fails to prevent duplicate names.
  static Future<bool> projectNameExists({
    required String ownerId,
    required String name,
  }) async {
    try {
      final query = await _projectsCol
          .where('ownerId', isEqualTo: ownerId)
          .where('name', isEqualTo: name)
          .limit(1)
          .get();
      return query.docs.isNotEmpty;
    } catch (e) {
      // Log error and throw exception to block save
      debugPrint('Error checking duplicate project name: $e');
      throw StateError(
          'Unable to verify project name uniqueness. Please try again.');
    }
  }

  static Future<String> createProject({
    required String ownerId,
    required String ownerName,
    required String name,
    required String solutionTitle,
    required String solutionDescription,
    required String businessCase,
    required String notes,
    String? ownerEmail,
    double progress = 0.1,
    double investmentMillions = 0,
    String status = 'Initiation',
    String milestone = 'Initiation',
    List<String> tags = const [],
    String checkpointRoute = 'project_decision_summary',
  }) async {
    final now = FieldValue.serverTimestamp();
    final normalizedTags = tags
        .where((tag) => tag.trim().isNotEmpty)
        .take(5)
        .map((tag) => tag.trim())
        .toList();
    if (normalizedTags.isEmpty && status.trim().isNotEmpty) {
      normalizedTags.add(status.trim());
    }

    final sanitizedEmail = ownerEmail?.trim();

    if (ownerId.trim().isEmpty) {
      throw StateError('Missing owner ID for project creation');
    }

    final payload = {
      'ownerId': ownerId,
      'ownerName': ownerName,
      if (sanitizedEmail != null && sanitizedEmail.isNotEmpty)
        'ownerEmail': sanitizedEmail.toLowerCase(),
      'name': name,
      'projectName': name,
      'solutionTitle': solutionTitle,
      'solutionDescription': solutionDescription,
      'businessCase': businessCase,
      'notes': notes,
      'status': status,
      'progress': progress,
      'investmentMillions': investmentMillions,
      'milestone': milestone,
      'tags': normalizedTags,
      'createdAt': now,
      'updatedAt': now,
      'checkpointRoute': checkpointRoute,
      'checkpointAt': now,
    };

    final ref = await _projectsCol.add(payload);
    return ref.id;
  }

  static Stream<List<ProjectRecord>> streamProjects({
    String? ownerId,
    int limit = 200, // Increased limit to ensure all projects are visible
    bool filterByOwner = true,
  }) {
    // Start with base query - NO status filter to show ALL projects (Draft, Initiation, In Progress, etc.)
    Query<Map<String, dynamic>> query =
        _projectsCol.orderBy('createdAt', descending: true).limit(limit);
    if (filterByOwner && ownerId != null && ownerId.isNotEmpty) {
      query = query.where('ownerId', isEqualTo: ownerId);
    }
    return query.snapshots().map((snapshot) {
      final projects = snapshot.docs.map(ProjectRecord.fromDoc).toList();
      debugPrint(
          '📊 StreamProjects: Found ${projects.length} projects for ownerId: $ownerId');
      return projects;
    });
  }

  /// Stream projects by a list of project IDs (for program dashboard)
  static Stream<List<ProjectRecord>> streamProjectsByIds(
      List<String> projectIds) {
    if (projectIds.isEmpty) {
      return Stream.value([]);
    }

    // Firestore 'in' queries support up to 10 items, programs have max 3 projects so we're safe
    return _projectsCol
        .where(FieldPath.documentId, whereIn: projectIds)
        .snapshots()
        .handleError((error) {
      debugPrint('⚠️ Error streaming projects by IDs: $error');
      return null;
    }).map((snapshot) {
      final projects = <ProjectRecord>[];
      for (final doc in snapshot.docs) {
        try {
          if (doc.exists) {
            projects.add(ProjectRecord.fromDoc(doc));
          }
        } catch (e) {
          debugPrint('⚠️ Error parsing project ${doc.id}: $e');
        }
      }
      return projects;
    });
  }

  static Future<void> deleteProject(String projectId) {
    return _projectsCol.doc(projectId).delete();
  }

  /// Update project fields
  static Future<void> updateProject(
      String projectId, Map<String, dynamic> updates) async {
    final payload = Map<String, dynamic>.from(updates);
    payload['updatedAt'] = FieldValue.serverTimestamp();
    await _projectsCol.doc(projectId).update(payload);
  }

  /// Fetch a single project by id.
  static Future<ProjectRecord?> getProjectById(String projectId) async {
    try {
      final doc = await _projectsCol.doc(projectId).get();
      if (!doc.exists) return null;
      return ProjectRecord.fromDoc(doc);
    } catch (_) {
      return null;
    }
  }

  /// Update a project's checkpoint route and timestamp.
  static Future<void> updateCheckpoint({
    required String projectId,
    required String checkpointRoute,
  }) async {
    await _projectsCol.doc(projectId).update({
      'checkpointRoute': checkpointRoute,
      'checkpointAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Get total project count (admin only)
  static Future<int> getTotalProjectCount() async {
    try {
      final snapshot = await _projectsCol.count().get();
      return snapshot.count ?? 0;
    } catch (e) {
      return 0;
    }
  }

  /// Watch all projects (admin only)
  static Stream<List<Map<String, dynamic>>> watchAllProjects() {
    return _projectsCol.orderBy('createdAt', descending: true).snapshots().map(
          (snapshot) => snapshot.docs
              .map((doc) => {'projectId': doc.id, ...doc.data()})
              .toList(),
        );
  }
}
