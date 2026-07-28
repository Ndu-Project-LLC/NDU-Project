import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:ndu_project/services/openai_service_secure.dart';
import 'package:ndu_project/utils/project_data_helper.dart';
import 'package:ndu_project/models/project_data_model.dart';
import 'package:ndu_project/widgets/kaz_ai_chat_bubble.dart';
import 'package:ndu_project/widgets/responsive.dart';
import 'package:ndu_project/widgets/responsive_scaffold.dart';
import 'package:ndu_project/widgets/unified_phase_header.dart';
import 'package:ndu_project/widgets/planning_phase_header.dart';
import 'package:ndu_project/utils/planning_phase_navigation.dart';
import 'dart:math' as math;

import 'package:ndu_project/widgets/voice_text_field.dart';
import 'package:ndu_project/utils/rich_text_editing_controller.dart';
import 'package:ndu_project/widgets/text_formatting_toolbar.dart';
import 'package:ndu_project/utils/pdf_export_helper.dart';
import 'package:ndu_project/utils/csv_import_helper.dart';
import 'package:ndu_project/widgets/csv_table_import_button.dart';

class RiskAssessmentScreen extends StatefulWidget {
 const RiskAssessmentScreen({super.key});

 static void open(BuildContext context) {
 Navigator.of(context).push(
 MaterialPageRoute(builder: (_) => const RiskAssessmentScreen()),
 );
 }

 @override
 State<RiskAssessmentScreen> createState() => _RiskAssessmentScreenState();
}

class _RiskAssessmentScreenState extends State<RiskAssessmentScreen> {
 static const List<String> _riskLevelOptions = ['Low', 'Medium', 'High'];
 static const List<String> _riskStatusOptions = [
 'Open',
 'In Progress',
 'Monitoring',
 'Closed',
 ];

 final List<_RiskEntry> _entries = [];
 final TextEditingController _searchController = TextEditingController();
 String? _statusFilter;
 bool _loadingEntries = false;

 final TextEditingController _notesController = RichTextEditingController();
 final _Debouncer _notesDebounce = _Debouncer();
 final OpenAiServiceSecure _openAi = OpenAiServiceSecure();
 final Map<String, RichTextEditingController> _mitigationControllers = {};
 final Map<String, String> _mitigationPlans = {};
 final _Debouncer _mitigationDebounce = _Debouncer();
 bool _notesSaving = false;
 DateTime? _notesSavedAt;
 bool _mitigationSaving = false;
 DateTime? _mitigationSavedAt;
 bool _didInitNotes = false;
 bool _loadingMitigationSuggestions = false;
 String? _mitigationSuggestionError;final Set<String> _seededRiskDescriptions = {};
  final Set<String> _regeneratingMitigationIds = {};

  static const List<CsvColumnSpec> _riskCsvColumns = [
    CsvColumnSpec(key: 'id', label: 'Risk ID', sampleValue: 'R-001'),
    CsvColumnSpec(key: 'description', label: 'Description', required: true, sampleValue: 'Budget overrun risk'),
    CsvColumnSpec(key: 'category', label: 'Category', sampleValue: 'Financial'),
    CsvColumnSpec(key: 'probability', label: 'Probability', allowedValues: ['Low', 'Medium', 'High'], defaultValue: 'Medium'),
    CsvColumnSpec(key: 'impact', label: 'Impact', allowedValues: ['Low', 'Medium', 'High'], defaultValue: 'Medium'),
    CsvColumnSpec(key: 'score', label: 'Risk Score', sampleValue: '12'),
    CsvColumnSpec(key: 'owner', label: 'Owner', sampleValue: 'Project Manager'),
    CsvColumnSpec(key: 'status', label: 'Status', allowedValues: ['Open', 'In Progress', 'Monitoring', 'Closed'], defaultValue: 'Open'),
  ];

 @override
 void initState() {
 super.initState();
 _searchController.addListener(() {
 if (mounted) setState(() {});
 });
 WidgetsBinding.instance.addPostFrameCallback((_) => _loadEntries());
 }

 @override
 void didChangeDependencies() {
 super.didChangeDependencies();
 if (_didInitNotes) return;
 final data = ProjectDataHelper.getData(context);
 _notesController.text =
 data.planningNotes['planning_risk_assessment_notes'] ?? '';
 _didInitNotes = true;
 }

 @override
 void dispose() {
 _searchController.dispose();
 _notesController.dispose();
 _notesDebounce.dispose();
 _mitigationDebounce.dispose();
 for (final controller in _mitigationControllers.values) {
 controller.dispose();
 }
 super.dispose();
 }

