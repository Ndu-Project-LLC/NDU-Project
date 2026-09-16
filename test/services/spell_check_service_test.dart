// The app-wide spell/grammar checker is deterministic and offline, so it is
// expected to behave exactly the same with AI switched off. These tests pin the
// two properties that matter most:
//
//   1. Precision — valid words, acronyms, identifiers, contractions, possessives
//      and hyphenated compounds are never underlined. A checker that cries wolf
//      is worse than no checker at all.
//   2. Recall for real typos — one-edit typos and the curated common
//      misspellings are reported with the right correction, and grammar slips
//      Word catches too (repeated words, double spaces, "could of", "alot").

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ndu_project/services/spell_check/spell_check_service.dart';

/// A small but realistic dictionary for the tests — the production list is
/// ~234k words loaded from an asset.
const List<String> _dictionary = <String>[
  'a',
  'and',
  'another',
  'bit',
  'could',
  'do',
  'done',
  'every',
  'for',
  'grid',
  'has',
  'have',
  'hello',
  'in',
  'is',
  'it',
  'need',
  'of',
  'one',
  'plan',
  'project',
  'receive',
  'received',
  'requirement',
  'requirements',
  'right',
  'separate',
  'site',
  'survey',
  'than',
  'that',
  'the',
  'their',
  'there',
  'this',
  'time',
  'we',
  'word',
  'words',
  'world',
  'you',
];

SpellCheckService get _service => SpellCheckService.instance;

List<String> _words(String text) =>
    _service.check(text).map((issue) => issue.word).toList();

