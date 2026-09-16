import 'package:flutter_test/flutter_test.dart';
import 'package:ndu_project/utils/role_catalogue.dart';
import 'package:ndu_project/utils/role_description_bank.dart';
import 'package:ndu_project/utils/role_descriptions.dart';

void main() {
  group('role description bank', () {
    test('describes every catalogued role', () {
      final missing = <String>[];
      for (final title in comprehensiveRoleTitles) {
        if (roleDescriptionFor(title).trim().isEmpty) missing.add(title);
      }
      expect(missing, isEmpty,
          reason: 'These roles would auto-fill nothing: '
              '${missing.take(10).join(', ')}');
    });

    test('assigns a discipline to every catalogued role', () {
      final missing = <String>[];
      for (final title in comprehensiveRoleTitles) {
        if (roleWorkstreamFor(title).trim().isEmpty) missing.add(title);
      }
      expect(missing, isEmpty,
          reason: 'These roles have no discipline: '
              '${missing.take(10).join(', ')}');
    });

    test('maps every catalogued role to a catalogue discipline', () {
      final missing = <String>[];
      for (final title in comprehensiveRoleTitles) {
        if (roleDisciplineFor(title).trim().isEmpty) missing.add(title);
      }
      expect(missing, isEmpty);
    });

    test('descriptions are meaningful, not stubs', () {
      final stubs = <String>[];
      for (final title in comprehensiveRoleTitles) {
        if (roleDescriptionFor(title).trim().length < 20) stubs.add(title);
      }
      expect(stubs, isEmpty,
          reason: 'Placeholder-looking descriptions: '
              '${stubs.take(10).join(', ')}');
    });

    test('keeps the wording the screens used before', () {
      expect(
        roleDescriptionFor('Project Manager'),
        'Overall project leadership, planning, and coordination across all phases.',
      );
      expect(roleWorkstreamFor('Quality Assurance Lead'), 'Quality');
      expect(roleWorkstreamFor('Planning Engineer'), 'Engineering');
    });

    test('prefers the wider hand-written bank where it covers a title', () {
      // 'Solution Architect' and friends live in role_descriptions.dart; they
      // should resolve to that wording rather than a composed sentence.
      const banked = 'Solution Architect';
      expect(comprehensiveRoleTitles, contains(banked));
      expect(roleDescriptionFor(banked), roleDescriptions[banked]!.description);
      expect(roleWorkstreamFor(banked), roleDescriptions[banked]!.discipline);
    });

    test('still answers for a title outside the catalogue', () {
      expect(roleDisciplineFor('Chief Bottle Washer'), isEmpty);
      expect(roleDescriptionFor('Chief Bottle Washer').trim(), isNotEmpty);
      expect(roleWorkstreamFor('Chief Bottle Washer'), isEmpty);
    });

    test('composes role-appropriate sentences', () {
      // Sanity-check a few archetypes so the templates cannot silently
      // collapse into one generic sentence.
      expect(roleDescriptionFor('Welder'), contains('Delivers'));
      expect(roleDescriptionFor('Data Analyst'), contains('Analyses'));
      expect(roleDescriptionFor('Chief Operating Officer'),
          contains('senior leadership'));
      expect(roleDescriptionFor('Enterprise Architect'),
          contains('architecture'));
      expect(roleDescriptionFor('Cost Estimator'), contains('estimates'));
    });
  });
}