 Future<void> _loadEntries() async {
 final projectId = ProjectDataHelper.getData(context).projectId;
 if (projectId == null || projectId.isEmpty) return;
 if (!mounted) return;
 setState(() => _loadingEntries = true);
 try {
 final snapshot = await FirebaseFirestore.instance
 .collection('projects')
 .doc(projectId)
 .collection('risk_assessment_entries')
 .orderBy('createdAt', descending: true)
 .get();
 final firestoreEntries =
 snapshot.docs.map((doc) => _RiskEntry.fromFirestore(doc)).toList();
 final provider = ProjectDataHelper.getProvider(context);
 final projectData = provider.projectData;
 final mergedEntries = await _mergeEntriesWithSolutionRisks(
 firestoreEntries, projectData.solutionRisks);
 if (!mounted) return;
 setState(() {
 _entries
 ..clear()
 ..addAll(mergedEntries);
 _mitigationPlans
 ..clear()
 ..addAll(projectData.riskMitigationPlans);
 _mitigationSuggestionError = null;
 });
 _ensureMitigationControllers(mergedEntries);
 await _maybeSeedMitigationPlans(mergedEntries, projectData);
 } catch (e) {
 if (mounted) {
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(content: Text('Unable to load risk register data')),
 );
 }
 } finally {
 if (mounted) setState(() => _loadingEntries = false);
 }
 }

 Future<void> _persistEntry(_RiskEntry entry, {required bool isNew}) async {
 final projectId = ProjectDataHelper.getData(context).projectId;
 if (projectId == null || projectId.isEmpty) return;
 final docRef = FirebaseFirestore.instance
 .collection('projects')
 .doc(projectId)
 .collection('risk_assessment_entries')
 .doc(entry.docId);
 await docRef.set(entry.toFirestore(isNew: isNew), SetOptions(merge: true));
 }

 void _handleNotesChanged(String value) {
 final trimmed = value.trim();
 final provider = ProjectDataHelper.getProvider(context);
 provider.updateField(
 (data) => data.copyWith(
 planningNotes: {
 ...data.planningNotes,
 'planning_risk_assessment_notes': trimmed,
 },
 ),
 );
 _notesDebounce.run(() async {
 if (!mounted) return;
 setState(() => _notesSaving = true);
 final success = await ProjectDataHelper.updateAndSave(
 context: context,
 checkpoint: 'risk_assessment',
 dataUpdater: (data) => data.copyWith(
 planningNotes: {
 ...data.planningNotes,
 'planning_risk_assessment_notes': trimmed,
 },
 ),
 showSnackbar: false,
 );
 if (!mounted) return;
 setState(() {
 _notesSaving = false;
 if (success) _notesSavedAt = DateTime.now();
 });
 });
 }

 Future<void> _openEntryDialog(
 {_RiskEntry? entry, bool readOnly = false}) async {
 final idController = TextEditingController(text: entry?.id ?? '');
 final descriptionController =
 TextEditingController(text: entry?.description ?? '');
 final categoryController =
 TextEditingController(text: entry?.category ?? '');
 final scoreController = TextEditingController(text: entry?.score ?? '');
 final ownerController = TextEditingController(text: entry?.owner ?? '');
 String selectedProbability =
 _riskLevelOptions.contains(entry?.probability ?? '')
 ? (entry?.probability ?? _riskLevelOptions[1])
 : _riskLevelOptions[1];
 String selectedImpact = _riskLevelOptions.contains(entry?.impact ?? '')
 ? (entry?.impact ?? _riskLevelOptions[1])
 : _riskLevelOptions[1];
 String selectedStatus = _riskStatusOptions.contains(entry?.status ?? '')
 ? (entry?.status ?? _riskStatusOptions.first)
 : _riskStatusOptions.first;

 final result = await showDialog<bool>(
 context: context,
 builder: (context) {
 final bool isEditing = entry != null;
 return StatefulBuilder(
 builder: (context, setLocalState) => AlertDialog(
 title: Text(readOnly
 ? 'View risk'
 : (isEditing ? 'Edit risk' : 'Add risk')),
 content: SizedBox(
 width: 440,
 child: SingleChildScrollView(
 child: Column(
 mainAxisSize: MainAxisSize.min,
 children: [
 _dialogField(
 controller: idController,
 label: 'Risk ID',
 readOnly: readOnly),
 _dialogField(
 controller: descriptionController,
 label: 'Description',
 readOnly: readOnly,
 maxLines: 2),
 _dialogField(
 controller: categoryController,
 label: 'Category',
 readOnly: readOnly),
 _dialogDropdownField(
 label: 'Probability',
 value: selectedProbability,
 options: _riskLevelOptions,
 enabled: !readOnly,
 onChanged: (value) =>
 setLocalState(() => selectedProbability = value),
 ),
 _dialogDropdownField(
 label: 'Impact',
 value: selectedImpact,
 options: _riskLevelOptions,
 enabled: !readOnly,
 onChanged: (value) =>
 setLocalState(() => selectedImpact = value),
 ),
 _dialogField(
 controller: scoreController,
 label: 'Risk Score',
 readOnly: readOnly),
 _dialogField(
 controller: ownerController,
 label: 'Owner',
 readOnly: readOnly),
 _dialogDropdownField(
 label: 'Status',
 value: selectedStatus,
 options: _riskStatusOptions,
 enabled: !readOnly,
 onChanged: (value) =>
 setLocalState(() => selectedStatus = value),
 ),
 ],
 ),
 ),
 ),
 actions: [
 TextButton(
 onPressed: () => Navigator.of(context).pop(false),
 child: const Text('Close')),
 if (!readOnly)
 ElevatedButton(
 onPressed: () => Navigator.of(context).pop(true),
 child: Text(isEditing ? 'Save' : 'Add'),
 ),
 ],
 ),
 );
 },
 );

 if (result != true || readOnly) return;
 final newEntry = _RiskEntry(
 docId: entry?.docId ?? _newEntryId(),
 id: idController.text.trim().isEmpty
 ? 'R-${DateTime.now().millisecondsSinceEpoch}'
 : idController.text.trim(),
 description: descriptionController.text.trim(),
 category: categoryController.text.trim(),
 probability: selectedProbability,
 impact: selectedImpact,
 score: scoreController.text.trim(),
 discipline: '',
 role: '',
 owner: ownerController.text.trim(),
 status: selectedStatus,
 createdAt: entry?.createdAt ?? DateTime.now(),
 updatedAt: DateTime.now(),
 );

 setState(() {
 final index = _entries.indexWhere((item) => item.docId == newEntry.docId);
 if (index == -1) {
 _entries.insert(0, newEntry);
 } else {
 _entries[index] = newEntry;
 }
 });
 await _persistEntry(newEntry, isNew: entry == null);
 }

 String _newEntryId() {
 final projectId = ProjectDataHelper.getData(context).projectId;
 if (projectId == null || projectId.isEmpty) {
 return DateTime.now().millisecondsSinceEpoch.toString();
 }
 return FirebaseFirestore.instance
 .collection('projects')
 .doc(projectId)
 .collection('risk_assessment_entries')
 .doc()
 .id;
 }

 List<_RiskEntry> _filteredEntries() {
 final query = _searchController.text.trim().toLowerCase();
 return _entries.where((entry) {
 final matchesStatus =
 _statusFilter == null || entry.status == _statusFilter;
 if (!matchesStatus) return false;
 if (query.isEmpty) return true;
 final haystack = [
 entry.id,
 entry.description,
 entry.category,
 entry.owner,
 entry.status,
 ].join(' ').toLowerCase();
 return haystack.contains(query);
 }).toList();
 }

 Future<void> _openFilterDialog() async {
 final current = _statusFilter;
 final options = ['All', 'Open', 'In Progress', 'Monitoring', 'Closed'];
 final result = await showDialog<String?>(
 context: context,
 builder: (context) {
 return AlertDialog(
 title: const Text('Filter by status'),
 content: Column(
 mainAxisSize: MainAxisSize.min,
 children: [
 for (final option in options)
 RadioListTile<String?>(
 title: Text(option),
 value: option == 'All' ? null : option,
 // TODO: Migrate to RadioGroup when this screen is revisited.
 // ignore: deprecated_member_use
 groupValue: current,
 // ignore: deprecated_member_use
 onChanged: (value) => Navigator.of(context).pop(value),
 ),
 ],
 ),
 );
 },
 );
 if (result == null && current == null) return;
 setState(() => _statusFilter = result);
 }

 @override
 Widget build(BuildContext context) {
 final entries = _filteredEntries();
 final stats = _RiskStats.fromEntries(entries);
 final isMobile = AppBreakpoints.isMobile(context);

 return ResponsiveScaffold(
 activeItemLabel: 'Risk Mitigation',
 floatingActionButton: const KazAiChatBubble(positioned: false),
 body: Column(
 children: [
 PlanningPhaseHeader(
 title: 'Risk Assessment',
 breadcrumbPhase: 'Planning Phase',
 breadcrumbTitle: 'Risk Assessment',
 onBack: () => PlanningPhaseNavigation.goToPrevious(
 context, 'risk_assessment'),
 onForward: () =>
 PlanningPhaseNavigation.goToNext(context, 'risk_assessment'), onExportPdf: _exportPdf),
 Expanded(
 child: SingleChildScrollView(
 padding: EdgeInsets.fromLTRB(
 isMobile ? 16 : 40,
 24,
 isMobile ? 16 : 40,
 100,
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 // Page Title
 const Text('Risk Planning',
 style: TextStyle(
 fontSize: 24,
 fontWeight: FontWeight.bold,
 color: Color(0xFF111827))),
 const SizedBox(height: 4),
 const Text('Identify, analyze and mitigate project risks.',
 style:
 TextStyle(fontSize: 14, color: Color(0xFF6B7280))),
 const SizedBox(height: 24),
 // Notes
 _RiskNotesCard(
 controller: _notesController,
 saving: _notesSaving,
 savedAt: _notesSavedAt,
 onChanged: _handleNotesChanged),
 const SizedBox(height: 16),
 // Metrics
 _MetricsWrap(stats: stats),
 const SizedBox(height: 16),
 // Risk Matrix
 _RiskMatrixCard(stats: stats),
 const SizedBox(height: 16),
 // Mitigation Plan
 _MitigationPlanCard(
 entries: entries,
 controllers: _mitigationControllers,
 onChanged: _handleMitigationChanged,
 onRegenerate: _regenerateMitigationForEntry,
 loadingSuggestions: _loadingMitigationSuggestions,
 suggestionError: _mitigationSuggestionError,
 saving: _mitigationSaving,
 savedAt: _mitigationSavedAt,
 regeneratingIds: _regeneratingMitigationIds),
 const SizedBox(height: 16),    // Risk Register
        _RiskRegister(
          entries: entries,
          loading: _loadingEntries,
          searchController: _searchController,
          onAdd: () => _openEntryDialog(),
          onFilter: _openFilterDialog,
          onCsvImport: _handleCsvImport,
          onView: (entry) =>
              _openEntryDialog(entry: entry, readOnly: true),
          onEdit: (entry) => _openEntryDialog(entry: entry),
        ),
 ],
 ),
 ),
 ),
 ],
 ),
 );
 }

 Widget _buildMobileHeader() {
 final user = FirebaseAuth.instance.currentUser;
 final photoUrl = user?.photoURL;

 return Container(
 padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
 decoration: const BoxDecoration(
 color: Colors.white,
 border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
 ),
 child: SafeArea(
 bottom: false,
 child: Row(
 children: [
 // Hamburger menu button
 InkWell(
 onTap: () {
 final scaffold = Scaffold.maybeOf(context);
 if (scaffold != null && scaffold.hasDrawer) {
 scaffold.openDrawer();
 }
 },
 borderRadius: BorderRadius.circular(8),
 child: const Padding(
 padding: EdgeInsets.all(4),
 child: Icon(Icons.menu, size: 24, color: Color(0xFF1F2937)),
 ),
 ),
 const SizedBox(width: 12),
 // Back/Forward chevrons + title
 _circleIcon(
 icon: Icons.chevron_left_rounded,
 onTap: () => PlanningPhaseNavigation.goToPrevious(
 context, 'risk_assessment'),
 ),
 const SizedBox(width: 8),
 _circleIcon(
 icon: Icons.chevron_right_rounded,
 onTap: () =>
 PlanningPhaseNavigation.goToNext(context, 'risk_assessment'),
 ),
 const SizedBox(width: 12),
 const Expanded(
 child: Text(
 'Risk Mitigation',
 style: TextStyle(
 fontSize: 16,
 fontWeight: FontWeight.w600,
 color: Color(0xFF111827)),
 ),
 ),
 // Avatar
 CircleAvatar(
 radius: 18,
 backgroundColor: const Color(0xFFE5E7EB),
 backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
 child: photoUrl == null
 ? const Icon(Icons.person, size: 18, color: Color(0xFF374151))
 : null,
 ),
 ],
 ),
 ),
 );
 }

 Widget _circleIcon({required IconData icon, VoidCallback? onTap}) {
 return InkWell(
 onTap: onTap,
 borderRadius: BorderRadius.circular(999),
 child: Container(
 width: 36,
 height: 36,
 decoration: BoxDecoration(
 color: Colors.white,
 shape: BoxShape.circle,
 border: Border.all(color: const Color(0xFFE5E7EB)),
 ),
 child: Icon(icon, size: 20, color: const Color(0xFF6B7280)),
 ),
 );
 }

 String _normalizeRiskDescription(String value) => value.trim().toLowerCase();

 Future<List<_RiskEntry>> _mergeEntriesWithSolutionRisks(
 List<_RiskEntry> baseEntries,
 List<SolutionRisk> solutionRisks,
 ) async {
 final normalizedExisting = <String>{};
 for (final entry in baseEntries) {
 final normalized = _normalizeRiskDescription(entry.description);
 if (normalized.isNotEmpty) {
 normalizedExisting.add(normalized);
 }
 }
 _seededRiskDescriptions
 .removeWhere((description) => normalizedExisting.contains(description));

 final merged = List<_RiskEntry>.from(baseEntries);
 for (final solutionRisk in solutionRisks) {
 final solutionTitle = solutionRisk.solutionTitle.trim();
 for (final riskTextRaw in solutionRisk.risks) {
 final riskText = riskTextRaw.trim();
 if (riskText.isEmpty) continue;
 final normalized = _normalizeRiskDescription(riskText);
 if (normalizedExisting.contains(normalized) ||
 _seededRiskDescriptions.contains(normalized)) {
 continue;
 }

 final newEntry = _RiskEntry(
 docId: _newEntryId(),
 id: 'R-${DateTime.now().millisecondsSinceEpoch}',
 description: riskText,
 category:
 solutionTitle.isNotEmpty ? solutionTitle : 'Initiation risk',
 probability: 'Medium',
 impact: 'Medium',
 score: '0',
 discipline: '',
 role: '',
 owner: '',
 status: 'Open',
 createdAt: DateTime.now(),
 updatedAt: DateTime.now(),
 );
 merged.insert(0, newEntry);
 normalizedExisting.add(normalized);
 _seededRiskDescriptions.add(normalized);
 try {
 await _persistEntry(newEntry, isNew: true);
 } catch (e) {
 debugPrint('Could not persist seeded risk: $e');
 }
 }
 }
 return merged;
 }

 void _ensureMitigationControllers(List<_RiskEntry> entries) {
 final desired = entries.map((e) => e.docId).toSet();
 for (final entry in entries) {
 final controller = _mitigationControllers[entry.docId];
 final stored = _mitigationPlans[entry.docId] ?? '';
 if (controller == null) {
 _mitigationControllers[entry.docId] =
 RichTextEditingController(text: stored);
 } else if (controller.text != stored) {
 controller.text = stored;
 }
 }
 final toRemove = _mitigationControllers.keys
 .where((id) => !desired.contains(id))
 .toList();
 for (final id in toRemove) {
 _mitigationControllers[id]?.dispose();
 _mitigationControllers.remove(id);
 }
 }

 Future<void> _maybeSeedMitigationPlans(
 List<_RiskEntry> entries,
 ProjectDataModel projectData,
 ) async {
 if (_loadingMitigationSuggestions) return;
 final missing = entries.where((entry) {
 final stored = _mitigationPlans[entry.docId]?.trim() ?? '';
 return stored.isEmpty;
 }).toList();
 if (missing.isEmpty) return;

 setState(() => _loadingMitigationSuggestions = true);
 final mitigationContext = ProjectDataHelper.buildProjectContextScan(
 projectData,
 sectionLabel: 'Risk Mitigation Plan');
 try {
 final requests = missing
 .map((entry) => RiskMitigationRequest(
 id: entry.docId,
 risk: entry.description,
 solutionTitle: entry.category))
 .toList();
 final suggestions = await _openAi.generateRiskMitigationPlans(
 risks: requests,
 context: mitigationContext,
 );
 if (suggestions.isNotEmpty) {
 var updated = false;
 for (final entry in missing) {
 final plan = suggestions[entry.docId];
 if (plan == null || plan.trim().isEmpty) continue;
 final trimmed = plan.trim();
 final existing = _mitigationPlans[entry.docId]?.trim() ?? '';
 if (existing == trimmed) continue;
 _mitigationPlans[entry.docId] = trimmed;
 final controller = _mitigationControllers[entry.docId];
 if (controller != null) {
 controller.text = trimmed;
 }
 updated = true;
 }
 if (updated) {
 await _persistMitigationPlans();
 }
 }
 } catch (e) {
 if (mounted) {
 setState(() => _mitigationSuggestionError = e.toString());
 }
 } finally {
 if (mounted) {
 setState(() => _loadingMitigationSuggestions = false);
 }
 }
 }

 void _handleMitigationChanged(String docId, String value) {
 _mitigationPlans[docId] = value;
 _scheduleMitigationSave();
 }

 void _scheduleMitigationSave() {
 _mitigationDebounce.run(() {
 _persistMitigationPlans();
 });
 }

 Future<void> _persistMitigationPlans({bool showSnackbar = false}) async {
 if (!mounted) return;
 final trimmed = <String, String>{};
 for (final entry in _mitigationPlans.entries) {
 trimmed[entry.key] = entry.value.trim();
 }
 setState(() => _mitigationSaving = true);
 final success = await ProjectDataHelper.updateAndSave(
 context: context,
 checkpoint: 'risk_assessment',
 dataUpdater: (data) => data.copyWith(riskMitigationPlans: trimmed),
 showSnackbar: showSnackbar,
 );
 if (!mounted) return;
 setState(() {
 _mitigationSaving = false;
 if (success) _mitigationSavedAt = DateTime.now();
 });
 }

 Future<void> _regenerateMitigationForEntry(_RiskEntry entry) async {
 if (_regeneratingMitigationIds.contains(entry.docId)) return;
 setState(() => _regeneratingMitigationIds.add(entry.docId));
 final provider = ProjectDataHelper.getProvider(context);
 final mitigationContext = ProjectDataHelper.buildProjectContextScan(
 provider.projectData,
 sectionLabel: 'Risk Mitigation Plan');
 try {
 final suggestions = await _openAi.generateRiskMitigationPlans(
 risks: [
 RiskMitigationRequest(
 id: entry.docId,
 risk: entry.description,
 solutionTitle: entry.category,
 )
 ],
 context: mitigationContext,
 );
 final plan = suggestions[entry.docId];
 if (plan != null && plan.trim().isNotEmpty) {
 final trimmed = plan.trim();
 _mitigationPlans[entry.docId] = trimmed;
 final controller = _mitigationControllers[entry.docId];
 if (controller != null) {
 controller.text = trimmed;
 }
 await _persistMitigationPlans();
 } else {
 if (mounted) {
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(
 content: Text('AI did not return a mitigation plan.'),
 backgroundColor: Colors.orange,
 ),
 );
 }
 }
 } catch (e) {
 if (mounted) {
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(
 content: Text('Failed to regenerate mitigation plan: $e'),
 backgroundColor: Colors.red,
 ),
 );
 }
 } finally {
 if (mounted) {
 setState(() => _regeneratingMitigationIds.remove(entry.docId));
 }
 }
 }

  Future<void> _handleCsvImport(List<Map<String, String>> rows) async {
    int imported = 0;
    for (final row in rows) {
      final description = row['description']?.trim() ?? '';
      if (description.isEmpty) continue;
      final entry = _RiskEntry(
        docId: _newEntryId(),
        id: row['id']?.trim().isNotEmpty == true
            ? row['id']!.trim()
            : 'R-${DateTime.now().millisecondsSinceEpoch + imported}',
        description: description,
        category: row['category']?.trim() ?? '',
        probability: row['probability']?.trim().isNotEmpty == true
            ? row['probability']!.trim()
            : 'Medium',
        impact: row['impact']?.trim().isNotEmpty == true
            ? row['impact']!.trim()
            : 'Medium',
        score: row['score']?.trim() ?? '',
        discipline: '',
        role: '',
        owner: row['owner']?.trim() ?? '',
        status: row['status']?.trim().isNotEmpty == true
            ? row['status']!.trim()
            : 'Open',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      setState(() => _entries.insert(0, entry));
      await _persistEntry(entry, isNew: true);
      imported++;
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Imported $imported risk(s) from CSV')),
      );
    }
  }

  Future<void> _exportPdf() async {
 final projectData = ProjectDataHelper.getData(context);
 await PdfExportHelper.exportScreenPdf(
 context: context,
 screenTitle: 'Risk Assessment',
 sections: [
 PdfSection.keyValue('Project Info', [
 {'Project Name': projectData.projectName ?? 'N/A'},
 {'Solution Title': projectData.solutionTitle ?? 'N/A'},
 ]),
 PdfSection.text('Notes', projectData.planningNotes['planning_risk_assessment_notes'] ?? 'No data recorded.'),
 ],
 );
 }
}

