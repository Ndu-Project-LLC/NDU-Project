import 'package:flutter/material.dart';

/// A bottom-of-page info banner that the user can dismiss with a close (X)
/// button. The dismissed state is stored in the parent widget (via
/// [onDismiss]) so the banner stays hidden across rebuilds for the lifetime
/// of the parent widget.
///
/// Used on FEP / Charter / Planning screens for the small AI hint / context
/// banner that appears alongside the Back / Next navigation buttons.
class CloseableInfoBanner extends StatelessWidget {
  final String message;
  final IconData icon;
  final Color iconColor;
  final Color backgroundColor;
  final Color borderColor;
  final VoidCallback? onDismiss;
  final bool showDismissButton;

  const CloseableInfoBanner({
    super.key,
    required this.message,
    this.icon = Icons.auto_awesome,
    this.iconColor = const Color(0xFFD97706),
    this.backgroundColor = const Color(0xFFE6F1FF),
    this.borderColor = const Color(0xFFD7E5FF),
    this.onDismiss,
    this.showDismissButton = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: iconColor, size: 18),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              message,
              style: const TextStyle(color: Color(0xFF1F2937), fontSize: 13),
            ),
          ),
          if (showDismissButton && onDismiss != null) ...[
            const SizedBox(width: 8),
            Tooltip(
              message: 'Close banner',
              child: InkWell(
                onTap: onDismiss,
                borderRadius: BorderRadius.circular(12),
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(
                    Icons.close,
                    size: 16,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Helper that shows a dismissible SnackBar. The user can tap "Dismiss" to
/// close the banner immediately rather than waiting for it to time out.
void showDismissibleSnackBar(
  BuildContext context,
  String message, {
  Color backgroundColor = const Color(0xFFD97706),
  Duration duration = const Duration(seconds: 4),
  Color? textColor,
}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: TextStyle(color: textColor ?? Colors.white),
        ),
        backgroundColor: backgroundColor,
        duration: duration,
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'Dismiss',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
}
