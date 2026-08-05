// SideAccumulatedContext
//
// Deterministic, no-hallucination accumulator for sidebar screens.
//
// The sidebar pages in the Launch/Execution module are visited top-to-bottom:
//   1. Cost Estimate Overview
//   2. Scope Tracking Plan
//   3. Change Management
//   4. Issue Management
//   5. Lessons Learned
//   6. Security Management
//   7. Start-Up Planning (Operations / Hypercare / DevOps / Close Out)
//   8. Deliverables Roadmap
//   9. Project Plan (Overview / Level 1 / Detailed / Condensed)
//  10. Project Baseline
//
// Each screen, on first load, should:
//   1. Load its own existing entries from Firestore.
//   2. If empty, deterministically seed entries from REAL prior-phase data
//      (ProjectDataModel + Firestore services). NO LLM/ hallucination.
//   3. Persist seeded entries to Firestore so subsequent loads are stable.
//   4. Render entries top-to-bottom in sidebar order.
//
// The accumulator below exposes:
//   - buildAccumulatedContext(context, checkpoint): returns a string with all
//     sidebar-context-above-this-checkpoint concatenated, for display in
//     "Carried context" banners or for downstream consumers.
//   - sidebarCheckpointOrder: the canonical top-to-bottom ordering.
//   - checkpointsAbove(checkpoint): every checkpoint strictly above the given
//     one in the sidebar — used to prove continuity.
//   - SidebarSeedResult / seedEntriesFor(checkpoint, ...): a deterministic
//     helper that pulls real data for the given checkpoint and returns either
//     a list of seed rows (real) or an empty result (no hallucination).

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:ndu_project/models/project_data_model.dart';
import 'package:ndu_project/services/execution_service.dart';
import 'package:ndu_project/utils/project_data_helper.dart';

/// Canonical top-to-bottom ordering of the sidebar pages shown in the
/// Launch/Execution module screenshot.
const List<String> sidebarCheckpointOrder = [
  'cost_estimate',
  'scope_tracking_plan',
  'change_management',
  'issue_management',
  'lessons_learned',
  'security_management',
  'startup_planning',
  'startup_planning_operations',
  'startup_planning_hypercare',
  'startup_planning_devops',
  'startup_planning_closeout',
  'deliverables_roadmap',
  'project_plan',
  'project_plan_level1_schedule',
  'project_plan_detailed_schedule',
  'project_plan_condensed_summary',
  'project_baseline',
];

/// Returns every checkpoint strictly above the given one in the sidebar
/// ordering. Returns an empty list if the checkpoint is unknown or is the
/// topmost entry.
List<String> checkpointsAbove(String checkpoint) {
  final idx = sidebarCheckpointOrder.indexOf(checkpoint);
  if (idx <= 0) return const [];
  return sidebarCheckpointOrder.sublist(0, idx);
}

/// Friendly label for a checkpoint (used in "Carried context" banner).
String labelForCheckpoint(String checkpoint) {
  switch (checkpoint) {
    case 'cost_estimate':
      return 'Cost Estimate Overview';
    case 'scope_tracking_plan':
      return 'Scope Tracking Plan';
    case 'change_management':
      return 'Change Management';
    case 'issue_management':
      return 'Issue Management';
    case 'lessons_learned':
      return 'Lessons Learned';
    case 'security_management':
      return 'Security Management';
    case 'startup_planning':
      return 'Start-Up Planning';
    case 'startup_planning_operations':
      return 'Operations Plan & Manual';
    case 'startup_planning_hypercare':
      return 'Hypercare Plan';
    case 'startup_planning_devops':
      return 'DevOps';
    case 'startup_planning_closeout':
      return 'Close Out Plan';
    case 'deliverables_roadmap':
      return 'Deliverables Roadmap';
    case 'project_plan':
      return 'Project Plan Overview';
    case 'project_plan_level1_schedule':
      return 'Level 1 — Project Schedule';
    case 'project_plan_detailed_schedule':
      return 'Detailed Project Schedule';
    case 'project_plan_condensed_summary':
      return 'Condensed Project Summary';
    case 'project_baseline':
      return 'Project Baseline';
    default:
      return checkpoint;
  }
}

