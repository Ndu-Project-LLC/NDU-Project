// Lusaka 25 (copy) review, on the SSHER section:
//
//   "what is the cost aspect for these things? … something very basic, like if
//    it says PPE required, just have a question on the cost for that"
//   "in that share costs … you can have them on the table and say cost items and
//    then estimated costs … that is how we can put our share costs into the cost
//    estimate."
//
// The rule the owner described has two halves and both matter: only a real
// purchase belongs in the estimate, and only a *priced* one. Getting either half
// wrong puts a number in the cost baseline that nobody stood behind — an
// internal control with no spend, or a purchase whose price is still unknown.

import 'package:flutter_test/flutter_test.dart';

import 'package:ndu_project/cost_estimate/utils/ssher_cost_lines.dart';
import 'package:ndu_project/models/project_data_model.dart';

SsherEntry _entry({
  String concern = 'PPE for site visitors',
  String category = 'safety',
  bool requiresPurchase = true,
  String estimatedCost = '12000',
}) {
  return SsherEntry(
    category: category,
    department: 'Operations',
    teamMember: 'A. Banda',
    concern: concern,
    riskLevel: 'High',
    mitigation: 'Issue at the gate',
    requiresPurchase: requiresPurchase,
    estimatedCost: estimatedCost,
  );
}

void main() {
  group('loosely typed amounts', () {
    test('parses the shapes an assessor actually types', () {
      expect(parseSsherAmount('12000'), 12000);
      expect(parseSsherAmount('12,000'), 12000);
      expect(parseSsherAmount(r'$12,000'), 12000);
      expect(parseSsherAmount('12 000'), 12000);
    });

    test('an amount nobody typed is zero, not a guess', () {
      expect(parseSsherAmount(''), 0);
      expect(parseSsherAmount('   '), 0);
      expect(parseSsherAmount('TBC'), 0);
    });
  });

  group('which SSHER items become cost lines', () {
    test('a priced purchase becomes a line', () {
      final lines = collectSsherCostLines(
        entries: [_entry(estimatedCost: r'$12,000')],
      );

      expect(lines, hasLength(1));
      expect(lines.single.description, 'PPE for site visitors');
      expect(lines.single.total, 12000);
      expect(lines.single.category, 'safety');
    });

    test('an item that needs no purchase carries no line', () {
      // "if it's something that needs to be bought for the project" — a control
      // the project already covers is not a cost.
      final lines = collectSsherCostLines(
        entries: [_entry(requiresPurchase: false)],
      );

      expect(lines, isEmpty);
    });

    test('a purchase with no price waits instead of costing zero', () {
      final lines = collectSsherCostLines(
        entries: [_entry(estimatedCost: '')],
      );

      expect(lines, isEmpty);
    });

    test('a zero price is not a priced purchase', () {
      final lines = collectSsherCostLines(entries: [_entry(estimatedCost: '0')]);

      expect(lines, isEmpty);
    });

    test('an unnamed item is skipped', () {
      final lines = collectSsherCostLines(entries: [_entry(concern: '   ')]);

      expect(lines, isEmpty);
    });

    test('the SSHER discipline is carried through on every line', () {
      final lines = collectSsherCostLines(entries: [
        _entry(concern: 'Guard service', category: 'security'),
        _entry(concern: 'Air quality monitors', category: 'environment'),
        _entry(concern: 'Permit fee', category: 'regulatory'),
      ]);

      expect(lines.map((l) => l.category).toList(),
          ['security', 'environment', 'regulatory']);
    });

    test('the whole category is summed, not just the first item', () {
      final lines = collectSsherCostLines(entries: [
        _entry(concern: 'PPE', estimatedCost: '1000'),
        _entry(concern: 'Training', estimatedCost: '2500'),
        _entry(concern: 'Free control', requiresPurchase: false),
        _entry(concern: 'Unpriced audit', estimatedCost: ''),
      ]);

      expect(lines, hasLength(2));
      expect(lines.fold<double>(0, (s, l) => s + l.total), 3500);
    });
  });
}
