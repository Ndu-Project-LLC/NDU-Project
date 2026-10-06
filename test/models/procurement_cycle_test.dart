// The limited procurement cycle (Lusaka 27 follow-up): "it might not really
// have that whole cycle thing, but it might have like a limited cycle — like
// we will identify a few … items, and we will get their quotes, and then we
// will buy it." Same shape as the contract's RFP cycle, three stages instead
// of seven. These tests pin the calendar math and the round-trip.
import 'package:flutter_test/flutter_test.dart';

import 'package:ndu_project/models/procurement_cycle.dart';

void main() {
  group('the limited procurement cycle', () {
    test('has three stages, one of them a milestone', () {
      expect(ProcurementCycleStage.values.length, 3);
      expect(ProcurementCycleStage.identify.isMilestone, isFalse);
      expect(ProcurementCycleStage.quote.isMilestone, isFalse);
      expect(ProcurementCycleStage.purchase.isMilestone, isTrue);
      expect(ProcurementCycle.adjustableStages.length, 2);
    });

    test('runs the owner’s template: 1 wk identify, 2 wk quotes, then buy', () {
      final cycle = ProcurementCycle.withDefaults(DateTime(2026, 10, 1));
      expect(cycle.totalWeeks, 3);
      expect(cycle.purchaseDate, DateTime(2026, 10, 22));
      expect(cycle.summary, '3 wk cycle · purchase Oct 22, 2026');
    });

    test('the windows tile the calendar without gaps', () {
      final cycle = ProcurementCycle.withDefaults(DateTime(2026, 10, 1));
      final windows = cycle.windows();
      expect(windows.map((w) => w.stage).toList(),
          ProcurementCycleStage.values);
      expect(windows[0].start, DateTime(2026, 10, 1));
      expect(windows[0].end, DateTime(2026, 10, 7));
      expect(windows[1].start, DateTime(2026, 10, 8));
      expect(windows[1].end, DateTime(2026, 10, 21));
      // The milestone collapses onto the day after the last window.
      expect(windows[2].start, DateTime(2026, 10, 22));
      expect(windows[2].end, DateTime(2026, 10, 22));
      expect(windows[2].isMilestone, isTrue);
    });

    test('a stage week change moves the purchase date', () {
      final cycle =
          ProcurementCycle.withDefaults(DateTime(2026, 10, 1))
              .withStageWeeks(ProcurementCycleStage.quote, 4);
      expect(cycle.totalWeeks, 5);
      expect(cycle.purchaseDate, DateTime(2026, 11, 5));
    });

    test('a stage week is clamped to 0–52', () {
      final cycle = ProcurementCycle.withDefaults(DateTime(2026, 10, 1))
          .withStageWeeks(ProcurementCycleStage.identify, 99);
      expect(cycle.weeksFor(ProcurementCycleStage.identify), 52);
      expect(
        ProcurementCycle.withDefaults(DateTime(2026, 10, 1))
            .withStageWeeks(ProcurementCycleStage.identify, -3)
            .weeksFor(ProcurementCycleStage.identify),
        0,
      );
    });

    test('a zero-week cycle does not validate', () {
      final cycle = ProcurementCycle.withDefaults(DateTime(2026, 10, 1))
          .withStageWeeks(ProcurementCycleStage.identify, 0)
          .withStageWeeks(ProcurementCycleStage.quote, 0);
      expect(cycle.validate(), isNotNull);
      expect(
        ProcurementCycle.withDefaults(DateTime(2026, 10, 1)).validate(),
        isNull,
      );
    });

    test('round-trips through its map', () {
      final cycle = ProcurementCycle.withDefaults(DateTime(2026, 10, 1))
          .withStageWeeks(ProcurementCycleStage.quote, 3);
      final restored = ProcurementCycle.fromMap(cycle.toMap());
      expect(restored, cycle);
      expect(restored!.purchaseDate, cycle.purchaseDate);
    });

    test('fromMap returns null for junk input', () {
      expect(ProcurementCycle.fromMap(null), isNull);
      expect(ProcurementCycle.fromMap('nope'), isNull);
      expect(ProcurementCycle.fromMap(<String, dynamic>{}), isNull);
    });
  });
}