// ─── UI Widgets ─────────────────────────────────────────────────────────────

class _RiskNotesCard extends StatelessWidget {
 const _RiskNotesCard({
 required this.controller,
 required this.saving,
 required this.savedAt,
 required this.onChanged,
 });

 final TextEditingController controller;
 final bool saving;
 final DateTime? savedAt;
 final ValueChanged<String> onChanged;

 @override
 Widget build(BuildContext context) {
 return Container(
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(16),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 boxShadow: const [
 BoxShadow(
 color: Color(0x0A000000), blurRadius: 4, offset: Offset(0, 1)),
 ],
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 // Header with border-bottom, bg-gray-50/50
 Container(
 padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
 decoration: const BoxDecoration(
 color: Color(0xFFFAFAFA),
 borderRadius: BorderRadius.only(
 topLeft: Radius.circular(16),
 topRight: Radius.circular(16),
 ),
 border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
 ),
 child: Row(
 children: [
 Container(
 width: 32,
 height: 32,
 decoration: BoxDecoration(
 color: const Color(0xFFF1F5F9),
 borderRadius: BorderRadius.circular(10),
 ),
 child: const Icon(Icons.description_outlined,
 color: Color(0xFF475569), size: 16),
 ),
 const SizedBox(width: 10),
 const Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 'Notes',
 style: TextStyle(
 fontSize: 14,
 fontWeight: FontWeight.w600,
 color: Color(0xFF111827)),
 ),
 SizedBox(height: 2),
 Text(
 'Summarize key risks, probability/impact themes, and mitigation focus.',
 style: TextStyle(
 fontSize: 12,
 color: Color(0xFF6B7280),
 height: 1.3),
 ),
 ],
 ),
 ),
 if (saving)
 const _StatusChip(
 label: 'Saving...', color: Color(0xFF64748B))
 else if (savedAt != null)
 _StatusChip(
 label:
 'Saved ${TimeOfDay.fromDateTime(savedAt!).format(context)}',
 color: const Color(0xFF16A34A),
 background: const Color(0xFFECFDF3),
 ),
 ],
 ),
 ),
 // Body: transparent textarea
 Padding(
 padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
 child: VoiceTextField(
 controller: controller,
 onChanged: onChanged,
 maxLines: 6,
 decoration: const InputDecoration(
 hintText: 'Capture risk assessment notes here...',
 border: InputBorder.none,
 filled: false,
 contentPadding: EdgeInsets.zero,
 ),
 style: const TextStyle(fontSize: 14, color: Color(0xFF1F2937)),
 ),
 ),
 ],
 ),
 );
 }
}

