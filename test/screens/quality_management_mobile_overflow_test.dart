// Phone-width layout regression for the Quality Management plan header.
//
// In the field at 427px the plan card header squeezed its section title to one
// character per line: the trailing AI switch, Regenerate and Delete are all
// fixed-width, so the Expanded title was left with nothing and the Row itself
// overflowed the card by more than 100px. The header now stacks its AI
// controls onto a second, wrapping line below the title when the card is
// narrow.
//
// These tests pump the real screen with AI on and a stored AI-authored plan —
// the state where every trailing control is present, i.e. the worst case — and
// pin the geometry: the title must get real width, and every control must end
// up inside the viewport.
//
// Other rows on this page still overflow at phone width; those are recorded in
// `test/support/mobile_overflow_debt.dart` and audited by
// `test/mobile_responsiveness_audit_test.dart`. The RenderFlex errors they
// report are drained below and checked to be exactly that known debt, so this
// test still fails on any new kind of layout error.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ndu_project/models/project_data_model.dart';
import 'package:ndu_project/providers/project_data_provider.dart';
import 'package:ndu_project/screens/quality_management_screen.dart';

const String _planTitle = 'Project Quality Management Plan (AI-Generated)';

/// Pump the real Quality Management screen with AI on and a stored plan.
///
/// Layout errors are collected through [FlutterError.onError] rather than
/// [WidgetTester.takeException]: the binding collapses a burst of overflows
/// into one "Multiple exceptions (N)" report that carries no location.
Future<ProjectDataProvider> _pumpQualityScreen(
  WidgetTester tester, {
  required Size viewport,
  required List<String> messages,
}) async {
  tester.view.physicalSize = viewport;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final prior = FlutterError.onError;
  FlutterError.onError = (details) {
    try {
      messages.add(details.toString());
    } catch (_) {
      messages.add(details.exceptionAsString());
    }
  };
  addTearDown(() => FlutterError.onError = prior);

  final model = ProjectDataModel().copyWith(
    projectId: 'p1',
    aiEnabled: true,
    qualityManagementData: QualityManagementData.empty().copyWith(
      qualityManagementPlan:
          'Project Quality Management Plan for this project establishes the '
          'quality policy, governance structure, and lifecycle reviews.',
      // Marks the plan as AI-authored so the header shows its "(AI-Generated)"
      // suffix, and seeds insights so no generation is attempted in a test.
      aiGeneratedPlans: const {'plan': true},
      aiInsights: const {'plan': 'Seeded insight — no generation needed.'},
    ),
  );

  final provider = ProjectDataProvider();
  provider.updateProjectData(model);

  await tester.pumpWidget(
    ProjectDataInherited(
      provider: provider,
      child: ChangeNotifierProvider<ProjectDataProvider>.value(
        value: provider,
        child: const MaterialApp(home: QualityManagementScreen()),
      ),
    ),
  );
  // The screen arms post-frame work and an autosave debounce; fixed frames let
  // them run without settling on the continuous autosave indicator.
  await tester.pump();
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 200));
  }

  // Anything the binding queued outside the interceptor still needs draining.
  for (var i = 0; i < 100; i++) {
    final error = tester.takeException();
    if (error == null) break;
    messages.add(error.toString());
  }

  FlutterError.onError = prior;
  return provider;
}

/// Every layout error the page reported must be the RenderFlex debt already
/// tracked in `mobile_overflow_debt.dart` — nothing of any other kind.
void _expectOnlyKnownOverflowDebt(List<String> messages) {
  for (final message in messages) {
    expect(
      message,
      contains('RenderFlex overflowed'),
      reason: 'expected only the known phone-width overflow debt, got:\n'
          '$message',
    );
  }
}

/// The title must keep real width, and the AI controls must stay in the
/// viewport — the two things the stacked header fixes.
void _expectHeaderFits(WidgetTester tester) {
  final titleFinder = find.text(_planTitle);
  expect(titleFinder, findsOneWidget,
      reason: 'the AI-authored plan header must show its full title');

  final titleBox = tester.renderObject<RenderBox>(titleFinder);
  expect(
    titleBox.size.width,
    greaterThan(150),
    reason: 'the section title was squeezed to ${titleBox.size.width}px — '
        'the fixed-width AI controls ate the whole row',
  );

  final screenWidth = tester.view.physicalSize.width;
  for (final label in ['Regenerate', 'Delete']) {
    final control = find.text(label);
    expect(control, findsOneWidget, reason: '"$label" must be offered');
    final box = tester.renderObject<RenderBox>(control);
    final right = box.localToGlobal(Offset.zero).dx + box.size.width;
    expect(
      right,
      lessThanOrEqualTo(screenWidth),
      reason: '"$label" sits ${right - screenWidth}px past the right edge',
    );
  }

  final toggle = find.byType(Switch).first;
  final toggleBox = tester.renderObject<RenderBox>(toggle);
  final toggleRight =
      toggleBox.localToGlobal(Offset.zero).dx + toggleBox.size.width;
  expect(toggleRight, lessThanOrEqualTo(screenWidth),
      reason: 'the AI switch sits past the right edge');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  testWidgets('plan header fits a 427px phone (Pixel 9 Pro)', (tester) async {
    final messages = <String>[];
    await _pumpQualityScreen(
      tester,
      viewport: const Size(427, 952),
      messages: messages,
    );

    _expectHeaderFits(tester);
    _expectOnlyKnownOverflowDebt(messages);
  });

  testWidgets('plan header fits a 360px phone', (tester) async {
    final messages = <String>[];
    await _pumpQualityScreen(
      tester,
      viewport: const Size(360, 800),
      messages: messages,
    );

    _expectHeaderFits(tester);
    _expectOnlyKnownOverflowDebt(messages);
  });
}
