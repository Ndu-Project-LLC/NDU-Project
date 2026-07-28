library;

/// AI Assistant Screen — 5 AI actions powered by KAZ AI.
///
/// Actions: Auto-feed costs, Suggest rates, Reduce costs, Find gaps, Validate
/// estimate. Every suggestion carries the mandatory "validate with SME"
/// disclaimer.
///
/// Rendered inside the Cost Estimate module's [ResponsiveScaffold] body —
/// no Scaffold of its own. Light-mode (white) theme.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ndu_project/theme.dart';
import 'package:ndu_project/cost_estimate/models/cost_estimate_models.dart';
import 'package:ndu_project/cost_estimate/providers/cost_estimate_provider.dart';
import 'package:ndu_project/cost_estimate/providers/compute_utils.dart';
import 'package:ndu_project/services/ai/kaz_ai_service.dart';

class AIAssistantScreen extends StatefulWidget {
  const AIAssistantScreen({super.key});

  @override
  State<AIAssistantScreen> createState() => _AIAssistantScreenState();
}

class _AIAssistantScreenState extends State<AIAssistantScreen> {
  String? _activeAction;
  bool _loading = false;
  List<Map<String, dynamic>> _suggestions = [];
  String _disclaimer = '';
  bool _usedFallback = false;

  final _actions = [
    ('feed', 'Auto-feed costs', Icons.auto_awesome,
        'Propose cost lines from project context', LightModeColors.accent),
    ('rates', 'Suggest rates', Icons.trending_up,
        'Rate range for a role/industry', const Color(0xFFFBBF24)),
    ('reduce', 'Reduce costs', Icons.shield,
        '3-5 cost-reduction levers', const Color(0xFF16A34A)),
    ('gaps', 'Find gaps', Icons.search,
        'Missing cost categories', const Color(0xFFD97706)),
    ('validate', 'Validate estimate', Icons.warning_amber,
        'Review completeness & risk', const Color(0xFF8B5CF6)),
  ];

  Future<void> _runAction(String action) async {
    final estimate = context.read<CostEstimateProvider>().estimate!;
    setState(() {
      _activeAction = action;
      _loading = true;
      _suggestions = [];
    });

    try {
      final result = await KAZAIService.costEstimateAI(
        action: action,
        projectName: estimate.projectName,
        className: estimate.className.name,
        deliveryModel: estimate.deliveryModel.name,
        existingLines: estimate.lines
            .map((l) => {
                  'category': l.category.name,
                  'subCategory': l.subCategory,
                  'description': l.description,
                  'total': l.total,
                  'inSchedule': l.inSchedule,
                })
            .toList(),
        totals: {
          'direct': estimate.totals.direct,
          'indirect': estimate.totals.indirect,
          'sherQuality': estimate.totals.sherQuality,
          'costBaseline': estimate.totals.costBaseline,
          'managementReserve': estimate.totals.managementReserve,
        },
      );

      setState(() {
        _suggestions = (result['suggestions'] as List?)?.cast<Map<String, dynamic>>() ?? [];
        _disclaimer = result['disclaimer'] ?? '';
        _usedFallback = result['usedFallback'] ?? false;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _disclaimer = '⚠️ AI service unavailable. Please try again.';
        _loading = false;
      });
    }
  }

