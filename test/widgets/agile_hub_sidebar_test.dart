// The Agile Project Hub breaks itself into 15 sub-pages
// ("Module Components"), and those same 15 have to be reachable from the
// sidebar, nested under **Agile Project Hub**. These tests pin that the
// breakdown exists once (`utils/agile_hub_sections.dart`), that the sidebar
// renders it, and that the highlight follows the user into a sub-page —
// including a sub-page whose screen is shared with the Planning phase and so
// reports a label of its own instead of a hub-specific one.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ndu_project/utils/agile_hub_sections.dart';
import 'package:ndu_project/widgets/initiation_like_sidebar.dart';

/// The sidebar body is a lazy ListView, so on the default 800x600 surface the
/// Execution Phase group sits far below the fold and is never built — the
/// sub-pages could not be observed at all. Build onto a surface tall enough to
/// inflate the whole navigation.
Future<void> pumpSidebar(WidgetTester tester, String activeItemLabel) async {
  tester.view.physicalSize = const Size(1400, 16000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
          body: InitiationLikeSidebar(activeItemLabel: activeItemLabel)),
    ),
  );
  await tester.pumpAndSettle();
}

/// The decoration of the sidebar tile that renders [text].
///
/// The coloured "selected" background lives on the `Container` that wraps the
/// tile's row, so the nearest `Container` ancestor of the label is the one
/// carrying the highlight.
BoxDecoration subPageDecoration(WidgetTester tester, String text) {
  final container = tester.widget<Container>(
    find.ancestor(of: find.text(text), matching: find.byType(Container)).first,
  );
  return container.decoration! as BoxDecoration;
}

void main() {
  group('the Agile Project Hub breakdown', () {
    test('is 15 numbered sections', () {
      expect(agileHubSections, hasLength(15));
      expect(
        agileHubSections.map((s) => s.number),
        [for (var i = 1; i <= 15; i++) i],
      );
    });

    test('gives every section its own page', () {
      for (final section in agileHubSections) {
        expect(section.route, isNotEmpty,
            reason: '${section.title} has no route');
        expect(section.path, startsWith('/'));
        expect(section.route, isNot(startsWith('/')),
            reason:
                '${section.title} route is a full path, not an AppRoutes name');
        expect(section.activeLabel, isNotEmpty,
            reason: '${section.title} has no active label to highlight');
        expect(section.features, isNotEmpty);
      }
      final routes = agileHubSections.map((s) => s.route).toList();
      expect(routes.toSet().length, routes.length,
          reason: 'two hub sections open the same page');
    });

    test('names each sub-page with the "<section> - <sub-page>" convention',
        () {
      for (final section in agileHubSections) {
        expect(section.sidebarLabel,
            'Agile Project Hub - ${section.sidebarTitle}');
      }
      expect(agileHubSidebarLabels, hasLength(agileHubSections.length));
      expect(agileHubTargetLabels, isNotEmpty);
    });
  });

  group('the sidebar', () {
    testWidgets('lists every hub section under "Agile Project Hub"',
        (tester) async {
      await pumpSidebar(tester, 'Agile Project Hub');

      expect(find.text('Agile Project Hub'), findsOneWidget);
      expect(find.text('Hub Overview'), findsOneWidget);
      for (final section in agileHubSections) {
        expect(
          find.text(section.sidebarTitle),
          findsWidgets,
          reason: '"${section.title}" is missing from the Agile Project Hub '
              'sub-pages',
        );
      }
    });

    testWidgets('collapses the sub-pages when the header is tapped',
        (tester) async {
      await pumpSidebar(tester, 'Agile Project Hub');
      expect(find.text('Hub Overview'), findsOneWidget);

      await tester.tap(find.text('Agile Project Hub'));
      await tester.pumpAndSettle();

      expect(find.text('Hub Overview'), findsNothing);
      expect(find.text(agileHubSections.first.sidebarTitle), findsNothing);
    });

    testWidgets('expands and highlights when a shared sub-page is open',
        (tester) async {
      // The Sprint Planning sub-page opens Sprint Cadence & Calendar, which
      // reports "Agile Delivery Model - Sprint Calendar" — not a hub label.
      // The hub group still has to light up and open, otherwise the user lands
      // on a sub-page the sidebar does not show.
      await pumpSidebar(tester, 'Agile Delivery Model - Sprint Calendar');

      expect(find.text('Agile Project Hub'), findsOneWidget);
      expect(find.text('Sprint Planning'), findsOneWidget);

      expect(subPageDecoration(tester, 'Sprint Planning').color,
          isNot(Colors.transparent),
          reason: 'the open sub-page is not highlighted');
      expect(subPageDecoration(tester, 'Backlog Grooming').color,
          Colors.transparent,
          reason: 'an unrelated sub-page should not be highlighted');
    });
  });
}
