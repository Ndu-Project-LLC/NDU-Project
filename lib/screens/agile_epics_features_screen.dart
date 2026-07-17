import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ndu_project/models/epic_model.dart';
import 'package:ndu_project/models/feature_model.dart';
import 'package:ndu_project/providers/project_data_provider.dart';
import 'package:ndu_project/services/epic_feature_service.dart';
import 'package:ndu_project/services/openai_service_secure.dart';
import 'package:ndu_project/wbs/models/wbs_models.dart';
import 'package:ndu_project/wbs/providers/wbs_provider.dart';
import 'package:ndu_project/wbs/services/wbs_agile_sync_service.dart';
import 'package:ndu_project/utils/planning_phase_navigation.dart';
import 'package:ndu_project/utils/project_data_helper.dart';
import 'package:ndu_project/widgets/draggable_sidebar.dart';
import 'package:ndu_project/widgets/field_regenerate_undo_buttons.dart';
import 'package:ndu_project/widgets/initiation_like_sidebar.dart';
import 'package:ndu_project/widgets/kaz_ai_chat_bubble.dart';
import 'package:ndu_project/widgets/launch_phase_navigation.dart';
import 'package:ndu_project/widgets/planning_phase_header.dart';
import 'package:ndu_project/widgets/responsive.dart';
import 'package:ndu_project/widgets/text_formatting_toolbar.dart';

import 'package:ndu_project/widgets/voice_text_field.dart';
import 'package:ndu_project/utils/pdf_export_helper.dart';
const Color _kBackground = Colors.white;
const Color _kBorder = Color(0xFFE5E7EB);
const Color _kMuted = Color(0xFF6B7280);
const Color _kHeadline = Color(0xFF111827);
const Color _kAccent = Color(0xFFD97706);

class AgileEpicsFeaturesScreen extends StatefulWidget {
 const AgileEpicsFeaturesScreen({super.key});

 @override
 State<AgileEpicsFeaturesScreen> createState() =>
 _AgileEpicsFeaturesScreenState();
}

