import 'dart:math' as math;
import 'package:flutter/material.dart';

/// ─────────────────────────────────────────────────────────────────────────
/// Launch Insights — world-class visualization widgets shared by every
/// Launch Phase screen. Pure Flutter / CustomPaint — no external chart
/// dependencies, so it ships with the existing build pipeline.
///
/// Public widgets:
///   • LaunchKpiTile / LaunchKpiRow       — metric tiles with sparkline
///   • LaunchProgressDonut               — completion % donut gauge
///   • LaunchStatusMixBar                — horizontal stacked status bar
///   • LaunchPlannedVsActualBarChart     — grouped bar chart
///   • LaunchRadarChart                   — multi-axis performance radar
///   • LaunchTrendLineChart              — mini line trend
///   • LaunchKanbanBoard                 — 3-column status board
///   • LaunchInsightsHeader              — composed header (KPIs + donut)
/// ─────────────────────────────────────────────────────────────────────────

const Color _kAmber = Color(0xFFF59E0B);
const Color _kAmberDark = Color(0xFFD97706);
const Color _kGreen = Color(0xFF10B981);
const Color _kRed = Color(0xFFEF4444);
const Color _kBlue = Color(0xFFD97706);
const Color _kPurple = Color(0xFF7C3AED);
const Color _kSlate = Color(0xFF64748B);
const Color _kInk = Color(0xFF0F172A);
const Color _kInk2 = Color(0xFF334155);
const Color _kMute = Color(0xFF6B7280);

// ─────────────────────────────────────────────────────────────────────────
// KPI Tiles
// ─────────────────────────────────────────────────────────────────────────

class LaunchKpiTile {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final String? delta;
  final List<double>? sparkline;

  const LaunchKpiTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.delta,
    this.sparkline,
  });
}

class LaunchKpiRow extends StatelessWidget {
  final List<LaunchKpiTile> tiles;
  const LaunchKpiRow({super.key, required this.tiles});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 1100;
        final crossAxisCount = isWide
            ? (tiles.length >= 4 ? 4 : tiles.length)
            : (constraints.maxWidth >= 700 ? 2 : 1);
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: tiles
              .map((t) => SizedBox(
                    width: (constraints.maxWidth -
                            12 * (crossAxisCount - 1)) /
                        crossAxisCount,
                    child: _LaunchKpiTileView(tile: t),
                  ))
              .toList(),
        );
      },
    );
  }
}

class _LaunchKpiTileView extends StatelessWidget {
  final LaunchKpiTile tile;
  const _LaunchKpiTileView({required this.tile});

