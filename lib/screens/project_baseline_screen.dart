import 'dart:convert';

import 'package:flutter/material.dart';

import 'package:ndu_project/widgets/draggable_sidebar.dart';
import 'package:ndu_project/widgets/initiation_like_sidebar.dart';
import 'package:ndu_project/widgets/kaz_ai_chat_bubble.dart';
import 'package:ndu_project/widgets/responsive.dart';
import 'package:ndu_project/utils/project_data_helper.dart';
import 'package:ndu_project/widgets/launch_phase_navigation.dart';
import 'package:ndu_project/utils/planning_phase_navigation.dart';
import 'package:ndu_project/services/openai_service_secure.dart';
import 'package:ndu_project/utils/text_sanitizer.dart';
import 'package:ndu_project/models/project_data_model.dart';

import 'package:ndu_project/widgets/voice_text_field.dart';
import 'package:ndu_project/widgets/planning_phase_header.dart';
import 'package:ndu_project/utils/pdf_export_helper.dart';
import 'package:ndu_project/theme.dart';
class ProjectBaselineScreen extends StatefulWidget {
 const ProjectBaselineScreen({super.key});

 static void open(BuildContext context) {
 Navigator.of(context).push(
 MaterialPageRoute(builder: (_) => const ProjectBaselineScreen()),
 );
 }

 @override
 State<ProjectBaselineScreen> createState() => _ProjectBaselineScreenState();
}

class _ProjectBaselineScreenState extends State<ProjectBaselineScreen> {
 bool _loading = true;
 bool _showComparison = false;
 bool _isGenerating = false;

 String _projectName = '';
 DateTime? _baselineStartDate;
 DateTime? _baselineEndDate;
 DateTime? _currentStartDate;
 DateTime? _currentEndDate;

 List<_BaselineVersion> _baselineVersions = [];
 String? _activeVersionId;

 List<_ScheduleMilestone> _milestones = [];
 List<_SchedulePhase> _phases = [];
 List<_CostItem> _costItems = [];
 List<_ScopeItem> _scopeItems = [];

 double _totalBudget = 0;
 double _currentSpend = 0;
 int _originalEpicCount = 0;
 int _currentEpicCount = 0;
 int _scopeChangeCount = 0;

 @override
 void initState() {
 super.initState();
 WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
 }

 void _loadData() {
 final data = ProjectDataHelper.getData(context);

 _projectName = data.projectName.trim();
 _totalBudget = ProjectDataHelper.getCostEstimateTotalByState(data,
 costState: 'forecast');

 _loadScheduleData(data);
 _loadCostData(data);
 _loadScopeData(data);
 _loadBaselineHistory(data);

 setState(() => _loading = false);
 }

 void _loadScheduleData(ProjectDataModel data) {
 final milestoneStart = data.frontEndPlanning.milestoneStartDate.trim();
 final milestoneEnd = data.frontEndPlanning.milestoneEndDate.trim();

 if (milestoneStart.isNotEmpty) {
 _baselineStartDate = DateTime.tryParse(milestoneStart);
 _currentStartDate = _baselineStartDate;
 }
 if (milestoneEnd.isNotEmpty) {
 _baselineEndDate = DateTime.tryParse(milestoneEnd);
 _currentEndDate = _baselineEndDate;
 }

 _milestones = data.keyMilestones
 .where((m) => m.name.trim().isNotEmpty)
 .map((m) => _ScheduleMilestone(
 name: m.name.trim(),
 targetDate: _parseDate(m.dueDate),
 discipline: m.discipline.trim(),
 status: _mapMilestoneStatus(m),
 baselineDate: _parseDate(m.dueDate),
 ))
 .toList();

 if (data.scheduleActivities.isNotEmpty) {
 final phaseMap = <String, _SchedulePhase>{};

 for (final activity in data.scheduleActivities) {
 final phaseName = activity.discipline.trim().isEmpty
 ? 'General'
 : activity.discipline.trim();
 final startDate = _parseDate(activity.startDate);
 final endDate = _parseDate(activity.dueDate);

 if (!phaseMap.containsKey(phaseName)) {
 phaseMap[phaseName] = _SchedulePhase(
 name: phaseName,
 baselineStart: startDate,
 baselineEnd: endDate,
 currentStart: startDate,
 currentEnd: endDate,
 taskCount: 0,
 completedCount: 0,
 );
 }

 final phase = phaseMap[phaseName]!;
 phaseMap[phaseName] = _SchedulePhase(
 name: phase.name,
 baselineStart: _earlierDate(phase.baselineStart, startDate),
 baselineEnd: _laterDate(phase.baselineEnd, endDate),
 currentStart: _earlierDate(phase.currentStart, startDate),
 currentEnd: _laterDate(phase.currentEnd, endDate),
 taskCount: phase.taskCount + 1,
 completedCount: phase.completedCount +
 (activity.status.toLowerCase().contains('complete') ? 1 : 0),
 );
 }

 _phases = phaseMap.values.toList();
 _phases.sort((a, b) => (a.baselineStart ?? DateTime.now())
 .compareTo(b.baselineStart ?? DateTime.now()));

 if (_phases.isNotEmpty) {
 _baselineStartDate ??= _phases.first.baselineStart;
 _baselineEndDate ??= _phases.last.baselineEnd;
 _currentStartDate ??= _phases.first.currentStart;
 _currentEndDate ??= _phases.last.currentEnd;
 }
 }
 }

 void _loadCostData(ProjectDataModel data) {
 final forecastItems = ProjectDataHelper.getActiveCostEstimateItems(
 data,
 costState: 'forecast',
 );
 final actualByScope = <String, double>{};
 for (final item in ProjectDataHelper.getActiveCostEstimateItems(
 data,
 costState: 'actual',
 )) {
 final scopeKey = item.reconciliationReference.trim().isNotEmpty
 ? item.reconciliationReference.trim()
 : item.id;
 actualByScope[scopeKey] = (actualByScope[scopeKey] ?? 0) + item.amount;
 }

 _costItems = forecastItems
 .map((item) => _CostItem(
 category: item.title.trim(),
 estimated: item.amount,
 actual: actualByScope[
 item.reconciliationReference.trim().isNotEmpty
 ? item.reconciliationReference.trim()
 : item.id] ??
 0,
 ))
 .toList();

 final storedSpend =
 data.planningNotes['baseline_current_spend']?.trim() ?? '';
 final actualTotal = ProjectDataHelper.getCostEstimateTotalByState(data,
 costState: 'actual');
 _currentSpend =
 actualTotal > 0 ? actualTotal : double.tryParse(storedSpend) ?? 0;
 }

 void _loadScopeData(ProjectDataModel data) {
 _scopeItems = [];

 for (final item in data.withinScopeItems) {
 if (item.description.trim().isNotEmpty) {
 _scopeItems.add(_ScopeItem(
 description: item.description.trim(),
 isInScope: true,
 ));
 }
 }

 for (final item in data.outOfScopeItems) {
 if (item.description.trim().isNotEmpty) {
 _scopeItems.add(_ScopeItem(
 description: item.description.trim(),
 isInScope: false,
 ));
 }
 }

 _originalEpicCount = data
 .planningNotes['baseline_original_epics']?.isNotEmpty ==
 true
 ? int.tryParse(data.planningNotes['baseline_original_epics']!.trim()) ??
 0
 : _countEpics();
 _currentEpicCount = _countEpics();
 _scopeChangeCount = data
 .planningNotes['baseline_scope_changes']?.isNotEmpty ==
 true
 ? int.tryParse(data.planningNotes['baseline_scope_changes']!.trim()) ??
 0
 : 0;
 }

 int _countEpics() {
 return _scopeItems.where((s) => s.isInScope).length;
 }

