// Guards the review's rename and de-cluttering of the template section: the
// block the owner pointed at must read "User Story Template", and the row of
// work item type chips that crowded the top ("they can be hidden, they should
// be hidden") must sit behind a collapsed Advanced disclosure.
//
// Services are unavailable in a widget test (no Firebase/network), which is
// fine: the page swallows the failed load and renders the empty state, which
// still carries the section heading and the disclosure.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ndu_project/models/project_data_model.dart';
import 'package:ndu_project/providers/project_data_provider.dart';
import 'package:ndu_project/screens/agile_acceptance_criteria_screen.dart';

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

  testWidgets('the template section is called "User Story Template"',
      (tester) async {
    await _pumpScreen(tester);

    expect(tester.takeException(), isNull);
    expect(find.text('User Story Template'), findsOneWidget);

    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('the work item type chips sit behind a collapsed Advanced',
      (tester) async {
    await _pumpScreen(tester);

    // The chip row is the clutter the owner called out; it must not be on
    // screen until the user asks for it.
    expect(find.text('Advanced'), findsOneWidget);
    expect(find.text('Infrastructure Task'), findsNothing);

    await tester.ensureVisible(find.text('Advanced'));
    await tester.tap(find.text('Advanced'));
    // Fixed frames, not pumpAndSettle: the AI button's spinner never settles.
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(find.text('Infrastructure Task'), findsOneWidget);

    await tester.pump(const Duration(seconds: 3));
  });
}
