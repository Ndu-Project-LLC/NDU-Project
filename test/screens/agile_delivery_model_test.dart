// Regression tests for the Agile Delivery Model screen changes:
//
//  1. "Waterfall" is no longer an option in the Delivery Framework selector
//     (legacy projects that already saved Waterfall keep rendering safely
//     via the isWaterfall guards, but no one can pick it anymore).
//  2. The "Metrics & Reporting" TAB was removed from this screen and moved
//     to its own sidebar entry directly below "Agile Delivery Model" —
//     opening it renders `AgileDeliveryModelScreen(metricsOnly: true)`.
// ignore_for_file: depend_on_referenced_packages
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ndu_project/models/project_data_model.dart';
import 'package:ndu_project/providers/project_data_provider.dart';
import 'package:ndu_project/screens/agile_delivery_model_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  Future<void> pumpScreen(WidgetTester tester, Widget screen,
      {Size size = const Size(2000, 1200)}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final provider = ProjectDataProvider();
    provider.updateProjectData(ProjectDataModel().copyWith(projectId: 'p1'));

    await tester.pumpWidget(
      ProjectDataInherited(
        provider: provider,
        child: ChangeNotifierProvider<ProjectDataProvider>.value(
          value: provider,
          child: MaterialApp(home: screen),
        ),
      ),
    );
    // Bounded pumps: the screen may kick off auto-AI generation, so
    // pumpAndSettle could spin.
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    // The screen loads its data from Firestore, which has no platform
    // handler under `flutter test` — the pigeon channel error only lands
    // as a real async event, so let the real event loop run (otherwise
    // `_isLoading` never clears and the content never renders).
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 1500)));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
  }

  /// Drains every recorded exception so one failure never hides the others.
  List<Object> takeAllExceptions(WidgetTester tester) {
    final errors = <Object>[];
    Object? error;
    while ((error = tester.takeException()) != null) {
      errors.add(error!);
    }
    return errors;
  }

  testWidgets('tabbed screen drops the Metrics & Reporting tab and Waterfall',
      (tester) async {
    await pumpScreen(tester, const AgileDeliveryModelScreen());
    expect(takeAllExceptions(tester), isEmpty);

    // Two tabs remain; the Metrics & Reporting TAB is gone.
    expect(find.byType(TabBar), findsOneWidget);
    expect(find.widgetWithText(Tab, 'Delivery Model'), findsOneWidget);
    expect(find.widgetWithText(Tab, 'Release Strategy'), findsOneWidget);
    expect(find.widgetWithText(Tab, 'Metrics & Reporting'), findsNothing);
    // Its content is no longer rendered anywhere on this screen.
    expect(
        find.text(
            'Define how delivery progress, throughput, predictability'),
        findsNothing);

    // Waterfall is gone from the Delivery Framework selector; the Agile
    // frameworks remain.
    expect(find.text('Waterfall'), findsNothing);
    expect(find.text('Scrum'), findsOneWidget);
    expect(find.text('Kanban'), findsOneWidget);
    expect(find.text('ScrumBan'), findsOneWidget);
  });

  testWidgets('metricsOnly view renders the Metrics & Reporting section',
      (tester) async {
    await pumpScreen(
        tester, const AgileDeliveryModelScreen(metricsOnly: true));
    expect(takeAllExceptions(tester), isEmpty);

    // No tab bar at all — this is a standalone section page.
    expect(find.byType(TabBar), findsNothing);
    expect(find.text('Release Strategy'), findsNothing);

    // The metrics content renders (title + intro banner + field).
    expect(find.text('Metrics & Reporting'), findsWidgets);
    expect(
        find.textContaining('Define how delivery progress'), findsOneWidget);
  });

  testWidgets(
      'sidebar lists Metrics & Reporting directly below Agile Delivery Model',
      (tester) async {
    // Tall viewport so the entire sidebar menu fits without lazy-ListView
    // gaps — the Agile Delivery group sits ~2700px down a 977px menu.
    await pumpScreen(tester, const AgileDeliveryModelScreen(metricsOnly: true),
        size: const Size(2000, 4400));
    expect(takeAllExceptions(tester), isEmpty);

    // The active label expands the Agile Delivery group; with the whole
    // menu on one screen all of its items are built.
    expect(find.text('Agile Delivery'), findsWidgets);
    expect(find.text('Agile Delivery Model'), findsWidgets);
    expect(find.text('Metrics & Reporting'), findsWidgets);
    expect(find.text('Backlog Governance'), findsWidgets);

    // The first occurrence of each label is in the sidebar (the sidebar
    // builds before the page content).
    final modelY =
        tester.getTopLeft(find.text('Agile Delivery Model').first).dy;
    final metricsY =
        tester.getTopLeft(find.text('Metrics & Reporting').first).dy;
    final backlogY =
        tester.getTopLeft(find.text('Backlog Governance').first).dy;

    expect(metricsY, greaterThan(modelY),
        reason: 'Metrics & Reporting must sit below Agile Delivery Model');
    expect(metricsY, lessThan(backlogY),
        reason: 'Metrics & Reporting must sit above the items that follow '
            '(Backlog Governance)');
  });
}