 void _loadBaselineHistory(ProjectDataModel data) {
 _baselineVersions = [];

 final historyJson = data.planningNotes['baseline_versions']?.trim() ?? '';
 if (historyJson.isNotEmpty) {
 try {
 final List<dynamic> decoded = jsonDecode(historyJson);
 _baselineVersions = decoded
 .map((v) => _BaselineVersion.fromJson(v as Map<String, dynamic>))
 .toList();
 _baselineVersions.sort((a, b) => b.createdAt.compareTo(a.createdAt));
 } catch (e) { debugPrint('Error: $e'); }
 }

 _activeVersionId =
 data.planningNotes['baseline_active_version']?.trim() ?? '';
 if (_activeVersionId!.isEmpty && _baselineVersions.isNotEmpty) {
 _activeVersionId = _baselineVersions.first.id;
 }
 }

 DateTime? _parseDate(String raw) {
 if (raw.trim().isEmpty) return null;
 final parsed = DateTime.tryParse(raw);
 if (parsed != null) return parsed;

 final parts = raw.split(RegExp(r'[\s,]+'));
 if (parts.length >= 3) {
 const months = [
 'Jan',
 'Feb',
 'Mar',
 'Apr',
 'May',
 'Jun',
 'Jul',
 'Aug',
 'Sep',
 'Oct',
 'Nov',
 'Dec'
 ];
 final monthIdx =
 months.indexWhere((m) => parts[0].toLowerCase() == m.toLowerCase());
 if (monthIdx != -1) {
 final day = int.tryParse(parts[1]) ?? 1;
 final year = int.tryParse(parts[2]) ?? DateTime.now().year;
 return DateTime(year, monthIdx + 1, day);
 }
 }
 return null;
 }

 DateTime? _earlierDate(DateTime? a, DateTime? b) {
 if (a == null) return b;
 if (b == null) return a;
 return a.isBefore(b) ? a : b;
 }

 DateTime? _laterDate(DateTime? a, DateTime? b) {
 if (a == null) return b;
 if (b == null) return a;
 return a.isAfter(b) ? a : b;
 }

 String _mapMilestoneStatus(dynamic m) {
 final comments = (m.comments ?? '').toString().trim().toLowerCase();
 if (comments.contains('complete')) return 'Completed';
 if (comments.contains('progress')) return 'In Progress';
 final dueDate = (m.dueDate ?? '').toString().trim();
 if (dueDate.isNotEmpty) {
 final parsed = DateTime.tryParse(dueDate);
 if (parsed != null && parsed.isBefore(DateTime.now())) {
 return 'Overdue';
 }
 }
 return 'Planned';
 }

 String _formatDate(DateTime? date) {
 if (date == null) return '—';
 const months = [
 'Jan',
 'Feb',
 'Mar',
 'Apr',
 'May',
 'Jun',
 'Jul',
 'Aug',
 'Sep',
 'Oct',
 'Nov',
 'Dec'
 ];
 return '${months[date.month - 1]} ${date.day}, ${date.year}';
 }

 String _formatShortDate(DateTime? date) {
 if (date == null) return '—';
 const months = [
 'Jan',
 'Feb',
 'Mar',
 'Apr',
 'May',
 'Jun',
 'Jul',
 'Aug',
 'Sep',
 'Oct',
 'Nov',
 'Dec'
 ];
 return '${months[date.month - 1]} ${date.day}';
 }

 int _daysBetween(DateTime? a, DateTime? b) {
 if (a == null || b == null) return 0;
 return b.difference(a).inDays;
 }

 Widget _buildTableHeaderCell(
 String label, {
 int flex = 1,
 double? width,
 }) {
 final child = Container(
 alignment: Alignment.center,
 padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
 child: Text(
 label,
 textAlign: TextAlign.center,
 style: const TextStyle(
 fontWeight: FontWeight.w700,
 fontSize: 12,
 color: Color(0xFF374151),
 ),
 ),
 );

 if (width != null) {
 return SizedBox(width: width, child: child);
 }

 return Expanded(flex: flex, child: child);
 }

 Widget _buildTableTextCell(
 String text, {
 int flex = 1,
 double? width,
 TextStyle? style,
 Alignment alignment = Alignment.centerLeft,
 TextAlign textAlign = TextAlign.left,
 }) {
 final child = Container(
 alignment: alignment,
 padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
 child: Text(
 text,
 textAlign: textAlign,
 softWrap: true,
 style: style ??
 const TextStyle(
 fontSize: 12,
 color: Color(0xFF374151),
 height: 1.35,
 ),
 ),
 );

 if (width != null) {
 return SizedBox(width: width, child: child);
 }

 return Expanded(flex: flex, child: child);
 }

 Widget _buildTableActionCell({
 required List<Widget> children,
 double width = 120,
 }) {
 return SizedBox(
 width: width,
 child: Row(
 mainAxisAlignment: MainAxisAlignment.center,
 children: children,
 ),
 );
 }

