import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ndu_project/models/project_data_model.dart';
import 'package:ndu_project/providers/project_data_provider.dart';
import 'package:ndu_project/schedule/providers/schedule_provider.dart';
import 'package:ndu_project/services/planning_sync_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('sync flow populates schedule tree from planning data',
      (tester) async {
    final scheduleProvider = ScheduleProvider();
    final dataProvider = ProjectDataProvider();
    dataProvider.updateField((d) {
      var milestones = <Milestone>[];
      for (var i = 1; i <= 7; i++) {
        milestones.add(Milestone(
          id: 'm$i',
          name: 'Milestone $i',
          dueDate: '2026-${i.toString().padLeft(2, '0')}-01',
          discipline: '',
          comments: '',
        ));
      }
      return d.copyWith(
        projectName: 'Test Project',
        overallFramework: 'Waterfall',
        keyMilestones: milestones,
        workPackages: const [],
      );
    });

    scheduleProvider.setup(projectName: 'Test Project', deliveryModel: 'WATERFALL');

    await tester.pumpWidget(
      ChangeNotifierProvider<ProjectDataProvider>.value(
        value: dataProvider,
        child: MaterialApp(
          home: Builder(builder: (context) {
            return TextButton(
              onPressed: () {},
              child: const Text('x'),
            );
          }),
        ),
      ),
    );

    final context = tester.element(find.byType(MaterialApp));
    await PlanningSyncService.syncAll(context: context, provider: scheduleProvider);

    final root = scheduleProvider.schedule!.activities[0];
    debugPrint('REPRO children: ${root.children.length}');
    for (final c in root.children) {
      debugPrint('REPRO child: ${c.name} src=${c.importSource} children=${c.children.length}');
    }
    expect(root.children.any((c) => c.name == 'Planning Milestones'), isTrue,
        reason: 'milestone group should be imported');

    // Cancel the auto-save debounce timer so the test framework's
    // pending-timer check passes.
    dataProvider.dispose();
  });
}
