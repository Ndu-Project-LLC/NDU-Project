/// The project's risk log — the one table the Front End Planning risk register
/// and the Planning Risk Assessment both render.
///
/// Owner, Lusaka 27, on the Planning Risk Assessment:
///
///   "We already have a risk table. I think that we have either in the
///    [initiation] or in FEP. … this table has to be the exact same table. This
///    table is supposed to carry on over and in the final date if things are
///    closed they can close it or stuff like that."
///
/// So the column set and the row mapping live here, once, and both screens read
/// the same store: [ProjectDataModel.frontEndPlanning]`.riskRegisterItems`.
/// That is what makes the Planning numbers agree with Front End Planning
/// instead of the two views disagreeing about the same project.
library;

import 'package:ndu_project/models/project_data_model.dart';

/// One column of the risk log table.
class RiskLogColumn {
  const RiskLogColumn(this.key, this.label);

  /// The key [RiskLogRow.valueFor] understands.
  final String key;

  /// The header shown in the table and in the PDF export.
  final String label;
}

/// The risk log's columns, in the order Front End Planning shows them.
///
/// Front End Planning's trailing "Action" column is not here: it is a control,
/// not part of the log, and the Planning copy of the table is read-only.
const List<RiskLogColumn> riskLogColumns = [
  RiskLogColumn('id', 'ID'),
  RiskLogColumn('title', 'Risk Title'),
  RiskLogColumn('description', 'Description'),
  RiskLogColumn('category', 'Category'),
  RiskLogColumn('probability', 'Probability'),
  RiskLogColumn('impact', 'Impact'),
  RiskLogColumn('costImpact', 'Cost Impact'),
  RiskLogColumn('scheduleImpact', 'Schedule Impact'),
  RiskLogColumn('riskLevel', 'Risk Level'),
  RiskLogColumn('mitigation', 'Mitigation'),
  RiskLogColumn('discipline', 'Discipline'),
  RiskLogColumn('projectRole', 'Project Role'),
  RiskLogColumn('owner', 'Owner'),
  RiskLogColumn('status', 'Status'),
];

/// A row of the risk log.
///
/// Built from the canonical store through [fromRegisterItems], so a risk
/// created, edited or closed on either screen is the same row on both.
class RiskLogRow {
  const RiskLogRow({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.probability,
    required this.impact,
    required this.costImpact,
    required this.scheduleImpact,
    required this.riskLevel,
    required this.mitigation,
    required this.discipline,
    required this.projectRole,
    required this.owner,
    required this.status,
  });

  final String id;
  final String title;
  final String description;
  final String category;
  final String probability;
  final String impact;

  /// Potential cost impact if the risk materialises — the most-likely figure
  /// from the register. Empty when the project never recorded one (the column
  /// reads `TBD` rather than a misleading zero).
  final String costImpact;

  /// Potential schedule impact in days — see [costImpact].
  final String scheduleImpact;

  /// The overall rating: [deriveRiskLevel] of [probability] × [impact].
  final String riskLevel;
  final String mitigation;
  final String discipline;
  final String projectRole;
  final String owner;
  final String status;

  /// Maps every saved register item, numbering them the way Front End Planning
  /// does (`001`, `002`, …).
  static List<RiskLogRow> fromRegisterItems(List<RiskRegisterItem> items) => [
        for (var i = 0; i < items.length; i++)
          RiskLogRow.fromRegisterItem(items[i], i),
      ];

  factory RiskLogRow.fromRegisterItem(RiskRegisterItem item, int index) {
    final status = item.status.trim();
    return RiskLogRow(
      id: idForIndex(index),
      title: item.riskName.trim(),
      description: item.description.trim(),
      category: item.category.trim(),
      probability: item.likelihood.trim(),
      impact: item.impactLevel.trim(),
      costImpact: costImpactLabel(item),
      scheduleImpact: scheduleImpactLabel(item),
      riskLevel: deriveRiskLevel(item.likelihood, item.impactLevel),
      mitigation: item.mitigationStrategy.trim(),
      discipline: item.discipline.trim(),
      projectRole: item.projectRole.trim(),
      owner: item.owner.trim(),
      // Front End Planning defaults an unset status to "Identified"; the log
      // carries that across rather than showing a blank status column.
      status: status.isEmpty ? 'Identified' : status,
    );
  }

  /// `\$12,500` from the register's most-likely cost impact, or `''` when the
  /// project never recorded one — the cell then shows the column's dash.
  static String costImpactLabel(RiskRegisterItem item) {
    final value = item.costImpactMostLikely;
    if (value <= 0) return '';
    return '\$${_groupAmount(value.round())}';
  }

  /// `12 days` from the register's most-likely schedule impact, or `''`.
  static String scheduleImpactLabel(RiskRegisterItem item) {
    final days = item.scheduleImpactMostLikely;
    if (days <= 0) return '';
    return days == 1 ? '1 day' : '$days days';
  }

  /// `1,234,567` — plain grouping, no `intl` dependency.
  static String _groupAmount(int value) => value
      .toString()
      .replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (match) => ',');

  /// The id Front End Planning shows for the row at [index] (`001`).
  static String idForIndex(int index) =>
      (index + 1).toString().padLeft(3, '0');

  /// `'High' | 'Medium' | 'Low'` from a free-text scale, or [fallback] when the
  /// value is blank or unrecognised.
  static String normalizeScale(String raw, {String fallback = 'Medium'}) {
    final normalized = raw.trim().toLowerCase();
    if (normalized.startsWith('h')) return 'High';
    if (normalized.startsWith('l')) return 'Low';
    if (normalized.startsWith('m')) return 'Medium';
    return fallback;
  }

  /// The overall risk level for [probability] × [impact] — the same derivation
  /// Front End Planning prints in its "Risk Level" column.
  static String deriveRiskLevel(String probability, String impact) {
    final prob = normalizeScale(probability).toLowerCase();
    final imp = normalizeScale(impact).toLowerCase();
    if ((prob == 'high' && imp == 'high') ||
        (prob == 'high' && imp == 'medium') ||
        (prob == 'medium' && imp == 'high')) {
      return 'High';
    }
    if ((prob == 'low' && imp == 'low') ||
        (prob == 'low' && imp == 'medium') ||
        (prob == 'medium' && imp == 'low')) {
      return 'Low';
    }
    return 'Medium';
  }

  /// The value of [columnKey], or '' for a key this row does not carry. The
  /// on-screen cells and the PDF export both read this, so the table a user
  /// sees and the table they download cannot disagree.
  String valueFor(String columnKey) => switch (columnKey) {
        'id' => id,
        'title' => title,
        'description' => description,
        'category' => category,
        'probability' => probability,
        'impact' => impact,
        'costImpact' => costImpact.isEmpty ? 'TBD' : costImpact,
        'scheduleImpact' => scheduleImpact.isEmpty ? 'TBD' : scheduleImpact,
        'riskLevel' => riskLevel,
        'mitigation' => mitigation,
        'discipline' => discipline,
        'projectRole' => projectRole,
        'owner' => owner,
        'status' => status,
        _ => '',
      };

  /// Header labels in column order — what the PDF export prints.
  static List<String> get columnLabels =>
      [for (final column in riskLogColumns) column.label];

  /// This row's values in column order — what the PDF export prints.
  List<String> get values =>
      [for (final column in riskLogColumns) valueFor(column.key)];
}
