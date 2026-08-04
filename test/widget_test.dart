// Widget tests for the NDU Project app.
//
// These test real, dependency-light widgets. The old template test pumped
// `MyApp` (the Firebase-backed router app), which cannot run in a widget
// test without mocking Firebase — so it targets `MyHomePage` (the counter
// widget that lives in lib/main.dart) and the app theme instead.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ndu_project/main.dart' show MyHomePage;
import 'package:ndu_project/theme.dart';

void main() {
  testWidgets('MyHomePage counter increments on tap', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: MyHomePage(title: 'NDU')));

    // Counter starts at 0.
    expect(find.text('0'), findsOneWidget);
    expect(find.text('1'), findsNothing);

    // Tap the '+' icon and trigger a frame.
    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();

    // Counter incremented to 1.
    expect(find.text('0'), findsNothing);
    expect(find.text('1'), findsOneWidget);
  });

  testWidgets('MyHomePage renders its title', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: MyHomePage(title: 'NDU Project')));

    expect(find.text('NDU Project'), findsOneWidget);
    expect(find.byIcon(Icons.add), findsOneWidget);
  });

  test('light theme exposes the brand yellow primary', () {
    // The app's signature brand color — see lib/theme.dart lightPrimary.
    expect(lightTheme.colorScheme.primary, const Color(0xFFFFC812));
    // On-primary is dark ink for readable contrast on the yellow.
    expect(lightTheme.colorScheme.onPrimary, const Color(0xFF1C1C1C));
  });

  test('dark theme constructs and is genuinely dark', () {
    expect(darkTheme, isNotNull);
    expect(darkTheme.brightness, Brightness.dark);
    expect(darkTheme.colorScheme.surface.computeLuminance(), lessThan(0.5));
  });
}
