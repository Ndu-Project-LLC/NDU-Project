// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// Stakeholder Announcement — model + template knowledge base
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// Powers the "Announcements" tab (4th tab) of the Stakeholder Management
// screen. Provides:
//
//   1. A [StakeholderAnnouncement] model — a single announcement record
//      authored against a specific audience level (one of the four
//      Influence/Interest matrix quadrants OR "Project Team").
//
//   2. A curated [StakeholderAnnouncementTemplate] knowledge base —
//      real-world, ready-to-use templates that the user can pick from to
//      seed the composer. NO AI generation here — every template is a
//      hand-written starting point that the user can tailor. The user
//      spec was explicit: "announcement templates that can be used for
//      each Engagement Plan/level including the project team section".
//
// Audience levels (kept in sync with the Influence/Interest matrix used
// elsewhere in the stakeholder screen):
//   - 'Manage Closely'  — high influence / high interest (key players)
//   - 'Keep Satisfied'  — high influence / low interest
//   - 'Keep Informed'   — low influence / high interest
//   - 'Monitor'         — low influence / low interest
//   - 'Project Team'    — internal team members (treated as Manage Closely
//                          by default; segmented here for template routing)
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

/// The five audience levels an announcement can target. Kept as a
/// `const` list so the UI can iterate without duplicating strings.
const List<String> kStakeholderAnnouncementAudienceLevels = [
  'Manage Closely',
  'Keep Satisfied',
  'Keep Informed',
  'Monitor',
  'Project Team',
];

/// The channels a stakeholder announcement can be delivered through.
/// Aligned with the channels referenced in the Engagement Plan table
/// (In-app, Email, Phone Call, Town Hall, Slack/Teams) so the same
/// vocabulary is used throughout the stakeholder screen.
const List<String> kStakeholderAnnouncementChannels = [
  'Email',
  'In-app',
  'Slack/Teams',
  'Phone Call',
  'Town Hall',
];

/// The lifecycle states for an announcement.
const List<String> kStakeholderAnnouncementStatuses = [
  'Draft',
  'Scheduled',
  'Sent',
];

/// A single stakeholder announcement record. Authored against a specific
/// audience level (one of the four matrix quadrants or "Project Team").
class StakeholderAnnouncement {
  String id;
  String title;
  String body;
  String audienceLevel;
  String channel;
  String status;
  DateTime createdAt;
  DateTime? updatedAt;
  DateTime? scheduledFor;
  String createdBy;
  String templateId;

  StakeholderAnnouncement({
    String? id,
    required this.title,
    required this.body,
    required this.audienceLevel,
    this.channel = 'Email',
    this.status = 'Draft',
    DateTime? createdAt,
    this.updatedAt,
    this.scheduledFor,
    this.createdBy = '',
    this.templateId = '',
  })  : id = id ?? DateTime.now().microsecondsSinceEpoch.toString(),
        createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'body': body,
        'audienceLevel': audienceLevel,
        'channel': channel,
        'status': status,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt?.toIso8601String(),
        'scheduledFor': scheduledFor?.toIso8601String(),
        'createdBy': createdBy,
        'templateId': templateId,
      };

  factory StakeholderAnnouncement.fromJson(Map<String, dynamic> json) {
    return StakeholderAnnouncement(
      id: json['id']?.toString(),
      title: json['title']?.toString() ?? '',
      body: json['body']?.toString() ?? '',
      audienceLevel: json['audienceLevel']?.toString() ?? 'Manage Closely',
      channel: json['channel']?.toString() ?? 'Email',
      status: json['status']?.toString() ?? 'Draft',
      createdAt:
          DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
              DateTime.now(),
      updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? ''),
      scheduledFor:
          DateTime.tryParse(json['scheduledFor']?.toString() ?? ''),
      createdBy: json['createdBy']?.toString() ?? '',
      templateId: json['templateId']?.toString() ?? '',
    );
  }

  StakeholderAnnouncement copyWith({
    String? title,
    String? body,
    String? audienceLevel,
    String? channel,
    String? status,
    DateTime? updatedAt,
    DateTime? scheduledFor,
    String? createdBy,
    String? templateId,
  }) {
    return StakeholderAnnouncement(
      id: id,
      title: title ?? this.title,
      body: body ?? this.body,
      audienceLevel: audienceLevel ?? this.audienceLevel,
      channel: channel ?? this.channel,
      status: status ?? this.status,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      scheduledFor: scheduledFor ?? this.scheduledFor,
      createdBy: createdBy ?? this.createdBy,
      templateId: templateId ?? this.templateId,
    );
  }
}

