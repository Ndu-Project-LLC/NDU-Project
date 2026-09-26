// Cost of Quality tab — the capture side of the quality → Cost Estimate link.
//
// Lusaka 25 (copy): "quality is not done … the quality costs must reach the cost
// estimate" and "these are the costs that we are incurring because we are not
// doing quality right."
//
// Before this tab existed the Cost of Quality model had nowhere to be entered, so
// the Cost Estimate pull had nothing to move. These tests drive the real Quality
// Management screen: open the tab, add an entry through the real dialog, and
// check what landed on the project — including the two things that decide whether
// the entry ever reaches the estimate: it must be priced, and its category must
// be remembered.
//
// AI is switched off in the seeded project so no generation is attempted; the
// capture under test is plain data entry and involves no AI at all.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ndu_project/models/cost_of_quality.dart';
import 'package:ndu_project/models/project_data_model.dart';
import 'package:ndu_project/providers/project_data_provider.dart';
import 'package:ndu_project/screens/quality_management_screen.dart';

/// A TextField found by the label it carries in the entry dialog.
Finder _labelledField(String label) => find.byWidgetPredicate(
      (w) => w is TextField && w.decoration?.labelText == label,
      description: 'TextField labelled "$label"',
    );

Finder _hintedField(String hint) => find.byWidgetPredicate(
      (w) => w is TextField && w.decoration?.hintText == hint,
      description: 'TextField hinted "$hint"',
    );

