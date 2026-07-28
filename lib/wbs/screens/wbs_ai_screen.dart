library;

/// WBS AI Screen — 3 AI actions (suggest, expand, validate) with global/regional/local context.
///
/// Rendered inside the parent [ResponsiveScaffold]'s TabBarView, so this widget
/// returns its content directly (no Scaffold) with a white background.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ndu_project/theme.dart';
import 'package:ndu_project/wbs/models/wbs_models.dart';
import 'package:ndu_project/wbs/providers/wbs_provider.dart';
import 'package:ndu_project/services/ai/kaz_ai_service.dart';

class WBSAIScreen extends StatefulWidget {
  const WBSAIScreen({super.key});

  @override
  State<WBSAIScreen> createState() => _WBSAIScreenState();
}

class _WBSAIScreenState extends State<WBSAIScreen> {
  String? _activeAction;
  bool _loading = false;
  List<Map<String, dynamic>> _suggestions = [];
  final Set<int> _selectedIndices = {};
  String _disclaimer = '';
  bool _usedFallback = false;

  final _industryCtrl = TextEditingController();
  final _regionCtrl = TextEditingController();
  final _siteContextCtrl = TextEditingController();

  final _actions = [
    (
      'suggest',
      'Suggest WBS split',
      Icons.auto_awesome,
      'Full Level 1 + Level 2 from global/regional/local projects',
      LightModeColors.accent
    ),
    (
      'expand',
      'Expand a node',
      Icons.search,
      'Level 2 children for a selected Level 1 node',
      const Color(0xFFFBBF24)
    ),
    (
      'validate',
      'Validate WBS',
      Icons.shield,
      'Review against best practices',
      const Color(0xFF8B5CF6)
    ),
  ];

  @override
  void dispose() {
    _industryCtrl.dispose();
    _regionCtrl.dispose();
    _siteContextCtrl.dispose();
    super.dispose();
  }

