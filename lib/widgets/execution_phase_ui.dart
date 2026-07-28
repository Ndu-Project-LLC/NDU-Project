import 'package:flutter/material.dart';
import 'package:ndu_project/widgets/responsive.dart';

enum ExecutionActionTone {
  primary,
  secondary,
  ai,
  destructive,
}

class ExecutionActionItem {
  const ExecutionActionItem({
    required this.label,
    required this.icon,
    this.onPressed,
    this.tone = ExecutionActionTone.secondary,
    this.isLoading = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final ExecutionActionTone tone;
  final bool isLoading;
}

class ExecutionActionBar extends StatelessWidget {
  const ExecutionActionBar({
    super.key,
    required this.actions,
    this.compact = false,
  });

  final List<ExecutionActionItem> actions;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (actions.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: actions.map((action) => _buildAction(context, action)).toList(),
    );
  }

  Widget _buildAction(BuildContext context, ExecutionActionItem action) {
    final bool disabled = action.onPressed == null || action.isLoading;
    final Color aiColor = const Color(0xFF5B5BD6);

    switch (action.tone) {
      case ExecutionActionTone.primary:
        return FilledButton.icon(
          onPressed: disabled ? null : action.onPressed,
          icon: action.isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Icon(action.icon, size: compact ? 16 : 18),
          label: Text(action.label),
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF0F172A),
            foregroundColor: Colors.white,
            disabledBackgroundColor: const Color(0xFFE2E8F0),
            disabledForegroundColor: const Color(0xFF94A3B8),
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 14 : 16,
              vertical: compact ? 11 : 12,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            textStyle: TextStyle(
              fontSize: compact ? 12 : 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        );
      case ExecutionActionTone.ai:
        return OutlinedButton.icon(
          onPressed: disabled ? null : action.onPressed,
          icon: action.isLoading
              ? SizedBox(
                  width: compact ? 16 : 18,
                  height: compact ? 16 : 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: aiColor,
                  ),
                )
              : Icon(action.icon, size: compact ? 16 : 18, color: aiColor),
          label: Text(action.label),
          style: OutlinedButton.styleFrom(
            foregroundColor: aiColor,
            side: BorderSide(color: aiColor.withOpacity(0.28)),
            backgroundColor: const Color(0xFFF8F7FF),
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 14 : 16,
              vertical: compact ? 11 : 12,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            textStyle: TextStyle(
              fontSize: compact ? 12 : 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        );
      case ExecutionActionTone.destructive:
        return OutlinedButton.icon(
          onPressed: disabled ? null : action.onPressed,
          icon: Icon(action.icon, size: compact ? 16 : 18),
          label: Text(action.label),
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFFB91C1C),
            side: const BorderSide(color: Color(0xFFFECACA)),
            backgroundColor: const Color(0xFFFEF2F2),
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 14 : 16,
              vertical: compact ? 11 : 12,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            textStyle: TextStyle(
              fontSize: compact ? 12 : 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        );
      case ExecutionActionTone.secondary:
        return OutlinedButton.icon(
          onPressed: disabled ? null : action.onPressed,
          icon: Icon(action.icon, size: compact ? 16 : 18),
          label: Text(action.label),
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF475569),
            side: const BorderSide(color: Color(0xFFE2E8F0)),
            backgroundColor: Colors.white,
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 14 : 16,
              vertical: compact ? 11 : 12,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            textStyle: TextStyle(
              fontSize: compact ? 12 : 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        );
    }
  }
}

class ExecutionPageHeader extends StatelessWidget {
  const ExecutionPageHeader({
    super.key,
    required this.badge,
    required this.title,
    required this.description,
    this.trailing,
    this.metadata = const <Widget>[],
  });

  final String badge;
  final String title;
  final String description;
  final Widget? trailing;
  final List<Widget> metadata;

  @override
  Widget build(BuildContext context) {
    final bool isMobile = AppBreakpoints.isMobile(context);

    return Container(
      padding: EdgeInsets.all(isMobile ? 20 : 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 22,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF3C7),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              badge.toUpperCase(),
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: Color(0xFF92400E),
                letterSpacing: 0.4,
              ),
            ),
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final bool stack = trailing != null && constraints.maxWidth < 900;
              if (stack) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _HeaderCopy(title: title, description: description),
                    const SizedBox(height: 16),
                    trailing!,
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _HeaderCopy(title: title, description: description),
                  ),
                  if (trailing != null) ...[
                    const SizedBox(width: 16),
                    Flexible(child: trailing!),
                  ],
                ],
              );
            },
          ),
          if (metadata.isNotEmpty) ...[
            const SizedBox(height: 18),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: metadata,
            ),
          ],
        ],
      ),
    );
  }
}

