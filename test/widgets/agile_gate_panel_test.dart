// The order the owner asked for is a *visual* claim — acceptance criteria above
// definition of done — so this asserts it by position on the screen rather than
// by trusting the widget tree's build order.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ndu_project/utils/agile_gate_definitions.dart';
import 'package:ndu_project/widgets/agile_gate_panel.dart';

Future<void> _pump(
  WidgetTester tester, {
  required AgileGateDefinition ready,
  required AgileGateDefinition done,
  VoidCallback? onOpenGovernance,
  String summary = '',
  Widget? criteria,
}) async {
  tester.view.physicalSize = const Size(1800, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: AgileGatePanel(
            ready: ready,
            done: done,
            acceptanceCriteriaSummary: summary,
            onOpenGovernance: onOpenGovernance,
            acceptanceCriteria: criteria ??
                const Padding(
                  padding: EdgeInsets.all(8),
                  child: Text('Acceptance criteria editor'),
                ),
          ),
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 50));
}

double _topOf(WidgetTester tester, String text) =>
    tester.getTopLeft(find.text(text).first).dy;

void main() {
  final ready = AgileGateDefinitions.ready(const {});
  final done = AgileGateDefinitions.done(const {});

  testWidgets('the gate reads ready, criteria, done from top to bottom',
      (tester) async {
    await _pump(tester, ready: ready, done: done);

    final readyY = _topOf(tester, 'Definition of Ready');
    final criteriaY = _topOf(tester, 'Acceptance Criteria');
    final doneY = _topOf(tester, 'Definition of Done');

    expect(readyY, lessThan(criteriaY));
    expect(criteriaY, lessThan(doneY),
        reason: 'acceptance criteria must sit above definition of done');
  });

  testWidgets('the stage numbers show the same order', (tester) async {
    await _pump(tester, ready: ready, done: done);

    expect(find.text('1'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(_topOf(tester, '1'), lessThan(_topOf(tester, '2')));
    expect(_topOf(tester, '2'), lessThan(_topOf(tester, '3')));
  });

  testWidgets('ready and done say they are governed elsewhere', (tester) async {
    await _pump(tester, ready: ready, done: done, onOpenGovernance: () {});

    expect(find.text('FROM GOVERNANCE'), findsNWidgets(2));
    expect(find.text('THIS PAGE'), findsOneWidget);
    expect(
      find.textContaining('maintained in Backlog Governance'),
      findsNWidgets(2),
      reason: 'both outer gates must point at their single definition',
    );
    expect(find.text('Open Backlog Governance'), findsNWidgets(2));
  });

  testWidgets('the prose form is shown when governance is not in checklist '
      'mode', (tester) async {
    await _pump(
      tester,
      ready: AgileGateDefinitions.ready(const {
        'dor_use_checklist': false,
        'definition_of_ready': 'Sized, dependencies known, PO approved.',
      }),
      done: done,
    );

    expect(find.text('Sized, dependencies known, PO approved.'), findsOneWidget);
    // The checklist is not rendered as chips in prose mode.
    expect(find.text('Story written and described'), findsNothing);
  });

  testWidgets('saved checklist items are echoed as chips', (tester) async {
    await _pump(
      tester,
      ready: AgileGateDefinitions.ready(const {
        'dor_use_checklist': true,
        'dor_checklist': [
          {'label': 'Business approval obtained', 'checked': false},
        ],
      }),
      done: done,
    );

    expect(find.text('Business approval obtained'), findsOneWidget);
  });

  testWidgets('the criteria summary is shown beside the middle stage',
      (tester) async {
    await _pump(tester, ready: ready, done: done, summary: '6 criteria');

    expect(find.text('6 criteria'), findsOneWidget);
  });

  testWidgets('the governance link is only offered when it can be opened',
      (tester) async {
    await _pump(tester, ready: ready, done: done);

    expect(find.text('Open Backlog Governance'), findsNothing);
  });
}
