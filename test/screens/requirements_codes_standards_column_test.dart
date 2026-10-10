// Lusaka 14: each requirement row carries the codes / standards it must
// satisfy. The picker only offers standards already captured in Quality
// Management (never free-typed), and the choice sticks to the row.

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
  model.frontEndPlanning.requirements =
      'The system shall encrypt data at rest\n'
      'The system shall log every access';
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

  testWidgets('table shows a Codes / Standards picker per requirement row',
      (tester) async {
    await _pumpScreen(tester);

    expect(find.text('Codes / Standards'), findsOneWidget);
    expect(find.byType(CodesStandardsMultiSelect), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('the picker only offers captured standards and keeps the choice',
      (tester) async {
    await _pumpScreen(tester);

    // The underlying screen runs ongoing timers, so pump fixed frames rather
    // than settling on an animation.
    await tester.tap(find.byType(CodesStandardsMultiSelect).first);
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 150));
    }

    // The captured standard (and its code) is offered; nothing is free-typed.
    expect(find.text('Data Protection Standard'), findsOneWidget);
    expect(find.text('ISO 27001'), findsOneWidget);

    await tester.tap(find.text('Data Protection Standard'));
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(milliseconds: 150));
    }
    await tester.tap(find.text('Done'));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 150));
    }

    // The row now shows the chosen standard.
    expect(
      find.descendant(
        of: find.byType(CodesStandardsMultiSelect).first,
        matching: find.text('Data Protection Standard'),
      ),
      findsOneWidget,
    );
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
  });
}
