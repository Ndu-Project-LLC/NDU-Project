// Tests for collectScheduleTimelines — the Schedule → WBS direction of the
// timeline link (voice note, 2026-09-10). A WBS node carries plannedStart /
// plannedFinish but nothing wrote them before this, so the schedule is where
// they come from.

import 'package:flutter_test/flutter_test.dart';
import 'package:ndu_project/schedule/models/schedule_models.dart';
import 'package:ndu_project/schedule/utils/schedule_wbs_timelines.dart';

ScheduleActivity _activity(
  String id, {
  String? wbsNodeId,
  DateTime? start,
  DateTime? finish,
  List<ScheduleActivity> children = const [],
}) {
  return ScheduleActivity(
    id: id,
    wbsNodeId: wbsNodeId,
    level: 2,
    code: '',
    name: id,
    type: ActivityType.activity,
    domain: ScheduleDomain.engineering,
    startDate: start,
    endDate: finish,
    dependencies: const [],
    aiGenerated: false,
    children: children,
  );
}

void main() {
  group('collectScheduleTimelines', () {
    test('returns nothing for an empty schedule', () {
      expect(collectScheduleTimelines(const []), isEmpty);
    });

    test('maps a linked activity to its WBS node', () {
      final start = DateTime(2026, 3, 1);
      final finish = DateTime(2026, 4, 15);

      final out = collectScheduleTimelines([
        _activity('a1', wbsNodeId: 'n1', start: start, finish: finish),
      ]);

      expect(out.keys, ['n1']);
      expect(out['n1']!.start, start);
      expect(out['n1']!.finish, finish);
    });

    test('takes the widest window when several activities share a node', () {
      final out = collectScheduleTimelines([
        _activity('a1',
            wbsNodeId: 'n1',
            start: DateTime(2026, 3, 10),
            finish: DateTime(2026, 3, 20)),
        _activity('a2',
            wbsNodeId: 'n1',
            start: DateTime(2026, 3, 1),
            finish: DateTime(2026, 3, 5)),
        _activity('a3',
            wbsNodeId: 'n1',
            start: DateTime(2026, 4, 1),
            finish: DateTime(2026, 4, 30)),
      ]);

      expect(out['n1']!.start, DateTime(2026, 3, 1));
      expect(out['n1']!.finish, DateTime(2026, 4, 30));
    });

    test('ignores activities with no WBS link', () {
      final out = collectScheduleTimelines([
        _activity('a1',
            start: DateTime(2026, 3, 1), finish: DateTime(2026, 3, 10)),
        _activity('a2', wbsNodeId: '', start: DateTime(2026, 3, 1)),
        _activity('a3', wbsNodeId: '   ', start: DateTime(2026, 3, 1)),
      ]);

      expect(out, isEmpty);
    });

    test('omits a linked node with no dates at all', () {
      final out = collectScheduleTimelines([
        _activity('a1', wbsNodeId: 'n1'),
      ]);

      expect(out, isEmpty);
    });

    test('keeps a node that only has a start or only a finish', () {
      final out = collectScheduleTimelines([
        _activity('a1', wbsNodeId: 'n1', start: DateTime(2026, 3, 1)),
        _activity('a2', wbsNodeId: 'n2', finish: DateTime(2026, 5, 1)),
      ]);

      expect(out['n1']!.start, DateTime(2026, 3, 1));
      expect(out['n1']!.finish, isNull);
      expect(out['n2']!.start, isNull);
      expect(out['n2']!.finish, DateTime(2026, 5, 1));
    });

    test('walks nested children and trims the node id', () {
      final out = collectScheduleTimelines([
        _activity('root',
            children: [
              _activity('c1',
                  wbsNodeId: ' n1 ',
                  start: DateTime(2026, 2, 1),
                  finish: DateTime(2026, 2, 28)),
              _activity('c2',
                  children: [
                    _activity('g1',
                        wbsNodeId: 'n2',
                        start: DateTime(2026, 6, 1),
                        finish: DateTime(2026, 6, 30)),
                  ]),
            ]),
      ]);

      expect(out.keys.toSet(), {'n1', 'n2'});
      expect(out['n1']!.start, DateTime(2026, 2, 1));
      expect(out['n2']!.finish, DateTime(2026, 6, 30));
    });
  });
}
