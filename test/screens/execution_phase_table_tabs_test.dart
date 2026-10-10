// Every Execution Phase surface that used to stack its registers in one long
// column now groups them behind the same tab navigator the Launch Phase screens
// use. This pins the tab set for each, so a screen silently losing a register —
// or the navigator itself — fails here instead of going unnoticed.

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
import 'package:ndu_project/screens/detailed_design_screen.dart';
import 'package:ndu_project/screens/gap_analysis_scope_reconcillation_screen.dart';
import 'package:ndu_project/screens/identify_staff_ops_team_screen.dart';
import 'package:ndu_project/screens/launch_checklist_screen.dart';
import 'package:ndu_project/screens/risk_tracking_screen.dart';
import 'package:ndu_project/screens/staff_team_screen.dart';
import 'package:ndu_project/screens/technical_debt_management_screen.dart';
import 'package:ndu_project/screens/update_ops_maintenance_plans_screen.dart';
import 'package:ndu_project/screens/vendor_tracking_screen.dart';
import 'package:ndu_project/widgets/launch_phase_table_tabs.dart';
import 'package:ndu_project/wbs/providers/wbs_provider.dart';

/// A tabbed screen plus the tabs its rail must present, in order.
class _TabbedScreen {
  const _TabbedScreen(this.name, this.screen, this.tabs);

  final String name;
  final Widget screen;
  final List<String> tabs;
}

const List<_TabbedScreen> _screens = [
  _TabbedScreen('Vendor Tracking', VendorTrackingScreen(), [
    'Vendor scorecard',
    'Performance pulse',
    'Risk signals',
    'Action plan',
  ]),
  _TabbedScreen('Risk Tracking', RiskTrackingScreen(), [
    'Risk register',
    'Mitigation coverage',
    'Risk signals',
    'Escalation readiness',
  ]),
  _TabbedScreen('Technical Debt Management', TechnicalDebtManagementScreen(), [
    'Debt register',
    'Remediation runway',
    'Root cause signals',
    'Ownership coverage',
  ]),
  _TabbedScreen('Identify and Staff Ops Team', IdentifyStaffOpsTeamScreen(), [
    'Ops roster',
    'Readiness checklist',
  ]),
  _TabbedScreen('Launch Checklist', LaunchChecklistScreen(), [
    'Launch Checklist',
    'Approvals & Sign-offs',
    'Launch Milestones',
    'Launch Timeline',
  ]),
  _TabbedScreen('Detailed Design', DetailedDesignScreen(), [
    'Architecture & System Design',
    'Design Specification Register',
    'Security & Compliance Controls',
    'Non-Functional Requirements',
    'Design Decision Log',
    'Artifact Readiness',
  ]),
  _TabbedScreen(
      'Update Ops and Maintenance Plans', UpdateOpsMaintenancePlansScreen(), [
    'Ops Plan Register',
    'Readiness Coverage',
    'Ops Signals',
    'Maintenance Windows',
  ]),
  _TabbedScreen('Staff Team', StaffTeamScreen(), [
    'Staffing grid',
    'Team mobilization',
    'Onboarding actions',
    'Coverage risks',
  ]),
  _TabbedScreen(
      'Gap Analysis and Scope Reconciliation',
      GapAnalysisScopeReconcillationScreen(), [
    'Gap Register',
    'Root Cause Analysis',
    'Reconciliation Planning',
    'Impact Assessment',
    'Reconciliation Workflow',
    'Lessons Learned',
  ]),
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });

  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  for (final screen in _screens) {
    testWidgets('${screen.name} groups its registers behind the tab navigator',
        (tester) async {
      tester.view.physicalSize = const Size(1600, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      // No project id is set, so the screens render their empty states without
      // reaching Firestore and the tab host can be exercised in a widget test.
      final provider = ProjectDataProvider();
      provider
          .updateProjectData(ProjectDataModel(projectName: 'Agility Platform'));
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
            child: MaterialApp(home: screen.screen),
          ),
        ),
      );

      // These screens keep loading spinners running with no Firestore behind
      // them, so pumpAndSettle would never return; settle by frame count.
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }

      // Let the provider's two-second auto-save debounce fire rather than leave
      // a pending timer behind at the end of the test; with no project id the
      // save itself is a no-op.
      await provider.flushAutoSave();
      await tester.pump();

      expect(
        find.byType(LaunchPhaseTableTabs),
        findsOneWidget,
        reason: '${screen.name} has no table navigator',
      );

      for (final label in screen.tabs) {
        expect(
          find.byKey(ValueKey<String>('launch-phase-tab-$label')),
          findsOneWidget,
          reason: '${screen.name} is missing the "$label" tab',
        );
      }
    });
  }
}
