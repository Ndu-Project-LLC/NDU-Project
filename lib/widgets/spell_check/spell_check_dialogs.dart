// ─────────────────────────────────────────────────────────────────────────────
// spell_check_dialogs.dart
//
// The two ways a user fixes what the spell checker flags:
//
//   showSpellCheckSuggestions — the popup for a single word. Opened by
//     long-pressing an underlined word, it offers the ranked corrections plus
//     "Change all", "Ignore" and "Add to dictionary".
//
//   showSpellCheckDialog — the field-wide review, opened from the "Spell check"
//     entry in the field's Open Editor popup. Lists every issue with its
//     suggestions, like Word's Spelling pane.
//
// Both write through [SpellCheckTextEditingController] so the caret and the
// user's own text stay intact, and neither ever changes text the user did not
// pick.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

import 'package:ndu_project/services/spell_check/spell_check_service.dart';
import 'package:ndu_project/widgets/spell_check/spell_checking_text_controller.dart';
import 'package:ndu_project/widgets/spell_check/spell_fix_popup.dart';

/// Popup for one flagged word: pick a correction, ignore it, or add it to the
/// dictionary.
Future<void> showSpellCheckSuggestions(
  BuildContext context, {
  required TextEditingController controller,
  required SpellIssue issue,
}) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => _SuggestionsDialog(
      controller: controller,
      initialIssue: issue,
    ),
  );
}

/// The selection-toolbar builder that puts the corrections one gesture away.
///
/// Right-click a flagged word on desktop/web, or long-press it on touch, and
/// the toolbar offers `Spelling suggestions…` for that word — the same gesture
/// Word uses. Everything the platform would normally show stays in place; this
/// only prepends the spelling entry when the caret sits on a flagged word.
Widget buildSpellCheckContextMenu(
  BuildContext context,
  EditableTextState editableTextState,
  TextEditingController controller,
) {
  final buttons = <ContextMenuButtonItem>[
    ...editableTextState.contextMenuButtonItems,
  ];

  final spellCheckEnabled = controller is SpellCheckTextEditingController
      ? controller.spellCheckEnabled
      : true;
  // A read-only field cannot accept a correction, so it gets no spelling
  // entries at all.
  final readOnly = editableTextState.widget.readOnly;
  if (spellCheckEnabled && !readOnly) {
    var insertAt = 0;

    // Suggestions for the flagged word under the caret, when there is one.
    final selection = editableTextState.textEditingValue.selection;
    final issue = spellIssueAt(controller, selection.start) ??
        spellIssueAt(controller, selection.end);
    if (issue != null) {
      // The fix itself, so a right-click is already a correction when the
      // checker is confident about one — the same one click the fix card offers.
      final autoCorrection = autoCorrectionFor(issue);
      if (autoCorrection != null) {
        buttons.insert(
          insertAt++,
          ContextMenuButtonItem(
            label: autoCorrection.isEmpty
                ? 'Auto-correct: remove "${issue.word.trim()}"'
                : 'Auto-correct to "$autoCorrection"',
            onPressed: () {
              ContextMenuController.removeAny();
              final before = controller.value;
              applyAutoCorrection(controller, issue);
              refreshSpellSpans(controller);
              _offerUndo(context, controller, before, autoCorrection);
            },
          ),
        );
      }

      buttons.insert(
        insertAt++,
        ContextMenuButtonItem(
          label: 'Spelling: "${issue.word}"…',
          onPressed: () {
            ContextMenuController.removeAny();
            showSpellCheckSuggestions(
              context,
              controller: controller,
              issue: issue,
            );
          },
        ),
      );

      if (issue.kind == SpellIssueKind.spelling) {
        buttons.insert(
          insertAt++,
          ContextMenuButtonItem(
            label: 'Add "${issue.word.trim()}" to dictionary',
            onPressed: () {
              ContextMenuController.removeAny();
              final word = issue.word.trim();
              SpellCheckService.instance.addToUserDictionary(word);
              refreshSpellSpans(controller);
              ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                SnackBar(
                  content: Text('"$word" added to your dictionary.'),
                  duration: const Duration(seconds: 4),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),
        );
      }
    }

    // The field-wide review (Word's Review ▸ Spelling & Grammar). Always
    // present, so even a field with no editor-action popup — a plain notes or
    // plan area, for instance — still has a way to see every correction and
    // apply them across the whole text.
    buttons.insert(
      insertAt,
      ContextMenuButtonItem(
        label: 'Spelling & grammar…',
        onPressed: () {
          ContextMenuController.removeAny();
          showSpellCheckDialog(context, controller: controller);
        },
      ),
    );
  }

  return AdaptiveTextSelectionToolbar.buttonItems(
    anchors: editableTextState.contextMenuAnchors,
    buttonItems: buttons,
  );
}

/// Puts the text back the way it was, so a one-click fix is one click to undo.
void _offerUndo(
  BuildContext context,
  TextEditingController controller,
  TextEditingValue before,
  String applied,
) {
  ScaffoldMessenger.maybeOf(context)?.showSnackBar(
    SnackBar(
      content: Text(
        applied.isEmpty ? 'Correction removed.' : 'Corrected to "$applied".',
      ),
      duration: const Duration(seconds: 5),
      behavior: SnackBarBehavior.floating,
      action: SnackBarAction(
        label: 'Undo',
        onPressed: () {
          controller.value = before;
          refreshSpellSpans(controller);
        },
      ),
    ),
  );
}

/// Field-wide review of everything the checker flagged.
Future<void> showSpellCheckDialog(
  BuildContext context, {
  required TextEditingController controller,
}) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => _SpellCheckDialog(controller: controller),
  );
}