/// Pump the real Quality Management screen with an empty, AI-off project.
Future<ProjectDataProvider> _pumpQualityScreen(WidgetTester tester) async {
  // All seven tabs plus the footer need room, so use a desktop surface.
  tester.view.physicalSize = const Size(2200, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final model = ProjectDataModel().copyWith(projectId: 'p1', aiEnabled: false);
  final provider = ProjectDataProvider();
  provider.updateProjectData(model);

  await tester.pumpWidget(
    ProjectDataInherited(
      provider: provider,
      child: ChangeNotifierProvider<ProjectDataProvider>.value(
        value: provider,
        child: const MaterialApp(home: QualityManagementScreen()),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  return provider;
}

/// Open the Cost of Quality tab from the tab strip.
///
/// The strip scrolls horizontally, and Cost of Quality is the last of the seven
/// tabs, so it starts off-screen — it has to be brought into view before it can
/// be tapped.
Future<void> _openCostOfQualityTab(WidgetTester tester) async {
  final tab = find.text('Cost of Quality');
  expect(tab, findsOneWidget,
      reason: 'the Cost of Quality tab must be on the strip');
  await tester.ensureVisible(tab);
  await tester.pump();
  await tester.tap(tab);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

/// Add one entry to [categoryLabel] through the real dialog.
Future<void> _addEntry(
  WidgetTester tester, {
  required String categoryLabel,
  required String description,
  required String estimated,
  String actual = '',
}) async {
  // Each category card carries its own "Add entry", so the button has to be the
  // one *inside* the card for the category asked for — tapping the first button
  // on the page always opens Prevention.
  final card = find
      .ancestor(
        of: find.text(categoryLabel),
        matching: find.byType(Container),
      )
      .first;
  final addButton = find.descendant(of: card, matching: find.text('Add entry'));
  expect(addButton, findsOneWidget,
      reason: '$categoryLabel card should offer one "Add entry"');
  await tester.tap(addButton);
  // Fixed pumps rather than pumpAndSettle: this screen runs continuous
  // animations (the autosave indicator), so settling never completes.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));

  expect(find.text('Add $categoryLabel Cost'), findsOneWidget,
      reason: 'the dialog must say which category is being priced');

  await tester.enterText(
    _hintedField('e.g. Code reviews on every merge'),
    description,
  );
  await tester.enterText(_labelledField('Estimated cost'), estimated);
  if (actual.isNotEmpty) {
    await tester.enterText(_labelledField('Actual cost (once known)'), actual);
  }
  await tester.pump();

  // The dialog says plainly whether this entry will reach the estimate.
  expect(find.textContaining('reach the Cost Estimate'), findsWidgets);

  await tester.tap(find.widgetWithText(FilledButton, 'Add entry'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('the Cost of Quality tab starts empty and says so',
      (tester) async {
    await _pumpQualityScreen(tester);
    await _openCostOfQualityTab(tester);

    expect(find.text('Cost of Quality'), findsWidgets);
    expect(
      find.textContaining('Prevention'),
      findsWidgets,
      reason: 'the four categories are named, not lumped into one total',
    );
    expect(find.textContaining('External Failure'), findsWidgets);
    // Every category states it has nothing yet.
    expect(find.textContaining('costs recorded yet'), findsNWidgets(4));
  });

  testWidgets('pricing an entry stores it against its category', (tester) async {
    final provider = await _pumpQualityScreen(tester);
    await _openCostOfQualityTab(tester);

    await _addEntry(
      tester,
      categoryLabel: 'Prevention',
      description: 'Code reviews on every merge',
      estimated: '4500',
    );

    final coq = provider.projectData.costOfQualityData;
    expect(coq, isNotNull, reason: 'the entry must reach the project model');
    expect(coq!.preventionCosts, hasLength(1));

    final entry = coq.preventionCosts.single;
    expect(entry.description, 'Code reviews on every merge');
    expect(entry.estimatedCost, 4500);
    expect(entry.actualCost, 0);
    // Untouched categories stay empty rather than being defaulted.
    expect(coq.appraisalCosts, isEmpty);
    expect(coq.internalFailureCosts, isEmpty);
    expect(coq.externalFailureCosts, isEmpty);
  });

  testWidgets('an entry with no amount is captured but flagged as unpriced',
      (tester) async {
    final provider = await _pumpQualityScreen(tester);
    await _openCostOfQualityTab(tester);

    await _addEntry(
      tester,
      categoryLabel: 'Appraisal',
      description: 'Third-party test pass',
      estimated: '',
    );

    final coq = provider.projectData.costOfQualityData;
    expect(coq?.appraisalCosts, hasLength(1));
    expect(coq!.appraisalCosts.single.estimatedCost, 0);

    // The tab tells the user this row cannot reach the estimate yet, rather than
    // silently carrying a zero.
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.textContaining('will not reach the Cost Estimate'), findsWidgets);
  });

  testWidgets('an actual amount is recorded alongside the estimate',
      (tester) async {
    final provider = await _pumpQualityScreen(tester);
    await _openCostOfQualityTab(tester);

    await _addEntry(
      tester,
      categoryLabel: 'Internal Failure',
      description: 'Rework on the payments module',
      estimated: '2000',
      actual: '3750',
    );

    final entry =
        provider.projectData.costOfQualityData!.internalFailureCosts.single;
    expect(entry.estimatedCost, 2000);
    expect(entry.actualCost, 3750);
  });

  testWidgets('the category totals and the priced count update on capture',
      (tester) async {
    await _pumpQualityScreen(tester);
    await _openCostOfQualityTab(tester);

    await _addEntry(
      tester,
      categoryLabel: 'Prevention',
      description: 'Supplier quality reviews',
      estimated: '12000',
    );
    await tester.pump(const Duration(milliseconds: 400));

    // One entry, one priced, and the estimated total reflects it.
    expect(find.text('Entries'), findsOneWidget);
    expect(find.text('Priced'), findsOneWidget);
    expect(find.text('1'), findsWidgets);
    expect(find.text('12.0K'), findsWidgets);
  });

  testWidgets('the tab the user opens is the tab the section Next gate records',
      (tester) async {
    // The gate's tab ids and what the screen records have to be the same
    // string — they were not, once, and Quality's Next could never unlock.
    final provider = await _pumpQualityScreen(tester);
    await _openCostOfQualityTab(tester);

    final visited =
        provider.projectData.qualityManagementData?.visitedSections ?? const [];
    expect(visited, contains('costOfQuality'));
    expect(visited, contains('plan'),
        reason: 'the tab the user lands on counts as seen');
  });
}
