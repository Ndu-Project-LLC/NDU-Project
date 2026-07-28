import 'dart:math' as math;

import 'package:ndu_project/models/project_activity.dart';
import 'package:ndu_project/models/project_data_model.dart';

class AgileProjectContextHelper {
  static String activeSprintLabel(ProjectDataModel data) {
    final sprintCount = math.max(
      1,
      (data.scheduleActivities.length / 8).ceil(),
    );
    return 'Sprint $sprintCount';
  }

  static List<AgilePersonSeed> people(ProjectDataModel data, {int limit = 8}) {
    final people = <AgilePersonSeed>[];
    for (final member in data.teamMembers) {
      final name = member.name.trim();
      if (name.isEmpty) continue;
      people.add(
        AgilePersonSeed(
          name: name,
          role: _fallback(member.role, 'Team Member'),
          notes: member.responsibilities.trim(),
        ),
      );
    }
    if (people.isEmpty) {
      for (final role in data.projectRoles) {
        final title = role.title.trim();
        if (title.isEmpty) continue;
        people.add(
          AgilePersonSeed(
            name: title,
            role: _fallback(role.workstream, 'Project Role'),
            notes: role.description.trim(),
          ),
        );
      }
    }
    if (people.isEmpty) {
      final ownerSet = <String>{};
      for (final item in workItems(data, limit: limit * 2)) {
        final owner = item.owner.trim();
        if (owner.isEmpty || !ownerSet.add(owner.toLowerCase())) continue;
        people.add(
          AgilePersonSeed(
            name: owner,
            role: _fallback(item.category, 'Contributor'),
            notes: item.description,
          ),
        );
      }
    }
    return people.take(limit).toList();
  }

  static List<AgileWorkItemSeed> workItems(
    ProjectDataModel data, {
    int limit = 18,
  }) {
    final items = <AgileWorkItemSeed>[];
    final seen = <String>{};

    void addItem(AgileWorkItemSeed item) {
      final key = '${item.id}|${item.title}'.toLowerCase();
      if (item.title.trim().isEmpty || seen.contains(key)) return;
      seen.add(key);
      items.add(item);
    }

    for (final requirement in data.planningRequirementItems) {
      addItem(
        AgileWorkItemSeed(
          id: _fallback(requirement.id, 'REQ-${items.length + 1}'),
          title: requirement.plannedText.trim(),
          description: _fallback(
            requirement.acceptanceCriteria.trim(),
            requirement.notes.trim(),
          ),
          owner: requirement.owner.trim(),
          priority: _normalizePriority(requirement.priority),
          status: _normalizeStatus(requirement.status),
          category: 'Requirement',
        ),
      );
    }

    for (final package in data.workPackages) {
      addItem(
        AgileWorkItemSeed(
          id: _fallback(package.packageCode, package.id),
          title: package.title.trim(),
          description: _fallback(package.description.trim(), package.notes.trim()),
          owner: package.owner.trim(),
          priority: _priorityFromStatus(package.status),
          status: _normalizeStatus(package.status),
          category: _fallback(package.type.trim(), 'Work Package'),
        ),
      );
    }

    for (final activity in data.scheduleActivities) {
      addItem(
        AgileWorkItemSeed(
          id: _fallback(activity.wbsId, activity.id),
          title: activity.title.trim(),
          description: activity.milestone.trim(),
          owner: activity.assignee.trim(),
          priority: _normalizePriority(activity.priority),
          status: _normalizeStatus(activity.status),
          category: 'Schedule Activity',
        ),
      );
    }

    for (final activity in [
      ...data.projectActivities,
      ...data.customProjectActivities,
    ]) {
      addItem(
        AgileWorkItemSeed(
          id: activity.id,
          title: activity.title.trim(),
          description: activity.description.trim(),
          owner: activity.assignedTo?.trim() ?? activity.role.trim(),
          priority: 'Medium',
          status: _projectActivityStatus(activity.status),
          category: _fallback(activity.sourceSection.trim(), 'Project Activity'),
        ),
      );
    }

    if (items.isEmpty) {
      addItem(
        AgileWorkItemSeed(
          id: 'PROJECT-1',
          title: _fallback(data.projectObjective.trim(), data.projectName.trim()),
          description: _fallback(data.businessCase.trim(), data.notes.trim()),
          owner: '',
          priority: 'Medium',
          status: 'Backlog',
          category: 'Project Objective',
        ),
      );
    }

    return items.take(limit).toList();
  }

  static List<AgileIssueSeed> issues(ProjectDataModel data, {int limit = 10}) {
    final issues = <AgileIssueSeed>[];
    for (final item in data.issueLogItems) {
      issues.add(
        AgileIssueSeed(
          id: _fallback(item.id, 'ISS-${issues.length + 1}'),
          title: _fallback(item.title.trim(), item.description.trim()),
          description: item.description.trim(),
          owner: item.assignee.trim(),
          status: _normalizeStatus(item.status),
          severity: _fallback(item.severity.trim(), 'Medium'),
          due: item.dueDate.trim(),
        ),
      );
    }
    return issues.take(limit).toList();
  }

