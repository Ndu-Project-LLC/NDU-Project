import 'package:ndu_project/models/project_activity.dart';
import 'package:ndu_project/models/project_data_model.dart';

/// Central orchestration utility that builds a unified, cross-phase
/// activity log from structured project data.
class ProjectIntelligenceService {
  static const Set<String> _executionSectionCheckpoints = <String>{
    'staff_team',
    'team_meetings',
    'progress_tracking',
    'contracts_tracking',
    'vendor_tracking',
    'detailed_design',
    'agile_development_iterations',
    'scope_tracking_implementation',
    'stakeholder_alignment',
    'update_ops_maintenance_plans',
    'launch_checklist',
    'risk_tracking',
    'scope_completion',
    'gap_analysis_scope_reconcillation',
    'punchlist_actions',
    'technical_debt_management',
    'identify_staff_ops_team',
    'salvage_disposal_team',
  };

  static const Set<String> _initiationSectionCheckpoints = <String>{
    'business_case',
    'potential_solutions',
    'risk_identification',
    'it_considerations',
    'infrastructure_considerations',
    'core_stakeholders',
    'cost_analysis',
    'preferred_solution_analysis',
  };

  static const List<String> _estimateSections = <String>[
    'cost_analysis',
    'cost_estimate',
    'project_charter',
  ];

  static const List<String> _scheduleSections = <String>[
    'schedule',
    'project_charter',
  ];

  static const List<String> _trainingSections = <String>[
    'team_training',
    'project_charter',
  ];

