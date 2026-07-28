import 'package:flutter/material.dart';
import 'package:ndu_project/models/launch_phase_models.dart';
import 'package:ndu_project/services/launch_phase_service.dart';
import 'package:ndu_project/services/openai_service_secure.dart';
import 'package:ndu_project/utils/project_data_helper.dart';

/// Provides comprehensive cross-phase context building and AI generation
/// for all nine Launch Phase screens.
///
/// Phase Dependency Chain:
///   Initiation → Front End Planning → Planning → Design → Execution → LAUNCH
///
/// Each Launch screen inherits data context from ALL prior phases so that
/// AI-generated content reflects the full project history.
class LaunchPhaseAiSeed {
  const LaunchPhaseAiSeed._();

  // ────────────────────────────────────────────────────────────────
  // 1. Cross-phase context builder
  // ────────────────────────────────────────────────────────────────

  /// Builds a rich, phase-dependency-aware context string for AI generation.
  ///
  /// This method:
  ///  1. Starts with the base context from [ProjectDataHelper.buildExecutivePlanContext]
  ///     which already includes Initiation, FEP, Planning, Design, and Execution data.
  ///  2. Augments it with live Firestore data from Execution Phase entries
  ///     (staffing, contracts, vendors, budget, deliverables, scope tracking, risks).
  ///  3. Adds Planning Phase sprints and deliverables if available.
  ///  4. Appends the target [sectionLabel] so the AI knows which section to generate.
  static Future<String> buildFullPhaseDependencyContext(
    BuildContext context, {
    required String sectionLabel,
  }) async {
    final projectData = ProjectDataHelper.getData(context);
    final projectId = projectData.projectId;

    // Base context covers Initiation + FEP + Planning + Design + Execution
    var contextText = ProjectDataHelper.buildExecutivePlanContext(
      projectData,
      sectionLabel: sectionLabel,
    );
    if (contextText.trim().isEmpty) {
      contextText = ProjectDataHelper.buildProjectContextScan(
        projectData,
        sectionLabel: sectionLabel,
      );
    }
    if (contextText.trim().isEmpty) return '';

    if (projectId == null || projectId.isEmpty) return contextText;

    // Load cross-phase data from Firestore
    final staffing = await LaunchPhaseService.loadExecutionStaffing(projectId);
    final contracts =
        await LaunchPhaseService.loadExecutionContracts(projectId);
    final vendors = await LaunchPhaseService.loadExecutionVendors(projectId);
    final budgetRows = await LaunchPhaseService.loadBudgetRows(projectId);
    final deliverableRows =
        await LaunchPhaseService.loadDeliverableRows(projectId);
    final scopeTracking =
        await LaunchPhaseService.loadScopeTrackingItems(projectId);
    final riskSnapshot =
        await LaunchPhaseService.loadRiskTrackingSnapshot(projectId);
    final planningDeliverables =
        await LaunchPhaseService.loadPlanningDeliverables(projectId);
    final planningSprints =
        await LaunchPhaseService.loadPlanningSprints(projectId);
    final stakeholders =
        await LaunchPhaseService.loadCoreStakeholders(projectId);

    // Format each cross-phase summary
    final staffingSummary = staffing.isEmpty
        ? null
        : staffing
            .map((s) =>
                '- ${s.name} (${s.role}, status: ${s.releaseStatus})')
            .take(10)
            .join('\n');

    final contractsSummary = contracts.isEmpty
        ? null
        : contracts
            .map((c) =>
                '- ${c.contractName} (vendor: ${c.vendor}, value: ${c.value}, status: ${c.closeOutStatus})')
            .take(10)
            .join('\n');

    final vendorsSummary = vendors.isEmpty
        ? null
        : vendors
            .map((v) =>
                '- ${v.vendorName} (ref: ${v.contractRef}, status: ${v.accountStatus})')
            .take(10)
            .join('\n');

    final budgetSummary = budgetRows.isEmpty
        ? null
        : budgetRows
            .map((b) =>
                '- ${b['category'] ?? 'Unknown'}: planned ${b['plannedAmount'] ?? '0'}, actual ${b['actualAmount'] ?? '0'}')
            .take(10)
            .join('\n');

    final deliverablesSummary = deliverableRows.isEmpty
        ? null
        : deliverableRows
            .map((d) =>
                '- ${d['title'] ?? 'Untitled'} (status: ${d['status'] ?? 'Unknown'})')
            .take(10)
            .join('\n');

    final scopeSummary = scopeTracking.isEmpty
        ? null
        : scopeTracking
            .map(
                (s) => '- ${s.deliverable} (status: ${s.status})')
            .take(10)
            .join('\n');

    String? riskSummary;
    final riskItems = riskSnapshot['riskItems'];
    if (riskItems is List && riskItems.isNotEmpty) {
      riskSummary = riskItems
          .whereType<Map>()
          .take(8)
          .map((r) =>
              '- ${r['title'] ?? r['risk'] ?? 'Unknown'} (status: ${r['status'] ?? 'Unknown'}, owner: ${r['owner'] ?? 'Unassigned'})')
          .join('\n');
    }

    String? sprintsSummary;
    if (planningSprints.isNotEmpty) {
      sprintsSummary = planningSprints
          .map((s) =>
              '- Sprint ${s['sprintNumber'] ?? s['name'] ?? '?'}: ${s['goal'] ?? s['title'] ?? ''} (status: ${s['status'] ?? 'Unknown'})')
          .take(6)
          .join('\n');
    }

    String? stakeholdersSummary;
    if (stakeholders.isNotEmpty) {
      stakeholdersSummary = stakeholders
          .map((s) =>
              '- ${s['name'] ?? s['title'] ?? 'Stakeholder'} (${s['role'] ?? 'Role'})')
          .take(8)
            .join('\n');
    }

    // Build the augmented context
    contextText = ProjectDataHelper.buildLaunchPhaseContext(
      baseContext: contextText,
      sectionLabel: sectionLabel,
      staffingSummary: staffingSummary,
      contractsSummary: contractsSummary,
      vendorsSummary: vendorsSummary,
      budgetSummary: budgetSummary,
      deliverablesSummary: deliverablesSummary,
      scopeTrackingSummary: scopeSummary,
      riskTrackingSummary: riskSummary,
      sprintsSummary: sprintsSummary,
    );

    // Append planning deliverables and stakeholders if available
    final buf = StringBuffer(contextText);

    if (planningDeliverables.isNotEmpty) {
      buf.writeln();
      buf.writeln('Planning Phase Deliverables:');
      for (final d in planningDeliverables.take(6)) {
        buf.writeln(
            '- ${d['name'] ?? d['title'] ?? 'Deliverable'} (status: ${d['status'] ?? 'Unknown'})');
      }
    }

    if (stakeholdersSummary != null) {
      buf.writeln();
      buf.writeln('Core Stakeholders:');
      buf.writeln(stakeholdersSummary);
    }

    return buf.toString().trim();
  }

