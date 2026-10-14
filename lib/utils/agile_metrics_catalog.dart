/// One metric a project can track, as defined in Metrics Planning.
class AgileMetric {
  const AgileMetric({
    required this.key,
    required this.label,
    required this.description,
    required this.category,
    this.isBusiness = false,
  });

  /// Stable key, persisted in `metricsConfig.selectedMetrics`.
  final String key;
  final String label;
  final String description;
  final String category;

  /// Business metrics are reported to stakeholders rather than used to run the
  /// sprint, so they are offered as optional rather than part of the core set.
  final bool isBusiness;
}

/// The metric catalog, and the rule for which metrics a project tracks.
///
/// This used to live inside Metrics Planning, which meant the dashboard could
/// not say what it was showing. The review's ask was the opposite way round:
/// "just have the metrics available. And then the dashboard is going to reflect
/// those metrics. And nobody's choosing" — so the catalog is one list, the
/// dashboard reads it, and a project that has never chosen still gets a
/// sensible tracked set instead of an empty page.
class AgileMetricsCatalog {
  AgileMetricsCatalog._();

  static const List<AgileMetric> all = [
    AgileMetric(
      key: 'velocity',
      label: 'Velocity',
      description: 'Story points completed per sprint',
      category: 'Delivery',
    ),
    AgileMetric(
      key: 'throughput',
      label: 'Throughput',
      description: 'Number of work items completed per sprint',
      category: 'Delivery',
    ),
    AgileMetric(
      key: 'burndown',
      label: 'Burndown',
      description: 'Remaining work vs time within a sprint',
      category: 'Delivery',
    ),
    AgileMetric(
      key: 'burnup',
      label: 'Burnup',
      description: 'Completed work vs total scope over time',
      category: 'Delivery',
    ),
    AgileMetric(
      key: 'escaped_defects',
      label: 'Escaped Defects',
      description: 'Defects found in production post-release',
      category: 'Quality',
    ),
    AgileMetric(
      key: 'defect_density',
      label: 'Defect Density',
      description: 'Defects per story point or per feature',
      category: 'Quality',
    ),
    AgileMetric(
      key: 'rework',
      label: 'Rework %',
      description: 'Percentage of work requiring rework',
      category: 'Quality',
    ),
    AgileMetric(
      key: 'lead_time',
      label: 'Lead Time',
      description: 'Time from work item created to delivered',
      category: 'Flow',
    ),
    AgileMetric(
      key: 'cycle_time',
      label: 'Cycle Time',
      description: 'Time from work started to delivered',
      category: 'Flow',
    ),
    AgileMetric(
      key: 'work_item_aging',
      label: 'Work Item Aging',
      description: 'How long items have been in progress',
      category: 'Flow',
    ),
    AgileMetric(
      key: 'sprint_predictability',
      label: 'Sprint Predictability',
      description: 'Ratio of planned vs completed story points',
      category: 'Predictability',
    ),
    AgileMetric(
      key: 'commitment_reliability',
      label: 'Commitment Reliability',
      description: 'How often the team meets sprint commitments',
      category: 'Predictability',
    ),
    AgileMetric(
      key: 'delivery_confidence',
      label: 'Delivery Confidence',
      description: 'Forecast confidence for release dates',
      category: 'Predictability',
    ),
    AgileMetric(
      key: 'value_delivered',
      label: 'Value Delivered',
      description: 'Business value realized per release',
      category: 'Business',
      isBusiness: true,
    ),
    AgileMetric(
      key: 'feature_adoption',
      label: 'Feature Adoption',
      description: 'User adoption rate of delivered features',
      category: 'Business',
      isBusiness: true,
    ),
    AgileMetric(
      key: 'customer_satisfaction',
      label: 'Customer Satisfaction',
      description: 'CSAT or NPS scores per release',
      category: 'Business',
      isBusiness: true,
    ),
  ];

  static final Map<String, AgileMetric> byKey = {
    for (final metric in all) metric.key: metric,
  };

  /// Categories in catalog order.
  static List<String> get categories {
    final seen = <String>[];
    for (final metric in all) {
      if (!seen.contains(metric.category)) seen.add(metric.category);
    }
    return seen;
  }

  static List<AgileMetric> inCategory(String category) =>
      [for (final metric in all) if (metric.category == category) metric];

  /// What a project tracks before anyone chooses: the two the owner named
  /// ("the predictability should be tracked because you need to know if you say
  /// you could finish"), plus delivery confidence, and the business metrics,
  /// which are the optional end of the set.
  static const Set<String> defaultTrackedKeys = {
    'velocity',
    'sprint_predictability',
    'delivery_confidence',
    'value_delivered',
  };

  /// The metrics selected in a saved metrics config, or the defaults when the
  /// project has never chosen. Order follows the catalog, and unknown keys are
  /// dropped rather than rendered as blanks.
  static List<AgileMetric> trackedMetrics(Map<String, dynamic> metricsConfig) {
    final selected = (metricsConfig['selectedMetrics'] as List?)
            ?.map((e) => e.toString().trim())
            .where((key) => key.isNotEmpty)
            .toSet() ??
        const <String>{};
    final keys = selected.isEmpty ? defaultTrackedKeys : selected;
    return [for (final metric in all) if (keys.contains(metric.key)) metric];
  }

  /// Whether [metricsConfig] carries no selection, so the dashboard can say it
  /// is showing the default set rather than pretending the user chose it.
  static bool usesDefaultTrackedSet(Map<String, dynamic> metricsConfig) {
    final selected = (metricsConfig['selectedMetrics'] as List?)
        ?.where((e) => e.toString().trim().isNotEmpty);
    return selected == null || selected.isEmpty;
  }
}
