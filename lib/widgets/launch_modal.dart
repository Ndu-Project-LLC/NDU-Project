import 'package:flutter/material.dart';

import 'package:ndu_project/widgets/voice_text_field.dart';

/// Shared building blocks for world-class Launch Phase pop-up modals.
///
/// Design language:
///  * White container, 16px radius, soft shadow (8% black, blur 24, y+8).
///  * Max width 560px, centered.
///  * 24px interior padding.
///  * Header: 32x32 colored icon tile, 18px w700 title, 13px subtitle, X close.
///  * Field labels: 11px w600 uppercase, 0.8 letter spacing, gray-500.
///  * Inputs: white fill, 8px radius, 1px gray-200 border, gold (0xFFFFC107)
///    focused border 1.6px. All text inputs use [VoiceTextField] with docx
///    import disabled.
///  * Action row: white "Cancel" outlined + gold "Save" filled, 8px gap.

const Color _kModalTextPrimary = Color(0xFF1A1D1F);
const Color _kModalTextSecondary = Color(0xFF6B7280);
const Color _kModalBorder = Color(0xFFE4E7EC);
const Color _kModalAccent = Color(0xFFFFC107);

/// Convenience wrapper around [showDialog] that builds a [LaunchModalShell].
///
/// Pass [icon], [title], [subtitle] for the header, [accent] for the icon tile
/// color (defaults to gold), [body] for the form fields, and [actions] for the
/// bottom-right action row. The dialog is dismissible by tapping the barrier.
Future<T?> showLaunchModal<T>({
  required BuildContext context,
  required IconData icon,
  required String title,
  String? subtitle,
  Color? accent,
  required Widget body,
  List<Widget>? actions,
  T? resultValue,
}) {
  return showDialog<T>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => LaunchModalShell(
      icon: icon,
      title: title,
      subtitle: subtitle,
      accent: accent,
      body: body,
      actions: actions,
    ),
  );
}

/// The world-class modal container. Use directly inside [showDialog] when you
/// need full control, or via [showLaunchModal] for the common case.
class LaunchModalShell extends StatelessWidget {
  const LaunchModalShell({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.accent,
    required this.body,
    this.actions,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Color? accent;
  final Widget body;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    final Color effectiveAccent = accent ?? _kModalAccent;
    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LaunchModalHeader(
                    icon: icon,
                    title: title,
                    subtitle: subtitle,
                    accent: effectiveAccent,
                  ),
                  const SizedBox(height: 20),
                  body,
                  if (actions != null && actions!.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (int i = 0; i < actions!.length; i++) ...[
                            if (i > 0) const SizedBox(width: 8),
                            actions![i],
                          ],
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Modal header: 32x32 colored icon tile + 18px title + 13px subtitle + close.
class LaunchModalHeader extends StatelessWidget {
  const LaunchModalHeader({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.accent,
    this.onClose,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Color? accent;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final Color effectiveAccent = accent ?? _kModalAccent;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: effectiveAccent.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: effectiveAccent, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: _kModalTextPrimary,
                  height: 1.2,
                ),
              ),
              if (subtitle != null && subtitle!.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  style: const TextStyle(
                    fontSize: 13,
                    color: _kModalTextSecondary,
                    height: 1.35,
                  ),
                ),
              ],
            ],
          ),
        ),
        Tooltip(
          message: 'Close',
          child: _CloseButton(onPressed: onClose ?? () => Navigator.of(context).maybePop()),
        ),
      ],
    );
  }
}

class _CloseButton extends StatefulWidget {
  const _CloseButton({required this.onPressed});
  final VoidCallback onPressed;

  @override
  State<_CloseButton> createState() => _CloseButtonState();
}

class _CloseButtonState extends State<_CloseButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => Future.microtask(() {
        if (mounted) setState(() => _hover = true);
      }),
      onExit: (_) => Future.microtask(() {
        if (mounted) setState(() => _hover = false);
      }),
      child: InkWell(
        onTap: widget.onPressed,
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: _hover
                ? const Color(0xFFF3F4F6)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(
            Icons.close,
            color: _kModalTextSecondary,
            size: 20,
          ),
        ),
      ),
    );
  }
}

/// Uppercase field label: 11px w600, 0.8 letter spacing, gray-500.
class LaunchModalLabel extends StatelessWidget {
  const LaunchModalLabel(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: _kModalTextSecondary,
        letterSpacing: 0.8,
      ),
    );
  }
}

/// Vertical gap inside a modal form. Defaults to 12px between fields.
class LaunchModalFieldGap extends StatelessWidget {
  const LaunchModalFieldGap({super.key, this.size = 12});
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox(height: size);
}

/// A label + 4px gap + styled [VoiceTextField] combo. Use [maxLines] > 1 for
/// multi-line inputs. All text inputs use [VoiceTextField] with docx import
/// disabled, per the design spec.
class LaunchModalTextField extends StatelessWidget {
  const LaunchModalTextField({
    super.key,
    required this.label,
    required this.controller,
    this.hint,
    this.maxLines = 1,
    this.keyboardType,
    this.suffixText,
    this.readOnly = false,
    this.onTap,
    this.suffixIcon,
    this.style,
    this.enableVoice = true,
  });

