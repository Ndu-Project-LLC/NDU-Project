// Regression test for the Planning Phase → Requirements crash.
//
// The table's "Expand" button pushes a non-opaque route, so the inline table
// stays mounted underneath it. Both copies were built with the same
// ScrollControllers, and a `Scrollbar` with `thumbVisibility: true` asserts
// when its controller has more than one ScrollPosition:
//
//   The provided ScrollController is attached to more than one ScrollPosition.
//   When Scrollbar.thumbVisibility is true, the associated ScrollController
//   must only have one
//
// That threw on every frame of the expanded table and took the page down, so
// the expanded copy now builds with its own controllers. This test clicks
// Expand and fails if anything is thrown while both copies are mounted.
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

Future<void> _pumpScreen(WidgetTester tester) async {
  // The default 800x600 test surface is narrower than the table's fixed column
  // widths, so the page reports its own overflow errors that have nothing to do
  // with this crash. Use a desktop-sized surface, like the browser.
  tester.view.physicalSize = const Size(2000, 1200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final provider = ProjectDataProvider();
  provider.updateProjectData(ProjectDataModel().copyWith(projectId: 'p1'));

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
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
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

  testWidgets('the page itself renders', (tester) async {
    await _pumpScreen(tester);

    expect(tester.takeException(), isNull);
    expect(find.text('Add another'), findsOneWidget);

    // Drain the provider's debounced autosave so the test ends cleanly.
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('Expand shows the table full screen without throwing',
      (tester) async {
    await _pumpScreen(tester);

    await tester.tap(find.text('Expand'));
    // The route fades in over 220ms; the inline table stays mounted below it.
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(tester.takeException(), isNull);
    expect(find.text('Planning Requirements'), findsWidgets);

    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('scroll hints survive opening and closing the expanded table',
      (tester) async {
    await _pumpScreen(tester);

    await tester.tap(find.text('Expand'));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(tester.takeException(), isNull);

    // Close: the inline table must come back attached to its own controllers.
    final close = find.byTooltip('Close');
    expect(close, findsWidgets);
    await tester.tap(close.first);
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(tester.takeException(), isNull);
    expect(find.text('Add another'), findsOneWidget);

    await tester.pump(const Duration(seconds: 3));
  });
}