  // ────────────────────────────────────────────────────────────────
  // 2. Context sufficiency check
  // ────────────────────────────────────────────────────────────────

  /// Evaluates whether the cross-phase context contains enough concrete
  /// data to generate meaningful Launch Phase entries.
  ///
  /// Returns a [ContextSufficiencyResult] that indicates whether context is
  /// sufficient and, if not, which areas are missing data.
  static Future<ContextSufficiencyResult> checkContextSufficiency(
    BuildContext context, {
    required String sectionLabel,
  }) async {
    final projectData = ProjectDataHelper.getData(context);
    final projectId = projectData.projectId;

    final missingAreas = <String>[];

    // Check base project data
    final projectName = projectData.projectName ?? '';
    final projectDescription = projectData.projectDescription ?? '';
    if (projectName.isEmpty && projectDescription.isEmpty) {
      missingAreas.add('Project name and description');
    }

    // Check for any prior phase data in the base context
    final baseContext = ProjectDataHelper.buildExecutivePlanContext(
      projectData,
      sectionLabel: sectionLabel,
    );
    final fallbackContext = baseContext.trim().isEmpty
        ? ProjectDataHelper.buildProjectContextScan(
            projectData,
            sectionLabel: sectionLabel,
          )
        : baseContext;

    if (fallbackContext.trim().isEmpty) {
      missingAreas.add('Any prior phase data (Initiation, Planning, Design, Execution)');
    }

    // Check cross-phase Firestore data for concrete entries
    if (projectId != null && projectId.isNotEmpty) {
      final staffing = await LaunchPhaseService.loadExecutionStaffing(projectId);
      final contracts = await LaunchPhaseService.loadExecutionContracts(projectId);
      final vendors = await LaunchPhaseService.loadExecutionVendors(projectId);
      final budgetRows = await LaunchPhaseService.loadBudgetRows(projectId);
      final deliverableRows = await LaunchPhaseService.loadDeliverableRows(projectId);
      final scopeTracking = await LaunchPhaseService.loadScopeTrackingItems(projectId);
      final riskSnapshot = await LaunchPhaseService.loadRiskTrackingSnapshot(projectId);
      final planningDeliverables = await LaunchPhaseService.loadPlanningDeliverables(projectId);

      final hasStaffing = staffing.isNotEmpty;
      final hasContracts = contracts.isNotEmpty;
      final hasVendors = vendors.isNotEmpty;
      final hasBudget = budgetRows.isNotEmpty;
      final hasDeliverables = deliverableRows.isNotEmpty || planningDeliverables.isNotEmpty;
      final hasScope = scopeTracking.isNotEmpty;
      final hasRisks = (riskSnapshot['riskItems'] as List?)?.isNotEmpty == true;

      // Section-specific sufficiency checks
      switch (sectionLabel) {
        case 'Deliver Project Closure':
          if (!hasScope) missingAreas.add('Scope tracking data from Execution Phase');
          if (!hasDeliverables) missingAreas.add('Deliverables from Planning or Execution Phase');
          if (!hasRisks) missingAreas.add('Risk tracking data from Execution Phase');
          break;
        case 'Transition to Production Team':
          if (!hasStaffing) missingAreas.add('Staffing/team roster from Execution Phase');
          if (!hasDeliverables) missingAreas.add('Deliverables from prior phases');
          break;
        case 'Contract Close Out':
          if (!hasContracts) missingAreas.add('Contract records from Execution Phase');
          if (!hasVendors) missingAreas.add('Vendor records from Execution Phase');
          break;
        case 'Vendor Account Close Out':
          if (!hasVendors) missingAreas.add('Vendor records from Execution Phase');
          if (!hasContracts) missingAreas.add('Contract records from Execution Phase');
          break;
        case 'Project Summary':
          if (!hasScope && !hasDeliverables) missingAreas.add('Scope or deliverable data from prior phases');
          if (!hasBudget) missingAreas.add('Budget data from Execution Phase');
          break;
        case 'Commerce Viability':
          if (!hasBudget) missingAreas.add('Budget/financial data from Execution Phase');
          if (!hasContracts && !hasVendors) missingAreas.add('Contract or vendor data from Execution Phase');
          break;
        case 'Actual vs Planned Gap Analysis':
          if (!hasBudget) missingAreas.add('Budget data for variance analysis');
          if (!hasScope && !hasDeliverables) missingAreas.add('Scope or deliverable data for gap analysis');
          if (!hasRisks) missingAreas.add('Risk tracking data from Execution Phase');
          break;
        case 'Project Close Out':
          if (!hasContracts && !hasVendors && !hasStaffing) {
            missingAreas.add('Any project records (contracts, vendors, team) from prior phases');
          }
          break;
        case 'Demobilize Team':
          if (!hasStaffing) missingAreas.add('Staffing/team roster from Execution Phase');
          if (!hasContracts && !hasVendors) missingAreas.add('Vendor or contract data for offboarding');
          break;
        case 'Launch Checklist':
          if (!hasScope && !hasDeliverables && !hasRisks) {
            missingAreas.add('Scope, deliverable, or risk data from prior phases');
          }
          break;
      }
    }

    final isSufficient = missingAreas.isEmpty;
    return ContextSufficiencyResult(
      isSufficient: isSufficient,
      missingAreas: missingAreas,
    );
  }