  final String label;
  final TextEditingController controller;
  final String? hint;
  final int maxLines;
  final TextInputType? keyboardType;
  final String? suffixText;
  final bool readOnly;
  final VoidCallback? onTap;
  final Widget? suffixIcon;
  final TextStyle? style;
  final bool enableVoice;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        LaunchModalLabel(label),
        const SizedBox(height: 4),
        VoiceTextField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          readOnly: readOnly,
          onTap: onTap,
          style: style,
          enableVoice: enableVoice,
          enableDocxImport: false,
          decoration: _inputDecoration(hint: hint, suffixText: suffixText, suffixIcon: suffixIcon),
        ),
      ],
    );
  }
}

/// A label + styled date picker trigger (read-only [VoiceTextField] that opens
/// a date picker on tap).
class LaunchModalDateField extends StatefulWidget {
  const LaunchModalDateField({
    super.key,
    required this.label,
    required this.initialDate,
    required this.onPicked,
    this.hint = 'Select date',
    this.firstDate,
    this.lastDate,
  });

  final String label;
  final DateTime? initialDate;
  final ValueChanged<DateTime?> onPicked;
  final String hint;
  final DateTime? firstDate;
  final DateTime? lastDate;

  @override
  State<LaunchModalDateField> createState() => _LaunchModalDateFieldState();
}

class _LaunchModalDateFieldState extends State<LaunchModalDateField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.initialDate != null
          ? _formatDateShort(widget.initialDate!)
          : '',
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  static String _formatDateShort(DateTime dt) {
    const months = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${dt.day} ${months[dt.month]} ${dt.year}';
  }

  Future<void> _pick() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: widget.initialDate ?? DateTime.now(),
      firstDate: widget.firstDate ?? DateTime(2020),
      lastDate: widget.lastDate ?? DateTime(2040),
    );
    if (picked != null) {
      _controller.text = _formatDateShort(picked);
      widget.onPicked(picked);
    } else {
      widget.onPicked(null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        LaunchModalLabel(widget.label),
        const SizedBox(height: 4),
        VoiceTextField(
          controller: _controller,
          readOnly: true,
          onTap: _pick,
          enableVoice: false,
          enableDocxImport: false,
          decoration: _inputDecoration(
            hint: widget.hint,
            suffixIcon: const Icon(Icons.calendar_today_outlined, size: 16, color: _kModalTextSecondary),
          ),
        ),
      ],
    );
  }
}

/// A label + styled dropdown. Wraps [DropdownButtonFormField] with the modal
/// design system (white fill, 8px radius, gray border, gold focus).
class LaunchModalDropdown<T> extends StatelessWidget {
  const LaunchModalDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.hint,
  });

  final String label;
  final T? value;
  final List<T> items;
  final ValueChanged<T?> onChanged;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        LaunchModalLabel(label),
        const SizedBox(height: 4),
        DropdownButtonFormField<T>(
          value: value,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down_rounded,
              color: _kModalTextSecondary, size: 20),
          style: const TextStyle(
            fontSize: 13,
            color: _kModalTextPrimary,
          ),
          decoration: _inputDecoration(hint: hint),
          items: items
              .map((v) => DropdownMenuItem<T>(
                    value: v,
                    child: Text(v.toString()),
                  ))
              .toList(),
          onChanged: onChanged,
        ),
      ],
    );
  }
}

/// Cancel button: white background, gray border, 8px radius, gray text.
class LaunchModalCancelButton extends StatelessWidget {
  const LaunchModalCancelButton({
    super.key,
    required this.label,
    this.onPressed,
  });

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed ?? () => Navigator.of(context).maybePop(),
      style: OutlinedButton.styleFrom(
        foregroundColor: _kModalTextSecondary,
        backgroundColor: Colors.white,
        side: const BorderSide(color: _kModalBorder),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: _kModalTextSecondary,
        ),
      ),
    );
  }
}

/// Primary action button: gold background, dark text, 8px radius, w600.
class LaunchModalPrimaryButton extends StatelessWidget {
  const LaunchModalPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
  });

  final String label;
  final VoidCallback onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final content = icon != null
        ? Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: _kModalTextPrimary),
              const SizedBox(width: 6),
              Text(label),
            ],
          )
        : Text(label);

    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: _kModalAccent,
        foregroundColor: _kModalTextPrimary,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        elevation: 0,
      ),
      child: content,
    );
  }
}

/// Destructive action button: red background, white text, 8px radius, w600.
class LaunchModalDangerButton extends StatelessWidget {
  const LaunchModalDangerButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: const Color(0xFFEF4444),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        elevation: 0,
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
    );
  }
}

InputDecoration _inputDecoration({
  String? hint,
  String? suffixText,
  Widget? suffixIcon,
}) {
  return InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)),
    isDense: true,
    filled: true,
    fillColor: Colors.white,
    contentPadding:
        const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
    suffixText: suffixText,
    suffixIcon: suffixIcon,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: _kModalBorder, width: 1),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: _kModalBorder, width: 1),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: _kModalAccent, width: 1.6),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.6),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1),
    ),
  );
}
