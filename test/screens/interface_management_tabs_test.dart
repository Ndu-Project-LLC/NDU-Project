// Regression test for the Interface Management screen crash.
//
// The page body lives inside a `SingleChildScrollView`, so any viewport
// widget (e.g. a `ListView.builder`) nested in it is given unbounded height
// and throws "Vertical viewport was given unbounded height" as soon as its
// data is non-empty — which took down the whole app the moment a project had
// interface entries. The register table's action cell also overflowed
// horizontally by 16px (two 48px IconButtons inside an 80px box).
//
// This test seeds interface entries, an audit-log entry, and then taps
// through every tab, asserting no layout exception is raised anywhere.
// ignore_for_file: depend_on_referenced_packages
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ndu_project/models/project_data_model.dart';
import 'package:ndu_project/providers/project_data_provider.dart';
import 'package:ndu_project/screens/interface_management_screen.dart';

/// Every tab on the screen, in the order they appear in the tab bar.
///
/// The Status Dashboard leads (Lusaka 27) and is the tab the screen opens on,
/// so the tests that are about the register select that tab explicitly.
const _tabLabels = [
  'Status Dashboard',
  'Interface Register',
  'Architecture',
  'RACI & Governance',
  'Risks & Decisions',
  'Dependencies',
  'Handoff Readiness',
  'Maturity',
  'Audit Trail',
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  Future<void> pumpScreen(
    WidgetTester tester, {
    Size size = const Size(2000, 1200),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final model = ProjectDataModel().copyWith(projectId: 'p1');
    final entryA = InterfaceEntry(
      boundary: 'Payment Gateway',
      owner: 'APIs Team',
      status: 'Open',
      criticality: 'Critical',
      risk: 'High',
      interfaceType: 'Technical',
      cadence: 'Weekly',
    );
    final entryB = InterfaceEntry(
      boundary: 'Data Warehouse',
      owner: 'Data Team',
      status: 'Approved',
      criticality: 'Major',
      risk: 'Low',
      cadence: 'Monthly',
    );
    model.interfaceEntries.addAll([entryA, entryB]);
    model.interfaceChangeLog.addAll([
      InterfaceChangeLogEntry(
        interfaceId: entryA.id,
        interfaceName: 'Payment Gateway',
        action: 'Created',
        changedAt: DateTime.now().toIso8601String(),
      ),
      InterfaceChangeLogEntry(
        interfaceId: entryB.id,
        interfaceName: 'Data Warehouse',
        action: 'Updated',
        fieldName: 'Status',
        oldValue: 'Pending',
        newValue: 'Approved',
        changedAt: DateTime.now().toIso8601String(),
      ),
    ]);

    final provider = ProjectDataProvider();
    provider.updateProjectData(model);

    await tester.pumpWidget(
      ProjectDataInherited(
        provider: provider,
        child: ChangeNotifierProvider<ProjectDataProvider>.value(
          value: provider,
          child: const MaterialApp(home: InterfaceManagementScreen()),
        ),
      ),
    );
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
  }

  /// Drains every recorded layout exception, so one failure never hides
  /// the others.
  List<Object> takeAllExceptions(WidgetTester tester) {
    final errors = <Object>[];
    Object? error;
    while ((error = tester.takeException()) != null) {
      errors.add(error!);
    }
    return errors;
  }

  /// Selects a tab by its label in the tab strip.
  Future<void> selectTab(WidgetTester tester, String label) async {
    final tab = find.widgetWithText(InkWell, label);
    expect(tab, findsOneWidget, reason: 'tab "$label" should exist');
    await tester.ensureVisible(tab);
    await tester.pump(const Duration(milliseconds: 250));
    await tester.tap(tab);
    await tester.pump(const Duration(milliseconds: 350));
  }

  testWidgets('renders the register tab with data without crashing',
      (tester) async {
    await pumpScreen(tester);
    await selectTab(tester, 'Interface Register');
    expect(takeAllExceptions(tester), isEmpty);
    expect(find.text('Payment Gateway'), findsWidgets);
  });

  testWidgets('renders the register tab at a wide desktop size without crashing',
      (tester) async {
    await pumpScreen(tester, size: const Size(2560, 1300));
    await selectTab(tester, 'Interface Register');
    expect(takeAllExceptions(tester), isEmpty);
    expect(find.text('Payment Gateway'), findsWidgets);
  });

  testWidgets('RACI & Governance says where its values come from',
      (tester) async {
    await pumpScreen(tester);
    await selectTab(tester, 'RACI & Governance');

    expect(takeAllExceptions(tester), isEmpty);

    // The owner's question was "this got filled up from where?", so the answer
    // is on the page, with a way into the register.
    expect(find.text('Where this matrix comes from'), findsOneWidget);
    expect(find.text('Open the register'), findsOneWidget);
    expect(find.textContaining('Party A (provider)'), findsWidgets);

    // The seeded interfaces have owners and cadences but no parties and no
    // last sync, so the tables must say exactly that — and the invented
    // 'Team' that used to fill the Informed column must be gone.
    expect(find.text('Team'), findsNothing);
    expect(find.text('Not set'), findsWidgets);
    expect(find.text('Never synced'), findsWidgets);
    expect(find.text('No owner'), findsNothing);

    // Coverage is counted on the same rows the table draws.
    expect(find.text('2 interfaces'), findsOneWidget);
    expect(find.text('0 with no accountable owner'), findsOneWidget);
    expect(find.text('2 never synced'), findsOneWidget);
    expect(find.text('Governance & Cadence'), findsOneWidget);
  });

  testWidgets('Open the register switches to the Interface Register tab',
      (tester) async {
    await pumpScreen(tester);
    await selectTab(tester, 'RACI & Governance');

    final link = find.text('Open the register');
    await tester.ensureVisible(link);
    await tester.pump(const Duration(milliseconds: 250));
    await tester.tap(link);
    await tester.pump(const Duration(milliseconds: 350));

    expect(takeAllExceptions(tester), isEmpty);
    // The register tab's own header action only renders on that tab.
    expect(find.text('Add Interface'), findsOneWidget);
    expect(find.text('Payment Gateway'), findsWidgets);
  });

  testWidgets('every tab renders on a narrow window without layout exceptions',
      (tester) async {
    // The RACI and governance tables switched to horizontal scrolling when the
    // window is narrower than their minimum width, so this is the path that
    // most easily goes wrong.
    await pumpScreen(tester, size: const Size(1000, 900));
    expect(takeAllExceptions(tester), isEmpty);

    final failures = <String>[];
    for (final label in _tabLabels) {
      await selectTab(tester, label);
      final errors = takeAllExceptions(tester);
      if (errors.isNotEmpty) {
        failures.add('$label → ${errors.first}');
      }
    }

    expect(failures, isEmpty,
        reason: 'Tabs crashed at 1000x900:\n${failures.join('\n')}');
  });

  testWidgets('every tab renders with seeded data without crashing',
      (tester) async {
    await pumpScreen(tester);
    expect(takeAllExceptions(tester), isEmpty);

    final failures = <String>[];
    for (final label in _tabLabels) {
      await selectTab(tester, label);

      final errors = takeAllExceptions(tester);
      if (errors.isNotEmpty) {
        failures.add('$label → ${errors.first}');
      }
    }

    expect(failures, isEmpty,
        reason: 'Tabs crashed with seeded interface entries:\n'
            '${failures.join('\n')}');
  });
}
