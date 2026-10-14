import 'package:flutter/material.dart';
import 'package:ndu_project/utils/agile_metrics_catalog.dart';

const Color _kBorder = Color(0xFFE5E7EB);
const Color _kMuted = Color(0xFF6B7280);
const Color _kHeadline = Color(0xFF111827);
const Color _kAccent = Color(0xFFF59E0B);
const Color _kAccentBg = Color(0xFFFEF3C7);

/// The dashboard's "what this page is measuring" panel: one chip per metric the
/// project tracks, read from Metrics Planning.
///
/// The review's complaint was that the dashboard "does not look like it's
/// driving any certain output" — every tile had a number with nothing behind
/// it. Presentational on purpose, so what the dashboard claims to track can be
/// tested without Firestore.
class AgileTrackedMetricsStrip extends StatelessWidget {
  const AgileTrackedMetricsStrip({
    super.key,
    required this.metrics,
    this.usingDefaults = false,
  });

  final List<AgileMetric> metrics;

  /// True when nobody has chosen a set, so this is the default. Said out loud
  /// rather than passing the defaults off as the user's decision.
  final bool usingDefaults;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('tracked-metrics-strip'),
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.insights, size: 16, color: _kAccent),
              SizedBox(width: 8),
              Text('Tracked metrics',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _kHeadline)),
              SizedBox(width: 8),
              Text('set in Metrics Planning',
                  style: TextStyle(fontSize: 11, color: _kMuted)),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            usingDefaults
                ? 'No metric set has been chosen yet, so the default tracking '
                    'set is shown. Change it in Metrics Planning.'
                : 'Everything below is measured from this set.',
            style: const TextStyle(fontSize: 11.5, color: _kMuted),
          ),
          const SizedBox(height: 12),
          if (metrics.isEmpty)
            const Text(
              'No metrics are selected, so the dashboard has nothing to report. '
              'Pick a set in Metrics Planning.',
              style: TextStyle(fontSize: 12, color: _kMuted),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [for (final metric in metrics) _chip(metric)],
            ),
        ],
      ),
    );
  }

  Widget _chip(AgileMetric metric) {
    return Tooltip(
      message: metric.description,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: metric.isBusiness ? const Color(0xFFF9FAFB) : _kAccentBg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: metric.isBusiness ? _kBorder : const Color(0xFFFDE68A),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(metric.label,
                style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: _kHeadline)),
            if (metric.isBusiness) ...[
              const SizedBox(width: 6),
              const Text('optional',
                  style: TextStyle(fontSize: 10, color: _kMuted)),
            ],
          ],
        ),
      ),
    );
  }
}
