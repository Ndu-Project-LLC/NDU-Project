// ─────────────────────────────────────────────────────────────────────────────
// spell_fix_tap_area.dart
//
// Makes an underlined word clickable.
//
// Flutter does not allow tap recognisers on spans inside an *editable* field
// (RenderEditable asserts on them on every platform but macOS), so the click is
// caught the other way round: this widget wraps the field, listens to raw
// pointer events, works out which character was clicked through the field's own
// [RenderEditable], and — when that character is part of a flagged word — opens
// the fix card anchored to it.
//
// A [Listener] is used rather than a [GestureDetector] on purpose: a Listener
// never enters the gesture arena, so it cannot steal the tap that places the
// caret, drags a selection, or scrolls the field. A click that the field itself
// consumed (a drag, a long press, a slow press) is ignored here.
//
// The text field keeps behaving exactly as before; this only *adds* the card
// when the click lands on a word the checker flagged.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'package:ndu_project/services/spell_check/spell_check_service.dart';
import 'package:ndu_project/widgets/spell_check/spell_checking_text_controller.dart';
import 'package:ndu_project/widgets/spell_check/spell_fix_popup.dart';

/// Longest press that still counts as a click. A longer press is a long-press,
/// which belongs to the platform's selection toolbar.
const Duration kSpellFixClickTimeout = Duration(milliseconds: 400);

/// Wraps [child] (a text field) so a click on an underlined word offers its
/// fix. Set [enabled] to false for read-only or obscured fields.
class SpellFixTapArea extends StatefulWidget {
  const SpellFixTapArea({
    super.key,
    required this.controller,
    required this.child,
    this.enabled = true,
    this.showFixCard,
  });

  final TextEditingController controller;
  final Widget child;
  final bool enabled;

  /// Test seam: lets a test observe/override how the card is opened.
  final Future<void> Function(BuildContext context, SpellIssue issue, Rect rect)?
      showFixCard;

  @override
  State<SpellFixTapArea> createState() => _SpellFixTapAreaState();
}

class _SpellFixTapAreaState extends State<SpellFixTapArea> {
  Offset? _downPosition;
  Duration? _downTimestamp;

  bool get _enabled {
    if (!widget.enabled) return false;
    final controller = widget.controller;
    return controller is SpellCheckTextEditingController &&
        controller.spellCheckEnabled &&
        SpellCheckService.instance.isReady;
  }

  void _onPointerDown(PointerDownEvent event) {
    if (!_enabled || event.buttons != kPrimaryButton) {
      _downPosition = null;
      return;
    }
    _downPosition = event.position;
    _downTimestamp = event.timeStamp;
  }

  void _onPointerCancel(PointerCancelEvent event) {
    _downPosition = null;
    _downTimestamp = null;
  }

  void _onPointerUp(PointerUpEvent event) {
    final down = _downPosition;
    final downAt = _downTimestamp;
    _downPosition = null;
    _downTimestamp = null;

    if (!_enabled || down == null || downAt == null) return;
    if (event.buttons != 0) return; // still dragging: not a click
    if ((event.position - down).distance > kTouchSlop) return;
    if (event.timeStamp - downAt > kSpellFixClickTimeout) return;

    _openFixCardFor(event.position);
  }

  void _openFixCardFor(Offset globalPosition) {
    final editable = _findRenderEditable(context.findRenderObject());
    if (editable == null) return;
    if (!editable.hasSize || editable.size.isEmpty) return;

    final origin = editable.localToGlobal(Offset.zero);
    if (!(origin & editable.size).contains(globalPosition)) return;

    final controller = widget.controller;
    final text = controller.text;
    if (text.isEmpty) return;

    final position = editable.getPositionForPoint(globalPosition);
    if (position.offset < 0) return;

    final issue = _issueAt(controller, editable, position, globalPosition);
    if (issue == null) return;

    final rect = _globalBoundsOf(editable, issue.start, issue.end, globalPosition);
    final showFixCard = widget.showFixCard;
    if (showFixCard != null) {
      showFixCard(context, issue, rect);
      return;
    }
    showSpellFixPopup(
      context,
      controller: controller,
      issue: issue,
      anchorRect: rect,
      anchorPoint: globalPosition,
      messenger: ScaffoldMessenger.maybeOf(context),
    );
  }

  /// The flagged range under [globalPosition]: the character clicked if it sits
  /// inside an issue (which also covers flagged whitespace, like a double
  /// space), otherwise the word the click landed in.
  SpellIssue? _issueAt(
    TextEditingController controller,
    RenderEditable editable,
    TextPosition position,
    Offset globalPosition,
  ) {
    final issues = spellIssuesIn(controller);
    if (issues.isEmpty) return null;

    for (final issue in issues) {
      if (position.offset >= issue.start && position.offset <= issue.end) {
        return issue;
      }
    }

    final word = editable.getWordBoundary(position);
    if (word.isValid && word.start != word.end) {
      for (final issue in issues) {
        if (issue.start < word.end && issue.end > word.start) return issue;
      }
    }
    return null;
  }

  /// Global bounds of characters [start]..[end], falling back to the click
  /// point when the field has no visible glyphs there (an empty line).
  Rect _globalBoundsOf(
    RenderEditable editable,
    int start,
    int end,
    Offset fallback,
  ) {
    final origin = editable.localToGlobal(Offset.zero);
    final startRect =
        editable.getLocalRectForCaret(TextPosition(offset: start));
    final endRect = editable.getLocalRectForCaret(TextPosition(offset: end));
    final sameLine = (startRect.top - endRect.top).abs() < 0.5;
    final local = sameLine
        ? Rect.fromLTRB(
            startRect.left,
            startRect.top,
            math.max(endRect.right, startRect.right),
            startRect.bottom,
          )
        : startRect;
    if (local.isEmpty) return Rect.fromLTWH(fallback.dx, fallback.dy, 1, 1);
    return local.shift(origin);
  }

  @override
  Widget build(BuildContext context) {
    if (!_enabled) return widget.child;
    return Listener(
      onPointerDown: _onPointerDown,
      onPointerUp: _onPointerUp,
      onPointerCancel: _onPointerCancel,
      child: widget.child,
    );
  }
}

/// First [RenderEditable] in [root]'s subtree — the field's text layer.
RenderEditable? _findRenderEditable(RenderObject? root) {
  if (root == null) return null;
  if (root is RenderEditable) return root;
  RenderEditable? found;
  root.visitChildren((child) {
    found ??= _findRenderEditable(child);
  });
  return found;
}
