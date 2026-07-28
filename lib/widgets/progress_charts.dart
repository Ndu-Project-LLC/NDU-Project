import 'package:flutter/material.dart';
import 'dart:math' as math;

/// Timeline chart for deliverables showing past and future targets
class DeliverableTimelineChart extends StatelessWidget {
  const DeliverableTimelineChart({
    super.key,
    required this.deliverables,
    this.height = 200,
  });

  final List<Map<String, dynamic>>
      deliverables; // {title, dueDate, status, completionDate}
  final double height;

  @override
  Widget build(BuildContext context) {
    if (deliverables.isEmpty) {
      return SizedBox(
        height: height,
        child: const Center(
          child: Text(
            'No deliverables to display',
            style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
          ),
        ),
      );
    }

    return Container(
      height: height,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: CustomPaint(
        painter: _TimelinePainter(deliverables: deliverables),
        child: Container(),
      ),
    );
  }
}

class _TimelinePainter extends CustomPainter {
  _TimelinePainter({required this.deliverables});

  final List<Map<String, dynamic>> deliverables;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..isAntiAlias = true;
    final now = DateTime.now();

    // Draw timeline line
    final lineY = size.height * 0.5;
    paint
      ..color = const Color(0xFFE5E7EB)
      ..strokeWidth = 2;
    canvas.drawLine(Offset(0, lineY), Offset(size.width, lineY), paint);

    // Draw deliverables
    for (var i = 0; i < deliverables.length; i++) {
      final deliverable = deliverables[i];
      final dueDate = deliverable['dueDate'] as DateTime?;
      final status = deliverable['status'] as String? ?? 'Not Started';

      if (dueDate == null) continue;

      // Calculate position (simplified - assumes date range)
      final daysDiff = dueDate.difference(now).inDays;
      final maxDays = 90; // 3 months range
      final x = (daysDiff / maxDays * size.width).clamp(0.0, size.width);

      // Color based on status
      final color = switch (status) {
        'Completed' => const Color(0xFF10B981),
        'In Progress' => const Color(0xFF2563EB),
        'At Risk' => const Color(0xFFF59E0B),
        'Blocked' => const Color(0xFFEF4444),
        _ => const Color(0xFF9CA3AF),
      };

      // Draw marker
      paint
        ..color = color
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(x, lineY), 6, paint);

      // Draw label
      final title = deliverable['title'] as String? ?? '';
      if (title.isNotEmpty && i % 2 == 0) {
        // Show every other label to avoid overlap
        final textPainter = TextPainter(
          text: TextSpan(
            text: title.length > 15 ? '${title.substring(0, 15)}...' : title,
            style: const TextStyle(fontSize: 10, color: Color(0xFF6B7280)),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        textPainter.paint(
          canvas,
          Offset(x - textPainter.width / 2, lineY + 10),
        );
      }
    }

    // Draw "Now" indicator
    paint
      ..color = const Color(0xFFEF4444)
      ..strokeWidth = 2;
    final nowX = size.width * 0.5; // Assume now is middle
    canvas.drawLine(
      Offset(nowX, lineY - 10),
      Offset(nowX, lineY + 10),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _TimelinePainter oldDelegate) =>
      oldDelegate.deliverables != deliverables;
}

/// Donut chart for category spending
class DonutChart extends StatelessWidget {
  const DonutChart({
    super.key,
    required this.data, // List of {label, value, color}
    this.size = 150,
  });

  final List<Map<String, dynamic>> data;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return SizedBox(
        width: size,
        height: size,
        child: const Center(
          child: Text(
            'No data',
            style: TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
          ),
        ),
      );
    }

    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _DonutPainter(data: data),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                data.fold<double>(0, (sum, d) => sum + (d['value'] as num).toDouble()).toStringAsFixed(0),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF111827),
                ),
              ),
              const Text(
                'Total',
                style: TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  _DonutPainter({required this.data});

  final List<Map<String, dynamic>> data;

  @override
  void paint(Canvas canvas, Size size) {
    final total =
        data.fold<double>(0, (sum, d) => sum + (d['value'] as num).toDouble());
    if (total == 0) return;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide * 0.35;
    var startAngle = -math.pi / 2; // Start at top

    for (final item in data) {
      final value = (item['value'] as num).toDouble();
      final sweep = (value / total) * 2 * math.pi;
      final color = item['color'] as Color? ?? const Color(0xFF2563EB);

      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = radius * 0.4
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweep,
        false,
        paint,
      );

      startAngle += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) =>
      oldDelegate.data != data;
}

/// Bar chart for planned vs actual
class BarChart extends StatelessWidget {
  const BarChart({
    super.key,
    required this.data, // List of {label, planned, actual}
    this.height = 200,
  });

  final List<Map<String, dynamic>> data;
  final double height;

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return SizedBox(
        height: height,
        child: const Center(
          child: Text(
            'No data',
            style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
          ),
        ),
      );
    }

    return Container(
      height: height,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: CustomPaint(
        painter: _BarChartPainter(data: data),
        child: Container(),
      ),
    );
  }
}

class _BarChartPainter extends CustomPainter {
  _BarChartPainter({required this.data});

  final List<Map<String, dynamic>> data;

  @override
  void paint(Canvas canvas, Size size) {
    final maxValue = data.fold<double>(
      0,
      (max, d) => math.max(
        max,
        math.max(
          (d['planned'] as num?)?.toDouble() ?? 0,
          (d['actual'] as num?)?.toDouble() ?? 0,
        ),
      ),
    );

    if (maxValue == 0) return;

    final chartHeight = size.height * 0.7;
    final baseY = size.height * 0.85;
    final barWidth = (size.width / data.length) * 0.3;
    final spacing = size.width / (data.length + 1);

    for (var i = 0; i < data.length; i++) {
      final item = data[i];
      final planned = (item['planned'] as num?)?.toDouble() ?? 0;
      final actual = (item['actual'] as num?)?.toDouble() ?? 0;
      final x = spacing * (i + 1) - barWidth;

      // Planned bar
      final plannedHeight = (planned / maxValue) * chartHeight;
      final plannedRect = Rect.fromLTWH(
        x,
        baseY - plannedHeight,
        barWidth,
        plannedHeight,
      );
      final plannedRRect =
          RRect.fromRectAndRadius(plannedRect, const Radius.circular(4));
      canvas.drawRRect(
        plannedRRect,
        Paint()..color = const Color(0xFF9CA3AF),
      );

      // Actual bar
      final actualHeight = (actual / maxValue) * chartHeight;
      final actualRect = Rect.fromLTWH(
        x + barWidth + 4,
        baseY - actualHeight,
        barWidth,
        actualHeight,
      );
      final actualRRect =
          RRect.fromRectAndRadius(actualRect, const Radius.circular(4));
      canvas.drawRRect(
        actualRRect,
        Paint()..color = const Color(0xFF2563EB),
      );

      // Label
      final label = item['label'] as String? ?? '';
      if (label.isNotEmpty) {
        final textPainter = TextPainter(
          text: TextSpan(
            text: label.length > 8 ? '${label.substring(0, 8)}...' : label,
            style: const TextStyle(fontSize: 10, color: Color(0xFF6B7280)),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        textPainter.paint(
          canvas,
          Offset(x - (textPainter.width - barWidth * 2) / 2, baseY + 4),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _BarChartPainter oldDelegate) =>
      oldDelegate.data != data;
}
