// Lusaka 27, on the Interface Management RACI & Governance tab:
//
//   "I'm not sure how this came about. So this information you detailed got
//    filled up from where, what's that information?"
//   "when did you assign yourself to that?"
//
// Nobody assigns anything: each row is an interface from the Interface Register
// and each letter is read from that interface's own field. These tests pin the
// mapping (so the screen cannot quietly re-derive it) and pin that Informed is
// honestly "Not set" rather than an invented value on every row.

import 'package:flutter_test/flutter_test.dart';

import 'package:ndu_project/models/interface_raci.dart';
import 'package:ndu_project/models/project_data_model.dart';

InterfaceEntry _entry({
  String boundary = 'Payment Gateway',
  String owner = 'A. Banda',
  String partyA = 'APIs Team',
  String partyB = 'Finance Team',
  String cadence = 'Weekly',
  String lastSync = '',
  String escalationPath = '',
  String status = 'Open',
}) {
  return InterfaceEntry(
    boundary: boundary,
    owner: owner,
    partyA: partyA,
    partyB: partyB,
    cadence: cadence,
    lastSync: lastSync,
    escalationPath: escalationPath,
    status: status,
  );
}

void main() {
  group('roles', () {
    test('carry the letters the matrix shows', () {
      expect(
        RaciRole.values.map((r) => r.letter),
        ['R', 'A', 'C', 'I'],
      );
    });

    test('name the register field each letter is read from', () {
      expect(RaciRole.responsible.sourceField, 'Party A (provider)');
      expect(RaciRole.accountable.sourceField, 'Owner');
      expect(RaciRole.consulted.sourceField, 'Party B (receiver)');
      expect(RaciRole.informed.sourceField,
          'not captured on the register yet');
    });

    test('only the informed role has nothing on the register behind it', () {
      expect(RaciRole.responsible.isCaptured, isTrue);
      expect(RaciRole.accountable.isCaptured, isTrue);
      expect(RaciRole.consulted.isCaptured, isTrue);
      expect(RaciRole.informed.isCaptured, isFalse);
    });

    test('read as a legend line', () {
      expect(RaciRole.responsible.legendLine, contains('does the work'));
      expect(RaciRole.accountable.legendLine, contains('owns the outcome'));
      expect(RaciRole.consulted.legendLine, contains('provides input'));
      expect(RaciRole.informed.legendLine,
          'I — not captured on the register yet');
    });
  });

  group('a register entry becomes a matrix row', () {
    test('R is Party A, A is the owner, C is Party B', () {
      final row = InterfaceRaciRow.fromEntry(_entry(), number: 1);
      expect(row.responsible, 'APIs Team');
      expect(row.accountable, 'A. Banda');
      expect(row.consulted, 'Finance Team');
    });

    test('Informed is never invented', () {
      final row = InterfaceRaciRow.fromEntry(_entry(), number: 1);
      expect(row.informed, isEmpty);
      expect(row.valueFor(RaciRole.informed), kRaciNotSet);
      expect(row.isFilled(RaciRole.informed), isFalse);
    });

    test('a blank value reads as Not set, not as a dash or a guess', () {
      final row = InterfaceRaciRow.fromEntry(
        _entry(owner: '  ', partyA: '', partyB: ''),
        number: 3,
      );
      expect(row.valueFor(RaciRole.responsible), kRaciNotSet);
      expect(row.valueFor(RaciRole.accountable), kRaciNotSet);
      expect(row.valueFor(RaciRole.consulted), kRaciNotSet);
      expect(row.isFilled(RaciRole.accountable), isFalse);
    });

    test('carries the governance fields for the second table', () {
      final row = InterfaceRaciRow.fromEntry(
        _entry(
          cadence: 'Monthly',
          lastSync: 'Sep 12, 2026',
          escalationPath: 'PM → Sponsor',
        ),
        number: 1,
      );
      expect(row.cadence, 'Monthly');
      expect(row.lastSync, 'Sep 12, 2026');
      expect(row.escalationPath, 'PM → Sponsor');
      expect(row.status, 'Open');
    });

    test('trims every value it carries across', () {
      final row = InterfaceRaciRow.fromEntry(
        _entry(boundary: '  Payment Gateway  ', owner: ' A. Banda '),
        number: 1,
      );
      expect(row.name, 'Payment Gateway');
      expect(row.accountable, 'A. Banda');
    });

    test('an unnamed or unstatused interface still renders', () {
      final row = InterfaceRaciRow.fromEntry(
        _entry(boundary: '   ', status: ''),
        number: 1,
      );
      expect(row.name, 'Unnamed interface');
      expect(row.status, 'Pending');
    });

    test('numbers the rows in register order', () {
      final rows = InterfaceRaciRow.fromEntries([
        _entry(boundary: 'A'),
        _entry(boundary: 'B'),
        _entry(boundary: 'C'),
      ]);
      expect(rows.map((r) => r.number), [1, 2, 3]);
      expect(rows.map((r) => r.name), ['A', 'B', 'C']);
    });

    test('no entries means no rows', () {
      expect(InterfaceRaciRow.fromEntries(const []), isEmpty);
    });
  });

  group('gaps on a row', () {
    test('flags a missing accountable owner and the governance holes', () {
      final row = InterfaceRaciRow.fromEntry(_entry(owner: ''), number: 1);
      expect(row.hasNoAccountable, isTrue);
      expect(row.hasGovernanceGap, isTrue);
    });

    test('a fully populated row has nothing to flag', () {
      final row = InterfaceRaciRow.fromEntry(
        _entry(lastSync: 'Sep 12, 2026'),
        number: 1,
      );
      expect(row.hasNoResponsible, isFalse);
      expect(row.hasNoAccountable, isFalse);
      expect(row.hasNoConsulted, isFalse);
      expect(row.hasNoCadence, isFalse);
      expect(row.isNeverSynced, isFalse);
      expect(row.hasGovernanceGap, isFalse);
    });
  });

  group('coverage', () {
    test('an empty matrix is zero everywhere', () {
      expect(RaciCoverage.fromRows(const []), RaciCoverage.empty);
      expect(RaciCoverage.empty.isEmpty, isTrue);
      expect(RaciCoverage.empty.hasGaps, isFalse);
    });

    test('counts each kind of hole across the matrix', () {
      final rows = InterfaceRaciRow.fromEntries([
        _entry(boundary: 'A', owner: '', lastSync: 'Sep 1, 2026'),
        _entry(boundary: 'B', partyA: '', cadence: ''),
        _entry(boundary: 'C', partyB: ''),
      ]);
      final coverage = RaciCoverage.fromRows(rows);
      expect(coverage.total, 3);
      expect(coverage.missingAccountable, 1);
      expect(coverage.missingResponsible, 1);
      expect(coverage.missingConsulted, 1);
      expect(coverage.missingCadence, 1);
      // Only the first row carries a last-sync date.
      expect(coverage.neverSynced, 2);
      expect(coverage.hasGaps, isTrue);
      expect(coverage.gaps, 6);
    });

    test('a complete matrix has no gaps', () {
      final rows = InterfaceRaciRow.fromEntries([
        _entry(lastSync: 'Sep 12, 2026'),
        _entry(boundary: 'Data Warehouse', lastSync: 'Sep 14, 2026'),
      ]);
      final coverage = RaciCoverage.fromRows(rows);
      expect(coverage.total, 2);
      expect(coverage.gaps, 0);
      expect(coverage.hasGaps, isFalse);
    });
  });
}
