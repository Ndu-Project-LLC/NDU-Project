// The WBS → Schedule half of the timeline link: how a package's planned
// window is divided between the schedule rows that are still blank.
//
// Regression: every blank row of a package used to be given the package's
// *whole* window, so a package of three rows planned for 05–30 January came
// back as three identical 05–30 January activities — not a plan, and not
// something CPM can read as three sequential tasks either.

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ndu_project/schedule/models/schedule_models.dart';
import 'package:ndu_project/schedule/providers/schedule_provider.dart';

ScheduleActivity activity(
  String id, {
  String? wbsNodeId,
  DateTime? start,
  DateTime? end,
  List<ScheduleActivity> children = const [],
}) {
  return ScheduleActivity(
    id: id,
    level: 2,
    code: '',
    name: 'Row $id',
    type: ActivityType.task,
    domain: ScheduleDomain.engineering,
    wbsNodeId: wbsNodeId,
    startDate: start,
    endDate: end,
    dependencies: const [],
    aiGenerated: false,
    children: children,
  );
}

ScheduleProvider providerWith(List<ScheduleActivity> children) {
  final provider = ScheduleProvider();
  provider.setup(projectName: 'P', deliveryModel: 'WATERFALL');
  provider.setActivities([
    ScheduleActivity(
      id: 'root',
      level: 0,
      code: '0',
      name: 'P',
      type: ActivityType.summary,
      domain: ScheduleDomain.engineering,
      dependencies: const [],
      aiGenerated: false,
      children: children,
    ),
  ]);
  return provider;
}

List<ScheduleActivity> rowsOf(ScheduleProvider provider) =>
    provider.schedule!.activities.first.children;

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  final january = {
    'n1': (start: DateTime(2026, 1, 5), finish: DateTime(2026, 1, 30)),
  };

  test('divides the package window between its blank rows', () {
    final provider = providerWith([
      activity('a1', wbsNodeId: 'n1'),
      activity('a2', wbsNodeId: 'n1'),
      activity('a3', wbsNodeId: 'n1'),
    ]);

    expect(provider.applyWbsPlannedDates(january), 3);

    final rows = rowsOf(provider);
    expect(rows[0].startDate, DateTime(2026, 1, 5));
    expect(rows[2].endDate, DateTime(2026, 1, 30));
    // No row may be handed the whole window any more.
    expect(rows[1].startDate, isNot(DateTime(2026, 1, 5)));
    expect(rows[1].endDate, isNot(DateTime(2026, 1, 30)));
  });

  test('the slices tile the window exactly — no gaps, no overlaps', () {
    final provider = providerWith([
      for (var i = 0; i < 4; i++) activity('a$i', wbsNodeId: 'n1'),
    ]);

    provider.applyWbsPlannedDates(january);

    final rows = rowsOf(provider);
    for (var i = 1; i < rows.length; i++) {
      expect(
        rows[i].startDate,
        rows[i - 1].endDate!.add(const Duration(days: 1)),
        reason: 'row $i must begin the day after row ${i - 1} ends',
      );
    }
    final totalDays = rows.fold<int>(
        0, (sum, r) => sum + r.endDate!.difference(r.startDate!).inDays + 1);
    expect(totalDays, 26, reason: 'the window must be covered once, not twice');
  });

  test('duration matches the slice each row was given', () {
    final provider = providerWith([
      activity('a1', wbsNodeId: 'n1'),
      activity('a2', wbsNodeId: 'n1'),
      activity('a3', wbsNodeId: 'n1'),
    ]);

    provider.applyWbsPlannedDates(january);

    for (final row in rowsOf(provider)) {
      expect(
        row.duration,
        row.endDate!.difference(row.startDate!).inDays + 1,
      );
    }
  });

  test('a single blank row still takes the whole window', () {
    final provider = providerWith([activity('a1', wbsNodeId: 'n1')]);

    provider.applyWbsPlannedDates(january);

    final row = rowsOf(provider).single;
    expect(row.startDate, DateTime(2026, 1, 5));
    expect(row.endDate, DateTime(2026, 1, 30));
  });

  test(
      'an already dated row keeps its own window and is left out of the '
      'split', () {
    final provider = providerWith([
      activity('a1', wbsNodeId: 'n1'),
      activity(
        'a2',
        wbsNodeId: 'n1',
        start: DateTime(2026, 6, 1),
        end: DateTime(2026, 6, 30),
      ),
      activity('a3', wbsNodeId: 'n1'),
    ]);

    expect(provider.applyWbsPlannedDates(january), 2);

    final rows = rowsOf(provider);
    expect(rows[1].startDate, DateTime(2026, 6, 1));
    expect(rows[1].endDate, DateTime(2026, 6, 30));
    // The two blank rows split the window between them.
    expect(rows[0].startDate, DateTime(2026, 1, 5));
    expect(rows[2].endDate, DateTime(2026, 1, 30));
    expect(rows[2].startDate!.isAfter(rows[0].endDate!), isTrue);
  });

  test('more rows than days still leaves no row ending before it starts', () {
    // Two days of window, five blank rows: some rows have to share a day.
    final provider = providerWith([
      for (var i = 0; i < 5; i++) activity('a$i', wbsNodeId: 'n1'),
    ]);

    provider.applyWbsPlannedDates({
      'n1': (start: DateTime(2026, 1, 5), finish: DateTime(2026, 1, 6)),
    });

    for (final row in rowsOf(provider)) {
      expect(row.endDate!.isBefore(row.startDate!), isFalse);
    }
  });

  test('packages are split independently of one another', () {
    final provider = providerWith([
      activity('a1', wbsNodeId: 'n1'),
      activity('a2', wbsNodeId: 'n2'),
      activity('b1', wbsNodeId: 'n1'),
      activity('b2', wbsNodeId: 'n2'),
    ]);

    provider.applyWbsPlannedDates({
      'n1': (start: DateTime(2026, 1, 5), finish: DateTime(2026, 1, 30)),
      'n2': (start: DateTime(2026, 3, 2), finish: DateTime(2026, 3, 13)),
    });

    final rows = rowsOf(provider);
    expect(rows[0].startDate, DateTime(2026, 1, 5));
    expect(rows[1].startDate, DateTime(2026, 3, 2));
    expect(rows[2].endDate, DateTime(2026, 1, 30));
    expect(rows[3].endDate, DateTime(2026, 3, 13));
  });

  test('a window with only a start date is not invented into a range', () {
    final provider = providerWith([
      activity('a1', wbsNodeId: 'n1'),
      activity('a2', wbsNodeId: 'n1'),
    ]);

    provider.applyWbsPlannedDates({
      'n1': (start: DateTime(2026, 1, 5), finish: null),
    });

    for (final row in rowsOf(provider)) {
      expect(row.startDate, DateTime(2026, 1, 5));
      expect(row.endDate, isNull);
    }
  });
}
