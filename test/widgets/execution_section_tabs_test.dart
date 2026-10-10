import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ndu_project/widgets/execution_section_tabs.dart';

void main() {
  testWidgets('shows only the selected section and switches on tap',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ExecutionSectionTabs(
              tabs: [
                SectionTab(
                  label: 'Plan notes',
                  builder: (_) => const Text('NOTES BODY'),
                ),
                SectionTab(
                  label: 'Early works',
                  builder: (_) => const Text('EARLY WORKS BODY'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Plan notes'), findsOneWidget);
    expect(find.text('Early works'), findsOneWidget);
    expect(find.text('NOTES BODY'), findsOneWidget);
    expect(find.text('EARLY WORKS BODY'), findsNothing);

    await tester.tap(find.text('Early works'));
    await tester.pumpAndSettle();

    expect(find.text('EARLY WORKS BODY'), findsOneWidget);
    expect(find.text('NOTES BODY'), findsNothing);
  });
}