class _AgileEpicsFeaturesScreenState
 extends State<AgileEpicsFeaturesScreen> {
 List<Epic> _epics = [];
 String? _selectedEpicId;
 List<Feature> _features = [];
 bool _isLoading = true;
  bool _isGenerating = false;
  bool _isSyncing = false;

  // ── Managed controllers to prevent memory leaks ──
 final Map<String, TextEditingController> _epicControllers = {};
 final Map<String, TextEditingController> _featureControllers = {};
 final Map<String, TextEditingController> _chipControllers = {};

 TextEditingController _getController(
 Map<String, TextEditingController> map, String key, String initialValue) {
 if (!map.containsKey(key)) {
 map[key] = TextEditingController(text: initialValue);
 }
 return map[key]!;
 }

 String? get _projectId {
 try {
 return ProjectDataInherited.maybeOf(context)?.projectData.projectId;
 } catch (e) {
 return null;
 }
 }

 @override
 void initState() {
 super.initState();
 WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
 }

 Future<void> _loadData() async {
 final pid = _projectId;
 if (pid == null) return;
 setState(() => _isLoading = true);
 try {
 final epics = await EpicFeatureService.loadEpics(pid);
 if (!mounted) return;
 setState(() {
 _epics = epics;
 _isLoading = false;
 if (_selectedEpicId == null && epics.isNotEmpty) {
 _selectedEpicId = epics.first.id;
 }
 });
 if (_selectedEpicId != null) _loadFeatures();
 // ── Auto-populate from AI when no epics exist ──────────────────
 if (_epics.isEmpty && !_isGenerating) {
 _generateEpics();
 }
 } catch (e) {
 if (mounted) setState(() => _isLoading = false);
 }
 }

  Future<void> _loadFeatures() async {
    final pid = _projectId;
    if (pid == null || _selectedEpicId == null) return;
    final features =
        await EpicFeatureService.loadFeatures(pid, _selectedEpicId!);
    if (mounted) setState(() => _features = features);
  }

  Future<void> _syncFromWbs() async {
    final pid = _projectId;
    if (pid == null) return;
    setState(() => _isSyncing = true);
    try {
      final wbsProvider = context.read<WBSProvider>();
      final wbs = wbsProvider.wbs;
      if (wbs == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No WBS found. Create a WBS first.')),
          );
        }
        return;
      }
      if (wbs.methodology == ProjectMethodology.waterfall) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('WBS is set to Waterfall. Switch to Agile or Hybrid to sync.')),
          );
        }
        return;
      }
      final result = await WbsAgileSyncService.syncWbsToAgile(
        projectId: pid,
        wbs: wbs,
      );
      if (!mounted) return;
      if (result.total > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Synced ${result.total} items from WBS: ${result.epicsCreated} epics, ${result.featuresCreated} features, ${result.storiesCreated} stories.'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Color(0xFF059669),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('All WBS items already synced. No new items created.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sync failed: $e')),
        );
      }
    }
    if (mounted) setState(() => _isSyncing = false);
  }

 void _addEpic() {
 final epic = Epic(title: 'New Epic ${_epics.length + 1}');
 final pid = _projectId;
 if (pid == null) return;
 EpicFeatureService.saveEpic(projectId: pid, epic: epic);
 setState(() {
 _epics.add(epic);
 _selectedEpicId = epic.id;
 });
 _loadFeatures();
 }

 void _updateEpic(Epic epic) {
 final pid = _projectId;
 if (pid == null) return;
 EpicFeatureService.saveEpic(projectId: pid, epic: epic);
 }

 void _deleteEpic(int index) {
 final pid = _projectId;
 final epic = _epics[index];
 if (pid == null) return;
 EpicFeatureService.deleteEpic(projectId: pid, epicId: epic.id);
 _epicControllers.remove(epic.id);
 _chipControllers.removeWhere((k, _) => k.startsWith('${epic.id}_'));
 setState(() {
 _epics.removeAt(index);
 if (_selectedEpicId == epic.id) {
 _selectedEpicId = _epics.isNotEmpty ? _epics.first.id : null;
 }
 });
 if (_selectedEpicId != null) _loadFeatures();
 }

 void _addFeature() {
 final epicId = _selectedEpicId;
 if (epicId == null) return;
 final pid = _projectId;
 if (pid == null) return;
 final feature = Feature(epicId: epicId);
 EpicFeatureService.saveFeature(
 projectId: pid, epicId: epicId, feature: feature);
 setState(() => _features.add(feature));
 }

 void _updateFeature(Feature feature) {
 final pid = _projectId;
 if (pid == null || _selectedEpicId == null) return;
 EpicFeatureService.saveFeature(
 projectId: pid, epicId: _selectedEpicId!, feature: feature);
 }

 void _deleteFeature(int index) {
 final pid = _projectId;
 if (pid == null || _selectedEpicId == null) return;
 final feature = _features[index];
 EpicFeatureService.deleteFeature(
 projectId: pid, epicId: _selectedEpicId!, featureId: feature.id);
 _featureControllers.remove(feature.id);
 setState(() => _features.removeAt(index));
 }

 Future<void> _generateEpics() async {
 final pid = _projectId;
 if (pid == null) return;
 setState(() => _isGenerating = true);
 try {
 final projectData = ProjectDataHelper.getData(context);
 final contextText = ProjectDataHelper.buildProjectContextScan(
 projectData,
 sectionLabel: 'Epics & Features',
 );
 final openai = OpenAiServiceSecure();
 final result = await openai.generateCompletion(
 'Based on this project context, suggest 3-5 agile epics.\n\n'
 'Context:\n$contextText\n\n'
 'For each epic provide: title, description, theme, business value, and estimated story points. '
 'Return ONLY a valid JSON array with keys: title, description, theme, businessValue, totalStoryPoints.',
 maxTokens: 1200,
 temperature: 0.5,
 );
 final parsed = _parseEpicGeneration(result);
 if (parsed.isEmpty) {
 if (mounted) {
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(content: Text('AI did not return valid epics. Try again.')),
 );
 }
 } else {
 for (final epic in parsed) {
 await EpicFeatureService.saveEpic(projectId: pid, epic: epic);
 }
 _loadData();
 }
 } catch (e) {
 if (mounted) {
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(content: Text('AI generation failed: ${e.toString()}')),
 );
 }
 }
 if (mounted) setState(() => _isGenerating = false);
 }

 List<Epic> _parseEpicGeneration(String text) {
 try {
 final data = _extractJsonArray(text);
 if (data == null) return [];
 return data.map<Epic>((json) {
 if (json is Map) {
 return Epic(
 title: (json['title'] ?? '').toString(),
 description: (json['description'] ?? '').toString(),
 theme: (json['theme'] ?? '').toString(),
 businessValue: (json['businessValue'] ?? '').toString(),
 totalStoryPoints:
 double.tryParse((json['totalStoryPoints'] ?? '0').toString()) ??
 0,
 );
 }
 return Epic(title: 'Generated Epic');
 }).toList();
 } catch (e) {
 return [];
 }
 }

 List<dynamic>? _extractJsonArray(String text) {
 final start = text.indexOf('[');
 final end = text.lastIndexOf(']');
 if (start == -1 || end == -1) return null;
 try {
 return _parseJson(text.substring(start, end + 1));
 } catch (e) {
 return null;
 }
 }

 List<dynamic>? _parseJson(String json) {
 try {
 final result = jsonDecode(json);
 if (result is List) return result;
 return null;
 } catch (e) {
 return null;
 }
 }

 // ── Per-field AI regeneration for epics ──────────────────────────────
 Future<void> _regenerateEpicField(Epic epic, String field) async {
 try {
 final projectData = ProjectDataHelper.getData(context);
 final contextText = ProjectDataHelper.buildProjectContextScan(
 projectData,
 sectionLabel: 'Epic $field',
 );
 final openai = OpenAiServiceSecure();
 final result = await openai.generateCompletion(
 'Based on this project context, suggest a concise $field for an agile epic.\n\n'
 'Context:\n$contextText\n\n'
 'Current epic title: ${epic.title}\n'
 'Current value: ${field == 'title' ? epic.title : field == 'theme' ? epic.theme : epic.businessValue}\n\n'
 'Return ONLY the text value (no JSON, no markdown).',
 maxTokens: 100,
 temperature: 0.6,
 );
 final cleaned = result.trim();
 if (cleaned.isNotEmpty) {
 switch (field) {
 case 'title':
 epic.title = cleaned;
 _epicControllers[epic.id]?.text = cleaned;
 break;
 case 'theme':
 epic.theme = cleaned;
 _chipControllers['${epic.id}_Theme']?.text = cleaned;
 break;
 case 'businessValue':
 epic.businessValue = cleaned;
 _chipControllers['${epic.id}_Value']?.text = cleaned;
 break;
 }
 setState(() {});
 _updateEpic(epic);
 }
 } catch (e) {
 if (mounted) {
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(content: Text('AI regeneration failed: $e')),
 );
 }
 }
 }

 // ── Per-field AI regeneration for features ───────────────────────────
 Future<void> _regenerateFeatureField(Feature feature, String field) async {
 try {
 final projectData = ProjectDataHelper.getData(context);
 final contextText = ProjectDataHelper.buildProjectContextScan(
 projectData,
 sectionLabel: 'Feature $field',
 );
 final openai = OpenAiServiceSecure();
 final result = await openai.generateCompletion(
 'Based on this project context, suggest a concise $field for an agile feature.\n\n'
 'Context:\n$contextText\n\n'
 'Return ONLY the text value (no JSON, no markdown).',
 maxTokens: 100,
 temperature: 0.6,
 );
 final cleaned = result.trim();
 if (cleaned.isNotEmpty) {
 switch (field) {
 case 'title':
 feature.title = cleaned;
 _featureControllers[feature.id]?.text = cleaned;
 break;
 case 'description':
 feature.description = cleaned;
 break;
 }
 setState(() {});
 _updateFeature(feature);
 }
 } catch (e) {
 if (mounted) {
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(content: Text('AI regeneration failed: $e')),
 );
 }
 }
 }

 @override
 Widget build(BuildContext context) {
 final bool isMobile = AppBreakpoints.isMobile(context);
 final double hp = isMobile ? 20 : 40;

 return Scaffold(
 backgroundColor: _kBackground,
 body: SafeArea(
 child: Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 DraggableSidebar(
 openWidth: AppBreakpoints.sidebarWidth(context),
 child: const InitiationLikeSidebar(
 activeItemLabel: 'Agile Delivery Model - Epics & Features'),
 ),
 Expanded(
 child: Stack(
 children: [
 MobileSidebarHamburger(
 sidebar: const InitiationLikeSidebar(
 activeItemLabel: 'Agile Delivery Model - Epics & Features',
 ),
 ),
 SingleChildScrollView(
 padding: EdgeInsets.symmetric(horizontal: hp, vertical: 32),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 PlanningPhaseHeader(
 title: 'Epics & Features Planning',
onBack: () => PlanningPhaseNavigation.goToPrevious(
 context, 'agile_epics_features'),
 onForward: () => PlanningPhaseNavigation.goToNext(
 context, 'agile_epics_features'), onExportPdf: _exportPdf),
 const SizedBox(height: 32),
 if (_isLoading)
 const Center(child: CircularProgressIndicator())
 else ...[
  Row(
    children: [
      Expanded(
        child: Text('Define epics (large bodies of work) and their features.',
            style: TextStyle(fontSize: 15, color: _kMuted)),
      ),
      const SizedBox(width: 12),
      OutlinedButton.icon(
        onPressed: _isSyncing ? null : _syncFromWbs,
        icon: _isSyncing
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.link, size: 18),
        label: Text(_isSyncing ? 'Syncing...' : 'Sync from WBS'),
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF059669),
          side: const BorderSide(color: Color(0xFF059669)),
        ),
      ),
      const SizedBox(width: 8),
      OutlinedButton.icon(
        onPressed: _isGenerating ? null : _generateEpics,
        icon: _isGenerating
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.auto_awesome, size: 18),
        label: Text(_isGenerating ? 'Generating...' : 'AI Generate'),
        style: OutlinedButton.styleFrom(
          foregroundColor: _kAccent,
          side: const BorderSide(color: _kAccent),
        ),
      ),
    ],
  ),
 const SizedBox(height: 20),
 Row(
 children: [
 const Text('Epics',
 style: TextStyle(
 fontSize: 18,
 fontWeight: FontWeight.w700,
 color: _kHeadline)),
 const Spacer(),
 TextButton.icon(
 onPressed: _addEpic,
 icon: const Icon(Icons.add, size: 18),
 label: const Text('Add Epic'),
 ),
 ],
 ),
 if (_epics.isEmpty)
 _buildEmptyState('No epics defined. Add one or use AI Generate.')
 else
 ..._epics.asMap().entries.map(
 (e) => _buildEpicTile(e.key, e.value)),
 const SizedBox(height: 28),
 if (_selectedEpicId != null) ...[
 Row(
 children: [
 Text('Features for selected epic',
 style: const TextStyle(
 fontSize: 16,
 fontWeight: FontWeight.w600,
 color: _kHeadline)),
 const Spacer(),
 TextButton.icon(
 onPressed: _addFeature,
 icon: const Icon(Icons.add, size: 18),
 label: const Text('Add Feature'),
 ),
 ],
 ),
 if (_features.isEmpty)
 _buildEmptyState('No features yet for this epic.')
 else
 ..._features.asMap().entries.map(
 (e) => _buildFeatureCard(e.key, e.value)),
 ],
 ],
 const SizedBox(height: 24),
 LaunchPhaseNavigation(
 backLabel: PlanningPhaseNavigation.backLabel('agile_epics_features'),
 nextLabel: PlanningPhaseNavigation.nextLabel('agile_epics_features'),
 onBack: () => PlanningPhaseNavigation.goToPrevious(context, 'agile_epics_features'),
 onNext: () => PlanningPhaseNavigation.goToNext(context, 'agile_epics_features'),
 ),
 const SizedBox(height: 40),
 ],
 ),
 ),
 const Positioned(
 right: 24,
 bottom: 24,
 child: KazAiChatBubble(positioned: false),
 ),
 ],
 ),
 ),
 ],
 ),
 ),
 );
 }


