import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ndu_project/widgets/scrollable_section_header.dart';

/// A section-header stack taller than any cap the tests below use.
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
              child: tallStack(),
            ),
            const Expanded(child: Center(child: Text('Tab content'))),
          ],
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

ScrollableState stackScrollable(WidgetTester tester) =>
    tester.state<ScrollableState>(
      find
          .descendant(
            of: find.byKey(const ValueKey('stackScroll')),
            matching: find.byType(Scrollable),
          )
          .first,
    );

double hintOpacity(WidgetTester tester) => tester
    .widget<AnimatedOpacity>(
        find.byKey(const ValueKey('sectionHeaderScrollHint')))
    .opacity;

void main() {
  testWidgets('hints that there is more to scroll, then collapses out of the way',
      (tester) async {
    await pumpHeader(tester, const Size(900, 480));

    // Capped at half the window (240 < the 576-tall stack), so it scrolls…
    expect(stackScrollable(tester).position.maxScrollExtent, greaterThan(56));
    // …and the hint says as much.
    expect(hintOpacity(tester), 1);

    // Scrolling the stack partway collapses it once the scroll settles.
    await tester.drag(find.text('Card 0'), const Offset(0, -140));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(find.text('Show header'), findsOneWidget);
    expect(find.text('Schedule'), findsOneWidget);
    expect(find.text('Builder'), findsOneWidget);
    expect(find.text('Card 0'), findsNothing);
    expect(find.text('Tab content'), findsOneWidget);

    // The slim bar brings the whole stack back.
    await tester.tap(find.text('Show header'));
    await tester.pumpAndSettle();
    expect(find.text('Card 0'), findsOneWidget);
    expect(find.text('Show header'), findsNothing);
    expect(stackScrollable(tester).position.pixels, 0);
  });

  testWidgets('shows no hint while the whole stack fits', (tester) async {
    await pumpHeader(tester, const Size(900, 1600));

    expect(stackScrollable(tester).position.maxScrollExtent, 0);
    expect(hintOpacity(tester), 0);
    expect(find.text('Card 5'), findsOneWidget);
  });
}
