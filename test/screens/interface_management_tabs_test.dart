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
const _tabLabels = [
  'Interface Register',
  'Architecture',
  'RACI & Governance',
  'Risks & Decisions',
  'Dependencies',
  'Handoff Readiness',
  'Maturity',
  'Status Dashboard',
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

  testWidgets('renders the register tab with data without crashing',
      (tester) async {
    await pumpScreen(tester);
    expect(takeAllExceptions(tester), isEmpty);
    expect(find.text('Payment Gateway'), findsWidgets);
  });

  testWidgets('renders the register tab at a wide desktop size without crashing',
      (tester) async {
    await pumpScreen(tester, size: const Size(2560, 1300));
    expect(takeAllExceptions(tester), isEmpty);
    expect(find.text('Payment Gateway'), findsWidgets);
  });

  testWidgets('every tab renders with seeded data without crashing',
      (tester) async {
    await pumpScreen(tester);
    expect(takeAllExceptions(tester), isEmpty);

    final failures = <String>[];
    for (final label in _tabLabels) {
      final tab = find.widgetWithText(InkWell, label);
      expect(tab, findsOneWidget, reason: 'tab "$label" should exist');

      await tester.ensureVisible(tab);
      await tester.pump(const Duration(milliseconds: 250));
      await tester.tap(tab);
      await tester.pump(const Duration(milliseconds: 350));

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
