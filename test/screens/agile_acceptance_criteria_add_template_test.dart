// Guards the reported flow on the Acceptance Criteria Planning page: the
// "Add" button above the Templates list must open the create-template modal,
// and only a template the user actually described may reach the list.
//
// Services are unavailable in a widget test (no Firebase/network), which is
// fine here — the page swallows the failed load and the failed AI template
// generation, then renders the empty state with the button, exactly like the
// screenshot in the report.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ndu_project/models/project_data_model.dart';
import 'package:ndu_project/providers/project_data_provider.dart';
import 'package:ndu_project/screens/agile_acceptance_criteria_screen.dart';
import 'package:ndu_project/widgets/voice_text_field.dart';

Future<void> _pumpScreen(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final provider = ProjectDataProvider();
  provider.updateProjectData(ProjectDataModel().copyWith(projectId: 'p1'));

  await tester.pumpWidget(
    ChangeNotifierProvider<ProjectDataProvider>.value(
      value: provider,
      child: ProjectDataInherited(
        provider: provider,
        child: const MaterialApp(home: AgileAcceptanceCriteriaScreen()),
      ),
    ),
  );
  // The page spins until the Firebase-less load gives up, so pump fixed frames
  // instead of settling on an animation that never ends.
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Add opens the modal instead of creating a template outright',
      (tester) async {
    await _pumpScreen(tester);

    expect(find.text('No templates for this work item type.'), findsOneWidget);

    await tester.tap(find.text('Add'));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(tester.takeException(), isNull);
    expect(find.text('New template'), findsOneWidget);
    expect(find.text('Template name'), findsOneWidget);
    expect(find.text('Starting criteria'), findsOneWidget);
    expect(find.text('Create template'), findsOneWidget);

    // Nothing was added just by opening the modal.
    await tester.tap(find.text('Cancel'));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('New template'), findsNothing);
    expect(find.text('No templates for this work item type.'), findsOneWidget);

    // Drain the provider's debounced autosave so the test ends cleanly.
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('the modal creates the described template and selects it',
      (tester) async {
    await _pumpScreen(tester);

    await tester.tap(find.text('Add'));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    // The modal's own fields; the page underneath has none at this point.
    await tester.enterText(
        find.byType(VoiceTextFormField).first, 'Checkout flow acceptance');
    await tester.pump();
    expect(find.text('Checkout flow acceptance'), findsOneWidget);

    expect(find.text('Create template'), findsOneWidget);
    await tester.tap(find.text('Create template'));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(tester.takeException(), isNull);
    // The modal is gone and the template is in the list, with its seeded
    // criteria visible in the editor.
    expect(find.text('New template'), findsNothing);
    expect(find.text('Checkout flow acceptance'), findsWidgets);
    expect(find.text('No templates for this work item type.'), findsNothing);

    await tester.pump(const Duration(seconds: 3));
  });
}
