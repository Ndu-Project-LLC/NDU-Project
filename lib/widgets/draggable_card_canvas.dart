import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ─────────────────────────────────────────────────────────────────────────
/// Draggable Cards System
///
/// Allows cards on a screen to be dragged freely across the entire screen
/// surface. Cards are stacked in a free-form canvas overlay that floats
/// above the regular scrolling content. Users can:
///   • Toggle between "List mode" (sequential stacked cards) and
///     "Freeform mode" (drag-anywhere cards)
///   • Long-press a card in freeform mode to pick it up and drag it
///   • Tap to bring a card to the front
///   • Pin card positions across sessions (per-project, per-section)
///
/// Public API:
///   • DraggableCard            — wraps any child card to make it draggable
///   • FreeformCardCanvas       — overlay that hosts draggable cards
///   • CardPositionStore        — persists card positions via shared prefs
///   • DragModeToggle           — chip that toggles list vs freeform mode
/// ─────────────────────────────────────────────────────────────────────────

const Color _kDragHandleColor = Color(0xFFF59E0B);
const Color _kDragHandleActiveColor = Color(0xFFD97706);
const Color _kCanvasBgColor = Color(0xFF0F172A);
const Color _kCardShadowColor = Color(0x33000000);

/// Persists card positions per (project, section) using shared_preferences.
/// Key format: `drag_cards_{projectId}_{section}_{cardId}` -> "x,y"
class CardPositionStore {
  static String _key(String projectId, String section, String cardId) =>
      'drag_cards_${projectId}_$section\_$cardId';

  static Future<Offset?> getPosition(
      String projectId, String section, String cardId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key(projectId, section, cardId));
      if (raw == null || !raw.contains(',')) return null;
      final parts = raw.split(',');
      final dx = double.tryParse(parts[0]);
      final dy = double.tryParse(parts[1]);
      if (dx == null || dy == null) return null;
      return Offset(dx, dy);
    } catch (_) {
      return null;
    }
  }

  static Future<void> setPosition(String projectId, String section,
      String cardId, Offset position) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          _key(projectId, section, cardId),
          '${position.dx},${position.dy}');
    } catch (_) {
      // Silent failure — positions are best-effort
    }
  }

  static Future<void> clearSection(
      String projectId, String section) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys().where(
          (k) => k.startsWith('drag_cards_${projectId}_${section}_'));
      for (final k in keys) {
        await prefs.remove(k);
      }
    } catch (_) {}
  }
}

/// A single card that can be dragged freely when in freeform mode.
/// Pass [isFreeform] = false to render as a regular static card (list mode).
class DraggableCard extends StatefulWidget {
  const DraggableCard({
    super.key,
    required this.id,
    required this.child,
    required this.isFreeform,
    required this.canvasKey,
    this.onPositionChanged,
    this.onBringToFront,
    this.initialPosition,
    this.cardWidth,
    this.projectId = '',
    this.section = '',
  });

  final String id;
  final Widget child;
  final bool isFreeform;
  final GlobalKey canvasKey;
  final void Function(Offset position)? onPositionChanged;
  final void Function()? onBringToFront;
  final Offset? initialPosition;
  final double? cardWidth;
  final String projectId;
  final String section;

  @override
  State<DraggableCard> createState() => _DraggableCardState();
}

class _DraggableCardState extends State<DraggableCard> {
  Offset _position = Offset.zero;
  bool _isDragging = false;
  bool _positionLoaded = false;

  @override
  void initState() {
    super.initState();
    _position = widget.initialPosition ?? Offset.zero;
    _loadSavedPosition();
  }

  Future<void> _loadSavedPosition() async {
    if (widget.projectId.isEmpty || widget.section.isEmpty) {
      setState(() => _positionLoaded = true);
      return;
    }
    final saved = await CardPositionStore.getPosition(
        widget.projectId, widget.section, widget.id);
    if (saved != null && mounted) {
      setState(() {
        _position = saved;
        _positionLoaded = true;
      });
    } else if (mounted) {
      setState(() => _positionLoaded = true);
    }
  }

  void _handleDragUpdate(LongPressMoveUpdateDetails details) {
    setState(() {
      // Use the local offset (delta from previous position) via globalPosition
      // difference, since LongPressMoveUpdateDetails doesn't expose .delta.
      final newGlobal = details.globalPosition;
      final delta = _lastGlobalPos == null ? Offset.zero : (newGlobal - _lastGlobalPos!);
      _lastGlobalPos = newGlobal;
      _position += delta;
      // Clamp within canvas bounds
      final canvasCtx = widget.canvasKey.currentContext;
      if (canvasCtx != null) {
        final canvasBox = canvasCtx.findRenderObject() as RenderBox?;
        if (canvasBox != null && canvasBox.hasSize) {
          final canvasSize = canvasBox.size;
          final cardWidth = widget.cardWidth ?? 280.0;
          final cardHeight = 200.0; // approximate; cards vary
          _position = Offset(
            _position.dx.clamp(0.0, (canvasSize.width - cardWidth).clamp(0.0, canvasSize.width)),
            _position.dy.clamp(0.0, (canvasSize.height - cardHeight).clamp(0.0, canvasSize.height)),
          );
        }
      }
    });
  }

