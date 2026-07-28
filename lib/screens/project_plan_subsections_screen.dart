import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:ndu_project/widgets/draggable_sidebar.dart';
import 'package:ndu_project/widgets/initiation_like_sidebar.dart';
import 'package:ndu_project/widgets/responsive.dart';
import 'package:ndu_project/widgets/kaz_ai_chat_bubble.dart';
import 'package:ndu_project/widgets/planning_ai_notes_card.dart';
import 'package:ndu_project/services/firebase_auth_service.dart';
import 'package:ndu_project/services/user_service.dart';
import 'package:ndu_project/services/openai_service_secure.dart';
import 'package:ndu_project/widgets/launch_phase_navigation.dart';
import 'package:ndu_project/utils/planning_phase_navigation.dart';
import 'package:ndu_project/utils/project_data_helper.dart';
import 'package:ndu_project/utils/text_sanitizer.dart';
import 'package:ndu_project/models/project_data_model.dart';

import 'package:ndu_project/widgets/voice_text_field.dart';
import 'package:ndu_project/widgets/planning_phase_header.dart';
import 'package:ndu_project/utils/pdf_export_helper.dart';

class ProjectPlanLevel1ScheduleScreen extends StatefulWidget {
 const ProjectPlanLevel1ScheduleScreen({super.key});

 static void open(BuildContext context) {
 Navigator.of(context).push(
 MaterialPageRoute(
 builder: (_) => const ProjectPlanLevel1ScheduleScreen()),
 );
 }

 @override
 State<ProjectPlanLevel1ScheduleScreen> createState() =>
 _Level1ScheduleScreenState();
}

