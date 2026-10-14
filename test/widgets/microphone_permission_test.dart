import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ndu_project/widgets/voice_text_field.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The microphone disclosure is asked for exactly once: declining brings it
/// back next time, granting sticks — immediately for this session and, via
/// the persisted preference, for every future launch.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    resetMicrophonePermissionCacheForTest();
  });

  Future<BuildContext> pumpHost(WidgetTester tester) async {
    late BuildContext host;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            host = context;
            return const Scaffold(body: SizedBox.shrink());
          },
        ),
      ),
    );
    return host;
  }

  testWidgets('a grant stored by a previous launch skips the dialog',
      (tester) async {
    // Fresh session (cache cleared) but the preference already says granted —
    // exactly the state on the second app launch after saying yes once.
    SharedPreferences.setMockInitialValues({
      kMicrophonePermissionGrantedKey: true,
    });
    final context = await pumpHost(tester);

    expect(await requestMicrophonePermission(context), isTrue);
    await tester.pump();
    expect(find.text('Microphone Access'), findsNothing);
  });

  testWidgets('declining does not stick — the dialog comes back', (tester) async {
    final context = await pumpHost(tester);

    final first = requestMicrophonePermission(context);
    await tester.pumpAndSettle();
    expect(find.text('Microphone Access'), findsOneWidget);
    await tester.tap(find.text("Don't Allow"));
    await tester.pumpAndSettle();
    expect(await first, isFalse);

    // Still un-granted, so the user gets asked again rather than being
    // silently locked out of dictation.
    final second = requestMicrophonePermission(context);
    await tester.pumpAndSettle();
    expect(find.text('Microphone Access'), findsOneWidget);
    await tester.tap(find.text("Don't Allow"));
    await tester.pumpAndSettle();
    expect(await second, isFalse);
  });

  testWidgets('granting is asked for once and then sticks', (tester) async {
    final context = await pumpHost(tester);

    final first = requestMicrophonePermission(context);
    await tester.pumpAndSettle();
    expect(find.text('Microphone Access'), findsOneWidget);
    await tester.tap(find.text('Allow'));
    await tester.pumpAndSettle();
    expect(await first, isTrue);

    // The grant is persisted, so a fresh app launch (new process, same
    // storage) skips the dialog entirely.
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(kMicrophonePermissionGrantedKey), isTrue);

    final second = await requestMicrophonePermission(context);
    expect(second, isTrue);
    await tester.pump();
    expect(find.text('Microphone Access'), findsNothing);
  });
}
