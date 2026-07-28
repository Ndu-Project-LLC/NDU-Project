import 'package:flutter/material.dart';

class ReviewConfirmationCheckbox extends StatelessWidget {
  const ReviewConfirmationCheckbox({
    super.key,
    required this.value,
    required this.onChanged,
    this.padding = const EdgeInsets.only(top: 16),
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final EdgeInsetsGeometry padding;

  static const String defaultLabel =
      'I confirm that I have reviewed all information on this page before proceeding.';

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Checkbox(
              value: value,
              onChanged: (checked) => onChanged(checked ?? false),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            const SizedBox(width: 8),
            const Expanded(
              child: Padding(
                padding: EdgeInsets.only(top: 3),
                child: Text(
                  defaultLabel,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF334155),
                    height: 1.35,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
