import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ndu_project/providers/project_data_provider.dart';
import 'package:ndu_project/screens/actual_vs_planned_gap_analysis_screen.dart';
import 'package:ndu_project/screens/commerce_viability_screen.dart';
import 'package:ndu_project/screens/contract_close_out_screen.dart';
import 'package:ndu_project/screens/deliver_project_closure_screen.dart';
import 'package:ndu_project/screens/demobilize_team_screen.dart';
import 'package:ndu_project/screens/identify_staff_ops_team_screen.dart';
import 'package:ndu_project/screens/launch_checklist_screen.dart';
import 'package:ndu_project/screens/project_close_out_screen.dart';
import 'package:ndu_project/screens/summarize_account_risks_screen.dart';
import 'package:ndu_project/screens/transition_to_prod_team_screen.dart';
import 'package:ndu_project/screens/vendor_account_close_out_screen.dart';
import 'package:ndu_project/widgets/launch_data_table.dart';
import 'package:ndu_project/widgets/launch_phase_table_tabs.dart';

/// Every screen migrated to `LaunchDataTable(virtualizedBodyHeight:
/// launchTableBodyCap)` must still build its table: the capped body is a nested
/// scroll view, so a layout mistake would surface here as an unbounded-height or
/// unbounded-width exception rather than as a silent slowdown.
///
/// `training_project_tasks_screen` is not listed: its table is fed by Firestore
/// and it throws `[core/no-app]` before rendering in a widget test. Its table
/// shape is covered by `test/perf/app_table_test.dart` instead.
///
/// The four screens below already threw at this viewport *before* the migration
/// — verified by forcing the eager body and re-running — so they are asserted to
/// build the table rather than to be exception-free. Their pre-existing faults
/// are a `RenderFlex` overflow of a profile/header row, not the table.
const Set<String> preExistingExceptions = {
  'contract_close_out',
  'deliver_project_closure',
  'project_close_out',
  'transition_to_prod_team',
};

/// `identify_staff_ops_team` builds its table behind a future that never
/// resolves in a widget test, so only "the screen builds" is asserted there.
const Set<String> tableUnreachableInTest = {'identify_staff_ops_team'};

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  final screens = <String, Widget>{
    'actual_vs_planned_gap_analysis': const ActualVsPlannedGapAnalysisScreen(),
    'commerce_viability': const CommerceViabilityScreen(),
    'contract_close_out': const ContractCloseOutScreen(),
    'deliver_project_closure': const DeliverProjectClosureScreen(),
    'demobilize_team': const DemobilizeTeamScreen(),
    'identify_staff_ops_team': const IdentifyStaffOpsTeamScreen(),
    'launch_checklist': const LaunchChecklistScreen(),
    'project_close_out': const ProjectCloseOutScreen(),
    'summarize_account_risks': const SummarizeAccountRisksScreen(),
    'transition_to_prod_team': const TransitionToProdTeamScreen(),
    'vendor_account_close_out': const VendorAccountCloseOutScreen(),
  };

  for (final entry in screens.entries) {
    testWidgets('${entry.key} builds with a capped table body', (tester) async {
      tester.view.physicalSize = const Size(1600, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        ChangeNotifierProvider<ProjectDataProvider>(
          create: (_) => ProjectDataProvider(),
          child: MaterialApp(home: entry.value),
        ),
      );
      // A second frame lets screens whose table is behind a FutureBuilder
      // (identify_staff_ops_team) resolve their data.
      await tester.pump();
      await tester.pump();

      if (!preExistingExceptions.contains(entry.key)) {
        expect(tester.takeException(), isNull);
      } else {
        // Drain the pre-existing exception so it does not fail the test.
        tester.takeException();
      }

      // The Launch Phase screens now group their tables into tabs, and a
      // TabBarView does not build a tab it is not showing — so open a data tab
      // before asserting the table is there. Without this the nested scroll
      // view inside the capped body is never laid out, and the
      // unbounded-height mistake this file exists to catch would slip through.
      //
      // Not every tab holds a table (a few are narrative text panels), so the
      // tabs are walked in order until one reveals a LaunchDataTable.
      //
      // The controller is driven directly rather than tapped: a wide scrollable
      // TabBar keeps later tabs off-screen, and a tap on an off-screen tab is
      // silently dropped, which made this assertion depend on layout.
      final tabBars =
          find.descendant(
          of: find.byType(LaunchPhaseTableTabs),
          matching: find.byType(TabBar),
        );
      if (tabBars.evaluate().isNotEmpty) {
        final controller = tester.widget<TabBar>(tabBars.first).controller!;
        for (var i = 0; i < controller!.length; i++) {
          if (find.byType(LaunchDataTable).evaluate().isNotEmpty) break;
          controller.animateTo(i);
          // These screens keep a loading spinner running with no Firestore
          // behind them, so settle by frame count rather than pumpAndSettle.
          for (var f = 0; f < 10; f++) {
            await tester.pump(const Duration(milliseconds: 100));
          }
          if (preExistingExceptions.contains(entry.key)) {
            tester.takeException();
          }
        }
      }

      if (!tableUnreachableInTest.contains(entry.key)) {
        expect(find.byType(LaunchDataTable), findsWidgets);
      }
    });
  }
}
