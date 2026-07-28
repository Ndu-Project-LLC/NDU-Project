import 'package:flutter/material.dart';
import 'package:ndu_project/models/design_phase_models.dart';
import 'package:ndu_project/providers/project_data_provider.dart';
import 'package:ndu_project/models/project_data_model.dart';
import 'package:ndu_project/models/project_activity.dart';
import 'package:ndu_project/models/staffing_row.dart';
import 'package:ndu_project/services/project_intelligence_service.dart';
import 'package:ndu_project/services/sidebar_navigation_service.dart';
import 'package:ndu_project/utils/phase_transition_helper.dart';
import 'package:ndu_project/wbs/models/wbs_models.dart';
import 'package:ndu_project/cost_estimate/models/cost_estimate_models.dart';
import 'package:provider/provider.dart';

/// Helper functions for easy integration of ProjectDataProvider across screens
class ProjectDataHelper {
  /// The last project name observed by [buildProjectContextScan] or
  /// [captureProjectName]. Used as a fallback by modules whose `setup()`
  /// methods don't have access to a [BuildContext] (e.g. the Cost Estimate
  /// provider's [CostEstimateProvider.setup] method).
  static String? _lastKnownProjectName;
  static String? get lastKnownProjectName => _lastKnownProjectName;

  /// Capture the current project name so later modules (Cost Estimate,
  /// Schedule) can read it without a [BuildContext].
  static void captureProjectName(String? name) {
    final trimmed = (name ?? '').trim();
    if (trimmed.isEmpty) return;
    _lastKnownProjectName = trimmed;
  }

  /// Read the project name from the [ProjectDataProvider] in [context], if
  /// available, and update [lastKnownProjectName]. Returns the name (or null
  /// if no provider is in scope or the name is empty).
  static String? readProjectNameFromContext(BuildContext context) {
    final provider = ProjectDataInherited.maybeOf(context);
    if (provider == null) return _lastKnownProjectName;
    final name = provider.projectData.projectName.trim();
    if (name.isNotEmpty) {
      _lastKnownProjectName = name;
    }
    return _lastKnownProjectName;
  }

  static ProjectMethodology? projectMethodologyFromOverallFramework(
      String? framework) {
    final normalized = (framework ?? '').trim().toLowerCase();
    if (normalized == 'agile') return ProjectMethodology.agile;
    if (normalized == 'hybrid') return ProjectMethodology.hybrid;
    if (normalized == 'waterfall') return ProjectMethodology.waterfall;
    return null;
  }

  static String? overallFrameworkFromMethodology(ProjectMethodology? method) {
    switch (method) {
      case ProjectMethodology.agile:
        return 'Agile';
      case ProjectMethodology.hybrid:
        return 'Hybrid';
      case ProjectMethodology.waterfall:
        return 'Waterfall';
      case null:
        return null;
    }
  }

  static ProjectMethodology resolvedProjectMethodology(ProjectDataModel data) {
    final management = data.designManagementData;
    if (management != null) return management.methodology;
    return projectMethodologyFromOverallFramework(data.overallFramework) ??
        ProjectMethodology.waterfall;
  }

  /// Check if a destination checkpoint is locked/not accessible
  /// Returns true if the destination is locked, false if accessible
  static bool isDestinationLocked(
      BuildContext context, String destinationCheckpoint) {
    final provider = Provider.of<ProjectDataProvider>(context, listen: false);

    final projectData = provider.projectData;
    final currentCheckpoint = projectData.currentCheckpoint;

    // Check if it's a Basic Plan locked item
    const basicPlanLockedCheckpoints = {
      'fep_contract_vendor_quotes',
      'fep_security',
      'fep_allowance',
      'work_breakdown_structure',
      'interface_management',
      'project_baseline',
      'project_plan_level1_schedule',
      'project_plan_detailed_schedule',
      'project_plan_condensed_summary',
      'team_management',
      'staff_team',
      'update_ops_maintenance_plans',
      'gap_analysis_scope_reconcillation',
      'punchlist_actions',
      'salvage_disposal_team',
      'engineering_design',
      'specialized_design',
      'technical_development',
      'project_summary',
      'warranties_operations_support',
      'project_financial_review',
    };

    if (projectData.isBasicPlanProject &&
        basicPlanLockedCheckpoints.contains(destinationCheckpoint)) {
      return true;
    }

    // Check if checkpoint has been reached
    if (currentCheckpoint.isEmpty) {
      // Only allow first checkpoint if no progress
      return destinationCheckpoint !=
          SidebarNavigationService.instance.getNextItem(null)?.checkpoint;
    }

    return !SidebarNavigationService.instance
        .isCheckpointReached(destinationCheckpoint, currentCheckpoint);
  }

