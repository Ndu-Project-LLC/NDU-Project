// Lusaka 25 (copy) review, on the Quality Management plan:
//
//   "if AI is off, I don't want to see AI generated anything"
//   "can you tie this function to AI being turned on and off?"
//   "it cannot be edited … they should be able to edit it, reject it, delete it.
//    We don't want them to be forced with anything."
//
// Two pieces of state make that possible, and both have to survive a save so the
// screen cannot start lying again after a reload:
//
//   * `ProjectDataModel.aiEnabled` — the one switch every AI surface reads.
//   * `QualityManagementData.aiGeneratedPlans` — which category's narrative AI
//     actually wrote, so the "(AI-Generated)" heading only appears while that is
//     still true (a rewrite or a delete has to clear it).
//
// The "absent means on / absent means nothing AI" cases are the ones that matter
// most: documents written before either field existed must not silently lose
// their AI, and must not retroactively start claiming AI wrote text it didn't.

import 'package:flutter_test/flutter_test.dart';

import 'package:ndu_project/models/project_data_model.dart';

void main() {
  group('the workspace AI switch', () {
    test('defaults to on', () {
      expect(ProjectDataModel().aiEnabled, isTrue);
    });

    test('can be turned off and back on', () {
      final off = ProjectDataModel().copyWith(aiEnabled: false);
      expect(off.aiEnabled, isFalse);

      final backOn = off.copyWith(aiEnabled: true);
      expect(backOn.aiEnabled, isTrue);
    });

    test('stays off across a save and reload', () {
      final off = ProjectDataModel().copyWith(aiEnabled: false);

      expect(ProjectDataModel.fromJson(off.toJson()).aiEnabled, isFalse);
    });

    test('a document saved before the switch existed loads with AI on', () {
      final legacy = ProjectDataModel().toJson()..remove('aiEnabled');

      expect(ProjectDataModel.fromJson(legacy).aiEnabled, isTrue);
    });

    test('only an explicit false turns AI off', () {
      final json = ProjectDataModel().toJson();

      expect(ProjectDataModel.fromJson(json..['aiEnabled'] = false).aiEnabled,
          isFalse);
      expect(
          ProjectDataModel.fromJson(json..['aiEnabled'] = true).aiEnabled, isTrue);
    });
  });

  group('which quality narratives AI wrote', () {
    test('a fresh record claims nothing was AI-written', () {
      expect(QualityManagementData.empty().aiGeneratedPlans, isEmpty);
    });

    test('only the category AI produced is marked', () {
      final q = QualityManagementData.empty()
          .copyWith(aiGeneratedPlans: {'plan': true});

      expect(q.aiGeneratedPlans['plan'], isTrue);
      // Untouched tabs must not inherit the marker, or every heading would say
      // "(AI-Generated)" the moment one plan was generated.
      expect(q.aiGeneratedPlans['metrics'], isNull);
    });

    test('rewriting a narrative drops its AI marker', () {
      final ai = QualityManagementData.empty()
          .copyWith(aiGeneratedPlans: {'plan': true});

      final rewritten = ai.copyWith(
        qualityManagementPlan: 'Written by us',
        aiGeneratedPlans: {...ai.aiGeneratedPlans, 'plan': false},
      );

      expect(rewritten.aiGeneratedPlans['plan'], isFalse);
      expect(rewritten.qualityManagementPlan, 'Written by us');
    });

    test('rejecting a narrative empties it and clears the marker', () {
      final ai = QualityManagementData.empty().copyWith(
        qualityRegisterLog: 'AI register',
        aiGeneratedPlans: {'register': true},
      );

      final rejected = ai.copyWith(
        qualityRegisterLog: '',
        aiGeneratedPlans: {...ai.aiGeneratedPlans, 'register': false},
      );

      expect(rejected.qualityRegisterLog, isEmpty);
      expect(rejected.aiGeneratedPlans['register'], isFalse);
    });

    test('the markers survive a save and reload', () {
      final q = QualityManagementData.empty().copyWith(
        qualityRegisterLog: 'AI register',
        aiGeneratedPlans: {'register': true, 'plan': false},
      );

      expect(QualityManagementData.fromJson(q.toJson()).aiGeneratedPlans,
          {'register': true, 'plan': false});
    });

    test('a record saved before the markers existed claims nothing', () {
      final legacy = QualityManagementData.empty().toJson()
        ..remove('aiGeneratedPlans');

      expect(QualityManagementData.fromJson(legacy).aiGeneratedPlans, isEmpty);
    });
  });
}
