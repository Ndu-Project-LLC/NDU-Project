library;

/// Section Navigator — world-class horizontal tab bar + page-route stepper.
///
/// A premium navigation widget that combines:
///   1. A horizontal tab bar with icon + label per section, active tab
///      highlighted with the gold accent.
///   2. A "Page Route" stepper below the tabs showing numbered dots
///      connected by lines, with the active step highlighted.
///
/// Designed to be reusable across any screen that has multiple sub-sections
/// (WBS, Cost Estimate, Schedule, SSHer, Project Controls, etc.).
///
/// ## Collapsible mode
///
/// Pass `collapsible: true` to render a chevron toggle in the header row.
/// Tapping the header (or the chevron) collapses the tab bar + stepper
/// into zero height, freeing vertical space on the page. When collapsed,
/// a compact active-tab pill is shown in the header so the user always
/// knows which section is selected. `defaultCollapsed` controls the
/// initial state.
///
/// Usage:
/// ```dart
/// SectionNavigator(
///   title: 'WBS Navigation',
///   subtitle: 'Navigate between WBS sections',
///   icon: Icons.account_tree_outlined,
///   tabs: [
///     SectionTab(icon: Icons.folder_open, label: 'Builder'),
///     SectionTab(icon: Icons.auto_awesome, label: 'AI Generator'),
///     SectionTab(icon: Icons.check_circle, label: 'Validator'),
///     SectionTab(icon: Icons.trending_up, label: 'Export & Link'),
///   ],
///   controller: _tabController,
///   onChanged: (index) => setState(() {}),
///   collapsible: true,
///   defaultCollapsed: false,
/// )
/// ```

import 'package:flutter/material.dart';
import 'package:ndu_project/theme.dart';

/// A single tab definition for the [SectionNavigator].
class SectionTab {
  const SectionTab({
    required this.icon,
    required this.label,
    this.badge,
  });

  /// Icon shown in the tab pill.
  final IconData icon;

  /// Text label shown in the tab pill.
  final String label;

  /// Optional badge count (e.g. number of validation issues). When non-null,
  /// a small circular badge is rendered on the right edge of the tab.
  final int? badge;
}

class SectionNavigator extends StatefulWidget {
  const SectionNavigator({
    super.key,
    required this.tabs,
    required this.controller,
    required this.onChanged,
    this.title,
    this.subtitle,
    this.icon,
    this.accentColor,
    this.backgroundColor = const Color(0xFFF9FAFB),
    this.routeLabel = 'Page Route',
    this.collapsible = false,
    this.defaultCollapsed = false,
  });

  /// The ordered list of tabs to render.
  final List<SectionTab> tabs;

  /// The tab controller that drives selection. The navigator calls
  /// [TabController.animateTo] when a tab is tapped and listens to
  /// [TabController.addListener] to update the stepper.
  final TabController controller;

  /// Called whenever the active tab changes. The parent should call
  /// `setState` so this widget rebuilds with the new active index.
  final ValueChanged<int> onChanged;

  /// Optional title shown in the header row (left of the tab bar).
  final String? title;

  /// Optional subtitle shown below the title.
  final String? subtitle;

  /// Optional icon shown in a rounded square to the left of the title.
  final IconData? icon;

  /// Override the accent color (defaults to [LightModeColors.accent] gold).
  final Color? accentColor;

  /// Background used by the navigation surface.
  final Color backgroundColor;

  /// Label for the stepper row (default "Page Route").
  final String routeLabel;

  /// Whether the section can be collapsed via a chevron toggle in the
  /// header. When `true`, tapping the header (or the chevron) collapses
  /// the tab bar and stepper to zero height, freeing vertical space.
  /// When `false` (default) the full layout is always visible.
  final bool collapsible;

  /// Initial collapse state when [collapsible] is `true`. Ignored when
  /// [collapsible] is `false`.
  final bool defaultCollapsed;

  @override
  State<SectionNavigator> createState() => _SectionNavigatorState();
}

