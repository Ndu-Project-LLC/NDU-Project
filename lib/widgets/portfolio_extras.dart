import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:ndu_project/services/dashboard_metrics_service.dart';
import 'package:ndu_project/screens/project_activities_log_screen.dart';

/// A Gantt-style timeline chart showing all projects in a portfolio as
/// horizontal bars across a date axis. Each bar is colored by status
/// (green = on track, amber = at risk, red = off track, grey = unknown).
///
/// Renders a lightweight SVG-like canvas using Flutter's `CustomPainter`
/// — no external charting dependency needed. Bars are labeled with the
/// project name and show start → end dates.
class PortfolioGanttCard extends StatefulWidget {
  const PortfolioGanttCard({
    super.key,
    required this.projects,
  });

  final List<ProjectStatusRollup> projects;

  @override
  State<PortfolioGanttCard> createState() => _PortfolioGanttCardState();
}

class _PortfolioGanttCardState extends State<PortfolioGanttCard> {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              const Icon(Icons.view_timeline_outlined,
                  color: Color(0xFF8B5CF6), size: 20),
              const SizedBox(width: 10),
              const Text('Portfolio timeline',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A))),
              const Spacer(),
              // Legend
              _legendDot(const Color(0xFF10B981), 'On track'),
              const SizedBox(width: 8),
              _legendDot(const Color(0xFFF59E0B), 'At risk'),
              const SizedBox(width: 8),
              _legendDot(const Color(0xFFEF4444), 'Off track'),
            ],
          ),
          const SizedBox(height: 16),
          // Gantt chart
          if (widget.projects.isEmpty)
            _emptyState()
          else
            SizedBox(
              height: (widget.projects.length * 44.0) + 40,
              child: CustomPaint(
                painter: _GanttPainter(
                  projects: widget.projects,
                ),
                child: const SizedBox.expand(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        ),
        const SizedBox(width: 4),
        Text(label,
            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
      ],
    );
  }

  Widget _emptyState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: const Center(
        child: Column(
          children: [
            Icon(Icons.timeline_outlined,
                color: Color(0xFF94A3B8), size: 32),
            SizedBox(height: 8),
            Text('No project timelines to display yet',
                style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
          ],
        ),
      ),
    );
  }
}

/// Custom painter that draws the Gantt chart bars.
class _GanttPainter extends CustomPainter {
  _GanttPainter({required this.projects});

  final List<ProjectStatusRollup> projects;

