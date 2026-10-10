// Lusaka 14: the Design Plan → Work Packages section is the one place that
// answers "what must this design satisfy?". Each WBS item echoes the
// requirements mapped to it (read-only from Requirements) together with the
// codes / standards those requirements carry.

// ignore_for_file: depend_on_referenced_packages
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ndu_project/models/project_data_model.dart';
import 'package:ndu_project/providers/project_data_provider.dart';
import 'package:ndu_project/screens/design_planning_screen.dart';
import 'package:ndu_project/wbs/providers/wbs_provider.dart';

Future<void> _pumpWorkPackages(
  WidgetTester tester, {
  required List<WorkItem> wbsTree,
  required List<RequirementItem> requirementItems,
}) async {
  tester.view.physicalSize = const Size(1400, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final model = ProjectDataModel(
    projectName: 'Agility Platform',
    solutionTitle: 'Delivery platform',
  );
  model.wbsTree = wbsTree;
  model.frontEndPlanning.requirementItems = requirementItems;

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
        child: const MaterialApp(
          home: Scaffold(
            body: DesignPlanningScreen(initialSectionId: 'work_packages'),
          ),
        ),
      ),
    ),
  );
  for (var i = 0; i < 14; i++) {
    await tester.pump(const Duration(milliseconds: 150));
  }
  // Clear the provider's 2s auto-save debounce.
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });

  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  testWidgets('each WBS item lists its requirements and their codes/standards',
      (tester) async {
    final wbsTree = <WorkItem>[
      WorkItem(
        title: 'Epic: Secure platform',
        wbsCode: 'G1',
        children: <WorkItem>[
          WorkItem(title: 'Feature: Encrypted storage', wbsCode: 'G1.1'),
        ],
      ),
    ];
    final requirementItems = <RequirementItem>[
      RequirementItem(
        description: 'Encrypt data at rest',
        wbsGoalId: 'G1',
        wbsElementIds: const ['G1.1'],
        codesStandards: const ['ISO 27001'],
      ),
    ];

    await _pumpWorkPackages(
      tester,
      wbsTree: wbsTree,
      requirementItems: requirementItems,
    );

    // The mapped requirement is echoed under each WBS item it targets.
    expect(find.textContaining('Encrypt data at rest'), findsWidgets);
    // ... together with the codes / standards it carries.
    expect(find.textContaining('Codes / Standards: ISO 27001'), findsWidgets);
    // ... and the section says this view is read-only.
    expect(find.textContaining('reflected here read-only'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a requirement with no codes/standards still lists read-only',
      (tester) async {
    final wbsTree = <WorkItem>[
      WorkItem(
        title: 'Epic: Secure platform',
        wbsCode: 'G1',
        children: <WorkItem>[
          WorkItem(title: 'Feature: Encrypted storage', wbsCode: 'G1.1'),
        ],
      ),
    ];
    final requirementItems = <RequirementItem>[
      RequirementItem(
        description: 'Log every access',
        wbsGoalId: 'G1',
        wbsElementIds: const ['G1.1'],
      ),
    ];

    await _pumpWorkPackages(
      tester,
      wbsTree: wbsTree,
      requirementItems: requirementItems,
    );

    expect(find.textContaining('Log every access'), findsWidgets);
    expect(find.textContaining('Codes / Standards:'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
