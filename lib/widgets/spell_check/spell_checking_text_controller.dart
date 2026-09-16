// ─────────────────────────────────────────────────────────────────────────────
// spell_checking_text_controller.dart
//
// A drop-in replacement for [TextEditingController] that renders Microsoft-Word
// style wavy underlines under misspellings and grammar slips, and offers the
// fixes on demand.
//
// Any field whose controller is (or extends) this class gets the underlines:
// the controller is the only place in Flutter where you can supply the
// [TextSpan]s a [TextField] paints, so a controller is the natural hook.
//
// Nothing is ever corrected silently:
//   • Red wavy underline  — spelling
//   • Blue wavy underline — grammar
//   • Right-click (desktop/web) or long-press (touch) the word and pick
//     "Spelling suggestions…" from the selection toolbar — Word's behaviour.
//   • The "Spelling & grammar" entry in the field's Open Editor popup reviews
//     the whole field at once.
//
// Note: the underlines are pure [TextSpan] decoration. Recognisers on spans
// inside an *editable* field are not supported by Flutter (RenderEditable
// asserts on them for every platform except macOS), which is why the fixes are
// offered through the selection toolbar and the review dialog instead.
//
// The fix helpers at the bottom of this file take a plain
// [TextEditingController], so the review works on every field in the app —
// including ones still holding a plain controller.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';

import 'package:flutter/material.dart';

import 'package:ndu_project/services/spell_check/spell_check_service.dart';

/// Wavy underline colours, following the convention Word uses.
const Color kSpellErrorColor = Color(0xFFE53935);
const Color kGrammarErrorColor = Color(0xFF2563EB);

/// A [TextEditingController] that underlines misspellings and grammar slips as
/// the user types, and lets them fix them on demand.
class SpellCheckTextEditingController extends TextEditingController {
  SpellCheckTextEditingController({super.text, this.spellCheckEnabled = true});

  /// Mirrors [TextEditingController.fromValue] so call sites that build a value
  /// first keep working unchanged.
  ///
  /// The super constructor is a factory, so the value is copied in rather than
  /// forwarded.
  SpellCheckTextEditingController.fromValue(
    TextEditingValue? value, {
    this.spellCheckEnabled = true,
  }) : super(text: value?.text ?? '') {
    if (value != null) {
      this.value = value;
    }
  }

  /// Turned off for obfuscated fields (passwords) and anywhere underlines would
  /// be noise.
  bool spellCheckEnabled;

  String? _cachedKey;
  TextSpan? _cachedSpan;
  bool _disposed = false;

  /// Redraws the underlines after the dictionary or the ignored words changed.
  void refresh() {
    if (_disposed) return;
    _cachedKey = null;
    _cachedSpan = null;
    notifyListeners();
  }

  /// The spans the field paints before spell decorations are applied.
  ///
  /// Overridable so controllers with their own rendering (for example
  /// `RichTextEditingController`'s inline markdown) keep it while still getting
  /// the underlines and their fixes.
  @protected
  TextSpan buildSourceSpan(
    BuildContext context,
    TextStyle? style,
    bool withComposing,
  ) =>
      super.buildTextSpan(
        context: context,
        style: style,
        withComposing: withComposing,
      );

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final base = buildSourceSpan(context, style, withComposing);
    final service = SpellCheckService.instance;
    if (!spellCheckEnabled) return base;

    if (!service.isReady) {
      // The first field to render kicks off the dictionary load; every
      // controller that asked for a span redraws when it lands.
      unawaited(service.ensureLoaded().then((_) {
        if (_disposed) return;
        notifyListeners();
      }));
      return base;
    }

    final key = '${text.hashCode}|${style?.hashCode}|$withComposing|'
        '${service.revision}|$spellCheckEnabled';
    if (_cachedKey == key && _cachedSpan != null) return _cachedSpan!;

