import 'package:flutter/material.dart';
import 'package:ndu_project/theme.dart';

import 'package:ndu_project/widgets/voice_text_field.dart';
import 'package:ndu_project/widgets/delete_confirmation_dialog.dart';
class ChartBuilderWorkspace extends StatefulWidget {
  const ChartBuilderWorkspace({super.key});

  @override
  State<ChartBuilderWorkspace> createState() => _ChartBuilderWorkspaceState();
}

class _ChartBuilderWorkspaceState extends State<ChartBuilderWorkspace> {
  ChartType _type = ChartType.bar;
  final List<_ChartPoint> _points = [
    _ChartPoint(label: 'Jan', value: 42, color: const Color(0xFFD97706)),
    _ChartPoint(label: 'Feb', value: 58, color: const Color(0xFF10B981)),
    _ChartPoint(label: 'Mar', value: 36, color: const Color(0xFFF59E0B)),
    _ChartPoint(label: 'Apr', value: 74, color: const Color(0xFFEF4444)),
  ];

  void _addPoint() {
    setState(() {
      _points.add(_ChartPoint(label: 'New', value: 40, color: const Color(0xFF8B5CF6)));
    });
  }

  Future<void> _removePoint(int index) async {
    if (_points.length <= 1) return;
    final confirmed = await showDeleteConfirmationDialog(
      context,
      title: 'Remove Data Point',
      itemLabel: _points[index].label,
    );
    if (!confirmed) return;
    setState(() => _points.removeAt(index));
  }

  void _updatePoint(int index, {String? label, double? value, Color? color}) {
    final current = _points[index];
    setState(() {
      _points[index] = current.copyWith(
        label: label ?? current.label,
        value: value ?? current.value,
        color: color ?? current.color,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppSemanticColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              children: [
                _ChartHeader(
                  active: _type,
                  onSelect: (type) => setState(() => _type = type),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppSemanticColors.border),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: CustomPaint(
                          painter: _ChartPainter(type: _type, points: _points),
                          child: Container(),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 280,
            decoration: BoxDecoration(
              border: Border(left: BorderSide(color: AppSemanticColors.border)),
              color: const Color(0xFFF9FAFB),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text('Data', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.grey[800])),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: _points.length,
                    itemBuilder: (context, index) {
                      final point = _points[index];
                      return _DataRow(
                        point: point,
                        onLabelChanged: (label) => _updatePoint(index, label: label),
                        onValueChanged: (value) => _updatePoint(index, value: value),
                        onColorChanged: (color) => _updatePoint(index, color: color),
                        onRemove: () => _removePoint(index),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _addPoint,
                      icon: const Icon(Icons.add),
                      label: const Text('Add point'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChartHeader extends StatelessWidget {
  const _ChartHeader({required this.active, required this.onSelect});

  final ChartType active;
  final ValueChanged<ChartType> onSelect;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          Text('Chart Builder', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.grey[800])),
          const Spacer(),
          _ChartTypeChip(
            label: 'Bar',
            isActive: active == ChartType.bar,
            onTap: () => onSelect(ChartType.bar),
          ),
          const SizedBox(width: 8),
          _ChartTypeChip(
            label: 'Line',
            isActive: active == ChartType.line,
            onTap: () => onSelect(ChartType.line),
          ),
          const SizedBox(width: 8),
          _ChartTypeChip(
            label: 'Area',
            isActive: active == ChartType.area,
            onTap: () => onSelect(ChartType.area),
          ),
          const SizedBox(width: 8),
          _ChartTypeChip(
            label: 'Donut',
            isActive: active == ChartType.donut,
            onTap: () => onSelect(ChartType.donut),
          ),
        ],
      ),
    );
  }
}

class _ChartTypeChip extends StatelessWidget {
  const _ChartTypeChip({required this.label, required this.isActive, required this.onTap});

  final String label;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? LightModeColors.accent.withOpacity(0.18) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isActive ? LightModeColors.accent : AppSemanticColors.border),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: isActive ? Colors.black : Colors.grey[700],
          ),
        ),
      ),
    );
  }
}

class _DataRow extends StatelessWidget {
  const _DataRow({
    required this.point,
    required this.onLabelChanged,
    required this.onValueChanged,
    required this.onColorChanged,
    required this.onRemove,
  });