class _Level1ScheduleScreenState
 extends State<ProjectPlanLevel1ScheduleScreen> {
 List<_L1Phase> _phases = [];
 List<_L1Milestone> _milestones = [];
 DateTime? _projectStart;
 DateTime? _projectEnd;
 DateTime? _baselineDate;
 String _methodology = 'Waterfall';
 bool _hasBaseline = false;
 List<_L1Phase> _baselinePhases = [];

 @override
 void initState() {
 super.initState();
 WidgetsBinding.instance.addPostFrameCallback((_) {
 _loadData();
 });
 }

 void _loadData() {
 final data = ProjectDataHelper.getData(context);

 _projectStart = _parseDate(data.frontEndPlanning.milestoneStartDate);
 _projectEnd = _parseDate(data.frontEndPlanning.milestoneEndDate);

 _methodology = data.planningNotes['planning_schedule_methodology']
 ?.trim()
 .isNotEmpty ==
 true
 ? data.planningNotes['planning_schedule_methodology']!
 : 'Waterfall';

 _hasBaseline = data.scheduleBaselineDate.trim().isNotEmpty;
 _baselineDate =
 _hasBaseline ? DateTime.tryParse(data.scheduleBaselineDate) : null;

 _phases = _derivePhases(data);
 _baselinePhases = _hasBaseline
 ? _derivePhasesFromActivities(
 data.scheduleBaselineActivities, data.wbsTree)
 : <_L1Phase>[];

 _milestones = data.keyMilestones
 .where((m) => m.name.trim().isNotEmpty)
 .map((m) => _L1Milestone(
 name: m.name.trim(),
 targetDate: _parseDate(m.dueDate),
 discipline: m.discipline.trim(),
 comments: m.comments.trim(),
 ))
 .toList();

 if (mounted) setState(() {});
 }

 List<_L1Phase> _derivePhases(ProjectDataModel data) {
 if (data.wbsTree.isEmpty) {
 return _buildFallbackPhases(data);
 }
 return _derivePhasesFromActivities(data.scheduleActivities, data.wbsTree);
 }

 List<_L1Phase> _derivePhasesFromActivities(
 List<ScheduleActivity> activities, List<WorkItem> wbsTree) {
 final wbsChildIds = <String, Set<String>>{};
 void collectDescendants(WorkItem node, Set<String> bucket) {
 bucket.add(node.id);
 if (node.title.trim().isNotEmpty) {
 final normalized = node.title.trim().toLowerCase();
 bucket.add(normalized);
 }
 for (final child in node.children) {
 collectDescendants(child, bucket);
 }
 }

 for (final root in wbsTree) {
 final ids = <String>{};
 collectDescendants(root, ids);
 wbsChildIds[root.id] = ids;
 }

 final phases = <_L1Phase>[];
 final usedActivities = <String>{};

 for (final root in wbsTree) {
 final title = root.title.trim().isEmpty
 ? 'Phase ${phases.length + 1}'
 : root.title.trim();
 final childIds = wbsChildIds[root.id] ?? <String>{};

 final matched = activities.where((a) {
 if (usedActivities.contains(a.id)) return false;
 if (childIds.contains(a.wbsId)) return true;
 if (childIds.contains(a.wbsId.toLowerCase())) return true;
 final actTitle = a.title.trim().toLowerCase();
 if (childIds.contains(actTitle)) return true;
 return false;
 }).toList();

 for (final a in matched) {
 usedActivities.add(a.id);
 }

 if (matched.isEmpty) {
 final fallbackStart = _projectStart ?? DateTime.now();
 final fallbackEnd =
 _projectEnd ?? fallbackStart.add(const Duration(days: 90));
 final totalDays = fallbackEnd.difference(fallbackStart).inDays;
 final phaseDuration = wbsTree.length > 1
 ? (totalDays / wbsTree.length).round()
 : totalDays;
 final offset = phases.length * phaseDuration;

 phases.add(_L1Phase(
 name: title,
 startDate: fallbackStart.add(Duration(days: offset)),
 endDate: fallbackStart.add(Duration(days: offset + phaseDuration)),
 progress: 0,
 activityCount: 0,
 status: 'Planned',
 ));
 } else {
 DateTime? minStart;
 DateTime? maxEnd;
 double totalProgress = 0;
 int completedCount = 0;

 for (final a in matched) {
 final start = _parseDate(a.startDate);
 final end = _parseDate(a.dueDate);
 if (start != null && (minStart == null || start.isBefore(minStart))) {
 minStart = start;
 }
 if (end != null && (maxEnd == null || end.isAfter(maxEnd))) {
 maxEnd = end;
 }
 totalProgress += a.progress;
 if (a.status.toLowerCase() == 'completed') completedCount++;
 }

 phases.add(_L1Phase(
 name: title,
 startDate: minStart ?? _projectStart ?? DateTime.now(),
 endDate: maxEnd ?? _projectEnd ?? DateTime.now(),
 progress: matched.isNotEmpty ? totalProgress / matched.length : 0,
 activityCount: matched.length,
 status: completedCount == matched.length && matched.isNotEmpty
 ? 'Complete'
 : matched.any((a) => a.status.toLowerCase() == 'in_progress')
 ? 'In Progress'
 : 'Planned',
 ));
 }
 }

 final orphanActivities =
 activities.where((a) => !usedActivities.contains(a.id)).toList();
 if (orphanActivities.isNotEmpty) {
 DateTime? minStart;
 DateTime? maxEnd;
 double totalProgress = 0;
 int completedCount = 0;

 for (final a in orphanActivities) {
 final start = _parseDate(a.startDate);
 final end = _parseDate(a.dueDate);
 if (start != null && (minStart == null || start.isBefore(minStart))) {
 minStart = start;
 }
 if (end != null && (maxEnd == null || end.isAfter(maxEnd))) {
 maxEnd = end;
 }
 totalProgress += a.progress;
 if (a.status.toLowerCase() == 'completed') completedCount++;
 }

 phases.add(_L1Phase(
 name: 'Other Activities',
 startDate: minStart ?? _projectStart ?? DateTime.now(),
 endDate: maxEnd ?? _projectEnd ?? DateTime.now(),
 progress: totalProgress / orphanActivities.length,
 activityCount: orphanActivities.length,
 status: completedCount == orphanActivities.length
 ? 'Complete'
 : orphanActivities
 .any((a) => a.status.toLowerCase() == 'in_progress')
 ? 'In Progress'
 : 'Planned',
 ));
 }

 return phases;
 }

 List<_L1Phase> _buildFallbackPhases(ProjectDataModel data) {
 final start = _projectStart ?? DateTime.now();
 final end = _projectEnd ?? start.add(const Duration(days: 365));
 final totalDays = end.difference(start).inDays;

 const phaseNames = ['Initiation', 'Planning', 'Execution', 'Launch'];
 const phasePercents = [0.1, 0.3, 0.45, 0.15];

 var offset = 0;
 final phases = <_L1Phase>[];
 for (int i = 0; i < phaseNames.length; i++) {
 final duration = (totalDays * phasePercents[i]).round();
 phases.add(_L1Phase(
 name: phaseNames[i],
 startDate: start.add(Duration(days: offset)),
 endDate: start.add(Duration(days: offset + duration)),
 progress: 0,
 activityCount: 0,
 status: 'Planned',
 ));
 offset += duration;
 }
 return phases;
 }

 int get _totalDurationDays {
 if (_projectStart == null || _projectEnd == null) {
 if (_phases.isEmpty) return 0;
 final minStart = _phases
 .map((p) => p.startDate)
 .reduce((a, b) => a.isBefore(b) ? a : b);
 final maxEnd =
 _phases.map((p) => p.endDate).reduce((a, b) => a.isAfter(b) ? a : b);
 return maxEnd.difference(minStart).inDays;
 }
 return _projectEnd!.difference(_projectStart!).inDays;
 }

 String get _scheduleHealth {
 if (_phases.isEmpty) return 'No Data';
 final avgProgress =
 _phases.fold<double>(0, (sum, p) => sum + p.progress) / _phases.length;
 if (avgProgress >= 0.8) return 'On Track';
 if (avgProgress >= 0.5) return 'At Risk';
 return 'Behind';
 }

 Color get _healthColor {
 final health = _scheduleHealth;
 if (health == 'On Track') return const Color(0xFF10B981);
 if (health == 'At Risk') return const Color(0xFFF59E0B);
 if (health == 'Behind') return const Color(0xFFEF4444);
 return const Color(0xFF6B7280);
 }

 @override
 Widget build(BuildContext context) {
 final isMobile = AppBreakpoints.isMobile(context);
 final horizontalPadding = isMobile ? 20.0 : 32.0;

 return Scaffold(
 backgroundColor: Colors.white,
 body: SafeArea(
 child: Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 DraggableSidebar(
 openWidth: AppBreakpoints.sidebarWidth(context),
 child: const InitiationLikeSidebar(
 activeItemLabel: 'Project Plan - Level 1 - Project Schedule'),
 ),
 Expanded(
 child: Stack(
 children: [
 MobileSidebarHamburger(
 sidebar: const InitiationLikeSidebar(
 activeItemLabel: 'Project Plan - Level 1 - Project Schedule',
 ),
 ),
 SingleChildScrollView(
 padding: EdgeInsets.symmetric(
 horizontal: horizontalPadding, vertical: 24),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 PlanningPhaseHeader(title: 'Project Schedule', onExportPdf: _exportPdf),
 const SizedBox(height: 16),
 _TopHeader(
 title: 'Level 1 - Project Schedule',
 onBack: () => PlanningPhaseNavigation.goToPrevious(
 context, 'project_plan_level1_schedule'),
 onForward: () => PlanningPhaseNavigation.goToNext(
 context, 'project_plan_level1_schedule'),
 ),
 const SizedBox(height: 12),
 Text(
 'Map major phases, milestone timing, and governance checkpoints.',
 style: const TextStyle(
 fontSize: 14, color: Color(0xFF6B7280)),
 ),
 const SizedBox(height: 20),
 PlanningAiNotesCard(
 title: 'Notes',
 sectionLabel: 'Level 1 - Project Schedule',
 noteKey: 'planning_project_plan_level1_notes',
 checkpoint: 'project_plan_level1_schedule',
 description:
 'Capture plan assumptions, deadlines, and key constraints.',
 ),
 const SizedBox(height: 24),
 _buildMetricsRow(),
 const SizedBox(height: 24),
 _buildGanttTimeline(),
 const SizedBox(height: 24),
 _buildPhaseSummaryTable(),
 const SizedBox(height: 24),
 _buildMilestonesSection(),
 const SizedBox(height: 24),
 LaunchPhaseNavigation(
 backLabel: PlanningPhaseNavigation.backLabel(
 'project_plan_level1_schedule'),
 nextLabel: PlanningPhaseNavigation.nextLabel(
 'project_plan_level1_schedule'),
 onBack: () => PlanningPhaseNavigation.goToPrevious(
 context, 'project_plan_level1_schedule'),
 onNext: () => PlanningPhaseNavigation.goToNext(
 context, 'project_plan_level1_schedule'),
 ),
 const SizedBox(height: 80),
 ],
 ),
 ),
 const Positioned(
 right: 24,
 bottom: 24,
 child: KazAiChatBubble(positioned: false)),
 ],
 ),
 ),
 ],
 ),
 ),
 );
 }

 Widget _buildMetricsRow() {
 return Wrap(
 spacing: 16,
 runSpacing: 16,
 children: [
 _MetricCard(
 label: 'Total Duration',
 value: _totalDurationDays > 0 ? '$_totalDurationDays days' : '--',
 accent: const Color(0xFF3B82F6),
 icon: Icons.schedule_outlined,
 ),
 _MetricCard(
 label: 'Phases',
 value: '${_phases.length}',
 accent: const Color(0xFF8B5CF6),
 icon: Icons.layers_outlined,
 ),
 _MetricCard(
 label: 'Milestones',
 value: '${_milestones.length}',
 accent: const Color(0xFFF59E0B),
 icon: Icons.flag_outlined,
 ),
 _MetricCard(
 label: 'Schedule Health',
 value: _scheduleHealth,
 accent: _healthColor,
 icon: Icons.assessment_outlined,
 ),
 ],
 );
 }

 Widget _buildGanttTimeline() {
 return Container(
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(16),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 ),
 padding: const EdgeInsets.all(20),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 children: [
 const Text(
 'Phase Timeline',
 style: TextStyle(
 fontSize: 16,
 fontWeight: FontWeight.w700,
 color: Color(0xFF111827),
 ),
 ),
 const SizedBox(width: 12),
 Container(
 padding:
 const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
 decoration: BoxDecoration(
 color: const Color(0xFFF3F4F6),
 borderRadius: BorderRadius.circular(999),
 ),
 child: Text(
 _methodology,
 style: const TextStyle(
 fontSize: 11,
 fontWeight: FontWeight.w600,
 color: Color(0xFF374151),
 ),
 ),
 ),
 if (_hasBaseline && _baselineDate != null) ...[
 const SizedBox(width: 8),
 Container(
 padding:
 const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
 decoration: BoxDecoration(
 color: const Color(0xFFFEE2E2),
 borderRadius: BorderRadius.circular(999),
 ),
 child: Text(
 'Baseline: ${_formatDate(_baselineDate!)}',
 style: const TextStyle(
 fontSize: 11,
 fontWeight: FontWeight.w600,
 color: Color(0xFF991B1B),
 ),
 ),
 ),
 ],
 const Spacer(),
 if (_projectStart != null)
 Text(
 '${_formatDate(_projectStart!)} → ${_projectEnd != null ? _formatDate(_projectEnd!) : '—'}',
 style:
 const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
 ),
 ],
 ),
 const SizedBox(height: 16),
 _L1GanttChart(
 phases: _phases,
 baselinePhases: _baselinePhases,
 milestones: _milestones,
 projectStart: _projectStart,
 projectEnd: _projectEnd,
 ),
 ],
 ),
 );
 }

 Widget _buildPhaseSummaryTable() {
 if (_phases.isEmpty) {
 return const _SectionEmptyState(
 title: 'No phases defined yet',
 message: 'Create WBS items to see phase-level schedule breakdown.',
 icon: Icons.layers_outlined,
 );
 }

 return Container(
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(16),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Padding(
 padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
 child: Row(
 children: [
 const Icon(Icons.table_chart_outlined,
 size: 18, color: Color(0xFF6B7280)),
 const SizedBox(width: 8),
 const Text(
 'Phase Summary',
 style: TextStyle(
 fontSize: 16,
 fontWeight: FontWeight.w700,
 color: Color(0xFF111827),
 ),
 ),
 ],
 ),
 ),
 const SizedBox(height: 12),
 _buildPhaseTable(),
 ],
 ),
 );
 }

 Widget _buildPhaseTable() {
 const border = BorderSide(color: Color(0xFFE5E7EB));
 const headerStyle = TextStyle(
 fontSize: 12,
 fontWeight: FontWeight.w700,
 color: Color(0xFF6B7280),
 );

 return LayoutBuilder(
 builder: (context, constraints) {
 return SingleChildScrollView(
 scrollDirection: Axis.horizontal,
 child: SizedBox(
 width: constraints.maxWidth > 1080 ? constraints.maxWidth : 1080,
 child: Table(
 defaultVerticalAlignment: TableCellVerticalAlignment.middle,
 columnWidths: const {
 0: FixedColumnWidth(56),
 1: FixedColumnWidth(250),
 2: FixedColumnWidth(145),
 3: FixedColumnWidth(145),
 4: FixedColumnWidth(110),
 5: FixedColumnWidth(150),
 6: FixedColumnWidth(100),
 7: FixedColumnWidth(124),
 },
 border: const TableBorder(
 horizontalInside: border,
 verticalInside: border,
 ),
 children: [
 TableRow(
 decoration: const BoxDecoration(color: Color(0xFFF8FAFC)),
 children: [
 _headerCell('#', headerStyle),
 _headerCell('Phase', headerStyle),
 _headerCell('Start', headerStyle),
 _headerCell('End', headerStyle),
 _headerCell('Duration', headerStyle),
 _headerCell('Progress', headerStyle),
 _headerCell('Tasks', headerStyle),
 _headerCell('Status', headerStyle),
 ],
 ),
 ...List.generate(_phases.length, (index) {
 final phase = _phases[index];
 final duration =
 phase.endDate.difference(phase.startDate).inDays;
 final progressPct = (phase.progress * 100).round();
 final statusColor = _statusColor(phase.status);

 return TableRow(
 decoration: BoxDecoration(
 color:
 index.isEven ? Colors.white : const Color(0xFFFAFAFA),
 ),
 children: [
 _dataCell(Center(
 child: Text('${index + 1}',
 style: const TextStyle(
 fontSize: 12,
 fontWeight: FontWeight.w700,
 color: Color(0xFF4B5563))),
 )),
 _dataCell(_tableTextCell(phase.name,
 fontWeight: FontWeight.w600)),
 _dataCell(_tableTextCell(_formatDate(phase.startDate),
 textAlign: TextAlign.center)),
 _dataCell(_tableTextCell(_formatDate(phase.endDate),
 textAlign: TextAlign.center)),
 _dataCell(_tableTextCell('${duration}d',
 textAlign: TextAlign.center)),
 _dataCell(Padding(
 padding: const EdgeInsets.symmetric(
 horizontal: 12, vertical: 10),
 child: Row(
 children: [
 Expanded(
 child: ClipRRect(
 borderRadius: BorderRadius.circular(4),
 child: LinearProgressIndicator(
 value: phase.progress.clamp(0, 1),
 backgroundColor: const Color(0xFFE5E7EB),
 valueColor: AlwaysStoppedAnimation<Color>(
 progressPct >= 80
 ? const Color(0xFF10B981)
 : progressPct >= 50
 ? const Color(0xFFF59E0B)
 : const Color(0xFF3B82F6),
 ),
 ),
 ),
 ),
 const SizedBox(width: 8),
 Text('$progressPct%',
 style: const TextStyle(
 fontSize: 12,
 fontWeight: FontWeight.w600,
 color: Color(0xFF374151))),
 ],
 ),
 )),
 _dataCell(Center(
 child: Text('${phase.activityCount}',
 style: const TextStyle(
 fontSize: 12,
 fontWeight: FontWeight.w600,
 color: Color(0xFF374151))),
 )),
 _dataCell(Center(
 child: Container(
 padding: const EdgeInsets.symmetric(
 horizontal: 10, vertical: 4),
 decoration: BoxDecoration(
 color: statusColor.withOpacity(0.12),
 borderRadius: BorderRadius.circular(999),
 ),
 child: Text(
 phase.status,
 style: TextStyle(
 fontSize: 11,
 fontWeight: FontWeight.w700,
 color: statusColor,
 ),
 ),
 ),
 )),
 ],
 );
 }),
 ],
 ),
 ),
 );
 },
 );
 }

 Widget _buildMilestonesSection() {
 return Container(
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(16),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Padding(
 padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
 child: Row(
 children: [
 const Icon(Icons.flag_outlined,
 size: 18, color: Color(0xFFF59E0B)),
 const SizedBox(width: 8),
 const Text(
 'Key Milestones',
 style: TextStyle(
 fontSize: 16,
 fontWeight: FontWeight.w700,
 color: Color(0xFF111827),
 ),
 ),
 const Spacer(),
 Text(
 '${_milestones.length} milestones',
 style:
 const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
 ),
 ],
 ),
 ),
 const SizedBox(height: 12),
 _milestones.isEmpty
 ? Padding(
 padding: const EdgeInsets.all(24),
 child: Text(
 'No milestones defined. Add milestones in the FEP Milestone screen to see them here.',
 style: TextStyle(
 fontSize: 13,
 color: Colors.grey[500],
 fontStyle: FontStyle.italic),
 ),
 )
 : _buildMilestonesTable(),
 ],
 ),
 );
 }

 Widget _buildMilestonesTable() {
 const border = BorderSide(color: Color(0xFFE5E7EB));
 const headerStyle = TextStyle(
 fontSize: 12,
 fontWeight: FontWeight.w700,
 color: Color(0xFF6B7280),
 );

 return LayoutBuilder(
 builder: (context, constraints) {
 return SingleChildScrollView(
 scrollDirection: Axis.horizontal,
 child: SizedBox(
 width: constraints.maxWidth > 980 ? constraints.maxWidth : 980,
 child: Table(
 defaultVerticalAlignment: TableCellVerticalAlignment.middle,
 columnWidths: const {
 0: FixedColumnWidth(56),
 1: FixedColumnWidth(280),
 2: FixedColumnWidth(150),
 3: FixedColumnWidth(170),
 4: FlexColumnWidth(1.4),
 },
 border: const TableBorder(
 horizontalInside: border,
 verticalInside: border,
 ),
 children: [
 TableRow(
 decoration: const BoxDecoration(color: Color(0xFFF8FAFC)),
 children: [
 _headerCell('#', headerStyle),
 _headerCell('Milestone', headerStyle),
 _headerCell('Target Date', headerStyle),
 _headerCell('Discipline', headerStyle),
 _headerCell('Notes', headerStyle),
 ],
 ),
 ...List.generate(_milestones.length, (index) {
 final m = _milestones[index];
 return TableRow(
 decoration: BoxDecoration(
 color:
 index.isEven ? Colors.white : const Color(0xFFFAFAFA),
 ),
 children: [
 _dataCell(Center(
 child: Text('${index + 1}',
 style: const TextStyle(
 fontSize: 12,
 fontWeight: FontWeight.w700,
 color: Color(0xFF4B5563))),
 )),
 _dataCell(
 _tableTextCell(m.name, fontWeight: FontWeight.w600)),
 _dataCell(_tableTextCell(
 m.targetDate != null ? _formatDate(m.targetDate!) : '—',
 textAlign: TextAlign.center,
 )),
 _dataCell(Padding(
 padding: const EdgeInsets.symmetric(
 horizontal: 12, vertical: 10),
 child: Container(
 padding: const EdgeInsets.symmetric(
 horizontal: 8, vertical: 4),
 decoration: BoxDecoration(
 color: const Color(0xFFEFF6FF),
 borderRadius: BorderRadius.circular(999),
 ),
 child: Text(
 m.discipline.isEmpty ? 'General' : m.discipline,
 style: const TextStyle(
 fontSize: 11,
 fontWeight: FontWeight.w600,
 color: Color(0xFF1D4ED8),
 ),
 ),
 ),
 )),
 _dataCell(Padding(
 padding: const EdgeInsets.symmetric(
 horizontal: 12, vertical: 10),
 child: Text(
 m.comments.isEmpty ? '—' : m.comments,
 style: const TextStyle(
 fontSize: 12,
 color: Color(0xFF6B7280),
 height: 1.3),
 softWrap: true,
 ),
 )),
 ],
 );
 }),
 ],
 ),
 ),
 );
 },
 );
 }

 Widget _headerCell(String text, TextStyle style) {
 return Padding(
 padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
 child: Text(text, style: style, textAlign: TextAlign.center),
 );
 }

 Widget _dataCell(Widget child) {
 return Padding(
 padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
 child: child,
 );
 }

 Widget _tableTextCell(
 String text, {
 FontWeight fontWeight = FontWeight.w500,
 TextAlign textAlign = TextAlign.left,
 }) {
 return Padding(
 padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
 child: Text(
 text,
 textAlign: textAlign,
 softWrap: true,
 style: TextStyle(
 fontSize: 12.5,
 height: 1.35,
 fontWeight: fontWeight,
 color: const Color(0xFF111827),
 ),
 ),
 );
 }

 Color _statusColor(String status) {
 final s = status.toLowerCase();
 if (s.contains('complete')) return const Color(0xFF10B981);
 if (s.contains('progress')) return const Color(0xFF3B82F6);
 if (s.contains('risk') || s.contains('behind')) {
 return const Color(0xFFEF4444);
 }
 return const Color(0xFF6B7280);
 }

 DateTime? _parseDate(String raw) {
 final value = raw.trim();
 if (value.isEmpty) return null;
 final parsed = DateTime.tryParse(value);
 if (parsed != null) return parsed;
 final parts = value.split(RegExp(r'[\s,]+'));
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

 String _formatDate(DateTime date) {
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

 Future<void> _exportPdf() async {
 final projectData = ProjectDataHelper.getData(context);
 await PdfExportHelper.exportScreenPdf(
 context: context,
 screenTitle: 'Project Plan Subsections',
 sections: [
 PdfSection.keyValue('Project Info', [
 {'Project Name': projectData.projectName ?? 'N/A'},
 {'Solution Title': projectData.solutionTitle ?? 'N/A'},
 ]),
 PdfSection.text('Notes', projectData.planningNotes['planning_project_plan_subsections_notes'] ?? 'No data recorded.'),
 ],
 );
 }
}

class _L1Phase {
 const _L1Phase({
 required this.name,
 required this.startDate,
 required this.endDate,
 required this.progress,
 required this.activityCount,
 required this.status,
 });

 final String name;
 final DateTime startDate;
 final DateTime endDate;
 final double progress;
 final int activityCount;
 final String status;
}

class _L1Milestone {
 const _L1Milestone({
 required this.name,
 required this.targetDate,
 required this.discipline,
 required this.comments,
 });

 final String name;
 final DateTime? targetDate;
 final String discipline;
 final String comments;
}

class _L1GanttChart extends StatelessWidget {
 const _L1GanttChart({
 required this.phases,
 required this.baselinePhases,
 required this.milestones,
 required this.projectStart,
 required this.projectEnd,
 });

 final List<_L1Phase> phases;
 final List<_L1Phase> baselinePhases;
 final List<_L1Milestone> milestones;
 final DateTime? projectStart;
 final DateTime? projectEnd;

 static const double _leftColumnWidth = 180;
 static const double _rowHeight = 48;
 static const double _milestoneRowHeight = 32;

 @override
 Widget build(BuildContext context) {
 if (phases.isEmpty && milestones.isEmpty) {
 return Container(
 padding: const EdgeInsets.all(24),
 decoration: BoxDecoration(
 color: const Color(0xFFF9FAFB),
 borderRadius: BorderRadius.circular(12),
 ),
 child: const Center(
 child: Column(
 children: [
 Icon(Icons.timeline_outlined, size: 40, color: Color(0xFF9CA3AF)),
 SizedBox(height: 12),
 Text(
 'No timeline data yet. Add WBS items and milestones to populate.',
 style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
 ),
 ],
 ),
 ),
 );
 }

 DateTime start;
 DateTime end;

 if (projectStart != null && projectEnd != null) {
 start = projectStart!;
 end = projectEnd!;
 } else if (phases.isNotEmpty) {
 start = phases.first.startDate;
 end = phases.last.endDate;
 for (final p in phases) {
 if (p.startDate.isBefore(start)) start = p.startDate;
 if (p.endDate.isAfter(end)) end = p.endDate;
 }
 } else {
 start = DateTime.now();
 end = start.add(const Duration(days: 90));
 }

 for (final m in milestones) {
 if (m.targetDate != null) {
 if (m.targetDate!.isBefore(start)) start = m.targetDate!;
 if (m.targetDate!.isAfter(end)) end = m.targetDate!;
 }
 }

 final buffer = (end.difference(start).inDays * 0.03).round().clamp(3, 14);
 start = start.subtract(Duration(days: buffer));
 end = end.add(Duration(days: buffer));

 final totalDays = end.difference(start).inDays + 1;
 final timelineWidth = (totalDays * 3.0).clamp(600.0, 2400.0);
 final pxPerDay = timelineWidth / totalDays;
 final totalRows = phases.length + (milestones.isNotEmpty ? 1 : 0);
 final chartHeight = totalRows * _rowHeight + 20;
 final totalChartWidth = _leftColumnWidth + timelineWidth + 2;
 final monthSegments = _generateMonthSegments(start, end);

 return SingleChildScrollView(
 scrollDirection: Axis.horizontal,
 child: Container(
 width: totalChartWidth,
 decoration: BoxDecoration(
 color: const Color(0xFFF9FAFB),
 borderRadius: BorderRadius.circular(12),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 ),
 child: Column(
 children: [
 Container(
 padding: const EdgeInsets.symmetric(vertical: 10),
 decoration: const BoxDecoration(
 border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
 ),
 child: Row(
 children: [
 const SizedBox(
 width: _leftColumnWidth,
 child: Padding(
 padding: EdgeInsets.symmetric(horizontal: 12),
 child: Text(
 'Phase',
 style: TextStyle(
 fontSize: 12,
 fontWeight: FontWeight.w700,
 color: Color(0xFF6B7280),
 ),
 ),
 ),
 ),
 SizedBox(
 width: timelineWidth,
 height: 18,
 child: Row(
 children: monthSegments.map((segment) {
 final segmentWidth = segment.dayCount * pxPerDay;
 return SizedBox(
 width: segmentWidth,
 child: Padding(
 padding: const EdgeInsets.symmetric(horizontal: 6),
 child: Align(
 alignment: Alignment.centerLeft,
 child: Text(
 segment.label,
 style: const TextStyle(
 fontSize: 11,
 fontWeight: FontWeight.w700,
 color: Color(0xFF374151),
 ),
 ),
 ),
 ),
 );
 }).toList(),
 ),
 ),
 ],
 ),
 ),
 SizedBox(
 height: chartHeight,
 child: Stack(
 children: [
 Positioned.fill(
 child: CustomPaint(
 painter: _L1GridPainter(
 leftColumnWidth: _leftColumnWidth,
 rowHeight: _rowHeight,
 rowCount: totalRows,
 monthSegments: monthSegments,
 pxPerDay: pxPerDay,
 ),
 ),
 ),
 ...List.generate(phases.length, (index) {
 final phase = phases[index];
 final top = index * _rowHeight + 4;
 final startOffset =
 phase.startDate.difference(start).inDays;
 final duration =
 phase.endDate.difference(phase.startDate).inDays + 1;
 final left = _leftColumnWidth + startOffset * pxPerDay;
 final width = (duration * pxPerDay).clamp(24.0, 800.0);

 _L1Phase? baselinePhase;
 if (baselinePhases.isNotEmpty) {
 for (final bp in baselinePhases) {
 if (bp.name == phase.name ||
 bp.name.toLowerCase() == phase.name.toLowerCase()) {
 baselinePhase = bp;
 break;
 }
 }
 }

 return Positioned(
 left: 0,
 right: 0,
 top: top,
 height: _rowHeight - 6,
 child: Row(
 children: [
 SizedBox(
 width: _leftColumnWidth,
 child: Padding(
 padding:
 const EdgeInsets.symmetric(horizontal: 12),
 child: Text(
 phase.name,
 maxLines: 1,
 overflow: TextOverflow.ellipsis,
 style: const TextStyle(
 fontSize: 12,
 fontWeight: FontWeight.w600,
 color: Color(0xFF111827),
 ),
 ),
 ),
 ),
 Expanded(
 child: Stack(
 clipBehavior: Clip.none,
 children: [
 if (baselinePhase != null) ...[
 Positioned(
 left: baselinePhase.startDate
 .difference(start)
 .inDays *
 pxPerDay,
 top: 10,
 child: Container(
 height: _rowHeight - 26,
 width: (baselinePhase.endDate
 .difference(
 baselinePhase.startDate)
 .inDays +
 1) *
 pxPerDay,
 decoration: BoxDecoration(
 color: const Color(0xFFE5E7EB)
 .withOpacity(0.6),
 borderRadius: BorderRadius.circular(6),
 border: Border.all(
 color: const Color(0xFFD1D5DB),
 width: 1,
 style: BorderStyle.solid,
 ),
 ),
 ),
 ),
 ],
 Positioned(
 left: left - _leftColumnWidth,
 top: 4,
 child: Container(
 height: _rowHeight - 16,
 width: width,
 decoration: BoxDecoration(
 borderRadius: BorderRadius.circular(8),
 ),
 child: ClipRRect(
 borderRadius: BorderRadius.circular(8),
 child: Stack(
 children: [
 Container(
 decoration: BoxDecoration(
 color: _phaseColor(index),
 ),
 ),
 if (phase.progress > 0)
 Align(
 alignment: Alignment.centerLeft,
 child: FractionallySizedBox(
 widthFactor:
 phase.progress.clamp(0, 1),
 child: Container(
 decoration: BoxDecoration(
 color: _phaseColor(index)
 .withOpacity(0.85),
 ),
 ),
 ),
 ),
 Center(
 child: Text(
 '${(phase.progress * 100).round()}%',
 style: const TextStyle(
 fontSize: 10,
 fontWeight: FontWeight.w700,
 color: Colors.white,
 ),
 ),
 ),
 ],
 ),
 ),
 ),
 ),
 ],
 ),
 ),
 ],
 ),
 );
 }),
 if (milestones.isNotEmpty)
 ..._buildMilestoneMarkers(start, pxPerDay, phases.length),
 ],
 ),
 ),
 if (_hasBaselinePhases())
 Padding(
 padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
 child: Row(
 children: [
 Container(
 width: 20,
 height: 10,
 decoration: BoxDecoration(
 color: const Color(0xFFE5E7EB).withOpacity(0.6),
 borderRadius: BorderRadius.circular(3),
 border: Border.all(color: const Color(0xFFD1D5DB)),
 ),
 ),
 const SizedBox(width: 6),
 const Text(
 'Baseline',
 style: TextStyle(fontSize: 10, color: Color(0xFF6B7280)),
 ),
 const SizedBox(width: 16),
 Container(
 width: 20,
 height: 10,
 decoration: BoxDecoration(
 color: const Color(0xFF3B82F6),
 borderRadius: BorderRadius.circular(3),
 ),
 ),
 const SizedBox(width: 6),
 const Text(
 'Current',
 style: TextStyle(fontSize: 10, color: Color(0xFF6B7280)),
 ),
 const SizedBox(width: 16),
 const Icon(Icons.diamond,
 size: 12, color: Color(0xFFF59E0B)),
 const SizedBox(width: 4),
 const Text(
 'Milestone',
 style: TextStyle(fontSize: 10, color: Color(0xFF6B7280)),
 ),
 ],
 ),
 ),
 ],
 ),
 ),
 );
 }

 bool _hasBaselinePhases() => baselinePhases.isNotEmpty;

 List<Widget> _buildMilestoneMarkers(
 DateTime start, double pxPerDay, int phaseCount) {
 final topOffset = phaseCount * _rowHeight + 4;

 return [
 Positioned(
 left: 0,
 right: 0,
 top: topOffset,
 height: _milestoneRowHeight,
 child: Row(
 children: [
 SizedBox(
 width: _leftColumnWidth,
 child: Padding(
 padding: const EdgeInsets.symmetric(horizontal: 12),
 child: Text(
 'Milestones',
 style: TextStyle(
 fontSize: 11,
 fontWeight: FontWeight.w600,
 color: Colors.grey[600],
 ),
 ),
 ),
 ),
 Expanded(
 child: Stack(
 children: milestones.map((m) {
 if (m.targetDate == null) return const SizedBox.shrink();
 final offset =
 m.targetDate!.difference(start).inDays * pxPerDay;
 return Positioned(
 left: offset - 6,
 top: 6,
 child: Tooltip(
 message:
 '${m.name}${m.targetDate != null ? ' — ${_fmtDate(m.targetDate!)}' : ''}',
 child: CustomPaint(
 size: const Size(12, 12),
 painter: _DiamondPainter(
 color: const Color(0xFFF59E0B),
 ),
 ),
 ),
 );
 }).toList(),
 ),
 ),
 ],
 ),
 ),
 ];
 }

 Color _phaseColor(int index) {
 const colors = [
 Color(0xFF3B82F6),
 Color(0xFF8B5CF6),
 Color(0xFF10B981),
 Color(0xFFF59E0B),
 Color(0xFFEF4444),
 Color(0xFF06B6D4),
 Color(0xFFEC4899),
 Color(0xFF6366F1),
 ];
 return colors[index % colors.length];
 }

 String _fmtDate(DateTime date) {
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
}

class _L1TimelineSegment {
 const _L1TimelineSegment({required this.label, required this.dayCount});
 final String label;
 final int dayCount;
}

List<_L1TimelineSegment> _generateMonthSegments(DateTime start, DateTime end) {
 final segments = <_L1TimelineSegment>[];
 final inclusiveEnd = DateTime(end.year, end.month, end.day);
 DateTime cursor = DateTime(start.year, start.month, 1);

 while (!cursor.isAfter(inclusiveEnd)) {
 final bucketStart = cursor.isBefore(start) ? start : cursor;
 final nextMonth = DateTime(cursor.year, cursor.month + 1, 1);
 final bucketEnd = nextMonth.subtract(const Duration(days: 1));
 final actualEnd =
 bucketEnd.isAfter(inclusiveEnd) ? inclusiveEnd : bucketEnd;
 final dayCount = actualEnd.difference(bucketStart).inDays + 1;

 segments.add(_L1TimelineSegment(
 label: _fmtMonth(cursor),
 dayCount: dayCount,
 ));
 cursor = nextMonth;
 }

 return segments;
}

String _fmtMonth(DateTime date) {
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
 return '${months[date.month - 1]} ${date.year}';
}

class _L1GridPainter extends CustomPainter {
 const _L1GridPainter({
 required this.leftColumnWidth,
 required this.rowHeight,
 required this.rowCount,
 required this.monthSegments,
 required this.pxPerDay,
 });

 final double leftColumnWidth;
 final double rowHeight;
 final int rowCount;
 final List<_L1TimelineSegment> monthSegments;
 final double pxPerDay;

 @override
 void paint(Canvas canvas, Size size) {
 final rowPaint = Paint()
 ..color = const Color(0xFFE5E7EB)
 ..strokeWidth = 0.5;

 for (int row = 0; row <= rowCount; row++) {
 final y = row * rowHeight;
 canvas.drawLine(Offset(0, y), Offset(size.width, y), rowPaint);
 }

 final dividerPaint = Paint()
 ..color = const Color(0xFFD1D5DB)
 ..strokeWidth = 1;

 double x = leftColumnWidth;
 canvas.drawLine(Offset(x, 0), Offset(x, size.height), dividerPaint);
 for (final segment in monthSegments) {
 x += segment.dayCount * pxPerDay;
 canvas.drawLine(Offset(x, 0), Offset(x, size.height), dividerPaint);
 }
 }

 @override
 bool shouldRepaint(covariant _L1GridPainter oldDelegate) => false;
}

class _DiamondPainter extends CustomPainter {
 const _DiamondPainter({required this.color});
 final Color color;

 @override
 void paint(Canvas canvas, Size size) {
 final paint = Paint()..color = color;
 final path = Path()
 ..moveTo(size.width / 2, 0)
 ..lineTo(size.width, size.height / 2)
 ..lineTo(size.width / 2, size.height)
 ..lineTo(0, size.height / 2)
 ..close();
 canvas.drawPath(path, paint);
 }

 @override
 bool shouldRepaint(covariant _DiamondPainter oldDelegate) =>
 color != oldDelegate.color;
}

class ProjectPlanDetailedScheduleScreen extends StatefulWidget {
 const ProjectPlanDetailedScheduleScreen({super.key});

 @override
 State<ProjectPlanDetailedScheduleScreen> createState() =>
 _DetailedScheduleState();
}

class _DetailedScheduleState extends State<ProjectPlanDetailedScheduleScreen> {
 List<_DetailedTask> _tasks = [];
 List<_DetailedTask> _baselineTasks = [];
 DateTime? _projectStart;
 DateTime? _projectEnd;
 DateTime? _baselineDate;
 bool _loading = true;
 String _zoomLevel = 'Week';
 bool _showBaseline = true;
 bool _showDependencies = true;
 String? _selectedTaskId;
 String? _hoveredTaskId;
 Timer? _saveDebounce;
 final ScrollController _horizontalScrollController = ScrollController();
 final ScrollController _verticalScrollController = ScrollController();

 @override
 void initState() {
 super.initState();
 WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
 }

 @override
 void dispose() {
 _horizontalScrollController.dispose();
 _verticalScrollController.dispose();
 _saveDebounce?.cancel();
 super.dispose();
 }

 void _loadData() {
 final data = ProjectDataHelper.getData(context);

 _projectStart = _parseDate(data.frontEndPlanning.milestoneStartDate);
 _projectEnd = _parseDate(data.frontEndPlanning.milestoneEndDate);

 final storedStart =
 data.planningNotes['planning_schedule_start_date']?.trim() ?? '';
 if (storedStart.isNotEmpty) {
 _projectStart = DateTime.tryParse(storedStart) ?? _projectStart;
 }

 _baselineDate = data.scheduleBaselineDate.trim().isNotEmpty
 ? DateTime.tryParse(data.scheduleBaselineDate)
 : null;

 _tasks = data.scheduleActivities
 .map((a) => _DetailedTask.fromActivity(a))
 .toList();

 if (_tasks.isEmpty && data.wbsTree.isNotEmpty) {
 _tasks = _buildTasksFromWbs(data);
 }

 _baselineTasks = data.scheduleBaselineActivities
 .map((a) => _DetailedTask.fromActivity(a))
 .toList();

 _sortTasksByStartDate();
 _autoExpandDates();

 setState(() => _loading = false);
 }

 List<_DetailedTask> _buildTasksFromWbs(ProjectDataModel data) {
 final tasks = <_DetailedTask>[];
 final start = _projectStart ?? DateTime.now();

 void visit(WorkItem item, int depth) {
 if (item.title.trim().isEmpty) return;
 final task = _DetailedTask(
 id: item.id,
 wbsId: item.id,
 title: item.title.trim(),
 startDate: start.add(Duration(days: depth * 7)),
 dueDate: start
 .add(Duration(days: depth * 7 + (item.children.isEmpty ? 5 : 14))),
 progress: _parseProgress(item.status),
 status: _mapWbsStatus(item.status),
 priority: 'Medium',
 assignee: '',
 discipline: item.framework,
 dependencies: item.dependencies,
 isMilestone: item.children.isEmpty && item.dependencies.isEmpty,
 );
 tasks.add(task);
 for (final child in item.children) {
 visit(child, depth + 1);
 }
 }

 for (final root in data.wbsTree) {
 visit(root, 0);
 }

 return tasks;
 }

 double _parseProgress(String status) {
 final s = status.trim().toLowerCase();
 if (s.contains('completed') || s.contains('complete')) return 1.0;
 if (s.contains('in_progress')) return 0.5;
 return 0.0;
 }

 String _mapWbsStatus(String status) {
 final s = status.trim().toLowerCase();
 if (s.contains('completed') || s.contains('complete')) return 'Completed';
 if (s.contains('in_progress')) return 'In Progress';
 if (s.contains('at risk')) return 'At Risk';
 return 'Not Started';
 }

 void _sortTasksByStartDate() {
 _tasks.sort((a, b) => a.startDate.compareTo(b.startDate));
 }

 void _autoExpandDates() {
 if (_tasks.isEmpty) return;

 DateTime? minStart;
 DateTime? maxEnd;

 for (final task in _tasks) {
 if (minStart == null || task.startDate.isBefore(minStart)) {
 minStart = task.startDate;
 }
 if (maxEnd == null || task.dueDate.isAfter(maxEnd)) {
 maxEnd = task.dueDate;
 }
 }

 if (_projectStart == null && minStart != null) {
 _projectStart = minStart.subtract(const Duration(days: 7));
 }
 if (_projectEnd == null && maxEnd != null) {
 _projectEnd = maxEnd.add(const Duration(days: 7));
 }
 }

 Future<void> _syncToScheduleScreen() async {
 _saveDebounce?.cancel();
 _saveDebounce = Timer(const Duration(milliseconds: 800), () async {
 final activities = _tasks
 .map((t) => ScheduleActivity(
 id: t.id,
 wbsId: t.wbsId,
 title: t.title,
 durationDays: t.dueDate.difference(t.startDate).inDays,
 predecessorIds: t.dependencies,
 isMilestone: t.isMilestone,
 status: t.status,
 priority: t.priority,
 assignee: t.assignee,
 discipline: t.discipline,
 progress: t.progress,
 startDate: _formatDate(t.startDate),
 dueDate: _formatDate(t.dueDate),
 estimatedHours: 0,
 milestone: t.isMilestone ? t.title : '',
 ))
 .toList();

 await ProjectDataHelper.updateAndSave(
 context: context,
 checkpoint: 'project_plan_detailed_schedule',
 dataUpdater: (data) => data.copyWith(
 scheduleActivities: activities,
 ),
 showSnackbar: false,
 );
 });
 }

 void _updateTask(_DetailedTask updated) {
 final index = _tasks.indexWhere((t) => t.id == updated.id);
 if (index == -1) return;
 setState(() => _tasks[index] = updated);
 _syncToScheduleScreen();
 }

 void _selectTask(String? taskId) {
 setState(() => _selectedTaskId = taskId);
 }

 void _addTask() {
 final newTask = _DetailedTask(
 id: DateTime.now().microsecondsSinceEpoch.toString(),
 wbsId: '',
 title: 'New Task',
 startDate: _projectStart ?? DateTime.now(),
 dueDate: (_projectStart ?? DateTime.now()).add(const Duration(days: 5)),
 progress: 0,
 status: 'Not Started',
 priority: 'Medium',
 assignee: '',
 discipline: '',
 dependencies: [],
 isMilestone: false,
 );
 setState(() {
 _tasks.add(newTask);
 });
 _selectTask(newTask.id);
 _scrollToLatestInlineTask();
 _syncToScheduleScreen();
 }

 void _scrollToLatestInlineTask() {
 WidgetsBinding.instance.addPostFrameCallback((_) async {
 await Future<void>.delayed(const Duration(milliseconds: 120));
 if (!mounted || !_verticalScrollController.hasClients) return;
 final position = _verticalScrollController.position;
 await _verticalScrollController.animateTo(
 position.maxScrollExtent,
 duration: const Duration(milliseconds: 420),
 curve: Curves.easeOutCubic,
 );
 });
 }

 void _deleteTask(String taskId) async {
 final task =
 _tasks.firstWhere((t) => t.id == taskId, orElse: () => _tasks.first);

 final confirmed = await showDialog<bool>(
 context: context,
 builder: (context) => AlertDialog(
 title: const Text('Delete Task'),
 content: Text('Are you sure you want to delete "${task.title}"?'),
 actions: [
 TextButton(
 onPressed: () => Navigator.of(context).pop(false),
 child: const Text('Cancel'),
 ),
 ElevatedButton(
 onPressed: () => Navigator.of(context).pop(true),
 style: ElevatedButton.styleFrom(
 backgroundColor: const Color(0xFFEF4444),
 foregroundColor: Colors.white,
 ),
 child: const Text('Delete'),
 ),
 ],
 ),
 );

 if (confirmed == true) {
 setState(() {
 _tasks.removeWhere((t) => t.id == taskId);
 if (_selectedTaskId == taskId) _selectedTaskId = null;
 });
 _syncToScheduleScreen();
 }
 }

 @override
 Widget build(BuildContext context) {
 final isMobile = AppBreakpoints.isMobile(context);
 final horizontalPadding = isMobile ? 20.0 : 32.0;

 return Scaffold(
 backgroundColor: Colors.white,
 body: SafeArea(
 child: Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 DraggableSidebar(
 openWidth: AppBreakpoints.sidebarWidth(context),
 child: InitiationLikeSidebar(
 activeItemLabel: 'Project Plan - Detailed Project Schedule'),
 ),
 Expanded(
 child: Stack(
 children: [
 MobileSidebarHamburger(
 sidebar: const InitiationLikeSidebar(
 activeItemLabel: 'Project Plan - Level 1 - Project Schedule',
 ),
 ),
 _loading
 ? const Center(child: CircularProgressIndicator())
 : SingleChildScrollView(
 controller: _verticalScrollController,
 padding: EdgeInsets.symmetric(
 horizontal: horizontalPadding, vertical: 24),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 _buildHeader(isMobile),
 const SizedBox(height: 20),
 PlanningAiNotesCard(
 title: 'Notes',
 sectionLabel: 'Detailed Project Schedule',
 noteKey: 'planning_project_plan_detailed_notes',
 checkpoint: 'project_plan_detailed_schedule',
 description:
 'Capture schedule insights, dependencies, and key timing constraints.',
 ),
 const SizedBox(height: 24),
 _buildMetricsRow(),
 const SizedBox(height: 24),
 _buildGanttSection(),
 const SizedBox(height: 24),
 _buildTaskListSection(),
 const SizedBox(height: 24),
 LaunchPhaseNavigation(
 backLabel: PlanningPhaseNavigation.backLabel(
 'project_plan_detailed_schedule'),
 nextLabel: PlanningPhaseNavigation.nextLabel(
 'project_plan_detailed_schedule'),
 onBack: () =>
 PlanningPhaseNavigation.goToPrevious(
 context,
 'project_plan_detailed_schedule'),
 onNext: () => PlanningPhaseNavigation.goToNext(
 context, 'project_plan_detailed_schedule'),
 ),
 const SizedBox(height: 80),
 ],
 ),
 ),
 const Positioned(
 right: 24,
 bottom: 24,
 child: KazAiChatBubble(positioned: false)),
 ],
 ),
 ),
 ],
 ),
 ),
 );
 }

 Widget _buildHeader(bool isMobile) {
 return Container(
 padding:
 EdgeInsets.symmetric(horizontal: isMobile ? 16 : 24, vertical: 16),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(16),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 ),
 child: isMobile
 ? Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 children: [
 const Text(
 'Detailed Project Schedule',
 style: TextStyle(
 fontSize: 20,
 fontWeight: FontWeight.w700,
 color: Color(0xFF111827)),
 ),
 const Spacer(),
 _buildAddTaskButton(),
 ],
 ),
 const SizedBox(height: 16),
 _buildZoomControls(),
 const SizedBox(height: 12),
 _buildToggleControls(),
 ],
 )
 : Row(
 children: [
 const Text(
 'Detailed Project Schedule',
 style: TextStyle(
 fontSize: 22,
 fontWeight: FontWeight.w700,
 color: Color(0xFF111827)),
 ),
 const Spacer(),
 _buildAddTaskButton(),
 const SizedBox(width: 16),
 _buildZoomControls(),
 const SizedBox(width: 16),
 _buildToggleControls(),
 ],
 ),
 );
 }

 Widget _buildAddTaskButton() {
 return ElevatedButton.icon(
 onPressed: _addTask,
 icon: const Icon(Icons.add, size: 18),
 label: const Text('Add Task'),
 style: ElevatedButton.styleFrom(
 backgroundColor: const Color(0xFFFFD54F),
 foregroundColor: const Color(0xFF111827),
 elevation: 0,
 padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
 ),
 );
 }

 Widget _buildZoomControls() {
 return Container(
 padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
 decoration: BoxDecoration(
 color: const Color(0xFFF3F4F6),
 borderRadius: BorderRadius.circular(10),
 ),
 child: Row(
 mainAxisSize: MainAxisSize.min,
 children: ['Day', 'Week', 'Month'].map((level) {
 final isSelected = _zoomLevel == level;
 return GestureDetector(
 onTap: () => setState(() => _zoomLevel = level),
 child: Container(
 padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
 decoration: BoxDecoration(
 color: isSelected ? Colors.white : Colors.transparent,
 borderRadius: BorderRadius.circular(8),
 boxShadow: isSelected
 ? [
 BoxShadow(
 color: Colors.black.withOpacity(0.08),
 blurRadius: 4)
 ]
 : null,
 ),
 child: Text(
 level,
 style: TextStyle(
 fontSize: 12,
 fontWeight: FontWeight.w600,
 color: isSelected
 ? const Color(0xFF2563EB)
 : const Color(0xFF6B7280),
 ),
 ),
 ),
 );
 }).toList(),
 ),
 );
 }

 Widget _buildToggleControls() {
 return Row(
 mainAxisSize: MainAxisSize.min,
 children: [
 _ToggleChip(
 label: 'Baseline',
 icon: Icons.straighten,
 isActive: _showBaseline,
 onTap: () => setState(() => _showBaseline = !_showBaseline),
 ),
 const SizedBox(width: 8),
 _ToggleChip(
 label: 'Dependencies',
 icon: Icons.account_tree_outlined,
 isActive: _showDependencies,
 onTap: () => setState(() => _showDependencies = !_showDependencies),
 ),
 ],
 );
 }

 Widget _buildMetricsRow() {
 final completedTasks = _tasks.where((t) => t.status == 'Completed').length;
 final inProgressTasks =
 _tasks.where((t) => t.status == 'In Progress').length;
 final totalTasks = _tasks.length;

 return Wrap(
 spacing: 16,
 runSpacing: 16,
 children: [
 _MetricCard(
 label: 'Total Tasks',
 value: '$totalTasks',
 accent: const Color(0xFF3B82F6),
 icon: Icons.task_alt_outlined,
 ),
 _MetricCard(
 label: 'Completed',
 value: '$completedTasks',
 accent: const Color(0xFF10B981),
 icon: Icons.check_circle_outline,
 ),
 _MetricCard(
 label: 'In Progress',
 value: '$inProgressTasks',
 accent: const Color(0xFFF59E0B),
 icon: Icons.pending_outlined,
 ),
 _MetricCard(
 label: 'Critical Path',
 value: '${_calculateCriticalPathTasks().length}',
 accent: const Color(0xFFEF4444),
 icon: Icons.warning_amber_outlined,
 ),
 ],
 );
 }

 List<String> _calculateCriticalPathTasks() {
 if (_tasks.isEmpty) return [];
 final criticalTasks = <String>[];
 for (final task in _tasks) {
 if (task.status == 'At Risk' || task.dueDate.isBefore(DateTime.now())) {
 criticalTasks.add(task.id);
 }
 }
 return criticalTasks;
 }

 Widget _buildGanttSection() {
 if (_tasks.isEmpty) {
 return _SectionEmptyState(
 title: 'No schedule tasks yet',
 message: 'Add tasks to see the detailed Gantt chart.',
 icon: Icons.timeline_outlined,
 );
 }

 return Container(
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(16),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Padding(
 padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
 child: Row(
 children: [
 const Icon(Icons.timeline, size: 18, color: Color(0xFF6B7280)),
 const SizedBox(width: 8),
 const Text(
 'Gantt Timeline',
 style: TextStyle(
 fontSize: 16,
 fontWeight: FontWeight.w700,
 color: Color(0xFF111827),
 ),
 ),
 const Spacer(),
 if (_projectStart != null)
 Text(
 '${_formatDate(_projectStart!)} → ${_projectEnd != null ? _formatDate(_projectEnd!) : '—'}',
 style:
 const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
 ),
 ],
 ),
 ),
 const SizedBox(height: 16),
 SizedBox(
 height: 400,
 child: SingleChildScrollView(
 controller: _horizontalScrollController,
 scrollDirection: Axis.horizontal,
 child: _DetailedGanttChart(
 tasks: _tasks,
 baselineTasks: _showBaseline ? _baselineTasks : [],
 projectStart: _projectStart,
 projectEnd: _projectEnd,
 zoomLevel: _zoomLevel,
 showDependencies: _showDependencies,
 selectedTaskId: _selectedTaskId,
 hoveredTaskId: _hoveredTaskId,
 onTaskSelect: _selectTask,
 onTaskHover: (id) => setState(() => _hoveredTaskId = id),
 onTaskUpdate: _updateTask,
 baselineDate: _baselineDate,
 ),
 ),
 ),
 const SizedBox(height: 12),
 Padding(
 padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
 child: _buildGanttLegend(),
 ),
 ],
 ),
 );
 }

 Widget _buildGanttLegend() {
 return Row(
 children: [
 _LegendItem(color: const Color(0xFF3B82F6), label: 'Not Started'),
 const SizedBox(width: 16),
 _LegendItem(color: const Color(0xFFF59E0B), label: 'In Progress'),
 const SizedBox(width: 16),
 _LegendItem(color: const Color(0xFF10B981), label: 'Completed'),
 const SizedBox(width: 16),
 _LegendItem(color: const Color(0xFFEF4444), label: 'At Risk'),
 if (_showBaseline) ...[
 const SizedBox(width: 24),
 Container(
 width: 20,
 height: 10,
 decoration: BoxDecoration(
 color: const Color(0xFFE5E7EB).withOpacity(0.6),
 borderRadius: BorderRadius.circular(3),
 border: Border.all(color: const Color(0xFFD1D5DB)),
 ),
 ),
 const SizedBox(width: 6),
 const Text('Baseline',
 style: TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
 ],
 ],
 );
 }

 Widget _buildTaskListSection() {
 if (_tasks.isEmpty) return const SizedBox.shrink();

 return Container(
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(16),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Padding(
 padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
 child: Row(
 children: [
 const Icon(Icons.list_alt, size: 18, color: Color(0xFF6B7280)),
 const SizedBox(width: 8),
 const Text(
 'Task Details',
 style: TextStyle(
 fontSize: 16,
 fontWeight: FontWeight.w700,
 color: Color(0xFF111827),
 ),
 ),
 const Spacer(),
 Text(
 '${_tasks.length} tasks',
 style:
 const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
 ),
 ],
 ),
 ),
 const SizedBox(height: 12),
 _buildTaskTable(),
 ],
 ),
 );
 }

 Widget _buildTaskTable() {
 const border = BorderSide(color: Color(0xFFE5E7EB));
 const headerStyle = TextStyle(
 fontSize: 12,
 fontWeight: FontWeight.w700,
 color: Color(0xFF6B7280),
 );

 return LayoutBuilder(
 builder: (context, constraints) {
 return SingleChildScrollView(
 scrollDirection: Axis.horizontal,
 child: SizedBox(
 width: constraints.maxWidth > 980 ? constraints.maxWidth : 980,
 child: Table(
 defaultVerticalAlignment: TableCellVerticalAlignment.middle,
 columnWidths: {
 0: const FixedColumnWidth(56),
 1: const FlexColumnWidth(3.6),
 2: const FixedColumnWidth(98),
 3: const FixedColumnWidth(98),
 4: const FixedColumnWidth(84),
 5: const FixedColumnWidth(112),
 6: const FixedColumnWidth(116),
 7: const FixedColumnWidth(96),
 8: const FixedColumnWidth(88),
 },
 border: const TableBorder(
 horizontalInside: border,
 verticalInside: border,
 ),
 children: [
 TableRow(
 decoration: const BoxDecoration(color: Color(0xFFF8FAFC)),
 children: [
 _headerCell('#', headerStyle),
 _headerCell('Task', headerStyle),
 _headerCell('Start', headerStyle),
 _headerCell('End', headerStyle),
 _headerCell('Days', headerStyle),
 _headerCell('Progress', headerStyle),
 _headerCell('Status', headerStyle),
 _headerCell('Priority', headerStyle),
 _headerCell('', headerStyle),
 ],
 ),
 ...List.generate(_tasks.length, (index) {
 final task = _tasks[index];
 final duration =
 task.dueDate.difference(task.startDate).inDays;
 final isSelected = _selectedTaskId == task.id;

 return TableRow(
 decoration: BoxDecoration(
 color: isSelected
 ? const Color(0xFFE8F4FF)
 : (index.isEven
 ? Colors.white
 : const Color(0xFFFAFAFA)),
 ),
 children: [
 _dataCell(Center(
 child: Text('${index + 1}',
 style: const TextStyle(
 fontSize: 12,
 fontWeight: FontWeight.w700,
 color: Color(0xFF4B5563))),
 )),
 _dataCell(_TaskNameCell(
 task: task,
 isSelected: isSelected,
 onTap: () => _selectTask(task.id),
 )),
 _dataCell(_DateCell(
 date: task.startDate,
 onDateSelected: (date) {
 _updateTask(task.copyWith(startDate: date));
 },
 )),
 _dataCell(_DateCell(
 date: task.dueDate,
 onDateSelected: (date) {
 _updateTask(task.copyWith(dueDate: date));
 },
 )),
 _dataCell(Center(
 child: Text(
 '${duration}d',
 style: const TextStyle(
 fontSize: 11,
 fontWeight: FontWeight.w600,
 color: Color(0xFF374151)),
 ),
 )),
 _dataCell(_ProgressCell(progress: task.progress)),
 _dataCell(_StatusCell(status: task.status)),
 _dataCell(_PriorityCell(priority: task.priority)),
 _dataCell(Center(
 child: IconButton(
 icon: const Icon(Icons.delete_outline, size: 16),
 color: const Color(0xFF6B7280),
 onPressed: () => _deleteTask(task.id),
 tooltip: 'Delete task',
 ),
 )),
 ],
 );
 }),
 ],
 ),
 ),
 );
 },
 );
 }

 Widget _headerCell(String text, TextStyle style) {
 return Padding(
 padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
 child: Text(text, style: style, textAlign: TextAlign.center),
 );
 }

 Widget _dataCell(Widget child) {
 return Padding(
 padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
 child: child,
 );
 }

 DateTime? _parseDate(String raw) {
 final value = raw.trim();
 if (value.isEmpty) return null;
 final parsed = DateTime.tryParse(value);
 if (parsed != null) return parsed;
 final parts = value.split(RegExp(r'[\s,]+'));
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

 String _formatDate(DateTime date) {
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
}

class _DetailedTask {
 final String id;
 final String wbsId;
 final String title;
 final DateTime startDate;
 final DateTime dueDate;
 final double progress;
 final String status;
 final String priority;
 final String assignee;
 final String discipline;
 final List<String> dependencies;
 final bool isMilestone;

 const _DetailedTask({
 required this.id,
 required this.wbsId,
 required this.title,
 required this.startDate,
 required this.dueDate,
 required this.progress,
 required this.status,
 required this.priority,
 required this.assignee,
 required this.discipline,
 required this.dependencies,
 required this.isMilestone,
 });

 factory _DetailedTask.fromActivity(ScheduleActivity activity) {
 return _DetailedTask(
 id: activity.id,
 wbsId: activity.wbsId,
 title: activity.title,
 startDate: _parseActivityDate(activity.startDate) ?? DateTime.now(),
 dueDate: _parseActivityDate(activity.dueDate) ??
 DateTime.now().add(const Duration(days: 5)),
 progress: activity.progress,
 status: _normalizeStatus(activity.status),
 priority: activity.priority,
 assignee: activity.assignee,
 discipline: activity.discipline,
 dependencies: activity.predecessorIds,
 isMilestone: activity.isMilestone,
 );
 }

 static DateTime? _parseActivityDate(String raw) {
 if (raw.isEmpty) return null;
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

 static String _normalizeStatus(String status) {
 final s = status.trim().toLowerCase();
 if (s.contains('complete')) return 'Completed';
 if (s.contains('in_progress')) return 'In Progress';
 if (s.contains('risk') || s.contains('behind')) return 'At Risk';
 return 'Not Started';
 }

 _DetailedTask copyWith({
 String? id,
 String? wbsId,
 String? title,
 DateTime? startDate,
 DateTime? dueDate,
 double? progress,
 String? status,
 String? priority,
 String? assignee,
 String? discipline,
 List<String>? dependencies,
 bool? isMilestone,
 }) {
 return _DetailedTask(
 id: id ?? this.id,
 wbsId: wbsId ?? this.wbsId,
 title: title ?? this.title,
 startDate: startDate ?? this.startDate,
 dueDate: dueDate ?? this.dueDate,
 progress: progress ?? this.progress,
 status: status ?? this.status,
 priority: priority ?? this.priority,
 assignee: assignee ?? this.assignee,
 discipline: discipline ?? this.discipline,
 dependencies: dependencies ?? this.dependencies,
 isMilestone: isMilestone ?? this.isMilestone,
 );
 }
}

class _DetailedGanttChart extends StatelessWidget {
 const _DetailedGanttChart({
 required this.tasks,
 required this.baselineTasks,
 required this.projectStart,
 required this.projectEnd,
 required this.zoomLevel,
 required this.showDependencies,
 required this.selectedTaskId,
 required this.hoveredTaskId,
 required this.onTaskSelect,
 required this.onTaskHover,
 required this.onTaskUpdate,
 this.baselineDate,
 });

 final List<_DetailedTask> tasks;
 final List<_DetailedTask> baselineTasks;
 final DateTime? projectStart;
 final DateTime? projectEnd;
 final String zoomLevel;
 final bool showDependencies;
 final String? selectedTaskId;
 final String? hoveredTaskId;
 final ValueChanged<String?> onTaskSelect;
 final ValueChanged<String?> onTaskHover;
 final ValueChanged<_DetailedTask> onTaskUpdate;
 final DateTime? baselineDate;

 static const double _leftColumnWidth = 280;
 static const double _rowHeight = 44;
 static const double _headerHeight = 50;

 @override
 Widget build(BuildContext context) {
 if (tasks.isEmpty) {
 return const SizedBox(width: 600, height: 200);
 }

 final start = projectStart ??
 tasks.map((t) => t.startDate).reduce((a, b) => a.isBefore(b) ? a : b);
 final end = projectEnd ??
 tasks.map((t) => t.dueDate).reduce((a, b) => a.isAfter(b) ? a : b);

 final buffer = (end.difference(start).inDays * 0.05).round().clamp(7, 30);
 final chartStart = start.subtract(Duration(days: buffer));
 final chartEnd = end.add(Duration(days: buffer));

 double pxPerDay;
 switch (zoomLevel) {
 case 'Day':
 pxPerDay = 40.0;
 break;
 case 'Week':
 pxPerDay = 20.0;
 break;
 case 'Month':
 default:
 pxPerDay = 8.0;
 break;
 }

 final totalDays = chartEnd.difference(chartStart).inDays + 1;
 final timelineWidth = totalDays * pxPerDay;
 final chartHeight = tasks.length * _rowHeight + _headerHeight;

 final segments = _generateTimeSegments(chartStart, chartEnd, zoomLevel);
 final taskIndexMap = {
 for (var i = 0; i < tasks.length; i++) tasks[i].id: i
 };

 return SizedBox(
 width: _leftColumnWidth + timelineWidth + 2,
 height: chartHeight,
 child: Stack(
 children: [
 CustomPaint(
 size: Size(_leftColumnWidth + timelineWidth, chartHeight),
 painter: _DetailedGanttPainter(
 leftColumnWidth: _leftColumnWidth,
 rowHeight: _rowHeight,
 headerHeight: _headerHeight,
 rowCount: tasks.length,
 segments: segments,
 pxPerDay: pxPerDay,
 chartStart: chartStart,
 ),
 ),
 Positioned(
 left: 0,
 top: 0,
 width: _leftColumnWidth,
 height: _headerHeight,
 child: Container(
 decoration: const BoxDecoration(
 color: Color(0xFFF8FAFC),
 border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
 ),
 child: const Center(
 child: Text(
 'Task Name',
 style: TextStyle(
 fontSize: 12,
 fontWeight: FontWeight.w700,
 color: Color(0xFF374151),
 ),
 ),
 ),
 ),
 ),
 ...List.generate(tasks.length, (index) {
 final task = tasks[index];
 final top = _headerHeight + index * _rowHeight;
 final isSelected = selectedTaskId == task.id;

 return Positioned(
 left: 0,
 top: top,
 width: _leftColumnWidth,
 height: _rowHeight,
 child: GestureDetector(
 onTap: () => onTaskSelect(task.id),
 child: Container(
 decoration: BoxDecoration(
 color: isSelected
 ? const Color(0xFFE8F4FF)
 : (index.isEven
 ? Colors.white
 : const Color(0xFFFAFAFA)),
 border: Border(
 bottom: BorderSide(
 color: const Color(0xFFE5E7EB).withOpacity(0.5),
 ),
 ),
 ),
 padding: const EdgeInsets.symmetric(horizontal: 12),
 alignment: Alignment.centerLeft,
 child: Row(
 children: [
 Expanded(
 child: Text(
 task.title,
 style: TextStyle(
 fontSize: 12,
 fontWeight:
 isSelected ? FontWeight.w600 : FontWeight.w500,
 color: const Color(0xFF111827),
 ),
 overflow: TextOverflow.ellipsis,
 ),
 ),
 if (task.isMilestone)
 const Icon(Icons.flag,
 size: 14, color: Color(0xFFF59E0B)),
 ],
 ),
 ),
 ),
 );
 }),
 ..._buildDependencyLines(chartStart, pxPerDay, taskIndexMap),
 ..._buildTaskBars(chartStart, pxPerDay),
 ],
 ),
 );
 }

 List<Widget> _buildTaskBars(DateTime chartStart, double pxPerDay) {
 return List.generate(tasks.length, (index) {
 final task = tasks[index];
 final top = _headerHeight + index * _rowHeight;
 final startOffset = task.startDate.difference(chartStart).inDays;
 final duration = task.dueDate.difference(task.startDate).inDays + 1;
 final left = _leftColumnWidth + startOffset * pxPerDay;
 final width = (duration * pxPerDay).clamp(20.0, 2000.0);

 Color barColor;
 switch (task.status) {
 case 'Completed':
 barColor = const Color(0xFF10B981);
 break;
 case 'In Progress':
 barColor = const Color(0xFFF59E0B);
 break;
 case 'At Risk':
 barColor = const Color(0xFFEF4444);
 break;
 default:
 barColor = const Color(0xFF3B82F6);
 }

 final baselineTask = baselineTasks
 .where((t) => t.id == task.id || t.title == task.title)
 .firstOrNull;

 return Positioned(
 left: left,
 top: top + 8,
 child: GestureDetector(
 onTap: () => onTaskSelect(task.id),
 child: SizedBox(
 width: width,
 height: _rowHeight - 16,
 child: Stack(
 children: [
 if (baselineTask != null) ...[
 Positioned(
 left: 0,
 top: 0,
 child: Container(
 width: ((baselineTask.dueDate
 .difference(baselineTask.startDate)
 .inDays +
 1) *
 pxPerDay)
 .clamp(20.0, 2000.0),
 height: _rowHeight - 16,
 decoration: BoxDecoration(
 color: const Color(0xFFE5E7EB).withOpacity(0.6),
 borderRadius: BorderRadius.circular(6),
 border: Border.all(color: const Color(0xFFD1D5DB)),
 ),
 ),
 ),
 ],
 Container(
 width: width,
 height: _rowHeight - 16,
 decoration: BoxDecoration(
 borderRadius: BorderRadius.circular(6),
 color: barColor,
 ),
 child: ClipRRect(
 borderRadius: BorderRadius.circular(6),
 child: Stack(
 children: [
 if (task.progress > 0)
 Align(
 alignment: Alignment.centerLeft,
 child: FractionallySizedBox(
 widthFactor: task.progress.clamp(0, 1),
 child: Container(
 decoration: BoxDecoration(
 color: barColor.withOpacity(0.7),
 ),
 ),
 ),
 ),
 Center(
 child: Text(
 '${(task.progress * 100).round()}%',
 style: const TextStyle(
 fontSize: 10,
 fontWeight: FontWeight.w700,
 color: Colors.white,
 ),
 ),
 ),
 ],
 ),
 ),
 ),
 ],
 ),
 ),
 ),
 );
 });
 }

 List<Widget> _buildDependencyLines(
 DateTime chartStart, double pxPerDay, Map<String, int> taskIndexMap) {
 if (!showDependencies) return [];

 final lines = <Widget>[];

 for (final task in tasks) {
 if (task.dependencies.isEmpty) continue;

 final taskIndex = taskIndexMap[task.id];
 if (taskIndex == null) continue;

 final taskLeft = _leftColumnWidth +
 task.startDate.difference(chartStart).inDays * pxPerDay;

 for (final depId in task.dependencies) {
 final depIndex = taskIndexMap[depId];
 if (depIndex == null) continue;

 final depTask = tasks[depIndex];
 final depLeft = _leftColumnWidth +
 depTask.dueDate.difference(chartStart).inDays * pxPerDay;
 final depTop = _headerHeight + depIndex * _rowHeight + _rowHeight / 2;
 final targetTop =
 _headerHeight + taskIndex * _rowHeight + _rowHeight / 2;

 lines.add(
 CustomPaint(
 size: Size(_leftColumnWidth + (tasks.length * 50 + 200), 400),
 painter: _DependencyLinePainter(
 startX: depLeft + 8,
 startY: depTop,
 endX: taskLeft,
 endY: targetTop,
 ),
 ),
 );
 }
 }

 return lines;
 }

 List<_TimeSegment> _generateTimeSegments(
 DateTime start, DateTime end, String zoom) {
 final segments = <_TimeSegment>[];
 DateTime cursor = DateTime(start.year, start.month, 1);

 while (!cursor.isAfter(end)) {
 final nextMonth = DateTime(cursor.year, cursor.month + 1, 1);
 final bucketStart = cursor.isBefore(start) ? start : cursor;
 final bucketEnd = nextMonth.subtract(const Duration(days: 1));
 final actualEnd = bucketEnd.isAfter(end) ? end : bucketEnd;
 final dayCount = actualEnd.difference(bucketStart).inDays + 1;

 String label;
 if (zoom == 'Day') {
 label = '${_fmtMonth(cursor)} ${cursor.year}';
 } else if (zoom == 'Week') {
 label = '${_fmtShortMonth(cursor)} ${cursor.year}';
 } else {
 label = _fmtShortMonth(cursor);
 }

 segments.add(_TimeSegment(
 label: label,
 dayCount: dayCount,
 startDate: bucketStart,
 ));

 cursor = nextMonth;
 }

 return segments;
 }

 String _fmtMonth(DateTime date) {
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
 return months[date.month - 1];
 }

 String _fmtShortMonth(DateTime date) {
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
}

class _TimeSegment {
 final String label;
 final int dayCount;
 final DateTime startDate;

 const _TimeSegment(
 {required this.label, required this.dayCount, required this.startDate});
}

class _DetailedGanttPainter extends CustomPainter {
 const _DetailedGanttPainter({
 required this.leftColumnWidth,
 required this.rowHeight,
 required this.headerHeight,
 required this.rowCount,
 required this.segments,
 required this.pxPerDay,
 required this.chartStart,
 });

 final double leftColumnWidth;
 final double rowHeight;
 final double headerHeight;
 final int rowCount;
 final List<_TimeSegment> segments;
 final double pxPerDay;
 final DateTime chartStart;

 @override
 void paint(Canvas canvas, Size size) {
 final rowPaint = Paint()
 ..color = const Color(0xFFE5E7EB)
 ..strokeWidth = 0.5;

 for (int row = 0; row <= rowCount; row++) {
 final y = headerHeight + row * rowHeight;
 canvas.drawLine(
 Offset(0, y),
 Offset(size.width, y),
 rowPaint,
 );
 }

 final dividerPaint = Paint()
 ..color = const Color(0xFFD1D5DB)
 ..strokeWidth = 1;

 canvas.drawLine(
 Offset(leftColumnWidth, 0),
 Offset(leftColumnWidth, size.height),
 dividerPaint,
 );

 double x = leftColumnWidth;
 for (final segment in segments) {
 canvas.drawLine(Offset(x, 0), Offset(x, size.height), dividerPaint);
 x += segment.dayCount * pxPerDay;
 }
 }

 @override
 bool shouldRepaint(covariant _DetailedGanttPainter oldDelegate) => false;
}

class _DependencyLinePainter extends CustomPainter {
 const _DependencyLinePainter({
 required this.startX,
 required this.startY,
 required this.endX,
 required this.endY,
 });

 final double startX;
 final double startY;
 final double endX;
 final double endY;

 @override
 void paint(Canvas canvas, Size size) {
 final paint = Paint()
 ..color = const Color(0xFF8B5CF6)
 ..strokeWidth = 2
 ..style = PaintingStyle.stroke;

 final path = Path();
 path.moveTo(startX, startY);

 if (endX > startX) {
 final midX = startX + (endX - startX) / 2;
 path.lineTo(midX, startY);
 path.lineTo(midX, endY);
 path.lineTo(endX, endY);
 } else {
 path.lineTo(startX + 20, startY);
 path.lineTo(startX + 20, startY + (endY - startY) / 2);
 path.lineTo(endX - 20, endY);
 path.lineTo(endX, endY);
 }

 canvas.drawPath(path, paint);

 final arrowPaint = Paint()
 ..color = const Color(0xFF8B5CF6)
 ..style = PaintingStyle.fill;

 final arrowPath = Path();
 arrowPath.moveTo(endX, endY);
 arrowPath.lineTo(endX - 6, endY - 4);
 arrowPath.lineTo(endX - 6, endY + 4);
 arrowPath.close();
 canvas.drawPath(arrowPath, arrowPaint);
 }

 @override
 bool shouldRepaint(covariant _DependencyLinePainter oldDelegate) => false;
}

class _ToggleChip extends StatelessWidget {
 const _ToggleChip({
 required this.label,
 required this.icon,
 required this.isActive,
 required this.onTap,
 });

 final String label;
 final IconData icon;
 final bool isActive;
 final VoidCallback onTap;

 @override
 Widget build(BuildContext context) {
 return GestureDetector(
 onTap: onTap,
 child: Container(
 padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
 decoration: BoxDecoration(
 color: isActive ? const Color(0xFFEEF2FF) : const Color(0xFFF3F4F6),
 borderRadius: BorderRadius.circular(8),
 border: Border.all(
 color: isActive ? const Color(0xFF6366F1) : const Color(0xFFE5E7EB),
 ),
 ),
 child: Row(
 mainAxisSize: MainAxisSize.min,
 children: [
 Icon(
 icon,
 size: 14,
 color:
 isActive ? const Color(0xFF6366F1) : const Color(0xFF6B7280),
 ),
 const SizedBox(width: 6),
 Text(
 label,
 style: TextStyle(
 fontSize: 12,
 fontWeight: FontWeight.w600,
 color: isActive
 ? const Color(0xFF6366F1)
 : const Color(0xFF6B7280),
 ),
 ),
 ],
 ),
 ),
 );
 }
}

class _LegendItem extends StatelessWidget {
 const _LegendItem({required this.color, required this.label});

 final Color color;
 final String label;

 @override
 Widget build(BuildContext context) {
 return Row(
 mainAxisSize: MainAxisSize.min,
 children: [
 Container(
 width: 12,
 height: 12,
 decoration: BoxDecoration(
 color: color,
 borderRadius: BorderRadius.circular(3),
 ),
 ),
 const SizedBox(width: 6),
 Text(label,
 style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
 ],
 );
 }
}

class _TaskNameCell extends StatelessWidget {
 const _TaskNameCell(
 {required this.task, required this.isSelected, required this.onTap});

 final _DetailedTask task;
 final bool isSelected;
 final VoidCallback onTap;

 @override
 Widget build(BuildContext context) {
 return GestureDetector(
 onTap: onTap,
 child: Container(
 padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
 child: Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 if (task.isMilestone)
 const Padding(
 padding: EdgeInsets.only(right: 6),
 child: Icon(Icons.flag, size: 14, color: Color(0xFFF59E0B)),
 ),
 Expanded(
 child: Text(
 task.title,
 style: TextStyle(
 fontSize: 12,
 fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
 color: const Color(0xFF111827),
 height: 1.35,
 ),
 softWrap: true,
 ),
 ),
 ],
 ),
 ),
 );
 }
}

class _DateCell extends StatelessWidget {
 const _DateCell({required this.date, required this.onDateSelected});

 final DateTime date;
 final ValueChanged<DateTime> onDateSelected;

 @override
 Widget build(BuildContext context) {
 return GestureDetector(
 onTap: () async {
 final picked = await showDatePicker(
 context: context,
 initialDate: date,
 firstDate: DateTime(2000),
 lastDate: DateTime(2100),
 );
 if (picked != null) {
 onDateSelected(picked);
 }
 },
 child: Container(
 padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
 child: Text(
 _formatDate(date),
 style: const TextStyle(fontSize: 12, color: Color(0xFF374151)),
 ),
 ),
 );
 }

 String _formatDate(DateTime date) {
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
}

class _ProgressCell extends StatelessWidget {
 const _ProgressCell({required this.progress});

 final double progress;

 @override
 Widget build(BuildContext context) {
 final pct = (progress * 100).round();
 return Container(
 padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
 child: Row(
 mainAxisSize: MainAxisSize.min,
 children: [
 SizedBox(
 width: 50,
 child: ClipRRect(
 borderRadius: BorderRadius.circular(3),
 child: LinearProgressIndicator(
 value: progress.clamp(0, 1),
 backgroundColor: const Color(0xFFE5E7EB),
 valueColor: AlwaysStoppedAnimation<Color>(
 pct >= 80
 ? const Color(0xFF10B981)
 : pct >= 50
 ? const Color(0xFFF59E0B)
 : const Color(0xFF3B82F6),
 ),
 ),
 ),
 ),
 const SizedBox(width: 6),
 Text(
 '$pct%',
 style: const TextStyle(
 fontSize: 11,
 fontWeight: FontWeight.w600,
 color: Color(0xFF374151)),
 ),
 ],
 ),
 );
 }
}

class _StatusCell extends StatelessWidget {
 const _StatusCell({required this.status});

 final String status;

 @override
 Widget build(BuildContext context) {
 Color color;
 switch (status) {
 case 'Completed':
 color = const Color(0xFF10B981);
 break;
 case 'In Progress':
 color = const Color(0xFFF59E0B);
 break;
 case 'At Risk':
 color = const Color(0xFFEF4444);
 break;
 default:
 color = const Color(0xFF6B7280);
 }

 return Container(
 margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
 padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
 decoration: BoxDecoration(
 color: color.withOpacity(0.12),
 borderRadius: BorderRadius.circular(999),
 ),
 child: Text(
 status,
 style: TextStyle(
 fontSize: 11,
 fontWeight: FontWeight.w700,
 color: color,
 ),
 ),
 );
 }
}

class _PriorityCell extends StatelessWidget {
 const _PriorityCell({required this.priority});

 final String priority;

 @override
 Widget build(BuildContext context) {
 Color color;
 switch (priority.toLowerCase()) {
 case 'high':
 color = const Color(0xFFEF4444);
 break;
 case 'medium':
 color = const Color(0xFFF59E0B);
 break;
 default:
 color = const Color(0xFF10B981);
 }

 return Container(
 margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
 padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
 decoration: BoxDecoration(
 color: color.withOpacity(0.12),
 borderRadius: BorderRadius.circular(999),
 ),
 child: Text(
 priority,
 style: TextStyle(
 fontSize: 11,
 fontWeight: FontWeight.w600,
 color: color,
 ),
 ),
 );
 }
}

class ProjectPlanCondensedSummaryScreen extends StatefulWidget {
 const ProjectPlanCondensedSummaryScreen({super.key});

 @override
 State<ProjectPlanCondensedSummaryScreen> createState() =>
 _CondensedSummaryState();
}

class _CondensedSummaryState extends State<ProjectPlanCondensedSummaryScreen> {
 final TextEditingController _summaryController = TextEditingController();
 bool _loading = true;
 bool _isGenerating = false;
 String? _undoBeforeAi;
 Timer? _saveDebounce;
 DateTime? _lastSavedAt;

 _SummaryData _summaryData = _SummaryData.empty();

 @override
 void initState() {
 super.initState();
 _summaryController.addListener(_handleSummaryChanged);
 WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
 }

 @override
 void dispose() {
 _saveDebounce?.cancel();
 _summaryController.removeListener(_handleSummaryChanged);
 _summaryController.dispose();
 super.dispose();
 }

 void _handleSummaryChanged() {
 _saveDebounce?.cancel();
 _saveDebounce = Timer(const Duration(milliseconds: 700), _persistSummary);
 }

 void _loadData() {
 final data = ProjectDataHelper.getData(context);

 final stored =
 data.planningNotes['planning_project_plan_condensed_summary'] ?? '';
 _summaryController.text = stored;

 _summaryData = _aggregateSummaryData(data);

 setState(() => _loading = false);
 }

 _SummaryData _aggregateSummaryData(ProjectDataModel data) {
 final scheduleHealth = _calculateScheduleHealth(data);
 final budgetData = _aggregateBudget(data);
 final risks = _aggregateRisks(data);
 final milestones = _aggregateMilestones(data);
 final scope = _aggregateScope(data);
 final team = _aggregateTeam(data);

 return _SummaryData(
 projectName: data.projectName,
 scheduleHealth: scheduleHealth,
 scheduleDaysRemaining: _calculateDaysRemaining(data),
 totalBudget: budgetData.total,
 currency: budgetData.currency,
 budgetVariance: budgetData.variance,
 riskCount: risks.open,
 riskLevel: risks.level,
 topMilestones: milestones,
 scopeIn: scope.inScope,
 scopeOut: scope.outScope,
 teamMembers: team.members,
 vendorCount: team.vendors,
 );
 }

 _ScheduleHealth _calculateScheduleHealth(ProjectDataModel data) {
 if (data.scheduleActivities.isEmpty) {
 if (data.keyMilestones.isEmpty) return _ScheduleHealth.unknown;
 final overdueMilestones = data.keyMilestones
 .where((m) =>
 m.dueDate.trim().isNotEmpty &&
 DateTime.tryParse(m.dueDate)?.isBefore(DateTime.now()) == true)
 .length;
 if (overdueMilestones > 0) return _ScheduleHealth.atRisk;
 return _ScheduleHealth.onTrack;
 }

 final completed = data.scheduleActivities
 .where((a) => a.status.toLowerCase() == 'completed')
 .length;
 final total = data.scheduleActivities.length;
 final progress = total > 0 ? completed / total : 0.0;

 if (progress >= 0.8) return _ScheduleHealth.onTrack;
 if (progress >= 0.5) return _ScheduleHealth.atRisk;
 return _ScheduleHealth.behind;
 }

 int _calculateDaysRemaining(ProjectDataModel data) {
 DateTime? endDate;
 if (data.frontEndPlanning.milestoneEndDate.trim().isNotEmpty) {
 endDate = DateTime.tryParse(data.frontEndPlanning.milestoneEndDate);
 }
 if (endDate == null) {
 for (final m in data.keyMilestones) {
 if (m.dueDate.trim().isNotEmpty) {
 final parsed = DateTime.tryParse(m.dueDate);
 if (parsed != null && (endDate == null || parsed.isAfter(endDate))) {
 endDate = parsed;
 }
 }
 }
 }
 if (endDate == null) return 0;
 return endDate.difference(DateTime.now()).inDays;
 }

 _BudgetData _aggregateBudget(ProjectDataModel data) {
 final total = data.costEstimateItems
 .fold<double>(0, (acc, item) => acc + item.amount);
 final currency = data.costBenefitCurrency.trim().isNotEmpty
 ? data.costBenefitCurrency.trim()
 : 'USD';

 return _BudgetData(
 total: total,
 currency: currency,
 variance: 0,
 );
 }

 _RiskData _aggregateRisks(ProjectDataModel data) {
 var openRisks = 0;
 var highRisks = 0;

 for (final r in data.frontEndPlanning.riskRegisterItems) {
 if (r.status.trim().toLowerCase() != 'closed' &&
 r.status.trim().toLowerCase() != 'resolved') {
 openRisks++;
 if (r.impactLevel.toLowerCase().contains('high') ||
 r.impactLevel.toLowerCase().contains('critical')) {
 highRisks++;
 }
 }
 }

 for (final i in data.issueLogItems) {
 if (i.status.trim().toLowerCase() != 'resolved' &&
 i.status.trim().toLowerCase() != 'closed') {
 openRisks++;
 }
 }

 _RiskLevel level;
 if (highRisks >= 3 || openRisks >= 10) {
 level = _RiskLevel.high;
 } else if (highRisks >= 1 || openRisks >= 5) {
 level = _RiskLevel.medium;
 } else {
 level = _RiskLevel.low;
 }

 return _RiskData(open: openRisks, level: level);
 }

 List<_MilestoneSummary> _aggregateMilestones(ProjectDataModel data) {
 return data.keyMilestones
 .where((m) => m.name.trim().isNotEmpty)
 .take(5)
 .map((m) => _MilestoneSummary(
 name: m.name.trim(),
 dueDate: m.dueDate.trim(),
 discipline: m.discipline.trim(),
 status: _determineMilestoneStatus(m),
 ))
 .toList();
 }

 String _determineMilestoneStatus(Milestone m) {
 final comments = m.comments.trim().toLowerCase();
 if (comments.contains('complete') || comments.contains('done')) {
 return 'Complete';
 }
 if (comments.contains('progress') || comments.contains('ongoing')) {
 return 'In Progress';
 }
 final dueDate = m.dueDate.trim();
 if (dueDate.isNotEmpty) {
 final parsed = DateTime.tryParse(dueDate);
 if (parsed != null && parsed.isBefore(DateTime.now())) {
 return 'At Risk';
 }
 }
 return 'Planned';
 }

 _ScopeData _aggregateScope(ProjectDataModel data) {
 final inScope = <String>[];
 final outScope = <String>[];

 for (final item in data.withinScopeItems) {
 if (item.description.trim().isNotEmpty) {
 inScope.add(item.description.trim());
 }
 }

 for (final item in data.outOfScopeItems) {
 if (item.description.trim().isNotEmpty) {
 outScope.add(item.description.trim());
 }
 }

 return _ScopeData(
 inScope: inScope.take(5).toList(), outScope: outScope.take(3).toList());
 }

 _TeamData _aggregateTeam(ProjectDataModel data) {
 final members = data.teamMembers
 .where((m) => m.name.trim().isNotEmpty)
 .map((m) => m.name.trim())
 .toList();

 final vendors =
 data.contractors.where((c) => c.name.trim().isNotEmpty).length +
 data.vendors.where((v) => v.name.trim().isNotEmpty).length;

 return _TeamData(members: members.take(8).toList(), vendors: vendors);
 }

 Future<void> _regenerateSummary() async {
 if (_isGenerating) return;

 setState(() => _isGenerating = true);
 _undoBeforeAi = _summaryController.text;

 try {
 final contextText = _buildAiContext();
 final ai = OpenAiServiceSecure();
 final text = await ai.generateFepSectionText(
 section: 'Executive Summary',
 context: contextText,
 maxTokens: 800,
 temperature: 0.6,
 );

 if (!mounted) return;
 final cleaned = TextSanitizer.sanitizeAiRichText(text).trim();
 if (cleaned.isNotEmpty) {
 _summaryController.text = cleaned;
 _persistSummary();
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
 buffer.writeln('Project Name: ${_summaryData.projectName}');
 buffer.writeln('Schedule Health: ${_summaryData.scheduleHealth.name}');
 buffer.writeln('Days Remaining: ${_summaryData.scheduleDaysRemaining}');
 buffer.writeln(
 'Budget: ${_summaryData.currency} ${_summaryData.totalBudget.toStringAsFixed(2)}');
 buffer.writeln('Open Risks: ${_summaryData.riskCount}');
 buffer.writeln('Risk Level: ${_summaryData.riskLevel.name}');

 if (_summaryData.topMilestones.isNotEmpty) {
 buffer.writeln('\nKey Milestones:');
 for (final m in _summaryData.topMilestones) {
 buffer.writeln('- ${m.name} (${m.status}, ${m.dueDate})');
 }
 }

 if (_summaryData.scopeIn.isNotEmpty) {
 buffer.writeln('\nIn Scope:');
 for (final s in _summaryData.scopeIn) {
 buffer.writeln('- $s');
 }
 }

 if (_summaryData.teamMembers.isNotEmpty) {
 buffer.writeln('\nTeam: ${_summaryData.teamMembers.join(', ')}');
 }

 buffer.writeln(
 '\nGenerate a concise executive summary (3-4 sentences) using BLUF format.');
 return buffer.toString();
 }

 void _undo() {
 final prev = _undoBeforeAi;
 if (prev == null) return;
 _undoBeforeAi = null;
 _summaryController.text = prev;
 _persistSummary();
 }

 Future<void> _persistSummary() async {
 final success = await ProjectDataHelper.updateAndSave(
 context: context,
 checkpoint: 'project_plan_condensed_summary',
 showSnackbar: false,
 dataUpdater: (data) => data.copyWith(
 planningNotes: {
 ...data.planningNotes,
 'planning_project_plan_condensed_summary':
 _summaryController.text.trim(),
 },
 ),
 );

 if (mounted && success) {
 setState(() => _lastSavedAt = DateTime.now());
 }
 }

 @override
 Widget build(BuildContext context) {
 final isMobile = AppBreakpoints.isMobile(context);
 final horizontalPadding = isMobile ? 20.0 : 32.0;

 return Scaffold(
 backgroundColor: Colors.white,
 body: SafeArea(
 child: Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 DraggableSidebar(
 openWidth: AppBreakpoints.sidebarWidth(context),
 child: InitiationLikeSidebar(
 activeItemLabel: 'Project Plan - Condensed Project Summary'),
 ),
 Expanded(
 child: Stack(
 children: [
 MobileSidebarHamburger(
 sidebar: const InitiationLikeSidebar(
 activeItemLabel: 'Project Plan - Level 1 - Project Schedule',
 ),
 ),
 _loading
 ? const Center(child: CircularProgressIndicator())
 : SingleChildScrollView(
 padding: EdgeInsets.symmetric(
 horizontal: horizontalPadding, vertical: 24),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 _buildHeader(isMobile),
 const SizedBox(height: 20),
 PlanningAiNotesCard(
 title: 'Notes',
 sectionLabel: 'Condensed Project Summary',
 noteKey:
 'planning_project_plan_condensed_notes',
 checkpoint: 'project_plan_condensed_summary',
 description:
 'Capture executive-level insights and recommendations.',
 ),
 const SizedBox(height: 24),
 _buildExecutiveSummarySection(),
 const SizedBox(height: 24),
 _buildKpiGrid(isMobile),
 const SizedBox(height: 24),
 _buildDetailsSection(isMobile),
 const SizedBox(height: 24),
 LaunchPhaseNavigation(
 backLabel: PlanningPhaseNavigation.backLabel(
 'project_plan_condensed_summary'),
 nextLabel: PlanningPhaseNavigation.nextLabel(
 'project_plan_condensed_summary'),
 onBack: () =>
 PlanningPhaseNavigation.goToPrevious(
 context,
 'project_plan_condensed_summary'),
 onNext: () => PlanningPhaseNavigation.goToNext(
 context, 'project_plan_condensed_summary'),
 ),
 const SizedBox(height: 80),
 ],
 ),
 ),
 const Positioned(
 right: 24,
 bottom: 24,
 child: KazAiChatBubble(positioned: false)),
 ],
 ),
 ),
 ],
 ),
 ),
 );
 }

 Widget _buildHeader(bool isMobile) {
 return Container(
 padding:
 EdgeInsets.symmetric(horizontal: isMobile ? 16 : 24, vertical: 16),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(16),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 ),
 child: isMobile
 ? Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 children: [
 const Text(
 'Condensed Project Summary',
 style: TextStyle(
 fontSize: 20,
 fontWeight: FontWeight.w700,
 color: Color(0xFF111827)),
 ),
 const Spacer(),
 _buildAIGenerateButton(),
 ],
 ),
 const SizedBox(height: 12),
 Text(
 'Executive view of schedule, cost, scope, and readiness.',
 style:
 const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
 ),
 ],
 )
 : Row(
 children: [
 const Text(
 'Condensed Project Summary',
 style: TextStyle(
 fontSize: 22,
 fontWeight: FontWeight.w700,
 color: Color(0xFF111827)),
 ),
 const Spacer(),
 Text(
 'Executive view of project status',
 style:
 const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
 ),
 const SizedBox(width: 16),
 _buildAIGenerateButton(),
 ],
 ),
 );
 }

 Widget _buildAIGenerateButton() {
 return Row(
 mainAxisSize: MainAxisSize.min,
 children: [
 if (_undoBeforeAi != null)
 IconButton(
 icon: const Icon(Icons.undo, size: 18),
 onPressed: _undo,
 tooltip: 'Undo AI generation',
 color: const Color(0xFF6B7280),
 ),
 ElevatedButton.icon(
 onPressed: _isGenerating ? null : _regenerateSummary,
 icon: _isGenerating
 ? const SizedBox(
 width: 18,
 height: 18,
 child: CircularProgressIndicator(strokeWidth: 2),
 )
 : const Icon(Icons.auto_awesome, size: 18),
 label: const Text('Generate Summary'),
 style: ElevatedButton.styleFrom(
 backgroundColor: const Color(0xFFFFC812),
 foregroundColor: Colors.white,
 elevation: 0,
 padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
 shape:
 RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
 ),
 ),
 ],
 );
 }

 Widget _buildExecutiveSummarySection() {
 return Container(
 padding: const EdgeInsets.all(20),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(16),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 children: [
 Container(
 width: 32,
 height: 32,
 decoration: BoxDecoration(
 color: const Color(0xFFEEF2FF),
 borderRadius: BorderRadius.circular(8),
 ),
 child: const Icon(Icons.summarize,
 size: 18, color: Color(0xFF6366F1)),
 ),
 const SizedBox(width: 12),
 const Text(
 'Executive Summary',
 style: TextStyle(
 fontSize: 16,
 fontWeight: FontWeight.w700,
 color: Color(0xFF111827),
 ),
 ),
 const Spacer(),
 if (_lastSavedAt != null)
 Container(
 padding:
 const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
 decoration: BoxDecoration(
 color: const Color(0xFFECFDF3),
 borderRadius: BorderRadius.circular(999),
 ),
 child: Text(
 'Saved ${TimeOfDay.fromDateTime(_lastSavedAt!).format(context)}',
 style: const TextStyle(
 fontSize: 11,
 fontWeight: FontWeight.w600,
 color: Color(0xFF16A34A),
 ),
 ),
 ),
 ],
 ),
 const SizedBox(height: 8),
 const Text(
 'Write a concise summary using BLUF format - lead with the conclusion.',
 style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
 ),
 const SizedBox(height: 16),
 VoiceTextField(
 controller: _summaryController,
 maxLines: 5,
 decoration: InputDecoration(
 hintText:
 'This project is on track to deliver [outcome] by [date]. '
 'Key milestones include [milestones]. '
 'Primary risks are [risks] and mitigation strategies are in place. '
 'Budget is tracking [status].',
 border: OutlineInputBorder(
 borderRadius: BorderRadius.circular(12),
 borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
 ),
 enabledBorder: OutlineInputBorder(
 borderRadius: BorderRadius.circular(12),
 borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
 ),
 focusedBorder: OutlineInputBorder(
 borderRadius: BorderRadius.circular(12),
 borderSide: const BorderSide(color: Color(0xFF6366F1)),
 ),
 filled: true,
 fillColor: const Color(0xFFF8FAFC),
 contentPadding: const EdgeInsets.all(16),
 ),
 style: const TextStyle(fontSize: 14, height: 1.5),
 ),
 ],
 ),
 );
 }

 Widget _buildKpiGrid(bool isMobile) {
 return Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 const Text(
 'Key Performance Indicators',
 style: TextStyle(
 fontSize: 16,
 fontWeight: FontWeight.w700,
 color: Color(0xFF111827),
 ),
 ),
 const SizedBox(height: 16),
 if (isMobile)
 Column(
 children: [
 Row(
 children: [
 Expanded(child: _buildScheduleKpi()),
 const SizedBox(width: 16),
 Expanded(child: _buildBudgetKpi()),
 ],
 ),
 const SizedBox(height: 16),
 Row(
 children: [
 Expanded(child: _buildRiskKpi()),
 const SizedBox(width: 16),
 Expanded(child: _buildScopeKpi()),
 ],
 ),
 ],
 )
 else
 Row(
 children: [
 Expanded(child: _buildScheduleKpi()),
 const SizedBox(width: 16),
 Expanded(child: _buildBudgetKpi()),
 const SizedBox(width: 16),
 Expanded(child: _buildRiskKpi()),
 const SizedBox(width: 16),
 Expanded(child: _buildScopeKpi()),
 ],
 ),
 ],
 );
 }

 Widget _buildScheduleKpi() {
 Color statusColor;
 String statusText;

 switch (_summaryData.scheduleHealth) {
 case _ScheduleHealth.onTrack:
 statusColor = const Color(0xFF10B981);
 statusText = 'On Track';
 break;
 case _ScheduleHealth.atRisk:
 statusColor = const Color(0xFFF59E0B);
 statusText = 'At Risk';
 break;
 case _ScheduleHealth.behind:
 statusColor = const Color(0xFFEF4444);
 statusText = 'Behind';
 break;
 case _ScheduleHealth.unknown:
 statusColor = const Color(0xFF6B7280);
 statusText = 'Unknown';
 break;
 }

 return _KpiCard(
 label: 'Schedule',
 icon: Icons.schedule,
 iconColor: statusColor,
 value: '${_summaryData.scheduleDaysRemaining}',
 subtitle: 'days remaining',
 status: statusText,
 statusColor: statusColor,
 );
 }

 Widget _buildBudgetKpi() {
 final budgetFormatted = _summaryData.totalBudget > 0
 ? '${_summaryData.currency} ${_formatNumber(_summaryData.totalBudget)}'
 : 'Not set';

 return _KpiCard(
 label: 'Budget',
 icon: Icons.account_balance_wallet,
 iconColor: const Color(0xFF3B82F6),
 value: budgetFormatted,
 subtitle: 'total budget',
 status: _summaryData.budgetVariance >= 0 ? 'Under Budget' : 'Over Budget',
 statusColor: _summaryData.budgetVariance >= 0
 ? const Color(0xFF10B981)
 : const Color(0xFFEF4444),
 );
 }

 Widget _buildRiskKpi() {
 Color riskColor;
 switch (_summaryData.riskLevel) {
 case _RiskLevel.high:
 riskColor = const Color(0xFFEF4444);
 break;
 case _RiskLevel.medium:
 riskColor = const Color(0xFFF59E0B);
 break;
 case _RiskLevel.low:
 riskColor = const Color(0xFF10B981);
 break;
 }

 return _KpiCard(
 label: 'Risk',
 icon: Icons.security,
 iconColor: riskColor,
 value: '${_summaryData.riskCount}',
 subtitle: 'open items',
 status: _summaryData.riskLevel.name,
 statusColor: riskColor,
 );
 }

 Widget _buildScopeKpi() {
 return _KpiCard(
 label: 'Scope',
 icon: Icons.layers,
 iconColor: const Color(0xFF8B5CF6),
 value: '${_summaryData.scopeIn.length}',
 subtitle: 'in scope items',
 status: _summaryData.scopeOut.isNotEmpty
 ? '${_summaryData.scopeOut.length} out of scope'
 : 'No exclusions',
 statusColor: _summaryData.scopeOut.isNotEmpty
 ? const Color(0xFFF59E0B)
 : const Color(0xFF10B981),
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

 Widget _buildDetailsSection(bool isMobile) {
 return Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 const Text(
 'Project Details',
 style: TextStyle(
 fontSize: 16,
 fontWeight: FontWeight.w700,
 color: Color(0xFF111827),
 ),
 ),
 const SizedBox(height: 16),
 if (isMobile)
 Column(
 children: [
 _buildMilestonesCard(),
 const SizedBox(height: 16),
 _buildScopeCard(),
 const SizedBox(height: 16),
 _buildTeamCard(),
 ],
 )
 else
 Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Expanded(flex: 2, child: _buildMilestonesCard()),
 const SizedBox(width: 16),
 Expanded(
 child: Column(
 children: [
 _buildScopeCard(),
 const SizedBox(height: 16),
 _buildTeamCard(),
 ],
 )),
 ],
 ),
 ],
 );
 }

 Widget _buildMilestonesCard() {
 return Container(
 padding: const EdgeInsets.all(20),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(16),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 children: [
 const Icon(Icons.flag, size: 18, color: Color(0xFFF59E0B)),
 const SizedBox(width: 8),
 const Text(
 'Key Milestones',
 style: TextStyle(
 fontSize: 14,
 fontWeight: FontWeight.w700,
 color: Color(0xFF111827),
 ),
 ),
 const Spacer(),
 Text(
 '${_summaryData.topMilestones.length} milestones',
 style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
 ),
 ],
 ),
 const SizedBox(height: 12),
 if (_summaryData.topMilestones.isEmpty)
 const Text(
 'No milestones defined yet.',
 style: TextStyle(
 fontSize: 12,
 color: Color(0xFF9CA3AF),
 fontStyle: FontStyle.italic),
 )
 else
 ...List.generate(_summaryData.topMilestones.length, (index) {
 final m = _summaryData.topMilestones[index];
 Color statusColor;
 switch (m.status) {
 case 'Complete':
 statusColor = const Color(0xFF10B981);
 break;
 case 'In Progress':
 statusColor = const Color(0xFF3B82F6);
 break;
 case 'At Risk':
 statusColor = const Color(0xFFEF4444);
 break;
 default:
 statusColor = const Color(0xFF6B7280);
 }

 return Padding(
 padding: const EdgeInsets.only(bottom: 8),
 child: Row(
 children: [
 Container(
 width: 24,
 height: 24,
 decoration: BoxDecoration(
 color: const Color(0xFFF3F4F6),
 borderRadius: BorderRadius.circular(4),
 ),
 child: Center(
 child: Text(
 '${index + 1}',
 style: const TextStyle(
 fontSize: 11,
 fontWeight: FontWeight.w700,
 color: Color(0xFF374151),
 ),
 ),
 ),
 ),
 const SizedBox(width: 10),
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 m.name,
 style: const TextStyle(
 fontSize: 12,
 fontWeight: FontWeight.w600,
 color: Color(0xFF111827),
 ),
 overflow: TextOverflow.ellipsis,
 ),
 if (m.dueDate.isNotEmpty)
 Text(
 m.dueDate,
 style: const TextStyle(
 fontSize: 10,
 color: Color(0xFF6B7280),
 ),
 ),
 ],
 ),
 ),
 Container(
 padding: const EdgeInsets.symmetric(
 horizontal: 8, vertical: 4),
 decoration: BoxDecoration(
 color: statusColor.withOpacity(0.12),
 borderRadius: BorderRadius.circular(999),
 ),
 child: Text(
 m.status,
 style: TextStyle(
 fontSize: 10,
 fontWeight: FontWeight.w700,
 color: statusColor,
 ),
 ),
 ),
 ],
 ),
 );
 }),
 ],
 ),
 );
 }

 Widget _buildScopeCard() {
 return Container(
 padding: const EdgeInsets.all(20),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(16),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 children: [
 const Icon(Icons.checklist, size: 18, color: Color(0xFF8B5CF6)),
 const SizedBox(width: 8),
 const Text(
 'Scope Summary',
 style: TextStyle(
 fontSize: 14,
 fontWeight: FontWeight.w700,
 color: Color(0xFF111827),
 ),
 ),
 ],
 ),
 const SizedBox(height: 12),
 if (_summaryData.scopeIn.isEmpty)
 const Text(
 'No scope defined yet.',
 style: TextStyle(
 fontSize: 12,
 color: Color(0xFF9CA3AF),
 fontStyle: FontStyle.italic),
 )
 else ...[
 const Text(
 'In Scope:',
 style: TextStyle(
 fontSize: 11,
 fontWeight: FontWeight.w600,
 color: Color(0xFF10B981),
 ),
 ),
 const SizedBox(height: 4),
 ...List.generate(_summaryData.scopeIn.length, (index) {
 return Padding(
 padding: const EdgeInsets.only(bottom: 4),
 child: Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 const Icon(Icons.check, size: 12, color: Color(0xFF10B981)),
 const SizedBox(width: 6),
 Expanded(
 child: Text(
 _summaryData.scopeIn[index],
 style: const TextStyle(
 fontSize: 11, color: Color(0xFF374151)),
 overflow: TextOverflow.ellipsis,
 ),
 ),
 ],
 ),
 );
 }),
 ],
 if (_summaryData.scopeOut.isNotEmpty) ...[
 const SizedBox(height: 12),
 const Text(
 'Out of Scope:',
 style: TextStyle(
 fontSize: 11,
 fontWeight: FontWeight.w600,
 color: Color(0xFFF59E0B),
 ),
 ),
 const SizedBox(height: 4),
 ...List.generate(_summaryData.scopeOut.length, (index) {
 return Padding(
 padding: const EdgeInsets.only(bottom: 4),
 child: Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 const Icon(Icons.close, size: 12, color: Color(0xFFF59E0B)),
 const SizedBox(width: 6),
 Expanded(
 child: Text(
 _summaryData.scopeOut[index],
 style: const TextStyle(
 fontSize: 11, color: Color(0xFF374151)),
 overflow: TextOverflow.ellipsis,
 ),
 ),
 ],
 ),
 );
 }),
 ],
 ],
 ),
 );
 }

 Widget _buildTeamCard() {
 return Container(
 padding: const EdgeInsets.all(20),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(16),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 children: [
 const Icon(Icons.people, size: 18, color: Color(0xFF3B82F6)),
 const SizedBox(width: 8),
 const Text(
 'Team Summary',
 style: TextStyle(
 fontSize: 14,
 fontWeight: FontWeight.w700,
 color: Color(0xFF111827),
 ),
 ),
 ],
 ),
 const SizedBox(height: 12),
 Row(
 children: [
 _buildTeamStatChip(
 label: '${_summaryData.teamMembers.length}',
 subtitle: 'Members',
 color: const Color(0xFF3B82F6),
 ),
 const SizedBox(width: 12),
 _buildTeamStatChip(
 label: '${_summaryData.vendorCount}',
 subtitle: 'Vendors',
 color: const Color(0xFF8B5CF6),
 ),
 ],
 ),
 if (_summaryData.teamMembers.isNotEmpty) ...[
 const SizedBox(height: 12),
 Wrap(
 spacing: 6,
 runSpacing: 6,
 children: List.generate(
 _summaryData.teamMembers.length.clamp(0, 6), (index) {
 final name = _summaryData.teamMembers[index];
 return Container(
 padding:
 const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
 decoration: BoxDecoration(
 color: const Color(0xFFF3F4F6),
 borderRadius: BorderRadius.circular(999),
 ),
 child: Text(
 name,
 style: const TextStyle(
 fontSize: 10,
 fontWeight: FontWeight.w600,
 color: Color(0xFF374151),
 ),
 ),
 );
 }),
 ),
 if (_summaryData.teamMembers.length > 6)
 Padding(
 padding: const EdgeInsets.only(top: 6),
 child: Text(
 '+${_summaryData.teamMembers.length - 6} more',
 style: const TextStyle(
 fontSize: 10,
 color: Color(0xFF6B7280),
 ),
 ),
 ),
 ],
 ],
 ),
 );
 }

 Widget _buildTeamStatChip({
 required String label,
 required String subtitle,
 required Color color,
 }) {
 return Container(
 padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
 decoration: BoxDecoration(
 color: color.withOpacity(0.1),
 borderRadius: BorderRadius.circular(8),
 ),
 child: Column(
 children: [
 Text(
 label,
 style: TextStyle(
 fontSize: 18,
 fontWeight: FontWeight.w700,
 color: color,
 ),
 ),
 Text(
 subtitle,
 style: const TextStyle(
 fontSize: 10,
 color: Color(0xFF6B7280),
 ),
 ),
 ],
 ),
 );
 }
}