    final decorated = decorateWithSpellCheck(base, text);
    _cachedKey = key;
    _cachedSpan = decorated;
    return decorated;
  }

  @override
  void dispose() {
    _disposed = true;
    _cachedSpan = null;
    super.dispose();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Span decoration
// ─────────────────────────────────────────────────────────────────────────────

/// Walks the span tree [base] and underlines every word the checker flagged in
/// [text].
///
/// Offsets are tracked while walking, which is correct for nested spans as long
/// as each leaf's text length matches the source text. That holds for the plain
/// controller and for `RichTextEditingController`, which swaps formatting
/// markers for same-length zero-width characters.
TextSpan decorateWithSpellCheck(TextSpan base, String text) {
  final flagged = SpellCheckService.instance.check(text);
  if (flagged.isEmpty) return base;

  var offset = 0;
  final output = <InlineSpan>[];

  List<InlineSpan> decorateLeaf(TextSpan leaf, int start) {
    final leafText = leaf.text ?? '';
    if (leafText.isEmpty) return <InlineSpan>[leaf];
    final relevant = flagged
        .where((issue) =>
            issue.start >= start && issue.end <= start + leafText.length)
        .toList();
    if (relevant.isEmpty) return <InlineSpan>[leaf];

    final spans = <InlineSpan>[];
    var cursor = 0;
    for (final issue in relevant) {
      final localStart = issue.start - start;
      final localEnd = issue.end - start;
      if (localStart < cursor) continue;
      if (localStart > cursor) {
        spans.add(TextSpan(
          text: leafText.substring(cursor, localStart),
          style: leaf.style,
        ));
      }
      spans.add(TextSpan(
        text: leafText.substring(localStart, localEnd),
        style: _underlineStyle(
          leaf.style,
          issue.kind == SpellIssueKind.spelling
              ? kSpellErrorColor
              : kGrammarErrorColor,
        ),
      ));
      cursor = localEnd;
    }
    if (cursor < leafText.length) {
      spans.add(TextSpan(text: leafText.substring(cursor), style: leaf.style));
    }
    return spans;
  }

  void walk(InlineSpan span) {
    if (span is! TextSpan) {
      output.add(span);
      return;
    }
    final leafText = span.text;
    if (leafText != null && leafText.isNotEmpty) {
      final start = offset;
      offset += leafText.length;
      output.addAll(decorateLeaf(span, start));
      return;
    }
    final nested = span.children;
    if (nested == null) {
      output.add(span);
      return;
    }
    final nestedOut = <InlineSpan>[];
    for (final child in nested) {
      if (child is TextSpan) {
        final childStart = offset;
        offset += spanTextLength(child);
        final rendered = decorateLeaf(child, childStart);
        if (rendered.length == 1) {
          nestedOut.add(rendered.first);
        } else {
          nestedOut.add(TextSpan(style: child.style, children: rendered));
        }
      } else {
        nestedOut.add(child);
      }
    }
    output.add(TextSpan(
      style: span.style,
      recognizer: span.recognizer,
      children: nestedOut,
    ));
  }

  final source = base.children ?? <InlineSpan>[TextSpan(text: base.text)];
  for (final span in source) {
    walk(span);
  }
  return TextSpan(style: base.style, children: output);
}

/// Total rendered length of [span], used to keep offsets aligned while walking.
int spanTextLength(TextSpan span) {
  var total = span.text?.length ?? 0;
  final children = span.children;
  if (children == null) return total;
  for (final child in children) {
    if (child is TextSpan) total += spanTextLength(child);
  }
  return total;
}

TextStyle _underlineStyle(TextStyle? base, Color color) {
  final style = base ?? const TextStyle();
  final existing = style.decoration;
  return style.copyWith(
    decoration: existing == null
        ? TextDecoration.underline
        : TextDecoration.combine(<TextDecoration>[
            existing,
            TextDecoration.underline,
          ]),
    decorationStyle: TextDecorationStyle.wavy,
    decorationColor: color,
    decorationThickness: 1.5,
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Fix helpers — these work on any TextEditingController
// ─────────────────────────────────────────────────────────────────────────────

/// Everything the checker flags in [controller]'s current text.
List<SpellIssue> spellIssuesIn(TextEditingController controller) =>
    SpellCheckService.instance.check(controller.text);

/// The issue covering [offset] in [controller]'s text, if any.
SpellIssue? spellIssueAt(TextEditingController controller, int offset) {
  for (final issue in spellIssuesIn(controller)) {
    if (offset >= issue.start && offset <= issue.end) return issue;
  }
  return null;
}

/// The issue covering [controller]'s caret, if any.
SpellIssue? spellIssueAtCaret(TextEditingController controller) {
  final selection = controller.selection;
  if (!selection.isValid || selection.baseOffset < 0) return null;
  return spellIssueAt(controller, selection.baseOffset);
}

/// Replaces [issue] with [replacement], keeping the caret in a sensible place.
void applySpellReplacement(
  TextEditingController controller,
  SpellIssue issue,
  String replacement,
) {
  final text = controller.text;
  if (issue.start < 0 || issue.end > text.length) return;
  final previousSelection = controller.selection;
  final next = text.replaceRange(issue.start, issue.end, replacement);
  final delta = replacement.length - (issue.end - issue.start);
  var base = previousSelection.isValid ? previousSelection.baseOffset : -1;
  var extent = previousSelection.isValid ? previousSelection.extentOffset : -1;
  if (base >= issue.end) base += delta;
  if (extent >= issue.end) extent += delta;
  controller.value = TextEditingValue(
    text: next,
    selection: base >= 0 && extent >= 0
        ? TextSelection(baseOffset: base, extentOffset: extent)
        : TextSelection.collapsed(offset: next.length),
  );
}

/// Applies [issue]'s deterministic grammar fix, if it has one.
bool applySpellGrammarFix(TextEditingController controller, SpellIssue issue) {
  final replacement = issue.replacement;
  if (replacement == null) return false;
  applySpellReplacement(controller, issue, replacement);
  return true;
}

/// Replaces every occurrence of [word] (case-insensitively) with
/// [replacement], returning how many were changed. "Change all", Word-style.
int replaceAllSpelling(
  TextEditingController controller,
  String word,
  String replacement,
) {
  if (word.isEmpty) return 0;
  final text = controller.text;
  final pattern = RegExp(RegExp.escape(word), caseSensitive: false);
  final matches = pattern.allMatches(text).toList();
  if (matches.isEmpty) return 0;

  final buffer = StringBuffer();
  var last = 0;
  for (final match in matches) {
    buffer
      ..write(text.substring(last, match.start))
      ..write(matchCase(match.group(0)!, replacement));
    last = match.end;
  }
  buffer.write(text.substring(last));
  final next = buffer.toString();
  controller.value = TextEditingValue(
    text: next,
    selection: TextSelection.collapsed(offset: next.length),
  );
  return matches.length;
}

/// Redraws the underlines on [controller] when it is spell-aware.
void refreshSpellSpans(TextEditingController controller) {
  if (controller is SpellCheckTextEditingController) {
    controller.refresh();
  }
}

/// Keeps the capitalisation the user typed: "Recieve" becomes "Receive".
String matchCase(String typed, String replacement) {
  if (typed.isEmpty || replacement.isEmpty) return replacement;
  if (typed == typed.toUpperCase() && typed.length > 1) {
    return replacement.toUpperCase();
  }
  if (typed[0] == typed[0].toUpperCase()) {
    return replacement[0].toUpperCase() + replacement.substring(1);
  }
  return replacement;
}