/// Builds an accumulated-context string for the given checkpoint by
/// walking every checkpoint ABOVE it (in sidebar order) and concatenating
/// the real, persisted entries from Firestore plus the in-memory
/// ProjectDataModel fields.
///
/// This string is safe to display in a "Carried context" banner on each
/// sidebar page; it never invents data. If a prior section has no real
/// entries, that section is silently omitted.
Future<String> buildAccumulatedContext(
  BuildContext context,
  String checkpoint,
) async {
  final data = ProjectDataHelper.getData(context);
  final projectId = data.projectId;
  final above = checkpointsAbove(checkpoint);
  if (above.isEmpty) return '';

  final buf = StringBuffer();
  buf.writeln('Carried context (top → bottom, real data only):');
  buf.writeln('=' * 60);

  for (final cp in above) {
    final section = await _sectionForCheckpoint(cp, data, projectId);
    if (section.isEmpty) continue;
    buf.writeln();
    buf.writeln('• ${labelForCheckpoint(cp)}');
    buf.writeln(section);
  }

  return buf.toString().trim();
}

/// Returns a short, real-data summary for one checkpoint section. Returns
/// an empty string if no real data exists for that section.
Future<String> _sectionForCheckpoint(
  String checkpoint,
  ProjectDataModel data,
  String? projectId,
) async {
  try {
    switch (checkpoint) {
      case 'cost_estimate':
        final items = data.costEstimateItems;
        if (items.isEmpty) return '';
        final lines = items.take(8).map((i) {
          final title = i.title.trim().isEmpty ? 'Untitled' : i.title.trim();
          final amount = i.amount.toStringAsFixed(2);
          return '- $title ($amount)';
        });
        return 'Cost Estimate Items:\n${lines.join('\n')}';

      case 'scope_tracking_plan':
        final items = data.planningRequirementItems;
        if (items.isEmpty) return '';
        final lines = items.take(8).map((r) {
          final t = r.plannedText.trim();
          return t.isEmpty ? null : '- $t';
        }).whereType<String>();
        final list = lines.toList();
        if (list.isEmpty) return '';
        return 'Planning Requirements:\n${list.join('\n')}';

      case 'change_management':
        if (projectId == null || projectId.isEmpty) return '';
        final crs = await ExecutionService.streamChangeRequests(projectId).first;
        if (crs.isEmpty) return '';
        final lines = crs.take(8).map((c) {
          final t = c.issueTopic.trim().isEmpty
              ? 'Change Request'
              : c.issueTopic.trim();
          final state = c.approved ? 'approved' : 'pending';
          return '- $t (status: $state)';
        });
        return 'Change Requests:\n${lines.join('\n')}';

      case 'issue_management':
        if (projectId == null || projectId.isEmpty) return '';
        final issues = await ExecutionService.streamIssues(projectId).first;
        if (issues.isEmpty) {
          // Fall back to in-memory issue log items if Firestore is empty.
          if (data.issueLogItems.isEmpty) return '';
          final lines = data.issueLogItems.take(8).map((i) {
            final t = i.title.trim().isEmpty ? 'Issue' : i.title.trim();
            return '- $t (severity: ${i.severity}, status: ${i.status})';
          });
          return 'Issues (from planning):\n${lines.join('\n')}';
        }
        final lines = issues.take(8).map((i) {
          final t = i.issueTopic.trim().isEmpty
              ? 'Issue'
              : i.issueTopic.trim();
          final state = i.approved ? 'approved' : 'open';
          return '- $t (status: $state)';
        });
        return 'Issues:\n${lines.join('\n')}';

      case 'lessons_learned':
        final lessons = data.lessonsLearned;
        if (lessons.isEmpty) return '';
        final lines = lessons.take(8).map((l) {
          final t = l.lesson.trim().isEmpty ? 'Lesson' : l.lesson.trim();
          final phase = l.phase.trim().isEmpty ? '' : ' [${l.phase}]';
          return '- $t$phase';
        });
        return 'Lessons Learned:\n${lines.join('\n')}';

      case 'security_management':
        final ssher = data.ssherData;
        final items = <String>[];
        if (ssher.safetyItems.isNotEmpty) {
          items.addAll(ssher.safetyItems.take(6).map((s) {
            final t = s.title.trim().isEmpty ? 'Safety Item' : s.title.trim();
            return '- $t (${s.category})';
          }));
        }
        final fepSec = data.frontEndPlanning.security.trim();
        if (fepSec.isNotEmpty) items.add('- FEP Security: $fepSec');
        if (items.isEmpty) return '';
        return 'Security / Safety Context:\n${items.join('\n')}';

      case 'startup_planning':
      case 'startup_planning_operations':
      case 'startup_planning_hypercare':
      case 'startup_planning_devops':
      case 'startup_planning_closeout':
        if (projectId == null || projectId.isEmpty) return '';
        // Pull from the startup_planning Firestore sub-collection.
        final doc = await FirebaseFirestore.instance
            .collection('startup_planning')
            .doc(projectId)
            .get();
        if (!doc.exists) return '';
        final docData = doc.data() ?? <String, dynamic>{};
        final summary = (docData['narrativeSummary'] ?? '').toString().trim();
        if (summary.isEmpty) return '';
        return 'Start-Up Planning Summary:\n$summary';

      case 'deliverables_roadmap':
        final deliverables = <Map<String, dynamic>>[];
        for (final wp in data.workPackages) {
          for (final d in wp.deliverables) {
            if (d.title.trim().isEmpty) continue;
            deliverables.add(<String, dynamic>{
              'title': d.title,
              'package': wp.title,
              'type': d.type,
              'status': d.status,
              'reference': d.reference,
            });
          }
        }
        if (deliverables.isEmpty) return '';
        final lines = deliverables.take(8).map((d) {
          final t = (d['title'] as String).trim();
          final pkg = (d['package'] as String).trim();
          return pkg.isEmpty ? '- $t' : '- $t ($pkg)';
        });
        return 'Deliverables Roadmap:\n${lines.join('\n')}';

      case 'project_plan':
      case 'project_plan_level1_schedule':
      case 'project_plan_detailed_schedule':
      case 'project_plan_condensed_summary':
        if (data.scheduleActivities.isEmpty &&
            data.keyMilestones.isEmpty) return '';
        final items = <String>[];
        for (final m in data.keyMilestones.take(6)) {
          final name = m.name.trim().isEmpty ? 'Milestone' : m.name.trim();
          final due = m.dueDate.trim();
          items.add(due.isEmpty ? '- $name' : '- $name (due: $due)');
        }
        for (final a in data.scheduleActivities.take(6)) {
          final name =
              a.title.trim().isEmpty ? 'Activity' : a.title.trim();
          items.add('- $name (${a.startDate} → ${a.dueDate})');
        }
        if (items.isEmpty) return '';
        return 'Project Plan Snapshot:\n${items.join('\n')}';

      case 'project_baseline':
        if (data.scheduleBaselineActivities.isEmpty &&
            data.scheduleBaselineDate.isEmpty) return '';
        final items = <String>[];
        if (data.scheduleBaselineDate.isNotEmpty) {
          items.add('- Baseline date: ${data.scheduleBaselineDate}');
        }
        items.addAll(data.scheduleBaselineActivities.take(6).map((a) {
          final name =
              a.title.trim().isEmpty ? 'Activity' : a.title.trim();
          return '- $name (baseline: ${a.startDate} → ${a.dueDate})';
        }));
        return 'Project Baseline:\n${items.join('\n')}';
    }
  } catch (e) {
    debugPrint('[SidebarAccumulatedContext] $checkpoint error: $e');
  }
  return '';
}

