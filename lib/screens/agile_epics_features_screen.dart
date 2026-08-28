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
import 'package:ndu_project/widgets/initiation_like_sidebar.dart';
import 'package:ndu_project/widgets/kaz_ai_chat_bubble.dart';
import 'package:ndu_project/widgets/launch_phase_navigation.dart';
import 'package:ndu_project/widgets/planning_phase_header.dart';
import 'package:ndu_project/widgets/responsive.dart';

import 'package:ndu_project/widgets/voice_text_field.dart';
import 'package:ndu_project/utils/pdf_export_helper.dart';

import 'package:ndu_project/widgets/delete_success_snackbar.dart';
const Color _kBackground = Colors.white;
const Color _kBorder = Color(0xFFE5E7EB);
const Color _kMuted = Color(0xFF6B7280);
const Color _kHeadline = Color(0xFF111827);
const Color _kAccent = Color(0xFFD97706);
const Color _kYellow = Color(0xFFFFC107);
const Color _kDarkText = Color(0xFF141414);

/// Cycled across epic cards so each code chip (G1, G2, …) gets its own hue.
const List<Color> _kEpicPalette = [
  Color(0xFFFFC107),
  Color(0xFF3B82F6),
  Color(0xFF10B981),
  Color(0xFF8B5CF6),
  Color(0xFFF97316),
  Color(0xFF14B8A6),
];

class AgileEpicsFeaturesScreen extends StatefulWidget {
  const AgileEpicsFeaturesScreen({super.key});

  @override
  State<AgileEpicsFeaturesScreen> createState() =>
      _AgileEpicsFeaturesScreenState();
}

class _AgileEpicsFeaturesScreenState extends State<AgileEpicsFeaturesScreen> {
  List<Epic> _epics = [];
  String? _selectedEpicId;
  List<Feature> _features = [];
  bool _isLoading = true;
  bool _isGenerating = false;
  bool _isSyncing = false;
  // Guards against infinite _loadData → _syncFromWbs → _loadData recursion
  // when the auto-sync-on-empty-list fires on first visit. Without this flag,
  // a sync that produces 0 new items (e.g. WBS exists but all nodes are
  // already synced) would loop indefinitely.
  bool _hasAttemptedAutoSync = false;

  /// Once-per-visit guard for the AI feature auto-generation pass (the
  /// nested _loadData fired by _syncFromWbs would otherwise trigger it a
  /// second time).
  bool _hasAttemptedFeatureAutoGen = false;

  /// Features per epic id — powers the feature-count badge and the
  /// feature chips rendered on each epic card in the grid.
  final Map<String, List<Feature>> _featuresByEpic = {};

  /// WBS node id → code (G1, G1.2, …) so synced epics can show the code
  /// chip of the WBS element they were pulled from.
  final Map<String, String> _wbsCodeById = {};

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