class _StatusChip extends StatelessWidget {
 const _StatusChip(
 {required this.label, required this.color, this.background});

 final String label;
 final Color color;
 final Color? background;

 @override
 Widget build(BuildContext context) {
 return Container(
 padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
 decoration: BoxDecoration(
 color: background ?? color.withValues(alpha: 0.1),
 borderRadius: BorderRadius.circular(999),
 ),
 child: Text(
 label,
 style:
 TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
 ),
 );
 }
}

class _OutlinedButton extends StatelessWidget {
 const _OutlinedButton({required this.label, this.onPressed});

 final String label;
 final VoidCallback? onPressed;

 @override
 Widget build(BuildContext context) {
 return OutlinedButton(
 onPressed: onPressed,
 style: OutlinedButton.styleFrom(
 backgroundColor: Colors.white,
 side: const BorderSide(color: Color(0xFFE5E7EB)),
 padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
 foregroundColor: const Color(0xFF111827),
 textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
 ),
 child: Text(label),
 );
 }
}

class _YellowButton extends StatelessWidget {
 const _YellowButton({required this.label, this.onPressed});

 final String label;
 final VoidCallback? onPressed;

 @override
 Widget build(BuildContext context) {
 return ElevatedButton(
 onPressed: onPressed,
 style: ElevatedButton.styleFrom(
 backgroundColor: const Color(0xFFFFB800),
 foregroundColor: const Color(0xFF111827),
 elevation: 0,
 padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
 textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
 ),
 child: Text(label),
 );
 }
}

