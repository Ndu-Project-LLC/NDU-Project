// The underlines are drawn from the controller's spans, and the fixes write
// back through the controller, so both halves are exercised here: what the
// field actually paints, and what applying a suggestion does to the text.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ndu_project/services/spell_check/spell_check_service.dart';
import 'package:ndu_project/utils/rich_text_editing_controller.dart';
import 'package:ndu_project/widgets/spell_check/spell_check_dialogs.dart';
import 'package:ndu_project/widgets/spell_check/spell_checking_text_controller.dart';

const List<String> _dictionary = <String>[
  'a',
  'and',
  'bold',
  'hallo',
  'hello',
  'it',
  'need',
  'plan',
  'project',
  'receive',
  'received',
  'requirement',
  'the',
  'this',
  'to',
  'we',
  'world',
];

/// Flattens a span tree into the leaf spans that carry text.
List<TextSpan> _leaves(InlineSpan span) {
  if (span is! TextSpan) return const <TextSpan>[];
  if ((span.text ?? '').isNotEmpty) return <TextSpan>[span];
  final children = span.children;
  if (children == null) return const <TextSpan>[];
  return <TextSpan>[
    for (final child in children) ..._leaves(child),
  ];
}

/// The text of the first underline-decorated leaf, or null when none is.
String? _firstUnderlinedText(InlineSpan span) {
  for (final leaf in _leaves(span)) {
    final decoration = leaf.style?.decoration;
    if (decoration != null &&
        decoration.contains(TextDecoration.underline)) {
      return leaf.text;
    }
  }
  return null;
}

