/// Unfinished Work Dialog — a beautifully designed pop-up that notifies the
/// user of pending work items before they navigate away from the current
/// page (Task 20).
///
/// Pages register their "unfinished items" via [UnfinishedWorkRegistry.of]
/// and call [showUnfinishedWorkDialogIfAny] before performing navigation.
/// If there are no unfinished items, the navigation proceeds silently.
///
/// Visual design:
/// - Soft warm gradient header with a brain/alert icon
/// - Bold headline: 'You have unfinished work'
/// - Subtitle: 'X items on this page need your attention before you leave.'
/// - Bulleted list of unfinished item titles (max 5 shown; rest collapsed)
/// - Two CTAs: 'Stay on this page' (default) and 'Leave anyway'
///
/// The dialog is dismissible (Escape / barrier tap = Stay).

library;

import 'package:flutter/material.dart';

/// Represents a single unfinished work item on the current page.
class UnfinishedItem {
  const UnfinishedItem({
    required this.title,
    this.detail,
    this.severity = UnfinishedSeverity.warning,
  });

  /// Short title (e.g., 'Project Sponsor not assigned').
  final String title;

  /// Optional longer explanation.
  final String? detail;

  /// How urgent this item is.
  final UnfinishedSeverity severity;
}

enum UnfinishedSeverity { info, warning, blocking }

/// Inherited widget that exposes the list of unfinished items for the
/// current page. Pages wrap their content with [UnfinishedWorkScope] and
/// pass their unfinished items; any descendant can then query them via
/// [UnfinishedWorkRegistry.of].
class UnfinishedWorkScope extends InheritedWidget {
  const UnfinishedWorkScope({
    super.key,
    required this.items,
    required super.child,
  });

  final List<UnfinishedItem> items;

  static UnfinishedWorkScope? of(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<UnfinishedWorkScope>();
  }

  @override
  bool updateShouldNotify(UnfinishedWorkScope oldWidget) =>
      items.length != oldWidget.items.length;
}

/// Convenience helper for showing the dialog before a navigation action.
/// Returns `true` if the user chose to leave (or if there's nothing pending),
/// `false` if they chose to stay.
Future<bool> showUnfinishedWorkDialogIfAny(
  BuildContext context, {
  VoidCallback? onLeave,
}) async {
  final scope = UnfinishedWorkScope.of(context);
  final items = scope?.items ?? const <UnfinishedItem>[];
  if (items.isEmpty) {
    onLeave?.call();
    return true;
  }
  final shouldLeave = await showUnfinishedWorkDialog(context, items: items);
  if (shouldLeave) {
    onLeave?.call();
  }
  return shouldLeave;
}

/// Shows the beautifully-designed unfinished-work dialog.
/// Returns `true` if the user chose to leave, `false` if they chose to stay.
Future<bool> showUnfinishedWorkDialog(
  BuildContext context, {
  required List<UnfinishedItem> items,
}) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: true,
    builder: (context) => _UnfinishedWorkDialog(items: items),
  );
  return result ?? false;
}

class _UnfinishedWorkDialog extends StatelessWidget {
  const _UnfinishedWorkDialog({required this.items});

  final List<UnfinishedItem> items;

  @override
  Widget build(BuildContext context) {
    final visibleItems = items.take(5).toList();
    final hiddenCount = items.length - visibleItems.length;
    final hasBlocking =
        items.any((i) => i.severity == UnfinishedSeverity.blocking);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Gradient header ──
              Container(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFFFFF7E6), Color(0xFFFFE4B5)],
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFC107),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.assignment_late_rounded,
                        color: Colors.white,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'You have unfinished work',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF1F2933),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${items.length} item${items.length == 1 ? '' : 's'} on this page '
                            'need${items.length == 1 ? 's' : ''} your attention '
                            'before you leave.',
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: Color(0xFF6B7280),
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // ── Items list ──
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ...visibleItems.map((item) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _severityDot(item.severity),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.title,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF111827),
                                      ),
                                    ),
                                    if (item.detail != null) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        item.detail!,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFF6B7280),
                                          height: 1.4,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        )),
                    if (hiddenCount > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 4, bottom: 6),
                        child: Text(
                          '+ $hiddenCount more item${hiddenCount == 1 ? '' : 's'}…',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF9CA3AF),
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              // ── Actions ──
              Container(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                decoration: const BoxDecoration(
                  color: Color(0xFFFAFAFA),
                  border: Border(
                    top: BorderSide(color: Color(0xFFE5E7EB), width: 1),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF6B7280),
                          side: const BorderSide(color: Color(0xFFD1D5DB)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          hasBlocking ? 'Leave anyway' : 'Leave anyway',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFFC107),
                          foregroundColor: const Color(0xFF1F2933),
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Stay on this page',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _severityDot(UnfinishedSeverity severity) {
    final color = switch (severity) {
      UnfinishedSeverity.info => const Color(0xFF3B82F6),
      UnfinishedSeverity.warning => const Color(0xFFF59E0B),
      UnfinishedSeverity.blocking => const Color(0xFFEF4444),
    };
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