  static ProjectDataModel rebuildActivityLog(ProjectDataModel data) {
    final now = DateTime.now();
    final hiddenIds = data.hiddenProjectActivityIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet();
    final existingById = <String, ProjectActivity>{
      for (final activity in data.projectActivities) activity.id: activity,
    };
    for (final activity in data.customProjectActivities) {
      final id = activity.id.trim();
      if (id.isEmpty) continue;
      existingById.putIfAbsent(id, () => activity);
    }
    final nextById = <String, ProjectActivity>{};

    void upsert(ProjectActivity draft) {
      final existing = existingById[draft.id];
      nextById[draft.id] = _mergeLifecycle(draft, existing);
    }

    _upsertInitiationActivities(
      data: data,
      now: now,
      existingById: existingById,
      upsert: upsert,
    );

    for (final item in data.frontEndPlanning.opportunityItems) {
      final title = item.opportunity.trim();
      if (title.isEmpty) continue;

      final details = <String>[];
      if (item.potentialCostSavings.trim().isNotEmpty) {
        details
            .add('Potential cost savings: ${item.potentialCostSavings.trim()}');
      }
      if (item.potentialScheduleSavings.trim().isNotEmpty) {
        details.add('Schedule impact: ${item.potentialScheduleSavings.trim()}');
      }
      if (item.implementationStrategy.trim().isNotEmpty) {
        details.add(
            'Implementation strategy: ${item.implementationStrategy.trim()}');
      }
      if (item.applicablePhase.trim().isNotEmpty) {
        details.add('Applicable phase: ${item.applicablePhase.trim()}');
      }
      if (item.status.trim().isNotEmpty) {
        details.add('Status: ${item.status.trim()}');
      }
      final description = details.isEmpty
          ? 'Opportunity identified in Front End Planning.'
          : details.join(' | ');

      final role = item.responsibleRole.trim().isNotEmpty
          ? item.responsibleRole.trim()
          : item.stakeholder.trim();
      final owner = item.owner.trim().isNotEmpty
          ? item.owner.trim()
          : item.assignedTo.trim();
      final phase = item.applicablePhase.trim().isNotEmpty
          ? item.applicablePhase.trim()
          : _phaseForSection('fep_opportunities');

      upsert(
        ProjectActivity(
          id: 'activity_opp_${item.id}',
          title: title,
          description: description,
          sourceSection: 'fep_opportunities',
          phase: phase,
          discipline: _fallback(item.discipline, 'Planning'),
          role: _fallback(role, 'Project Manager'),
          assignedTo: _nullable(owner),
          applicableSections:
              _resolveApplicableSections(item.appliesTo, 'fep_opportunities'),
          dueDate: '',
          status: ProjectActivityStatus.pending,
          approvalStatus: ProjectApprovalStatus.draft,
          createdAt: existingById['activity_opp_${item.id}']?.createdAt ?? now,
          updatedAt: now,
        ),
      );
    }

    for (final item in data.frontEndPlanning.allowanceItems) {
      final title = item.name.trim().isNotEmpty
          ? item.name.trim()
          : 'Allowance ${item.number.toString()}';
      if (title.trim().isEmpty) continue;

      final details = <String>[
        if (item.type.trim().isNotEmpty) 'Type: ${item.type.trim()}',
        if (item.amount > 0) 'Value: ${item.amount.toStringAsFixed(2)}',
        if (item.notes.trim().isNotEmpty) item.notes.trim(),
      ];
      final description = details.isEmpty
          ? 'Allowance identified in Front End Planning.'
          : details.join(' | ');

      upsert(
        ProjectActivity(
          id: 'activity_allow_${item.id}',
          title: title,
          description: description,
          sourceSection: 'fep_allowance',
          phase: _phaseForSection('fep_allowance'),
          discipline: _fallback(item.type, 'Finance'),
          role: 'Cost Engineer',
          assignedTo: _nullable(item.assignedTo),
          applicableSections:
              _resolveApplicableSections(item.appliesTo, 'fep_allowance'),
          dueDate: '',
          status: ProjectActivityStatus.pending,
          approvalStatus: ProjectApprovalStatus.draft,
          createdAt:
              existingById['activity_allow_${item.id}']?.createdAt ?? now,
          updatedAt: now,
        ),
      );
    }

    for (var i = 0; i < data.frontEndPlanning.requirementItems.length; i++) {
      final item = data.frontEndPlanning.requirementItems[i];
      final title = item.description.trim();
      if (title.isEmpty) continue;

      final detailParts = <String>[
        if (item.comments.trim().isNotEmpty) item.comments.trim(),
        if (item.requirementSource.trim().isNotEmpty)
          'Source: ${item.requirementSource.trim()}',
        if (item.requirementType.trim().isNotEmpty)
          'Type: ${item.requirementType.trim()}',
      ];

      upsert(
        ProjectActivity(
          id: 'activity_req_$i',
          title: title,
          description: detailParts.isEmpty
              ? 'Requirement identified.'
              : detailParts.join(' | '),
          sourceSection: 'fep_requirements',
          phase: _fallback(item.phase, _phaseForSection('fep_requirements')),
          discipline: _fallback(
              item.discipline, _fallback(item.requirementType, 'Engineering')),
          role: _fallback(item.role, 'Requirements Owner'),
          assignedTo: _nullable(item.person),
          applicableSections: const <String>[
            'project_charter',
            'project_framework',
            'requirements_implementation',
          ],
          dueDate: '',
          status: ProjectActivityStatus.pending,
          approvalStatus: ProjectApprovalStatus.draft,
          createdAt: existingById['activity_req_$i']?.createdAt ?? now,
          updatedAt: now,
        ),
      );
    }

    for (var i = 0; i < data.frontEndPlanning.riskRegisterItems.length; i++) {
      final item = data.frontEndPlanning.riskRegisterItems[i];
      final title = item.riskName.trim();
      if (title.isEmpty) continue;

      final details = <String>[
        if (item.category.trim().isNotEmpty) 'Category: ${item.category}',
        if (item.requirement.trim().isNotEmpty)
          'Requirement: ${item.requirement}',
        if (item.impactLevel.trim().isNotEmpty) 'Impact: ${item.impactLevel}',
        if (item.likelihood.trim().isNotEmpty) 'Likelihood: ${item.likelihood}',
        if (item.mitigationStrategy.trim().isNotEmpty)
          'Mitigation: ${item.mitigationStrategy}',
      ];

      upsert(
        ProjectActivity(
          id: 'activity_risk_$i',
          title: title,
          description: details.isEmpty
              ? _fallback(
                  item.description, 'Risk identified in Front End Planning.')
              : details.join(' | '),
          sourceSection: 'fep_risks',
          phase: _phaseForSection('fep_risks'),
          discipline: _fallback(item.discipline, 'Risk Management'),
          role: _fallback(item.projectRole, 'Risk Owner'),
          assignedTo: _nullable(item.owner),
          applicableSections: const <String>[
            'project_charter',
            'risk_assessment',
            'schedule',
          ],
          dueDate: '',
          status: ProjectActivityStatus.pending,
          approvalStatus: ProjectApprovalStatus.draft,
          createdAt: existingById['activity_risk_$i']?.createdAt ?? now,
          updatedAt: now,
        ),
      );
    }

    _upsertDashboardItems(
      items: data.withinScopeItems,
      prefix: 'scope_in',
      sourceSection: 'fep_summary_within_scope',
      discipline: 'Planning',
      role: 'Project Manager',
      applicableSections: const <String>[
        'project_charter',
        'project_framework',
        'work_breakdown_structure',
      ],
      now: now,
      existingById: existingById,
      upsert: upsert,
    );

    _upsertDashboardItems(
      items: data.outOfScopeItems,
      prefix: 'scope_out',
      sourceSection: 'fep_summary_out_of_scope',
      discipline: 'Planning',
      role: 'Project Manager',
      applicableSections: const <String>[
        'project_charter',
        'scope_tracking_plan',
      ],
      now: now,
      existingById: existingById,
      upsert: upsert,
    );

    _upsertDashboardItems(
      items: data.assumptionItems,
      prefix: 'assumption',
      sourceSection: 'fep_summary_assumptions',
      discipline: 'Planning',
      role: 'Project Manager',
      applicableSections: const <String>[
        'project_charter',
        'risk_assessment',
        'project_plan',
      ],
      now: now,
      existingById: existingById,
      upsert: upsert,
    );

    _upsertDashboardItems(
      items: data.constraintItems,
      prefix: 'constraint',
      sourceSection: 'fep_summary_constraints',
      discipline: 'Planning',
      role: 'Project Manager',
      applicableSections: const <String>[
        'project_charter',
        'risk_assessment',
        'cost_estimate',
      ],
      now: now,
      existingById: existingById,
      upsert: upsert,
    );

    _upsertExecutionActivities(
      data: data,
      now: now,
      existingById: existingById,
      upsert: upsert,
    );

    final customById = <String, ProjectActivity>{
      for (final activity in data.customProjectActivities)
        if (activity.id.trim().isNotEmpty) activity.id.trim(): activity,
    };
    for (final activity in data.projectActivities) {
      final id = activity.id.trim();
      if (!_isCustomActivityId(id) || customById.containsKey(id)) {
        continue;
      }
      customById[id] = activity;
    }

    for (final custom in customById.values) {
      final id = custom.id.trim();
      if (id.isEmpty || hiddenIds.contains(id)) continue;

      final existing = existingById[id];
      nextById[id] = custom.copyWith(
        title: _fallback(custom.title, 'Custom Activity'),
        description: _fallback(custom.description, 'Custom activity entry.'),
        sourceSection: _fallback(custom.sourceSection, 'manual_activity'),
        phase: _fallback(custom.phase, 'Planning Phase'),
        discipline: _fallback(custom.discipline, 'Project Management'),
        role: _fallback(custom.role, 'Project Lead'),
        assignedTo: custom.assignedTo,
        applicableSections: custom.applicableSections,
        dueDate: custom.dueDate,
        status: custom.status,
        approvalStatus: custom.approvalStatus,
        createdAt: existing?.createdAt ?? custom.createdAt,
        updatedAt: custom.updatedAt,
      );
    }

    if (hiddenIds.isNotEmpty) {
      nextById.removeWhere((id, _) => hiddenIds.contains(id));
    }

    final activities = nextById.values.toList()
      ..sort((a, b) {
        final sourceOrder = a.sourceSection.compareTo(b.sourceSection);
        if (sourceOrder != 0) return sourceOrder;
        return a.title.compareTo(b.title);
      });

    return data.copyWith(
      projectActivities: activities,
      customProjectActivities: customById.values.toList(),
      hiddenProjectActivityIds: hiddenIds.toList(),
    );
  }

