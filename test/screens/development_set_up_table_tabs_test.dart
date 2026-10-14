// Development Set Up used to stack its framework guide, five registers and the
// approval gates in one long column, so the last table meant scrolling past
// everything above it. The registers now sit behind the same tab navigator the
// Launch Phase screens use, with the framework guide as the leading Overview tab.
//
// Register *titles* double as tab labels, so they cannot tell which body is on
// screen; these assertions use each panel's subtitle instead.

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
import 'package:ndu_project/screens/execution/development_set_up_screen.dart';
import 'package:ndu_project/widgets/launch_phase_table_tabs.dart';
import 'package:ndu_project/wbs/providers/wbs_provider.dart';

/// The table tabs, in the order the rail should present them.
const List<String> _tableTabs = [
  'Environment Provisioning Register',
  'CI/CD Pipeline Register',
  'Development Tools Register',
  'Quality Gates Register',
  'Security Baseline Register',
  'Approval Gates',
];

/// Header of the framework guide — the Overview tab's body.
const String _guideHeader = 'Development setup best practices';

/// Subtitles unique to three of the register bodies.
const String _envSubtitle =
    'Track environment provisioning status, access URLs, and ownership across all deployment spaces.';
const String _cicdSubtitle =
    'Track pipeline stages, tools, triggers, and gate criteria for the build-test-deploy workflow.';
const String _approvalSubtitle =
    'Development readiness approval gates aligned with PMI PMBOK phase gates and organizational authority matrices. Each gate must be cleared before development can commence.';

Finder _tab(String label) =>
    find.byKey(ValueKey<String>('launch-phase-tab-$label'));

/// Wide enough for the whole rail, so a tap on any tab lands on it.
Future<void> _pumpScreen(WidgetTester tester) async {
  tester.view.physicalSize = const Size(2000, 1200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  // No project id is set, so the screen renders its empty-state panels without
  // reaching Firestore and the tab host can be exercised in a widget test.
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
        child: const MaterialApp(home: DevelopmentSetUpScreen()),
      ),
    ),
  );

  // The screen keeps a loading spinner running with no Firestore behind it, so
  // pumpAndSettle would never return; settle by frame count instead.
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 200));
  }

  // `updateProjectData` arms an auto-save debounce. Let it fire here rather
  // than leave a pending timer behind at the end of the test; the project has
  // no id, so the save itself is a no-op.
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

  testWidgets('every register sits behind the Launch Phase tab navigator',
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

  testWidgets('the framework guide opens first, not a register', (tester) async {
    await _pumpScreen(tester);

    expect(find.text(_guideHeader), findsOneWidget);
    expect(find.text(_envSubtitle), findsNothing);
    expect(find.text(_approvalSubtitle), findsNothing);
  });

  testWidgets('tapping a tab swaps in that register without scrolling',
      (tester) async {
    await _pumpScreen(tester);

    await tester.tap(_tab('Environment Provisioning Register'));
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    expect(find.text(_envSubtitle), findsOneWidget);
    expect(find.text(_guideHeader), findsNothing);

    await tester.tap(_tab('CI/CD Pipeline Register'));
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    expect(find.text(_cicdSubtitle), findsOneWidget);
    expect(find.text(_envSubtitle), findsNothing);

    // The last tab of seven: reachable without scrolling the page.
    final approval = _tab('Approval Gates');
    await tester.ensureVisible(approval);
    // Bounded pumps, not pumpAndSettle: this screen keeps a spinner running
    // with no Firestore behind it, so pumpAndSettle would never return.
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    await tester.tap(approval);
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    expect(find.text(_approvalSubtitle), findsOneWidget);
    expect(find.text(_cicdSubtitle), findsNothing);
  });
}
