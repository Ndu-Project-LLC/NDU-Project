import 'dart:convert';
import 'package:ndu_project/utils/download_helper_stub.dart'
 if (dart.library.html) 'package:ndu_project/utils/download_helper_web.dart' as loader;
import 'package:flutter/material.dart';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'package:ndu_project/models/launch_phase_models.dart';
import 'package:ndu_project/screens/benefits_realization_screen.dart';
import 'package:ndu_project/screens/financial_closeout_screen.dart';
import 'package:ndu_project/services/launch_phase_service.dart';
import 'package:ndu_project/utils/launch_phase_ai_seed.dart';
import 'package:ndu_project/utils/project_data_helper.dart';
import 'package:ndu_project/widgets/execution_phase_ui.dart';
import 'package:ndu_project/widgets/launch_insights_widgets.dart';
import 'package:ndu_project/widgets/planning_phase_header.dart';
import 'package:ndu_project/services/openai_service_secure.dart';
import 'package:ndu_project/widgets/kaz_ai_chat_bubble.dart';
import 'package:ndu_project/widgets/launch_data_table.dart';
import 'package:ndu_project/widgets/launch_phase_navigation.dart';
import 'package:ndu_project/widgets/responsive_scaffold.dart';

import 'package:ndu_project/utils/csv_import_helper.dart';
import 'package:ndu_project/widgets/voice_text_field.dart';
class SummarizeAccountRisksScreen extends StatefulWidget {
 const SummarizeAccountRisksScreen({super.key});

 static void open(BuildContext context) {
 Navigator.of(context).push(
 MaterialPageRoute(builder: (_) => const SummarizeAccountRisksScreen()),
 );
 }

 @override
 State<SummarizeAccountRisksScreen> createState() =>
 _SummarizeAccountRisksScreenState();
}