class _KpiCard extends StatelessWidget {
 const _KpiCard({
 required this.label,
 required this.icon,
 required this.iconColor,
 required this.value,
 required this.subtitle,
 required this.status,
 required this.statusColor,
 });

 final String label;
 final IconData icon;
 final Color iconColor;
 final String value;
 final String subtitle;
 final String status;
 final Color statusColor;

 @override
 Widget build(BuildContext context) {
 return Container(
 padding: const EdgeInsets.all(16),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(14),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 children: [
 Container(
 width: 32,
 height: 32,
 decoration: BoxDecoration(
 color: iconColor.withOpacity(0.12),
 borderRadius: BorderRadius.circular(8),
 ),
 child: Icon(icon, size: 18, color: iconColor),
 ),
 const SizedBox(width: 10),
 Text(
 label,
 style: const TextStyle(
 fontSize: 12,
 fontWeight: FontWeight.w600,
 color: Color(0xFF6B7280),
 ),
 ),
 ],
 ),
 const SizedBox(height: 12),
 Text(
 value,
 style: TextStyle(
 fontSize: 24,
 fontWeight: FontWeight.w700,
 color: iconColor,
 ),
 ),
 Text(
 subtitle,
 style: const TextStyle(
 fontSize: 11,
 color: Color(0xFF9CA3AF),
 ),
 ),
 const SizedBox(height: 8),
 Container(
 padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
 decoration: BoxDecoration(
 color: statusColor.withOpacity(0.12),
 borderRadius: BorderRadius.circular(999),
 ),
 child: Text(
 status,
 style: TextStyle(
 fontSize: 10,
 fontWeight: FontWeight.w700,
 color: statusColor,
 ),
 ),
 ),
 ],
 ),
 );
 }
}

