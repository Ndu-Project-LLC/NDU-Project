import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:ndu_project/providers/project_data_provider.dart';
import 'package:ndu_project/services/agile_wireframe_service.dart';
import 'package:ndu_project/services/openai_service_secure.dart';
import 'package:ndu_project/utils/planning_phase_navigation.dart';
import 'package:ndu_project/utils/project_data_helper.dart';
import 'package:ndu_project/widgets/draggable_sidebar.dart';
import 'package:ndu_project/widgets/field_regenerate_undo_buttons.dart';
import 'package:ndu_project/widgets/initiation_like_sidebar.dart';
import 'package:ndu_project/widgets/kaz_ai_chat_bubble.dart';
import 'package:ndu_project/widgets/launch_phase_navigation.dart';
import 'package:ndu_project/widgets/planning_phase_header.dart';
import 'package:ndu_project/widgets/responsive.dart';
import 'package:ndu_project/widgets/voice_text_field.dart';
import 'package:ndu_project/widgets/delete_confirmation_dialog.dart';
import 'package:ndu_project/utils/pdf_export_helper.dart';

const Color _kBackground = Colors.white;
const Color _kBorder = Color(0xFFE5E7EB);
const Color _kMuted = Color(0xFF6B7280);
const Color _kHeadline = Color(0xFF111827);
const Color _kAccent = Color(0xFFD97706);

class TeamRow {
  String id;
  String name;
  String role;
  String count;
  String skills;

  TeamRow({
    String? id,
    this.name = '',
    this.role = '',
    this.count = '1',
    this.skills = '',
  }) : id = id ?? DateTime.now().microsecondsSinceEpoch.toString();
}

class AgileTeamStructureScreen extends StatefulWidget {
  const AgileTeamStructureScreen({super.key});

  @override
  State<AgileTeamStructureScreen> createState() =>
      _AgileTeamStructureScreenState();
}

class _AgileTeamStructureScreenState extends State<AgileTeamStructureScreen> {
  List<TeamRow> _teams = [];
  final Map<String, TextEditingController> _noteControllers = {};
  final Map<String, List<TextEditingController>> _teamControllers = {};
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isGenerating = false;
  Timer? _autoSaveDebounce;

  // ── Per-field history + AI state ─────────────────────────────────────
  final Map<String, List<String>> _fieldHistories = {};
  final Map<String, int> _fieldHistoryIndices = {};
  final Map<String, bool> _fieldIsAiGenerated = {};
  final Map<String, bool> _fieldIsRegenerating = {};

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

  @override
  void dispose() {
    _autoSaveDebounce?.cancel();
    for (final c in _noteControllers.values) {
      c.dispose();
    }
    for (final controllers in _teamControllers.values) {
      for (final c in controllers) {
        c.dispose();
      }
    }
    super.dispose();
  }