  Epic? get _selectedEpic {
    final id = _selectedEpicId;
    if (id == null) return null;
    for (final epic in _epics) {
      if (epic.id == id) return epic;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  @override
  void dispose() {
    for (final c in _epicControllers.values) {
      c.dispose();
    }
    for (final c in _featureControllers.values) {
      c.dispose();
    }
    for (final c in _chipControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadData() async {
    final pid = _projectId;
    if (pid == null) return;
    setState(() => _isLoading = true);
    try {
      // Ensure THIS project's WBS is loaded before anything reads it —
      // WBSProvider may otherwise hold a stale WBS from a previously-active
      // project (or null after a fresh app start). ensureProjectLoaded is
      // dedup-guarded, so the auto-load below and the manual "Sync from WBS"
      // button share a single underlying Firestore/SharedPreferences read.
      await context.read<WBSProvider>().ensureProjectLoaded(pid);
      if (!mounted) return;
      _indexWbsCodes(context.read<WBSProvider>().wbs);

      final epics = await EpicFeatureService.loadEpics(pid);
      if (!mounted) return;
      final featuresByEpic = <String, List<Feature>>{};
      for (final epic in epics) {
        featuresByEpic[epic.id] =
            await EpicFeatureService.loadFeatures(pid, epic.id);
      }
      if (!mounted) return;
      setState(() {
        _epics = epics;
        _featuresByEpic
          ..clear()
          ..addAll(featuresByEpic);
        _isLoading = false;
        if (_selectedEpicId == null && epics.isNotEmpty) {
          _selectedEpicId = epics.first.id;
        }
        _features = _selectedEpicId != null
            ? List<Feature>.from(
                featuresByEpic[_selectedEpicId!] ?? const <Feature>[])
            : <Feature>[];
      });
      // ── Auto-load Epics/Features from the WBS on screen load ────────
      // The WBS is the source of truth: the first visit of the screen
      // pulls the WBS tree into Firestore via WbsAgileSyncService
      // (additive — existing records matched by wbsId are never
      // overwritten), so newly added WBS epics/features show up
      // automatically. The manual "Sync from WBS" button remains for
      // explicit re-syncs; `_hasAttemptedAutoSync` keeps this a
      // once-per-visit operation so a sync that creates 0 items (WBS
      // already synced) can never loop.
      if (!_isSyncing && !_isGenerating && !_hasAttemptedAutoSync) {
        _hasAttemptedAutoSync = true;
        await _syncFromWbs(silentIfNoWbs: true);
      }
      // Auto-generate features for epics that have no features yet.
      // Guarded once-per-visit: the nested _loadData fired at the end of
      // _syncFromWbs would otherwise run this AI pass a second time.
      if (_epics.isNotEmpty &&
          !_isGenerating &&
          !_isSyncing &&
          !_hasAttemptedFeatureAutoGen) {
        _hasAttemptedFeatureAutoGen = true;
        await _generateFeaturesForAllEpics();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load epics: $e')),
        );
      }
    }
  }

  /// Index WBS node ids → codes (G1, G1.2, …) so epic cards can show the
  /// code chip of the WBS element they were synced from.
  void _indexWbsCodes(WBS? wbs) {
    _wbsCodeById.clear();
    if (wbs == null) return;
    void walk(WBSNode node) {
      _wbsCodeById[node.id] = node.code;
      for (final c in node.children) {
        walk(c);
      }
    }

    walk(wbs.level0);
  }

  Future<void> _loadFeatures() async {
    final pid = _projectId;
    if (pid == null || _selectedEpicId == null) return;
    final features =
        await EpicFeatureService.loadFeatures(pid, _selectedEpicId!);
    if (!mounted) return;
    setState(() {
      _features = features;
      _featuresByEpic[_selectedEpicId!] = List<Feature>.from(features);
    });
  }

  /// Pull Epics/Features/Stories from the WBS tree into Firestore.
  ///
  /// [silentIfNoWbs] suppresses the "No WBS found" and "All WBS items already
  /// synced" SnackBars — used by the auto-sync-on-first-visit path in
  /// [_loadData] so that landing on the page with no WBS (or with an
  /// already-synced WBS) doesn't spam the user with notifications they
  /// didn't ask for. Success ("Synced N items…") and failure ("Sync
  /// failed: …") messages are always shown so the user knows what happened.
  Future<void> _syncFromWbs({bool silentIfNoWbs = false}) async {
    final pid = _projectId;
    if (pid == null) return;
    setState(() => _isSyncing = true);
    try {
      final wbsProvider = context.read<WBSProvider>();
      // CRITICAL: ensure the WBS for *this* project is loaded before reading
      // it. Without this, the WBSProvider may still hold a stale WBS from a
      // previously-visited project (or null after a fresh app start), causing
      // false "No WBS found" errors or, worse, syncing the wrong project's
      // WBS tree into the current project's Firestore.
      await wbsProvider.ensureProjectLoaded(pid);
      if (!mounted) return;
      final wbs = wbsProvider.wbs;
      if (wbs == null) {
        if (mounted && !silentIfNoWbs) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'No WBS found for this project. Open the WBS module from the sidebar to create one first, then return here and click "Sync from WBS".'),
              duration: Duration(seconds: 6),
            ),
          );
        }
        return;
      }
      // Defensive: never sync a WBS whose projectId doesn't match the
      // currently-active project — that would create Epic/Feature/Story
      // records under the wrong project in Firestore.
      if (wbs.projectId.isNotEmpty &&
          wbs.projectId != 'default' &&
          wbs.projectId != pid) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'WBS project mismatch: WBS belongs to "${wbs.projectId}" but the active project is "$pid". Re-open the WBS module to load the correct project.'),
              behavior: SnackBarBehavior.floating,
              backgroundColor: const Color(0xFFB45309),
              duration: const Duration(seconds: 7),
            ),
          );
        }
        return;
      }
      if (wbs.methodology == ProjectMethodology.waterfall) {
        if (mounted && !silentIfNoWbs) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'WBS methodology is Waterfall — Epics/Features/Stories only apply to Agile or Hybrid. Open the WBS module to switch methodology.'),
              duration: Duration(seconds: 6),
            ),
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
        // Always announce successful creation — even when auto-triggered,
        // the user benefits from seeing "Synced 3 items from WBS" so they
        // understand where the suddenly-appearing epics came from.
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Synced ${result.total} items from WBS: ${result.epicsCreated} epics, ${result.featuresCreated} features, ${result.storiesCreated} stories.'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: const Color(0xFF059669),
          ),
        );
      } else if (!silentIfNoWbs) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text('All WBS items already synced. No new items created.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      await _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sync failed: $e'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: const Color(0xFFB91C1C),
            duration: const Duration(seconds: 8),
          ),
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
      _featuresByEpic[epic.id] = <Feature>[];
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
    _epicControllers.remove('${epic.id}_desc');
    _chipControllers.removeWhere((k, _) => k.startsWith('${epic.id}_'));
    _featuresByEpic.remove(epic.id);
    setState(() {
      _epics.removeAt(index);
      if (_selectedEpicId == epic.id) {
        _selectedEpicId = _epics.isNotEmpty ? _epics.first.id : null;
      }
      _features = _selectedEpicId != null
          ? List<Feature>.from(
              _featuresByEpic[_selectedEpicId!] ?? const <Feature>[])
          : <Feature>[];
    });
    if (_selectedEpicId != null) _loadFeatures();
    showDeleteSuccessSnackBar(context, itemLabel: 'Epic');
  }

  void _addFeature() {
    final epicId = _selectedEpicId;
    if (epicId == null) return;
    final pid = _projectId;
    if (pid == null) return;
    final feature = Feature(epicId: epicId);
    EpicFeatureService.saveFeature(
        projectId: pid, epicId: epicId, feature: feature);
    setState(() {
      _features.add(feature);
      _featuresByEpic[epicId] = List<Feature>.from(_features);
    });
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
    _featureControllers.remove('${feature.id}_desc');
    setState(() {
      _features.removeAt(index);
      _featuresByEpic[_selectedEpicId!] = List<Feature>.from(_features);
    });
    showDeleteSuccessSnackBar(context, itemLabel: 'Feature');
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
            const SnackBar(
                content: Text('AI did not return valid epics. Try again.')),
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

  /// Auto-generate features for all epics using AI on page load.
  /// Uses the overall project context to generate relevant features for each epic.
  Future<void> _generateFeaturesForAllEpics() async {
    final pid = _projectId;
    if (pid == null || _epics.isEmpty) return;
    
    setState(() => _isGenerating = true);
    try {
      final projectData = ProjectDataHelper.getData(context);
      final contextText = ProjectDataHelper.buildProjectContextScan(
        projectData,
        sectionLabel: 'Features Generation',
      );
      final openai = OpenAiServiceSecure();
      
      for (final epic in _epics) {
        // Skip epics that already have features
        final existingFeatures = await EpicFeatureService.loadFeatures(pid, epic.id);
        if (existingFeatures.isNotEmpty) continue;
        
        final result = await openai.generateCompletion(
          'Based on this project context and the epic below, suggest 2-3 agile features.\n\n'
          'Project Context:\n$contextText\n\n'
          'Epic Title: ${epic.title}\n'
          'Epic Description: ${epic.description}\n'
          'Epic Theme: ${epic.theme}\n\n'
          'For each feature provide: title, description, priority (critical/high/medium/low), and story point estimate. '
          'Return ONLY a valid JSON array with keys: title, description, priority, storyPointEstimate.',
          maxTokens: 800,
          temperature: 0.5,
        );
        
        final features = _parseFeatureGeneration(result);
        for (final feature in features) {
          feature.epicId = epic.id;
          await EpicFeatureService.saveFeature(
            projectId: pid,
            epicId: epic.id,
            feature: feature,
          );
        }
        // Keep the per-epic feature map (grid badges/chips) in sync with
        // what was just generated for this epic.
        if (features.isNotEmpty && mounted) {
          setState(() {
            _featuresByEpic[epic.id] = [...existingFeatures, ...features];
            if (epic.id == _selectedEpicId) {
              _features = List<Feature>.from(_featuresByEpic[epic.id]!);
            }
          });
        }
      }
      
      // Reload features for the currently selected epic
      if (_selectedEpicId != null) {
        await _loadFeatures();
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Features auto-generated for epics.'),
            backgroundColor: Color(0xFF059669),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Feature generation failed: ${e.toString()}')),
        );
      }
    }
    if (mounted) setState(() => _isGenerating = false);
  }

  List<Feature> _parseFeatureGeneration(String text) {
    try {
      final data = _extractJsonArray(text);
      if (data == null) return [];
      return data.map<Feature>((json) {
        if (json is Map) {
          return Feature(
            title: (json['title'] ?? '').toString(),
            description: (json['description'] ?? '').toString(),
            priority: (json['priority'] ?? 'medium').toString(),
            storyPointEstimate:
                double.tryParse((json['storyPointEstimate'] ?? '1').toString()) ?? 1,
          );
        }
        return Feature(title: 'Generated Feature');
      }).toList();
    } catch (e) {
      return [];
    }
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
                  Positioned.fill(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.symmetric(horizontal: hp, vertical: 32),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          PlanningPhaseHeader(
                              title: 'Epics & Features Planning',
                              onBack: () => PlanningPhaseNavigation.goToPrevious(
                                  context, 'agile_epics_features'),
                              onForward: () => PlanningPhaseNavigation.goToNext(
                                  context, 'agile_epics_features'),
                              onExportPdf: _exportPdf),
                          const SizedBox(height: 32),
                        if (_isLoading)
                          const Center(child: CircularProgressIndicator())
                        else ...[
                          // ── Toolbar: WBS pull + KAZ AI (wraps on narrow) ──
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              ConstrainedBox(
                                constraints: const BoxConstraints(
                                    minWidth: 220, maxWidth: 420),
                                child: const Text(
                                    'Epics and features pulled live from your WBS — edit or extend them below.',
                                    style: TextStyle(
                                        fontSize: 15, color: _kMuted)),
                              ),
                              OutlinedButton.icon(
                                onPressed: _isSyncing ? null : _syncFromWbs,
                                icon: _isSyncing
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2))
                                    : const Icon(Icons.link, size: 18),
                                label: Text(_isSyncing
                                    ? 'Syncing...'
                                    : 'Sync from WBS'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFF059669),
                                  side: const BorderSide(
                                      color: Color(0xFF059669)),
                                ),
                              ),
                              OutlinedButton.icon(
                                onPressed:
                                    _isGenerating ? null : _generateEpics,
                                icon: _isGenerating
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2))
                                    : const Icon(Icons.auto_awesome, size: 18),
                                label: Text(_isGenerating
                                    ? 'Generating...'
                                    : 'AI Generate'),
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
                              if (_epics.isNotEmpty) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: _kYellow.withValues(alpha: 0.16),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text('${_epics.length}',
                                      style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF8A6A00))),
                                ),
                              ],
                              const Spacer(),
                              FilledButton.icon(
                                onPressed: _addEpic,
                                icon: const Icon(Icons.add, size: 16),
                                label: const Text('Add Epic'),
                                style: FilledButton.styleFrom(
                                  backgroundColor: _kYellow,
                                  foregroundColor: _kDarkText,
                                  minimumSize: const Size(0, 40),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10)),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          if (_epics.isEmpty)
                            _buildEmptyState(
                              _isSyncing
                                  ? 'Syncing epics from your WBS…'
                                  : 'No epics yet. Pull epics and features straight from the WBS you built — or let KAZ AI suggest a starting set.',
                              onSync: _isSyncing ? null : _syncFromWbs,
                            )
                          else
                            // ── Responsive epic grid: >1200 → 3 cols,
                            //    >760 → 2 cols, else 1 col ────────────────
                            LayoutBuilder(
                              builder: (context, constraints) {
                                final double w = constraints.maxWidth;
                                final int cols =
                                    w > 1200 ? 3 : (w > 760 ? 2 : 1);
                                return GridView.builder(
                                  shrinkWrap: true,
                                  physics:
                                      const NeverScrollableScrollPhysics(),
                                  padding: EdgeInsets.zero,
                                  gridDelegate:
                                      SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: cols,
                                    crossAxisSpacing: 14,
                                    mainAxisSpacing: 14,
                                    mainAxisExtent: 236,
                                  ),
                                  itemCount: _epics.length,
                                  itemBuilder: (context, i) =>
                                      _buildEpicCard(i, _epics[i]),
                                );
                              },
                            ),
                          const SizedBox(height: 28),
                          if (_selectedEpicId != null) ...[
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    'Features — ${_selectedEpic?.title.isNotEmpty == true ? _selectedEpic!.title : 'selected epic'}',
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: _kHeadline),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: _kBorder.withValues(alpha: 0.3),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text('${_features.length}',
                                      style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: _kMuted)),
                                ),
                                const Spacer(),
                                TextButton.icon(
                                  onPressed: _addFeature,
                                  icon: const Icon(Icons.add, size: 18),
                                  label: const Text('Add Feature'),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            if (_features.isEmpty)
                              _buildEmptyState(
                                  'No features yet for this epic. Add one with “Add Feature”, or click “Sync from WBS” to pull this epic\'s level-2 nodes.')
                            else
                              ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: _features.length,
                                itemBuilder: (context, i) =>
                                    _buildFeatureRow(i, _features[i]),
                              ),
                          ],
                        ],
                        const SizedBox(height: 24),
                        LaunchPhaseNavigation(
                          backLabel: PlanningPhaseNavigation.backLabel(
                              'agile_epics_features'),
                          nextLabel: PlanningPhaseNavigation.nextLabel(
                              'agile_epics_features'),
                          onBack: () => PlanningPhaseNavigation.goToPrevious(
                              context, 'agile_epics_features'),
                          onNext: () => PlanningPhaseNavigation.goToNext(
                              context, 'agile_epics_features'),
                        ),
                        const SizedBox(height: 40),
                      ],
                    ),
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

  // ───────────────────────────────────────────────────────────────────────
  // EPIC CARD (grid) — presentation surface: code chip, name, description,
  // feature chips, hover elevation, ⋮ overflow (Edit / Delete). Inline
  // editors moved into the ⋮ → Edit dialog so cards stay clean.
  // ───────────────────────────────────────────────────────────────────────
  Widget _buildEpicCard(int index, Epic epic) {
    final isSelected = epic.id == _selectedEpicId;
    final epicFeatures = _featuresByEpic[epic.id] ?? const <Feature>[];
    final Color chipColor = _kEpicPalette[index % _kEpicPalette.length];
    final String code = _epicCode(epic, index);

    return _HoverBuilder(
      builder: (context, hovered) => AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
              color: isSelected ? _kYellow : _kBorder,
              width: isSelected ? 2 : 1),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? _kYellow.withValues(alpha: 0.18)
                  : hovered
                      ? Colors.black.withValues(alpha: 0.10)
                      : Colors.black.withValues(alpha: 0.04),
              blurRadius: isSelected || hovered ? 18 : 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () {
              setState(() => _selectedEpicId = epic.id);
              _loadFeatures();
            },
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Header: code chip + name + count + ⋮ ────────────
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: chipColor.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: chipColor.withValues(alpha: 0.35)),
                        ),
                        child: Text(
                          code,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.3,
                            color: Color.lerp(chipColor, Colors.black, 0.3),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          epic.title.isEmpty ? 'Untitled epic' : epic.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: _kDarkText),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Tooltip(
                        message: epicFeatures.isEmpty
                            ? 'No features yet'
                            : '${epicFeatures.length} feature${epicFeatures.length == 1 ? '' : 's'}',
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF3F4F6),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.view_module,
                                  size: 11, color: Color(0xFF6B7280)),
                              const SizedBox(width: 4),
                              Text('${epicFeatures.length}',
                                  style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF4B5563))),
                            ],
                          ),
                        ),
                      ),
                      _epicOverflowMenu(epic),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // ── Description (2-line ellipsis) ────────────────────
                  Text(
                    epic.description.isEmpty
                        ? 'No description yet — use ⋮ → Edit to add one.'
                        : epic.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 12,
                        height: 1.4,
                        color: epic.description.isEmpty
                            ? _kMuted.withValues(alpha: 0.7)
                            : _kMuted),
                  ),
                  const SizedBox(height: 12),
                  // ── Feature chips (status dot + priority) ───────────
                  if (epicFeatures.isEmpty)
                    const Text(
                      'No features yet — sync from WBS or use “Add Feature”.',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 11,
                          fontStyle: FontStyle.italic,
                          color: Color(0xFF9CA3AF)),
                    )
                  else
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final feature in epicFeatures.take(3))
                          _buildFeatureChip(feature),
                        if (epicFeatures.length > 3)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF9FAFB),
                              borderRadius: BorderRadius.circular(8),
                              border:
                                  Border.all(color: _kBorder, width: 0.6),
                            ),
                            child: Text(
                              '+${epicFeatures.length - 3} more',
                              style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: _kMuted),
                            ),
                          ),
                      ],
                    ),
                  const Spacer(),
                  // ── Footer: status · points · WBS traceability ──────
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color:
                              _statusColor(epic.status).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                  color: _statusColor(epic.status),
                                  shape: BoxShape.circle),
                            ),
                            const SizedBox(width: 5),
                            Text(epic.status,
                                style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: _statusColor(epic.status))),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                          '${epic.totalStoryPoints.toStringAsFixed(0)} pts',
                          style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: _kMuted)),
                      const Spacer(),
                      if (epic.wbsId.isNotEmpty)
                        const Tooltip(
                          message: 'Synced from WBS',
                          child: Icon(Icons.link,
                              size: 14, color: Color(0xFF059669)),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Code chip label: the WBS code (G1, G2, …) for synced epics, or a
  /// sequential E-code for epics created manually / via AI Generate.
  String _epicCode(Epic epic, int index) {
    final wbsCode =
        epic.wbsId.isNotEmpty ? _wbsCodeById[epic.wbsId] : null;
    if (wbsCode != null && wbsCode.isNotEmpty && wbsCode != '0') {
      return wbsCode;
    }
    return 'E${index + 1}';
  }

  /// ⋮ overflow menu — Edit opens the shared editor dialog (same save
  /// path as the previous inline editors), Delete removes the epic.
  Widget _epicOverflowMenu(Epic epic) {
    return PopupMenuButton<String>(
      tooltip: 'More actions',
      icon: const Icon(Icons.more_vert, size: 18, color: Color(0xFF6B7280)),
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onSelected: (value) {
        if (value == 'edit') {
          _showEpicEditorDialog(epic);
        } else if (value == 'delete') {
          final idx = _epics.indexOf(epic);
          if (idx >= 0) _deleteEpic(idx);
        }
      },
      itemBuilder: (_) => [
        const PopupMenuItem(
          value: 'edit',
          height: 40,
          child: Row(children: [
            Icon(Icons.edit_outlined, size: 16, color: Color(0xFF6B7280)),
            SizedBox(width: 8),
            Text('Edit', style: TextStyle(fontSize: 13)),
          ]),
        ),
        const PopupMenuItem(
          value: 'delete',
          height: 40,
          child: Row(children: [
            Icon(Icons.delete_outline, size: 16, color: Color(0xFFEF4444)),
            SizedBox(width: 8),
            Text('Delete',
                style: TextStyle(fontSize: 13, color: Color(0xFFEF4444))),
          ]),
        ),
      ],
    );
  }

  /// Compact feature chip shown on an epic card: status dot + title +
  /// priority mini-chip.
  Widget _buildFeatureChip(Feature feature) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _kBorder, width: 0.6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
                color: _statusColor(feature.status), shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 110),
            child: Text(
              feature.title.isEmpty ? 'Untitled feature' : feature.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w600, color: _kDarkText),
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              color:
                  _priorityColor(feature.priority).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              feature.priority,
              style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: _priorityColor(feature.priority)),
            ),
          ),
        ],
      ),
    );
  }

  /// Polished feature list row for the selected epic: status dot, title,
  /// 2-line description, priority chip, points, and quiet edit/delete.
  Widget _buildFeatureRow(int index, Feature feature) {
    return _HoverBuilder(
      builder: (context, hovered) => AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _kBorder),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: hovered ? 0.08 : 0.03),
              blurRadius: hovered ? 14 : 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Tooltip(
              message: 'Status: ${feature.status}',
              child: Container(
                width: 10,
                height: 10,
                margin: const EdgeInsets.only(top: 4),
                decoration: BoxDecoration(
                    color: _statusColor(feature.status),
                    shape: BoxShape.circle),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          feature.title.isEmpty
                              ? 'Untitled feature'
                              : feature.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              color: _kDarkText),
                        ),
                      ),
                      if (feature.wbsId.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        const Tooltip(
                          message: 'Synced from WBS',
                          child: Icon(Icons.link,
                              size: 14, color: Color(0xFF059669)),
                        ),
                      ],
                    ],
                  ),
                  if (feature.description.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      feature.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 12, color: _kMuted, height: 1.35),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color:
                    _priorityColor(feature.priority).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                feature.priority,
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: _priorityColor(feature.priority)),
              ),
            ),
            const SizedBox(width: 10),
            Text('${feature.storyPointEstimate.toStringAsFixed(0)} pts',
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: _kMuted)),
            const SizedBox(width: 4),
            IconButton(
              tooltip: 'Edit',
              icon: const Icon(Icons.edit_outlined,
                  size: 16, color: Color(0xFF6B7280)),
              onPressed: () => _showFeatureEditorDialog(feature),
              constraints:
                  const BoxConstraints(minWidth: 30, minHeight: 30),
              padding: EdgeInsets.zero,
            ),
            IconButton(
              tooltip: 'Delete',
              icon: const Icon(Icons.delete_outline,
                  size: 16, color: Color(0xFFEF4444)),
              onPressed: () => _deleteFeature(index),
              constraints:
                  const BoxConstraints(minWidth: 30, minHeight: 30),
              padding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'active':
        return const Color(0xFFFFC812);
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
        return const Color(0xFFFFC812);
      default:
        return Colors.grey;
    }
  }

  // ── Editor dialogs (opened from ⋮ / ✎) ──────────────────────────────
  // These reuse the EXISTING editor logic and save path: the same managed
  // controller maps the KAZ-AI regenerate helpers write to, and the same
  // onChanged → mutate model → _updateEpic/_updateFeature →
  // EpicFeatureService.saveEpic/saveFeature flow the inline editors used.

  InputDecoration _editorFieldDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      isDense: true,
      filled: true,
      fillColor: Colors.white,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _kBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _kYellow, width: 1.5),
      ),
    );
  }

  Widget _editorLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(text.toUpperCase(),
          style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
              color: Color(0xFF6B7280))),
    );
  }

  Widget _editorAiButton(String tooltip, VoidCallback onPressed) {
    return IconButton(
      tooltip: tooltip,
      icon: const Icon(Icons.auto_awesome,
          color: Color(0xFFF59E0B), size: 16),
      onPressed: onPressed,
      constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
      padding: EdgeInsets.zero,
    );
  }

  Future<void> _showEpicEditorDialog(Epic epic) async {
    // Refresh the shared controllers to the epic's current values — the
    // maps persist across dialog opens, so stale text must be re-synced.
    _getController(_epicControllers, epic.id, epic.title).text = epic.title;
    _getController(_epicControllers, '${epic.id}_desc', epic.description)
        .text = epic.description;
    _getController(_chipControllers, '${epic.id}_Theme', epic.theme).text =
        epic.theme;
    _getController(_chipControllers, '${epic.id}_Value', epic.businessValue)
        .text = epic.businessValue;

    await showDialog<void>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              const Icon(Icons.edit_note, color: Color(0xFFB27A00), size: 20),
              const SizedBox(width: 8),
              const Text('Edit Epic',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: _kDarkText)),
              const Spacer(),
              if (epic.wbsId.isNotEmpty)
                const Tooltip(
                  message: 'Synced from WBS',
                  child: Icon(Icons.link, size: 16, color: Color(0xFF059669)),
                ),
            ],
          ),
          content: SizedBox(
            width: 460,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _editorLabel('Title'),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: VoiceTextField(
                          controller: _getController(
                              _epicControllers, epic.id, epic.title),
                          decoration:
                              _editorFieldDecoration('Epic title'),
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: _kDarkText),
                          onChanged: (v) {
                            epic.title = v;
                            _updateEpic(epic);
                          },
                        ),
                      ),
                      _editorAiButton('KAZ AI — suggest title', () async {
                        await _regenerateEpicField(epic, 'title');
                        setDialogState(() {});
                      }),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _editorLabel('Description'),
                  VoiceTextField(
                    controller: _getController(_epicControllers,
                        '${epic.id}_desc', epic.description),
                    decoration: _editorFieldDecoration(
                        'What is this epic about?'),
                    style: const TextStyle(
                        fontSize: 13, color: _kDarkText),
                    maxLines: 3,
                    minLines: 3,
                    onChanged: (v) {
                      epic.description = v;
                      _updateEpic(epic);
                    },
                  ),
                  const SizedBox(height: 14),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _editorLabel('Theme'),
                            VoiceTextField(
                              controller: _getController(_chipControllers,
                                  '${epic.id}_Theme', epic.theme),
                              decoration: _editorFieldDecoration(
                                  'e.g. Onboarding'),
                              style: const TextStyle(
                                  fontSize: 13, color: _kDarkText),
                              onChanged: (v) {
                                epic.theme = v;
                                _updateEpic(epic);
                              },
                            ),
                          ],
                        ),
                      ),
                      _editorAiButton('KAZ AI — suggest theme', () async {
                        await _regenerateEpicField(epic, 'theme');
                        setDialogState(() {});
                      }),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _editorLabel('Business value'),
                            VoiceTextField(
                              controller: _getController(_chipControllers,
                                  '${epic.id}_Value', epic.businessValue),
                              decoration: _editorFieldDecoration(
                                  'Why does this matter?'),
                              style: const TextStyle(
                                  fontSize: 13, color: _kDarkText),
                              onChanged: (v) {
                                epic.businessValue = v;
                                _updateEpic(epic);
                              },
                            ),
                          ],
                        ),
                      ),
                      _editorAiButton(
                          'KAZ AI — suggest business value', () async {
                        await _regenerateEpicField(epic, 'businessValue');
                        setDialogState(() {});
                      }),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _editorLabel('Status'),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _kBorder),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: epic.status,
                        isExpanded: true,
                        items:
                            ['backlog', 'active', 'complete', 'cancelled']
                                .map((s) => DropdownMenuItem(
                                    value: s,
                                    child: Row(children: [
                                      Container(
                                        width: 8,
                                        height: 8,
                                        decoration: BoxDecoration(
                                            color: _statusColor(s),
                                            shape: BoxShape.circle),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(s,
                                          style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              color: _statusColor(s))),
                                    ])))
                                .toList(),
                        onChanged: (v) {
                          if (v == null) return;
                          setDialogState(() => epic.status = v);
                          _updateEpic(epic);
                          setState(() {});
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Close', style: TextStyle(color: _kMuted)),
            ),
            FilledButton(
              onPressed: () {
                _updateEpic(epic);
                setState(() {});
                Navigator.pop(dialogCtx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Epic saved.'),
                    behavior: SnackBarBehavior.floating,
                    backgroundColor: Color(0xFF059669),
                  ),
                );
              },
              style: FilledButton.styleFrom(
                backgroundColor: _kYellow,
                foregroundColor: _kDarkText,
              ),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showFeatureEditorDialog(Feature feature) async {
    _getController(_featureControllers, feature.id, feature.title).text =
        feature.title;
    _getController(
            _featureControllers, '${feature.id}_desc', feature.description)
        .text = feature.description;

    await showDialog<void>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              const Icon(Icons.edit_note, color: Color(0xFFB27A00), size: 20),
              const SizedBox(width: 8),
              const Text('Edit Feature',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: _kDarkText)),
              const Spacer(),
              if (feature.wbsId.isNotEmpty)
                const Tooltip(
                  message: 'Synced from WBS',
                  child: Icon(Icons.link, size: 16, color: Color(0xFF059669)),
                ),
            ],
          ),
          content: SizedBox(
            width: 440,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _editorLabel('Title'),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: VoiceTextField(
                          controller: _getController(
                              _featureControllers, feature.id, feature.title),
                          decoration:
                              _editorFieldDecoration('Feature title'),
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: _kDarkText),
                          onChanged: (v) {
                            feature.title = v;
                            _updateFeature(feature);
                          },
                        ),
                      ),
                      _editorAiButton('KAZ AI — suggest title', () async {
                        await _regenerateFeatureField(feature, 'title');
                        setDialogState(() {});
                      }),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _editorLabel('Description'),
                  VoiceTextField(
                    controller: _getController(_featureControllers,
                        '${feature.id}_desc', feature.description),
                    decoration: _editorFieldDecoration(
                        'Describe this feature'),
                    style: const TextStyle(
                        fontSize: 13, color: _kDarkText),
                    maxLines: 3,
                    minLines: 3,
                    onChanged: (v) {
                      feature.description = v;
                      _updateFeature(feature);
                    },
                  ),
                  const SizedBox(height: 14),
                  _editorLabel('Priority'),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _kBorder),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: feature.priority,
                        isExpanded: true,
                        items: ['critical', 'high', 'medium', 'low']
                            .map((p) => DropdownMenuItem(
                                value: p,
                                child: Row(children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                        color: _priorityColor(p),
                                        shape: BoxShape.circle),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(p,
                                      style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: _priorityColor(p))),
                                ])))
                            .toList(),
                        onChanged: (v) {
                          if (v == null) return;
                          setDialogState(() => feature.priority = v);
                          _updateFeature(feature);
                          setState(() {});
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                      'Est: ${feature.storyPointEstimate.toStringAsFixed(0)} pts  ·  Status: ${feature.status}',
                      style: const TextStyle(
                          fontSize: 11, color: _kMuted)),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Close', style: TextStyle(color: _kMuted)),
            ),
            FilledButton(
              onPressed: () {
                _updateFeature(feature);
                setState(() {});
                Navigator.pop(dialogCtx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Feature saved.'),
                    behavior: SnackBarBehavior.floating,
                    backgroundColor: Color(0xFF059669),
                  ),
                );
              },
              style: FilledButton.styleFrom(
                backgroundColor: _kYellow,
                foregroundColor: _kDarkText,
              ),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(String message, {VoidCallback? onSync}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFDF5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kYellow.withValues(alpha: 0.35)),
      ),
      child: Column(
        children: [
          Icon(Icons.auto_awesome_mosaic,
              size: 36, color: _kYellow.withValues(alpha: 0.7)),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: _kMuted, fontSize: 13.5, height: 1.5),
          ),
          if (onSync != null) ...[
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: onSync,
              icon: _isSyncing
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: _kDarkText))
                  : const Icon(Icons.link, size: 16),
              label: Text(_isSyncing ? 'Syncing…' : 'Sync from WBS'),
              style: FilledButton.styleFrom(
                backgroundColor: _kYellow,
                foregroundColor: _kDarkText,
                minimumSize: const Size(0, 40),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ],
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
        PdfSection.text(
            'Notes',
            projectData.planningNotes['planning_agile_epics_features_notes'] ??
                'No data recorded.'),
      ],
    );
  }
}

/// Local hover-state helper (MouseRegion) used by epic grid cards and
/// feature rows to animate elevation on hover — same pattern as the WBS
/// builder screen's node cards.
class _HoverBuilder extends StatefulWidget {
  const _HoverBuilder({required this.builder});
  final Widget Function(BuildContext context, bool hovered) builder;
  @override
  State<_HoverBuilder> createState() => _HoverBuilderState();
}

class _HoverBuilderState extends State<_HoverBuilder> {
  bool _hovered = false;
  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: widget.builder(context, _hovered),
    );
  }
}
