// A widget whose build throws must never render as *nothing*.
//
// The app's shared policy (`lib/utils/error_widget_policy.dart`) decides what a
// failed subtree shows. It used to return `SizedBox.shrink()` for a list of
// message fragments that included real data failures — Firestore's "Nested
// arrays are not supported" and listener "invalid state" errors — and the
// matching `FlutterError.onError` swallowed the same messages. The result was
// indistinguishable from an empty page: sidebar and header drew, the body came
// up blank, and the console said nothing. These tests pin down the fix:
//
//   * the screen never hides a failure — not even framework noise, because a
//     hidden widget at the root is a uniformly blank page;
//   * a data-layer failure draws a visible error screen naming the failure;
//   * noise stays out of the console (still logged, never silent), and real
//     errors still reach the previous handler (so the test binding / crash
//     reporting still sees them).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ndu_project/utils/error_widget_policy.dart';

class _Exploding extends StatelessWidget {
  const _Exploding(this.message);

  final String message;

  @override
  Widget build(BuildContext context) => throw StateError(message);
}

class _CapturingHandler {
  final List<String> reported = [];

  void call(FlutterErrorDetails details) =>
      reported.add(details.exceptionAsString());
}

void main() {
  late _CapturingHandler previous;
  late void Function(FlutterErrorDetails)? original;

  setUp(() {
    previous = _CapturingHandler();
    original = FlutterError.onError;
    FlutterError.onError = previous.call;
    installAppErrorHandling();
  });

  tearDown(() {
    FlutterError.onError = original;
    ErrorWidget.builder = ErrorWidget.new;
  });

  group('isBenignFrameworkNoise', () {
    test('hides framework and tooling noise', () {
      for (final message in const [
        'Id does not exist. The requested object was not found in the tree.',
        'A _RestorableNode was used after being disposed.',
        'ModalScopeStatus.of() called with a context that does not contain a '
            'ModalRoute.',
        'ListTile background color or ink splashes may be invisible.',
      ]) {
        expect(isBenignFrameworkNoise(message), isTrue, reason: message);
      }
    });

    test('does NOT hide data failures — those blanked pages', () {
      for (final message in const [
        'Bad state: Nested arrays are not supported',
        'Unsupported field value: nested arrays are not supported',
        'An error occurred while listening to the document: invalid state',
        'The document was saved with invalid state. Nested arrays',
        'Null check operator used on a null value',
        'type Null is not a subtype of type String',
      ]) {
        expect(isBenignFrameworkNoise(message), isFalse, reason: message);
      }
    });

    test('never matches a stack-trace fragment', () {
      // In a release build every frame contains `mode#`; matching it would
      // hide every error in the app.
      expect(isBenignFrameworkNoise('Exception: boom'), isFalse);
    });
  });

  group('what a failed subtree renders', () {
    test('framework noise renders a card, never nothing', () {
      // Hiding noise from the *screen* is what produced a uniformly blank
      // page with no console output: the failure still fired flutter-first-frame
      // (so the HTML loading spinner was removed) while its widget drew zero
      // pixels.
      for (final message in const [
        'Id does not exist.',
        '_RestorableNode was used after being disposed.',
        'ModalScopeStatus.of() called with a context that has no ModalRoute.',
        'ListTile background color or ink splashes may be invisible.',
      ]) {
        final widget = buildAppErrorWidget(
            FlutterErrorDetails(exception: StateError(message)));
        expect(widget, isA<AppErrorScreen>(), reason: message);
      }
    });

    test('a data failure renders a visible error screen', () {
      final widget = buildAppErrorWidget(FlutterErrorDetails(
        exception: StateError('Nested arrays are not supported'),
      ));
      expect(widget, isA<AppErrorScreen>());
    });

    testWidgets('a page section that throws a Firestore error is not blank',
        (tester) async {
      // The reported symptom: the shell (sidebar + header) draws and the body
      // is empty. With the policy installed the failure has to be visible.
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              Text('Page header'),
              Expanded(
                child: _Exploding('Nested arrays are not supported'),
              ),
            ],
          ),
        ),
      ));

      // The failure itself is still reported (to the handler, and to any crash
      // reporting) — only how it is *drawn* changed.
      expect(tester.takeException(), isA<StateError>());

      expect(find.byType(AppErrorScreen), findsOneWidget);
      expect(find.textContaining('Nested arrays are not supported'),
          findsWidgets);
      // The rest of the page keeps working.
      expect(find.text('Page header'), findsOneWidget);
    });

    testWidgets('a failure in a fixed-height slot does not blank the page',
        (tester) async {
      // The reported symptom, part two: the failure lands in a *fixed-height*
      // sibling slot — a page header inside a Column, or a child of a ListView
      // — rather than in an Expanded. That slot hands its child an unbounded
      // height. The fallback used to be a `Scaffold`, which cannot lay out
      // without a bounded parent: it threw `RenderCustomMultiChildLayoutBox ...
      // infinite size` during layout, which poisons the whole content subtree,
      // so the header and body both vanished while the sidebar kept drawing.
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              _Exploding('Nested arrays are not supported'),
              Expanded(child: SizedBox.shrink()),
            ],
          ),
        ),
      ));

      // Drain every queued report: a layout failure is reported *after* the
      // build failure, so stopping at the first exception would miss it.
      final seen = <Object>[];
      for (var i = 0; i < 50; i++) {
        final extra = tester.takeException();
        if (extra == null) break;
        seen.add(extra);
      }

      expect(find.byType(AppErrorScreen), findsOneWidget);
      expect(find.textContaining('Nested arrays are not supported'),
          findsWidgets);
      expect(
        seen.where((e) => e.toString().contains('infinite size')).toList(),
        isEmpty,
        reason: 'The fallback must lay out with an unbounded parent; it threw: '
            '$seen',
      );
    });

    testWidgets('even a framework-noise failure draws a visible screen',
        (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: _Exploding('_RestorableNode was used after being disposed.'),
        ),
      ));

      // Reported (so it is diagnosable) and drawn — never blank.
      expect(tester.takeException(), isA<StateError>());

      expect(find.byType(AppErrorScreen), findsOneWidget);
    });
  });

  group('the installed handler', () {
    test('logs suppressed noise but does not forward it', () {
      FlutterError.reportError(FlutterErrorDetails(
        exception: StateError('Id does not exist.'),
      ));
      expect(previous.reported, isEmpty);
    });

    test('forwards real errors to the previous handler', () {
      FlutterError.reportError(FlutterErrorDetails(
        exception: StateError('Bad state: Nested arrays are not supported'),
      ));
      expect(previous.reported.single,
          contains('Nested arrays are not supported'));
    });
  });
}