  Offset? _lastGlobalPos;

  void _handleDragEnd(LongPressEndDetails _) {
    setState(() {
      _isDragging = false;
      _lastGlobalPos = null;
    });
    widget.onPositionChanged?.call(_position);
    // Persist position
    if (widget.projectId.isNotEmpty && widget.section.isNotEmpty) {
      CardPositionStore.setPosition(
          widget.projectId, widget.section, widget.id, _position);
    }
  }

  @override
  Widget build(BuildContext context) {
    // List mode — render as static card
    if (!widget.isFreeform) {
      return widget.child;
    }

    // Freeform mode — render as positioned, draggable card
    return Positioned(
      left: _position.dx,
      top: _position.dy,
      child: GestureDetector(
        onTap: widget.onBringToFront,
        onLongPressStart: (details) {
          setState(() {
            _isDragging = true;
            _lastGlobalPos = details.globalPosition;
          });
          widget.onBringToFront?.call();
        },
        onLongPressMoveUpdate: _handleDragUpdate,
        onLongPressEnd: _handleDragEnd,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: widget.cardWidth ?? 280.0,
          transform: _isDragging
              ? (Matrix4.identity()..scale(1.04))
              : Matrix4.identity(),
          transformAlignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: _kCardShadowColor.withOpacity(_isDragging ? 0.4 : 0.15),
                blurRadius: _isDragging ? 24 : 10,
                offset: Offset(0, _isDragging ? 12 : 4),
              ),
            ],
            border: Border.all(
              color: _isDragging
                  ? _kDragHandleActiveColor.withOpacity(0.6)
                  : Colors.transparent,
              width: _isDragging ? 2 : 0,
            ),
          ),
          child: Stack(
            children: [
              widget.child,
              // Drag handle indicator (top-right) — only visible when not dragging
              Positioned(
                top: 6,
                right: 6,
                child: AnimatedOpacity(
                  opacity: _isDragging ? 0 : 0.6,
                  duration: const Duration(milliseconds: 180),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: _kDragHandleColor.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                          color: _kDragHandleColor.withOpacity(0.4)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.drag_indicator,
                            size: 12, color: _kDragHandleColor),
                        SizedBox(width: 2),
                        Text(
                          'DRAG',
                          style: TextStyle(
                            fontSize: 8,
                            fontWeight: FontWeight.w800,
                            color: _kDragHandleColor,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              // Live position readout while dragging
              if (_isDragging)
                Positioned(
                  bottom: 6,
                  right: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: _kCanvasBgColor.withOpacity(0.85),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${_position.dx.round()}, ${_position.dy.round()}',
                      style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Canvas overlay that hosts draggable cards in freeform mode.
/// Falls back to a regular Column in list mode.
class FreeformCardCanvas extends StatefulWidget {
  const FreeformCardCanvas({
    super.key,
    required this.projectId,
    required this.section,
    required this.cards, // (id, widget) pairs
    this.cardWidth = 280.0,
    this.listSpacing = 10.0,
    this.enableToggle = true,
    this.header,
  });

  final String projectId;
  final String section;
  final List<({String id, Widget widget})> cards;
  final double cardWidth;
  final double listSpacing;
  final bool enableToggle;
  final Widget? header;

  @override
  State<FreeformCardCanvas> createState() => _FreeformCardCanvasState();
}

class _FreeformCardCanvasState extends State<FreeformCardCanvas> {
  bool _isFreeform = false;
  int _frontCardIndex = 0;
  final GlobalKey _canvasKey = GlobalKey();
  final Map<String, Offset> _cardPositions = {};

  @override
  void initState() {
    super.initState();
    _loadAllPositions();
  }

  Future<void> _loadAllPositions() async {
    for (final c in widget.cards) {
      final pos = await CardPositionStore.getPosition(
          widget.projectId, widget.section, c.id);
      if (pos != null) {
        _cardPositions[c.id] = pos;
      }
    }
    if (mounted) setState(() {});
  }

  Future<void> _resetPositions() async {
    await CardPositionStore.clearSection(widget.projectId, widget.section);
    _cardPositions.clear();
    if (mounted) setState(() {});
  }

  void _bringToFront(int index) {
    setState(() => _frontCardIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header + drag mode toggle
        if (widget.enableToggle) ...[
          Row(
            children: [
              if (widget.header != null) Expanded(child: widget.header!),
              if (widget.header == null) const Spacer(),
              DragModeToggle(
                isFreeform: _isFreeform,
                onToggle: (v) => setState(() => _isFreeform = v),
                onReset: _isFreeform ? _resetPositions : null,
              ),
            ],
          ),
          const SizedBox(height: 12),
        ] else if (widget.header != null) ...[
          widget.header!,
          const SizedBox(height: 12),
        ],
        // Body: list mode or freeform mode
        if (!_isFreeform)
          _buildListMode()
        else
          _buildFreeformMode(),
      ],
    );
  }

  Widget _buildListMode() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < widget.cards.length; i++) ...[
          widget.cards[i].widget,
          if (i < widget.cards.length - 1)
            SizedBox(height: widget.listSpacing),
        ],
      ],
    );
  }

  Widget _buildFreeformMode() {
    return Container(
      key: _canvasKey,
      width: double.infinity,
      height: 600, // generous canvas height
      decoration: BoxDecoration(
        color: _kCanvasBgColor.withOpacity(0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _kDragHandleColor.withOpacity(0.3),
          width: 1.5,
          style: BorderStyle.solid,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(13),
        child: CustomPaint(
          painter: _DotGridPainter(),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
          // Hint banner (top-left)
          Positioned(
            top: 8,
            left: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _kDragHandleColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                    color: _kDragHandleColor.withOpacity(0.3)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.touch_app_outlined,
                      size: 11, color: _kDragHandleColor),
                  SizedBox(width: 4),
                  Text(
                    'LONG-PRESS A CARD TO DRAG • TAP TO BRING TO FRONT',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: _kDragHandleColor,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Draggable cards (in z-order; front card last)
          ...widget.cards.asMap().entries.map((entry) {
            final i = entry.key;
            final c = entry.value;
            // Z-index: cards listed in order, but frontCardIndex is on top
            final zIndex = (i == _frontCardIndex)
                ? widget.cards.length + 1
                : i;
            return IndexedStack(
              index: widget.cards.length - zIndex - 1,
              sizing: StackFit.passthrough,
              children: [
                DraggableCard(
                  id: c.id,
                  canvasKey: _canvasKey,
                  isFreeform: true,
                  cardWidth: widget.cardWidth,
                  projectId: widget.projectId,
                  section: widget.section,
                  initialPosition: _cardPositions[c.id] ??
                      _defaultPosition(i),
                  onBringToFront: () => _bringToFront(i),
                  onPositionChanged: (pos) =>
                      _cardPositions[c.id] = pos,
                  child: c.widget,
                ),
              ],
            );
          }),
            ],
          ),
        ),
      ),
    );
  }

  Offset _defaultPosition(int index) {
    // Stagger initial positions in a flowing spiral/row layout
    final cols = 3;
    final colWidth = 300.0;
    final rowHeight = 230.0;
    final col = index % cols;
    final row = index ~/ cols;
    return Offset(
      16 + col * colWidth,
      40 + row * rowHeight,
    );
  }
}

/// Paints a subtle dot grid pattern on the freeform canvas background.
class _DotGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const spacing = 24.0;
    const dotRadius = 1.5;
    final paint = Paint()
      ..color = const Color(0xFF64748B).withOpacity(0.25)
      ..style = PaintingStyle.fill;
    for (var x = spacing / 2; x < size.width; x += spacing) {
      for (var y = spacing / 2; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), dotRadius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// A pill-style toggle button for switching between List and Freeform modes.
class DragModeToggle extends StatelessWidget {
  const DragModeToggle({
    super.key,
    required this.isFreeform,
    required this.onToggle,
    this.onReset,
  });

  final bool isFreeform;
  final ValueChanged<bool> onToggle;
  final VoidCallback? onReset;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Reset positions (freeform only)
        if (isFreeform && onReset != null) ...[
          Tooltip(
            message: 'Reset all card positions',
            child: InkWell(
              onTap: onReset,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: const Color(0xFFEF4444).withOpacity(0.3)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.refresh,
                        size: 13, color: Color(0xFFEF4444)),
                    SizedBox(width: 4),
                    Text(
                      'Reset',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFFEF4444),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
        // Mode toggle pill
        Tooltip(
          message: isFreeform
              ? 'Switch to list mode (sequential stacked cards)'
              : 'Switch to freeform mode (drag cards anywhere on screen)',
          child: InkWell(
            onTap: () => onToggle(!isFreeform),
            borderRadius: BorderRadius.circular(8),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: isFreeform
                    ? _kDragHandleColor.withOpacity(0.18)
                    : const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isFreeform
                      ? _kDragHandleColor.withOpacity(0.6)
                      : const Color(0xFFD1D5DB),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isFreeform
                        ? Icons.drag_indicator
                        : Icons.view_agenda_outlined,
                    size: 14,
                    color: isFreeform
                        ? _kDragHandleActiveColor
                        : const Color(0xFF6B7280),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    isFreeform ? 'FREEFORM' : 'LIST',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: isFreeform
                          ? _kDragHandleActiveColor
                          : const Color(0xFF6B7280),
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(width: 6),
                  // Switch indicator
                  Container(
                    width: 24,
                    height: 12,
                    decoration: BoxDecoration(
                      color: isFreeform
                          ? _kDragHandleColor
                          : const Color(0xFFD1D5DB),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: AnimatedAlign(
                      duration: const Duration(milliseconds: 200),
                      alignment: isFreeform
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        width: 10,
                        height: 10,
                        margin: const EdgeInsets.all(1),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
