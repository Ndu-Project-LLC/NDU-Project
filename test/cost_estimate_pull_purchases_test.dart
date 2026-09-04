import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ndu_project/cost_estimate/models/cost_estimate_models.dart';
import 'package:ndu_project/cost_estimate/providers/cost_estimate_provider.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  CostEstimateProvider _fresh() {
    final provider = CostEstimateProvider();
    provider.setup(
      projectName: 'P',
      className: EstimateClass.class3,
      deliveryModel: DeliveryModel.waterfall,
    );
    return provider;
  }

  List<ScheduledPurchaseCandidate> _candidates() => const [
        ScheduledPurchaseCandidate(
          activityId: 'buy_1',
          title: 'Buy CPE Pumps',
          wbsRef: 'G1.1.1',
        ),
        ScheduledPurchaseCandidate(
          activityId: 'buy_2',
          title: 'Buy Steel Beams',
          wbsRef: 'G2.1',
        ),
        ScheduledPurchaseCandidate(
          activityId: 'buy_3',
          title: 'Buy Paint (no WBS yet)',
        ),
      ];

  test('pulls purchases as procurement lines marked in-schedule', () {
    final provider = _fresh();
    final result = provider.pullScheduledPurchases(_candidates());

    expect(result.pulled, 3);
    expect(result.alreadyInEstimate, 0);
    expect(result.addedByActivityId.keys.toSet(), {'buy_1', 'buy_2', 'buy_3'});

    final lines = provider.estimate!.lines;
    expect(lines.length, 3);
    for (final line in lines) {
      expect(line.category, CostCategory.procurement);
      expect(line.inSchedule, isTrue);
      expect(line.aiGenerated, isFalse);
    }
    // WBS refs carried over for WBS-linked purchases.
    expect(
        lines.firstWhere((l) => l.description == 'Buy CPE Pumps').wbsRef,
        'G1.1.1');
    expect(
        lines.firstWhere((l) => l.description == 'Buy Steel Beams').wbsRef,
        'G2.1');
    // No WBS → line still created, just without a ref (user links later).
    expect(
        lines.firstWhere((l) => l.description == 'Buy Paint (no WBS yet)')
            .wbsRef,
        isNull);
    // Lines start at $0: schedule stores no money — user prices them later.
    expect(provider.estimate!.totals.costBaseline, 0);
  });

  test('idempotent — second pull adds nothing and reports already', () {
    final provider = _fresh();
    final first = provider.pullScheduledPurchases(_candidates());
    expect(first.pulled, 3);

    final second = provider.pullScheduledPurchases(_candidates());
    expect(second.pulled, 0);
    expect(second.alreadyInEstimate, 3);
    expect(provider.estimate!.lines.length, 3);
  });

  test('activity already linked via costLineId counts as represented', () {
    final provider = _fresh();
    final result = provider.pullScheduledPurchases(
        _candidates().take(1).toList());
    final stampedId = result.addedByActivityId['buy_1'];

    // Genuinely linked (costLineId resolves to a live line) → represented.
    final linked = provider.pullScheduledPurchases([
      ScheduledPurchaseCandidate(
        activityId: 'buy_1',
        title: 'Buy CPE Pumps',
        wbsRef: 'G1.1.1',
        activityCostLineId: stampedId,
      ),
    ]);
    expect(linked.pulled, 0);
    expect(linked.alreadyInEstimate, 1);

    // Dangling link (stale costLineId) but an identical in-schedule line
    // exists → still represented by content; no duplicate is created.
    final dangling = provider.pullScheduledPurchases([
      const ScheduledPurchaseCandidate(
        activityId: 'buy_1',
        title: 'Buy CPE Pumps',
        wbsRef: 'G1.1.1',
        activityCostLineId: 'stale_id_that_was_deleted',
      ),
    ]);
    expect(dangling.pulled, 0);
    expect(dangling.alreadyInEstimate, 1);
    expect(provider.estimate!.lines.length, 1,
        reason: 'no duplicate for a content-identical purchase');
  });

  test('no estimate → empty result (module auto-setup covers this)', () {
    final provider = CostEstimateProvider();
    final result = provider.pullScheduledPurchases(_candidates());
    expect(result.pulled, 0);
    expect(result.alreadyInEstimate, 0);
  });
}