class _SummaryData {
 final String projectName;
 final _ScheduleHealth scheduleHealth;
 final int scheduleDaysRemaining;
 final double totalBudget;
 final String currency;
 final double budgetVariance;
 final int riskCount;
 final _RiskLevel riskLevel;
 final List<_MilestoneSummary> topMilestones;
 final List<String> scopeIn;
 final List<String> scopeOut;
 final List<String> teamMembers;
 final int vendorCount;

 const _SummaryData({
 required this.projectName,
 required this.scheduleHealth,
 required this.scheduleDaysRemaining,
 required this.totalBudget,
 required this.currency,
 required this.budgetVariance,
 required this.riskCount,
 required this.riskLevel,
 required this.topMilestones,
 required this.scopeIn,
 required this.scopeOut,
 required this.teamMembers,
 required this.vendorCount,
 });

 factory _SummaryData.empty() => const _SummaryData(
 projectName: '',
 scheduleHealth: _ScheduleHealth.unknown,
 scheduleDaysRemaining: 0,
 totalBudget: 0,
 currency: 'USD',
 budgetVariance: 0,
 riskCount: 0,
 riskLevel: _RiskLevel.low,
 topMilestones: [],
 scopeIn: [],
 scopeOut: [],
 teamMembers: [],
 vendorCount: 0,
 );
}

