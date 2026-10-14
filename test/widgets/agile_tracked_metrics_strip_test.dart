// Guards the dashboard saying what it measures: one chip per metric Metrics
// Planning defines, and an honest label when those are only the defaults.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ndu_project/utils/agile_metrics_catalog.dart';
import 'package:ndu_project/widgets/agile_tracked_metrics_strip.dart';

Future<void> _pump(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(body: SingleChildScrollView(child: child)),
  ));
  await tester.pump();
}

void main() {
  testWidgets('renders one chip per tracked metric', (tester) async {
    await _pump(
      tester,
      AgileTrackedMetricsStrip(
        metrics: AgileMetricsCatalog.trackedMetrics(const {
          'selectedMetrics': ['velocity', 'sprint_predictability'],
        }),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Tracked metrics'), findsOneWidget);
    expect(find.text('Velocity'), findsOneWidget);
    expect(find.text('Sprint Predictability'), findsOneWidget);
    expect(find.text('Throughput'), findsNothing,
        reason: 'only the chosen set is shown');
  });

  testWidgets('says out loud when it is showing the default set',
      (tester) async {
    await _pump(
      tester,
      AgileTrackedMetricsStrip(
        metrics: AgileMetricsCatalog.trackedMetrics(const {}),
        usingDefaults: true,
      ),
    );

    expect(find.textContaining('default tracking'), findsOneWidget);
    expect(find.textContaining('Everything below is measured'),
        findsNothing);
  });

  testWidgets('an empty set points at Metrics Planning instead of going blank',
      (tester) async {
    await _pump(
      tester,
      const AgileTrackedMetricsStrip(metrics: []),
    );

    expect(find.textContaining('Pick a set in Metrics Planning'), findsOneWidget);
  });
}
