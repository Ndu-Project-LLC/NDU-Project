import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ─────────────────────────────────────────────────────────────────────────
/// KanbanCardGrid
///
/// A responsive grid of cards that the user can reorder via long-press
/// drag-and-drop — exactly like a Kanban board. Drop a card onto another
/// card's slot and the two swap positions. The order is persisted to
/// SharedPreferences (per-project, per-section) so the user's preferred
/// arrangement survives reloads.
///
/// Features:
///   • Long-press any card to pick it up (works for mouse + touch).
///   • While dragging, every other slot becomes a live drop target with a
///     highlight ring + soft amber halo, so the user always knows where the
///     card will land.
///   • The dragged card's source slot dims to 30% opacity (placeholder).
///   • The floating "feedback" card lifts with elevation + 96% opacity so
///     the user can still read its content while dragging.
///   • A subtle "DRAG" pill in the top-right corner of every card telegraphs
///     affordance (matches the existing FreeformCardCanvas pattern).
///   • A "Reset card order" button appears as soon as the order diverges
///     from the default — keeps the UI honest without cluttering the
///     initial view.
///   • A one-line hint banner above the grid teaches the interaction
///     ("Long-press a card to drag • Drop onto another card to swap").
///   • Order is persisted to SharedPreferences under
///     `kanban_order_{projectId}_{section}` as a JSON-style string list.
///
/// Public API:
///   • KanbanCardGrid(cards, projectId, section, columns, defaultOrder)
///   • KanbanCardEntry   — (id, child) record consumed by the grid
/// ─────────────────────────────────────────────────────────────────────────

const Color _kKanbanAccent = Color(0xFFF59E0B); // amber
const Color _kKanbanAccentActive = Color(0xFFD97706);
const Color _kKanbanDragPillBg = Color(0xFFF59E0B);
const Color _kKanbanHintBg = Color(0xFFFEF3C7);
const Color _kKanbanHintBorder = Color(0xFFFCD34D);
const Color _kKanbanHintText = Color(0xFF92400E);

/// A single card entry in a [KanbanCardGrid].
class KanbanCardEntry {
  const KanbanCardEntry({required this.id, required this.child});

  /// Stable identifier for this card. Used as the drag payload + the
  /// SharedPreferences key component. Must be unique within the grid.
  final String id;

  /// The card widget to render in this slot.
  final Widget child;
}

/// A responsive grid of reorderable cards.
///
/// Wrap any list of [KanbanCardEntry] items and the user will be able to
/// long-press-drag any card onto another card to swap their positions. The
/// new order is persisted to [SharedPreferences] keyed by
/// `kanban_order_{projectId}_{section}`.
class KanbanCardGrid extends StatefulWidget {
  const KanbanCardGrid({
    super.key,
    required this.cards,
    required this.projectId,
    required this.section,
    this.columns = 2,
    this.spacing = 16.0,
    this.runSpacing = 16.0,
    this.defaultOrder,
    this.showHintBanner = true,
    this.hintText,
  });

  /// The cards to render. Order of this list is the *default* order;
  /// the user's persisted order (if any) overrides it on load.
  final List<KanbanCardEntry> cards;

  /// Project identifier — distinguishes persisted orders across projects.
  /// Empty string is fine for a global/shared grid.
  final String projectId;

  /// Section identifier — distinguishes persisted orders across screens
  /// within the same project (e.g. 'fep_summary', 'planning_dashboard').
  final String section;

  /// Number of columns at desktop width. Falls back to 1 column on mobile.
  final int columns;

  /// Horizontal spacing between cards in a row.
  final double spacing;

  /// Vertical spacing between rows.
  final double runSpacing;

  /// Optional explicit default order. If null, the order of [cards] is
  /// used. Provide this if [cards] may be supplied in a non-stable order
  /// (e.g. derived from a Map iteration).
  final List<String>? defaultOrder;

  /// Whether to render the amber hint banner above the grid.
  final bool showHintBanner;

  /// Override for the hint banner text. Defaults to a sensible string.
  final String? hintText;

  @override
  State<KanbanCardGrid> createState() => _KanbanCardGridState();
}

class _KanbanCardGridState extends State<KanbanCardGrid> {
  late List<String> _order;
  String? _draggingId;
  String? _hoverTargetId;

