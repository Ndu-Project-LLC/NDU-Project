// The fix card is what a click on an underlined word opens, so these tests
// cover the whole conversation it offers: the one-click fix (and its Undo),
// the ranked suggestions, Add to dictionary, Ignore, Change all, and the fact
// that dismissing it changes nothing.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ndu_project/services/spell_check/spell_check_service.dart';
import 'package:ndu_project/widgets/spell_check/spell_checking_text_controller.dart';
import 'package:ndu_project/widgets/spell_check/spell_fix_popup.dart';

const List<String> _dictionary = <String>[
  'a',
  'and',
  'case',
  'is',
  'it',
  'plan',
  'project',
  'receive',
  'the',
  'this',
  'world',
];

SpellIssue _issueFor(String text, String word) => SpellCheckService.instance
    .check(text)
    .firstWhere((issue) => issue.word == word);

/// Hosts the card over a button so it has an overlay and a messenger, exactly
/// as it does inside a screen.
Future<void> _openCard(
  WidgetTester tester, {
  required TextEditingController controller,
  required SpellIssue issue,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              onPressed: () => showSpellFixPopup(
                context,
                controller: controller,
                issue: issue,
                anchorRect: const Rect.fromLTWH(40, 240, 80, 18),
              ),
              child: const Text('open card'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open card'));
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    SpellCheckService.instance.debugClearUserLists();
    SpellCheckService.instance.debugLoadWords(_dictionary);
  });

  testWidgets('offers the one-click fix, the suggestions and the learning '
      'actions', (tester) async {
    const text = 'The projct plan is set';
    final controller = SpellCheckTextEditingController(text: text);
    addTearDown(controller.dispose);

    await _openCard(tester, controller: controller, issue: _issueFor(text, 'projct'));

    expect(find.byKey(spellFixPopupKey), findsOneWidget);
    expect(find.text('projct'), findsOneWidget); // the flagged word
    expect(find.byKey(spellFixAutoCorrectKey), findsOneWidget);
    expect(find.byKey(spellFixSuggestionKey(0)), findsOneWidget);
    expect(find.byKey(spellFixAddToDictionaryKey), findsOneWidget);
    expect(find.byKey(spellFixIgnoreKey), findsOneWidget);
    // "Change all" only appears when the word repeats.
    expect(find.byKey(spellFixChangeAllKey), findsNothing);
  });

  testWidgets('auto-correct rewrites the word, and Undo puts it back',
      (tester) async {
    const text = 'The projct plan is set';
    final controller = SpellCheckTextEditingController(text: text);
    addTearDown(controller.dispose);

    await _openCard(tester, controller: controller, issue: _issueFor(text, 'projct'));
    await tester.tap(find.byKey(spellFixAutoCorrectKey));
    await tester.pumpAndSettle();

    expect(controller.text, 'The project plan is set');
    expect(find.byKey(spellFixPopupKey), findsNothing);

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(controller.text, text);
  });

  testWidgets('a picked suggestion keeps the capitalisation the user typed',
      (tester) async {
    const text = 'We Recieve the plan';
    final controller = SpellCheckTextEditingController(text: text);
    addTearDown(controller.dispose);

    // The service already matches the capitalisation the user typed.
    expect(SpellCheckService.instance.suggest('Recieve').first, 'Receive');

    await _openCard(
      tester,
      controller: controller,
      issue: _issueFor(text, 'Recieve'),
    );
    await tester.tap(find.byKey(spellFixSuggestionKey(0)));
    await tester.pumpAndSettle();

    expect(controller.text, 'We Receive the plan');
  });

  testWidgets('Add to dictionary accepts the word everywhere', (tester) async {
    const text = 'The courier crossed the Chongwe corridor';
    final controller = SpellCheckTextEditingController(text: text);
    addTearDown(controller.dispose);

    await _openCard(
      tester,
      controller: controller,
      issue: _issueFor(text, 'Chongwe'),
    );
    await tester.tap(find.byKey(spellFixAddToDictionaryKey));
    await tester.pumpAndSettle();

    expect(SpellCheckService.instance.userWords, contains('chongwe'));
    expect(find.byKey(spellFixPopupKey), findsNothing);
    // The word is no longer reported, so its underline is gone.
    expect(
      spellIssuesIn(controller).where((issue) => issue.word == 'Chongwe'),
      isEmpty,
    );
    expect(controller.text, text); // nothing was rewritten
  });

  testWidgets('Ignore stops the underline without teaching the dictionary',
      (tester) async {
    const text = 'The courier crossed the Chongwe corridor';
    final controller = SpellCheckTextEditingController(text: text);
    addTearDown(controller.dispose);

    await _openCard(
      tester,
      controller: controller,
      issue: _issueFor(text, 'Chongwe'),
    );
    await tester.tap(find.byKey(spellFixIgnoreKey));
    await tester.pumpAndSettle();

    expect(SpellCheckService.instance.ignoredWords, contains('chongwe'));
    expect(SpellCheckService.instance.userWords, isNot(contains('chongwe')));
    expect(
      spellIssuesIn(controller).where((issue) => issue.word == 'Chongwe'),
      isEmpty,
    );
  });

  testWidgets('Change all fixes every occurrence at once', (tester) async {
    const text = 'The projct plan needs a projct owner';
    final controller = SpellCheckTextEditingController(text: text);
    addTearDown(controller.dispose);

    await _openCard(
      tester,
      controller: controller,
      issue: _issueFor(text, 'projct'),
    );
    expect(find.byKey(spellFixChangeAllKey), findsOneWidget);
    await tester.tap(find.byKey(spellFixChangeAllKey));
    await tester.pumpAndSettle();

    expect(controller.text, 'The project plan needs a project owner');
  });

  testWidgets('Escape dismisses the card without changing the text',
      (tester) async {
    const text = 'The projct plan is set';
    final controller = SpellCheckTextEditingController(text: text);
    addTearDown(controller.dispose);

    await _openCard(
      tester,
      controller: controller,
      issue: _issueFor(text, 'projct'),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(find.byKey(spellFixPopupKey), findsNothing);
    expect(controller.text, text);
  });

  testWidgets('typing under the card closes it instead of fixing the wrong '
      'word', (tester) async {
    const text = 'The projct plan is set';
    final controller = SpellCheckTextEditingController(text: text);
    addTearDown(controller.dispose);

    await _openCard(
      tester,
      controller: controller,
      issue: _issueFor(text, 'projct'),
    );
    controller.text = 'The projct plan is set already';
    await tester.pumpAndSettle();

    expect(find.byKey(spellFixPopupKey), findsNothing);
  });

  testWidgets('a grammar issue offers its single correct fix', (tester) async {
    const text = 'The plan the the team agreed';
    final controller = SpellCheckTextEditingController(text: text);
    addTearDown(controller.dispose);

    final issue = SpellCheckService.instance
        .check(text)
        .firstWhere((issue) => issue.replacement != null);

    await _openCard(tester, controller: controller, issue: issue);
    expect(find.textContaining('Auto-correct'), findsOneWidget);

    await tester.tap(find.byKey(spellFixAutoCorrectKey));
    await tester.pumpAndSettle();
    expect(controller.text, 'The plan the team agreed');
    // A grammar rule is not vocabulary, so it cannot be learned.
    expect(find.byKey(spellFixAddToDictionaryKey), findsNothing);
  });

  testWidgets('a word with no suggestions says so instead of guessing',
      (tester) async {
    const text = 'The Qqxz plan';
    final controller = SpellCheckTextEditingController(text: text);
    addTearDown(controller.dispose);

    final issue = _issueFor(text, 'Qqxz');
    expect(issue.suggestions, isEmpty);

    await _openCard(tester, controller: controller, issue: issue);
    expect(find.byKey(spellFixAutoCorrectKey), findsNothing);
    expect(find.textContaining('No suggestions'), findsOneWidget);
    expect(find.byKey(spellFixAddToDictionaryKey), findsOneWidget);
  });
}
