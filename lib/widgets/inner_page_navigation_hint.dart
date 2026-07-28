import 'package:flutter/material.dart';
import 'package:ndu_project/services/hint_service.dart';

/// Represents a single navigable section within a page.
class InnerPageSection {
  const InnerPageSection({
    required this.id,
    required this.label,
    this.icon,
    this.status = InnerPageSectionStatus.available,
    this.description,
    this.stepNumber,
  });

  final String id;
  final String label;
  final IconData? icon;
  final InnerPageSectionStatus status;
  final String? description;
  final int? stepNumber;

  InnerPageSection copyWith({
    String? id,
    String? label,
    IconData? icon,
    InnerPageSectionStatus? status,
    String? description,
    int? stepNumber,
  }) {
    return InnerPageSection(
      id: id ?? this.id,
      label: label ?? this.label,
      icon: icon ?? this.icon,
      status: status ?? this.status,
      description: description ?? this.description,
      stepNumber: stepNumber ?? this.stepNumber,
    );
  }
}

/// Status of a navigable section within a page.
enum InnerPageSectionStatus {
  /// The section is available for the user to navigate to.
  available,

  /// The section is the currently active/visible section.
  current,

  /// The section has been completed by the user.
  completed,

  /// The section is locked and requires prior sections to be completed.
  locked,

  /// The section has been marked as not applicable.
  notApplicable,
}

/// A world-class inline navigation hint card that shows users the structure
/// of a multi-section page and lets them jump between sections.
///
/// Features:
///   - Shows total sections, completed count, and current position
///   - Visual progress bar across all sections
///   - Each section shows status badge, label, and optional description
///   - Click/tap on any available section to navigate
///   - Dismissible with "Don't show again" per-page persistence
///   - Animated entrance and subtle visual polish
class InnerPageNavigationHint extends StatefulWidget {
  const InnerPageNavigationHint({
    super.key,
    required this.pageId,
    required this.pageTitle,
    required this.sections,
    required this.onSectionTap,
    this.description,
    this.accentColor = const Color(0xFF005BB3),
    this.currentSectionId,
    this.compact = false,
  });

  /// Unique identifier for this page (used for "don't show again" persistence).
  final String pageId;

  /// The title of the page (displayed in the hint header).
  final String pageTitle;

  /// The list of navigable sections on this page.
  final List<InnerPageSection> sections;

  /// Callback when a section is tapped.
  final ValueChanged<String> onSectionTap;

  /// Optional short description shown below the title.
  final String? description;

  /// Brand accent color for the progress bar and badges.
  final Color accentColor;

  /// The ID of the currently active section (will be highlighted).
  final String? currentSectionId;

  /// If true, renders a compact single-line version.
  final bool compact;

  @override
  State<InnerPageNavigationHint> createState() =>
      _InnerPageNavigationHintState();
}