  static List<AgileRiskSeed> risks(ProjectDataModel data, {int limit = 10}) {
    final risks = <AgileRiskSeed>[];
    for (final item in data.executionRiskItems) {
      risks.add(
        AgileRiskSeed(
          id: item.id,
          title: _fallback(item.title.trim(), item.description.trim()),
          description: _fallback(item.description.trim(), item.mitigationStrategy.trim()),
          owner: item.owner.trim(),
          status: _fallback(item.status.trim(), 'Open'),
          probability: item.likelihoodScore == 0 ? 3 : item.likelihoodScore,
          impact: item.impactScore == 0 ? 3 : item.impactScore,
          mitigation: item.mitigationStrategy.trim(),
        ),
      );
    }

    if (risks.isEmpty) {
      for (final issue in issues(data, limit: limit)) {
        risks.add(
          AgileRiskSeed(
            id: issue.id,
            title: issue.title,
            description: issue.description,
            owner: issue.owner,
            status: issue.status,
            probability: _severityScore(issue.severity),
            impact: _severityScore(issue.severity),
            mitigation: issue.due.isEmpty ? '' : 'Target resolution by ${issue.due}',
          ),
        );
      }
    }

    return risks.take(limit).toList();
  }

  static List<AgileStakeholderSeed> stakeholders(
    ProjectDataModel data, {
    int limit = 6,
  }) {
    final stakeholders = <AgileStakeholderSeed>[];
    for (final entry in data.stakeholderEntries) {
      final name = entry.name.trim();
      if (name.isEmpty) continue;
      stakeholders.add(
        AgileStakeholderSeed(
          name: name,
          role: _fallback(entry.role.trim(), entry.organization.trim()),
          owner: entry.owner.trim(),
          notes: entry.notes.trim(),
          sentiment: entry.interest.toLowerCase() == 'high' ? 'positive' : 'mixed',
        ),
      );
    }
    return stakeholders.take(limit).toList();
  }

  static int estimateStoryPoints(String text) {
    final length = text.trim().split(RegExp(r'\s+')).length;
    if (length >= 18) return 8;
    if (length >= 12) return 5;
    if (length >= 7) return 3;
    return 2;
  }

  static String initials(String value) {
    final tokens = value
        .trim()
        .split(RegExp(r'\s+'))
        .where((token) => token.isNotEmpty)
        .toList();
    if (tokens.isEmpty) return 'TM';
    if (tokens.length == 1) return tokens.first.substring(0, 1).toUpperCase();
    return '${tokens.first[0]}${tokens.last[0]}'.toUpperCase();
  }

  static String _projectActivityStatus(ProjectActivityStatus status) {
    switch (status) {
      case ProjectActivityStatus.implemented:
        return 'Done';
      case ProjectActivityStatus.acknowledged:
        return 'In Progress';
      case ProjectActivityStatus.rejected:
        return 'Blocked';
      case ProjectActivityStatus.deferred:
        return 'Ready';
      case ProjectActivityStatus.pending:
        return 'Backlog';
    }
  }

  static String _normalizePriority(String value) {
    final normalized = value.trim().toLowerCase();
    if (normalized.contains('high') || normalized.contains('critical')) {
      return 'High';
    }
    if (normalized.contains('low')) return 'Low';
    return 'Medium';
  }

  static String _priorityFromStatus(String value) {
    final normalized = value.trim().toLowerCase();
    if (normalized.contains('block')) return 'High';
    if (normalized.contains('complete')) return 'Low';
    return 'Medium';
  }

  static String _normalizeStatus(String value) {
    final normalized = value.trim().toLowerCase();
    if (normalized.contains('done') || normalized.contains('complete')) {
      return 'Done';
    }
    if (normalized.contains('review')) return 'In Review';
    if (normalized.contains('progress') || normalized.contains('active')) {
      return 'In Progress';
    }
    if (normalized.contains('ready')) return 'Ready';
    if (normalized.contains('block') || normalized.contains('risk')) {
      return 'Blocked';
    }
    return 'Backlog';
  }

  static int _severityScore(String value) {
    final normalized = value.trim().toLowerCase();
    if (normalized.contains('critical') || normalized.contains('high')) return 4;
    if (normalized.contains('low')) return 2;
    return 3;
  }

  static String _fallback(String value, String fallback) {
    return value.trim().isEmpty ? fallback : value.trim();
  }
}

class AgilePersonSeed {
  final String name;
  final String role;
  final String notes;

  const AgilePersonSeed({
    required this.name,
    required this.role,
    required this.notes,
  });
}

class AgileWorkItemSeed {
  final String id;
  final String title;
  final String description;
  final String owner;
  final String priority;
  final String status;
  final String category;

  const AgileWorkItemSeed({
    required this.id,
    required this.title,
    required this.description,
    required this.owner,
    required this.priority,
    required this.status,
    required this.category,
  });
}

class AgileIssueSeed {
  final String id;
  final String title;
  final String description;
  final String owner;
  final String status;
  final String severity;
  final String due;

  const AgileIssueSeed({
    required this.id,
    required this.title,
    required this.description,
    required this.owner,
    required this.status,
    required this.severity,
    required this.due,
  });
}

class AgileRiskSeed {
  final String id;
  final String title;
  final String description;
  final String owner;
  final String status;
  final int probability;
  final int impact;
  final String mitigation;

  const AgileRiskSeed({
    required this.id,
    required this.title,
    required this.description,
    required this.owner,
    required this.status,
    required this.probability,
    required this.impact,
    required this.mitigation,
  });
}

class AgileStakeholderSeed {
  final String name;
  final String role;
  final String owner;
  final String notes;
  final String sentiment;

  const AgileStakeholderSeed({
    required this.name,
    required this.role,
    required this.owner,
    required this.notes,
    required this.sentiment,
  });
}
