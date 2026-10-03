// Dragging a kanban card used to work only for the first few cards on the
// board. Every card is keyed by its story id, and the ids collided — the whole
// batch was seeded from one clock tick — so the column's ListView held
// duplicate keys, its children's order scrambled, and a drag landed on the
// wrong child (only the cards early in the list still moved). The load path now
// heals the ids (see ExecutionPhaseService.decodeAgileTasks and
// test/services/execution_phase_service_agile_tasks_test.dart); this test pins
// the board behaviour that fix restores: a card that is *not* the first in its
// column can be dragged into another column, and it is that card that moves.
//
// The board loads its stories from Firestore, so the test hands it the stories
// through the [KanbanBoardPanel.stories] seam and drives the real widget.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ndu_project/models/agile_task.dart';
import 'package:ndu_project/providers/project_data_provider.dart';
import 'package:ndu_project/screens/agile_kanban_board_screen.dart';
import 'package:ndu_project/services/kanban_config_service.dart';

AgileTask _story(String id, String title) => AgileTask(
      id: id,
      userStory: title,
      storyPoints: 3,
      workflowState: 'backlog',
    );

/// The board column whose workflow name is [name].
Finder _column(String name) => find.byKey(
    ValueKey('kanban_column_${KanbanConfigService.columnIdFor(name)}'));

Finder _inColumn(String name, String text) =>
    find.descendant(of: _column(name), matching: find.text(text));

Future<void> _pumpBoard(WidgetTester tester, List<AgileTask> stories) async {
  tester.view.physicalSize = const Size(1600, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ChangeNotifierProvider<ProjectDataProvider>.value(
      value: ProjectDataProvider(),
      child: MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 1600,
              child: KanbanBoardPanel(stories: stories),
            ),
          ),
        ),
      ),
    ),
  );
  // _loadData runs from a post-frame callback. Injected stories leave the
  // loading strip on one frame, so two pumps are enough — no settle, which
  // would never finish while the strip animates.
  await tester.pump();
  await tester.pump();
}

/// Presses [card], moves it over the [to] column the way a pointer would
/// (hovering, so the drop target updates), then releases.
Future<void> _dragCardToColumn(
    WidgetTester tester, String card, String to) async {
  final gesture = await tester.startGesture(tester.getCenter(find.text(card)));
  await tester.pump(const Duration(milliseconds: 50));
  await gesture.moveTo(tester.getCenter(_column(to)));
  await tester.pump(const Duration(milliseconds: 50));
  await gesture.up();
  await tester.pump();
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  testWidgets('dragging the second card moves that card, not the first',
      (tester) async {
    await _pumpBoard(tester, [
      _story('s1', 'Story one'),
      _story('s2', 'Story two'),
      _story('s3', 'Story three'),
    ]);

    expect(_inColumn('Backlog', 'Story two'), findsOneWidget);

    await _dragCardToColumn(tester, 'Story two', 'Ready');

    // The card the user grabbed moved...
    expect(_inColumn('Ready', 'Story two'), findsOneWidget,
        reason: 'the second card should follow the pointer into Ready');
    expect(_inColumn('Backlog', 'Story two'), findsNothing);
    // ...and the first card did not come along for the ride.
    expect(_inColumn('Backlog', 'Story one'), findsOneWidget);
    expect(_inColumn('Ready', 'Story one'), findsNothing);
    // No card is lost or duplicated by the move.
    for (final title in const ['Story one', 'Story two', 'Story three']) {
      expect(find.text(title), findsOneWidget);
    }
  });

  testWidgets('the last card in a fuller column is draggable too',
      (tester) async {
    // Four cards fill the column without needing a scroll, so the last one is
    // really rendered — the deepest card a drag has to reach here.
    await _pumpBoard(tester, [
      for (var i = 1; i <= 4; i++) _story('s$i', 'Story $i'),
    ]);

    await _dragCardToColumn(tester, 'Story 4', 'In Progress');

    expect(_inColumn('In Progress', 'Story 4'), findsOneWidget,
        reason: 'a card down the column must still be draggable');
    expect(_inColumn('Backlog', 'Story 4'), findsNothing);
    expect(_inColumn('Backlog', 'Story 1'), findsOneWidget);
  });

  testWidgets('every card keeps a key of its own', (tester) async {
    await _pumpBoard(tester, [
      for (var i = 1; i <= 5; i++) _story('s$i', 'Story $i'),
    ]);

    // Because the ids are unique, the keys are too — which is what keeps the
    // ListView's children from scrambling on a rebuild.
    for (var i = 1; i <= 5; i++) {
      expect(find.byKey(ValueKey('kanban_card_s$i')), findsOneWidget,
          reason: 'each story needs its own key, or dragging breaks');
    }
  });
}