class _InnerPageNavigationHintState extends State<InnerPageNavigationHint>
    with SingleTickerProviderStateMixin {
  bool _dismissed = false;
  bool _isExpanded = true;
  late final AnimationController _animController;
  late final Animation<double> _fadeAnim;

  static const String _dismissPrefix = 'inner_nav_hint_dismissed_';

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    );
    _animController.forward();
    _loadDismissState();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _loadDismissState() async {
    final dismissed = await HintService.isPageDismissed('${_dismissPrefix}${widget.pageId}');
    if (mounted && dismissed) {
      setState(() => _dismissed = true);
    }
  }

  Future<void> _dismissPermanently() async {
    await HintService.markPageDismissed('${_dismissPrefix}${widget.pageId}');
    if (mounted) {
      await _animController.reverse();
      setState(() => _dismissed = true);
    }
  }

  void _dismissForSession() {
    _animController.reverse().then((_) {
      if (mounted) setState(() => _dismissed = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_dismissed) return const SizedBox.shrink();

    final completedCount =
        widget.sections.where((s) => s.status == InnerPageSectionStatus.completed).length;
    final totalSections = widget.sections.length;
    final progress = totalSections > 0 ? completedCount / totalSections : 0.0;
    final currentIndex = widget.currentSectionId != null
        ? widget.sections.indexWhere((s) => s.id == widget.currentSectionId)
        : -1;

    return FadeTransition(
      opacity: _fadeAnim,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: widget.accentColor.withOpacity(0.18),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: widget.accentColor.withOpacity(0.07),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Header ──
            _buildHeader(completedCount, totalSections, progress),

            // ── Expandable section list ──
            if (_isExpanded) ...[
              Container(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                child: _buildSectionList(currentIndex),
              ),
              // ── Footer ──
              _buildFooter(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(int completedCount, int totalSections, double progress) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 10, 12),
      decoration: BoxDecoration(
        color: widget.accentColor.withOpacity(0.04),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Navigation icon
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: widget.accentColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.map_outlined,
                  size: 18,
                  color: widget.accentColor,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${widget.pageTitle} Navigation',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF111827),
                      ),
                    ),
                    if (widget.description != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        widget.description!,
                        style: TextStyle(
                          fontSize: 11,
                          color: const Color(0xFF6B7280),
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              // Expand/collapse button
              IconButton(
                icon: Icon(
                  _isExpanded ? Icons.expand_less : Icons.expand_more,
                  size: 20,
                  color: const Color(0xFF6B7280),
                ),
                onPressed: () => setState(() => _isExpanded = !_isExpanded),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                splashRadius: 16,
              ),
              // Close button
              IconButton(
                icon: const Icon(Icons.close, size: 16, color: Color(0xFF9CA3AF)),
                onPressed: _dismissForSession,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                splashRadius: 14,
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Progress bar
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: SizedBox(
                    height: 6,
                    child: Stack(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFE5E7EB),
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        FractionallySizedBox(
                          widthFactor: progress.clamp(0.0, 1.0),
                          child: Container(
                            decoration: BoxDecoration(
                              color: progress >= 1.0
                                  ? const Color(0xFF16A34A)
                                  : widget.accentColor,
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '$completedCount/$totalSections complete',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: progress >= 1.0
                      ? const Color(0xFF16A34A)
                      : const Color(0xFF6B7280),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionList(int currentIndex) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 6),
        // Section hint text
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text(
            'Navigate between sections of this page:',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF6B7280),
            ),
          ),
        ),
        // Section items in a wrap layout
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: widget.sections.map((section) {
            final isCurrent = section.id == widget.currentSectionId;
            return _SectionChip(
              section: section,
              accentColor: widget.accentColor,
              isCurrent: isCurrent,
              onTap: section.status == InnerPageSectionStatus.locked
                  ? null
                  : () => widget.onSectionTap(section.id),
            );
          }).toList(),
        ),
        // Step-by-step mini map (horizontal)
        const SizedBox(height: 12),
        _buildMiniMap(currentIndex),
      ],
    );
  }

  Widget _buildMiniMap(int currentIndex) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.route_outlined, size: 14, color: const Color(0xFF6B7280)),
              const SizedBox(width: 6),
              Text(
                'Page Route',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF6B7280),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: List.generate(widget.sections.length, (i) {
                final section = widget.sections[i];
                final isCurrent = section.id == widget.currentSectionId;
                final isLast = i == widget.sections.length - 1;
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTap: section.status == InnerPageSectionStatus.locked
                          ? null
                          : () => widget.onSectionTap(section.id),
                      child: Tooltip(
                        message: section.label,
                        waitDuration: const Duration(milliseconds: 300),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: isCurrent ? 28 : 22,
                          height: isCurrent ? 28 : 22,
                          decoration: BoxDecoration(
                            color: _miniMapColor(section, isCurrent),
                            shape: BoxShape.circle,
                            border: isCurrent
                                ? Border.all(
                                    color: widget.accentColor, width: 2.5)
                                : null,
                            boxShadow: isCurrent
                                ? [
                                    BoxShadow(
                                      color:
                                          widget.accentColor.withOpacity(0.3),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Center(
                            child: _miniMapIcon(section, isCurrent),
                          ),
                        ),
                      ),
                    ),
                    if (!isLast) ...[
                      Container(
                        width: 16,
                        height: 2,
                        color: _miniMapLineColor(i),
                      ),
                    ],
                  ],
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Color _miniMapColor(InnerPageSection section, bool isCurrent) {
    if (isCurrent) return Colors.white;
    switch (section.status) {
      case InnerPageSectionStatus.completed:
        return const Color(0xFF16A34A);
      case InnerPageSectionStatus.notApplicable:
        return const Color(0xFF9CA3AF);
      case InnerPageSectionStatus.locked:
        return const Color(0xFFE5E7EB);
      case InnerPageSectionStatus.available:
        return widget.accentColor.withOpacity(0.15);
      case InnerPageSectionStatus.current:
        return Colors.white;
    }
  }

  Widget? _miniMapIcon(InnerPageSection section, bool isCurrent) {
    if (isCurrent) {
      return Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          color: widget.accentColor,
          shape: BoxShape.circle,
        ),
      );
    }
    switch (section.status) {
      case InnerPageSectionStatus.completed:
        return const Icon(Icons.check, size: 12, color: Colors.white);
      case InnerPageSectionStatus.notApplicable:
        return const Icon(Icons.remove, size: 10, color: Colors.white);
      case InnerPageSectionStatus.locked:
        return const Icon(Icons.lock_outline, size: 10, color: Color(0xFF9CA3AF));
      case InnerPageSectionStatus.available:
        return Text(
          '${section.stepNumber ?? ''}',
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w800,
            color: widget.accentColor,
          ),
        );
      case InnerPageSectionStatus.current:
        return Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: widget.accentColor,
            shape: BoxShape.circle,
          ),
        );
    }
  }

  Color _miniMapLineColor(int upToIndex) {
    final section = widget.sections[upToIndex];
    if (section.status == InnerPageSectionStatus.completed ||
        section.status == InnerPageSectionStatus.notApplicable) {
      return const Color(0xFF16A34A);
    }
    return const Color(0xFFD1D5DB);
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFFF1F5F9))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton.icon(
            onPressed: _dismissPermanently,
            icon: const Icon(Icons.visibility_off_outlined, size: 14),
            label: const Text(
              "Don't show on this page",
              style: TextStyle(fontSize: 11),
            ),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF9CA3AF),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ],
      ),
    );
  }
}