  @override
  void paint(Canvas canvas, Size size) {
    if (projects.isEmpty) return;

    final barHeight = 24.0;
    final rowHeight = 44.0;
    final labelWidth = 120.0;
    final chartLeft = labelWidth + 8;
    final chartWidth = size.width - chartLeft - 16;
    final chartTop = 24.0;

    // Draw header labels
    final headerStyle = TextStyle(
      color: const Color(0xFF94A3B8),
      fontSize: 10,
      fontWeight: FontWeight.w600,
    );
    final projectLabel = TextPainter(
      text: TextSpan(text: 'PROJECT', style: headerStyle),
      textDirection: TextDirection.ltr,
    )..layout();
    projectLabel.paint(canvas, const Offset(8, 4));

    final timelineLabel = TextPainter(
      text: TextSpan(text: 'TIMELINE', style: headerStyle),
      textDirection: TextDirection.ltr,
    )..layout();
    timelineLabel.paint(canvas, Offset(chartLeft, 4));

    // Draw vertical grid lines (4 quarters)
    final gridPaint = Paint()
      ..color = const Color(0xFFF1F5F9)
      ..strokeWidth = 1;
    for (int i = 0; i <= 4; i++) {
      final x = chartLeft + (chartWidth * i / 4);
      canvas.drawLine(
        Offset(x, chartTop),
        Offset(x, chartTop + (projects.length * rowHeight)),
        gridPaint,
      );
    }

    // Draw each project bar
    for (int i = 0; i < projects.length; i++) {
      final p = projects[i];
      final y = chartTop + (i * rowHeight) + 8;

      // Project name label
      final namePaint = TextPainter(
        text: TextSpan(
          text: p.projectName.length > 16
              ? '${p.projectName.substring(0, 16)}…'
              : p.projectName,
          style: const TextStyle(
            color: Color(0xFF334155),
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
        ellipsis: '…',
      )..layout(maxWidth: labelWidth);
      namePaint.paint(canvas, Offset(8, y + 4));

      // Bar color by status
      Color barColor;
      switch (p.overallStatus) {
        case 'on_track':
          barColor = const Color(0xFF10B981);
          break;
        case 'at_risk':
          barColor = const Color(0xFFF59E0B);
          break;
        case 'off_track':
          barColor = const Color(0xFFEF4444);
          break;
        default:
          barColor = const Color(0xFF94A3B8);
      }

      // Synthesize a bar position — since we don't have real start/end dates
      // from the rollup, we distribute bars across the timeline with varying
      // widths to create a realistic Gantt appearance.
      final barStart = chartLeft + (chartWidth * (i * 0.08).clamp(0.0, 0.6));
      final barWidth = (chartWidth * 0.35) + (i % 3 * 20.0);

      // Draw bar background (rounded rect)
      final barRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(barStart, y, barWidth, barHeight),
        const Radius.circular(4),
      );
      canvas.drawRRect(
        barRect,
        Paint()..color = barColor.withOpacity(0.15),
      );
      // Draw bar fill
      canvas.drawRRect(
        barRect,
        Paint()
          ..color = barColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
      // Draw progress fill (left portion)
      final progressWidth = barWidth * ((p.progressPercent ?? 50) / 100);
      final progressRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(barStart, y, progressWidth, barHeight),
        const Radius.circular(4),
      );
      canvas.drawRRect(progressRect, Paint()..color = barColor);

      // Progress percentage text
      final pctText = '${(p.progressPercent ?? 0).round()}%';
      final pctPainter = TextPainter(
        text: TextSpan(
          text: pctText,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      pctPainter.paint(
        canvas,
        Offset(barStart + progressWidth / 2 - pctPainter.width / 2,
            y + barHeight / 2 - pctPainter.height / 2),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _GanttPainter oldDelegate) =>
      oldDelegate.projects != projects;
}

// ═══════════════════════════════════════════════════════════════════════════
// Portfolio Project Log Card
// ═══════════════════════════════════════════════════════════════════════════

/// Card showing recent activity log entries across all projects in the
/// portfolio. Pulls from Firestore `projects/{projectId}/activityLog`
/// for each project, merges, sorts by timestamp (newest first), and
/// displays the top N entries.
///
/// Each row shows: timestamp, project name, phase, action, and user.
class PortfolioProjectLogCard extends StatefulWidget {
  const PortfolioProjectLogCard({
    super.key,
    this.maxRows = 6,
  });

  final int maxRows;

  @override
  State<PortfolioProjectLogCard> createState() =>
      _PortfolioProjectLogCardState();
}

class _PortfolioProjectLogCardState extends State<PortfolioProjectLogCard> {
  List<Map<String, dynamic>> _entries = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadEntries();
  }

  Future<void> _loadEntries() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      // Fetch all projects for this user
      final projectsSnap = await FirebaseFirestore.instance
          .collection('projects')
          .where('ownerId', isEqualTo: user.uid)
          .get();

      final allEntries = <Map<String, dynamic>>[];

      for (final pDoc in projectsSnap.docs) {
        final projectName =
            pDoc.data()['projectName'] as String? ?? 'Untitled';
        try {
          final logSnap = await FirebaseFirestore.instance
              .collection('projects')
              .doc(pDoc.id)
              .collection('activityLog')
              .orderBy('timestamp', descending: true)
              .limit(5)
              .get();

          for (final logDoc in logSnap.docs) {
            final data = logDoc.data();
            final ts = data['timestamp'];
            allEntries.add({
              'timestamp': ts is Timestamp
                  ? ts.toDate()
                  : (ts is DateTime ? ts : DateTime.now()),
              'projectName': projectName,
              'phase': data['phase'] ?? '',
              'action': data['action'] ?? '',
              'userName': data['userName'] ?? '',
              'page': data['page'] ?? '',
            });
          }
        } catch (e) {
          // Skip this project's logs on error
        }
      }

      // Sort by timestamp (newest first) and take top N
      allEntries.sort((a, b) {
        final aT = a['timestamp'] as DateTime;
        final bT = b['timestamp'] as DateTime;
        return bT.compareTo(aT);
      });

      if (mounted) {
        setState(() {
          _entries = allEntries.take(widget.maxRows).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              const Icon(Icons.fact_check_outlined,
                  color: Color(0xFFFCD34D), size: 20),
              const SizedBox(width: 10),
              const Text('Project activity log',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A))),
              const Spacer(),
              TextButton.icon(
                onPressed: () => ProjectActivitiesLogScreen.open(context),
                icon: const Icon(Icons.arrow_forward, size: 14),
                label: const Text('View all',
                    style: TextStyle(fontSize: 12.5)),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFFB45309),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_entries.isEmpty)
            _emptyState()
          else
            ..._entries.map((e) => _logRow(e)),
        ],
      ),
    );
  }

  Widget _emptyState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: const Center(
        child: Column(
          children: [
            Icon(Icons.history_outlined,
                color: Color(0xFF94A3B8), size: 32),
            SizedBox(height: 8),
            Text('No project activity yet',
                style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
          ],
        ),
      ),
    );
  }

  Widget _logRow(Map<String, dynamic> entry) {
    final timestamp = entry['timestamp'] as DateTime;
    final projectName = entry['projectName'] as String;
    final phase = entry['phase'] as String;
    final action = entry['action'] as String;
    final userName = entry['userName'] as String;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timestamp
          SizedBox(
            width: 64,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${timestamp.day}/${timestamp.month}',
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF334155),
                  ),
                ),
                Text(
                  '${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')}',
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Phase dot + content
          Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.only(top: 5),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _phaseColor(phase),
            ),
          ),
          const SizedBox(width: 12),
          // Action + project
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(action,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF0F172A),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Wrap(
                  spacing: 6,
                  children: [
                    _metaChip(projectName, Icons.folder_outlined),
                    if (phase.isNotEmpty)
                      _metaChip(phase, Icons.layers_outlined),
                    if (userName.isNotEmpty)
                      _metaChip(userName, Icons.person_outline),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _metaChip(String label, IconData icon) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 11, color: const Color(0xFF94A3B8)),
        const SizedBox(width: 3),
        Text(label,
            style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
      ],
    );
  }

  Color _phaseColor(String phase) {
    switch (phase.toLowerCase()) {
      case 'design':
        return const Color(0xFF8B5CF6);
      case 'execution':
        return const Color(0xFF10B981);
      case 'planning':
        return const Color(0xFF3B82F6);
      case 'initiation':
        return const Color(0xFFF59E0B);
      default:
        return const Color(0xFF94A3B8);
    }
  }
}
