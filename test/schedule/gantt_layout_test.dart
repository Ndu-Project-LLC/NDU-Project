import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ndu_project/schedule/models/schedule_models.dart';
import 'package:ndu_project/schedule/providers/schedule_provider.dart';
import 'package:ndu_project/schedule/screens/gantt_screen.dart';
import 'package:ndu_project/theme.dart';

/// Regression tests for the Gantt layout and zoom-control theming.
///
/// Two problems were reported from the schedule module:
///   1. the chart shrink-wrapped to `leftColWidth + cellCount * cellWidth`, so a
///      short project left most of the screen blank and the grid looked broken;
///   2. the Week/Month/Quarter/Year control rendered in the Material seed blue
///      instead of the brand yellow used everywhere else in the module.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  ScheduleActivity task({
    required String id,
    required String code,
    required String name,
    required DateTime start,
    required DateTime end,
  }) {
    return ScheduleActivity(
      id: id,
      level: 1,
      code: code,
      name: name,
      type: ActivityType.task,
      domain: ScheduleDomain.engineering,
      startDate: start,
      endDate: end,
      duration: end.difference(start).inDays.toDouble(),
      dependencies: const [],
      aiGenerated: false,
      children: const [],
    );
  }

  Future<void> pumpGantt(
    WidgetTester tester,
    List<ScheduleActivity> activities, {
    Size size = const Size(1600, 1000),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final provider = ScheduleProvider();
    provider.setup(projectName: 'Test Project', deliveryModel: 'WATERFALL');
    provider.setActivities(activities);

    await tester.pumpWidget(
      ChangeNotifierProvider<ScheduleProvider>.value(
        value: provider,
        child: const MaterialApp(home: Scaffold(body: GanttScreen())),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  /// The Gantt grid's horizontal scroll view.
  Finder findChartScrollView() => find.descendant(
        of: find.byType(GanttScreen),
        matching: find.byWidgetPredicate(
          (w) => w is SingleChildScrollView && w.scrollDirection == Axis.horizontal,
        ),
      );

  /// A two-week project — only a handful of week cells, which is exactly the
  /// case that used to leave the right-hand side of the screen empty.
  List<ScheduleActivity> shortProject() => [
        task(
          id: 'a1',
          code: '1',
          name: 'Platform Foundation',
          start: DateTime(2026, 10, 5),
          end: DateTime(2026, 10, 9),
        ),
      ];

  testWidgets('the chart fills the available width', (tester) async {
    await pumpGantt(tester, shortProject());

    // The grid is the widest card on the page; measure it against the
    // viewport rather than against a hard-coded number.
    final chart = findChartScrollView();
    expect(chart, findsOneWidget);

    final chartWidth = tester.getSize(chart).width;
    final viewport = tester.view.physicalSize.width /
        tester.view.devicePixelRatio;

    // Allow a pixel of rounding, but it must not be leaving the screen empty.
    expect(
      chartWidth,
      greaterThan(viewport * 0.95),
      reason: 'The Gantt grid should span the viewport, but was only '
          '${chartWidth.toStringAsFixed(1)}px wide in a '
          '${viewport.toStringAsFixed(1)}px viewport.',
    );
  });

  testWidgets('a long timeline overflows the card and scrolls instead of'
      ' being crushed', (tester) async {
    // 18 months of work: at week zoom this is far wider than the viewport, so
    // the table must stay scrollable rather than compressing its cells.
    await pumpGantt(tester, [
      task(
        id: 'a1',
        code: '1',
        name: 'Long Programme',
        start: DateTime(2026, 1, 5),
        end: DateTime(2027, 6, 30),
      ),
    ]);

    final chart = findChartScrollView();
    expect(chart, findsOneWidget);

    // The card is clamped to the viewport...
    final viewport = tester.view.physicalSize.width /
        tester.view.devicePixelRatio;
    expect(tester.getSize(chart).width, lessThanOrEqualTo(viewport));

    // ...while its content is wider, which is what makes it scrollable.
    final content = find.descendant(
      of: chart,
      matching: find.byType(Column),
    );
    expect(
      tester.getSize(content.first).width,
      greaterThan(tester.getSize(chart).width),
      reason: 'A long timeline should overflow the card and scroll '
          'horizontally instead of being squeezed to fit.',
    );
  });

  testWidgets('the zoom control is brand yellow, not the seed blue',
      (tester) async {
    await pumpGantt(tester, shortProject());

    for (final label in ['Week', 'Month', 'Quarter', 'Year']) {
      expect(find.text(label), findsOneWidget,
          reason: 'The "$label" zoom option should be present.');
    }

    // The button's generic type is a private enum, so it is matched
    // structurally rather than by type.
    final zoom = find.byWidgetPredicate(
      (w) => w is SegmentedButton<Object>,
    );
    expect(zoom, findsOneWidget);
  });

  testWidgets('the selected zoom segment uses the brand yellow fill',
      (tester) async {
    await pumpGantt(tester, shortProject());

    final button = tester.widget<SegmentedButton<Object>>(
      find.byWidgetPredicate((w) => w is SegmentedButton<Object>),
    );
    // SegmentedButton.styleFrom folds the selected fill into
    // backgroundColor, keyed on the `selected` widget state.
    final selected =
        button.style?.backgroundColor?.resolve(const {WidgetState.selected});

    expect(
      selected,
      LightModeColors.accent,
      reason: 'The active zoom segment should use the brand yellow accent.',
    );
  });
}