  Future<void> _runAction(String action) async {
    final wbs = context.read<WBSProvider>().wbs;
    if (wbs == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('WBS not initialized yet. Please try again.')),
        );
      }
      return;
    }
    final frameworkMeta = wbs.framework;

    setState(() {
      _activeAction = action;
      _loading = true;
      _suggestions = [];
    });

    // Build existing nodes for context
    final existingNodes = <Map<String, dynamic>>[
      {
        'code': wbs.level0.code,
        'name': wbs.level0.name,
        'level': 0,
      },
      ...wbs.level0.children.map((l1) => {
            'code': l1.code,
            'name': l1.name,
            'level': 1,
            'description': l1.description,
          }),
      ...wbs.level0.children.expand((l1) => l1.children.map((l2) => {
            'code': l2.code,
            'name': l2.name,
            'level': 2,
            'description': l2.description,
          })),
    ];

    try {
      final result = await KAZAIService.wbsAI(
        action: action,
        projectName: wbs.projectName,
        framework: wbs.framework.name,
        frameworkLabel: frameworkMeta.label,
        level1Label: frameworkMeta.level1Label,
        level2Label: frameworkMeta.level2Label,
        industry: _industryCtrl.text.trim().isEmpty
            ? null
            : _industryCtrl.text.trim(),
        region:
            _regionCtrl.text.trim().isEmpty ? null : _regionCtrl.text.trim(),
        siteContext: _siteContextCtrl.text.trim().isEmpty
            ? null
            : _siteContextCtrl.text.trim(),
        existingNodes: existingNodes,
      );

      setState(() {
        _suggestions =
            (result['suggestions'] as List?)?.cast<Map<String, dynamic>>() ??
                [];
        _disclaimer = result['disclaimer'] ?? '';
        _usedFallback = result['usedFallback'] ?? false;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _disclaimer = '⚠️ AI service unavailable.';
        _loading = false;
      });
    }
  }

  void _applySuggestion(Map<String, dynamic> s) {
    final provider = context.read<WBSProvider>();
    final wbs = provider.wbs;
    if (wbs == null) return;
    if (wbs.level0.children.length >= 3) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Maximum 3 top-level WBS items. Remove one first to add another.'),
            backgroundColor: Color(0xFFEF4444),
          ),
        );
      }
      return;
    }
    final l1Id = provider.addChildNode(
      wbs.level0.id,
      s['name'] as String? ?? '',
      s['description'] as String?,
    );
    if (l1Id.isNotEmpty) {
      provider.updateNode(
        l1Id,
        WBSNode(
          id: l1Id,
          level: WBSLevel.level1,
          code: '',
          name: s['name'] as String? ?? '',
          description: s['description'] as String?,
          aiGenerated: true,
          aiSource: s['aiSource'] != null
              ? AISource.values.byName(s['aiSource'] as String)
              : null,
          aiConfidence: s['aiConfidence'] != null
              ? AIConfidence.values.byName(s['aiConfidence'] as String)
              : null,
          aiReference: s['aiReference'] as String?,
          children: const [],
        ),
      );
      final children = s['children'] as List?;
      if (children != null) {
        for (final child in children) {
          final c = child as Map<String, dynamic>;
          final l2Id = provider.addChildNode(
            l1Id,
            c['name'] as String? ?? '',
            c['description'] as String?,
          );
          if (l2Id.isNotEmpty) {
            provider.updateNode(
              l2Id,
              WBSNode(
                id: l2Id,
                level: WBSLevel.level2,
                code: '',
                name: c['name'] as String? ?? '',
                description: c['description'] as String?,
                aiGenerated: true,
                aiSource: c['aiSource'] != null
                    ? AISource.values.byName(c['aiSource'] as String)
                    : null,
                aiConfidence: c['aiConfidence'] != null
                    ? AIConfidence.values.byName(c['aiConfidence'] as String)
                    : null,
                aiReference: c['aiReference'] as String?,
                children: const [],
              ),
            );
          }
        }
      }
    }
    setState(() {
      _suggestions.removeWhere((item) => item['name'] == s['name']);
    });
  }

  void _applySelectedSuggestions() {
    final provider = context.read<WBSProvider>();
    final wbs = provider.wbs;
    if (wbs == null) return;

    final selected = _selectedIndices.toList()..sort((a, b) => b - a);
    for (final idx in selected) {
      if (idx < _suggestions.length) {
        final s = _suggestions[idx];
        if (wbs.level0.children.length >= 3) break;
        final l1Id = provider.addChildNode(
          wbs.level0.id,
          s['name'] as String? ?? '',
          s['description'] as String?,
        );
        if (l1Id.isNotEmpty) {
          provider.updateNode(
            l1Id,
            WBSNode(
              id: l1Id,
              level: WBSLevel.level1,
              code: '',
              name: s['name'] as String? ?? '',
              description: s['description'] as String?,
              aiGenerated: true,
              aiSource: s['aiSource'] != null
                  ? AISource.values.byName(s['aiSource'] as String)
                  : null,
              aiConfidence: s['aiConfidence'] != null
                  ? AIConfidence.values.byName(s['aiConfidence'] as String)
                  : null,
              aiReference: s['aiReference'] as String?,
              children: const [],
            ),
          );
          final children = s['children'] as List?;
          if (children != null) {
            for (final child in children) {
              final c = child as Map<String, dynamic>;
              final l2Id = provider.addChildNode(
                l1Id,
                c['name'] as String? ?? '',
                c['description'] as String?,
              );
              if (l2Id.isNotEmpty) {
                provider.updateNode(
                  l2Id,
                  WBSNode(
                    id: l2Id,
                    level: WBSLevel.level2,
                    code: '',
                    name: c['name'] as String? ?? '',
                    description: c['description'] as String?,
                    aiGenerated: true,
                    children: const [],
                  ),
                );
              }
            }
          }
        }
      }
    }
    setState(() {
      for (final idx in selected) {
        if (idx < _suggestions.length) {
          _suggestions.removeAt(idx);
        }
      }
      _selectedIndices.clear();
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
                  const Text('AI WBS Generator',
                      style: TextStyle(
                          color: Color(0xFF1A1D1F),
                          fontSize: 20,
                          fontWeight: FontWeight.bold)),
                ],
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFBBF24).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text('KAZ AI',
                    style: TextStyle(
                        color: Color(0xFFFBBF24),
                        fontSize: 11,
                        fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Disclaimer
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: LightModeColors.accent.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: LightModeColors.accent.withValues(alpha: 0.4)),
            ),
            child: Row(
              children: [
                const Icon(Icons.warning_amber,
                    color: LightModeColors.accent, size: 16),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'All AI-generated WBS nodes must be validated by a qualified SME before baseline.',
                    style: TextStyle(color: Color(0xFF6B7280), fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Context inputs
          Container(
            padding: const EdgeInsets.all(16),
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.location_on,
                        color: LightModeColors.accent, size: 14),
                    SizedBox(width: 6),
                    Text('PROJECT CONTEXT (IMPROVES AI SUGGESTIONS)',
                        style: TextStyle(
                            color: LightModeColors.accent,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1)),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildTextField('Industry', _industryCtrl,
                          'e.g. Manufacturing, Oil & Gas'),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildTextField('Region', _regionCtrl,
                          'e.g. East Africa, Southeast Asia'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _buildTextField('Site-specific context', _siteContextCtrl,
                    'e.g. Greenfield site, existing grid connection...',
                    maxLines: 3),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Action grid
          Row(
            children: _actions.map((a) {
              final isActive = _activeAction == a.$1;
              return Expanded(
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  child: Material(
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
                            color: isActive ? a.$5 : const Color(0xFFE4E7EC),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.03),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Icon(a.$3, color: a.$5, size: 20),
                            const SizedBox(height: 8),
                            Text(a.$2,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                    color: Color(0xFF1A1D1F),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600)),
                            const SizedBox(height: 2),
                            Text(a.$4,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                    color: Color(0xFF6B7280), fontSize: 11)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
          // Loading
          if (_loading)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(48),
                child: Column(
                  children: [
                    const CircularProgressIndicator(
                        color: LightModeColors.accent),
                    const SizedBox(height: 12),
                    const Text('KAZ AI is analyzing similar projects...',
                        style:
                            TextStyle(color: Color(0xFF6B7280), fontSize: 13)),
                  ],
                ),
              ),
            ),
          // Results
          if (!_loading && _suggestions.isNotEmpty) ...[
            if (_usedFallback)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFE4E7EC)),
                ),
                child: const Text(
                  '⚠️ Used KAZ AI fallback response (live model unavailable).',
                  style: TextStyle(color: Color(0xFF6B7280), fontSize: 11),
                ),
              ),
            ..._suggestions
                .asMap()
                .entries
                .map((e) => _buildSuggestionCard(e.key, e.value)),
            if (_disclaimer.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(top: 12),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: LightModeColors.accent.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                      color: LightModeColors.accent.withValues(alpha: 0.4)),
                ),
                child: Text(_disclaimer,
                    style: const TextStyle(
                        color: Color(0xFFD97706), fontSize: 12)),
              ),
          ],
          // Empty state when no results and not loading
          if (!_loading && _suggestions.isEmpty && _activeAction != null) ...[
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE4E7EC)),
              ),
              child: const Column(
                children: [
                  Icon(Icons.lightbulb_outline,
                      color: Color(0xFF9CA3AF), size: 32),
                  SizedBox(height: 8),
                  Text('No suggestions returned for this action.',
                      style: TextStyle(color: Color(0xFF6B7280), fontSize: 13)),
                  SizedBox(height: 4),
                  Text('Try refining the project context inputs above.',
                      style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 12)),
                ],
              ),
            ),
          ],
          if (!_loading && _activeAction == null) ...[
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE4E7EC)),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.tips_and_updates,
                          color: LightModeColors.accent, size: 18),
                      SizedBox(width: 8),
                      Text('How the AI WBS Generator works',
                          style: TextStyle(
                              color: Color(0xFF1A1D1F),
                              fontSize: 15,
                              fontWeight: FontWeight.w700)),
                    ],
                  ),
                  SizedBox(height: 8),
                  Text(
                    'KAZ AI compares your project against historical global, regional, and local projects. The more context you provide (industry, region, site-specific notes), the more accurate the suggested Level 1 / Level 2 decomposition.',
                    style: TextStyle(color: Color(0xFF6B7280), fontSize: 13),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Pick one of the three actions above to begin. Suggestions appear as cards — review, then click "Add to WBS" to merge them into your tree.',
                    style: TextStyle(color: Color(0xFF6B7280), fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController ctrl, String hint,
      {int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(),
            style: const TextStyle(
                color: Color(0xFF6B7280),
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8)),
        const SizedBox(height: 4),
        TextField(
          controller: ctrl,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
            filled: true,
            fillColor: Colors.white,
            isDense: true,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFE4E7EC))),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(
                    color: LightModeColors.accent, width: 1.6)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFE4E7EC))),
          ),
          style: const TextStyle(color: Color(0xFF1A1D1F), fontSize: 14),
        ),
      ],
    );
  }

  Widget _buildSuggestionCard(int index, Map<String, dynamic> s) {
    final children =
        (s['children'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final aiSource = s['aiSource'] as String?;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Level 1 node
          Row(
            children: [
              Checkbox(
                value: _selectedIndices.contains(index),
                onChanged: (checked) {
                  setState(() {
                    if (checked == true) {
                      _selectedIndices.add(index);
                    } else {
                      _selectedIndices.remove(index);
                    }
                  });
                },
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(s['name'] as String? ?? '',
                              style: const TextStyle(
                                  color: Color(0xFF1A1D1F),
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600)),
                        ),
                        if (aiSource != null) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFBBF24)
                                  .withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(aiSource.toUpperCase(),
                                style: const TextStyle(
                                    color: Color(0xFFFBBF24),
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ],
                    ),
                    if (s['description'] != null)
                      Text(s['description'] as String,
                          style: const TextStyle(
                              color: Color(0xFF6B7280), fontSize: 13)),
                    if (s['aiReference'] != null)
                      Row(
                        children: [
                          const Icon(Icons.auto_awesome,
                              size: 10, color: LightModeColors.accent),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(s['aiReference'] as String,
                                style: const TextStyle(
                                    color: Color(0xFF9CA3AF),
                                    fontSize: 11,
                                    fontStyle: FontStyle.italic)),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ],
          ),
          // Level 2 children
          if (children.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              margin: const EdgeInsets.only(left: 44),
              padding: const EdgeInsets.only(left: 16),
              decoration: const BoxDecoration(
                border: Border(
                  left: BorderSide(color: Color(0xFFE4E7EC), width: 1),
                ),
              ),
              child: Column(
                children: children.map((c) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF3F4F6),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Center(
                            child: Text('L2',
                                style: TextStyle(
                                    color: Color(0xFF6B7280),
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(c['name'] as String? ?? '',
                              style: const TextStyle(
                                  color: Color(0xFF1A1D1F),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500)),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
          // Apply single button
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              onPressed: () {
                _applySuggestion(s);
                setState(() => _selectedIndices.remove(index));
              },
              icon: const Icon(Icons.add, size: 14),
              label: const Text('Add Single'),
              style: OutlinedButton.styleFrom(
                foregroundColor: LightModeColors.accent,
                side: const BorderSide(color: LightModeColors.accent),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
