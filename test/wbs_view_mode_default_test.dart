import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ndu_project/wbs/providers/wbs_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pump() async {
    // WBSProvider's constructor kicks off an async SharedPreferences load;
    // let it settle before assertions.
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }

  test('fresh page load defaults to Simple view', () async {
    SharedPreferences.setMockInitialValues({}); // no stored state at all
    final provider = WBSProvider();
    await pump();
    expect(provider.viewModeSimple, isTrue,
        reason: 'Simple must be the default view on page load');
  });

  test('legacy storage with viewModeSimple:false no longer forces Advanced',
      () async {
    // Simulates a returning user whose legacy localStorage captured the old
    // Advanced default — the provider must ignore the stored view mode so
    // every page load starts on Simple.
    SharedPreferences.setMockInitialValues({
      'ndu_wbs_v2':
          '{"state":{"setupComplete":true,"viewModeSimple":false,"wbs":null}}',
    });
    final provider = WBSProvider();
    await pump();
    expect(provider.viewModeSimple, isTrue,
        reason: 'stored view mode must be ignored; Simple is always default');
  });

  test('setViewMode still toggles within the session', () async {
    SharedPreferences.setMockInitialValues({});
    final provider = WBSProvider();
    await pump();
    provider.setViewMode(false);
    expect(provider.viewModeSimple, isFalse);
    provider.setViewMode(true);
    expect(provider.viewModeSimple, isTrue);
  });
}
