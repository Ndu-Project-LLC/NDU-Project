// Lusaka 27 review, on the Planning Risk Assessment:
//
//   "We already have a risk table. I think that we have either in the
//    [initiation] or in FEP. … this table has to be the exact same table."
//   "the risk management section in the planning section should start off from
//    this … the table of course is needed with the ID numbers, the title, the
//    description, what category it is, the probability."
//   "So in planning, there are 14 medium risks. Here they are showing three high
//    and three medium … That means it didn't take this information."
//
// So the column set and the row mapping live in one pure module
// (`lib/models/risk_log.dart`) that both the FEP risk register and the Planning
// Risk Assessment read, from the same store. These tests pin the columns and the
// mapping, which is what keeps the two views — and the numbers they report —
// from drifting apart again.

import 'package:flutter_test/flutter_test.dart';

import 'package:ndu_project/models/project_data_model.dart';
import 'package:ndu_project/models/risk_log.dart';

RiskRegisterItem _item({
  String riskName = '',
  String description = '',
  String category = '',
  String likelihood = '',
  String impactLevel = '',
  double costImpactMostLikely = 0,
  int scheduleImpactMostLikely = 0,
  String mitigationStrategy = '',
  String discipline = '',
  String projectRole = '',
  String owner = '',
  String status = '',
}) {
  return RiskRegisterItem(
    riskName: riskName,
    description: description,
    category: category,
    likelihood: likelihood,
    impactLevel: impactLevel,
    costImpactMostLikely: costImpactMostLikely,
    scheduleImpactMostLikely: scheduleImpactMostLikely,
    mitigationStrategy: mitigationStrategy,
    discipline: discipline,
    projectRole: projectRole,
    owner: owner,
    status: status,
  );
}

void main() {
  group('the columns are Front End Planning’s risk log columns', () {
    test('in table order, without the FEP-only Action control', () {
      expect(
        [for (final column in riskLogColumns) column.label],
        [
          'ID',
          'Risk Title',
          'Description',
          'Category',
          'Probability',
          'Impact',
          // Lusaka 27 follow-up: "you have the potential cost impact with the
          // schedule impact … that is all done on the table".
          'Cost Impact',
          'Schedule Impact',
          'Risk Level',
          'Mitigation',
          'Discipline',
          'Project Role',
          'Owner',
          'Status',
        ],
      );
    });

    test('every column key is answered by a row', () {
      final row = RiskLogRow.fromRegisterItem(_item(riskName: 'x'), 0);
      for (final column in riskLogColumns) {
        expect(row.valueFor(column.key), isNotNull,
            reason: '${column.key} must be a known column');
      }
      // An unknown key is empty rather than a crash.
      expect(row.valueFor('nope'), '');
    });

    test('values and labels line up position by position', () {
      final row = RiskLogRow.fromRegisterItem(
        _item(riskName: 'Scope creep', owner: 'PM', status: 'Open'),
        0,
      );
      expect(row.values.length, RiskLogRow.columnLabels.length);
      expect(row.values[RiskLogRow.columnLabels.indexOf('Risk Title')],
          'Scope creep');
      expect(row.values[RiskLogRow.columnLabels.indexOf('Owner')], 'PM');
    });
  });

  group('a register item becomes one log row', () {
    test('every field carries across', () {
      final row = RiskLogRow.fromRegisterItem(
        _item(
          riskName: 'Long lead equipment slips',
          description: 'The telemetry racks arrive late',
          category: 'Procurement',
          likelihood: 'High',
          impactLevel: 'Medium',
          mitigationStrategy: 'Order early',
          discipline: 'Engineering',
          projectRole: 'Procurement Lead',
          owner: 'A. Owner',
          status: 'Open',
        ),
        0,
      );

      expect(row.id, '001');
      expect(row.title, 'Long lead equipment slips');
      expect(row.description, 'The telemetry racks arrive late');
      expect(row.category, 'Procurement');
      expect(row.probability, 'High');
      expect(row.impact, 'Medium');
      // No impact recorded → the columns read TBD, not a misleading zero.
      expect(row.valueFor('costImpact'), 'TBD');
      expect(row.valueFor('scheduleImpact'), 'TBD');
      expect(row.riskLevel, 'High');
      expect(row.mitigation, 'Order early');
      expect(row.discipline, 'Engineering');
      expect(row.projectRole, 'Procurement Lead');
      expect(row.owner, 'A. Owner');
      expect(row.status, 'Open');
    });

    test('cost and schedule impact carry across when recorded', () {
      final row = RiskLogRow.fromRegisterItem(
        _item(
          riskName: 'Flooding delays earthworks',
          costImpactMostLikely: 12500,
          scheduleImpactMostLikely: 12,
        ),
        0,
      );
      expect(row.costImpact, '\$12,500');
      expect(row.valueFor('costImpact'), '\$12,500');
      expect(row.scheduleImpact, '12 days');
      expect(row.valueFor('scheduleImpact'), '12 days');
    });

    test('a one-day schedule impact does not read as plural', () {
      final row = RiskLogRow.fromRegisterItem(
        _item(riskName: 'x', scheduleImpactMostLikely: 1),
        0,
      );
      expect(row.scheduleImpact, '1 day');
    });

    test('ids are numbered the way Front End Planning numbers them', () {
      final rows = RiskLogRow.fromRegisterItems([
        _item(riskName: 'a'),
        _item(riskName: 'b'),
        _item(riskName: 'c'),
      ]);
      expect([for (final row in rows) row.id], ['001', '002', '003']);
      expect(RiskLogRow.idForIndex(9), '010');
    });

    test('an unset status reads as Identified, not blank', () {
      final row = RiskLogRow.fromRegisterItem(_item(riskName: 'a'), 0);
      expect(row.status, 'Identified');
    });

    test('no register items means no rows', () {
      expect(RiskLogRow.fromRegisterItems(const []), isEmpty);
    });
  });

  group('the overall risk level', () {
    test('is High, Medium or Low for the usual pairs', () {
      expect(RiskLogRow.deriveRiskLevel('High', 'High'), 'High');
      expect(RiskLogRow.deriveRiskLevel('High', 'Medium'), 'High');
      expect(RiskLogRow.deriveRiskLevel('Medium', 'High'), 'High');
      expect(RiskLogRow.deriveRiskLevel('Medium', 'Medium'), 'Medium');
      expect(RiskLogRow.deriveRiskLevel('High', 'Low'), 'Medium');
      expect(RiskLogRow.deriveRiskLevel('Low', 'Medium'), 'Low');
      expect(RiskLogRow.deriveRiskLevel('Low', 'Low'), 'Low');
    });

    test('treats a blank scale as Medium, like Front End Planning does', () {
      expect(RiskLogRow.deriveRiskLevel('', ''), 'Medium');
    });

    test('reads a free-text scale by its first letter', () {
      expect(RiskLogRow.normalizeScale(' high '), 'High');
      expect(RiskLogRow.normalizeScale('M'), 'Medium');
      expect(RiskLogRow.normalizeScale('low'), 'Low');
      expect(RiskLogRow.normalizeScale('', fallback: 'Low'), 'Low');
      expect(RiskLogRow.normalizeScale('unknown'), 'Medium');
    });
  });
}