class _HeaderCopy extends StatelessWidget {
  const _HeaderCopy({
    required this.title,
    required this.description,
  });

  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF111827),
                height: 1.08,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          description,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF4B5563),
                height: 1.5,
              ),
        ),
      ],
    );
  }
}

class ExecutionMetricData {
  const ExecutionMetricData({
    required this.label,
    required this.value,
    required this.icon,
    this.helper,
    this.emphasisColor = const Color(0xFF2563EB),
  });

  final String label;
  final String value;
  final IconData icon;
  final String? helper;
  final Color emphasisColor;
}

class ExecutionMetricsGrid extends StatelessWidget {
  const ExecutionMetricsGrid({
    super.key,
    required this.metrics,
    this.minTileWidth = 160,
  });

  final List<ExecutionMetricData> metrics;
  final double minTileWidth;

  @override
  Widget build(BuildContext context) {
    if (metrics.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final double width = constraints.maxWidth;
        final int count = metrics.length;
        final double spacing = 12;

        // Wide screens: single row with equal-width Expanded cards
        if (width >= 900) {
          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: metrics
                  .map((metric) => Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(
                            left: metrics.indexOf(metric) == 0 ? 0 : spacing / 2,
                            right: metrics.indexOf(metric) == metrics.length - 1
                                ? 0
                                : spacing / 2,
                          ),
                          child: ExecutionMetricCard(metric: metric),
                        ),
                      ))
                  .toList(),
            ),
          );
        }

        // Medium / narrow: use Wrap with uniform widths + IntrinsicHeight per row
        int columns;
        if (width >= 600) {
          columns = (count / 2).ceil().clamp(1, 4);
        } else if (width >= 400) {
          columns = 2;
        } else {
          columns = 1;
        }
        final double tileWidth =
            (width - (spacing * (columns - 1))) / columns;

        // Build rows of cards so IntrinsicHeight can equalise each row
        final List<Widget> rows = [];
        for (int i = 0; i < count; i += columns) {
          final rowMetrics = metrics.sublist(
            i,
            (i + columns).clamp(0, count),
          );
          rows.add(
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: rowMetrics
                    .map((metric) => SizedBox(
                          width: tileWidth.clamp(minTileWidth, width)
                              .toDouble(),
                          child: Padding(
                            padding: EdgeInsets.only(
                              left: rowMetrics.indexOf(metric) == 0
                                  ? 0
                                  : spacing / 2,
                              right: rowMetrics.indexOf(metric) ==
                                      rowMetrics.length - 1
                                  ? 0
                                  : spacing / 2,
                            ),
                            child: ExecutionMetricCard(metric: metric),
                          ),
                        ))
                    .toList(),
              ),
            ),
          );
          if (i + columns < count) {
            rows.add(SizedBox(height: spacing));
          }
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: rows,
        );
      },
    );
  }
}

class ExecutionMetricCard extends StatelessWidget {
  const ExecutionMetricCard({
    super.key,
    required this.metric,
  });

