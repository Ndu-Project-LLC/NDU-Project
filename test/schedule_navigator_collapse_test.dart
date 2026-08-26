import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ndu_project/widgets/section_navigator.dart';

/// Mirrors the Schedule module screen layout: a Column with the
/// [SectionNavigator] on top and tab content in an [Expanded] below.
/// Regression test for the bug where collapsing the navigator blanked the
/// whole page content.
class _Host extends StatefulWidget {
  const _Host({this.storageKey, this.initiallyCollapsed = true});

  final String? storageKey;
  final bool initiallyCollapsed;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> with SingleTickerProviderStateMixin {
  late final TabController _tabController =
      TabController(length: 3, vsync: this);

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: SectionNavigator(
              title: 'Schedule Navigation',
              collapseStorageKey: widget.storageKey,
              subtitle: 'Navigate between schedule sections',
              icon: Icons.calendar_month_outlined,
              tabs: const [
                SectionTab(icon: Icons.build_outlined, label: 'Builder'),
                SectionTab(icon: Icons.bar_chart, label: 'Gantt'),
                SectionTab(icon: Icons.list_alt, label: 'List View'),
              ],
              controller: _tabController,
              onChanged: (index) => setState(() {}),
              isCollapsible: true,
              initiallyCollapsed: widget.initiallyCollapsed,
            ),
          ),
          const Expanded(
            child: Center(child: Text('TAB CONTENT MARKER')),
          ),
        ],
      ),
    );
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('SectionNavigator collapse does not blank page content', () {
    testWidgets('tab content renders while navigator is collapsed by default',
        (tester) async {
      tester.view.physicalSize = const Size(1600, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(const MaterialApp(home: const _Host()));

      await tester.pumpAndSettle();

      // Navigator header is visible…
      expect(find.text('Schedule Navigation'), findsOneWidget);
      // …tab pills are hidden (collapsed)…
      expect(find.text('Builder'), findsNothing);
      // …but the tab content below MUST still be visible.
      expect(find.text('TAB CONTENT MARKER'), findsOneWidget);
    });

    testWidgets('tab content renders when collapsed state is persisted',
        (tester) async {
      tester.view.physicalSize = const Size(1600, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      SharedPreferences.setMockInitialValues({
        'section_navigator_collapsed_Schedule Navigation': true,
      });

      await tester.pumpWidget(const MaterialApp(home: _Host()));
      await tester.pumpAndSettle();

      expect(find.text('Builder'), findsNothing);
      expect(find.text('TAB CONTENT MARKER'), findsOneWidget);
    });

    testWidgets('expanding and re-collapsing keeps tab content visible',
        (tester) async {
      tester.view.physicalSize = const Size(1600, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(const MaterialApp(home: _Host()));
      await tester.pumpAndSettle();

      // Expand the navigator via the collapse toggle.
      await tester.tap(find.byTooltip('Expand'));
      await tester.pumpAndSettle();
      expect(find.text('Builder'), findsOneWidget);
      expect(find.text('TAB CONTENT MARKER'), findsOneWidget);

      // Collapse it again.
      await tester.tap(find.byTooltip('Collapse'));
      await tester.pumpAndSettle();
      expect(find.text('Builder'), findsNothing);
      expect(find.text('TAB CONTENT MARKER'), findsOneWidget);
    });

    testWidgets('no exceptions are thrown during collapsed build',
        (tester) async {
      tester.view.physicalSize = const Size(1600, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      SharedPreferences.setMockInitialValues({
        'section_navigator_collapsed_Schedule Navigation': true,
      });

      // pumpAndSettle fails the test if any exception is thrown during build.
      await tester.pumpWidget(const MaterialApp(home: _Host()));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });
}
