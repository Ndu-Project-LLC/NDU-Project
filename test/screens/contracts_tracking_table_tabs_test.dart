// The Contracts Tracking screen used to stack its four registers in one long
// column, so the last one was several screens of scrolling away. It now uses
// the same tab navigator the Launch Phase screens use, with the control
// framework as the leading Overview tab.

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
import 'package:ndu_project/screens/contracts_tracking_screen.dart';
import 'package:ndu_project/widgets/launch_phase_table_tabs.dart';
import 'package:ndu_project/wbs/providers/wbs_provider.dart';

/// The table tabs, in the order the rail should present them.
const List<String> _tableTabs = [
  'Contract register',
  'Renewal pipeline',
  'Risk signals',
  'Approval readiness',
];

Finder _tab(String label) =>
    find.byKey(ValueKey<String>('launch-phase-tab-$label'));

/// No project id is set: the screen then renders its empty-state panels without
/// reaching Firestore, so the tab host can be exercised in a widget test.
Future<void> _pumpScreen(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1400, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final provider = ProjectDataProvider();
  provider.updateProjectData(ProjectDataModel(projectName: 'Agility Platform'));
  addTearDown(provider.reset);

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
        child: const MaterialApp(home: ContractsTrackingScreen()),
      ),
    ),
  );
  // The screen keeps a loading spinner running with no Firestore behind it, so
  // pumpAndSettle would never return; settle by frame count instead.
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 200));
  }

  // `updateProjectData` arms a two-second auto-save debounce. Let it fire here
  // rather than leave a pending timer behind at the end of the test; the
  // project has no id, so the save itself is a no-op.
  await provider.flushAutoSave();
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });

  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  testWidgets('the registers sit behind the Launch Phase tab navigator',
      (tester) async {
    await _pumpScreen(tester);

    expect(find.byType(LaunchPhaseTableTabs), findsOneWidget);
    expect(_tab('Overview'), findsOneWidget);
    for (final label in _tableTabs) {
      expect(_tab(label), findsOneWidget, reason: 'missing "$label" tab');
    }

    // The tab host derives its body height from the viewport, so a bad figure
    // would surface here as a layout overflow rather than as a wrong tab.
    expect(tester.takeException(), isNull);
  });

  testWidgets('the control framework opens first, not a register',
      (tester) async {
    await _pumpScreen(tester);

    expect(find.text('Contract control framework'), findsOneWidget);
    expect(
      find.text('Track scope, owners, and renewal milestones'),
      findsNothing,
    );
    expect(find.text('Items that need attention this week'), findsNothing);
  });

  testWidgets('tapping a tab swaps in that register without scrolling',
      (tester) async {
    await _pumpScreen(tester);

    await tester.tap(_tab('Contract register'));
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    expect(
      find.text('Track scope, owners, and renewal milestones'),
      findsOneWidget,
    );
    expect(find.text('Contract control framework'), findsNothing);

    await tester.tap(_tab('Risk signals'));
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    expect(find.text('Items that need attention this week'), findsOneWidget);
    expect(
      find.text('Track scope, owners, and renewal milestones'),
      findsNothing,
    );
  });
}