/// Result of a deterministic seed operation. [rows] is always real data —
/// never invented. If empty, the caller should leave the screen empty
/// (or render an explicit "no prior data to seed" state).
class SidebarSeedResult {
  final List<Map<String, dynamic>> rows;
  final String source; // human-readable source label
  const SidebarSeedResult({this.rows = const [], this.source = ''});

  bool get isNotEmpty => rows.isNotEmpty;
}

/// Deterministic seed for the Issue Management screen.
/// Pulls REAL items from prior-phase risk register (risks that became issues)
/// plus the planning issue log. Returns empty if no real issues exist —
/// never invents issues.
SidebarSeedResult seedIssueManagement(ProjectDataModel data) {
  final rows = <Map<String, dynamic>>[];

  // 1. Planning issue log items (if any were captured during planning).
  for (final i in data.issueLogItems) {
    if (i.title.trim().isEmpty && i.description.trim().isEmpty) continue;
    rows.add(<String, dynamic>{
      'title': i.title,
      'description': i.description,
      'type': i.type.isEmpty ? 'Issue' : i.type,
      'severity': i.severity.isEmpty ? 'Medium' : i.severity,
      'status': i.status.isEmpty ? 'Open' : i.status,
      'assignee': i.assignee,
      'dueDate': i.dueDate,
      'milestone': i.milestone,
    });
  }

  // 2. Risk register items that are typed as "Issue" or have materialized.
  for (final r in data.frontEndPlanning.riskRegisterItems) {
    final typeLower = r.riskType.toLowerCase();
    final catLower = r.category.toLowerCase();
    final isIssue = typeLower.contains('issue') ||
        catLower.contains('issue') ||
        typeLower.contains('problem') ||
        r.status.toLowerCase().contains('materialized') ||
        r.status.toLowerCase().contains('occurred');
    if (!isIssue) continue;
    if (r.riskName.trim().isEmpty && r.description.trim().isEmpty) continue;
    rows.add(<String, dynamic>{
      'title': r.riskName.trim().isEmpty
          ? 'Issue from risk register'
          : r.riskName,
      'description': r.description,
      'type': 'Issue',
      'severity': r.impactLevel.isEmpty ? 'Medium' : r.impactLevel,
      'status': r.status.isEmpty ? 'Open' : r.status,
      'assignee': r.owner,
      'dueDate': '',
      'milestone': '',
    });
  }

  if (rows.isEmpty) return const SidebarSeedResult();
  return SidebarSeedResult(rows: rows, source: 'planning issue log + risk register');
}