  // ─── Lifecycle ───────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _order = _defaultOrder();
    _loadPersistedOrder();
  }

  @override
  void didUpdateWidget(covariant KanbanCardGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If the set of card IDs changed (rare, but possible if the host screen
    // dynamically adds/removes cards), reconcile the order: keep the
    // existing relative order for cards that still exist, append any new
    // cards at the end.
    final knownIds = widget.cards.map((c) => c.id).toSet();
    final oldOrderIds = _order.toSet();
    if (!setEquals(knownIds, oldOrderIds)) {
      final reconciled = <String>[
        ..._order.where((id) => knownIds.contains(id)),
        ...widget.cards
            .where((c) => !oldOrderIds.contains(c.id))
            .map((c) => c.id),
      ];
      _order = reconciled;
      _savePersistedOrder();
    }
  }

  List<String> _defaultOrder() {
    if (widget.defaultOrder != null) return List.from(widget.defaultOrder!);
    return widget.cards.map((c) => c.id).toList();
  }

  String get _prefsKey =>
      'kanban_order_${widget.projectId}_${widget.section}';

  Future<void> _loadPersistedOrder() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getStringList(_prefsKey);
      if (saved == null) {
        return;
      }
      // Validate: every saved id must still exist; every known id must
      // be present in the saved list. If validation fails, discard.
      final knownIds = widget.cards.map((c) => c.id).toSet();
      final savedSet = saved.toSet();
      final allKnownPresent = knownIds.every((id) => savedSet.contains(id));
      final allSavedKnown =
          saved.every((id) => knownIds.contains(id));
      if (allKnownPresent && allSavedKnown && saved.length == knownIds.length) {
        _order = List<String>.from(saved);
        if (mounted) setState(() {});
      }
    } catch (_) {
      // Silent — order load is best-effort.
    }
  }

  Future<void> _savePersistedOrder() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_prefsKey, _order);
    } catch (_) {
      // Silent — order persistence is best-effort.
    }
  }

  // ─── Drag handlers ───────────────────────────────────────────────────────

  void _onDragStarted(String id) {
    setState(() => _draggingId = id);
  }

  void _onDragEnd() {
    if (_draggingId != null || _hoverTargetId != null) {
      setState(() {
        _draggingId = null;
        _hoverTargetId = null;
      });
    }
  }

  void _onHoverChanged(String? id) {
    if (_hoverTargetId != id) {
      setState(() => _hoverTargetId = id);
    }
  }

  void _onAccept(String draggedId, String targetId) {
    if (draggedId == targetId) {
      _onDragEnd();
      return;
    }
    setState(() {
      final draggedIdx = _order.indexOf(draggedId);
      final targetIdx = _order.indexOf(targetId);
      if (draggedIdx == -1 || targetIdx == -1) {
        _draggingId = null;
        _hoverTargetId = null;
        return;
      }
      // Swap positions — gives the satisfying "two cards trade places"
      // Kanban feel.
      final tmp = _order[draggedIdx];
      _order[draggedIdx] = _order[targetIdx];
      _order[targetIdx] = tmp;
      _draggingId = null;
      _hoverTargetId = null;
    });
    _savePersistedOrder();
  }

  void _resetOrder() {
    setState(() {
      _order = _defaultOrder();
      _draggingId = null;
      _hoverTargetId = null;
    });
    _savePersistedOrder();
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.sizeOf(context).width < 720;
    final effectiveColumns = isMobile ? 1 : widget.columns;

    final defaultOrder = _defaultOrder();
    final orderChanged = !_listEquals(_order, defaultOrder);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Hint banner + Reset button row
        if (widget.showHintBanner || orderChanged) ...[
          Row(
            children: [
              if (widget.showHintBanner)
                Expanded(child: _buildHintBanner()),
              if (widget.showHintBanner && orderChanged)
                const SizedBox(width: 8),
              if (orderChanged) _buildResetButton(),
            ],
          ),
          const SizedBox(height: 12),
        ],
        // The reorderable grid
        _buildGrid(effectiveColumns),
      ],
    );
  }

  Widget _buildHintBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: _kKanbanHintBg.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _kKanbanHintBorder.withValues(alpha: 0.6)),
      ),
      child: Row(
        children: [
          const Icon(Icons.touch_app_outlined,
              size: 14, color: _kKanbanHintText),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              widget.hintText ??
                  'Long-press a card to drag • Drop onto another card to swap',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: _kKanbanHintText,
                letterSpacing: 0.1,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResetButton() {
    return Tooltip(
      message: 'Reset to the default card order',
      child: InkWell(
        onTap: _resetOrder,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFEF4444).withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
                color: const Color(0xFFEF4444).withValues(alpha: 0.25)),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.restart_alt, size: 13, color: Color(0xFFEF4444)),
              SizedBox(width: 4),
              Text(
                'Reset order',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFEF4444),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGrid(int columns) {
    // Group cards into rows based on _order
    final rows = <Widget>[];
    for (var i = 0; i < _order.length; i += columns) {
      final rowChildren = <Widget>[];
      for (var j = 0; j < columns && i + j < _order.length; j++) {
        final cardId = _order[i + j];
        final entry = _entryForId(cardId);
        if (entry == null) continue;
        rowChildren.add(
          Expanded(
            child: _KanbanCardSlot(
              cardId: cardId,
              isDragging: _draggingId == cardId,
              isHoverTarget: _hoverTargetId == cardId,
              anyCardDragging: _draggingId != null,
              onDragStarted: () => _onDragStarted(cardId),
              onDragEnd: _onDragEnd,
              onHoverChanged: _onHoverChanged,
              onAccept: (draggedId) => _onAccept(draggedId, cardId),
              child: entry.child,
            ),
          ),
        );
        if (j < columns - 1 && i + j + 1 < _order.length) {
          rowChildren.add(SizedBox(width: widget.spacing));
        }
      }
      rows.add(
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: rowChildren,
        ),
      );
      if (i + columns < _order.length) {
        rows.add(SizedBox(height: widget.runSpacing));
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: rows,
    );
  }

  KanbanCardEntry? _entryForId(String id) {
    for (final c in widget.cards) {
      if (c.id == id) return c;
    }
    return null;
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────

  bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  bool setEquals<T>(Set<T> a, Set<T> b) {
    if (a.length != b.length) return false;
    return a.containsAll(b);
  }
}

/// A single slot in the [KanbanCardGrid] — wraps a card in a
/// [LongPressDraggable] + [DragTarget] so it can both be dragged and
/// receive drops. Manages hover/drag visual feedback.
class _KanbanCardSlot extends StatelessWidget {
  const _KanbanCardSlot({
    required this.cardId,
    required this.child,
    required this.isDragging,
    required this.isHoverTarget,
    required this.anyCardDragging,
    required this.onDragStarted,
    required this.onDragEnd,
    required this.onHoverChanged,
    required this.onAccept,
  });

  final String cardId;
  final Widget child;
  final bool isDragging;
  final bool isHoverTarget;
  final bool anyCardDragging;
  final VoidCallback onDragStarted;
  final VoidCallback onDragEnd;
  final ValueChanged<String?> onHoverChanged;
  final void Function(String draggedId) onAccept;

  @override
  Widget build(BuildContext context) {
    return DragTarget<String>(
      onAcceptWithDetails: (details) {
        onAccept(details.data);
      },
      onWillAcceptWithDetails: (details) {
        // Don't accept a drop on ourselves.
        final data = details.data;
        if (data == cardId) return false;
        onHoverChanged(cardId);
        return true;
      },
      onLeave: (_) {
        onHoverChanged(null);
      },
      builder: (context, candidate, rejected) {
        final isReceivingDrop = candidate.isNotEmpty;
        return LongPressDraggable<String>(
          data: cardId,
          delay: const Duration(milliseconds: 220),
          onDragStarted: onDragStarted,
          onDragEnd: (_) => onDragEnd(),
          onDragCompleted: onDragEnd,
          onDraggableCanceled: (_, __) => onDragEnd(),
          // While dragging this card, lift it as a floating, elevated copy
          // so the user can still read it.
          feedback: Material(
            elevation: 14,
            borderRadius: BorderRadius.circular(14),
            color: Colors.transparent,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Opacity(
                opacity: 0.94,
                child: _FeedbackWrapper(child: child),
              ),
            ),
          ),
          // Source slot dims to 30% so the user sees a "hole".
          childWhenDragging: Opacity(
            opacity: 0.28,
            child: IgnorePointer(child: child),
          ),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            transform: isHoverTarget
                ? (Matrix4.identity()..scale(1.015))
                : Matrix4.identity(),
            transformAlignment: Alignment.topCenter,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(13),
              border: isHoverTarget
                  ? Border.all(
                      color: _kKanbanAccentActive.withValues(alpha: 0.85),
                      width: 2.2,
                    )
                  : (isReceivingDrop
                      ? Border.all(
                          color: _kKanbanAccent.withValues(alpha: 0.5),
                          width: 1.5,
                        )
                      : null),
              boxShadow: isHoverTarget
                  ? [
                      BoxShadow(
                        color: _kKanbanAccent.withValues(alpha: 0.28),
                        blurRadius: 22,
                        spreadRadius: 2,
                      ),
                    ]
                  : null,
            ),
            child: Stack(
              children: [
                child,
                // DRAG affordance pill (top-right). Always visible
                // at low opacity; brightens when any card is being dragged.
                Positioned(
                  top: 8,
                  right: 8,
                  child: IgnorePointer(
                    child: AnimatedOpacity(
                      opacity: anyCardDragging ? 0.85 : 0.55,
                      duration: const Duration(milliseconds: 180),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: _kKanbanDragPillBg.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                              color:
                                  _kKanbanDragPillBg.withValues(alpha: 0.45)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.drag_indicator,
                                size: 12, color: _kKanbanAccentActive),
                            SizedBox(width: 3),
                            Text(
                              'DRAG',
                              style: TextStyle(
                                fontSize: 8,
                                fontWeight: FontWeight.w800,
                                color: _kKanbanAccentActive,
                                letterSpacing: 0.6,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Wraps the feedback card so it sits inside a fixed-width container with
/// a subtle outline, making the dragged ghost readable without leaking
/// layout (since the original child was created inside an `Expanded`).
class _FeedbackWrapper extends StatelessWidget {
  const _FeedbackWrapper({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: _kKanbanAccent.withValues(alpha: 0.55), width: 1.5),
      ),
      child: child,
    );
  }
}