enum _ScheduleHealth { onTrack, atRisk, behind, unknown }

enum _RiskLevel { low, medium, high }

class _BudgetData {
 final double total;
 final String currency;
 final double variance;

 const _BudgetData({
 required this.total,
 required this.currency,
 required this.variance,
 });
}

class _RiskData {
 final int open;
 final _RiskLevel level;

 const _RiskData({required this.open, required this.level});
}

class _MilestoneSummary {
 final String name;
 final String dueDate;
 final String discipline;
 final String status;

 const _MilestoneSummary({
 required this.name,
 required this.dueDate,
 required this.discipline,
 required this.status,
 });
}

class _ScopeData {
 final List<String> inScope;
 final List<String> outScope;

 const _ScopeData({required this.inScope, required this.outScope});
}

class _TeamData {
 final List<String> members;
 final int vendors;

 const _TeamData({required this.members, required this.vendors});
}

class _ProjectPlanSectionScreen extends StatelessWidget {
 const _ProjectPlanSectionScreen({required this.config});

 final _ProjectPlanSectionConfig config;

 @override
 Widget build(BuildContext context) {
 final isMobile = AppBreakpoints.isMobile(context);
 final horizontalPadding = isMobile ? 20.0 : 32.0;

 return Scaffold(
 backgroundColor: Colors.white,
 body: SafeArea(
 child: Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 DraggableSidebar(
 openWidth: AppBreakpoints.sidebarWidth(context),
 child: InitiationLikeSidebar(
 activeItemLabel: config.activeItemLabel),
 ),
 Expanded(
 child: Stack(
 children: [
 MobileSidebarHamburger(
 sidebar: const InitiationLikeSidebar(
 activeItemLabel: 'Project Plan - Level 1 - Project Schedule',
 ),
 ),
 SingleChildScrollView(
 padding: EdgeInsets.symmetric(
 horizontal: horizontalPadding, vertical: 24),
 child: LayoutBuilder(
 builder: (context, constraints) {
 final width = constraints.maxWidth;
 const gap = 24.0;
 final twoCol = width >= 980;
 final halfWidth = twoCol ? (width - gap) / 2 : width;
 final hasContent = config.metrics.isNotEmpty ||
 config.sections.isNotEmpty;
 return Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 _TopHeader(
 title: config.title,
 onBack: () =>
 PlanningPhaseNavigation.goToPrevious(
 context, config.checkpoint),
 onForward: () => PlanningPhaseNavigation.goToNext(
 context, config.checkpoint),
 ),
 const SizedBox(height: 12),
 Text(
 config.subtitle,
 style: const TextStyle(
 fontSize: 14, color: Color(0xFF6B7280)),
 ),
 const SizedBox(height: 20),
 PlanningAiNotesCard(
 title: 'Notes',
 sectionLabel: config.title,
 noteKey: config.noteKey,
 checkpoint: config.checkpoint,
 description:
 'Capture plan assumptions, deadlines, and key constraints.',
 ),
 const SizedBox(height: 24),
 if (hasContent) ...[
 _MetricsRow(metrics: config.metrics),
 const SizedBox(height: 24),
 Wrap(
 spacing: gap,
 runSpacing: gap,
 children: config.sections
 .map((section) => SizedBox(
 width: halfWidth,
 child: _SectionCard(data: section)))
 .toList(),
 ),
 ] else
 const _SectionEmptyState(
 title: 'No schedule details yet',
 message:
 'Add schedule insights to populate this view.',
 icon: Icons.calendar_today_outlined,
 ),
 const SizedBox(height: 24),
 LaunchPhaseNavigation(
 backLabel: PlanningPhaseNavigation.backLabel(
 config.checkpoint),
 nextLabel: PlanningPhaseNavigation.nextLabel(
 config.checkpoint),
 onBack: () =>
 PlanningPhaseNavigation.goToPrevious(
 context, config.checkpoint),
 onNext: () => PlanningPhaseNavigation.goToNext(
 context, config.checkpoint),
 ),
 const SizedBox(height: 40),
 ],
 );
 },
 ),
 ),
 const Positioned(
 right: 24,
 bottom: 24,
 child: KazAiChatBubble(positioned: false)),
 ],
 ),
 ),
 ],
 ),
 ),
 );
 }
}

