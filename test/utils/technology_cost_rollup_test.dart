import 'package:flutter_test/flutter_test.dart';
import 'package:ndu_project/utils/technology_cost_rollup.dart';

void main() {
  group('parseCostAmount', () {
    test('reads a plain amount', () {
      expect(parseCostAmount('12000'), 12000);
    });

    test('reads a currency-prefixed amount', () {
      expect(parseCostAmount(r'$12,000'), 12000);
      expect(parseCostAmount('£150'), 150);
    });

    test('reads a currency-suffixed amount', () {
      expect(parseCostAmount('150 GBP'), 150);
      expect(parseCostAmount('240 usd'), 240);
    });

    test(
        'prefers the price over the quantity in "qty @ price" form — the bug '
        'that made a total disagree with its rows', () {
      // The old parser took the first number, so this summed as 3 rather
      // than 4500.
      expect(parseCostAmount(r'3 licences @ $1500'), 1500);
      expect(parseCostAmount(r'12 users @ $25/month'), 25);
    });

    test('falls back to the largest number when no currency is present', () {
      expect(parseCostAmount('5 seats 1200'), 1200);
    });

    test('returns 0 for empty or non-numeric input', () {
      expect(parseCostAmount(''), 0);
      expect(parseCostAmount('TBC'), 0);
      expect(parseCostAmount('   '), 0);
    });

    test('never turns a placeholder into a silent zero-cost line', () {
      expect(parseCostAmount('n/a'), 0);
    });
  });

  group('detectCostPeriod', () {
    test('detects monthly forms', () {
      for (final raw in [
        r'$150/month',
        r'$150 per month',
        '150 monthly',
        '150 pcm',
        r'$150/mo',
      ]) {
        expect(detectCostPeriod(raw), CostPeriod.monthly, reason: raw);
      }
    });

    test('detects annual forms', () {
      for (final raw in [
        r'$1800/year',
        r'$1800 per year',
        '1800 yearly',
        '1800 annual',
        '1800 per annum',
        '1800 p.a.',
        r'$1800/yr',
      ]) {
        expect(detectCostPeriod(raw), CostPeriod.annual, reason: raw);
      }
    });

    test('defaults to one-time, matching the previous behaviour', () {
      expect(detectCostPeriod('12000'), CostPeriod.oneTime);
      expect(detectCostPeriod(r'$12,000'), CostPeriod.oneTime);
      expect(detectCostPeriod(''), CostPeriod.oneTime);
    });
  });

  group('rollUpTechnologyCosts', () {
    test('sums per table, subtotals one-time and recurring, and projects the '
        'grand total across the project months', () {
      final rollup = rollUpTechnologyCosts(
        items: [
          (table: 'Technology Inventory', name: 'Laptops', cost: r'$1500'),
          (
            table: 'Technology Inventory',
            name: 'Cloud',
            cost: r'$150/month',
          ),
          (
            table: 'AI Integrations',
            name: 'LLM API',
            cost: r'$300/month',
          ),
          (
            table: 'External Integrations',
            name: 'Payments',
            cost: r'$1200/year',
          ),
        ],
        months: 12,
      );

      expect(rollup.oneTime, 1500);
      expect(rollup.monthly, 450);
      expect(rollup.annual, 1200);
      expect(rollup.recurringPerMonth, 550);
      expect(rollup.recurringPerYear, 6600);

      final byTable = rollup.totalsByTable();
      expect(byTable['Technology Inventory'], 1500 + 150 * 12);
      expect(byTable['AI Integrations'], 300 * 12);
      expect(byTable['External Integrations'], 1200);

      // 1500 one-time + 550/month over a year.
      expect(rollup.grandTotal, 1500 + 550 * 12);
    });

    test('reprojects recurring spend when the project is longer', () {
      final items = [
        (
          table: 'AI Integrations',
          name: 'LLM API',
          cost: r'$150/month',
        ),
      ];
      expect(
        rollUpTechnologyCosts(items: items, months: 6).grandTotal,
        900,
      );
      expect(
        rollUpTechnologyCosts(items: items, months: 24).grandTotal,
        3600,
      );
    });

    test('does not count an unpriced row as zero', () {
      final rollup = rollUpTechnologyCosts(
        items: [
          (table: 'Technology Inventory', name: 'Laptops', cost: ''),
          (table: 'Technology Inventory', name: 'TBC item', cost: 'TBC'),
          (table: 'Technology Inventory', name: 'Cloud', cost: r'$100/month'),
        ],
        months: 12,
      );

      expect(rollup.lines.length, 1);
      expect(rollup.lines.single.name, 'Cloud');
      expect(rollup.grandTotal, 1200);
    });

    test('skips unnamed rows', () {
      final rollup = rollUpTechnologyCosts(
        items: [(table: 'Technology Inventory', name: '  ', cost: r'$500')],
        months: 12,
      );
      expect(rollup.lines, isEmpty);
      expect(rollup.grandTotal, 0);
    });

    test('falls back to a 12-month view when the duration is unusable', () {
      final rollup = rollUpTechnologyCosts(
        items: [
          (
            table: 'AI Integrations',
            name: 'LLM API',
            cost: r'$150/month',
          ),
        ],
        months: 0,
      );
      expect(rollup.months, 12);
      expect(rollup.grandTotal, 1800);
    });

    test('labels rows with no table as Other rather than dropping them', () {
      final rollup = rollUpTechnologyCosts(
        items: [(table: '', name: 'Misc', cost: '500')],
        months: 12,
      );
      expect(rollup.totalsByTable().keys, contains('Other'));
    });
  });

  group('projectMonthsBetween', () {
    test('counts whole months inclusively of the starting month', () {
      expect(
        projectMonthsBetween(DateTime(2026, 1, 1), DateTime(2026, 12, 31)),
        12,
      );
    });

    test('counts a part-month as a further month', () {
      expect(
        projectMonthsBetween(DateTime(2026, 1, 20), DateTime(2026, 2, 10)),
        2,
      );
    });

    test('returns 0 for missing or inverted dates so the caller can fall back',
        () {
      expect(projectMonthsBetween(null, DateTime(2026, 12, 1)), 0);
      expect(projectMonthsBetween(DateTime(2026, 1, 1), null), 0);
      expect(projectMonthsBetween(DateTime(2026, 6, 1), DateTime(2026, 1, 1)), 0);
    });
  });
}
