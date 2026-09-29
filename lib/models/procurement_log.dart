import 'package:flutter/foundation.dart';

import 'package:ndu_project/models/procurement/procurement_models.dart';
import 'package:ndu_project/models/procurement/procurement_ui_extensions.dart';

/// One column of the procurement log.
@immutable
class ProcurementLogColumn {
  const ProcurementLogColumn(this.key, this.label);

  final String key;
  final String label;
}

/// The procurement log columns, in order (Lusaka 27).
///
/// The owner's asks on the procurement table: it is the **log** and it "should
/// have like the key items that they plan to buy", the items must be things to
/// purchase, and each has to say whether it is a **long-lead** item
/// ("you need to be items that will be procured and then identify if they're
/// gonna be long lead items").
const List<ProcurementLogColumn> procurementLogColumns = <ProcurementLogColumn>[
  ProcurementLogColumn('number', '#'),
  ProcurementLogColumn('item', 'Item'),
  ProcurementLogColumn('category', 'Category'),
  ProcurementLogColumn('priority', 'Priority'),
  ProcurementLogColumn('longLead', 'Long Lead'),
  ProcurementLogColumn('budget', 'Budget'),
  ProcurementLogColumn('delivery', 'Est. Delivery'),
  ProcurementLogColumn('leadTime', 'Lead Time'),
  ProcurementLogColumn('vendor', 'Vendor'),
  ProcurementLogColumn('status', 'Status'),
];

/// How many days ahead count as "long lead" when an item has no explicit
/// delivery date to measure.
const int kLongLeadThresholdDays = 56;

/// Whether an item is a long-lead purchase.
///
/// The rule the procurement section already used (`_StrategiesSection`, now
/// folded in here so the overview count and the log column cannot disagree): a
/// critical or high-priority item, a category that is equipment / materials /
/// logistics, or a delivery date more than [kLongLeadThresholdDays] out.
bool isLongLeadProcurementItem(ProcurementItemModel item, {DateTime? now}) {
  if (item.priority == ProcurementPriority.critical ||
      item.priority == ProcurementPriority.high) {
    return true;
  }
  final category = item.category.toLowerCase();
  if (category.contains('equipment') ||
      category.contains('material') ||
      category.contains('logistics')) {
    return true;
  }
  final delivery = item.estimatedDelivery;
  if (delivery != null) {
    final reference = now ?? DateTime.now();
    return delivery.difference(reference).inDays > kLongLeadThresholdDays;
  }
  return false;
}

/// A procurement item as it appears in the log table.
///
/// Pure mapping so the row rules are unit-testable without a widget tree.
@immutable
class ProcurementLogRow {
  const ProcurementLogRow({
    required this.number,
    required this.id,
    required this.name,
    required this.category,
    required this.priority,
    required this.longLead,
    required this.budget,
    required this.delivery,
    required this.requiredBy,
    required this.leadTimeWeeks,
    required this.vendorName,
    required this.status,
    required this.progress,
  });

  /// The 1-based row number every table in the app carries.
  final int number;

  final String id;
  final String name;
  final String category;
  final String priority;

  /// Long-lead purchase — see [isLongLeadProcurementItem].
  final bool longLead;

  final double budget;

  /// Expected delivery, when it is known.
  final DateTime? delivery;

  /// The date the item is needed by, when it is known.
  final DateTime? requiredBy;

  /// Weeks of lead time, from the delivery (or required-by) date. Null when
  /// neither date is known.
  final int? leadTimeWeeks;

  final String vendorName;
  final String status;
  final double progress;

  /// Builds a row. [number] is the 1-based row position in the log; [vendorName]
  /// is resolved by the caller because an item only stores a vendor id.
  factory ProcurementLogRow.fromItem(
    ProcurementItemModel item, {
    required int number,
    String vendorName = '',
    DateTime? now,
  }) {
    final delivery = item.estimatedDelivery;
    final requiredBy = item.requiredByDate;
    final anchor = delivery ?? requiredBy;
    final reference = now ?? DateTime.now();
    return ProcurementLogRow(
      number: number,
      id: item.id,
      name: item.name.trim().isEmpty ? 'Untitled item' : item.name.trim(),
      category: item.category.trim().isEmpty ? 'Uncategorised' : item.category.trim(),
      priority: item.priority.label,
      longLead: isLongLeadProcurementItem(item, now: now),
      budget: item.budget,
      delivery: delivery,
      requiredBy: requiredBy,
      leadTimeWeeks: anchor == null
          ? null
          : (anchor.difference(reference).inDays / 7).ceil().clamp(0, 520),
      vendorName: vendorName.trim(),
      status: item.status.label,
      progress: item.progress.clamp(0.0, 1.0),
    );
  }

  bool get isOrdered =>
      status == ProcurementItemStatus.ordered.label ||
      status == ProcurementItemStatus.delivered.label;

  String valueFor(String key) {
    switch (key) {
      case 'number':
        return number.toString();
      case 'item':
        return name;
      case 'category':
        return category;
      case 'priority':
        return priority;
      case 'longLead':
        return longLead ? 'Yes' : 'No';
      case 'budget':
        return budget > 0 ? '\$${formatProcurementAmount(budget)}' : 'TBD';
      case 'delivery':
        return _dateLabel(delivery);
      case 'leadTime':
        final weeks = leadTimeWeeks;
        if (weeks == null) return 'TBD';
        return weeks == 1 ? '1 wk' : '$weeks wks';
      case 'vendor':
        return vendorName.isEmpty ? 'Not assigned' : vendorName;
      case 'status':
        return status;
    }
    return '';
  }