class _ProjectPlanSectionConfig {
 const _ProjectPlanSectionConfig({
 required this.title,
 required this.subtitle,
 required this.noteKey,
 required this.checkpoint,
 required this.activeItemLabel,
 required this.metrics,
 required this.sections,
 });

 final String title;
 final String subtitle;
 final String noteKey;
 final String checkpoint;
 final String activeItemLabel;
 final List<_MetricData> metrics;
 final List<_SectionData> sections;
}

class _TopHeader extends StatelessWidget {
 const _TopHeader({
 required this.title,
 required this.onBack,
 required this.onForward,
 });

 final String title;
 final VoidCallback onBack;
 final VoidCallback onForward;

 @override
 Widget build(BuildContext context) {
 return Row(
 children: [
 _CircleIconButton(
 icon: Icons.arrow_back_ios_new_rounded, onTap: onBack),
 const SizedBox(width: 12),
 _CircleIconButton(
 icon: Icons.arrow_forward_ios_rounded, onTap: onForward),
 const SizedBox(width: 16),
 Text(
 title,
 style: const TextStyle(
 fontSize: 22,
 fontWeight: FontWeight.w700,
 color: Color(0xFF111827)),
 ),
 const Spacer(),
 const SizedBox(width: 8),
 const _UserChip(),
 ],
 );
 }
}

