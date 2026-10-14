import 'package:flutter_test/flutter_test.dart';
import 'package:ndu_project/models/project_data_model.dart';
import 'package:ndu_project/services/integrated_work_package_service.dart';

void main() {
  WorkPackage package(String classification, String title) => WorkPackage(
        packageClassification: classification,
        title: title,
      );

  group('packageActivityName', () {
    test('leaves a title that already names its type alone', () {
      final name = IntegratedWorkPackageService.packageActivityName(
        package(
          IntegratedWorkPackageService.engineeringEwp,
          '1.1 Authentication & Security Engineering Engineering Work Package',
        ),
      );

      // The stored title's doubled word is collapsed for display, and the
      // classification is not prefixed on top of the type the title carries.
      expect(name, '1.1 Authentication & Security Engineering Work Package');
      expect(name, isNot(contains('Engineering Engineering')));
      expect(name, isNot(contains('engineeringEwp')));
      expect(name, isNot(contains(':')));
    });

    test('prefixes in short form when the title names no type', () {
      expect(
        IntegratedWorkPackageService.packageActivityName(
          package(IntegratedWorkPackageService.procurementPackage,
              '1.1 Pump House'),
        ),
        'Procurement · 1.1 Pump House',
      );
    });

    test('falls back to the type label for an untitled package', () {
      expect(
        IntegratedWorkPackageService.packageActivityName(
          package(IntegratedWorkPackageService.constructionCwp, '   '),
        ),
        'Construction Work Package',
      );
    });

    test('names an unrecognised classification without inventing a prefix', () {
      expect(
        IntegratedWorkPackageService.packageActivityName(
          package('', '1.1 Site survey'),
        ),
        '1.1 Site survey',
      );
    });
  });

  group('packageTitleWithType', () {
    test('keeps a word shared with the title once', () {
      expect(
        IntegratedWorkPackageService.packageTitleWithType(
          '1.1 Authentication & Security Engineering',
          'Engineering Work Package',
        ),
        '1.1 Authentication & Security Engineering Work Package',
      );
    });

    test('joins normally when nothing is shared', () {
      expect(
        IntegratedWorkPackageService.packageTitleWithType(
            '1.1 Pump House', 'Procurement Package'),
        '1.1 Pump House Procurement Package',
      );
    });

    test('keeps single-word suffixes that tell sibling packages apart', () {
      expect(
        IntegratedWorkPackageService.packageTitleWithType(
            '1.1 Substation', 'Commissioning'),
        '1.1 Substation Commissioning',
      );
    });

    test('tolerates a title that is only whitespace', () {
      expect(
        IntegratedWorkPackageService.packageTitleWithType(
            '   ', 'Engineering Work Package'),
        'Engineering Work Package',
      );
    });
  });

  test('generated chains read without a doubled word or raw classification',
      () {
    final wbs = <WorkItem>[
      WorkItem(
        id: 'root',
        title: 'Lusaka 25',
        children: [
          WorkItem(
            id: 'l2',
            title: 'Engineering',
            children: [
              WorkItem(
                id: 'leaf',
                title: '1.1 Authentication & Security Engineering',
              ),
            ],
          ),
        ],
      ),
    ];

    final packages = IntegratedWorkPackageService.generatePackageChainsFromWbs(
      wbsTree: wbs,
      methodology: 'waterfall',
    );

    expect(packages, isNotEmpty);

    final ewp = packages.firstWhere((p) =>
        p.packageClassification == IntegratedWorkPackageService.engineeringEwp);
    expect(ewp.title, '1.1 Authentication & Security Engineering Work Package');

    final names =
        packages.map(IntegratedWorkPackageService.packageActivityName).toList();
    for (final name in names) {
      expect(name, isNot(contains('Engineering Engineering')));
      expect(name, isNot(contains('engineeringEwp')));
      expect(name, matches(RegExp(r'^\S')));
    }
  });
}
