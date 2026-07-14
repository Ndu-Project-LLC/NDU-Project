import 'package:flutter/material.dart';
import 'package:ndu_project/models/acceptance_criteria.dart';

class AcConfidenceScore extends StatelessWidget {
  final AcceptanceCriteriaTemplate template;
  final bool compact;

  const AcConfidenceScore({
    super.key,
    required this.template,
    this.compact = false,
  });

  Color _scoreColor(double score) {
    if (score >= 75) return const Color(0xFF10B981);
    if (score >= 50) return const Color(0xFFF59E0B);
    return const Color(0xFFEF4444);
  }

  String _scoreLabel(double score) {
    if (score >= 90) return 'Excellent';
    if (score >= 75) return 'Good';
    if (score >= 50) return 'Needs Work';
    if (score >= 25) return 'Poor';
    return 'Incomplete';
  }

  IconData _scoreIcon(double score) {
    if (score >= 75) return Icons.check_circle;
    if (score >= 50) return Icons.warning_amber_rounded;
    return Icons.error;
  }

  @override
  Widget build(BuildContext context) {
    final score = template.confidenceScore;
    final color = _scoreColor(score);
    final suggestions = template.improvementSuggestions;
    final requiredCount = template.criteria.where((c) => c.isRequired).length;
    final filledCount =
        template.criteria.where((c) => c.description.trim().length >= 10).length;

    if (compact) {
      return Tooltip(
        message: 'AC Confidence: ${score.toStringAsFixed(0)}% — ${_scoreLabel(score)}',
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(_scoreIcon(score), size: 12, color: color),
              const SizedBox(width: 4),
              Text(
                '${score.toStringAsFixed(0)}%',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(_scoreIcon(score), color: color, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${score.toStringAsFixed(0)}% Confidence',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                    ),
                    Text(
                      _scoreLabel(score),
                      style: TextStyle(fontSize: 13, color: color.withOpacity(0.8)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: score / 100,
              backgroundColor: color.withOpacity(0.12),
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _miniStat('Total', '${template.criteria.length}'),
              const SizedBox(width: 16),
              _miniStat('Required', requiredCount.toString()),
              const SizedBox(width: 16),
              _miniStat('Filled', filledCount.toString()),
            ],
          ),
          if (suggestions.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 8),
            const Text(
              'Improvement Suggestions',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 6),
            ...suggestions.take(3).map(
                  (s) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.lightbulb_outline,
                            size: 14, color: Color(0xFFF59E0B)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            s,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
          ],
        ],
      ),
    );
  }

  Widget _miniStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Color(0xFF111827),
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
        ),
      ],
    );
  }
}