  // ────────────────────────────────────────────────────────────────
  // 3. AI generation entry point
  // ────────────────────────────────────────────────────────────────

  /// Generates AI-populated entries for a Launch Phase screen, using
  /// the full cross-phase dependency context.
  ///
  /// Returns a [LaunchAiResult] containing the generated entries and
  /// context sufficiency information. If context is insufficient,
  /// the [LaunchAiResult.isContextSufficient] flag will be false.
  static Future<LaunchAiResult> generateEntries({
    required BuildContext context,
    required String sectionLabel,
    required Map<String, String> sections,
    int itemsPerSection = 3,
  }) async {
    // Check context sufficiency first
    final sufficiency = await checkContextSufficiency(
      context,
      sectionLabel: sectionLabel,
    );

    final contextText = await buildFullPhaseDependencyContext(
      context,
      sectionLabel: sectionLabel,
    );
    if (contextText.isEmpty) {
      return LaunchAiResult(
        entries: {},
        isContextSufficient: false,
        missingAreas: ['No project data available. Please complete prior phases first.'],
      );
    }

    final entries = await OpenAiServiceSecure().generateLaunchPhaseEntries(
      context: contextText,
      sections: sections,
      itemsPerSection: itemsPerSection,
    );

    return LaunchAiResult(
      entries: entries,
      isContextSufficient: sufficiency.isSufficient,
      missingAreas: sufficiency.missingAreas,
    );
  }

