// The bundled word list comes from /usr/share/dict/web2, which carries BASE
// forms only: it has "requirement" but never "requirements", "ensure" but never
// "ensuring". Because the checker originally tested membership alone, every
// regular inflection in generated prose was underlined — the wall of red across
// the Requirements Plan.
//
// These tests run against the REAL asset (no fixture dictionary), because the
// behaviour under test is precisely the coverage of that generated list plus the
// morphology layered on top of it.
//
// The other half of the contract matters just as much: morphology must not hide
// typos. English doubles a final consonant for a stem like "occur"+"ed", so
// "occurred" is accepted while "occured" stays flagged.

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ndu_project/services/spell_check/spell_check_service.dart';

SpellCheckService get _service => SpellCheckService.instance;

/// The Requirements Plan paragraph from the report, verbatim.
const String _plan = '''
### Requirements Plan

The Integrated Procurement Management System project will adhere to the following requirements to ensure successful execution and alignment with project milestones:

- Finalize Procurement Schedule: Complete the procurement schedule by April 30, 2026, aligning with key project milestones to facilitate timely resource acquisition.
- Supplier Capability Analysis: Conduct a comprehensive analysis of supplier capabilities and market conditions, to be completed by the end of Q2 2026, ensuring selected vendors can meet project needs.
- Contingency Planning: Establish contingency plans for critical procurement items to mitigate risks of delays and ensure continuity in procurement activities.
- Supplier Evaluations: Complete supplier evaluations and selections by the end of Q2 2026, ensuring compliance with procurement policies and alignment with project goals.
- Compliance Monitoring: Continuously monitor compliance with procurement policies and regulations throughout the project's lifecycle, conducting regular audits to identify and address any discrepancies.
- Stakeholder Engagement: Provide regular updates to stakeholders regarding procurement progress and compliance status, utilizing a centralized communication platform for efficient information sharing.
- Data Security Measures: Implement role-based access controls and data encryption for all sensitive procurement information, ensuring protection both at rest and in transit.
- Feedback Mechanisms: Create a structured feedback process to continuously improve procurement processes based on stakeholder input and insights.
''';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    _service.debugClearUserLists();
    await _service.ensureLoaded();
  });

  test('the generated list really is the real asset', () {
    expect(_service.isReady, isTrue);
    expect(_service.dictionarySize, greaterThan(200000));
  });

  test('the Requirements Plan paragraph has no false positives', () {
    final flagged = _service
        .check(_plan)
        .map((issue) => '${issue.word}@${issue.start}')
        .toList();

    expect(
      flagged,
      isEmpty,
      reason: 'valid inflections must not be underlined, found: $flagged',
    );
  });

  test('regular inflections of a known base are accepted', () {
    const inflections = <String>[
      // plurals and third person singular
      'requirements', 'capabilities', 'policies', 'activities',
      'discrepancies', 'processes', 'conditions', 'regulations', 'protocols',
      'insights', 'updates', 'evaluations', 'selections', 'measures',
      'approvals', 'goals', 'controls', 'mechanisms', 'items', 'risks',
      'delays', 'stakeholders', 'controls', 'columns',
      // participles and past tense
      'ensuring', 'planning', 'utilizing', 'integrating', 'monitoring',
      'aligning', 'conducting', 'sharing', 'completed', 'finalized',
      'integrated', 'aligned', 'selected', 'structured',
      // comparatives and adverbs
      'larger', 'strongest', 'successfully', 'automatically', 'simply',
    ];

    for (final word in inflections) {
      expect(_service.isWordKnown(word), isTrue,
          reason: '"$word" is a valid inflection and must not be flagged');
    }
  });

  test('a memoised scan is dropped when the dictionaries change', () async {
    // check() memoises its result per text so a frame costs one scan no matter
    // how many callers ask. The cache must still fall away when the user adds a
    // word, otherwise adding a correction would appear to do nothing.
    const text = 'We recieve the plan.';
    expect(_service.check(text).map((i) => i.word), contains('recieve'));

    await _service.addToUserDictionary('recieve');
    // Same String instance on purpose — a stale memo would answer from cache.
    expect(_service.check(text), isEmpty,
        reason: 'the user dictionary change must invalidate the cached scan');

    await _service.resetWord('recieve');
    expect(_service.check(text).map((i) => i.word), contains('recieve'),
        reason: 'removing the word must invalidate it again');
  });

  test('the doubling rule does not hide real typos', () {
    // "occur" doubles its r before -ed, so the undoubled spelling stays wrong.
    for (final typo in <String>[
      'occured', 'commited', 'recieve', 'seperate', 'managment', 'goverment',
    ]) {
      expect(_service.isWordKnown(typo), isFalse,
          reason: '"$typo" is a typo and must stay flagged');
    }

    // Both the doubling and the US no-doubling spellings are real words.
    for (final correct in <String>[
      'occurred', 'committed', 'beginning', 'planning', 'planned', 'stopped',
      'visited', 'targeted', 'budgeted', 'traveled', 'travelled', 'offered',
      'monitored', 'limited', 'repeated', 'permitted', 'referred',
    ]) {
      expect(_service.isWordKnown(correct), isTrue,
          reason: '"$correct" is a real word and must be accepted');
    }
  });
}
