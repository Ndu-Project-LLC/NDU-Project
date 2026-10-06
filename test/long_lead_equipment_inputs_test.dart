import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ndu_project/models/project_data_model.dart';
import 'package:ndu_project/providers/project_data_provider.dart';
import 'package:ndu_project/screens/long_lead_equipment_ordering_screen.dart';

/// Regression tests for the three constrained inputs on the Long Lead
/// Equipment Ordering screen.
///
/// They were all free-text `TextField`s, which meant categories were typed from
/// memory and never matched across projects, lead times accepted anything
/// including "as soon as possible", and owners were invented rather than drawn
/// from the people actually registered on the project.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  const team = ['Amina Banda', 'Bala Zulu', 'Chanda Mwape'];

  Future<void> openCategoryDialog(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final provider = ProjectDataProvider();
    provider.updateProjectData(ProjectDataModel(
      projectName: 'Zala connect',
      teamMembers: [
        TeamMember(name: 'Amina Banda', role: 'Procurement Lead'),
        TeamMember(name: 'Bala Zulu', role: 'Design Lead'),
        TeamMember(name: 'Chanda Mwape', role: 'Site Manager'),
      ],
    ));
    addTearDown(provider.reset);

    await tester.pumpWidget(
      ChangeNotifierProvider<ProjectDataProvider>.value(
        value: provider,
        child: const MaterialApp(
          home: Scaffold(body: LongLeadEquipmentOrderingScreen()),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    await tester.tap(find.text('Create item').first);
    // The screen keeps a loading spinner running with no Firestore behind it,
    // so pumpAndSettle would never return; settle by frame count instead.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // This screen's header row has a pre-existing overflow that is unrelated
    // to the dialog. Drain it so it does not mask a real failure. takeException
    // collapses a burst into one "Multiple exceptions" report carrying no
    // detail, so everything queued here is discarded by design.
    for (var i = 0; i < 100; i++) {
      if (tester.takeException() == null) break;
    }

    // updateProjectData arms a 2s auto-save debounce; drain it so the binding
    // does not fail the test on a pending timer.
    await tester.pump(const Duration(seconds: 3));
    await provider.flushAutoSave();
  }

  testWidgets('Category is a dropdown listing the whole taxonomy',
      (tester) async {
    await openCategoryDialog(tester);
    expect(find.text('Add equipment category'), findsOneWidget);

    await tester.tap(find.byType(DropdownButtonFormField<String>).first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    for (final category
        in LongLeadEquipmentOrderingScreen.equipmentCategoryOptions) {
      expect(
        find.text(category),
        findsWidgets,
        reason: '"$category" should be offered as an equipment category.',
      );
    }
  });

  testWidgets('Lead time threshold is a numeric amount plus a unit',
      (tester) async {
    await openCategoryDialog(tester);

    final amount = find.widgetWithText(TextField, 'Lead time threshold');
    expect(amount, findsOneWidget);

    final field = tester.widget<TextField>(amount);
    // A lead time is a quantity: the amount must not accept letters.
    expect(field.keyboardType, TextInputType.number);
    expect(field.inputFormatters, isNotEmpty);

    // The unit is chosen from a dropdown rather than typed alongside the number.
    expect(find.widgetWithText(TextField, 'Unit'), findsNothing);
    expect(
      find.descendant(of: find.byType(AlertDialog), matching: find.text('Unit')),
      findsWidgets,
    );
  });

  testWidgets('Owner is a dropdown of the registered users', (tester) async {
    await openCategoryDialog(tester);

    final dropdowns = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(DropdownButtonFormField<String>),
    );
    // Category, Criticality, the lead-time Unit, and Owner.
    expect(dropdowns, findsNWidgets(4));

    await tester.tap(dropdowns.last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    for (final member in team) {
      expect(
        find.text(member),
        findsWidgets,
        reason: 'Registered user "$member" should be selectable as owner.',
      );
    }
  });
}
