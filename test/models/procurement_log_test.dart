// Lusaka 27 review, on the procurement section:
//
//   "so I think I remember even a comment about this being a little busy, the
//    table makes sense, the things that were put in here didn't make sense, so
//    some of these look like contracts, but procured items are really supposed
//    to be like equipment and stuff like that."
//   "this procurement [log] to be at the top and it should have like the key
//    items that they plan to buy."
//   "I think I had a comment around the fact that you need to be items that will
//    be procured and then identify if they're gonna be long lead items."
//   "it's gonna be a dashboard that kind of shows the key status of the procured
//    items and the cost and all of that."
//
// One pure module owns the log columns, the row mapping, the long-lead rule and
// the overview numbers, so the log table and the dashboard above it cannot
// report different things.

import 'package:flutter_test/flutter_test.dart';

import 'package:ndu_project/models/procurement/procurement_models.dart';
import 'package:ndu_project/models/procurement_log.dart';

ProcurementItemModel _item({
  String id = 'i1',
  String name = 'Telemetry rack units',
  String description = 'Rack units for the farm',
  String category = 'Equipment',
  ProcurementItemStatus status = ProcurementItemStatus.planning,
  ProcurementPriority priority = ProcurementPriority.medium,
  double budget = 120000,
  double spent = 0,
  DateTime? estimatedDelivery,
  DateTime? requiredByDate,
  String? vendorId,
  double progress = 0.0,
}) {
  return ProcurementItemModel(
    id: id,
    projectId: 'p1',
    name: name,
    description: description,
    category: category,
    status: status,
    priority: priority,
    budget: budget,
    spent: spent,
    estimatedDelivery: estimatedDelivery,
    requiredByDate: requiredByDate,
    vendorId: vendorId,
    progress: progress,
    events: const [],
    notes: '',
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
    projectPhase: 'Planning',
    responsibleMember: '',
    comments: '',
    currencyCode: 'USD',
  );
}

