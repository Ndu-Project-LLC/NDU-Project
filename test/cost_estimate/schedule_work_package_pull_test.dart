// Tests for CostEstimateProvider.pullScheduleWorkPackages — the data movement
// half of "the cost estimate starts from the Schedule" (voice note 2026-09-10).
//
// Two properties matter most here:
//   1. Pulled lines start at $0, so seeding the estimate from the schedule can
//      never move a total until a human prices something.
//   2. The pull is idempotent, so pressing the button twice does not duplicate
//      the estimate.

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ndu_project/cost_estimate/models/cost_estimate_models.dart';
import 'package:ndu_project/cost_estimate/providers/compute_utils.dart';
import 'package:ndu_project/cost_estimate/providers/cost_estimate_provider.dart';

CostEstimateProvider readyEstimate() {
  final provider = CostEstimateProvider();
  provider.setup(
    projectName: 'Test Project',
    className: EstimateClass.class3,
    deliveryModel: DeliveryModel.waterfall,
  );
  return provider;
}

ScheduleWorkPackageCandidate candidate(
  String activityId, {
  String title = 'Work package',
  String? wbsRef,
  CostCategory category = CostCategory.labor,
  String? activityCostLineId,
}) {
  return ScheduleWorkPackageCandidate(
    activityId: activityId,
    title: title,
    wbsRef: wbsRef,
    category: category,
    activityCostLineId: activityCostLineId,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('pullScheduleWorkPackages', () {
    test('creates one unpriced direct line per work package', () {
      final ce = readyEstimate();
      final result = ce.pullScheduleWorkPackages([
        candidate('a1', title: 'Pour foundations', wbsRef: 'G1.1'),
        candidate('a2',
            title: 'Erect steel',
            wbsRef: 'G1.2',
            category: CostCategory.construction),
      ]);

      expect(result.pulled, 2);
      expect(result.alreadyInEstimate, 0);
      expect(result.addedByActivityId.keys.toSet(), {'a1', 'a2'});

      final lines = ce.estimate!.lines;
      expect(lines, hasLength(2));
      expect(lines[0].description, 'Pour foundations');
      expect(lines[0].wbsRef, 'G1.1');
      expect(lines[0].category, CostCategory.labor);
      expect(lines[1].category, CostCategory.construction);
      for (final line in lines) {
        expect(line.total, 0, reason: 'unpriced until a human estimates it');
        expect(line.inSchedule, isTrue);
        expect(line.aiGenerated, isFalse);
        expect(line.subCategory, 'Schedule work package');
      }
    });

    test('seeding from the schedule cannot move the baseline by itself', () {
      final ce = readyEstimate();
      ce.pullScheduleWorkPackages([
        candidate('a1'),
        candidate('a2'),
        candidate('a3'),
      ]);

      final totals = ComputeUtils.computeTotals(ce.estimate!.lines);
      expect(totals.costBaseline, 0);
      expect(totals.totalAuthorizedBudget, 0);
      expect(totals.direct, 0);
    });

    test('is idempotent — a second pull adds nothing', () {
      final ce = readyEstimate();
      final candidates = [
        candidate('a1', title: 'One', wbsRef: 'G1'),
        candidate('a2', title: 'Two', wbsRef: 'G2'),
      ];

      expect(ce.pullScheduleWorkPackages(candidates).pulled, 2);
      final second = ce.pullScheduleWorkPackages(candidates);

      expect(second.pulled, 0);
      expect(second.alreadyInEstimate, 2);
      expect(ce.estimate!.lines, hasLength(2));
    });

    test('skips a work package already linked through its activity costLineId',
        () {
      final ce = readyEstimate();
      final first = ce.pullScheduleWorkPackages([candidate('a1', title: 'One')]);
      final lineId = first.addedByActivityId['a1']!;

      final second = ce.pullScheduleWorkPackages([
        candidate('a1', title: 'One', activityCostLineId: lineId),
      ]);

      expect(second.pulled, 0);
      expect(second.alreadyInEstimate, 1);
      expect(ce.estimate!.lines, hasLength(1));
    });

    test('re-linking by a costLineId that no longer exists still pulls', () {
      final ce = readyEstimate();
      final result = ce.pullScheduleWorkPackages([
        candidate('a1', title: 'One', activityCostLineId: 'deleted_line'),
      ]);

      expect(result.pulled, 1);
    });

    test('does not duplicate a work package that shares title and WBS ref',
        () {
      final ce = readyEstimate();
      ce.pullScheduleWorkPackages([
        candidate('a1', title: 'Shared', wbsRef: 'G1'),
      ]);
      final result = ce.pullScheduleWorkPackages([
        // Same package seen through a different activity id (e.g. re-imported
        // schedule) — the description + WBS ref match is the weak signal.
        candidate('a2', title: 'Shared', wbsRef: 'G1'),
      ]);

      expect(result.pulled, 0);
      expect(result.alreadyInEstimate, 1);
      expect(ce.estimate!.lines, hasLength(1));
    });

    test('keeps distinct work packages that share a WBS ref', () {
      final ce = readyEstimate();
      final result = ce.pullScheduleWorkPackages([
        candidate('a1', title: 'Design', wbsRef: 'G1'),
        candidate('a2', title: 'Build', wbsRef: 'G1'),
      ]);

      expect(result.pulled, 2);
    });

    test('a blank wbsRef is stored as null, not an empty string', () {
      final ce = readyEstimate();
      ce.pullScheduleWorkPackages([candidate('a1', title: 'One', wbsRef: '  ')]);
      expect(ce.estimate!.lines.single.wbsRef, isNull);
    });

    test('trims the title and falls back when it is blank', () {
      final ce = readyEstimate();
      ce.pullScheduleWorkPackages([
        candidate('a1', title: '  Spaced  '),
        candidate('a2', title: '   '),
      ]);

      expect(ce.estimate!.lines[0].description, 'Spaced');
      expect(ce.estimate!.lines[1].description, 'Scheduled work package');
    });

    test('returns empty for no candidates or no estimate', () {
      expect(readyEstimate().pullScheduleWorkPackages(const []), isNotNull);

      final noEstimate = CostEstimateProvider();
      final result = noEstimate.pullScheduleWorkPackages([candidate('a1')]);
      expect(result.pulled, 0);
      expect(result.addedByActivityId, isEmpty);
    });

    test('an existing manual line is preserved alongside the pulled ones', () {
      final ce = readyEstimate();
      ce.addLine(CostLine(
        id: 'manual',
        category: CostCategory.materials,
        subCategory: '',
        description: 'Hand entered',
        total: 500,
        inSchedule: false,
        basisSource: CostSourceType.vendorQuote,
        aiGenerated: false,
      ));

      ce.pullScheduleWorkPackages([candidate('a1', title: 'From schedule')]);

      expect(ce.estimate!.lines, hasLength(2));
      // The manual line still carries its money; the pulled one is still $0.
      final totals = ComputeUtils.computeTotals(ce.estimate!.lines);
      expect(totals.direct, 500);
    });
  });

  group('representation checks', () {
    test('isScheduleWorkPackageRepresented matches before a pull', () {
      final ce = readyEstimate();
      const c = null;
      final target = candidate('a1', title: 'One', wbsRef: 'G1');
      expect(c, isNull);
      expect(ce.isScheduleWorkPackageRepresented(target), isFalse);
      ce.pullScheduleWorkPackages([target]);
      expect(ce.isScheduleWorkPackageRepresented(target), isTrue);
    });

    test('an identical line outside the schedule does not count as represented',
        () {
      final ce = readyEstimate();
      ce.addLine(CostLine(
        id: 'manual',
        category: CostCategory.labor,
        subCategory: '',
        description: 'One',
        wbsRef: 'G1',
        total: 10,
        inSchedule: false, // not on the schedule
        basisSource: CostSourceType.expertJudgment,
        aiGenerated: false,
      ));

      expect(
        ce.isScheduleWorkPackageRepresented(
            candidate('a1', title: 'One', wbsRef: 'G1')),
        isFalse,
      );
    });
  });
}
