// Lusaka 14: in Planning the Scope Tracking Plan page is a scope-transfer
// plan — how agreed scope is handed into the project — and must not carry the
// Execution scope tracking (registry / traceability / baseline & variance) or
// change management. It must also be reachable from the sidebar again.

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
import 'package:ndu_project/screens/scope_tracking_plan_screen.dart';
import 'package:ndu_project/widgets/initiation_like_sidebar.dart';
import 'package:ndu_project/wbs/providers/wbs_provider.dart';

Future<void> _pumpScreen(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1400, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final provider = ProjectDataProvider();
  provider.updateProjectData(ProjectDataModel(projectName: 'Agility Platform'));

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
        child: const MaterialApp(home: ScopeTrackingPlanScreen()),
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

  testWidgets('the page presents a scope-transfer plan summary',
      (tester) async {
    await _pumpScreen(tester);

    expect(find.text('Scope Transfer Plan'), findsWidgets);
    expect(find.text('Scope the transfer'), findsOneWidget);
    expect(find.text('Map to the WBS'), findsOneWidget);
    expect(find.text('Route changes elsewhere'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the Execution scope-tracking tabs are not shown', (tester) async {
    await _pumpScreen(tester);

    expect(find.text('Scope Registry'), findsNothing);
    expect(find.text('Traceability'), findsNothing);
    expect(find.text('Baseline & Variance'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the sidebar still offers a Scope Tracking Plan entry',
      (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: InitiationLikeSidebar()),
      ),
    );
    await tester.pumpAndSettle();

    // The sub-page lives under Project Services — bring it on screen and
    // make sure the section is open.
    final projectServices = find.text('Project Services');
    await tester.ensureVisible(projectServices);
    await tester.pumpAndSettle();

    // Expansion is remembered in a *static* that is shared by every sidebar
    // instance (`_sharedProjectServicesExpanded`), and the sidebar opens this
    // section by itself when the active item lives in it. The screens pumped
    // by the tests above do exactly that, so by the time this test builds a
    // sidebar the section is already open — tapping it unconditionally would
    // collapse it and the entry would be gone. Only open it when it is shut.
    if (find.text('Scope Tracking Plan').evaluate().isEmpty) {
      await tester.tap(projectServices);
      await tester.pumpAndSettle();
    }

    expect(find.text('Scope Tracking Plan'), findsOneWidget);
  });
}
