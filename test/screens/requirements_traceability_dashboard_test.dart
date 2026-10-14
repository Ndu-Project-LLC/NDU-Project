import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ndu_project/models/design_phase_models.dart';
import 'package:ndu_project/models/project_data_model.dart';
import 'package:ndu_project/widgets/requirements_traceability_dashboard.dart';

/// Regression guard for [RequirementsTraceabilityDashboard] blanking its body.
///
/// The acceptance-criteria form builds each field row as a list of `Expanded`
/// children and then hands that same list to either a `Row` or, on narrow
/// viewports, a `Column`. The dashboard body lives in a vertical scroll view,
/// which gives its children unbounded height, so the `Column` branch threw
/// `RenderFlex children have non-zero flex but incoming height constraints are
/// unbounded` and blanked the page.
///
/// Testing the widget directly rather than the whole screen matters here: the
/// form sits far down a lazy scroll view, so a screen-level test never builds
/// it and passes vacuously.
void main() {
  final requirements = [
    RequirementRow(
      id: 'req-1',
      requirementId: 'REQ-001',
      title: 'Offline disbursement',
      owner: 'Amina',
      definition: 'The app must settle payouts without connectivity.',
      designArtifactLabel: 'Wireframes v2',
    ),
  ];

  Widget build(RequirementRow selected) {
    return MaterialApp(
      home: Scaffold(
        // A vertical scroll view is what makes the height unbounded; without
        // it the Column branch would not throw and the test would be vacuous.
        body: SingleChildScrollView(
          child: RequirementsTraceabilityDashboard(
            projectData: ProjectDataModel(),
            requirements: requirements,
            checklistItems: const [],
            ownerOptions: const ['Amina', 'Bala'],
            notesController: TextEditingController(),
            selectedRequirementIndex: 0,
            selectedRequirement: selected,
            showAllRows: true,
            onAddRequirement: () {},
            onRefreshContext: () {},
            onToggleShowAll: () {},
            onSelectRequirement: (_) {},
            onDeleteRequirement: (_) {},
            onArtifactTap: (_) {},
            onUpdateSelectedRequirement: (_) {},
            onUploadArtifact: (_) async {},
          ),
        ),
      ),
    );
  }

  // 700 and 1100 straddle the dashboard's own 720px and 1100px breakpoints,
  // and 1600 covers the wide layout.
  for (final width in [700.0, 1100.0, 1600.0]) {
    testWidgets('lays out the requirement detail form at ${width.toInt()}px',
        (tester) async {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(build(requirements.first));
      await tester.pump();

      final fatal = <String>[];
      for (var i = 0; i < 40; i++) {
        final error = tester.takeException();
        if (error == null) break;
        final text = error.toString();
        // The binding collapses a burst of layout errors into a single
        // "Multiple exceptions (N)" report, so a fatal layout failure can
        // surface with no layout detail attached. Treat any leftover report as
        // fatal rather than letting it pass unnoticed.
        if (text.contains('non-zero flex') ||
            text.contains('was not laid out') ||
            text.contains('incoming height constraints are unbounded') ||
            text.contains('Multiple exceptions')) {
          fatal.add(text.split('\n').first);
        }
      }

      expect(
        fatal,
        isEmpty,
        reason: 'A fatal layout error blanks the dashboard body.',
      );
      expect(find.text('Acceptance Criteria & Source Verification'),
          findsOneWidget);
    });
  }
}