  static String buildContextScan(ProjectDataModel data,
      {String? sectionLabel}) {
    final buffer = StringBuffer();
    final activities = data.projectActivities;

    void writeField(String label, String value) {
      final text = value.trim();
      if (text.isEmpty) return;
      buffer.writeln('$label: $text');
    }

    buffer.writeln('Project Context Scan');
    buffer.writeln('====================');
    writeField('Project Name', data.projectName);
    writeField('Solution Title', data.solutionTitle);
    writeField('Business Case', data.businessCase);
    writeField('Project Objective', data.projectObjective);
    writeField('Charter Assumptions', data.charterAssumptions);
    writeField('Charter Constraints', data.charterConstraints);

    if (data.withinScopeItems.isNotEmpty) {
      buffer.writeln('Within Scope:');
      for (final item in data.withinScopeItems) {
        final text = item.description.trim();
        if (text.isNotEmpty) buffer.writeln('- $text');
      }
    }

    if (data.frontEndPlanning.requirementItems.isNotEmpty) {
      buffer.writeln('Requirements:');
      for (final item in data.frontEndPlanning.requirementItems) {
        final text = item.description.trim();
        if (text.isNotEmpty) buffer.writeln('- $text');
      }
    }

    if (data.frontEndPlanning.riskRegisterItems.isNotEmpty) {
      buffer.writeln('Risks:');
      for (final item in data.frontEndPlanning.riskRegisterItems) {
        final text = item.riskName.trim();
        if (text.isNotEmpty) buffer.writeln('- $text');
      }
    }

    if (activities.isNotEmpty) {
      final pending =
          activities.where((a) => a.status == ProjectActivityStatus.pending);
      final implemented = activities
          .where((a) => a.status == ProjectActivityStatus.implemented);
      buffer.writeln(
          'Activity Summary: total=${activities.length}, pending=${pending.length}, implemented=${implemented.length}');
    }

    if ((sectionLabel ?? '').trim().isNotEmpty) {
      writeField('Target Section', sectionLabel!);
    }

    return buffer.toString().trim();
  }

