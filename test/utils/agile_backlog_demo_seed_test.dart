// The demo-ready backlog (Lusaka 27 follow-up): "if you're going to
// demonstrate this … build us stories there, some story points and stuff like
// that. And then all the features … so that way we can test the schedule."
// These tests pin the seeding rules: linked, sized, non-destructive, and
// idempotent for a backlog that already has sized stories.
import 'package:flutter_test/flutter_test.dart';

import 'package:ndu_project/models/agile_task.dart';
import 'package:ndu_project/models/epic_model.dart';
import 'package:ndu_project/models/feature_model.dart';
import 'package:ndu_project/utils/agile_backlog_demo_seed.dart';

Epic _epic(String id) => Epic(id: id, title: 'Epic $id');

Feature _feature(
  String id, {
  required String epicId,
  String title = '',
}) =>
    Feature(
      id: id,
      title: title.isEmpty ? 'Feature $id' : title,
      epicId: epicId,
    );

void main() {
  group('the demo backlog seed', () {
    test('creates 2 stories for the first feature and 3 for later ones', () {
      final featureA = _feature('f1', epicId: 'e1');
      final featureB = _feature('f2', epicId: 'e1');

      final a = AgileBacklogDemoSeed.storiesForFeature(featureA,
          featureIndex: 0);
      final b = AgileBacklogDemoSeed.storiesForFeature(featureB,
          featureIndex: 1);

      expect(a.length, 2);
      expect(b.length, 3);
    });

    test('every story is linked to its feature and epic', () {
      final feature = _feature('f1', epicId: 'e1', title: 'Weather feed');
      final stories = AgileBacklogDemoSeed.storiesForFeature(feature,
          featureIndex: 0);
      for (final story in stories) {
        expect(story.featureId, 'f1');
        expect(story.epicId, 'e1');
      }
    });

    test('every story is sized, prioritised and starts as To-Do', () {
      final stories = AgileBacklogDemoSeed.storiesForFeature(
          _feature('f1', epicId: 'e1'),
          featureIndex: 0);
      for (final story in stories) {
        expect(story.storyPoints, greaterThan(0));
        expect(story.priority, isNotEmpty);
        expect(story.status, 'To-Do');
      }
      // Varied sizes, not a wall of the same number.
      expect(stories.map((s) => s.storyPoints).toSet().length, greaterThan(1));
    });

    test('story points vary across features so the demo is not uniform', () {
      final f1 = AgileBacklogDemoSeed.storiesForFeature(
          _feature('f1', epicId: 'e1'),
          featureIndex: 0);
      final f2 = AgileBacklogDemoSeed.storiesForFeature(
          _feature('f2', epicId: 'e1'),
          featureIndex: 1);
      expect(f1.first.storyPoints, isNot(f2.first.storyPoints));
    });

    test('seeds continue the feature’s backlog order, not from zero', () {
      final feature = _feature('f1', epicId: 'e1');
      final existing = [
        AgileTask(
          epicId: 'e1',
          featureId: 'f1',
          userStory: 'Real story',
          storyPoints: 5,
          backlogOrder: 4,
        ),
      ];
      final stories = AgileBacklogDemoSeed.storiesForFeature(feature,
          featureIndex: 0, existing: existing);
      expect(stories.map((s) => s.backlogOrder).toList(), [5, 6]);
    });

    test('the existing stories are not touched — seeding is additive', () {
      final feature = _feature('f1', epicId: 'e1');
      final existing = [
        AgileTask(
          epicId: 'e1',
          featureId: 'f1',
          userStory: 'Real story',
          storyPoints: 5,
          backlogOrder: 1,
        ),
      ];
      final seeds = AgileBacklogDemoSeed.storiesForFeature(feature,
          featureIndex: 0, existing: existing);
      expect(seeds.any((s) => s.userStory == 'Real story'), isFalse);
    });

    test('backlogNeedsSeeding is true only while a feature has no sized story',
        () {
      final features = [
        _feature('f1', epicId: 'e1'),
        _feature('f2', epicId: 'e1'),
      ];
      final stories = [
        AgileTask(
            epicId: 'e1', featureId: 'f1', userStory: 'a', storyPoints: 3),
        AgileTask(
            epicId: 'e1', featureId: 'f2', userStory: 'b', storyPoints: 2),
      ];
      expect(
        AgileBacklogDemoSeed.backlogNeedsSeeding(features, stories: stories),
        isFalse,
        reason: 'every feature already carries a sized story',
      );
      expect(
        AgileBacklogDemoSeed.backlogNeedsSeeding(
          features,
          stories: [stories.first],
        ),
        isTrue,
        reason: 'f2 has nothing sized',
      );
    });

    test('backlogNeedsSeeding is false with no features to seed', () {
      expect(
        AgileBacklogDemoSeed.backlogNeedsSeeding(
          const [],
          stories: const [],
        ),
        isFalse,
      );
    });
  });
}
