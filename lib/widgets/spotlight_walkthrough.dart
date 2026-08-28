/// Spotlight Walkthrough — a full-screen coach-mark that "punches" a
/// rounded-rect hole through a dark scrim around a target widget located
/// via a [GlobalKey], with a floating tooltip card carrying step content,
/// an optional primary CTA and prev/next navigation.
///
/// Usage (in a Stack):
/// ```dart
/// if (_showCoachMark)
///   Positioned.fill(
///     child: SpotlightWalkthrough(
///       targetKey: _targetCardKey,
///       steps: const [SpotlightStep(title: 'Title', description: 'Body')],
///       primaryLabel: 'Assign Manager Now',
///       onPrimary: _openAssignDialog,
///       onDismiss: () => setState(() => _showCoachMark = false),
///     ),
///   );
/// ```
///
/// Or imperatively via an overlay:
/// ```dart
/// SpotlightWalkthrough.show(context, targetKey: k, steps: [...], onDismiss: () {});
/// ```
///
/// Design notes:
/// - The scrim is painted with `Path.combine(PathOperation.difference, …)`
///   so the highlighted area is a true punched-through hole, with an
///   animated glow ring around it.
/// - Tap-outside-to-dismiss is implemented with four invisible barrier bands
///   that surround the hole — taps *inside* the hole fall through to the
///   target widget so the user can interact with the real UI (e.g. tap the
///   PROJECT MANAGER card itself).
/// - The target [RenderBox] is re-measured every frame the glow animates,
///   so the highlight stays glued to the target while the page scrolls.
/// - The widget never crashes when the target has no render box yet: it
///   waits (post-frame) for the box to become available and auto-dismisses
///   gracefully if the target never appears.

import 'dart:ui' show BlurStyle, MaskFilter, PathOperation;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// One step of a [SpotlightWalkthrough].
class SpotlightStep {
  /// Short headline shown at the top of the tooltip card.
  final String title;

  /// Supporting copy shown under the title.
  final String description;

  /// Optional numbered guidance rows (e.g. the 3 "here's how" steps).
  final List<String> bullets;

  /// Optional icon shown in the card's leading medallion.
  final IconData? icon;

  /// Optional badge text rendered as a small pill next to the title
  /// (e.g. 'Required').
  final String? badgeLabel;

  const SpotlightStep({
    required this.title,
    this.description = '',
    this.bullets = const [],
    this.icon,
    this.badgeLabel,
  });
}

class SpotlightWalkthrough extends StatefulWidget {
  /// [GlobalKey] attached to the widget that should be highlighted.
  final GlobalKey targetKey;

  /// Ordered list of steps. When more than one step is provided, prev/next
  /// controls and step dots are rendered.
  final List<SpotlightStep> steps;

  /// Called when the walkthrough should close (Got it, ✕, tap outside,
  /// Escape, or advancing past the last step).
  final VoidCallback onDismiss;

  /// Optional label for the primary call-to-action button.
  final String? primaryLabel;

  /// Optional callback for the primary CTA. The walkthrough stays open so
  /// the host can decide when to dismiss (pass [dismissOnPrimary] to change).
  final VoidCallback? onPrimary;

  /// Whether tapping the primary CTA should also dismiss the walkthrough.
  final bool dismissOnPrimary;

  /// Scrim color behind the punched hole.
  final Color barrierColor;

  /// Accent color for the glow ring and primary button.
  final Color accentColor;

  /// Corner radius of the punched hole / glow ring.
  final double highlightRadius;

  /// Padding between the target's bounds and the punched hole.
  final double highlightPadding;

  /// Whether to scroll the target into view when it first appears.
  final bool ensureVisible;

  /// How long to wait for the target's render box before giving up.
  final Duration targetTimeout;

