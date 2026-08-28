/// Open Editor Button — world-class replacement for inline text-field icons.
///
/// Across the app, fields used to be polluted with a row of suffix icons
/// (microphone, AI sparkles, .docx import, clear, undo/redo, rewrite, etc.).
/// This widget replaces that pattern with a single yellow-themed button
/// placed OUTSIDE the text field. Tapping it opens a popup menu listing
/// every available editor action for that field.
///
/// Visual identity:
///  • Brand-gold gradient (#FFB800 → #F59E0B) matching the rest of the
///    KAZ AI / NDU Project accent system.
///  • Edit-note leading icon + 'Open Editor' label + chevron-down.
///  • Loading state: leading icon swaps to a white spinner while any
///    async action is running.
///  • Disabled state: grey gradient + grey text — used when no actions
///    are applicable (e.g. password fields).
///
/// Usage:
///   OpenEditorButton(
///     actions: [
///       EditorAction(
///         id: 'voice',
///         icon: Icons.mic_none_outlined,
///         label: 'Voice input',
///         onTap: _toggleVoiceInput,
///       ),
///       EditorAction(
///         id: 'ai',
///         icon: Icons.auto_awesome,
///         label: 'KAZ AI suggest',
///         onTap: _generateWithKazAi,
///       ),
///     ],
///     isLoading: _isListening || _isGeneratingAi,
///   )
library;

import 'package:flutter/material.dart';

/// A single editor action surfaced inside the [OpenEditorButton] popup.
class EditorAction {
  const EditorAction({
    required this.id,
    required this.icon,
    required this.label,
    required this.onTap,
    this.tooltip,
    this.enabled = true,
    this.accent,
    this.isDestructive = false,
  });

  /// Stable identifier used as the [showMenu] result value.
  final String id;

  /// Icon shown to the left of the label inside the popup row.
  final IconData icon;

  /// Human-readable label, e.g. 'Voice input'.
  final String label;

  /// Optional tooltip / subtitle shown under the label inside the popup.
  final String? tooltip;

  /// Callback invoked when the user picks this action.
  final VoidCallback onTap;

  /// Whether the action can currently be tapped. Disabled rows render
  /// greyed-out and are not selectable.
  final bool enabled;

  /// Per-action accent color for the leading icon. Defaults to brand gold.
  final Color? accent;

  /// Destructive actions (e.g. clear, delete) render their leading icon in
  /// red and their label in a darker tone, matching the existing trash
  /// icon convention.
  final bool isDestructive;
}

/// A yellow-themed button that opens a popup menu of [EditorAction]s.
///
/// Renders OUTSIDE the text field as a sibling. Tapping it opens a
/// Material [showMenu] popup directly below the button, listing every
/// enabled action. After the user picks one, the popup closes and the
/// action's [EditorAction.onTap] is invoked.
class OpenEditorButton extends StatefulWidget {
  const OpenEditorButton({
    super.key,
    required this.actions,
    this.label = 'Open Editor',
    this.compact = false,
    this.isLoading = false,
  });

  /// The editor actions to surface in the popup.
  ///
  /// Only actions with [EditorAction.enabled] = true are shown.
  /// If every action is disabled (or the list is empty), the button
  /// renders in a disabled state.
  final List<EditorAction> actions;

  /// The button label. Defaults to 'Open Editor'.
  final String label;

  /// Compact mode — smaller padding / icon / text for inline use.
  final bool compact;

  /// When true, the leading icon is replaced with a white spinner. Set
  /// this to `true` while any async action is in progress (e.g.
  /// `_isListening || _isGeneratingAi || _isImportingDoc`).
  final bool isLoading;

  @override
  State<OpenEditorButton> createState() => _OpenEditorButtonState();
}

class _OpenEditorButtonState extends State<OpenEditorButton> {
  final GlobalKey _buttonKey = GlobalKey();