class _SectionNavigatorState extends State<SectionNavigator>
    with SingleTickerProviderStateMixin {
  late bool _collapsed;

  @override
  void initState() {
    super.initState();
    _collapsed = widget.collapsible && widget.defaultCollapsed;
  }

  void _toggle() {
    if (!widget.collapsible) return;
    setState(() => _collapsed = !_collapsed);
  }

  void _selectTab(int index) {
    if (index == widget.controller.index) return;
    widget.controller.animateTo(index);
    widget.onChanged(index);
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.accentColor ?? LightModeColors.accent;
    final activeIndex =
        widget.controller.index.clamp(0, widget.tabs.length - 1);
    final activeTab = widget.tabs[activeIndex];
    final hasHeader = widget.title != null || widget.icon != null;
    // When there's no header to attach the chevron to, we cannot offer
    // collapse (there would be no expand affordance once collapsed).
    final canCollapse = widget.collapsible && hasHeader;

    return Container(
      decoration: BoxDecoration(
        color: widget.backgroundColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE4E7EC)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header row (icon + title + subtitle + active-tab + chevron) ──
          if (hasHeader)
            _buildHeader(accent, activeTab),

          // ── Tab bar + Page Route stepper (animated collapse) ─────────
          AnimatedSize(
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeInOutCubic,
            alignment: Alignment.topCenter,
            child: canCollapse && _collapsed
                ? const SizedBox(width: double.infinity, height: 0)
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Tab bar
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final tabCount = widget.tabs.length;
                            final isScrollable =
                                constraints.maxWidth < tabCount * 130;
                            if (isScrollable) {
                              return _buildScrollableTabRow(
                                  constraints, accent, activeIndex);
                            }
                            return _buildFixedTabRow(
                                constraints, accent, activeIndex);
                          },
                        ),
                      ),
                      // Page Route stepper
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                        child: _PageRouteStepper(
                          totalSteps: widget.tabs.length,
                          currentStep: activeIndex,
                          accentColor: accent,
                          label: widget.routeLabel,
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  /// Header row containing the icon + title + subtitle, plus (when
  /// collapsible) the active-tab pill and a chevron toggle. The whole
  /// row is tappable when collapsible.
  Widget _buildHeader(Color accent, SectionTab activeTab) {
    final showActivePill = widget.collapsible && _collapsed;
    final headerPadding = widget.collapsible
        ? const EdgeInsets.fromLTRB(20, 14, 8, 14)
        : const EdgeInsets.fromLTRB(20, 16, 20, 8);

    Widget header = Padding(
      padding: headerPadding,
      child: Row(
        children: [
          if (widget.icon != null) ...[
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [accent, accent.withValues(alpha: 0.7)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Icon(widget.icon, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
          ],
          if (widget.title != null)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.title!,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1A1D1F),
                      fontFamily: appFontFamily,
                    ),
                  ),
                  if (widget.subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      widget.subtitle!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF6B7280),
                        fontFamily: appFontFamily,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          // Compact active-tab indicator — only visible when collapsed
          if (showActivePill) ...[
            _ActiveTabPill(
              icon: activeTab.icon,
              label: activeTab.label,
              badge: activeTab.badge,
              accent: accent,
            ),
            const SizedBox(width: 8),
          ],
          // Chevron toggle — only when collapsible
          if (widget.collapsible)
            _ChevronToggle(
              collapsed: _collapsed,
              accent: accent,
              onTap: _toggle,
            ),
        ],
      ),
    );

    // Make the entire header row tappable to toggle (only when collapsible).
    if (widget.collapsible) {
      header = InkWell(
        onTap: _toggle,
        borderRadius: BorderRadius.circular(16),
        child: header,
      );
    }
    return header;
  }

  /// Fixed (non-scrollable) tab row — each tab takes equal width.
  Widget _buildFixedTabRow(
      BoxConstraints constraints, Color accent, int activeIndex) {
    return Row(
      children: List.generate(widget.tabs.length, (i) {
        final tab = widget.tabs[i];
        final isActive = i == activeIndex;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: i < widget.tabs.length - 1 ? 8 : 0),
            child: _TabPill(
              icon: tab.icon,
              label: tab.label,
              badge: tab.badge,
              isActive: isActive,
              accentColor: accent,
              onTap: () => _selectTab(i),
            ),
          ),
        );
      }),
    );
  }

  /// Scrollable tab row — for narrow screens.
  Widget _buildScrollableTabRow(
      BoxConstraints constraints, Color accent, int activeIndex) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: List.generate(widget.tabs.length, (i) {
          final tab = widget.tabs[i];
          final isActive = i == activeIndex;
          return Padding(
            padding: EdgeInsets.only(right: i < widget.tabs.length - 1 ? 8 : 0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 180),
              child: _TabPill(
                icon: tab.icon,
                label: tab.label,
                badge: tab.badge,
                isActive: isActive,
                accentColor: accent,
                onTap: () => _selectTab(i),
              ),
            ),
          );
        }),
      ),
    );
  }
}

