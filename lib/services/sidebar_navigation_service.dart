/// Service that maintains the sidebar as the source of truth for project flow.
/// The order of items in this list determines the chronological flow of the project.
class SidebarNavigationService {
  SidebarNavigationService._();
  static final SidebarNavigationService instance = SidebarNavigationService._();

  static const List<_PhaseRange> _phaseRanges = [
    _PhaseRange(
      label: 'Initiation Phase',
      startCheckpoint: 'business_case',
      endCheckpoint: 'preferred_solution_analysis',
    ),
    _PhaseRange(
      label: 'Front End Planning',
      startCheckpoint: 'fep_summary',
      endCheckpoint: 'project_charter',
    ),
    _PhaseRange(
      label: 'Planning Phase',
      startCheckpoint: 'project_framework',
      endCheckpoint: 'project_baseline',
    ),
    _PhaseRange(
      label: 'Design Phase',
      startCheckpoint: 'design_management',
      endCheckpoint: 'design_deliverables',
    ),
    _PhaseRange(
      label: 'Execution Phase',
      startCheckpoint: 'staff_team',
      endCheckpoint: 'salvage_disposal_team',
    ),
    _PhaseRange(
      label: 'Launch Phase',
      startCheckpoint: 'deliver_project_closure',
      endCheckpoint: 'project_close_out',
    ),
  ];

  static const Set<String> basicPlanLockedLabels = {
    'Contract & Vendor Quotes',
    'Security',
    'Allowance',
    'Work Breakdown Structure',
    'Interface Management',
    'Project Baseline',
    'Level 1 - Project Schedule',
    'Detailed Project Schedule',
    'Condensed Project Summary',
    'Team Management',
    'Staff Team',
    'Update Ops and Maintenance Plans',
    'Gap Analysis and Scope Reconciliation',
    'Punchlist Actions',
    'Salvage and/or Disposal Plan',
    'Engineering',
    'Specialized Design',
    'Technical Development',
    'Project Summary',
    'Warranties & Operations Support',
    'Project Financial Review',
  };

  /// Check if an item is locked based on its label and plan status
  bool isItemLocked(SidebarItem item, bool isBasicPlan) {
    if (!isBasicPlan) return false;
    return basicPlanLockedLabels.contains(item.label);
  }

  /// Get the next accessible item in the sidebar order
  SidebarItem? getNextAccessibleItem(
      String? currentCheckpoint, bool isBasicPlan) {
    if (currentCheckpoint == null) return _sidebarOrder.first;

    int currentIndex = _sidebarOrder
        .indexWhere((item) => item.checkpoint == currentCheckpoint);
    if (currentIndex == -1) return null;

    // Look ahead for the first non-locked item
    for (int i = currentIndex + 1; i < _sidebarOrder.length; i++) {
      final item = _sidebarOrder[i];
      if (!isItemLocked(item, isBasicPlan)) {
        return item;
      }
    }
    return null; // Reached end or all remaining are locked
  }