  Future<void> _loadData() async {
    final pid = _projectId;
    if (pid == null) return;
    setState(() => _isLoading = true);
    try {
      final data = await AgileWireframeService.loadTeamStructure(pid);
      if (!mounted) return;
      final rows = (data['rows'] as List?)
              ?.map((e) => TeamRow(
                    id: e['id'] as String?,
                    name: e['name'] as String? ?? '',
                    role: e['role'] as String? ?? '',
                    count: e['count'] as String? ?? '1',
                    skills: e['skills'] as String? ?? '',
                  ))
              .toList() ??
          [];
      var notesText = data['notes'] as String? ?? '';
      if (rows.isEmpty && notesText.isEmpty) {
        final dm = await AgileWireframeService.loadDeliveryModel(pid);
        notesText = dm['team'] as String? ?? '';
      }
      // Dispose stale team controllers
      for (final controllers in _teamControllers.values) {
        for (final c in controllers) {
          c.dispose();
        }
      }
      _teamControllers.clear();
      // Dispose and recreate notes controller
      _noteControllers['notes']?.dispose();
      final notesCtrl = TextEditingController(text: notesText);
      _noteControllers['notes'] = notesCtrl;
      setState(() {
        _teams = rows;
        _isLoading = false;
      });

      if (rows.isEmpty && mounted) {
        _silentImportFromOrgPlan();
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _silentImportFromOrgPlan() async {
    final pid = _projectId;
    if (pid == null || !mounted) return;
    try {
      final rolesSnapshot = await FirebaseFirestore.instance
          .collection('projects')
          .doc(pid)
          .collection('organization_plan_sections')
          .doc('roles_responsibilities')
          .collection('roles')
          .get();
      final imported = <TeamRow>[];
      if (rolesSnapshot.docs.isNotEmpty) {
        final Map<String, List<Map<String, dynamic>>> rolesByTitle = {};
        for (final doc in rolesSnapshot.docs) {
          final d = doc.data();
          final title = (d['title'] as String?)?.trim() ?? '';
          if (title.isEmpty) continue;
          rolesByTitle.putIfAbsent(title, () => []).add(d);
        }
        for (final entry in rolesByTitle.entries) {
          imported.add(TeamRow(
            name: entry.key,
            role: entry.key,
            count: entry.value.length.toString(),
            skills: entry.value
                .map((p) => (p['department'] as String?)?.trim())
                .where((d) => d != null && d.isNotEmpty)
                .join(', '),
          ));
        }
      }
      final data = ProjectDataHelper.getData(context);
      if (data.staffingRequirements != null) {
        for (final s in data.staffingRequirements!) {
          final title = (s.title ?? '').trim();
          if (title.isEmpty) continue;
          final existingIdx = imported.indexWhere((t) => t.name == title);
          if (existingIdx >= 0) {
            imported[existingIdx].count =
                ((int.tryParse(imported[existingIdx].count) ?? 0) +
                        (s.headcount ?? 1))
                    .toString();
          } else {
            imported.add(TeamRow(
                name: title,
                role: title,
                count: (s.headcount ?? 1).toString()));
          }
        }
      }
      if (imported.isNotEmpty && mounted) {
        setState(() => _teams = imported);
        await _performSave();
      }
    } catch (_) {}
  }

  void _scheduleAutoSave() {
    _autoSaveDebounce?.cancel();
    _autoSaveDebounce =
        Timer(const Duration(milliseconds: 500), () => _performSave());
  }

  Future<void> _performSave() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    try {
      await _saveData();
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Saved'), duration: Duration(seconds: 1)),
        );
      }
    } catch (e) {
      debugPrint('Error: $e');
    }
    if (mounted) setState(() => _isSaving = false);
  }

  // ── Field history tracking for undo/redo ─────────────────────────────
  void _recordFieldHistory(String key, String value, {bool isAi = false}) {
    final history = _fieldHistories.putIfAbsent(key, () => []);
    final index = _fieldHistoryIndices.putIfAbsent(key, () => -1);
    if (index < history.length - 1) {
      history.removeRange(index + 1, history.length);
    }
    if (history.isEmpty || history.last != value) {
      history.add(value);
      _fieldHistoryIndices[key] = history.length - 1;
    }
    if (isAi) _fieldIsAiGenerated[key] = true;
  }

  bool _canUndoField(String key) => (_fieldHistoryIndices[key] ?? -1) > 0;

  bool _canRedoField(String key) {
    final idx = _fieldHistoryIndices[key] ?? -1;
    final history = _fieldHistories[key] ?? [];
    return idx >= 0 && idx < history.length - 1;
  }

  void _undoField(String key, TextEditingController controller) {
    if (!_canUndoField(key)) return;
    final idx = _fieldHistoryIndices[key]! - 1;
    _fieldHistoryIndices[key] = idx;
    controller.text = _fieldHistories[key]![idx];
    _scheduleAutoSave();
  }

  void _redoField(String key, TextEditingController controller) {
    if (!_canRedoField(key)) return;
    final idx = _fieldHistoryIndices[key]! + 1;
    _fieldHistoryIndices[key] = idx;
    controller.text = _fieldHistories[key]![idx];
    _scheduleAutoSave();
  }

