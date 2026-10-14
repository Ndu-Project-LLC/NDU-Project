// ─────────────────────────────────────────────────────────────────────────────
// spell_fix_popup.dart
//
// The fix card that opens where the user clicked.
//
// Click (or long-press) a red/blue underlined word and a card appears anchored
// to that word offering, in order of usefulness:
//
//   • Auto-correct to "…"   — one click, the ranked best fix
//   • the ranked corrections, each one click
//   • Add to dictionary     — the word is accepted from now on, everywhere
//   • Ignore                — dismissed without teaching the dictionary
//   • Change all (n)        — fixes every occurrence in the field
//   • Review all issues…    — the field-wide spelling & grammar pane
//
// Every change is undoable: the card posts a snack bar with an Undo action that
// puts the exact previous value (text and caret) back.
//
// Nothing here edits text the user did not pick, and closing the card without
// choosing anything changes nothing.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart'
    show HardwareKeyboard, KeyDownEvent, KeyEvent, LogicalKeyboardKey;

import 'package:ndu_project/services/spell_check/spell_check_service.dart';
import 'package:ndu_project/widgets/spell_check/spell_check_dialogs.dart';
import 'package:ndu_project/widgets/spell_check/spell_checking_text_controller.dart';

/// Keys the card exposes so tests (and, later, keyboard shortcuts) can reach
/// individual actions without depending on their label text.
const Key spellFixPopupKey = Key('spell-fix-popup');
const Key spellFixAutoCorrectKey = Key('spell-fix-auto-correct');
const Key spellFixAddToDictionaryKey = Key('spell-fix-add-to-dictionary');
const Key spellFixIgnoreKey = Key('spell-fix-ignore');
const Key spellFixChangeAllKey = Key('spell-fix-change-all');
const Key spellFixReviewKey = Key('spell-fix-review');

/// Key for the nth ranked suggestion row in the card.
Key spellFixSuggestionKey(int index) => Key('spell-fix-suggestion-$index');

/// True when [issue] has a fix that can be applied without asking the user to
/// choose — a deterministic grammar fix or a clear winning suggestion.
bool hasAutoCorrection(SpellIssue issue) =>
    issue.replacement != null || issue.suggestions.isNotEmpty;

/// The text a one-click fix writes for [issue], or null when there is none.
///
/// Grammar rules carry their single correct fix in `replacement` (which may be
/// the empty string, meaning "remove the flagged text"). Spelling relies on the
/// ranked [SpellIssue.suggestions], matched to the user's capitalisation so
/// "Lusaka" never becomes "lusaka".
String? autoCorrectionFor(SpellIssue issue) {
  final replacement = issue.replacement;
  if (replacement != null) return replacement;
  final suggestions = issue.suggestions;
  if (suggestions.isEmpty) return null;
  return matchCase(issue.word.trim(), suggestions.first);
}

/// Applies the one-click fix for [issue]; returns what was written, or null
/// when there was nothing to apply.
String? applyAutoCorrection(
  TextEditingController controller,
  SpellIssue issue,
) {
  final fix = autoCorrectionFor(issue);
  if (fix == null) return null;
  applySpellReplacement(controller, issue, fix);
  return fix;
}

/// How many times [word] appears in [controller]'s text (case-insensitively),
/// which is what "Change all" would rewrite.
int spellWordOccurrences(TextEditingController controller, String word) {
  final needle = word.trim();
  if (needle.isEmpty) return 0;
  return RegExp(RegExp.escape(needle), caseSensitive: false)
      .allMatches(controller.text)
      .length;
}