/// A hand-written announcement template. The user picks a template to
/// pre-fill the composer; they can then tailor the wording before saving.
/// Every template is a real-world, industry-standard starting point —
/// no AI hallucination, no fluff.
class StakeholderAnnouncementTemplate {
  final String id;
  final String title;
  final String subject;
  final String body;
  final String audienceLevel;
  final String channel;
  final String useCase;

  const StakeholderAnnouncementTemplate({
    required this.id,
    required this.title,
    required this.subject,
    required this.body,
    required this.audienceLevel,
    required this.channel,
    required this.useCase,
  });
}

/// Curated template knowledge base. Grouped by audience level so the
/// UI can render them as pickable chips inside level-grouped sections.
///
/// Each template carries a `useCase` so the user knows when to reach for
/// it. The `body` is written in second person, ready to copy/paste into
/// an email or chat — the user just needs to fill in the {{placeholders}}.
class StakeholderAnnouncementTemplates {
  const StakeholderAnnouncementTemplates._();

  static const List<StakeholderAnnouncementTemplate> all = [
    // ── Manage Closely (high influence / high interest) ──────────────
    StakeholderAnnouncementTemplate(
      id: 'mc_kickoff_briefing',
      title: 'Project Kickoff Briefing',
      subject: 'Project {{project_name}} — Kickoff Briefing',
      audienceLevel: 'Manage Closely',
      channel: 'In-app',
      useCase: 'Use at project launch to align key players on objectives, '
          'scope, and governance before work begins.',
      body: 'Hello,\n\n'
          'This is to confirm that {{project_name}} will officially kick off '
          'on {{kickoff_date}}. As a key stakeholder, your engagement is '
          'critical to the project\'s success.\n\n'
          'Project objectives: {{objectives}}\n'
          'In-scope: {{in_scope}}\n'
          'Out-of-scope: {{out_of_scope}}\n'
          'Key milestones: {{milestones}}\n\n'
          'Governance cadence:\n'
          ' - Weekly status: {{weekly_status_day}}\n'
          ' - Steering committee: monthly\n'
          ' - Decision log: maintained in the project workspace\n\n'
          'Please confirm receipt and raise any concerns before the '
          'kickoff meeting.\n\n'
          'Regards,\n{{sender_name}}',
    ),
    StakeholderAnnouncementTemplate(
      id: 'mc_weekly_status',
      title: 'Weekly Status Update',
      subject: 'Weekly Status — {{project_name}} (Week {{week_no}})',
      audienceLevel: 'Manage Closely',
      channel: 'Email',
      useCase: 'Weekly digest sent to key players summarizing progress, '
          'blockers, and decisions needed.',
      body: 'Hi all,\n\n'
          'Here is the weekly status for {{project_name}}.\n\n'
          'Status: {{rag_status}}\n'
          'Progress this week: {{progress}}\n'
          'Planned for next week: {{planned}}\n\n'
          'Risks / Issues:\n{{risks}}\n\n'
          'Decisions needed:\n{{decisions}}\n\n'
          'Dashboard: {{dashboard_link}}\n\n'
          'Please review and flag anything I\'ve missed before '
          '{{review_deadline}}.\n\n'
          'Regards,\n{{sender_name}}',
    ),
    StakeholderAnnouncementTemplate(
      id: 'mc_critical_escalation',
      title: 'Critical Issue Escalation',
      subject: 'ESCALATION — {{project_name}}: {{issue_summary}}',
      audienceLevel: 'Manage Closely',
      channel: 'Phone Call',
      useCase: 'Use when a critical issue threatens project objectives and '
          'requires same-day decision-making from key players.',
      body: 'Hello,\n\n'
          'I am escalating a critical issue on {{project_name}} that requires '
          'your decision today.\n\n'
          'Issue: {{issue_summary}}\n'
          'Impact: {{impact}}\n'
          'Owner: {{issue_owner}}\n'
          'Detected at: {{detected_at}}\n\n'
          'Options:\n'
          ' 1. {{option_1}}\n'
          ' 2. {{option_2}}\n'
          ' 3. {{option_3}}\n\n'
          'Recommendation: {{recommendation}}\n\n'
          'I will call you at {{phone_number}} at {{call_time}} to discuss. '
          'Please confirm availability or propose an alternative time.\n\n'
          'Regards,\n{{sender_name}}',
    ),

    // ── Keep Satisfied (high influence / low interest) ───────────────
    StakeholderAnnouncementTemplate(
      id: 'ks_monthly_exec_summary',
      title: 'Monthly Executive Summary',
      subject: 'Monthly Executive Summary — {{project_name}} ({{month}})',
      audienceLevel: 'Keep Satisfied',
      channel: 'Email',
      useCase: 'Monthly one-page summary for senior stakeholders who need to '
          'stay informed but do not require weekly detail.',
      body: 'Hello,\n\n'
          'Please find below the monthly executive summary for '
          '{{project_name}}.\n\n'
          'Overall status: {{rag_status}}\n'
          'Budget consumed: {{budget_pct}}%\n'
          'Schedule: {{schedule_var}} days vs plan\n'
          'Open risks: {{open_risks}}\n\n'
          'Key achievements this month:\n{{achievements}}\n\n'
          'Focus for next month:\n{{focus_next}}\n\n'
          'Full dashboard: {{dashboard_link}}\n\n'
          'No action required from your side this cycle. I will reach out '
          'directly if a decision is needed.\n\n'
          'Regards,\n{{sender_name}}',
    ),
    StakeholderAnnouncementTemplate(
      id: 'ks_quarterly_briefing',
      title: 'Quarterly Briefing',
      subject: 'Quarterly Briefing — {{project_name}} (Q{{quarter}})',
      audienceLevel: 'Keep Satisfied',
      channel: 'In-app',
      useCase: 'Quarterly briefing for senior stakeholders — covers '
          'strategic progress, financials, and forward outlook.',
      body: 'Hello,\n\n'
          'The Q{{quarter}} briefing for {{project_name}} is now available.\n\n'
          'Strategic progress: {{strategic_progress}}\n'
          'Financial position: {{financials}}\n'
          'Risks to watch next quarter: {{forward_risks}}\n\n'
          'Key decision points for next quarter:\n{{decisions_next}}\n\n'
          'Briefing deck: {{deck_link}}\n\n'
          'The steering committee will review this on {{steering_date}}. '
          'Please share any input before then.\n\n'
          'Regards,\n{{sender_name}}',
    ),

    // ── Keep Informed (low influence / high interest) ────────────────
    StakeholderAnnouncementTemplate(
      id: 'ki_milestone_reached',
      title: 'Milestone Reached Announcement',
      subject: 'Milestone Reached — {{milestone_name}}',
      audienceLevel: 'Keep Informed',
      channel: 'Email',
      useCase: 'Sent when a major project milestone is achieved, to keep '
          'interested stakeholders engaged and motivated.',
      body: 'Hello,\n\n'
          'We are pleased to share that {{project_name}} has reached the '
          '{{milestone_name}} milestone on {{milestone_date}}.\n\n'
          'What was delivered: {{delivered}}\n'
          'What this means: {{impact}}\n'
          'Next milestone: {{next_milestone}} (target: {{next_target}})\n\n'
          'Thank you for your continued interest and support.\n\n'
          'Regards,\n{{sender_name}}',
    ),
    StakeholderAnnouncementTemplate(
      id: 'ki_newsletter',
      title: 'Project Newsletter',
      subject: '{{project_name}} Newsletter — {{edition_title}}',
      audienceLevel: 'Keep Informed',
      channel: 'Email',
      useCase: 'Periodic newsletter sent to a broad interested audience. '
          'Use monthly or per-phase.',
      body: 'Welcome to the {{edition_title}} edition of the '
          '{{project_name}} newsletter.\n\n'
          'In this edition:\n'
          ' - {{headline_1}}\n'
          ' - {{headline_2}}\n'
          ' - {{headline_3}}\n\n'
          'Spotlight: {{spotlight}}\n\n'
          'Upcoming: {{upcoming}}\n\n'
          'How to get involved: {{get_involved}}\n\n'
          'Read the full edition: {{newsletter_link}}\n\n'
          'Regards,\n{{sender_name}}',
    ),

    // ── Monitor (low influence / low interest) ───────────────────────
    StakeholderAnnouncementTemplate(
      id: 'mn_change_notification',
      title: 'Project Change Notification',
      subject: 'Change Notification — {{project_name}}: {{change_summary}}',
      audienceLevel: 'Monitor',
      channel: 'Email',
      useCase: 'Sent only when a change to the project (scope, schedule, '
          'budget, or leadership) is significant enough to warrant '
          'notification to the wider stakeholder base.',
      body: 'Hello,\n\n'
          'This is a notification that the following change has been '
          'approved on {{project_name}}:\n\n'
          'Change: {{change_summary}}\n'
          'Reason: {{change_reason}}\n'
          'Effective date: {{effective_date}}\n'
          'Impact: {{change_impact}}\n\n'
          'No action is required from your side. Please reach out if you '
          'have any questions.\n\n'
          'Regards,\n{{sender_name}}',
    ),

    // ── Project Team (internal team members) ─────────────────────────
    StakeholderAnnouncementTemplate(
      id: 'pt_sprint_kickoff',
      title: 'Sprint Kickoff',
      subject: 'Sprint {{sprint_no}} Kickoff — {{project_name}}',
      audienceLevel: 'Project Team',
      channel: 'Slack/Teams',
      useCase: 'Sent at the start of each sprint / work cycle to align the '
          'team on goals, capacity, and commitments.',
      body: 'Team,\n\n'
          'Sprint {{sprint_no}} kicks off {{kickoff_time}}.\n\n'
          'Sprint goal: {{sprint_goal}}\n'
          'Capacity: {{capacity}}\n'
          'Committed scope:\n{{committed_scope}}\n\n'
          'Key ceremonies:\n'
          ' - Planning: {{planning_time}}\n'
          ' - Daily standup: {{standup_time}} (every day)\n'
          ' - Review: {{review_time}}\n'
          ' - Retro: {{retro_time}}\n\n'
          'Sprint board: {{board_link}}\n\n'
          'Let\'s make it a good one.\n{{sender_name}}',
    ),
    StakeholderAnnouncementTemplate(
      id: 'pt_retro_invitation',
      title: 'Retrospective Invitation',
      subject: 'Retrospective — Sprint {{sprint_no}} — {{retro_time}}',
      audienceLevel: 'Project Team',
      channel: 'In-app',
      useCase: 'Sent 24-48 hours before the sprint retrospective to invite '
          'the team and prompt pre-input.',
      body: 'Team,\n\n'
          'The sprint {{sprint_no}} retrospective is scheduled for '
          '{{retro_time}} at {{retro_location}}.\n\n'
          'Please add your input to the retro board before the meeting:\n'
          ' - What went well\n'
          ' - What didn\'t go well\n'
          ' - What we should change next sprint\n\n'
          'Retro board: {{retro_board_link}}\n\n'
          'See you there.\n{{sender_name}}',
    ),
    StakeholderAnnouncementTemplate(
      id: 'pt_recognition_shoutout',
      title: 'Recognition Shout-out',
      subject: 'Shout-out — {{recognized_name}}',
      audienceLevel: 'Project Team',
      channel: 'Slack/Teams',
      useCase: 'Public team recognition for a member who went above and '
          'beyond. Aligns with the Team Member Recognition process.',
      body: 'Team,\n\n'
          'Big shout-out to {{recognized_name}} for {{recognition_reason}}.\n\n'
          'This is a great example of {{value_demonstrated}} and deserves '
          'recognition. Thank you for raising the bar.\n\n'
          'If you\'d like to add your own note of appreciation, reply in '
          'thread.\n\n'
          '{{sender_name}}',
    ),
    StakeholderAnnouncementTemplate(
      id: 'pt_daily_standup_reminder',
      title: 'Daily Standup Reminder',
      subject: 'Standup reminder — {{standup_time}}',
      audienceLevel: 'Project Team',
      channel: 'Slack/Teams',
      useCase: 'Short reminder sent 5-10 minutes before the daily standup. '
          'Automate via scheduler if possible.',
      body: 'Friendly reminder: standup in {{minutes_until}} minutes at '
          '{{standup_time}} ({{standup_location}}).\n\n'
          'Come ready to share:\n'
          ' - What you did yesterday\n'
          ' - What you\'re doing today\n'
          ' - Any blockers\n\n'
          'Join: {{standup_link}}',
    ),
  ];

  /// Returns all templates for a given audience level, in their declared
  /// order. Empty list if the level has no templates (shouldn't happen
  /// with the current KB, but defensive).
  static List<StakeholderAnnouncementTemplate> forAudience(
      String audienceLevel) {
    return all
        .where((t) => t.audienceLevel == audienceLevel)
        .toList(growable: false);
  }
}
