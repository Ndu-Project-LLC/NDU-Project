import 'package:flutter/material.dart';
import 'package:ndu_project/models/project_data_model.dart';
import 'package:ndu_project/providers/project_data_provider.dart';
import 'package:ndu_project/services/quality_intelligence_service.dart';

/// Quality Intelligence Integration for KAZ AI
/// 
/// Provides methods to integrate quality analysis capabilities into the KAZ AI chat.
/// Detects quality-related queries and generates intelligent responses with full rationale.
class QualityAiIntegration {
  /// Check if a user message is asking about quality
  static bool isQualityQuery(String message) {
    final lower = message.toLowerCase();
    final qualityKeywords = [
      // Direct quality mentions
      'quality', 'qa', 'qc', 'quality assurance', 'quality control',
      'defect', 'bug', 'error', 'issue', 'rework',
      'standard', 'compliance', 'audit', 'inspection',
      'test', 'testing', 'acceptance criteria',
      'kpi', 'metric', 'measurement',
      'risk', 'quality risk',
      'improvement', 'best practice',
      // Specific quality questions
      'missing requirement', 'gap', 'what\'s wrong',
      'recommend', 'suggest', 'should i add',
      'how to improve', 'better quality',
    ];
    
    return qualityKeywords.any((keyword) => lower.contains(keyword));
  }

  /// Check if user wants a comprehensive quality analysis
  static bool isQualityAnalysisRequest(String message) {
    final lower = message.toLowerCase();
    final analysisTriggers = [
      'analyze quality', 'quality analysis', 'quality report',
      'quality check', 'review my quality', 'quality assessment',
      'quality health', 'quality status', 'how is my quality',
      'run quality', 'start quality', 'quality intelligence',
      'show me quality', 'tell me about quality',
    ];
    
    return analysisTriggers.any((trigger) => lower.contains(trigger));
  }

  /// Generate a quality-focused system prompt enhancement for AI context
  static String generateQualityContextEnhancement(ProjectDataModel projectData) {
    final qualityData = projectData.qualityManagementData;
    if (qualityData == null) return '';

    final report = QualityIntelligenceService.generateFullReport(
      projectData: projectData,
      qualityData: qualityData,
    );

    return '''
## Quality Intelligence Context Available

You have access to quality intelligence data for this project. When users ask about quality, 
you can reference these findings:

${QualityIntelligenceService.buildAiContextSummary(report)}

### How to Use This Information:
1. When users ask about quality issues, reference specific findings from above
2. Always explain the **rationale** behind each recommendation (best practices, industry standards)
3. Suggest **specific actions** they can take based on the recommendations
4. Reference supporting data where available (e.g., "Your audit completion rate is X% vs Y% target")
5. If they ask for detailed analysis, suggest opening the Quality Intelligence Report dialog

### Available Quality Commands:
- "Analyze my quality" - Shows full quality intelligence report
- "What quality risks do I have?" - Lists identified quality risks  
- "Recommend quality KPIs" - Suggests relevant metrics to track
- "What standards apply?" - Lists applicable industry standards
- "Find gaps in my quality plan" - Identifies missing requirements and gaps
''';
  }

  /// Generate a direct response for quality analysis requests
  static String? generateDirectQualityResponse(String message, ProjectDataModel projectData) {
    if (!isQualityAnalysisRequest(message)) return null;

    final qualityData = projectData.qualityManagementData;
    if (qualityData == null) {
      return null; // Let the normal AI handle it
    }

    final report = QualityIntelligenceService.generateFullReport(
      projectData: projectData,
      qualityData: qualityData,
    );

    return _formatQualityAnalysisResponse(report);
  }