  /// Flat, ordered list of all sidebar items with their checkpoint names.
  /// This order determines the project flow chronology.
  static const List<SidebarItem> _sidebarOrder = [
    // Initiation Phase - Business Case
    SidebarItem(checkpoint: 'business_case', label: 'Scope Statement'),
    SidebarItem(
        checkpoint: 'potential_solutions', label: 'Potential Solutions'),
    SidebarItem(
        checkpoint: 'risk_identification', label: 'Risk Identification'),
    SidebarItem(checkpoint: 'it_considerations', label: 'IT Considerations'),
    SidebarItem(
        checkpoint: 'infrastructure_considerations',
        label: 'Infrastructure Considerations'),
    SidebarItem(checkpoint: 'core_stakeholders', label: 'Core Stakeholders'),
    SidebarItem(
        checkpoint: 'preferred_solution_analysis',
        label: 'Preferred Solution Analysis'),
    SidebarItem(checkpoint: 'cost_analysis', label: 'Initial Cost Estimate'),

    // Front End Planning
    SidebarItem(checkpoint: 'fep_summary', label: 'Summary'),
    SidebarItem(checkpoint: 'fep_requirements', label: 'Project Requirements'),
    SidebarItem(checkpoint: 'fep_risks', label: 'Project Risks'),
    SidebarItem(
        checkpoint: 'fep_opportunities', label: 'Project Opportunities'),
    SidebarItem(checkpoint: 'fep_contract_vendor_quotes', label: 'Contracting'),
    SidebarItem(checkpoint: 'fep_procurement', label: 'Procurement'),
    SidebarItem(checkpoint: 'fep_security', label: 'Security'),
    SidebarItem(checkpoint: 'fep_milestone', label: 'Milestone'),
    SidebarItem(checkpoint: 'fep_allowance', label: 'Allowance'),
    SidebarItem(checkpoint: 'project_charter', label: 'Project Charter'),
    SidebarItem(
        checkpoint: 'project_activities_log', label: 'Project Activities Log'),

    // Planning Phase
    SidebarItem(checkpoint: 'project_framework', label: 'Project Details'),
    SidebarItem(
        checkpoint: 'work_breakdown_structure',
        label: 'Work Breakdown Structure'),
    SidebarItem(
        checkpoint: 'project_goals_milestones',
        label: 'Project Goals & Milestones'),
    SidebarItem(checkpoint: 'requirements', label: 'Requirements'),
    // Organization Plan sub-items
    SidebarItem(
        checkpoint: 'organization_roles_responsibilities',
        label: 'Roles & Responsibilities'),
    SidebarItem(checkpoint: 'organization_raci_matrix', label: 'RACI Matrix'),
    SidebarItem(
        checkpoint: 'organization_staffing_plan', label: 'Staffing Plan'),
    SidebarItem(checkpoint: 'team_training', label: 'Training & Team Building'),
    SidebarItem(
        checkpoint: 'stakeholder_management', label: 'Stakeholder Management'),
    SidebarItem(checkpoint: 'team_management', label: 'Team Management'),
    SidebarItem(checkpoint: 'ssher', label: 'SSHER'),
    SidebarItem(checkpoint: 'quality_management', label: 'Quality Management'),
    // Design & Technology — now before Execution Plan
    SidebarItem(checkpoint: 'design', label: 'Design Planning'),
    SidebarItem(checkpoint: 'technology', label: 'Technology Planning'),
    SidebarItem(
        checkpoint: 'interface_management', label: 'Interface Management'),
    // Agile Delivery Model Section — before Execution Plan
    SidebarItem(
        checkpoint: 'agile_delivery_model', label: 'Agile Delivery Model'),
    SidebarItem(checkpoint: 'agile_scrum_config', label: 'Scrum Configuration'),
    SidebarItem(
        checkpoint: 'agile_capacity_planning', label: 'Capacity Planning'),
    SidebarItem(
        checkpoint: 'agile_backlog_governance', label: 'Backlog Governance'),
    SidebarItem(
        checkpoint: 'agile_team_structure', label: 'Agile Team Structure'),
    SidebarItem(
        checkpoint: 'agile_kanban_config', label: 'Kanban Configuration'),
    SidebarItem(checkpoint: 'agile_epics_features', label: 'Epics & Features'),
    SidebarItem(
        checkpoint: 'agile_acceptance_criteria',
        label: 'Acceptance Criteria Planning'),
    SidebarItem(
        checkpoint: 'agile_sprint_calendar',
        label: 'Sprint Cadence & Calendar'),
    SidebarItem(checkpoint: 'agile_map_out', label: 'Agile Map Out'),
    SidebarItem(checkpoint: 'agile_release_plan', label: 'Release Plan'),
    SidebarItem(
        checkpoint: 'agile_metrics_planning', label: 'Agile Metrics Planning'),
    // Execution Plan sub-items (full flow matching sidebar order)
    SidebarItem(checkpoint: 'execution_plan', label: 'Execution Plan Overview'),
    SidebarItem(
        checkpoint: 'execution_work_packages',
        label: 'Execution Work Packages'),
    SidebarItem(
        checkpoint: 'execution_plan_strategy',
        label: 'Executive Plan Strategy'),
    SidebarItem(
        checkpoint: 'execution_plan_details', label: 'Execution Plan Details'),
    SidebarItem(
        checkpoint: 'execution_early_works', label: 'Execution Early Works'),
    SidebarItem(
        checkpoint: 'execution_enabling_work_plan',
        label: 'Execution Enabling Work Plan'),
    SidebarItem(
        checkpoint: 'execution_issue_management',
        label: 'Execution Issue Management'),
    SidebarItem(
        checkpoint: 'execution_plan_stakeholder_identification',
        label: 'Execution Stakeholder Identification'),
    SidebarItem(
        checkpoint: 'execution_plan_construction_plan',
        label: 'Construction Plan'),
    SidebarItem(
        checkpoint: 'execution_plan_infrastructure_plan',
        label: 'Infrastructure Plan'),
    SidebarItem(
        checkpoint: 'execution_plan_agile_delivery_plan',
        label: 'Agile Delivery Plan'),
    SidebarItem(
        checkpoint: 'execution_plan_lessons_learned',
        label: 'Execution Lessons Learned'),
    SidebarItem(
        checkpoint: 'execution_plan_best_practices', label: 'Best Practices'),
    SidebarItem(
        checkpoint: 'execution_plan_interface_management',
        label: 'Execution Interface Management'),
    SidebarItem(
        checkpoint: 'execution_plan_communication_plan',
        label: 'Communication Plan'),
    SidebarItem(
        checkpoint: 'execution_plan_interface_management_plan',
        label: 'Execution Interface Management Plan'),
    SidebarItem(
        checkpoint: 'execution_plan_interface_management_overview',
        label: 'Execution Interface Management Overview'),
    SidebarItem(
        checkpoint: 'deliverables_roadmap_overview', label: 'Roadmap Overview'),
    SidebarItem(
        checkpoint: 'deliverables_roadmap_detailed',
        label: 'Detailed Deliverables'),
    SidebarItem(
        checkpoint: 'document_review_matrix', label: 'Document Review Matrix'),
    // Risk & Contracts
    SidebarItem(checkpoint: 'risk_assessment', label: 'Risk Assessment'),
    SidebarItem(checkpoint: 'contracts', label: 'Contract'),
    SidebarItem(checkpoint: 'procurement', label: 'Procurement'),
    // Schedule & Cost
    SidebarItem(checkpoint: 'schedule', label: 'Schedule'),
    SidebarItem(checkpoint: 'cost_estimate', label: 'Cost Estimate Overview'),
    // Scope & Change Management
    SidebarItem(
        checkpoint: 'scope_tracking_plan', label: 'Scope Tracking Plan'),
    SidebarItem(checkpoint: 'change_management', label: 'Change Management'),
    SidebarItem(checkpoint: 'issue_management', label: 'Issue Management'),
    SidebarItem(checkpoint: 'lessons_learned', label: 'Lessons Learned'),
    // Start-Up Planning sub-items
    SidebarItem(checkpoint: 'startup_planning', label: 'Start-Up Planning'),
    SidebarItem(
        checkpoint: 'startup_planning_operations',
        label: 'Operations Plan and Manual'),
    SidebarItem(
        checkpoint: 'startup_planning_hypercare', label: 'Hypercare Plan'),
    SidebarItem(checkpoint: 'startup_planning_devops', label: 'DevOps'),
    SidebarItem(
        checkpoint: 'startup_planning_closeout', label: 'Close Out Plan'),
    SidebarItem(
        checkpoint: 'deliverables_roadmap', label: 'Deliverables Roadmap'),
    // Project Plan sub-items
    SidebarItem(checkpoint: 'project_plan', label: 'Project Plan Overview'),
    SidebarItem(
        checkpoint: 'project_plan_level1_schedule',
        label: 'Level 1 - Project Schedule'),
    SidebarItem(
        checkpoint: 'project_plan_detailed_schedule',
        label: 'Detailed Project Schedule'),
    SidebarItem(
        checkpoint: 'project_plan_condensed_summary',
        label: 'Condensed Project Summary'),
    SidebarItem(checkpoint: 'project_baseline', label: 'Project Baseline'),

    // Design Phase
    SidebarItem(checkpoint: 'design_management', label: 'Design Management'),
    SidebarItem(
        checkpoint: 'requirements_implementation',
        label: 'Requirements Implementation'),
    SidebarItem(
        checkpoint: 'technical_alignment', label: 'Technical Alignment'),
    SidebarItem(checkpoint: 'development_set_up', label: 'Development Set Up'),
    SidebarItem(checkpoint: 'ui_ux_design', label: 'UI/UX Design'),
    SidebarItem(checkpoint: 'backend_design', label: 'Backend Design'),
    SidebarItem(checkpoint: 'engineering_design', label: 'Engineering'),
    SidebarItem(
        checkpoint: 'technical_development', label: 'Technical Development'),
    SidebarItem(checkpoint: 'tools_integration', label: 'Tools Integration'),
    SidebarItem(
        checkpoint: 'long_lead_equipment_ordering',
        label: 'Long Lead Equipment Ordering'),
    SidebarItem(checkpoint: 'specialized_design', label: 'Specialized Design'),
    SidebarItem(
        checkpoint: 'design_deliverables', label: 'Design Deliverables'),

    // Execution Phase
    SidebarItem(checkpoint: 'staff_team', label: 'Project Team Activities'),
    SidebarItem(checkpoint: 'team_meetings', label: 'Team Meetings'),
    SidebarItem(checkpoint: 'progress_tracking', label: 'Progress Tracking'),
    SidebarItem(
        checkpoint: 'deliverable_status_updates',
        label: 'Deliverable Status Updates'),
    SidebarItem(
        checkpoint: 'recurring_deliverables', label: 'Recurring Deliverables'),
    SidebarItem(checkpoint: 'status_reports', label: 'Status Reports'),
    SidebarItem(checkpoint: 'contracts_tracking', label: 'Contracts Tracking'),
    SidebarItem(checkpoint: 'vendor_tracking', label: 'Vendor Tracking'),
    SidebarItem(checkpoint: 'detailed_design', label: 'Detailed Design'),
    SidebarItem(
        checkpoint: 'agile_development_iterations', label: 'Agile Project Hub'),
    SidebarItem(
        checkpoint: 'scope_tracking_implementation',
        label: 'Scope Tracking Implementation'),
    SidebarItem(
        checkpoint: 'stakeholder_alignment', label: 'Stakeholder Alignment'),
    SidebarItem(
        checkpoint: 'update_ops_maintenance_plans',
        label: 'Update Ops and Maintenance Plans'),
    SidebarItem(
        checkpoint: 'launch_checklist', label: 'Start-up or Launch Checklist'),
    SidebarItem(checkpoint: 'risk_tracking', label: 'Risk Tracking'),
    SidebarItem(checkpoint: 'scope_completion', label: 'Scope Completion'),
    SidebarItem(
        checkpoint: 'gap_analysis_scope_reconcillation',
        label: 'Gap Analysis and Scope Reconciliation'),
    SidebarItem(checkpoint: 'punchlist_actions', label: 'Punchlist Overview'),
    SidebarItem(
        checkpoint: 'technical_debt_management', label: 'Tech Debt Management'),
    SidebarItem(
        checkpoint: 'identify_staff_ops_team',
        label: 'Identify and Staff Ops Team'),
    SidebarItem(
        checkpoint: 'salvage_disposal_team',
        label: 'Salvage and/or Disposal Plan'),

    // Launch Phase (11 sections per Launch Phase spec)
    SidebarItem(
        checkpoint: 'deliver_project_closure',
        label: 'Launch Readiness Assessment'),
    SidebarItem(
        checkpoint: 'transition_to_prod_team',
        label: 'Deployment Transfer, Certification & Release'),
    SidebarItem(
        checkpoint: 'fat_mechanical_completion',
        label: 'FAT, Mechanical Completion & Commission Solution'),
    SidebarItem(
        checkpoint: 'contract_close_out', label: 'Vendor & Contract Closeout'),
    SidebarItem(
        checkpoint: 'actual_vs_planned_gap_analysis',
        label: 'Scope & Deliverable Reconciliation'),
    SidebarItem(
        checkpoint: 'commerce_viability',
        label: 'Hypercare & Warranty Support'),
    SidebarItem(checkpoint: 'financial_closeout', label: 'Financial Closeout'),
    SidebarItem(
        checkpoint: 'summarize_account_risks',
        label: 'Project Performance Review'),
    SidebarItem(
        checkpoint: 'benefits_realization', label: 'Benefits Realization'),
    SidebarItem(
        checkpoint: 'demobilize_team',
        label: 'Team Demobilization & Operations/Production Transition'),
    SidebarItem(checkpoint: 'project_close_out', label: 'Project Closeout'),
  ];