/// Deterministic seed for the Lessons Learned screen.
/// Pulls REAL lesson records from the in-memory model. If none exist yet,
/// also scans prior-phase notes (FEP summary, project charter notes) for
/// any captured insights that can serve as initial lessons. Never invents
/// lessons.
SidebarSeedResult seedLessonsLearned(ProjectDataModel data) {
  final rows = <Map<String, dynamic>>[];

  // 1. Existing lessons learned records.
  for (final l in data.lessonsLearned) {
    if (l.lesson.trim().isEmpty) continue;
    rows.add(<String, dynamic>{
      'lesson': l.lesson,
      'category': l.category,
      'type': l.type,
      'phase': l.phase,
      'status': l.status,
      'submittedBy': l.submittedBy,
      'notes': l.notes,
      'impact': l.impact,
      'highlight': l.highlight,
    });
  }

  // 2. Front-end planning summary often contains implicit lessons.
  final fepSummary = data.frontEndPlanning.summary.trim();
  if (fepSummary.isNotEmpty && rows.length < 8) {
    rows.add(<String, dynamic>{
      'lesson': 'FEP summary captured — review for lessons: '
          '${fepSummary.length > 120 ? fepSummary.substring(0, 120) : fepSummary}…',
      'category': 'Planning',
      'type': 'Insight',
      'phase': 'Front-End Planning',
      'status': 'Draft',
      'submittedBy': '',
      'notes': fepSummary,
      'impact': 'Medium',
      'highlight': false,
    });
  }

  // 3. Project charter notes can contain lessons from initiation.
  final charterNotes = data.notes.trim();
  if (charterNotes.isNotEmpty && rows.length < 8) {
    rows.add(<String, dynamic>{
      'lesson': 'Project notes captured — review for lessons: '
          '${charterNotes.length > 120 ? charterNotes.substring(0, 120) : charterNotes}…',
      'category': 'Initiation',
      'type': 'Insight',
      'phase': 'Initiation',
      'status': 'Draft',
      'submittedBy': '',
      'notes': charterNotes,
      'impact': 'Medium',
      'highlight': false,
    });
  }

  if (rows.isEmpty) return const SidebarSeedResult();
  return SidebarSeedResult(rows: rows, source: 'lessons register + planning notes');
}

/// Deterministic seed for the Security Management screen.
/// Pulls REAL safety items from SSHER data + FEP security notes.
SidebarSeedResult seedSecurityManagement(ProjectDataModel data) {
  final ssher = data.ssherData;
  final fepSec = data.frontEndPlanning.security.trim();
  final rows = <Map<String, dynamic>>[];
  for (final s in ssher.safetyItems) {
    rows.add(<String, dynamic>{
      'title': s.title,
      'category': s.category,
      'source': 'SSHER register',
    });
  }
  if (fepSec.isNotEmpty) {
    rows.add(<String, dynamic>{
      'title': fepSec,
      'category': 'FEP Security',
      'source': 'Front-End Planning',
    });
  }
  if (rows.isEmpty) return const SidebarSeedResult();
  return SidebarSeedResult(rows: rows, source: 'SSHER + FEP security');
}