/// Opens the fix card for [issue], anchored to [anchorRect] (the word's global
/// bounds) or [anchorPoint] (the click that opened it).
///
/// Returns what was applied, or null when the user dismissed the card.
Future<String?> showSpellFixPopup(
  BuildContext context, {
  required TextEditingController controller,
  required SpellIssue issue,
  Rect? anchorRect,
  Offset? anchorPoint,
  ScaffoldMessengerState? messenger,
}) async {
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  final resolvedMessenger = messenger ?? ScaffoldMessenger.maybeOf(context);

  // Without an overlay (a bare widget tree, for instance) fall back to the
  // dialog so the user can still fix the word.
  if (overlay == null) {
    await showSpellCheckSuggestions(
      context,
      controller: controller,
      issue: issue,
    );
    return null;
  }

  final anchor = anchorRect ??
      Rect.fromLTWH(anchorPoint?.dx ?? 0, anchorPoint?.dy ?? 0, 1, 1);

  final completer = Completer<String?>();
  late OverlayEntry entry;
  // The card can be closed from several places at once (the action the user
  // picked, the controller changing under it, the barrier), so the first close
  // wins and an entry is only ever removed once.
  var closed = false;

  void close(String? result) {
    if (closed) return;
    closed = true;
    if (entry.mounted) entry.remove();
    if (!completer.isCompleted) completer.complete(result);
  }

  entry = OverlayEntry(
    builder: (overlayContext) => _SpellFixPopup(
      controller: controller,
      issue: issue,
      anchor: anchor,
      messenger: resolvedMessenger,
      onClose: close,
    ),
  );
  overlay.insert(entry);
  return completer.future;
}

// ── The card ─────────────────────────────────────────────────────────────────

class _SpellFixPopup extends StatefulWidget {
  const _SpellFixPopup({
    required this.controller,
    required this.issue,
    required this.anchor,
    required this.messenger,
    required this.onClose,
  });

  final TextEditingController controller;
  final SpellIssue issue;
  final Rect anchor;
  final ScaffoldMessengerState? messenger;
  final void Function(String? result) onClose;

  @override
  State<_SpellFixPopup> createState() => _SpellFixPopupState();
}

