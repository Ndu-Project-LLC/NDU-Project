// The review renamed the template section to "User Story Template" and asked
// for several named templates with one marked default ("they can name the
// template and decide what it will be from"), so a newly created story starts
// from that default. These tests pin the pure rules behind the section and the
// story-creation path, neither of which needs Firestore to be checked.

import 'package:flutter_test/flutter_test.dart';

import 'package:ndu_project/models/acceptance_criteria.dart';
import 'package:ndu_project/models/feature_model.dart';
import 'package:ndu_project/utils/agile_story_template.dart';
import 'package:ndu_project/utils/auto_bullet_text_controller.dart';

AcceptanceCriteriaTemplate _template({
  required String id,
  required String name,
  bool isDefault = false,
  WorkItemType type = WorkItemType.userStory,
  List<String> criteria = const [],
}) {
  final template = AcceptanceCriteriaTemplate(
    id: id,
    name: name,
    isDefault: isDefault,
    workItemType: type,
  );
  template.criteria
      .addAll(criteria.map((d) => AcceptanceCriterion(description: d)));
  return template;
}

void main() {
  final feature = Feature(id: 'feat-a1', epicId: 'epic-a', title: 'Sign up');

  group('the section is a User Story Template', () {
    test('its heading is what the owner asked for', () {
      expect(AgileStoryTemplate.sectionTitle, 'User Story Template');
    });
  });

  group('several named templates coexist', () {
    test('all user-story templates are listed, names intact', () {
      final config = AcceptanceCriteriaConfig(templates: [
        _template(id: 't1', name: 'Standard user story'),
        _template(id: 't2', name: 'Technical user story'),
      ]);

      expect(
        AgileStoryTemplate.userStoryTemplates(config).map((t) => t.name),
        ['Standard user story', 'Technical user story'],
      );
    });

    test('templates for other work item types stay out of the story list', () {
      final config = AcceptanceCriteriaConfig(templates: [
        _template(id: 't1', name: 'Standard user story'),
        _template(id: 'e1', name: 'Epic acceptance', type: WorkItemType.epic),
      ]);

      expect(
        AgileStoryTemplate.userStoryTemplates(config).map((t) => t.id),
        ['t1'],
      );
    });
  });

  group('one template is the default', () {
    test('the marked default wins over order', () {
      final config = AcceptanceCriteriaConfig(templates: [
        _template(id: 't1', name: 'Standard'),
        _template(id: 't2', name: 'Technical', isDefault: true),
      ]);

      expect(AgileStoryTemplate.defaultTemplate(config)?.name, 'Technical');
    });

    test('with nothing marked, the first user-story template is the default',
        () {
      final config = AcceptanceCriteriaConfig(templates: [
        _template(id: 'e1', name: 'Epic acceptance', type: WorkItemType.epic),
        _template(id: 't1', name: 'Standard'),
      ]);

      expect(AgileStoryTemplate.defaultTemplate(config)?.name, 'Standard');
    });

    test('with no story template it falls back to the first template of any '
        'type, then to nothing', () {
      final epicOnly = AcceptanceCriteriaConfig(templates: [
        _template(id: 'e1', name: 'Epic acceptance', type: WorkItemType.epic),
      ]);

      expect(AgileStoryTemplate.defaultTemplate(epicOnly)?.name,
          'Epic acceptance');
      expect(AgileStoryTemplate.defaultTemplate(AcceptanceCriteriaConfig()),
          isNull);
    });

    test('markDefault leaves exactly one default', () {
      final config = AcceptanceCriteriaConfig(templates: [
        _template(id: 't1', name: 'Standard'),
        _template(id: 't2', name: 'Technical', isDefault: true),
      ]);

      AgileStoryTemplate.markDefault(config.templates, 't1');

      expect(config.templates.where((t) => t.isDefault).map((t) => t.id),
          ['t1']);
    });

    test('ensureDefault backfills a config saved before the flag existed', () {
      final config = AcceptanceCriteriaConfig(templates: [
        _template(id: 't1', name: 'Standard'),
        _template(id: 't2', name: 'Technical'),
      ]);

      final chosen = AgileStoryTemplate.ensureDefault(config);

      expect(chosen?.id, 't1');
      expect(config.templates.where((t) => t.isDefault).length, 1);
    });

    test('ensureDefault collapses several defaults down to one', () {
      final config = AcceptanceCriteriaConfig(templates: [
        _template(id: 't1', name: 'Standard', isDefault: true),
        _template(id: 't2', name: 'Technical', isDefault: true),
      ]);

      AgileStoryTemplate.ensureDefault(config);

      expect(config.templates.where((t) => t.isDefault).length, 1);
    });
  });

  group('the default seeds a new story', () {
    test('its criteria become the story acceptance criteria, bullet by bullet',
        () {
      final config = AcceptanceCriteriaConfig(templates: [
        _template(id: 't1', name: 'Standard',
            criteria: ['User can sign up with email', '   ']),
      ]);

      final story = AgileStoryTemplate.newStoryFor(
          feature: feature, config: config);

      expect(story.acceptanceCriteria,
          '${kListBullet}User can sign up with email',
          reason: 'blank criteria must not produce a stray bullet');
    });

    test('the marked default is the one used, not the first template', () {
      final config = AcceptanceCriteriaConfig(templates: [
        _template(id: 't1', name: 'Standard', criteria: ['Standard criterion']),
        _template(id: 't2', name: 'Technical', isDefault: true,
            criteria: ['Technical criterion']),
      ]);

      final story = AgileStoryTemplate.newStoryFor(
          feature: feature, config: config);

      expect(story.acceptanceCriteria, contains('Technical criterion'));
      expect(story.acceptanceCriteria, isNot(contains('Standard criterion')));
    });

    test('the story is still linked to its feature and epic', () {
      final story = AgileStoryTemplate.newStoryFor(
        feature: feature,
        config: AcceptanceCriteriaConfig(templates: [
          _template(id: 't1', name: 'Standard', criteria: ['A criterion']),
        ]),
      );

      expect(story.featureId, 'feat-a1');
      expect(story.epicId, 'epic-a');
      expect(story.userStory, 'New story 1');
    });

    test('with no template at all the story is created without criteria', () {
      final story = AgileStoryTemplate.newStoryFor(feature: feature);

      expect(story.acceptanceCriteria, '');
      expect(story.featureId, 'feat-a1');
    });
  });
}