  /// Show a message when user tries to navigate to a locked destination
  static void showLockedDestinationMessage(
      BuildContext context, String destinationName) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            'Please complete the current requirements before accessing $destinationName.'),
        backgroundColor: Colors.orange,
        duration: const Duration(seconds: 3),
        action: SnackBarAction(
          label: 'OK',
          textColor: Colors.white,
          onPressed: () {},
        ),
      ),
    );
  }

  /// Show a message when required data is missing
  static void showMissingDataMessage(BuildContext context, String message) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.orange,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  /// Save current screen data and navigate to next screen with automatic Firebase sync
  /// Includes security check to prevent navigation to locked destinations
  static Future<void> saveAndNavigate({
    required BuildContext context,
    required String checkpoint,
    required Widget Function() nextScreenBuilder,
    ProjectDataModel Function(ProjectDataModel)? dataUpdater,
    String?
        destinationCheckpoint, // Optional: checkpoint of destination screen for lock checking
    String? destinationName, // Optional: human-readable name for error messages
    bool saveInBackground = false, // Opt-in: navigate immediately, save async
  }) async {
    final provider = Provider.of<ProjectDataProvider>(context, listen: false);

    // Security check: Verify destination is not locked
    if (destinationCheckpoint != null &&
        isDestinationLocked(context, destinationCheckpoint)) {
      showLockedDestinationMessage(context, destinationName ?? 'the next page');
      return; // Block navigation
    }

    // Update data if updater is provided
    if (dataUpdater != null) {
      provider.updateField(dataUpdater);
    }

    if (saveInBackground) {
      // Update checkpoint in-memory so downstream widgets can reflect progress
      // immediately without waiting on network IO.
      provider
          .updateField((data) => data.copyWith(currentCheckpoint: checkpoint));

      // Navigate immediately to reduce perceived latency.
      if (context.mounted) {
        PhaseTransitionHelper.pushPhaseAware(
          context: context,
          builder: (_) => nextScreenBuilder(),
          destinationCheckpoint: destinationCheckpoint,
          sourceCheckpoint: checkpoint,
        );
      }

      // Save in the background (no UI blocking). We intentionally avoid showing
      // snackbars here because the source context may be disposed after nav.
      Future<void>(() async {
        try {
          final success = await provider.saveToFirebase(checkpoint: checkpoint);
          if (!success) {
            debugPrint(
              'Warning: ${provider.lastError ?? "Could not save data"} (background save)',
            );
          }
        } catch (e) {
          debugPrint('Background save error: $e');
        }
      });

      return;
    }

    // Save to Firebase (blocking)
    final success = await provider.saveToFirebase(checkpoint: checkpoint);

    if (!success && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text('Warning: ${provider.lastError ?? "Could not save data"}'),
          backgroundColor: Colors.orange,
        ),
      );
    }

    // Navigate to next screen
    if (context.mounted) {
      PhaseTransitionHelper.pushPhaseAware(
        context: context,
        builder: (_) => nextScreenBuilder(),
        destinationCheckpoint: destinationCheckpoint,
        sourceCheckpoint: checkpoint,
      );
    }
  }

  /// Build a compact, structured context string for Front End Planning prompts.
  /// This aggregates prior inputs across the project to enable high‑quality AI suggestions.
  ///
  /// When [wbs] and/or [costEstimate] are provided, the scan is enriched with
  /// a WBS structure section (framework + Level 1/2 node names) and a Cost
  /// Estimate summary (total + top cost lines), so AI prompts on later pages
  /// (Cost Estimate, Schedule, etc.) can reference the WBS and cost data.
  static String buildProjectContextScan(
    ProjectDataModel data, {
    String? sectionLabel,
    WBS? wbs,
    CostEstimate? costEstimate,
  }) {
    // Capture the latest project name so modules without a BuildContext
    // (e.g. CostEstimateProvider.setup) can read it later.
    captureProjectName(data.projectName);

    final enriched = ProjectIntelligenceService.rebuildActivityLog(data);
    final base = ProjectIntelligenceService.buildContextScan(
      enriched,
      sectionLabel: sectionLabel,
    );

    final wbsSection = wbs != null ? _wbsContextSection(wbs) : '';
    final costSection =
        costEstimate != null ? _costEstimateContextSection(costEstimate) : '';

    final parts = <String>[
      base,
      if (wbsSection.isNotEmpty) wbsSection,
      if (costSection.isNotEmpty) costSection,
    ];
    return parts.where((s) => s.trim().isNotEmpty).join('\n\n');
  }

  /// Build a compact WBS summary section for inclusion in AI context scans.
  /// Shows the framework, project name, and Level 1 / Level 2 node names so
  /// downstream AI prompts can reference the WBS structure.
  static String _wbsContextSection(WBS wbs) {
    final buf = StringBuffer();
    final counts = countNodes(wbs);
    buf.writeln('Work Breakdown Structure');
    buf.writeln('------------------------');
    buf.writeln('Project: ${wbs.projectName}');
    buf.writeln('Framework: ${wbs.framework.label}');
    buf.writeln(
        'Levels: ${counts.level1} ${wbs.framework.level1Label} · ${counts.level2} ${wbs.framework.level2Label}');
    if (wbs.level0.children.isNotEmpty) {
      buf.writeln('${wbs.framework.level1Label}:');
      for (final l1 in wbs.level0.children) {
        buf.writeln('- ${l1.code} ${l1.name}');
        if (l1.children.isNotEmpty) {
          for (final l2 in l1.children) {
            buf.writeln('    · ${l2.code} ${l2.name}');
          }
        }
      }
    }
    return buf.toString().trim();
  }

  /// Build a compact Cost Estimate summary section for inclusion in AI
  /// context scans. Shows the project name, estimate class, total, and the
  /// top cost lines by amount so later pages can reference cost data.
  static String _costEstimateContextSection(CostEstimate estimate) {
    final buf = StringBuffer();
    buf.writeln('Cost Estimate');
    buf.writeln('-------------');
    buf.writeln('Project: ${estimate.projectName}');
    buf.writeln('Class: ${estimate.className.label} (${estimate.className.name})');
    buf.writeln('Delivery model: ${estimate.deliveryModel.label}');
    buf.writeln('Status: ${estimate.status.label}');
    buf.writeln('Currency: ${estimate.currency}');
    final total = estimate.lines.fold<double>(
        0, (s, l) => s + _effectiveLineTotalForContext(l));
    buf.writeln('Total: ${total.toStringAsFixed(2)} ${estimate.currency}');
    buf.writeln('Lines: ${estimate.lines.length}');
    if (estimate.lines.isNotEmpty) {
      final sorted = [...estimate.lines]
        ..sort((a, b) => _effectiveLineTotalForContext(b)
            .compareTo(_effectiveLineTotalForContext(a)));
      final top = sorted.take(8).toList();
      buf.writeln('Top cost lines:');
      for (final l in top) {
        final wbsRef = (l.wbsRef ?? '').trim();
        final refSuffix = wbsRef.isEmpty ? '' : ' [WBS: $wbsRef]';
        buf.writeln(
            '- ${l.category.label} · ${l.description}$refSuffix · ${_effectiveLineTotalForContext(l).toStringAsFixed(2)} ${estimate.currency}');
      }
    }
    return buf.toString().trim();
  }

  /// Mirror of [ComputeUtils] effective line total — kept private to avoid
  /// importing the cost estimate compute utils from this helper (which would
  /// create a circular dependency in some downstream import graphs).
  static double _effectiveLineTotalForContext(CostLine l) {
    if (l.varianceType == VarianceType.remove) {
      return -(l.varianceBaselineTotal ?? 0);
    }
    if (l.varianceType == VarianceType.change) {
      return l.varianceDelta ?? 0;
    }
    return l.total;
  }

  static List<String> _formatInterfaceEntriesForContext(
      List<InterfaceEntry> entries) {
    final formatted = <String>[];
    for (final entry in entries) {
      final boundary = entry.boundary.trim().isNotEmpty
          ? entry.boundary.trim()
          : 'Unnamed interface';
      final details = [
        if (entry.owner.trim().isNotEmpty) 'Owner: ${entry.owner.trim()}',
        if (entry.cadence.trim().isNotEmpty) 'Cadence: ${entry.cadence.trim()}',
        if (entry.risk.trim().isNotEmpty) 'Risk: ${entry.risk.trim()}',
        if (entry.status.trim().isNotEmpty) 'Status: ${entry.status.trim()}',
        if (entry.lastSync.trim().isNotEmpty)
          'Last sync: ${entry.lastSync.trim()}',
        if (entry.notes.trim().isNotEmpty) 'Notes: ${entry.notes.trim()}',
      ].join(' | ');
      final entryText = details.isNotEmpty ? '$boundary | $details' : boundary;
      formatted.add(entryText);
    }
    return formatted;
  }

  static String buildFepContext(ProjectDataModel data, {String? sectionLabel}) {
    final buf = StringBuffer();
    void w(String label, String? value) {
      final v = (value ?? '').trim();
      if (v.isEmpty) return;
      buf.writeln('$label:');
      buf.writeln(v);
      buf.writeln();
    }

    buf.writeln('Project Context');
    buf.writeln('================');
    w('Project Name', data.projectName);
    w('Solution Title', data.solutionTitle);
    w('Solution Description', data.solutionDescription);
    w('Business Case', data.businessCase);
    w('Initiation Notes', data.notes);
    w('Potential Solution', data.potentialSolution);
    w('Project Objective', data.projectObjective);
    w('Overall Framework', data.overallFramework);

    if (data.projectGoals.isNotEmpty) {
      buf.writeln('Project Goals:');
      for (final g in data.projectGoals) {
        final name = (g.name).trim();
        final desc = (g.description).trim();
        if (name.isEmpty && desc.isEmpty) continue;
        buf.writeln(
            '- ${name.isEmpty ? 'Goal' : name}: ${desc.isEmpty ? '' : desc}');
      }
      buf.writeln();
    }

    if (data.planningGoals.isNotEmpty) {
      buf.writeln('Planning Goals:');
      for (final g in data.planningGoals) {
        final title = (g.title).trim();
        final desc = (g.description).trim();
        final year = (g.targetYear).trim();
        if (title.isEmpty && desc.isEmpty && year.isEmpty) continue;
        buf.writeln(
            '- ${title.isEmpty ? 'Goal ${g.goalNumber}' : title} (${year.isEmpty ? 'n/a' : year}): $desc');
      }
      buf.writeln();
    }

    if (data.keyMilestones.isNotEmpty) {
      buf.writeln('Key Milestones:');
      for (final m in data.keyMilestones) {
        final name = (m.name).trim();
        final due = (m.dueDate).trim();
        final discipline = (m.discipline).trim();
        if (name.isEmpty && due.isEmpty && discipline.isEmpty) continue;
        buf.writeln(
            '- ${name.isEmpty ? 'Milestone' : name} | Due: ${due.isEmpty ? 'TBD' : due} | ${discipline.isEmpty ? '' : 'Discipline: $discipline'}');
      }
      buf.writeln();
    }

    if (data.planningNotes.isNotEmpty) {
      buf.writeln('Planning Phase Notes:');
      data.planningNotes.forEach((key, value) {
        final v = value.trim();
        if (v.isEmpty) return;
        buf.writeln('- ${key.trim()}: $v');
      });
      buf.writeln();
    }

    // Include any prior Front End Planning fields already provided
    final fep = data.frontEndPlanning;
    w('Front End Planning – Requirements Notes', fep.requirementsNotes);
    w('Front End Planning – Requirements', fep.requirements);
    w('Front End Planning – Risks', fep.risks);
    w('Front End Planning – Opportunities', fep.opportunities);
    w('Front End Planning – Contracting', fep.contractVendorQuotes);
    w('Front End Planning – Procurement', fep.procurement);
    w('Front End Planning – Security', fep.security);
    w('Front End Planning – Allowance', fep.allowance);
    w('Front End Planning – Summary', fep.summary);
    w('Front End Planning – Technology', fep.technology);
    w('Front End Planning – Personnel', fep.personnel);
    w('Front End Planning – Infrastructure', fep.infrastructure);

    final interfaceEntriesContext =
        _formatInterfaceEntriesForContext(data.interfaceEntries);
    if (interfaceEntriesContext.isNotEmpty) {
      buf.writeln('Interface Register:');
      for (final entry in interfaceEntriesContext) {
        buf.writeln('- $entry');
      }
      buf.writeln();
    }

    if ((sectionLabel ?? '').isNotEmpty) {
      buf.writeln('Target Section: ${sectionLabel!.trim()}');
    }

    return buf.toString().trim();
  }

  /// Build context for AI-generated Project Objective summaries.
  /// Includes charter inputs and front-end planning details without reusing
  /// an existing objective to avoid circular summaries.
  static String buildProjectObjectiveContext(ProjectDataModel data) {
    final buf = StringBuffer();

    void w(String label, String? value) {
      final v = (value ?? '').trim();
      if (v.isEmpty) return;
      buf.writeln('$label:');
      buf.writeln(v);
      buf.writeln();
    }

    void wList(String label, Iterable<String> items) {
      final list =
          items.map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
      if (list.isEmpty) return;
      buf.writeln('$label:');
      for (final item in list) {
        buf.writeln('- $item');
      }
      buf.writeln();
    }

    buf.writeln('Project Context');
    buf.writeln('================');
    w('Project Name', data.projectName);
    w('Solution Title', data.solutionTitle);
    w('Solution Description', data.solutionDescription);
    w('Business Case', data.businessCase);
    w('Initiation Notes', data.notes);
    w('Potential Solution', data.potentialSolution);
    w('Overall Framework', data.overallFramework);

    w('Charter Assumptions', data.charterAssumptions);
    w('Charter Constraints', data.charterConstraints);

    if (data.projectGoals.isNotEmpty) {
      final items = data.projectGoals.map((g) {
        final name = g.name.trim().isEmpty ? 'Goal' : g.name.trim();
        final desc = g.description.trim();
        return desc.isEmpty ? name : '$name: $desc';
      });
      wList('Project Goals', items);
    }

    if (data.planningGoals.isNotEmpty) {
      final items = data.planningGoals.map((g) {
        final title =
            g.title.trim().isEmpty ? 'Goal ${g.goalNumber}' : g.title.trim();
        final year = g.targetYear.trim();
        final desc = g.description.trim();
        final suffix = [
          if (year.isNotEmpty) 'Target: $year',
          if (desc.isNotEmpty) desc,
        ].join(' | ');
        return suffix.isEmpty ? title : '$title ($suffix)';
      });
      wList('Planning Goals', items);
    }

    if (data.keyMilestones.isNotEmpty) {
      final items = data.keyMilestones.map((m) {
        final name = m.name.trim().isNotEmpty ? m.name.trim() : 'Milestone';
        final due = m.dueDate.trim();
        final discipline = m.discipline.trim();
        final details = [
          if (due.isNotEmpty) 'Due: $due',
          if (discipline.isNotEmpty) 'Discipline: $discipline',
        ].join(' | ');
        return details.isEmpty ? name : '$name ($details)';
      });
      wList('Key Milestones', items);
    }

    wList('Within Scope', data.withinScopeItems.map((e) => e.description));
    wList('Out of Scope', data.outOfScopeItems.map((e) => e.description));
    wList('Assumptions', data.assumptionItems.map((e) => e.description));
    wList('Constraints', data.constraintItems.map((e) => e.description));

    if (data.planningNotes.isNotEmpty) {
      final items = data.planningNotes.entries
          .where((e) => e.value.trim().isNotEmpty)
          .map((e) => '${e.key}: ${e.value}');
      wList('Planning Notes', items);
    }

    final fep = data.frontEndPlanning;
    w('Front End Planning – Requirements Notes', fep.requirementsNotes);
    w('Front End Planning – Requirements', fep.requirements);
    w('Front End Planning – Risks', fep.risks);
    w('Front End Planning – Opportunities', fep.opportunities);
    w('Front End Planning – Contracting', fep.contractVendorQuotes);
    w('Front End Planning – Procurement', fep.procurement);
    w('Front End Planning – Security', fep.security);
    w('Front End Planning – Allowance', fep.allowance);
    w('Front End Planning – Summary', fep.summary);
    w('Front End Planning – Technology', fep.technology);
    w('Front End Planning – Personnel', fep.personnel);
    w('Front End Planning – Infrastructure', fep.infrastructure);

    final interfaceEntriesContext =
        _formatInterfaceEntriesForContext(data.interfaceEntries);
    if (interfaceEntriesContext.isNotEmpty) {
      buf.writeln('Interface Register:');
      for (final entry in interfaceEntriesContext) {
        buf.writeln('- $entry');
      }
      buf.writeln();
    }

    buf.writeln('Target Section: Project Objective Summary');
    return buf.toString().trim();
  }

  /// Build a richer, cross-application context string for executive plan diagrams.
  /// Includes only populated fields to avoid noise and random output.
  static String buildExecutivePlanContext(ProjectDataModel data,
      {String? sectionLabel}) {
    final buf = StringBuffer();
    var hasContent = false;

    String clamp(String value, {int max = 420}) {
      final trimmed = value.trim();
      if (trimmed.length <= max) return trimmed;
      return '${trimmed.substring(0, max - 3)}...';
    }

    void w(String label, String? value) {
      final v = clamp(value ?? '');
      if (v.isEmpty) return;
      hasContent = true;
      buf.writeln('$label:');
      buf.writeln(v);
      buf.writeln();
    }

    void wList(String label, Iterable<String> items) {
      final list = items.map(clamp).where((e) => e.isNotEmpty).toList();
      if (list.isEmpty) return;
      hasContent = true;
      buf.writeln('$label:');
      for (final item in list) {
        buf.writeln('- $item');
      }
      buf.writeln();
    }

    buf.writeln('Project Context');
    buf.writeln('================');
    w('Project Name', data.projectName);
    w('Solution Title', data.solutionTitle);
    w('Solution Description', data.solutionDescription);
    w('Business Case', data.businessCase);
    w('Project Objective', data.projectObjective);
    w('Overall Framework', data.overallFramework);
    w('Notes', data.notes);
    wList('Tags', data.tags);

    if (data.projectGoals.isNotEmpty) {
      final items = data.projectGoals.map((g) {
        final name = g.name.trim().isEmpty ? 'Goal' : g.name.trim();
        final desc = g.description.trim();
        return desc.isEmpty ? name : '$name: $desc';
      });
      wList('Project Goals', items);
    }

    if (data.planningGoals.isNotEmpty) {
      final items = data.planningGoals.map((g) {
        final title =
            g.title.trim().isEmpty ? 'Goal ${g.goalNumber}' : g.title.trim();
        final year = g.targetYear.trim();
        final desc = g.description.trim();
        final suffix = [
          if (year.isNotEmpty) 'Target: $year',
          if (desc.isNotEmpty) desc,
        ].join(' | ');
        return suffix.isEmpty ? title : '$title ($suffix)';
      });
      wList('Planning Goals', items);
    }

    if (data.keyMilestones.isNotEmpty) {
      final items = data.keyMilestones.map((m) {
        final name = m.name.trim().isEmpty ? 'Milestone' : m.name.trim();
        final due = m.dueDate.trim();
        final discipline = m.discipline.trim();
        final details = [
          if (due.isNotEmpty) 'Due: $due',
          if (discipline.isNotEmpty) 'Discipline: $discipline',
        ].join(' | ');
        return details.isEmpty ? name : '$name ($details)';
      });
      wList('Key Milestones', items);
    }

    if (data.planningNotes.isNotEmpty) {
      final items = data.planningNotes.entries
          .where((e) => e.value.trim().isNotEmpty)
          .map((e) => '${e.key}: ${e.value}');
      wList('Planning Notes', items);
    }

    if (data.potentialSolutions.isNotEmpty) {
      final items = data.potentialSolutions.map((s) {
        final title = s.title.trim().isEmpty ? 'Solution' : s.title.trim();
        final desc = s.description.trim();
        return desc.isEmpty ? title : '$title: $desc';
      });
      wList('Potential Solutions', items);
    }

    final preferred = data.preferredSolutionAnalysis;
    if (preferred != null) {
      w('Selected Solution', preferred.selectedSolutionTitle);
      w('Preferred Solution Notes', preferred.workingNotes);
    }

    if (data.solutionRisks.isNotEmpty) {
      final items = <String>[];
      for (final r in data.solutionRisks) {
        final title = r.solutionTitle.trim().isEmpty
            ? 'Solution'
            : r.solutionTitle.trim();
        final risks =
            r.risks.map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
        if (risks.isEmpty) continue;
        items.add('$title: ${risks.join('; ')}');
      }
      wList('Key Risks', items);
    }

    if ((data.wbsCriteriaA ?? '').trim().isNotEmpty ||
        (data.wbsCriteriaB ?? '').trim().isNotEmpty) {
      w('WBS Criteria A', data.wbsCriteriaA);
      w('WBS Criteria B', data.wbsCriteriaB);
    }

    if (data.goalWorkItems.isNotEmpty) {
      final items = <String>[];
      for (var i = 0; i < data.goalWorkItems.length; i++) {
        final list = data.goalWorkItems[i]
            .where((w) => w.title.trim().isNotEmpty)
            .toList();
        if (list.isEmpty) continue;
        final sample = list.take(3).map((w) => w.title.trim()).join(', ');
        items.add('Goal ${i + 1} Work Items: $sample');
      }
      wList('Work Breakdown Highlights', items);
    }

    // Include Execution Phase Data
    final exec = data.executionPhaseData;
    if (exec != null) {
      w('Execution Plan Outline', exec.executionPlanOutline);
      w('Execution Plan Strategy', exec.executionPlanStrategy);
    }

    final fep = data.frontEndPlanning;
    w('Front End Planning – Requirements', fep.requirements);
    w('Front End Planning – Risks', fep.risks);
    w('Front End Planning – Opportunities', fep.opportunities);
    w('Front End Planning – Contracting', fep.contractVendorQuotes);
    w('Front End Planning – Procurement', fep.procurement);
    w('Front End Planning – Security', fep.security);
    w('Front End Planning – Allowance', fep.allowance);
    w('Front End Planning – Summary', fep.summary);
    w('Front End Planning – Technology', fep.technology);
    w('Front End Planning – Personnel', fep.personnel);
    w('Front End Planning – Infrastructure', fep.infrastructure);
    w('Front End Planning – Contracts', fep.contracts);
    wList('Interface Register',
        _formatInterfaceEntriesForContext(data.interfaceEntries));

    // Section-specific context for Interface Management Plan
    if ((sectionLabel ?? '').trim().toLowerCase().contains('interface management plan')) {
      w('Stakeholder Management Notes',
          data.planningNotes['stakeholder_management_plan']);
      w('Additional Interfaces Identified',
          data.planningNotes['additional_interfaces']);

      if (data.vendors.isNotEmpty) {
        final items = data.vendors.map((v) {
          final name = v.name.trim();
          final svc = v.equipmentOrService.trim();
          return svc.isEmpty ? name : '$name ($svc)';
        }).where((e) => e.isNotEmpty);
        wList('Vendors & Contractors', items);
      }

      if (data.contractors.isNotEmpty) {
        final items = data.contractors.map((c) {
          final name = c.name.trim();
          final svc = c.service.trim();
          return svc.isEmpty ? name : '$name: $svc';
        }).where((e) => e.isNotEmpty);
        wList('Contractors', items);
      }

      final fep = data.frontEndPlanning;
      w('FEP Contracting', fep.contractVendorQuotes);
      w('FEP Procurement', fep.procurement);
    }

    if (data.teamMembers.isNotEmpty) {
      final items = data.teamMembers.map((m) {
        final name = m.name.trim();
        final role = m.role.trim();
        final resp = m.responsibilities.trim();
        final base = [name, role].where((e) => e.isNotEmpty).join(' - ');
        return resp.isEmpty ? base : '$base: $resp';
      }).where((e) => e.isNotEmpty);
      wList('Team Members', items);
    }

    final stakeholders = data.coreStakeholdersData;
    if (stakeholders != null) {
      w('Core Stakeholders Notes', stakeholders.notes);
      if (stakeholders.solutionStakeholderData.isNotEmpty) {
        final items = stakeholders.solutionStakeholderData.map((s) {
          final title = s.solutionTitle.trim().isEmpty
              ? 'Solution'
              : s.solutionTitle.trim();
          final notable = s.notableStakeholders.trim();
          return notable.isEmpty ? title : '$title: $notable';
        });
        wList('Notable Stakeholders', items);
      }
    }

    final it = data.itConsiderationsData;
    if (it != null) {
      w('IT Considerations Notes', it.notes);
      if (it.solutionITData.isNotEmpty) {
        final items = it.solutionITData.map((s) {
          final title = s.solutionTitle.trim().isEmpty
              ? 'Solution'
              : s.solutionTitle.trim();
          final tech = s.coreTechnology.trim();
          return tech.isEmpty ? title : '$title: $tech';
        });
        wList('Core Technologies', items);
      }
    }

    final infra = data.infrastructureConsiderationsData;
    if (infra != null) {
      w('Infrastructure Notes', infra.notes);
      if (infra.solutionInfrastructureData.isNotEmpty) {
        final items = infra.solutionInfrastructureData.map((s) {
          final title = s.solutionTitle.trim().isEmpty
              ? 'Solution'
              : s.solutionTitle.trim();
          final major = s.majorInfrastructure.trim();
          return major.isEmpty ? title : '$title: $major';
        });
        wList('Major Infrastructure', items);
      }
    }

    final cost = data.costAnalysisData;
    if (cost != null) {
      w('Project Value Target', cost.projectValueAmount);
      w('Savings Target', cost.savingsTarget);
      w('Savings Notes', cost.savingsNotes);
      if (cost.benefitLineItems.isNotEmpty) {
        final items = cost.benefitLineItems.map((b) {
          final title = b.title.trim().isEmpty ? 'Benefit' : b.title.trim();
          final units = b.units.trim();
          final unitValue = b.unitValue.trim();
          final details = [
            if (unitValue.isNotEmpty) 'Unit: $unitValue',
            if (units.isNotEmpty) 'Units: $units',
          ].join(' | ');
          return details.isEmpty ? title : '$title ($details)';
        });
        wList('Project Benefits', items.take(6));
      }
    }

    final ssher = data.ssherData;
    if (ssher.entries.isNotEmpty) {
      final items = ssher.entries.map((entry) {
        final concern =
            entry.concern.trim().isEmpty ? 'SSHER Item' : entry.concern.trim();
        final category = entry.category.trim();
        return category.isEmpty ? concern : '$concern ($category)';
      });
      wList('SSHER Items', items);
    } else if (ssher.safetyItems.isNotEmpty) {
      final items = ssher.safetyItems.map((s) {
        final title = s.title.trim().isEmpty ? 'Safety Item' : s.title.trim();
        final category = s.category.trim();
        return category.isEmpty ? title : '$title ($category)';
      });
      wList('SSHER Safety Items', items);
    }
    w('SSHER Notes', ssher.screen1Data);
    w('SSHER Notes (2)', ssher.screen2Data);
    w('SSHER Notes (3)', ssher.screen3Data);
    w('SSHER Notes (4)', ssher.screen4Data);

    if ((sectionLabel ?? '').trim().isNotEmpty) {
      buf.writeln('Target Section: ${sectionLabel!.trim()}');
      buf.writeln();
    }

    if (!hasContent) return '';
    return buf.toString().trim();
  }

  /// Build launch-phase context by appending execution data summaries
  /// to the base context from buildExecutivePlanContext.
  /// All parameters are optional summaries pre-loaded from Firestore.
  static String buildLaunchPhaseContext({
    required String baseContext,
    String? sectionLabel,
    String? staffingSummary,
    String? contractsSummary,
    String? vendorsSummary,
    String? deliverablesSummary,
    String? budgetSummary,
    String? scopeTrackingSummary,
    String? riskTrackingSummary,
    String? sprintsSummary,
  }) {
    final buf = StringBuffer();
    buf.write(baseContext);
    buf.writeln();
    buf.writeln();

    buf.writeln('Execution Phase Data');
    buf.writeln('=====================');

    if (staffingSummary != null && staffingSummary.trim().isNotEmpty) {
      buf.writeln();
      buf.writeln('Staffing:');
      buf.writeln(staffingSummary.trim());
    }

    if (contractsSummary != null && contractsSummary.trim().isNotEmpty) {
      buf.writeln();
      buf.writeln('Contracts:');
      buf.writeln(contractsSummary.trim());
    }

    if (vendorsSummary != null && vendorsSummary.trim().isNotEmpty) {
      buf.writeln();
      buf.writeln('Vendors:');
      buf.writeln(vendorsSummary.trim());
    }

    if (deliverablesSummary != null && deliverablesSummary.trim().isNotEmpty) {
      buf.writeln();
      buf.writeln('Deliverables:');
      buf.writeln(deliverablesSummary.trim());
    }

    if (budgetSummary != null && budgetSummary.trim().isNotEmpty) {
      buf.writeln();
      buf.writeln('Budget:');
      buf.writeln(budgetSummary.trim());
    }

    if (scopeTrackingSummary != null &&
        scopeTrackingSummary.trim().isNotEmpty) {
      buf.writeln();
      buf.writeln('Scope Tracking:');
      buf.writeln(scopeTrackingSummary.trim());
    }

    if (riskTrackingSummary != null && riskTrackingSummary.trim().isNotEmpty) {
      buf.writeln();
      buf.writeln('Risk Tracking:');
      buf.writeln(riskTrackingSummary.trim());
    }

    if (sprintsSummary != null && sprintsSummary.trim().isNotEmpty) {
      buf.writeln();
      buf.writeln('Sprints/Milestones:');
      buf.writeln(sprintsSummary.trim());
    }

    if ((sectionLabel ?? '').trim().isNotEmpty) {
      buf.writeln();
      buf.writeln('Target Section: ${sectionLabel!.trim()}');
    }

    return buf.toString().trim();
  }

  /// Get project data from context (non-listening by default, safe for event handlers)
  static ProjectDataModel getData(BuildContext context, {bool listen = false}) {
    return Provider.of<ProjectDataProvider>(context, listen: listen)
        .projectData;
  }

  /// Get project data with listening (use only in build methods)
  static ProjectDataModel getDataListening(BuildContext context) {
    return Provider.of<ProjectDataProvider>(context).projectData;
  }

  /// Get provider from context
  static ProjectDataProvider getProvider(BuildContext context) {
    return Provider.of<ProjectDataProvider>(context, listen: false);
  }

  /// Update and save data without navigation
  static Future<bool> updateAndSave({
    required BuildContext context,
    required String checkpoint,
    required ProjectDataModel Function(ProjectDataModel) dataUpdater,
    bool showSnackbar = true,
  }) async {
    final provider = Provider.of<ProjectDataProvider>(context, listen: false);
    provider.updateField(dataUpdater);

    final success = await provider.saveToFirebase(checkpoint: checkpoint);

    if (!success && context.mounted && showSnackbar) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text('Error: ${provider.lastError ?? "Could not save data"}'),
          backgroundColor: Colors.red,
        ),
      );
    } else if (success && context.mounted && showSnackbar) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Data saved successfully'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 1),
        ),
      );
    }

    return success;
  }

  // ── Bidirectional Risk Register Sync ──
  //
  // Section-specific risks (e.g. Interface Management, SSHER, Design) are
  // mirrored into the central `frontEndPlanning.riskRegisterItems` list with
  // a `sourceSection` tag. Updates to either side propagate to the other.

  /// Upserts a risk into the central Risk Register, tagged with its source
  /// section via `requirementType`. The `category` field is preserved for
  /// user/discipline classification (e.g. 'Safety', 'Contractual').
  /// De-duplication matches on `riskName + requirementType` (the sourceSection).
  static Future<void> upsertRiskToRegister({
    required BuildContext context,
    required String sourceSection,
    required String riskName,
    String description = '',
    String category = '',
    String impactLevel = 'Medium',
    String likelihood = 'Medium',
    String mitigationStrategy = '',
    String discipline = '',
    String owner = '',
    String status = 'Open',
    String checkpoint = 'risk_register_sync',
  }) async {
    await updateAndSave(
      context: context,
      checkpoint: checkpoint,
      showSnackbar: false,
      dataUpdater: (d) {
        final items = List<RiskRegisterItem>.from(
            d.frontEndPlanning.riskRegisterItems);
        final idx = items.indexWhere((r) =>
            r.riskName.trim().toLowerCase() == riskName.trim().toLowerCase() &&
            r.requirementType.trim().toLowerCase() ==
                sourceSection.trim().toLowerCase());
        if (idx >= 0) {
          // Update existing — preserve category if caller didn't provide one
          items[idx] = RiskRegisterItem(
            riskName: riskName,
            description: description.isNotEmpty ? description : items[idx].description,
            category: category.isNotEmpty ? category : items[idx].category,
            requirement: items[idx].requirement,
            requirementType: sourceSection,
            impactLevel: impactLevel,
            likelihood: likelihood,
            mitigationStrategy: mitigationStrategy.isNotEmpty
                ? mitigationStrategy
                : items[idx].mitigationStrategy,
            discipline: discipline.isNotEmpty ? discipline : items[idx].discipline,
            projectRole: items[idx].projectRole,
            owner: owner.isNotEmpty ? owner : items[idx].owner,
            status: status,
            probabilityNumeric: items[idx].probabilityNumeric,
            costImpactMin: items[idx].costImpactMin,
            costImpactMostLikely: items[idx].costImpactMostLikely,
            costImpactMax: items[idx].costImpactMax,
            scheduleImpactMin: items[idx].scheduleImpactMin,
            scheduleImpactMostLikely: items[idx].scheduleImpactMostLikely,
            scheduleImpactMax: items[idx].scheduleImpactMax,
            controlAccountId: items[idx].controlAccountId,
            cbsId: items[idx].cbsId,
            riskType: items[idx].riskType,
            responseStrategy: items[idx].responseStrategy,
            residualProbability: items[idx].residualProbability,
            residualCostImpact: items[idx].residualCostImpact,
          );
        } else {
          items.add(RiskRegisterItem(
            riskName: riskName,
            description: description,
            category: category.isNotEmpty ? category : sourceSection,
            requirementType: sourceSection,
            impactLevel: impactLevel,
            likelihood: likelihood,
            mitigationStrategy: mitigationStrategy,
            discipline: discipline,
            owner: owner,
            status: status,
          ));
        }
        return d.copyWith(
          frontEndPlanning:
              d.frontEndPlanning.copyWith(riskRegisterItems: items),
        );
      },
    );
  }

  /// Removes a risk from the central register by name + source section.
  /// Used when a section-specific risk is deleted.
  static Future<void> removeRiskFromRegister({
    required BuildContext context,
    required String sourceSection,
    required String riskName,
    String checkpoint = 'risk_register_sync',
  }) async {
    await updateAndSave(
      context: context,
      checkpoint: checkpoint,
      showSnackbar: false,
      dataUpdater: (d) {
        final items = List<RiskRegisterItem>.from(
            d.frontEndPlanning.riskRegisterItems);
        items.removeWhere((r) =>
            r.riskName.trim().toLowerCase() == riskName.trim().toLowerCase() &&
            r.requirementType.trim().toLowerCase() ==
                sourceSection.trim().toLowerCase());
        return d.copyWith(
          frontEndPlanning:
              d.frontEndPlanning.copyWith(riskRegisterItems: items),
        );
      },
    );
  }

  /// Returns all risks from the central register that originate from a
  /// specific source section (matched on `requirementType`).
  static List<RiskRegisterItem> getRisksForSection(
      ProjectDataModel data, String sourceSection) {
    return data.frontEndPlanning.riskRegisterItems
        .where((r) =>
            r.requirementType.trim().toLowerCase() ==
                sourceSection.trim().toLowerCase())
        .toList();
  }

  /// One-time migration: backfills `requirementType` on existing risks that
  /// have no source-section tag. Uses category heuristics to infer the
  /// originating section. Called on project load.
  static ProjectDataModel migrateRiskSourceSections(ProjectDataModel data) {
    final items = data.frontEndPlanning.riskRegisterItems;
    if (items.isEmpty) return data;
    bool changed = false;
    final migrated = items.map((r) {
      final rt = r.requirementType.trim();
      if (rt.isNotEmpty) return r;
      // Infer from category
      final cat = r.category.trim().toLowerCase();
      String inferred;
      if (cat == 'safety' ||
          cat == 'security' ||
          cat == 'health' ||
          cat == 'environment' ||
          cat == 'regulatory') {
        inferred = 'SSHER';
      } else if (cat.contains('interface')) {
        inferred = 'Interface Management';
      } else if (cat.contains('design')) {
        inferred = 'Design Planning';
      } else if (cat.contains('quality')) {
        inferred = 'Quality';
      } else if (cat.contains('execution') || cat.contains('tracking')) {
        inferred = 'Risk Tracking Workspace';
      } else {
        inferred = 'Front End Planning';
      }
      changed = true;
      return RiskRegisterItem(
        riskName: r.riskName,
        description: r.description,
        category: r.category,
        requirement: r.requirement,
        requirementType: inferred,
        impactLevel: r.impactLevel,
        likelihood: r.likelihood,
        mitigationStrategy: r.mitigationStrategy,
        discipline: r.discipline,
        projectRole: r.projectRole,
        owner: r.owner,
        status: r.status,
        probabilityNumeric: r.probabilityNumeric,
        costImpactMin: r.costImpactMin,
        costImpactMostLikely: r.costImpactMostLikely,
        costImpactMax: r.costImpactMax,
        scheduleImpactMin: r.scheduleImpactMin,
        scheduleImpactMostLikely: r.scheduleImpactMostLikely,
        scheduleImpactMax: r.scheduleImpactMax,
        controlAccountId: r.controlAccountId,
        cbsId: r.cbsId,
        riskType: r.riskType,
        responseStrategy: r.responseStrategy,
        residualProbability: r.residualProbability,
        residualCostImpact: r.residualCostImpact,
      );
    }).toList();
    if (!changed) return data;
    return data.copyWith(
      frontEndPlanning:
          data.frontEndPlanning.copyWith(riskRegisterItems: migrated),
    );
  }

  // ── Bidirectional Activities Log Sync ──
  //
  // Section-specific register/log actions (e.g. interface created, SSHER
  // item pushed, quality check added) are mirrored into the central
  // `ProjectData.activities` list with a `sourceSection` tag.

  /// Logs an activity to the central Project Activities Log with a
  /// sourceSection tag for traceability. De-duplicates by title +
  /// sourceSection within the same day.
  static Future<void> logActivityToCentral({
    required BuildContext context,
    required String sourceSection,
    required String title,
    String description = '',
    String phase = 'Planning',
    String discipline = '',
    String role = '',
    String assignedTo = '',
    String dueDate = '',
    String status = 'pending',
    String checkpoint = 'activities_log_sync',
  }) async {
    await updateAndSave(
      context: context,
      checkpoint: checkpoint,
      showSnackbar: false,
      dataUpdater: (d) {
        final activities = List<ProjectActivity>.from(d.projectActivities);
        // De-dup: skip if an activity with the same title + sourceSection
        // was already logged today
        final today = DateTime.now();
        final alreadyLogged = activities.any((a) =>
            a.title == title &&
            a.sourceSection == sourceSection &&
            a.createdAt.year == today.year &&
            a.createdAt.month == today.month &&
            a.createdAt.day == today.day);
        if (alreadyLogged) return d;
        final now = DateTime.now();
        activities.add(ProjectActivity(
          id: now.microsecondsSinceEpoch.toString(),
          title: title,
          description: description,
          sourceSection: sourceSection,
          phase: phase,
          discipline: discipline,
          role: role,
          assignedTo: assignedTo.isEmpty ? null : assignedTo,
          dueDate: dueDate,
          createdAt: now,
          updatedAt: now,
        ));
        return d.copyWith(projectActivities: activities);
      },
    );
  }

  /// Returns all activities from the central log that originated from a
  /// specific source section.
  static List<ProjectActivity> getActivitiesForSection(
      ProjectDataModel data, String sourceSection) {
    return data.projectActivities
        .where((a) =>
            a.sourceSection.trim().toLowerCase() ==
                sourceSection.trim().toLowerCase())
        .toList();
  }


  static List<ProjectGoal> convertLegacyGoals(
      List<Map<String, String>>? legacyGoals) {
    if (legacyGoals == null || legacyGoals.isEmpty) return [];

    return legacyGoals
        .map((g) => ProjectGoal(
              name: g['name'] ?? g['title'] ?? '',
              description: g['description'] ?? '',
              framework: g['framework'],
            ))
        .toList();
  }

  /// Convert legacy planning goals to new format
  static List<PlanningGoal> convertLegacyPlanningGoals(
      List<Map<String, String>>? legacyGoals) {
    if (legacyGoals == null || legacyGoals.isEmpty) {
      return List.generate(3, (i) => PlanningGoal(goalNumber: i + 1));
    }

    return legacyGoals.asMap().entries.map((entry) {
      final i = entry.key;
      final g = entry.value;
      return PlanningGoal(
        goalNumber: i + 1,
        title: g['title'] ?? '',
        description: g['description'] ?? '',
        targetYear: g['year'] ?? '',
      );
    }).toList();
  }

  /// Show saving indicator
  static void showSavingIndicator(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
            SizedBox(width: 12),
            Text('Saving...'),
          ],
        ),
        duration: Duration(seconds: 1),
      ),
    );
  }

  /// Helper to update Front End Planning data while preserving other fields
  static FrontEndPlanningData updateFEPField({
    required FrontEndPlanningData current,
    String? requirements,
    String? requirementsPlan,
    String? requirementsNotes,
    String? risks,
    String? opportunities,
    String? contractVendorQuotes,
    String? procurement,
    String? security,
    String? allowance,
    String? summary,
    String? technology,
    String? personnel,
    String? infrastructure,
    String? contracts,
    String? milestoneStartDate,
    String? milestoneEndDate,
    bool? milestoneSmeReviewStep1,
    bool? milestoneSmeReviewStep2,
    bool? charterApproved,
    DateTime? charterApprovedAt,
    bool? businessCaseLocked,
    bool? skippedBusinessCase,
    List<RequirementItem>? requirementItems,
    // Added optional list fields so screens can update persisted lists centrally
    List<ScenarioRecord>? scenarioMatrixItems,
    List<RoleItem>? securityRoles,
    List<PermissionItem>? securityPermissions,
    List<SecuritySetting>? securitySettings,
    List<AccessLogItem>? securityAccessLogs,
    List<DebtItem>? technicalDebtItems,
    List<DebtInsight>? technicalDebtRootCauses,
    List<RemediationTrack>? technicalDebtTracks,
    List<OwnerItem>? technicalDebtOwners,
    List<RiskRegisterItem>? riskRegisterItems,
    List<AllowanceItem>? allowanceItems,
    List<StaffingRow>? staffingRows,
    List<TechnologyPersonnelItem>? technologyPersonnelItems,
    List<InfrastructurePlanningItem>? infrastructureItems,
    List<OpportunityItem>? opportunityItems,
    List<PlanningDashboardItem>? successCriteriaItems,
    bool? detailsConfirmed,
  }) {
    return FrontEndPlanningData(
      requirements: requirements ?? current.requirements,
      requirementsPlan: requirementsPlan ?? current.requirementsPlan,
      requirementsNotes: requirementsNotes ?? current.requirementsNotes,
      risks: risks ?? current.risks,
      opportunities: opportunities ?? current.opportunities,
      contractVendorQuotes:
          contractVendorQuotes ?? current.contractVendorQuotes,
      procurement: procurement ?? current.procurement,
      security: security ?? current.security,
      allowance: allowance ?? current.allowance,
      summary: summary ?? current.summary,
      technology: technology ?? current.technology,
      personnel: personnel ?? current.personnel,
      infrastructure: infrastructure ?? current.infrastructure,
      contracts: contracts ?? current.contracts,
      milestoneStartDate: milestoneStartDate ?? current.milestoneStartDate,
      milestoneEndDate: milestoneEndDate ?? current.milestoneEndDate,
      milestoneSmeReviewStep1:
          milestoneSmeReviewStep1 ?? current.milestoneSmeReviewStep1,
      milestoneSmeReviewStep2:
          milestoneSmeReviewStep2 ?? current.milestoneSmeReviewStep2,
      charterApproved: charterApproved ?? current.charterApproved,
      charterApprovedAt: charterApprovedAt ?? current.charterApprovedAt,
      businessCaseLocked: businessCaseLocked ?? current.businessCaseLocked,
      skippedBusinessCase: skippedBusinessCase ?? current.skippedBusinessCase,
      requirementItems: requirementItems ?? current.requirementItems,
      // Preserve or replace list fields
      scenarioMatrixItems: scenarioMatrixItems ?? current.scenarioMatrixItems,
      securityRoles: securityRoles ?? current.securityRoles,
      securityPermissions: securityPermissions ?? current.securityPermissions,
      securitySettings: securitySettings ?? current.securitySettings,
      securityAccessLogs: securityAccessLogs ?? current.securityAccessLogs,
      technicalDebtItems: technicalDebtItems ?? current.technicalDebtItems,
      technicalDebtRootCauses:
          technicalDebtRootCauses ?? current.technicalDebtRootCauses,
      technicalDebtTracks: technicalDebtTracks ?? current.technicalDebtTracks,
      technicalDebtOwners: technicalDebtOwners ?? current.technicalDebtOwners,
      riskRegisterItems: riskRegisterItems ?? current.riskRegisterItems,
      allowanceItems: allowanceItems ?? current.allowanceItems,
      staffingRows: staffingRows ?? current.staffingRows,
      technologyPersonnelItems:
          technologyPersonnelItems ?? current.technologyPersonnelItems,
      infrastructureItems: infrastructureItems ?? current.infrastructureItems,
      opportunityItems: opportunityItems ?? current.opportunityItems,
      successCriteriaItems:
          successCriteriaItems ?? current.successCriteriaItems,
      detailsConfirmed: detailsConfirmed ?? current.detailsConfirmed,
    );
  }

  static const String _autoScheduleMarker = '[AUTO_APPLY_SCHEDULE]';
  static const String _autoTrainingOpportunityPrefix =
      'auto_apply_training_opp_';
  static const String _autoTrainingAllowancePrefix =
      'auto_apply_training_allow_';
  static const String _autoBenefitOpportunityPrefix = 'auto_apply_benefit_opp_';
  static const String _autoCostAllowancePrefix = 'auto_apply_cost_allow_';

  /// Applies Front End Planning "Apply To" mappings into downstream sections.
  ///
  /// - `Estimate`: creates auto benefit line items from opportunities and auto
  ///   cost estimate items from allowances.
  /// - `Schedule`: creates auto milestones.
  /// - `Training`: creates auto training activities.
  ///
  /// Auto-generated entries are refreshed each call and won't overwrite manual
  /// entries.
  static ProjectDataModel applyTaggedFrontEndPlanningData(
      ProjectDataModel data) {
    final fep = data.frontEndPlanning;

    final mergedMilestones =
        _mergeAutoScheduleMilestones(data.keyMilestones, fep);
    final mergedTraining =
        _mergeAutoTrainingActivities(data.trainingActivities, fep);
    final mergedCostAnalysis =
        _mergeAutoBenefitLineItems(data.costAnalysisData, fep);
    final mergedCostEstimates =
        _mergeAutoCostEstimateItems(data.costEstimateItems, fep);

    final merged = data.copyWith(
      keyMilestones: mergedMilestones,
      trainingActivities: mergedTraining,
      costAnalysisData: mergedCostAnalysis,
      costEstimateItems: mergedCostEstimates,
    );
    return ProjectIntelligenceService.rebuildActivityLog(merged);
  }

  /// Count of opportunities shown in charter snapshot.
  static int getExpectedOpportunitiesCount(ProjectDataModel data) {
    final structuredCount = data.frontEndPlanning.opportunityItems
        .where((o) => o.opportunity.trim().isNotEmpty)
        .length;
    if (structuredCount > 0) return structuredCount;
    return data.opportunities.where((o) => o.trim().isNotEmpty).length;
  }

  /// Sum opportunity savings, optionally only those tagged for `Estimate`.
  static double getOpportunitySavingsTotal(
    ProjectDataModel data, {
    bool estimateOnly = false,
  }) {
    return data.frontEndPlanning.opportunityItems
        .where((o) => o.opportunity.trim().isNotEmpty)
        .where((o) => !estimateOnly || _hasTag(o.appliesTo, 'Estimate'))
        .fold<double>(
            0.0, (sum, o) => sum + _parseNumericValue(o.potentialCostSavings));
  }

  /// Active cost estimate lines after state reconciliation.
  static List<CostEstimateItem> getActiveCostEstimateItems(
    ProjectDataModel data, {
    String? costState,
    bool includeBaseline = true,
  }) {
    final reconciled = _reconcileCostEstimateItems(data.costEstimateItems);
    return reconciled.where((item) {
      if (!includeBaseline && item.isBaseline) return false;
      if (costState != null && item.costState != costState) return false;
      return true;
    }).toList();
  }

  static double getCostEstimateTotalByState(
    ProjectDataModel data, {
    required String costState,
    bool includeBaseline = true,
  }) {
    return getActiveCostEstimateItems(
      data,
      costState: costState,
      includeBaseline: includeBaseline,
    ).fold<double>(0.0, (sum, item) => sum + item.amount);
  }

  static double getCombinedCostEstimateRollup(
    ProjectDataModel data, {
    bool includeBaseline = true,
  }) {
    return getActiveCostEstimateItems(
      data,
      includeBaseline: includeBaseline,
    ).fold<double>(0.0, (sum, item) => sum + item.amount);
  }

  /// Unified total estimated cost used by Project Charter.
  static double getTotalEstimatedCostValue(ProjectDataModel data) {
    final forecastTotal =
        getCostEstimateTotalByState(data, costState: 'forecast');
    if (forecastTotal > 0) return forecastTotal;

    final operationalTotal = data.contractors
            .fold<double>(0.0, (sum, item) => sum + item.estimatedCost) +
        data.vendors
            .fold<double>(0.0, (sum, item) => sum + item.estimatedPrice) +
        data.frontEndPlanning.allowanceItems
            .fold<double>(0.0, (sum, item) => sum + item.amount);
    if (operationalTotal > 0) return operationalTotal;

    final costAnalysisTotal = data.costAnalysisData?.solutionCosts.fold<double>(
            0.0,
            (sum, solution) =>
                sum +
                solution.costRows.fold<double>(0.0,
                    (rowSum, row) => rowSum + _parseNumericValue(row.cost))) ??
        0.0;

    return costAnalysisTotal;
  }

  static bool _hasTag(List<String> tags, String expected) {
    return tags.any((tag) => tag.toLowerCase() == expected.toLowerCase());
  }

  static String _withFallback(String raw, String fallback) {
    final text = raw.trim();
    return text.isNotEmpty ? text : fallback;
  }

  static double _parseNumericValue(String raw) {
    final cleaned = raw.replaceAll(',', '');
    final match = RegExp(r'-?\d+(?:\.\d+)?').firstMatch(cleaned);
    if (match == null) return 0.0;
    return double.tryParse(match.group(0) ?? '') ?? 0.0;
  }

  static String _buildAutoNote({
    required String source,
    String? owner,
    String? extra,
  }) {
    final parts = <String>[
      source,
      if ((owner ?? '').trim().isNotEmpty) 'Owner: ${owner!.trim()}',
      if ((extra ?? '').trim().isNotEmpty) extra!.trim(),
    ];
    return parts.join(' | ');
  }

  static List<Milestone> _mergeAutoScheduleMilestones(
    List<Milestone> current,
    FrontEndPlanningData fep,
  ) {
    final manual = current
        .where((m) => !m.comments.contains(_autoScheduleMarker))
        .toList();

    final generated = <Milestone>[];

    for (final opp in fep.opportunityItems) {
      if (!_hasTag(opp.appliesTo, 'Schedule')) continue;
      final title =
          _withFallback(opp.opportunity, 'Opportunity ${generated.length + 1}');
      final scheduleSavings = opp.potentialScheduleSavings.trim();
      final marker = '$_autoScheduleMarker | opp:${opp.id}';
      generated.add(
        Milestone(
          name: 'Opportunity: $title',
          discipline: _withFallback(opp.discipline, 'Planning'),
          dueDate: '',
          comments: _buildAutoNote(
            source: marker,
            owner: opp.assignedTo,
            extra: scheduleSavings.isNotEmpty
                ? 'Potential schedule savings: $scheduleSavings'
                : null,
          ),
        ),
      );
    }

    for (final allowance in fep.allowanceItems) {
      if (!_hasTag(allowance.appliesTo, 'Schedule')) continue;
      if (allowance.name.trim().isEmpty && allowance.notes.trim().isEmpty) {
        continue;
      }
      final title = _withFallback(
          allowance.name, 'Allowance ${allowance.number.toString()}');
      final marker = '$_autoScheduleMarker | allow:${allowance.id}';
      generated.add(
        Milestone(
          name: 'Allowance: $title',
          discipline: _withFallback(allowance.type, 'Planning'),
          dueDate: '',
          comments: _buildAutoNote(
            source: marker,
            owner: allowance.assignedTo,
            extra: allowance.notes.trim().isNotEmpty ? allowance.notes : null,
          ),
        ),
      );
    }

    return [...manual, ...generated];
  }

  static List<TrainingActivity> _mergeAutoTrainingActivities(
    List<TrainingActivity> current,
    FrontEndPlanningData fep,
  ) {
    final manual = current
        .where((activity) =>
            !activity.id.startsWith(_autoTrainingOpportunityPrefix) &&
            !activity.id.startsWith(_autoTrainingAllowancePrefix))
        .toList();

    final generated = <TrainingActivity>[];

    for (final opp in fep.opportunityItems) {
      if (!_hasTag(opp.appliesTo, 'Training')) continue;
      final title =
          _withFallback(opp.opportunity, 'Opportunity ${generated.length + 1}');
      final scheduleSavings = opp.potentialScheduleSavings.trim();
      generated.add(
        TrainingActivity(
          id: '$_autoTrainingOpportunityPrefix${opp.id}',
          title: 'Opportunity Follow-up: $title',
          description: _buildAutoNote(
            source: 'Auto-applied from Project Opportunities',
            owner: opp.assignedTo,
            extra: scheduleSavings.isNotEmpty
                ? 'Schedule context: $scheduleSavings'
                : null,
          ),
          category: 'Training',
          status: 'Upcoming',
          duration: '',
          isMandatory: false,
        ),
      );
    }

    for (final allowance in fep.allowanceItems) {
      if (!_hasTag(allowance.appliesTo, 'Training')) continue;
      final title = _withFallback(
          allowance.name, 'Allowance ${allowance.number.toString()}');
      generated.add(
        TrainingActivity(
          id: '$_autoTrainingAllowancePrefix${allowance.id}',
          title: 'Allowance Readiness: $title',
          description: _buildAutoNote(
            source: 'Auto-applied from Allowance',
            owner: allowance.assignedTo,
            extra: allowance.notes.trim().isNotEmpty
                ? allowance.notes.trim()
                : null,
          ),
          category: 'Training',
          status: 'Upcoming',
          duration: '',
          isMandatory: false,
        ),
      );
    }

    return [...manual, ...generated];
  }

  static CostAnalysisData? _mergeAutoBenefitLineItems(
    CostAnalysisData? current,
    FrontEndPlanningData fep,
  ) {
    final manualItems = (current?.benefitLineItems ?? const <BenefitLineItem>[])
        .where((item) => !item.id.startsWith(_autoBenefitOpportunityPrefix))
        .toList();

    final autoItems = <BenefitLineItem>[];
    for (final opp in fep.opportunityItems) {
      if (!_hasTag(opp.appliesTo, 'Estimate')) continue;
      // Only feed approved opportunities into the cost estimate
      if (opp.status.toLowerCase() != 'approved') continue;
      final savings = _parseNumericValue(opp.potentialCostSavings);
      if (savings <= 0) continue;

      autoItems.add(
        BenefitLineItem(
          id: '$_autoBenefitOpportunityPrefix${opp.id}',
          categoryKey: 'cost_saving',
          title: _withFallback(opp.opportunity, 'Opportunity savings'),
          unitValue: savings.toStringAsFixed(2),
          units: '1',
          notes: _buildAutoNote(
            source: 'Auto-applied from Project Opportunities',
            owner: opp.assignedTo,
            extra: opp.potentialCostSavings.trim(),
          ),
        ),
      );
    }

    final merged = [...manualItems, ...autoItems];
    if (current == null && merged.isEmpty) return null;

    final base = current ?? CostAnalysisData();
    return CostAnalysisData(
      notes: base.notes,
      solutionCosts: base.solutionCosts,
      projectValueAmount: base.projectValueAmount,
      projectValueBenefits: base.projectValueBenefits,
      benefitLineItems: merged,
      solutionProjectBenefits: base.solutionProjectBenefits,
      solutionCategoryCosts: base.solutionCategoryCosts,
      solutionCostAssumptions: base.solutionCostAssumptions,
      savingsNotes: base.savingsNotes,
      savingsTarget: base.savingsTarget,
      basisFrequency: base.basisFrequency,
      trackerBasisFrequency: base.trackerBasisFrequency,
      npvDiscountRate: base.npvDiscountRate,
      solutionSavingsSuggestions: base.solutionSavingsSuggestions,
    );
  }

  static List<CostEstimateItem> _mergeAutoCostEstimateItems(
    List<CostEstimateItem> current,
    FrontEndPlanningData fep,
  ) {
    final manualItems = current
        .where((item) => !item.id.startsWith(_autoCostAllowancePrefix))
        .toList();

    final autoItems = <CostEstimateItem>[];
    for (final allowance in fep.allowanceItems) {
      if (!_hasTag(allowance.appliesTo, 'Estimate')) continue;
      if (allowance.amount <= 0) continue;

      final title = _withFallback(
          allowance.name, 'Allowance ${allowance.number.toString()}');
      autoItems.add(
        CostEstimateItem(
          id: '$_autoCostAllowancePrefix${allowance.id}',
          title: 'Allowance: $title',
          notes: _buildAutoNote(
            source: 'Auto-applied from Allowance',
            owner: allowance.assignedTo,
            extra: allowance.notes.trim(),
          ),
          amount: allowance.amount,
          costType: 'indirect',
          source: 'planning_allowance',
          costState: 'forecast',
          estimatingMethod: 'top_down',
          estimatingBasis: 'Auto-applied from allowance register',
          contingencyAmount: allowance.amount,
          reconciliationReference: 'allowance:${allowance.id}',
        ),
      );
    }

    return [...manualItems, ...autoItems];
  }

  static List<CostEstimateItem> _reconcileCostEstimateItems(
      List<CostEstimateItem> items) {
    final grouped = <String, List<CostEstimateItem>>{};
    final passthrough = <CostEstimateItem>[];

    for (final item in items) {
      if (item.isBaseline || !_isAutoImportedCostSource(item.source)) {
        passthrough.add(item);
        continue;
      }
      final key = _reconciliationGroupKey(item);
      if (key == null) {
        passthrough.add(item);
        continue;
      }
      grouped.putIfAbsent(key, () => <CostEstimateItem>[]).add(item);
    }

    final reconciled = <CostEstimateItem>[...passthrough];
    for (final groupItems in grouped.values) {
      final highestPriority = groupItems
          .map(_costStatePriority)
          .fold<int>(0, (highest, value) => value > highest ? value : highest);
      reconciled.addAll(groupItems.where(
        (item) => _costStatePriority(item) == highestPriority,
      ));
    }
    return reconciled;
  }

  static bool _isAutoImportedCostSource(String source) {
    const autoSources = {
      'project_contractor',
      'project_vendor',
      'project_contract',
      'project_procurement_item',
      'project_procurement_actual',
      'project_purchase_order',
      'planning_allowance',
      'risk_mitigation',
      'project_work_package',
      'project_work_package_actual',
      'planning_staffing',
      'planning_infrastructure',
      'planning_technology',
    };
    return autoSources.contains(source);
  }

  static String? _reconciliationGroupKey(CostEstimateItem item) {
    if (item.reconciliationReference.trim().isNotEmpty) {
      return item.reconciliationReference.trim();
    }
    if (item.workPackageId.trim().isNotEmpty) {
      return 'work_package:${item.workPackageId.trim()}';
    }
    if (item.contractId.trim().isNotEmpty) {
      return 'contract:${item.contractId.trim()}';
    }
    final procurementId = _procurementRecordKey(item);
    if (procurementId != null) {
      return 'procurement:$procurementId';
    }
    return null;
  }

  static String? _procurementRecordKey(CostEstimateItem item) {
    const prefixes = {
      'src_procurement_actual_',
      'src_procurement_',
    };
    for (final prefix in prefixes) {
      if (item.id.startsWith(prefix)) {
        return item.id.substring(prefix.length);
      }
    }
    return null;
  }

  static int _costStatePriority(CostEstimateItem item) {
    switch (item.costState) {
      case 'actual':
        return 3;
      case 'committed':
        return 2;
      case 'forecast':
      default:
        return 1;
    }
  }
}