class _RiskStats {
 _RiskStats({
 required this.total,
 required this.statusCounts,
 required this.statusSubtitle,
 required this.progress,
 required this.topRiskArea,
 required this.openCount,
 required this.matrixCounts,
 });

 factory _RiskStats.fromEntries(List<_RiskEntry> entries) {
 final total = entries.length;
 final statusCounts = <String, int>{};
 int closedCount = 0;
 final areaCounts = <String, int>{};
 final matrixCounts = {
 for (final level in _levels)
 level: {for (final inner in _levels) inner: 0}
 };

 for (final entry in entries) {
 final status = entry.status.trim();
 if (status.isNotEmpty) {
 statusCounts[status] = (statusCounts[status] ?? 0) + 1;
 if (status.toLowerCase() == 'closed') {
 closedCount += 1;
 }
 }
 final category = entry.category.trim();
 if (category.isNotEmpty) {
 areaCounts[category] = (areaCounts[category] ?? 0) + 1;
 }
 final probability = _normalizeLevel(entry.probability);
 final impact = _normalizeLevel(entry.impact);
 matrixCounts[probability]?[impact] =
 (matrixCounts[probability]?[impact] ?? 0) + 1;
 }

 final statusList = statusCounts.entries.toList()
 ..sort((a, b) => b.value.compareTo(a.value));
 final statusSubtitle = statusList.isEmpty
 ? '—'
 : statusList
 .take(3)
 .map((entry) => '${entry.key}: ${entry.value}')
 .join(' · ');

 final topRiskArea = areaCounts.entries.isEmpty
 ? '—'
 : areaCounts.entries
 .reduce(
 (current, next) => next.value > current.value ? next : current,
 )
 .key;

 final openCount = total - closedCount;
 final progress =
 total > 0 ? (closedCount / total).clamp(0, 1).toDouble() : null;

 return _RiskStats(
 total: total,
 statusCounts: statusCounts,
 statusSubtitle: statusSubtitle,
 progress: progress,
 topRiskArea: topRiskArea,
 openCount: openCount,
 matrixCounts: matrixCounts,
 );
 }

 static const List<String> _levels = ['Low', 'Medium', 'High'];

 static String _normalizeLevel(String value) {
 final lower = value.trim().toLowerCase();
 if (lower.startsWith('h')) return 'High';
 if (lower.startsWith('m')) return 'Medium';
 return 'Low';
 }

 final int total;
 final Map<String, int> statusCounts;
 final String statusSubtitle;
 final double? progress;
 final String topRiskArea;
 final int openCount;
 final Map<String, Map<String, int>> matrixCounts;

 int countFor(String likelihood, String impact) =>
 matrixCounts[likelihood]?[impact] ?? 0;

 int get maxCellCount {
 var maxCount = 0;
 for (final row in matrixCounts.values) {
 for (final cell in row.values) {
 if (cell > maxCount) {
 maxCount = cell;
 }
 }
 }
 return maxCount;
 }
}

class _MetricsWrap extends StatelessWidget {
 const _MetricsWrap({required this.stats});

 final _RiskStats stats;

 @override
 Widget build(BuildContext context) {
 final totalRisks = stats.total;
 final String statusSubtitle = stats.statusSubtitle;
 final String topRiskArea = stats.topRiskArea;
 final String unaddressed = totalRisks == 0 ? '0' : '${stats.openCount}';

 final cards = [
 _MetricCard(
 title: 'Total Risks',
 value: '$totalRisks',
 ),
 _MetricCard(
 title: 'Risk Status',
 value: statusSubtitle,
 ),
 _MetricCard(
 title: 'Top Risk Area',
 value: topRiskArea,
 footer: totalRisks == 0 ? 'No risks yet' : null,
 footerIcon: totalRisks == 0 ? Icons.warning_amber_rounded : null,
 ),
 _MetricCard(
 title: 'Unaddressed',
 value: unaddressed,
 footer: totalRisks == 0 ? 'Add risks to begin tracking' : null,
 footerIcon: totalRisks == 0 ? Icons.warning_amber_rounded : null,
 ),
 ];

        return GridView.count(
        crossAxisCount: 2,
        childAspectRatio: 1.35,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        children: cards,
        );
        }
}

class _MetricCard extends StatelessWidget {
 const _MetricCard({
 required this.title,
 required this.value,
 this.footer,
 this.footerIcon,
 });

 final String title;
 final String value;
 final String? footer;
 final IconData? footerIcon;

        @override
        Widget build(BuildContext context) {
        return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: const [
        BoxShadow(
        color: Color(0x0A000000), blurRadius: 4, offset: Offset(0, 1)),
        ],
        ),
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
        // Small label
        Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: Color(0xFF6B7280)),
        ),
        const SizedBox(height: 8),
        // Large value
        Text(
        value,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        color: Color(0xFF111827)),
        ),
        // Optional footer
        if (footer != null) ...[
        const SizedBox(height: 8),
        Row(
        children: [
        if (footerIcon != null)
        Icon(footerIcon, size: 14, color: const Color(0xFF9CA3AF)),
        if (footerIcon != null) const SizedBox(width: 4),
        Expanded(
        child: Text(
        footer!,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style:
        const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
        ),
        ),
        ],
        ),
        ],
        ],
        ),
        );
        }
}

class _RiskMatrixCard extends StatelessWidget {
 const _RiskMatrixCard({required this.stats});

 final _RiskStats stats;

 static const Color _high = Color(0xFFFEE2E2);
 static const Color _medium = Color(0xFFFEF08A);
 static const Color _low = Color(0xFFDCFCE7);

