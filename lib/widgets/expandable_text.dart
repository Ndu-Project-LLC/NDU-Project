import 'package:flutter/material.dart';

/// Expandable text widget that truncates at maxLines and shows "View more" button
class ExpandableText extends StatefulWidget {
  final String text;
  final int maxLines;
  final TextStyle? style;
  final Color? expandButtonColor;

  const ExpandableText({
    super.key,
    required this.text,
    this.maxLines = 8,
    this.style,
    this.expandButtonColor,
  });

  @override
  State<ExpandableText> createState() => _ExpandableTextState();
}

class _ExpandableTextState extends State<ExpandableText> {
  bool _isExpanded = false;
  bool _exceedsMaxLines = false;

  @override
  void didUpdateWidget(ExpandableText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      // Reset expansion when text changes
      setState(() => _isExpanded = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Calculate if text exceeds max lines
    final textSpan = TextSpan(
      text: widget.text,
      style: widget.style ?? Theme.of(context).textTheme.bodyMedium,
    );
    
    final textPainter = TextPainter(
      text: textSpan,
      maxLines: widget.maxLines,
      textDirection: TextDirection.ltr,
    );
    
    textPainter.layout(maxWidth: MediaQuery.of(context).size.width - 100);
    _exceedsMaxLines = textPainter.didExceedMaxLines;
    textPainter.dispose();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedSize(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          child: Text(
            widget.text,
            maxLines: _isExpanded ? null : widget.maxLines,
            overflow: _isExpanded ? null : TextOverflow.ellipsis,
            style: widget.style,
          ),
        ),
        if (_exceedsMaxLines)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: TextButton(
              onPressed: () => setState(() => _isExpanded = !_isExpanded),
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: const Size(0, 36),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                _isExpanded ? 'View less' : 'View more',
                style: TextStyle(
                  color: widget.expandButtonColor ?? Theme.of(context).primaryColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