  // ────────────────────────────────────────────────────────────────
  // 4. Insufficient context dialog
  // ────────────────────────────────────────────────────────────────

  /// Shows a dialog informing the user that there is insufficient
  /// prior-phase context to generate meaningful AI entries.
  static Future<void> showInsufficientContextDialog(
    BuildContext context, {
    required List<String> missingAreas,
  }) async {
    return showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded,
                color: const Color(0xFFF59E0B), size: 28),
            const SizedBox(width: 12),
            const Flexible(
              child: Text(
                'Insufficient Context',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'The AI cannot generate meaningful entries because the following prior-phase data is missing or incomplete:',
              style: TextStyle(fontSize: 14, height: 1.5),
            ),
            const SizedBox(height: 16),
            ...missingAreas.map((area) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.circle, size: 8,
                          color: const Color(0xFFEF4444)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          area,
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                )),
            const SizedBox(height: 16),
            const Text(
              'Please complete the relevant sections in prior phases before using AI to populate this screen.',
              style: TextStyle(
                  fontSize: 13,
                  color: Color(0xFF6B7280),
                  height: 1.4),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF005BB3),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            child: const Text('Understood',
                style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  // ────────────────────────────────────────────────────────────────
  // 5. Auto-populate helpers (data-driven, no AI call)
  // ────────────────────────────────────────────────────────────────

  /// Loads ALL cross-phase data from Firestore and returns a structured
  /// record that screens can use for deterministic auto-population
  /// (before or instead of AI generation).
  static Future<CrossPhaseData> loadCrossPhaseData(String projectId) async {
    return CrossPhaseData(
      staffing: await LaunchPhaseService.loadExecutionStaffing(projectId),
      contracts: await LaunchPhaseService.loadExecutionContracts(projectId),
      vendors: await LaunchPhaseService.loadExecutionVendors(projectId),
      budgetRows: await LaunchPhaseService.loadBudgetRows(projectId),
      deliverableRows:
          await LaunchPhaseService.loadDeliverableRows(projectId),
      scopeTracking:
          await LaunchPhaseService.loadScopeTrackingItems(projectId),
      riskSnapshot:
          await LaunchPhaseService.loadRiskTrackingSnapshot(projectId),
      planningDeliverables:
          await LaunchPhaseService.loadPlanningDeliverables(projectId),
      planningSprints:
          await LaunchPhaseService.loadPlanningSprints(projectId),
      stakeholders: await LaunchPhaseService.loadCoreStakeholders(projectId),
    );
  }
}

/// Result of a context sufficiency check.
class ContextSufficiencyResult {
  final bool isSufficient;
  final List<String> missingAreas;