SpellIssue _first(String text) => _service.check(text).first;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    _service
      ..debugClearUserLists()
      ..debugLoadWords(_dictionary);
  });

  group('valid words are never flagged', () {
    test('plain prose passes', () {
      expect(_words('we need the requirements that this project has'), isEmpty);
    });

    test('sentence-initial capitals pass', () {
      expect(_words('This is the plan.'), isEmpty);
    });

    test('acronyms pass', () {
      expect(_words('NDU KAZ WBS PBS KPI USD ZMW'), isEmpty);
    });

    test('identifiers and mixed-case product names pass', () {
      expect(_words('PowerBI iPhone kWh JavaScript'), isEmpty);
    });

    test('contractions pass', () {
      expect(
        _words("we don't have it, you're right, isn't it, we've done it"),
        isEmpty,
      );
    });

    test('possessives of known words pass', () {
      expect(_service.isWordKnown("project's"), isTrue);
      expect(_words("the project's plan"), isEmpty);
    });

    test('hyphenated compounds of known words pass', () {
      expect(_words('site-survey plan'), isEmpty);
    });

    test('single letters and numbers pass', () {
      expect(_words('a 3 x 4 grid'), isEmpty);
    });

    test('the project vocabulary is accepted', () {
      expect(_words('the WBS checkpoint for the stakeholder'), isEmpty);
    });
  });

  group('URLs, e-mails and dotted names are left alone', () {
    test('a bare URL passes', () {
      expect(_words('https://nduproject.com/docs'), isEmpty);
      expect(_words('www.nduproject.com'), isEmpty);
    });

    test('an e-mail address passes', () {
      expect(_words('user@gmail.com'), isEmpty);
      expect(_words('we need chungu.chama@nduproject.com for the plan'), isEmpty);
    });

    test('a file name passes', () {
      expect(_words('we need design.docx and the plan'), isEmpty);
      expect(_words('app.dart'), isEmpty);
    });

    test('a typo outside the URL is still reported', () {
      expect(
        _words('https://nduproject.com recieve the plan'),
        contains('recieve'),
      );
    });

    test('the range covers exactly the word after a URL', () {
      const text = 'https://nduproject.com recieve the plan';
      final issue =
          _service.check(text).firstWhere((i) => i.word == 'recieve');
      expect(text.substring(issue.start, issue.end), 'recieve');
    });
  });

  group('typos are reported with a correction', () {
    test('a transposed pair', () {
      final issue = _first('teh');
      expect(issue.kind, SpellIssueKind.spelling);
      expect(issue.suggestions, contains('the'));
    });

    test('a one-letter substitution', () {
      final issue = _first('recieve');
      expect(issue.word, 'recieve');
      expect(issue.suggestions, contains('receive'));
    });

    test('a curated misspelling resolves even without a close neighbour', () {
      _service.debugLoadWords(<String>['separate']);
      expect(_first('seperate').suggestions, contains('separate'));
    });

    test('suggestions keep the case the user typed', () {
      expect(_first('Recieve').suggestions, contains('Receive'));
    });

    test('the suggestion range covers exactly the word', () {
      const text = 'we need recieve this';
      final issue = _service
          .check(text)
          .firstWhere((i) => i.word == 'recieve');
      expect(text.substring(issue.start, issue.end), 'recieve');
    });

    test('run-together phrases are corrected', () {
      expect(_first('alot').suggestions, contains('a lot'));
    });

    test('issues come back in text order', () {
      final issues = _service.check('teh recieve');
      expect(issues.length, 2);
      expect(issues.first.start, lessThan(issues.last.start));
    });

    test('nothing is reported before the dictionary is ready', () {
      _service.debugLoadWords(<String>[], ready: false);
      expect(_service.isReady, isFalse);
      expect(_service.check('recieve teh'), isEmpty);
    });
  });

  group('grammar rules', () {
    test('a repeated word', () {
      final issue = _first('we we need the plan');
      expect(issue.kind, SpellIssueKind.grammar);
      expect(issue.message, 'Repeated word');
      expect(issue.replacement, '');
    });

    test('a double space between words', () {
      final issue = _first('hello  world');
      expect(issue.message, 'Extra space');
      expect(issue.replacement, ' ');
    });

    test('a space before punctuation', () {
      final issue = _first('hello , world');
      expect(issue.message, 'Remove the space before punctuation');
    });

    test('an uncapitalised sentence start', () {
      final issue = _first('This is the plan. another one');
      expect(issue.message, 'Capitalise the first word of a sentence');
      expect(issue.replacement, 'A');
    });

    test('abbreviations do not start a sentence', () {
      expect(_words('this is the plan, e.g. another one'), isEmpty);
    });

    test('a lowercase standalone i', () {
      final issue = _first('i think so');
      expect(issue.message, 'Use the capital "I"');
      expect(issue.replacement, 'I');
    });

    test('"could of" instead of "could have"', () {
      final issue = _first('we could of done it');
      expect(issue.replacement, 'could have');
    });

    test('spelling and grammar never describe the same characters twice', () {
      final issues = _service.check('teh teh requirement');
      for (final a in issues) {
        for (final b in issues) {
          if (identical(a, b)) continue;
          expect(a.start < b.end && b.start < a.end, isFalse,
              reason: '$a overlaps $b');
        }
      }
    });
  });

  group('the bundled dictionary', () {
    // The real asset, not the fixture above: this proves the generated list is
    // declared in pubspec, parses, and is big enough that ordinary prose passes.
    test('loads the generated word list', () async {
      await SpellCheckService.instance.ensureLoaded();

      expect(SpellCheckService.instance.isReady, isTrue);
      expect(
        SpellCheckService.instance.dictionarySize,
        greaterThan(200000),
        reason: 'the generated list should carry the full web2 vocabulary',
      );
      expect(
        _service.check(
          'The project requirements must meet the agreed scope and schedule.',
        ),
        isEmpty,
        reason: 'ordinary project prose must not be underlined',
      );
      expect(
        _service.check('This sentance has a typo').map((i) => i.word),
        contains('sentance'),
      );
      expect(_first('sentance').suggestions, contains('sentence'));
    });
  });

  group('the user dictionary', () {
    test('an ignored word stops being flagged', () async {
      expect(_words('chungu'), isNotEmpty);
      await _service.ignoreWord('chungu');
      expect(_words('chungu'), isEmpty);
    });

    test('an added word stops being flagged', () async {
      await _service.addToUserDictionary('Chungu');
      expect(_service.isWordKnown('chungu'), isTrue);
      expect(_words('chungu'), isEmpty);
    });

    test('ignoring and adding bump the revision so fields redraw', () async {
      final before = _service.revision;
      await _service.ignoreWord('chungu');
      expect(_service.revision, greaterThan(before));
    });

    test('learned project vocabulary is accepted', () async {
      expect(_words('Chungu Chipimo'), isNotEmpty);
      await _service.learnWords(<String>['Chungu Chipimo', 'Agri-Tech']);
      // Names, and both halves of a hyphenated term, are learned.
      expect(_words('Chungu Chipimo'), isEmpty);
      expect(_words('Agri-Tech'), isEmpty);
      expect(_service.isWordKnown('agri'), isTrue);
      expect(_service.isWordKnown('tech'), isTrue);
    });

    test('a word can be flagged again', () async {
      await _service.ignoreWord('chungu');
      await _service.resetWord('chungu');
      expect(_words('chungu'), isNotEmpty);
    });
  });
}