  @override
  Widget build(BuildContext context) {
    final isUp = (tile.delta ?? '').startsWith('+');
    final isDown = (tile.delta ?? '').startsWith('-');
    final deltaColor = isUp
        ? _kGreen
        : isDown
            ? _kRed
            : _kMute;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: tile.color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(tile.icon, color: tile.color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  tile.label.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: _kMute,
                    letterSpacing: 0.6,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  tile.value,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: _kInk,
                    letterSpacing: -0.4,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (tile.delta != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    tile.delta!,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: deltaColor,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (tile.sparkline != null && tile.sparkline!.length >= 2)
            SizedBox(
              width: 44,
              height: 28,
              child: CustomPaint(
                painter: _SparklinePainter(
                  points: tile.sparkline!,
                  color: tile.color,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  final List<double> points;
  final Color color;
  _SparklinePainter({required this.points, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;
    final minV = points.reduce(math.min);
    final maxV = points.reduce(math.max);
    final range = (maxV - minV).abs() < 0.0001 ? 1.0 : (maxV - minV);
    final dx = size.width / (points.length - 1);
    final path = Path();
    for (var i = 0; i < points.length; i++) {
      final x = i * dx;
      final y = size.height - ((points[i] - minV) / range) * size.height;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter oldDelegate) =>
      oldDelegate.points != points || oldDelegate.color != color;
}

// ─────────────────────────────────────────────────────────────────────────
// Progress Donut Gauge
// ─────────────────────────────────────────────────────────────────────────

class LaunchProgressDonut extends StatelessWidget {
  final double percent; // 0..1
  final String centerLabel;
  final String? caption;
  final Color color;
  final double size;

  const LaunchProgressDonut({
    super.key,
    required this.percent,
    required this.centerLabel,
    this.caption,
    this.color = _kAmber,
    this.size = 150,
  });

  @override
  Widget build(BuildContext context) {
    final clamped = percent.clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: CustomPaint(
              painter: _DonutPainter(percent: clamped, color: color),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${(clamped * 100).round()}%',
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: _kInk,
                        letterSpacing: -0.6,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      centerLabel,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: _kMute,
                        letterSpacing: 0.6,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (caption != null) ...[
            const SizedBox(height: 8),
            Text(
              caption!,
              style: const TextStyle(fontSize: 11, color: _kInk2, height: 1.4),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  final double percent;
  final Color color;
  _DonutPainter({required this.percent, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 10;
    final trackPaint = Paint()
      ..color = const Color(0xFFE5E7EB)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round;
    final progressPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi,
      false,
      trackPaint,
    );
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * percent,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) =>
      oldDelegate.percent != percent || oldDelegate.color != color;
}

// ─────────────────────────────────────────────────────────────────────────
// Status Mix Horizontal Bar
// ─────────────────────────────────────────────────────────────────────────

class LaunchStatusMixBar extends StatelessWidget {
  final String title;
  final Map<String, int> counts; // e.g. {'Complete': 5, 'In Progress': 3, ...}
  final Map<String, Color> colorMap;

  const LaunchStatusMixBar({
    super.key,
    required this.title,
    required this.counts,
    this.colorMap = const {
      'Complete': _kGreen,
      'In Progress': _kAmber,
      'Pending': _kSlate,
      'Not Applicable': _kMute,
      'Blocked': _kRed,
    },
  });

  @override
  Widget build(BuildContext context) {
    final total = counts.values.fold<int>(0, (s, v) => s + v);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.stacked_bar_chart, size: 16, color: _kInk2),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: _kInk,
                ),
              ),
              const Spacer(),
              Text(
                '$total item${total == 1 ? "" : "s"}',
                style: const TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w700, color: _kMute),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (total == 0)
            Container(
              height: 18,
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Center(
                child: Text('No items',
                    style: TextStyle(fontSize: 10, color: _kMute)),
              ),
            )
          else
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                height: 18,
                child: Row(
                  children: counts.entries
                      .where((e) => e.value > 0)
                      .map((e) {
                    final color = colorMap[e.key] ?? _kSlate;
                    final flex = (e.value * 1000) ~/ total;
                    return Expanded(
                      flex: flex,
                      child: Container(
                        color: color,
                        alignment: Alignment.center,
                        child: e.value > 0 && (e.value / total) > 0.08
                            ? Text(
                                '${e.value}',
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              )
                            : null,
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 14,
            runSpacing: 6,
            children: counts.entries.where((e) => e.value > 0).map((e) {
              final color = colorMap[e.key] ?? _kSlate;
              final pct = total == 0 ? 0 : (e.value / total * 100).round();
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration:
                        BoxDecoration(color: color, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${e.key}: ${e.value} ($pct%)',
                    style: const TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w600, color: _kInk2),
                  ),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Planned vs Actual Bar Chart
// ─────────────────────────────────────────────────────────────────────────

class LaunchPlannedVsActualBarChart extends StatelessWidget {
  final String title;
  final List<({String label, double planned, double actual})> bars;
  final String unit; // e.g. '\$', '%', 'hrs'

  const LaunchPlannedVsActualBarChart({
    super.key,
    required this.title,
    required this.bars,
    this.unit = '',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bar_chart_outlined, size: 16, color: _kInk2),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w700, color: _kInk),
                ),
              ),
              Row(
                children: const [
                  _LegendDot(color: _kSlate, label: 'Planned'),
                  SizedBox(width: 10),
                  _LegendDot(color: _kAmber, label: 'Actual'),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 160,
            child: CustomPaint(
              painter: _BarGroupPainter(bars: bars),
              child: Container(),
            ),
          ),
          const SizedBox(height: 6),
          // Value labels under each group
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: bars
                .map((b) => Expanded(
                      child: Column(
                        children: [
                          Text(
                            b.label,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: _kInk2),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${unit}${b.actual.toStringAsFixed(0)}',
                            style: const TextStyle(
                                fontSize: 10, color: _kAmberDark),
                          ),
                        ],
                      ),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label,
            style: const TextStyle(
                fontSize: 10, fontWeight: FontWeight.w600, color: _kInk2)),
      ],
    );
  }
}

class _BarGroupPainter extends CustomPainter {
  final List<({String label, double planned, double actual})> bars;
  _BarGroupPainter({required this.bars});

  @override
  void paint(Canvas canvas, Size size) {
    if (bars.isEmpty) return;
    final maxVal = bars.fold<double>(
        0, (m, b) => math.max(m, math.max(b.planned, b.actual)));
    if (maxVal <= 0) return;
    final groupWidth = size.width / bars.length;
    final barWidth = (groupWidth * 0.32).clamp(8.0, 32.0);
    final gap = barWidth * 0.3;
    final chartHeight = size.height - 4;

    for (var i = 0; i < bars.length; i++) {
      final b = bars[i];
      final groupCenter = groupWidth * i + groupWidth / 2;
      // Planned
      final plannedH = (b.planned / maxVal) * chartHeight;
      final plannedRect = Rect.fromLTWH(
        groupCenter - barWidth - gap / 2,
        chartHeight - plannedH,
        barWidth,
        plannedH,
      );
      canvas.drawRRect(
        RRect.fromRectAndCorners(plannedRect,
            topLeft: const Radius.circular(3), topRight: const Radius.circular(3)),
        Paint()..color = _kSlate,
      );
      // Actual
      final actualH = (b.actual / maxVal) * chartHeight;
      final actualRect = Rect.fromLTWH(
        groupCenter + gap / 2,
        chartHeight - actualH,
        barWidth,
        actualH,
      );
      canvas.drawRRect(
        RRect.fromRectAndCorners(actualRect,
            topLeft: const Radius.circular(3), topRight: const Radius.circular(3)),
        Paint()..color = _kAmber,
      );
    }
    // Baseline
    canvas.drawLine(
      Offset(0, chartHeight + 2),
      Offset(size.width, chartHeight + 2),
      Paint()..color = const Color(0xFFE5E7EB)..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(covariant _BarGroupPainter oldDelegate) =>
      oldDelegate.bars != bars;
}

// ─────────────────────────────────────────────────────────────────────────
// Radar Chart (Project Performance Review)
// ─────────────────────────────────────────────────────────────────────────

class LaunchRadarChart extends StatelessWidget {
  final String title;
  final List<({String axis, double value})> axes; // value 0..1
  final List<double>? target; // optional target ring per axis (0..1)

  const LaunchRadarChart({
    super.key,
    required this.title,
    required this.axes,
    this.target,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.radar_outlined, size: 16, color: _kInk2),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w700, color: _kInk),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 220,
            child: CustomPaint(
              painter: _RadarPainter(axes: axes, target: target),
              child: Container(),
            ),
          ),
        ],
      ),
    );
  }
}

class _RadarPainter extends CustomPainter {
  final List<({String axis, double value})> axes;
  final List<double>? target;
  _RadarPainter({required this.axes, this.target});

  @override
  void paint(Canvas canvas, Size size) {
    if (axes.length < 3) return;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 32;
    final n = axes.length;
    final ringPaint = Paint()
      ..color = const Color(0xFFE5E7EB)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    // Draw 4 concentric rings
    for (var r = 1; r <= 4; r++) {
      final ringRadius = radius * r / 4;
      final path = Path();
      for (var i = 0; i < n; i++) {
        final angle = -math.pi / 2 + (2 * math.pi * i / n);
        final p = Offset(
          center.dx + ringRadius * math.cos(angle),
          center.dy + ringRadius * math.sin(angle),
        );
        if (i == 0) {
          path.moveTo(p.dx, p.dy);
        } else {
          path.lineTo(p.dx, p.dy);
        }
      }
      path.close();
      canvas.drawPath(path, ringPaint);
    }
    // Axis spokes
    final spokePaint = Paint()
      ..color = const Color(0xFFE5E7EB)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (var i = 0; i < n; i++) {
      final angle = -math.pi / 2 + (2 * math.pi * i / n);
      final p = Offset(
        center.dx + radius * math.cos(angle),
        center.dy + radius * math.sin(angle),
      );
      canvas.drawLine(center, p, spokePaint);
    }
    // Target ring (optional)
    if (target != null && target!.length == n) {
      final targetPath = Path();
      for (var i = 0; i < n; i++) {
        final angle = -math.pi / 2 + (2 * math.pi * i / n);
        final r = radius * target![i].clamp(0.0, 1.0);
        final p = Offset(
          center.dx + r * math.cos(angle),
          center.dy + r * math.sin(angle),
        );
        if (i == 0) {
          targetPath.moveTo(p.dx, p.dy);
        } else {
          targetPath.lineTo(p.dx, p.dy);
        }
      }
      targetPath.close();
      canvas.drawPath(
          targetPath,
          Paint()
            ..color = _kPurple.withOpacity(0.7)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5
            ..strokeJoin = StrokeJoin.round);
    }
    // Value polygon (filled)
    final valuePath = Path();
    for (var i = 0; i < n; i++) {
      final angle = -math.pi / 2 + (2 * math.pi * i / n);
      final r = radius * axes[i].value.clamp(0.0, 1.0);
      final p = Offset(
        center.dx + r * math.cos(angle),
        center.dy + r * math.sin(angle),
      );
      if (i == 0) {
        valuePath.moveTo(p.dx, p.dy);
      } else {
        valuePath.lineTo(p.dx, p.dy);
      }
    }
    valuePath.close();
    canvas.drawPath(
        valuePath,
        Paint()
          ..color = _kAmber.withOpacity(0.25)
          ..style = PaintingStyle.fill);
    canvas.drawPath(
        valuePath,
        Paint()
          ..color = _kAmber
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeJoin = StrokeJoin.round);
    // Axis labels
    for (var i = 0; i < n; i++) {
      final angle = -math.pi / 2 + (2 * math.pi * i / n);
      final labelR = radius + 14;
      final p = Offset(
        center.dx + labelR * math.cos(angle),
        center.dy + labelR * math.sin(angle),
      );
      final tp = TextPainter(
        text: TextSpan(
          text: axes[i].axis,
          style: const TextStyle(
              fontSize: 10, fontWeight: FontWeight.w700, color: _kInk2),
        ),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      )..layout();
      tp.paint(canvas, Offset(p.dx - tp.width / 2, p.dy - tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(covariant _RadarPainter oldDelegate) =>
      oldDelegate.axes != axes;
}

// ─────────────────────────────────────────────────────────────────────────
// Mini Line Trend Chart
// ─────────────────────────────────────────────────────────────────────────

class LaunchTrendLineChart extends StatelessWidget {
  final String title;
  final List<double> planned;
  final List<double> actual;
  final String unit;

  const LaunchTrendLineChart({
    super.key,
    required this.title,
    required this.planned,
    required this.actual,
    this.unit = '',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.show_chart, size: 16, color: _kInk2),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w700, color: _kInk),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 110,
            child: CustomPaint(
              painter: _LineTrendPainter(planned: planned, actual: actual),
              child: Container(),
            ),
          ),
        ],
      ),
    );
  }
}

class _LineTrendPainter extends CustomPainter {
  final List<double> planned;
  final List<double> actual;
  _LineTrendPainter({required this.planned, required this.actual});

  @override
  void paint(Canvas canvas, Size size) {
    void drawLine(List<double> data, Color color, {bool fill = false}) {
      if (data.length < 2) return;
      final maxV = data.reduce(math.max);
      final minV = data.reduce(math.min);
      final range = (maxV - minV).abs() < 0.0001 ? 1.0 : (maxV - minV);
      final dx = size.width / (data.length - 1);
      final path = Path();
      for (var i = 0; i < data.length; i++) {
        final x = i * dx;
        final y = size.height - ((data[i] - minV) / range) * size.height;
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      if (fill) {
        final fillPath = Path.from(path)
          ..lineTo(size.width, size.height)
          ..lineTo(0, size.height)
          ..close();
        canvas.drawPath(
            fillPath, Paint()..color = color.withOpacity(0.18));
      }
      canvas.drawPath(
          path,
          Paint()
            ..color = color
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round);
    }

    drawLine(planned, _kSlate, fill: false);
    drawLine(actual, _kAmber, fill: true);
  }

  @override
  bool shouldRepaint(covariant _LineTrendPainter oldDelegate) =>
      oldDelegate.planned != planned || oldDelegate.actual != actual;
}

// ─────────────────────────────────────────────────────────────────────────
// Kanban Board (3 columns: To Do / In Progress / Done)
// ─────────────────────────────────────────────────────────────────────────

class LaunchKanbanBoard extends StatelessWidget {
  final String title;
  final List<LaunchKanbanCard> cards;

  const LaunchKanbanBoard({
    super.key,
    required this.title,
    required this.cards,
  });

  @override
  Widget build(BuildContext context) {
    final todo = cards
        .where((c) =>
            c.status.toLowerCase() == 'pending' ||
            c.status.toLowerCase() == 'to do' ||
            c.status.toLowerCase() == 'not started')
        .toList();
    final inProgress = cards
        .where((c) =>
            c.status.toLowerCase() == 'in progress' ||
            c.status.toLowerCase() == 'in review' ||
            c.status.toLowerCase() == 'review')
        .toList();
    final done = cards
        .where((c) =>
            c.status.toLowerCase() == 'complete' ||
            c.status.toLowerCase() == 'completed' ||
            c.status.toLowerCase() == 'done' ||
            c.status.toLowerCase() == 'approved')
        .toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.view_kanban_outlined, size: 16, color: _kInk2),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w700, color: _kInk),
              ),
              const Spacer(),
              Text(
                '${cards.length} item${cards.length == 1 ? "" : "s"}',
                style: const TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w700, color: _kMute),
              ),
            ],
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 760;
              if (isWide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _KanbanColumn(label: 'To Do', color: _kSlate, cards: todo)),
                    const SizedBox(width: 8),
                    Expanded(child: _KanbanColumn(label: 'In Progress', color: _kAmber, cards: inProgress)),
                    const SizedBox(width: 8),
                    Expanded(child: _KanbanColumn(label: 'Done', color: _kGreen, cards: done)),
                  ],
                );
              }
              return Column(
                children: [
                  _KanbanColumn(label: 'To Do', color: _kSlate, cards: todo),
                  const SizedBox(height: 8),
                  _KanbanColumn(label: 'In Progress', color: _kAmber, cards: inProgress),
                  const SizedBox(height: 8),
                  _KanbanColumn(label: 'Done', color: _kGreen, cards: done),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class LaunchKanbanCard {
  final String title;
  final String subtitle;
  final String status;
  final IconData? icon;
  final Color? accent;

  const LaunchKanbanCard({
    required this.title,
    required this.subtitle,
    required this.status,
    this.icon,
    this.accent,
  });
}

class _KanbanColumn extends StatelessWidget {
  final String label;
  final Color color;
  final List<LaunchKanbanCard> cards;
  const _KanbanColumn({required this.label, required this.color, required this.cards});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 2, 4, 8),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                ),
                const SizedBox(width: 6),
                Text(
                  '$label (${cards.length})',
                  style: const TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w700, color: _kInk2),
                ),
              ],
            ),
          ),
          if (cards.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
              child: const Center(
                child: Text('No items',
                    style: TextStyle(fontSize: 11, color: _kMute)),
              ),
            )
          else
            ...cards.map((c) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border(
                        left: BorderSide(
                            color: c.accent ?? color, width: 3),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.03),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            if (c.icon != null) ...[
                              Icon(c.icon, size: 12, color: c.accent ?? color),
                              const SizedBox(width: 4),
                            ],
                            Expanded(
                              child: Text(
                                c.title,
                                style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: _kInk),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        if (c.subtitle.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            c.subtitle,
                            style: const TextStyle(
                                fontSize: 10, color: _kInk2),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                )),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Donut Breakdown (for budget / cost distribution)
// ─────────────────────────────────────────────────────────────────────────

class LaunchDonutBreakdown extends StatelessWidget {
  final String title;
  final List<({String label, double value, Color color})> segments;
  final String centerLabel;
  final String centerValue;

  const LaunchDonutBreakdown({
    super.key,
    required this.title,
    required this.segments,
    required this.centerLabel,
    required this.centerValue,
  });

  @override
  Widget build(BuildContext context) {
    final total =
        segments.fold<double>(0, (s, e) => s + e.value);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.donut_small_outlined, size: 16, color: _kInk2),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w700, color: _kInk),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 420;
              final donutSize = 130.0;
              return isWide
                  ? Row(
                      children: [
                        SizedBox(
                          width: donutSize,
                          height: donutSize,
                          child: CustomPaint(
                            painter: _DonutSegmentPainter(
                                segments: segments, total: total),
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    centerValue,
                                    style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                        color: _kInk),
                                  ),
                                  Text(
                                    centerLabel,
                                    style: const TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w700,
                                        color: _kMute,
                                        letterSpacing: 0.6),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: segments.map((s) {
                              final pct = total == 0
                                  ? 0
                                  : (s.value / total * 100).round();
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 10,
                                      height: 10,
                                      decoration: BoxDecoration(
                                          color: s.color,
                                          shape: BoxShape.circle),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(s.label,
                                          style: const TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: _kInk2),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis),
                                    ),
                                    Text('$pct%',
                                        style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: _kInk)),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    )
                  : Column(
                      children: [
                        SizedBox(
                          width: donutSize,
                          height: donutSize,
                          child: CustomPaint(
                            painter: _DonutSegmentPainter(
                                segments: segments, total: total),
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(centerValue,
                                      style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w800,
                                          color: _kInk)),
                                  Text(centerLabel,
                                      style: const TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w700,
                                          color: _kMute,
                                          letterSpacing: 0.6)),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 12,
                          runSpacing: 4,
                          children: segments.map((s) {
                            final pct = total == 0
                                ? 0
                                : (s.value / total * 100).round();
                            return Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                      color: s.color, shape: BoxShape.circle),
                                ),
                                const SizedBox(width: 4),
                                Text('${s.label} $pct%',
                                    style: const TextStyle(
                                        fontSize: 10, color: _kInk2)),
                              ],
                            );
                          }).toList(),
                        ),
                      ],
                    );
            },
          ),
        ],
      ),
    );
  }
}