  final ExecutionMetricData metric;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            metric.label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Color(0xFF64748B),
              letterSpacing: 0.2,
            ),
            softWrap: true,
            maxLines: 2,
            overflow: TextOverflow.visible,
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: metric.emphasisColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(metric.icon, size: 20, color: metric.emphasisColor),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      metric.value,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF111827),
                        height: 1.0,
                      ),
                    ),
                    // Always reserve space for helper line so cards are same height
                    if (metric.helper != null &&
                        metric.helper!.trim().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          metric.helper!,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF6B7280),
                            height: 1.3,
                          ),
                          softWrap: true,
                          maxLines: 3,
                          overflow: TextOverflow.visible,
                        ),
                      )
                    else
                      const SizedBox(height: 16),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class ExecutionPanelShell extends StatefulWidget {
  const ExecutionPanelShell({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.trailing,
    this.padding,
    this.collapsible = false,
    this.initiallyExpanded = true,
    this.headerIcon,
    this.headerIconColor,
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final Widget? trailing;
  final EdgeInsetsGeometry? padding;
  final bool collapsible;
  final bool initiallyExpanded;
  final IconData? headerIcon;
  final Color? headerIconColor;

  @override
  State<ExecutionPanelShell> createState() => _ExecutionPanelShellState();
}

class _ExecutionPanelShellState extends State<ExecutionPanelShell>
    with SingleTickerProviderStateMixin {
  late bool _isExpanded;
  late AnimationController _controller;
  late Animation<double> _chevronRotation;
  late Animation<double> _bodyOpacity;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.initiallyExpanded;
    _controller = AnimationController(
      duration: const Duration(milliseconds: 280),
      vsync: this,
    );
    _chevronRotation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    _bodyOpacity = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    if (_isExpanded) {
      _controller.value = 1.0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: widget.padding ?? const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: _isExpanded
              ? const Color(0xFFE5E7EB)
              : const Color(0xFFF3F4F6),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 18,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header row (always visible) ──
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.collapsible ? _toggle : null,
            child: _buildHeaderRow(),
          ),
          // ── Collapsible body ──
          if (_isExpanded) ...[
            const SizedBox(height: 18),
            FadeTransition(
              opacity: _bodyOpacity,
              child: widget.child,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHeaderRow() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool stack =
            widget.trailing != null && constraints.maxWidth < 820;

        final Widget titleBlock = Row(
          children: [
            if (widget.headerIcon != null) ...[
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: (widget.headerIconColor ?? const Color(0xFF6366F1))
                      .withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  widget.headerIcon,
                  size: 18,
                  color:
                      widget.headerIconColor ?? const Color(0xFF6366F1),
                ),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          widget.title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF111827),
                          ),
                        ),
                      ),
                      if (widget.collapsible) ...[
                        const SizedBox(width: 8),
                        _buildChevron(),
                      ],
                    ],
                  ),
                  if (widget.subtitle != null &&
                      widget.subtitle!.trim().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        widget.subtitle!,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF6B7280),
                          height: 1.45,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        );

        if (stack) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              titleBlock,
              if (widget.trailing != null) ...[
                const SizedBox(height: 16),
                widget.trailing!,
              ],
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: titleBlock),
            if (widget.trailing != null) ...[
              const SizedBox(width: 12),
              widget.trailing!,
            ],
          ],
        );
      },
    );
  }

  Widget _buildChevron() {
    return AnimatedBuilder(
      animation: _chevronRotation,
      builder: (context, child) {
        return Transform.rotate(
          angle: _chevronRotation.value * 3.14159265, // 0 → π
          child: child,
        );
      },
      child: Icon(
        Icons.expand_more_rounded,
        size: 20,
        color: _isExpanded
            ? const Color(0xFF6366F1)
            : const Color(0xFF9CA3AF),
      ),
    );
  }
}

class ExecutionEmptyState extends StatelessWidget {
  const ExecutionEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    this.actions = const <Widget>[],
  });

  final IconData icon;
  final String title;
  final String description;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 28),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Icon(icon, size: 26, color: const Color(0xFF64748B)),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Color(0xFF64748B),
              height: 1.5,
            ),
          ),
          if (actions.isNotEmpty) ...[
            const SizedBox(height: 18),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              children: actions,
            ),
          ],
        ],
      ),
    );
  }
}

class ExecutionStatusBadge extends StatelessWidget {
  const ExecutionStatusBadge({
    super.key,
    required this.label,
  });

  final String label;

  @override
  Widget build(BuildContext context) {
    final _StatusPalette palette = _StatusPalette.resolve(label);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: palette.background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: palette.border),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: palette.foreground,
        ),
      ),
    );
  }
}

