// Every Design Planning sub-item in the sidebar must open its own page. Each
// tap should push a DesignPlanningScreen that deep-links to the section the
// sidebar entry names.

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
import 'package:ndu_project/wbs/providers/wbs_provider.dart';
import 'package:ndu_project/widgets/initiation_like_sidebar.dart';

/// Sidebar label → the section id the sidebar passes to DesignPlanningScreen.
/// These must match `_sectionOrder` in `design_planning_screen.dart`.
const Map<String, String> _subItems = {
  'Project Overview': 'overview',
  'Design Overview': 'design_overview',
  'Design Specifications': 'design_specifications_workspace',
  'Deviations': 'deviations',
  'Requirements Mapping': 'requirements',
  'Architecture Basis': 'architecture',
  'UI/UX Basis': 'uiux',
  'Technical Basis': 'technical',
  'Constraints & Assumptions': 'constraints',
  'Risks & Mitigation': 'risks',
  'Dependencies': 'dependencies',
  'Decision Log': 'decisions',
  'Validation': 'validation',
  'Approvals': 'approvals',
  'Work Packages': 'work_packages',
};

Future<void> _pumpSidebar(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1400, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final provider = ProjectDataProvider();
  provider.updateProjectData(ProjectDataModel(
    projectName: 'Agility Platform',
    solutionTitle: 'Delivery platform',
  ));

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
            body: InitiationLikeSidebar(activeItemLabel: 'Design Planning'),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });

  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  for (final entry in _subItems.entries) {
    testWidgets('sidebar "${entry.key}" opens Design Planning at its section',
        (tester) async {
      await _pumpSidebar(tester);

      final item = find.text(entry.key);
      expect(item, findsOneWidget,
          reason: 'the "${entry.key}" sub-item is not in the sidebar');

      // The sidebar is a long scrolling list; bring the entry on screen the
      // way a user scrolling the menu would before tapping it.
      await tester.ensureVisible(item);
      await tester.pump();
      await tester.tap(item);
      for (var i = 0; i < 14; i++) {
        await tester.pump(const Duration(milliseconds: 150));
      }

      expect(tester.takeException(), isNull);
      final opened = find.byType(DesignPlanningScreen);
      expect(opened, findsOneWidget,
          reason: 'tapping "${entry.key}" did not open Design Planning');
      expect(
        tester.widget<DesignPlanningScreen>(opened).initialSectionId,
        entry.value,
        reason: 'tapping "${entry.key}" opened the wrong section',
      );
    });
  }
}
