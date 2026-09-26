// Regression test for the Planning Phase → Requirements crash on load WITH DATA.
//
// The table body is a horizontal scroll view whose child carried only a
// `minWidth`, so `maxWidth` stayed infinite. Inside a horizontal scrollable that
// unbounded width propagates to everything below it, and two things then throw:
//
//   Vertical viewport was given unbounded width.
//     -> the vertical ReorderableListView holding the requirement rows
//
//   RenderFlex children have non-zero flex but incoming width constraints are
//   unbounded.
//     -> any Row below with an Expanded child
//
// The page only looked healthy while it was EMPTY: the empty state renders a
// plain Center instead of a viewport, so nothing asked for a finite width. Every
// earlier test pumped an empty model and passed. These tests seed requirement
// rows precisely so the table body is built.
//
// The vertical Scrollbar also needs the list to adopt its controller, otherwise
// it throws "The Scrollbar's ScrollController has no ScrollPosition attached"
// once rows exist.
//
// Firebase is mocked because the page's header reads the signed-in user; the
// page's data load is expected to fail in a widget test and is swallowed.

// ignore_for_file: depend_on_referenced_packages
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ndu_project/models/project_data_model.dart';
import 'package:ndu_project/providers/project_data_provider.dart';
import 'package:ndu_project/screens/planning_requirements_screen.dart';

// Printed by the framework if the table lays out with unbounded width.
const String _unboundedFlex =
    'RenderFlex children have non-zero flex but incoming width constraints are unbounded';
const String _unboundedViewport = 'Vertical viewport was given unbounded width';
const String _scrollbarNoPosition =
    "The Scrollbar's ScrollController has no ScrollPosition attached";

Future<void> _pumpWithRows(WidgetTester tester) async {
  // The table's fixed column widths total 2360, so the default 800x600 test
  // surface would report its own overflow. Use a desktop-sized surface.
  tester.view.physicalSize = const Size(2000, 1200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final model = ProjectDataModel().copyWith(projectId: 'p1');
  // Requirements arrive as newline-separated text; each line becomes a row.
  model.frontEndPlanning.requirements =
      'The system shall store requirements in Firestore\n'
      'The system shall export the requirements plan to PDF';

  final provider = ProjectDataProvider();
  provider.updateProjectData(model);

  await tester.pumpWidget(
    ProjectDataInherited(
      provider: provider,
      child: ChangeNotifierProvider<ProjectDataProvider>.value(
        value: provider,
        child: const MaterialApp(home: PlanningRequirementsScreen()),
      ),
    ),
  );
  // Spinners only stop once the Firebase-less load gives up, so pump fixed
  // frames rather than settling on an animation that never ends.
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
}

/// Fails if the exception (or any exception) mentions one of the unbounded-width
/// failure modes. Benign framework overflow messages are ignored.
void _expectNoUnboundedWidthFailure(Object? error, String when) {
  if (error == null) return;
  final String text = error.toString();
  expect(text.contains(_unboundedFlex), isFalse,
      reason: 'unbounded-width flex failure $when:\n$text');
  expect(text.contains(_unboundedViewport), isFalse,
      reason: 'unbounded-width viewport failure $when:\n$text');
  expect(text.contains(_scrollbarNoPosition), isFalse,
      reason: 'detached Scrollbar controller $when:\n$text');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('the table renders requirement rows without unbounded width',
      (tester) async {
    await _pumpWithRows(tester);

    // The row list is only built when rows exist, which is the whole point.
    expect(find.byType(ReorderableListView), findsWidgets);
    _expectNoUnboundedWidthFailure(tester.takeException(), 'with rows');

    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('Expand renders the full-screen copy with rows', (tester) async {
    await _pumpWithRows(tester);

    await tester.tap(find.text('Expand'));
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(find.byType(ReorderableListView), findsWidgets);
    _expectNoUnboundedWidthFailure(tester.takeException(), 'in the expanded copy');

    await tester.pump(const Duration(seconds: 3));
  });
}
