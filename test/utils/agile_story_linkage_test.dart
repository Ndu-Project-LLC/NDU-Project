// The review's chain is Epic → Feature → Story → Task, with the story → feature
// link mandatory and the epic inherited from the feature. These tests pin the
// rule in the one place both the backlog screen and Epics & Features use it,
// including the case that caused the original gap: stories that carry no
// feature must be reported as unlinked, never silently accepted as linked.

import 'package:flutter_test/flutter_test.dart';

import 'package:ndu_project/models/agile_task.dart';
import 'package:ndu_project/models/epic_model.dart';
import 'package:ndu_project/models/feature_model.dart';
import 'package:ndu_project/utils/agile_backlog_table.dart';
import 'package:ndu_project/utils/agile_story_linkage.dart';

void main() {
  final epicA = Epic(id: 'epic-a', title: 'Customer onboarding');
  final epicB = Epic(id: 'epic-b', title: 'Billing');
  final featureA1 = Feature(id: 'feat-a1', epicId: 'epic-a', title: 'Sign up');
  final featureB1 =
      Feature(id: 'feat-b1', epicId: 'epic-b', title: 'Invoices');
  final epics = [epicA, epicB];
  final featuresByEpic = {
    'epic-a': [featureA1],
    'epic-b': [featureB1],
  };

  group('a new story is born linked', () {
    test('it carries the feature and that feature\'s epic', () {
      final story = AgileStoryLinkage.newStoryFor(feature: featureB1);

      expect(story.featureId, 'feat-b1');
      expect(story.epicId, 'epic-b',
          reason: 'the epic must come from the feature, not the caller');
      expect(story.readinessStatus, 'Draft');
    });

    test('it is ordered after the stories the feature already holds', () {
      final existing = [
        AgileTask(featureId: 'feat-b1', backlogOrder: 4),
        AgileTask(featureId: 'feat-b1', backlogOrder: 9),
        AgileTask(featureId: 'feat-a1', backlogOrder: 99),
      ];

      final story = AgileStoryLinkage.newStoryFor(
        feature: featureB1,
        existing: existing,
      );

      expect(story.backlogOrder, 10,
          reason: 'other features\' stories must not affect the order');
    });

    test('deleting a story cannot make the next one collide', () {
      // Orders 1 and 2 existed; 1 was deleted, so a count would hand out 2
      // again and two stories would share a backlog position.
      final remaining = [AgileTask(featureId: 'feat-b1', backlogOrder: 2)];

      final story = AgileStoryLinkage.newStoryFor(
        feature: featureB1,
        existing: remaining,
      );

      expect(story.backlogOrder, 3);
    });

    test('a caller title wins, blank ones fall back to the default', () {
      expect(
        AgileStoryLinkage.newStoryFor(feature: featureA1, title: 'Reset password')
            .userStory,
        'Reset password',
      );
      expect(
        AgileStoryLinkage.newStoryFor(feature: featureA1, title: '   ').userStory,
        'New story 1',
      );
    });

    test('the new story lands in the linked group, not the unlinked one', () {
      final story = AgileStoryLinkage.newStoryFor(feature: featureA1);
      final rows = AgileBacklogTable.build(
        epics: epics,
        featuresByEpic: featuresByEpic,
        stories: [story],
      );

      expect(rows.single.isUnlinked, isFalse);
      expect(rows.single.featureTitle, 'Sign up');
      expect(rows.single.epicTitle, 'Customer onboarding');
    });
  });

  group('re-parenting a story', () {
    test('link() replaces both ids, including a stale epic', () {
      final story = AgileTask(
        featureId: 'feat-deleted',
        epicId: 'epic-deleted',
        userStory: 'Loose story',
      );

      final linked = AgileStoryLinkage.link(story, featureB1);

      expect(linked.featureId, 'feat-b1');
      expect(linked.epicId, 'epic-b');
      expect(linked.userStory, 'Loose story', reason: 'the rest is untouched');
      expect(linked.id, story.id);
    });
  });

  group('link checks', () {
    test('an empty feature id is unlinked', () {
      expect(
        AgileStoryLinkage.isLinked(AgileTask(userStory: 'Legacy'),
            featuresByEpic: featuresByEpic),
        isFalse,
      );
    });

    test('a feature id that no longer exists is unlinked', () {
      expect(
        AgileStoryLinkage.isLinked(AgileTask(featureId: 'feat-gone'),
            featuresByEpic: featuresByEpic),
        isFalse,
      );
    });

    test('a resolvable feature id is linked, and resolves back to the feature',
        () {
      final story = AgileTask(featureId: 'feat-a1');

      expect(
          AgileStoryLinkage.isLinked(story, featuresByEpic: featuresByEpic), isTrue);
      expect(
        AgileStoryLinkage.featureFor(story, featuresByEpic: featuresByEpic)?.title,
        'Sign up',
      );
    });
  });

  group('reporting the gap', () {
    test('counts every story that reaches no feature', () {
      final stories = [
        AgileTask(featureId: 'feat-a1'),
        AgileTask(featureId: ''),
        AgileTask(featureId: 'feat-deleted'),
      ];

      expect(
        AgileStoryLinkage.countUnlinked(stories,
            featuresByEpic: featuresByEpic),
        2,
        reason: 'a dangling feature id is just as unlinked as a missing one',
      );
      expect(
        AgileStoryLinkage.countUnlinked(const [],
            featuresByEpic: featuresByEpic),
        0,
      );
    });
  });

  group('feature options for a picker', () {
    test('every feature is offered, labelled with its epic', () {
      final labels = AgileStoryLinkage.optionLabels(
        epics: epics,
        featuresByEpic: featuresByEpic,
      );

      expect(labels['feat-a1'], 'Customer onboarding · Sign up');
      expect(labels['feat-b1'], 'Billing · Invoices');
      expect(
        AgileStoryLinkage.allFeatures(
                epics: epics, featuresByEpic: featuresByEpic)
            .map((f) => f.id),
        ['feat-a1', 'feat-b1'],
      );
    });

    test('unnamed epics and features still read as something', () {
      expect(
        AgileStoryLinkage.optionLabel(
            feature: Feature(id: 'f', title: '  '), epicTitle: ''),
        'Untitled epic · Untitled feature',
      );
    });
  });
}