void main() {
  final now = DateTime(2026, 6, 1);

  group('columns', () {
    test('are numbered and carry the item, the cost and the long-lead flag', () {
      expect(procurementLogColumns.first.key, 'number');
      expect(procurementLogColumns.first.label, '#');
      expect(
        procurementLogColumns.map((c) => c.label),
        containsAll(<String>[
          'Item',
          'Category',
          'Priority',
          'Long Lead',
          'Budget',
          'Est. Delivery',
          'Lead Time',
          'Vendor',
          'Status',
        ]),
      );
    });

    test('every column is answered by a row', () {
      final row = ProcurementLogRow.fromItem(_item(), number: 1, now: now);
      for (final column in procurementLogColumns) {
        expect(row.valueFor(column.key), isNotEmpty,
            reason: 'no value for ${column.key}');
      }
      expect(row.valueFor('nope'), '');
    });
  });

  group('row mapping', () {
    test('numbers rows and formats the budget', () {
      final row = ProcurementLogRow.fromItem(
        _item(budget: 1250000),
        number: 4,
        now: now,
      );
      expect(row.valueFor('number'), '4');
      expect(row.valueFor('budget'), r'$1,250,000');
    });

    test('an unknown budget reads TBD, not zero', () {
      final row =
          ProcurementLogRow.fromItem(_item(budget: 0), number: 1, now: now);
      expect(row.valueFor('budget'), 'TBD');
    });

    test('carries the category, priority and status labels', () {
      final row = ProcurementLogRow.fromItem(
        _item(
          category: 'IT Equipment',
          priority: ProcurementPriority.critical,
          status: ProcurementItemStatus.ordered,
        ),
        number: 1,
        now: now,
      );
      expect(row.valueFor('category'), 'IT Equipment');
      expect(row.valueFor('priority'), 'Critical');
      expect(row.valueFor('status'), 'Ordered');
      expect(row.isOrdered, isTrue);
    });

    test('falls back for a blank name and category', () {
      final row = ProcurementLogRow.fromItem(
        _item(name: '  ', category: ''),
        number: 1,
        now: now,
      );
      expect(row.valueFor('item'), 'Untitled item');
      expect(row.valueFor('category'), 'Uncategorised');
    });

    test('resolves the vendor name, or says it is not assigned', () {
      final linked = ProcurementLogRow.fromItem(
        _item(vendorId: 'v1'),
        number: 1,
        vendorName: 'Aquaflow Ltd',
        now: now,
      );
      expect(linked.valueFor('vendor'), 'Aquaflow Ltd');
      final unlinked =
          ProcurementLogRow.fromItem(_item(), number: 1, now: now);
      expect(unlinked.valueFor('vendor'), 'Not assigned');
    });

    test('dates and lead time come from the delivery date', () {
      final row = ProcurementLogRow.fromItem(
        _item(estimatedDelivery: DateTime(2026, 8, 10)),
        number: 1,
        now: now,
      );
      expect(row.valueFor('delivery'), 'Aug 10, 2026');
      expect(row.valueFor('leadTime'), '10 wks'); // Jun 1 → Aug 10
    });

    test('lead time falls back to the required-by date, then to TBD', () {
      final requiredBy = ProcurementLogRow.fromItem(
        _item(requiredByDate: DateTime(2026, 6, 15)),
        number: 1,
        now: now,
      );
      expect(requiredBy.valueFor('leadTime'), '2 wks');

      final undated =
          ProcurementLogRow.fromItem(_item(), number: 1, now: now);
      expect(undated.valueFor('leadTime'), 'TBD');
      expect(undated.valueFor('delivery'), 'TBD');
      expect(undated.leadTimeWeeks, isNull);
    });

    test('a delivery date in the past does not read as a negative lead time',
        () {
      final row = ProcurementLogRow.fromItem(
        _item(estimatedDelivery: DateTime(2026, 1, 5)),
        number: 1,
        now: now,
      );
      expect(row.valueFor('leadTime'), '0 wks');
      expect(row.leadTimeWeeks, 0);
    });
  });

  group('the long-lead rule', () {
    test('a critical or high priority item is long lead whatever its dates',
        () {
      expect(
        isLongLeadProcurementItem(
            _item(priority: ProcurementPriority.critical, category: 'Services'),
            now: now),
        isTrue,
      );
      expect(
        isLongLeadProcurementItem(
            _item(priority: ProcurementPriority.high, category: 'Services'),
            now: now),
        isTrue,
      );
    });

    test('equipment, materials and logistics are long lead', () {
      for (final category in <String>[
        'Equipment',
        'IT Equipment',
        'Raw materials',
        'Logistics',
      ]) {
        expect(
          isLongLeadProcurementItem(_item(category: category), now: now),
          isTrue,
          reason: category,
        );
      }
    });

    test('a far-off delivery date makes a low-priority service long lead', () {
      expect(
        isLongLeadProcurementItem(
          _item(
            priority: ProcurementPriority.low,
            category: 'Services',
            estimatedDelivery: now.add(const Duration(days: 90)),
          ),
          now: now,
        ),
        isTrue,
      );
      expect(
        isLongLeadProcurementItem(
          _item(
            priority: ProcurementPriority.low,
            category: 'Services',
            estimatedDelivery: now.add(const Duration(days: 10)),
          ),
          now: now,
        ),
        isFalse,
      );
    });

    test('an ordinary near-term item is not long lead', () {
      expect(
        isLongLeadProcurementItem(
            _item(priority: ProcurementPriority.medium, category: 'Office'),
            now: now),
        isFalse,
      );
    });
  });

  group('the overview summary', () {
    test('an empty log is zero everywhere, not a divide-by-zero', () {
      final summary = ProcurementStatusSummary.fromItems(const [], now: now);
      expect(summary.isEmpty, isTrue);
      expect(summary.totalItems, 0);
      expect(summary.totalBudget, 0);
      expect(summary.committedRate, 0);
    });

    test('counts the items, the long-lead ones and the money', () {
      final summary = ProcurementStatusSummary.fromItems(<ProcurementItemModel>[
        _item(id: 'a', category: 'Equipment', budget: 100000),
        _item(
          id: 'b',
          category: 'Services',
          priority: ProcurementPriority.critical,
          status: ProcurementItemStatus.ordered,
          budget: 50000,
        ),
        _item(
          id: 'c',
          category: 'Office',
          priority: ProcurementPriority.low,
          status: ProcurementItemStatus.delivered,
          budget: 25000,
        ),
      ], now: now);

      expect(summary.totalItems, 3);
      expect(summary.longLeadItems, 2); // the equipment and the critical one
      expect(summary.orderedItems, 1);
      expect(summary.deliveredItems, 1);
      expect(summary.notStartedItems, 1);
      expect(summary.totalBudget, 175000);
      expect(summary.committedBudget, 75000);
      expect(summary.committedRate, 43);
    });

    test('counts items needed before today that are not delivered or cancelled',
        () {
      final summary = ProcurementStatusSummary.fromItems(<ProcurementItemModel>[
        _item(id: 'a', requiredByDate: DateTime(2026, 5, 1)),
        _item(
          id: 'b',
          requiredByDate: DateTime(2026, 5, 1),
          status: ProcurementItemStatus.delivered,
        ),
        _item(
          id: 'c',
          requiredByDate: DateTime(2026, 5, 1),
          status: ProcurementItemStatus.cancelled,
        ),
        _item(id: 'd', estimatedDelivery: DateTime(2026, 12, 1)),
      ], now: now);
      expect(summary.overdueItems, 1);
    });
  });

  group('search', () {
    test('matches item, category, vendor, money and dates', () {
      final row = ProcurementLogRow.fromItem(
        _item(
          name: 'Telemetry rack units',
          category: 'IT Equipment',
          budget: 120000,
          estimatedDelivery: DateTime(2026, 8, 10),
        ),
        number: 1,
        vendorName: 'Aquaflow Ltd',
        now: now,
      );
      expect(row.matches(''), isTrue);
      expect(row.matches('TELEMETRY'), isTrue);
      expect(row.matches('aquaflow'), isTrue);
      expect(row.matches(r'$120,000'), isTrue);
      expect(row.matches('Aug 10'), isTrue);
      expect(row.matches('contracting'), isFalse);
    });
  });

  group('amount formatting', () {
    test('groups thousands without a currency symbol', () {
      expect(formatProcurementAmount(0), '0');
      expect(formatProcurementAmount(1000), '1,000');
      expect(formatProcurementAmount(1234567.8), '1,234,568');
    });
  });

  group('the PDF export table', () {
    test('headers are the log columns, in order', () {
      expect(procurementLogExportHeaders(), ProcurementLogRow.columnLabels);
      expect(
          procurementLogExportHeaders().length, procurementLogColumns.length);
      expect(procurementLogExportHeaders().first, '#');
      expect(procurementLogExportHeaders(), contains('Long Lead'));
    });

    test('one numbered row per item, in column order', () {
      final rows = procurementLogExportRows(
        <ProcurementItemModel>[
          _item(id: 'i1', name: 'Telemetry rack units'),
          _item(id: 'i2', name: 'Fibre drums'),
        ],
        vendorNames: const {'v1': 'Aquaflow Ltd'},
      );
      expect(rows.length, 2);
      expect(rows.every((r) => r.length == procurementLogColumns.length), isTrue,
          reason: 'every row must line up with the header');
      expect(rows.map((r) => r.first), ['1', '2']);
      expect(rows[1][1], 'Fibre drums');
    });

    test('names the vendor the way the on-screen table does', () {
      final rows = procurementLogExportRows(
        <ProcurementItemModel>[
          _item(name: 'Telemetry rack units', vendorId: 'v1'),
        ],
        vendorNames: const {'v1': 'Aquaflow Ltd'},
      );
      expect(rows.single, contains('Aquaflow Ltd'));
    });

    test('an item with no vendor resolves to Not assigned, and an empty log '
        'exports no rows', () {
      final rows = procurementLogExportRows(<ProcurementItemModel>[
        _item(name: 'Fibre drums'),
      ]);
      expect(rows.single, contains('Not assigned'));
      expect(procurementLogExportRows(const []), isEmpty);
    });
  });
}
