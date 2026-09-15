// Tests for the Schedule ↔ WBS work-package bridge behind the Schedule
// module's "WBS Packages" card (voice note, 2026-09-10):
//
//   "this card is supposed to show the WBS packages"
//   "the schedule should be able to put out everything that's like on the WBS
//    [so it] should be able to find itself on the schedule"
//
// The pure half is covered here — which packages exist, where they sit on the
// schedule, and which ones are still missing. The provider half (actually
// adding them, filling dates, attaching a cost line) is covered by the widget
// test beside this file.

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ndu_project/schedule/models/schedule_models.dart';
import 'package:ndu_project/schedule/providers/schedule_provider.dart';
import 'package:ndu_project/schedule/utils/schedule_wbs_packages.dart';
import 'package:ndu_project/wbs/models/wbs_models.dart';

WBSNode wbsNode(
  String id,
  String code,
  String name, {
  WBSLevel level = WBSLevel.level1,
  DateTime? plannedStart,
  DateTime? plannedFinish,
  List<String>? costLineIds,
  List<WBSNode> children = const [],
}) {
  return WBSNode(
    id: id,
    level: level,
    code: code,
    name: name,
    plannedStart: plannedStart,
    plannedFinish: plannedFinish,
    costLineIds: costLineIds,
    aiGenerated: false,
    children: children,
  );
}

WBS wbsWith(List<WBSNode> level1) {
  final now = DateTime(2026, 9, 10);
  return WBS(
    id: 'wbs_1',
    projectId: 'proj_1',
    projectName: 'Lusaka',
    framework: WBSFramework.waterfallDeliverable,
    level0: WBSNode(
      id: 'root',
      level: WBSLevel.level0,
      code: '0',
      name: 'Lusaka',
      aiGenerated: false,
      children: level1,
    ),
    aiSuggestions: const [],
    createdAt: now,
    updatedAt: now,
  );
}

