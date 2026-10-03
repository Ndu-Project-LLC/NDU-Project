import 'package:flutter/material.dart';

/// A collapsible "Notes" section used across the application.
///
/// The section starts **collapsed** so a notes editor never occupies page
/// space until the user explicitly opens it. The header row (icon + title +
/// chevron) is always visible and toggles the content on tap.
///
/// Drop it around any existing notes widget to collapse it:
///
/// ```dart
/// CollapsibleNotesSection(
///   title: 'Notes',
///   child: _roundedField(controller: _notesController, hint: '...'),
/// )
/// ```
class CollapsibleNotesSection extends StatefulWidget {
  const CollapsibleNotesSection({
    super.key,
    required this.child,
    this.title = 'Notes',
    this.titleWidget,
    this.icon = Icons.sticky_note_2_outlined,
    this.trailing,
    this.initiallyExpanded = false,
    this.card = false,
    this.headerPadding,
    this.iconColor = const Color(0xFFD97706),
    this.titleStyle,
  });

  /// The notes editor revealed when the section is opened.
  final Widget child;

  /// Header label. Defaults to 'Notes'.
  final String title;

  /// Replaces the default [title] text — used where the heading is an
  /// admin-editable widget (e.g. `EditableContentText`).
  final Widget? titleWidget;

  /// Leading glyph. Pass null to omit the icon container.
  final IconData? icon;

  /// Optional widget shown before the chevron in the header (e.g. a saved
  /// status chip or an AI action).
  final Widget? trailing;

  /// Whether the section starts open. Defaults to false — notes are closed
  /// until the user opens them.
  final bool initiallyExpanded;

  /// Wrap the header and content in the standard white card chrome.
  final bool card;

  final EdgeInsets? headerPadding;
  final Color iconColor;
  final TextStyle? titleStyle;

  @override
  State<CollapsibleNotesSection> createState() =>
      _CollapsibleNotesSectionState();
}

class _CollapsibleNotesSectionState extends State<CollapsibleNotesSection> {
  late bool _isExpanded = widget.initiallyExpanded;

  void _toggle() {
    setState(() => _isExpanded = !_isExpanded);
  }

  @override
  Widget build(BuildContext context) {
    final header = InkWell(
      onTap: _toggle,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: widget.headerPadding ??
            const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
        child: Row(
          children: [
            if (widget.icon != null) ...[
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: widget.iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(widget.icon, size: 17, color: widget.iconColor),
              ),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: widget.titleWidget ??
                  Text(
                    widget.title,
                    style: widget.titleStyle ??
                        const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF111827),
                        ),
                  ),
            ),
            if (widget.trailing != null) ...[
              widget.trailing!,
              const SizedBox(width: 8),
            ],
            AnimatedRotation(
              turns: _isExpanded ? 0.5 : 0,
              duration: const Duration(milliseconds: 250),
              child: const Icon(
                Icons.keyboard_arrow_down,
                size: 22,
                color: Color(0xFF6B7280),
              ),
            ),
          ],
        ),
      ),
    );

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        header,
        AnimatedCrossFade(
          firstChild: const SizedBox.shrink(),
          secondChild: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: widget.child,
          ),
          crossFadeState: _isExpanded
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 250),
        ),
      ],
    );

    if (!widget.card) return content;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F000000),
            blurRadius: 18,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: content,
    );
  }
}
