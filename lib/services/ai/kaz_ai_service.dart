/// KAZ AI Service — client-side service for AI calls.
///
/// In the Flutter app, AI calls go to a backend or use the ZAI SDK directly.
/// This service provides a clean interface with fallback responses when the
/// backend is unavailable.
///
/// NOTE: The z_ai_web_dev_sdk must be used server-side only. In a production
/// Flutter app, this service would call a backend API endpoint that uses the
/// SDK. For now, it returns deterministic fallback responses attributed to KAZ AI.

import 'dart:math';

class KAZAIService {
  static const String disclaimer =
      '⚠️ AI-generated content — validate with a qualified Subject Matter Expert before baseline.';

  /// Cost Estimate AI — 5 actions.
  static Future<Map<String, dynamic>> costEstimateAI({
    required String action,
    required String projectName,
    required String className,
    required String deliveryModel,
    required List<Map<String, dynamic>> existingLines,
    required Map<String, double> totals,
  }) async {
    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 800));

    // Deterministic fallback responses (attributed to KAZ AI)
    switch (action) {
      case 'feed':
        return {
          'suggestions': [
            {
              'category': 'labor',
              'subCategory': 'Project Manager',
              'description': 'Project management — full project duration',
              'quantity': 480,
              'unit': 'hours',
              'rate': 145,
              'rationale': 'PMO coverage for the project lifecycle',
            },
            {
              'category': 'projectTeam',
              'subCategory': 'PMO Support',
              'description': 'PMO administrative support',
              'quantity': 200,
              'unit': 'hours',
              'rate': 85,
              'rationale': 'Indirect PMO cost not in schedule',
            },
            {
              'category': 'contingency',
              'subCategory': 'General Contingency',
              'description': 'Contingency for $className estimate maturity',
              'quantity': 1,
              'unit': 'lump',
              'rate': (totals['costBaseline'] ?? 0 * 0.1).round(),
              'rationale': '10% contingency typical for this estimate class',
            },
            {
              'category': 'ssher',
              'subCategory': 'Safety Program',
              'description': 'Safety, health & environmental compliance',
              'quantity': 1,
              'unit': 'lump',
              'rate': 8500,
              'rationale': 'SSHER often not in schedule',
            },
            {
              'category': 'quality',
              'subCategory': 'QA/QC',
              'description': 'Quality assurance & control activities',
              'quantity': 120,
              'unit': 'hours',
              'rate': 110,
              'rationale': 'Quality management coverage',
            },
          ],
          'disclaimer': disclaimer,
          'source': 'KAZ AI',
          'action': action,
          'usedFallback': true,
        };
      case 'reduce':
        return {
          'suggestions': [
            {
              'title': 'Right-size contingency',
              'description':
                  'Review contingency against actual risk register; reduce if risks have mitigations.',
              'estimatedSavings': '2-5% of baseline',
              'riskLevel': 'MED',
            },
            {
              'title': 'Consolidate software licenses',
              'description':
                  'Audit SaaS subscriptions for overlap; consolidate where possible.',
              'estimatedSavings': '\$2K-8K',
              'riskLevel': 'LOW',
            },
            {
              'title': 'Use reserved cloud instances',
              'description':
                  'Switch from on-demand to reserved instances for steady-state workloads.',
              'estimatedSavings': '15-30% on infra',
              'riskLevel': 'LOW',
            },
            {
              'title': 'Reduce travel via remote reviews',
              'description':
                  'Convert in-person design reviews to remote where feasible.',
              'estimatedSavings': '\$5K-15K',
              'riskLevel': 'LOW',
            },
          ],
          'disclaimer': disclaimer,
          'source': 'KAZ AI',
          'action': action,
          'usedFallback': true,
        };
      case 'gaps':
        return {
          'suggestions': [
            {
              'category': 'Project Team (PMO)',
              'reason': 'No PMO/PM costs visible',
              'suggestedAction': 'Add Project Manager and PMO support as indirect costs',
            },
            {
              'category': 'Quality Management',
              'reason': 'No QA/QC line',
              'suggestedAction': 'Add quality management hours',
            },
            {
              'category': 'Risk Allowances',
              'reason': 'No risk allowances from risk register',
              'suggestedAction': 'Quantify top risks and add allowances',
            },
            {
              'category': 'Escalation & Inflation',
              'reason': 'No escalation for long-duration project',
              'suggestedAction': 'Add labor/material escalation',
            },
            {
              'category': 'Management Reserve',
              'reason': 'No management reserve',
              'suggestedAction': 'Add 5-10% reserve outside baseline',
            },
          ],
          'disclaimer': disclaimer,
          'source': 'KAZ AI',
          'action': action,
          'usedFallback': true,
        };
      case 'rates':
        return {
          'suggestions': [
            {
              'role': 'Senior Developer',
              'low': 95,
              'mostLikely': 130,
              'high': 175,
              'currency': 'USD',
              'rationale': 'Industry-average range; validate with current market data.',
            },
          ],
          'disclaimer': disclaimer,
          'source': 'KAZ AI',
          'action': action,
          'usedFallback': true,
        };
      case 'validate':
        return {
          'suggestions': [
            {
              'overallAssessment':
                  'Estimate has direct costs but may be missing indirect, SSHER/Quality, and reserve components.',
              'strengths': ['Direct costs are itemized'],
              'concerns': [
                'Verify indirect costs (PMO) are included',
                'Confirm SSHER & Quality coverage',
                'Ensure management reserve is outside baseline',
              ],
              'recommendations': [
                "Run the 'Find gaps' action",
                'Add contingency appropriate to estimate class',
              ],
            },
          ],
          'disclaimer': disclaimer,
          'source': 'KAZ AI',
          'action': action,
          'usedFallback': true,
        };
      default:
        return {
          'suggestions': [],
          'disclaimer': disclaimer,
          'source': 'KAZ AI',
          'action': action,
          'usedFallback': true,
        };
    }
  }

  /// WBS AI — 3 actions (suggest, expand, validate).
  static Future<Map<String, dynamic>> wbsAI({
    required String action,
    required String projectName,
    required String framework,
    required String frameworkLabel,
    required String level1Label,
    required String level2Label,
    String? industry,
    String? region,
    String? siteContext,
    List<Map<String, dynamic>>? existingNodes,
    Map<String, dynamic>? targetNode,
  }) async {
    await Future.delayed(const Duration(milliseconds: 800));

    switch (action) {
      case 'suggest':
        return {
          'suggestions': [
            {
              'name': 'Engineering & Design',
              'description': 'Engineering deliverables and design packages',
              'aiSource': 'GLOBAL',
              'aiReference': 'Standard engineering deliverables across industries globally',
              'aiConfidence': 'HIGH',
              'children': [
                {
                  'name': 'Process Design Package',
                  'description': 'Process flow diagrams and P&IDs',
                  'aiSource': 'GLOBAL',
                  'aiReference': 'Industry standard',
                  'aiConfidence': 'HIGH',
                },
                {
                  'name': 'Detailed Engineering',
                  'description': 'Discipline-specific detailed design',
                  'aiSource': 'GLOBAL',
                  'aiReference': 'Industry standard',
                  'aiConfidence': 'HIGH',
                },
                {
                  'name': 'Design Reviews',
                  'description': 'HAZOP, HSE, constructability reviews',
                  'aiSource': 'GLOBAL',
                  'aiReference': 'Industry standard',
                  'aiConfidence': 'MED',
                },
              ],
            },
            {
              'name': 'Procurement',
              'description': 'Equipment and material procurement',
              'aiSource': 'GLOBAL',
              'aiReference': 'Standard procurement breakdown globally',
              'aiConfidence': 'HIGH',
              'children': [
                {
                  'name': 'Long-Lead Equipment',
                  'description': 'Long-lead item procurement',
                  'aiSource': 'GLOBAL',
                  'aiReference': 'Industry standard',
                  'aiConfidence': 'HIGH',
                },
                {
                  'name': 'Bulk Materials',
                  'description': 'Bulk material procurement',
                  'aiSource': 'GLOBAL',
                  'aiReference': 'Industry standard',
                  'aiConfidence': 'HIGH',
                },
                {
                  'name': 'Vendor Management',
                  'description': 'Vendor selection and management',
                  'aiSource': 'GLOBAL',
                  'aiReference': 'Industry standard',
                  'aiConfidence': 'MED',
                },
              ],
            },
            {
              'name': 'Construction',
              'description': 'Site construction and installation',
              'aiSource': 'GLOBAL',
              'aiReference': 'Standard construction breakdown globally',
              'aiConfidence': 'HIGH',
              'children': [
                {
                  'name': 'Site Preparation',
                  'description': 'Site readiness and ground works',
                  'aiSource': 'GLOBAL',
                  'aiReference': 'Industry standard',
                  'aiConfidence': 'HIGH',
                },
                {
                  'name': 'Civil & Structural',
                  'description': 'Civil and structural works',
                  'aiSource': 'GLOBAL',
                  'aiReference': 'Industry standard',
                  'aiConfidence': 'HIGH',
                },
                {
                  'name': 'Mechanical Installation',
                  'description': 'Equipment installation',
                  'aiSource': 'GLOBAL',
                  'aiReference': 'Industry standard',
                  'aiConfidence': 'MED',
                },
              ],
            },
            {
              'name': 'Commissioning',
              'description': 'Testing and commissioning',
              'aiSource': 'GLOBAL',
              'aiReference': 'Standard commissioning breakdown globally',
              'aiConfidence': 'HIGH',
              'children': [
                {
                  'name': 'Pre-Commissioning',
                  'description': 'Pre-commissioning checks',
                  'aiSource': 'GLOBAL',
                  'aiReference': 'Industry standard',
                  'aiConfidence': 'HIGH',
                },
                {
                  'name': 'System Commissioning',
                  'description': 'System commissioning activities',
                  'aiSource': 'GLOBAL',
                  'aiReference': 'Industry standard',
                  'aiConfidence': 'HIGH',
                },
                {
                  'name': 'Performance Testing',
                  'description': 'Performance guarantee testing',
                  'aiSource': 'GLOBAL',
                  'aiReference': 'Industry standard',
                  'aiConfidence': 'MED',
                },
              ],
            },
            {
              'name': 'Project Management',
              'description': 'Project management and controls',
              'aiSource': 'GLOBAL',
              'aiReference': 'Standard PM breakdown globally',
              'aiConfidence': 'HIGH',
              'children': [
                {
                  'name': 'Project Controls',
                  'description': 'Schedule and cost control',
                  'aiSource': 'GLOBAL',
                  'aiReference': 'Industry standard',
                  'aiConfidence': 'HIGH',
                },
                {
                  'name': 'Quality Management',
                  'description': 'Quality assurance and control',
                  'aiSource': 'GLOBAL',
                  'aiReference': 'Industry standard',
                  'aiConfidence': 'HIGH',
                },
                {
                  'name': 'HSE Management',
                  'description': 'Health, safety, and environment',
                  'aiSource': 'GLOBAL',
                  'aiReference': 'Industry standard',
                  'aiConfidence': 'HIGH',
                },
              ],
            },
          ],
          'disclaimer': disclaimer,
          'source': 'KAZ AI',
          'action': action,
          'usedFallback': true,
        };
      case 'expand':
        return {
          'suggestions': [
            {
              'name': 'Sub-Deliverable A',
              'description': 'First sub-component',
              'aiSource': 'GLOBAL',
              'aiReference': 'Typical decomposition',
              'aiConfidence': 'MED',
            },
            {
              'name': 'Sub-Deliverable B',
              'description': 'Second sub-component',
              'aiSource': 'GLOBAL',
              'aiReference': 'Typical decomposition',
              'aiConfidence': 'MED',
            },
            {
              'name': 'Sub-Deliverable C',
              'description': 'Third sub-component',
              'aiSource': 'GLOBAL',
              'aiReference': 'Typical decomposition',
              'aiConfidence': 'MED',
            },
          ],
          'disclaimer': disclaimer,
          'source': 'KAZ AI',
          'action': action,
          'usedFallback': true,
        };
      case 'validate':
        return {
          'suggestions': [
            {
              'overallAssessment':
                  'WBS structure appears reasonable. Validate node counts and naming conventions.',
              'strengths': ['Framework choice is appropriate'],
              'concerns': [
                'Verify each Level 1 has at least 2 Level 2 children',
                'Confirm deliverable-focused naming',
              ],
              'recommendations': [
                'Run the built-in Validator for automated checks',
              ],
            },
          ],
          'disclaimer': disclaimer,
          'source': 'KAZ AI',
          'action': action,
          'usedFallback': true,
        };
      default:
        return {
          'suggestions': [],
          'disclaimer': disclaimer,
          'source': 'KAZ AI',
          'action': action,
          'usedFallback': true,
        };
    }
  }
}
