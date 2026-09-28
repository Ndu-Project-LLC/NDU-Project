// The Kanban Configuration page used to render read-only cards and a live
// board — the review could not tell what was configurable. It now edits the
// columns the board actually renders (loaded from the saved Kanban config) and
// states the rules that are fixed. These tests pin both halves, and pin that
// the loaded columns are the board's own fallback workflow, so the page can
// never disagree with the board about the starting columns.
// ignore_for_file: depend_on_referenced_packages
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ndu_project/models/project_data_model.dart';
import 'package:ndu_project/providers/project_data_provider.dart';
import 'package:ndu_project/screens/agile_kanban_config_screen.dart';

Future<void> _pumpScreen(WidgetTester tester) async {
  tester.view.physicalSize = const Size(2200, 1500);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final provider = ProjectDataProvider();
  provider.updateProjectData(ProjectDataModel().copyWith(projectId: 'p1'));

  await tester.pumpWidget(
    ChangeNotifierProvider<ProjectDataProvider>.value(
      value: provider,
      child: const MaterialApp(home: AgileKanbanConfigScreen()),
    ),
  );
  // Fixed pumps rather than pumpAndSettle: the embedded board animates its
  // loading strip, so settling would never finish.
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
  // Firestore has no platform handler under `flutter test`; the config read
  // fails fast and the page falls back to the board's default columns. Let the
  // real event loop run so that load completes.
  await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 1500)));
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
}

String _nameAt(WidgetTester tester, int index) => tester
    .widget<TextField>(find.byKey(ValueKey('kanban-column-name-$index')))
    .controller!
    .text;

String _wipAt(WidgetTester tester, int index) => tester
    .widget<TextField>(find.byKey(ValueKey('kanban-column-wip-$index')))
    .controller!
    .text;

List<String> _names(WidgetTester tester, int count) =>
    [for (var i = 0; i < count; i++) _nameAt(tester, i)];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });

  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  testWidgets('lists the workflow columns the board will render',
      (tester) async {
    await _pumpScreen(tester);

    expect(_names(tester, 5),
        ['Backlog', 'Ready', 'In Progress', 'In Review', 'Done']);
    // Blank WIP means "no limit" — the same 999 the board reads.
    expect([for (var i = 0; i < 5; i++) _wipAt(tester, i)],
        ['', '8', '5', '3', '']);
    expect(find.text('Workflow Columns'), findsOneWidget);
    expect(find.text('YOURS TO CHANGE'), findsOneWidget);
  });

  testWidgets('states what the board owns and will not let you change',
      (tester) async {
    await _pumpScreen(tester);

    expect(find.text('Fixed on Every Kanban Board'), findsOneWidget);
    expect(find.text('LOCKED'), findsOneWidget);
    expect(
      find.textContaining('re-homes its cards to the first column'),
      findsOneWidget,
      reason: 'the rename/remove consequence has to be visible before saving',
    );
    expect(find.textContaining('WIP limit blocks further pulls'), findsOneWidget);
  });

  testWidgets('editing a column marks the workflow unsaved and saveable',
      (tester) async {
    await _pumpScreen(tester);

    expect(find.text('UNSAVED'), findsNothing);

    await tester.enterText(
        find.byKey(const ValueKey('kanban-column-wip-0')), '12');
    await tester.pump();

    expect(find.text('UNSAVED'), findsOneWidget);
    expect(find.text('12'), findsWidgets,
        reason: 'the resolved WIP limit label follows the field');
    expect(
      tester
          .widget<FilledButton>(find.byKey(const ValueKey('kanban-save-config')))
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('columns can be added, reordered and removed', (tester) async {
    await _pumpScreen(tester);

    await tester.tap(find.byKey(const ValueKey('kanban-add-column')));
    await tester.pump();
    expect(_names(tester, 6).last, 'New Column');

    await tester.tap(find.byTooltip('Move column 2 up'));
    await tester.pump();
    expect(_names(tester, 2), ['Ready', 'Backlog']);

    await tester.tap(find.byTooltip('Remove column 3'));
    await tester.pump();
    expect(_names(tester, 5), ['Ready', 'Backlog', 'In Review', 'Done', 'New Column']);
  });

  testWidgets('the last column cannot be removed', (tester) async {
    await _pumpScreen(tester);

    // Remove down to a single column.
    for (var i = 0; i < 4; i++) {
      await tester.tap(find.byTooltip('Remove column 1'));
      await tester.pump();
    }
    expect(_names(tester, 1), ['Done']);
    // The tooltip is built by the button, so the button is its ancestor.
    final removeButton = find.ancestor(
      of: find.byTooltip('Remove column 1'),
      matching: find.byType(IconButton),
    );
    expect(tester.widget<IconButton>(removeButton).onPressed, isNull,
        reason: 'a workflow needs at least one column');
  });
}
