// A section that fails while it is being built must not blank the page it
// sits on.
//
// The Design Phase pages are assembled in one scroll view from many
// independent sections, each produced by a `_buildStableXxx()` / `_buildWebXxx()`
// helper that walks project data inline. When one of those helpers throws, the
// framework's ErrorWidget takes over that slot — and with the app-wide policy
// hiding framework noise, a section that failed with one of those messages drew
// *nothing at all*: the user saw the page shell (sidebar + header) with an
// empty body, which is the reported symptom.
//
// `SafeSection` contains that blast radius around the place the page's own
// code runs: the failed section renders a compact card naming itself, every
// sibling keeps rendering, and the failure is printed so the console is never
// silent.
//
// Scope, deliberately: this guards the section's *construction*. An exception
// thrown later, by a nested widget's own `build` or during layout, happens
// outside this boundary — those are the app-wide policy's job (a visible error
// instead of a silent blank).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ndu_project/widgets/safe_section.dart';

Widget _healthy(BuildContext context) => const Text('Requirements Register');

/// Stands in for a `_buildStableXxx()` helper that throws while it assembles
/// the section — a null-check on missing project data, a bad index, and so on.
Widget _exploding(BuildContext context) =>
    throw StateError('Nested arrays are not supported');

void main() {
  testWidgets('a healthy section renders its own content', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: SafeSection(
          title: 'Requirements Register',
          builder: _healthy,
        ),
      ),
    ));

    expect(find.text('Requirements Register'), findsOneWidget);
    expect(find.byType(SectionErrorCard), findsNothing);
  });

  testWidgets('a failing section names itself and keeps its siblings',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: Column(
          children: [
            SafeSection(title: 'Traceability Matrix', builder: _healthy),
            SafeSection(title: 'Dependencies', builder: _exploding),
            SafeSection(title: 'Working Notes', builder: _healthy),
          ],
        ),
      ),
    ));

    // The failure is contained: it never reaches the framework, so it cannot
    // poison the page (or the frame) the way an unhandled build error does.
    expect(tester.takeException(), isNull);

    // The failed section says so — it does not render as nothing.
    expect(find.byType(SectionErrorCard), findsOneWidget);
    expect(find.text('"Dependencies" could not be displayed'), findsOneWidget);
    expect(
        find.textContaining('Nested arrays are not supported'), findsOneWidget);

    // And the rest of the page is untouched: both healthy sections still
    // render their content.
    expect(find.text('Requirements Register'), findsNWidgets(2));
  });

  testWidgets('the failure is printed, so a blank section is never silent',
      (tester) async {
    final printed = <String>[];
    final previous = debugPrint;
    try {
      debugPrint = (String? message, {int? wrapWidth}) {
        if (message != null) printed.add(message);
      };

      await tester.pumpWidget(const MaterialApp(
        home: SafeSection(title: 'System Architecture', builder: _exploding),
      ));
    } finally {
      // Restore before the body ends: the test binding asserts that foundation
      // debug variables are back in place when the test finishes.
      debugPrint = previous;
    }

    expect(tester.takeException(), isNull);
    expect(
      printed.any((line) =>
          line.contains('[SafeSection]') &&
          line.contains('System Architecture') &&
          line.contains('Nested arrays are not supported')),
      isTrue,
      reason: 'The failure must reach the console: $printed',
    );
  });
}
