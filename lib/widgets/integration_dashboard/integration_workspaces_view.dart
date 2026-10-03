import 'package:flutter/material.dart';

import 'package:ndu_project/services/dashboard_metrics_service.dart';
import 'package:ndu_project/services/project_service.dart';
import 'package:ndu_project/widgets/integration_dashboard/_integration_tokens.dart';
import 'package:ndu_project/widgets/integration_dashboard/integration_dashboard_parts.dart';

/// The workspace half of the Integration Dashboard.
///
/// This is the "which of my projects needs me?" question: a portfolio roll-up
/// across every basic-plan workspace the user owns, a resume card pointing at
/// the one they last touched, and a searchable, responsive grid of the
/// workspaces themselves.
///
/// Everything here is derived from [DashboardMetrics] (status rollups) and
/// the live [ProjectRecord] stream, so the numbers and the cards can never
/// disagree with each other.
class IntegrationWorkspacesView extends StatelessWidget {
  const IntegrationWorkspacesView({
    super.key,
    required this.tokens,
    required this.projects,
    required this.metrics,
    required this.isLoading,
    required this.error,
    required this.searchController,
    required this.searchQuery,
    required this.onSearchChanged,
    required this.onRetry,
    required this.onOpenProject,
    required this.onCreateProject,
  });

  final IntegrationTokens tokens;

  /// Already filtered to basic-plan workspaces, newest activity first.
  final List<ProjectRecord> projects;

  final DashboardMetrics? metrics;
  final bool isLoading;
  final String? error;
  final TextEditingController searchController;
  final String searchQuery;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onRetry;
  final ValueChanged<ProjectRecord> onOpenProject;
  final VoidCallback onCreateProject;

  /// Rollups keyed by project id, restricted to the workspaces on screen.
  Map<String, ProjectStatusRollup> get _statusesById {
    final all = metrics?.projectStatuses ?? const <ProjectStatusRollup>[];
    final visible = projects.map((p) => p.id).toSet();
    return {
      for (final s in all)
        if (visible.contains(s.projectId)) s.projectId: s,
    };
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading && metrics == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: IntegrationBusyWorkspaceCard(),
      );
    }

    if (error != null && metrics == null) {
      return IntegrationErrorCard(
        tokens: tokens,
        message: error!,
        onRetry: onRetry,
      );
    }

    if (projects.isEmpty) {
      return IntegrationEmptyWorkspacesCard(
        tokens: tokens,
        onCreateProject: onCreateProject,
      );
    }

    final statuses = _statusesById;
    final filtered = _filter(projects);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _PortfolioStatsRow(
          tokens: tokens,
          projects: projects,
          statuses: statuses,
        ),
        const SizedBox(height: 14),
        _PortfolioHealthBento(
          tokens: tokens,
          projects: projects,
          statuses: statuses,
        ),
        const SizedBox(height: 14),
        _ResumeCard(
          tokens: tokens,
          projects: projects,
          onOpenProject: onOpenProject,
          onCreateProject: onCreateProject,
        ),
        const SizedBox(height: 14),
        _SearchField(
          tokens: tokens,
          controller: searchController,
          query: searchQuery,
          resultCount: filtered.length,
          totalCount: projects.length,
          onChanged: onSearchChanged,
        ),
        const SizedBox(height: 12),
        if (filtered.isEmpty)
          _NoSearchResults(tokens: tokens, query: searchQuery)
        else
          _ProjectGrid(
            tokens: tokens,
            projects: filtered,
            statuses: statuses,
            onOpenProject: onOpenProject,
          ),
      ],
    );
  }

  List<ProjectRecord> _filter(List<ProjectRecord> source) {
    final q = searchQuery.trim().toLowerCase();
    if (q.isEmpty) return source;
    return source.where((p) {
      return p.name.toLowerCase().contains(q) ||
          p.solutionTitle.toLowerCase().contains(q) ||
          p.businessCase.toLowerCase().contains(q) ||
          p.milestone.toLowerCase().contains(q) ||
          p.ownerName.toLowerCase().contains(q) ||
          p.tags.any((t) => t.toLowerCase().contains(q));
    }).toList(growable: false);
  }
}

