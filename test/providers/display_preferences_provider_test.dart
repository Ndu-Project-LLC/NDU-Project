import 'package:flutter_test/flutter_test.dart';
import 'package:ndu_project/providers/display_preferences_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DisplayPreferencesProvider', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('loads defaults and derives the default text scale', () async {
      final provider = DisplayPreferencesProvider();
      await provider.load();

      expect(provider.fontSize, 'medium');
      expect(provider.textScaleFactor, 1.0);
      expect(provider.compactMode, isFalse);
      expect(provider.reduceAnimations, isFalse);
      expect(provider.speechToTextEnabled, isTrue);
    });

    test('updates observers immediately and persists across instances',
        () async {
      final provider = DisplayPreferencesProvider();
      await provider.load();
      var notifications = 0;
      provider.addListener(() => notifications++);

      await provider.setFontSize('large');
      await provider.setCompactMode(true);
      await provider.setReduceAnimations(true);
      await provider.setSpeechToTextEnabled(false);

      expect(provider.fontSize, 'large');
      expect(provider.textScaleFactor, 1.15);
      expect(provider.compactMode, isTrue);
      expect(provider.reduceAnimations, isTrue);
      expect(provider.speechToTextEnabled, isFalse);
      expect(notifications, 4);

      final restored = DisplayPreferencesProvider();
      await restored.load();
      expect(restored.fontSize, 'large');
      expect(restored.compactMode, isTrue);
      expect(restored.reduceAnimations, isTrue);
      expect(restored.speechToTextEnabled, isFalse);
    });

    test('normalizes unknown font size values to medium', () async {
      final provider = DisplayPreferencesProvider();
      await provider.setFontSize('extra-large');
      expect(provider.fontSize, 'medium');
      expect(provider.textScaleFactor, 1.0);
    });
  });
}
