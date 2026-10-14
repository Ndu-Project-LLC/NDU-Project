import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ndu_project/cost_estimate/providers/cost_estimate_provider.dart';
import 'package:ndu_project/models/project_data_model.dart'
    hide ScheduleActivity;
import 'package:ndu_project/providers/project_data_provider.dart';
import 'package:ndu_project/schedule/models/schedule_models.dart';
import 'package:ndu_project/schedule/providers/schedule_provider.dart';
import 'package:ndu_project/schedule/screens/list_view_screen.dart';
import 'package:ndu_project/schedule/services/schedule_cpm_service.dart';

/// The Schedule List View table must let the user delete an activity, using the
/// same confirmation as the Builder: cancelling keeps it, confirming removes it
/// together with any nested rows.
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  ScheduleProvider providerWith(List<ScheduleActivity> children) {
    final provider = ScheduleProvider();
    provider.setup(
        projectName: 'Test Project',
        deliveryModel: 'WATERFALL',
        projectId: 'p1');
    provider.setActivities([
      provider.schedule!.activities.first.copyWith(children: children),
    ]);
    return provider;
  }

  // Distinct codes keep the table's default code sort deterministic, so a
  // row's position in the table is known from its code.
  ScheduleActivity row(String id, String code, String name,
      {List<ScheduleActivity> children = const []}) {
    return ScheduleActivity(
      id: id,
      level: 1,
      code: code,
      name: name,
      type: ActivityType.summary,
      domain: ScheduleDomain.engineering,
      dependencies: const [],
      aiGenerated: false,
      children: children,
    );
  }

  ProjectDataProvider projectDataProvider() {
    final provider = ProjectDataProvider();
    provider.updateProjectData(ProjectDataModel(projectId: 'p1'));
    // updateProjectData arms a debounced Firebase autosave; disposing cancels
    // it, which the binding requires once the tree is torn down.
    addTearDown(provider.dispose);
    return provider;
  }

  /// Pumps three seconds of frames, outlasting the autosave debounce.
  Future<void> settle(WidgetTester tester, {int frames = 30}) async {
    for (var i = 0; i < frames; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> pumpListView(
    WidgetTester tester, {
    required ScheduleProvider scheduleProvider,
  }) async {
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ChangeNotifierProvider<ProjectDataProvider>.value(
        value: projectDataProvider(),
        child: MultiProvider(
          providers: [
            ChangeNotifierProvider<ScheduleProvider>.value(
              value: scheduleProvider,
            ),
            ChangeNotifierProvider<CostEstimateProvider>.value(
              value: CostEstimateProvider(),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(body: ListViewScreen()),
          ),
        ),
      ),
    );
    await settle(tester);
  }

  List<ScheduleActivity> liveActivities(ScheduleProvider provider) {
    return ScheduleCpmService.flatten(provider.schedule!.activities)
        .where((a) => a.level > 0)
        .toList();
  }

  /// Taps the delete button on the row at [index] (0-based, in table order).
  /// The Actions column sits past the right edge of the table, which scrolls
  /// horizontally, so bring the button into view before tapping it.
  Future<void> tapDeleteAt(WidgetTester tester, int index) async {
    final button = find.byIcon(Icons.delete_outline).at(index);
    await tester.ensureVisible(button);
    await tester.pump();
    await tester.tap(button);
    await settle(tester, frames: 8);
  }

  testWidgets('each live activity row has a delete button', (tester) async {
    final schedule = providerWith([
      row('a1', '1', 'Platform Foundation'),
      row('a2', '2', 'Controls Integration'),
    ]);
    await pumpListView(tester, scheduleProvider: schedule);

    expect(find.text('Platform Foundation'), findsWidgets);
    expect(find.byIcon(Icons.delete_outline), findsNWidgets(2));
  });

  testWidgets('asks first, and cancelling keeps the activity', (tester) async {
    final schedule = providerWith([row('a1', '1', 'Platform Foundation')]);
    await pumpListView(tester, scheduleProvider: schedule);

    await tapDeleteAt(tester, 0);

    expect(find.text('Delete activity'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await settle(tester, frames: 8);

    expect(find.text('Delete activity'), findsNothing);
    expect(
      liveActivities(schedule).map((a) => a.name),
      contains('Platform Foundation'),
      reason: 'a cancelled delete must leave the schedule untouched',
    );
  });

  testWidgets('confirming removes only that activity', (tester) async {
    final schedule = providerWith([
      row('a1', '1', 'Platform Foundation'),
      row('a2', '2', 'Controls Integration'),
    ]);
    await pumpListView(tester, scheduleProvider: schedule);

    await tapDeleteAt(tester, 0);
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await settle(tester, frames: 8);

    expect(
      liveActivities(schedule).map((a) => a.name),
      ['Controls Integration'],
    );
    expect(
        find.textContaining('Deleted "Platform Foundation"'), findsOneWidget);
  });

  testWidgets('says how many nested activities go with the parent',
      (tester) async {
    final schedule = providerWith([
      row(
        'a1',
        '1',
        'Platform Foundation',
        children: [
          row('a1a', '1.1', 'Design'),
          row('a1b', '1.2', 'Review'),
        ],
      ),
    ]);
    await pumpListView(tester, scheduleProvider: schedule);

    await tapDeleteAt(tester, 0);

    expect(
      find.textContaining('also deletes the 2 activities nested under it'),
      findsOneWidget,
    );
  });
}