  const ContextSufficiencyResult({
    required this.isSufficient,
    required this.missingAreas,
  });
}

/// Result of AI generation for a Launch Phase screen.
/// Includes the generated entries and context sufficiency information.
class LaunchAiResult {
  final Map<String, List<Map<String, dynamic>>> entries;
  final bool isContextSufficient;
  final List<String> missingAreas;

  const LaunchAiResult({
    required this.entries,
    required this.isContextSufficient,
    required this.missingAreas,
  });
}

/// Immutable snapshot of cross-phase data used for deterministic
/// auto-population of Launch Phase screens.
class CrossPhaseData {
  final List<LaunchTeamMember> staffing;
  final List<LaunchContractItem> contracts;
  final List<LaunchVendorItem> vendors;
  final List<Map<String, dynamic>> budgetRows;
  final List<Map<String, dynamic>> deliverableRows;
  final List<LaunchScopeItem> scopeTracking;
  final Map<String, dynamic> riskSnapshot;
  final List<Map<String, dynamic>> planningDeliverables;
  final List<Map<String, dynamic>> planningSprints;
  final List<Map<String, String>> stakeholders;

  const CrossPhaseData({
    this.staffing = const [],
    this.contracts = const [],
    this.vendors = const [],
    this.budgetRows = const [],
    this.deliverableRows = const [],
    this.scopeTracking = const [],
    this.riskSnapshot = const {},
    this.planningDeliverables = const [],
    this.planningSprints = const [],
    this.stakeholders = const [],
  });

  // ── Budget helpers ──

  double get totalPlannedBudget => budgetRows.fold<double>(
        0,
        (sum, b) =>
            sum +
            (_parseNum(b['plannedAmount'])),
      );

  double get totalActualBudget => budgetRows.fold<double>(
        0,
        (sum, b) =>
            sum +
            (_parseNum(b['actualAmount'])),
      );

  double get budgetVariance => totalPlannedBudget - totalActualBudget;

  double get totalContractValue => contracts.fold<double>(
        0,
        (sum, c) => sum + _parseNum(c.value),
      );

  // ── Scope helpers ──

  int get completedDeliverables => deliverableRows.where((d) {
        final s = (d['status'] ?? '').toString().toLowerCase();
        return s == 'completed' || s == 'done' || s == 'verified';
      }).length;

  int get completedScopeItems => scopeTracking.where((s) {
        final st = s.status.toLowerCase();
        return st == 'verified' || st == 'completed' || st == 'done';
      }).length;

  int get totalScopeCount =>
      deliverableRows.length + scopeTracking.length;

  int get totalCompletedScope =>
      completedDeliverables + completedScopeItems;

  // ── Risk helpers ──

  List<Map<String, dynamic>> get openRiskItems {
    final items = riskSnapshot['riskItems'];
    if (items is! List) return [];
    return items
        .whereType<Map>()
        .map((r) => Map<String, dynamic>.from(r))
        .where((r) {
      final status = (r['status'] ?? '').toString().toLowerCase();
      return status != 'closed' &&
          status != 'resolved' &&
          status != 'mitigated';
    }).toList();
  }

  List<Map<String, dynamic>> get mitigationPlans {
    final plans = riskSnapshot['mitigationPlans'];
    if (plans is! List) return [];
    return plans
        .whereType<Map>()
        .map((p) => Map<String, dynamic>.from(p))
        .toList();
  }

  // ── Utility ──

  static double _parseNum(dynamic v) {
    if (v == null) return 0;
    return double.tryParse(
            v.toString().replaceAll(RegExp(r'[^\d.]'), '')) ??
        0;
  }
}