  void _applyLineSuggestion(Map<String, dynamic> s) {
    final provider = context.read<CostEstimateProvider>();
    final category = CostCategory.values.byName(
        (s['category'] as String?)?.toLowerCase() ?? 'labor');
    final qty = (s['quantity'] as num?)?.toDouble() ?? 1;
    final rate = (s['rate'] as num?)?.toDouble() ?? 0;
    provider.addLine(CostLine(
      id: newId('line'),
      category: category,
      subCategory: (s['subCategory'] as String?) ?? '',
      description: (s['description'] as String?) ?? '',
      quantity: qty,
      unit: (s['unit'] as String?) ?? 'units',
      rate: rate,
      total: qty * rate,
      inSchedule: false,
      basisSource: CostSourceType.kazAI,
      basisReference: 'KAZ AI',
      aiGenerated: true,
      confidence: Confidence.med,
    ));
    setState(() {
      _suggestions.removeWhere((item) => item['description'] == s['description']);
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.auto_awesome,
                      color: LightModeColors.accent, size: 20),
                  const SizedBox(width: 8),
                  const Text(
                    'AI Assistant',
                    style: TextStyle(
                        color: Color(0xFF1A1D1F),
                        fontSize: 20,
                        fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFBBF24).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'KAZ AI',
                  style: TextStyle(
                    color: Color(0xFFFBBF24),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Powered by KAZ AI. All suggestions are editable, dismissible, and require SME validation.',
            style: TextStyle(color: Color(0xFF6B7280), fontSize: 13),
          ),
          const SizedBox(height: 16),
          // Persistent disclaimer
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: LightModeColors.accent.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: LightModeColors.accent.withValues(alpha: 0.3)),
            ),
            child: const Row(
              children: [
                Icon(Icons.warning_amber,
                    color: LightModeColors.accent, size: 18),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'All AI-generated content must be validated by a qualified Subject Matter Expert before being used in a baseline estimate.',
                    style: TextStyle(color: Color(0xFF495057), fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // Action grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 2.5,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: _actions.length,
            itemBuilder: (ctx, i) {
              final a = _actions[i];
              final isActive = _activeAction == a.$1;
              return Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _loading ? null : () => _runAction(a.$1),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isActive
                          ? a.$5.withValues(alpha: 0.08)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isActive
                            ? a.$5
                            : const Color(0xFFE4E7EC),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Icon(a.$3, color: a.$5, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                a.$2,
                                style: const TextStyle(
                                  color: Color(0xFF1A1D1F),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                a.$4,
                                style: const TextStyle(
                                    color: Color(0xFF6B7280),
                                    fontSize: 12),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 24),
          // Loading
          if (_loading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(48),
                child: Column(
                  children: [
                    CircularProgressIndicator(color: LightModeColors.accent),
                    SizedBox(height: 12),
                    Text('KAZ AI is analyzing your estimate...',
                        style:
                            TextStyle(color: Color(0xFF6B7280), fontSize: 13)),
                  ],
                ),
              ),
            ),
          // Results
          if (!_loading && _suggestions.isNotEmpty) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${_suggestions.length} suggestions from KAZ AI',
                  style: const TextStyle(
                      color: Color(0xFF1A1D1F),
                      fontSize: 15,
                      fontWeight: FontWeight.bold),
                ),
                TextButton(
                  onPressed: () => setState(() => _suggestions = []),
                  child: const Text('Clear',
                      style: TextStyle(color: Color(0xFF6B7280))),
                ),
              ],
            ),
            if (_usedFallback)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  '⚠️ Used KAZ AI fallback response (live model unavailable).',
                  style: TextStyle(color: Color(0xFF6B7280), fontSize: 11),
                ),
              ),
            ...(_suggestions.map((s) => _buildSuggestionCard(s))),
            if (_disclaimer.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(top: 12),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: LightModeColors.accent.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                      color: LightModeColors.accent.withValues(alpha: 0.3)),
                ),
                child: Text(_disclaimer,
                    style: const TextStyle(
                        color: Color(0xFFD97706), fontSize: 12)),
              ),
          ],
          // Empty state
          if (!_loading && _suggestions.isEmpty && _activeAction == null)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(48),
                child: Column(
                  children: [
                    const Icon(Icons.lightbulb,
                        color: LightModeColors.accent, size: 48),
                    const SizedBox(height: 16),
                    const Text(
                      'Pick an action to start',
                      style: TextStyle(
                          color: Color(0xFF1A1D1F),
                          fontSize: 15,
                          fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'KAZ AI can propose cost lines, suggest rates, find gaps, propose savings, and validate your estimate.',
                      style: TextStyle(color: Color(0xFF6B7280), fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSuggestionCard(Map<String, dynamic> s) {
    final isLine = s.containsKey('category') && s.containsKey('quantity');
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE4E7EC)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: LightModeColors.accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.add_circle,
                color: LightModeColors.accent, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        s['description'] ?? s['title'] ?? s['category'] ?? 'Suggestion',
                        style: const TextStyle(
                          color: Color(0xFF1A1D1F),
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFBBF24).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'KAZ AI',
                        style: TextStyle(
                          color: Color(0xFFFBBF24),
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                if (s['rationale'] != null || s['detail'] != null)
                  Text(
                    s['rationale'] ?? s['detail'] ?? '',
                    style:
                        const TextStyle(color: Color(0xFF495057), fontSize: 12),
                  ),
                if (s['meta'] != null || s['estimatedSavings'] != null)
                  Text(
                    s['meta'] ?? 'Savings: ${s['estimatedSavings']}',
                    style:
                        const TextStyle(color: Color(0xFF6B7280), fontSize: 12),
                  ),
              ],
            ),
          ),
          if (isLine)
            FilledButton(
              onPressed: () => _applyLineSuggestion(s),
              style: FilledButton.styleFrom(
                backgroundColor: LightModeColors.accent,
                foregroundColor: LightModeColors.lightOnPrimary,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              ),
              child: const Text('Add', style: TextStyle(fontSize: 12)),
            ),
        ],
      ),
    );
  }
}