  /// Free-text search over the row.
  bool matches(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return <String>[
      name,
      category,
      priority,
      status,
      vendorName,
      valueFor('budget'),
      valueFor('delivery'),
    ].any((field) => field.toLowerCase().contains(q));
  }

  /// Header labels in column order — what the PDF export prints.
  static List<String> get columnLabels =>
      <String>[for (final column in procurementLogColumns) column.label];

  /// This row's values in column order — what the PDF export prints.
  List<String> get values => <String>[
        for (final column in procurementLogColumns) valueFor(column.key),
      ];
}

/// The Procurement Log exactly as the PDF export prints it:
/// [ProcurementLogRow.columnLabels] as the header and one numbered row per item,
/// in column order. [vendorNames] resolves an item's vendor id the way the
/// on-screen table does, so a vendor is named in the PDF too.
List<String> procurementLogExportHeaders() => ProcurementLogRow.columnLabels;

List<List<String>> procurementLogExportRows(
  List<ProcurementItemModel> items, {
  Map<String, String> vendorNames = const <String, String>{},
}) =>
    <List<String>>[
      for (var i = 0; i < items.length; i++)
        ProcurementLogRow.fromItem(
          items[i],
          number: i + 1,
          vendorName: vendorNames[items[i].vendorId ?? ''] ?? '',
        ).values,
    ];

/// The key status of the procured items and their cost, for the overview
/// dashboard the owner asked to sit above the log
/// ("it's gonna be a dashboard that kind of shows the key status of the procured
/// items and the cost and all of that. It can sort of blank and then fill up as
/// they get the work done.").
@immutable
class ProcurementStatusSummary {
  const ProcurementStatusSummary({
    required this.totalItems,
    required this.longLeadItems,
    required this.orderedItems,
    required this.deliveredItems,
    required this.notStartedItems,
    required this.overdueItems,
    required this.totalBudget,
    required this.committedBudget,
  });

  final int totalItems;
  final int longLeadItems;
  final int orderedItems;
  final int deliveredItems;

  /// Items still at the planning stage.
  final int notStartedItems;

  /// Items needed before today that are not delivered yet.
  final int overdueItems;

  final double totalBudget;

  /// Budget of the items that have been ordered or delivered.
  final double committedBudget;

  static const ProcurementStatusSummary empty = ProcurementStatusSummary(
    totalItems: 0,
    longLeadItems: 0,
    orderedItems: 0,
    deliveredItems: 0,
    notStartedItems: 0,
    overdueItems: 0,
    totalBudget: 0,
    committedBudget: 0,
  );

  factory ProcurementStatusSummary.fromItems(
    List<ProcurementItemModel> items, {
    DateTime? now,
  }) {
    if (items.isEmpty) return empty;
    final reference = now ?? DateTime.now();
    var longLead = 0;
    var ordered = 0;
    var delivered = 0;
    var notStarted = 0;
    var overdue = 0;
    var budget = 0.0;
    var committed = 0.0;
    for (final item in items) {
      if (isLongLeadProcurementItem(item, now: reference)) longLead++;
      switch (item.status) {
        case ProcurementItemStatus.planning:
          notStarted++;
        case ProcurementItemStatus.ordered:
          ordered++;
          committed += item.budget;
        case ProcurementItemStatus.delivered:
          delivered++;
          committed += item.budget;
        case ProcurementItemStatus.rfqReview:
        case ProcurementItemStatus.vendorSelection:
        case ProcurementItemStatus.cancelled:
          break;
      }
      budget += item.budget;
      final due = item.requiredByDate ?? item.estimatedDelivery;
      if (due != null &&
          due.isBefore(reference) &&
          item.status != ProcurementItemStatus.delivered &&
          item.status != ProcurementItemStatus.cancelled) {
        overdue++;
      }
    }
    return ProcurementStatusSummary(
      totalItems: items.length,
      longLeadItems: longLead,
      orderedItems: ordered,
      deliveredItems: delivered,
      notStartedItems: notStarted,
      overdueItems: overdue,
      totalBudget: budget,
      committedBudget: committed,
    );
  }

  /// Percentage of the budget that has been ordered or delivered, 0–100.
  int get committedRate {
    if (totalBudget <= 0) return 0;
    return ((committedBudget / totalBudget) * 100).round();
  }

  bool get isEmpty => totalItems == 0;
}

/// `1,234,567` — plain grouping; the UI adds the currency symbol.
String formatProcurementAmount(double value) {
  final rounded = value.round();
  return rounded.toString().replaceAllMapped(
        RegExp(r'\B(?=(\d{3})+(?!\d))'),
        (match) => ',',
      );
}

String _dateLabel(DateTime? date) {
  if (date == null) return 'TBD';
  const months = <String>[
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  final month = months[date.month - 1];
  final day = date.day.toString().padLeft(2, '0');
  return '$month $day, ${date.year}';
}