 @override
 Widget build(BuildContext context) {
 return Container(
 width: double.infinity,
 padding: const EdgeInsets.all(16),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(16),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 boxShadow: const [
 BoxShadow(
 color: Color(0x0A000000), blurRadius: 4, offset: Offset(0, 1)),
 ],
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 // Title + legend
 Row(
 children: [
 const Text(
 'Risk Matrix',
 style: TextStyle(
 fontSize: 16,
 fontWeight: FontWeight.w600,
 color: Color(0xFF111827)),
 ),
 const Spacer(),
 _LegendDot(color: _high, label: 'High'),
 const SizedBox(width: 12),
 _LegendDot(color: _medium, label: 'Medium'),
 const SizedBox(width: 12),
 _LegendDot(color: _low, label: 'Low'),
 ],
 ),
 const SizedBox(height: 16),
 // "Impact" label above grid
 const Center(
 child: Text(
 'Impact',
 style: TextStyle(
 fontSize: 12,
 fontWeight: FontWeight.w500,
 color: Color(0xFF6B7280)),
 ),
 ),
 const SizedBox(height: 8),
 // Grid with "Likelihood" on left
 Row(
 crossAxisAlignment: CrossAxisAlignment.center,
 children: [
 // Rotated "Likelihood" label
 SizedBox(
 width: 28,
 child: RotatedBox(
 quarterTurns: 3,
 child: Center(
 child: Text(
 'Likelihood',
 style: TextStyle(
 fontSize: 12,
 fontWeight: FontWeight.w500,
 color: const Color(0xFF6B7280)),
 ),
 ),
 ),
 ),
 // The matrix grid
 Expanded(
 child: Column(
 children: [
 // X-axis headers
 Row(
 children: const [
 SizedBox(width: 40),
 Expanded(
 child: Center(
 child: Text('Low',
 style: TextStyle(
 fontSize: 12,
 fontWeight: FontWeight.w500,
 color: Color(0xFF6B7280))))),
 Expanded(
 child: Center(
 child: Text('Medium',
 style: TextStyle(
 fontSize: 12,
 fontWeight: FontWeight.w500,
 color: Color(0xFF6B7280))))),
 Expanded(
 child: Center(
 child: Text('High',
 style: TextStyle(
 fontSize: 12,
 fontWeight: FontWeight.w500,
 color: Color(0xFF6B7280))))),
 ],
 ),
 const SizedBox(height: 6),
 // Rows: High (top), Medium, Low (bottom)
 ...['High', 'Medium', 'Low'].map((likelihood) {
 return Padding(
 padding: const EdgeInsets.only(bottom: 6),
 child: Row(
 children: [
 // Y-axis label
 SizedBox(
 width: 40,
 child: Text(
 likelihood,
 style: const TextStyle(
 fontSize: 12,
 fontWeight: FontWeight.w500,
 color: Color(0xFF6B7280)),
 ),
 ),
 // Cells
 ...['Low', 'Medium', 'High'].map((impact) {
 final count = stats.countFor(likelihood, impact);
 final color = _cellColor(likelihood, impact);
 return Expanded(
 child: Container(
 height: 56,
 margin:
 const EdgeInsets.symmetric(horizontal: 3),
 decoration: BoxDecoration(
 color: color,
 borderRadius: BorderRadius.circular(8),
 ),
 child: Center(
 child: Column(
 mainAxisSize: MainAxisSize.min,
 children: [
 Text(
 count > 0 ? '$count' : '0',
 style: const TextStyle(
 fontSize: 16,
 fontWeight: FontWeight.bold,
 color: Color(0xFF1F2937)),
 ),
 const SizedBox(height: 2),
 const Text(
 'risks',
 style: TextStyle(
 fontSize: 10,
 color: Color(0xFF6B7280)),
 ),
 ],
 ),
 ),
 ),
 );
 }),
 ],
 ),
 );
 }),
 ],
 ),
 ),
 ],
 ),
 ],
 ),
 );
 }

 Color _cellColor(String likelihood, String impact) {
 if (likelihood == 'Low') {
 if (impact == 'High') return _medium;
 return _low;
 }
 if (likelihood == 'Medium') {
 if (impact == 'High') return _high;
 if (impact == 'Medium') return _medium;
 return _low;
 }
 // High likelihood
 if (impact == 'Low') return _medium;
 return _high;
 }
}

class _LegendDot extends StatelessWidget {
 const _LegendDot({required this.color, required this.label});

 final Color color;
 final String label;

 @override
 Widget build(BuildContext context) {
 return Row(
 mainAxisSize: MainAxisSize.min,
 children: [
 Container(
 width: 8,
 height: 8,
 decoration: BoxDecoration(color: color, shape: BoxShape.circle),
 ),
 const SizedBox(width: 4),
 Text(
 label,
 style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
 ),
 ],
 );
 }
}

class _MitigationPlanCard extends StatelessWidget {
 const _MitigationPlanCard({
 required this.entries,
 required this.controllers,
 required this.onChanged,
 required this.onRegenerate,
 required this.loadingSuggestions,
 required this.suggestionError,
 required this.saving,
 required this.savedAt,
 required this.regeneratingIds,
 });

 final List<_RiskEntry> entries;
 final Map<String, RichTextEditingController> controllers;
 final void Function(String docId, String value) onChanged;
 final Future<void> Function(_RiskEntry entry) onRegenerate;
 final bool loadingSuggestions;
 final String? suggestionError;
 final bool saving;
 final DateTime? savedAt;
 final Set<String> regeneratingIds;

 @override
 Widget build(BuildContext context) {
 return Container(
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(16),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 boxShadow: const [
 BoxShadow(
 color: Color(0x0A000000), blurRadius: 4, offset: Offset(0, 1)),
 ],
 ),
 child: ClipRRect(
 borderRadius: BorderRadius.circular(16),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 // Header with border-bottom, bg-gray-50/50
 Container(
 padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
 decoration: const BoxDecoration(
 color: Color(0xFFFAFAFA),
 border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
 ),
 child: Row(
 children: [
 const Icon(Icons.shield_rounded,
 color: Color(0xFF475569), size: 20),
 const SizedBox(width: 10),
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 const Text(
 'Mitigation plan',
 style: TextStyle(
 fontSize: 14,
 fontWeight: FontWeight.w600,
 color: Color(0xFF111827)),
 ),
 const SizedBox(height: 2),
 const Text(
 'Auto-filled with AI suggestions from initiation-phase risks.',
 style: TextStyle(
 fontSize: 12,
 color: Color(0xFF6B7280),
 height: 1.3),
 ),
 ],
 ),
 ),
 if (saving)
 const _StatusChip(
 label: 'Saving...', color: Color(0xFF64748B))
 else if (savedAt != null)
 _StatusChip(
 label:
 'Saved ${TimeOfDay.fromDateTime(savedAt!).format(context)}',
 color: const Color(0xFF16A34A),
 background: const Color(0xFFECFDF3),
 ),
 ],
 ),
 ),
 if (loadingSuggestions) ...[
 const Padding(
 padding: EdgeInsets.all(16),
 child: LinearProgressIndicator(minHeight: 4),
 ),
 ],
 if (suggestionError != null) ...[
 Padding(
 padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
 child: Text(
 suggestionError!,
 style:
 const TextStyle(color: Color(0xFFB91C1C), fontSize: 12),
 ),
 ),
 ],
 if (entries.isEmpty)
 Container(
 width: double.infinity,
 margin: const EdgeInsets.all(12),
 padding: const EdgeInsets.symmetric(vertical: 24),
 decoration: BoxDecoration(
 color: const Color(0xFFF9FAFB),
 borderRadius: BorderRadius.circular(12),
 ),
 child: const Center(
 child: Text(
 'Risk register is empty. Add risks to capture mitigation plans.',
 textAlign: TextAlign.center,
 style: TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)),
 ),
 ),
 )
 else ...[
 Padding(
 padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 for (int i = 0; i < entries.length; i++) ...[
 _buildMitigationRow(context, entries[i]),
 if (i < entries.length - 1)
 const Divider(
 height: 24, thickness: 1, color: Color(0xFFF3F4F6)),
 ],
 ],
 ),
 ),
 ],
 ],
 ),
 ),
 );
 }

 Widget _buildMitigationRow(BuildContext context, _RiskEntry entry) {
 final controller = controllers[entry.docId];
 if (controller == null) return const SizedBox.shrink();
 final isRegenerating = regeneratingIds.contains(entry.docId);
 return Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Expanded(
 child: Text(
 entry.description,
 style: const TextStyle(
 fontSize: 14,
 fontWeight: FontWeight.w600,
 color: Color(0xFF111827)),
 ),
 ),
 Text(
 entry.category.isNotEmpty ? entry.category : 'Uncategorized',
 style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
 ),
 ],
 ),
 const SizedBox(height: 12),
 Row(
 mainAxisAlignment: MainAxisAlignment.spaceBetween,
 children: [
 const Text(
 'Mitigation plan',
 style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
 ),
 IconButton(
 icon: isRegenerating
 ? const SizedBox(
 width: 20,
 height: 20,
 child: CircularProgressIndicator(strokeWidth: 2),
 )
 : const Icon(Icons.autorenew, size: 18),
 onPressed: () => onRegenerate(entry),
 tooltip: 'Refresh AI suggestion',
 ),
 ],
 ),
 const SizedBox(height: 4),
 VoiceTextField(
 controller: controller,
 onChanged: (value) => onChanged(entry.docId, value),
 minLines: 3,
 maxLines: 6,
 decoration: InputDecoration(
 hintText: 'Capture mitigation steps, owner, and cadence...',
 border: OutlineInputBorder(
 borderRadius: BorderRadius.circular(12),
 borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
 ),
 filled: true,
 fillColor: const Color(0xFFF9FAFB),
 contentPadding: const EdgeInsets.all(12),
 ),
 ),
 const SizedBox(height: 12),
 ],
 );  }
}