/// Compact active-tab indicator shown in the collapsed header. Lets the
/// user see which section is currently selected without expanding the
/// full tab bar.
class _ActiveTabPill extends StatelessWidget {
  const _ActiveTabPill({
    required this.icon,
    required this.label,
    required this.accent,
    this.badge,
  });

  final IconData icon;
  final String label;
  final Color accent;
  final int? badge;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: accent.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: accent),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: accent,
              fontFamily: appFontFamily,
            ),
          ),
          if (badge != null && badge! > 0) ...[
            const SizedBox(width: 6),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                badge! > 99 ? '99+' : '$badge',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: accent,
                  fontFamily: appFontFamily,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Chevron toggle button rendered at the right edge of the header when
/// `collapsible: true`. Tapping it (or the header) toggles collapse.
class _ChevronToggle extends StatelessWidget {
  const _ChevronToggle({
    required this.collapsed,
    required this.accent,
    required this.onTap,
  });

  final bool collapsed;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: collapsed
                ? Colors.white
                : accent.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: collapsed
                  ? const Color(0xFFE4E7EC)
                  : accent.withValues(alpha: 0.25),
            ),
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: Icon(
              collapsed
                  ? Icons.keyboard_arrow_down_rounded
                  : Icons.keyboard_arrow_up_rounded,
              key: ValueKey(collapsed),
              size: 20,
              color: collapsed ? const Color(0xFF6B7280) : accent,
            ),
          ),
        ),
      ),
    );
  }
}

/// A single tab pill — icon + label, with active/inactive states.
class _TabPill extends StatelessWidget {
  const _TabPill({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.accentColor,
    required this.onTap,
    this.badge,
  });

  final IconData icon;
  final String label;
  final bool isActive;
  final Color accentColor;
  final VoidCallback onTap;
  final int? badge;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: isActive ? accentColor : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isActive ? accentColor : const Color(0xFFE4E7EC),
              width: 1,
            ),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: accentColor.withValues(alpha: 0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: isActive ? Colors.white : const Color(0xFF6B7280),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
                    color: isActive ? Colors.white : const Color(0xFF1A1D1F),
                    fontFamily: appFontFamily,
                    height: 1.25,
                  ),
                  maxLines: 2,
                  softWrap: true,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.visible,
                ),
              ),
              if (badge != null && badge! > 0) ...[
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isActive
                        ? Colors.white.withValues(alpha: 0.25)
                        : accentColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    badge! > 99 ? '99+' : '$badge',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: isActive ? Colors.white : accentColor,
                      fontFamily: appFontFamily,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Page Route stepper — numbered dots connected by lines.
class _PageRouteStepper extends StatelessWidget {
  const _PageRouteStepper({
    required this.totalSteps,
    required this.currentStep,
    required this.accentColor,
    required this.label,
  });

  final int totalSteps;
  final int currentStep;
  final Color accentColor;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Color(0xFF9CA3AF),
            letterSpacing: 0.5,
            fontFamily: appFontFamily,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: List.generate(totalSteps, (i) {
            final isActive = i == currentStep;
            final isCompleted = i < currentStep;
            return Expanded(
              child: Row(
                children: [
                  // Dot
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isActive
                          ? accentColor
                          : isCompleted
                              ? accentColor.withValues(alpha: 0.15)
                              : const Color(0xFFF3F4F6),
                      border: Border.all(
                        color: isActive
                            ? accentColor
                            : isCompleted
                                ? accentColor.withValues(alpha: 0.3)
                                : const Color(0xFFE4E7EC),
                        width: isActive ? 2 : 1,
                      ),
                      boxShadow: isActive
                          ? [
                              BoxShadow(
                                color: accentColor.withValues(alpha: 0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : null,
                    ),
                    child: Center(
                      child: isCompleted
                          ? Icon(
                              Icons.check_rounded,
                              size: 14,
                              color: accentColor,
                            )
                          : Text(
                              '${i + 1}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: isActive
                                    ? Colors.white
                                    : const Color(0xFF9CA3AF),
                                fontFamily: appFontFamily,
                              ),
                            ),
                    ),
                  ),
                  // Connector line (except after the last dot)
                  if (i < totalSteps - 1)
                    Expanded(
                      child: Container(
                        height: 2,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(1),
                          color: i < currentStep
                              ? accentColor.withValues(alpha: 0.4)
                              : const Color(0xFFE4E7EC),
                        ),
                      ),
                    ),
                ],
              ),
            );
          }),
        ),
      ],
    );
  }
}