/// Deterministic seed for the Change Management screen.
/// Pulls REAL change requests from the in-memory risk register (which often
/// doubles as a change register) plus execution-phase change requests from
/// Firestore. Never invents changes.
Future<SidebarSeedResult> seedChangeManagement(
  ProjectDataModel data,
  String? projectId,
) async {
  final rows = <Map<String, dynamic>>[];

  // 1. In-memory risk register items that have a non-empty mitigation
  //    strategy can serve as pre-change context.
  for (final r in data.frontEndPlanning.riskRegisterItems.take(12)) {
    if (r.riskName.trim().isEmpty && r.description.trim().isEmpty) continue;
    rows.add(<String, dynamic>{
      'title': r.riskName.trim().isEmpty ? 'Risk-driven change' : r.riskName,
      'description': r.description,
      'category': r.category,
      'owner': r.owner,
      'status': r.status,
      'source': 'Risk register',
    });
  }

  // 2. Execution-phase change requests persisted in Firestore.
  if (projectId != null && projectId.isNotEmpty) {
    try {
      final crs =
          await ExecutionService.streamChangeRequests(projectId).first;
      for (final c in crs.take(12)) {
        rows.add(<String, dynamic>{
          'title': c.issueTopic,
          'description': c.description,
          'category': c.discipline,
          'owner': c.raisedBy,
          'status': c.approved ? 'approved' : 'pending',
          'source': 'Execution change requests',
        });
      }
    } catch (e) {
      debugPrint('[seedChangeManagement] Firestore read error: $e');
    }
  }

  if (rows.isEmpty) return const SidebarSeedResult();
  return SidebarSeedResult(rows: rows, source: 'risk register + execution CRs');
}

/// Deterministic seed for the Deliverables Roadmap screen.
/// Pulls REAL deliverables from work packages in the in-memory model.
SidebarSeedResult seedDeliverablesRoadmap(ProjectDataModel data) {
  final rows = <Map<String, dynamic>>[];
  for (final wp in data.workPackages) {
    for (final d in wp.deliverables) {
      if (d.title.trim().isEmpty) continue;
      rows.add(<String, dynamic>{
        'title': d.title,
        'package': wp.title,
        'type': d.type,
        'status': d.status,
        'reference': d.reference,
        'source': 'Work packages',
      });
    }
  }
  if (rows.isEmpty) return const SidebarSeedResult();
  return SidebarSeedResult(rows: rows, source: 'work package deliverables');
}

/// Deterministic seed for the Project Plan screens (Overview, Level 1,
/// Detailed, Condensed). Pulls REAL schedule activities + milestones from
/// the in-memory model.
SidebarSeedResult seedProjectPlan(ProjectDataModel data) {
  final rows = <Map<String, dynamic>>[];

  for (final m in data.keyMilestones) {
    if (m.name.trim().isEmpty) continue;
    rows.add(<String, dynamic>{
      'kind': 'milestone',
      'name': m.name,
      'dueDate': m.dueDate,
      'discipline': m.discipline,
      'source': 'Key milestones',
    });
  }

  for (final a in data.scheduleActivities) {
    if (a.title.trim().isEmpty) continue;
    rows.add(<String, dynamic>{
      'kind': 'activity',
      'name': a.title,
      'start': a.startDate,
      'finish': a.dueDate,
      'duration': a.durationDays,
      'source': 'Schedule activities',
    });
  }

  if (rows.isEmpty) return const SidebarSeedResult();
  return SidebarSeedResult(rows: rows, source: 'milestones + schedule');
}

/// Deterministic seed for the Project Baseline screen.
/// Pulls REAL baseline schedule activities + baseline date from in-memory.
SidebarSeedResult seedProjectBaseline(ProjectDataModel data) {
  final rows = <Map<String, dynamic>>[];

  if (data.scheduleBaselineDate.isNotEmpty) {
    rows.add(<String, dynamic>{
      'kind': 'meta',
      'name': 'Baseline date',
      'value': data.scheduleBaselineDate,
      'source': 'Schedule baseline',
    });
  }

  for (final a in data.scheduleBaselineActivities) {
    if (a.title.trim().isEmpty) continue;
    rows.add(<String, dynamic>{
      'kind': 'baseline_activity',
      'name': a.title,
      'start': a.startDate,
      'finish': a.dueDate,
      'duration': a.durationDays,
      'source': 'Schedule baseline',
    });
  }

  if (rows.isEmpty) return const SidebarSeedResult();
  return SidebarSeedResult(rows: rows, source: 'schedule baseline');
}

