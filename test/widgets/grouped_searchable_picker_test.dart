import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ndu_project/widgets/grouped_searchable_picker.dart';

const _sections = <PickerSection>[
  PickerSection(
    label: 'Leadership & Project Management',
    options: ['Project Manager', 'Program Manager', 'Operations Manager'],
  ),
  PickerSection(
    label: 'Quality & Testing',
    options: ['QA Lead', 'Test Lead'],
  ),
  PickerSection(label: 'Other', options: ['Custom']),
];

Future<String?> _pumpPicker(
  WidgetTester tester, {
  String? value,
}) async {
  String? picked;
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: GroupedSearchablePicker(
            sections: _sections,
            value: value,
            hintText: 'Select a position',
            onChanged: (v) => picked = v,
          ),
        ),
      ),
    ),
  );
  return picked;
}

void main() {
  group('GroupedSearchablePicker', () {
    testWidgets('shows the hint until a value is chosen', (tester) async {
      await _pumpPicker(tester);
      expect(find.text('Select a position'), findsOneWidget);
      expect(find.text('Project Manager'), findsNothing);
    });

    testWidgets('shows the current value in the field', (tester) async {
      await _pumpPicker(tester, value: 'QA Lead');
      expect(find.text('QA Lead'), findsOneWidget);
      expect(find.text('Select a position'), findsNothing);
    });

    testWidgets('opens a dialog listing every section', (tester) async {
      await _pumpPicker(tester);

      await tester.tap(find.byType(InputDecorator));
      await tester.pumpAndSettle();

      expect(find.text('Select a role'), findsOneWidget);
      expect(find.text('LEADERSHIP & PROJECT MANAGEMENT'), findsOneWidget);
      expect(find.text('QUALITY & TESTING'), findsOneWidget);
      expect(find.text('OTHER'), findsOneWidget);
      expect(find.text('6 options — type to filter'), findsOneWidget);
    });

    testWidgets('filters options and hides empty sections as you type',
        (tester) async {
      await _pumpPicker(tester);
      await tester.tap(find.byType(InputDecorator));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'manager');
      await tester.pumpAndSettle();

      expect(find.text('Project Manager'), findsOneWidget);
      expect(find.text('Program Manager'), findsOneWidget);
      expect(find.text('Operations Manager'), findsOneWidget);
      expect(find.text('QA Lead'), findsNothing);
      // Sections with no matches disappear.
      expect(find.text('QUALITY & TESTING'), findsNothing);
      expect(find.text('OTHER'), findsNothing);
      expect(find.text('3 of 6 match "manager"'), findsOneWidget);
    });

    testWidgets('search is case insensitive', (tester) async {
      await _pumpPicker(tester);
      await tester.tap(find.byType(InputDecorator));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'QA');
      await tester.pumpAndSettle();

      expect(find.text('QA Lead'), findsOneWidget);
    });

    testWidgets('reports when nothing matches', (tester) async {
      await _pumpPicker(tester);
      await tester.tap(find.byType(InputDecorator));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'zzz');
      await tester.pumpAndSettle();

      expect(find.text('No roles match your search.'), findsOneWidget);
    });

    testWidgets('clearing the search restores every section', (tester) async {
      await _pumpPicker(tester);
      await tester.tap(find.byType(InputDecorator));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'zzz');
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Clear search'));
      await tester.pumpAndSettle();

      expect(find.text('QUALITY & TESTING'), findsOneWidget);
      expect(find.text('Custom'), findsOneWidget);
    });

    testWidgets('returns the tapped option and closes', (tester) async {
      String? picked;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: GroupedSearchablePicker(
                sections: _sections,
                value: null,
                hintText: 'Select a position',
                onChanged: (v) => picked = v,
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byType(InputDecorator));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Test Lead'));
      await tester.pumpAndSettle();

      expect(picked, 'Test Lead');
      expect(find.text('Select a role'), findsNothing);
    });

    testWidgets('cancel reports nothing', (tester) async {
      String? picked;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: GroupedSearchablePicker(
                sections: _sections,
                value: null,
                hintText: 'Select a position',
                onChanged: (v) => picked = v,
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byType(InputDecorator));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(picked, isNull);
    });
  });
}
