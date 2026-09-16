import 'package:flutter_test/flutter_test.dart';
import 'package:ndu_project/utils/role_catalogue.dart';

void main() {
  group('role catalogue', () {
    test('is comprehensive', () {
      expect(
        comprehensiveRoleTitles.length,
        greaterThanOrEqualTo(250),
        reason: 'The role picker is meant to cover every plausible project '
            'role, so the catalogue should stay very long.',
      );
    });

    test('contains no duplicates', () {
      final seen = <String, int>{};
      final duplicates = <String>[];
      for (final title in comprehensiveRoleTitles) {
        final count = (seen[title] ?? 0) + 1;
        seen[title] = count;
        if (count > 1) duplicates.add(title);
      }
      expect(duplicates, isEmpty,
          reason: 'Duplicate role titles: ${duplicates.toSet().join(', ')}');
    });

    test('contains no blank or padded titles', () {
      for (final title in comprehensiveRoleTitles) {
        expect(title, title.trim());
        expect(title.isNotEmpty, isTrue);
      }
    });

    test('keeps the long-standing roles available', () {
      // These titles existed before the catalogue was extracted; removing one
      // would silently drop it from both pickers.
      const legacyTitles = <String>[
        'Project Manager',
        'Project Sponsor (Owner)',
        'Program Manager',
        'Product Owner',
        'Scrum Master',
        'Business Analyst',
        'PMO Lead',
        'PMO Manager',
        'Delivery Manager',
        'Operations Manager',
        'Risk Manager',
        'Quality Assurance Lead',
        'Quality Lead',
        'Change Manager',
        'Stakeholder Manager',
        'Planning Engineer',
        'Project Coordinator',
        'Portfolio Manager',
        'SSHER Lead',
        'Contracts Manager',
        'Contracts Lead',
        'Procurement Manager',
        'Tech Lead',
        'Lead Developer',
        'Lead Designer',
        'Engineering Manager',
        'Technical Manager',
        'Construction Manager',
        'Startup Manager',
        'Release Manager',
        'Cost Lead',
        'Cost Estimator',
        'Schedule Lead',
        'Scheduler',
        'Test Lead',
        'Technical Architect',
        'Solutions Architect',
        'Design Engineer',
        'Data Specialist',
        'Developer - Backend',
        'Developer - Frontend',
        'Business Manager',
        'Project Engineer',
        'Engineer',
      ];
      for (final title in legacyTitles) {
        expect(comprehensiveRoleTitles, contains(title));
      }
    });

    test('grouping covers exactly the flat list', () {
      final grouped = roleTitlesByDiscipline.values.expand((r) => r).toList();
      expect(grouped, hasLength(comprehensiveRoleTitles.length));
      expect(grouped, containsAll(comprehensiveRoleTitles));
    });

    test('groups titles under discipline headings in catalogue order', () {
      final groups = groupRolesByDiscipline(comprehensiveRoleTitles);

      expect(groups.map((g) => g.label), roleTitlesByDiscipline.keys);
      expect(
        groups.expand((g) => g.titles).toList(),
        comprehensiveRoleTitles,
      );
    });

    test('collects uncatalogued titles into a trailing Other group', () {
      final groups = groupRolesByDiscipline(
        [...comprehensiveRoleTitles, 'Custom'],
      );

      expect(groups.last.label, 'Other');
      expect(groups.last.titles, ['Custom']);
    });

    test('grouping ignores titles that are not requested', () {
      final groups = groupRolesByDiscipline(
        ['Project Manager', 'Scrum Master', 'Custom'],
      );

      expect(groups, hasLength(2));
      expect(groups.first.label, 'Leadership & Project Management');
      expect(groups.first.titles, ['Project Manager', 'Scrum Master']);
      expect(groups.last.titles, ['Custom']);
    });

    test('grouping handles an empty request', () {
      expect(groupRolesByDiscipline(const []), isEmpty);
    });

    test('starts with the leadership roles', () {
      expect(
        comprehensiveRoleTitles.take(5),
        containsAll(<String>['Project Manager', 'Program Manager']),
      );
    });
  });
}
