// Phone-width layout regression for the Project Plan page header.
//
// At 360px the page overflowed in five places. Every one was a Row that held
// free text as a fixed-width child, so the row was as wide as the text the user
// typed:
//
//   * the header title beside the "Edit Plan" button;
//   * the selected-project chip, sized to the whole project name (1,198px past
//     the edge with the demo project's name);
//   * the status / start / end badges;
//   * the "Project Plan Overview" section heading beside its chevron;
//   * the section card's heading beside its "Import from prior sections"
//     button.
//
// None of those are clipped-but-visible: content off the right edge is content
// the user cannot reach. These tests pump the real screen with a project name
// long enough to blow the header out, and check each control ends up inside the
// viewport, so the layout stays honest for any name the user types.

// ignore_for_file: depend_on_referenced_packages
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ndu_project/models/project_data_model.dart';
import 'package:ndu_project/screens/project_plan_screen.dart';

import '../support/mobile_layout_audit.dart';

/// A name long enough that the project chip cannot fit it on a phone — the
/// state that made the header overflow, not the three-word case that hides it.
const String _longProjectName =
    'Zambia Youth Agri-Fintech Platform — phase two rollout across Lusaka, '
    'Copperbelt and Southern provinces';

ProjectDataModel _project() => ProjectDataModel(
      projectId: 'p-project-plan',
      projectName: _longProjectName,
      solutionTitle: 'Agri-Fintech Platform',
    );

/// Every widget [finder] matches must start on screen and end inside it. A
/// control past the right edge is the defect this file exists for.
void _expectInsideViewport(WidgetTester tester, Finder finder, double width) {
  expect(finder, findsWidgets, reason: 'the control should be on the page');
  for (var i = 0; i < finder.evaluate().length; i++) {
    final rect = tester.getRect(finder.at(i));
    expect(rect.left, greaterThanOrEqualTo(0),
        reason: 'the control starts left of the viewport');
    expect(
      rect.right,
      lessThanOrEqualTo(width + 0.5),
      reason: 'the control is cut off at the right-hand edge (${rect.right} > '
          '$width) — on a phone it must wrap or elide, not sit off screen',
    );
  }
}

void main() {
  // The screen reads the signed-in user and subscribes to Firestore on init, so
  // the plugins are mocked the way the responsiveness audit mocks them.
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });

  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  for (final viewport in kAuditViewports) {
    final width = viewport.width;

    testWidgets('the project plan header fits ${width.toInt()}px',
        (tester) async {
      final report = await auditScreenAtPhoneWidth(
        tester,
        'ProjectPlanScreen',
        ProjectPlanScreen.new,
        viewport: viewport,
        project: _project(),
        inspect: (tester) async {
          // The chip shows the project name, elided rather than sized to it.
          // The name also appears as a "Project Name:" value in the details
          // card, so scope the finder to the header's dropdown.
          final chipName = find.descendant(
            of: find.byType(DropdownButton<String>),
            matching: find.text(_longProjectName),
          );
          expect(chipName, findsOneWidget,
              reason: 'the header must offer the selected project');
          final chipText = tester.widget<Text>(chipName);
          expect(chipText.overflow, TextOverflow.ellipsis,
              reason: 'a long project name must elide in the header chip');
          _expectInsideViewport(tester, chipName, width);

          // The badges sit either side by side or stacked, but always on screen.
          _expectInsideViewport(tester, find.text('Status: —'), width);
          _expectInsideViewport(tester, find.text('Start —'), width);
          _expectInsideViewport(tester, find.text('End —'), width);

          // The title and the "Edit Plan" button share the header row.
          _expectInsideViewport(tester, find.text('Project Plan'), width);
          _expectInsideViewport(tester, find.text('Edit Plan'), width);

          // The section card's heading keeps real width next to (or above) its
          // import action.
          _expectInsideViewport(tester, find.text('Overview'), width);
          _expectInsideViewport(
              tester, find.text('Import from prior sections'), width);
          final subtitle = tester.getRect(find.text(
              'Capture the intent, scope, and success criteria for this plan.'));
          expect(
            subtitle.width,
            greaterThan(150),
            reason: 'the card subtitle was squeezed to ${subtitle.width}px — '
                'the import button ate the whole row',
          );
        },
      );

      expect(report.blockers, isEmpty,
          reason: 'the page must lay out to be audited:\n'
              '${report.rawBlockers.join('\n')}');
      expect(report.overflows, isEmpty,
          reason: 'nothing on the page may sit off the edge of a phone:\n'
              '${overflowReport(report)}');
    });
  }
}