// ──────────────────────────────────────────────────────────────────────
// Portfolio roll-up
// ──────────────────────────────────────────────────────────────────────

class _PortfolioStatsRow extends StatelessWidget {
  const _PortfolioStatsRow({
    required this.tokens,
    required this.projects,
    required this.statuses,
  });

  final IntegrationTokens tokens;
  final List<ProjectRecord> projects;
  final Map<String, ProjectStatusRollup> statuses;

  @override
  Widget build(BuildContext context) {
    int onTrack = 0, atRisk = 0, offTrack = 0;
    for (final p in projects) {
      switch (statuses[p.id]?.overallStatus) {
        case 'on_track':
          onTrack++;
        case 'at_risk':
          atRisk++;
        case 'off_track':
          offTrack++;
        case _:
          break;
      }
    }
    final avgProgress = projects.isEmpty
        ? 0.0
        : projects.map((p) => p.progress).reduce((a, b) => a + b) /
            projects.length;

    return IntegrationTileGrid(
      minTileWidth: 210,
      children: [
        IntegrationStatTile(
          tokens: tokens,
          label: 'On Track',
          value: '$onTrack',
          sublabel: 'healthy workspaces',
          icon: Icons.check_circle_rounded,
          accent: tokens.good,
        ),
        IntegrationStatTile(
          tokens: tokens,
          label: 'At Risk',
          value: '$atRisk',
          sublabel: 'need attention',
          icon: Icons.warning_amber_rounded,
          accent: tokens.warn,
        ),
        IntegrationStatTile(
          tokens: tokens,
          label: 'Off Track',
          value: '$offTrack',
          sublabel: 'blocked / stalled',
          icon: Icons.error_outline_rounded,
          accent: tokens.bad,
        ),
        IntegrationStatTile(
          tokens: tokens,
          label: 'Avg. Progress',
          value: '${(avgProgress * 100).round()}%',
          sublabel: 'across all workspaces',
          icon: Icons.trending_up_rounded,
          accent: tokens.brandDeep,
        ),
      ],
    );
  }
}

/// Six cross-cutting health indicators. Deliberately answers "where is the
/// portfolio bleeding?" rather than repeating the headline counts above.
class _PortfolioHealthBento extends StatelessWidget {
  const _PortfolioHealthBento({
    required this.tokens,
    required this.projects,
    required this.statuses,
  });

  final IntegrationTokens tokens;
  final List<ProjectRecord> projects;
  final Map<String, ProjectStatusRollup> statuses;

