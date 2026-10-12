// Lusaka 15: the Codes / Standards column is read-only on the requirements
// screens — Front End Planning → Requirements (here) and Planning →
// Requirements.
//
// Codes and standards are authored in Design Planning (Design Specifications →
// Requirements Mapping) and then surface on the requirements log. Leaving the
// picker on the requirements pages made them look like the place to fill them
// in, so the cell now reports what Design Planning mapped:
//
//   "it needs to be grayed out. So it's something that they don't have to fill
//    out now, for when they then go to the codes and standards and map it to
//    the requirements, then it can show up on this requirements log."
//
// This replaces the Lusaka 14 test that asserted the picker itself.

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
import 'package:ndu_project/widgets/codes_standards_selectors.dart';
import 'package:ndu_project/wbs/providers/wbs_provider.dart';

Future<void> _pumpScreen(WidgetTester tester) async {
  tester.view.physicalSize = const Size(2600, 1200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final model = ProjectDataModel().copyWith(projectId: 'p1');
  // Two requirements: one already mapped to a standard by Design Planning,
  // one still unmapped.
  model.frontEndPlanning.requirementItems = <RequirementItem>[
    RequirementItem(
      id: 'r1',
      description: 'The system shall encrypt data at rest',
      codesStandards: const ['Data Protection Standard'],
    ),
    RequirementItem(
      id: 'r2',
      description: 'The system shall log every access',
    ),
  ];
  model.qualityManagementData = QualityManagementData.empty().copyWith(
    standards: <QualityStandard>[
      QualityStandard(
        id: 's1',
        name: 'Data Protection Standard',
        source: 'ISO 27001',
        category: 'Security',
        description: '',
        applicability: '',
      ),
    ],
  );

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
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });

  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  testWidgets('the table shows a read-only Codes / Standards cell per row',
      (tester) async {
    await _pumpScreen(tester);

    // The column is still there, with one read-only cell per requirement...
    expect(find.text('Codes / Standards'), findsOneWidget);
    expect(find.byType(CodesStandardsReadOnly), findsNWidgets(2));

    // ... and no picker.
    expect(find.byType(CodesStandardsMultiSelect), findsNothing);
    expect(find.text('Select codes…'), findsNothing);

    // What Design Planning mapped is reported, and the unmapped row says so.
    expect(find.text('Data Protection Standard'), findsOneWidget);
    expect(find.text('Set in Design Planning'), findsNWidgets(2));

    expect(tester.takeException(), isNull);
  });

  testWidgets('tapping the cell does not open the codes picker',
      (tester) async {
    await _pumpScreen(tester);

    final cell = find.byType(CodesStandardsReadOnly).first;
    await tester.ensureVisible(cell);
    await tester.pump();
    expect(tester.takeException(), isNull);

    await tester.tap(cell);
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 150));
    }

    // The Quality Management picker dialog must not open.
    expect(find.text('Select all'), findsNothing);
    expect(find.text('Done'), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.pump(const Duration(seconds: 1));
  });
}
