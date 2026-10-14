import 'package:ndu_project/models/acceptance_criteria.dart';
import 'package:ndu_project/models/agile_task.dart';
import 'package:ndu_project/models/feature_model.dart';
import 'package:ndu_project/utils/agile_story_linkage.dart';
import 'package:ndu_project/utils/auto_bullet_text_controller.dart';

/// The **User Story Template** section of Acceptance Criteria Planning.
///
/// The review renamed the old generic "Templates" block ("it has to be called a
/// user story template"), asked for several named templates — technical user
/// stories and the like — with one of them the default, and for that default to
/// be what a newly created story actually starts from ("they can name it. So
/// they can name the template and decide what it will be from").
///
/// Everything here is pure so the screen, the create-template dialog and the
/// story-creation paths all agree, and so the rules can be tested without
/// Firestore.
class AgileStoryTemplate {
  AgileStoryTemplate._();

  /// Section heading. The *page* is still the Acceptance Criteria Planning
  /// checkpoint in the flow — only the template section is renamed.
  static const String sectionTitle = 'User Story Template';

  /// Badge on the template a new story will start from.
  static const String defaultBadge = 'Default';

  /// Templates that read as user-story templates, in list order.
  static List<AcceptanceCriteriaTemplate> userStoryTemplates(
    AcceptanceCriteriaConfig config,
  ) =>
      config.templates
          .where((t) => t.workItemType == WorkItemType.userStory)
          .toList();

  /// The template a new story starts from.
  ///
  /// The user's marked default wins; otherwise the first user-story template;
  /// otherwise the first template of any type, so a project that only defines
  /// an epic template still has something to seed from. Null when the config
  /// has no templates at all.
  static AcceptanceCriteriaTemplate? defaultTemplate(
    AcceptanceCriteriaConfig config,
  ) {
    final stories = userStoryTemplates(config);
    for (final t in stories) {
      if (t.isDefault) return t;
    }
    if (stories.isNotEmpty) return stories.first;
    for (final t in config.templates) {
      if (t.isDefault) return t;
    }
    return config.templates.isEmpty ? null : config.templates.first;
  }

  /// Make [id] the one default across [templates] — and only that one.
  static void markDefault(
    List<AcceptanceCriteriaTemplate> templates,
    String id,
  ) {
    for (final t in templates) {
      t.isDefault = t.id == id;
    }
  }

  /// Guarantee exactly one default, so a config saved before the flag existed
  /// (or one whose default was deleted, or one that arrived with several) still
  /// has a single template a new story can start from.
  ///
  /// Returns the template now marked, or null when there are none.
  static AcceptanceCriteriaTemplate? ensureDefault(
    AcceptanceCriteriaConfig config,
  ) {
    final marked = config.templates.where((t) => t.isDefault).toList();
    if (marked.length == 1) return marked.first;
    final target = defaultTemplate(config);
    if (target == null) return null;
    markDefault(config.templates, target.id);
    return target;
  }

  /// The bullet list a new story's `acceptanceCriteria` starts with, built from
  /// [template]'s criteria in the app's `• ` list format.
  ///
  /// Blank criteria are skipped rather than emitted as stray bullets, and a
  /// template with nothing filled in yields an empty string — never a lone dot.
  static String acceptanceCriteriaFor(AcceptanceCriteriaTemplate? template) {
    if (template == null) return '';
    return template.criteria
        .map((c) => c.description.trim())
        .where((d) => d.isNotEmpty)
        .map((d) => '$kListBullet$d')
        .join('\n');
  }

  /// A new story under [feature], seeded with the default template's criteria.
  ///
  /// Linkage is not duplicated here: the story is born through
  /// [AgileStoryLinkage.newStoryFor], so it still carries the feature and the
  /// feature's epic. The template only adds the acceptance criteria.
  static AgileTask newStoryFor({
    required Feature feature,
    Iterable<AgileTask> existing = const [],
    String? title,
    AcceptanceCriteriaConfig? config,
  }) {
    final story = AgileStoryLinkage.newStoryFor(
      feature: feature,
      existing: existing,
      title: title,
    );
    if (config == null) return story;
    return story.copyWith(
      acceptanceCriteria: acceptanceCriteriaFor(defaultTemplate(config)),
    );
  }
}
