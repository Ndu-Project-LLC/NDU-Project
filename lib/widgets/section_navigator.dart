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
    this.enabled = true,
  });

  /// Icon shown in the tab pill.
  final IconData icon;

  /// Text label shown in the tab pill.
  final String label;

  /// Optional badge count (e.g. number of validation issues). When non-null,
  /// a small circular badge is rendered on the right edge of the tab.
  final int? badge;

  /// Whether this tab is interactive. When disabled, the pill is greyed out
  /// and tapping does nothing.
  final bool enabled;
}

class SectionNavigator extends StatelessWidget {
  const SectionNavigator({
    super.key,
    required this.tabs,
    required this.controller,
    required this.onChanged,
    this.title,
    this.subtitle,
    this.icon,
    this.accentColor,
    this.routeLabel = 'Page Route',
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

  /// Label for the stepper row (default "Page Route").
  final String routeLabel;

  @override
  Widget build(BuildContext context) {
    final accent = accentColor ?? LightModeColors.accent;
    final activeIndex = controller.index.clamp(0, tabs.length - 1);

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
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
          // ── Header row (icon + title + subtitle) ─────────────────────
          if (title != null || icon != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: [
                  if (icon != null) ...[
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
                      child: Icon(icon, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 12),
                  ],
                  if (title != null)
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title!,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1A1D1F),
                              fontFamily: appFontFamily,
                            ),
                          ),
                          if (subtitle != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              subtitle!,
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
                ],
              ),
            ),

          // ── Tab bar ──────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: LayoutBuilder(
              builder: (context, constraints) {
                // Determine if tabs should wrap or fit in a single row
                final tabCount = tabs.length;
                final isScrollable = constraints.maxWidth < tabCount * 130;

                if (isScrollable) {
                  return _buildScrollableTabRow(accent, activeIndex);
                }
                return _buildFixedTabRow(constraints, accent, activeIndex);
              },
            ),
          ),

          // ── Page Route stepper ───────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: _PageRouteStepper(
              totalSteps: tabs.length,
              currentStep: activeIndex,
              accentColor: accent,
              label: routeLabel,
            ),
          ),
        ],
      ),
    );
  }

  /// Fixed (non-scrollable) tab row — each tab takes equal width.
  Widget _buildFixedTabRow(
      BoxConstraints constraints, Color accent, int activeIndex) {
    return Row(
      children: List.generate(tabs.length, (i) {
        final tab = tabs[i];
        final isActive = i == activeIndex;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: i < tabs.length - 1 ? 8 : 0),
            child: _TabPill(
              icon: tab.icon,
              label: tab.label,
              badge: tab.badge,
              isActive: isActive,
              enabled: tab.enabled,
              accentColor: accent,
              onTap: tab.enabled ? () => _selectTab(i) : () {},
            ),
          ),
        );
      }),
    );
  }

  /// Scrollable tab row — for narrow screens.
  Widget _buildScrollableTabRow(Color accent, int activeIndex) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: List.generate(tabs.length, (i) {
          final tab = tabs[i];
          final isActive = i == activeIndex;
          return Padding(
            padding: EdgeInsets.only(right: i < tabs.length - 1 ? 8 : 0),
            child: _TabPill(
              icon: tab.icon,
              label: tab.label,
              badge: tab.badge,
              isActive: isActive,
              enabled: tab.enabled,
              accentColor: accent,
              onTap: tab.enabled ? () => _selectTab(i) : () {},
            ),
          );
        }),
      ),
    );
  }

  void _selectTab(int index) {
    if (index == controller.index) return;
    controller.animateTo(index);
    onChanged(index);
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
    this.enabled = true,
  });

  final IconData icon;
  final String label;
  final bool isActive;
  final Color accentColor;
  final VoidCallback onTap;
  final int? badge;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1.0 : 0.4,
      child: AbsorbPointer(
        absorbing: !enabled,
        child: Material(
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
                        fontWeight:
                            isActive ? FontWeight.w700 : FontWeight.w600,
                        color:
                            isActive ? Colors.white : const Color(0xFF1A1D1F),
                        fontFamily: appFontFamily,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (badge != null && badge! > 0) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
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
