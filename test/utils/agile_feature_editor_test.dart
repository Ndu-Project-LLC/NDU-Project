// The review: a feature needs "the title … the description [and] the priority of
// that feature. Because every feature will be tied to an epic." These pin the
// pure half of that — what a new feature starts as, and what re-parenting means.

import 'package:flutter_test/flutter_test.dart';

import 'package:ndu_project/models/epic_model.dart';
import 'package:ndu_project/models/feature_model.dart';
import 'package:ndu_project/utils/agile_feature_editor.dart';

void main() {
  final epicA = Epic(id: 'epic-a', title: 'Customer onboarding');
  final epicB = Epic(id: 'epic-b', title: 'Billing');

  group('a new feature', () {
    test('belongs to its epic immediately', () {
      final feature = AgileFeatureEditor.newFor(epicA);

      expect(feature.epicId, 'epic-a');
      expect(feature.title, AgileFeatureEditor.defaultTitle,
          reason: 'a nameless row in the epic list helps nobody');
    });

    test('keeps a title that was supplied', () {
      expect(
        AgileFeatureEditor.newFor(epicA, title: '  Sign up with email  ').title,
        'Sign up with email',
      );
      expect(AgileFeatureEditor.newFor(epicA, title: '   ').title,
          AgileFeatureEditor.defaultTitle);
    });
  });

  group('re-parenting', () {
    test('only counts when the epic actually changes', () {
      final feature = Feature(id: 'f1', epicId: 'epic-a', title: 'Sign up');

      expect(AgileFeatureEditor.reparents(feature, 'epic-b'), isTrue);
      expect(AgileFeatureEditor.reparents(feature, 'epic-a'), isFalse);
      expect(AgileFeatureEditor.reparents(feature, ''), isFalse,
          reason: 'a feature always belongs to an epic');
    });

    test('moveToEpic changes the link and nothing else', () {
      final feature = Feature(
        id: 'f1',
        epicId: 'epic-a',
        title: 'Sign up',
        description: 'Self-serve signup',
        priority: 'high',
        storyPointEstimate: 5,
      );

      final moved = AgileFeatureEditor.moveToEpic(feature, epicB.id);

      expect(moved.epicId, 'epic-b');
      expect(moved.title, 'Sign up');
      expect(moved.description, 'Self-serve signup');
      expect(moved.priority, 'high');
      expect(moved.storyPointEstimate, 5);
      expect(moved.id, feature.id);
    });
  });

  group('display and vocabulary', () {
    test('an untitled feature still reads as something', () {
      expect(AgileFeatureEditor.displayTitle(Feature(title: '  ')),
          'Untitled feature');
      expect(AgileFeatureEditor.displayTitle(Feature(title: 'Billing')),
          'Billing');
    });

    test('priorities are the stored vocabulary, in order', () {
      expect(AgileFeatureEditor.priorities,
          ['critical', 'high', 'medium', 'low']);
    });

    test('a stray priority falls back to medium', () {
      expect(AgileFeatureEditor.normalisePriority('HIGH'), 'high');
      expect(AgileFeatureEditor.normalisePriority('urgent'), 'medium');
      expect(AgileFeatureEditor.normalisePriority('  '), 'medium');
    });
  });
}
