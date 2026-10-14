// Lusaka 27 review, on the Planning Risk Assessment being sign-off gated:
//
//   "I confirm that I have reviewed this with all the key stakeholders. And we
//    have estimated this number as accepted. So that needs to be required for
//    the risk assessment section. But this is a required section for sure."
//   "for the top risks like say the high [ones] … we're going to require them to
//    have either like two to five top risks … those top risks they can then have
//    the specific [mitigation] plan for those top risks that can be seen
//    immediately"
//   "that is also going to be the cost estimate from the risk perspective. So it
//    is like 0.6 percent of the budget"
//
// The rule lives in `lib/models/risk_assessment_signoff.dart`, pure, so the
// screen's Next button and these tests read one definition of "this section is
// done". It is pinned here because the gate changes the flow, and a gate that
// quietly stops blocking is worse than no gate at all.

import 'package:flutter_test/flutter_test.dart';

import 'package:ndu_project/models/risk_assessment_signoff.dart';
import 'package:ndu_project/models/risk_log.dart';

RiskLogRow _row({
  required String id,
  String title = '',
  String description = '',
  String riskLevel = 'Medium',
  String mitigation = 'Monitor monthly',
}) {
  return RiskLogRow(
    id: id,
    title: title,
    description: description,
    category: '',
    probability: '',
    impact: '',
    costImpact: '',
    scheduleImpact: '',
    riskLevel: riskLevel,
    mitigation: mitigation,
    discipline: '',
    projectRole: '',
    owner: '',
    status: 'Open',
  );
}

/// Two populated risks, both mitigated: everything except the sign-off itself.
final _signedOffRows = [
  _row(id: '001', title: 'Scope creep', riskLevel: 'High'),
  _row(id: '002', title: 'Supplier delay', riskLevel: 'Medium'),
];

const _ready = RiskAssessmentSignoff(
  confirmed: true,
  reviewedOn: '2026-09-28',
  reviewCadence: 'Monthly',
);