  // ── Per-field AI regeneration ────────────────────────────────────────
  Future<void> _regenerateField(
      String key, String label, TextEditingController controller) async {
    setState(() => _fieldIsRegenerating[key] = true);
    try {
      final data = ProjectDataHelper.getData(context);
      final contextText =
          ProjectDataHelper.buildProjectContextScan(data, sectionLabel: label);
      final openai = OpenAiServiceSecure();
      final result = await openai.generateCompletion(
        'Based on this project context, regenerate the "$label" field.\n\n'
        'Context:\n$contextText\n\n'
        'Current value:\n${controller.text.isEmpty ? "(empty)" : controller.text}\n\n'
        'Provide a concise, specific recommendation for this field. '
        'Return ONLY the text content (no JSON, no markdown headers).',
        maxTokens: 200,
        temperature: 0.6,
      );
      final cleaned = result.trim();
      if (cleaned.isNotEmpty) {
        controller.text = cleaned;
        _recordFieldHistory(key, cleaned, isAi: true);
        _scheduleAutoSave();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('AI regeneration failed: $e')),
        );
      }
    }
    if (mounted) setState(() => _fieldIsRegenerating[key] = false);
  }

  // ── Build an enhanced field with KAZ AI + clear + formatting toolbar ─
  Widget _buildEnhancedField({
    required String key,
    required String label,
    required TextEditingController controller,
    String? hint,
    int minLines = 1,
    int maxLines = 1,
    bool isDense = true,
    bool showInlineActions = false,
  }) {
    final isRegenerating = _fieldIsRegenerating[key] ?? false;
    final isAiGenerated = _fieldIsAiGenerated[key] ?? false;
    final hasContent = controller.text.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Label row with AI badge ──────────────────────────────
        Wrap(
          spacing: 8,
          runSpacing: 6,
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _kHeadline)),
            if (isAiGenerated)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7E6),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.auto_awesome, size: 9, color: Color(0xFFD97706)),
                    SizedBox(width: 2),
                    Text('AI',
                        style: TextStyle(
                            fontSize: 8,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFD97706))),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),

        // ── Text formatting toolbar ──────────────────────────────
        const SizedBox(height: 2),

        // ── Hoverable field with AI controls ─────────────────────
        HoverableFieldControls(
          isAiGenerated: isAiGenerated,
          isLoading: isRegenerating,
          canUndo: _canUndoField(key),
          canRedo: _canRedoField(key),
          onUndo: () => _undoField(key, controller),
          onRedo: () => _redoField(key, controller),
          onRegenerate: () => _regenerateField(key, label, controller),
          child: VoiceTextField(
            controller: controller,
            minLines: minLines,
            maxLines: maxLines,
            onChanged: (value) {
              _recordFieldHistory(key, value);
              _scheduleAutoSave();
              setState(() {});
            },
            decoration: InputDecoration(
              hintText: hint,
              labelText: null,
              isDense: isDense,
              border: const OutlineInputBorder(),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              suffixIcon: showInlineActions
                  ? SizedBox(
                      width: hasContent ? 72 : 38,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: 'KAZ AI',
                            icon: isRegenerating
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  )
                                : const Icon(Icons.auto_awesome,
                                    color: Color(0xFFF59E0B), size: 16),
                            onPressed: isRegenerating
                                ? null
                                : () =>
                                    _regenerateField(key, label, controller),
                            padding: const EdgeInsets.all(2),
                            constraints: const BoxConstraints(
                                minWidth: 28, minHeight: 28),
                          ),
                          if (hasContent)
                            IconButton(
                              tooltip: 'Clear all content',
                              icon: const Icon(Icons.delete_sweep,
                                  color: Color(0xFFEF4444), size: 16),
                              onPressed: () {
                                controller.clear();
                                _recordFieldHistory(key, '');
                                _scheduleAutoSave();
                                setState(() {});
                              },
                              padding: const EdgeInsets.all(2),
                              constraints: const BoxConstraints(
                                  minWidth: 28, minHeight: 28),
                            ),
                        ],
                      ),
                    )
                  : null,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _saveData() async {
    final pid = _projectId;
    if (pid == null) return;
    await AgileWireframeService.saveTeamStructure(
      projectId: pid,
      data: {
        'rows': _teams
            .map((t) => {
                  'id': t.id,
                  'name': t.name,
                  'role': t.role,
                  'count': t.count,
                  'skills': t.skills,
                })
            .toList(),
        'notes': _noteControllers['notes']?.text ?? '',
      },
    );
  }

  void _addTeam() {
    setState(() => _teams.add(TeamRow()));
    _scheduleAutoSave();
  }

  Future<void> _removeTeam(int index) async {
    final confirmed = await showDeleteConfirmationDialog(
      context,
      title: 'Delete Team',
      itemLabel: _teams[index].name.isNotEmpty ? _teams[index].name : null,
    );
    if (!confirmed) return;
    final removed = _teams[index];
    final controllers = _teamControllers.remove(removed.id);
    if (controllers != null) {
      for (final c in controllers) {
        c.dispose();
      }
    }
    setState(() => _teams.removeAt(index));
    _scheduleAutoSave();
  }

  Future<void> _generateWithAI() async {
    final pid = _projectId;
    if (pid == null) return;
    setState(() => _isGenerating = true);
    try {
      final data = ProjectDataHelper.getData(context);
      final contextText = ProjectDataHelper.buildProjectContextScan(data,
          sectionLabel: 'Agile Team Structure');
      final openai = OpenAiServiceSecure();
      final result = await openai.generateCompletion(
        'Based on this project context, suggest agile team squads.\n\n'
        'Context:\n$contextText\n\n'
        'Suggest 3-5 squads. For each provide: squad name, primary role, team size, and key skills.\n'
        'Return as a JSON array with keys: name, role, count, skills.',
        maxTokens: 1000,
        temperature: 0.5,
      );
      final parsed = _parseTeamGeneration(result);
      if (parsed.isNotEmpty) {
        setState(() => _teams = parsed);
        _performSave();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('AI did not return valid team data. Try again.')),
          );
        }
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

  Future<void> _loadFromOrganisationPlan() async {
    final pid = _projectId;
    if (pid == null) return;
    if (!mounted) return;

    setState(() => _isGenerating = true);
    try {
      StringBuffer summary = StringBuffer();
      final List<TeamRow> imported = [];

      // 1. Read org roles subcollection
      final rolesSnapshot = await FirebaseFirestore.instance
          .collection('projects')
          .doc(pid)
          .collection('organization_plan_sections')
          .doc('roles_responsibilities')
          .collection('roles')
          .get();

      if (rolesSnapshot.docs.isNotEmpty) {
        final Map<String, List<Map<String, dynamic>>> rolesByTitle = {};
        for (final doc in rolesSnapshot.docs) {
          final data = doc.data();
          final title = (data['title'] as String?)?.trim() ?? '';
          if (title.isEmpty) continue;
          rolesByTitle.putIfAbsent(title, () => []).add(data);
        }
        for (final entry in rolesByTitle.entries) {
          final people = entry.value;
          final depts = people
              .map((p) => (p['department'] as String?)?.trim())
              .where((d) => d != null && d.isNotEmpty)
              .toSet()
              .join(', ');
          final placements = people
              .map((p) => (p['teamPlacement'] as String?)?.trim())
              .where((p) => p != null && p.isNotEmpty)
              .toSet()
              .join(', ');
          imported.add(TeamRow(
            name: entry.key,
            role: entry.key,
            count: people.length.toString(),
            skills:
                'Dept: $depts${placements.isNotEmpty ? ' | $placements' : ''}',
          ));
        }
        summary.writeln(
            '  • ${rolesByTitle.length} role groups from Roles & Responsibilities');
      }

      // 2. Read staffing requirements from ProjectDataModel
      final data = ProjectDataHelper.getData(context);
      final staffing = data.staffingRequirements;
      if (staffing != null && staffing.isNotEmpty) {
        final Map<String, int> headcountByTitle = {};
        final Map<String, Set<String>> notesByTitle = {};
        for (final s in staffing) {
          final title = (s.title ?? '').trim();
          if (title.isEmpty) continue;
          headcountByTitle[title] =
              (headcountByTitle[title] ?? 0) + (s.headcount ?? 1);
          if ((s.notes ?? '').isNotEmpty) {
            notesByTitle.putIfAbsent(title, () => {}).add(s.notes!);
          }
        }
        for (final entry in headcountByTitle.entries) {
          final existingIdx = imported.indexWhere((t) => t.name == entry.key);
          if (existingIdx >= 0) {
            final currentCount = int.tryParse(imported[existingIdx].count) ?? 0;
            imported[existingIdx].count =
                (currentCount + entry.value).toString();
          } else {
            imported.add(TeamRow(
              name: entry.key,
              role: entry.key,
              count: entry.value.toString(),
              skills: notesByTitle[entry.key]?.join('; ') ?? '',
            ));
          }
        }
        summary.writeln(
            '  • ${headcountByTitle.length} role groups from Staffing Plan');
      }

      // 3. Read team members from ProjectDataModel
      final members = data.teamMembers;
      if (members != null && members.isNotEmpty) {
        final Map<String, List<String>> membersByRole = {};
        for (final m in members) {
          final role = (m.role ?? '').trim();
          if (role.isEmpty) continue;
          membersByRole.putIfAbsent(role, () => []).add(
              '${m.name ?? ''}${m.responsibilities != null && m.responsibilities!.isNotEmpty ? ' (${m.responsibilities})' : ''}');
        }
        for (final entry in membersByRole.entries) {
          final existingIdx = imported.indexWhere((t) => t.name == entry.key);
          if (existingIdx >= 0) {
            final memberSkills = entry.value.join('; ');
            if (imported[existingIdx].skills.isEmpty) {
              imported[existingIdx].skills = memberSkills;
            }
          } else {
            imported.add(TeamRow(
              name: entry.key,
              role: entry.key,
              count: entry.value.length.toString(),
              skills: entry.value.join('; '),
            ));
          }
        }
        summary.writeln(
            '  • ${membersByRole.length} role groups from Team Members');
      }

      if (imported.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'No organisation plan data found. Add roles in Organisation Plan first.'),
            ),
          );
        }
        return;
      }

      // Show confirmation dialog
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Import from Organisation Plan'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                  'The following data sources will be merged into team rows:'),
              const SizedBox(height: 12),
              Text(summary.toString(), style: const TextStyle(fontSize: 13)),
              const SizedBox(height: 12),
              Text(
                  '${imported.length} squads/teams will be created or updated.',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Text(
                'This will replace your current team rows.',
                style: TextStyle(fontSize: 12, color: Colors.orange.shade700),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Import'),
            ),
          ],
        ),
      );

      if (confirmed == true && mounted) {
        setState(() => _teams = imported);
        await _performSave();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load from organisation plan: $e')),
        );
      }
    }
    if (mounted) setState(() => _isGenerating = false);
  }

  List<TeamRow> _parseTeamGeneration(String text) {
    try {
      final start = text.indexOf('[');
      final end = text.lastIndexOf(']');
      if (start == -1 || end == -1) return [];
      final jsonStr = text.substring(start, end + 1);
      final list = jsonDecode(jsonStr) as List;
      return list.map<TeamRow>((e) {
        final m = e as Map<String, dynamic>;
        return TeamRow(
          name: (m['name'] ?? '').toString(),
          role: (m['role'] ?? '').toString(),
          count: (m['count'] ?? '1').toString(),
          skills: (m['skills'] ?? '').toString(),
        );
      }).toList();
    } catch (e) {
      return [];
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
                  activeItemLabel: 'Agile Delivery Model - Team Structure'),
            ),
            Expanded(
              child: Stack(
                children: [
                  MobileSidebarHamburger(
                    sidebar: const InitiationLikeSidebar(
                      activeItemLabel: 'Agile Delivery Model - Team Structure',
                    ),
                  ),
                  SingleChildScrollView(
                    padding: EdgeInsets.symmetric(horizontal: hp, vertical: 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        PlanningPhaseHeader(
                            title: 'Agile Team Structure',
                            onBack: () => PlanningPhaseNavigation.goToPrevious(
                                context, 'agile_team_structure'),
                            onForward: () => PlanningPhaseNavigation.goToNext(
                                context, 'agile_team_structure'),
                            onExportPdf: _exportPdf),
                        const SizedBox(height: 32),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            SizedBox(
                              width: 720,
                              child: _buildSectionTitle('Squads & Teams',
                                  'Define each agile squad, their primary role, team size, and required skills.'),
                            ),
                            OutlinedButton.icon(
                              onPressed: _isGenerating ? null : _generateWithAI,
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
                        const SizedBox(height: 16),
                        if (_isLoading)
                          const Center(child: CircularProgressIndicator())
                        else ...[
                          if (_isSaving)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                children: [
                                  const SizedBox(
                                      width: 12,
                                      height: 12,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2)),
                                  const SizedBox(width: 8),
                                  Text('Saving...',
                                      style: TextStyle(
                                          fontSize: 12, color: _kMuted)),
                                ],
                              ),
                            ),
                          if (_teams.isEmpty)
                            _buildEmptyState(
                                'No teams defined yet. Add your first squad.')
                          else
                            ..._teams
                                .asMap()
                                .entries
                                .map((e) => _buildTeamCard(e.key, e.value)),
                          const SizedBox(height: 16),
                          OutlinedButton.icon(
                            onPressed: _addTeam,
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('Add Squad / Team'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: _kAccent,
                              side: const BorderSide(color: _kAccent),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ],
                        const SizedBox(height: 32),
                        _buildNotesSection(),
                        const SizedBox(height: 24),
                        LaunchPhaseNavigation(
                          backLabel: PlanningPhaseNavigation.backLabel(
                              'agile_team_structure'),
                          nextLabel: PlanningPhaseNavigation.nextLabel(
                              'agile_team_structure'),
                          onBack: () => PlanningPhaseNavigation.goToPrevious(
                              context, 'agile_team_structure'),
                          onNext: () => PlanningPhaseNavigation.goToNext(
                              context, 'agile_team_structure'),
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

  List<TextEditingController> _controllersForTeam(TeamRow team) {
    if (!_teamControllers.containsKey(team.id)) {
      _teamControllers[team.id] = [
        TextEditingController(text: team.name),
        TextEditingController(text: team.count),
        TextEditingController(text: team.role),
        TextEditingController(text: team.skills),
      ];
      // Sync controller text back to the TeamRow on change
      _teamControllers[team.id]![0].addListener(() {
        team.name = _teamControllers[team.id]![0].text;
      });
      _teamControllers[team.id]![1].addListener(() {
        team.count = _teamControllers[team.id]![1].text;
      });
      _teamControllers[team.id]![2].addListener(() {
        team.role = _teamControllers[team.id]![2].text;
      });
      _teamControllers[team.id]![3].addListener(() {
        team.skills = _teamControllers[team.id]![3].text;
      });
    }
    return _teamControllers[team.id]!;
  }

  Widget _buildTeamCard(int index, TeamRow team) {
    final ctrls = _controllersForTeam(team);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: _kBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final narrow = constraints.maxWidth < 900;
                final nameField = _buildEnhancedField(
                  key: '${team.id}_name',
                  label: 'Squad / Team Name',
                  controller: ctrls[0],
                );
                final countField = TextField(
                  controller: ctrls[1],
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Count',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: (_) => _scheduleAutoSave(),
                );
                final deleteButton = Align(
                  alignment: Alignment.topRight,
                  child: IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: () => _removeTeam(index),
                  ),
                );
                if (narrow) {
                  return Column(
                    children: [
                      nameField,
                      const SizedBox(height: 12),
                      countField,
                      deleteButton,
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: nameField),
                    const SizedBox(width: 12),
                    SizedBox(width: 150, child: countField),
                    const SizedBox(width: 8),
                    deleteButton,
                  ],
                );
              },
            ),
            const SizedBox(height: 12),
            _buildEnhancedField(
              key: '${team.id}_role',
              label: 'Primary Role / Focus',
              controller: ctrls[2],
              minLines: 2,
              maxLines: 4,
            ),
            const SizedBox(height: 12),
            _buildEnhancedField(
              key: '${team.id}_skills',
              label: 'Key Skills / Cross-functional coverage',
              controller: ctrls[3],
              minLines: 2,
              maxLines: 4,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotesSection() {
    _noteControllers.putIfAbsent('notes', () => TextEditingController());
    return _buildEnhancedField(
      key: 'notes',
      label: 'Additional Notes',
      controller: _noteControllers['notes']!,
      hint: 'Team location, timezone overlaps, RACI notes...',
      minLines: 3,
      maxLines: 6,
    );
  }

  Widget _buildSectionTitle(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: const TextStyle(
                fontSize: 18, fontWeight: FontWeight.w700, color: _kHeadline)),
        const SizedBox(height: 4),
        Text(subtitle, style: TextStyle(fontSize: 14, color: _kMuted)),
      ],
    );
  }

  Widget _buildEmptyState(String message) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        border: Border.all(color: _kBorder),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Text(message, style: TextStyle(color: _kMuted, fontSize: 15)),
      ),
    );
  }

  Future<void> _exportPdf() async {
    final projectData = ProjectDataHelper.getData(context);
    await PdfExportHelper.exportScreenPdf(
      context: context,
      screenTitle: 'Agile Team Structure',
      sections: [
        PdfSection.keyValue('Project Info', [
          {
            'Project Name': projectData.projectName.isEmpty
                ? 'N/A'
                : projectData.projectName
          },
          {
            'Solution Title': projectData.solutionTitle.isEmpty
                ? 'N/A'
                : projectData.solutionTitle
          },
        ]),
        PdfSection.text(
            'Notes',
            projectData.planningNotes['planning_agile_team_structure_notes'] ??
                'No data recorded.'),
      ],
    );
  }
}
