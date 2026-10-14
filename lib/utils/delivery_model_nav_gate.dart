/// Delivery-model gating for the project navigation flow (Lusaka 27).
///
/// The owner's rule: an Agile-delivered project has no Execution Plan section —
/// "there should be no execution plan for the agile delivery … the execution
/// plan is mostly so if the waterfall project is going to be blanked out, they
/// cannot click on it, they cannot access it" — and, by the same logic, a
/// Waterfall project has no Agile Delivery flow.
///
/// The rule is deliberately pure and total: it takes the project's
/// `'AGILE' | 'WATERFALL' | 'HYBRID'` delivery model and answers which of the
/// two sections the flow should keep. Nothing here reads Flutter state, so the
/// same predicate gates the sidebar widget, the flow walkers in
/// [SidebarNavigationService] and the on-page Next/Back buttons.
library;

class DeliveryModelNavGate {
  DeliveryModelNavGate._();

  static const String agile = 'AGILE';
  static const String waterfall = 'WATERFALL';
  static const String hybrid = 'HYBRID';

  /// The Planning-phase **Execution Plan** section, in flow order. These are
  /// the Execution Plan group the sidebar renders plus `execution_quality_
  /// tracking`, which has no sidebar row of its own but sits inside the same
  /// contiguous block of the flow.
  static const Set<String> executionPlanCheckpoints = {
    'execution_plan',
    'execution_work_packages',
    'execution_plan_strategy',
    'execution_plan_details',
    'execution_early_works',
    'execution_enabling_work_plan',
    'execution_plan_construction_plan',
    'execution_plan_infrastructure_plan',
    'execution_plan_agile_delivery_plan',
    'execution_plan_best_practices',
    'execution_plan_interface_management',
    'execution_plan_communication_plan',
    'execution_plan_interface_management_plan',
    'execution_plan_interface_management_overview',
    'execution_quality_tracking',
  };

  /// The Planning-phase **Agile Delivery** section, in flow order. This is the
  /// sidebar's Agile Delivery group plus `agile_stories_backlog`, a page with
  /// no sidebar row of its own.
  ///
  /// `agile_development_iterations` (the Agile Project Hub that lives in the
  /// Execution *phase*) is deliberately absent: it is not part of this flow and
  /// a Waterfall project still keeps it.
  static const Set<String> agileDeliveryCheckpoints = {
    'agile_delivery_model',
    'agile_scrum_config',
    'agile_capacity_planning',
    'agile_backlog_governance',
    'agile_team_structure',
    'agile_epics_features',
    'agile_kanban_config',
    'agile_stories_backlog',
    'agile_acceptance_criteria',
    'agile_sprint_calendar',
    'agile_release_plan',
    'agile_metrics_planning',
    'agile_map_out',
  };

  /// Upper-cased, trimmed delivery model, or `null` when none was supplied.
  static String? normalize(String? deliveryModel) {
    final normalized = deliveryModel?.trim().toUpperCase();
    if (normalized == null || normalized.isEmpty) return null;
    return normalized;
  }

  /// An Agile project has no Execution Plan. Unset and Hybrid projects keep it.
  static bool showsExecutionPlan(String? deliveryModel) =>
      normalize(deliveryModel) != agile;

  /// A Waterfall project has no Agile Delivery flow. Unset and Hybrid projects
  /// keep it.
  static bool showsAgileDelivery(String? deliveryModel) =>
      normalize(deliveryModel) != waterfall;

  /// Whether [checkpoint] sits in a section [deliveryModel] does not use, so
  /// navigation should hide and skip it.
  static bool hidesCheckpoint(String checkpoint, String? deliveryModel) {
    final id = checkpoint.trim().toLowerCase();
    if (executionPlanCheckpoints.contains(id)) {
      return !showsExecutionPlan(deliveryModel);
    }
    if (agileDeliveryCheckpoints.contains(id)) {
      return !showsAgileDelivery(deliveryModel);
    }
    return false;
  }

  /// [checkpoints] without the ones [deliveryModel] does not use, order kept.
  static List<String> visibleCheckpoints(
    Iterable<String> checkpoints,
    String? deliveryModel,
  ) =>
      checkpoints
          .where((id) => !hidesCheckpoint(id, deliveryModel))
          .toList(growable: false);
}