void main() {
  group('the confirmation is the owner’s sentence, verbatim', () {
    test('and it is a required part of the section', () {
      expect(
        RiskAssessmentSignoff.confirmationSentence,
        'I confirm that I have reviewed this with all the key stakeholders.',
      );
      expect(RiskAssessmentSignoff.empty.confirmed, isFalse);
      expect(RiskAssessmentSignoff.empty.isComplete(_signedOffRows), isFalse);
    });
  });

  group('what blocks the section', () {
    test('an unticked confirmation blocks it first', () {
      const signoff = RiskAssessmentSignoff(
        reviewedOn: '2026-09-28',
        reviewCadence: 'Monthly',
      );
      expect(signoff.blockerFor(_signedOffRows), contains('confirmation'));
    });

    test('a missing review date blocks it', () {
      const signoff = RiskAssessmentSignoff(
        confirmed: true,
        reviewCadence: 'Monthly',
      );
      expect(signoff.blockerFor(_signedOffRows), contains('date'));
    });

    test('a missing review cadence blocks it', () {
      const signoff = RiskAssessmentSignoff(
        confirmed: true,
        reviewedOn: '2026-09-28',
      );
      expect(signoff.blockerFor(_signedOffRows), contains('often'));
    });

    test('a log with fewer than two risks blocks it', () {
      expect(_ready.blockerFor([_row(id: '001', title: 'Only one')]),
          contains('at least 2'));
      expect(_ready.blockerFor(const []), contains('at least 2'));
    });

    test('a top risk without a mitigation plan blocks it', () {
      final rows = [
        _row(id: '001', title: 'Scope creep', riskLevel: 'High'),
        _row(
            id: '002',
            title: 'Supplier delay',
            riskLevel: 'High',
            mitigation: '   '),
      ];
      expect(_ready.blockerFor(rows), contains('mitigation'));
    });

    test('all of it satisfied means the section is complete', () {
      expect(_ready.blockerFor(_signedOffRows), isNull);
      expect(_ready.isComplete(_signedOffRows), isTrue);
    });

    test('only the confirmation sentence is not enough on its own', () {
      const signoff = RiskAssessmentSignoff(confirmed: true);
      expect(signoff.isComplete(_signedOffRows), isFalse);
    });
  });

  group('the top risks', () {
    test('are the worst ones, High before Medium before Low', () {
      final rows = [
        _row(id: '001', riskLevel: 'Low'),
        _row(id: '002', riskLevel: 'High'),
        _row(id: '003', riskLevel: 'Medium'),
        _row(id: '004', riskLevel: 'High'),
      ];
      expect(
        [for (final row in RiskAssessmentSignoff.topRisks(rows)) row.id],
        ['002', '004', '003', '001'],
      );
    });

    test('keep log order within the same level, and cap at five', () {
      final rows = [
        _row(id: '001', riskLevel: 'High'),
        _row(id: '002', riskLevel: 'High'),
        _row(id: '003', riskLevel: 'Medium'),
        _row(id: '004', riskLevel: 'Medium'),
        _row(id: '005', riskLevel: 'Low'),
        _row(id: '006', riskLevel: 'Low'),
        _row(id: '007', riskLevel: 'Low'),
      ];
      final top = RiskAssessmentSignoff.topRisks(rows);
      expect(top.length, RiskAssessmentSignoff.maximumTopRisks);
      expect([for (final row in top) row.id], ['001', '002', '003', '004', '005']);
    });

    test('a short log is not padded out', () {
      expect(RiskAssessmentSignoff.topRisks(const []), isEmpty);
      expect(RiskAssessmentSignoff.topRisks([_row(id: '001')]).length, 1);
    });

    test('a blank level ranks as Medium, not as the worst', () {
      final rows = [
        _row(id: '001', riskLevel: ''),
        _row(id: '002', riskLevel: 'High'),
      ];
      expect(RiskAssessmentSignoff.topRisks(rows).first.id, '002');
    });

    test('the ones missing a mitigation plan are reported', () {
      final rows = [
        _row(id: '001', riskLevel: 'High', mitigation: ''),
        _row(id: '002', riskLevel: 'High', mitigation: 'Do the thing'),
      ];
      expect(
        [for (final row in RiskAssessmentSignoff.topRisksMissingMitigation(rows)) row.id],
        ['001'],
      );
      expect(
        RiskAssessmentSignoff.topRisksMissingMitigation(_signedOffRows),
        isEmpty,
      );
    });
  });

  group('the risk allowance', () {
    test('is 0.6 % of the budget', () {
      expect(RiskAssessmentSignoff.riskAllowancePercentOfBudget, 0.006);
      expect(RiskAssessmentSignoff.riskAllowanceLabel, '0.6% of budget');
      expect(RiskAssessmentSignoff.riskAllowanceFor(1000000), 6000);
      expect(RiskAssessmentSignoff.riskAllowanceFor(250000), 1500);
    });

    test('is zero while there is no budget to take it from', () {
      expect(RiskAssessmentSignoff.riskAllowanceFor(0), 0);
      expect(RiskAssessmentSignoff.riskAllowanceFor(-5), 0);
    });
  });

  group('the sign-off round-trips through the planning notes', () {
    test('and an empty notes map means nothing recorded', () {
      final restored =
          RiskAssessmentSignoff.fromPlanningNotes(const <String, String>{});
      expect(restored.confirmed, isFalse);
      expect(restored.reviewedOn, '');
      expect(restored.reviewCadence, '');
    });

    test('a full sign-off comes back unchanged', () {
      final restored =
          RiskAssessmentSignoff.fromPlanningNotes(_ready.toPlanningNotes());
      expect(restored.confirmed, isTrue);
      expect(restored.reviewedOn, '2026-09-28');
      expect(restored.reviewCadence, 'Monthly');
      expect(restored.isComplete(_signedOffRows), isTrue);
    });

    test('and it does not disturb the other planning notes', () {
      final notes = <String, String>{
        'planning_risk_assessment_notes': 'keep me',
        ..._ready.toPlanningNotes(),
      };
      expect(notes['planning_risk_assessment_notes'], 'keep me');
      expect(
          RiskAssessmentSignoff.fromPlanningNotes(notes).confirmed, isTrue);
    });
  });
}