  const SpotlightWalkthrough({
    super.key,
    required this.targetKey,
    required this.steps,
    required this.onDismiss,
    this.primaryLabel,
    this.onPrimary,
    this.dismissOnPrimary = false,
    this.barrierColor = Colors.black54,
    this.accentColor = const Color(0xFFFFC107),
    this.highlightRadius = 16,
    this.highlightPadding = 8,
    this.ensureVisible = true,
    this.targetTimeout = const Duration(seconds: 3),
  }) : assert(steps.length > 0);

  /// Shows the walkthrough as a root overlay entry and removes it when
  /// dismissed. Returns nothing; [onDismiss] is forwarded to the host.
  static void show(
    BuildContext context, {
    required GlobalKey targetKey,
    required List<SpotlightStep> steps,
    required VoidCallback onDismiss,
    String? primaryLabel,
    VoidCallback? onPrimary,
    bool dismissOnPrimary = false,
    Color barrierColor = Colors.black54,
    Color accentColor = const Color(0xFFFFC107),
    bool ensureVisible = true,
  }) {
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => Positioned.fill(
        child: SpotlightWalkthrough(
          targetKey: targetKey,
          steps: steps,
          onDismiss: () {
            if (entry.mounted) entry.remove();
            onDismiss();
          },
          primaryLabel: primaryLabel,
          onPrimary: onPrimary,
          dismissOnPrimary: dismissOnPrimary,
          barrierColor: barrierColor,
          accentColor: accentColor,
          ensureVisible: ensureVisible,
        ),
      ),
    );
    Overlay.of(context, rootOverlay: true).insert(entry);
  }

  @override
  State<SpotlightWalkthrough> createState() => _SpotlightWalkthroughState();
}

