import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ndu_project/providers/project_data_provider.dart';
import 'package:ndu_project/screens/punchlist_actions_screen.dart';

/// Punchlist Overview shows its three sections as tabs: completion health,
/// item distribution and action velocity. Only the selected section is built.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('punchlist sections switch between tabs', (tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final provider = ProjectDataProvider();
    addTearDown(provider.reset);

    await tester.pumpWidget(
      ChangeNotifierProvider<ProjectDataProvider>.value(
        value: provider,
        child: const MaterialApp(home: PunchlistActionsScreen()),
      ),
    );
    await tester.pump();
    await tester.pump();

    // The first tab is selected: completion health is visible, the table
    // sections are not built yet.
    expect(find.text('Completion health'), findsOneWidget);
    expect(find.text('Punchlist completion health'), findsOneWidget);
    expect(find.text('Add Category'), findsNothing);
    expect(find.text('Add Workstream'), findsNothing);

    await tester.tap(find.text('Item distribution'));
    // The page keeps a loading indicator running with no Firestore behind it,
    // so settle by frame count instead of pumpAndSettle.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Add Category'), findsOneWidget);
    expect(find.text('Punchlist completion health'), findsNothing);

    await tester.tap(find.text('Action velocity'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Add Workstream'), findsOneWidget);
    expect(find.text('Add Category'), findsNothing);

    // Drain layout noise from the page header and the debounced autosave so
    // the binding does not fail the test on pending timers.
    for (var i = 0; i < 100; i++) {
      if (tester.takeException() == null) break;
    }
    await tester.pump(const Duration(seconds: 3));
  });
}
