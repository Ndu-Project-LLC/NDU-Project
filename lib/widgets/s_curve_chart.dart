import 'package:flutter/material.dart';

class SCurveChart extends StatelessWidget {
  const SCurveChart({super.key, 
    required this.plannedData,
    required this.actualData,
    required this.startDate,
    required this.endDate,
    this.height = 300,
    this.plannedColor = const Color(0xFF3B82F6),
    this.actualColor = const Color(0xFFF59E0B),
  });

  final List<SCurveDataPoint> plannedData;
  final List<SCurveDataPoint> actualData;
  final DateTime startDate;
  final DateTime endDate;
  final double height;
  final Color plannedColor;
  final Color actualColor;

  @override
  Widget build(BuildContext context) {
    if (plannedData.isEmpty && actualData.isEmpty) {
      return Container(
        height: height,
        width: double.infinity,
        decoration: BoxDecoration(
          color: const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: const Center(
          child: Text(
            'No data available for S-curve chart.',
            style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
          ),
        ),
      );
    }

    return Container(
      height: height,
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _LegendItem(color: plannedColor, label: 'Planned (Budgeted)'),
              const SizedBox(width: 16),
              _LegendItem(color: actualColor, label: 'Actual'),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return CustomPaint(
                  size: Size(constraints.maxWidth, constraints.maxHeight),
                  painter: _SCurvePainter(
                    plannedData: plannedData,
                    actualData: actualData,
                    startDate: startDate,
                    endDate: endDate,
                    plannedColor: plannedColor,
                    actualColor: actualColor,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Color(0xFF374151)),
        ),
      ],
    );
  }
}

class _SCurvePainter extends CustomPainter {
  const _SCurvePainter({
    required this.plannedData,
    required this.actualData,
    required this.startDate,
    required this.endDate,
    required this.plannedColor,
    required this.actualColor,
  });

  final List<SCurveDataPoint> plannedData;
  final List<SCurveDataPoint> actualData;
  final DateTime startDate;
  final DateTime endDate;
  final Color plannedColor;
  final Color actualColor;

  @override
  void paint(Canvas canvas, Size size) {
    final chartWidth = size.width - 60;
    final chartHeight = size.height - 40;
    final origin = Offset(50, size.height - 30);

    final totalDays = endDate.difference(startDate).inDays + 1;
    if (totalDays <= 0) return;

    // Find max cost for Y-axis scaling
    double maxCost = 0;
    for (final point in [...plannedData, ...actualData]) {
      if (point.cumulativeCost > maxCost) maxCost = point.cumulativeCost;
    }
    if (maxCost == 0) maxCost = 1;

    // Draw grid lines
    final gridPaint = Paint()
      ..color = const Color(0xFFE5E7EB)
      ..strokeWidth = 1;

    for (int i = 0; i <= 4; i++) {
      final y = origin.dy - (i * chartHeight / 4);
      canvas.drawLine(Offset(origin.dx, y), Offset(origin.dx + chartWidth, y), gridPaint);
    }

    // Draw axes
    final axisPaint = Paint()
      ..color = const Color(0xFF9CA3AF)
      ..strokeWidth = 2;

    canvas.drawLine(origin, Offset(origin.dx + chartWidth, origin.dy), axisPaint);
    canvas.drawLine(origin, Offset(origin.dx, origin.dy - chartHeight), axisPaint);

    // Draw Y-axis labels
    for (int i = 0; i <= 4; i++) {
      final y = origin.dy - (i * chartHeight / 4);
      final value = (maxCost * i / 4).round();
      final textPainter = TextPainter(
        text: TextSpan(
          text: '\$$value',
          style: const TextStyle(fontSize: 9, color: Color(0xFF6B7280)),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(origin.dx - textPainter.width - 6, y - textPainter.height / 2));
    }

    // Draw X-axis labels (months)
    final months = <String>[];
    DateTime cursor = DateTime(startDate.year, startDate.month, 1);
    final endMonth = DateTime(endDate.year, endDate.month, 1);
    while (!cursor.isAfter(endMonth)) {
      months.add('${_monthAbbreviation(cursor.month)} ${cursor.year}');
      cursor = DateTime(cursor.year, cursor.month + 1, 1);
    }

    for (int i = 0; i < months.length; i++) {
      final x = origin.dx + (i * chartWidth / (months.length - 1).clamp(1, 100));
      final textPainter = TextPainter(
        text: TextSpan(
          text: months[i],
          style: const TextStyle(fontSize: 9, color: Color(0xFF6B7280)),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(x - textPainter.width / 2, origin.dy + 6));
    }

    // Draw planned curve
    if (plannedData.isNotEmpty) {
      _drawCurve(canvas, origin, chartWidth, chartHeight, totalDays, maxCost, plannedData, plannedColor);
    }

    // Draw actual curve
    if (actualData.isNotEmpty) {
      _drawCurve(canvas, origin, chartWidth, chartHeight, totalDays, maxCost, actualData, actualColor);
    }
  }

  void _drawCurve(
    Canvas canvas,
    Offset origin,
    double chartWidth,
    double chartHeight,
    int totalDays,
    double maxCost,
    List<SCurveDataPoint> data,
    Color color,
  ) {
    if (data.length < 2) return;

    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    final path = Path();
    for (int i = 0; i < data.length; i++) {
      final daysFromStart = data[i].date.difference(startDate).inDays;
      final x = origin.dx + (daysFromStart / totalDays) * chartWidth;
      final y = origin.dy - (data[i].cumulativeCost / maxCost) * chartHeight;

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, paint);

    // Draw dots at data points
    final dotPaint = Paint()..color = color;
    for (int i = 0; i < data.length; i++) {
      final daysFromStart = data[i].date.difference(startDate).inDays;
      final x = origin.dx + (daysFromStart / totalDays) * chartWidth;
      final y = origin.dy - (data[i].cumulativeCost / maxCost) * chartHeight;
      canvas.drawCircle(Offset(x, y), 3, dotPaint);
    }
  }

  String _monthAbbreviation(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[month - 1];
  }

  @override
  bool shouldRepaint(covariant _SCurvePainter oldDelegate) {
    return oldDelegate.plannedData != plannedData ||
        oldDelegate.actualData != actualData ||
        oldDelegate.startDate != startDate ||
        oldDelegate.endDate != endDate;
  }
}

class SCurveDataPoint {
  const SCurveDataPoint({required this.date, required this.cumulativeCost});

  final DateTime date;
  final double cumulativeCost;
}