class _DonutSegmentPainter extends CustomPainter {
  final List<({String label, double value, Color color})> segments;
  final double total;
  _DonutSegmentPainter({required this.segments, required this.total});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 6;
    if (total <= 0) {
      canvas.drawCircle(
          center,
          radius,
          Paint()
            ..color = const Color(0xFFE5E7EB)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 16);
      return;
    }
    var startAngle = -math.pi / 2;
    for (final s in segments) {
      if (s.value <= 0) continue;
      final sweep = (s.value / total) * 2 * math.pi;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweep,
        false,
        Paint()
          ..color = s.color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 16
          ..strokeCap = StrokeCap.butt,
      );
      startAngle += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutSegmentPainter oldDelegate) =>
      oldDelegate.segments != segments || oldDelegate.total != total;
}

// ─────────────────────────────────────────────────────────────────────────
// Composed insights header — KPI row + donut side-by-side
// ─────────────────────────────────────────────────────────────────────────

class LaunchInsightsHeader extends StatelessWidget {
  final String sectionTitle;
  final String sectionSubtitle;
  final IconData sectionIcon;
  final Color sectionColor;
  final double completionPercent; // 0..1
  final String completionLabel;
  final String? completionCaption;
  final List<LaunchKpiTile> kpiTiles;

  const LaunchInsightsHeader({
    super.key,
    required this.sectionTitle,
    required this.sectionSubtitle,
    required this.sectionIcon,
    this.sectionColor = _kAmber,
    required this.completionPercent,
    required this.completionLabel,
    this.completionCaption,
    required this.kpiTiles,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            sectionColor.withOpacity(0.08),
            Colors.white,
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: sectionColor.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: sectionColor.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(sectionIcon, color: sectionColor, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      sectionTitle,
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: _kInk,
                          letterSpacing: -0.2),
                    ),
                    Text(
                      sectionSubtitle,
                      style: const TextStyle(
                          fontSize: 11, color: _kInk2, height: 1.4),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              LaunchProgressDonut(
                percent: completionPercent,
                centerLabel: completionLabel,
                caption: completionCaption,
                color: sectionColor,
                size: 92,
              ),
            ],
          ),
          const SizedBox(height: 12),
          LaunchKpiRow(tiles: kpiTiles),
        ],
      ),
    );
  }
}
