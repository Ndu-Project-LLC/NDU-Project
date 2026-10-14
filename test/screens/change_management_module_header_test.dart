// The Change Management module hosts its page in a plain Column
// (not the shared [ScrollableSectionHeader] the Schedule, Cost
// Estimate and Project Controls modules use). This smoke test pins
// the contract that matters either way: the same Development Set
// Up-style page header — back chevron, centered module title,
// Tasks (N) pill — renders above the section navigator, with the
// tab content below.
//
// The Tasks (N) pill in the header reads [ProjectDataInherited],
// which the real app provides above the router (see main.dart);
// this pump wraps the app the same way so the pill renders.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ndu_project/cost_estimate/providers/cost_estimate_provider.dart';
import 'package:ndu_project/providers/project_data_provider.dart';
import 'package:ndu_project/project_controls/providers/change_management_provider.dart';
import 'package:ndu_project/project_controls/providers/project_controls_provider.dart';
import 'package:ndu_project/project_controls/screens/change_management_module_screen.dart';
import 'package:ndu_project/schedule/providers/schedule_provider.dart';
import 'package:ndu_project/wbs/providers/wbs_provider.dart';
import 'package:ndu_project/widgets/unified_phase_header.dart';

// Reuse the module pump fixtures: provider setup plus the bounded
// pumps these module screens need (they host perpetual animations
// that `pumpAndSettle` would wait on forever).
import 'module_section_header_scroll_test.dart' as fixtures;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
      'the Change Management module shows the page header above its navigation',
      (tester) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // The change dashboard's 3:2 grid rows overflow under the
    // test font (Ahem draws every glyph at a full 1em, roughly
    // twice real text width) — a pre-existing test-metrics
    // artifact in the dashboard content, unrelated to the page
    // header. Once a second exception is pending, the test
    // framework replaces them with an aggregate placeholder that
    // hides the individual messages, so capture the raw
    // [FlutterErrorDetails] instead and inspect each one after
    // the pumps. The binding restores the real handler when the
    // test completes.
    final layoutErrors = <FlutterErrorDetails>[];
    FlutterError.onError = (FlutterErrorDetails details) =>
        layoutErrors.add(details);

    final projectProvider = ProjectDataProvider();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<CostEstimateProvider>.value(
              value: fixtures.readyCostEstimate()),
          ChangeNotifierProvider<WBSProvider>.value(
              value: await fixtures.readyWbs(tester)),
          ChangeNotifierProvider<ScheduleProvider>.value(
              value: await fixtures.readySchedule(tester)),
          ChangeNotifierProvider<ProjectDataProvider>.value(
              value: projectProvider),
          ChangeNotifierProvider<ProjectControlsProvider>(
              create: (_) => ProjectControlsProvider()),
          ChangeNotifierProvider<ChangeManagementProvider>(
              create: (_) => ChangeManagementProvider()..seedDemoData()),
        ],
        child: ProjectDataInherited(
          provider: projectProvider,
          child: const MaterialApp(home: ChangeManagementModuleScreen()),
        ),
      ),
    );
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 120));
    }

    // The page header (desktop ≥1200px): white bar with the back
    // chevron, centered module title and the outstanding-tasks
    // pill. Scope the finders to the header — the sidebar also
    // lists the module by name.
    final header = find.byType(UnifiedPhaseHeader);
    expect(header, findsOneWidget);
    expect(
      find.descendant(
          of: header, matching: find.byIcon(Icons.arrow_back_ios)),
      findsOneWidget,
    );
    expect(
      find.descendant(of: header, matching: find.text('Change Management')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: header, matching: find.text('Tasks (0)')),
      findsOneWidget,
    );

    // The section navigator and tabs sit under the header.
    expect(find.text('Change Management Navigation'), findsOneWidget);
    expect(find.byType(TabBarView), findsOneWidget);

    // Tolerate the known dashboard overflows; anything else is a
    // real regression.
    for (final details in layoutErrors) {
      final message = details.exception.toString();
      expect(message.contains('RenderFlex overflowed'), isTrue,
          reason: 'unexpected layout error: $message');
    }
  });
}
