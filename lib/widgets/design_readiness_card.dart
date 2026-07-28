import 'package:flutter/material.dart';
import 'package:ndu_project/models/design_phase_models.dart';

class DesignReadinessCard extends StatelessWidget {
  final DesignReadinessModel readiness;

  const DesignReadinessCard({
    super.key,
    required this.readiness,
  });

  @override
  Widget build(BuildContext context) {
    // Determine overall color based on score
    Color scoreColor = Colors.red;
    if (readiness.overallScore >= 0.8) {
      scoreColor = Colors.green;
    } else if (readiness.overallScore >= 0.5) {
      scoreColor = Colors.orange;
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'DESIGN READINESS',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${(readiness.overallScore * 100).toInt()}%',
                    style: TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.w800,
                      color: scoreColor,
                      height: 1.0,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _getReadinessLabel(readiness.overallScore),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: scoreColor,
                    ),
                  ),
                ],
              ),
              SizedBox(
                height: 80,
                width: 80,
                child: Stack(
                  children: [
                    Center(
                      child: SizedBox(
                        height: 80,
                        width: 80,
                        child: CircularProgressIndicator(
                          value: readiness.overallScore,
                          strokeWidth: 8,
                          backgroundColor: Colors.grey.shade100,
                          valueColor: AlwaysStoppedAnimation<Color>(scoreColor),
                        ),
                      ),
                    ),
                    Center(
                      child: Icon(
                        _getReadinessIcon(readiness.overallScore),
                        size: 32,
                        color: scoreColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 16),

          // Breakdown Grid
          Row(
            children: [
              Expanded(
                  child: _buildScoreItem(
                      'Requirements', readiness.specificationsScore)),
              Expanded(
                  child:
                      _buildScoreItem('Alignment', readiness.alignmentScore)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                  child: _buildScoreItem(
                      'Architecture', readiness.architectureScore)),
              Expanded(
                  child:
                      _buildScoreItem('Risk Mitigation', readiness.riskScore)),
            ],
          ),

          if (readiness.missingItems.isNotEmpty) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade100),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.warning_amber_rounded,
                          size: 16, color: Colors.red.shade700),
                      const SizedBox(width: 8),
                      Text(
                        'Blocking items',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.red.shade800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ...readiness.missingItems.take(3).map((item) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          '• $item',
                          style: TextStyle(
                              fontSize: 12, color: Colors.red.shade800),
                        ),
                      )),
                  if (readiness.missingItems.length > 3)
                    Text(
                      '+ ${readiness.missingItems.length - 3} more items',
                      style: TextStyle(
                          fontSize: 11,
                          color: Colors.red.shade600,
                          fontStyle: FontStyle.italic),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildScoreItem(String label, double score) {
    Color barColor = Colors.grey;
    if (score >= 0.8) {
      barColor = Colors.green;
    } else if (score >= 0.5) barColor = Colors.orange;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: const TextStyle(fontSize: 11, color: Colors.grey)),
            Text('${(score * 100).toInt()}%',
                style:
                    const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 4),
        LinearProgressIndicator(
          value: score,
          backgroundColor: Colors.grey.shade100,
          valueColor: AlwaysStoppedAnimation<Color>(barColor),
          minHeight: 4,
          borderRadius: BorderRadius.circular(2),
        ),
      ],
    );
  }

  String _getReadinessLabel(double score) {
    if (score >= 0.9) return 'Ready for Execution';
    if (score >= 0.7) return 'Nearing Completion';
    if (score >= 0.4) return 'In Progress';
    return 'Early Stages';
  }

  IconData _getReadinessIcon(double score) {
    if (score >= 0.9) return Icons.rocket_launch;
    if (score >= 0.7) return Icons.check_circle_outline;
    if (score >= 0.4) return Icons.construction;
    return Icons.design_services;
  }
}
