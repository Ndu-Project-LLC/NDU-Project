import 'package:flutter/material.dart';

/// Floating Quick Action menu for Progress Tracking pages
/// Actions: Add (+), Regenerate (AI), Export
class ProgressQuickActions extends StatelessWidget {
  const ProgressQuickActions({
    super.key,
    required this.onAdd,
    this.onRegenerate,
    this.onExport,
    this.showRegenerate = true,
    this.showExport = true,
  });

  final VoidCallback onAdd;
  final VoidCallback? onRegenerate;
  final VoidCallback? onExport;
  final bool showRegenerate;
  final bool showExport;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ActionButton(
            icon: Icons.add,
            label: 'Add',
            onPressed: onAdd,
            color: const Color(0xFF2563EB),
          ),
          if (showRegenerate) ...[
            SizedBox(
              height: 32,
              child: const VerticalDivider(
                thickness: 1,
                color: Color(0xFFE5E7EB),
              ),
            ),
            _ActionButton(
              icon: Icons.auto_awesome,
              label: 'Regenerate',
              onPressed: onRegenerate,
              color: const Color(0xFF7C3AED),
            ),
          ],
          if (showExport) ...[
            SizedBox(
              height: 32,
              child: const VerticalDivider(
                thickness: 1,
                color: Color(0xFFE5E7EB),
              ),
            ),
            _ActionButton(
              icon: Icons.download_outlined,
              label: 'Export',
              onPressed: onExport,
              color: const Color(0xFF059669),
            ),
          ],
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    required this.color,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
