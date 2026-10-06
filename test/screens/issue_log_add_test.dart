// Regression test for the Issue Log add flow.
//
// Repro: the Issue Log card only rendered a search box, so the empty state
// ("Issue log is empty") was a dead end — the _handleNewIssue dialog existed
// but nothing opened it. The "Add issue" button must open the New Issue
// dialog and the saved entry must render as a row in the log table.
// ignore_for_file: depend_on_referenced_packages
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ndu_project/models/project_data_model.dart';
import 'package:ndu_project/providers/project_data_provider.dart';
import 'package:ndu_project/screens/issue_management_screen.dart';
import 'package:ndu_project/services/execution_service.dart';

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

    // Start from an empty log so the only entry is the one the dialog creates.
    final model = ProjectDataModel().copyWith(projectId: 'p1');
    final provider = ProjectDataProvider();
    provider.updateProjectData(model);

    await tester.pumpWidget(
      ProjectDataInherited(
        provider: provider,
        child: ChangeNotifierProvider<ProjectDataProvider>.value(
          value: provider,
          child: const MaterialApp(home: IssueManagementScreen()),
        ),
      ),
    );
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
  }

  // The screen hosts looping animations (e.g. the chat bubble pulse), so
  // pumpAndSettle would never settle — pump bounded frames instead.
  Future<void> pumpFrames(WidgetTester tester, [int frames = 5]) async {
    for (var i = 0; i < frames; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
  }

  testWidgets('the Add issue button opens the dialog and saves a row',
      (tester) async {
    await pumpScreen(tester);
    expect(tester.takeException(), isNull);

    // The log starts empty.
    expect(find.text('Issue log is empty'), findsOneWidget);

    // The header now exposes an add action next to the search box.
    final addButton = find.text('Add issue');
    expect(addButton, findsOneWidget);
    await tester.ensureVisible(addButton);
    await pumpFrames(tester, 2);
    await tester.tap(addButton);
    await pumpFrames(tester);
    expect(find.text('New Issue'), findsOneWidget);

    // Title is the first field in the dialog and the only required one.
    // Scope to the dialog: the screen underneath has its own text fields
    // (notes, search), and finder traversal reaches those first.
    await tester.enterText(
      find
          .descendant(
            of: find.byType(AlertDialog),
            matching: find.byType(TextField),
          )
          .first,
      'Permit delay',
    );
    await pumpFrames(tester, 2);

    await tester.tap(find.widgetWithText(ElevatedButton, 'Save'));
    // Let the dialog close and the async Firebase save run to completion.
    await pumpFrames(tester, 15);

    expect(find.text('New Issue'), findsNothing,
        reason: 'dialog should close after Save');
    expect(tester.takeException(), isNull);

    // The saved issue must render as a row in the log table.
    final rowText = find.text('Permit delay');
    expect(rowText, findsWidgets,
        reason: 'the issue saved by the dialog must appear in the log table');
    final size = tester.getSize(rowText.first);
    expect(size.width, greaterThan(0), reason: 'row text laid out');
    expect(size.height, greaterThan(0), reason: 'row text laid out');
  });

  testWidgets('issues created in the execution phase render in this log',
      (tester) async {
    // The planning log and the execution-phase issue store used to be two
    // disconnected stores: issues created in execution never reached this
    // screen. They must read as ONE log.
    debugExecutionIssuesStream = (projectId) => Stream.value(
          <ExecutionIssueModel>[
            ExecutionIssueModel(
              id: 'x1',
              projectId: projectId,
              issueTopic: 'Tower crane breakdown',
              description: 'Crane hydraulic line failed on site',
              discipline: 'Engineering',
              raisedBy: 'Site Engineer',
              scheduleImpact: '2 weeks',
              costImpact: r'$5,000',
              approved: false,
              comments: 'Severity: High, Status: Open',
              createdById: 'u1',
              createdByEmail: 'u1@example.com',
              createdByName: 'U1',
              createdAt: DateTime(2026, 1, 2),
              updatedAt: DateTime(2026, 1, 2),
            ),
          ],
        );
    addTearDown(() => debugExecutionIssuesStream = null);

    await pumpScreen(tester);
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    expect(tester.takeException(), isNull);

    // The execution-created issue is on screen...
    expect(find.text('Tower crane breakdown'), findsOneWidget);
    // ...under its execution-linked id...
    expect(find.text('exec_x1'), findsOneWidget);
    // ...and the empty state is gone.
    expect(find.text('Issue log is empty'), findsNothing);
  });

  testWidgets('the Add issue button is reachable on a narrow window',
      (tester) async {
    await pumpScreen(tester, size: const Size(1000, 900));
    expect(tester.takeException(), isNull);

    final addButton = find.text('Add issue');
    expect(addButton, findsOneWidget);
    await tester.ensureVisible(addButton);
    await pumpFrames(tester, 2);
    await tester.tap(addButton);
    await pumpFrames(tester);

    expect(find.text('New Issue'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
