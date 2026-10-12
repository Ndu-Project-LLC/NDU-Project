// The Integration Dashboard's hero header must survive a phone viewport.
//
// `/dashboard` is reachable on mobile (the mobile shell links to it), so the
// hero band cannot rely on desktop width. These tests render the header at the
// narrowest phone width we support and fail on any RenderFlex overflow — the
// striped "RIGHT OVERFLOWED BY N PIXELS" band Flutter paints in debug builds.

// ignore_for_file: depend_on_referenced_packages
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:provider/provider.dart';

import 'package:ndu_project/cost_estimate/providers/cost_estimate_provider.dart';
import 'package:ndu_project/project_controls/providers/project_controls_provider.dart';
import 'package:ndu_project/providers/project_data_provider.dart';
import 'package:ndu_project/schedule/providers/schedule_provider.dart';
import 'package:ndu_project/screens/integration_dashboard_screen.dart';
import 'package:ndu_project/services/dashboard_metrics_service.dart';
import 'package:ndu_project/services/project_service.dart';
import 'package:ndu_project/theme.dart';
import 'package:ndu_project/utils/dashboard_palette.dart';
import 'package:ndu_project/wbs/providers/wbs_provider.dart';
import 'package:ndu_project/widgets/dashboard_header.dart';
import 'package:ndu_project/widgets/integration_dashboard/_integration_tokens.dart';
import 'package:ndu_project/widgets/integration_dashboard/integration_workspaces_view.dart';

/// A basic-plan workspace with the longest plausible field values, so the
/// data-rich layout is exercised rather than the empty state.
ProjectRecord _record({
  required String id,
  required String name,
  required String solution,
  required String businessCase,
  required String owner,
  required double progress,
  required DateTime updatedAt,
}) {
  return ProjectRecord(
    id: id,
    ownerId: 'owner-1',
    ownerEmail: 'owner@example.com',
    ownerName: owner,
    name: name,
    solutionTitle: solution,
    solutionDescription: solution,
    businessCase: businessCase,
    notes: '',
    status: 'in_progress',
    progress: progress,
    investmentMillions: 12.5,
    milestone: 'Design freeze',
    tags: const ['water', 'phase-2'],
    isBasicPlanProject: true,
    createdAt: updatedAt,
    updatedAt: updatedAt,
    checkpointRoute: 'initiation',
    checkpointAt: updatedAt,
    progressSnapshot: const ProjectProgressSnapshot(
      currentPhase: 'Planning',
      completion: 0.4,
      completionPercent: 40,
      totalActivities: 24,
      implementedActivities: 10,
      pendingActivities: 14,
      approvedSections: 3,
      totalSections: 9,
      achievedMilestones: 2,
      totalMilestones: 6,
      overdueActivities: 1,
      health: ProjectProgressHealth.onTrack,
    ),
  );
}

ProjectStatusRollup _rollup(String id, String name, String status) {
  return ProjectStatusRollup(
    projectId: id,
    projectName: name,
    overallStatus: status,
    scheduleStatus: status,
    costStatus: 'on_track',
    scopeStatus: 'on_track',
    qualityStatus: 'on_track',
    riskStatus: status,
    progressPercent: 40,
    budgetUsedPercent: 22,
    openRisks: 2,
    openIssues: 1,
    updatedAt: DateTime(2026, 9, 30),
  );
}
Future<void> _pumpScreen(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final projectProvider = ProjectDataProvider();
  await tester.pumpWidget(
    ProjectDataInherited(
      provider: projectProvider,
      child: MultiProvider(
        providers: [
          ChangeNotifierProvider<ProjectDataProvider>.value(value: projectProvider),
          ChangeNotifierProvider<WBSProvider>.value(value: WBSProvider()),
          ChangeNotifierProvider<ScheduleProvider>.value(value: ScheduleProvider()),
          ChangeNotifierProvider<CostEstimateProvider>.value(
            value: CostEstimateProvider(),
          ),
          ChangeNotifierProvider<ProjectControlsProvider>.value(
            value: ProjectControlsProvider(),
          ),
        ],
        child: MaterialApp(
          theme: lightTheme,
          home: const IntegrationDashboardScreen(
            initialView: IntegrationDashboardView.workspaces,
          ),
        ),
      ),
    ),
  );
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
}