Future<BuildContext> _contextFor(WidgetTester tester) async {
  late BuildContext captured;
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) {
          captured = context;
          return const Scaffold(body: SizedBox.shrink());
        },
      ),
    ),
  );
  return captured;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    SpellCheckService.instance
      ..debugClearUserLists()
      ..debugLoadWords(_dictionary);
  });

  testWidgets('a typo is underlined and the rest of the text is not',
      (tester) async {
    final context = await _contextFor(tester);
    final controller =
        SpellCheckTextEditingController(text: 'we need to recieve it');

    final span = controller.buildTextSpan(
      context: context,
      style: const TextStyle(fontSize: 14),
      withComposing: false,
    );

    final underlined = _leaves(span)
        .where((leaf) =>
            leaf.style?.decoration?.contains(TextDecoration.underline) ??
            false)
        .toList();
    expect(underlined, hasLength(1));
    expect(underlined.single.text, 'recieve');
    expect(underlined.single.style!.decorationStyle, TextDecorationStyle.wavy);
    expect(underlined.single.style!.decorationColor, kSpellErrorColor);
    // The underlines are decoration only: Flutter does not support gesture
    // recognisers on spans inside an editable field, so the corrections come
    // from the selection toolbar and the review dialog instead.
    expect(underlined.single.recognizer, isNull);
    expect(
      _leaves(span).map((leaf) => leaf.text).join(),
      'we need to recieve it',
      reason: 'decorating must not change the text',
    );
  });

  testWidgets('grammar slips get their own colour', (tester) async {
    final context = await _contextFor(tester);
    final controller = SpellCheckTextEditingController(text: 'we we need it');

    final span = controller.buildTextSpan(
      context: context,
      style: const TextStyle(fontSize: 14),
      withComposing: false,
    );

    final underlined = _leaves(span)
        .where((leaf) =>
            leaf.style?.decoration?.contains(TextDecoration.underline) ??
            false)
        .toList();
    expect(underlined, isNotEmpty);
    expect(underlined.first.style!.decorationColor, kGrammarErrorColor);
  });

  testWidgets('a clean text is painted untouched', (tester) async {
    final context = await _contextFor(tester);
    final controller =
        SpellCheckTextEditingController(text: 'we need the requirement');

    final span = controller.buildTextSpan(
      context: context,
      style: const TextStyle(fontSize: 14),
      withComposing: false,
    );

    expect(_firstUnderlinedText(span), isNull);
    expect(
      _leaves(span).map((leaf) => leaf.text).join(),
      'we need the requirement',
    );
  });

  testWidgets('spell checking can be switched off for a field',
      (tester) async {
    final context = await _contextFor(tester);
    final controller = SpellCheckTextEditingController(
      text: 'we recieve it',
      spellCheckEnabled: false,
    );

    final span = controller.buildTextSpan(
      context: context,
      style: const TextStyle(fontSize: 14),
      withComposing: false,
    );

    expect(_firstUnderlinedText(span), isNull);
  });

  testWidgets('markdown fields keep their text and still get underlines',
      (tester) async {
    final context = await _contextFor(tester);
    final controller =
        RichTextEditingController(text: '**bold** recieve this');

    final span = controller.buildTextSpan(
      context: context,
      style: const TextStyle(fontSize: 14),
      withComposing: false,
    );

    // The raw text keeps its markers — decoration must never mutate the value.
    expect(controller.text, '**bold** recieve this');
    expect(_firstUnderlinedText(span), 'recieve');
  });

  group('applying a correction', () {
    test('replaces only the flagged word', () {
      final controller =
          SpellCheckTextEditingController(text: 'we recieve the plan');
      final issue = spellIssuesIn(controller).single;

      applySpellReplacement(controller, issue, 'receive');

      expect(controller.text, 'we receive the plan');
      controller.dispose();
    });

    test('keeps the caret after the corrected word', () {
      final controller = SpellCheckTextEditingController(text: 'recieve it');
      controller.selection = const TextSelection.collapsed(offset: 10);
      final issue = spellIssuesIn(controller).single;

      applySpellReplacement(controller, issue, 'receive');

      expect(controller.text, 'receive it');
      // "recieve" and "receive" are the same length, so the caret does not move.
      expect(controller.selection.baseOffset, 10);
      controller.dispose();
    });

    test('changes every occurrence', () {
      final controller = SpellCheckTextEditingController(
        text: 'recieve this and recieve that',
      );

      final changed = replaceAllSpelling(controller, 'recieve', 'receive');

      expect(changed, 2);
      expect(controller.text, 'receive this and receive that');
      controller.dispose();
    });

    test('applies a grammar fix in place', () {
      final controller = SpellCheckTextEditingController(text: 'we  need it');
      final issue = spellIssuesIn(controller).single;

      expect(applySpellGrammarFix(controller, issue), isTrue);
      expect(controller.text, 'we need it');
      controller.dispose();
    });
  });

  group('the corrector is reachable from a plain field', () {
    // The review used to hang off the field's editor-action popup, which is only
    // rendered on fields that already have actions. A plain notes or plan area
    // therefore showed underlines with no way to open the corrector at all, so
    // every field now carries it in the selection menu.

    Future<EditableTextState> pumpField(
      WidgetTester tester,
      TextEditingController controller, {
      bool readOnly = false,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TextField(controller: controller, readOnly: readOnly),
          ),
        ),
      );
      return tester.state<EditableTextState>(find.byType(EditableText));
    }

    List<ContextMenuButtonItem> menuItems(
      WidgetTester tester,
      EditableTextState state,
      TextEditingController controller,
    ) {
      final menu = buildSpellCheckContextMenu(
        tester.element(find.byType(EditableText)),
        state,
        controller,
      );
      return (menu as AdaptiveTextSelectionToolbar).buttonItems!;
    }

    testWidgets('the menu always offers Spelling & grammar', (tester) async {
      final controller =
          SpellCheckTextEditingController(text: 'we need to recieve it');
      final state = await pumpField(tester, controller);

      final labels = menuItems(tester, state, controller)
          .map((item) => item.label)
          .toList();
      expect(labels, contains('Spelling & grammar…'));

      // Opening it reviews the whole field, not one word under the caret.
      final review = menuItems(tester, state, controller)
          .firstWhere((item) => item.label == 'Spelling & grammar…');
      review.onPressed!();
      await tester.pumpAndSettle();

      expect(find.text('Spelling and Grammar'), findsOneWidget);
      expect(find.textContaining('recieve'), findsWidgets);

      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    });

    testWidgets('a word under the caret gets its own entry', (tester) async {
      final controller =
          SpellCheckTextEditingController(text: 'we need to recieve it');
      final state = await pumpField(tester, controller);

      // Caret inside "recieve" (offset 12 is its second character).
      controller.selection = const TextSelection.collapsed(offset: 12);
      await tester.pump();

      final labels = menuItems(tester, state, controller)
          .map((item) => item.label)
          .toList();
      expect(labels, contains('Spelling: "recieve"…'));

      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    });

    testWidgets('the menu offers the one-click fix', (tester) async {
      final controller =
          SpellCheckTextEditingController(text: 'we need to recieve it');
      final state = await pumpField(tester, controller);

      controller.selection = const TextSelection.collapsed(offset: 12);
      await tester.pump();

      final fix = menuItems(tester, state, controller)
          .firstWhere((item) => item.label!.startsWith('Auto-correct to '));
      // The service matches the capitalisation the user typed, so a lowercase
      // word is corrected to a lowercase one.
      expect(fix.label, 'Auto-correct to "receive"');

      fix.onPressed!();
      await tester.pumpAndSettle();
      expect(controller.text, 'we need to receive it');

      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    });

    testWidgets('the menu can add the word to the dictionary', (tester) async {
      SpellCheckService.instance.debugClearUserLists();
      addTearDown(SpellCheckService.instance.debugClearUserLists);

      final controller =
          SpellCheckTextEditingController(text: 'we need to recieve it');
      final state = await pumpField(tester, controller);

      controller.selection = const TextSelection.collapsed(offset: 12);
      await tester.pump();

      final learn = menuItems(tester, state, controller)
          .firstWhere((item) => item.label!.startsWith('Add "'));
      expect(learn.label, 'Add "recieve" to dictionary');

      learn.onPressed!();
      await tester.pumpAndSettle();

      expect(SpellCheckService.instance.userWords, contains('recieve'));
      // Nothing was rewritten: the word is simply accepted from now on.
      expect(controller.text, 'we need to recieve it');

      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    });

    testWidgets('a read-only field offers no spelling entries', (tester) async {
      final controller =
          SpellCheckTextEditingController(text: 'we need to recieve it');
      final state = await pumpField(tester, controller, readOnly: true);

      final labels = menuItems(tester, state, controller)
          .map((item) => item.label)
          .where((label) => label != null && label.startsWith('Spelling'))
          .toList();
      expect(labels, isEmpty);

      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    });
  });

  testWidgets('a field renders the underlines end to end', (tester) async {
    final controller =
        SpellCheckTextEditingController(text: 'we need to recieve it');

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TextField(controller: controller),
        ),
      ),
    );

    // The EditableText paints the controller's span, which carries the wavy
    // underline for the typo.
    final editable = tester.widget<EditableText>(find.byType(EditableText));
    final span = editable.controller.buildTextSpan(
      context: tester.element(find.byType(EditableText)),
      style: const TextStyle(fontSize: 14),
      withComposing: false,
    );
    expect(_firstUnderlinedText(span), 'recieve');

    // Unmount before disposing so the field drops the controller first.
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
  });
}
