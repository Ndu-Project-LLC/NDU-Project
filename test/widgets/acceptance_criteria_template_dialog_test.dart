// The create-template modal behind the Templates section's "Add" button.
//
// The behaviour these tests pin down is that nothing reaches the page unless
// the user described it: a name, a work item type, a format and a starting
// point for the criteria — plus no silent duplicate for the same work item
// type.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ndu_project/models/acceptance_criteria.dart';
import 'package:ndu_project/widgets/acceptance_criteria_template_dialog.dart';
import 'package:ndu_project/widgets/voice_text_field.dart';

/// Pumps a page whose button opens the modal, and returns the pending result.
Future<Future<AcceptanceCriteriaTemplate?>> _openModal(
  WidgetTester tester, {
  WorkItemType type = WorkItemType.userStory,
  AcFormat format = AcFormat.checklist,
  List<AcceptanceCriteriaTemplate> existing = const [],
}) async {
  late Future<AcceptanceCriteriaTemplate?> pending;
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () {
                pending = AcceptanceCriteriaTemplateDialog.show(
                  context,
                  initialWorkItemType: type,
                  initialFormat: format,
                  existingTemplates: existing,
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return pending;
}

Finder get _createButton => find.widgetWithText(FilledButton, 'Create template');

bool _enabled(WidgetTester tester) =>
    tester.widget<FilledButton>(_createButton).enabled;

/// The "Starting criteria" picker. Keyed because its seed type is private to
/// the dialog, so it cannot be named from a test.
final Finder _seedDropdown = find.byKey(const ValueKey('acSeedDropdown'));

Future<void> _enterName(WidgetTester tester, String name) async {
  await tester.enterText(find.byType(VoiceTextFormField).first, name);
  await tester.pump();
}

Future<void> _pickWorkItemType(WidgetTester tester, String label) async {
  await tester.tap(find.byType(DropdownButtonFormField<WorkItemType>));
  await tester.pumpAndSettle();
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

Future<void> _pickSeed(WidgetTester tester, String label) async {
  // The modal scrolls on a short viewport (the test surface is 800x600) and
  // the seed picker is the last field before the pinned action bar, so it
  // starts below the fold. Tapping its laid-out centre without scrolling first
  // lands on those pinned actions instead, and the menu silently never opens.
  await tester.ensureVisible(_seedDropdown);
  await tester.pumpAndSettle();
  await tester.tap(_seedDropdown);
  await tester.pumpAndSettle();
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('opens with the page\'s current type and format',
      (tester) async {
    await _openModal(tester,
        type: WorkItemType.feature, format: AcFormat.bdd);

    expect(find.text('New template'), findsOneWidget);
    expect(find.text('Template name'), findsOneWidget);
    expect(find.text('Starting criteria'), findsOneWidget);
    // The summary line reflects the caller's context, not fixed defaults.
    expect(
      find.textContaining('Creates a Feature template in '
          'Given / When / Then (BDD)'),
      findsOneWidget,
    );
  });

  testWidgets('Create stays disabled until the template has a name',
      (tester) async {
    await _openModal(tester);

    expect(_enabled(tester), isFalse);

    await _enterName(tester, '   ');
    expect(_enabled(tester), isFalse);

    await _enterName(tester, 'Checkout flow');
    expect(_enabled(tester), isTrue);
  });

  testWidgets('returns the described template with its seeded criteria',
      (tester) async {
    final pending = await _openModal(tester);

    await _enterName(tester, '  Checkout flow  ');
    await tester.enterText(
        find.byType(VoiceTextFormField).at(1), 'For the payments journey');
    await tester.pump();
    await tester.tap(_createButton);
    await tester.pumpAndSettle();

    final template = await pending;
    expect(template, isNotNull);
    expect(template!.name, 'Checkout flow'); // trimmed
    expect(template.description, 'For the payments journey');
    expect(template.workItemType, WorkItemType.userStory);
    expect(template.format, AcFormat.checklist);
    expect(
      template.criteria.map((c) => c.category),
      <CriterionCategory>[
        CriterionCategory.functional,
        CriterionCategory.nonFunctional,
      ],
    );
    // Criteria start blank — they are prompts to be filled in.
    expect(template.criteria.every((c) => c.description.isEmpty), isTrue);
  });

  testWidgets('the chosen work item type and format are carried through',
      (tester) async {
    final pending = await _openModal(tester);

    await _enterName(tester, 'Spike outcome');
    await _pickWorkItemType(tester, 'Spike');
    await tester.tap(find.byType(DropdownButtonFormField<AcFormat>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Scenario-Based').last);
    await tester.pumpAndSettle();
    await tester.pump();
    await tester.tap(_createButton);
    await tester.pumpAndSettle();

    final template = await pending;
    expect(template!.workItemType, WorkItemType.spike);
    expect(template.format, AcFormat.scenario);
  });

  testWidgets('a duplicate name for the same work item type is refused',
      (tester) async {
    final existing = <AcceptanceCriteriaTemplate>[
      AcceptanceCriteriaTemplate(
        name: 'Checkout flow',
        workItemType: WorkItemType.userStory,
      ),
    ];
    final pending = await _openModal(tester, existing: existing);

    await _enterName(tester, 'checkout FLOW ');

    expect(_enabled(tester), isFalse);
    expect(
      find.textContaining('already exists'),
      findsOneWidget,
    );

    // The same name under a different work item type is not a clash.
    await _pickWorkItemType(tester, 'Bug');
    await tester.pump();
    expect(find.textContaining('already exists'), findsNothing);
    expect(_enabled(tester), isTrue);

    await tester.tap(_createButton);
    await tester.pumpAndSettle();
    final template = await pending;
    expect(template!.workItemType, WorkItemType.bug);
  });

  testWidgets('"Start empty" creates a template with no criteria',
      (tester) async {
    final pending = await _openModal(tester);

    await _enterName(tester, 'Blank slate');
    await _pickSeed(tester, 'Start empty');

    // The summary is one sentence ('...with no criteria yet. ...'), so this is
    // a substring match, not an exact one.
    expect(find.textContaining('no criteria yet'), findsOneWidget);
    await tester.tap(_createButton);
    await tester.pumpAndSettle();

    final template = await pending;
    expect(template!.criteria, isEmpty);
  });

  testWidgets('Cancel closes the modal without returning a template',
      (tester) async {
    final pending = await _openModal(tester);

    await _enterName(tester, 'Abandoned');
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    // Bounded so a dialog that fails to close reports a failure instead of
    // leaving the result future unresolved and hanging the whole suite.
    expect(await pending.timeout(const Duration(seconds: 5)), isNull);
    expect(find.text('New template'), findsNothing);
  });

  testWidgets('Escape closes the modal too', (tester) async {
    final pending = await _openModal(tester);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    // Bounded for the same reason as the Cancel test above — Escape only
    // closes this modal because the dialog wires the shortcut up itself.
    expect(await pending.timeout(const Duration(seconds: 5)), isNull);
    expect(find.text('New template'), findsNothing);
  });
}
