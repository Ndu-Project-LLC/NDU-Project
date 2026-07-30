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
import 'package:ndu_project/services/openai_service_secure.dart';

class WBSAIScreen extends StatefulWidget {
  const WBSAIScreen({super.key});

  @override
  State<WBSAIScreen> createState() => _WBSAIScreenState();
}

class _WBSAIScreenState extends State<WBSAIScreen> {
  String? _activeAction;
  bool _loading = false;
  List<Map<String, dynamic>> _suggestions = [];
  String _disclaimer = '';
  bool _usedFallback = false;

  final _industryCtrl = TextEditingController();
  final _regionCtrl = TextEditingController();
  final _siteContextCtrl = TextEditingController();

  final _actions = [
    ('suggest', 'Suggest WBS split', Icons.auto_awesome,
        'Full Level 1 + Level 2 from global/regional/local projects',
        LightModeColors.accent),
    ('expand', 'Expand a node', Icons.search,
        'Level 2 children for a selected Level 1 node',
        const Color(0xFF3B82F6)),
    ('validate', 'Validate WBS', Icons.shield,
        'Review against best practices', const Color(0xFF8B5CF6)),
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
          const SnackBar(content: Text('WBS not initialized yet. Please try again.')),
        );
      }
      return;
    }
    final fm = wbs.framework;

    setState(() {
      _activeAction = action;
      _loading = true;
      _suggestions = [];
      _disclaimer = '';
      _usedFallback = false;
    });

    try {
      String prompt;
      switch (action) {
        case 'suggest':
          prompt = _buildSuggestPrompt(wbs, fm);
          break;
        case 'expand':
          prompt = _buildExpandPrompt(wbs, fm);
          break;
        case 'validate':
          prompt = _buildValidatePrompt(wbs, fm);
          break;
        default:
          return;
      }

      const maxRetries = 3;
      String result = '';
      for (int attempt = 1; attempt <= maxRetries; attempt++) {
        try {
          result = await OpenAiServiceSecure().generateCompletion(
            prompt,
            maxTokens: 1200,
            temperature: 0.7,
          );
          break;
        } catch (e) {
          if (attempt == maxRetries) rethrow;
          await Future.delayed(Duration(seconds: 2 * attempt));
        }
      }

      if (!mounted) return;

      final suggestions = _parseSuggestResponse(result, action, wbs);
      setState(() {
        _suggestions = suggestions;
        _disclaimer = suggestions.isEmpty
            ? 'Could not generate suggestions. Try refining your inputs.'
            : 'Review all AI-generated nodes before adding to your WBS.';
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('AI generation failed: $e'),
            backgroundColor: const Color(0xFFEF4444),
            action: SnackBarAction(
              label: 'Try Again',
              textColor: Colors.white,
              onPressed: () => _runAction(action),
            ),
          ),
        );
      }
      setState(() {
        _disclaimer = '⚠️ AI service unavailable.';
        _loading = false;
      });
    }
  }

  String _buildSuggestPrompt(WBS wbs, WBSFramework fm) {
    final existingNames =
        wbs.level0.children.map((n) => n.name).join(', ');
    final industry = _industryCtrl.text.trim();
    final region = _regionCtrl.text.trim();
    final siteContext = _siteContextCtrl.text.trim();

    return '''
You are a WBS expert. Generate 3-5 Level 1 ${fm.level1Label} nodes with Level 2 ${fm.level2Label} children for a project.

Project: "${wbs.projectName}"
Framework: ${fm.label}
Level 1 label: ${fm.level1Label}
Level 2 label: ${fm.level2Label}
Level 3 label: ${fm.level3Label}
Methodology: ${wbs.methodology.label}
${industry.isNotEmpty ? 'Industry: $industry' : ''}
${region.isNotEmpty ? 'Region: $region' : ''}
${siteContext.isNotEmpty ? 'Site context: $siteContext' : ''}
${existingNames.isNotEmpty ? 'Existing nodes: $existingNames' : ''}

Output format — one suggestion block per level 1 node:

#1: Node Name|Level 1 node description
  #1.1: Child Name|Child description
  #1.2: Child Name|Child description
#2: Node Name|Level 1 node description
  #2.1: Child Name|Child description

Guidelines:
- Use deliverable-based names (nouns not verbs)
- Be specific to the project industry and context
- Each Level 1 node should have 2-4 Level 2 children
- Suggest 3-5 Level 1 nodes
''';
  }

  String _buildExpandPrompt(WBS wbs, WBSFramework fm) {
    final existingNames =
        wbs.level0.children.map((n) => n.name).join(', ');
    final industry = _industryCtrl.text.trim();
    final siteContext = _siteContextCtrl.text.trim();

    return '''
You are a WBS expert. The project has these Level 1 ${fm.level1Label} nodes: $existingNames

Suggest how to expand one of them into Level 2 ${fm.level2Label} children.

Project: "${wbs.projectName}"
Framework: ${fm.label}
Level 2 label: ${fm.level2Label}
Level 3 label: ${fm.level3Label}
Methodology: ${wbs.methodology.label}
${industry.isNotEmpty ? 'Industry: $industry' : ''}
${siteContext.isNotEmpty ? 'Site context: $siteContext' : ''}

Output format — one line per suggested level 2 node:
NodeName|Description
NodeName|Description

Suggest 3-5 Level 2 nodes. Use deliverable-based names.
''';
  }

  String _buildValidatePrompt(WBS wbs, WBSFramework fm) {
    final treeLines = <String>[];
    void flatten(WBSNode node, int depth) {
      treeLines.add('${'  ' * depth}[${node.code}] ${node.name}'
          '${node.description != null ? ': ${node.description}' : ''}');
      for (final c in node.children) {
        flatten(c, depth + 1);
      }
    }
    flatten(wbs.level0, 0);

    return '''
You are a WBS validation expert. Assess this WBS against best practices (V1-V8 rules).

Project: "${wbs.projectName}"
Framework: ${fm.label}
Methodology: ${wbs.methodology.label}

WBS Tree:
${treeLines.join('\n')}

Provide validation results in this format:
Score: X/10
Strengths:
+ Strength one per line
+ Strength two per line
Issues:
- Issue one per line
- Issue two per line
Recommendations:
* Recommendation one per line
* Recommendation two per line

Then list action items:
---
Action Item Name|Description of the action item
---
Action Item Name|Description of the action item
''';
  }

  List<Map<String, dynamic>> _parseSuggestResponse(
      String text, String action, WBS wbs) {
    final suggestions = <Map<String, dynamic>>[];
    final lines = text.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();

    if (action == 'suggest') {
      Map<String, dynamic>? currentSuggestion;
      for (final line in lines) {
        final l1Match = RegExp(r'^#\d+:\s*(.+?)\|(.+)$').firstMatch(line);
        if (l1Match != null) {
          if (currentSuggestion != null) {
            suggestions.add(currentSuggestion);
          }
          currentSuggestion = {
            'name': l1Match.group(1)!.trim(),
            'description': l1Match.group(2)!.trim(),
            'children': <Map<String, dynamic>>[],
          };
          continue;
        }
        final l2Match = RegExp(r'^#\d+\.\d+:\s*(.+?)(?:\|(.+))?$').firstMatch(line);
        if (l2Match != null && currentSuggestion != null) {
          (currentSuggestion['children'] as List<Map<String, dynamic>>).add({
            'name': l2Match.group(1)!.trim(),
            if (l2Match.group(2) != null) 'description': l2Match.group(2)!.trim(),
          });
        }
      }
      if (currentSuggestion != null) {
        suggestions.add(currentSuggestion);
      }
    } else if (action == 'expand') {
      for (final line in lines) {
        final parts = line.split('|');
        if (parts.length >= 2) {
          suggestions.add({
            'name': parts[0].trim(),
            'description': parts.sublist(1).join('|').trim(),
            'children': <Map<String, dynamic>>[],
          });
        }
      }
    } else if (action == 'validate') {
      final actionItems = <String>[];
      bool inActionItems = false;
      for (final line in lines) {
        if (line.startsWith('---')) {
          inActionItems = true;
          continue;
        }
        if (inActionItems) {
          actionItems.add(line);
        }
      }
      for (final item in actionItems) {
        final parts = item.split('|');
        suggestions.add({
          'name': parts.isNotEmpty ? parts[0].trim() : 'Action item',
          'description': parts.length >= 2 ? parts.sublist(1).join('|').trim() : 'Validation finding',
          'children': <Map<String, dynamic>>[],
        });
      }
      if (suggestions.isEmpty) {
        final scoreMatch = RegExp(r'Score:\s*(\d+)/10').firstMatch(text);
        suggestions.add({
          'name': 'WBS Validation',
          'description': scoreMatch != null
              ? 'Validation score: ${scoreMatch.group(1)}/10'
              : 'Validation complete',
          'children': <Map<String, dynamic>>[],
        });
      }
    }

    return suggestions;
  }

  void _applySuggestion(Map<String, dynamic> s) {
    final provider = context.read<WBSProvider>();
    final wbs = provider.wbs;
    if (wbs == null) return;
    if (wbs.level0.children.length >= 3) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Maximum 3 top-level WBS items. Remove one first to add another.'),
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
              const Row(
                children: [
                  Icon(Icons.auto_awesome,
                      color: LightModeColors.accent, size: 20),
                  SizedBox(width: 8),
                  Text('AI WBS Generator',
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
                  color: const Color(0xFF22C55E).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text('AI',
                    style: TextStyle(
                        color: Color(0xFF22C55E),
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
            child: const Row(
              children: [
                Icon(Icons.warning_amber,
                    color: LightModeColors.accent, size: 16),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'All AI-generated WBS nodes must be validated by a qualified SME before baseline.',
                    style: TextStyle(
                        color: Color(0xFF6B7280), fontSize: 13),
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
                      child: _buildTextField(
                          'Industry', _industryCtrl,
                          'e.g. Manufacturing, Oil & Gas'),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildTextField(
                          'Region', _regionCtrl,
                          'e.g. East Africa, Southeast Asia'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _buildTextField(
                    'Site-specific context', _siteContextCtrl,
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
                                    color: Color(0xFF6B7280),
                                    fontSize: 11)),
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
            const Center(
              child: Padding(
                padding: EdgeInsets.all(48),
                child: Column(
                  children: [
                    CircularProgressIndicator(
                        color: LightModeColors.accent),
                    const SizedBox(height: 12),
                    const Text('Generating suggestions...',
                        style:
                            TextStyle(color: Color(0xFF6B7280), fontSize: 13)),
                  ],
                ),
              ),
            ),
          // Results
          if (!_loading && _suggestions.isNotEmpty) ...[
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
                      color: LightModeColors.accent
                          .withValues(alpha: 0.4)),
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
                      style:
                          TextStyle(color: Color(0xFF6B7280), fontSize: 13)),
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
                    'AI generates WBS suggestions based on your project context. The more context you provide (industry, region, site-specific notes), the more accurate the suggested Level 1 / Level 2 decomposition.',
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

  Widget _buildTextField(
      String label, TextEditingController ctrl, String hint,
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

  Widget _buildSuggestionCard(Map<String, dynamic> s) {
    final children = (s['children'] as List?)?.cast<Map<String, dynamic>>() ?? [];
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
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: LightModeColors.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Center(
                  child: Text('L1',
                      style: TextStyle(
                          color: Color(0xFFD97706),
                          fontSize: 11,
                          fontWeight: FontWeight.bold)),
                ),
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
                              color: const Color(0xFF3B82F6)
                                  .withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(aiSource.toUpperCase(),
                                style: const TextStyle(
                                    color: Color(0xFF3B82F6),
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
          // Apply button
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: () => _applySuggestion(s),
              icon: const Icon(Icons.add, size: 14),
              label: const Text('Add to WBS'),
              style: FilledButton.styleFrom(
                backgroundColor: LightModeColors.accent,
                foregroundColor: LightModeColors.lightOnPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
