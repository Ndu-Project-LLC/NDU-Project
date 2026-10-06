// The AI-Powered Context Insights card on the Project Controls
// dashboard must collapse overall — collapsed by default — so the
// dashboard leads with the health and EVM cards. The header stays
// visible; a tap on it reveals (and a second tap hides again) the
// milestone, cost and recommendation sections behind it.
//
// Visibility is asserted through the semantics tree, not
// `find.text`: the card's [AnimatedCrossFade] keeps the hidden
// child mounted (faded out, wrapped in `ExcludeSemantics`), so the
// section text is in the widget tree even while collapsed — but not
// visible to users or assistive tech.
//
// NOTE: assertions use the *live* semantics tree
// (`find.semantics.byPredicate`), not `find.bySemanticsLabel`. The
// latter reads `renderObject.debugSemantics` — the render object's
// cached semantics node, which keeps its label even after
// `ExcludeSemantics` detached it from the live tree, so it reports
// hidden content as still present.

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart' show SemanticsNode;
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ndu_project/cost_estimate/providers/cost_estimate_provider.dart';
import 'package:ndu_project/models/project_data_model.dart';
import 'package:ndu_project/providers/project_data_provider.dart';
import 'package:ndu_project/project_controls/providers/change_management_provider.dart';
import 'package:ndu_project/project_controls/providers/project_controls_provider.dart';
import 'package:ndu_project/project_controls/screens/project_controls_screen.dart';
import 'package:ndu_project/schedule/providers/schedule_provider.dart';
import 'package:ndu_project/wbs/providers/wbs_provider.dart';

// Reuse the module pump fixtures: provider setup plus the bounded
// pumps these module screens need (they host perpetual animations
// that `pumpAndSettle` would wait on forever).
import 'module_section_header_scroll_test.dart' as fixtures;

/// Finds semantics nodes carrying exactly [label] in the live
/// semantics tree (see the file header for why this is needed
/// instead of [Finder.bySemanticsLabel]).
SemanticsFinder _liveSemanticsLabel(String label) {
  return find.semantics.byPredicate(
    (SemanticsNode node) => node.label == label,
  );
}

/// Pumps [ProjectControlsScreen] with a bound project, so the
/// dashboard derives a non-empty AI context scan and renders the
/// AI-Powered Context Insights card.
///
/// The [ProjectDataProvider] is created (not `.value`) so
/// [MultiProvider] disposes it with the tree — cancelling the
/// auto-save debounce that `updateProjectData` schedules.
Future<void> pumpProjectControls(
  WidgetTester tester, {
  required ProjectDataModel projectData,
}) async {
  tester.view.physicalSize = const Size(1400, 1000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final projectDataProvider = ProjectDataProvider()
    ..updateProjectData(projectData);

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<CostEstimateProvider>.value(
            value: fixtures.readyCostEstimate()),
        ChangeNotifierProvider<WBSProvider>.value(
            value: await fixtures.readyWbs(tester)),
        ChangeNotifierProvider<ScheduleProvider>.value(
            value: await fixtures.readySchedule(tester)),
        ChangeNotifierProvider<ProjectDataProvider>(
            create: (_) => projectDataProvider),
        ChangeNotifierProvider<ProjectControlsProvider>(
            create: (_) => ProjectControlsProvider()),
        ChangeNotifierProvider<ChangeManagementProvider>(
            create: (_) => ChangeManagementProvider()),
      ],
      child: const MaterialApp(home: ProjectControlsScreen()),
    ),
  );
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 120));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
      'the AI-Powered Context Insights card is collapsed by default '
      'and expands on tap', (tester) async {
    // The handle must be disposed inside the test body: the
    // framework verifies outstanding handles before any
    // addTearDown callback runs.
    final semantics = tester.ensureSemantics();
    try {
    await pumpProjectControls(
      tester,
      projectData: ProjectDataModel(
        projectId: 'p1',
        projectName: 'Lusaka',
        keyMilestones: [
          Milestone(name: 'Project Charter & Requirements Finalization'),
          Milestone(name: 'UX/UI Design & Interactive Prototype Sign-off'),
        ],
        charterConstraints:
            'Strict 8-week MVP timeline divided into 4 two-week Agile sprints.',
        charterAssumptions:
            'MTN MoMo and Airtel Money developer APIs provide reliable, uninterrupted sandbox testing environments.',
      ),
    );

    // The card renders, collapsed by default: header visible,
    // chevron pointing "expand".
    expect(find.text('AI-Powered Context Insights'), findsOneWidget);
    expect(find.text('Auto-populated from project data across all phases'),
        findsOneWidget);
    expect(find.byIcon(Icons.expand_more_rounded), findsOneWidget);
    expect(find.byIcon(Icons.expand_less_rounded), findsNothing);

    // The sections are mounted but hidden — absent from the live
    // semantics tree while the card is collapsed.
    expect(_liveSemanticsLabel('SCOPE MILESTONES (from project data)'),
        findsNothing);
    expect(
        _liveSemanticsLabel('CHANGE RECOMMENDATIONS (from constraints/assumptions)'),
        findsNothing);

    // The page header scrolls with the page and pushes the card
    // partly below the fold — scroll it into view before tapping.
    await tester.ensureVisible(find.text('AI-Powered Context Insights'));
    await tester.pump();

    // Tap the header to expand the card.
    await tester.tap(find.text('AI-Powered Context Insights'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Chevron flips and the sections become visible.
    expect(find.byIcon(Icons.expand_more_rounded), findsNothing);
    expect(find.byIcon(Icons.expand_less_rounded), findsOneWidget);
    expect(_liveSemanticsLabel('SCOPE MILESTONES (from project data)'),
        findsOneWidget);
    expect(
        _liveSemanticsLabel('CHANGE RECOMMENDATIONS (from constraints/assumptions)'),
        findsOneWidget);
    expect(
        _liveSemanticsLabel('Project Charter & Requirements Finalization'),
        findsOneWidget);

    expect(tester.takeException(), isNull);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('the AI-Powered Context Insights card collapses again '
      'on a second tap', (tester) async {
    final semantics = tester.ensureSemantics();
    try {
    await pumpProjectControls(
      tester,
      projectData: ProjectDataModel(
        projectId: 'p1',
        projectName: 'Lusaka',
        keyMilestones: [
          Milestone(name: 'Chongwe Farmer Cooperative Onboarding & Training'),
        ],
      ),
    );

    // Expand… (scroll the card into view first — the page header
    // above the tabs pushes it partly below the fold)
    await tester.ensureVisible(find.text('AI-Powered Context Insights'));
    await tester.pump();
    await tester.tap(find.text('AI-Powered Context Insights'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byIcon(Icons.expand_less_rounded), findsOneWidget);
    expect(_liveSemanticsLabel('SCOPE MILESTONES (from project data)'),
        findsOneWidget);

    // …then tap the header again — the card collapses back.
    await tester.tap(find.text('AI-Powered Context Insights'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    // The AnimatedCrossFade swaps the fading-out child into the
    // excluded (bottom) slot only once its reverse animation reports
    // dismissed; give the semantics tree one more frame to drop the
    // hidden subtree.
    await tester.pump();

    expect(find.byIcon(Icons.expand_more_rounded), findsOneWidget);
    expect(find.byIcon(Icons.expand_less_rounded), findsNothing);
    expect(_liveSemanticsLabel('SCOPE MILESTONES (from project data)'),
        findsNothing);

    expect(tester.takeException(), isNull);
    } finally {
      semantics.dispose();
    }
  });
}