  final _ChartPoint point;
  final ValueChanged<String> onLabelChanged;
  final ValueChanged<double> onValueChanged;
  final ValueChanged<Color> onColorChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final swatches = [
      const Color(0xFFD97706),
      const Color(0xFF10B981),
      const Color(0xFFF59E0B),
      const Color(0xFFEF4444),
      const Color(0xFF8B5CF6),
      const Color(0xFF0EA5E9),
    ];
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppSemanticColors.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: point.color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: VoiceTextFormField(
                  initialValue: point.label,
                  decoration: const InputDecoration(
                    isDense: true,
                    border: OutlineInputBorder(),
                    labelText: 'Label',
                  ),
                  onChanged: onLabelChanged,
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 80,
                child: VoiceTextFormField(
                  initialValue: point.value.toStringAsFixed(0),
                  decoration: const InputDecoration(
                    isDense: true,
                    border: OutlineInputBorder(),
                    labelText: 'Value',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (value) {
                    final parsed = double.tryParse(value);
                    if (parsed != null) onValueChanged(parsed);
                  },
                ),
              ),
              IconButton(
                tooltip: 'Remove',
                onPressed: onRemove,
                icon: const Icon(Icons.close, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: swatches.map((swatch) {
              final selected = swatch.toARGB32() == point.color.toARGB32();
              return GestureDetector(
                onTap: () => onColorChanged(swatch),
                child: Container(
                  width: 18,
                  height: 18,
                  margin: const EdgeInsets.only(right: 6),
                  decoration: BoxDecoration(
                    color: swatch,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: selected ? Colors.black : Colors.transparent,
                      width: selected ? 2 : 1,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _ChartPainter extends CustomPainter {
  _ChartPainter({required this.type, required this.points});

  final ChartType type;
  final List<_ChartPoint> points;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final paint = Paint()..isAntiAlias = true;
    canvas.drawRect(rect, paint..color = Colors.white);

    if (points.isEmpty) return;

    switch (type) {
      case ChartType.bar:
        _paintBars(canvas, size);
        break;
      case ChartType.line:
        _paintLine(canvas, size, fill: false);
        break;
      case ChartType.area:
        _paintLine(canvas, size, fill: true);
        break;
      case ChartType.donut:
        _paintDonut(canvas, size);
        break;
    }
  }

  void _paintBars(Canvas canvas, Size size) {
    final maxValue = points.map((e) => e.value).reduce((a, b) => a > b ? a : b);
    final chartHeight = size.height * 0.78;
    final baseY = size.height * 0.88;
    final spacing = size.width / (points.length + 1);
    for (var i = 0; i < points.length; i++) {
      final p = points[i];
      final barHeight = maxValue == 0 ? 0 : (p.value / maxValue) * chartHeight;
      final barWidth = spacing * 0.5;
      final x = spacing * (i + 0.7);
      final rect = Rect.fromLTWH(x, baseY - barHeight, barWidth, barHeight.toDouble());
      final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(8));
      final paint = Paint()..color = p.color;
      canvas.drawRRect(rrect, paint);

      final textPainter = TextPainter(
        text: TextSpan(text: p.label, style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: barWidth + 20);
      textPainter.paint(canvas, Offset(x - 4, baseY + 6));
    }
  }

  void _paintLine(Canvas canvas, Size size, {required bool fill}) {
    final maxValue = points.map((e) => e.value).reduce((a, b) => a > b ? a : b);
    final minValue = points.map((e) => e.value).reduce((a, b) => a < b ? a : b);
    final chartHeight = size.height * 0.7;
    final topY = size.height * 0.12;
    final leftX = size.width * 0.06;
    final rightX = size.width * 0.94;
    final span = maxValue - minValue == 0 ? 1 : maxValue - minValue;
    final step = points.length <= 1 ? 0 : (rightX - leftX) / (points.length - 1);

    final line = Path();
    for (var i = 0; i < points.length; i++) {
      final value = points[i].value;
      final x = points.length <= 1 ? (leftX + rightX) / 2 : leftX + step * i;
      final y = topY + chartHeight - ((value - minValue) / span) * chartHeight;
      if (i == 0) {
        line.moveTo(x, y);
      } else {
        line.lineTo(x, y);
      }
    }

    if (fill) {
      final fillPath = Path.from(line)
        ..lineTo(rightX, topY + chartHeight)
        ..lineTo(leftX, topY + chartHeight)
        ..close();
      final gradient = LinearGradient(
        colors: [const Color(0xFFD97706).withOpacity(0.35), Colors.white],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      );
      canvas.drawPath(fillPath, Paint()..shader = gradient.createShader(Offset.zero & size));
    }

    canvas.drawPath(
      line,
      Paint()
        ..color = const Color(0xFFD97706)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );

    for (var i = 0; i < points.length; i++) {
      final value = points[i].value;
      final x = points.length <= 1 ? (leftX + rightX) / 2 : leftX + step * i;
      final y = topY + chartHeight - ((value - minValue) / span) * chartHeight;
      canvas.drawCircle(xy(x, y), 5, Paint()..color = points[i].color);
    }
  }

  void _paintDonut(Canvas canvas, Size size) {
    final total = points.fold<double>(0, (sum, p) => sum + p.value.abs());
    if (total == 0) return;
    final center = Offset(size.width * 0.5, size.height * 0.5);
    final radius = size.shortestSide * 0.32;
    var startAngle = -1.57;
    for (final p in points) {
      final sweep = (p.value.abs() / total) * 6.283;
      final paint = Paint()
        ..color = p.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = radius * 0.35
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(Rect.fromCircle(center: center, radius: radius), startAngle, sweep, false, paint);
      startAngle += sweep;
    }
    final textPainter = TextPainter(
      text: const TextSpan(
        text: 'Total',
        style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(canvas, center - Offset(textPainter.width / 2, textPainter.height + 4));
  }

  Offset xy(double x, double y) => Offset(x, y);

  @override
  bool shouldRepaint(covariant _ChartPainter oldDelegate) =>
      oldDelegate.type != type || oldDelegate.points != points;
}

class _ChartPoint {
  _ChartPoint({required this.label, required this.value, required this.color});

  final String label;
  final double value;
  final Color color;

  _ChartPoint copyWith({String? label, double? value, Color? color}) {
    return _ChartPoint(
      label: label ?? this.label,
      value: value ?? this.value,
      color: color ?? this.color,
    );
  }
}

enum ChartType { bar, line, area, donut }