  @override
  Widget build(BuildContext context) {
    final rolls = statuses.values.toList(growable: false);
    final total = projects.length;

    int countWhere(bool Function(ProjectStatusRollup) test) =>
        rolls.where(test).length;

    final openRisks = rolls.fold<int>(
      0,
      (sum, s) => sum + (s.openRisks ?? 0),
    );
    final openIssues = rolls.fold<int>(
      0,
      (sum, s) => sum + (s.openIssues ?? 0),
    );

    // NOTE: ProjectStatusRollup.budgetUsedPercent is already a 0–100 value
    // (DashboardMetricsService multiplies the ratio by 100 when inferring it).
    // The previous dashboard multiplied by 100 a second time, so a project
    // burning 30% of budget rendered as "3000%". Averaging the raw percentage
    // is the fix; anything with no rollup data is excluded rather than
    // dragging the average toward zero.
    final budgetSamples = rolls
        .map((s) => s.budgetUsedPercent)
        .whereType<double>()
        .toList(growable: false);
    final avgBudget = budgetSamples.isEmpty
        ? null
        : budgetSamples.reduce((a, b) => a + b) / budgetSamples.length;

    String healthy(String key) =>
        '${countWhere((s) => _field(s, key) == 'on_track')}/$total';

    return IntegrationCard(
      tokens: tokens,
      color: tokens.surfaceAlt,
      borderColor: tokens.outlineSoft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IntegrationSectionTitle(
            tokens: tokens,
            icon: Icons.analytics_outlined,
            title: 'Portfolio Health',
            subtitle:
                'Cross-cutting indicators across every workspace in view.',
            trailing: Text(
              '$total project${total == 1 ? '' : 's'}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: tokens.muted,
              ),
            ),
          ),
          const SizedBox(height: 14),
          IntegrationTileGrid(
            minTileWidth: 155,
            children: [
              IntegrationMiniKpi(
                tokens: tokens,
                label: 'Open Risks',
                value: '$openRisks',
                icon: Icons.warning_amber_outlined,
                accent: tokens.bad,
                hint: 'open high or critical risks',
              ),
              IntegrationMiniKpi(
                tokens: tokens,
                label: 'Open Issues',
                value: '$openIssues',
                icon: Icons.error_outline_outlined,
                accent: tokens.warn,
                hint: 'open or pending quality issues',
              ),
              IntegrationMiniKpi(
                tokens: tokens,
                label: 'Avg Budget Used',
                value: avgBudget == null
                    ? '—'
                    : '${avgBudget.clamp(0, 999).toStringAsFixed(0)}%',
                icon: Icons.savings_outlined,
                accent: tokens.brandDeep,
                hint: avgBudget == null
                    ? 'no budget data reported yet'
                    : 'average across workspaces with cost data',
              ),
              IntegrationMiniKpi(
                tokens: tokens,
                label: 'Schedule Healthy',
                value: healthy('scheduleStatus'),
                icon: Icons.schedule_outlined,
                accent: tokens.good,
                hint: 'workspaces with an on-track schedule',
              ),
              IntegrationMiniKpi(
                tokens: tokens,
                label: 'Cost Healthy',
                value: healthy('costStatus'),
                icon: Icons.attach_money_outlined,
                accent: tokens.good,
                hint: 'workspaces within budget',
              ),
              IntegrationMiniKpi(
                tokens: tokens,
                label: 'Scope Healthy',
                value: healthy('scopeStatus'),
                icon: Icons.account_tree_outlined,
                accent: tokens.good,
                hint: 'workspaces with an on-track scope',
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _field(ProjectStatusRollup s, String key) {
    switch (key) {
      case 'scheduleStatus':
        return s.scheduleStatus;
      case 'costStatus':
        return s.costStatus;
      case 'scopeStatus':
        return s.scopeStatus;
      case 'qualityStatus':
        return s.qualityStatus;
      case 'riskStatus':
        return s.riskStatus;
      default:
        return s.overallStatus;
    }
  }
}

// ──────────────────────────────────────────────────────────────────────
// Resume card
// ──────────────────────────────────────────────────────────────────────

class _ResumeCard extends StatelessWidget {
  const _ResumeCard({
    required this.tokens,
    required this.projects,
    required this.onOpenProject,
    required this.onCreateProject,
  });

  final IntegrationTokens tokens;
  final List<ProjectRecord> projects;
  final ValueChanged<ProjectRecord> onOpenProject;
  final VoidCallback onCreateProject;

  @override
  Widget build(BuildContext context) {
    final hasProjects = projects.isNotEmpty;
    final latest = hasProjects ? projects.first : null;

    return LayoutBuilder(
      builder: (context, constraints) {
        final stacked = constraints.maxWidth < 620;
        final text = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              hasProjects
                  ? 'Continue where you left off'
                  : 'Start your first project',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.2,
                color: tokens.ink,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              hasProjects
                  ? latest != null
                      ? '“${_displayName(latest)}” was last touched '
                          '${relativeTime(latest.updatedAt)} — we\'ll resume '
                          'exactly where you stopped.'
                      : 'Pick the workspace you last touched — we\'ll resume '
                          'exactly where you stopped.'
                  : 'In under five minutes you\'ll have a project framework, '
                      'core stakeholder map, and a draft business case.',
              style: TextStyle(
                fontSize: 12.5,
                height: 1.5,
                color: tokens.muted,
              ),
            ),
            if (hasProjects && latest != null) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  IntegrationChip(
                    tokens: tokens,
                    label: phaseLabelFor(latest.progress),
                    icon: Icons.timeline_rounded,
                    accent: tokens.brandDeep,
                  ),
                  IntegrationChip(
                    tokens: tokens,
                    label: '${(latest.progress * 100).round()}% complete',
                    icon: Icons.donut_small_rounded,
                    accent: tokens.brandDeep,
                  ),
                  if (latest.tags.isNotEmpty)
                    IntegrationChip(
                      tokens: tokens,
                      label: latest.tags.first,
                      icon: Icons.sell_outlined,
                    ),
                ],
              ),
            ],
          ],
        );

        final cta = FilledButton.icon(
          onPressed: () =>
              hasProjects && latest != null ? onOpenProject(latest) : onCreateProject(),
          style: FilledButton.styleFrom(
            backgroundColor: tokens.brand,
            foregroundColor: tokens.onBrand,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          icon: const Icon(Icons.arrow_forward_rounded, size: 17),
          label: Text(
            hasProjects ? 'Open last project' : 'Begin initiation',
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
          ),
        );

        final badge = Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: tokens.brandSoft,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Icon(
            hasProjects
                ? Icons.rocket_launch_rounded
                : Icons.wb_sunny_rounded,
            color: tokens.brandDeep,
            size: 28,
          ),
        );

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                tokens.brandSoft,
                tokens.surface,
              ],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: tokens.outline),
            boxShadow: [
              BoxShadow(
                color: tokens.shadow,
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: stacked
              // Narrow layout: badge sits beside the copy, CTA drops below.
              // The copy already carries the heading, so it is rendered once.
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        badge,
                        const SizedBox(width: 14),
                        Expanded(child: text),
                      ],
                    ),
                    const SizedBox(height: 18),
                    cta,
                  ],
                )
              : Row(
                  children: [
                    badge,
                    const SizedBox(width: 18),
                    Expanded(child: text),
                    const SizedBox(width: 14),
                    cta,
                  ],
                ),
        );
      },
    );
  }
}

