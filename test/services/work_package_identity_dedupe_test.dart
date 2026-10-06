// Identity dedupe for generated work packages.
//
// The schedule's "WBS Packages" section showed the same package row five times
// over ("1.1 Authentication & Security Engine Engineering Work Package", 7
// days each). Two holes let that happen:
//
//   1. The design screen appended generated chains with no dedupe at all, and
//      the other generation screens filtered only by exact id — so
//      regenerating after a rebuilt WBS (fresh node ids, same names) stacked a
//      second copy of every package under new ids.
//   2. PlanningSyncService rebuilds the package rows from the saved package
//      list on every sync, faithfully materialising the duplicates as schedule
//      activities each time.
//
// The fix is a package identity (collapsed title + classification) and dedupe
// helpers applied at every append, in the generator, at the schedule-network
// builder, and in the sync itself.
import 'package:flutter_test/flutter_test.dart';
import 'package:ndu_project/models/project_data_model.dart';
import 'package:ndu_project/services/integrated_work_package_service.dart';

void main() {
  WorkPackage package(
    String classification,
    String title, {
    String? id,
  }) =>
      WorkPackage(
        id: id,
        packageClassification: classification,
        title: title,
      );

  group('packageIdentityKey', () {
    test('ignores the id a package was minted with', () {
      expect(
        IntegratedWorkPackageService.packageIdentityKey(
            package(IntegratedWorkPackageService.engineeringEwp, 'Pump House',
                id: 'a')),
        IntegratedWorkPackageService.packageIdentityKey(
            package(IntegratedWorkPackageService.engineeringEwp, 'Pump House',
                id: 'b')),
      );
    });

    test('collapses the historical doubled-word titles', () {
      // Projects saved while titles still stuttered ("… Engineering
      // Engineering Work Package") must match their regenerated twins.
      expect(
        IntegratedWorkPackageService.packageIdentityKey(
          package(IntegratedWorkPackageService.engineeringEwp,
              '1.1 Auth Engineering Engineering Work Package'),
        ),
        IntegratedWorkPackageService.packageIdentityKey(
          package(IntegratedWorkPackageService.engineeringEwp,
              '1.1 Auth Engineering Work Package'),
        ),
      );
    });

    test('is case- and whitespace-insensitive', () {
      expect(
        IntegratedWorkPackageService.packageIdentityKey(
            package(IntegratedWorkPackageService.engineeringEwp,
                '  1.1 Pump House  ')),
        IntegratedWorkPackageService.packageIdentityKey(
            package(IntegratedWorkPackageService.engineeringEwp,
                '1.1 pump house')),
      );
    });

    test('keeps different classifications apart', () {
      expect(
        IntegratedWorkPackageService.packageIdentityKey(
            package(IntegratedWorkPackageService.engineeringEwp,
                '1.1 Pump House')),
        isNot(IntegratedWorkPackageService.packageIdentityKey(
            package(IntegratedWorkPackageService.procurementPackage,
                '1.1 Pump House'))),
      );
    });
  });

  group('dedupePackages', () {
    test('keeps the first of each identity within one batch', () {
      final out = IntegratedWorkPackageService.dedupePackages([
        package(IntegratedWorkPackageService.engineeringEwp, 'Pump House',
            id: 'a'),
        package(IntegratedWorkPackageService.engineeringEwp, 'Pump House',
            id: 'b'),
        package(IntegratedWorkPackageService.procurementPackage, 'Pump House',
            id: 'c'),
      ]);

      expect(out.map((p) => p.id), ['a', 'c']);
    });
  });

  group('dedupePackagesAgainst', () {
    test('drops candidates that restate an existing package', () {
      final existing = [
        package(IntegratedWorkPackageService.engineeringEwp, 'Pump House'),
      ];
      final out = IntegratedWorkPackageService.dedupePackagesAgainst(
        [
          package(IntegratedWorkPackageService.engineeringEwp, 'Pump House',
              id: 'fresh-id'),
          package(IntegratedWorkPackageService.engineeringEwp, 'Substation',
              id: 'also-fresh'),
        ],
        existing,
      );

      expect(out.map((p) => p.id), ['also-fresh']);
    });

    test('keeps everything when nothing overlaps', () {
      final out = IntegratedWorkPackageService.dedupePackagesAgainst(
        [package(IntegratedWorkPackageService.engineeringEwp, 'New leaf')],
        [package(IntegratedWorkPackageService.engineeringEwp, 'Old leaf')],
      );

      expect(out, hasLength(1));
    });
  });

  group('generatePackageChainsFromWbs', () {
    test('a WBS leaf listed twice yields one chain, not two', () {
      final tree = [
        WorkItem(id: 'l2', title: 'Authentication & Security', children: [
          WorkItem(id: 'leaf-1', title: '1.1 Auth & Security Engineering'),
          // The same node pasted twice (a malformed WBS): same title, new id.
          WorkItem(id: 'leaf-2', title: '1.1 Auth & Security Engineering'),
        ]),
      ];

      final packages =
          IntegratedWorkPackageService.generatePackageChainsFromWbs(
        wbsTree: tree,
        methodology: 'waterfall',
      );

      // One leaf's chain: EWP + procurement + execution.
      expect(packages, hasLength(3));
      expect(
        packages.map((p) => p.title).toSet(),
        hasLength(3),
      );
    });
  });

  group('generateScheduleActivitiesFromPackages', () {
    test('a saved package list holding duplicates yields one activity', () {
      final duplicated = [
        package(IntegratedWorkPackageService.engineeringEwp,
            '1.1 Auth & Security Engineering Work Package',
            id: 'wp-1'),
        package(IntegratedWorkPackageService.engineeringEwp,
            '1.1 Auth & Security Engineering Work Package',
            id: 'wp-2'),
        package(IntegratedWorkPackageService.engineeringEwp,
            '1.1 Auth & Security Engineering Work Package',
            id: 'wp-3'),
      ];

      final activities =
          IntegratedWorkPackageService.generateScheduleActivitiesFromPackages(
        packages: duplicated,
      );

      expect(activities, hasLength(1));
    });
  });
}
