import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ndu_project/cost_estimate/models/cost_estimate_models.dart';
import 'package:ndu_project/cost_estimate/providers/cost_estimate_provider.dart';
import 'package:ndu_project/schedule/models/schedule_models.dart';
import 'package:ndu_project/schedule/providers/schedule_provider.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  /// Mirrors the UI flow: pull scheduled purchases → stamp costLineId on the
  /// activity → price the line. The schedule-row badge renders from exactly
  /// two facts this test asserts: `activity.costLineId` resolves to a live
  /// estimate line, and that line is priced (total > 0) or not.
  test(
      'pull → stamp → price cycle leaves the activity linked to a priced line',
      () {
    // ── Schedule with a leaf purchase ────────────────────────────────
    final scheduleProvider = ScheduleProvider();
    scheduleProvider.setup(
      projectName: 'Test Project',
      deliveryModel: 'WATERFALL',
    );
    final root = scheduleProvider.schedule!.activities[0];
    final purchaseId = scheduleProvider.addActivity(
        root.id,
        const ScheduleActivity(
          id: '', // addActivity assigns a real id
          level: 1,
          code: '',
          name: 'Buy CPE Pumps',
          type: ActivityType.activity,
          domain: ScheduleDomain.procurement,
          dependencies: [],
          aiGenerated: false,
          children: [],
        ));

    // ── Cost estimate (auto-setup like the module does) ──────────────
    final costProvider = CostEstimateProvider();
    costProvider.setup(
      projectName: 'Test Project',
      className: EstimateClass.class3,
      deliveryModel: DeliveryModel.waterfall,
    );

    // Pull the scheduled purchase (module button action).
    final result = costProvider.pullScheduledPurchases([
      ScheduledPurchaseCandidate(
        activityId: purchaseId,
        title: 'Buy CPE Pumps',
      ),
    ]);
    expect(result.pulled, 1);
    final lineId = result.addedByActivityId[purchaseId]!;
    final pulled = costProvider.estimate!.lines.firstWhere((l) => l.id == lineId);

    // At pull time the line is NOT yet priced (badge would read amber).
    expect(pulled.total, 0);
    expect(pulled.category, CostCategory.procurement);
    expect(pulled.inSchedule, isTrue);

    // Stamp the activity — what the module does after a pull. The row badge
    // (Cost: not priced yet) renders because the link resolves.
    final freshRoot = scheduleProvider.schedule!.activities[0];
    final purchase = freshRoot.children.firstWhere((c) => c.id == purchaseId);
    scheduleProvider.updateActivity(
        purchaseId, purchase.copyWith(costLineId: lineId));

    // Second pull must not duplicate the linked purchase.
    final again = costProvider.pullScheduledPurchases([
      ScheduledPurchaseCandidate(
        activityId: purchaseId,
        title: 'Buy CPE Pumps',
        activityCostLineId: lineId,
      ),
    ]);
    expect(again.pulled, 0);
    expect(again.alreadyInEstimate, 1);
    expect(costProvider.estimate!.lines.length, 1);

    // Price the line (what the walkthrough dialog does on save). The badge
    // now flips to the green "Cost: $X" state.
    costProvider.updateLine(lineId, CostLine(
          id: lineId,
          category: CostCategory.procurement,
          subCategory: 'Scheduled purchase',
          description: 'Buy CPE Pumps',
          quantity: 1,
          unit: 'lump',
          rate: 1500,
          total: 1500,
          inSchedule: true,
          basisSource: CostSourceType.vendorQuote,
          aiGenerated: false,
        ));

    final pricedLine =
        costProvider.estimate!.lines.firstWhere((l) => l.id == lineId);
    expect(pricedLine.total, 1500);

    // The two facts the schedule row badge renders from:
    final stamped =
        scheduleProvider.schedule!.activities.first.children
            .firstWhere((c) => c.id == purchaseId);
    expect(stamped.costLineId, lineId, reason: 'activity points at the line');
    final linkedExists = costProvider.estimate!.lines.any(
        (l) => l.id == stamped.costLineId && l.total > 0);
    expect(linkedExists, isTrue,
        reason: 'linked line exists and is priced → green badge state');
  });
}
