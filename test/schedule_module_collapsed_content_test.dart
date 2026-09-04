import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ndu_project/widgets/section_navigator.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets(
      'SectionNavigator collapses and content remains accessible',
      (tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    late TabController tabController;

    // Use a StatefulWidget to create the TabController with a proper TickerProvider.
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: _TestHarness(
          onReady: (tc) => tabController = tc,
        ),
      ),
    ));
    await tester.pumpAndSettle();

    // Navigator header visible and collapsed…
    expect(find.text('Schedule Navigation'), findsOneWidget);

    // Content area should still be rendered below the collapsed navigator.
    expect(find.text('Tab Content'), findsOneWidget);

    // Tab labels should not be visible when collapsed.
    expect(find.text('Builder'), findsNothing);
    expect(find.text('Gantt'), findsNothing);
    expect(find.text('List View'), findsNothing);

    // Tap the expand button to expand the navigator.
    await tester.tap(find.byIcon(Icons.keyboard_arrow_down));
    await tester.pumpAndSettle();

    // Tab labels should now be visible.
    expect(find.text('Builder'), findsOneWidget);
    expect(find.text('Gantt'), findsOneWidget);
    expect(find.text('List View'), findsOneWidget);
  });
}

/// Harness that creates a TabController with the proper TickerProvider.
class _TestHarness extends StatefulWidget {
  const _TestHarness({required this.onReady});
  final ValueChanged<TabController> onReady;

  @override
  State<_TestHarness> createState() => _TestHarnessState();
}

class _TestHarnessState extends State<_TestHarness>
    with SingleTickerProviderStateMixin {
  late final TabController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onReady(_controller);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SectionNavigator(
          title: 'Schedule Navigation',
          subtitle: 'Navigate between schedule sections',
          icon: Icons.calendar_month_outlined,
          tabs: const [
            SectionTab(icon: Icons.build_outlined, label: 'Builder'),
            SectionTab(icon: Icons.bar_chart, label: 'Gantt'),
            SectionTab(icon: Icons.list_alt, label: 'List View'),
          ],
          controller: _controller,
          onChanged: (_) {},
          isCollapsible: true,
          initiallyCollapsed: true,
        ),
        const Expanded(
          child: Center(child: Text('Tab Content')),
        ),
      ],
    );
  }
}
