import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ndu_project/providers/project_data_provider.dart';
import 'package:ndu_project/widgets/page_walkthrough.dart';
import 'package:ndu_project/widgets/unified_phase_header.dart';

/// The Tasks chip only renders when a project context exists, so these tests
/// supply one — otherwise there is nothing for the Walkthrough chip to sit
/// beside and the adjacency check would be meaningless.
Widget _fakePage(WidgetTester tester) {
  tester.view.physicalSize = const Size(1600, 1000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final provider = ProjectDataProvider();
  addTearDown(provider.reset);

  Widget section(String title, String body) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 8),
            Text(body, style: const TextStyle(fontSize: 13)),
          ],
        ),
      );

  return ProjectDataInherited(
    provider: provider,
    child: MaterialApp(
      home: Scaffold(
        body: Column(
          children: [
            const UnifiedPhaseHeader(title: 'Risk Assessment'),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    section('Risk Register', 'Every identified project risk.'),
                    section('Mitigation Plans', 'How each risk is treated.'),
                    section('Risk Escalation', 'Who is told, and when.'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('the Walkthrough chip renders beside Tasks in the header',
      (tester) async {
    await tester.pumpWidget(_fakePage(tester));
    await tester.pump();

    final tasks = find.textContaining('Tasks (');
    expect(tasks, findsOneWidget, reason: 'The Tasks chip should be present.');

    final walkthrough = find.text('Walkthrough');
    expect(walkthrough, findsOneWidget);

    // Same header row, immediately adjacent.
    expect(
      (tester.getCenter(walkthrough).dy - tester.getCenter(tasks).dy).abs(),
      lessThan(40),
      reason: 'The Walkthrough chip should sit beside Tasks.',
    );
  });

  testWidgets('pressing Walkthrough opens a tour describing the page',
      (tester) async {
    await tester.pumpWidget(_fakePage(tester));
    await tester.pump();

    await tester.tap(find.text('Walkthrough'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Opening card names the page and counts what it found.
    expect(find.text('Quick tour'), findsOneWidget);
    expect(find.textContaining('3 sections'), findsWidgets);

    // Advancing walks into the discovered sections.
    await tester.tap(find.text('Next'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Risk Register'), findsWidgets);
  });

  testWidgets('a registered bespoke tour overrides the derived one',
      (tester) async {
    addTearDown(PageWalkthroughRegistry.clear);
    PageWalkthroughRegistry.register(
      'Risk Assessment',
      (stops) => const [
        SpotlightStep(
          title: 'Bespoke intro',
          description: 'Hand-written copy wins over the derived tour.',
        ),
      ],
    );

    await tester.pumpWidget(_fakePage(tester));
    await tester.pump();

    await tester.tap(find.text('Walkthrough'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Bespoke intro'), findsOneWidget);
    expect(find.textContaining('sections'), findsNothing);
  });
}
