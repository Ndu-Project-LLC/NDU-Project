import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ndu_project/cost_estimate/models/cost_estimate_models.dart';
import 'package:ndu_project/cost_estimate/providers/cost_estimate_provider.dart';
import 'package:ndu_project/models/project_data_model.dart' hide ScheduleActivity;

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  List<CostEstimateItem> initiationItems() => [
        CostEstimateItem(
          title: 'Detailed engineering design',
          amount: 120000,
          costType: 'labor',
          phase: 'design',
        ),
        CostEstimateItem(
          title: 'Road construction works',
          amount: 480000,
          costType: 'construction',
          phase: 'execution',
          workPackageTitle: 'Road Construction',
        ),
        // Zero-amount items must be skipped.
        CostEstimateItem(title: 'Placeholder', amount: 0),
      ];

  test('importing initiation-phase cost items populates lines and totals',
      () {
    final provider = CostEstimateProvider();
    provider.setup(
      projectName: 'Chipata—Lundazi Road',
      className: EstimateClass.class3,
      deliveryModel: DeliveryModel.waterfall,
    );
    expect(provider.estimate!.lines, isEmpty);
    expect(provider.estimate!.totals.costBaseline, 0);

    final imported = provider.importFromProjectCostEstimateItems(
      initiationItems(),
    );

    expect(imported, isTrue);
    final estimate = provider.estimate!;
    // 2 of 3 items (zero-amount placeholder skipped).
    expect(estimate.lines.length, 2);
    // Dashboard KPIs read `totals` — must no longer stay at $0.
    expect(estimate.totals.costBaseline, 600000);
    // Mgmt reserve defaults to 0, so authorized == baseline (not $0).
    expect(estimate.totals.totalAuthorizedBudget, 600000);
  });

  test('import is idempotent — never duplicates on later rebuilds', () {
    final provider = CostEstimateProvider();
    provider.setup(
      projectName: 'P',
      className: EstimateClass.class3,
      deliveryModel: DeliveryModel.waterfall,
    );
    final items = initiationItems();

    expect(provider.importFromProjectCostEstimateItems(items), isTrue);
    // Module screen re-triggers on every build while lines exist — must no-op.
    expect(provider.importFromProjectCostEstimateItems(items), isFalse);
    expect(provider.estimate!.lines.length, 2);
    expect(provider.estimate!.totals.costBaseline, 600000);
  });

  test('late-arriving initiation data still populates (async load race)',
      () async {
    final provider = CostEstimateProvider();
    provider.setup(
      projectName: 'P',
      className: EstimateClass.class3,
      deliveryModel: DeliveryModel.waterfall,
    );

    // Simulate the module screen's build-time trigger firing after project
    // data has loaded asynchronously (the bug scenario): the import runs
    // from a post-frame callback well after setup().
    await Future<void>.delayed(Duration.zero);
    final imported =
        provider.importFromProjectCostEstimateItems(initiationItems());

    expect(imported, isTrue);
    expect(provider.estimate!.lines.length, 2);
    expect(provider.estimate!.totals.costBaseline, 600000);
  });
}