class _CircleIconButton extends StatelessWidget {
 const _CircleIconButton({required this.icon, this.onTap});

 final IconData icon;
 final VoidCallback? onTap;

 @override
 Widget build(BuildContext context) {
 return InkWell(
 onTap: onTap,
 borderRadius: BorderRadius.circular(18),
 child: Container(
 width: 36,
 height: 36,
 decoration: BoxDecoration(
 color: Colors.white,
 shape: BoxShape.circle,
 border: Border.all(color: const Color(0xFFE5E7EB)),
 ),
 child: Icon(icon, size: 16, color: const Color(0xFF6B7280)),
 ),
 );
 }
}

class _UserChip extends StatelessWidget {
 const _UserChip();

 @override
 Widget build(BuildContext context) {
 final user = FirebaseAuth.instance.currentUser;
 final displayName =
 FirebaseAuthService.displayNameOrEmail(fallback: 'User');
 final email = user?.email ?? '';

 return StreamBuilder<bool>(
 stream: UserService.watchAdminStatus(),
 builder: (context, snapshot) {
 final isAdmin = snapshot.data ?? UserService.isAdminEmail(email);
 final role = isAdmin ? 'Admin' : 'Member';
 return Container(
 padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(18),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 ),
 child: Row(
 mainAxisSize: MainAxisSize.min,
 children: [
 CircleAvatar(
 radius: 16,
 backgroundColor: const Color(0xFFE5E7EB),
 backgroundImage: user?.photoURL != null
 ? NetworkImage(user!.photoURL!)
 : null,
 child: user?.photoURL == null
 ? Text(
 displayName.isNotEmpty
 ? displayName[0].toUpperCase()
 : 'U',
 style: const TextStyle(
 fontSize: 12,
 fontWeight: FontWeight.w600,
 color: Color(0xFF374151)),
 )
 : null,
 ),
 const SizedBox(width: 8),
 Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 mainAxisSize: MainAxisSize.min,
 children: [
 Text(displayName,
 style: const TextStyle(
 fontSize: 12, fontWeight: FontWeight.w600)),
 Text(role,
 style: const TextStyle(
 fontSize: 10, color: Color(0xFF6B7280))),
 ],
 ),
 const SizedBox(width: 6),
 const Icon(Icons.keyboard_arrow_down,
 size: 18, color: Color(0xFF9CA3AF)),
 ],
 ),
 );
 },
 );
 }
}