 Future<void> _handleUpdateBaseline() async {
 final approvedByController = TextEditingController();
 final descriptionController = TextEditingController();

 try {
 final payload = await showDialog<Map<String, String>>(
 context: context,
 builder: (dialogContext) => AlertDialog(
 title: const Text('Create Baseline Version'),
 content: SizedBox(
 width: 520,
 child: Column(
 mainAxisSize: MainAxisSize.min,
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 const Text(
 'This will capture the current schedule, cost, and scope as a new baseline version.',
 style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
 ),
 const SizedBox(height: 16),
 VoiceTextField(
 controller: approvedByController,
 decoration: const InputDecoration(
 labelText: 'Approved By',
 hintText: 'Enter approver name',
 border: OutlineInputBorder(),
 ),
 ),
 const SizedBox(height: 12),
 VoiceTextField(
 controller: descriptionController,
 minLines: 3,
 maxLines: 5,
 decoration: const InputDecoration(
 labelText: 'Version Description',
 hintText: 'Describe this baseline version...',
 border: OutlineInputBorder(),
 ),
 ),
 ],
 ),
 ),
 actions: [
 TextButton(
 onPressed: () => Navigator.of(dialogContext).pop(),
 child: const Text('Cancel'),
 ),
 ElevatedButton(
 onPressed: () {
 final approvedBy = approvedByController.text.trim();
 final description = descriptionController.text.trim();
 if (approvedBy.isEmpty || description.isEmpty) return;
 Navigator.of(dialogContext).pop({
 'approvedBy': approvedBy,
 'description': description,
 });
 },
 child: const Text('Create Baseline'),
 ),
 ],
 ),
 );

 if (!mounted || payload == null) return;
 final approvedBy = payload['approvedBy'] ?? '';
 final description = payload['description'] ?? '';
 if (approvedBy.isEmpty || description.isEmpty) return;

 final now = DateTime.now();
 final version = _BaselineVersion(
 id: '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}-${now.millisecondsSinceEpoch % 1000}',
 versionLabel: 'v${_baselineVersions.length + 1}',
 createdAt: now,
 approvedBy: approvedBy,
 description: description,
 scheduleSummary: _buildScheduleSummary(),
 costSummary: _buildCostSummary(),
 scopeSummary: _buildScopeSummary(),
 );

 _baselineVersions.insert(0, version);
 _activeVersionId = version.id;

 await _persistBaselineVersion(version);
 setState(() {});
 } catch (e) {
 if (!mounted) return;
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(
 content: Text('Unable to save baseline version.'),
 backgroundColor: Colors.red,
 ),
 );
 } finally {
 approvedByController.dispose();
 descriptionController.dispose();
 }
 }

 String _buildScheduleSummary() {
 final buffer = StringBuffer();
 buffer.writeln('Start: ${_formatDate(_baselineStartDate)}');
 buffer.writeln('End: ${_formatDate(_baselineEndDate)}');
 buffer.writeln(
 'Duration: ${_daysBetween(_baselineStartDate, _baselineEndDate)} days');
 buffer.writeln('Milestones: ${_milestones.length}');
 buffer.writeln('Phases: ${_phases.length}');
 return buffer.toString();
 }

 String _buildCostSummary() {
 final buffer = StringBuffer();
 buffer.writeln('Total Budget: \$${_totalBudget.toStringAsFixed(2)}');
 buffer.writeln('Cost Items: ${_costItems.length}');
 return buffer.toString();
 }

 String _buildScopeSummary() {
 final buffer = StringBuffer();
 buffer.writeln('In Scope: ${_scopeItems.where((s) => s.isInScope).length}');
 buffer.writeln(
 'Out of Scope: ${_scopeItems.where((s) => !s.isInScope).length}');
 return buffer.toString();
 }

 Future<void> _persistBaselineVersion(_BaselineVersion version) async {
 final versionsJson = jsonEncode(
 _baselineVersions.map((v) => v.toJson()).toList(),
 );

 await ProjectDataHelper.updateAndSave(
 context: context,
 checkpoint: 'project_baseline',
 showSnackbar: false,
 dataUpdater: (data) => data.copyWith(
 planningNotes: {
 ...data.planningNotes,
 'baseline_versions': versionsJson,
 'baseline_active_version': _activeVersionId ?? '',
 'baseline_original_epics': _originalEpicCount.toString(),
 'baseline_current_epics': _currentEpicCount.toString(),
 'baseline_scope_changes': _scopeChangeCount.toString(),
 },
 ),
 );

 if (mounted) {
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(
 content: Text('Baseline ${version.versionLabel} created.'),
 duration: const Duration(seconds: 2),
 ),
 );
 }
 }

 Future<void> _setActiveVersion(String versionId) async {
 setState(() => _activeVersionId = versionId);

 await ProjectDataHelper.updateAndSave(
 context: context,
 checkpoint: 'project_baseline',
 showSnackbar: false,
 dataUpdater: (data) => data.copyWith(
 planningNotes: {
 ...data.planningNotes,
 'baseline_active_version': versionId,
 },
 ),
 );
 }

 Future<void> _regenerateNotes() async {
 if (_isGenerating) return;

 setState(() => _isGenerating = true);

 try {
 final contextText = _buildAiContext();
 final ai = OpenAiServiceSecure();
 final text = await ai.generateFepSectionText(
 section: 'Project Baseline Summary',
 context: contextText,
 maxTokens: 800,
 temperature: 0.6,
 );

 if (!mounted) return;
 final cleaned = TextSanitizer.sanitizeAiRichText(text).trim();
 if (cleaned.isNotEmpty) {
 await ProjectDataHelper.updateAndSave(
 context: context,
 checkpoint: 'project_baseline',
 showSnackbar: false,
 dataUpdater: (data) => data.copyWith(
 planningNotes: {
 ...data.planningNotes,
 'planning_project_baseline_notes': cleaned,
 },
 ),
 );
 setState(() {});
 }
 } catch (e) {
 if (!mounted) return;
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(content: Text('AI generation failed: ${e.toString()}')),
 );
 } finally {
 if (mounted) setState(() => _isGenerating = false);
 }
 }

 String _buildAiContext() {
 final buffer = StringBuffer();
 buffer.writeln('Project: $_projectName');
 buffer.writeln('');
 buffer.writeln('SCHEDULE BASELINE:');
 buffer.writeln(_buildScheduleSummary());
 buffer.writeln('');
 buffer.writeln('COST BASELINE:');
 buffer.writeln(_buildCostSummary());
 buffer.writeln('');
 buffer.writeln('SCOPE BASELINE:');
 buffer.writeln(_buildScopeSummary());
 buffer.writeln('');
 buffer.writeln('MILESTONES:');
 for (final m in _milestones) {
 buffer
 .writeln('- ${m.name}: ${_formatDate(m.baselineDate)} (${m.status})');
 }
 buffer.writeln('');
 buffer.writeln(
 'Generate a summary of the project baseline including key dates, budget summary, and scope boundaries.');
 return buffer.toString();
 }

 @override
 Widget build(BuildContext context) {
 final bool isMobile = AppBreakpoints.isMobile(context);
 final double horizontalPadding = isMobile ? 18 : 32;

 return Scaffold(
 backgroundColor: Colors.white,
 body: SafeArea(
 child: Stack(
 children: [
 Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 DraggableSidebar(
 openWidth: AppBreakpoints.sidebarWidth(context),
 child: const InitiationLikeSidebar(
 activeItemLabel: 'Project Baseline'),
 ),
 Expanded(
 child: _loading
 ? const Center(child: CircularProgressIndicator())
 : SingleChildScrollView(
 padding: EdgeInsets.symmetric(
 horizontal: horizontalPadding, vertical: 28),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 PlanningPhaseHeader(
 title: 'Project Baseline',
onBack: () =>
 PlanningPhaseNavigation.goToPrevious(
 context, 'project_baseline'),
 onForward: () => PlanningPhaseNavigation.goToNext(
 context, 'project_baseline'), onExportPdf: _exportPdf),
 const SizedBox(height: 16),
 _buildHeader(context),
 const SizedBox(height: 24),
 _buildComparisonToggle(),
 const SizedBox(height: 24),
 _buildBaselineCards(context),
 const SizedBox(height: 24),
 _buildMilestonesSection(),
 const SizedBox(height: 24),
 _buildPhasesSection(),
 const SizedBox(height: 24),
 _buildBaselineHistory(),
 const SizedBox(height: 24),
 _buildVarianceAnalysis(),
 const SizedBox(height: 24),
 LaunchPhaseNavigation(
 backLabel: PlanningPhaseNavigation.backLabel(
 'project_baseline'),
 nextLabel: PlanningPhaseNavigation.nextLabel(
 'project_baseline'),
 onBack: () =>
 PlanningPhaseNavigation.goToPrevious(
 context, 'project_baseline'),
 onNext: () => PlanningPhaseNavigation.goToNext(
 context, 'project_baseline'),
 ),
 const SizedBox(height: 48),
 ],
 ),
 ),
 ),
 ],
 ),
 MobileSidebarHamburger(
 sidebar: const InitiationLikeSidebar(
 activeItemLabel: 'Project Baseline',
 ),
 ),
 const KazAiChatBubble(),
 ],
 ),
 ),
 );
 }

 Widget _buildHeader(BuildContext context) {
 return Container(
 padding: const EdgeInsets.all(24),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(20),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 boxShadow: [
 BoxShadow(
 color: Colors.black.withOpacity(0.04),
 blurRadius: 16,
 offset: const Offset(0, 8),
 ),
 ],
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 children: [
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 'Project Baseline',
 style:
 Theme.of(context).textTheme.headlineMedium?.copyWith(
 fontWeight: FontWeight.w700,
 color: const Color(0xFF111827),
 ),
 ),
 const SizedBox(height: 6),
 Text(
 _projectName.isNotEmpty
 ? _projectName
 : 'Track schedule, cost, and scope baselines.',
 style: const TextStyle(
 fontSize: 14,
 color: Color(0xFF6B7280),
 ),
 ),
 ],
 ),
 ),
 const SizedBox(width: 16),
 ElevatedButton.icon(
 onPressed: _isGenerating ? null : _regenerateNotes,
 style: ElevatedButton.styleFrom(
 backgroundColor: const Color(0xFF4154F1),
 foregroundColor: Colors.white,
 padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
 elevation: 0,
 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
 ),
 icon: _isGenerating
 ? const SizedBox(
 width: 16,
 height: 16,
 child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
 )
 : const Icon(Icons.auto_awesome, size: 16),
 label: const Text('AI Assist', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
 ),
 const SizedBox(width: 12),
 FilledButton.icon(
 onPressed: _handleUpdateBaseline,
 icon: const Icon(Icons.add_chart, size: 18),
 label: const Text('New Baseline'),
 style: FilledButton.styleFrom(
 backgroundColor: const Color(0xFFFFC812),
 padding:
 const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
 shape: RoundedRectangleBorder(
 borderRadius: BorderRadius.circular(12)),
 ),
 ),
 ],
 ),
 const SizedBox(height: 16),
 const Divider(color: Color(0xFFE5E7EB)),
 const SizedBox(height: 16),
 _buildProjectStats(),
 ],
 ),
 );
 }

 Widget _buildProjectStats() {
 final scheduleDuration = _daysBetween(_baselineStartDate, _baselineEndDate);
 final activeVersion =
 _baselineVersions.where((v) => v.id == _activeVersionId).firstOrNull;

 return Wrap(
 spacing: 24,
 runSpacing: 12,
 children: [
 _buildStatChip(
 'Start Date',
 _formatShortDate(_baselineStartDate),
 Icons.play_arrow_outlined,
 const Color(0xFF10B981),
 ),
 _buildStatChip(
 'End Date',
 _formatShortDate(_baselineEndDate),
 Icons.stop_outlined,
 const Color(0xFFEF4444),
 ),
 _buildStatChip(
 'Duration',
 scheduleDuration > 0 ? '$scheduleDuration days' : '—',
 Icons.timelapse,
 const Color(0xFF6366F1),
 ),
 _buildStatChip(
 'Active Version',
 activeVersion?.versionLabel ?? 'No baseline',
 Icons.bookmark_outline,
 const Color(0xFFFFC812),
 ),
 _buildStatChip(
 'Versions',
 '${_baselineVersions.length}',
 Icons.history,
 const Color(0xFF6B7280),
 ),
 ],
 );
 }

 Widget _buildStatChip(
 String label, String value, IconData icon, Color color) {
 return Container(
 padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
 decoration: BoxDecoration(
 color: color.withOpacity(0.08),
 borderRadius: BorderRadius.circular(10),
 ),
 child: Row(
 mainAxisSize: MainAxisSize.min,
 children: [
 Icon(icon, size: 16, color: color),
 const SizedBox(width: 8),
 Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 mainAxisSize: MainAxisSize.min,
 children: [
 Text(
 label,
 style: TextStyle(
 fontSize: 10,
 color: color.withOpacity(0.8),
 ),
 ),
 Text(
 value,
 style: TextStyle(
 fontSize: 13,
 fontWeight: FontWeight.w700,
 color: color,
 ),
 ),
 ],
 ),
 ],
 ),
 );
 }

 Widget _buildComparisonToggle() {
 return Container(
 padding: const EdgeInsets.all(16),
 decoration: BoxDecoration(
 color: const Color(0xFFF8FAFC),
 borderRadius: BorderRadius.circular(12),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 ),
 child: Row(
 children: [
 const Icon(Icons.compare_arrows, size: 20, color: Color(0xFF6B7280)),
 const SizedBox(width: 12),
 const Expanded(
 child: Text(
 'Show baseline vs current comparison',
 style: TextStyle(
 fontSize: 13,
 fontWeight: FontWeight.w600,
 color: Color(0xFF374151),
 ),
 ),
 ),
 Switch(
 value: _showComparison,
 onChanged: (value) => setState(() => _showComparison = value),
 trackColor: WidgetStateProperty.resolveWith((states) => states.contains(WidgetState.selected) ? const Color(0xFFFFC812) : null),
 thumbColor: WidgetStateProperty.resolveWith((states) {
 if (states.contains(WidgetState.selected)) {
 return Colors.white;
 }
 return Colors.grey;
 }),
 ),
 ],
 ),
 );
 }

 Widget _buildBaselineCards(BuildContext context) {
 return LayoutBuilder(
 builder: (context, constraints) {
 final width = constraints.maxWidth;
 int columns;
 if (width >= 1080) {
 columns = 3;
 } else if (width >= 720) {
 columns = 2;
 } else {
 columns = 1;
 }

 const spacing = 16.0;
 final cardWidth =
 columns == 1 ? width : (width - spacing * (columns - 1)) / columns;

 return Wrap(
 spacing: spacing,
 runSpacing: 18,
 children: [
 SizedBox(
 width: cardWidth,
 child: _buildScheduleBaselineCard(),
 ),
 SizedBox(
 width: cardWidth,
 child: _buildCostBaselineCard(),
 ),
 SizedBox(
 width: cardWidth,
 child: _buildScopeBaselineCard(),
 ),
 ],
 );
 },
 );
 }

 Widget _buildScheduleBaselineCard() {
 return Container(
 padding: const EdgeInsets.all(24),
 decoration: BoxDecoration(
 gradient: const LinearGradient(
 colors: [Color(0xFFFFC812), Color(0xFFE6B000)],
 begin: Alignment.topLeft,
 end: Alignment.bottomRight,
 ),
 borderRadius: BorderRadius.circular(20),
 boxShadow: [
 BoxShadow(
 color: const Color(0xFFD97706).withOpacity(0.3),
 blurRadius: 20,
 offset: const Offset(0, 12),
 ),
 ],
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 children: const [
 Icon(Icons.schedule, color: Colors.white, size: 24),
 SizedBox(width: 12),
 Text(
 'Schedule Baseline',
 style: TextStyle(
 color: Colors.white,
 fontSize: 18,
 fontWeight: FontWeight.w700,
 ),
 ),
 ],
 ),
 const SizedBox(height: 24),
 _buildScheduleMetric(
 'Start Date', _formatShortDate(_baselineStartDate)),
 _buildScheduleMetric('End Date', _formatShortDate(_baselineEndDate)),
 _buildScheduleMetric('Duration',
 '${_daysBetween(_baselineStartDate, _baselineEndDate)} days'),
 _buildScheduleMetric('Milestones', '${_milestones.length}'),
 _buildScheduleMetric('Phases', '${_phases.length}'),
 if (_showComparison) ...[
 const SizedBox(height: 16),
 Container(
 height: 1,
 color: Colors.white.withOpacity(0.2),
 ),
 const SizedBox(height: 16),
 const Text(
 'Current Status',
 style: TextStyle(
 color: Color(0xCCEFF6FF),
 fontSize: 12,
 fontWeight: FontWeight.w600,
 ),
 ),
 const SizedBox(height: 8),
 _buildScheduleMetric(
 'Schedule Variance',
 _calculateScheduleVariance(),
 isVariance: true,
 ),
 ],
 ],
 ),
 );
 }

 Widget _buildScheduleMetric(String label, String value,
 {bool isVariance = false}) {
 return Padding(
 padding: const EdgeInsets.symmetric(vertical: 6),
 child: Row(
 mainAxisAlignment: MainAxisAlignment.spaceBetween,
 children: [
 Text(
 label,
 style: TextStyle(
 color: isVariance
 ? const Color(0xFFFFD700)
 : const Color(0xCCEFF6FF),
 fontSize: 13,
 fontWeight: FontWeight.w600,
 ),
 ),
 Text(
 value,
 style: TextStyle(
 color: isVariance ? const Color(0xFFFFD700) : Colors.white,
 fontSize: 14,
 fontWeight: FontWeight.w700,
 ),
 ),
 ],
 ),
 );
 }

 String _calculateScheduleVariance() {
 if (_baselineStartDate == null || _currentStartDate == null) return '—';
 final variance = _currentEndDate?.difference(_baselineEndDate!).inDays ?? 0;
 if (variance == 0) return 'On Track';
 return variance > 0 ? '+$variance days' : '$variance days';
 }

 Widget _buildCostBaselineCard() {
 final variance = _currentSpend - _totalBudget;
 final variancePct =
 _totalBudget > 0 ? (variance / _totalBudget * 100) : 0.0;

 return Container(
 padding: const EdgeInsets.all(24),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(20),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 boxShadow: [
 BoxShadow(
 color: Colors.black.withOpacity(0.04),
 blurRadius: 16,
 offset: const Offset(0, 8),
 ),
 ],
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 children: const [
 Icon(Icons.account_balance_wallet,
 color: Color(0xFF10B981), size: 24),
 SizedBox(width: 12),
 Text(
 'Cost Baseline',
 style: TextStyle(
 color: Color(0xFF111827),
 fontSize: 18,
 fontWeight: FontWeight.w700,
 ),
 ),
 ],
 ),
 const SizedBox(height: 24),
 _buildCostMetric('Total Budget', '\$${_formatNumber(_totalBudget)}'),
 _buildCostMetric('Cost Items', '${_costItems.length}'),
 _buildCostMetric('Categories',
 '${_costItems.map((c) => c.category).toSet().length}'),
 if (_showComparison) ...[
 const SizedBox(height: 16),
 Container(
 height: 1,
 color: const Color(0xFFE5E7EB),
 ),
 const SizedBox(height: 16),
 const Text(
 'Current Status',
 style: TextStyle(
 color: Color(0xFF6B7280),
 fontSize: 12,
 fontWeight: FontWeight.w600,
 ),
 ),
 const SizedBox(height: 8),
 _buildCostMetric(
 'Current Spend',
 '\$${_formatNumber(_currentSpend)}',
 ),
 _buildCostMetric(
 'Variance',
 '${variance >= 0 ? '+' : ''}\$${_formatNumber(variance)} (${variancePct.toStringAsFixed(1)}%)',
 isVariance: true,
 isOverBudget: variance > 0,
 ),
 ],
 ],
 ),
 );
 }

 Widget _buildCostMetric(String label, String value,
 {bool isVariance = false, bool isOverBudget = false}) {
 Color valueColor = const Color(0xFF111827);
 if (isVariance) {
 valueColor =
 isOverBudget ? const Color(0xFFEF4444) : const Color(0xFF10B981);
 }

 return Padding(
 padding: const EdgeInsets.symmetric(vertical: 6),
 child: Row(
 mainAxisAlignment: MainAxisAlignment.spaceBetween,
 children: [
 Text(
 label,
 style: const TextStyle(
 color: Color(0xFF6B7280),
 fontSize: 13,
 fontWeight: FontWeight.w600,
 ),
 ),
 Text(
 value,
 style: TextStyle(
 color: valueColor,
 fontSize: 14,
 fontWeight: FontWeight.w700,
 ),
 ),
 ],
 ),
 );
 }

 Widget _buildScopeBaselineCard() {
 return Container(
 padding: const EdgeInsets.all(24),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(20),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 boxShadow: [
 BoxShadow(
 color: Colors.black.withOpacity(0.04),
 blurRadius: 16,
 offset: const Offset(0, 8),
 ),
 ],
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 children: const [
 Icon(Icons.dashboard_customize,
 color: Color(0xFF8B5CF6), size: 24),
 SizedBox(width: 12),
 Text(
 'Scope Baseline',
 style: TextStyle(
 color: Color(0xFF111827),
 fontSize: 18,
 fontWeight: FontWeight.w700,
 ),
 ),
 ],
 ),
 const SizedBox(height: 24),
 _buildScopeMetric('In Scope Items',
 '${_scopeItems.where((s) => s.isInScope).length}'),
 _buildScopeMetric('Out of Scope Items',
 '${_scopeItems.where((s) => !s.isInScope).length}'),
 _buildScopeMetric('Total Items', '${_scopeItems.length}'),
 if (_showComparison) ...[
 const SizedBox(height: 16),
 Container(
 height: 1,
 color: const Color(0xFFE5E7EB),
 ),
 const SizedBox(height: 16),
 const Text(
 'Change Tracking',
 style: TextStyle(
 color: Color(0xFF6B7280),
 fontSize: 12,
 fontWeight: FontWeight.w600,
 ),
 ),
 const SizedBox(height: 8),
 _buildScopeMetric(
 'Scope Changes',
 '$_scopeChangeCount',
 isVariance: _scopeChangeCount > 0,
 ),
 _buildScopeMetric(
 'Current vs Original',
 _scopeChangeCount >= 0
 ? '+$_scopeChangeCount'
 : '$_scopeChangeCount',
 isVariance: true,
 isChange: _scopeChangeCount != 0,
 ),
 ],
 ],
 ),
 );
 }

 Widget _buildScopeMetric(String label, String value,
 {bool isVariance = false, bool isChange = false}) {
 Color valueColor = const Color(0xFF111827);
 if (isVariance && isChange) {
 valueColor = const Color(0xFFF59E0B);
 }

 return Padding(
 padding: const EdgeInsets.symmetric(vertical: 6),
 child: Row(
 mainAxisAlignment: MainAxisAlignment.spaceBetween,
 children: [
 Text(
 label,
 style: const TextStyle(
 color: Color(0xFF6B7280),
 fontSize: 13,
 fontWeight: FontWeight.w600,
 ),
 ),
 Text(
 value,
 style: TextStyle(
 color: valueColor,
 fontSize: 14,
 fontWeight: FontWeight.w700,
 ),
 ),
 ],
 ),
 );
 }

 String _formatNumber(double value) {
 if (value >= 1000000) {
 return '${(value / 1000000).toStringAsFixed(1)}M';
 } else if (value >= 1000) {
 return '${(value / 1000).toStringAsFixed(0)}K';
 }
 return value.toStringAsFixed(0);
 }

 Widget _buildMilestonesSection() {
 return Container(
 padding: const EdgeInsets.all(24),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(20),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 boxShadow: [
 BoxShadow(
 color: Colors.black.withOpacity(0.04),
 blurRadius: 16,
 offset: const Offset(0, 8),
 ),
 ],
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 children: [
 Container(
 width: 36,
 height: 36,
 decoration: BoxDecoration(
 color: const Color(0xFFFFF3C4),
 borderRadius: BorderRadius.circular(10),
 ),
 child:
 const Icon(Icons.flag, color: Color(0xFFF59E0B), size: 20),
 ),
 const SizedBox(width: 12),
 const Text(
 'Key Milestones',
 style: TextStyle(
 fontSize: 18,
 fontWeight: FontWeight.w700,
 color: Color(0xFF111827),
 ),
 ),
 const Spacer(),
 Text(
 '${_milestones.length} milestones',
 style: const TextStyle(
 fontSize: 13,
 color: Color(0xFF6B7280),
 ),
 ),
 ],
 ),
 const SizedBox(height: 20),
 if (_milestones.isEmpty)
 const Center(
 child: Padding(
 padding: EdgeInsets.all(32),
 child: Text(
 'No milestones defined yet.',
 style: TextStyle(
 color: Color(0xFF9CA3AF),
 fontStyle: FontStyle.italic,
 ),
 ),
 ),
 )
 else
 LayoutBuilder(
 builder: (context, constraints) {
 return SingleChildScrollView(
 scrollDirection: Axis.horizontal,
 child: SizedBox(
 width:
 constraints.maxWidth > 600 ? constraints.maxWidth : 600,
 child: Column(
 children: [
 Container(
 padding: const EdgeInsets.symmetric(
 horizontal: 16, vertical: 10),
 decoration: const BoxDecoration(
 color: Color(0xFFF8FAFC),
 borderRadius:
 BorderRadius.vertical(top: Radius.circular(10)),
 ),
 child: Row(
 children: [
 _buildTableHeaderCell('#', flex: 2),
 _buildTableHeaderCell('Milestone', flex: 5),
 _buildTableHeaderCell('Target Date', flex: 3),
 _buildTableHeaderCell('Status', flex: 3),
 _buildTableHeaderCell('Discipline', flex: 3),
 ],
 ),
 ),
 ...List.generate(_milestones.length, (index) {
 final m = _milestones[index];
 return Container(
 padding: const EdgeInsets.symmetric(
 horizontal: 16, vertical: 12),
 decoration: BoxDecoration(
 color: index.isEven
 ? Colors.white
 : const Color(0xFFFAFAFA),
 border: const Border(
 bottom: BorderSide(color: Color(0xFFE5E7EB))),
 ),
 child: Row(
 children: [
 _buildTableTextCell(
 '${index + 1}',
 flex: 2,
 alignment: Alignment.center,
 textAlign: TextAlign.center,
 style: const TextStyle(
 fontSize: 13,
 color: Color(0xFF6B7280),
 ),
 ),
 _buildTableTextCell(
 m.name,
 flex: 5,
 style: const TextStyle(
 fontSize: 13,
 fontWeight: FontWeight.w600,
 color: Color(0xFF111827),
 height: 1.35,
 ),
 ),
 _buildTableTextCell(
 _formatShortDate(m.baselineDate),
 flex: 3,
 alignment: Alignment.center,
 textAlign: TextAlign.center,
 style: const TextStyle(
 fontSize: 13,
 color: Color(0xFF374151),
 ),
 ),
 Expanded(
 flex: 3,
 child: Container(
 alignment: Alignment.center,
 padding: const EdgeInsets.symmetric(
 horizontal: 10, vertical: 6),
 child: _buildStatusBadge(m.status),
 ),
 ),
 _buildTableTextCell(
 m.discipline.isEmpty
 ? 'General'
 : m.discipline,
 flex: 3,
 style: const TextStyle(
 fontSize: 12,
 color: Color(0xFF6B7280),
 height: 1.35,
 ),
 ),
 ],
 ),
 );
 }),
 ],
 ),
 ),
 );
 },
 ),
 ],
 ),
 );
 }

 Widget _buildStatusBadge(String status) {
 Color bgColor;
 Color textColor;

 switch (status.toLowerCase()) {
 case 'completed':
 bgColor = const Color(0xFF10B981);
 textColor = Colors.white;
 break;
 case 'in progress':
 bgColor = const Color(0xFFFBBF24);
 textColor = Colors.white;
 break;
 case 'overdue':
 bgColor = const Color(0xFFEF4444);
 textColor = Colors.white;
 break;
 default:
 bgColor = const Color(0xFFE5E7EB);
 textColor = const Color(0xFF6B7280);
 }

 return Container(
 padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
 decoration: BoxDecoration(
 color: bgColor,
 borderRadius: BorderRadius.circular(999),
 ),
 child: Text(
 status,
 style: TextStyle(
 fontSize: 10,
 fontWeight: FontWeight.w700,
 color: textColor,
 ),
 ),
 );
 }

 Widget _buildPhasesSection() {
 return Container(
 padding: const EdgeInsets.all(24),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(20),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 boxShadow: [
 BoxShadow(
 color: Colors.black.withOpacity(0.04),
 blurRadius: 16,
 offset: const Offset(0, 8),
 ),
 ],
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 children: [
 Container(
 width: 36,
 height: 36,
 decoration: BoxDecoration(
 color: const Color(0xFFEEF2FF),
 borderRadius: BorderRadius.circular(10),
 ),
 child: const Icon(Icons.layers,
 color: Color(0xFF6366F1), size: 20),
 ),
 const SizedBox(width: 12),
 const Text(
 'Schedule Phases',
 style: TextStyle(
 fontSize: 18,
 fontWeight: FontWeight.w700,
 color: Color(0xFF111827),
 ),
 ),
 const Spacer(),
 Text(
 '${_phases.length} phases',
 style: const TextStyle(
 fontSize: 13,
 color: Color(0xFF6B7280),
 ),
 ),
 ],
 ),
 const SizedBox(height: 20),
 if (_phases.isEmpty)
 const Center(
 child: Padding(
 padding: EdgeInsets.all(32),
 child: Text(
 'No schedule phases defined yet.',
 style: TextStyle(
 color: Color(0xFF9CA3AF),
 fontStyle: FontStyle.italic,
 ),
 ),
 ),
 )
 else
 LayoutBuilder(
 builder: (context, constraints) {
 return SingleChildScrollView(
 scrollDirection: Axis.horizontal,
 child: SizedBox(
 width:
 constraints.maxWidth > 780 ? constraints.maxWidth : 780,
 child: Column(
 children: [
 Container(
 padding: const EdgeInsets.symmetric(
 horizontal: 16, vertical: 10),
 decoration: const BoxDecoration(
 color: Color(0xFFF8FAFC),
 borderRadius:
 BorderRadius.vertical(top: Radius.circular(10)),
 ),
 child: Row(
 children: [
 _buildTableHeaderCell('#', flex: 2),
 _buildTableHeaderCell('Phase', flex: 4),
 _buildTableHeaderCell('Start', flex: 2),
 _buildTableHeaderCell('End', flex: 2),
 _buildTableHeaderCell('Duration', flex: 2),
 _buildTableHeaderCell('Tasks', flex: 2),
 _buildTableHeaderCell('Progress', flex: 4),
 ],
 ),
 ),
 ...List.generate(_phases.length, (index) {
 final p = _phases[index];
 final duration =
 _daysBetween(p.baselineStart, p.baselineEnd);
 final progress = p.taskCount > 0
 ? p.completedCount / p.taskCount
 : 0.0;

 return Container(
 padding: const EdgeInsets.symmetric(
 horizontal: 16, vertical: 12),
 decoration: BoxDecoration(
 color: index.isEven
 ? Colors.white
 : const Color(0xFFFAFAFA),
 border: const Border(
 bottom: BorderSide(color: Color(0xFFE5E7EB))),
 ),
 child: Row(
 children: [
 _buildTableTextCell(
 '${index + 1}',
 flex: 2,
 alignment: Alignment.center,
 textAlign: TextAlign.center,
 style: const TextStyle(
 fontSize: 13,
 color: Color(0xFF6B7280),
 ),
 ),
 _buildTableTextCell(
 p.name,
 flex: 4,
 style: const TextStyle(
 fontSize: 13,
 fontWeight: FontWeight.w600,
 color: Color(0xFF111827),
 height: 1.35,
 ),
 ),
 _buildTableTextCell(
 _formatShortDate(p.baselineStart),
 flex: 2,
 alignment: Alignment.center,
 textAlign: TextAlign.center,
 ),
 _buildTableTextCell(
 _formatShortDate(p.baselineEnd),
 flex: 2,
 alignment: Alignment.center,
 textAlign: TextAlign.center,
 ),
 _buildTableTextCell(
 '${duration}d',
 flex: 2,
 alignment: Alignment.center,
 textAlign: TextAlign.center,
 ),
 _buildTableTextCell(
 '${p.completedCount}/${p.taskCount}',
 flex: 2,
 alignment: Alignment.center,
 textAlign: TextAlign.center,
 ),
 Expanded(
 flex: 4,
 child: Row(
 children: [
 Expanded(
 child: ClipRRect(
 borderRadius:
 BorderRadius.circular(4),
 child: LinearProgressIndicator(
 value: progress,
 minHeight: 8,
 backgroundColor:
 const Color(0xFFE5E7EB),
 valueColor:
 AlwaysStoppedAnimation<Color>(
 progress >= 1.0
 ? const Color(0xFF10B981)
 : const Color(0xFFFBBF24),
 ),
 ),
 ),
 ),
 const SizedBox(width: 8),
 Text(
 '${(progress * 100).round()}%',
 style: const TextStyle(
 fontSize: 11,
 fontWeight: FontWeight.w600,
 color: Color(0xFF374151)),
 ),
 ],
 ),
 ),
 ],
 ),
 );
 }),
 ],
 ),
 ),
 );
 },
 ),
 ],
 ),
 );
 }

 Widget _buildBaselineHistory() {
 return Container(
 padding: const EdgeInsets.all(24),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(20),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 boxShadow: [
 BoxShadow(
 color: Colors.black.withOpacity(0.04),
 blurRadius: 16,
 offset: const Offset(0, 8),
 ),
 ],
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 children: [
 Container(
 width: 36,
 height: 36,
 decoration: BoxDecoration(
 color: const Color(0xFFFEF3C7),
 borderRadius: BorderRadius.circular(10),
 ),
 child: const Icon(Icons.history,
 color: Color(0xFFD97706), size: 20),
 ),
 const SizedBox(width: 12),
 const Text(
 'Baseline History',
 style: TextStyle(
 fontSize: 18,
 fontWeight: FontWeight.w700,
 color: Color(0xFF111827),
 ),
 ),
 const Spacer(),
 Text(
 '${_baselineVersions.length} versions',
 style: const TextStyle(
 fontSize: 13,
 color: Color(0xFF6B7280),
 ),
 ),
 ],
 ),
 const SizedBox(height: 20),
 if (_baselineVersions.isEmpty)
 Center(
 child: Padding(
 padding: const EdgeInsets.all(32),
 child: Column(
 children: [
 const Icon(Icons.add_chart,
 size: 48, color: Color(0xFF9CA3AF)),
 const SizedBox(height: 12),
 const Text(
 'No baseline versions yet.',
 style: TextStyle(
 color: Color(0xFF9CA3AF),
 fontStyle: FontStyle.italic,
 ),
 ),
 const SizedBox(height: 8),
 const Text(
 'Click "New Baseline" to create your first baseline version.',
 style: TextStyle(
 fontSize: 12,
 color: Color(0xFF9CA3AF),
 ),
 ),
 ],
 ),
 ),
 )
 else
 LayoutBuilder(
 builder: (context, constraints) {
 return SingleChildScrollView(
 scrollDirection: Axis.horizontal,
 child: SizedBox(
 width:
 constraints.maxWidth > 700 ? constraints.maxWidth : 700,
 child: Column(
 children: [
 Container(
 padding: const EdgeInsets.symmetric(
 horizontal: 16, vertical: 10),
 decoration: const BoxDecoration(
 color: Color(0xFFF8FAFC),
 borderRadius:
 BorderRadius.vertical(top: Radius.circular(10)),
 ),
 child: Row(
 children: [
 _buildTableHeaderCell('#', flex: 1),
 _buildTableHeaderCell('Version', flex: 2),
 _buildTableHeaderCell('Date', flex: 2),
 _buildTableHeaderCell('Approved By', flex: 2),
 _buildTableHeaderCell('Description', flex: 4),
 _buildTableHeaderCell('Actions', width: 120),
 ],
 ),
 ),
 ...List.generate(_baselineVersions.length, (index) {
 final v = _baselineVersions[index];
 final isActive = v.id == _activeVersionId;

 return Container(
 padding: const EdgeInsets.symmetric(
 horizontal: 16, vertical: 12),
 decoration: BoxDecoration(
 color: index.isEven
 ? Colors.white
 : const Color(0xFFFAFAFA),
 border: const Border(
 bottom: BorderSide(color: Color(0xFFE5E7EB))),
 ),
 child: Row(
 children: [
 _buildTableTextCell(
 '${index + 1}',
 flex: 1,
 alignment: Alignment.center,
 textAlign: TextAlign.center,
 style: const TextStyle(
 fontSize: 13,
 color: Color(0xFF6B7280),
 ),
 ),
 Expanded(
 flex: 2,
 child: Container(
 padding: const EdgeInsets.symmetric(
 horizontal: 10, vertical: 6),
 child: Wrap(
 crossAxisAlignment:
 WrapCrossAlignment.center,
 spacing: 8,
 runSpacing: 6,
 children: [
 Text(
 v.versionLabel,
 style: const TextStyle(
 fontSize: 13,
 fontWeight: FontWeight.w700,
 color: Color(0xFF111827),
 ),
 ),
 if (isActive)
 Container(
 padding: const EdgeInsets.symmetric(
 horizontal: 8, vertical: 2),
 decoration: BoxDecoration(
 color: const Color(0xFF10B981),
 borderRadius:
 BorderRadius.circular(999),
 ),
 child: const Text(
 'Active',
 style: TextStyle(
 fontSize: 9,
 fontWeight: FontWeight.w700,
 color: Colors.white,
 ),
 ),
 ),
 ],
 ),
 ),
 ),
 _buildTableTextCell(
 _formatShortDate(v.createdAt),
 flex: 2,
 alignment: Alignment.center,
 textAlign: TextAlign.center,
 ),
 _buildTableTextCell(
 v.approvedBy,
 flex: 2,
 ),
 _buildTableTextCell(
 v.description,
 flex: 4,
 style: const TextStyle(
 fontSize: 12,
 color: Color(0xFF6B7280),
 height: 1.35,
 ),
 ),
 _buildTableActionCell(
 children: [
 if (!isActive)
 IconButton(
 icon: const Icon(
 Icons.check_circle_outline,
 size: 18),
 color: const Color(0xFF6B7280),
 tooltip: 'Set as Active',
 onPressed: () =>
 _setActiveVersion(v.id),
 ),
 IconButton(
 icon: const Icon(
 Icons.visibility_outlined,
 size: 18),
 color: const Color(0xFFD97706),
 tooltip: 'View Details',
 onPressed: () => _showVersionDetails(v),
 ),
 ],
 ),
 ],
 ),
 );
 }),
 ],
 ),
 ),
 );
 },
 ),
 ],
 ),
 );
 }

 void _showVersionDetails(_BaselineVersion version) {
 showDialog<void>(
 context: context,
 builder: (dialogContext) => Dialog(
 insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
 child: ConstrainedBox(
 constraints: const BoxConstraints(maxWidth: 720),
 child: Padding(
 padding: const EdgeInsets.all(24),
 child: Column(
 mainAxisSize: MainAxisSize.min,
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 children: [
 Container(
 width: 42,
 height: 42,
 decoration: BoxDecoration(
 color: const Color(0xFFEEF2FF),
 borderRadius: BorderRadius.circular(12),
 ),
 child: const Icon(
 Icons.history,
 color: Color(0xFF4F46E5),
 size: 22,
 ),
 ),
 const SizedBox(width: 14),
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 'Baseline ${version.versionLabel}',
 style: const TextStyle(
 fontSize: 20,
 fontWeight: FontWeight.w800,
 color: Color(0xFF111827),
 ),
 ),
 const SizedBox(height: 4),
 const Text(
 'Version details and captured baseline summaries',
 style: TextStyle(
 fontSize: 13,
 color: Color(0xFF6B7280),
 ),
 ),
 ],
 ),
 ),
 IconButton(
 onPressed: () => Navigator.of(dialogContext).pop(),
 icon: const Icon(Icons.close),
 tooltip: 'Close',
 ),
 ],
 ),
 const SizedBox(height: 20),
 Flexible(
 child: SingleChildScrollView(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 mainAxisSize: MainAxisSize.min,
 children: [
 Container(
 padding: const EdgeInsets.all(16),
 decoration: BoxDecoration(
 color: const Color(0xFFF8FAFC),
 borderRadius: BorderRadius.circular(16),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 ),
 child: Column(
 children: [
 _buildDetailRow(
 'Date', _formatDate(version.createdAt)),
 _buildDetailRow(
 'Approved By', version.approvedBy),
 _buildDetailRow(
 'Description', version.description),
 ],
 ),
 ),
 if (version.scheduleSummary.isNotEmpty) ...[
 const SizedBox(height: 20),
 _buildVersionSummaryCard(
 title: 'Schedule Summary',
 content: version.scheduleSummary,
 ),
 ],
 if (version.costSummary.isNotEmpty) ...[
 const SizedBox(height: 16),
 _buildVersionSummaryCard(
 title: 'Cost Summary',
 content: version.costSummary,
 ),
 ],
 if (version.scopeSummary.isNotEmpty) ...[
 const SizedBox(height: 16),
 _buildVersionSummaryCard(
 title: 'Scope Summary',
 content: version.scopeSummary,
 ),
 ],
 ],
 ),
 ),
 ),
 const SizedBox(height: 20),
 Align(
 alignment: Alignment.centerRight,
 child: TextButton(
 onPressed: () => Navigator.of(dialogContext).pop(),
 child: const Text('Close'),
 ),
 ),
 ],
 ),
 ),
 ),
 ),
 );
 }

 Widget _buildDetailRow(String label, String value) {
 return Padding(
 padding: const EdgeInsets.symmetric(vertical: 8),
 child: Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 SizedBox(
 width: 120,
 child: Text(
 label,
 style: const TextStyle(
 fontSize: 12,
 fontWeight: FontWeight.w600,
 color: Color(0xFF6B7280),
 ),
 ),
 ),
 Expanded(
 child: Text(
 value,
 softWrap: true,
 style: const TextStyle(
 fontSize: 13,
 color: Color(0xFF111827),
 height: 1.4,
 ),
 ),
 ),
 ],
 ),
 );
 }

 Widget _buildVersionSummaryCard({
 required String title,
 required String content,
 }) {
 return Container(
 width: double.infinity,
 padding: const EdgeInsets.all(16),
 decoration: BoxDecoration(
 color: const Color(0xFFF8FAFC),
 borderRadius: BorderRadius.circular(16),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 title,
 style: const TextStyle(
 fontWeight: FontWeight.w700,
 fontSize: 13,
 color: Color(0xFF111827),
 ),
 ),
 const SizedBox(height: 10),
 SelectableText(
 content,
 style: const TextStyle(
 fontSize: 12,fontFamily: appFontFamily,
            color: Color(0xFF374151),
 height: 1.4,
 ),
 ),
 ],
 ),
 );
 }

 Widget _buildVarianceAnalysis() {
 final scheduleVariance = _calculateScheduleVarianceDays();
 final costVariance = _currentSpend - _totalBudget;

 return Container(
 padding: const EdgeInsets.all(24),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(20),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 boxShadow: [
 BoxShadow(
 color: Colors.black.withOpacity(0.04),
 blurRadius: 16,
 offset: const Offset(0, 8),
 ),
 ],
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 children: [
 Container(
 width: 36,
 height: 36,
 decoration: BoxDecoration(
 color: const Color(0xFFFEE2E2),
 borderRadius: BorderRadius.circular(10),
 ),
 child: const Icon(Icons.analytics_outlined,
 color: Color(0xFFEF4444), size: 20),
 ),
 const SizedBox(width: 12),
 const Text(
 'Variance Analysis',
 style: TextStyle(
 fontSize: 18,
 fontWeight: FontWeight.w700,
 color: Color(0xFF111827),
 ),
 ),
 ],
 ),
 const SizedBox(height: 24),
 LayoutBuilder(
 builder: (context, constraints) {
 final isWide = constraints.maxWidth > 600;
 return isWide
 ? Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Expanded(
 child:
 _buildScheduleVarianceCard(scheduleVariance)),
 const SizedBox(width: 24),
 Expanded(child: _buildCostVarianceCard(costVariance)),
 ],
 )
 : Column(
 children: [
 _buildScheduleVarianceCard(scheduleVariance),
 const SizedBox(height: 16),
 _buildCostVarianceCard(costVariance),
 ],
 );
 },
 ),
 ],
 ),
 );
 }

 Widget _buildScheduleVarianceCard(int varianceDays) {
 Color varianceColor;
 String varianceLabel;
 IconData varianceIcon;

 if (varianceDays == 0) {
 varianceColor = const Color(0xFF10B981);
 varianceLabel = 'On Track';
 varianceIcon = Icons.check_circle;
 } else if (varianceDays < 0) {
 varianceColor = const Color(0xFF10B981);
 varianceLabel = '${varianceDays.abs()} days ahead';
 varianceIcon = Icons.trending_up;
 } else {
 varianceColor = const Color(0xFFEF4444);
 varianceLabel = '$varianceDays days behind';
 varianceIcon = Icons.trending_down;
 }

 return Container(
 padding: const EdgeInsets.all(20),
 decoration: BoxDecoration(
 color: varianceColor.withOpacity(0.08),
 borderRadius: BorderRadius.circular(16),
 border: Border.all(color: varianceColor.withOpacity(0.2)),
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 children: [
 Icon(varianceIcon, color: varianceColor, size: 20),
 const SizedBox(width: 8),
 const Text(
 'Schedule Variance',
 style: TextStyle(
 fontSize: 14,
 fontWeight: FontWeight.w700,
 color: Color(0xFF111827),
 ),
 ),
 ],
 ),
 const SizedBox(height: 16),
 Text(
 varianceLabel,
 style: TextStyle(
 fontSize: 24,
 fontWeight: FontWeight.w800,
 color: varianceColor,
 ),
 ),
 const SizedBox(height: 8),
 Text(
 'Comparing baseline dates vs current dates',
 style: TextStyle(
 fontSize: 12,
 color: varianceColor.withOpacity(0.8),
 ),
 ),
 ],
 ),
 );
 }

 Widget _buildCostVarianceCard(double varianceAmount) {
 Color varianceColor;
 String varianceLabel;
 IconData varianceIcon;

 if (varianceAmount == 0) {
 varianceColor = const Color(0xFF10B981);
 varianceLabel = 'On Budget';
 varianceIcon = Icons.check_circle;
 } else if (varianceAmount < 0) {
 varianceColor = const Color(0xFF10B981);
 varianceLabel = '\$${_formatNumber(varianceAmount.abs())} under';
 varianceIcon = Icons.trending_up;
 } else {
 varianceColor = const Color(0xFFEF4444);
 varianceLabel = '\$${_formatNumber(varianceAmount)} over';
 varianceIcon = Icons.trending_down;
 }

 return Container(
 padding: const EdgeInsets.all(20),
 decoration: BoxDecoration(
 color: varianceColor.withOpacity(0.08),
 borderRadius: BorderRadius.circular(16),
 border: Border.all(color: varianceColor.withOpacity(0.2)),
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 children: [
 Icon(varianceIcon, color: varianceColor, size: 20),
 const SizedBox(width: 8),
 const Text(
 'Cost Variance',
 style: TextStyle(
 fontSize: 14,
 fontWeight: FontWeight.w700,
 color: Color(0xFF111827),
 ),
 ),
 ],
 ),
 const SizedBox(height: 16),
 Text(
 varianceLabel,
 style: TextStyle(
 fontSize: 24,
 fontWeight: FontWeight.w800,
 color: varianceColor,
 ),
 ),
 const SizedBox(height: 8),
 Text(
 'Comparing baseline budget vs current spend',
 style: TextStyle(
 fontSize: 12,
 color: varianceColor.withOpacity(0.8),
 ),
 ),
 ],
 ),
 );
 }

 int _calculateScheduleVarianceDays() {
 if (_baselineEndDate == null || _currentEndDate == null) return 0;
 return _currentEndDate!.difference(_baselineEndDate!).inDays;
 }

 Future<void> _exportPdf() async {
 final projectData = ProjectDataHelper.getData(context);
 await PdfExportHelper.exportScreenPdf(
 context: context,
 screenTitle: 'Project Baseline',
 sections: [
 PdfSection.keyValue('Project Info', [
 {'Project Name': projectData.projectName ?? 'N/A'},
 {'Solution Title': projectData.solutionTitle ?? 'N/A'},
 ]),
 PdfSection.text('Notes', projectData.planningNotes['planning_project_baseline_notes'] ?? 'No data recorded.'),
 ],
 );
 }
}

