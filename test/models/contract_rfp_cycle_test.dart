// Lusaka 27 review, on contracting:
//
//   "the contract price is going to be by contract basis … We can't have one
//    story for the entire project. It's going to be a contract by contract
//    basis."
//   "I think it should be a button where you click on it and it can pop up and
//    it can show you where the cycle [is] and you can choose which is going to
//    be where you are going to send out the [RFP]"
//   "We are going to give two weeks to have this scope out to them. We are
//    going to send out the RFP. We are going to give them four weeks to review
//    and respond … one week for clarification … two weeks to review the
//    contract and evaluate their responses … one week to give us all the
//    documentation … and then we are going to award the contract on this date.
//    So that is required for each of the contracts here."
//   "It is a very small contract and they can elect to keep that and say sole
//    source or award … so they're not forced to go through the [whole process]"
//
// These tests pin the owner's template, the stage dates the popup shows, and
// the two ways a contract can leave the cycle.

import 'package:flutter_test/flutter_test.dart';

import 'package:ndu_project/models/contract_rfp_cycle.dart';

ContractRfpCycle _defaults([String start = '2026-01-05']) =>
    ContractRfpCycle.withDefaults(DateTime.parse(start));

void main() {
  group('the owner\'s default template', () {
    test('is 2 / 4 / 1 / 2 / 1 weeks, ten weeks before award', () {
      expect(_defaults().weeksFor(RfpCycleStage.scopeOut), 2);
      expect(_defaults().weeksFor(RfpCycleStage.bidderResponse), 4);
      expect(_defaults().weeksFor(RfpCycleStage.clarification), 1);
      expect(_defaults().weeksFor(RfpCycleStage.evaluation), 2);
      expect(_defaults().weeksFor(RfpCycleStage.documentation), 1);
      expect(_defaults().totalWeeks, 10);
    });

    test('runs scope out → RFP issued → response → clarification → '
        'evaluation → documentation → award, in that order', () {
      final stages = _defaults().windows().map((w) => w.stage).toList();
      expect(stages, RfpCycleStage.values);
    });

    test('dates the stages from the start date with no gaps or overlaps', () {
      final cycle = _defaults(); // Monday 2026-01-05
      final windows = cycle.windows();

      final scopeOut = windows.firstWhere((w) => w.stage == RfpCycleStage.scopeOut);
      expect(scopeOut.start, DateTime(2026, 1, 5));
      expect(scopeOut.end, DateTime(2026, 1, 18)); // two weeks, inclusive

      final response =
          windows.firstWhere((w) => w.stage == RfpCycleStage.bidderResponse);
      expect(response.start, DateTime(2026, 1, 19));
      expect(response.end, DateTime(2026, 2, 15)); // four weeks

      final evaluation =
          windows.firstWhere((w) => w.stage == RfpCycleStage.evaluation);
      expect(evaluation.start, DateTime(2026, 2, 23));
      expect(evaluation.end, DateTime(2026, 3, 8));

      final documentation =
          windows.firstWhere((w) => w.stage == RfpCycleStage.documentation);
      expect(documentation.end, DateTime(2026, 3, 15));

      expect(cycle.windows().last.stage, RfpCycleStage.award);
      expect(cycle.awardDate, DateTime(2026, 3, 16));
    });

    test('milestones collapse onto a single date', () {
      final windows = _defaults().windows();
      for (final window in windows.where((w) => w.isMilestone)) {
        expect(window.start, window.end);
      }
    });

    test('reports the RFP issue date and the bid due date', () {
      final cycle = _defaults();
      expect(cycle.rfpIssuedDate, DateTime(2026, 1, 19));
      expect(cycle.bidDueDate, DateTime(2026, 2, 15));
    });
  });

  group('per contract, not per project', () {
    test('two contracts can run different cycles', () {
      final full = _defaults('2026-01-05');
      final fast = _defaults('2026-02-02').withStageWeeks(
        RfpCycleStage.bidderResponse,
        2,
      );
      expect(full.awardDate, isNot(equals(fast.awardDate)));
      expect(fast.awardDate, DateTime(2026, 3, 30));
    });

    test('stage durations are adjustable and clamped to 0..52 weeks', () {
      final cycle = _defaults()
          .withStageWeeks(RfpCycleStage.bidderResponse, 6)
          .withStageWeeks(RfpCycleStage.clarification, -3)
          .withStageWeeks(RfpCycleStage.evaluation, 999);
      expect(cycle.weeksFor(RfpCycleStage.bidderResponse), 6);
      expect(cycle.weeksFor(RfpCycleStage.clarification), 0);
      expect(cycle.weeksFor(RfpCycleStage.evaluation), 52);
    });

    test('a cycle can be back-planned from a target award date', () {
      final cycle = ContractRfpCycle.backPlanFromAwardDate(
        DateTime(2026, 3, 16),
      );
      expect(cycle.startDate, DateTime(2026, 1, 5));
      expect(cycle.awardDate, DateTime(2026, 3, 16));
    });
  });

  group('a small contract may skip the cycle', () {
    test('a skipped cycle has no windows and awards immediately', () {
      final cycle = ContractRfpCycle.skippedCycle(
        startDate: DateTime(2026, 1, 5),
        reason: 'Sole Source',
      );
      expect(cycle.isSkipped, isTrue);
      expect(cycle.windows(), isEmpty);
      expect(cycle.awardDate, DateTime(2026, 1, 5));
      expect(cycle.validate(), isNull);
    });

    test('skipping needs one of the known reasons', () {
      final missing = ContractRfpCycle.skippedCycle(
        startDate: DateTime(2026, 1, 5),
        reason: '',
      );
      expect(missing.validate(), contains('skips the RFP cycle'));
      expect(missing.summary, 'Skipped');

      final invented = ContractRfpCycle.skippedCycle(
        startDate: DateTime(2026, 1, 5),
        reason: 'Because',
      );
      expect(invented.validate(), contains('Unknown skip reason'));

      expect(kRfpCycleSkipReasons, contains('Sole Source'));
      expect(kRfpCycleSkipReasons, contains('Direct Award'));
    });

    test('a cycle can move between skipped and competitive', () {
      final competitive = _defaults();
      final skipped = competitive.asSkipped('Direct Award');
      expect(skipped.isSkipped, isTrue);
      final back = skipped.asCompetitive();
      expect(back.isSkipped, isFalse);
      expect(back.totalWeeks, competitive.totalWeeks);
    });
  });

  group('validation', () {
    test('a competitive cycle needs at least one week of work', () {
      var cycle = _defaults();
      for (final stage in ContractRfpCycle.adjustableStages) {
        cycle = cycle.withStageWeeks(stage, 0);
      }
      expect(cycle.totalWeeks, 0);
      expect(cycle.validate(), contains('at least one week'));
    });

    test('the default cycle is valid and reads as one line', () {
      final cycle = _defaults();
      expect(cycle.validate(), isNull);
      expect(cycle.summary, '10 wk cycle · award Mar 16, 2026');
    });
  });

  group('round trip', () {
    test('survives toMap/fromMap', () {
      final cycle = _defaults()
          .withStageWeeks(RfpCycleStage.bidderResponse, 3)
          .withStartDate(DateTime(2026, 4, 6, 14, 30));
      final restored = ContractRfpCycle.fromMap(cycle.toMap());
      expect(restored, isNotNull);
      expect(restored!.startDate, DateTime(2026, 4, 6));
      expect(restored.weeksFor(RfpCycleStage.bidderResponse), 3);
      expect(restored.awardDate, cycle.awardDate);
    });

    test('survives a skipped round trip', () {
      final cycle =
          ContractRfpCycle.skippedCycle(
        startDate: DateTime(2026, 4, 6),
        reason: 'Small Value Contract',
      );
      final restored = ContractRfpCycle.fromMap(cycle.toMap())!;
      expect(restored.isSkipped, isTrue);
      expect(restored.skipReason, 'Small Value Contract');
    });

    test('rejects a map without a start date, and defaults stage weeks', () {
      expect(ContractRfpCycle.fromMap(null), isNull);
      expect(ContractRfpCycle.fromMap(<String, dynamic>{}), isNull);
      final partial = ContractRfpCycle.fromMap(<String, dynamic>{
        'startDate': '2026-01-05',
      });
      expect(partial!.totalWeeks, 10);
    });
  });
}
