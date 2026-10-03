// Guards the reported flow end to end: on the Release Plan page, clicking
// "Add Release Plan" must open the dialog rather than take the screen down.
//
// Services are unavailable in a widget test (no Firebase), which is fine here —
// the page swallows the failed load and renders the empty state with the
// button. The dialog's own epic checklist is covered separately in
// `release_scope_picker_test.dart`, because it only appears once the project
// actually has epics.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ndu_project/models/project_data_model.dart';
import 'package:ndu_project/providers/project_data_provider.dart';
import 'package:ndu_project/screens/agile_release_plan_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Add Release Plan opens the dialog and leaves the page alive',
      (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final provider = ProjectDataProvider();
    provider.updateProjectData(ProjectDataModel().copyWith(projectId: 'p1'));

    await tester.pumpWidget(
      ProjectDataInherited(
        provider: provider,
        child: const MaterialApp(home: AgileReleasePlanScreen()),
      ),
    );
    // The page shows a spinner until the Firebase-less load gives up, so pump
    // fixed frames instead of settling on an animation that never ends.
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(find.text('Add Release Plan'), findsOneWidget);
    await tester.tap(find.text('Add Release Plan'));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(tester.takeException(), isNull);
    expect(find.text('Release Plan Details'), findsOneWidget);
    expect(find.text('Linked Scope'), findsOneWidget);
    // The page underneath is still there rather than replaced by an error.
    expect(find.text('Plan releases, PI increments, and versioned deployments.'),
        findsOneWidget);

    // Drain the provider's debounced autosave so the test ends cleanly.
    await tester.pump(const Duration(seconds: 3));
  });
}