  /// Ordered, read-only sidebar catalog for admin surfaces that need to mirror
  /// the complete project navigation model.
  static List<SidebarItem> get allItems => List.unmodifiable(_sidebarOrder);

  /// Get the next item in the sidebar order after the current checkpoint
  SidebarItem? getNextItem(String? currentCheckpoint) {
    if (currentCheckpoint == null || currentCheckpoint.isEmpty) {
      return _sidebarOrder.first;
    }

    final currentIndex = _sidebarOrder
        .indexWhere((item) => item.checkpoint == currentCheckpoint);
    if (currentIndex == -1 || currentIndex >= _sidebarOrder.length - 1) {
      return null; // Already at the end or checkpoint not found
    }

    return _sidebarOrder[currentIndex + 1];
  }

  /// Find a sidebar item by its display label (case-insensitive).
  SidebarItem? findItemByLabel(String label) {
    final normalized = label.trim().toLowerCase();
    for (final item in _sidebarOrder) {
      if (item.label.trim().toLowerCase() == normalized) {
        return item;
      }
    }
    return null;
  }

  /// Find a sidebar item by checkpoint key.
  SidebarItem? findItemByCheckpoint(String checkpoint) {
    final normalized = checkpoint.trim().toLowerCase();
    for (final item in _sidebarOrder) {
      if (item.checkpoint.trim().toLowerCase() == normalized) {
        return item;
      }
    }
    return null;
  }

