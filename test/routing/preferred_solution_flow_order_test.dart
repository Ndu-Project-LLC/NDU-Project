// Lusaka 24 review: "the preferred solution analysis comes before the
// preferred solution selection … the way it is now, where is preferred solution
// analysis, preferred solution before preferred solution analysis — it doesn't
// even follow the flow."
//
// The owner had asked for this ~15 times, so the order is pinned here rather
// than left to the sidebar's widget code:
//
//   Initial Cost Estimate → Preferred Solution Analysis → Preferred Solution
//   → Front End Planning
//
// The analysis compares the candidates and chooses one; the Preferred Solution
// page that follows is the record of that choice.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ndu_project/screens/project_decision_summary_screen.dart';
import 'package:ndu_project/services/sidebar_navigation_service.dart';
import 'package:ndu_project/widgets/initiation_like_sidebar.dart';

void main() {
  group('flow order', () {
    test('the analysis precedes the preferred solution', () {
      final labels = SidebarNavigationService.executiveSummaryItems
          .map((item) => item.label)
          .toList();

      expect(labels, ['Preferred Solution Analysis', 'Preferred Solution']);
      expect(labels.indexOf('Preferred Solution Analysis'),
          lessThan(labels.indexOf('Preferred Solution')));
    });

    test('the analysis is the last step of the business case', () {
      final checkpoints =
          SidebarNavigationService.allItems.map((i) => i.checkpoint).toList();
      final analysis = checkpoints.indexOf('preferred_solution_analysis');
      final cost = checkpoints.indexOf('cost_analysis');

      expect(analysis, greaterThan(cost));
      // Next in the linear flow is Front End Planning — the Preferred Solution
      // page sits between them and is reached from the analysis.
      expect(
        SidebarNavigationService.instance
            .getNextItem('preferred_solution_analysis')
            ?.checkpoint,
        'fep_summary',
      );
    });

    testWidgets('the sidebar lists the analysis above the preferred solution',
        (tester) async {
      // The sidebar body is a lazy ListView, so with the default 800x600 test
      // surface the Executive Summary group sits far below the fold and is
      // never built — the order could not be observed at all. Build onto a
      // surface tall enough to inflate the whole navigation.
      tester.view.physicalSize = const Size(1400, 8000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: InitiationLikeSidebar(
              activeItemLabel: 'Preferred Solution Analysis',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final analysisFinder = find.text('Preferred Solution Analysis');
      final preferredFinder = find.text('Preferred Solution');
      expect(analysisFinder, findsWidgets);
      expect(preferredFinder, findsWidgets);

      final analysisY = tester.getTopLeft(analysisFinder.first).dy;
      final preferredY = tester.getTopLeft(preferredFinder.first).dy;
      expect(analysisY, lessThan(preferredY));
    });
  });

  group('preferred solution page copy', () {
    test('asks for a selection while nothing has been chosen', () {
      expect(PreferredSolutionPageCopy.title(hasSelection: false),
          'Preferred Solution Selection');
      expect(PreferredSolutionPageCopy.subtitle(hasSelection: false),
          contains('select'));
    });

    test('reads as the record of the chosen solution once there is one', () {
      expect(PreferredSolutionPageCopy.title(hasSelection: true),
          'Preferred Solution');
      expect(PreferredSolutionPageCopy.subtitle(hasSelection: true),
          contains('Front End Planning'));
    });
  });
}