// ──────────────────────────────────────────────────────────────────────
// Search
// ──────────────────────────────────────────────────────────────────────

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.tokens,
    required this.controller,
    required this.query,
    required this.resultCount,
    required this.totalCount,
    required this.onChanged,
  });

  final IntegrationTokens tokens;
  final TextEditingController controller;
  final String query;
  final int resultCount;
  final int totalCount;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: controller,
          onChanged: onChanged,
          textInputAction: TextInputAction.search,
          style: TextStyle(fontSize: 14, color: tokens.ink),
          decoration: InputDecoration(
            hintText: 'Search workspaces, tags, solutions…',
            hintStyle: TextStyle(color: tokens.mutedSoft, fontSize: 13),
            prefixIcon: Icon(Icons.search_rounded, size: 20, color: tokens.muted),
            suffixIcon: query.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Clear search',
                    icon: Icon(Icons.close_rounded, size: 18, color: tokens.muted),
                    onPressed: () {
                      controller.clear();
                      onChanged('');
                    },
                  ),
            filled: true,
            fillColor: tokens.surface,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: tokens.outline),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: tokens.outline),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: tokens.brand, width: 1.6),
            ),
          ),
        ),
        if (query.trim().isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            '$resultCount of $totalCount workspace'
            '${totalCount == 1 ? '' : 's'} match “${query.trim()}”',
            style: TextStyle(fontSize: 11.5, color: tokens.muted),
          ),
        ],
      ],
    );
  }
}

class _NoSearchResults extends StatelessWidget {
  const _NoSearchResults({required this.tokens, required this.query});

  final IntegrationTokens tokens;
  final String query;

