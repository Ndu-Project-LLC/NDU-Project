import 'package:flutter/material.dart';
import 'package:ndu_project/services/design_phase_service.dart';
import 'package:ndu_project/providers/project_data_provider.dart';

class DesignPhaseProgressIndicator extends StatelessWidget {
  const DesignPhaseProgressIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = ProjectDataInherited.maybeOf(context);
    final projectId = provider?.projectData.projectId;

    if (projectId == null || projectId.isEmpty) {
      return _buildFallbackIndicator();
    }

    return StreamBuilder<Map<String, dynamic>>(
      stream: DesignPhaseService.instance.calculateOverallProgress(projectId),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          debugPrint('Progress error: ${snapshot.error}');
          return _buildFallbackIndicator();
        }

        final data = snapshot.data ?? {};
        final progress = (data['progress'] as num?)?.toDouble() ?? 0.0;
        final completed = (data['completed'] as int?) ?? 0;
        final total = (data['total'] as int?) ?? 14;

        return _buildIndicator(progress, completed, total);
      },
    );
  }

  Widget _buildFallbackIndicator() {
    return _buildIndicator(0.0, 0, 14);
  }

  Widget _buildIndicator(double progress, int completed, int total) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.analytics,
                    color: Color(0xFF6366F1), size: 20),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Design Phase Completion',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              SizedBox(
                width: 60,
                height: 60,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CircularProgressIndicator(
                      value: progress,
                      strokeWidth: 6,
                      backgroundColor: const Color(0xFFF1F5F9),
                      valueColor: const AlwaysStoppedAnimation<Color>(
                          Color(0xFF6366F1)),
                    ),
                    Center(
                      child: Text(
                        '${(progress * 100).toInt()}%',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A1D1F),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$completed of $total',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    Text(
                      'sections approved',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: const Color(0xFFF1F5F9),
              valueColor:
                  const AlwaysStoppedAnimation<Color>(Color(0xFF6366F1)),
            ),
          ),
        ],
      ),
    );
  }
}
