// Regression tests for the Planning Risk Assessment "Add risk" dialog.
//
// The dialog used to ask for a free-text Risk ID, a free-text Risk Score, a
// free-text Category and a free-text Owner. None of those are things a user
// should be inventing: ids are assigned by the app, the score is the overall
// scale derived from Probability x Impact, and Category/Owner must come from
// the shared taxonomy and the project's registered users.
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ndu_project/models/project_data_model.dart';
import 'package:ndu_project/models/risk_log.dart';
import 'package:ndu_project/providers/project_data_provider.dart';
import 'package:ndu_project/screens/risk_assessment_screen.dart';

/// The text currently shown in the read-only Risk Score field.
///
/// Scoped to the InputDecorator that follows the "Risk Score" label so it
/// cannot accidentally match a Probability/Impact dropdown that happens to
/// show the same word.
String _riskScoreValue(WidgetTester tester) {
  final score = find.ancestor(
    of: find.text('Risk Score'),
    matching: find.byType(InputDecorator),
  );
  final text = tester
      .widgetList<Text>(find.descendant(of: score, matching: find.byType(Text)))
      .map((widget) => widget.data ?? '')
      .firstWhere((value) => value.trim().isNotEmpty && value != 'Risk Score');
  return text.trim();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  Future<void> pumpScreen(WidgetTester tester) async {
    tester.view.physicalSize = const Size(2000, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final model = ProjectDataModel().copyWith(
      projectId: 'p1',
      projectName: 'Demo Project',
      teamMembers: [
        TeamMember()..name = 'Ada Lovelace',
        TeamMember()..name = 'Grace Hopper',
      ],
    );
    final provider = ProjectDataProvider();
    provider.updateProjectData(model);

    await tester.pumpWidget(
      ProjectDataInherited(
        provider: provider,
        child: ChangeNotifierProvider<ProjectDataProvider>.value(
          value: provider,
          child: const MaterialApp(home: RiskAssessmentScreen()),
        ),
      ),
    );
    // Bounded pumping rather than pumpAndSettle: this screen keeps an
    // animation running, so settle never returns.
    for (var i = 0; i < 15; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
  }

  /// Opens the "Add risk" dialog and returns once it is on screen.
  Future<void> openAddRiskDialog(WidgetTester tester) async {
    // The Add Risk button sits in a card that can start below the fold.
    await tester.ensureVisible(find.text('Add Risk').first);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Add Risk').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Add risk'), findsWidgets,
        reason: 'the Add risk dialog should be open');
  }

  group('Add risk dialog', () {
    testWidgets('does not ask the user for a Risk ID', (tester) async {
      await pumpScreen(tester);
      await openAddRiskDialog(tester);

      expect(find.text('Add risk'), findsWidgets);
      // The id is assigned by the app, so it is not an editable field.
      expect(find.widgetWithText(TextFormField, 'Risk ID'), findsNothing);
      expect(find.text('Risk ID'), findsNothing);
    });
    testWidgets('Risk Score reads as a derived overall scale', (tester) async {
      await pumpScreen(tester);
      await openAddRiskDialog(tester);

      // Shown as a non-editable value, not a text field to type into.
      expect(find.text('Risk Score'), findsOneWidget);
      expect(find.byType(TextFormField), findsNothing);

      // Medium x Medium is Medium on the overall scale. Read from the score
      // field itself rather than any "Medium" on screen — the Probability and
      // Impact dropdowns show Medium too.
      expect(_riskScoreValue(tester), 'Medium');
    });

    testWidgets('Risk Score recomputes when Probability changes',
        (tester) async {
      await pumpScreen(tester);
      await openAddRiskDialog(tester);

      expect(_riskScoreValue(tester), 'Medium');

      // Low x Medium is Low on the overall scale, so the score must follow the
      // inputs that produce it rather than staying a stale typed value.
      await tester.tap(find.text('Probability').last);
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.text('Low').last);
      await tester.pump(const Duration(milliseconds: 500));

      expect(_riskScoreValue(tester), 'Low');

      // High x High is High.
      await tester.tap(find.text('Impact').last);
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.text('High').last);
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.text('Probability').last);
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.text('High').last);
      await tester.pump(const Duration(milliseconds: 500));

      expect(_riskScoreValue(tester), 'High');
    });

    testWidgets('Category offers the whole shared taxonomy', (tester) async {
      await pumpScreen(tester);
      await openAddRiskDialog(tester);

      await tester.tap(find.text('Category').last);
      await tester.pump(const Duration(milliseconds: 500));

      // Every category is reachable, not just the default one.
      for (final category in riskCategoryOptions) {
        expect(
          find.text(category),
          findsWidgets,
          reason: '$category should be offered in the Category dropdown',
        );
      }
    });

    testWidgets('Owner offers the project registered users', (tester) async {
      await pumpScreen(tester);
      await openAddRiskDialog(tester);

      await tester.tap(find.text('Owner').last);
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Ada Lovelace'), findsWidgets);
      expect(find.text('Grace Hopper'), findsWidgets);
    });

    testWidgets('Category and Owner are dropdowns, not free text',
        (tester) async {
      await pumpScreen(tester);
      await openAddRiskDialog(tester);

      // Description stays the only free-text field left in the dialog.
      expect(find.text('Description'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Category'), findsNothing);
      expect(find.widgetWithText(TextFormField, 'Owner'), findsNothing);
      expect(find.widgetWithText(TextFormField, 'Risk Score'), findsNothing);
    });
  });

  group('riskCategoryOptions', () {
    test('is the shared taxonomy used across risk screens', () {
      expect(riskCategoryOptions, contains('Technical'));
      expect(riskCategoryOptions, contains('Schedule'));
      expect(riskCategoryOptions, contains('External'));
      // No duplicates, so a dropdown never lists the same value twice.
      expect(riskCategoryOptions.toSet().length, riskCategoryOptions.length);
    });
  });

  group('RiskLogRow.deriveRiskLevel', () {
    test('produces the overall scale from probability x impact', () {
      expect(RiskLogRow.deriveRiskLevel('High', 'High'), 'High');
      expect(RiskLogRow.deriveRiskLevel('Low', 'Low'), 'Low');
      expect(RiskLogRow.deriveRiskLevel('Medium', 'Medium'), 'Medium');
      expect(RiskLogRow.deriveRiskLevel('Low', 'Medium'), 'Low');
      expect(RiskLogRow.deriveRiskLevel('Medium', 'High'), 'High');
    });
  });
}