  static String _formatQualityAnalysisResponse(QualityIntelligenceReport report) {
    final buffer = StringBuffer();

    buffer.writeln('## 🔍 Quality Intelligence Analysis');
    buffer.writeln('');
    buffer.writeln('**Project**: ${report.projectName}');
    buffer.writeln('**Type**: ${report.projectType} | **Industry**: ${report.industry}');
    buffer.writeln('');

    // Critical items first
    if (report.criticalItems.isNotEmpty) {
      buffer.writeln('### 🚨 Critical Items Requiring Immediate Attention');
      buffer.writeln('');
      for (final item in report.criticalItems) {
        buffer.writeln('**${item.title}**');
        buffer.writeln('- ${item.description}');
        buffer.writeln('- 💡 *Action*: ${item.suggestedAction}');
        buffer.writeln('');
      }
      buffer.writeln('');
    }

    // Summary of findings by category
    buffer.writeln('### 📊 Findings Summary');
    buffer.writeln('');
    buffer.writeln('| Category | Count |');
    buffer.writeln('|----------|-------|');
    report.findingsByType.forEach((key, value) {
      buffer.writeln('| $key | $value |');
    });
    buffer.writeln('');

    // Priority breakdown
    buffer.writeln('### 🎯 Priority Breakdown');
    buffer.writeln('');
    buffer.writeln('- 🔴 **Critical**: ${report.findingsByPriority['Critical']} item(s)');
    buffer.writeln('- 🟠 **High**: ${report.findingsByPriority['High']} item(s)');
    buffer.writeln('- 🟡 **Medium**: ${report.findingsByPriority['Medium']} item(s)');
    buffer.writeln('- 🟢 **Low**: ${report.findingsByPriority['Low']} item(s)');
    buffer.writeln('');

    // Top recommendations
    if (report.missingRequirements.isNotEmpty) {
      buffer.writeln('### ⚠️ Top Missing Requirements');
      buffer.writeln('');
      for (final req in report.missingRequirements.take(3)) {
        buffer.writeln('- **${req.title}** [${req.priority.name}]');
        buffer.writeln('  - ${req.suggestedAction}');
      }
      buffer.writeln('');
    }

    if (report.qualityRisks.isNotEmpty) {
      buffer.writeln('### 🎯 Key Quality Risks');
      buffer.writeln('');
      for (final risk in report.qualityRisks.take(3)) {
        buffer.writeln('- **${risk.title}** [${risk.priority.name}]');
        buffer.writeln('  - ${risk.rationale.substring(0, risk.rationale.length.clamp(0, 150))}...');
      }
      buffer.writeln('');
    }

    // Recommended KPIs highlight
    if (report.recommendedKpis.isNotEmpty) {
      buffer.writeln('### 📈 Recommended KPIs to Track');
      buffer.writeln('');
      for (final kpi in report.recommendedKpis.take(5)) {
        buffer.writeln('- **${kpi.title}**: ${kpi.suggestedAction.split(':').last.trim()}');
      }
      buffer.writeln('');
    }

    buffer.writeln('---');
    buffer.writeln('');
    buffer.writeln('*Tap **View Full Report** to see all details with complete rationales.*');

    return buffer.toString();
  }

  /// Get quick action suggestions for quality improvement
  static List<Map<String, String>> getQuickQualityActions(QualityIntelligenceReport report) {
    final actions = <Map<String, String>>[];

    // Add top priority actions from findings
    for (final finding in report.allRecommendations) {
      if (finding.priority == Priority.critical || finding.priority == Priority.high) {
        actions.add({
          'title': finding.title,
          'action': finding.suggestedAction,
          'type': finding.type.name,
          'priority': finding.priority.name,
        });
      }
    }

    // Sort by priority (critical first)
    actions.sort((a, b) {
      final order = {'critical': 0, 'high': 1, 'medium': 2, 'low': 3};
      return (order[a['priority']] ?? 4).compareTo(order[b['priority']] ?? 4);
    });

    return actions.take(8).toList();
  }

  /// Build a markdown summary of quality status for dashboard widgets
  static String buildDashboardSummary(QualityIntelligenceReport report) {
    final score = _calculateQualityScore(report);
    final scoreEmoji = score >= 80 ? '✅' : score >= 60 ? '⚠️' : '🚨';

    return '''
$scoreEmoji **Quality Score: ${score.round()}/100**

**${report.totalFindings} findings** (${report.criticalItems.length} critical)

- Missing Requirements: ${report.missingRequirements.length}
- Quality Risks: ${report.qualityRisks.length}
- Gaps Detected: ${report.acceptanceCriteriaGaps.length}
- Recommended KPIs: ${report.recommendedKpis.length}
''';
  }

  static int _calculateQualityScore(QualityIntelligenceReport report) {
    // Start at 100, deduct for issues
    int score = 100;

    // Deduct for critical items (15 points each)
    score -= report.findingsByPriority['Critical']! * 15;
    
    // Deduct for high priority items (8 points each)
    score -= report.findingsByPriority['High']! * 8;
    
    // Deduct for medium priority items (3 points each)
    score -= report.findingsByPriority['Medium']! * 3;

    // Bonus for having objectives defined
    if (report.acceptanceCriteriaGaps.every((g) => !g.id.contains('no_quality_objectives'))) {
      score += 5;
    }

    return score.clamp(0, 100);
  }
}

/// Quick Action Chip for quality suggestions in chat UI
class QualityQuickActionChip extends StatelessWidget {
  const QualityQuickActionChip({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
    this.color,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final defaultColor = color ?? const Color(0xFFB8860B);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: defaultColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: defaultColor.withOpacity(0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: defaultColor),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: defaultColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Pre-defined quality quick actions for the chat interface
class QualityQuickActions {
  static List<Map<String, dynamic>> getActions() => [
    {
      'label': '🔍 Analyze Quality',
      'icon': Icons.analytics_outlined,
      'command': 'Analyze my quality',
      'description': 'Run full quality intelligence analysis',
    },
    {
      'label': '⚠️ Quality Risks',
      'icon': Icons.warning_amber_outlined,
      'command': 'What quality risks do I have?',
      'description': 'Identify potential quality issues',
    },
    {
      'label': '📊 Recommend KPIs',
      'icon': Icons.speed_outlined,
      'command': 'Recommend quality KPIs',
      'description': 'Get personalized KPI suggestions',
    },
    {
      'label': '📋 Standards Check',
      'icon': Icons.verified_user_outlined,
      'command': 'What standards apply?',
      'description': 'See applicable quality standards',
    },
    {
      'label': '🔍 Find Gaps',
      'icon': Icons.find_in_page_outlined,
      'command': 'Find gaps in my quality plan',
      'description': 'Identify missing requirements',
    },
  ];
}
