import 'package:flutter/material.dart';
import 'package:ndu_project/utils/rich_text_editing_controller.dart';

/// Unified list bullet: bullet dot "•" per spec (prose fields must not use auto-bullet).
const String kListBullet = '\u2022 ';

/// Mixin that adds auto-bullet functionality for *list* fields.
/// Uses "• " (bullet + space). Do not use for prose (Notes, Scope, Value narrative).
///
/// An empty field always stays empty — bullets are only inserted once content
/// is typed, so cleared/empty fields never show a stray dot.
class AutoBulletTextController extends TextEditingController {
  AutoBulletTextController({super.text}) {
    _setupListener();
  }

  void _setupListener() {
    addListener(_handleTextChange);
  }

  void _handleTextChange() {
    final currentText = text;
    final selection = this.selection;
    const bullet = kListBullet;

    // Keep empty fields empty — never force a bullet dot into a cleared or
    // untouched field. Bullets appear only when content is actually typed.
    if (currentText.isEmpty) return;

    final textBeforeCursor = currentText.substring(0, selection.baseOffset);
    final lastNewlineIndex = textBeforeCursor.lastIndexOf('\n');

    if (lastNewlineIndex != -1) {
      final afterNewline = textBeforeCursor.substring(lastNewlineIndex + 1);
      if (afterNewline.trim().isEmpty && !afterNewline.startsWith(bullet)) {
        final newText = currentText.substring(0, lastNewlineIndex + 1) +
            bullet +
            currentText.substring(selection.baseOffset);
        value = TextEditingValue(
          text: newText,
          selection: TextSelection.collapsed(
              offset: selection.baseOffset + bullet.length),
        );
        return;
      }
    }

    if (currentText.isNotEmpty &&
        !currentText.startsWith(bullet) &&
        !currentText.contains('\n')) {
      value = TextEditingValue(
        text: '$bullet$currentText',
        selection: TextSelection.collapsed(
            offset: selection.baseOffset + bullet.length),
      );
    }
  }

  @override
  void dispose() {
    removeListener(_handleTextChange);
    super.dispose();
  }
}

class RichAutoBulletTextController extends AutoBulletTextController {
  RichAutoBulletTextController({super.text});

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    return buildInlineFormattedTextSpan(
      text: text,
      baseStyle: style ?? DefaultTextStyle.of(context).style,
    );
  }
}

/// Extension for *list* fields only. Prose (Notes, Scope, Value narrative) must not use this.
///
/// An empty field always stays empty — bullets are only inserted once content
/// is typed, so cleared/empty fields never show a stray dot.
extension AutoBulletExtension on TextEditingController {
  void enableAutoBullet() {
    addListener(_autoBulletListener);
  }

  void disableAutoBullet() {
    removeListener(_autoBulletListener);
  }

  void _autoBulletListener() {
    final currentText = text;
    final selection = this.selection;
    const bullet = kListBullet;

    // Keep empty fields empty — never force a bullet dot into a cleared or
    // untouched field. Bullets appear only when content is actually typed.
    if (currentText.isEmpty) return;

    final textBeforeCursor = currentText.substring(0, selection.baseOffset);
    final lastNewlineIndex = textBeforeCursor.lastIndexOf('\n');

    if (lastNewlineIndex != -1) {
      final afterNewline = textBeforeCursor.substring(lastNewlineIndex + 1);
      if (afterNewline.trim().isEmpty && !afterNewline.startsWith(bullet)) {
        final newText = currentText.substring(0, lastNewlineIndex + 1) +
            bullet +
            currentText.substring(selection.baseOffset);
        value = TextEditingValue(
          text: newText,
          selection: TextSelection.collapsed(
              offset: selection.baseOffset + bullet.length),
        );
        return;
      }
    }

    if (currentText.isNotEmpty &&
        !currentText.contains('\n') &&
        !currentText.startsWith(bullet)) {
      value = TextEditingValue(
        text: '$bullet$currentText',
        selection: TextSelection.collapsed(
            offset: selection.baseOffset + bullet.length),
      );
    }
  }
}