/// A single section chip in the navigation hint.
class _SectionChip extends StatelessWidget {
  const _SectionChip({
    required this.section,
    required this.accentColor,
    required this.isCurrent,
    required this.onTap,
  });

  final InnerPageSection section;
  final Color accentColor;
  final bool isCurrent;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isLocked = section.status == InnerPageSectionStatus.locked;
    final isCompleted = section.status == InnerPageSectionStatus.completed;
    final isNA = section.status == InnerPageSectionStatus.notApplicable;

    Color bgColor;
    Color borderColor;
    Color textColor;
    IconData? trailingIcon;

    if (isCurrent) {
      bgColor = accentColor.withOpacity(0.1);
      borderColor = accentColor.withOpacity(0.4);
      textColor = accentColor;
      trailingIcon = Icons.radio_button_checked;
    } else if (isCompleted) {
      bgColor = const Color(0xFFF0FDF4);
      borderColor = const Color(0xFF86EFAC);
      textColor = const Color(0xFF16A34A);
      trailingIcon = Icons.check_circle_outline;
    } else if (isNA) {
      bgColor = const Color(0xFFF9FAFB);
      borderColor = const Color(0xFFE5E7EB);
      textColor = const Color(0xFF9CA3AF);
      trailingIcon = Icons.remove_circle_outline;
    } else if (isLocked) {
      bgColor = const Color(0xFFF9FAFB);
      borderColor = const Color(0xFFE5E7EB);
      textColor = const Color(0xFF9CA3AF);
      trailingIcon = Icons.lock_outline;
    } else {
      bgColor = const Color(0xFFF8FAFC);
      borderColor = const Color(0xFFE5E7EB);
      textColor = const Color(0xFF374151);
      trailingIcon = null;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: borderColor, width: isCurrent ? 1.5 : 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (section.stepNumber != null) ...[
                Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: textColor.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '${section.stepNumber}',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: textColor,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 5),
              ],
              if (section.icon != null) ...[
                Icon(section.icon, size: 13, color: textColor),
                const SizedBox(width: 4),
              ],
              Text(
                section.label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isCurrent ? FontWeight.w800 : FontWeight.w600,
                  color: textColor,
                ),
              ),
              if (trailingIcon != null) ...[
                const SizedBox(width: 4),
                Icon(trailingIcon, size: 13, color: textColor),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
