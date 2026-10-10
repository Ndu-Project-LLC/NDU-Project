// Widget tests for the WBS Mapping and Sub WBS columns in the Front End
// Planning → Requirements table.
//
// The columns are live pickers: WBS Mapping chooses the Level-1 goal (or ALL),
// and Sub WBS chooses the Level-2 elements under that goal. Choosing ALL means
// the requirement applies to the whole project, so Sub WBS is left blank.

// ignore_for_file: depend_on_referenced_packages
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ndu_project/models/project_data_model.dart';
import 'package:ndu_project/providers/app_content_provider.dart';
import 'package:ndu_project/providers/project_data_provider.dart';
import 'package:ndu_project/screens/front_end_planning_requirements_screen.dart';
import 'package:ndu_project/widgets/wbs_mapping_selectors.dart';
import 'package:ndu_project/wbs/providers/wbs_provider.dart';

Future<void> _pumpScreen(
  WidgetTester tester, {
  Size size = const Size(2400, 1200),
  bool charterApproved = false,
}) async {
  // The table's fixed column widths are wider than the default test surface.
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final model = ProjectDataModel().copyWith(projectId: 'p1');
  model.frontEndPlanning.charterApproved = charterApproved;
  model.frontEndPlanning.requirements =
      'The system shall store requirements in Firestore\n'
      'The system shall export the requirements plan to PDF';

  final provider = ProjectDataProvider();
  provider.updateProjectData(model);

  await tester.pumpWidget(
    ProjectDataInherited(
      provider: provider,
      child: MultiProvider(
        providers: [
          ChangeNotifierProvider<ProjectDataProvider>.value(value: provider),
          ChangeNotifierProvider<WBSProvider>.value(value: WBSProvider()),
          ChangeNotifierProvider<AppContentProvider>.value(
              value: AppContentProvider()),
        ],
        child: const MaterialApp(home: FrontEndPlanningRequirementsScreen()),
      ),
    ),
  );
  // The load runs after the first frame and the Firebase-less data load gives
  // up on its own, so pump fixed frames instead of settling on an animation.
  for (var i = 0; i < 8; i++) {
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

  testWidgets('table shows WBS Mapping and Sub WBS pickers for each row',
      (tester) async {
    await _pumpScreen(tester);

    expect(find.text('WBS Mapping'), findsOneWidget);
    expect(find.text('Sub WBS'), findsOneWidget);
    expect(find.text('WBS Mapping (Goal)'), findsNothing);

    // One goal picker and one element picker per requirement row.
    final rows = find.byKey(const ValueKey('req_table_row_0'));
    expect(rows, findsOneWidget);
    expect(find.byType(WbsGoalDropdown), findsNWidgets(2));
    expect(find.byType(WbsElementMultiSelect), findsNWidgets(2));

    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('choosing ALL blanks Sub WBS for that requirement only',
      (tester) async {
    await _pumpScreen(tester);

    // Row 0's goal picker: the first WBS Mapping dropdown in the table.
    await tester.tap(find.descendant(
      of: find.byType(WbsGoalDropdown).first,
      matching: find.byType(DropdownButton<String>),
    ));
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.tap(find.text('ALL — Entire project').last);
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    // Row 0 now has no element picker; row 1 (no goal yet) still has one.
    expect(find.byType(WbsElementMultiSelect), findsOneWidget);
    expect(find.text('ALL — Entire project'), findsWidgets);

    // Let the debounced auto-save finish before the test ends.
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('charter lock disables editing but keeps the table scrollable',
      (tester) async {
    // Narrow, short surface so the table overflows horizontally and the page
    // overflows vertically.
    await _pumpScreen(tester,
        size: const Size(1400, 600), charterApproved: true);

    // Editing is locked: the WBS pickers are disabled.
    final goalPicker =
        tester.widget<WbsGoalDropdown>(find.byType(WbsGoalDropdown).first);
    expect(goalPicker.enabled, isFalse);

    final row = find.byKey(const ValueKey('req_table_row_0'));

    // Vertical: the row starts below the fold on this short surface, so the
    // page has to scroll down to it — and the lock must not swallow that.
    final page = _scrollableFor(tester, row, AxisDirection.down);
    expect(page.position.maxScrollExtent, greaterThan(0));
    await tester.ensureVisible(row);
    await tester.pump();
    expect(page.position.pixels, greaterThan(0),
        reason: 'the page did not scroll down to the table under the lock');

    // Horizontal: with the row on screen, dragging it scrolls the table
    // sideways. The drag starts from a point that is inside both the row and
    // the visible viewport.
    final horizontal =
        _scrollableFor(tester, row, AxisDirection.right);
    expect(horizontal.position.maxScrollExtent, greaterThan(0));
    final before = horizontal.position.pixels;
    final rowRect = tester.getRect(row);
    final visibleStart = Offset(rowRect.left + 200, rowRect.center.dy);
    await tester.dragFrom(visibleStart, const Offset(-300, 0));
    await tester.pump();
    expect(horizontal.position.pixels, greaterThan(before),
        reason: 'the table did not scroll sideways under the lock');

    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
  });
}

ScrollableState _scrollableFor(
  WidgetTester tester,
  Finder from,
  AxisDirection direction,
) {
  return tester
      .stateList<ScrollableState>(
          find.ancestor(of: from, matching: find.byType(Scrollable)))
      .firstWhere((s) => s.widget.axisDirection == direction);
}
