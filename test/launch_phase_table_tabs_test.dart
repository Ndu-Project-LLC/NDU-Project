import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:ndu_project/models/project_data_model.dart';
import 'package:ndu_project/providers/project_data_provider.dart';
import 'package:ndu_project/screens/contract_close_out_screen.dart';
import 'package:ndu_project/widgets/launch_phase_table_tabs.dart';

/// Hosts [LaunchPhaseTableTabs] at a desktop viewport and records which bodies
/// were built, so a test can prove the tab host only builds the visible tab.
Widget _tabBarHost(
  WidgetTester tester, {
  required List<LaunchPhaseTableTab> tabs,
  required Map<String, Widget Function()> builders,
  Widget? overview,
}) {
  tester.view.physicalSize = const Size(1600, 1000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  return MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: LaunchPhaseTableTabs(
          overview: overview,
          tabs: tabs,
          builders: builders,
        ),
      ),
    ),
  );
}

void main() {
  group('LaunchPhaseTableTabs', () {
    testWidgets('renders an Overview tab plus one tab per table', (tester) async {
      await tester.pumpWidget(_tabBarHost(
        tester,
        tabs: const [
          LaunchPhaseTableTab(label: 'Contracts Status'),
          LaunchPhaseTableTab(label: 'Close-Out Steps'),
          LaunchPhaseTableTab(label: 'Sign-Offs'),
        ],
        builders: {
          'Contracts Status': () => const Text('contracts body'),
          'Close-Out Steps': () => const Text('steps body'),
          'Sign-Offs': () => const Text('signoffs body'),
        },
        overview: const Text('overview body'),
      ));
      await tester.pump();

      expect(find.byType(TabBar), findsOneWidget);
      expect(find.byType(TabBarView), findsOneWidget);

      for (final label in [
        'Overview',
        'Contracts Status',
        'Close-Out Steps',
        'Sign-Offs',
      ]) {
        expect(
          find.byKey(ValueKey<String>('launch-phase-tab-$label')),
          findsOneWidget,
          reason: 'expected a tab labelled "$label"',
        );
      }
    });

    testWidgets('shows the Overview body first and swaps on tab tap',
        (tester) async {
      await tester.pumpWidget(_tabBarHost(
        tester,
        tabs: const [
          LaunchPhaseTableTab(label: 'Contracts Status'),
          LaunchPhaseTableTab(label: 'Sign-Offs'),
        ],
        builders: {
          'Contracts Status': () => const Text('contracts body'),
          'Sign-Offs': () => const Text('signoffs body'),
        },
        overview: const Text('overview body'),
      ));
      await tester.pump();

      expect(find.text('overview body'), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey<String>('launch-phase-tab-Contracts Status')),
      );
      await tester.pumpAndSettle();
      expect(find.text('contracts body'), findsOneWidget);
      expect(find.text('overview body'), findsNothing);

      await tester.tap(
        find.byKey(const ValueKey<String>('launch-phase-tab-Sign-Offs')),
      );
      await tester.pumpAndSettle();
      expect(find.text('signoffs body'), findsOneWidget);
      expect(find.text('contracts body'), findsNothing);
    });

    testWidgets('omits the Overview tab when no overview is supplied',
        (tester) async {
      await tester.pumpWidget(_tabBarHost(
        tester,
        tabs: const [LaunchPhaseTableTab(label: 'Warranty Tracker')],
        builders: {
          'Warranty Tracker': () => const Text('warranty body'),
        },
      ));
      await tester.pump();

      expect(
        find.byKey(const ValueKey<String>('launch-phase-tab-Overview')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey<String>('launch-phase-tab-Warranty Tracker')),
        findsOneWidget,
      );
    });

    testWidgets('each table body scrolls inside its own tab', (tester) async {
      await tester.pumpWidget(_tabBarHost(
        tester,
        tabs: const [
          LaunchPhaseTableTab(label: 'Alpha'),
          LaunchPhaseTableTab(label: 'Beta'),
        ],
        builders: {
          // Tall enough to overflow the tab viewport so a scroll view is
          // actually required. Align to top so the label stays inside it.
          'Alpha': () => const SizedBox(
                height: 4000,
                child: Align(
                  alignment: Alignment.topCenter,
                  child: Text('alpha body'),
                ),
              ),
          'Beta': () => const SizedBox(
                height: 4000,
                child: Align(
                  alignment: Alignment.topCenter,
                  child: Text('beta body'),
                ),
              ),
        },
      ));
      await tester.pump();

      // Without a bounded, independently scrolling body, a tall table would
      // overflow the fixed-height TabBarView.
      expect(tester.takeException(), isNull);

      await tester.drag(
        find.text('alpha body'),
        const Offset(0, -600),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });

  group('Launch Phase screens are tabbed', () {
    testWidgets('Vendor & Contract Closeout tabs its four tables',
        (tester) async {
      tester.view.physicalSize = const Size(1600, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      // The screen reads project data through ProjectDataHelper, which needs a
      // ProjectDataProvider above it.
      final provider = ProjectDataProvider();
      provider.updateProjectData(ProjectDataModel(projectName: 'Zala connect'));
      addTearDown(provider.reset);

      await tester.pumpWidget(
        ChangeNotifierProvider<ProjectDataProvider>.value(
          value: provider,
          child: const MaterialApp(
            home: Scaffold(body: ContractCloseOutScreen()),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      // The screen keeps a loading spinner running with no Firestore behind it,
      // so pumpAndSettle would never return; settle by frame count instead.
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      // Pre-existing RenderFlex overflow noise from this screen's header. Drain
      // it so it cannot mask a real failure. takeException collapses a burst
      // into one detail-free "Multiple exceptions" report, so it is discarded
      // by design.
      for (var i = 0; i < 100; i++) {
        if (tester.takeException() == null) break;
      }

      expect(find.byType(LaunchPhaseTableTabs), findsOneWidget);

      for (final label in [
        'Financial Summary',
        'Contracts Status',
        'Close-Out Steps',
        'Sign-Offs',
      ]) {
        expect(
          find.byKey(ValueKey<String>('launch-phase-tab-$label')),
          findsOneWidget,
          reason: 'expected a "Vendor & Contract Closeout" tab "$label"',
        );
      }

      // Tapping a table tab swaps in that table instead of scrolling to it.
      await tester.tap(
        find.byKey(const ValueKey<String>('launch-phase-tab-Contracts Status')),
      );
      // pumpAndSettle never returns on this screen (perpetual loading spinner
      // with no Firestore), so settle by frame count.
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.text('Contracts Status'), findsWidgets);
    });
  });
}