class _MetricsRow extends StatelessWidget {
 const _MetricsRow({required this.metrics});

 final List<_MetricData> metrics;

 @override
 Widget build(BuildContext context) {
 return Wrap(
 spacing: 16,
 runSpacing: 16,
 children: metrics
 .map((metric) => _MetricCard(
 label: metric.label, value: metric.value, accent: metric.color))
 .toList(),
 );
 }
}

class _MetricData {
 const _MetricData(this.label, this.value, this.color);

 final String label;
 final String value;
 final Color color;
}

class _MetricCard extends StatelessWidget {
 const _MetricCard({
 required this.label,
 required this.value,
 required this.accent,
 this.icon,
 });

 final String label;
 final String value;
 final Color accent;
 final IconData? icon;

 @override
 Widget build(BuildContext context) {
 return Container(
 width: 190,
 padding: const EdgeInsets.all(16),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(14),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 children: [
 if (icon != null) ...[
 Icon(icon, size: 14, color: accent),
 const SizedBox(width: 6),
 ],
 Text(label,
 style:
 const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
 ],
 ),
 const SizedBox(height: 6),
 Text(
 value,
 style: TextStyle(
 fontSize: 20, fontWeight: FontWeight.w700, color: accent),
 ),
 ],
 ),
 );
 }
}

class _SectionData {
 const _SectionData({
 required this.title,
 required this.subtitle,
 }) : bullets = const [],
 statusRows = const [];

 final String title;
 final String subtitle;
 final List<_BulletData> bullets;
 final List<_StatusRowData> statusRows;
}

class _BulletData {
 const _BulletData(this.text, this.isCheck);

 final String text;
 final bool isCheck;
}

class _StatusRowData {
 const _StatusRowData(this.label, this.value, this.color);

 final String label;
 final String value;
 final Color color;
}

class _SectionCard extends StatelessWidget {
 const _SectionCard({required this.data});

 final _SectionData data;

 @override
 Widget build(BuildContext context) {
 final showBullets = data.bullets.isNotEmpty;
 final showStatus = data.statusRows.isNotEmpty;

 return Container(
 padding: const EdgeInsets.all(20),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(14),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 boxShadow: const [
 BoxShadow(
 color: Color(0x0A000000), blurRadius: 10, offset: Offset(0, 6)),
 ],
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(data.title,
 style: const TextStyle(
 fontSize: 14,
 fontWeight: FontWeight.w700,
 color: Color(0xFF111827))),
 const SizedBox(height: 6),
 Text(data.subtitle,
 style: const TextStyle(
 fontSize: 12, color: Color(0xFF6B7280), height: 1.4)),
 const SizedBox(height: 16),
 if (showBullets)
 ...data.bullets.map((bullet) => _BulletRow(data: bullet)),
 if (showStatus)
 ...data.statusRows.map((row) => _StatusRow(data: row)),
 ],
 ),
 );
 }
}

class _BulletRow extends StatelessWidget {
 const _BulletRow({required this.data});

 final _BulletData data;

 @override
 Widget build(BuildContext context) {
 return Padding(
 padding: const EdgeInsets.only(bottom: 10),
 child: Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Icon(
 data.isCheck ? Icons.check_circle_outline : Icons.circle,
 size: data.isCheck ? 16 : 8,
 color: data.isCheck
 ? const Color(0xFF10B981)
 : const Color(0xFF9CA3AF),
 ),
 const SizedBox(width: 8),
 Expanded(
 child: Text(
 data.text,
 style: const TextStyle(
 fontSize: 12, color: Color(0xFF374151), height: 1.4),
 ),
 ),
 ],
 ),
 );
 }
}

class _StatusRow extends StatelessWidget {
 const _StatusRow({required this.data});

 final _StatusRowData data;

 @override
 Widget build(BuildContext context) {
 return Padding(
 padding: const EdgeInsets.only(bottom: 10),
 child: Row(
 children: [
 Expanded(
 child: Text(
 data.label,
 style: const TextStyle(fontSize: 12, color: Color(0xFF374151)),
 ),
 ),
 Container(
 padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
 decoration: BoxDecoration(
 color: data.color.withOpacity(0.12),
 borderRadius: BorderRadius.circular(999),
 ),
 child: Text(
 data.value,
 style: TextStyle(
 fontSize: 11, fontWeight: FontWeight.w700, color: data.color),
 ),
 ),
 ],
 ),
 );
 }
}

class _SectionEmptyState extends StatelessWidget {
 const _SectionEmptyState(
 {required this.title, required this.message, required this.icon});

 final String title;
 final String message;
 final IconData icon;

 @override
 Widget build(BuildContext context) {
 return Container(
 width: double.infinity,
 padding: const EdgeInsets.all(24),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(18),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 ),
 child: Row(
 children: [
 Container(
 width: 44,
 height: 44,
 decoration: BoxDecoration(
 color: const Color(0xFFFFF7ED),
 borderRadius: BorderRadius.circular(14),
 ),
 child: Icon(icon, color: const Color(0xFFF59E0B)),
 ),
 const SizedBox(width: 14),
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(title,
 style: const TextStyle(
 fontSize: 14,
 fontWeight: FontWeight.w700,
 color: Color(0xFF111827))),
 const SizedBox(height: 6),
 Text(message,
 style: const TextStyle(
 fontSize: 12, color: Color(0xFF6B7280))),
 ],
 ),
 ),
 ],
 ),
 );
 }
}