class _BaselineVersion {
 final String id;
 final String versionLabel;
 final DateTime createdAt;
 final String approvedBy;
 final String description;
 final String scheduleSummary;
 final String costSummary;
 final String scopeSummary;

 const _BaselineVersion({
 required this.id,
 required this.versionLabel,
 required this.createdAt,
 required this.approvedBy,
 required this.description,
 this.scheduleSummary = '',
 this.costSummary = '',
 this.scopeSummary = '',
 });

 factory _BaselineVersion.fromJson(Map<String, dynamic> json) {
 return _BaselineVersion(
 id: json['id'] ?? '',
 versionLabel: json['versionLabel'] ?? '',
 createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
 approvedBy: json['approvedBy'] ?? '',
 description: json['description'] ?? '',
 scheduleSummary: json['scheduleSummary'] ?? '',
 costSummary: json['costSummary'] ?? '',
 scopeSummary: json['scopeSummary'] ?? '',
 );
 }

 Map<String, dynamic> toJson() => {
 'id': id,
 'versionLabel': versionLabel,
 'createdAt': createdAt.toIso8601String(),
 'approvedBy': approvedBy,
 'description': description,
 'scheduleSummary': scheduleSummary,
 'costSummary': costSummary,
 'scopeSummary': scopeSummary,
 };
}

class _ScheduleMilestone {
 final String name;
 final DateTime? targetDate;
 final DateTime? baselineDate;
 final String discipline;
 final String status;

 const _ScheduleMilestone({
 required this.name,
 this.targetDate,
 this.baselineDate,
 this.discipline = '',
 this.status = 'Planned',
 });
}

class _SchedulePhase {
 DateTime? baselineStart;
 DateTime? baselineEnd;
 DateTime? currentStart;
 DateTime? currentEnd;
 final String name;
 final int taskCount;
 final int completedCount;

 _SchedulePhase({
 this.baselineStart,
 this.baselineEnd,
 this.currentStart,
 this.currentEnd,
 required this.name,
 required this.taskCount,
 required this.completedCount,
 });
}

class _CostItem {
 final String category;
 final double estimated;
 final double actual;

 const _CostItem({
 required this.category,
 required this.estimated,
 this.actual = 0,
 });
}

class _ScopeItem {
 final String description;
 final bool isInScope;

 const _ScopeItem({
 required this.description,
 required this.isInScope,
 });
}
