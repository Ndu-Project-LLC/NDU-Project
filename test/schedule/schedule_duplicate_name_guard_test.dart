// The app must never hold two items that bear the same name — the Schedule
// list showed "Platform Foundation Engineering Work Package" twice (codes 1 and
// 10) because an import run re-generated chains under fresh ids, which no
// id-based filter could catch.
//
// The guard is name-based and lives in the shared key helper, the duplicate
// rule in schedule_duplicate_guard.dart, and the ScheduleProvider that
// persists the tree. Package-level identity dedupe is unchanged and covered
// by test/services/work_package_identity_dedupe_test.dart.

import 'package:flutter_test/flutter_test.dart';
import 'package:ndu_project/schedule/models/schedule_models.dart';
import 'package:ndu_project/schedule/providers/schedule_provider.dart';
import 'package:ndu_project/utils/item_name_key.dart';
import 'package:shared_preferences/shared_preferences.dart';

ScheduleActivity activity(
  String id,
  String name, {
  int level = 2,
  List<ScheduleActivity> children = const [],
}) =>
    ScheduleActivity(
      id: id,
      level: level,
      code: '',
      name: name,
      type: ActivityType.activity,
      domain: ScheduleDomain.engineering,
      dependencies: const [],
      aiGenerated: false,
      children: children,
    );

Future<ScheduleProvider> loadedProvider() async {
  SharedPreferences.setMockInitialValues({});
  final provider = ScheduleProvider();
  await Future<void>.delayed(Duration.zero);
  provider.setup(
    projectId: 'proj-1',
    projectName: 'Zala connect',
    deliveryModel: 'WATERFALL',
  );
  return provider;
}

