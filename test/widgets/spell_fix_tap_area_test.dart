// Clicking an underlined word is the gesture the whole feature hangs on, so
// these tests drive real clicks at real glyph positions through a real
// ExpandingTextFormField — the field in the Safety Concern screenshot — and
// check what the user gets: the fix card, a corrected word, a learned word, or
// nothing at all when the click missed every flagged word.

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderEditable;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ndu_project/services/spell_check/spell_check_service.dart';
import 'package:ndu_project/widgets/expanding_text_field.dart';
import 'package:ndu_project/widgets/spell_check/spell_checking_text_controller.dart';
import 'package:ndu_project/widgets/spell_check/spell_fix_popup.dart';

const List<String> _dictionary = <String>[
  'a',
  'an',
  'and',
  'corridor',
  'courier',
  'for',
  'is',
  'plan',
  'project',
  'safety',
  'the',
  'this',
  'uses',
  'world',
];

/// The field's text layer, which is what maps a click to a character.
RenderEditable _editable(WidgetTester tester) =>
    tester.state<EditableTextState>(find.byType(EditableText)).renderEditable;

/// Clicks the middle of [word] inside the field.
Future<void> _clickWord(WidgetTester tester, String text, String word) async {
  final editable = _editable(tester);
  final index = text.indexOf(word);
  expect(index, isNonNegative, reason: '"$word" must be in "$text"');

  final origin = editable.localToGlobal(Offset.zero);
  final caret = editable.getLocalRectForCaret(TextPosition(offset: index + 1));
  await tester.tapAt(origin + caret.center);
  await tester.pumpAndSettle();
}

