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
import 'package:ndu_project/screens/planning/planning_requirements_screen.dart';
import 'package:ndu_project/wbs/providers/wbs_provider.dart';

// Printed by the framework if the table lays out with unbounded width.
const String _unboundedFlex =
    'RenderFlex children have non-zero flex but incoming width constraints are unbounded';
const String _unboundedViewport = 'Vertical viewport was given unbounded width';
const String _scrollbarNoPosition =
    "The Scrollbar's ScrollController has no ScrollPosition attached";

Future<ProjectDataProvider> _pumpWithRows(
  WidgetTester tester, {
  bool charterApproved = false,
  Size surfaceSize = const Size(2000, 1200),
}) async {
  // Use a desktop surface by default so the fixed-width grid can be tested
  // without reporting its expected horizontal overflow. Mobile-specific tests
  // pass the target viewport size explicitly.
  tester.view.physicalSize = surfaceSize;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final model = ProjectDataModel().copyWith(projectId: 'p1');
  // Requirements arrive as newline-separated text; each line becomes a row.
  model.frontEndPlanning.requirements =
      'The system shall store requirements in Firestore\n'
      'The system shall export the requirements plan to PDF';
  if (charterApproved) {
    model.charterApprovalDate = DateTime(2026, 1, 1);
  }

  final provider = ProjectDataProvider();
  provider.updateProjectData(model);

  await tester.pumpWidget(
    ProjectDataInherited(
      provider: provider,
      child: MultiProvider(
        providers: [
          ChangeNotifierProvider<ProjectDataProvider>.value(value: provider),
          // The requirement rows' WBS goal/element pickers (Lusaka 28) read
          // the WBS tree.
          ChangeNotifierProvider<WBSProvider>.value(value: WBSProvider()),
        ],
        child: const MaterialApp(home: PlanningRequirementsScreen()),
      ),
    ),
  );
  // Spinners only stop once the Firebase-less load gives up, so pump fixed
  // frames rather than settling on an animation that never ends.
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 200));
  }

  return provider;
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

void _expectNoMobileFlexOverflow(WidgetTester tester) {
  Object? error;
  while ((error = tester.takeException()) != null) {
    final text = error.toString();
    expect(
      text.contains('RenderFlex overflowed'),
      isFalse,
      reason: 'mobile layout overflowed:\n$text',
    );
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

  testWidgets('the table renders requirement rows without unbounded width',
      (tester) async {
    await _pumpWithRows(tester);

    // The row list is only built when rows exist, which is the whole point.
    expect(find.byType(ReorderableListView), findsWidgets);
    _expectNoUnboundedWidthFailure(tester.takeException(), 'with rows');

    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('mobile viewport renders each requirement as a labeled card',
      (tester) async {
    await _pumpWithRows(
      tester,
      surfaceSize: const Size(427, 952),
    );

    expect(find.byKey(const ValueKey('req_mobile_card_0')), findsOneWidget);
    expect(find.byKey(const ValueKey('req_mobile_card_1')), findsOneWidget);
    expect(find.text('Requirement type'), findsWidgets);
    expect(find.text('WBS Goal (Level 1)'), findsWidgets);
    expect(find.text('Codes / Standards'), findsWidgets);
    expect(find.byKey(const ValueKey('req_header')), findsNothing);
    _expectNoUnboundedWidthFailure(tester.takeException(), 'on mobile');
    _expectNoMobileFlexOverflow(tester);

    await tester.pump(const Duration(seconds: 3));
    _expectNoMobileFlexOverflow(tester);
  });

  testWidgets('Expand renders the full-screen copy with rows', (tester) async {
    await _pumpWithRows(tester);

    await tester.tap(find.text('Expand'));
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(find.byType(ReorderableListView), findsWidgets);
    _expectNoUnboundedWidthFailure(
        tester.takeException(), 'in the expanded copy');

    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('Add another adds a row even after the charter is approved',
      (tester) async {
    final provider = await _pumpWithRows(tester, charterApproved: true);

    // Regression: the Planning-phase Requirements page is a later phase than
    // the Front End Planning the charter lock applies to, so it must stay
    // editable. Gating it on the FEP charter lock left the whole page
    // read-only once the charter was approved and made this button do nothing.
    expect(provider.projectData.frontEndPlanning.requirementItems, isEmpty);
    final addButton = find.widgetWithText(OutlinedButton, 'Add another');
    expect(tester.widget<OutlinedButton>(addButton).onPressed, isNotNull);

    await tester.ensureVisible(addButton);
    await tester.pump();
    await tester.tap(addButton);
    // The page has ongoing animations, so pumpAndSettle would never return.
    await tester.pump(const Duration(milliseconds: 400));

    // "Add another" opens a modal; the row is only added once it is confirmed.
    final dialog = find.byType(AlertDialog);
    expect(dialog, findsOneWidget);
    await tester.enterText(
        find.descendant(of: dialog, matching: find.byType(TextField)),
        'The system shall send weekly status emails');
    await tester.pump();
    await tester.tap(find.descendant(
        of: dialog, matching: find.widgetWithText(ElevatedButton, 'Add')));
    await tester.pump(const Duration(milliseconds: 400));

    // Let the debounced autosave persist the new row. The third table row sits
    // below the scroll viewport and is built lazily, so the persisted items are
    // the reliable signal that the row was added.
    await tester.pump(const Duration(milliseconds: 800));

    // The two seeded requirements plus the one just added.
    expect(provider.projectData.frontEndPlanning.requirementItems.length, 3);

    await tester.pump(const Duration(seconds: 3));
  });
}