/// Every activity name in the tree, root included.
List<String> namesIn(Schedule schedule) {
  final out = <String>[];
  void walk(ScheduleActivity node) {
    if (node.level > 0) out.add(node.name);
    node.children.forEach(walk);
  }

  schedule.activities.forEach(walk);
  return out;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('itemNameKey', () {
    test('treats cosmetic differences as the same name', () {
      expect(itemNameKey('Site Prep'), itemNameKey('  site   prep '));
      expect(itemNameKey('Site prep.'), itemNameKey('Site prep'));
      expect(itemNameKey('Procurement — Vessels'),
          itemNameKey('Procurement - Vessels'));
      // Older saved records store the doubled form of the generated title.
      expect(
        itemNameKey('Platform Foundation Engineering Engineering Work Package'),
        itemNameKey('Platform Foundation Engineering Work Package'),
      );
    });

    test('keeps genuinely different names apart', () {
      expect(itemNameKey('Long-Lead Vessels'),
          isNot(itemNameKey('Short-Lead Vessels')));
      expect(itemNameKey('Long-Lead Vessels'),
          isNot(itemNameKey('Long Lead Vessels Extra')));
    });

    test('a blank name never matches anything', () {
      expect(itemNameKey('   '), isEmpty);
      expect(isSameItemName('', ''), isFalse);
      expect(isSameItemName('', 'Site prep'), isFalse);
    });
  });

  group('dedupeItemsByName', () {
    test('keeps the first of each name and preserves order', () {
      final out = dedupeItemsByName(
        ['Alpha', 'Beta', 'alpha', 'Gamma', 'BETA'],
        (value) => value,
      );
      expect(out, ['Alpha', 'Beta', 'Gamma']);
    });
  });

  group('ScheduleProvider', () {
    test('adding an activity whose name already exists reuses that record',
        () async {
      final provider = await loadedProvider();
      addTearDown(provider.dispose);

      final firstId = provider.addActivity(
        provider.schedule!.activities.first.id,
        activity('seed', 'Platform Foundation Engineering Work Package'),
      );
      expect(firstId, isNotEmpty);

      // Same import run again: the existing record is returned, not a copy.
      final secondId = provider.addActivity(
        provider.schedule!.activities.first.id,
        activity('seed-2', 'Platform Foundation Engineering Work Package'),
      );
      expect(secondId, firstId);

      final names = namesIn(provider.schedule!);
      expect(
        names
            .where((name) =>
                name == 'Platform Foundation Engineering Work Package')
            .length,
        1,
      );
    });

    test('a name that differs only cosmetically is still a duplicate',
        () async {
      final provider = await loadedProvider();
      addTearDown(provider.dispose);

      provider.addActivity(
        provider.schedule!.activities.first.id,
        activity('seed', 'Platform Foundation Engineering Work Package'),
      );
      provider.addActivity(
        provider.schedule!.activities.first.id,
        activity('seed-2', '  platform foundation engineering work package. '),
      );

      expect(namesIn(provider.schedule!), hasLength(1));
    });

    test('a whole-tree write collapses duplicates already stored', () async {
      final provider = await loadedProvider();
      addTearDown(provider.dispose);

      final root = provider.schedule!.activities.first;
      provider.setActivities([
        root.copyWith(
          children: [
            activity('a', 'Platform Foundation Engineering Work Package'),
            activity(
              'b',
              'Platform Foundation Engineering Work Package',
              children: [activity('b1', 'Sub-task only on the copy')],
            ),
            activity('c', 'Procurement — Long-Lead Vessels'),
          ],
        ),
      ]);

      final names = namesIn(provider.schedule!);
      expect(
        names
            .where((name) =>
                name == 'Platform Foundation Engineering Work Package')
            .length,
        1,
        reason: 'the second copy must not survive the write',
      );
      expect(
        names,
        contains('Sub-task only on the copy'),
        reason: 'children of the dropped copy are lifted onto the survivor',
      );
      expect(names, contains('Procurement — Long-Lead Vessels'));
    });

    test('renaming onto a name another activity holds is rejected', () async {
      final provider = await loadedProvider();
      addTearDown(provider.dispose);

      final first = provider.addActivity(
        provider.schedule!.activities.first.id,
        activity('seed', 'Site Mobilization'),
      );
      provider.addActivity(
        provider.schedule!.activities.first.id,
        activity('seed-2', 'Mechanical Install'),
      );

      provider.updateActivity(
        first,
        activity(first, 'Mechanical Install', level: 0),
      );

      expect(namesIn(provider.schedule!), contains('Site Mobilization'));
      expect(
        namesIn(provider.schedule!)
            .where((name) => name == 'Mechanical Install')
            .length,
        1,
      );
    });

    test('two activities linked to different WBS nodes both survive', () async {
      final provider = await loadedProvider();
      addTearDown(provider.dispose);

      // Same displayed name, different real work: not a duplicate.
      provider.setActivities([
        provider.schedule!.activities.first.copyWith(
          children: [
            activity('a1', 'Site Mobilization').copyWith(wbsNodeId: 'n1'),
            activity('a2', 'Site Mobilization').copyWith(wbsNodeId: 'n2'),
          ],
        ),
      ]);
      expect(namesIn(provider.schedule!), hasLength(2));

      // Re-running the same import (same WBS nodes) collapses to one each.
      provider.setActivities([
        provider.schedule!.activities.first.copyWith(
          children: [
            activity('a1', 'Site Mobilization').copyWith(wbsNodeId: 'n1'),
            activity('a1-copy', 'Site Mobilization').copyWith(wbsNodeId: 'n1'),
          ],
        ),
      ]);
      expect(namesIn(provider.schedule!), hasLength(1));
    });

    test('re-saving an activity under its own name is not a clash', () async {
      final provider = await loadedProvider();
      addTearDown(provider.dispose);

      final id = provider.addActivity(
        provider.schedule!.activities.first.id,
        activity('seed', 'Site Mobilization'),
      );
      provider.updateActivity(
        id,
        activity(id, 'Site Mobilization', level: 0)
            .copyWith(description: 'Mobilise the site'),
      );

      expect(namesIn(provider.schedule!), hasLength(1));
    });
  });
}