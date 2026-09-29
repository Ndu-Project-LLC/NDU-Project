// The module section-header host must give every module screen ONE vertical
// scroll experience: the header stack (section navigator, context banner,
// status cards) renders as ordinary slivers of the page scroll and scrolls
// away with the tab content — no capped inner viewport, no "Scroll for more"
// pill, no self-collapsing timers.
//
// A slim pinned bar keeps the module label + active tab available however deep
// the user is; tapping it returns to the header stack.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ndu_project/widgets/scrollable_section_header.dart';

/// A section-header stack (576 logical px tall) of the kind the module screens
/// host: navigator card + context banner + status cards.
Widget tallStack() => Column(
      children: [
        for (var i = 0; i < 6; i++)
          Container(
            height: 80,
            margin: const EdgeInsets.all(8),
            alignment: Alignment.center,
            child: Text('Card $i'),
          ),
      ],
    );

/// Tab content long enough to scroll on its own, so the hand-off between
/// header and body can be driven from the body side.
Widget longBody() => SingleChildScrollView(
      child: Column(
        children: [
          for (var i = 0; i < 12; i++)
            Container(
              height: 80,
              margin: const EdgeInsets.all(8),
              alignment: Alignment.center,
              child: Text('Row $i'),
            ),
        ],
      ),
    );

Future<void> pumpHeader(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Column(
          children: [
            ScrollableSectionHeader(
              label: 'Schedule',
              summary: 'Builder',
              scrollKey: const ValueKey('stackScroll'),
              header: tallStack(),
              body: longBody(),
            ),
          ],
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// The page scroll's outer position — the first scrollable under the keyed
/// [NestedScrollView].
ScrollableState pageScrollable(WidgetTester tester) =>
    tester.state<ScrollableState>(
      find
          .descendant(
            of: find.byKey(const ValueKey('stackScroll')),
            matching: find.byType(Scrollable),
          )
          .first,
    );

void main() {
  testWidgets('header and body scroll as one continuous page', (tester) async {
    // 800 tall: the 576-px stack fits under the pinned bar and the body's
    // first rows are visible below it — the shared surface is inspectable
    // at rest.
    await pumpHeader(tester, const Size(900, 800));

    // The whole header is laid out — nothing clipped behind a cap…
    expect(find.text('Card 0'), findsOneWidget);
    expect(find.text('Card 5'), findsOneWidget);
    // …and the body renders right below it, on the same surface.
    expect(find.text('Row 0'), findsOneWidget);

    // No capped-inner-viewport chrome anywhere.
    expect(find.text('Scroll for more'), findsNothing);
    expect(find.text('Show header'), findsNothing);

    // Dragging on the header content moves the page scroll.
    await tester.drag(find.text('Card 0'), const Offset(0, -140));
    await tester.pumpAndSettle();
    expect(pageScrollable(tester).position.pixels, greaterThan(0));
  });

  testWidgets(
      'dragging the body hands off to the header, then back-to-top restores it',
      (tester) async {
    await pumpHeader(tester, const Size(900, 800));

    // A long drag starting on the body content exhausts the body's own extent
    // and hands off to the page scroll, scrolling the header out of the way.
    await tester.drag(find.text('Row 0'), const Offset(0, -3000));
    await tester.pumpAndSettle();

    final position = pageScrollable(tester).position;
    expect(position.maxScrollExtent, greaterThan(0));
    expect(position.pixels, position.maxScrollExtent);

    // The pinned bar is still there at the bottom of the travel…
    expect(find.text('Schedule'), findsOneWidget);
    expect(find.text('Builder'), findsOneWidget);

    // …and tapping it brings the header stack back.
    await tester.tap(find.byTooltip('Back to top'));
    await tester.pumpAndSettle();
    expect(pageScrollable(tester).position.pixels, 0);
    expect(find.text('Card 0'), findsOneWidget);
  });

  testWidgets(
      'the pinned bar survives even when the stack is taller than the window',
      (tester) async {
    // 480 tall: the 576-px stack alone exceeds the viewport — the exact
    // condition that used to clip cards behind a "Scroll for more" pill.
    await pumpHeader(tester, const Size(900, 480));

    await tester.drag(find.text('Card 0'), const Offset(0, -600));
    await tester.pumpAndSettle();

    expect(find.text('Schedule'), findsOneWidget);
    expect(find.text('Builder'), findsOneWidget);
    expect(find.byTooltip('Back to top'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders without a pinned bar when asked to', (tester) async {
    tester.view.physicalSize = const Size(900, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              ScrollableSectionHeader(
                label: 'Schedule',
                showPinnedBar: false,
                header: tallStack(),
                body: longBody(),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Schedule'), findsNothing);
    expect(find.byTooltip('Back to top'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders the footer outside the scroll', (tester) async {
    tester.view.physicalSize = const Size(900, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              ScrollableSectionHeader(
                label: 'WBS',
                header: tallStack(),
                body: longBody(),
                footer: const Padding(
                  padding: EdgeInsets.all(8),
                  child: Text('Back / Next'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Scroll to the very end: the footer must still be on screen.
    await tester.drag(find.text('Card 0'), const Offset(0, -3000));
    await tester.pumpAndSettle();

    expect(find.text('Back / Next'), findsOneWidget);
  });
}
