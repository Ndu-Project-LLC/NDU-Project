// Each Design Planning section panel has an enlarge control. Enlarging hides the
// section rail and the page context band so the open section fills the screen;
// the exit control restores them.

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
import 'package:ndu_project/widgets/planning_phase_header.dart';
import 'package:ndu_project/widgets/responsive_scaffold.dart';
import 'package:ndu_project/wbs/providers/wbs_provider.dart';

/// A rail label; the rail is found by its own semantics container below,
/// because the same label also appears in the open section's content.
const String _railLabel = 'Design Specifications';

Finder _railText() => find.descendant(
      of: find.byWidgetPredicate(
        (w) =>
            w is Semantics && w.properties.label == 'Design Planning sections',
      ),
      matching: find.text(_railLabel),
    );

Future<void> _pumpScreen(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1400, 900);
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
            body: DesignPlanningScreen(initialSectionId: 'work_packages'),
          ),
        ),
      ),
    ),
  );
  // Let the deep-link scroll and the provider's auto-save debounce settle.
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

  testWidgets('enlarging fills the whole screen and exiting restores the page',
      (tester) async {
    await _pumpScreen(tester);

    expect(_railText(), findsOneWidget,
        reason: 'the section rail should show before enlarging');
    expect(find.byType(ResponsiveScaffold), findsOneWidget);
    expect(find.byType(PlanningPhaseHeader), findsOneWidget);
    expect(find.byTooltip('Enlarge section'), findsOneWidget);

    await tester.ensureVisible(find.byTooltip('Enlarge section'));
    await tester.tap(find.byTooltip('Enlarge section'));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    // The whole screen: no sidebar scaffold, no page header, no rail.
    expect(find.byType(ResponsiveScaffold), findsNothing,
        reason: 'enlarged view should replace the page, sidebar included');
    expect(find.byType(PlanningPhaseHeader), findsNothing);
    expect(_railText(), findsNothing,
        reason: 'enlarged view should hide the section rail');
    expect(find.byTooltip('Exit enlarged view'), findsOneWidget);
    expect(find.byTooltip('Enlarge section'), findsNothing);
    expect(find.text('Design Work Packages'), findsWidgets,
        reason: 'the open section must still be shown when enlarged');
    expect(tester.takeException(), isNull);

    await tester.ensureVisible(find.byTooltip('Exit enlarged view'));
    await tester.tap(find.byTooltip('Exit enlarged view'));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(find.byType(ResponsiveScaffold), findsOneWidget,
        reason: 'exiting should bring back the normal page');
    expect(_railText(), findsOneWidget,
        reason: 'exiting the enlarged view should restore the section rail');
    expect(find.byTooltip('Enlarge section'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
