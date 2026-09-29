/// The project's issue log — the table on the Planning Issue Management screen.
///
/// Owner, Lusaka 27, naming the tables the way they should read:
///
///   "M-L-O-G is all these tables … this procurement table now [can] be called
///    a procurement log. The contract table can be called a contract log. The
///    issues management table can be called an issues log."
///
/// ... and, of every table in the app:
///
///   "all our tables should be numbered."
///
/// So the column set and the row mapping live here, once, next to the risk,
/// contract and procurement logs — same shape, same numbered `#` first.
library;

import 'package:flutter/foundation.dart';

import 'package:ndu_project/models/project_data_model.dart';

/// One column of the issue log.
@immutable
class IssueLogColumn {
  const IssueLogColumn(this.key, this.label);

  /// The key [IssueLogRow.valueFor] understands.
  final String key;

  /// The header shown in the table and in the PDF export.
  final String label;
}

/// The issue log's columns, in order (Lusaka 27).
///
/// `#` first, as every log in the app is numbered; the ID stays alongside it
/// because that is the traceable code the milestone view and the seeded
/// carry-over rows use.
const List<IssueLogColumn> issueLogColumns = <IssueLogColumn>[
  IssueLogColumn('number', '#'),
  IssueLogColumn('id', 'ID'),
  IssueLogColumn('title', 'Issue'),
  IssueLogColumn('type', 'Type'),
  IssueLogColumn('severity', 'Severity'),
  IssueLogColumn('status', 'Status'),
  IssueLogColumn('assignee', 'Assignee'),
  IssueLogColumn('dueDate', 'Due Date'),
  IssueLogColumn('milestone', 'Milestone'),
];

/// A row of the issue log.
///
/// Pure mapping so the row rules are unit-testable without a widget tree.
@immutable
class IssueLogRow {
  const IssueLogRow({
    required this.number,
    required this.id,
    required this.title,
    required this.type,
    required this.severity,
    required this.status,
    required this.assignee,
    required this.dueDate,
    required this.milestone,
  });

  /// The 1-based row number the owner asked every table to carry.
  final int number;

  final String id;
  final String title;
  final String type;
  final String severity;
  final String status;
  final String assignee;
  final String dueDate;
  final String milestone;

  /// Builds a row. [number] is the 1-based row position in the log.
  factory IssueLogRow.fromItem(IssueLogItem item, {required int number}) {
    final status = item.status.trim();
    return IssueLogRow(
      number: number,
      id: item.id.trim().isEmpty ? '—' : item.id.trim(),
      title: item.title.trim().isEmpty ? 'Untitled issue' : item.title.trim(),
      type: item.type.trim().isEmpty ? 'Other' : item.type.trim(),
      severity: item.severity.trim().isEmpty ? 'Medium' : item.severity.trim(),
      status: status.isEmpty ? 'Open' : status,
      assignee: item.assignee.trim().isEmpty ? 'Unassigned' : item.assignee.trim(),
      dueDate: item.dueDate.trim().isEmpty ? 'No due date' : item.dueDate.trim(),
      milestone: item.milestone.trim().isEmpty ? 'Unassigned' : item.milestone.trim(),
    );
  }

  /// Whether [status] means the issue is closed out.
  static bool isResolvedStatus(String status) {
    final value = status.trim().toLowerCase();
    return value == 'resolved' || value == 'closed';
  }

  /// Whether [status] means work has started but the issue is still open.
  static bool isInProgressStatus(String status) {
    final value = status.trim().toLowerCase();
    return value.startsWith('in progress') || value == 'progress';
  }

  bool get isResolved => isResolvedStatus(status);

  bool get isInProgress => isInProgressStatus(status);

  bool get isOpen => !isResolved && !isInProgress;

  /// The value of [columnKey], or '' for a key this row does not carry. The
  /// on-screen cells and the PDF export both read this, so the table a user
  /// sees and the table they download cannot disagree.
  String valueFor(String columnKey) {
    switch (columnKey) {
      case 'number':
        return number.toString();
      case 'id':
        return id;
      case 'title':
        return title;
      case 'type':
        return type;
      case 'severity':
        return severity;
      case 'status':
        return status;
      case 'assignee':
        return assignee;
      case 'dueDate':
        return dueDate;
      case 'milestone':
        return milestone;
    }
    return '';
  }

  /// Header labels in column order — what the PDF export prints.
  static List<String> get columnLabels =>
      <String>[for (final column in issueLogColumns) column.label];

  /// This row's values in column order — what the PDF export prints.
  List<String> get values =>
      <String>[for (final column in issueLogColumns) valueFor(column.key)];

  /// Free-text search over the row.
  bool matches(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return <String>[
      id,
      title,
      type,
      severity,
      status,
      assignee,
      dueDate,
      milestone,
    ].any((field) => field.toLowerCase().contains(q));
  }
}

/// The Issue Log exactly as the PDF export prints it.
///
/// The header is [IssueLogRow.columnLabels] and the body is one numbered row
/// per logged issue, in column order — so the table a user sees and the table
/// they download are built from the same thing. The export used to print only
/// Project Info and Notes, which is why nothing about the log reached the PDF.
List<String> issueLogExportHeaders() => IssueLogRow.columnLabels;

List<List<String>> issueLogExportRows(List<IssueLogItem> items) =>
    <List<String>>[
      for (var i = 0; i < items.length; i++)
        IssueLogRow.fromItem(items[i], number: i + 1).values,
    ];

/// The issue health the overview card reports: how many are open, in progress
/// and resolved. Built from the same rows as the log so the two cannot
/// disagree.
@immutable
class IssueLogSummary {
  const IssueLogSummary({
    required this.total,
    required this.open,
    required this.inProgress,
    required this.resolved,
  });

  final int total;
  final int open;
  final int inProgress;
  final int resolved;

  static const IssueLogSummary empty = IssueLogSummary(
    total: 0,
    open: 0,
    inProgress: 0,
    resolved: 0,
  );

  factory IssueLogSummary.fromItems(List<IssueLogItem> items) {
    if (items.isEmpty) return empty;
    var open = 0;
    var inProgress = 0;
    var resolved = 0;
    for (final item in items) {
      final status = item.status.trim();
      if (IssueLogRow.isResolvedStatus(status)) {
        resolved++;
      } else if (IssueLogRow.isInProgressStatus(status)) {
        inProgress++;
      } else {
        open++;
      }
    }
    return IssueLogSummary(
      total: items.length,
      open: open,
      inProgress: inProgress,
      resolved: resolved,
    );
  }

  bool get isEmpty => total == 0;
}
