// Tests for collectScheduleWorkPackages — the Schedule → Cost Estimate base
// case from the 2026-09-10 voice note: "the cost estimate … is supposed to
// start with the work packages from the Schedule as a direct cost".
//
// The selector is deliberately strict about CONTAINERS (leaf-only, so an
// upper-level stage is never estimated on top of its own children and the same
// work is never counted twice) and deliberately permissive about everything
// else, because the owner's complaint was about work packages missing from the
// views, not about extras.

import 'package:flutter_test/flutter_test.dart';
import 'package:ndu_project/cost_estimate/models/cost_estimate_models.dart';
import 'package:ndu_project/schedule/models/schedule_models.dart';
import 'package:ndu_project/schedule/utils/schedule_work_packages.dart';

ScheduleActivity activity(
  String id, {
  String name = 'work',
  ActivityType type = ActivityType.activity,
  ScheduleDomain domain = ScheduleDomain.engineering,
  String? wbsCode,
  String? costLineId,
  List<ScheduleActivity> children = const [],
}) {
  return ScheduleActivity(
    id: id,
    wbsCode: wbsCode,
    costLineId: costLineId,
    level: 2,
    code: '',
    name: name,
    type: type,
    domain: domain,
    dependencies: const [],
    aiGenerated: false,
    children: children,
  );
}

void main() {
  group('directCategoryForDomain', () {
    test('maps every domain to a DIRECT category', () {
      const direct = {
        CostCategory.labor,
        CostCategory.materials,
        CostCategory.software,
        CostCategory.procurement,
        CostCategory.travelTraining,
        CostCategory.construction,
      };
      for (final domain in ScheduleDomain.values) {
        expect(direct, contains(directCategoryForDomain(domain)),
            reason: 'domain=$domain must not feed indirect cost');
      }
    });

    test('maps by delivery character, not uniformly', () {
      expect(directCategoryForDomain(ScheduleDomain.engineering),
          CostCategory.labor);
      expect(directCategoryForDomain(ScheduleDomain.execution),
          CostCategory.labor);
      expect(directCategoryForDomain(ScheduleDomain.commissioning),
          CostCategory.labor);
      expect(directCategoryForDomain(ScheduleDomain.procurement),
          CostCategory.procurement);
      expect(directCategoryForDomain(ScheduleDomain.construction),
          CostCategory.construction);
    });
  });

  group('collectScheduleWorkPackages', () {
    test('returns nothing for an empty schedule', () {
      expect(collectScheduleWorkPackages(const []), isEmpty);
    });

    test('collects leaf activities', () {
      final out = collectScheduleWorkPackages([
        activity('a1', name: 'Pour foundations', wbsCode: 'G1.1'),
        activity('a2', name: 'Erect steel', wbsCode: 'G1.2'),
      ]);

      expect(out.map((w) => w.activityId), ['a1', 'a2']);
      expect(out.first.title, 'Pour foundations');
      expect(out.first.wbsRef, 'G1.1');
    });

    test('descends into containers and estimates only the leaves', () {
      final out = collectScheduleWorkPackages([
        activity('root', name: 'Project', children: [
          activity('stage', name: 'Stage 1', children: [
            activity('leaf1', name: 'Design package', wbsCode: 'G1.1'),
          ]),
          activity('leaf2', name: 'Site setup', wbsCode: 'G1.2'),
        ]),
      ]);

      // The single-child chain and the root are containers and must not be
      // estimated on top of their children.
      expect(out.map((w) => w.activityId), ['leaf1', 'leaf2']);
    });

    test('skips milestones — they are a point in time, not work', () {
      final out = collectScheduleWorkPackages([
        activity('m1', name: 'Design freeze', type: ActivityType.milestone),
        activity('a1', name: 'Real work'),
      ]);

      expect(out.map((w) => w.activityId), ['a1']);
    });

    test('includes unresolved-classification leaves rather than dropping them',
        () {
      // _typeForPackage falls back to `summary` for unknown classifications,
      // so a real work package can be typed summary while having no children.
      final out = collectScheduleWorkPackages([
        activity('a1', name: 'Mystery package', type: ActivityType.summary),
      ]);

      expect(out.map((w) => w.activityId), ['a1']);
    });

    test('skips activities with a blank name', () {
      final out = collectScheduleWorkPackages([
        activity('a1', name: '   '),
        activity('a2', name: 'Kept'),
      ]);

      expect(out.map((w) => w.activityId), ['a2']);
    });

    test('normalises blank link fields to null and trims them', () {
      final out = collectScheduleWorkPackages([
        activity('a1', wbsCode: '  ', costLineId: ''),
        activity('a2', wbsCode: ' G1.3 ', costLineId: ' line_9 '),
      ]);

      expect(out[0].wbsRef, isNull);
      expect(out[0].activityCostLineId, isNull);
      expect(out[1].wbsRef, 'G1.3');
      expect(out[1].activityCostLineId, 'line_9');
    });

    test('carries each work package\'s own domain into its category', () {
      final out = collectScheduleWorkPackages([
        activity('a1', domain: ScheduleDomain.engineering),
        activity('a2', domain: ScheduleDomain.procurement),
        activity('a3', domain: ScheduleDomain.construction),
      ]);

      expect(out.map((w) => w.category), [
        CostCategory.labor,
        CostCategory.procurement,
        CostCategory.construction,
      ]);
    });

    test('finds nested leaves in every branch of a wide tree', () {
      final out = collectScheduleWorkPackages([
        activity('s1', name: 'Stage A', children: [
          activity('a1', name: 'A leaf'),
          activity('a2', name: 'A stage', children: [
            activity('a2x', name: 'A deep leaf'),
          ]),
        ]),
        activity('s2', name: 'Stage B', children: [
          activity('b1', name: 'B leaf'),
        ]),
      ]);

      expect(out.map((w) => w.activityId).toSet(), {'a1', 'a2x', 'b1'});
    });
  });
}
