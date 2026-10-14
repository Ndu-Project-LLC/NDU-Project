// The WBS is where the agile chain starts (Level 1 Epic → 2 Feature →
// 3 User Story), but its summary only reported the first two levels — an Agile
// WBS broken down two levels looked the same as one broken down three. These
// pin the one-deeper summary and the honest nudge when stories are missing.

import 'package:flutter_test/flutter_test.dart';

import 'package:ndu_project/utils/wbs_agile_level_summary.dart';
import 'package:ndu_project/wbs/models/wbs_models.dart';

void main() {
  group('an Agile WBS', () {
    test('reports epic, feature, and user story counts with the chain labels',
        () {
      final line = WbsLevelSummary.summaryLine(
        framework: WBSFramework.agile,
        countsByLevel: {1: 3, 2: 8, 3: 21, 4: 40},
      );

      expect(line, '3 Epic · 8 Feature · 21 User Story');
      expect(line.contains('40'), isFalse,
          reason: 'one level deeper, not the whole tree');
    });

    test('skips the story level when the WBS has none', () {
      final line = WbsLevelSummary.summaryLine(
        framework: WBSFramework.agile,
        countsByLevel: {1: 3, 2: 8},
      );

      expect(line, '3 Epic · 8 Feature');
    });

    test('says why the story level is empty when there are features to break',
        () {
      final hint = WbsLevelSummary.storyGapHint(
        framework: WBSFramework.agile,
        countsByLevel: {1: 3, 2: 8},
      );

      expect(hint, contains('No User Story level yet'));
      expect(hint, contains('stories reach the backlog'));
    });

    test('stays quiet once stories exist', () {
      expect(
        WbsLevelSummary.storyGapHint(
          framework: WBSFramework.agile,
          countsByLevel: {1: 3, 2: 8, 3: 1},
        ),
        isNull,
      );
    });

    test('stays quiet when there is nothing to break down yet', () {
      expect(
        WbsLevelSummary.storyGapHint(
          framework: WBSFramework.agile,
          countsByLevel: {1: 3},
        ),
        isNull,
        reason: 'an epic with no features is unfinished at a higher level',
      );
    });

    test('can be asked for the whole chain including empty levels', () {
      final chain = WbsLevelSummary.breakdown(
        framework: WBSFramework.agile,
        countsByLevel: {1: 3, 2: 8},
        includeEmpty: true,
      );

      expect(chain.map((level) => level.level).toList(), [1, 2, 3]);
      expect(chain.last.display, '0 User Story');
    });
  });

  group('a waterfall WBS', () {
    test('uses the framework labels, not the agile ones', () {
      final line = WbsLevelSummary.summaryLine(
        framework: WBSFramework.waterfallDeliverable,
        countsByLevel: {1: 4, 2: 10, 3: 30},
      );

      expect(line, '4 Deliverable · 10 Sub-Deliverable · 30 Work Package');
    });

    test('never nudges about user stories', () {
      expect(
        WbsLevelSummary.storyGapHint(
          framework: WBSFramework.waterfallDeliverable,
          countsByLevel: {1: 4, 2: 10},
        ),
        isNull,
      );
    });
  });

  test('an empty map produces an empty line rather than a crash', () {
    expect(
      WbsLevelSummary.summaryLine(
        framework: WBSFramework.agile,
        countsByLevel: const {},
      ),
      '',
    );
  });
}
