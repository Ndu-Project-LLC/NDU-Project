// Performance harness for the spell checker.
//
// `check()` runs on EVERY keystroke — it is called from
// SpellCheckTextEditingController.buildTextSpan, i.e. inside the frame build —
// so its cost is felt directly as typing latency on every field in the app.
// These benchmarks pin the cost of each stage so a regression shows up as a
// number rather than as "the app feels laggy".
//
// Methodology: each timed iteration uses a DISTINCT text, which is what typing
// does (the text changes every keystroke) and which deliberately misses the
// service's memo. A separate case measures the memo hit, which is the path taken
// by the second and later callers within one frame (the selection menu asking
// for the issue under the caret, the review dialog listing everything).
//
// Runs in the Dart VM (JIT), so absolute figures are not browser figures, but
// they are consistent run-to-run and are what the optimisations are compared
// against. Run with:
//
//   flutter test test/perf/spell_check_benchmark_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ndu_project/services/spell_check/spell_check_service.dart';
import 'package:ndu_project/widgets/spell_check/spell_checking_text_controller.dart';

/// The Requirements Plan text as the app generates it: ~1.6k characters of
/// ordinary prose, the common case for a large field.
const String _cleanPlan = '''
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

/// The same prose with the typos a real reviewer leaves behind. This is the
/// expensive case: every flagged word used to trigger a full dictionary search
/// during the scan itself.
const String _typoPlan = '''
### Requirements Plan

The Integrated Procurement Managment System project will adhere to the folowing requirments to ensure succesful execution and alignment with project milestones:

- Finalize Procurement Schedule: Complete the procurement schedule by April 30, 2026, aligning with key project milestones to facilite timely resource acquistion.
- Supplier Capability Analysis: Conduct a comprehensive analysis of supplier capabilites and market conditons, to be completed by the end of Q2 2026, ensuring selected vendors can meet project needs.
- Contingency Planning: Establish contingency plans for critical procurement items to mitigate risks of delays and ensure continuity in procurement activites.
- Supplier Evaluations: Complete supplier evaluations and selections by the end of Q2 2026, ensuring compliance with procurement policys and alignment with project goals.
- Compliance Monitoring: Continuously monitor compliance with procurement policies and regulations throughout the project's lifecycle, conducting regular audits to identify and address any discrepencies.
- Stakeholder Engagement: Provide regular updates to stakeholders regarding procurement progress and compliance status, utilizing a centralized communication platform for efficient information sharing.
''';

/// A ~13k-character document, to show how the cost scales with length.
String get _hugeText => List<String>.generate(8, (_) => _cleanPlan).join('\n');

double _baseline = 0;

String _report(String label, int iterations, int microseconds) {
  final perCall = microseconds / iterations;
  final ratio = _baseline == 0 ? 1.0 : perCall / _baseline;
  return '${label.padRight(50)} ${perCall.toStringAsFixed(1).padLeft(9)} us/call'
      '   ${ratio.toStringAsFixed(2)}x plan';
}

/// [count] variants of [base], each a different String so the scan runs for
/// real — the memo must not be able to serve them from one another.
List<String> _distinct(String base, int count) => List<String>.generate(
      count,
      (i) => '$base\nReviewed revision $i.',
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final service = SpellCheckService.instance;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await service.ensureLoaded();
  });

  int timeIt(String label, int iterations, void Function(int i) body) {
    for (var i = 0; i < 5; i++) {
      body(i); // warm up, so first-call JIT cost is not attributed to the run
    }
    final stopwatch = Stopwatch()..start();
    for (var i = 0; i < iterations; i++) {
      body(i);
    }
    stopwatch.stop();
    return stopwatch.elapsedMicroseconds;
  }

  test('dictionary is the real asset', () {
    expect(service.dictionarySize, greaterThan(200000));
  });

  test('check() on clean prose, text changing each keystroke', () {
    const iterations = 200;
    final texts = _distinct(_cleanPlan, iterations);
    final micros = timeIt('clean', iterations, (i) => service.check(texts[i]));
    _baseline = micros / iterations;
    // ignore: avoid_print
    print(_report('check(clean plan, ${_cleanPlan.length} chars) [distinct]',
        iterations, micros));
  });

  test('check() on prose with typos', () {
    const iterations = 200;
    final texts = _distinct(_typoPlan, iterations);
    final issues = service.check(_typoPlan).length;
    final micros = timeIt('typos', iterations, (i) => service.check(texts[i]));
    // ignore: avoid_print
    print(_report('check(plan with $issues typos) [distinct]', iterations, micros));
  });

  test('check() on a 13k-character document', () {
    final huge = _hugeText;
    const iterations = 20;
    final texts = _distinct(huge, iterations);
    final micros = timeIt('huge', iterations, (i) => service.check(texts[i]));
    // ignore: avoid_print
    print(_report('check(${huge.length} chars) [distinct]', iterations, micros));
  });

  test('repeat calls on one text — the memo hit', () {
    const iterations = 200;
    final micros = timeIt(
      'memo',
      iterations,
      (_) => service.check(_cleanPlan), // same instance every time
    );
    // ignore: avoid_print
    print(_report('check() memo hit (2nd+ caller in a frame)', iterations, micros));
  });

  test('decorateWithSpellCheck() builds the painted spans', () {
    const iterations = 200;
    final texts = _distinct(_cleanPlan, iterations);
    final micros = timeIt(
      'decorate',
      iterations,
      (i) => decorateWithSpellCheck(TextSpan(text: texts[i]), texts[i]),
    );
    // ignore: avoid_print
    print(_report('decorateWithSpellCheck(clean plan) [distinct]', iterations, micros));
  });

  test('suggest() for one misspelled word', () {
    const iterations = 400;
    final micros = timeIt('suggest', iterations, (_) => service.suggest('recieve'));
    // ignore: avoid_print
    print(_report('suggest("recieve") — on demand only', iterations, micros));
  });
}
