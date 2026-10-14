import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ndu_project/cost_estimate/providers/cost_estimate_provider.dart';
import 'package:ndu_project/models/agile_task.dart';
import 'package:ndu_project/models/project_data_model.dart'
    hide ScheduleActivity;
import 'package:ndu_project/providers/project_data_provider.dart';
import 'package:ndu_project/schedule/models/schedule_models.dart';
import 'package:ndu_project/schedule/providers/schedule_provider.dart';
import 'package:ndu_project/schedule/screens/builder_screen.dart';
import 'package:ndu_project/schedule/services/schedule_cpm_service.dart';
import 'package:ndu_project/wbs/providers/wbs_provider.dart';

/// Covers the Schedule Builder action row: Import by Methodology, From Work
/// Packages, Import Agile Stories, Run CPM and Export.
///
/// The point of most of these is that the button *does* something. The import
/// paths used to read an unrelated legacy activity list to decide what had
/// already been imported, so a second press stacked a duplicate copy of the
/// whole chain; the agile import appended a fresh copy of every epic on every
/// run; and "Export" copied JSON to the clipboard and produced no file. Each
/// of those is pinned here.
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  ScheduleProvider scheduleProvider({String deliveryModel = 'WATERFALL'}) {
    return ScheduleProvider()
      ..setup(
        projectName: 'Test Project',
        deliveryModel: deliveryModel,
        projectId: 'p1',
      );
  }

  ProjectDataProvider projectDataProvider({
    List<WorkPackage> workPackages = const [],
    String projectId = 'p1',
  }) {
    final provider = ProjectDataProvider();
    provider.updateProjectData(
      ProjectDataModel(
        projectId: projectId,
        workPackages: workPackages,
      ),
    );
    // updateProjectData arms a debounced Firebase autosave; disposing cancels
    // it, which the binding requires once the tree is torn down.
    addTearDown(provider.dispose);
    return provider;
  }

  /// Pumps three seconds of frames.
  ///
  /// Not `pumpAndSettle`: while an import runs the action row shows a
  /// `CircularProgressIndicator`, which animates forever by design, so
  /// "settled" never arrives. Three seconds also outlasts the 2s autosave
  /// debounce that `ProjectDataProvider.updateProjectData` arms, which the
  /// binding otherwise reports as a timer still pending at teardown.
  Future<void> settle(WidgetTester tester, {int frames = 30}) async {
    for (var i = 0; i < frames; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> pumpBuilder(
    WidgetTester tester, {
    required ScheduleProvider scheduleProvider,
    ProjectDataProvider? projectDataProvider,
  }) async {
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ChangeNotifierProvider<ProjectDataProvider>.value(
        value: projectDataProvider ?? ProjectDataProvider(),
        child: MultiProvider(
          providers: [
            ChangeNotifierProvider<ScheduleProvider>.value(
              value: scheduleProvider,
            ),
            ChangeNotifierProvider<WBSProvider>.value(value: WBSProvider()),
            ChangeNotifierProvider<CostEstimateProvider>.value(
              value: CostEstimateProvider(),
            ),
          ],
          child: const MaterialApp(home: Scaffold(body: BuilderScreen())),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  List<ScheduleActivity> importedActivities(ScheduleProvider provider) {
    return ScheduleCpmService.flatten(provider.schedule!.activities)
        .where((a) => a.level > 0)
        .toList();
  }

  WorkPackage package({
    required String id,
    required String title,
    String classification = 'engineeringEwp',
    String wbsItemId = '',
    String parentPackageId = '',
    List<String> linkedEngineeringPackageIds = const [],
  }) {
    return WorkPackage(
      id: id,
      title: title,
      packageClassification: classification,
      wbsItemId: wbsItemId,
      parentPackageId: parentPackageId,
      linkedEngineeringPackageIds: linkedEngineeringPackageIds,
      plannedStart: '2026-01-06',
      plannedEnd: '2026-01-16',
    );
  }

  group('From Work Packages', () {
    testWidgets('imports each package once, however many times it is pressed',
        (tester) async {
      final schedule = scheduleProvider();
      await pumpBuilder(
        tester,
        scheduleProvider: schedule,
        projectDataProvider: projectDataProvider(workPackages: [
          package(id: 'wp1', title: 'Platform Foundation'),
          package(id: 'wp2', title: 'Controls Integration'),
        ]),
      );

      await tester.tap(find.text('From Work Packages'));
      await settle(tester);

      expect(importedActivities(schedule), hasLength(2));
      expect(
        importedActivities(schedule).map((a) => a.workPackageId).toSet(),
        {'wp1', 'wp2'},
        reason: 'each imported activity must record the package it came from',
      );

      // The regression: a second press used to append a second copy of every
      // package because the "already imported" check read the wrong list.
      await tester.tap(find.text('From Work Packages'));
      await settle(tester);

      expect(importedActivities(schedule), hasLength(2));
    });

    testWidgets('links the package chain across repeated runs', (tester) async {
      final schedule = scheduleProvider();
      // The successor is imported first; its predecessor only exists by the
      // time the second run happens, so the link can only be completed then.
      await pumpBuilder(
        tester,
        scheduleProvider: schedule,
        projectDataProvider: projectDataProvider(workPackages: [
          package(
            id: 'wp-proc',
            title: 'Switchgear Procurement',
            classification: 'procurementPackage',
            linkedEngineeringPackageIds: const ['wp-eng'],
          ),
          package(id: 'wp-eng', title: 'Substation Engineering'),
        ]),
      );

      await tester.tap(find.text('From Work Packages'));
      await settle(tester);

      final procurement = importedActivities(schedule)
          .firstWhere((a) => a.workPackageId == 'wp-proc');
      expect(
        procurement.dependencies.map((d) => d.activityId).toSet(),
        {
          importedActivities(schedule)
              .firstWhere((a) => a.workPackageId == 'wp-eng')
              .id
        },
        reason:
            'the chain must point at the activity the predecessor import created',
      );
    });

    testWidgets('says so when everything is already imported', (tester) async {
      final schedule = scheduleProvider();
      await pumpBuilder(
        tester,
        scheduleProvider: schedule,
        projectDataProvider: projectDataProvider(workPackages: [
          package(id: 'wp1', title: 'Platform Foundation'),
        ]),
      );

      await tester.tap(find.text('From Work Packages'));
      await settle(tester);
      await tester.tap(find.text('From Work Packages'));
      await settle(tester, frames: 6);

      expect(find.textContaining('already on the schedule'), findsOneWidget);
    });
  });

  group('Import by Methodology', () {
    testWidgets('shows what each source would add and runs the import',
        (tester) async {
      final schedule = scheduleProvider();
      await pumpBuilder(
        tester,
        scheduleProvider: schedule,
        projectDataProvider: projectDataProvider(workPackages: [
          package(id: 'wp1', title: 'Platform Foundation'),
          package(id: 'wp2', title: 'Controls Integration'),
        ]),
      );

      await tester.tap(find.text('Import by Methodology'));
      await settle(tester);

      // The dialog answers "what will this do" before it does anything.
      expect(find.text('2 packages · 0 already scheduled · 2 to add'),
          findsOneWidget);
      expect(find.text('Integrated work packages'), findsOneWidget);
      expect(find.text('Agile stories'), findsOneWidget);

      await tester.tap(find.text('Import 2 packages'));
      await settle(tester);

      expect(importedActivities(schedule), hasLength(2));
      expect(importedActivities(schedule).first.workPackageId, isNotEmpty);
    });

    testWidgets('the chosen source survives a rebuild of the dialog',
        (tester) async {
      // StatefulBuilder re-runs its builder on every setState, so a choice
      // held inside that builder silently snaps back to the default.
      final schedule = scheduleProvider();
      await pumpBuilder(
        tester,
        scheduleProvider: schedule,
        projectDataProvider: projectDataProvider(workPackages: [
          package(id: 'wp1', title: 'Platform Foundation'),
        ]),
      );

      await tester.tap(find.text('Import by Methodology'));
      await settle(tester);

      // Packages are the default for a waterfall project; picking the agile
      // card must stick, even though selecting it rebuilds the dialog.
      await tester.tap(find.text('Agile stories'));
      await settle(tester, frames: 3);

      // The dialog re-ran its builder to draw the agile result, so the choice
      // had to survive that rebuild: the action and the explanation below both
      // follow the selected source.
      expect(find.text('Import agile stories'), findsOneWidget);
      expect(
        find.textContaining('tops the schedule up rather than duplicating it'),
        findsOneWidget,
      );
      expect(find.textContaining('Waterfall'), findsOneWidget);
    });
  });

  group('Run CPM', () {
    testWidgets('opens a result sheet with the duration and critical path',
        (tester) async {
      final schedule = scheduleProvider();
      schedule.setActivities([
        schedule.schedule!.activities.first.copyWith(
          startDate: DateTime(2026, 1, 6),
          endDate: DateTime(2026, 2, 6),
          children: [
            const ScheduleActivity(
              id: 'a1',
              level: 1,
              code: '',
              name: 'Detailed Design',
              type: ActivityType.activity,
              domain: ScheduleDomain.engineering,
              duration: 10,
              dependencies: [],
              aiGenerated: false,
              children: [],
            ),
            const ScheduleActivity(
              id: 'a2',
              level: 1,
              code: '',
              name: 'Construction',
              type: ActivityType.activity,
              domain: ScheduleDomain.construction,
              duration: 20,
              dependencies: [
                ActivityDependency(
                  activityId: 'a1',
                  type: DependencyType.finishToStart,
                ),
              ],
              aiGenerated: false,
              children: [],
            ),
          ],
        ),
      ]);
      await pumpBuilder(tester, scheduleProvider: schedule);

      await tester.tap(find.text('Run CPM'));
      await settle(tester);

      expect(find.text('CPM results'), findsOneWidget);
      expect(find.text('30 days'), findsOneWidget);
      expect(find.textContaining('finishes'), findsOneWidget);
      expect(find.text('Critical path, in sequence'), findsOneWidget);
      expect(find.text('Detailed Design'), findsWidgets);
      expect(find.text('Construction'), findsWidgets);
    });

    testWidgets('names the dependency problems it found', (tester) async {
      final schedule = scheduleProvider();
      schedule.setActivities([
        schedule.schedule!.activities.first.copyWith(
          startDate: DateTime(2026, 1, 6),
          children: [
            const ScheduleActivity(
              id: 'a1',
              level: 1,
              code: '',
              name: 'Detailed Design',
              type: ActivityType.activity,
              domain: ScheduleDomain.engineering,
              duration: 5,
              dependencies: [
                ActivityDependency(
                  activityId: 'deleted-activity',
                  type: DependencyType.finishToStart,
                ),
              ],
              aiGenerated: false,
              children: [],
            ),
          ],
        ),
      ]);
      await pumpBuilder(tester, scheduleProvider: schedule);

      await tester.tap(find.text('Run CPM'));
      await settle(tester);

      expect(
        find.textContaining(
            'depends on an activity that is not on this schedule'),
        findsOneWidget,
      );
    });

    test('measures from the project start, not from today', () {
      final provider = scheduleProvider();
      provider.setActivities([
        provider.schedule!.activities.first.copyWith(
          startDate: DateTime(2020, 1, 6),
          children: [
            const ScheduleActivity(
              id: 'a1',
              level: 1,
              code: '',
              name: 'Detailed Design',
              type: ActivityType.activity,
              domain: ScheduleDomain.engineering,
              duration: 5,
              dependencies: [],
              aiGenerated: false,
              children: [],
            ),
          ],
        ),
      ]);

      provider.computeCpm();

      final activity = ScheduleCpmService.flatten(provider.schedule!.activities)
          .firstWhere((a) => a.id == 'a1');
      expect(
        activity.startDate,
        DateTime(2020, 1, 6),
        reason:
            'CPM offsets must hang off the schedule baseline, not the clock',
      );
    });

    test('reports activities that have no duration', () {
      final provider = scheduleProvider();
      provider.setActivities([
        provider.schedule!.activities.first.copyWith(
          startDate: DateTime(2026, 1, 6),
          children: [
            const ScheduleActivity(
              id: 'a1',
              level: 1,
              code: '',
              name: 'Undated work',
              type: ActivityType.activity,
              domain: ScheduleDomain.engineering,
              dependencies: [],
              aiGenerated: false,
              children: [],
            ),
          ],
        ),
      ]);

      final result = provider.computeCpm()!;

      expect(
        result.diagnostics
            .any((d) => d.type == CpmDiagnosticType.missingDuration),
        isTrue,
        reason: 'an assumed 1-day duration silently shortens the critical path',
      );
    });
  });

  group('deleting an activity', () {
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

    ScheduleActivity row(String id, String name,
        {List<ScheduleActivity> children = const []}) {
      return ScheduleActivity(
        id: id,
        level: 1,
        code: '',
        name: name,
        type: ActivityType.summary,
        domain: ScheduleDomain.engineering,
        dependencies: const [],
        aiGenerated: false,
        children: children,
      );
    }

    Future<void> tapDelete(WidgetTester tester) async {
      await tester.tap(find.byIcon(Icons.delete_outline).first);
      await settle(tester, frames: 8);
    }

    testWidgets('asks first, and cancelling keeps the activity',
        (tester) async {
      final schedule = providerWith([row('a1', 'Platform Foundation')]);
      await pumpBuilder(tester, scheduleProvider: schedule);

      await tapDelete(tester);

      expect(find.text('Delete activity'), findsOneWidget);
      expect(find.textContaining('Platform Foundation'), findsWidgets);

      await tester.tap(find.text('Cancel'));
      await settle(tester, frames: 8);

      expect(find.text('Delete activity'), findsNothing);
      expect(
        importedActivities(schedule).map((a) => a.name),
        contains('Platform Foundation'),
        reason: 'a cancelled delete must leave the schedule untouched',
      );
    });

    testWidgets('confirming removes the activity', (tester) async {
      final schedule = providerWith([
        row('a1', 'Platform Foundation'),
        row('a2', 'Controls Integration'),
      ]);
      await pumpBuilder(tester, scheduleProvider: schedule);

      await tapDelete(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await settle(tester, frames: 8);

      expect(
        importedActivities(schedule).map((a) => a.name),
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
          'Platform Foundation',
          children: [
            row('a1a', 'Design'),
            row('a1b', 'Review'),
          ],
        ),
      ]);
      await pumpBuilder(tester, scheduleProvider: schedule);

      // The first trash button belongs to the parent row.
      await tapDelete(tester);

      expect(
        find.textContaining('the 2 activities nested under it'),
        findsOneWidget,
      );
      expect(find.textContaining('dates and dependencies included'),
          findsOneWidget);
    });

    testWidgets('a parent delete takes its children with it, once confirmed',
        (tester) async {
      final schedule = providerWith([
        row(
          'a1',
          'Platform Foundation',
          children: [
            row('a1a', 'Design'),
            row('a1b', 'Review'),
          ],
        ),
      ]);
      await pumpBuilder(tester, scheduleProvider: schedule);

      await tapDelete(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await settle(tester, frames: 8);

      expect(importedActivities(schedule), isEmpty);
    });

    testWidgets('a locked schedule offers no delete at all', (tester) async {
      final schedule = providerWith([row('a1', 'Platform Foundation')]);
      await pumpBuilder(tester, scheduleProvider: schedule);

      // Locked after the first frame: the provider reads storage on
      // construction, and doing this before that read lands restores the
      // unlocked snapshot over the top.
      schedule.lock();
      await settle(tester, frames: 3);

      expect(schedule.schedule!.isLocked, isTrue);
      expect(find.byIcon(Icons.delete_outline), findsNothing);
    });
  });

  group('Export', () {
    testWidgets('offers a file for each destination', (tester) async {
      final schedule = scheduleProvider();
      await pumpBuilder(tester, scheduleProvider: schedule);

      await tester.tap(find.text('Export'));
      await settle(tester);

      expect(find.text('Export schedule'), findsOneWidget);
      expect(find.text('PDF document'), findsOneWidget);
      expect(find.text('CSV spreadsheet'), findsOneWidget);
      expect(find.text('JSON to clipboard'), findsOneWidget);
    });

    testWidgets('the JSON option copies the whole tree', (tester) async {
      final copied = <MethodCall>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          copied.add(call);
          return null;
        },
      );
      addTearDown(() => tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null));

      final schedule = scheduleProvider();
      schedule.setActivities([
        schedule.schedule!.activities.first.copyWith(
          children: [
            const ScheduleActivity(
              id: 'a1',
              level: 1,
              code: '',
              name: 'Detailed Design',
              type: ActivityType.activity,
              domain: ScheduleDomain.engineering,
              duration: 5,
              dependencies: [],
              aiGenerated: false,
              children: [],
            ),
          ],
        ),
      ]);
      await pumpBuilder(tester, scheduleProvider: schedule);

      await tester.tap(find.text('Export'));
      await settle(tester, frames: 10);
      await tester.tap(find.text('JSON to clipboard'));
      // Short settle: the confirmation is a 3-second SnackBar, and pumping
      // past that would assert on a message the user has already lost.
      await settle(tester, frames: 6);

      final clipboardWrite = copied
          .where((call) => call.method == 'Clipboard.setData')
          .cast<MethodCall>()
          .toList();
      expect(clipboardWrite, hasLength(1));
      final payload = (clipboardWrite.single.arguments
          as Map<Object?, Object?>)['text'] as String;
      expect(payload, contains('Detailed Design'));
      expect(payload, contains('dependencies'));
      expect(find.textContaining('copied to clipboard'), findsOneWidget);
    });
  });

  group('importStoriesFromAgile', () {
    AgileTask story(String id, String userStory) => AgileTask(
          id: id,
          userStory: userStory,
        );

    List<
        ({
          AgileTask story,
          String epicTitle,
          String featureTitle,
          String? sprintLabel,
          String? releaseLabel,
        })> backlog(List<AgileTask> stories) {
      return [
        for (final item in stories)
          (
            story: item,
            epicTitle: 'Platform',
            featureTitle: 'Foundation',
            sprintLabel: null,
            releaseLabel: null,
          ),
      ];
    }

    test('adds stories on the first run and none on the second', () {
      final provider = scheduleProvider(deliveryModel: 'AGILE');
      final stories = backlog([
        story('t1', 'Story one'),
        story('t2', 'Story two'),
      ]);

      final first = provider.importStoriesFromAgile(stories: stories);
      expect(first.storiesAdded, 2);
      expect(first.epicsAdded, 1);
      expect(first.featuresAdded, 1);

      final second = provider.importStoriesFromAgile(stories: stories);
      expect(second.storiesAdded, 0);
      expect(second.storiesSkipped, 2);

      final scheduled =
          ScheduleCpmService.flatten(provider.schedule!.activities)
              .where((a) => (a.agileTaskId ?? '').isNotEmpty)
              .toList();
      expect(
        scheduled,
        hasLength(2),
        reason:
            'a second run must top the schedule up, not duplicate the backlog',
      );
    });

    test('adds only the stories that are new', () {
      final provider = scheduleProvider(deliveryModel: 'AGILE');
      provider.importStoriesFromAgile(
          stories: backlog([story('t1', 'Story one')]));

      final summary = provider.importStoriesFromAgile(
        stories: backlog([story('t1', 'Story one'), story('t2', 'Story two')]),
      );

      expect(summary.storiesAdded, 1);
      expect(summary.storiesSkipped, 1);
      expect(summary.epicsReused, 1);
      expect(summary.featuresReused, 1);
      expect(
        ScheduleCpmService.flatten(provider.schedule!.activities)
            .where((a) => (a.agileTaskId ?? '').isNotEmpty),
        hasLength(2),
      );
    });

    test('wires story prerequisites into real dependencies', () {
      final provider = scheduleProvider(deliveryModel: 'AGILE');
      provider.importStoriesFromAgile(
        stories: backlog([
          story('t1', 'Story one'),
          story('t2', 'Story two')..dependencyTaskIds = ['t1'],
        ]),
      );

      final activities =
          ScheduleCpmService.flatten(provider.schedule!.activities);
      final second = activities.firstWhere((a) => a.agileTaskId == 't2');
      final first = activities.firstWhere((a) => a.agileTaskId == 't1');

      expect(second.dependencies.map((d) => d.activityId), [first.id]);
    });
  });
}