  @override
  Widget build(BuildContext context) {
    return IntegrationStatePanel(
      tokens: tokens,
      icon: Icons.search_off_rounded,
      title: 'No workspaces match that search',
      message: 'Nothing here matches “${query.trim()}”. Try a different '
          'name, tag, or solution.',
      accent: tokens.muted,
    );
  }
}

// ──────────────────────────────────────────────────────────────────────
// Project grid
// ──────────────────────────────────────────────────────────────────────

class _ProjectGrid extends StatelessWidget {
  const _ProjectGrid({
    required this.tokens,
    required this.projects,
    required this.statuses,
    required this.onOpenProject,
  });

  final IntegrationTokens tokens;
  final List<ProjectRecord> projects;
  final Map<String, ProjectStatusRollup> statuses;
  final ValueChanged<ProjectRecord> onOpenProject;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final cols = w >= 1500
            ? 3
            : w >= 980
                ? 2
                : 1;
        const gap = 14.0;
        final tileWidth = (w - gap * (cols - 1)) / cols;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final p in projects)
              SizedBox(
                width: tileWidth,
                child: WorkspaceProjectCard(
                  tokens: tokens,
                  project: p,
                  rollup: statuses[p.id],
                  onTap: () => onOpenProject(p),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// A single workspace card.
///
/// Carries enough identity to recognise a project without opening it
/// (icon, name, solution, health pill), a two-line brief, progress, and the
/// derived lifecycle phase.
class WorkspaceProjectCard extends StatelessWidget {
  const WorkspaceProjectCard({
    super.key,
    required this.tokens,
    required this.project,
    required this.rollup,
    required this.onTap,
  });

  final IntegrationTokens tokens;
  final ProjectRecord project;
  final ProjectStatusRollup? rollup;
  final VoidCallback onTap;

  static const _emojiIcons = <String, IconData>{
    'initiation': Icons.rocket_launch_rounded,
    'planning': Icons.map_outlined,
    'execution': Icons.handyman_outlined,
    'closure': Icons.flag_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final status = rollup?.overallStatus ?? 'unknown';
    final accent = tokens.health(status);
    final progress = (project.progress * 100).clamp(0.0, 100.0);
    final phase = phaseLabelFor(project.progress);
    final description = _descriptionFor(project);
    final owner = project.ownerName.trim();

    return Semantics(
      button: true,
      label: '${_displayName(project)}, $phase, '
          '${(progress / 100 * 100).round()} percent complete',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Ink(
            decoration: BoxDecoration(
              color: tokens.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: tokens.outline),
              boxShadow: [
                BoxShadow(
                  color: tokens.shadow,
                  blurRadius: 16,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: tokens.brandSoft,
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: Icon(
                        _emojiIcons[phase.toLowerCase()] ??
                            Icons.folder_special_rounded,
                        color: tokens.brandDeep,
                        size: 21,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _displayName(project),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.2,
                              color: tokens.ink,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            project.solutionTitle.trim().isEmpty
                                ? 'No solution defined yet'
                                : project.solutionTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: tokens.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    IntegrationPill(
                      tokens: tokens,
                      label: healthLabel(status),
                      accent: accent,
                    ),
                  ],
                ),
                if (description.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: tokens.surfaceAlt,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: tokens.outlineSoft),
                    ),
                    child: Text(
                      description,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.45,
                        color: tokens.inkSoft,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                Row(
                  children: [
                    Text(
                      'Progress',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.4,
                        color: tokens.muted,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${progress.toStringAsFixed(0)}%',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: accent,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: progress / 100,
                    minHeight: 7,
                    backgroundColor: tokens.surfaceSunken,
                    valueColor: AlwaysStoppedAnimation<Color>(accent),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Icons.schedule_rounded, size: 13, color: tokens.mutedSoft),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        owner.isEmpty
                            ? 'Updated ${relativeTime(project.updatedAt)}'
                            : '${owner.split(' ').first} · '
                                '${relativeTime(project.updatedAt)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: tokens.muted,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IntegrationChip(
                      tokens: tokens,
                      label: phase,
                      accent: tokens.brandDeep,
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.arrow_forward_rounded,
                      size: 16,
                      color: tokens.brandDeep,
                    ),
                  ],
                ),
                if (project.tags.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final tag in project.tags.take(3))
                        IntegrationChip(tokens: tokens, label: tag),
                      if (project.tags.length > 3)
                        IntegrationChip(
                          tokens: tokens,
                          label: '+${project.tags.length - 3}',
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Picks the most informative prose the project has. Order matters: the
  /// long-form brief first, then progressively cheaper fallbacks.
  static String _descriptionFor(ProjectRecord p) {
    for (final candidate in [
      p.solutionDescription,
      p.businessCase,
      p.notes,
      p.milestone,
    ]) {
      final trimmed = candidate.trim();
      if (trimmed.isNotEmpty) return trimmed;
    }
    return '';
  }
}

// ──────────────────────────────────────────────────────────────────────
// States
// ──────────────────────────────────────────────────────────────────────

class IntegrationEmptyWorkspacesCard extends StatelessWidget {
  const IntegrationEmptyWorkspacesCard({
    super.key,
    required this.tokens,
    required this.onCreateProject,
  });

  final IntegrationTokens tokens;
  final VoidCallback onCreateProject;

  @override
  Widget build(BuildContext context) {
    return IntegrationStatePanel(
      tokens: tokens,
      icon: Icons.wb_sunny_rounded,
      title: 'A clean slate — perfect for starting fresh.',
      message: 'No workspaces yet. Create a project and we\'ll walk you '
          'through initiation — no jargon, no setup, just a clear runway '
          'to launch.',
      action: FilledButton.icon(
        onPressed: onCreateProject,
        style: FilledButton.styleFrom(
          backgroundColor: tokens.brand,
          foregroundColor: tokens.onBrand,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        icon: const Icon(Icons.add_rounded, size: 18),
        label: const Text(
          'Create your first project',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}

class IntegrationErrorCard extends StatelessWidget {
  const IntegrationErrorCard({
    super.key,
    required this.tokens,
    required this.message,
    required this.onRetry,
  });

  final IntegrationTokens tokens;
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tokens.bad.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tokens.bad.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, color: tokens.bad, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(fontSize: 12.5, color: tokens.ink),
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

/// Placeholder shown while workspace metrics stream in.
class IntegrationBusyWorkspaceCard extends StatelessWidget {
  const IntegrationBusyWorkspaceCard({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 56),
      child: Center(
        child: SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(strokeWidth: 2.5),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────
// Shared formatting helpers
// ──────────────────────────────────────────────────────────────────────

String _displayName(ProjectRecord p) =>
    p.name.trim().isEmpty ? 'Untitled workspace' : p.name.trim();

/// Derive a lifecycle phase from progress so every card shows something
/// meaningful even when the project never set an explicit phase.
String phaseLabelFor(double progress) {
  if (progress <= 0) return 'Initiation';
  if (progress < 0.25) return 'Planning';
  if (progress < 0.75) return 'Execution';
  return 'Closure';
}

String healthLabel(String status) {
  switch (status) {
    case 'on_track':
      return 'On Track';
    case 'at_risk':
      return 'At Risk';
    case 'off_track':
      return 'Off Track';
    default:
      return 'Unknown';
  }
}

/// Human-friendly relative timestamp ("just now", "4h ago", "12/3/2025").
String relativeTime(DateTime dt) {
  if (dt.millisecondsSinceEpoch == 0) return 'recently';
  final delta = DateTime.now().difference(dt);
  if (delta.isNegative || delta.inMinutes < 1) return 'just now';
  if (delta.inMinutes < 60) return '${delta.inMinutes}m ago';
  if (delta.inHours < 24) return '${delta.inHours}h ago';
  if (delta.inDays < 7) return '${delta.inDays}d ago';
  if (delta.inDays < 365) return '${(delta.inDays / 7).floor()}w ago';
  return '${dt.day}/${dt.month}/${dt.year}';
}