Future<void> _pumpHeader(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final palette = DashboardPalette.forPlan(true);
  await tester.pumpWidget(
    MaterialApp(
      theme: lightTheme,
      home: DashboardPaletteScope(
        palette: palette,
        child: Scaffold(
          body: SingleChildScrollView(
            child: DashboardHeader(
              isBasicPlan: true,
              onAddProject: () {},
              crumbLabel: 'Integration Dashboard',
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 350));
}

/// Renders the data-rich workspaces view — roll-up cards, bento, resume card,
/// search field and the project grid — into a phone-width viewport.
Future<void> _pumpWorkspaces(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final projects = <ProjectRecord>[
    _record(
      id: 'p1',
      name: 'Lusaka Water Supply Network Extension',
      solution: 'Design, procurement and commissioning of the phase-two network',
      businessCase:
          'Slum upgrading programme dependent on a reliable mains supply.',
      owner: 'Chungu Chama',
      progress: 0.42,
      updatedAt: DateTime(2026, 10, 9),
    ),
    _record(
      id: 'p2',
      name: 'Kabulonga Wastewater Treatment Plant Upgrade',
      solution: 'Membrane bioreactor retrofit',
      businessCase: 'Effluent compliance deadline.',
      owner: 'Mumba Mwape',
      progress: 0.18,
      updatedAt: DateTime(2026, 10, 4),
    ),
    _record(
      id: 'p3',
      name: 'Lower Kafue Irrigation Scheme',
      solution: 'Pump station and canal lining',
      businessCase: 'Food security targets.',
      owner: 'Tembo Zulu',
      progress: 0.75,
      updatedAt: DateTime(2026, 9, 28),
    ),
  ];

  final metrics = DashboardMetrics(
    assignedToMe: const [],
    pastDue: const [],
    projectStatuses: [
      _rollup('p1', 'Lusaka Water Supply Network Extension', 'at_risk'),
      _rollup('p2', 'Kabulonga Wastewater Treatment Plant Upgrade', 'on_track'),
      _rollup('p3', 'Lower Kafue Irrigation Scheme', 'off_track'),
    ],
    programStatuses: const [],
    portfolioStatuses: const [],
  );

  await tester.pumpWidget(
    MaterialApp(
      theme: lightTheme,
      home: Scaffold(
        body: Builder(
          builder: (context) {
            final tokens = IntegrationTokens.of(
              context,
              DashboardPalette.forPlan(true),
            );
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: IntegrationWorkspacesView(
                tokens: tokens,
                projects: projects,
                metrics: metrics,
                isLoading: false,
                error: null,
                searchController: TextEditingController(),
                searchQuery: '',
                onSearchChanged: (_) {},
                onRetry: () {},
                onOpenProject: (_) {},
                onCreateProject: () {},
              ),
            );
          },
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 350));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });

  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  testWidgets('hero header does not overflow on a phone viewport',
      (tester) async {
    await _pumpHeader(tester, const Size(427, 952));
    expect(tester.takeException(), isNull);
  });

  testWidgets('hero header does not overflow on the narrowest phone',
      (tester) async {
    await _pumpHeader(tester, const Size(360, 900));
    expect(tester.takeException(), isNull);
  });

  testWidgets('the whole dashboard renders on a phone viewport',
      (tester) async {
    await _pumpScreen(tester, const Size(427, 952));
    expect(tester.takeException(), isNull);
  });

  testWidgets('the view switcher highlights only the selected segment',
      (tester) async {
    await _pumpScreen(tester, const Size(427, 952));

    // The switcher paints one sliding thumb. A thumb per segment made both
    // Workspaces and Baseline Integration read as selected.
    final switcher = find
        .ancestor(
          of: find.text('Baseline Integration'),
          matching: find.byType(Stack),
        )
        .first;
    expect(
      find.descendant(of: switcher, matching: find.byType(AnimatedPositioned)),
      findsOneWidget,
    );
  });

  testWidgets('the populated workspaces view fits a phone viewport',
      (tester) async {
    await _pumpWorkspaces(tester, const Size(427, 952));
    expect(tester.takeException(), isNull);
    // The roll-up and the cards are the whole point of the view; they must
    // survive the narrow layout rather than being clipped away.
    expect(find.text('Lusaka Water Supply Network Extension'), findsWidgets);
    expect(find.text('Lower Kafue Irrigation Scheme'), findsOneWidget);
  });

  testWidgets('the populated workspaces view fits the narrowest phone',
      (tester) async {
    await _pumpWorkspaces(tester, const Size(360, 900));
    expect(tester.takeException(), isNull);
  });

  // One test per width: each needs its own tree, because the screen holds a
  // Firestore stream subscription that cannot be listened to twice.
  //
  // The compact band kicks in below 560px, so 559 and 560 are the two
  // interesting neighbours; the rest bracket the phones and tablets we
  // actually ship to.
  for (final width in const <double>[
    320,
    360,
    390,
    427,
    480,
    520,
    559,
    560,
    640,
    768,
    1024,
    1440,
    1600,
  ]) {
    testWidgets('the hero header holds at ${width.toInt()}px', (tester) async {
      await _pumpHeader(tester, Size(width, 900));
      expect(tester.takeException(), isNull);
    });
  }

  for (final width in const <double>[320, 360, 427, 600, 900, 1200, 1600]) {
    testWidgets('the populated workspaces view holds at ${width.toInt()}px',
        (tester) async {
      await _pumpWorkspaces(tester, Size(width, 900));
      expect(tester.takeException(), isNull);
    });
  }

  for (final width in const <double>[360, 427, 600, 768, 1200]) {
    testWidgets('the full dashboard holds at ${width.toInt()}px',
        (tester) async {
      await _pumpScreen(tester, Size(width, 900));
      expect(tester.takeException(), isNull);
    });
  }
}