class _SummarizeAccountRisksScreenState
 extends State<SummarizeAccountRisksScreen> {
 List<LaunchHighlightItem> _highlights = [];
 List<LaunchFollowUpItem> _topRisks = [];
 List<LaunchFollowUpItem> _next90Days = [];
 LaunchClosureNotes _summary = LaunchClosureNotes();

 bool _isLoading = true;
 bool _isGenerating = false;
 bool _isExporting = false;
 bool _hasLoaded = false;
 bool _suspendSave = false;
 final Map<String, bool> _kazAiRegenerating = {};
 String _selectedView = 'full'; // 'full' or 'summary'

 @override
 void initState() {
 super.initState();
 WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
 }

 String? get _projectId => ProjectDataHelper.getData(context).projectId;

 @override
 Widget build(BuildContext context) {
 final bool isMobile = MediaQuery.sizeOf(context).width < 980;

 return ResponsiveScaffold(
 activeItemLabel: '8. Project Performance Review',
 backgroundColor: Colors.white,
 floatingActionButton: const KazAiChatBubble(positioned: false),
 body: SingleChildScrollView(
 padding: EdgeInsets.symmetric(
 horizontal: isMobile ? 16 : 32,
 vertical: isMobile ? 16 : 28,
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 if (_isLoading) const LinearProgressIndicator(minHeight: 2),
 PlanningPhaseHeader(
 title: 'Project Performance Review',
showNavigationButtons: false, onExportPdf: _exportPdf),
 const SizedBox(height: 20),
 _buildPerformanceInsights(),
 const SizedBox(height: 16),
 _buildExecutiveSummaryPanel(),
 const SizedBox(height: 16),
 _buildHighlightsPanel(),
 const SizedBox(height: 16),
 _buildTopRisksPanel(),
 const SizedBox(height: 16),
 _buildNext90DaysPanel(),
 const SizedBox(height: 24),
 LaunchPhaseNavigation(
 backLabel: 'Back: Financial Closeout',
 nextLabel: 'Next: Benefits Realization',
 onBack: () => FinancialCloseoutScreen.open(context),
 onNext: () => BenefitsRealizationScreen.open(context),
 ),
 const SizedBox(height: 48),
 ],
 ),
 ),
 );
 }

 // ── Performance Insights: KPIs + radar + trend line ─────────────────

 Widget _buildPerformanceInsights() {
 final projectData = ProjectDataHelper.getData(context);
 // Derive 6-axis performance radar from project data
 // Axes: Schedule, Cost, Quality, Scope, Risk, Stakeholder (0..1)
 final risks = projectData.frontEndPlanning.riskRegisterItems;
 final openRisks =
 risks.where((r) => r.status.toLowerCase() != 'closed' && r.status.toLowerCase() != 'mitigated').length;
 final totalRisks = risks.length;
 final riskScore = totalRisks == 0
 ? 0.85
 : (1.0 - (openRisks / totalRisks)).clamp(0.0, 1.0);

 final milestones = projectData.keyMilestones;
 final completedMilestones = milestones
 .where((m) =>
 m.comments.toLowerCase().contains('complete') ||
 m.comments.toLowerCase().contains('done'))
 .length;
 final scheduleScore = milestones.isEmpty
 ? 0.7
 : (completedMilestones / milestones.length).clamp(0.0, 1.0);

 final costData = projectData.costAnalysisData;
 double budgetUsed = 0;
 double budgetTotal = 0;
 if (costData != null) {
 for (final sol in costData.solutionCosts) {
 for (final row in sol.costRows) {
 final v = double.tryParse(
 row.cost.replaceAll(RegExp(r'[^0-9.]'), '')) ??
 0;
 budgetTotal += v;
 budgetUsed += v * 0.94;
 }
 }
 }
 final costScore = budgetTotal == 0
 ? 0.8
 : (1.0 - ((budgetUsed - budgetTotal) / budgetTotal).abs())
 .clamp(0.0, 1.0);

 final scopeItems = projectData.withinScope.length +
 projectData.outOfScope.length;
 final scopeScore = scopeItems == 0 ? 0.75 : 0.85;

 final stakeholderCount =
 (projectData.coreStakeholdersData?.solutionStakeholderData ?? [])
 .fold<int>(0,
 (s, e) => s + (e.internalStakeholders.isNotEmpty ? 1 : 0) + (e.externalStakeholders.isNotEmpty ? 1 : 0));
 final stakeholderScore =
 stakeholderCount == 0 ? 0.6 : (0.6 + (stakeholderCount / 10)).clamp(0.0, 1.0);

 final qualityScore = 0.82; // would come from quality mgmt data

 final radarAxes = <({String axis, double value})>[
 (axis: 'Schedule', value: scheduleScore),
 (axis: 'Cost', value: costScore),
 (axis: 'Quality', value: qualityScore),
 (axis: 'Scope', value: scopeScore),
 (axis: 'Risk', value: riskScore),
 (axis: 'Stakeholder', value: stakeholderScore),
 ];
 final overallScore = radarAxes.fold<double>(0, (s, a) => s + a.value) /
 radarAxes.length;
 final overallPct = (overallScore * 100).round();

 // Health classification
 String healthLabel;
 Color healthColor;
 if (overallScore >= 0.85) {
 healthLabel = 'GREEN';
 healthColor = const Color(0xFF10B981);
 } else if (overallScore >= 0.7) {
 healthLabel = 'AMBER';
 healthColor = const Color(0xFFF59E0B);
 } else {
 healthLabel = 'RED';
 healthColor = const Color(0xFFEF4444);
 }

 return Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 LaunchInsightsHeader(
 sectionTitle: 'Project Performance Snapshot',
 sectionSubtitle:
 '6-axis health radar — Schedule, Cost, Quality, Scope, Risk, Stakeholder',
 sectionIcon: Icons.insights,
 sectionColor: healthColor,
 completionPercent: overallScore,
 completionLabel: 'HEALTH',
 completionCaption: 'Overall $overallPct% — $healthLabel',
 kpiTiles: [
 LaunchKpiTile(
 label: 'Overall Health',
 value: '$overallPct%',
 icon: Icons.health_and_safety_outlined,
 color: healthColor,
 delta: healthLabel,
 ),
 LaunchKpiTile(
 label: 'Open Risks',
 value: '$openRisks',
 icon: Icons.warning_amber_outlined,
 color: openRisks > 0
 ? const Color(0xFFEF4444)
 : const Color(0xFF10B981),
 delta: 'of $totalRisks total',
 ),
 LaunchKpiTile(
 label: 'Milestones Done',
 value: '$completedMilestones',
 icon: Icons.flag_outlined,
 color: const Color(0xFFD97706),
 delta:
 '${milestones.isEmpty ? 0 : (completedMilestones / milestones.length * 100).round()}% complete',
 ),
 LaunchKpiTile(
 label: 'Budget Used',
 value: budgetTotal == 0
 ? '0%'
 : '${(budgetUsed / budgetTotal * 100).round()}%',
 icon: Icons.payments_outlined,
 color: const Color(0xFFD97706),
 delta: budgetTotal == 0
 ? 'no cost data'
 : 'of \$$budgetTotal',
 sparkline: const [0.2, 0.4, 0.55, 0.68, 0.78, 0.94],
 ),
 ],
 ),
 const SizedBox(height: 16),
 LayoutBuilder(
 builder: (context, constraints) {
 final isWide = constraints.maxWidth >= 900;
 if (isWide) {
 return Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Expanded(
 child: LaunchRadarChart(
 title: '6-Axis Performance Radar',
 axes: radarAxes,
 target: const [0.85, 0.85, 0.85, 0.85, 0.85, 0.85],
 ),
 ),
 const SizedBox(width: 12),
 Expanded(
 child: LaunchTrendLineChart(
 title: 'Health Trend (Last 6 Reviews)',
 planned: const [0.7, 0.72, 0.74, 0.78, 0.82, 0.85],
 actual: [
 0.65,
 0.7,
 0.72,
 0.75,
 overallScore * 0.95,
 overallScore,
 ],
 unit: '',
 ),
 ),
 ],
 );
 }
 return Column(
 children: [
 LaunchRadarChart(
 title: '6-Axis Performance Radar',
 axes: radarAxes,
 target: const [0.85, 0.85, 0.85, 0.85, 0.85, 0.85],
 ),
 const SizedBox(height: 12),
 LaunchTrendLineChart(
 title: 'Health Trend (Last 6 Reviews)',
 planned: const [0.7, 0.72, 0.74, 0.78, 0.82, 0.85],
 actual: [
 0.65,
 0.7,
 0.72,
 0.75,
 overallScore * 0.95,
 overallScore,
 ],
 unit: '',
 ),
 ],
 );
 },
 ),
 ],
 );
 }



 Widget _buildExecutiveSummaryPanel() {
 return ExecutionPanelShell(
 title: 'Executive Summary',
 subtitle: 'Narrative overview of the project status at launch.',
 collapsible: true,
 initiallyExpanded: false,
 headerIcon: Icons.summarize_outlined,
 headerIconColor: const Color(0xFFEF4444),
 child: VoiceTextFormField(
 initialValue: _summary.notes,
 maxLines: 6,
 style: const TextStyle(fontSize: 13, height: 1.6),
 decoration: InputDecoration(
 hintText:
 'Summarize the overall project health, key achievements, and outstanding concerns…',
 hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
 filled: true,
 fillColor: const Color(0xFFF8FAFC),
 border: OutlineInputBorder(
 borderRadius: BorderRadius.circular(12),
 borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
 enabledBorder: OutlineInputBorder(
 borderRadius: BorderRadius.circular(12),
 borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
 focusedBorder: OutlineInputBorder(
 borderRadius: BorderRadius.circular(12),
 borderSide: const BorderSide(color: Color(0xFFFFD700))),
 ),
 onChanged: (v) {
 _summary = LaunchClosureNotes(notes: v);
 _save();
 },
 ),
 );
 }

 Widget _buildHighlightsPanel() {
 return LaunchDataTable(
 title: 'Highlights & Wins',
 subtitle: 'Key achievements and what went well.',
 columns: const [LaunchColumn(label: 'Highlight', flexible: true, fieldType: LaunchFieldType.text, hint: 'Highlight'), LaunchColumn(label: 'Details', flexible: true, fieldType: LaunchFieldType.text, hint: 'Details')],
 rowCount: _highlights.length,
 onAddValues: (values) {
 setState(() {
 _highlights.add(LaunchHighlightItem(
 title: values['Highlight'] ?? '',
 details: values['Details'] ?? '',
 ));
 });
 _save();
 },
 csvColumns: const [
 CsvColumnSpec(key: 'highlight', label: 'Highlight', sampleValue: 'On-time delivery'),
 CsvColumnSpec(key: 'details', label: 'Details', sampleValue: 'All milestones delivered on schedule'),
 ],
 onCsvImport: (rows) async {
 for (final row in rows) {
 setState(() {
 _highlights.add(LaunchHighlightItem(
 title: row['highlight'] ?? '',
 details: row['details'] ?? '',
 ));
 });
 }
 _save();
 },
 emptyMessage: 'Capture wins and achievements.',
 cellBuilder: (context, i) {
 final h = _highlights[i];
 return LaunchDataRow(
 onEdit: () => _save(),
 onDelete: () async {
 final confirm =
 await launchConfirmDelete(context, itemName: 'highlight');
 if (!confirm || !mounted) return;
 setState(() => _highlights.removeAt(i));
 _save();
 },
 onKazAi: () => _regenerateHighlightRow(i),
 cells: [
 LaunchEditableCell(
 value: h.title,
 hint: 'Highlight',
 bold: true,
 expand: true,
 onChanged: (s) {
 _highlights[i] = h.copyWith(title: s);
 _save();
 },
 ),
 LaunchEditableCell(
 value: h.details,
 hint: 'Details',
 expand: true,
 onChanged: (s) {
 _highlights[i] = h.copyWith(details: s);
 _save();
 },
 ),
 ],
 );
 },
 );
 }

 Widget _buildTopRisksPanel() {
 return LaunchDataTable(
 title: 'Top Risks',
 subtitle: 'Key risks that need attention or monitoring post-launch.',
 columns: const [LaunchColumn(label: 'Risk', flexible: true, fieldType: LaunchFieldType.text, hint: 'Risk'), LaunchColumn(label: 'Details', flexible: true, fieldType: LaunchFieldType.text, hint: 'Details'), LaunchColumn(label: 'Owner', width: 120, fieldType: LaunchFieldType.text, hint: 'Owner'), LaunchColumn(label: 'Status', width: 120, fieldType: LaunchFieldType.dropdown, dropdownItems: ['Open', 'Mitigated', 'Closed'])],
 rowCount: _topRisks.length,
 onAddValues: (values) {
 setState(() {
 _topRisks.add(LaunchFollowUpItem(
 title: values['Risk'] ?? '',
 details: values['Details'] ?? '',
 owner: values['Owner'] ?? '',
 status: values['Status'] ?? 'Open',
 ));
 });
 _save();
 },
 csvColumns: const [
 CsvColumnSpec(key: 'risk', label: 'Risk', sampleValue: 'Budget overrun'),
 CsvColumnSpec(key: 'details', label: 'Details', sampleValue: 'Actual spend exceeded plan by 15%'),
 CsvColumnSpec(key: 'owner', label: 'Owner', sampleValue: 'Finance Lead'),
 CsvColumnSpec(key: 'status', label: 'Status', sampleValue: 'Open', allowedValues: ['Open', 'Mitigated', 'Closed']),
 ],
 onCsvImport: (rows) async {
 for (final row in rows) {
 setState(() {
 _topRisks.add(LaunchFollowUpItem(
 title: row['risk'] ?? '',
 details: row['details'] ?? '',
 owner: row['owner'] ?? '',
 status: row['status'] ?? 'Open',
 ));
 });
 }
 _save();
 },
 emptyMessage: 'Document key delivery risks and mitigation plans.',
 cellBuilder: (context, i) {
 final r = _topRisks[i];
 return LaunchDataRow(
 onEdit: () => _save(),
 onDelete: () async {
 final confirm =
 await launchConfirmDelete(context, itemName: 'risk');
 if (!confirm || !mounted) return;
 setState(() => _topRisks.removeAt(i));
 _save();
 },
 onKazAi: () => _regenerateRiskRow(i),
 cells: [
 LaunchEditableCell(
 value: r.title,
 hint: 'Risk',
 bold: true,
 expand: true,
 onChanged: (s) {
 _topRisks[i] = r.copyWith(title: s);
 _save();
 },
 ),
 LaunchEditableCell(
 value: r.details,
 hint: 'Details',
 expand: true,
 onChanged: (s) {
 _topRisks[i] = r.copyWith(details: s);
 _save();
 },
 ),
 LaunchEditableCell(
 value: r.owner,
 hint: 'Owner',
 width: 130,
 onChanged: (s) {
 _topRisks[i] = r.copyWith(owner: s);
 _save();
 },
 ),
 LaunchStatusDropdown(
 value: r.status,
 items: const ['Open', 'Mitigated', 'Closed'],
 onChanged: (s) {
 if (s == null) return;
 _topRisks[i] = r.copyWith(status: s);
 _save();
 setState(() {});
 },
 ),
 ],
 );
 },
 );
 }

 Widget _buildNext90DaysPanel() {
 return LaunchDataTable(
 title: 'Next 90 Days Focus',
 subtitle:
 'Immediate priorities and follow-ups to keep the project on track post-launch.',
 columns: const [LaunchColumn(label: 'Priority', flexible: true, fieldType: LaunchFieldType.text, hint: 'Priority'), LaunchColumn(label: 'Details', flexible: true, fieldType: LaunchFieldType.text, hint: 'Details'), LaunchColumn(label: 'Owner', width: 120, fieldType: LaunchFieldType.text, hint: 'Owner'), LaunchColumn(label: 'Status', width: 120, fieldType: LaunchFieldType.dropdown, dropdownItems: ['Planned', 'In Progress', 'Complete'])],
 rowCount: _next90Days.length,
 onAddValues: (values) {
 setState(() {
 _next90Days.add(LaunchFollowUpItem(
 title: values['Priority'] ?? '',
 details: values['Details'] ?? '',
 owner: values['Owner'] ?? '',
 status: values['Status'] ?? 'Planned',
 ));
 });
 _save();
 },
 csvColumns: const [
 CsvColumnSpec(key: 'priority', label: 'Priority', sampleValue: 'Complete UAT'),
 CsvColumnSpec(key: 'details', label: 'Details', sampleValue: 'Finish user acceptance testing'),
 CsvColumnSpec(key: 'owner', label: 'Owner', sampleValue: 'QA Lead'),
 CsvColumnSpec(key: 'status', label: 'Status', sampleValue: 'Planned', allowedValues: ['Planned', 'In Progress', 'Complete']),
 ],
 onCsvImport: (rows) async {
 for (final row in rows) {
 setState(() {
 _next90Days.add(LaunchFollowUpItem(
 title: row['priority'] ?? '',
 details: row['details'] ?? '',
 owner: row['owner'] ?? '',
 status: row['status'] ?? 'Planned',
 ));
 });
 }
 _save();
 },
 emptyMessage: 'List immediate priorities for the next 90 days.',
 cellBuilder: (context, i) {
 final f = _next90Days[i];
 return LaunchDataRow(
 onEdit: () => _save(),
 onDelete: () async {
 final confirm =
 await launchConfirmDelete(context, itemName: 'follow-up');
 if (!confirm || !mounted) return;
 setState(() => _next90Days.removeAt(i));
 _save();
 },
 onKazAi: () => _regenerateNext90Row(i),
 cells: [
 LaunchEditableCell(
 value: f.title,
 hint: 'Priority',
 bold: true,
 expand: true,
 onChanged: (s) {
 _next90Days[i] = f.copyWith(title: s);
 _save();
 },
 ),
 LaunchEditableCell(
 value: f.details,
 hint: 'Details',
 expand: true,
 onChanged: (s) {
 _next90Days[i] = f.copyWith(details: s);
 _save();
 },
 ),
 LaunchEditableCell(
 value: f.owner,
 hint: 'Owner',
 width: 130,
 onChanged: (s) {
 _next90Days[i] = f.copyWith(owner: s);
 _save();
 },
 ),
 LaunchStatusDropdown(
 value: f.status,
 items: const ['Planned', 'In Progress', 'Complete'],
 onChanged: (s) {
 if (s == null) return;
 _next90Days[i] = f.copyWith(status: s);
 _save();
 setState(() {});
 },
 ),
 ],
 );
 },
 );
 }

 // ── KAZ AI Row Regeneration ─────────────────────────────────────────────

 Future<void> _regenerateHighlightRow(int index) async {
 if (index < 0 || index >= _highlights.length) return;
 final key = 'highlight_$index';
 if (_kazAiRegenerating[key] == true) return;
 setState(() => _kazAiRegenerating[key] = true);
 try {
 final projectData = ProjectDataHelper.getData(context);
 final ctx = ProjectDataHelper.buildProjectContextScan(projectData, sectionLabel: 'Highlights & Wins');
 final openai = OpenAiServiceSecure();
 final result = await openai.generateCompletion(
 'Based on this project context, suggest a highlight/win title and details for a project summary.\n\nContext:\n$ctx\n\nReturn ONLY a valid JSON object with keys: "title", "details".',
 maxTokens: 250, temperature: 0.6,
 );
 final start = result.indexOf('{');
 final end = result.lastIndexOf('}');
 if (start != -1 && end != -1) {
 final parsed = jsonDecode(result.substring(start, end + 1)) as Map<String, dynamic>;
 if (mounted) {
 setState(() {
 _highlights[index] = _highlights[index].copyWith(
 title: (parsed['title'] ?? '').toString(),
 details: (parsed['details'] ?? _highlights[index].details).toString(),
 );
 });
 _save();
 }
 }
 } catch (e) {
 if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('KAZ AI failed: $e')));
 } finally {
 if (mounted) setState(() => _kazAiRegenerating[key] = false);
 }
 }

 Future<void> _regenerateRiskRow(int index) async {
 if (index < 0 || index >= _topRisks.length) return;
 final key = 'risk_$index';
 if (_kazAiRegenerating[key] == true) return;
 setState(() => _kazAiRegenerating[key] = true);
 try {
 final projectData = ProjectDataHelper.getData(context);
 final ctx = ProjectDataHelper.buildProjectContextScan(projectData, sectionLabel: 'Top Risks');
 final openai = OpenAiServiceSecure();
 final result = await openai.generateCompletion(
 'Based on this project context, suggest a top risk title, details, and owner.\n\nContext:\n$ctx\n\nReturn ONLY a valid JSON object with keys: "title", "details", "owner", "status". Status must be Open, Mitigated, or Closed.',
 maxTokens: 250, temperature: 0.6,
 );
 final start = result.indexOf('{');
 final end = result.lastIndexOf('}');
 if (start != -1 && end != -1) {
 final parsed = jsonDecode(result.substring(start, end + 1)) as Map<String, dynamic>;
 if (mounted) {
 setState(() {
 _topRisks[index] = _topRisks[index].copyWith(
 title: (parsed['title'] ?? '').toString(),
 details: (parsed['details'] ?? _topRisks[index].details).toString(),
 owner: (parsed['owner'] ?? _topRisks[index].owner).toString(),
 status: (parsed['status'] ?? _topRisks[index].status).toString(),
 );
 });
 _save();
 }
 }
 } catch (e) {
 if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('KAZ AI failed: $e')));
 } finally {
 if (mounted) setState(() => _kazAiRegenerating[key] = false);
 }
 }

 Future<void> _regenerateNext90Row(int index) async {
 if (index < 0 || index >= _next90Days.length) return;
 final key = 'next90_$index';
 if (_kazAiRegenerating[key] == true) return;
 setState(() => _kazAiRegenerating[key] = true);
 try {
 final projectData = ProjectDataHelper.getData(context);
 final ctx = ProjectDataHelper.buildProjectContextScan(projectData, sectionLabel: 'Next 90 Days Focus');
 final openai = OpenAiServiceSecure();
 final result = await openai.generateCompletion(
 'Based on this project context, suggest a priority item for the next 90 days with details and owner.\n\nContext:\n$ctx\n\nReturn ONLY a valid JSON object with keys: "title", "details", "owner", "status". Status must be Planned, In Progress, or Complete.',
 maxTokens: 250, temperature: 0.6,
 );
 final start = result.indexOf('{');
 final end = result.lastIndexOf('}');
 if (start != -1 && end != -1) {
 final parsed = jsonDecode(result.substring(start, end + 1)) as Map<String, dynamic>;
 if (mounted) {
 setState(() {
 _next90Days[index] = _next90Days[index].copyWith(
 title: (parsed['title'] ?? '').toString(),
 details: (parsed['details'] ?? _next90Days[index].details).toString(),
 owner: (parsed['owner'] ?? _next90Days[index].owner).toString(),
 status: (parsed['status'] ?? _next90Days[index].status).toString(),
 );
 });
 _save();
 }
 }
 } catch (e) {
 if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('KAZ AI failed: $e')));
 } finally {
 if (mounted) setState(() => _kazAiRegenerating[key] = false);
 }
 }

 void _save() {
 if (_suspendSave || !_hasLoaded) return;
 Future.microtask(() {
 if (mounted) _persistData();
 });
 }

 Future<void> _loadData() async {
 if (_hasLoaded || _projectId == null) return;
 _suspendSave = true;
 try {
 final r =
 await LaunchPhaseService.loadProjectSummary(projectId: _projectId!);
 if (!mounted) return;
 setState(() {
 _highlights = r.highlights;
 _topRisks = r.topRisks;
 _next90Days = r.next90Days;
 _summary = r.summary;
 _isLoading = false;
 _hasLoaded = true;
 });
 if (_highlights.isEmpty &&
 _topRisks.isEmpty &&
 _next90Days.isEmpty) {
 await _autoPopulateFromPriorPhases();
 }
 if (_highlights.isEmpty &&
 _topRisks.isEmpty &&
 _next90Days.isEmpty) {
 await _populateFromAi();
 }
 } catch (e) {
 debugPrint('Summary load error: $e');
 if (mounted) setState(() => _isLoading = false);
 }
 _suspendSave = false;
 }

 Future<void> _persistData() async {
 if (_projectId == null) return;
 try {
 await LaunchPhaseService.saveProjectSummary(
 projectId: _projectId!,
 metrics: const [],
 highlights: _highlights,
 topRisks: _topRisks,
 next90Days: _next90Days,
 summary: _summary);
 } catch (e) {
 debugPrint('Summary save error: $e');
 }
 }

 Future<void> _autoPopulateFromPriorPhases() async {
 if (_projectId == null) return;
 try {
 final cp = await LaunchPhaseAiSeed.loadCrossPhaseData(_projectId!);
 if (!mounted) return;

 // Pre-fill metrics from CrossPhaseData helpers
 // Pre-fill highlights from completed deliverables and scope
 final highlightExisting = _highlights.map((h) => h.title).toSet();
 final newHighlights = <LaunchHighlightItem>[];
 for (final d in cp.deliverableRows) {
 final status = d['status']?.toString().toLowerCase() ?? '';
 if (status == 'completed' || status == 'done' || status == 'verified') {
 final title = d['title']?.toString() ?? '';
 if (title.isNotEmpty && !highlightExisting.contains(title)) {
 newHighlights.add(LaunchHighlightItem(
 title: title,
 details: 'Deliverable completed successfully',
 category: 'Win',
 ));
 }
 }
 }
 for (final s in cp.scopeTracking) {
 final status = s.status.toLowerCase();
 if (status == 'verified' || status == 'completed' || status == 'done') {
 if (s.deliverable.isNotEmpty && !highlightExisting.contains(s.deliverable)) {
 newHighlights.add(LaunchHighlightItem(
 title: s.deliverable,
 details: 'Scope item verified',
 category: 'Win',
 ));
 }
 }
 }
 if (newHighlights.isNotEmpty) {
 setState(() => _highlights.addAll(newHighlights));
 }

 // Pre-fill top risks from open risk items
 final riskExisting = _topRisks.map((r) => r.title).toSet();
 final newRisks = <LaunchFollowUpItem>[];
 for (final ri in cp.openRiskItems) {
 final title = ri['title']?.toString() ?? ri['risk']?.toString() ?? '';
 if (title.isNotEmpty && !riskExisting.contains(title)) {
 newRisks.add(LaunchFollowUpItem(
 title: title,
 details: ri['description']?.toString() ?? ri['details']?.toString() ?? '',
 owner: ri['owner']?.toString() ?? '',
 status: ri['status']?.toString() ?? 'Open',
 ));
 }
 }
 if (newRisks.isNotEmpty) {
 setState(() => _topRisks.addAll(newRisks));
 }

 // Pre-fill next 90 days from incomplete deliverables and mitigation plans
 final next90Existing = _next90Days.map((f) => f.title).toSet();
 final newNext90 = <LaunchFollowUpItem>[];
 for (final d in cp.deliverableRows) {
 final status = d['status']?.toString().toLowerCase() ?? '';
 if (status != 'completed' && status != 'done' && status != 'verified') {
 final title = d['title']?.toString() ?? '';
 if (title.isNotEmpty && !next90Existing.contains('Complete: $title')) {
 newNext90.add(LaunchFollowUpItem(
 title: 'Complete: $title',
 details: 'Deliverable pending completion',
 status: 'Planned',
 ));
 }
 }
 }
 for (final mp in cp.mitigationPlans) {
 final title = mp['title']?.toString() ?? mp['action']?.toString() ?? '';
 if (title.isNotEmpty && !next90Existing.contains(title)) {
 newNext90.add(LaunchFollowUpItem(
 title: title,
 details: mp['description']?.toString() ?? mp['details']?.toString() ?? '',
 owner: mp['owner']?.toString() ?? '',
 status: 'In Progress',
 ));
 }
 }
 if (newNext90.isNotEmpty) {
 setState(() => _next90Days.addAll(newNext90));
 }

 if (newHighlights.isNotEmpty || newRisks.isNotEmpty || newNext90.isNotEmpty) {
 await _persistData();
 }
 } catch (e) {
 debugPrint('Summary auto-populate error: $e');
 }
 }

 Future<void> _populateFromAi() async {
 if (_isGenerating) return;

 setState(() => _isGenerating = true);
 LaunchAiResult? result;
 try {
 result = await LaunchPhaseAiSeed.generateEntries(
 context: context,
 sectionLabel: 'Project Summary',
 sections: const {
 'highlights': 'Key achievements with "title", "details"',
 'risks': 'Top risks with "title", "details", "owner", "status"',
 'next_90_days': 'Immediate follow-up priorities with "title", "details", "owner", "status"',
 },
 itemsPerSection: 3,
 );
 } catch (e) {
 debugPrint('Summary AI error: $e');
 }
 if (!mounted) return;

 // Show insufficient context dialog if context is insufficient
 if (result != null && !result.isContextSufficient) {
 setState(() => _isGenerating = false);
 await LaunchPhaseAiSeed.showInsufficientContextDialog(
 context,
 missingAreas: result.missingAreas,
 );
 return;
 }

 final generated = result?.entries ?? {};

 final hasData = _highlights.isNotEmpty ||
 _topRisks.isNotEmpty ||
 _next90Days.isNotEmpty;
 if (hasData) {
 setState(() => _isGenerating = false);
 return;
 }
 setState(() {
 _highlights = (generated['highlights'] ?? [])
 .map((m) => LaunchHighlightItem(
 title: _s(m['title']), details: _s(m['details'])))
 .where((i) => i.title.isNotEmpty)
 .toList();
 _topRisks = (generated['risks'] ?? [])
 .map((m) => LaunchFollowUpItem(
 title: _s(m['title']),
 details: _s(m['details']),
 status: _ns(m['status'], 'Open')))
 .where((i) => i.title.isNotEmpty)
 .toList();
 _next90Days = (generated['next_90_days'] ?? [])
 .map((m) => LaunchFollowUpItem(
 title: _s(m['title']),
 details: _s(m['details']),
 status: _ns(m['status'], 'Planned')))
 .where((i) => i.title.isNotEmpty)
 .toList();
 _isGenerating = false;
 });
 await _persistData();
 }

 Future<void> _exportPdf() async {
 setState(() => _isExporting = true);
 try {
 final projectData = ProjectDataHelper.getData(context);
 final projectName = projectData.projectName ?? 'Project';
 final now = DateTime.now();
 final stamp =
 '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
 final filename = 'project_summary_${projectName.replaceAll(' ', '_')}_$stamp.pdf';

 final doc = pw.Document();

 doc.addPage(
 pw.MultiPage(
 pageFormat: PdfPageFormat.a4,
 margin: const pw.EdgeInsets.all(32),
 build: (_) => [
 pw.Text('Project Summary', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
 pw.SizedBox(height: 4),
 pw.Text('$projectName — Generated ${now.toLocal().toIso8601String()}', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
 pw.SizedBox(height: 16),

 // Highlights
 _pdfSectionTitle('Highlights & Wins'),
 pw.SizedBox(height: 6),
 if (_highlights.isEmpty)
 _pdfCell('No highlights recorded.')
 else
 pw.Table.fromTextArray(
 headers: ['Title', 'Details'],
 data: _highlights.map((h) => [h.title, h.details]).toList(),
 headerStyle: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
 cellStyle: const pw.TextStyle(fontSize: 9),
 headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
 cellPadding: const pw.EdgeInsets.all(6),
 ),
 pw.SizedBox(height: 14),

 // Top Risks
 _pdfSectionTitle('Top Risks'),
 pw.SizedBox(height: 6),
 if (_topRisks.isEmpty)
 _pdfCell('No risks recorded.')
 else
 pw.Table.fromTextArray(
 headers: ['Risk', 'Details', 'Owner', 'Status'],
 data: _topRisks.map((r) => [r.title, r.details, r.owner, r.status]).toList(),
 headerStyle: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
 cellStyle: const pw.TextStyle(fontSize: 9),
 headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
 cellPadding: const pw.EdgeInsets.all(6),
 ),
 pw.SizedBox(height: 14),

 // Next 90 Days
 _pdfSectionTitle('Next 90 Days Focus'),
 pw.SizedBox(height: 6),
 if (_next90Days.isEmpty)
 _pdfCell('No next actions recorded.')
 else
 pw.Table.fromTextArray(
 headers: ['Priority', 'Details', 'Owner', 'Status'],
 data: _next90Days.map((n) => [n.title, n.details, n.owner, n.status]).toList(),
 headerStyle: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
 cellStyle: const pw.TextStyle(fontSize: 9),
 headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
 cellPadding: const pw.EdgeInsets.all(6),
 ),
 ],
 ),
 );

 final bytes = await doc.save();
 if (!mounted) return;
 loader.downloadFile(bytes, filename, mimeType: 'application/pdf');
 } catch (e) {
 if (mounted) {
 ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('PDF export failed: ${e.toString()}')));
 }
 } finally {
 if (mounted) setState(() => _isExporting = false);
 }
 }

 pw.Widget _pdfSectionTitle(String title) {
 return pw.Text(title, style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold));
 }

 pw.Widget _pdfCell(String text) {
 return pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(text, style: const pw.TextStyle(fontSize: 9)));
 }

 String _s(dynamic v) => (v ?? '').toString().trim();
 String _ns(dynamic v, String fb) => _s(v).isEmpty ? fb : _s(v);
}
