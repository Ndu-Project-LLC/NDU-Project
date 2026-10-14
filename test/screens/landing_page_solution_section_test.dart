// Regression tests for the landing page.
//
// `_SolutionSection` accidentally contains TWO sibling `GridView.count`s:
// a `shrinkWrap: true` one plus a stale non-shrinkWrap one left behind by
// the aborted shrinkWrap migration (commits cbc0474 / 78851947). The
// non-shrinkWrap grid sits inside the page's `SliverList` — whose children
// get unbounded height — so it throws "Vertical viewport was given unbounded
// height" and takes down the whole landing page. Even without the crash, the
// duplicate would render every capability card twice.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:ndu_project/screens/landing/landing_page_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpLanding(WidgetTester tester) async {
    // Desktop viewport: the marketing page is desktop-first and its nav
    // overflows horizontally below ~1000px (a separate, known concern).
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const LandingPageScreen(),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));

    // SliverList only lays out children as they enter the viewport, so the
    // solution section (4th of 14) must be scrolled into view before its
    // layout — and any exception it throws — can surface. The hero hosts its
    // own nested SingleChildScrollView, which swallows a synthetic drag at
    // screen centre, so drive the outer scroll position directly instead.
    var guard = 0;
    final outer =
        tester.state<ScrollableState>(find.byType(Scrollable).first);
    while (find.byKey(const Key('solution')).evaluate().isEmpty &&
        guard < 60) {
      if (!outer.position.hasPixels ||
          outer.position.pixels >= outer.position.maxScrollExtent) {
        break;
      }
      final next = outer.position.pixels + 600;
      outer.position.jumpTo(next.clamp(0.0, outer.position.maxScrollExtent));
      await tester.pump(const Duration(milliseconds: 100));
      guard++;
    }
    expect(find.byKey(const Key('solution')), findsWidgets,
        reason: 'solution section should be built after scrolling');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('landing page renders without layout exceptions',
      (tester) async {
    await pumpLanding(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets('capability cards are rendered exactly once', (tester) async {
    await pumpLanding(tester);
    expect(tester.takeException(), isNull);

    // The four capability cards from the solution section; a duplicate
    // GridView would double these.
    expect(find.text('End-to-end delivery'), findsOneWidget);
    expect(find.text('AI-driven recommendations'), findsOneWidget);
    expect(find.text('Real-time alignment'), findsOneWidget);
    expect(find.text('Readiness-based execution'), findsOneWidget);
  });
}
