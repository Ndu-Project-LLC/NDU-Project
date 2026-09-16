// The SSHER Add/Edit Safety Item dialog lists Department, Team Member and
// Risk Level side by side. Department and Risk Level have always been
// dropdowns; Team Member used to be free text. These tests pin the dropdown
// behaviour so it cannot regress, including the case where a row already
// carries a value that is no longer on the project team.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ndu_project/models/project_data_model.dart';
import 'package:ndu_project/providers/project_data_provider.dart';
import 'package:ndu_project/screens/ssher_add_safety_item_dialog.dart';

SsherItemInput _initial({
  String department = 'IT Security',
  String teamMember = '',
  String riskLevel = 'High',
}) =>
    SsherItemInput(
      department: department,
      teamMember: teamMember,
      concern: 'Loose cabling near the walkway',
      riskLevel: riskLevel,
      mitigation: 'Re-route and secure the cabling',
    );

/// Closes any open dropdown menu, then drains the provider's debounced
/// autosave so the test ends cleanly.
Future<void> _finish(WidgetTester tester) async {
  await tester.tapAt(const Offset(4, 4));
  await tester.pumpAndSettle();
  await tester.pump(const Duration(seconds: 3));
}

/// Opens [dialog] from a host button so `Navigator.pop` returns a value.
Future<void> _open(
  WidgetTester tester,
  AddSsherItemDialog dialog,
  void Function(SsherItemInput?) onResult, {
  ProjectDataProvider? provider,
}) async {
  Widget host = MaterialApp(
    home: Scaffold(
      body: Builder(
        builder: (context) => Center(
          child: ElevatedButton(
            onPressed: () async {
              onResult(await showDialog<SsherItemInput>(
                context: context,
                builder: (_) => dialog,
              ));
            },
            child: const Text('Open'),
          ),
        ),
      ),
    ),
  );

  if (provider != null) {
    host = ChangeNotifierProvider<ProjectDataProvider>.value(
      value: provider,
      child: host,
    );
  }

  await tester.pumpWidget(host);
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  testWidgets('renders Team Member as a dropdown beside the other two',
      (tester) async {
    await _open(
      tester,
      AddSsherItemDialog(
        accentColor: Colors.orange,
        icon: Icons.health_and_safety,
        heading: 'Add Safety Item',
        blurb: 'Record a workplace safety concern.',
        concernLabel: 'Safety Concern',
        teamMemberOptions: const ['Alice Mwale', 'Brian Tembo'],
        initialData: _initial(),
      ),
      (_) {},
    );

    // Department, Team Member and Risk Level are all dropdowns now.
    expect(find.byType(DropdownButtonFormField<String>), findsNWidgets(3));
    expect(find.text('Team Member'), findsOneWidget);
  });

  testWidgets('selecting a team member from the dropdown is saved',
      (tester) async {
    SsherItemInput? result;
    await _open(
      tester,
      AddSsherItemDialog(
        accentColor: Colors.orange,
        icon: Icons.health_and_safety,
        heading: 'Add Safety Item',
        blurb: 'Record a workplace safety concern.',
        concernLabel: 'Safety Concern',
        teamMemberOptions: const ['Alice Mwale', 'Brian Tembo'],
        initialData: _initial(),
      ),
      (value) => result = value,
    );

    // Second dropdown in the row is Team Member.
    await tester.tap(find.byIcon(Icons.arrow_drop_down).at(1));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Alice Mwale').last);
    await tester.pumpAndSettle();

    expect(find.text('Alice Mwale'), findsOneWidget);

    await tester.tap(find.text('Save Item'));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!.teamMember, 'Alice Mwale');
  });

  testWidgets('builds its options from the project team', (tester) async {
    final provider = ProjectDataProvider();
    provider.updateProjectData(
      ProjectDataModel().copyWith(
        projectId: 'p1',
        teamMembers: [
          TeamMember(name: 'Alice Mwale', role: 'Project Manager'),
          TeamMember(name: '', role: 'Analyst', email: 'brian@example.com'),
        ],
        staffingRequirements: [
          StaffingRequirement(personName: 'Chen Wei'),
        ],
        projectRoles: [
          RoleDefinition(title: 'Operations Lead'),
        ],
      ),
    );

    await _open(
      tester,
      AddSsherItemDialog(
        accentColor: Colors.orange,
        icon: Icons.health_and_safety,
        heading: 'Add Safety Item',
        blurb: 'Record a workplace safety concern.',
        concernLabel: 'Safety Concern',
        initialData: _initial(),
      ),
      (_) {},
      provider: provider,
    );

    await tester.tap(find.byIcon(Icons.arrow_drop_down).at(1));
    await tester.pumpAndSettle();

    // Team members first, then the staffing plan and project roles; a member
    // with no name falls back to their email.
    expect(find.text('Alice Mwale'), findsOneWidget);
    expect(find.text('brian@example.com'), findsOneWidget);
    expect(find.text('Chen Wei'), findsOneWidget);
    expect(find.text('Operations Lead'), findsOneWidget);
    expect(find.text('Unassigned'), findsNothing);

    await _finish(tester);
  });

  testWidgets('keeps a saved value that is no longer on the team',
      (tester) async {
    SsherItemInput? result;
    await _open(
      tester,
      AddSsherItemDialog(
        accentColor: Colors.orange,
        icon: Icons.health_and_safety,
        heading: 'Edit Safety Item',
        blurb: 'Record a workplace safety concern.',
        concernLabel: 'Safety Concern',
        teamMemberOptions: const ['Alice Mwale'],
        initialData: _initial(teamMember: 'Legacy Person'),
      ),
      (value) => result = value,
    );

    expect(find.text('Legacy Person'), findsOneWidget);

    await tester.tap(find.text('Save Item'));
    await tester.pumpAndSettle();

    expect(result!.teamMember, 'Legacy Person');
  });

  testWidgets('never offers an empty list', (tester) async {
    final provider = ProjectDataProvider();
    provider.updateProjectData(ProjectDataModel().copyWith(projectId: 'p1'));

    await _open(
      tester,
      AddSsherItemDialog(
        accentColor: Colors.orange,
        icon: Icons.health_and_safety,
        heading: 'Add Safety Item',
        blurb: 'Record a workplace safety concern.',
        concernLabel: 'Safety Concern',
        initialData: _initial(),
      ),
      (_) {},
      provider: provider,
    );

    await tester.tap(find.byIcon(Icons.arrow_drop_down).at(1));
    await tester.pumpAndSettle();

    expect(find.text('Unassigned'), findsOneWidget);

    await _finish(tester);
  });

  testWidgets('still requires a team member', (tester) async {
    SsherItemInput? result;
    await _open(
      tester,
      AddSsherItemDialog(
        accentColor: Colors.orange,
        icon: Icons.health_and_safety,
        heading: 'Add Safety Item',
        blurb: 'Record a workplace safety concern.',
        concernLabel: 'Safety Concern',
        teamMemberOptions: const ['Alice Mwale'],
        initialData: _initial(),
      ),
      (value) => result = value,
    );

    await tester.tap(find.text('Save Item'));
    await tester.pumpAndSettle();

    expect(result, isNull);
    expect(find.text('Required'), findsOneWidget);
  });
}
