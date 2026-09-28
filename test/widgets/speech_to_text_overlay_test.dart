import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ndu_project/providers/display_preferences_provider.dart';
import 'package:ndu_project/widgets/speech_to_text_overlay.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> pumpApp(
    WidgetTester tester, {
    required DisplayPreferencesProvider preferences,
    bool obscureText = false,
  }) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<DisplayPreferencesProvider>.value(
        value: preferences,
        child: MaterialApp(
          home: Scaffold(
            body: SpeechToTextOverlay(
              child: Center(
                child: TextField(obscureText: obscureText),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('offers dictation for a focused ordinary text field',
      (tester) async {
    final preferences = DisplayPreferencesProvider();
    await preferences.load();
    await pumpApp(tester, preferences: preferences);

    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();

    expect(find.text('Dictate'), findsOneWidget);
  });

  testWidgets('does not offer dictation for password fields', (tester) async {
    final preferences = DisplayPreferencesProvider();
    await preferences.load();
    await pumpApp(tester, preferences: preferences, obscureText: true);

    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();

    expect(find.text('Dictate'), findsNothing);
  });

  testWidgets('hides the contextual control immediately when disabled',
      (tester) async {
    final preferences = DisplayPreferencesProvider();
    await preferences.load();
    await pumpApp(tester, preferences: preferences);

    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();
    expect(find.text('Dictate'), findsOneWidget);

    await preferences.setSpeechToTextEnabled(false);
    await tester.pumpAndSettle();

    expect(find.text('Dictate'), findsNothing);
  });

  testWidgets('anchors the Dictate control inside the focused field',
      (tester) async {
    final preferences = DisplayPreferencesProvider();
    await preferences.load();
    await pumpApp(tester, preferences: preferences);

    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();

    final pill = tester.getRect(find.text('Dictate'));
    final field = tester.getRect(find.byType(TextField));

    // The control lives inside the field, not in a corner of the screen.
    expect(field.contains(pill.topLeft), isTrue,
        reason: 'Dictate pill should start inside the text field');
    expect(field.contains(pill.bottomRight), isTrue,
        reason: 'Dictate pill should end inside the text field');
  });

  testWidgets('once the microphone is allowed, dictation starts right away',
      (tester) async {
    // Answer the platform speech engine directly: under `flutter test` the
    // native macOS recognizer waits on an OS authorization prompt that can
    // never appear, so the mock stands in for it.
    const channel = MethodChannel('plugin.csdcorp.com/speech_to_text');
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (call) async {
      switch (call.method) {
        case 'initialize':
        case 'has_permission':
        case 'listen':
          return true;
      }
      return null;
    });
    addTearDown(
        () => messenger.setMockMethodCallHandler(channel, null));

    final preferences = DisplayPreferencesProvider();
    await preferences.load();
    await pumpApp(tester, preferences: preferences);

    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Dictate'));
    await tester.pumpAndSettle();
    expect(find.text('Microphone Access'), findsOneWidget);

    await tester.tap(find.text('Allow'));
    await tester.pumpAndSettle();

    // The permission dialog borrows focus while it is open; dictation must
    // still start right afterwards instead of being silently cancelled.
    // The pill flipping to its listening state is the proof.
    expect(find.text('Microphone Access'), findsNothing);
    expect(find.text('Stop'), findsOneWidget);

    // Stop again so the speech engine's internal listen timers are cleared
    // before the test tears down — and to prove the round trip works.
    await tester.tap(find.text('Stop'));
    await tester.pumpAndSettle();
    expect(find.text('Dictate'), findsOneWidget);

    // `stop()` arms the engine's 2s final-result timer; let it fire so no
    // timers are left pending when the test disposes the widget tree.
    await tester.pump(const Duration(milliseconds: 2100));
  });
}
