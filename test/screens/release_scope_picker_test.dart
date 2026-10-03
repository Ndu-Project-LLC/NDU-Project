// Regression test for the "Add Release Plan" crash.
//
// The release-plan dialog renders its Linked Scope checklist inside an
// `AlertDialog`. AlertDialog measures its content with `IntrinsicWidth`, and a
// viewport cannot answer intrinsic dimensions, so a `ListView` in there throws
// during layout:
//
//   RenderShrinkWrappingViewport does not support returning intrinsic dimensions
//
// That exception aborts the frame, so the whole page dies the moment the
// dialog opens — but only once the project actually has epics, which is why it
// survived the empty-project smoke test. These tests pump the picker under the
// same nesting the dialog uses, so the shape cannot come back unnoticed.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ndu_project/models/agile_task.dart';
import 'package:ndu_project/models/epic_model.dart';
import 'package:ndu_project/models/feature_model.dart';
import 'package:ndu_project/screens/agile_release_plan_screen.dart';

Epic _epic(String id, String title) => Epic(id: id, title: title);

Feature _feature(String id, String epicId, String title) =>
    Feature(id: id, epicId: epicId, title: title);

AgileTask _story(String id, String featureId, String userStory) => AgileTask(
      id: id,
      featureId: featureId,
      userStory: userStory,
      storyPoints: 5,
      readinessStatus: 'Ready for Sprint',
    );

/// Wraps [child] the way the release-plan dialog does, which is what makes the
/// intrinsic-dimension trap reachable.
Widget _dialogHost(Widget child) {
  return MaterialApp(
    home: Scaffold(
      body: AlertDialog(
        title: const Text('Release Plan Details'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [child]),
        ),
        actions: const [Text('Cancel')],
      ),
    ),
  );
}

Widget _picker({
  required List<Epic> epics,
  Map<String, List<Feature>> featuresByEpic = const {},
  List<AgileTask> stories = const [],
  Set<String> selectedEpicIds = const {},
  Set<String> selectedFeatureIds = const {},
  Set<String> selectedStoryIds = const {},
  void Function(String epicId, bool selected)? onEpicChanged,
  void Function(String epicId, String featureId, bool selected)?
      onFeatureChanged,
  void Function(String epicId, String featureId, String storyId, bool selected)?
      onStoryChanged,
}) {
  return ReleaseScopePicker(
    epics: epics,
    featuresByEpic: featuresByEpic,
    stories: stories,
    selectedEpicIds: selectedEpicIds,
    selectedFeatureIds: selectedFeatureIds,
    selectedStoryIds: selectedStoryIds,
    onEpicChanged: onEpicChanged ?? (_, __) {},
    onFeatureChanged: onFeatureChanged ?? (_, __, ___) {},
    onStoryChanged: onStoryChanged ?? (_, __, ___, ____) {},
  );
}

void main() {
  testWidgets('renders a project with epics inside an AlertDialog',
      (tester) async {
    await tester.pumpWidget(_dialogHost(_picker(
      epics: [_epic('e1', 'Farm Data Capture'), _epic('e2', 'Offline Sync')],
      featuresByEpic: {
        'e1': [_feature('f1', 'e1', 'Yield logging')],
      },
      stories: [_story('s1', 'f1', 'As a farmer I log my yield')],
    )));
    await tester.pump();

    // The layout exception would surface here rather than as a missing widget.
    expect(tester.takeException(), isNull);
    expect(find.text('Linked Scope'), findsOneWidget);
    expect(find.text('Farm Data Capture'), findsOneWidget);
    expect(find.text('Offline Sync'), findsOneWidget);
    expect(find.text('Yield logging'), findsOneWidget);
    expect(find.text('As a farmer I log my yield'), findsOneWidget);
    expect(find.text('5 pts · Ready for Sprint'), findsOneWidget);
  });

  testWidgets('an empty project shows the hint instead', (tester) async {
    await tester.pumpWidget(_dialogHost(_picker(epics: const [])));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('No epics defined yet.'), findsOneWidget);
  });

  testWidgets('ticking an epic reports it', (tester) async {
    final changes = <String>[];
    await tester.pumpWidget(_dialogHost(_picker(
      epics: [_epic('e1', 'Farm Data Capture')],
      onEpicChanged: (epicId, selected) => changes.add('$epicId=$selected'),
    )));
    await tester.pump();

    await tester.tap(find.text('Farm Data Capture'));
    await tester.pump();

    expect(changes, ['e1=true']);
  });

  testWidgets('ticking a story reports the story, feature and epic',
      (tester) async {
    final changes = <String>[];
    await tester.pumpWidget(_dialogHost(_picker(
      epics: [_epic('e1', 'Farm Data Capture')],
      featuresByEpic: {
        'e1': [_feature('f1', 'e1', 'Yield logging')],
      },
      stories: [_story('s1', 'f1', 'As a farmer I log my yield')],
      onStoryChanged: (epicId, featureId, storyId, selected) =>
          changes.add('$epicId/$featureId/$storyId=$selected'),
    )));
    await tester.pump();

    await tester.tap(find.text('As a farmer I log my yield'));
    await tester.pump();

    expect(changes, ['e1/f1/s1=true']);
  });

  testWidgets('already-selected scope renders ticked', (tester) async {
    await tester.pumpWidget(_dialogHost(_picker(
      epics: [_epic('e1', 'Farm Data Capture')],
      selectedEpicIds: const {'e1'},
    )));
    await tester.pump();

    final tile = tester.widget<CheckboxListTile>(
      find.ancestor(
        of: find.text('Farm Data Capture'),
        matching: find.byType(CheckboxListTile),
      ),
    );
    expect(tile.value, isTrue);
  });
}