Future<SpellCheckTextEditingController> _pumpField(
  WidgetTester tester, {
  required String text,
  bool readOnly = false,
  bool spellCheckEnabled = true,
}) async {
  final controller = SpellCheckTextEditingController(
    text: text,
    spellCheckEnabled: spellCheckEnabled,
  );
  addTearDown(controller.dispose);

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: ExpandingTextFormField(
            controller: controller,
            minLines: 3,
            readOnly: readOnly,
            decoration: const InputDecoration(
              labelText: 'Safety Concern',
              border: OutlineInputBorder(),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return controller;
}

/// The text of the first underline-decorated span in [controller], or null.
String? _underlinedText(
  SpellCheckTextEditingController controller,
  BuildContext context,
) {
  final span = controller.buildTextSpan(
    context: context,
    style: const TextStyle(),
    withComposing: false,
  );
  for (final leaf in _leaves(span)) {
    final decoration = leaf.style?.decoration;
    if (decoration != null && decoration.contains(TextDecoration.underline)) {
      return leaf.text;
    }
  }
  return null;
}

List<TextSpan> _leaves(InlineSpan span) {
  if (span is! TextSpan) return const <TextSpan>[];
  if ((span.text ?? '').isNotEmpty) return <TextSpan>[span];
  return <TextSpan>[
    for (final child in span.children ?? const <InlineSpan>[]) ..._leaves(child),
  ];
}

/// A context to build spans with, plus a place for the card.
Future<BuildContext> _pumpHost(WidgetTester tester, Widget child) async {
  late BuildContext captured;
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) {
            captured = context;
            return child;
          },
        ),
      ),
    ),
  );
  return captured;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    SpellCheckService.instance.debugClearUserLists();
    SpellCheckService.instance.debugLoadWords(_dictionary);
  });

  testWidgets('clicking an underlined word opens its fix card', (tester) async {
    const text = 'The courier uses a projct plan';
    await _pumpField(tester, text: text);

    expect(find.byKey(spellFixPopupKey), findsNothing);
    await _clickWord(tester, text, 'projct');

    expect(find.byKey(spellFixPopupKey), findsOneWidget);
    expect(find.text('projct'), findsOneWidget);
    expect(find.byKey(spellFixAutoCorrectKey), findsOneWidget);
  });

  testWidgets('clicking a word the checker accepts does nothing',
      (tester) async {
    const text = 'The courier uses a projct plan';
    final controller = await _pumpField(tester, text: text);

    await _clickWord(tester, text, 'courier');

    expect(find.byKey(spellFixPopupKey), findsNothing);
    expect(controller.text, text);
  });

  testWidgets('one click on the card fixes the word', (tester) async {
    const text = 'The courier uses a projct plan';
    final controller = await _pumpField(tester, text: text);

    await _clickWord(tester, text, 'projct');
    await tester.tap(find.byKey(spellFixAutoCorrectKey));
    await tester.pumpAndSettle();

    expect(controller.text, 'The courier uses a project plan');
    expect(find.byKey(spellFixPopupKey), findsNothing);
  });

  testWidgets('a tap on the field does not disturb the caret', (tester) async {
    const text = 'The courier uses a projct plan';
    final controller = await _pumpField(tester, text: text);

    await _clickWord(tester, text, 'courier');

    // The field still did its normal job: the caret moved where it was clicked.
    expect(
      controller.selection.baseOffset,
      inInclusiveRange('The '.length, 'The courier'.length),
    );
  });

  testWidgets('tapping outside the card dismisses it and changes nothing',
      (tester) async {
    const text = 'The courier uses a projct plan';
    final controller = await _pumpField(tester, text: text);

    await _clickWord(tester, text, 'projct');
    await tester.tapAt(const Offset(400, 560));
    await tester.pumpAndSettle();

    expect(find.byKey(spellFixPopupKey), findsNothing);
    expect(controller.text, text);
  });

  testWidgets('Add to dictionary clears the underline in every field at once',
      (tester) async {
    const text = 'The Chongwe corridor plan';
    final fieldController =
        SpellCheckTextEditingController(text: 'Chongwe corridor plan');
    addTearDown(fieldController.dispose);

    late BuildContext context;
    context = await _pumpHost(
      tester,
      Column(
        children: <Widget>[
          SizedBox(
            width: 600,
            child: ExpandingTextFormField(
              key: const Key('other'),
              controller: fieldController,
              minLines: 2,
              decoration: const InputDecoration(
                labelText: 'Mitigation Strategy',
                border: OutlineInputBorder(),
              ),
            ),
          ),
        ],
      ),
    );
    expect(_underlinedText(fieldController, context), 'Chongwe');

    // Now open the card in a second field and learn the word there.
    final controller = SpellCheckTextEditingController(text: text);
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(24),
            child: ExpandingTextFormField(
              controller: controller,
              minLines: 3,
              decoration: const InputDecoration(
                labelText: 'Safety Concern',
                border: OutlineInputBorder(),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await _clickWord(tester, text, 'Chongwe');
    await tester.tap(find.byKey(spellFixAddToDictionaryKey));
    await tester.pumpAndSettle();

    expect(SpellCheckService.instance.userWords, contains('chongwe'));
    // The second field, which has no idea the card exists, redraws too.
    expect(_underlinedText(fieldController, context), isNull);
    expect(
      spellIssuesIn(fieldController).where((i) => i.word == 'Chongwe'),
      isEmpty,
    );
  });

  testWidgets('a read-only field offers no fix card', (tester) async {
    const text = 'The courier uses a projct plan';
    final controller = await _pumpField(tester, text: text, readOnly: true);

    await _clickWord(tester, text, 'projct');

    expect(find.byKey(spellFixPopupKey), findsNothing);
    expect(controller.text, text);
  });

  testWidgets('a field with spell check switched off offers no fix card',
      (tester) async {
    const text = 'The courier uses a projct plan';
    await _pumpField(tester, text: text, spellCheckEnabled: false);

    await _clickWord(tester, text, 'projct');

    expect(find.byKey(spellFixPopupKey), findsNothing);
  });

  testWidgets('a drag from a flagged word does not open the card',
      (tester) async {
    const text = 'The courier uses a projct plan';
    await _pumpField(tester, text: text);

    final editable = _editable(tester);
    final origin = editable.localToGlobal(Offset.zero);
    final caret = editable.getLocalRectForCaret(
      TextPosition(offset: text.indexOf('projct') + 1),
    );
    final gesture = await tester.startGesture(origin + caret.center);
    await gesture.moveBy(const Offset(40, 0));
    await gesture.up();
    await tester.pumpAndSettle();

    expect(find.byKey(spellFixPopupKey), findsNothing);
  });
}
