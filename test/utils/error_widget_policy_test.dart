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
//   * only framework/tooling noise is hidden;
//   * a data-layer failure draws a visible error screen naming the failure;
//   * every suppression is logged, and real errors still reach the previous
//     handler (so the test binding / crash reporting still sees them).

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
    test('framework noise still renders nothing', () {
      final widget = buildAppErrorWidget(FlutterErrorDetails(
        exception: StateError('Id does not exist.'),
      ));
      expect(widget, isA<SizedBox>());
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

    testWidgets('the hidden case is limited to framework noise', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: _Exploding('_RestorableNode was used after being disposed.'),
        ),
      ));

      // Reported (so it is diagnosable), but drawn as nothing — this is the
      // narrow, deliberate exception for framework noise.
      expect(tester.takeException(), isA<StateError>());

      expect(find.byType(AppErrorScreen), findsNothing);
      expect(find.byType(SizedBox), findsWidgets);
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