class _SpellFixPopupState extends State<_SpellFixPopup>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 140),
  )..forward();

  /// The text the card was opened against; a change to it closes the card.
  late String _lastText;

  /// Closes the card when the text moves under it, so a fix can never be
  /// applied to the wrong range.
  ///
  /// Only a *text* change closes it: the caret and the composing region move
  /// on their own (the tap that opened the card, a soft keyboard arriving) and
  /// neither of those invalidates the flagged range.
  void _handleControllerChanged() {
    final text = widget.controller.text;
    if (text == _lastText) return;
    _lastText = text;
    if (mounted) widget.onClose(null);
  }

  bool _handleKey(KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.escape) {
      widget.onClose(null);
      return true;
    }
    if (event is KeyDownEvent &&
        (event.logicalKey == LogicalKeyboardKey.enter ||
            event.logicalKey == LogicalKeyboardKey.numpadEnter) &&
        hasAutoCorrection(widget.issue)) {
      _autoCorrect();
      return true;
    }
    return false;
  }

  @override
  void initState() {
    super.initState();
    _lastText = widget.controller.text;
    HardwareKeyboard.instance.addHandler(_handleKey);
    widget.controller.addListener(_handleControllerChanged);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleKey);
    widget.controller.removeListener(_handleControllerChanged);
    _animation.dispose();
    super.dispose();
  }

  // ── Actions ───────────────────────────────────────────────────────────────

  void _afterChange(String message, TextEditingValue before) {
    refreshSpellSpans(widget.controller);
    widget.messenger?.showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 5),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () {
            widget.controller.value = before;
            refreshSpellSpans(widget.controller);
          },
        ),
      ),
    );
    widget.onClose(message);
  }

  void _autoCorrect() {
    final before = widget.controller.value;
    final applied = applyAutoCorrection(widget.controller, widget.issue);
    if (applied == null) return;
    _afterChange(
      applied.isEmpty
          ? 'Fixed "${widget.issue.word.trim()}".'
          : 'Corrected to "$applied".',
      before,
    );
  }

  void _useSuggestion(String suggestion) {
    final before = widget.controller.value;
    final applied = matchCase(widget.issue.word.trim(), suggestion);
    applySpellReplacement(widget.controller, widget.issue, applied);
    _afterChange('Corrected to "$applied".', before);
  }

  void _addToDictionary() {
    final word = widget.issue.word.trim();
    unawaited(SpellCheckService.instance.addToUserDictionary(word));
    refreshSpellSpans(widget.controller);
    widget.messenger?.showSnackBar(
      SnackBar(
        content: Text('"$word" added to your dictionary.'),
        duration: const Duration(seconds: 5),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () {
            unawaited(SpellCheckService.instance.resetWord(word));
            refreshSpellSpans(widget.controller);
          },
        ),
      ),
    );
    widget.onClose(word);
  }

  void _ignore() {
    final word = widget.issue.word.trim();
    unawaited(SpellCheckService.instance.ignoreWord(word));
    refreshSpellSpans(widget.controller);
    widget.onClose(word);
  }

  void _changeAll() {
    final before = widget.controller.value;
    final suggestion = widget.issue.replacement ?? widget.issue.suggestions.first;
    final changed = replaceAllSpelling(
      widget.controller,
      widget.issue.word.trim(),
      matchCase(widget.issue.word.trim(), suggestion),
    );
    if (changed == 0) return;
    _afterChange(
      'Changed $changed ${changed == 1 ? 'occurrence' : 'occurrences'}.',
      before,
    );
  }

  void _reviewAll(BuildContext context) {
    final controller = widget.controller;
    widget.onClose(null);
    showSpellCheckDialog(context, controller: controller);
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final issue = widget.issue;
    final isSpelling = issue.kind == SpellIssueKind.spelling;
    final accent = isSpelling ? kSpellErrorColor : kGrammarErrorColor;
    final word = issue.word.trim();
    final fix = autoCorrectionFor(issue);
    final occurrences = spellWordOccurrences(widget.controller, word);
    final allIssues = spellIssuesIn(widget.controller).length;

    final suggestions = <String>[
      for (final suggestion in issue.suggestions.take(5))
        if (matchCase(word, suggestion) != word) matchCase(word, suggestion),
    ];

    final card = Material(
      key: spellFixPopupKey,
      color: scheme.surface,
      elevation: 10,
      shadowColor: Colors.black.withValues(alpha: 0.3),
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 330),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              // Header: what was flagged and why.
              Container(
                color: accent.withValues(alpha: 0.10),
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Icon(
                      isSpelling ? Icons.spellcheck : Icons.rule,
                      size: 18,
                      color: accent,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            word.isEmpty ? issue.message : word,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: scheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            issue.message,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // The one-click fix, first because it is what most clicks want.
              if (fix != null)
                _FixRow(
                  key: spellFixAutoCorrectKey,
                  icon: Icons.auto_fix_high,
                  label: fix.isEmpty
                      ? 'Auto-correct — remove it'
                      : 'Auto-correct to "$fix"',
                  hint: 'Enter',
                  accent: accent,
                  emphasized: true,
                  onTap: _autoCorrect,
                ),

              for (var i = 0; i < suggestions.length; i++)
                _FixRow(
                  key: spellFixSuggestionKey(i),
                  icon: Icons.check,
                  label: suggestions[i],
                  onTap: () => _useSuggestion(suggestions[i]),
                ),

              if (fix == null && suggestions.isEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                  child: Text(
                    isSpelling
                        ? 'No suggestions — add it to your dictionary if it is '
                            'correct.'
                        : 'No automatic fix — edit the text to resolve this.',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ),

              const Divider(height: 1),

              // Learn it, dismiss it, or fix every occurrence.
              Padding(
                padding: const EdgeInsets.fromLTRB(6, 4, 6, 6),
                child: Wrap(
                  spacing: 2,
                  runSpacing: 2,
                  children: <Widget>[
                    if (isSpelling)
                      _FixAction(
                        key: spellFixAddToDictionaryKey,
                        icon: Icons.bookmark_add_outlined,
                        label: 'Add to dictionary',
                        tooltip: 'Accept "$word" everywhere in the app',
                        onTap: _addToDictionary,
                      ),
                    _FixAction(
                      key: spellFixIgnoreKey,
                      icon: Icons.visibility_off_outlined,
                      label: 'Ignore',
                      tooltip: 'Stop flagging "$word"',
                      onTap: _ignore,
                    ),
                    if ((issue.replacement != null ||
                            issue.suggestions.isNotEmpty) &&
                        occurrences > 1)
                      _FixAction(
                        key: spellFixChangeAllKey,
                        icon: Icons.done_all,
                        label: 'Change all ($occurrences)',
                        tooltip: 'Fix every occurrence in this field',
                        onTap: _changeAll,
                      ),
                    if (allIssues > 0)
                      _FixAction(
                        key: spellFixReviewKey,
                        icon: Icons.fact_check_outlined,
                        label: 'Review all ($allIssues)',
                        tooltip: 'Review spelling and grammar in this field',
                        onTap: () => _reviewAll(context),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    return Stack(
      children: <Widget>[
        // Tap anywhere else to dismiss without changing anything.
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => widget.onClose(null),
          ),
        ),
        Positioned.fill(
          child: CustomSingleChildLayout(
            delegate: _FixCardLayout(anchor: widget.anchor),
            child: FadeTransition(
              opacity: _animation,
              child: ScaleTransition(
                alignment: Alignment.topLeft,
                scale: Tween<double>(begin: 0.96, end: 1).animate(
                  CurvedAnimation(
                    parent: _animation,
                    curve: Curves.easeOutCubic,
                  ),
                ),
                child: card,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Places the card under the word, flipping above it (and shifting sideways)
/// when the screen edge is closer than the card.
class _FixCardLayout extends SingleChildLayoutDelegate {
  const _FixCardLayout({required this.anchor});

  final Rect anchor;

  static const double _gap = 8;
  static const double _margin = 8;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    final maxWidth = math.min(330.0, constraints.maxWidth - _margin * 2);
    return BoxConstraints(
      maxWidth: maxWidth,
      maxHeight: math.max(120, constraints.maxHeight - _margin * 2),
    );
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final maxLeft = size.width - childSize.width - _margin;
    final left = anchor.left.clamp(_margin, math.max(_margin, maxLeft)).toDouble();

    var top = anchor.bottom + _gap;
    if (top + childSize.height > size.height - _margin) {
      final above = anchor.top - _gap - childSize.height;
      top = above >= _margin ? above : size.height - childSize.height - _margin;
    }
    return Offset(
      left,
      top.clamp(_margin, math.max(_margin, size.height - childSize.height))
          .toDouble(),
    );
  }

  @override
  bool shouldRelayout(_FixCardLayout oldDelegate) => oldDelegate.anchor != anchor;
}

/// A row in the card: the one-click fix and each ranked suggestion.
class _FixRow extends StatelessWidget {
  const _FixRow({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.accent,
    this.hint,
    this.emphasized = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? accent;
  final String? hint;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final color = accent ?? scheme.onSurface;

    return InkWell(
      onTap: onTap,
      child: Container(
        color: emphasized ? accent!.withValues(alpha: 0.08) : null,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: <Widget>[
            Icon(icon, size: 16, color: emphasized ? color : scheme.onSurfaceVariant),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: emphasized ? color : scheme.onSurface,
                  fontWeight: emphasized ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
            if (hint != null)
              Text(
                hint!,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: color.withValues(alpha: 0.7),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// One of the low-emphasis actions along the bottom of the card.
class _FixAction extends StatelessWidget {
  const _FixAction({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    required this.tooltip,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: TextButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 15),
        label: Text(label, style: const TextStyle(fontSize: 12.5)),
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          minimumSize: const Size(0, 32),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ),
    );
  }
}
