// Lusaka 27 review, on contracting:
//
//   "this is a table view which is good but … if you have five contracts you
//    want to be able to see your [contracts] … if you put on one you can expand
//    it, you can see all the details about it"
//   "that table needs to be here. As a default view … This is where they have
//    to go through the process of building it out."
//   "FEP scope input, that does not make sense to me. So if you have like the
//    contract, and the contract name, the scope, the potential value … then you
//    can do it there."
//
// The log is driven by one pure column set + row mapping, so the table, the
// CSV/PDF that follows it, and the search box cannot drift apart.

import 'package:flutter_test/flutter_test.dart';

import 'package:ndu_project/models/contract_log.dart';
import 'package:ndu_project/models/contract_rfp_cycle.dart';
import 'package:ndu_project/services/contract_service.dart';

ContractModel _contract({
  String id = 'c1',
  String name = 'Site preparation',
  String description = '',
  String scope = 'Bulk earthworks',
  String packageSummary = '',
  String contractType = 'Lump Sum (Fixed Price)',
  String? awardStrategy = 'Competitive Bidding',
  double estimatedValue = 1250000,
  String status = 'Not Started',
  String? linkedFepScopeId,
  ContractRfpCycle? rfpCycle,
  DateTime? targetAwardDate,
}) {
  return ContractModel(
    id: id,
    projectId: 'p1',
    name: name,
    description: description,
    contractType: contractType,
    paymentType: 'TBD',
    status: status,
    estimatedValue: estimatedValue,
    scope: scope,
    discipline: 'Civil',
    notes: '',
    createdById: 'u1',
    createdByEmail: 'a@b.c',
    createdByName: 'Ada',
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
    awardStrategy: awardStrategy,
    linkedFepScopeId: linkedFepScopeId,
    packageSummary: packageSummary.isEmpty ? null : packageSummary,
    rfpCycle: rfpCycle,
    targetAwardDate: targetAwardDate,
  );
}