// ── Single word ──────────────────────────────────────────────────────────────

class _SuggestionsDialog extends StatelessWidget {
  const _SuggestionsDialog({
    required this.controller,
    required this.initialIssue,
  });

  final TextEditingController controller;
  final SpellIssue initialIssue;

  /// The issue re-read from the current text, so a correction made elsewhere is
  /// reflected here.
  SpellIssue get issue => _resolveIssue(controller, initialIssue);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: <Widget>[
          Icon(
            issue.kind == SpellIssueKind.spelling
                ? Icons.spellcheck
                : Icons.rule,
            size: 20,
            color: issue.kind == SpellIssueKind.spelling
                ? kSpellErrorColor
                : kGrammarErrorColor,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              issue.word.trim().isEmpty
                  ? issue.message
                  : '"${issue.word}" — ${issue.message}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 380,
        child: SingleChildScrollView(
          child: _IssueActions(
            controller: controller,
            issue: issue,
            onApplied: () => Navigator.of(context).maybePop(),
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).maybePop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

/// Re-reads [issue] from the controller so it always points at live text.
SpellIssue _resolveIssue(TextEditingController controller, SpellIssue issue) {
  for (final current in spellIssuesIn(controller)) {
    if (current.start == issue.start && current.word == issue.word) {
      return current;
    }
  }
  return issue;
}

// ── Whole field ──────────────────────────────────────────────────────────────

class _SpellCheckDialog extends StatefulWidget {
  const _SpellCheckDialog({required this.controller});

  final TextEditingController controller;

  @override
  State<_SpellCheckDialog> createState() => _SpellCheckDialogState();
}

class _SpellCheckDialogState extends State<_SpellCheckDialog> {
  late List<SpellIssue> _issues = spellIssuesIn(widget.controller);

  void _refresh() {
    if (!mounted) return;
    setState(() => _issues = spellIssuesIn(widget.controller));
  }

  @override
  Widget build(BuildContext context) {
    final spellings =
        _issues.where((issue) => issue.kind == SpellIssueKind.spelling).length;
    final grammar = _issues.length - spellings;

    return AlertDialog(
      title: Row(
        children: <Widget>[
          const Icon(Icons.spellcheck, size: 20, color: kSpellErrorColor),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Spelling and Grammar',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
          ),
          IconButton(
            tooltip: 'Re-check',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh, size: 18),
          ),
        ],
      ),
      content: SizedBox(
        width: 560,
        height: 420,
        child: _issues.isEmpty
            ? const _NoIssues()
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    _summary(spellings, grammar),
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ListView.separated(
                      itemCount: _issues.length,
                      separatorBuilder: (_, __) =>
                          const Divider(height: 20, color: Color(0xFFE5E7EB)),
                      itemBuilder: (context, index) {
                        final issue = _issues[index];
                        return _IssueTile(
                          controller: widget.controller,
                          issue: issue,
                          index: index,
                          onApplied: _refresh,
                        );
                      },
                    ),
                  ),
                ],
              ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).maybePop(),
          child: const Text('Done'),
        ),
      ],
    );
  }

  static String _summary(int spellings, int grammar) {
    final parts = <String>[
      if (spellings > 0) '$spellings spelling ${spellings == 1 ? 'issue' : 'issues'}',
      if (grammar > 0) '$grammar grammar ${grammar == 1 ? 'issue' : 'issues'}',
    ];
    if (parts.isEmpty) return 'Nothing to fix.';
    return parts.join(' · ');
  }
}