class _RiskRegister extends StatelessWidget {
  const _RiskRegister({
    required this.entries,
    required this.loading,
    required this.searchController,
    required this.onAdd,
    required this.onFilter,
    required this.onCsvImport,
    required this.onView,
    required this.onEdit,
  });

  final List<_RiskEntry> entries;
  final bool loading;
  final TextEditingController searchController;
  final VoidCallback onAdd;
  final VoidCallback onFilter;
  final ValueChanged<List<Map<String, String>>> onCsvImport;
  final ValueChanged<_RiskEntry> onView;
  final ValueChanged<_RiskEntry> onEdit;

 static const List<int> _columnFlex = [4, 3, 2, 2, 2, 1, 2, 2, 2];
 static const double _actionsColumnWidth = 96;

 @override
 Widget build(BuildContext context) {
 return Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 // Title area outside card
 const Text(
 'Risk Register',
 style: TextStyle(
 fontSize: 18,
 fontWeight: FontWeight.bold,
 color: Color(0xFF111827)),
 ),
 const SizedBox(height: 4),
 const Text(
 'Monitor risk exposure and mitigation status across the project',
 style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
 ),
 const SizedBox(height: 16),
 // Controls row: search + filter + add risk
 Row(
 children: [
 Expanded(
 child: VoiceTextField(
 controller: searchController,
 decoration: InputDecoration(
 hintText: 'Search...',
 prefixIcon: const Icon(Icons.search,
 size: 18, color: Color(0xFF9CA3AF)),
 filled: true,
 fillColor: const Color(0xFFF9FAFB),
 contentPadding:
 const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
 border: OutlineInputBorder(
 borderRadius: BorderRadius.circular(10),
 borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
 ),
 enabledBorder: OutlineInputBorder(
 borderRadius: BorderRadius.circular(10),
 borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
 ),
 focusedBorder: OutlineInputBorder(
 borderRadius: BorderRadius.circular(10),
 borderSide:
 const BorderSide(color: Color(0xFFD97706), width: 1.5),
 ),
 ),
 style: const TextStyle(fontSize: 14),
 ),
 ),        const SizedBox(width: 8),
        _OutlinedButton(label: 'Filter', onPressed: onFilter),
        const SizedBox(width: 8),
        CsvTableImportButton(
          tableTitle: 'Risk Register',
          columns: _RiskAssessmentScreenState._riskCsvColumns,
          onImport: onCsvImport,
        ),
        const SizedBox(width: 8),
        _YellowButton(label: 'Add Risk', onPressed: onAdd),
 ],
 ),
 const SizedBox(height: 16),
 if (loading) ...[
 const Center(
 child: Padding(
 padding: EdgeInsets.symmetric(vertical: 32),
 child: CircularProgressIndicator(),
 ),
 ),
 ] else if (entries.isEmpty) ...[
 // Empty state: white rounded card
 Container(
 width: double.infinity,
 padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(16),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 boxShadow: const [
 BoxShadow(
 color: Color(0x0A000000),
 blurRadius: 4,
 offset: Offset(0, 1)),
 ],
 ),
 child: Column(
 children: const [
 Icon(Icons.description_outlined,
 size: 32, color: Color(0xFF9CA3AF)),
 SizedBox(height: 12),
 Text(
 'No risks yet',
 style: TextStyle(
 fontSize: 16,
 fontWeight: FontWeight.w600,
 color: Color(0xFF111827)),
 ),
 SizedBox(height: 6),
 Text(
 'Add risks from Risk Identification or Preferred Solution Analysis.',
 textAlign: TextAlign.center,
 style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
 ),
 ],
 ),
 ),
 ] else ...[
 LayoutBuilder(
 builder: (context, constraints) {
 final viewportWidth =
 MediaQuery.of(context).size.width - 72; // account for padding
 final tableWidth = math.max(1080.0, viewportWidth);
 return SingleChildScrollView(
 scrollDirection: Axis.horizontal,
 child: SizedBox(
 width: tableWidth,
 child: Column(
 children: [
 _RegisterHeader(columnFlex: _columnFlex),
 const SizedBox(height: 12),
 ...List.generate(entries.length, (index) {
 final entry = entries[index];
 final bool isLast = index == entries.length - 1;
 return Column(
 children: [
 _RegisterRow(
 entry: entry,
 columnFlex: _columnFlex,
 actionsColumnWidth: _actionsColumnWidth,
 onView: () => onView(entry),
 onEdit: () => onEdit(entry),
 ),
 if (!isLast)
 const Divider(
 height: 26,
 thickness: 1,
 color: Color(0xFFF3F4F6)),
 ],
 );
 }),
 ],
 ),
 ),
 );
 },
 ),
 ],
 ],
 );
 }
}

class _RegisterHeader extends StatelessWidget {
 const _RegisterHeader({required this.columnFlex});

 final List<int> columnFlex;

 static const List<String> _labels = [
 'Description',
 'Category',
 'Prob.',
 'Impact',
 'Value',
 'Discipline',
 'Role',
 'Owner',
 'Status',
 'Actions',
 ];

 @override
 Widget build(BuildContext context) {
 return Row(
 children: [
 ...List.generate(_labels.length, (index) {
 if (index == _labels.length - 1) {
 return const SizedBox(
 width: _RiskRegister._actionsColumnWidth); // icons
 }
 final flex = columnFlex[index];
 return Expanded(
 flex: flex,
 child: Text(
 _labels[index],
 style: const TextStyle(
 fontSize: 13,
 fontWeight: FontWeight.w600,
 color: Color(0xFF6B7280)),
 ),
 );
 }),
 ],
 );
 }
}

