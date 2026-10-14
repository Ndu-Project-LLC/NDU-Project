// The stakeholder register is an 11-column editable table. On a phone that
// table cannot be read: it lives inside a horizontal scroll view, so the user
// sees the row number and the contact person's name and nothing else — every
// other column (organization, role, contact details, influence, interest,
// channel, owner, notes, actions) is off the right-hand edge behind a sideways
// drag, and the heading row is 2,000px wide.
//
// The register now renders one labelled card per stakeholder at phone width.
// That defect does not show up as an overflow — the table scrolls, so nothing
// is clipped — which is exactly why this test measures where each value ended
// up horizontally instead of only asking whether the page threw.
//
// The register is reached through the real screen (`StakeholderManagementScreen`)
// with the app's own provider stack, seeded through the project the screen
// reads, so this covers the screen and not just the widget.

// ignore_for_file: depend_on_referenced_packages
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ndu_project/models/project_data_model.dart';
import 'package:ndu_project/screens/stakeholders/stakeholder_management_screen.dart';
import 'package:ndu_project/widgets/editable_table.dart';

import '../../support/mobile_layout_audit.dart';

/// Names, organizations and roles that are unmistakable in a finder, and long
/// enough to have exercised the table's fixed column widths.
const List<(String, String, String)> _people = <(String, String, String)>[
  (
    'Chanda Mwansa',
    'Nkombo Village Water Trust',
    'Community Liaison Lead',
  ),
  (
    'Thandiwe Banda',
    'Lusaka City Council — Water Directorate',
    'Regulatory Affairs Officer',
  ),
  (
    'Joseph Mutale',
    'Copperbelt Agri-Finance Cooperative',
    'Field Coordinator',
  ),
];

ProjectDataModel _project() {
  final now = DateTime(2026, 10, 12);
  return ProjectDataModel(
    projectId: 'p-stakeholders',
    projectName: 'Agri-Fintech Platform',
    stakeholderEntries: <StakeholderEntry>[
      for (var i = 0; i < _people.length; i++)
        StakeholderEntry(
          id: 'stakeholder-$i',
          name: _people[i].$1,
          organization: _people[i].$2,
          role: _people[i].$3,
          influence: 'High',
          interest: 'High',
          channel: 'Weekly steering call',
          contactInfo: 'chanda.mwansa@example.com',
          owner: 'Programme Manager',
          notes: 'Prefers SMS over email. Speaks Bemba and Nyanja.',
          createdAt: now,
          updatedAt: now,
        ),
    ],
  );
}

/// Every match of [text] must sit inside the viewport: content that is present
/// but off the right-hand edge is the defect this whole file exists for.
void _expectInsideViewport(WidgetTester tester, String text, double width) {
  final finder = find.text(text);
  expect(finder, findsWidgets, reason: '"$text" should be on the page');
  for (var i = 0; i < finder.evaluate().length; i++) {
    final rect = tester.getRect(finder.at(i));
    expect(
      rect.left,
      greaterThanOrEqualTo(0),
      reason: '"$text" starts left of the viewport',
    );
    expect(
      rect.right,
      lessThanOrEqualTo(width + 0.5),
      reason: '"$text" is cut off at the right-hand edge (${rect.right} > '
          '$width) — on a phone the register must lay its columns out under '
          'each other, not off the side of the screen',
    );
  }
}

void main() {
  // The screen subscribes to Firestore on init and reads the signed-in user, so
  // both plugins are mocked the same way the responsiveness audit mocks them.
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });

  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  for (final viewport in kAuditViewports) {
    final width = viewport.width;

    testWidgets('the stakeholder register reads as cards at ${width.toInt()}px',
        (tester) async {
      final report = await auditScreenAtPhoneWidth(
        tester,
        'StakeholderManagementScreen',
        StakeholderManagementScreen.new,
        viewport: viewport,
        project: _project(),
        inspect: (tester) async {
          // The register is one of the screen's editable tables.
          expect(find.byType(EditableTable), findsWidgets,
              reason: 'the seeded register should render its table');

          // A card presentation has nothing to scroll sideways.
          final sideways = find.byWidgetPredicate(
            (widget) =>
                widget is SingleChildScrollView &&
                widget.scrollDirection == Axis.horizontal,
          );
          final tables = find.byType(EditableTable);
          for (var i = 0; i < tables.evaluate().length; i++) {
            expect(
              find.descendant(of: tables.at(i), matching: sideways),
              findsNothing,
              reason: 'an editable table on a phone must not scroll sideways',
            );
          }

          // Each column heading is now the label on the value in its own row.
          expect(find.text('CONTACT PERSON'), findsNWidgets(_people.length));
          expect(find.text('ROLE/TITLE'), findsNWidgets(_people.length));
          expect(find.text('RELATIONSHIP OWNER'), findsNWidgets(_people.length));

          // The decisive check: the second, third and tenth columns sat at
          // x = 296 / 456 / 1,436 in the table, so every one of these values
          // used to be off the edge of a phone.
          for (final (name, organization, role) in _people) {
            _expectInsideViewport(tester, name, width);
            _expectInsideViewport(tester, organization, width);
            _expectInsideViewport(tester, role, width);
          }
          _expectInsideViewport(tester, 'Programme Manager', width);
        },
      );

      expect(report.blockers, isEmpty,
          reason: 'the screen must lay out for the register to be audited:\n'
              '${report.rawBlockers.join('\n')}');

      // This screen carries other, recorded phone-width debt (its header and
      // the engagement-plan matrix). None of it may come from the table the
      // register is built with.
      final fromTable = report.overflows
          .where((overflow) => overflow.contains('editable_table.dart'))
          .toList();
      expect(fromTable, isEmpty,
          reason: 'the register table itself must fit a phone:\n'
              '${fromTable.join('\n')}');
    });
  }
}