  /// Return ordered checkpoints that are still pending between the current
  /// checkpoint and the destination (inclusive of destination).
  List<SidebarItem> getPendingItemsToDestination({
    required String? currentCheckpoint,
    required String destinationCheckpoint,
  }) {
    final destinationIndex = _sidebarOrder
        .indexWhere((item) => item.checkpoint == destinationCheckpoint);
    if (destinationIndex == -1) return const <SidebarItem>[];

    var startIndex = 0;
    final current = (currentCheckpoint ?? '').trim();
    if (current.isNotEmpty) {
      final currentIndex =
          _sidebarOrder.indexWhere((item) => item.checkpoint == current);
      if (currentIndex != -1) {
        startIndex = currentIndex + 1;
      }
    }

    if (startIndex > destinationIndex) {
      return const <SidebarItem>[];
    }

    return _sidebarOrder.sublist(startIndex, destinationIndex + 1);
  }

  /// Get the previous item in the sidebar order before the current checkpoint
  SidebarItem? getPreviousItem(String? currentCheckpoint) {
    if (currentCheckpoint == null || currentCheckpoint.isEmpty) {
      return null;
    }

    final currentIndex = _sidebarOrder
        .indexWhere((item) => item.checkpoint == currentCheckpoint);
    if (currentIndex <= 0) {
      return null; // Already at the beginning or checkpoint not found
    }

    return _sidebarOrder[currentIndex - 1];
  }