void main() {
  group('columns', () {
    test('are numbered and carry the contract\'s own fields, not an '
        '"FEP scope input"', () {
      expect(contractLogColumns.first.key, 'number');
      expect(contractLogColumns.first.label, '#');
      expect(
        contractLogColumns.map((c) => c.label),
        containsAll(<String>[
          'Contract',
          'Scope',
          'Potential Value',
          'Award Strategy',
          'Type',
          'RFP Cycle',
          'Award Date',
          'Status',
        ]),
      );
      expect(
        contractLogColumns.map((c) => c.label),
        isNot(contains('FEP Scope Input')),
      );
    });

    test('every column has a value path on a row', () {
      final row = ContractLogRow.fromContract(
        _contract(
          rfpCycle: ContractRfpCycle.withDefaults(DateTime(2026, 1, 5)),
        ),
        number: 1,
      );
      for (final column in contractLogColumns) {
        expect(row.valueFor(column.key), isNotEmpty,
            reason: 'no value for ${column.key}');
      }
      expect(row.valueFor('unknown'), '');
    });
  });

  group('row mapping', () {
    test('numbers rows 1..n and formats the value', () {
      final row = ContractLogRow.fromContract(_contract(), number: 3);
      expect(row.number, 3);
      expect(row.valueFor('number'), '3');
      expect(row.valueFor('value'), '1,250,000');
    });

    test('shows TBD for an unknown value and award date', () {
      final row = ContractLogRow.fromContract(
        _contract(estimatedValue: 0, awardStrategy: null),
        number: 1,
      );
      expect(row.valueFor('value'), 'TBD');
      expect(row.valueFor('awardDate'), 'TBD');
      expect(row.valueFor('awardStrategy'), 'Not set');
      expect(row.valueFor('cycle'), 'Not set');
    });

    test('prefers the package summary over the raw scope for the Scope cell',
        () {
      final row = ContractLogRow.fromContract(
        _contract(packageSummary: 'Phase 1 enabling works'),
        number: 1,
      );
      expect(row.valueFor('scope'), 'Phase 1 enabling works');
    });

    test('falls back to the description when there is no scope', () {
      final row = ContractLogRow.fromContract(
        _contract(scope: '', description: 'Imported scope'),
        number: 2,
      );
      expect(row.valueFor('scope'), 'Imported scope');
    });

    test('summarises the per-contract cycle and its award date', () {
      final cycle = ContractRfpCycle.withDefaults(DateTime(2026, 1, 5));
      final row = ContractLogRow.fromContract(
        _contract(rfpCycle: cycle),
        number: 1,
      );
      expect(row.valueFor('cycle'), '10 wk cycle · award Mar 16, 2026');
      expect(row.valueFor('awardDate'), 'Mar 16, 2026');
      expect(row.hasRfpCycle, isTrue);
      expect(row.isReadyForMarket, isTrue);
    });

    test('a skipped cycle says so and awards on its start date', () {
      final row = ContractLogRow.fromContract(
        _contract(
          rfpCycle: ContractRfpCycle.skippedCycle(
            startDate: DateTime(2026, 5, 4),
            reason: 'Sole Source',
          ),
        ),
        number: 1,
      );
      expect(row.valueFor('cycle'), 'Skipped — Sole Source');
      expect(row.valueFor('awardDate'), 'May 04, 2026');
    });

    test('a set target award date is used when there is no cycle yet', () {
      final row = ContractLogRow.fromContract(
        _contract(targetAwardDate: DateTime(2026, 7, 1)),
        number: 1,
      );
      expect(row.valueFor('awardDate'), 'Jul 01, 2026');
      expect(row.hasRfpCycle, isFalse);
    });

    test('a contract without a strategy or a cycle is not market-ready', () {
      final row = ContractLogRow.fromContract(
        _contract(awardStrategy: null, contractType: ''),
        number: 1,
      );
      expect(row.isReadyForMarket, isFalse);
    });

    test('an unnamed contract still renders', () {
      final row =
          ContractLogRow.fromContract(_contract(name: '  '), number: 1);
      expect(row.valueFor('name'), 'Untitled contract');
    });
  });

  group('search', () {
    test('matches on any column, case-insensitively', () {
      final cycle = ContractRfpCycle.withDefaults(DateTime(2026, 1, 5));
      final row = ContractLogRow.fromContract(
        _contract(rfpCycle: cycle, linkedFepScopeId: 'scope_1'),
        number: 1,
      );
      expect(row.matches(''), isTrue);
      expect(row.matches('SITE PREP'), isTrue);
      expect(row.matches('earthworks'), isTrue);
      expect(row.matches('competitive'), isTrue);
      expect(row.matches('1,250,000'), isTrue);
      expect(row.matches('Mar 16'), isTrue);
      expect(row.matches('procurement'), isFalse);
    });
  });

  group('value formatting', () {
    test('groups thousands without a currency symbol', () {
      expect(formatContractValue(0), '0');
      expect(formatContractValue(999), '999');
      expect(formatContractValue(1000), '1,000');
      expect(formatContractValue(1234567.8), '1,234,568');
    });
  });

  group('the PDF export table', () {
    test('headers are the log columns, in order', () {
      expect(contractLogExportHeaders(), ContractLogRow.columnLabels);
      expect(contractLogExportHeaders().length, contractLogColumns.length);
      expect(contractLogExportHeaders().first, '#');
    });

    test('one numbered row per contract, in column order', () {
      final rows = contractLogExportRows(<ContractModel>[
        _contract(id: 'c1', name: 'Site preparation'),
        _contract(id: 'c2', name: 'Telemetry units'),
      ]);
      expect(rows.length, 2);
      expect(rows.every((r) => r.length == contractLogColumns.length), isTrue,
          reason: 'every row must line up with the header');
      expect(rows.map((r) => r.first), ['1', '2']);
      expect(rows[1][1], 'Telemetry units');
    });

    test('an empty log exports no rows', () {
      expect(contractLogExportRows(const []), isEmpty);
    });
  });
}
