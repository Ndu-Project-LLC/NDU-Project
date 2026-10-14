// Lusaka 15: on Planning Phase → Requirements the Codes / Standards column is
// no longer an input.
//
// A requirement finishes at its WBS mapping. The codes and standards a
// requirement must satisfy are authored in Design Planning (Design
// Specifications, then Requirements Mapping) and then surface on this log.
// Leaving the picker in the cell made the requirements page look like the place
// to fill them in, so the cell is now a greyed, non-tappable report of what
// Design Planning mapped.
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
import 'package:ndu_project/widgets/codes_standards_selectors.dart';
import 'package:ndu_project/wbs/providers/wbs_provider.dart';

Future<void> _pumpScreen(WidgetTester tester) async {
  // The table's fixed column widths total 2750, so the default 800x600 test
  // surface would report its own overflow. Use a desktop-sized surface.
  tester.view.physicalSize = const Size(2000, 1200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final model = ProjectDataModel().copyWith(projectId: 'p1');
  model.frontEndPlanning.requirementItems = <RequirementItem>[
    RequirementItem(
      id: 'r1',
      description: 'The system shall encrypt data at rest',
      codesStandards: const ['ISO 27001'],
    ),
  ];

  final provider = ProjectDataProvider();
  provider.updateProjectData(model);

  await tester.pumpWidget(
    ProjectDataInherited(
      provider: provider,
      child: MultiProvider(
        providers: [
          ChangeNotifierProvider<ProjectDataProvider>.value(value: provider),
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
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });

  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  testWidgets('the Codes / Standards cell is read-only, not a picker',
      (tester) async {
    await _pumpScreen(tester);

    expect(find.byType(CodesStandardsReadOnly), findsWidgets);
    expect(find.byType(CodesStandardsMultiSelect), findsNothing);
    expect(find.text('Select codes…'), findsNothing);

    // What Design Planning mapped is still shown on the log.
    expect(find.text('ISO 27001'), findsWidgets);
    expect(find.text('Set in Design Planning'), findsWidgets);

    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('tapping the cell does not open the codes picker',
      (tester) async {
    await _pumpScreen(tester);

    // The column sits near the right edge of the 2750-wide table, so bring it
    // into view before tapping — otherwise the tap misses and proves nothing.
    final cell = find.byType(CodesStandardsReadOnly).first;
    await tester.ensureVisible(cell);
    await tester.pump();
    expect(tester.takeException(), isNull);

    await tester.tap(cell);
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 150));
    }

    // The picker dialog ("Select all" + a Done button) must not open.
    expect(find.text('Select all'), findsNothing);
    expect(find.text('Done'), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.pump(const Duration(seconds: 3));
  });
}
