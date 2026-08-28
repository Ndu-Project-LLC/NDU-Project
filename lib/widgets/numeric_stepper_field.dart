import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A compact labeled numeric input with circular − / + stepper buttons.
///
/// The text field stays editable (numeric filter applied) while the buttons
/// increment/decrement by [step] and clamp the value between [min] and [max].
class NumericStepperField extends StatefulWidget {
  const NumericStepperField({
    super.key,
    required this.controller,
    required this.label,
    this.step = 1,
    this.min = 0,
    this.max = 9999,
    this.isDouble = false,
  });

  final TextEditingController controller;
  final String label;
  final double step;
  final double min;
  final double max;
  final bool isDouble;

  /// Formats [value] for display, dropping a trailing `.0` on whole numbers.
  static String formatValue(double value, {bool isDouble = false}) {
    String text = isDouble ? value.toString() : value.round().toString();
    if (text.endsWith('.0')) text = text.substring(0, text.length - 2);
    return text;
  }

  @override
  State<NumericStepperField> createState() => _NumericStepperFieldState();
}

class _NumericStepperFieldState extends State<NumericStepperField> {
  double get _currentValue {
    final raw = widget.controller.text.trim().replaceAll('%', '');
    return double.tryParse(raw) ?? widget.min;
  }

  void _apply(double value) {
    final clamped = value.clamp(widget.min, widget.max).toDouble();
    final text = NumericStepperField.formatValue(
      clamped,
      isDouble: widget.isDouble,
    );
    widget.controller.text = text;
    widget.controller.selection = TextSelection.collapsed(offset: text.length);
  }

  void _increment() => _apply(_currentValue + widget.step);

  void _decrement() => _apply(_currentValue - widget.step);

  OutlineInputBorder _inputBorder({Color color = const Color(0xFFE5E7EB)}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: color),
    );
  }

  Widget _stepButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: 36,
      height: 36,
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        padding: EdgeInsets.zero,
        splashRadius: 18,
        icon: Icon(icon, size: 18, color: const Color(0xFF141414)),
        style: IconButton.styleFrom(
          shape: const CircleBorder(),
          side: const BorderSide(color: Color(0xFFE5E7EB)),
          backgroundColor: Colors.white,
        ),
        hoverColor: const Color(0xFFFFC107).withValues(alpha: 0.18),
        highlightColor: const Color(0xFFFFC107),
        splashColor: const Color(0xFFFFC107).withValues(alpha: 0.4),
        focusColor: const Color(0xFFFFC107).withValues(alpha: 0.18),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          widget.label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFF6B7280),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            _stepButton(
              icon: Icons.remove,
              tooltip: 'Decrease ${widget.label}',
              onPressed: _decrement,
            ),
            Expanded(
              child: TextField(
                controller: widget.controller,
                textAlign: TextAlign.center,
                keyboardType: TextInputType.numberWithOptions(
                  decimal: widget.isDouble,
                  signed: widget.min < 0,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^-?\d*\.?\d*')),
                ],
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF141414),
                ),
                decoration: InputDecoration(
                  isDense: true,
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 12,
                  ),
                  border: _inputBorder(),
                  enabledBorder: _inputBorder(),
                  focusedBorder: _inputBorder(color: const Color(0xFFFFC107)),
                ),
              ),
            ),
            _stepButton(
              icon: Icons.add,
              tooltip: 'Increase ${widget.label}',
              onPressed: _increment,
            ),
          ],
        ),
      ],
    );
  }
}