class _StatusPalette {
  const _StatusPalette(this.background, this.border, this.foreground);

  final Color background;
  final Color border;
  final Color foreground;

  static _StatusPalette resolve(String value) {
    final String normalized = value.trim().toLowerCase();
    if (normalized.isEmpty) {
      return const _StatusPalette(
        Color(0xFFF8FAFC),
        Color(0xFFE2E8F0),
        Color(0xFF64748B),
      );
    }

    if (normalized.contains('complete') ||
        normalized.contains('approved') ||
        normalized.contains('ready') ||
        normalized.contains('active') ||
        normalized.contains('verified')) {
      return const _StatusPalette(
        Color(0xFFECFDF5),
        Color(0xFFA7F3D0),
        Color(0xFF047857),
      );
    }

    if (normalized.contains('risk') ||
        normalized.contains('block') ||
        normalized.contains('overdue') ||
        normalized.contains('expired') ||
        normalized.contains('critical')) {
      return const _StatusPalette(
        Color(0xFFFEF2F2),
        Color(0xFFFECACA),
        Color(0xFFB91C1C),
      );
    }

    if (normalized.contains('draft') ||
        normalized.contains('planned') ||
        normalized.contains('pending') ||
        normalized.contains('review') ||
        normalized.contains('open')) {
      return const _StatusPalette(
        Color(0xFFFFFBEB),
        Color(0xFFFDE68A),
        Color(0xFFB45309),
      );
    }

    if (normalized.contains('progress') ||
        normalized.contains('scheduled') ||
        normalized.contains('aligned')) {
      return const _StatusPalette(
        Color(0xFFEFF6FF),
        Color(0xFFBFDBFE),
        Color(0xFF1D4ED8),
      );
    }

    return const _StatusPalette(
      Color(0xFFF5F3FF),
      Color(0xFFDDD6FE),
      Color(0xFF6D28D9),
    );
  }
}

Future<T?> showExecutionEditorSheet<T>({
  required BuildContext context,
  required String title,
  required Widget child,
  required List<Widget> actions,
  String? subtitle,
  IconData icon = Icons.edit_outlined,
}) {
  final bool isMobile = AppBreakpoints.isMobile(context);
  final Widget surface = _ExecutionEditorSurface(
    title: title,
    subtitle: subtitle,
    icon: icon,
    actions: actions,
    isMobile: isMobile,
    child: child,
  );

  if (isMobile) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return FractionallySizedBox(
          heightFactor: 0.96,
          child: surface,
        );
      },
    );
  }

  return showDialog<T>(
    context: context,
    barrierDismissible: false,
    builder: (_) {
      return Dialog(
        insetPadding: const EdgeInsets.all(24),
        backgroundColor: Colors.transparent,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: 720,
            maxHeight: 860,
          ),
          child: surface,
        ),
      );
    },
  );
}

class _ExecutionEditorSurface extends StatelessWidget {
  const _ExecutionEditorSurface({
    required this.title,
    required this.child,
    required this.actions,
    required this.icon,
    required this.isMobile,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final List<Widget> actions;
  final IconData icon;
  final bool isMobile;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(isMobile ? 28 : 24),
        bottom: Radius.circular(isMobile ? 0 : 24),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                22,
                isMobile ? 18 : 22,
                22,
                18,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(icon, size: 20, color: const Color(0xFF334155)),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF111827),
                          ),
                        ),
                        if (subtitle != null && subtitle!.trim().isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              subtitle!,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF6B7280),
                                height: 1.45,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                    style: IconButton.styleFrom(
                      foregroundColor: const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, thickness: 1, color: Color(0xFFE5E7EB)),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(22),
                child: child,
              ),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(22, 16, 22, 22),
              decoration: const BoxDecoration(
                color: Color(0xFFFAFBFC),
                border: Border(
                  top: BorderSide(color: Color(0xFFE5E7EB)),
                ),
              ),
              child: Wrap(
                alignment: WrapAlignment.end,
                spacing: 10,
                runSpacing: 10,
                children: actions,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
