// The review wanted the metrics available rather than chosen one by one, and the
// dashboard to reflect whatever Metrics Planning defines. These tests pin the
// rule that makes both true: a project that has chosen nothing still tracks a
// sensible default set, and a project that has chosen is never second-guessed.

import 'package:flutter_test/flutter_test.dart';

import 'package:ndu_project/utils/agile_metrics_catalog.dart';

void main() {
  group('the catalog', () {
    test('is the single list both screens read', () {
      expect(AgileMetricsCatalog.all, isNotEmpty);
      expect(AgileMetricsCatalog.byKey.length, AgileMetricsCatalog.all.length,
          reason: 'every metric key must be unique');
      expect(AgileMetricsCatalog.byKey['velocity']?.label, 'Velocity');
    });

    test('keeps the categories in a stable order and covers every metric', () {
      final categories = AgileMetricsCatalog.categories;

      expect(categories.first, 'Delivery');
      final covered = [
        for (final category in categories)
          ...AgileMetricsCatalog.inCategory(category),
      ];
      expect(covered.length, AgileMetricsCatalog.all.length);
    });

    test('marks business metrics as the optional end of the set', () {
      expect(AgileMetricsCatalog.byKey['customer_satisfaction']?.isBusiness, isTrue);
      expect(AgileMetricsCatalog.byKey['velocity']?.isBusiness, isFalse);
    });
  });

  group('which metrics a project tracks', () {
    test('a project that has chosen nothing gets the default set', () {
      final tracked = AgileMetricsCatalog.trackedMetrics(const {});

      expect(tracked.map((m) => m.key),
          containsAll(AgileMetricsCatalog.defaultTrackedKeys));
      expect(AgileMetricsCatalog.usesDefaultTrackedSet(const {}), isTrue,
          reason: 'the dashboard must be able to say these are the defaults');
      expect(tracked.map((m) => m.key), contains('velocity'));
      expect(tracked.map((m) => m.key), contains('sprint_predictability'));
    });

    test('an empty saved list is treated as "nothing chosen", not "none"', () {
      final tracked =
          AgileMetricsCatalog.trackedMetrics(const {'selectedMetrics': []});

      expect(tracked, isNotEmpty);
      expect(AgileMetricsCatalog.usesDefaultTrackedSet(const {'selectedMetrics': []}),
          isTrue);
    });

    test('a saved selection wins, in catalog order, with unknowns dropped', () {
      final tracked = AgileMetricsCatalog.trackedMetrics(const {
        'selectedMetrics': ['lead_time', 'velocity', 'not_a_metric'],
      });

      expect(tracked.map((m) => m.key), ['velocity', 'lead_time'],
          reason: 'catalog order, and no blank chip for an unknown key');
      expect(AgileMetricsCatalog.usesDefaultTrackedSet(const {
        'selectedMetrics': ['lead_time'],
      }), isFalse);
    });

    test('the default set does not include the whole catalog', () {
      expect(AgileMetricsCatalog.defaultTrackedKeys.length,
          lessThan(AgileMetricsCatalog.all.length),
          reason: 'a default that tracks everything is the same as choosing none');
    });
  });
}
