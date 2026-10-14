// Lusaka 15 items 7-8: the Design Specifications table is the register (each
// row shows the requirement(s) it applies to), and Requirements Mapping is a
// table first — where codes / standards are applied to requirements and the
// still-unmapped requirement is called out.
//
//   "when you go to the design specifications … you actually list all the
//    specifications … a table where you are listing all the codes, standards,
//    specifications, their source and all of that."
//   "This was supposed to be a table view … that made it easy to see what
//    requirements need to be mapped."

// ignore_for_file: depend_on_referenced_packages
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ndu_project/models/project_data_model.dart';
import 'package:ndu_project/providers/project_data_provider.dart';
import 'package:ndu_project/screens/design/design_planning_screen.dart';
import 'package:ndu_project/utils/design_planning_document.dart';
import 'package:ndu_project/widgets/codes_standards_selectors.dart';
import 'package:ndu_project/wbs/providers/wbs_provider.dart';

/// One requirement carries a code / standard and a specification applies to
/// it; the other carries neither, so it is the row the table must call out.
ProjectDataModel _projectData() {
  final document = DesignPlanningDocument(
    specifications: [
      DesignSpecificationPlanRow(
        id: 'spec_sso',
        title: 'ISO 27001 access control',
        specificationType: 'Standard',
        attachedRequirementIds: ['r1'],
      ),
      DesignSpecificationPlanRow(
        id: 'spec_wcag',
        title: 'WCAG 2.2 AA',
        specificationType: 'Standard',
      ),
    ],
  );
  return ProjectDataModel(
    projectName: 'Agility Platform',
    solutionTitle: 'Delivery platform',
    frontEndPlanning: FrontEndPlanningData(
      requirementItems: [
        RequirementItem(
          id: 'r1',
          description: 'Platform must support SSO',
          codesStandards: ['ISO 27001'],
        ),
        RequirementItem(
          id: 'r2',
          description: 'Reports must export to PDF',
        ),
      ],
    ),
    planningNotes: document.toPlanningNotesPatch(),
  );
}

Future<void> _pumpScreen(
  WidgetTester tester, {
  required String sectionId,
}) async {
  tester.view.physicalSize = const Size(1600, 1000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final provider = ProjectDataProvider();
  provider.updateProjectData(_projectData());

  await tester.pumpWidget(
    ProjectDataInherited(
      provider: provider,
      child: MultiProvider(
        providers: [
          ChangeNotifierProvider<ProjectDataProvider>.value(value: provider),
          ChangeNotifierProvider<WBSProvider>.value(value: WBSProvider()),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: DesignPlanningScreen(initialSectionId: sectionId),
          ),
        ),
      ),
    ),
  );
  for (var i = 0; i < 14; i++) {
    await tester.pump(const Duration(milliseconds: 150));
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

  testWidgets(
      'Requirements Mapping opens as a table and calls out the unmapped row',
      (tester) async {
    await _pumpScreen(tester, sectionId: 'requirements');

    // Table first: the codes / standards are editable here, and the table
    // names the specification(s) each requirement is mapped to.
    expect(find.text('Table'), findsWidgets);
    expect(find.text('Codes / Standards'), findsOneWidget);
    expect(find.text('Specification(s) applied'), findsOneWidget);
    expect(find.byType(CodesStandardsMultiSelect), findsWidgets);

    expect(find.textContaining('Platform must support SSO'), findsWidgets);
    expect(find.textContaining('Reports must export to PDF'), findsWidgets);
    expect(find.text('ISO 27001'), findsWidgets,
        reason: 'the mapped code / standard shows on the requirement row');

    // The unmapped requirement is called out, by chip and by status.
    expect(find.text('Needs mapping (1)'), findsOneWidget);
    expect(find.textContaining('1 requirement(s) still need a code / standard'),
        findsOneWidget);

    // The unlinked specification is a coverage gap too ("Every listed
    // specification must be mapped to at least one requirement").
    expect(find.textContaining('not mapped to any requirement yet'),
        findsOneWidget);

    expect(tester.takeException(), isNull);
  });

  testWidgets('the Needs mapping filter narrows the table to unmapped rows',
      (tester) async {
    await _pumpScreen(tester, sectionId: 'requirements');

    // The section scrolls, so bring the chip into view before tapping it.
    await tester.ensureVisible(find.text('Needs mapping (1)'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('Needs mapping (1)'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.textContaining('Reports must export to PDF'), findsWidgets);
    expect(find.textContaining('Platform must support SSO'), findsNothing,
        reason: 'the mapped requirement should be filtered out');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'Design Specifications table names the requirement each row applies to',
      (tester) async {
    await _pumpScreen(tester, sectionId: 'design_specifications_workspace');

    expect(find.text('Applies to requirements'), findsOneWidget,
        reason: 'the specifications register must show the requirement link');
    expect(find.text('Code / standard / specification'), findsWidgets);
    expect(find.text('ISO 27001 access control'), findsWidgets);
    expect(find.textContaining('Platform must support SSO'), findsWidgets,
        reason: 'the applied requirement is shown by name, not by id');
    expect(find.text('Not mapped'), findsWidgets,
        reason: 'the unlinked specification is called out in the table');
    expect(find.textContaining('not mapped to a requirement yet'),
        findsOneWidget);

    expect(tester.takeException(), isNull);
  });
}