class _SpotlightWalkthroughState extends State<SpotlightWalkthrough>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  Rect? _targetRect;
  Offset _overlayOrigin = Offset.zero;
  int _stepIndex = 0;
  int _framesWaited = 0;
  bool _didEnsureVisible = false;
  bool _dismissed = false;

  static const int _maxWaitFrames = 200; // ~3.3s at 60fps
  static const double _cardWidth = 340;
  static const double _screenGutter = 16;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
      lowerBound: 0,
      upperBound: 1,
    )..repeat(reverse: true);
    _pulse.addListener(_onPulseTick);
    WidgetsBinding.instance.addPostFrameCallback((_) => _onPulseTick());
  }

  @override
  void dispose() {
    _pulse.removeListener(_onPulseTick);
    _pulse.dispose();
    super.dispose();
  }

  /// Runs on every pulse tick *and* once post-frame: re-measures the target
  /// render box (cheap localToGlobal math) so the highlight, tap-through hole
  /// and tooltip track the target during scrolling / layout changes.
  void _onPulseTick() {
    if (!mounted || _dismissed) return;
    final rect = _measureTarget();
    if (rect == null) {
      // Target not ready yet — keep waiting post-frame, give up eventually.
      if (_framesWaited >= _maxWaitFrames) {
        _dismiss();
        return;
      }
      _framesWaited++;
      WidgetsBinding.instance.addPostFrameCallback((_) => _onPulseTick());
      return;
    }
    _framesWaited = 0;
    if (!_didEnsureVisible) {
      _didEnsureVisible = true;
      _ensureTargetVisible();
    }
    final changed = _targetRect == null ||
        ((_targetRect!.left - rect.left).abs() > 0.5 ||
            (_targetRect!.top - rect.top).abs() > 0.5 ||
            (_targetRect!.width - rect.width).abs() > 0.5 ||
            (_targetRect!.height - rect.height).abs() > 0.5);
    if (changed) {
      setState(() => _targetRect = rect);
    }
  }

  /// Measures the target's bounding rect in the coordinate space of THIS
  /// widget's overlay (so the painted hole lines up with the target even
  /// when this widget is inset by app bars / sidebars). Returns null (never
  /// throws) when the key has no context, the render object is not an
  /// attached, sized RenderBox, or the node is off-screen/defunct.
  Rect? _measureTarget() {
    try {
      // Origin of this widget in window coordinates — used to translate the
      // target's global rect into our local paint space.
      final selfRo = context.findRenderObject();
      if (selfRo is RenderBox && selfRo.attached && selfRo.hasSize) {
        final selfTopLeft = selfRo.localToGlobal(Offset.zero);
        if (selfTopLeft.isFinite) _overlayOrigin = selfTopLeft;
      }
      final targetCtx = widget.targetKey.currentContext;
      if (targetCtx == null || !targetCtx.mounted) return null;
      final ro = targetCtx.findRenderObject();
      if (ro is! RenderBox || !ro.attached || !ro.hasSize) return null;
      final topLeft = ro.localToGlobal(Offset.zero);
      if (!topLeft.isFinite) return null;
      final size = ro.size;
      if (size.isEmpty || !size.isFinite) return null;
      return (topLeft & size).shift(-_overlayOrigin);
    } catch (_) {
      return null;
    }
  }

  void _ensureTargetVisible() {
    if (!widget.ensureVisible) return;
    try {
      final context = widget.targetKey.currentContext;
      if (context == null) return;
      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
        alignment: 0.3,
      );
    } catch (_) {
      // Target may not be inside a Scrollable — safe to ignore.
    }
  }

  void _dismiss() {
    if (_dismissed) return;
    _dismissed = true;
    widget.onDismiss();
  }

  void _next() {
    if (_stepIndex < widget.steps.length - 1) {
      setState(() => _stepIndex++);
    } else {
      _dismiss();
    }
  }

  void _previous() {
    if (_stepIndex > 0) setState(() => _stepIndex--);
  }

  void _onPrimary() {
    widget.onPrimary?.call();
    if (widget.dismissOnPrimary) _dismiss();
  }

  @override
  Widget build(BuildContext context) {
    final steps = widget.steps;
    final step = steps[_stepIndex.clamp(0, steps.length - 1)];
    final multiStep = steps.length > 1;
    final media = MediaQuery.of(context);
    final screenSize = media.size;
    final rect = _targetRect;

    // While the target render box is not ready yet, render nothing at all
    // (fully pointer-transparent, zero visual noise) instead of crashing.
    if (rect == null) {
      return const SizedBox.shrink();
    }

    final glowRect = rect.inflate(widget.highlightPadding);

    // Local size of the area we fill (may differ from the window when this
    // widget is embedded inside a Scaffold body with an app bar etc.).
    Size localSize = screenSize;
    try {
      final selfRo = context.findRenderObject();
      if (selfRo is RenderBox && selfRo.attached && selfRo.hasSize) {
        final s = selfRo.size;
        if (s.isFinite && !s.isEmpty) localSize = s;
      }
    } catch (_) {}

    final tooltipLayout =
        _computeTooltipLayout(step, glowRect, localSize, multiStep);

    return SizedBox.expand(
      child: Material(
        type: MaterialType.transparency,
        child: CallbackShortcuts(
          bindings: {
            const SingleActivator(LogicalKeyboardKey.escape): _dismiss,
          },
          child: Focus(
            autofocus: true,
            child: Stack(
              children: [
                // ── Scrim + glow (painted, ignores pointers) ────────────
                Positioned.fill(
                  child: IgnorePointer(
                    child: AnimatedBuilder(
                      animation: _pulse,
                      builder: (context, _) {
                        return CustomPaint(
                          painter: _SpotlightBarrierPainter(
                            rect: glowRect,
                            radius: widget.highlightRadius,
                            barrierColor: widget.barrierColor,
                            accentColor: widget.accentColor,
                            pulse: _pulse.value,
                          ),
                        );
                      },
                    ),
                  ),
                ),

                // ── Tap-to-dismiss bands around the hole ────────────────
                // Taps inside the hole are NOT intercepted: they reach the
                // target widget underneath so the user can follow the
                // guidance directly.
                _barrierBand(
                  Rect.fromLTWH(0, 0, localSize.width, glowRect.top),
                ),
                _barrierBand(
                  Rect.fromLTWH(0, glowRect.bottom, localSize.width,
                      (localSize.height - glowRect.bottom).clamp(0, double.infinity)),
                ),
                _barrierBand(
                  Rect.fromLTWH(0, glowRect.top, glowRect.left, glowRect.height),
                ),
                _barrierBand(
                  Rect.fromLTWH(glowRect.right, glowRect.top,
                      (localSize.width - glowRect.right).clamp(0, double.infinity),
                      glowRect.height),
                ),

                // ── Tooltip card ────────────────────────────────────────
                Positioned(
                  left: tooltipLayout.left,
                  top: tooltipLayout.top,
                  width: tooltipLayout.width,
                  child: _TooltipCard(
                    step: step,
                    stepIndex: _stepIndex,
                    stepCount: steps.length,
                    multiStep: multiStep,
                    accentColor: widget.accentColor,
                    primaryLabel: widget.primaryLabel,
                    onNext: _next,
                    onPrevious: _previous,
                    onPrimary: _onPrimary,
                    onDismiss: _dismiss,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Invisible, pointer-opaque band that dismisses the walkthrough on tap.
  Widget _barrierBand(Rect rect) {
    if (rect.width <= 0 || rect.height <= 0) return const SizedBox.shrink();
    return Positioned(
      left: rect.left,
      top: rect.top,
      width: rect.width,
      height: rect.height,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _dismiss,
        child: const ColoredBox(color: Color(0x00000000)),
      ),
    );
  }

  _TooltipLayout _computeTooltipLayout(
    SpotlightStep step,
    Rect glowRect,
    Size localSize,
    bool multiStep,
  ) {
    final width = _cardWidth.clamp(0.0, localSize.width - _screenGutter * 2);
    final bulletsHeight = step.bullets.length * 30.0;
    final estimatedHeight = 96 +
        (step.description.isEmpty ? 0 : 40) +
        bulletsHeight +
        (widget.primaryLabel == null ? 0 : 52) +
        (multiStep ? 44 : 0);
    final gap = 14.0;

    // Prefer below the highlight; flip above when there is not enough room.
    final belowTop = glowRect.bottom + gap;
    final aboveTop = glowRect.top - gap - estimatedHeight;
    final fitsBelow =
        belowTop + estimatedHeight <= localSize.height - _screenGutter;
    final top = fitsBelow
        ? belowTop
        : (aboveTop >= _screenGutter ? aboveTop : _screenGutter);

    // Center horizontally over the target, clamped to the screen gutter.
    double left = glowRect.center.dx - width / 2;
    left = left.clamp(
        _screenGutter,
        (localSize.width - width - _screenGutter)
            .clamp(_screenGutter, double.infinity));
    return _TooltipLayout(left: left, top: top, width: width);
  }
}

class _TooltipLayout {
  final double left;
  final double top;
  final double width;
  const _TooltipLayout({
    required this.left,
    required this.top,
    required this.width,
  });
}

/// Paints the dark scrim with a punched rounded-rect hole plus an animated
/// glow ring around the highlight.
class _SpotlightBarrierPainter extends CustomPainter {
  final Rect rect;
  final double radius;
  final Color barrierColor;
  final Color accentColor;
  final double pulse;

  _SpotlightBarrierPainter({
    required this.rect,
    required this.radius,
    required this.barrierColor,
    required this.accentColor,
    required this.pulse,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Scrim with punched hole.
    final full = Path()..addRect(Offset.zero & size);
    final hole = Path()
      ..addRRect(RRect.fromRectAndRadius(rect, Radius.circular(radius)));
    final scrim = Path.combine(PathOperation.difference, full, hole);
    canvas.drawPath(scrim, Paint()..color = barrierColor);

    // 2. Soft outer glow breathing with the pulse.
    final glowSpread = 10.0 + 8.0 * pulse;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          rect.inflate(2 + 2 * pulse), Radius.circular(radius + 2)),
      Paint()
        ..color = accentColor.withValues(alpha: 0.10 + 0.10 * pulse)
        ..maskFilter = MaskFilter.blur(BlurStyle.outer, glowSpread),
    );

    // 3. Crisp accent ring around the hole.
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(radius)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0 + 0.75 * pulse
        ..color = accentColor.withValues(alpha: 0.65 + 0.35 * pulse),
    );
  }

  @override
  bool shouldRepaint(covariant _SpotlightBarrierPainter old) {
    return old.rect != rect ||
        old.radius != radius ||
        old.barrierColor != barrierColor ||
        old.accentColor != accentColor ||
        old.pulse != pulse;
  }
}

/// The floating card carrying the step content, CTA and navigation.
class _TooltipCard extends StatelessWidget {
  final SpotlightStep step;
  final int stepIndex;
  final int stepCount;
  final bool multiStep;
  final Color accentColor;
  final String? primaryLabel;
  final VoidCallback onNext;
  final VoidCallback onPrevious;
  final VoidCallback onPrimary;
  final VoidCallback onDismiss;

  const _TooltipCard({
    required this.step,
    required this.stepIndex,
    required this.stepCount,
    required this.multiStep,
    required this.accentColor,
    required this.primaryLabel,
    required this.onNext,
    required this.onPrevious,
    required this.onPrimary,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final isLast = stepIndex >= stepCount - 1;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accentColor.withValues(alpha: 0.35), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header: medallion + title + badge + close ──────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.16),
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: accentColor.withValues(alpha: 0.45), width: 1),
                ),
                child: Icon(
                  step.icon ?? Icons.touch_app_outlined,
                  size: 20,
                  color: const Color(0xFF8A6100),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            step.title,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF141414),
                              height: 1.2,
                            ),
                          ),
                        ),
                        if (step.badgeLabel != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFDC2626),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              step.badgeLabel!,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (multiStep) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Step ${stepIndex + 1} of $stepCount',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.black.withValues(alpha: 0.45),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 4),
              _MiniIconButton(
                icon: Icons.close,
                tooltip: 'Dismiss',
                onTap: onDismiss,
              ),
            ],
          ),

          if (step.description.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              step.description,
              style: TextStyle(
                fontSize: 13,
                height: 1.45,
                color: const Color(0xFF141414).withValues(alpha: 0.72),
              ),
            ),
          ],

          if (step.bullets.isNotEmpty) ...[
            const SizedBox(height: 12),
            ...step.bullets.asMap().entries.map((entry) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 7),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: accentColor,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '${entry.key + 1}',
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        entry.value,
                        style: const TextStyle(
                          fontSize: 12.5,
                          height: 1.4,
                          color: Color(0xFF1F2937),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],

          if (primaryLabel != null) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onPrimary,
                icon: const Icon(Icons.person_add_alt_1, size: 17),
                label: Text(primaryLabel!),
                style: FilledButton.styleFrom(
                  backgroundColor: accentColor,
                  foregroundColor: Colors.black,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  textStyle: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                  ),
                ),
              ),
            ),
          ],

          if (multiStep) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                // Step dots
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(stepCount, (i) {
                      final active = i == stepIndex;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        width: active ? 18 : 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: active
                              ? accentColor
                              : Colors.black.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      );
                    }),
                  ),
                ),
                TextButton(
                  onPressed: stepIndex == 0 ? null : onPrevious,
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    foregroundColor: const Color(0xFF141414),
                  ),
                  child: const Text('Back'),
                ),
                const SizedBox(width: 4),
                TextButton(
                  onPressed: onNext,
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF8A6100),
                    backgroundColor: accentColor.withValues(alpha: 0.14),
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text(isLast ? 'Got it' : 'Next'),
                ),
              ],
            ),
          ] else ...[
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: onNext,
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF8A6100),
                  backgroundColor: accentColor.withValues(alpha: 0.14),
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text('Got it'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Small circular icon button used for the tooltip's close affordance.
class _MiniIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _MiniIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(
            icon,
            size: 18,
            color: Colors.black.withValues(alpha: 0.45),
          ),
        ),
      ),
    );
  }
}
