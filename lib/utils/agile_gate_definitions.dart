/// The three gates a backlog item passes through, in the order the review asked
/// for: a story must be **ready**, then meet its **acceptance criteria**, and
/// only then is it **done**.
///
/// The middle gate belongs to Acceptance Criteria Planning. The outer two belong
/// to Backlog Governance, and this file is the only reader of them — so the
/// Acceptance Criteria page shows what governance actually defined instead of
/// keeping a second copy that drifts.
enum AgileGateStage {
  definitionOfReady,
  acceptanceCriteria,
  definitionOfDone;

  String get label => switch (this) {
        AgileGateStage.definitionOfReady => 'Definition of Ready',
        AgileGateStage.acceptanceCriteria => 'Acceptance Criteria',
        AgileGateStage.definitionOfDone => 'Definition of Done',
      };

  /// Whether this gate is set on the Acceptance Criteria page, as opposed to
  /// being echoed from Backlog Governance.
  bool get ownedByAcceptanceCriteria =>
      this == AgileGateStage.acceptanceCriteria;
}

/// One gate as it will be displayed: its ordered checklist, or the prose
/// definition when the project left checklist mode off.
class AgileGateDefinition {
  const AgileGateDefinition({
    required this.stage,
    required this.items,
    this.freeText = '',
    this.usesChecklist = false,
    this.isCustom = false,
  });

  final AgileGateStage stage;

  /// Checklist entries, resolved to the defaults when the project saved none.
  final List<String> items;

  /// The prose definition (the non-checklist form).
  final String freeText;

  /// Whether Backlog Governance is showing this gate as a checklist. When it
  /// is off, the prose definition is what the user maintains.
  final bool usesChecklist;

  /// True when [items] came from the project's saved list rather than the
  /// built-in defaults.
  final bool isCustom;

  String get label => stage.label;

  /// Where this gate is maintained.
  String get source => stage.ownedByAcceptanceCriteria
      ? 'Set on this page'
      : 'Set in Backlog Governance';

  bool get hasFreeText => freeText.trim().isNotEmpty;

  /// What to render: the checklist when governance is in checklist mode, the
  /// prose when it is not and there is prose, and the checklist otherwise.
  List<String> get displayLines {
    if (usesChecklist) return items;
    if (hasFreeText) return [freeText.trim()];
    return items;
  }

  /// One-line description of what the gate holds, for the panel header.
  String get summary {
    final lines = displayLines;
    if (lines.isEmpty) return 'Not defined yet.';
    final shown = lines.take(3).join(', ');
    final extra = lines.length > 3 ? ' +${lines.length - 3} more' : '';
    return '$shown$extra';
  }
}

class AgileGateDefinitions {
  AgileGateDefinitions._();

  /// The gate order, outer gates from governance and the middle one from this
  /// section. Nothing should render these out of order.
  static const List<AgileGateStage> order = [
    AgileGateStage.definitionOfReady,
    AgileGateStage.acceptanceCriteria,
    AgileGateStage.definitionOfDone,
  ];

  /// Checkpoint of the screen that owns the outer gates.
  static const String governanceCheckpoint = 'agile_backlog_governance';

  static const String governanceScreenLabel = 'Backlog Governance';

  /// Saved keys, matching `agile_backlog_governance_screen.dart`.
  static const String readyChecklistKey = 'dor_checklist';
  static const String doneChecklistKey = 'dod_checklist';
  static const String readyChecklistModeKey = 'dor_use_checklist';
  static const String doneChecklistModeKey = 'dod_use_checklist';
  static const String readyFreeTextKey = 'definition_of_ready';
  static const String doneFreeTextKey = 'definition_of_done';

  /// Seed definitions, used when a project has not customised the gate. These
  /// are the same lists Backlog Governance seeds its editor with.
  static const List<String> defaultReadyItems = [
    'Story written and described',
    'Acceptance criteria defined',
    'Dependencies identified',
    'Designs/UX available (if applicable)',
    'Business approval obtained',
    'Estimated (story points or size)',
    'Test approach identified',
    'Edge cases documented',
  ];

  static const List<String> defaultDoneItems = [
    'Code complete',
    'Peer reviewed',
    'Unit tests pass',
    'Integration tests pass',
    'Acceptance criteria met',
    'Documentation updated',
    'Deployed to staging',
    'Product Owner approved',
  ];

  /// The Definition of Ready gate as Backlog Governance saved it.
  static AgileGateDefinition ready(Map<String, dynamic> governance) =>
      _read(
        stage: AgileGateStage.definitionOfReady,
        governance: governance,
        checklistKey: readyChecklistKey,
        checklistModeKey: readyChecklistModeKey,
        freeTextKey: readyFreeTextKey,
        fallback: defaultReadyItems,
      );

  /// The Definition of Done gate as Backlog Governance saved it.
  static AgileGateDefinition done(Map<String, dynamic> governance) =>
      _read(
        stage: AgileGateStage.definitionOfDone,
        governance: governance,
        checklistKey: doneChecklistKey,
        checklistModeKey: doneChecklistModeKey,
        freeTextKey: doneFreeTextKey,
        fallback: defaultDoneItems,
      );

  /// The governed gate for [stage], or null for the middle gate — acceptance
  /// criteria are defined on the Acceptance Criteria page, not echoed.
  static AgileGateDefinition? forStage(
    AgileGateStage stage,
    Map<String, dynamic> governance,
  ) =>
      switch (stage) {
        AgileGateStage.definitionOfReady => ready(governance),
        AgileGateStage.definitionOfDone => done(governance),
        AgileGateStage.acceptanceCriteria => null,
      };

  /// Labels from a saved checklist (`[{id, label, checked}]`), dropping blanks.
  static List<String> checklistLabels(Object? raw) {
    if (raw is! List) return const [];
    return [
      for (final entry in raw)
        if (entry is Map &&
            (entry['label']?.toString().trim().isNotEmpty ?? false))
          entry['label'].toString().trim(),
    ];
  }

  static AgileGateDefinition _read({
    required AgileGateStage stage,
    required Map<String, dynamic> governance,
    required String checklistKey,
    required String checklistModeKey,
    required String freeTextKey,
    required List<String> fallback,
  }) {
    final saved = checklistLabels(governance[checklistKey]);
    final freeText = governance[freeTextKey] as String? ?? '';
    return AgileGateDefinition(
      stage: stage,
      items: saved.isNotEmpty ? saved : fallback,
      freeText: freeText,
      usesChecklist: governance[checklistModeKey] == true,
      isCustom: saved.isNotEmpty,
    );
  }
}