ScheduleActivity activity(
  String id, {
  String? wbsNodeId,
  String? wbsCode,
  String name = 'Activity',
  DateTime? start,
  DateTime? finish,
  String? costLineId,
  List<ScheduleActivity> children = const [],
}) {
  return ScheduleActivity(
    id: id,
    level: 2,
    code: '',
    name: name,
    type: ActivityType.task,
    domain: ScheduleDomain.engineering,
    wbsNodeId: wbsNodeId,
    wbsCode: wbsCode,
    startDate: start,
    endDate: finish,
    costLineId: costLineId,
    dependencies: const [],
    aiGenerated: false,
    children: children,
  );
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('buildWbsPackageRows', () {
    test('shows every package below the root, in tree order', () {
      final wbs = wbsWith([
        wbsNode('n1', '1', 'Engineering', children: [
          wbsNode('n2', '1.1', 'Process Design', level: WBSLevel.level2),
        ]),
        wbsNode('n3', '2', 'Procurement'),
      ]);

      final rows = buildWbsPackageRows(wbs: wbs, activities: const []);

      // The project root is the project, never a package.
      expect(rows.map((r) => r.label),
          ['1 — Engineering', '1.1 — Process Design', '2 — Procurement']);
      expect(rows.map((r) => r.level), [1, 2, 1]);
      expect(rows.every((r) => !r.onSchedule), isTrue);
    });

    test('no WBS yields no rows', () {
      expect(buildWbsPackageRows(wbs: null, activities: const []), isEmpty);
    });

    test('skips an unnamed node but keeps walking its children', () {
      final wbs = wbsWith([
        wbsNode('n1', '1', '   ', children: [
          wbsNode('n2', '1.1', 'Process Design', level: WBSLevel.level2),
        ]),
      ]);

      final rows = buildWbsPackageRows(wbs: wbs, activities: const []);
      expect(rows.map((r) => r.label), ['1.1 — Process Design']);
    });

    test('falls back to the name when a node has no code', () {
      final wbs = wbsWith([wbsNode('n1', '', 'Mobilization')]);
      final rows = buildWbsPackageRows(wbs: wbs, activities: const []);
      expect(rows.single.label, 'Mobilization');
    });

    test('marks a package on-schedule and rolls up its widest window', () {
      final wbs = wbsWith([wbsNode('n1', '1', 'Engineering')]);
      final rows = buildWbsPackageRows(
        wbs: wbs,
        activities: [
          activity('a1',
              wbsNodeId: 'n1',
              start: DateTime(2026, 3, 1),
              finish: DateTime(2026, 3, 10)),
          activity('a2',
              wbsNodeId: 'n1',
              start: DateTime(2026, 2, 1),
              finish: DateTime(2026, 4, 30)),
        ],
      );

      final row = rows.single;
      expect(row.onSchedule, isTrue);
      expect(row.activityIds, ['a1', 'a2']);
      expect(row.scheduledStart, DateTime(2026, 2, 1));
      expect(row.scheduledFinish, DateTime(2026, 4, 30));
      expect(row.hasScheduleDates, isTrue);
    });

    test('an unlinked activity never satisfies coverage', () {
      final wbs = wbsWith([wbsNode('n1', '1', 'Engineering')]);
      final rows = buildWbsPackageRows(
        wbs: wbs,
        activities: [activity('a1', name: 'Floating activity')],
      );

      expect(rows.single.onSchedule, isFalse);
      expect(rows.single.activityNames, isEmpty);
    });

    test('trims the node id on both sides of the link', () {
      final wbs = wbsWith([wbsNode('n1', '1', 'Engineering')]);
      final rows = buildWbsPackageRows(
        wbs: wbs,
        activities: [activity('a1', wbsNodeId: ' n1 ')],
      );

      expect(rows.single.onSchedule, isTrue);
    });

    test('collects cost links from the node and from its activities', () {
      final wbs = wbsWith([
        wbsNode('n1', '1', 'Engineering', costLineIds: ['line_node']),
      ]);
      final rows = buildWbsPackageRows(
        wbs: wbs,
        activities: [
          activity('a1', wbsNodeId: 'n1', costLineId: 'line_activity'),
          activity('a2', wbsNodeId: 'n1'),
        ],
      );

      expect(rows.single.costLineIds, containsAll(['line_node', 'line_activity']));
      expect(rows.single.isPriced, isTrue);
    });

    test('keeps the WBS planned window separate from the schedule window', () {
      final wbs = wbsWith([
        wbsNode('n1', '1', 'Engineering',
            plannedStart: DateTime(2026, 1, 5),
            plannedFinish: DateTime(2026, 1, 30)),
      ]);

      final rows = buildWbsPackageRows(
        wbs: wbs,
        activities: [activity('a1', wbsNodeId: 'n1')],
      );

      final row = rows.single;
      expect(row.plannedStart, DateTime(2026, 1, 5));
      expect(row.hasPlannedWindow, isTrue);
      expect(row.scheduledStart, isNull);
      // Scheduled, but with no dates of its own — the case "fill schedule
      // dates from WBS" fixes.
      expect(row.needsScheduleDates, isTrue);
    });
  });

  group('wbsPackagesMissingFromSchedule', () {
    test('offers only the packages the schedule does not carry', () {
      final wbs = wbsWith([
        wbsNode('n1', '1', 'Engineering'),
        wbsNode('n2', '2', 'Procurement'),
      ]);

      final missing = wbsPackagesMissingFromSchedule(
        wbs: wbs,
        activities: [activity('a1', wbsNodeId: 'n1')],
      );

      expect(missing.map((p) => p.nodeId), ['n2']);
      expect(missing.single.label, '2 — Procurement');
    });

    test('is empty when everything is scheduled', () {
      final wbs = wbsWith([wbsNode('n1', '1', 'Engineering')]);
      final missing = wbsPackagesMissingFromSchedule(
        wbs: wbs,
        activities: [activity('a1', wbsNodeId: 'n1')],
      );
      expect(missing, isEmpty);
    });

    test('carries the planned window across so the pull starts dated', () {
      final wbs = wbsWith([
        wbsNode('n1', '1', 'Engineering',
            plannedStart: DateTime(2026, 1, 5),
            plannedFinish: DateTime(2026, 2, 5)),
      ]);

      final missing =
          wbsPackagesMissingFromSchedule(wbs: wbs, activities: const []);

      expect(missing.single.plannedStart, DateTime(2026, 1, 5));
      expect(missing.single.plannedFinish, DateTime(2026, 2, 5));
    });
  });

  group('countPackagesAwaitingScheduleDates', () {
    test('counts only scheduled packages that still have no dates', () {
      final wbs = wbsWith([
        wbsNode('n1', '1', 'Engineering'),
        wbsNode('n2', '2', 'Procurement'),
      ]);
      final rows = buildWbsPackageRows(
        wbs: wbs,
        activities: [
          activity('a1', wbsNodeId: 'n1', start: DateTime(2026, 3, 1)),
          activity('a2', wbsNodeId: 'n2'),
        ],
      );

      expect(countPackagesAwaitingScheduleDates(rows), 1);
    });
  });

  group('ScheduleProvider.attachWbsPackages', () {
    ScheduleProvider newSchedule() {
      final provider = ScheduleProvider();
      provider.setup(projectName: 'Lusaka', deliveryModel: 'WATERFALL');
      return provider;
    }

    test('adds one activity per package, linked back to its WBS node', () {
      final provider = newSchedule();
      final added = provider.attachWbsPackages([
        const WbsPackagePull(
          nodeId: 'n1',
          code: '1.1',
          name: 'Process Design',
          level: 2,
          description: null,
          plannedStart: null,
          plannedFinish: null,
        ),
      ]);

      expect(added, 1);
      final activity = provider.schedule!.activities
          .expand((root) => root.children)
          .singleWhere((a) => a.wbsNodeId == 'n1');
      expect(activity.name, '1.1 — Process Design');
      expect(activity.wbsCode, '1.1');
      expect(activity.importSource, 'wbs');
    });

    test('carries the WBS planned window into the activity dates', () {
      final provider = newSchedule();
      provider.attachWbsPackages([
        WbsPackagePull(
          nodeId: 'n1',
          code: '1',
          name: 'Engineering',
          level: 1,
          description: null,
          plannedStart: DateTime(2026, 1, 5),
          plannedFinish: DateTime(2026, 1, 9),
        ),
      ]);

      final activity = provider.schedule!.activities.first.children
          .singleWhere((a) => a.wbsNodeId == 'n1');
      expect(activity.startDate, DateTime(2026, 1, 5));
      expect(activity.endDate, DateTime(2026, 1, 9));
      // 5–9 Jan inclusive.
      expect(activity.duration, 5);
    });

    test('is idempotent — a package already linked is never added twice', () {
      final provider = newSchedule();
      const pull = WbsPackagePull(
        nodeId: 'n1',
        code: '1',
        name: 'Engineering',
        level: 1,
        description: null,
        plannedStart: null,
        plannedFinish: null,
      );

      expect(provider.attachWbsPackages([pull]), 1);
      expect(provider.attachWbsPackages([pull]), 0);
      expect(
        provider.schedule!.activities.first.children
            .where((a) => a.wbsNodeId == 'n1')
            .length,
        1,
      );
    });

    test('does nothing without a schedule', () {
      final provider = ScheduleProvider();
      expect(
        provider.attachWbsPackages([
          const WbsPackagePull(
            nodeId: 'n1',
            code: '1',
            name: 'Engineering',
            level: 1,
            description: null,
            plannedStart: null,
            plannedFinish: null,
          ),
        ]),
        0,
      );
    });
  });

  group('ScheduleProvider.applyWbsPlannedDates', () {
    test('fills only the activities that have no dates of their own', () {
      final provider = ScheduleProvider();
      provider.setup(projectName: 'Lusaka', deliveryModel: 'WATERFALL');
      provider.setActivities([
        ScheduleActivity(
          id: 'root',
          level: 0,
          code: '0',
          name: 'Lusaka',
          type: ActivityType.summary,
          domain: ScheduleDomain.engineering,
          dependencies: const [],
          aiGenerated: false,
          children: [
            activity('a1', wbsNodeId: 'n1'),
            activity('a2',
                wbsNodeId: 'n2',
                start: DateTime(2026, 6, 1),
                finish: DateTime(2026, 6, 10)),
          ],
        ),
      ]);

      final filled = provider.applyWbsPlannedDates({
        'n1': (start: DateTime(2026, 1, 5), finish: DateTime(2026, 1, 9)),
        'n2': (start: DateTime(2026, 9, 1), finish: DateTime(2026, 9, 30)),
      });

      expect(filled, 1);
      final children = provider.schedule!.activities.first.children;
      expect(children.first.startDate, DateTime(2026, 1, 5));
      // The CPM/hand-entered window is never overwritten.
      expect(children.last.startDate, DateTime(2026, 6, 1));
    });

    test('reports nothing to do when every linked row already has dates', () {
      final provider = ScheduleProvider();
      provider.setup(projectName: 'Lusaka', deliveryModel: 'WATERFALL');
      provider.setActivities([
        ScheduleActivity(
          id: 'root',
          level: 0,
          code: '0',
          name: 'Lusaka',
          type: ActivityType.summary,
          domain: ScheduleDomain.engineering,
          dependencies: const [],
          aiGenerated: false,
          children: [
            activity('a1',
                wbsNodeId: 'n1', start: DateTime(2026, 6, 1), finish: DateTime(2026, 6, 3)),
          ],
        ),
      ]);

      expect(
        provider.applyWbsPlannedDates({
          'n1': (start: DateTime(2026, 1, 5), finish: DateTime(2026, 1, 9)),
        }),
        0,
      );
    });
  });

  group('ScheduleProvider.attachCostLineToActivity', () {
    test('stamps the line on the activity and reports its WBS node', () {
      final provider = ScheduleProvider();
      provider.setup(projectName: 'Lusaka', deliveryModel: 'WATERFALL');
      provider.setActivities([
        ScheduleActivity(
          id: 'root',
          level: 0,
          code: '0',
          name: 'Lusaka',
          type: ActivityType.summary,
          domain: ScheduleDomain.engineering,
          dependencies: const [],
          aiGenerated: false,
          children: [activity('a1', wbsNodeId: 'n1')],
        ),
      ]);

      final nodeId = provider.attachCostLineToActivity('a1', 'line_9');

      expect(nodeId, 'n1');
      expect(
        provider.schedule!.activities.first.children.single.costLineId,
        'line_9',
      );
    });

    test('returns null when the activity is not linked to a WBS node', () {
      final provider = ScheduleProvider();
      provider.setup(projectName: 'Lusaka', deliveryModel: 'WATERFALL');
      provider.setActivities([
        ScheduleActivity(
          id: 'root',
          level: 0,
          code: '0',
          name: 'Lusaka',
          type: ActivityType.summary,
          domain: ScheduleDomain.engineering,
          dependencies: const [],
          aiGenerated: false,
          children: [activity('a1')],
        ),
      ]);

      expect(provider.attachCostLineToActivity('a1', 'line_9'), isNull);
      expect(
        provider.schedule!.activities.first.children.single.costLineId,
        'line_9',
      );
    });

    test('an unknown activity changes nothing', () {
      final provider = ScheduleProvider();
      provider.setup(projectName: 'Lusaka', deliveryModel: 'WATERFALL');
      expect(provider.attachCostLineToActivity('nope', 'line_9'), isNull);
    });
  });
}
