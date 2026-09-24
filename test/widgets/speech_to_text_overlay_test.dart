import 'package:flutter/material.dart';
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
}