class _NoIssues extends StatelessWidget {
  const _NoIssues();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(Icons.check_circle_outline, size: 40, color: Color(0xFF10B981)),
          SizedBox(height: 12),
          Text(
            'No spelling or grammar issues found.',
            style: TextStyle(fontSize: 13.5, color: Color(0xFF4B5563)),
          ),
        ],
      ),
    );
  }
}

class _IssueTile extends StatelessWidget {
  const _IssueTile({
    required this.controller,
    required this.issue,
    required this.index,
    required this.onApplied,
  });

  final TextEditingController controller;
  final SpellIssue issue;
  final int index;
  final VoidCallback onApplied;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Text(
              '${index + 1}.',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF9CA3AF),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                issue.word.trim().isEmpty ? issue.message : issue.word,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: issue.kind == SpellIssueKind.spelling
                      ? kSpellErrorColor
                      : kGrammarErrorColor,
                ),
              ),
            ),
            Text(
              issue.message,
              style: const TextStyle(fontSize: 11.5, color: Color(0xFF6B7280)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _IssueActions(
          controller: controller,
          issue: issue,
          onApplied: onApplied,
        ),
      ],
    );
  }
}

/// The correction / ignore / learn controls shared by both dialogs.
class _IssueActions extends StatelessWidget {
  const _IssueActions({
    required this.controller,
    required this.issue,
    required this.onApplied,
  });

  final TextEditingController controller;
  final SpellIssue issue;
  final VoidCallback onApplied;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            if (issue.replacement != null)
              _CorrectionChip(
                label: issue.replacement!.isEmpty
                    ? issue.message
                    : issue.replacement!,
                primary: true,
                onTap: () {
                  applySpellGrammarFix(controller, issue);
                  onApplied();
                },
              ),
            for (final suggestion in issue.suggestions)
              _CorrectionChip(
                label: suggestion,
                onTap: () {
                  // Case-matched, so "Lusaka" never becomes "lusaka".
                  applySpellSuggestion(controller, issue, suggestion);
                  onApplied();
                },
              ),
            if (issue.replacement == null && issue.suggestions.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 6),
                child: Text(
                  'No suggestions — add it to the dictionary if it is correct.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 4,
          children: <Widget>[
            if (issue.suggestions.isNotEmpty)
              TextButton(
                onPressed: () {
                  final changed = replaceAllSpelling(
                    controller,
                    issue.word.trim(),
                    issue.suggestions.first,
                  );
                  if (changed > 0) {
                    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                      SnackBar(
                        content: Text(
                          'Changed $changed '
                          '${changed == 1 ? 'occurrence' : 'occurrences'} to '
                          '"${issue.suggestions.first}".',
                        ),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  }
                  onApplied();
                },
                child: const Text('Change all', style: TextStyle(fontSize: 12.5)),
              ),
            TextButton(
              onPressed: () async {
                await SpellCheckService.instance.ignoreWord(issue.word);
                refreshSpellSpans(controller);
                onApplied();
              },
              child: const Text('Ignore', style: TextStyle(fontSize: 12.5)),
            ),
            TextButton(
              onPressed: () async {
                await SpellCheckService.instance.addToUserDictionary(issue.word);
                refreshSpellSpans(controller);
                onApplied();
              },
              child: const Text('Add to dictionary',
                  style: TextStyle(fontSize: 12.5)),
            ),
          ],
        ),
      ],
    );
  }
}

class _CorrectionChip extends StatelessWidget {
  const _CorrectionChip({
    required this.label,
    required this.onTap,
    this.primary = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: primary ? const Color(0xFFFFF3CD) : const Color(0xFFF3F4F6),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: primary ? FontWeight.w700 : FontWeight.w500,
              color: const Color(0xFF111827),
            ),
          ),
        ),
      ),
    );
  }
}