class _RegisterRow extends StatelessWidget {
 const _RegisterRow({
 required this.entry,
 required this.columnFlex,
 required this.actionsColumnWidth,
 required this.onView,
 required this.onEdit,
 });

 final _RiskEntry entry;
 final List<int> columnFlex;
 final double actionsColumnWidth;
 final VoidCallback onView;
 final VoidCallback onEdit;

 @override
 Widget build(BuildContext context) {
 Color pillColor;
 Color pillText;
 switch (entry.status) {
 case 'In Progress':
 pillColor = const Color(0xFFFFF7E6);
 pillText = const Color(0xFF92400E);
 break;
 case 'Monitoring':
 pillColor = const Color(0xFFE0F2F1);
 pillText = const Color(0xFF065F46);
 break;
 default:
 pillColor = const Color(0xFFE5E7EB);
 pillText = const Color(0xFF374151);
 }

 return Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Expanded(
 flex: columnFlex[0],
 child: Text(
 entry.description,
 maxLines: 2,
 overflow: TextOverflow.ellipsis,
 style: const TextStyle(fontSize: 13, color: Color(0xFF111827)),
 ),
 ),
 Expanded(
 flex: columnFlex[1],
 child: Text(
 entry.category,
 maxLines: 2,
 overflow: TextOverflow.ellipsis,
 style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
 ),
 ),
 Expanded(
 flex: columnFlex[2],
 child: _RiskTag(label: entry.probability),
 ),
 Expanded(
 flex: columnFlex[3],
 child: _RiskTag(label: entry.impact),
 ),
 Expanded(
 flex: columnFlex[4],
 child: Text(
 entry.score,
 style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
 ),
 ),
 Expanded(
 flex: columnFlex[5],
 child: Text(
 entry.discipline,
 style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
 ),
 ),
 Expanded(
 flex: columnFlex[6],
 child: Text(
 entry.role,
 maxLines: 1,
 overflow: TextOverflow.ellipsis,
 style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
 ),
 ),
 Expanded(
 flex: columnFlex[7],
 child: Text(
 entry.owner,
 maxLines: 1,
 overflow: TextOverflow.ellipsis,
 style: const TextStyle(fontSize: 13, color: Color(0xFF111827)),
 ),
 ),
 Expanded(
 flex: columnFlex[8],
 child: Align(
 alignment: Alignment.centerLeft,
 child: Container(
 padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
 decoration: BoxDecoration(
 color: pillColor, borderRadius: BorderRadius.circular(999)),
 child: Text(
 entry.status,
 style: TextStyle(
 fontSize: 12, fontWeight: FontWeight.w500, color: pillText),
 ),
 ),
 ),
 ),
 SizedBox(
 width: actionsColumnWidth,
 child: Row(
 mainAxisAlignment: MainAxisAlignment.end,
 children: [
 IconButton(
 icon: const Icon(Icons.visibility_outlined,
 size: 18, color: Color(0xFF6B7280)),
 onPressed: onView,
 tooltip: 'View',
 visualDensity: VisualDensity.compact,
 constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
 ),
 IconButton(
 icon: const Icon(Icons.edit_outlined,
 size: 18, color: Color(0xFF6B7280)),
 onPressed: onEdit,
 tooltip: 'Edit',
 visualDensity: VisualDensity.compact,
 constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
 ),
 ],
 ),
 ),
 ],
 );
 }
}

class _RiskTag extends StatelessWidget {
 const _RiskTag({required this.label});

 final String label;

 @override
 Widget build(BuildContext context) {
 final bool isHigh = label.toLowerCase() == 'high';
 final bool isMedium = label.toLowerCase() == 'medium';
 Color background;
 Color textColor;

 if (isHigh) {
 background = const Color(0xFFFEE2E2);
 textColor = const Color(0xFFB91C1C);
 } else if (isMedium) {
 background = const Color(0xFFFEF3C7);
 textColor = const Color(0xFF92400E);
 } else {
 background = const Color(0xFFDCFCE7);
 textColor = const Color(0xFF166534);
 }

 return Container(
 padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
 decoration: BoxDecoration(
 color: background, borderRadius: BorderRadius.circular(999)),
 child: Text(
 label,
 style: TextStyle(
 fontSize: 12, fontWeight: FontWeight.w500, color: textColor),
 ),
 );
 }
}

class _RiskEntry {
 const _RiskEntry({
 required this.docId,
 required this.id,
 required this.description,
 required this.category,
 required this.probability,
 required this.impact,
 required this.score,
 required this.discipline,
 required this.role,
 required this.owner,
 required this.status,
 required this.createdAt,
 required this.updatedAt,
 });

 final String docId;
 final String id;
 final String description;
 final String category;
 final String probability;
 final String impact;
 final String score;
 final String discipline;
 final String role;
 final String owner;
 final String status;
 final DateTime createdAt;
 final DateTime updatedAt;

 factory _RiskEntry.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
 final data = doc.data() ?? {};
 return _RiskEntry(
 docId: doc.id,
 id: data['id']?.toString() ?? '',
 description: data['description']?.toString() ?? '',
 category: data['category']?.toString() ?? '',
 probability: data['probability']?.toString() ?? '',
 impact: data['impact']?.toString() ?? '',
 score: data['score']?.toString() ?? '',
 discipline: data['discipline']?.toString() ?? '',
 role: data['role']?.toString() ?? '',
 owner: data['owner']?.toString() ?? '',
 status: data['status']?.toString() ?? '',
 createdAt: _readTimestamp(data['createdAt']),
 updatedAt: _readTimestamp(data['updatedAt']),
 );
 }

 Map<String, dynamic> toFirestore({required bool isNew}) {
 return {
 'id': id,
 'description': description,
 'category': category,
 'probability': probability,
 'impact': impact,
 'score': score,
 'discipline': discipline,
 'role': role,
 'owner': owner,
 'status': status,
 if (isNew) 'createdAt': Timestamp.now(),
 'updatedAt': Timestamp.now(),
 };
 }
}

DateTime _readTimestamp(dynamic value) {
 if (value is Timestamp) return value.toDate();
 if (value is DateTime) return value;
 return DateTime.now();
}

Widget _dialogField({
 required TextEditingController controller,
 required String label,
 bool readOnly = false,
 int maxLines = 1,
}) {
 return Padding(
 padding: const EdgeInsets.only(bottom: 12),
 child: VoiceTextField(
 controller: controller,
 readOnly: readOnly,
 maxLines: maxLines,
 decoration: InputDecoration(labelText: label),
 ),
 );
}

Widget _dialogDropdownField({
 required String label,
 required String value,
 required List<String> options,
 required ValueChanged<String> onChanged,
 bool enabled = true,
}) {
 final selected = options.contains(value) ? value : options.first;
 return Padding(
 padding: const EdgeInsets.only(bottom: 12),
 child: DropdownButtonFormField<String>(
 value: selected,
 onChanged: enabled
 ? (next) {
 if (next == null) return;
 onChanged(next);
 }
 : null,
 items: options
 .map((option) => DropdownMenuItem<String>(
 value: option,
 child: Text(option),
 ))
 .toList(),
 decoration: InputDecoration(labelText: label),
 ),
 );
}

class _Debouncer {
 _Debouncer({Duration? delay})
 : delay = delay ?? const Duration(milliseconds: 700);

 final Duration delay;
 Timer? _timer;

 void run(void Function() action) {
 _timer?.cancel();
 _timer = Timer(delay, action);
 }

 void dispose() => _timer?.cancel();
}
