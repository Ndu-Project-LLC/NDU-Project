// The shared progress summary + Continue badge for tab-based sections.
//
// Mirrors Design Planning's page-level pattern at tab scale: the chip answers
// "how much is left, what's next?", the badge marks the next tab in the strip,
// and both derive "next" from the same helper so they cannot disagree.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ndu_project/widgets/section_progress_bar.dart';

const _tabs = [
  FlowTab(id: 'safety', label: 'Safety'),
  FlowTab(id: 'security', label: 'Security'),
  FlowTab(id: 'health', label: 'Health'),
];

void _openNothing(String id) {}

Widget _host(List<FlowTab> tabs, Set<String> visited,
        {void Function(String id)? onOpen}) =>
    MaterialApp(
      home: Scaffold(
        body: SectionProgressBar(
          tabs: tabs,
          visitedIds: visited,
          onOpenTab: onOpen ?? _openNothing,
        ),
      ),
    );

void main() {
  group('SectionProgressBar', () {
    testWidgets('shows done count and the next tab label', (tester) async {
      await tester.pumpWidget(_host(_tabs, {'safety'}));

      expect(find.text('1 of 3 reviewed · Next: Security'), findsOneWidget);
    });

    testWidgets('tapping opens the next unvisited tab', (tester) async {
      var opened = '';
      await tester.pumpWidget(_host(
        _tabs,
        {'safety'},
        onOpen: (id) => opened = id,
      ));

      await tester.tap(find.byType(SectionProgressBar));
      expect(opened, 'security');
    });

    testWidgets('turns green and stops jumping when everything is seen',
        (tester) async {
      var opened = '';
      await tester.pumpWidget(_host(
        _tabs,
        {'safety', 'security', 'health'},
        onOpen: (String id) => opened = id,
      ));

      expect(find.text('All 3 tabs reviewed'), findsOneWidget);
      await tester.tap(find.byType(SectionProgressBar));
      expect(opened, isEmpty);
    });
  });

  group('nextUnvisitedTabId', () {
    test('returns the first unseen tab in declaration order', () {
      expect(
        nextUnvisitedTabId(_tabs, {'safety'}),
        'security',
      );
      expect(
        nextUnvisitedTabId(_tabs, {'safety', 'security'}),
        'health',
      );
    });

    test('returns null when every tab has been seen', () {
      expect(
        nextUnvisitedTabId(_tabs, {'safety', 'security', 'health'}),
        isNull,
      );
    });
  });

  group('FlowTabContinueBadge', () {
    testWidgets('renders its Continue label', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: FlowTabContinueBadge()),
      ));

      expect(find.text('Continue'), findsOneWidget);
    });
  });
}