  /// Check if a checkpoint has been reached based on sidebar order
  bool isCheckpointReached(
      String checkpointToCheck, String? currentCheckpoint) {
    if (currentCheckpoint == null || currentCheckpoint.isEmpty) {
      return false;
    }

    final currentIndex = _sidebarOrder
        .indexWhere((item) => item.checkpoint == currentCheckpoint);
    final checkIndex = _sidebarOrder
        .indexWhere((item) => item.checkpoint == checkpointToCheck);

    if (currentIndex == -1 || checkIndex == -1) {
      return false; // Unknown checkpoints
    }

    return currentIndex >= checkIndex;
  }

  /// Get all checkpoints up to and including the current one
  List<String> getReachedCheckpoints(String? currentCheckpoint) {
    if (currentCheckpoint == null || currentCheckpoint.isEmpty) {
      return [];
    }

    final currentIndex = _sidebarOrder
        .indexWhere((item) => item.checkpoint == currentCheckpoint);
    if (currentIndex == -1) {
      return [];
    }

    return _sidebarOrder
        .sublist(0, currentIndex + 1)
        .map((item) => item.checkpoint)
        .toList();
  }

  /// Resolve a checkpoint to its phase label (based on sidebar order).
  static String? phaseForCheckpoint(String? checkpoint) {
    if (checkpoint == null || checkpoint.isEmpty) return null;
    final checkpointIndex =
        _sidebarOrder.indexWhere((item) => item.checkpoint == checkpoint);
    if (checkpointIndex == -1) return null;

    for (final range in _phaseRanges) {
      final startIndex = _sidebarOrder
          .indexWhere((item) => item.checkpoint == range.startCheckpoint);
      final endIndex = _sidebarOrder
          .indexWhere((item) => item.checkpoint == range.endCheckpoint);
      if (startIndex == -1 || endIndex == -1) continue;
      if (checkpointIndex >= startIndex && checkpointIndex <= endIndex) {
        return range.label;
      }
    }
    return null;
  }

  /// Determine if navigation crosses a phase boundary.
  static bool isPhaseChange(String? fromCheckpoint, String? toCheckpoint) {
    final fromPhase = phaseForCheckpoint(fromCheckpoint);
    final toPhase = phaseForCheckpoint(toCheckpoint);
    if (fromPhase == null || toPhase == null) return false;
    return fromPhase != toPhase;
  }

  /// Check if a checkpoint is the first item of a phase.
  static bool isPhaseStartCheckpoint(String? checkpoint) {
    if (checkpoint == null || checkpoint.isEmpty) return false;
    return _phaseRanges.any((range) => range.startCheckpoint == checkpoint);
  }
}

/// Represents a single item in the sidebar navigation
class SidebarItem {
  final String checkpoint;
  final String label;

  const SidebarItem({
    required this.checkpoint,
    required this.label,
  });
}

class _PhaseRange {
  final String label;
  final String startCheckpoint;
  final String endCheckpoint;

  const _PhaseRange({
    required this.label,
    required this.startCheckpoint,
    required this.endCheckpoint,
  });
}
