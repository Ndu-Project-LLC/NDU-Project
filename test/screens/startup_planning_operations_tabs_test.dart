// Operations Plan and Hypercare Plan pages: each section sits behind its own
// tab, and only the selected section is on screen.
//
// Uses the same harness as the mobile audit so the page gets the providers and
// router it needs. The audit's `inspect` hook runs while the tree is mounted,
// so the taps happen before the page is torn down.

// ignore_for_file: depend_on_referenced_packages
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/mobile_layout_audit.dart';
import '../support/mobile_screen_registry.dart';

const String _page = 'StartUpPlanningOperationsScreen';
const String _hypercarePage = 'StartUpPlanningHypercareScreen';
const String _devOpsPage = 'StartUpPlanningDevOpsScreen';
const String _closeOutPage = 'StartUpPlanningCloseOutPlanScreen';

/// A tab label, scoped to the tab bar. The page also shows metric cards with
/// the same words (e.g. 'Observability'), so an unscoped text finder is
/// ambiguous on the DevOps page.
Finder _tab(String label) => find.descendant(
      of: find.byType(TabBar),
      matching: find.text(label),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });

  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  testWidgets('Operations Plan shows one section per tab', (tester) async {
    final build = mobileAuditScreens[_page]!;

    final report = await auditScreenAtPhoneWidth(
      tester,
      _page,
      build,
      viewport: const Size(1800, 1000),
      inspect: (tester) async {
        // First tab: service and ownership only.
        expect(find.text('Service and ownership'), findsOneWidget);
        expect(find.text('Monitoring and alerting register'), findsNothing);
        expect(find.text('Operational sign-off complete'), findsNothing);

        await tester.ensureVisible(find.text('Monitoring & alerting'));
        await tester.tap(find.text('Monitoring & alerting'));
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.text('Monitoring and alerting register'), findsOneWidget);
        expect(find.text('Service and ownership'), findsNothing);

        await tester.ensureVisible(find.text('Recovery & resilience'));
        await tester.tap(find.text('Recovery & resilience'));
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.text('Recovery and resilience register'), findsOneWidget);
        expect(find.text('Monitoring and alerting register'), findsNothing);

        await tester.ensureVisible(find.text('Sign-off'));
        await tester.tap(find.text('Sign-off'));
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.text('Operational sign-off complete'), findsOneWidget);
        expect(find.text('Recovery and resilience register'), findsNothing);
      },
    );

    expect(report.blockers, isEmpty, reason: overflowReport(report));
  });

  testWidgets('Hypercare Plan shows one section per tab', (tester) async {
    final build = mobileAuditScreens[_hypercarePage]!;

    final report = await auditScreenAtPhoneWidth(
      tester,
      _hypercarePage,
      build,
      viewport: const Size(1800, 1000),
      inspect: (tester) async {
        // First tab: the hypercare window only.
        expect(find.text('Projected hypercare window'), findsOneWidget);
        expect(find.text('Validation register'), findsNothing);
        expect(find.text('Ready to exit hypercare'), findsNothing);

        await tester.ensureVisible(find.text('Validation'));
        await tester.tap(find.text('Validation'));
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.text('Validation register'), findsOneWidget);
        expect(find.text('Projected hypercare window'), findsNothing);

        await tester.ensureVisible(find.text('Exit readiness'));
        await tester.tap(find.text('Exit readiness'));
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.text('Ready to exit hypercare'), findsOneWidget);
        expect(find.text('Validation register'), findsNothing);
      },
    );

    expect(report.blockers, isEmpty, reason: overflowReport(report));
  });

  testWidgets('Close Out Plan shows one section per tab', (tester) async {
    final build = mobileAuditScreens[_closeOutPage]!;

    final report = await auditScreenAtPhoneWidth(
      tester,
      _closeOutPage,
      build,
      viewport: const Size(1800, 1000),
      inspect: (tester) async {
        // First tab: close-out ownership only.
        expect(find.text('Close-out ownership'), findsOneWidget);
        expect(find.text('Acceptance register'), findsNothing);
        expect(find.text('Close-out approved'), findsNothing);

        await tester.ensureVisible(_tab('Acceptance'));
        await tester.tap(_tab('Acceptance'));
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.text('Acceptance register'), findsOneWidget);
        expect(find.text('Close-out ownership'), findsNothing);

        // The last tab sits past the visible edge of the tab row.
        await tester.drag(find.byType(TabBar), const Offset(-600, 0));
        await tester.pump(const Duration(milliseconds: 300));
        await tester.tap(_tab('Approval'));
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.text('Close-out approved'), findsOneWidget);
        expect(find.text('Acceptance register'), findsNothing);
      },
    );

    expect(report.blockers, isEmpty, reason: overflowReport(report));
  });

  testWidgets('DevOps Plan shows one section per tab', (tester) async {
    final build = mobileAuditScreens[_devOpsPage]!;

    final report = await auditScreenAtPhoneWidth(
      tester,
      _devOpsPage,
      build,
      viewport: const Size(1800, 1000),
      inspect: (tester) async {
        // First tab: release ownership only.
        expect(find.text('Release ownership and controls'), findsOneWidget);
        expect(find.text('Observability matrix'), findsNothing);
        expect(find.text('DevOps readiness approved'), findsNothing);

        await tester.ensureVisible(_tab('Observability'));
        await tester.tap(_tab('Observability'));
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.text('Observability matrix'), findsOneWidget);
        expect(find.text('Release ownership and controls'), findsNothing);

        // The sixth tab sits past the right edge of the scrollable tab row, so
        // scroll the row itself (horizontally) before tapping it.
        await tester.drag(find.byType(TabBar), const Offset(-600, 0));
        await tester.pump(const Duration(milliseconds: 300));
        await tester.tap(_tab('Readiness'));
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.text('DevOps readiness approved'), findsOneWidget);
        expect(find.text('Observability matrix'), findsNothing);
      },
    );

    expect(report.blockers, isEmpty, reason: overflowReport(report));
  });
}