Widget _buildEpicTile(int index, Epic epic) {
 final isSelected = epic.id == _selectedEpicId;
 return Card(
 margin: const EdgeInsets.only(bottom: 6),
 shape: RoundedRectangleBorder(
 borderRadius: BorderRadius.circular(10),
 side: BorderSide(
 color: isSelected ? _kAccent : _kBorder, width: isSelected ? 2 : 1),
 ),
 child: InkWell(
 borderRadius: BorderRadius.circular(10),
 onTap: () {
 setState(() => _selectedEpicId = epic.id);
 _loadFeatures();
 },
 child: Padding(
 padding: const EdgeInsets.all(12),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 children: [
 Expanded(
 child: VoiceTextField(
 decoration: InputDecoration(
 hintText: 'Epic title',
 border: InputBorder.none,
 isDense: true,
 suffixIcon: Row(
 mainAxisSize: MainAxisSize.min,
 children: [
 IconButton(
 tooltip: 'KAZ AI',
 icon: const Icon(Icons.auto_awesome,
 color: Color(0xFFF59E0B), size: 16),
 onPressed: () => _regenerateEpicField(epic, 'title'),
 padding: const EdgeInsets.all(2),
 constraints: const BoxConstraints(
 minWidth: 28, minHeight: 28),
 ),
 if (epic.title.isNotEmpty)
 IconButton(
 tooltip: 'Clear',
 icon: const Icon(Icons.delete_sweep,
 color: Color(0xFFEF4444), size: 16),
 onPressed: () {
 epic.title = '';
 _epicControllers[epic.id]?.clear();
 _updateEpic(epic);
 setState(() {});
 },
 padding: const EdgeInsets.all(2),
 constraints: const BoxConstraints(
 minWidth: 28, minHeight: 28),
 ),
 ],
 ),
 ),
 style: const TextStyle(
 fontWeight: FontWeight.w600, fontSize: 14),
 controller: _getController(_epicControllers, epic.id, epic.title),
 onChanged: (v) {
 epic.title = v;
 _updateEpic(epic);
 },
 ),
 ),
 Container(
 padding:
 const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
 decoration: BoxDecoration(
 color: _statusColor(epic.status).withOpacity(0.1),
 borderRadius: BorderRadius.circular(4),
 ),
 child: DropdownButtonHideUnderline(
 child: DropdownButton<String>(
 value: epic.status,
 isDense: true,
 items: ['backlog', 'active', 'complete', 'cancelled']
 .map((s) => DropdownMenuItem(
 value: s,
 child: Text(s,
 style: TextStyle(
 fontSize: 11,
 color: _statusColor(s)))))
 .toList(),
 onChanged: (v) {
 if (v != null) {
 epic.status = v;
 _updateEpic(epic);
 setState(() {});
 }
 },
 ),
 ),
 ),
                  const SizedBox(width: 4),
                  if (epic.wbsId.isNotEmpty)
                    Tooltip(
                      message: 'Synced from WBS',
                      child: Icon(Icons.link, size: 16, color: const Color(0xFF059669)),
                    ),
                  const SizedBox(width: 4),
                  IconButton(
                    icon: const Icon(Icons.delete_outline,
                        size: 18, color: Colors.red),
                    onPressed: () => _deleteEpic(index),
                    constraints: const BoxConstraints(),
                    padding: EdgeInsets.zero,
                  ),
                ],
              ),
  const SizedBox(height: 6),
  Row(
    children: [
      _buildChip(epic.id, 'Theme', epic.theme, (v) {
        epic.theme = v;
        _updateEpic(epic);
      }),
      const SizedBox(width: 8),
      _buildChip(epic.id, 'Value', epic.businessValue, (v) {
        epic.businessValue = v;
        _updateEpic(epic);
      }),
      const SizedBox(width: 8),
      Text('${epic.totalStoryPoints.toStringAsFixed(0)} pts',
          style: TextStyle(fontSize: 12, color: _kMuted)),
    ],
  ),
  VoiceTextField(
    decoration: InputDecoration(
      hintText: 'Epic description',
      border: InputBorder.none,
      isDense: true,
      contentPadding: EdgeInsets.zero,
    ),
    style: const TextStyle(fontSize: 12, color: _kMuted),
    controller: _getController(_epicControllers, '${epic.id}_desc', epic.description),
    onChanged: (v) {
      epic.description = v;
      _updateEpic(epic);
    },
  ),
],
 ),
 ),
 ),
 );
 }

 Widget _buildFeatureCard(int index, Feature feature) {
 return Card(
 margin: const EdgeInsets.only(bottom: 6, left: 16),
 shape: RoundedRectangleBorder(
 borderRadius: BorderRadius.circular(8),
 side: const BorderSide(color: _kBorder),
 ),
 child: Padding(
 padding: const EdgeInsets.all(10),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 children: [
 Expanded( child: VoiceTextField(
 decoration: InputDecoration(
 hintText: 'Feature title',
 border: InputBorder.none,
 isDense: true,
 suffixIcon: Row(
 mainAxisSize: MainAxisSize.min,
 children: [
 IconButton(
 tooltip: 'KAZ AI',
 icon: const Icon(Icons.auto_awesome,
 color: Color(0xFFF59E0B), size: 16),
 onPressed: () =>
 _regenerateFeatureField(feature, 'title'),
 padding: const EdgeInsets.all(2),
 constraints: const BoxConstraints(
 minWidth: 28, minHeight: 28),
 ),
 if (feature.title.isNotEmpty)
 IconButton(
 tooltip: 'Clear',
 icon: const Icon(Icons.delete_sweep,
 color: Color(0xFFEF4444), size: 16),
 onPressed: () {
 feature.title = '';
 _featureControllers[feature.id]?.clear();
 _updateFeature(feature);
 setState(() {});
 },
 padding: const EdgeInsets.all(2),
 constraints: const BoxConstraints(
 minWidth: 28, minHeight: 28),
 ),
 ],
 ),
 ),
 style: const TextStyle(
 fontWeight: FontWeight.w500, fontSize: 13),
 controller: _getController(_featureControllers, feature.id, feature.title),
 onChanged: (v) {
 feature.title = v;
 _updateFeature(feature);
 },
 ),
 ),
 Container(
 padding:
 const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
 decoration: BoxDecoration(
 color: _priorityColor(feature.priority).withOpacity(0.1),
 borderRadius: BorderRadius.circular(4),
 ),
 child: DropdownButtonHideUnderline(
 child: DropdownButton<String>(
 value: feature.priority,
 isDense: true,
 items: ['critical', 'high', 'medium', 'low']
 .map((p) => DropdownMenuItem(
 value: p,
 child: Text(p,
 style: TextStyle(
 fontSize: 11,
 color: _priorityColor(p)))))
 .toList(),
 onChanged: (v) {
 if (v != null) {
 feature.priority = v;
 _updateFeature(feature);
 setState(() {});
 }
 },
 ),
 ),
 ),
                  const SizedBox(width: 4),
                  if (feature.wbsId.isNotEmpty)
                    Tooltip(
                      message: 'Synced from WBS',
                      child: Icon(Icons.link, size: 14, color: const Color(0xFF059669)),
                    ),
                  const SizedBox(width: 4),
                  IconButton(
                    icon: const Icon(Icons.delete_outline,
                        size: 16, color: Colors.red),
                    onPressed: () => _deleteFeature(index),
                    constraints: const BoxConstraints(),
                    padding: EdgeInsets.zero,
                  ),
                ],
              ),
    VoiceTextField(
      decoration: InputDecoration(
        hintText: 'Feature description',
        border: InputBorder.none,
        isDense: true,
        contentPadding: EdgeInsets.zero,
      ),
      style: const TextStyle(fontSize: 12, color: _kMuted),
      controller: _getController(_featureControllers, '${feature.id}_desc', feature.description),
      onChanged: (v) {
        feature.description = v;
        _updateFeature(feature);
      },
    ),
    const SizedBox(height: 4),
    Row(
      children: [
        Text('Est: ${feature.storyPointEstimate.toStringAsFixed(0)} pts',
            style: TextStyle(fontSize: 11, color: _kMuted)),
 const SizedBox(width: 12),
 Text('Status: ${feature.status}',
 style: TextStyle(fontSize: 11, color: _kMuted)),
 ],
 ),
 ],
 ),
 ),
 );
 }

 Color _statusColor(String status) {
 switch (status) {
 case 'active':
 return Colors.blue;
 case 'complete':
 return Colors.green;
 case 'cancelled':
 return Colors.red;
 default:
 return Colors.grey;
 }
 }

 Color _priorityColor(String priority) {
 switch (priority) {
 case 'critical':
 return Colors.red;
 case 'high':
 return Colors.orange;
 case 'medium':
 return Colors.blue;
 default:
 return Colors.grey;
 }
 }

 Widget _buildChip(String epicId, String label, String value, ValueChanged<String> onChanged) {
 return Container(
 padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
 decoration: BoxDecoration(
 color: _kBorder.withOpacity(0.3),
 borderRadius: BorderRadius.circular(4),
 ),
 child: Row(
 mainAxisSize: MainAxisSize.min,
        children: [
          Text('$label: ', style: TextStyle(fontSize: 11, color: _kMuted)),
          VoiceTextField(
            decoration: InputDecoration(
              border: InputBorder.none,
              isDense: true,
              suffixIcon: value.isNotEmpty
                  ? IconButton(
                      tooltip: 'Clear',
                      icon: const Icon(Icons.close,
                          color: Color(0xFFEF4444), size: 12),
                      onPressed: () {
                        onChanged('');
                        setState(() {});
                      },
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                          minWidth: 20, minHeight: 20),
                    )
                  : null,
            ),
            style: const TextStyle(fontSize: 11),
            controller: _getController(_chipControllers, '${epicId}_$label', value),
            onChanged: onChanged,
          ),
        ],
 ),
 );
 }

 Widget _buildEmptyState(String message) {
 return Container(
 padding: const EdgeInsets.all(24),
 decoration: BoxDecoration(
 border: Border.all(color: _kBorder),
 borderRadius: BorderRadius.circular(12),
 ),
 child: Center(
 child: Text(message, style: TextStyle(color: _kMuted, fontSize: 14)),
 ),
 );
 }

 Future<void> _exportPdf() async {
 final projectData = ProjectDataHelper.getData(context);
 await PdfExportHelper.exportScreenPdf(
 context: context,
 screenTitle: 'Agile Epics & Features',
 sections: [
 PdfSection.keyValue('Project Info', [
 {'Project Name': projectData.projectName ?? 'N/A'},
 {'Solution Title': projectData.solutionTitle ?? 'N/A'},
 ]),
 PdfSection.text('Notes', projectData.planningNotes['planning_agile_epics_features_notes'] ?? 'No data recorded.'),
 ],
 );
 }
}


