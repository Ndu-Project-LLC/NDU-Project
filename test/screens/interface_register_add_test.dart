// Regression test for the Interface Register add flow.
//
// Repro: filling in the "Add Interface Entry" modal and pressing Save must
// insert the entry into the register table below the filter bar (and bump
// the Total Interfaces metric). The save path runs
// `ProjectDataHelper.updateAndSave` — which updates the provider model
// synchronously (notifying listeners) and then persists to Firebase — so the
// row must render even before the async write lands.
// ignore_for_file: depend_on_referenced_packages
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ndu_project/models/project_data_model.dart';
import 'package:ndu_project/providers/project_data_provider.dart';
import 'package:ndu_project/screens/interface_management_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  Future<void> pumpScreen(WidgetTester tester,
      {Size size = const Size(2000, 1200)}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // Start from an empty register so the only entry is the one the modal
    // creates.
    final model = ProjectDataModel().copyWith(projectId: 'p1');
    final provider = ProjectDataProvider();
    provider.updateProjectData(model);

    await tester.pumpWidget(
      ProjectDataInherited(
        provider: provider,
        child: ChangeNotifierProvider<ProjectDataProvider>.value(
          value: provider,
          child: const MaterialApp(home: InterfaceManagementScreen()),
        ),
      ),
    );
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }

    // The screen opens on the Status Dashboard (Lusaka 27), so select the
    // register tab before exercising the add flow.
    final registerTab = find.widgetWithText(InkWell, 'Interface Register');
    expect(registerTab, findsOneWidget);
    await tester.ensureVisible(registerTab);
    await tester.pump(const Duration(milliseconds: 250));
    await tester.tap(registerTab);
    await tester.pump(const Duration(milliseconds: 350));
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

  // The screen hosts looping animations (e.g. the AI-generating spinner),
  // so pumpAndSettle would never settle — pump bounded frames instead.
  Future<void> pumpFrames(WidgetTester tester, [int frames = 5]) async {
    for (var i = 0; i < frames; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
  }

  Future<void> runAddFlow(WidgetTester tester) async {
    expect(takeAllExceptions(tester), isEmpty);

    // Empty register to begin with.
    expect(find.textContaining('No interfaces registered yet'), findsOneWidget);

    // On shorter windows the button sits below the fold — scroll to it.
    await tester.ensureVisible(find.text('Add Interface'));
    await pumpFrames(tester, 2);
    await tester.tap(find.text('Add Interface'));
    await pumpFrames(tester);
    expect(find.text('Add Interface Entry'), findsOneWidget);

    // The boundary/name field is the first field in the dialog.
    await tester.enterText(find.byType(TextField).first, 'Payment Gateway');
    await pumpFrames(tester, 2);

    await tester.tap(find.widgetWithText(ElevatedButton, 'Save'));
    // Let the dialog close and the async Firebase save run to completion.
    await pumpFrames(tester, 15);

    expect(find.text('Add Interface Entry'), findsNothing,
        reason: 'dialog should close after Save');
    final errors = takeAllExceptions(tester);
    expect(errors, isEmpty,
        reason: 'layout exceptions during save:\n$errors');

    // The new entry must render as a row in the table, with a real layout
    // size (not a collapsed/zero-size widget).
    final rowText = find.text('Payment Gateway');
    expect(rowText, findsWidgets,
        reason: 'the entry saved by the modal must appear in the table');
    final size = tester.getSize(rowText.first);
    expect(size.width, greaterThan(0), reason: 'row text laid out');
    expect(size.height, greaterThan(0), reason: 'row text laid out');

    // And the metric card must agree there is exactly one interface.
    expect(find.text('Total Interfaces'), findsOneWidget);
  }

  testWidgets(
      'saving the Add Interface modal inserts the row into the register table',
      (tester) async {
    await pumpScreen(tester);
    await runAddFlow(tester);
  });

  testWidgets(
      'saving works on a narrow window where the table scrolls horizontally',
      (tester) async {
    await pumpScreen(tester, size: const Size(1000, 900));
    await runAddFlow(tester);
  });

  testWidgets('the Add Interface modal stays a sensible size on desktop',
      (tester) async {
    // Regression: the dialog used to size itself at 85% of the window width,
    // which on a wide desktop produced a near full-screen modal.
    await pumpScreen(tester, size: const Size(2000, 1200));
    await tester.ensureVisible(find.text('Add Interface'));
    await pumpFrames(tester, 2);
    await tester.tap(find.text('Add Interface'));
    await pumpFrames(tester);

    expect(find.text('Add Interface Entry'), findsOneWidget);
    expect(takeAllExceptions(tester), isEmpty);

    // Measure the dialog *card*, not `find.byType(AlertDialog)`: the latter's
    // first render box is the dialog route's padding/align, which fills the
    // window (2000 here) no matter how narrow the card is. The card is the
    // first Material the dialog builds.
    final dialogCard = find
        .descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(Material),
        )
        .first;
    final dialogSize = tester.getSize(dialogCard);
    expect(dialogSize.width, lessThanOrEqualTo(660),
        reason: 'dialog must not scale with the window width');
    expect(dialogSize.height, lessThanOrEqualTo(820),
        reason: 'dialog content scrolls instead of filling the window');
    expect(dialogSize.width, greaterThan(280),
        reason: 'dialog keeps a readable form width');
  });
}