  static void _upsertDashboardItems({
    required List<PlanningDashboardItem> items,
    required String prefix,
    required String sourceSection,
    required String discipline,
    required String role,
    required List<String> applicableSections,
    required DateTime now,
    required Map<String, ProjectActivity> existingById,
    required void Function(ProjectActivity draft) upsert,
  }) {
    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      final title = item.description.trim();
      if (title.isEmpty) continue;
      final id = 'activity_${prefix}_$i';

      upsert(
        ProjectActivity(
          id: id,
          title: title,
          description: title,
          sourceSection: sourceSection,
          phase: _phaseForSection(sourceSection),
          discipline: discipline,
          role: role,
          assignedTo: null,
          applicableSections: applicableSections,
          dueDate: '',
          status: ProjectActivityStatus.pending,
          approvalStatus: ProjectApprovalStatus.draft,
          createdAt: existingById[id]?.createdAt ?? now,
          updatedAt: now,
        ),
      );
    }
  }

  static void _upsertInitiationActivities({
    required ProjectDataModel data,
    required DateTime now,
    required Map<String, ProjectActivity> existingById,
    required void Function(ProjectActivity draft) upsert,
  }) {
    for (var i = 0; i < data.potentialSolutions.length; i++) {
      final item = data.potentialSolutions[i];
      final title = item.title.trim().isNotEmpty
          ? item.title.trim()
          : 'Potential Solution ${item.number}';
      if (title.trim().isEmpty) continue;

      final idSeed = item.id.trim().isNotEmpty ? item.id.trim() : '$i';
      final id = 'activity_init_solution_$idSeed';
      final description = item.description.trim().isNotEmpty
          ? item.description.trim()
          : 'Potential solution identified during Initiation.';

      upsert(
        ProjectActivity(
          id: id,
          title: title,
          description: description,
          sourceSection: 'potential_solutions',
          phase: _phaseForSection('potential_solutions'),
          discipline: 'Strategy',
          role: 'Project Lead',
          assignedTo: null,
          applicableSections: const <String>[
            'preferred_solution_analysis',
            'fep_summary',
            'project_charter',
          ],
          dueDate: '',
          status: ProjectActivityStatus.pending,
          approvalStatus: ProjectApprovalStatus.draft,
          createdAt: existingById[id]?.createdAt ?? now,
          updatedAt: now,
        ),
      );
    }

    for (var solutionIndex = 0;
        solutionIndex < data.solutionRisks.length;
        solutionIndex++) {
      final solutionRisk = data.solutionRisks[solutionIndex];
      final solutionTitle = solutionRisk.solutionTitle.trim().isNotEmpty
          ? solutionRisk.solutionTitle.trim()
          : 'Solution ${solutionIndex + 1}';
      for (var riskIndex = 0;
          riskIndex < solutionRisk.risks.length;
          riskIndex++) {
        final riskText = solutionRisk.risks[riskIndex].trim();
        if (riskText.isEmpty) continue;
        final id = 'activity_init_risk_${solutionIndex}_$riskIndex';
        upsert(
          ProjectActivity(
            id: id,
            title: riskText,
            description: 'Risk identified for $solutionTitle.',
            sourceSection: 'risk_identification',
            phase: _phaseForSection('risk_identification'),
            discipline: 'Risk Management',
            role: 'Risk Owner',
            assignedTo: null,
            applicableSections: const <String>[
              'preferred_solution_analysis',
              'fep_risks',
              'risk_assessment',
            ],
            dueDate: '',
            status: ProjectActivityStatus.pending,
            approvalStatus: ProjectApprovalStatus.draft,
            createdAt: existingById[id]?.createdAt ?? now,
            updatedAt: now,
          ),
        );
      }
    }
  }

  static void _upsertExecutionActivities({
    required ProjectDataModel data,
    required DateTime now,
    required Map<String, ProjectActivity> existingById,
    required void Function(ProjectActivity draft) upsert,
  }) {
    final executionData = data.executionPhaseData;
    if (executionData == null) return;

    final outline = executionData.executionPlanOutline?.trim() ?? '';
    if (outline.isNotEmpty) {
      const id = 'activity_exec_outline';
      upsert(
        ProjectActivity(
          id: id,
          title: 'Execution Plan Outline',
          description: outline,
          sourceSection: 'execution_plan',
          phase: _phaseForSection('execution_plan'),
          discipline: 'Execution',
          role: 'Execution Manager',
          assignedTo: null,
          applicableSections: const <String>[
            'execution_plan',
            'schedule',
            'project_charter',
          ],
          dueDate: '',
          status: ProjectActivityStatus.pending,
          approvalStatus: ProjectApprovalStatus.draft,
          createdAt: existingById[id]?.createdAt ?? now,
          updatedAt: now,
        ),
      );
    }

    final strategy = executionData.executionPlanStrategy?.trim() ?? '';
    if (strategy.isNotEmpty) {
      const id = 'activity_exec_strategy';
      upsert(
        ProjectActivity(
          id: id,
          title: 'Execution Plan Strategy',
          description: strategy,
          sourceSection: 'execution_plan_strategy',
          phase: _phaseForSection('execution_plan_strategy'),
          discipline: 'Execution',
          role: 'Execution Manager',
          assignedTo: null,
          applicableSections: const <String>[
            'execution_plan',
            'project_plan',
            'project_charter',
          ],
          dueDate: '',
          status: ProjectActivityStatus.pending,
          approvalStatus: ProjectApprovalStatus.draft,
          createdAt: existingById[id]?.createdAt ?? now,
          updatedAt: now,
        ),
      );
    }

    executionData.sectionData.forEach((sectionKey, rows) {
      final normalizedSection = sectionKey.trim();
      final sourceSection =
          normalizedSection.isNotEmpty ? normalizedSection : 'execution_plan';
      final sectionLabel = _humanizeSection(sourceSection);
      final applicableSections = <String>{
        sourceSection,
        'execution_plan',
        'project_charter',
      }.toList();

      for (var i = 0; i < rows.length; i++) {
        final row = rows[i];
        final title = row.title.trim();
        final details = row.details.trim();
        if (title.isEmpty && details.isEmpty) continue;

        final rowTitle =
            title.isNotEmpty ? title : '$sectionLabel activity ${i + 1}';
        final rowDescription = details.isNotEmpty
            ? details
            : 'Execution activity captured in $sectionLabel.';
        final id = 'activity_exec_${_slugToken(sourceSection)}_$i';

        upsert(
          ProjectActivity(
            id: id,
            title: rowTitle,
            description: rowDescription,
            sourceSection: sourceSection,
            phase: _phaseForSection(sourceSection),
            discipline: sectionLabel,
            role: 'Execution Lead',
            assignedTo: null,
            applicableSections: applicableSections,
            dueDate: '',
            status: _statusFromExecutionEntry(row.status),
            approvalStatus: ProjectApprovalStatus.draft,
            createdAt: existingById[id]?.createdAt ?? now,
            updatedAt: now,
          ),
        );
      }
    });
  }

  static ProjectActivity _mergeLifecycle(
      ProjectActivity draft, ProjectActivity? existing) {
    if (existing == null) return draft;
    final preservedAssignedTo = draft.assignedTo ?? existing.assignedTo;
    final preservedDueDate =
        draft.dueDate.trim().isEmpty ? existing.dueDate : draft.dueDate;

    return draft.copyWith(
      assignedTo: preservedAssignedTo,
      dueDate: preservedDueDate,
      status: existing.status,
      approvalStatus: existing.approvalStatus,
      createdAt: existing.createdAt,
    );
  }

  static List<String> _resolveApplicableSections(
      List<String> tags, String sourceSection) {
    final sections = <String>{sourceSection, 'project_charter'};
    for (final tag in tags) {
      final normalized = tag.trim().toLowerCase();
      if (normalized == 'estimate') {
        sections.addAll(_estimateSections);
      } else if (normalized == 'schedule') {
        sections.addAll(_scheduleSections);
      } else if (normalized == 'training') {
        sections.addAll(_trainingSections);
      } else if (normalized == 'project wide' || normalized == 'projectwide') {
        sections.addAll(const <String>['project_plan', 'execution_plan']);
      }
    }
    final result = sections.toList()..sort();
    return result;
  }

  static String _phaseForSection(String sourceSection) {
    final normalized = sourceSection.trim().toLowerCase();
    if (normalized.startsWith('fep_')) return 'Front End Planning';
    if (_executionSectionCheckpoints.contains(normalized) ||
        normalized.startsWith('execution_') ||
        normalized.contains('execution')) {
      return 'Execution Phase';
    }
    if (normalized.startsWith('design_')) return 'Design Phase';
    if (normalized.contains('launch')) return 'Launch Phase';
    if (_initiationSectionCheckpoints.contains(normalized) ||
        normalized.startsWith('preferred_solution')) {
      return 'Initiation Phase';
    }
    if (normalized.contains('project_')) return 'Planning Phase';
    return 'Initiation Phase';
  }

  static String _fallback(String? value, String fallback) {
    final text = (value ?? '').trim();
    return text.isEmpty ? fallback : text;
  }

  static String? _nullable(String value) {
    final text = value.trim();
    return text.isEmpty ? null : text;
  }

  static String _humanizeSection(String value) {
    final normalized = value.replaceAll('_', ' ').trim();
    if (normalized.isEmpty) return 'Execution';
    return normalized
        .split(RegExp(r'\s+'))
        .map((word) => word.isEmpty
            ? word
            : '${word[0].toUpperCase()}${word.substring(1)}')
        .join(' ');
  }

  static String _slugToken(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
  }

  static bool _isCustomActivityId(String id) {
    return id.startsWith('activity_custom_');
  }

  static ProjectActivityStatus _statusFromExecutionEntry(String rawStatus) {
    final normalized = rawStatus.trim().toLowerCase();
    if (normalized.contains('implement') ||
        normalized.contains('complete') ||
        normalized.contains('closed') ||
        normalized == 'done') {
      return ProjectActivityStatus.implemented;
    }
    if (normalized.contains('acknowledge')) {
      return ProjectActivityStatus.acknowledged;
    }
    if (normalized.contains('reject')) {
      return ProjectActivityStatus.rejected;
    }
    if (normalized.contains('defer') || normalized.contains('hold')) {
      return ProjectActivityStatus.deferred;
    }
    return ProjectActivityStatus.pending;
  }
}
