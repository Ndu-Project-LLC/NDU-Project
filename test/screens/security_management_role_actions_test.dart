import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ndu_project/providers/project_data_provider.dart';
import 'package:ndu_project/screens/security_management_screen.dart';
import 'package:provider/provider.dart';

/// The Roles table's Edit and Permissions buttons used to do nothing. These
/// tests open each dialog from its row and check it shows that row's data.
/// They cancel out of the dialogs, so nothing is saved and no Firebase is
/// needed.
void main() {
  Future<void> pumpRolesTab(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      ChangeNotifierProvider<ProjectDataProvider>(
        create: (_) => ProjectDataProvider(),
        child: const MaterialApp(home: SecurityManagementScreen()),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Roles').first);
    await tester.pump(const Duration(milliseconds: 500));
  }

  testWidgets('Edit opens the role dialog prefilled with that row',
      (tester) async {
    await pumpRolesTab(tester);

    // Manager is the second demo row.
    await tester.tap(find.widgetWithText(OutlinedButton, 'Edit').at(1));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Edit role'), findsOneWidget);
    final fields = tester
        .widgetList<TextField>(find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(TextField),
        ))
        .map((field) => field.controller?.text)
        .toList();
    expect(fields, containsAll(['Manager', 'Tier 2']));
    expect(find.text('Save'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Cancel'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('Permissions opens the checklist for that role', (tester) async {
    await pumpRolesTab(tester);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Permissions').at(0));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Permissions for Admin'), findsOneWidget);
    expect(find.byType(CheckboxListTile), findsWidgets);
    expect(find.text('Create Contract'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Cancel'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(AlertDialog), findsNothing);
  });
}