  // Brand-gold ramp — tightly coordinated with the rest of the app.
  static const Color _gold = Color(0xFFFFB800);
  static const Color _goldDeep = Color(0xFFF59E0B);
  static const Color _disabledBg = Color(0xFFE5E7EB);
  static const Color _disabledBgDeep = Color(0xFFD1D5DB);
  static const Color _disabledFg = Color(0xFF6B7280);

  @override
  Widget build(BuildContext context) {
    final hasActions = widget.actions.any((a) => a.enabled);
    final bgColors = hasActions
        ? const [_gold, _goldDeep]
        : const [_disabledBg, _disabledBgDeep];
    final fgColor = hasActions ? Colors.white : _disabledFg;

    return Theme(
      // Remove the default Material InkWell splash radius override.
      data: Theme.of(context).copyWith(
        splashColor: Colors.white.withValues(alpha: 0.18),
        highlightColor: Colors.white.withValues(alpha: 0.12),
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: bgColors,
          ),
          boxShadow: hasActions
              ? [
                  BoxShadow(
                    color: _gold.withValues(alpha: 0.35),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                  BoxShadow(
                    color: _goldDeep.withValues(alpha: 0.18),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ]
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            key: _buttonKey,
            onTap: hasActions ? _showMenu : null,
            borderRadius: BorderRadius.circular(10),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              padding: EdgeInsets.symmetric(
                horizontal: widget.compact ? 10 : 14,
                vertical: widget.compact ? 6 : 8,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.isLoading)
                    SizedBox(
                      width: widget.compact ? 13 : 15,
                      height: widget.compact ? 13 : 15,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(fgColor),
                      ),
                    )
                  else
                    Icon(
                      Icons.edit_note_rounded,
                      size: widget.compact ? 16 : 18,
                      color: fgColor,
                    ),
                  SizedBox(width: widget.compact ? 6 : 8),
                  Text(
                    widget.label,
                    style: TextStyle(
                      fontSize: widget.compact ? 12 : 13,
                      fontWeight: FontWeight.w700,
                      color: fgColor,
                      letterSpacing: 0.2,
                      fontFamily: 'Inter',
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: widget.compact ? 16 : 18,
                    color: fgColor,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showMenu() async {
    final renderBox =
        _buttonKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final size = renderBox.size;
    final offset = renderBox.localToGlobal(Offset.zero);
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;

    // Position the popup directly below the button, left-aligned with it.
    final position = RelativeRect.fromLTRB(
      offset.dx,
      offset.dy + size.height + 6,
      overlay.size.width - offset.dx - size.width,
      0,
    );

    final enabledActions = widget.actions.where((a) => a.enabled).toList();
    if (enabledActions.isEmpty) return;

    final selected = await showMenu<String>(
      context: context,
      position: position,
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFEFF1F4), width: 1),
      ),
      constraints: BoxConstraints(
        minWidth: 220,
        maxWidth: overlay.size.width,
      ),
      items: enabledActions.map(_buildPopupItem).toList(),
    );

    if (selected == null) return;
    if (!mounted) return;
    // Defensive: actions may change while the menu is open - never crash
    // with "Bad state: No element" (firstWhere without orElse).
    final match = enabledActions.where((a) => a.id == selected).firstOrNull;
    if (match == null) return;
    match.onTap();
  }

  PopupMenuItem<String> _buildPopupItem(EditorAction action) {
    final accent = action.isDestructive
        ? const Color(0xFFEF4444)
        : (action.accent ?? const Color(0xFFF59E0B));
    return PopupMenuItem<String>(
      value: action.id,
      enabled: action.enabled,
      height: action.tooltip != null ? 64 : 48,
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(action.icon, size: 18, color: accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  action.label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: action.isDestructive
                        ? const Color(0xFFB91C1C)
                        : const Color(0xFF111827),
                    fontFamily: 'Inter',
                  ),
                ),
                if (action.tooltip != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    action.tooltip!,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w400,
                      color: Color(0xFF6B7280),
                      fontFamily: 'Inter',
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