/// Deterministic seed for the four Start-Up Planning sub-screens.
/// Each sub-screen pulls REAL data relevant to its theme:
///   - operations:  operational team roles + runbooks from team members
///   - hypercare:   open risks + their mitigation strategies
///   - devops:      technology & infrastructure notes from FEP
///   - closeout:    lessons learned + completed deliverables
SidebarSeedResult seedStartupPlanningSubsection(
  ProjectDataModel data,
  String checkpoint,
) {
  final rows = <Map<String, dynamic>>[];

  switch (checkpoint) {
    case 'startup_planning_operations':
      // Pull operational team roles.
      for (final m in data.teamMembers) {
        if (m.role.trim().isEmpty) continue;
        rows.add(<String, dynamic>{
          'name': m.name,
          'role': m.role,
          'responsibilities': m.responsibilities,
          'source': 'Team roster',
        });
      }
      if (rows.isEmpty) return const SidebarSeedResult();
      return SidebarSeedResult(rows: rows, source: 'team roster');

    case 'startup_planning_hypercare':
      // Pull open risks for the watchlist.
      for (final r in data.frontEndPlanning.riskRegisterItems) {
        if (r.status.toLowerCase() == 'closed' ||
            r.status.toLowerCase() == 'resolved') continue;
        if (r.riskName.trim().isEmpty && r.description.trim().isEmpty) {
          continue;
        }
        rows.add(<String, dynamic>{
          'item': r.riskName.trim().isEmpty ? 'Risk' : r.riskName,
          'owner': r.owner,
          'severity': r.impactLevel,
          'signal': '',
          'response': r.mitigationStrategy,
          'source': 'Risk register',
        });
      }
      if (rows.isEmpty) return const SidebarSeedResult();
      return SidebarSeedResult(rows: rows, source: 'open risks');

    case 'startup_planning_devops':
      // Pull FEP technology + infrastructure notes.
      final fep = data.frontEndPlanning;
      final tech = fep.technology.trim();
      final infra = fep.infrastructure.trim();
      if (tech.isNotEmpty) {
        rows.add(<String, dynamic>{
          'name': 'Technology stack',
          'owner': '',
          'documentLink': '',
          'reviewDate': '',
          'status': 'Verified',
          'source': 'FEP technology',
          'notes': tech,
        });
      }
      if (infra.isNotEmpty) {
        rows.add(<String, dynamic>{
          'name': 'Infrastructure',
          'owner': '',
          'documentLink': '',
          'reviewDate': '',
          'status': 'Verified',
          'source': 'FEP infrastructure',
          'notes': infra,
        });
      }
      final it = data.itConsiderationsData;
      if (it != null && it.notes.trim().isNotEmpty) {
        rows.add(<String, dynamic>{
          'name': 'IT considerations',
          'owner': '',
          'documentLink': '',
          'reviewDate': '',
          'status': 'Verified',
          'source': 'IT considerations',
          'notes': it.notes,
        });
      }
      if (rows.isEmpty) return const SidebarSeedResult();
      return SidebarSeedResult(rows: rows, source: 'FEP + IT notes');

    case 'startup_planning_closeout':
      // Pull lessons learned + completed deliverables.
      for (final l in data.lessonsLearned) {
        if (l.lesson.trim().isEmpty) continue;
        rows.add(<String, dynamic>{
          'name': l.lesson,
          'owner': l.submittedBy,
          'phase': l.phase,
          'status': l.status,
          'source': 'Lessons learned',
        });
      }
      for (final wp in data.workPackages) {
        for (final d in wp.deliverables) {
          if (d.title.trim().isEmpty) continue;
          final statusLower = d.status.trim().toLowerCase();
          if (statusLower != 'completed' &&
              statusLower != 'done' &&
              statusLower != 'verified' &&
              statusLower != 'complete' &&
              statusLower != 'released') continue;
          rows.add(<String, dynamic>{
            'name': d.title,
            'owner': wp.owner,
            'phase': 'Execution',
            'status': d.status,
            'source': 'Completed deliverables',
          });
        }
      }
      if (rows.isEmpty) return const SidebarSeedResult();
      return SidebarSeedResult(rows: rows, source: 'lessons + completed deliverables');

    default:
      return const SidebarSeedResult();
  }
}
