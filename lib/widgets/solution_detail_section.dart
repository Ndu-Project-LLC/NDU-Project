import 'package:flutter/material.dart';

/// Accordion-style section widget for solution details view
class SolutionDetailSection extends StatefulWidget {
  const SolutionDetailSection({
    super.key,
    required this.title,
    required this.content,
    this.initiallyExpanded = false,
    this.icon,
  });

  final String title;
  final Widget content;
  final bool initiallyExpanded;
  final IconData? icon;

  @override
  State<SolutionDetailSection> createState() => _SolutionDetailSectionState();
}

class _SolutionDetailSectionState extends State<SolutionDetailSection> {
  late bool isExpanded;

  @override
  void initState() {
    super.initState();
    isExpanded = widget.initiallyExpanded;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: Column(
        children: [
          ListTile(
            leading: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.icon != null) ...[
                  Icon(
                    widget.icon,
                    color: theme.colorScheme.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                ],
                Icon(
                  isExpanded ? Icons.expand_more : Icons.chevron_right,
                  color: theme.colorScheme.primary,
                ),
              ],
            ),
            title: Text(
              widget.title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            onTap: () => setState(() => isExpanded = !isExpanded),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          ),
          if (isExpanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: widget.content,
            ),
        ],
      ),
    );
  }
}
