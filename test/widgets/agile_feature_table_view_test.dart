// The all-features list the review asked for on Epics & Features: every feature
// with its epic, and an explicit call-out for epics that contribute no row.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ndu_project/models/epic_model.dart';
import 'package:ndu_project/models/feature_model.dart';
import 'package:ndu_project/utils/agile_epic_feature_table.dart';
import 'package:ndu_project/widgets/agile_feature_table_view.dart';

Future<void> _pump(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(body: SingleChildScrollView(child: child)),
  ));
  await tester.pump();
}

void main() {
  final epicA = Epic(id: 'epic-a', title: 'Customer onboarding');
  final epicB = Epic(id: 'epic-b', title: 'Billing');
  final featuresByEpic = {
    'epic-a': [
      Feature(
        id: 'f-a1',
        epicId: 'epic-a',
        title: 'Sign up with email',
        priority: 'high',
        storyPointEstimate: 5,
      ),
    ],
    'epic-b': <Feature>[],
  };

  testWidgets('lists every feature with its epic and a summary', (tester) async {
    await _pump(
      tester,
      AgileFeatureTableView(
        rows: AgileEpicFeatureTable.build([epicA, epicB], featuresByEpic),
        epicsWithoutFeatures: AgileEpicFeatureTable.epicsWithoutFeatures(
            [epicA, epicB], featuresByEpic),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('All features'), findsOneWidget);
    expect(find.text('Sign up with email'), findsOneWidget);
    expect(find.text('Customer onboarding'), findsOneWidget);
    expect(find.text('high'), findsOneWidget);
    expect(find.text('5'), findsOneWidget);
    expect(find.textContaining('1 feature across 1 epic'), findsOneWidget);
  });

  testWidgets('an epic with no features is reported, not silently skipped',
      (tester) async {
    await _pump(
      tester,
      AgileFeatureTableView(
        rows: AgileEpicFeatureTable.build([epicA, epicB], featuresByEpic),
        epicsWithoutFeatures: AgileEpicFeatureTable.epicsWithoutFeatures(
            [epicA, epicB], featuresByEpic),
      ),
    );

    expect(find.byKey(const ValueKey('epics-without-features-notice')),
        findsOneWidget);
    expect(find.textContaining('1 epic with no features yet: Billing'),
        findsOneWidget);
  });

  testWidgets('nothing at all says so instead of rendering an empty table',
      (tester) async {
    await _pump(tester, const AgileFeatureTableView(rows: []));

    expect(find.text('All features'), findsNothing);
    expect(find.textContaining('No features yet'), findsOneWidget);
  });
}
