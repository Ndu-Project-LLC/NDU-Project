import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import 'package:ndu_project/models/launch_phase_models.dart';
import 'package:ndu_project/screens/commerce_viability_screen.dart';
import 'package:ndu_project/screens/contract_close_out_screen.dart';
import 'package:ndu_project/screens/project_close_out_screen.dart';
import 'package:ndu_project/services/launch_phase_service.dart';
import 'package:ndu_project/utils/launch_phase_ai_seed.dart';
import 'package:ndu_project/utils/download_helper.dart' as download_helper;
import 'package:ndu_project/utils/project_data_helper.dart';
import 'package:ndu_project/widgets/execution_phase_ui.dart';
import 'package:ndu_project/widgets/launch_insights_widgets.dart';
import 'package:ndu_project/widgets/planning_phase_header.dart';
import 'package:ndu_project/services/openai_service_secure.dart';
import 'package:ndu_project/widgets/kaz_ai_chat_bubble.dart';
import 'package:ndu_project/widgets/launch_data_table.dart';
import 'package:ndu_project/widgets/launch_phase_navigation.dart';
import 'package:ndu_project/utils/csv_import_helper.dart';
import 'package:ndu_project/widgets/responsive_scaffold.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class ActualVsPlannedGapAnalysisScreen extends StatefulWidget {
 const ActualVsPlannedGapAnalysisScreen({super.key});

 static void open(BuildContext context) {
 Navigator.of(context).push(
 MaterialPageRoute(
 builder: (_) => const ActualVsPlannedGapAnalysisScreen()),
 );
 }

 @override
 State<ActualVsPlannedGapAnalysisScreen> createState() =>
 _ActualVsPlannedGapAnalysisScreenState();
}

class _ActualVsPlannedGapAnalysisScreenState
 extends State<ActualVsPlannedGapAnalysisScreen> {
 List<LaunchGapItem> _scopeGaps = [];
 List<LaunchMilestoneVariance> _milestoneVariances = [];
 List<LaunchBudgetVariance> _budgetVariances = [];
 List<LaunchRootCauseItem> _rootCauses = [];
 List<LaunchFollowUpItem> _followUpActions = [];

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
 activeItemLabel: '5. Scope & Deliverable Reconciliation',
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
 title: 'Scope & Deliverable Reconciliation',
showNavigationButtons: false, onExportPdf: _exportPdf),
 const SizedBox(height: 16),
            _buildLaunchInsights(),
            const SizedBox(height: 16),
 _buildMetricsRow(),
 const SizedBox(height: 20),
 _buildScopeGapsPanel(),
 const SizedBox(height: 16),
 _buildMilestoneVariancePanel(),
 const SizedBox(height: 16),
 _buildBudgetVariancePanel(),
 const SizedBox(height: 16),
 _buildRootCausesPanel(),
 const SizedBox(height: 16),
 _buildFollowUpPanel(),
 const SizedBox(height: 24),
 LaunchPhaseNavigation(
 backLabel: 'Back: Vendor & Contract Closeout',
 nextLabel: 'Next: Hypercare & Warranty Support',
 onBack: () => ContractCloseOutScreen.open(context),
 onNext: () => CommerceViabilityScreen.open(context),
 ),
 const SizedBox(height: 48),
 ],
 ),
 ),
 );
 }

 Widget _buildMetricsRow() {
 final met = _scopeGaps.where((g) => g.gapStatus == 'Met').length;
 final partial = _scopeGaps.where((g) => g.gapStatus == 'Partial').length;
 final missed = _scopeGaps.where((g) => g.gapStatus == 'Missed').length;
 final openActions =
 _followUpActions.where((f) => f.status != 'Complete').length;

 return ExecutionMetricsGrid(
 metrics: [
 ExecutionMetricData(
 label: 'Met',
 value: '$met',
 icon: Icons.check_circle_outline,
 emphasisColor: const Color(0xFF10B981)),
 ExecutionMetricData(
 label: 'Partial',
 value: '$partial',
 icon: Icons.indeterminate_check_box_outlined,
 emphasisColor: const Color(0xFFF59E0B)),
 ExecutionMetricData(
 label: 'Missed',
 value: '$missed',
 icon: Icons.cancel_outlined,
 emphasisColor:
 missed > 0 ? const Color(0xFFEF4444) : const Color(0xFF10B981)),
 ExecutionMetricData(
 label: 'Open Actions',
 value: '$openActions',
 icon: Icons.pending_outlined,
 emphasisColor: const Color(0xFF8B5CF6)),
 ],
 );
 }

 Widget _buildScopeGapsPanel() {
 return LaunchDataTable(
 title: 'Scope Gap Analysis',
 subtitle: 'Compare planned deliverables vs actual outcomes.',
 columns: const [LaunchColumn(label: 'Planned', flexible: true, fieldType: LaunchFieldType.text, hint: 'Planned'), LaunchColumn(label: 'Actual', flexible: true, fieldType: LaunchFieldType.text, hint: 'Actual'), LaunchColumn(label: 'Gap', flexible: true, fieldType: LaunchFieldType.text, hint: 'Gap'), LaunchColumn(label: 'Status', width: 120, fieldType: LaunchFieldType.dropdown, dropdownItems: LaunchGapItem.gapStatuses, hint: 'Status')],
 rowCount: _scopeGaps.length,
 onAddValues: (values) {
 setState(() => _scopeGaps.add(LaunchGapItem(
 planned: values['Planned'] ?? '',
 actual: values['Actual'] ?? '',
 gapDescription: values['Gap'] ?? '',
 gapStatus: values['Status'] ?? 'Met',
 )));
 _save();
 },
 csvColumns: const [
 CsvColumnSpec(key: 'planned', label: 'Planned', sampleValue: 'User portal deployment'),
 CsvColumnSpec(key: 'actual', label: 'Actual', sampleValue: 'Deployed with minor gaps'),
 CsvColumnSpec(key: 'gap', label: 'Gap', sampleValue: 'Missing SSO integration'),
 CsvColumnSpec(key: 'status', label: 'Status', sampleValue: 'Partial', allowedValues: ['Met', 'Partial', 'Missed', 'Exceeded']),
 ],
 onCsvImport: (rows) async {
 for (final row in rows) {
 setState(() {
 _scopeGaps.add(LaunchGapItem(
 planned: row['planned'] ?? '',
 actual: row['actual'] ?? '',
 gapDescription: row['gap'] ?? '',
 gapStatus: row['status'] ?? 'Missed',
 ));
 });
 }
 _save();
 },
 emptyMessage: 'Add items to compare planned vs actual.',
 cellBuilder: (context, i) {
 final g = _scopeGaps[i];
 return LaunchDataRow(
 onEdit: () => _save(),
 onDelete: () async {
 final confirm =
 await launchConfirmDelete(context, itemName: 'scope gap');
 if (!confirm || !mounted) return;
 setState(() => _scopeGaps.removeAt(i));
 _save();
 },
 onKazAi: () => _regenerateScopeGapRow(i),
 cells: [
 LaunchEditableCell(
 value: g.planned,
 hint: 'Planned',
 bold: true,
 expand: true,
 onChanged: (s) {
 _scopeGaps[i] = g.copyWith(planned: s);
 _save();
 },
 ),
 LaunchEditableCell(
 value: g.actual,
 hint: 'Actual',
 expand: true,
 onChanged: (s) {
 _scopeGaps[i] = g.copyWith(actual: s);
 _save();
 },
 ),
 LaunchEditableCell(
 value: g.gapDescription,
 hint: 'Gap',
 expand: true,
 onChanged: (s) {
 _scopeGaps[i] = g.copyWith(gapDescription: s);
 _save();
 },
 ),
 LaunchStatusDropdown(
 value: g.gapStatus,
 items: LaunchGapItem.gapStatuses,
 onChanged: (s) {
 if (s == null) return;
 _scopeGaps[i] = g.copyWith(gapStatus: s);
 _save();
 setState(() {});
 },
 ),
 ],
 );
 },
 );
 }

 Widget _buildMilestoneVariancePanel() {
 return LaunchDataTable(
 title: 'Milestone Variance',
 subtitle: 'Compare planned vs actual milestone dates.',
 columns: const [LaunchColumn(label: 'Milestone', flexible: true, fieldType: LaunchFieldType.text, hint: 'Milestone'), LaunchColumn(label: 'Planned', width: 130, fieldType: LaunchFieldType.date, hint: 'Planned'), LaunchColumn(label: 'Actual', width: 130, fieldType: LaunchFieldType.date, hint: 'Actual'), LaunchColumn(label: 'Variance', width: 130, fieldType: LaunchFieldType.text, hint: 'Days'), LaunchColumn(label: 'Status', width: 120, fieldType: LaunchFieldType.dropdown, dropdownItems: ['On Track', 'Delayed', 'Missed', 'Early'], hint: 'Status')],
 rowCount: _milestoneVariances.length,
 onAddValues: (values) {
 setState(() => _milestoneVariances.add(LaunchMilestoneVariance(
 milestone: values['Milestone'] ?? '',
 plannedDate: values['Planned'] ?? '',
 actualDate: values['Actual'] ?? '',
 varianceDays: values['Variance'] ?? '',
 status: values['Status'] ?? 'On Track',
 )));
 _save();
 },
 csvColumns: const [
 CsvColumnSpec(key: 'milestone', label: 'Milestone', sampleValue: 'Go-live'),
 CsvColumnSpec(key: 'planned', label: 'Planned', sampleValue: '2025-01-15'),
 CsvColumnSpec(key: 'actual', label: 'Actual', sampleValue: '2025-01-18'),
 CsvColumnSpec(key: 'variance', label: 'Variance', sampleValue: '+3 days'),
 CsvColumnSpec(key: 'status', label: 'Status', sampleValue: 'On Track', allowedValues: ['On Track', 'Delayed', 'Missed', 'Early']),
 ],
 onCsvImport: (rows) async {
 for (final row in rows) {
 setState(() {
 _milestoneVariances.add(LaunchMilestoneVariance(
 milestone: row['milestone'] ?? '',
 plannedDate: row['planned'] ?? '',
 actualDate: row['actual'] ?? '',
 varianceDays: row['variance'] ?? '',
 status: row['status'] ?? 'On Track',
 ));
 });
 }
 _save();
 },
 emptyMessage: 'Track planned vs actual milestone dates.',
 cellBuilder: (context, i) {
 final m = _milestoneVariances[i];
 return LaunchDataRow(
 onEdit: () => _save(),
 onDelete: () async {
 final confirm = await launchConfirmDelete(context,
 itemName: 'milestone variance');
 if (!confirm || !mounted) return;
 setState(() => _milestoneVariances.removeAt(i));
 _save();
 },
 onKazAi: () => _regenerateMilestoneVarianceRow(i),
 cells: [
 LaunchEditableCell(
 value: m.milestone,
 hint: 'Milestone',
 bold: true,
 expand: true,
 onChanged: (s) {
 _milestoneVariances[i] = m.copyWith(milestone: s);
 _save();
 },
 ),
 LaunchDateCell(
 value: m.plannedDate,
 hint: 'Planned',
 onChanged: (s) {
 _milestoneVariances[i] = m.copyWith(plannedDate: s);
 _save();
 },
 ),
 LaunchDateCell(
 value: m.actualDate,
 hint: 'Actual',
 onChanged: (s) {
 _milestoneVariances[i] = m.copyWith(actualDate: s);
 _save();
 },
 ),
 LaunchEditableCell(
 value: m.varianceDays,
 hint: 'Days',
 width: 70,
 onChanged: (s) {
 _milestoneVariances[i] = m.copyWith(varianceDays: s);
 _save();
 },
 ),
 LaunchStatusDropdown(
 value: m.status,
 items: const ['On Track', 'Delayed', 'Missed', 'Early'],
 onChanged: (s) {
 if (s == null) return;
 _milestoneVariances[i] = m.copyWith(status: s);
 _save();
 setState(() {});
 },
 ),
 ],
 );
 },
 );
 }

 Widget _buildBudgetVariancePanel() {
 return LaunchDataTable(
 title: 'Budget Variance',
 subtitle: 'Compare planned vs actual costs by category.',
 columns: const [LaunchColumn(label: 'Category', flexible: true, fieldType: LaunchFieldType.text, hint: 'Category'), LaunchColumn(label: 'Planned', width: 130, fieldType: LaunchFieldType.text, hint: 'Planned'), LaunchColumn(label: 'Actual', width: 130, fieldType: LaunchFieldType.text, hint: 'Actual'), LaunchColumn(label: 'Variance', width: 130, fieldType: LaunchFieldType.text, hint: 'Variance'), LaunchColumn(label: '%', width: 110, fieldType: LaunchFieldType.text, hint: '%')],
 rowCount: _budgetVariances.length,
 onAddValues: (values) {
 setState(() => _budgetVariances.add(LaunchBudgetVariance(
 category: values['Category'] ?? '',
 plannedAmount: values['Planned'] ?? '',
 actualAmount: values['Actual'] ?? '',
 variance: values['Variance'] ?? '',
 variancePercent: values['%'] ?? '',
 )));
 _save();
 },
 csvColumns: const [
 CsvColumnSpec(key: 'category', label: 'Category', sampleValue: 'Infrastructure'),
 CsvColumnSpec(key: 'planned', label: 'Planned', sampleValue: '\$100,000'),
 CsvColumnSpec(key: 'actual', label: 'Actual', sampleValue: '\$115,000'),
 CsvColumnSpec(key: 'variance', label: 'Variance', sampleValue: '-\$15,000'),
 CsvColumnSpec(key: 'percent', label: '%', sampleValue: '15%'),
 ],
 onCsvImport: (rows) async {
 for (final row in rows) {
 setState(() {
 _budgetVariances.add(LaunchBudgetVariance(
 category: row['category'] ?? '',
 plannedAmount: row['planned'] ?? '',
 actualAmount: row['actual'] ?? '',
 variance: row['variance'] ?? '',
 variancePercent: row['percent'] ?? '',
 ));
 });
 }
 _save();
 },
 emptyMessage: 'Track planned vs actual budget by category.',
 cellBuilder: (context, i) {
 final b = _budgetVariances[i];
 return LaunchDataRow(
 onEdit: () => _save(),
 onDelete: () async {
 final confirm =
 await launchConfirmDelete(context, itemName: 'budget variance');
 if (!confirm || !mounted) return;
 setState(() => _budgetVariances.removeAt(i));
 _save();
 },
 onKazAi: () => _regenerateBudgetVarianceRow(i),
 cells: [
 LaunchEditableCell(
 value: b.category,
 hint: 'Category',
 bold: true,
 expand: true,
 onChanged: (s) {
 _budgetVariances[i] = b.copyWith(category: s);
 _save();
 },
 ),
 LaunchEditableCell(
 value: b.plannedAmount,
 hint: 'Planned',
 width: 130,
 onChanged: (s) {
 _budgetVariances[i] = b.copyWith(plannedAmount: s);
 _save();
 },
 ),
 LaunchEditableCell(
 value: b.actualAmount,
 hint: 'Actual',
 width: 130,
 onChanged: (s) {
 _budgetVariances[i] = b.copyWith(actualAmount: s);
 _save();
 },
 ),
 LaunchEditableCell(
 value: b.variance,
 hint: 'Variance',
 width: 120,
 onChanged: (s) {
 _budgetVariances[i] = b.copyWith(variance: s);
 _save();
 },
 ),
 LaunchEditableCell(
 value: b.variancePercent,
 hint: '%',
 width: 60,
 onChanged: (s) {
 _budgetVariances[i] = b.copyWith(variancePercent: s);
 _save();
 },
 ),
 ],
 );
 },
 );
 }

 Widget _buildRootCausesPanel() {
 return LaunchDataTable(
 title: 'Root Cause Analysis',
 subtitle:
 'For major gaps: identify root cause, impact, and corrective action.',
 columns: const [LaunchColumn(label: 'Gap', flexible: true, fieldType: LaunchFieldType.text, hint: 'Gap'), LaunchColumn(label: 'Root Cause', flexible: true, fieldType: LaunchFieldType.text, hint: 'Cause'), LaunchColumn(label: 'Impact', width: 120, fieldType: LaunchFieldType.text, hint: 'Impact'), LaunchColumn(label: 'Action', flexible: true, fieldType: LaunchFieldType.text, hint: 'Action'), LaunchColumn(label: 'Status', width: 120, fieldType: LaunchFieldType.dropdown, dropdownItems: ['Open', 'In Progress', 'Resolved'], hint: 'Status')],
 rowCount: _rootCauses.length,
 onAddValues: (values) {
 setState(() => _rootCauses.add(LaunchRootCauseItem(
 gap: values['Gap'] ?? '',
 rootCause: values['Root Cause'] ?? '',
 impact: values['Impact'] ?? '',
 correctiveAction: values['Action'] ?? '',
 status: values['Status'] ?? 'Open',
 )));
 _save();
 },
 csvColumns: const [
 CsvColumnSpec(key: 'gap', label: 'Gap', sampleValue: 'Budget overrun'),
 CsvColumnSpec(key: 'rootCause', label: 'Root Cause', sampleValue: 'Scope creep'),
 CsvColumnSpec(key: 'impact', label: 'Impact', sampleValue: 'High'),
 CsvColumnSpec(key: 'action', label: 'Action', sampleValue: 'Rebase budget'),
 CsvColumnSpec(key: 'status', label: 'Status', sampleValue: 'Open', allowedValues: ['Open', 'In Progress', 'Resolved']),
 ],
 onCsvImport: (rows) async {
 for (final row in rows) {
 setState(() {
 _rootCauses.add(LaunchRootCauseItem(
 gap: row['gap'] ?? '',
 rootCause: row['rootCause'] ?? '',
 impact: row['impact'] ?? '',
 correctiveAction: row['action'] ?? '',
 status: row['status'] ?? 'Open',
 ));
 });
 }
 _save();
 },
 emptyMessage: 'Analyze why major gaps occurred.',
 cellBuilder: (context, i) {
 final r = _rootCauses[i];
 return LaunchDataRow(
 onEdit: () => _save(),
 onDelete: () async {
 final confirm =
 await launchConfirmDelete(context, itemName: 'root cause');
 if (!confirm || !mounted) return;
 setState(() => _rootCauses.removeAt(i));
 _save();
 },
 onKazAi: () => _regenerateRootCauseRow(i),
 cells: [
 LaunchEditableCell(
 value: r.gap,
 hint: 'Gap',
 bold: true,
 expand: true,
 onChanged: (s) {
 _rootCauses[i] = r.copyWith(gap: s);
 _save();
 },
 ),
 LaunchEditableCell(
 value: r.rootCause,
 hint: 'Cause',
 expand: true,
 onChanged: (s) {
 _rootCauses[i] = r.copyWith(rootCause: s);
 _save();
 },
 ),
 LaunchEditableCell(
 value: r.impact,
 hint: 'Impact',
 expand: true,
 onChanged: (s) {
 _rootCauses[i] = r.copyWith(impact: s);
 _save();
 },
 ),
 LaunchEditableCell(
 value: r.correctiveAction,
 hint: 'Action',
 expand: true,
 onChanged: (s) {
 _rootCauses[i] = r.copyWith(correctiveAction: s);
 _save();
 },
 ),
 LaunchStatusDropdown(
 value: r.status,
 items: const ['Open', 'In Progress', 'Resolved'],
 onChanged: (s) {
 if (s == null) return;
 _rootCauses[i] = r.copyWith(status: s);
 _save();
 setState(() {});
 },
 ),
 ],
 );
 },
 );
 }

 Widget _buildFollowUpPanel() {
 return LaunchDataTable(
 title: 'Follow-Up Actions',
 subtitle: 'Items requiring post-project attention.',
 columns: const [LaunchColumn(label: 'Action', flexible: true, fieldType: LaunchFieldType.text, hint: 'Action'), LaunchColumn(label: 'Details', flexible: true, fieldType: LaunchFieldType.text, hint: 'Details'), LaunchColumn(label: 'Owner', width: 120, fieldType: LaunchFieldType.text, hint: 'Owner'), LaunchColumn(label: 'Status', width: 120, fieldType: LaunchFieldType.dropdown, dropdownItems: ['Open', 'In Progress', 'Complete'], hint: 'Status')],
 rowCount: _followUpActions.length,
 onAddValues: (values) {
 setState(() => _followUpActions.add(LaunchFollowUpItem(
 title: values['Action'] ?? '',
 details: values['Details'] ?? '',
 owner: values['Owner'] ?? '',
 status: values['Status'] ?? 'Open',
 )));
 _save();
 },
 csvColumns: const [
 CsvColumnSpec(key: 'action', label: 'Action', sampleValue: 'Monitor SLA compliance'),
 CsvColumnSpec(key: 'details', label: 'Details', sampleValue: 'Track vendor SLA adherence'),
 CsvColumnSpec(key: 'owner', label: 'Owner', sampleValue: 'Ops Manager'),
 CsvColumnSpec(key: 'status', label: 'Status', sampleValue: 'Open', allowedValues: ['Open', 'In Progress', 'Complete']),
 ],
 onCsvImport: (rows) async {
 for (final row in rows) {
 setState(() {
 _followUpActions.add(LaunchFollowUpItem(
 title: row['action'] ?? '',
 details: row['details'] ?? '',
 owner: row['owner'] ?? '',
 status: row['status'] ?? 'Open',
 ));
 });
 }
 _save();
 },
 emptyMessage: 'List items requiring attention after project closure.',
 cellBuilder: (context, i) {
 final f = _followUpActions[i];
 return LaunchDataRow(
 onEdit: () => _save(),
 onDelete: () async {
 final confirm = await launchConfirmDelete(context,
 itemName: 'follow-up action');
 if (!confirm || !mounted) return;
 setState(() => _followUpActions.removeAt(i));
 _save();
 },
 onKazAi: () => _regenerateFollowUpRow(i),
 cells: [
 LaunchEditableCell(
 value: f.title,
 hint: 'Action',
 bold: true,
 expand: true,
 onChanged: (s) {
 _followUpActions[i] = f.copyWith(title: s);
 _save();
 },
 ),
 LaunchEditableCell(
 value: f.details,
 hint: 'Details',
 expand: true,
 onChanged: (s) {
 _followUpActions[i] = f.copyWith(details: s);
 _save();
 },
 ),
 LaunchEditableCell(
 value: f.owner,
 hint: 'Owner',
 width: 130,
 onChanged: (s) {
 _followUpActions[i] = f.copyWith(owner: s);
 _save();
 },
 ),
 LaunchStatusDropdown(
 value: f.status,
 items: const ['Open', 'In Progress', 'Complete'],
 onChanged: (s) {
 if (s == null) return;
 _followUpActions[i] = f.copyWith(status: s);
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

 Future<void> _regenerateScopeGapRow(int index) async {
 if (index < 0 || index >= _scopeGaps.length) return;
 final key = 'gap_$index';
 if (_kazAiRegenerating[key] == true) return;
 setState(() => _kazAiRegenerating[key] = true);
 try {
 final projectData = ProjectDataHelper.getData(context);
 final ctx = ProjectDataHelper.buildProjectContextScan(projectData, sectionLabel: 'Scope Gap Analysis');
 final openai = OpenAiServiceSecure();
 final result = await openai.generateCompletion(
 'Based on this project context, suggest a planned deliverable, actual outcome, gap description, and status.\n\nContext:\n$ctx\n\nReturn ONLY a valid JSON object with keys: "planned", "actual", "gap", "status". Status must be Met, Partial, Missed, or Exceeded.',
 maxTokens: 250, temperature: 0.6,
 );
 final start = result.indexOf('{');
 final end = result.lastIndexOf('}');
 if (start != -1 && end != -1) {
 final parsed = jsonDecode(result.substring(start, end + 1)) as Map<String, dynamic>;
 if (mounted) {
 setState(() {
 _scopeGaps[index] = _scopeGaps[index].copyWith(
 planned: (parsed['planned'] ?? '').toString(),
 actual: (parsed['actual'] ?? _scopeGaps[index].actual).toString(),
 gapDescription: (parsed['gap'] ?? _scopeGaps[index].gapDescription).toString(),
 gapStatus: (parsed['status'] ?? _scopeGaps[index].gapStatus).toString(),
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

 Future<void> _regenerateMilestoneVarianceRow(int index) async {
 if (index < 0 || index >= _milestoneVariances.length) return;
 final key = 'msvar_$index';
 if (_kazAiRegenerating[key] == true) return;
 setState(() => _kazAiRegenerating[key] = true);
 try {
 final projectData = ProjectDataHelper.getData(context);
 final ctx = ProjectDataHelper.buildProjectContextScan(projectData, sectionLabel: 'Milestone Variance');
 final openai = OpenAiServiceSecure();
 final result = await openai.generateCompletion(
 'Based on this project context, suggest a milestone name, variance, and status.\n\nContext:\n$ctx\n\nReturn ONLY a valid JSON object with keys: "milestone", "variance", "status". Status must be On Track, Delayed, Missed, or Early.',
 maxTokens: 250, temperature: 0.6,
 );
 final start = result.indexOf('{');
 final end = result.lastIndexOf('}');
 if (start != -1 && end != -1) {
 final parsed = jsonDecode(result.substring(start, end + 1)) as Map<String, dynamic>;
 if (mounted) {
 setState(() {
 _milestoneVariances[index] = _milestoneVariances[index].copyWith(
 milestone: (parsed['milestone'] ?? '').toString(),
 varianceDays: (parsed['variance'] ?? _milestoneVariances[index].varianceDays).toString(),
 status: (parsed['status'] ?? _milestoneVariances[index].status).toString(),
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

 Future<void> _regenerateBudgetVarianceRow(int index) async {
 if (index < 0 || index >= _budgetVariances.length) return;
 final key = 'bv_$index';
 if (_kazAiRegenerating[key] == true) return;
 setState(() => _kazAiRegenerating[key] = true);
 try {
 final projectData = ProjectDataHelper.getData(context);
 final ctx = ProjectDataHelper.buildProjectContextScan(projectData, sectionLabel: 'Budget Variance');
 final openai = OpenAiServiceSecure();
 final result = await openai.generateCompletion(
 'Based on this project context, suggest a budget category, planned amount, actual amount, and variance.\n\nContext:\n$ctx\n\nReturn ONLY a valid JSON object with keys: "category", "planned", "actual", "variance", "percent".',
 maxTokens: 250, temperature: 0.6,
 );
 final start = result.indexOf('{');
 final end = result.lastIndexOf('}');
 if (start != -1 && end != -1) {
 final parsed = jsonDecode(result.substring(start, end + 1)) as Map<String, dynamic>;
 if (mounted) {
 setState(() {
 _budgetVariances[index] = _budgetVariances[index].copyWith(
 category: (parsed['category'] ?? '').toString(),
 plannedAmount: (parsed['planned'] ?? _budgetVariances[index].plannedAmount).toString(),
 actualAmount: (parsed['actual'] ?? _budgetVariances[index].actualAmount).toString(),
 variance: (parsed['variance'] ?? _budgetVariances[index].variance).toString(),
 variancePercent: (parsed['percent'] ?? _budgetVariances[index].variancePercent).toString(),
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

 Future<void> _regenerateRootCauseRow(int index) async {
 if (index < 0 || index >= _rootCauses.length) return;
 final key = 'rc_$index';
 if (_kazAiRegenerating[key] == true) return;
 setState(() => _kazAiRegenerating[key] = true);
 try {
 final projectData = ProjectDataHelper.getData(context);
 final ctx = ProjectDataHelper.buildProjectContextScan(projectData, sectionLabel: 'Root Cause Analysis');
 final openai = OpenAiServiceSecure();
 final result = await openai.generateCompletion(
 'Based on this project context, suggest a gap description, root cause, impact, and corrective action.\n\nContext:\n$ctx\n\nReturn ONLY a valid JSON object with keys: "gap", "root_cause", "impact", "action", "status". Status must be Open, In Progress, or Resolved.',
 maxTokens: 250, temperature: 0.6,
 );
 final start = result.indexOf('{');
 final end = result.lastIndexOf('}');
 if (start != -1 && end != -1) {
 final parsed = jsonDecode(result.substring(start, end + 1)) as Map<String, dynamic>;
 if (mounted) {
 setState(() {
 _rootCauses[index] = _rootCauses[index].copyWith(
 gap: (parsed['gap'] ?? '').toString(),
 rootCause: (parsed['root_cause'] ?? _rootCauses[index].rootCause).toString(),
 impact: (parsed['impact'] ?? _rootCauses[index].impact).toString(),
 correctiveAction: (parsed['action'] ?? _rootCauses[index].correctiveAction).toString(),
 status: (parsed['status'] ?? _rootCauses[index].status).toString(),
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

 Future<void> _regenerateFollowUpRow(int index) async {
 if (index < 0 || index >= _followUpActions.length) return;
 final key = 'fu_$index';
 if (_kazAiRegenerating[key] == true) return;
 setState(() => _kazAiRegenerating[key] = true);
 try {
 final projectData = ProjectDataHelper.getData(context);
 final ctx = ProjectDataHelper.buildProjectContextScan(projectData, sectionLabel: 'Follow-Up Actions');
 final openai = OpenAiServiceSecure();
 final result = await openai.generateCompletion(
 'Based on this project context, suggest a follow-up action title, details, and owner.\n\nContext:\n$ctx\n\nReturn ONLY a valid JSON object with keys: "title", "details", "owner", "status". Status must be Open, In Progress, or Complete.',
 maxTokens: 250, temperature: 0.6,
 );
 final start = result.indexOf('{');
 final end = result.lastIndexOf('}');
 if (start != -1 && end != -1) {
 final parsed = jsonDecode(result.substring(start, end + 1)) as Map<String, dynamic>;
 if (mounted) {
 setState(() {
 _followUpActions[index] = _followUpActions[index].copyWith(
 title: (parsed['title'] ?? '').toString(),
 details: (parsed['details'] ?? _followUpActions[index].details).toString(),
 owner: (parsed['owner'] ?? _followUpActions[index].owner).toString(),
 status: (parsed['status'] ?? _followUpActions[index].status).toString(),
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
 await LaunchPhaseService.loadGapAnalysis(projectId: _projectId!);
 if (!mounted) return;
 setState(() {
 _scopeGaps = r.scopeGaps;
 _milestoneVariances = r.milestoneVariances;
 _budgetVariances = r.budgetVariances;
 _rootCauses = r.rootCauses;
 _followUpActions = r.followUpActions;
 _isLoading = false;
 _hasLoaded = true;
 });
 if (_scopeGaps.isEmpty &&
 _milestoneVariances.isEmpty &&
 _budgetVariances.isEmpty &&
 _rootCauses.isEmpty &&
 _followUpActions.isEmpty) {
 await _autoPopulateFromPriorPhases();
 }
 if (_scopeGaps.isEmpty &&
 _milestoneVariances.isEmpty &&
 _budgetVariances.isEmpty &&
 _rootCauses.isEmpty &&
 _followUpActions.isEmpty) {
 await _populateFromAi();
 }
 } catch (e) {
 debugPrint('Gap analysis load error: $e');
 if (mounted) setState(() => _isLoading = false);
 }
 _suspendSave = false;
 }

 Future<void> _persistData() async {
 if (_projectId == null) return;
 try {
 await LaunchPhaseService.saveGapAnalysis(
 projectId: _projectId!,
 scopeGaps: _scopeGaps,
 milestoneVariances: _milestoneVariances,
 budgetVariances: _budgetVariances,
 rootCauses: _rootCauses,
 followUpActions: _followUpActions);
 } catch (e) {
 debugPrint('Gap analysis save error: $e');
 }
 }

 Future<void> _autoPopulateFromPriorPhases() async {
 if (_projectId == null) return;
 try {
 final cp = await LaunchPhaseAiSeed.loadCrossPhaseData(_projectId!);

 if (!mounted) return;

 final scopeGapExisting = _scopeGaps.map((g) => g.planned).toSet();
 final newScopeGaps = <LaunchGapItem>[];
 for (final st in cp.scopeTracking) {
 if (st.deliverable.isNotEmpty && !scopeGapExisting.contains(st.deliverable)) {
 final status = st.status.toLowerCase();
 String gapStatus;
 if (status == 'verified' || status == 'completed' || status == 'done') {
 gapStatus = 'Met';
 } else if (status == 'in progress') {
 gapStatus = 'Partial';
 } else {
 gapStatus = 'Missed';
 }
 newScopeGaps.add(LaunchGapItem(
 planned: st.deliverable,
 actual: st.status,
 gapStatus: gapStatus,
 notes: st.notes,
 ));
 }
 }
 if (newScopeGaps.isNotEmpty) {
 setState(() => _scopeGaps.addAll(newScopeGaps));
 }

 final milestoneExisting = _milestoneVariances.map((m) => m.milestone).toSet();
 final newMilestones = <LaunchMilestoneVariance>[];
 for (final sp in cp.planningSprints) {
 final title = sp['title']?.toString() ?? sp['name']?.toString() ?? '';
 if (title.isNotEmpty && !milestoneExisting.contains(title)) {
 newMilestones.add(LaunchMilestoneVariance(
 milestone: title,
 plannedDate: sp['startDate']?.toString() ?? sp['plannedDate']?.toString() ?? '',
 actualDate: sp['endDate']?.toString() ?? sp['actualDate']?.toString() ?? '',
 status: 'On Track',
 ));
 }
 }
 if (newMilestones.isNotEmpty) {
 setState(() => _milestoneVariances.addAll(newMilestones));
 }

 final budgetExisting = _budgetVariances.map((b) => b.category).toSet();
 final newBudgetVariances = <LaunchBudgetVariance>[];
 for (final br in cp.budgetRows) {
 final cat = br['category']?.toString() ?? '';
 if (cat.isNotEmpty && !budgetExisting.contains(cat)) {
 final planned = br['plannedAmount']?.toString() ?? '';
 final actual = br['actualAmount']?.toString() ?? '';
 final plannedNum = double.tryParse(planned.replaceAll(RegExp(r'[^\d.]'), '')) ?? 0;
 final actualNum = double.tryParse(actual.replaceAll(RegExp(r'[^\d.]'), '')) ?? 0;
 final variance = plannedNum - actualNum;
 final variancePct = plannedNum > 0 ? ((variance / plannedNum) * 100).toStringAsFixed(1) : '';
 newBudgetVariances.add(LaunchBudgetVariance(
 category: cat,
 plannedAmount: planned,
 actualAmount: actual,
 variance: variance.toStringAsFixed(0),
 variancePercent: variancePct.isNotEmpty ? '$variancePct%' : '',
 ));
 }
 }
 if (newBudgetVariances.isNotEmpty) {
 setState(() => _budgetVariances.addAll(newBudgetVariances));
 }

 final rootCauseExisting = _rootCauses.map((r) => r.gap).toSet();
 final newRootCauses = <LaunchRootCauseItem>[];
 for (final ri in cp.openRiskItems) {
 final title = ri['title']?.toString() ?? ri['risk']?.toString() ?? '';
 if (title.isNotEmpty && !rootCauseExisting.contains(title)) {
 newRootCauses.add(LaunchRootCauseItem(
 gap: title,
 rootCause: ri['cause']?.toString() ?? ri['rootCause']?.toString() ?? '',
 impact: ri['impact']?.toString() ?? '',
 status: 'Open',
 ));
 }
 }
 if (newRootCauses.isNotEmpty) {
 setState(() => _rootCauses.addAll(newRootCauses));
 }

 final followUpExisting = _followUpActions.map((f) => f.title).toSet();
 final newFollowUps = <LaunchFollowUpItem>[];
 for (final ri in cp.openRiskItems) {
 final title = ri['title']?.toString() ?? ri['risk']?.toString() ?? '';
 if (title.isNotEmpty && !followUpExisting.contains(title)) {
 newFollowUps.add(LaunchFollowUpItem(
 title: 'Monitor: $title',
 details: ri['description']?.toString() ?? ri['details']?.toString() ?? '',
 owner: ri['owner']?.toString() ?? '',
 status: 'Open',
 ));
 }
 }
 for (final mp in cp.mitigationPlans) {
 final title = mp['title']?.toString() ?? mp['action']?.toString() ?? '';
 if (title.isNotEmpty && !followUpExisting.contains(title)) {
 newFollowUps.add(LaunchFollowUpItem(
 title: title,
 details: mp['description']?.toString() ?? mp['details']?.toString() ?? '',
 owner: mp['owner']?.toString() ?? '',
 status: 'Open',
 ));
 }
 }
 if (newFollowUps.isNotEmpty) {
 setState(() => _followUpActions.addAll(newFollowUps));
 }

 if (newScopeGaps.isNotEmpty || newMilestones.isNotEmpty || newBudgetVariances.isNotEmpty || newRootCauses.isNotEmpty || newFollowUps.isNotEmpty) {
 await _persistData();
 }
 } catch (e) {
 debugPrint('Gap analysis auto-populate error: $e');
 }
 }

 Future<void> _populateFromAi() async {
 if (_isGenerating) return;
 setState(() => _isGenerating = true);
 LaunchAiResult? result;
 try {
 result = await LaunchPhaseAiSeed.generateEntries(
 context: context,
 sectionLabel: 'Actual vs Planned Gap Analysis',
 sections: const {
 'scope_gaps': 'Scope gap items with "planned", "actual", "gap_description", "gap_status"',
 'milestone_variances': 'Milestone variances with "milestone", "planned_date", "actual_date", "variance_days", "status"',
 'budget_variances': 'Budget variance items with "category", "planned_amount", "actual_amount", "variance", "variance_percent"',
 'root_causes': 'Root cause items with "gap", "root_cause", "impact", "corrective_action", "status"',
 'follow_up_actions': 'Follow-up actions with "title", "details", "owner", "status"',
 },
 itemsPerSection: 3,
 );
 } catch (e) {
 debugPrint('Gap analysis AI error: $e');
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

 final hasData = _scopeGaps.isNotEmpty ||
 _milestoneVariances.isNotEmpty ||
 _budgetVariances.isNotEmpty ||
 _rootCauses.isNotEmpty ||
 _followUpActions.isNotEmpty;
 if (hasData) {
 setState(() => _isGenerating = false);
 return;
 }
 setState(() {
 _scopeGaps = (generated['scope_gaps'] ?? [])
 .map((m) => LaunchGapItem(
 planned: _s(m['planned']),
 actual: _s(m['actual']),
 gapDescription: _s(m['gap_description']),
 gapStatus: _ns(m['gap_status'], 'Missed')))
 .where((i) => i.planned.isNotEmpty)
 .toList();
 _milestoneVariances = (generated['milestone_variances'] ?? [])
 .map((m) => LaunchMilestoneVariance(
 milestone: _s(m['milestone']),
 plannedDate: _s(m['planned_date']),
 actualDate: _s(m['actual_date']),
 varianceDays: _s(m['variance_days']),
 status: _ns(m['status'], 'On Track')))
 .where((i) => i.milestone.isNotEmpty)
 .toList();
 _budgetVariances = (generated['budget_variances'] ?? [])
 .map((m) => LaunchBudgetVariance(
 category: _s(m['category']),
 plannedAmount: _s(m['planned_amount']),
 actualAmount: _s(m['actual_amount']),
 variance: _s(m['variance']),
 variancePercent: _s(m['variance_percent'])))
 .where((i) => i.category.isNotEmpty)
 .toList();
 _rootCauses = (generated['root_causes'] ?? [])
 .map((m) => LaunchRootCauseItem(
 gap: _s(m['gap']),
 rootCause: _s(m['root_cause']),
 impact: _s(m['impact']),
 correctiveAction: _s(m['corrective_action']),
 status: _ns(m['status'], 'Open')))
 .where((i) => i.gap.isNotEmpty)
 .toList();
 _followUpActions = (generated['follow_up_actions'] ?? [])
 .map((m) => LaunchFollowUpItem(
 title: _s(m['title']),
 details: _s(m['details']),
 owner: _s(m['owner']),
 status: _ns(m['status'], 'Open')))
 .where((i) => i.title.isNotEmpty)
 .toList();
 _isGenerating = false;
 });
 await _persistData();
 }

 String _s(dynamic v) => (v ?? '').toString().trim();
 String _ns(dynamic v, String fb) => _s(v).isEmpty ? fb : _s(v);

 Future<void> _exportPdf() async {
 setState(() => _isExporting = true);
 try {
 final projectData = ProjectDataHelper.getData(context);
 final projectName = projectData.projectName;
 final now = DateTime.now();
 final stamp =
 '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
 final filename =
 'gap_analysis_${projectName.replaceAll(' ', '_')}_$stamp.pdf';

 final doc = pw.Document();

 doc.addPage(
 pw.MultiPage(
 pageFormat: PdfPageFormat.a4,
 margin: const pw.EdgeInsets.all(32),
 build: (_) => [
 pw.Text(
 'Actual vs Planned Gap Analysis',
 style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
 ),
 pw.SizedBox(height: 4),
 pw.Text(
 '$projectName — Generated ${now.toLocal().toIso8601String()}',
 style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
 ),
 pw.SizedBox(height: 16),
 _pdfSectionTitle('Scope Gap Analysis'),
 pw.SizedBox(height: 6),
 if (_scopeGaps.isEmpty)
 pw.Text('No scope gaps.',
 style:
 const pw.TextStyle(fontSize: 9, color: PdfColors.grey500))
 else
 pw.TableHelper.fromTextArray(
 headerStyle:
 pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
 headerDecoration:
 const pw.BoxDecoration(color: PdfColor(0.93, 0.95, 0.98)),
 cellStyle: const pw.TextStyle(fontSize: 8.5),
 cellAlignment: pw.Alignment.topLeft,
 headerAlignment: pw.Alignment.centerLeft,
 cellPadding:
 const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
 headers: const ['Planned', 'Actual', 'Gap', 'Status'],
 data: _scopeGaps
 .map((g) => [
 _pc(g.planned),
 _pc(g.actual),
 _pc(g.gapDescription),
 _pc(g.gapStatus),
 ])
 .toList(),
 ),
 pw.SizedBox(height: 20),
 _pdfSectionTitle('Milestone Variance'),
 pw.SizedBox(height: 6),
 if (_milestoneVariances.isEmpty)
 pw.Text('No milestone variances.',
 style:
 const pw.TextStyle(fontSize: 9, color: PdfColors.grey500))
 else
 pw.TableHelper.fromTextArray(
 headerStyle:
 pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
 headerDecoration:
 const pw.BoxDecoration(color: PdfColor(0.93, 0.95, 0.98)),
 cellStyle: const pw.TextStyle(fontSize: 8.5),
 cellAlignment: pw.Alignment.topLeft,
 headerAlignment: pw.Alignment.centerLeft,
 cellPadding:
 const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
 headers: const [
 'Milestone',
 'Planned',
 'Actual',
 'Variance',
 'Status'
 ],
 data: _milestoneVariances
 .map((m) => [
 _pc(m.milestone),
 _pc(m.plannedDate),
 _pc(m.actualDate),
 _pc(m.varianceDays),
 _pc(m.status),
 ])
 .toList(),
 ),
 pw.SizedBox(height: 20),
 _pdfSectionTitle('Budget Variance'),
 pw.SizedBox(height: 6),
 if (_budgetVariances.isEmpty)
 pw.Text('No budget variances.',
 style:
 const pw.TextStyle(fontSize: 9, color: PdfColors.grey500))
 else
 pw.TableHelper.fromTextArray(
 headerStyle:
 pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
 headerDecoration:
 const pw.BoxDecoration(color: PdfColor(0.93, 0.95, 0.98)),
 cellStyle: const pw.TextStyle(fontSize: 8.5),
 cellAlignment: pw.Alignment.topLeft,
 headerAlignment: pw.Alignment.centerLeft,
 cellPadding:
 const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
 headers: const [
 'Category',
 'Planned',
 'Actual',
 'Variance',
 '%'
 ],
 data: _budgetVariances
 .map((b) => [
 _pc(b.category),
 _pc(b.plannedAmount),
 _pc(b.actualAmount),
 _pc(b.variance),
 _pc(b.variancePercent),
 ])
 .toList(),
 ),
 pw.SizedBox(height: 20),
 _pdfSectionTitle('Root Cause Analysis'),
 pw.SizedBox(height: 6),
 if (_rootCauses.isEmpty)
 pw.Text('No root cause items.',
 style:
 const pw.TextStyle(fontSize: 9, color: PdfColors.grey500))
 else
 pw.TableHelper.fromTextArray(
 headerStyle:
 pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
 headerDecoration:
 const pw.BoxDecoration(color: PdfColor(0.93, 0.95, 0.98)),
 cellStyle: const pw.TextStyle(fontSize: 8.5),
 cellAlignment: pw.Alignment.topLeft,
 headerAlignment: pw.Alignment.centerLeft,
 cellPadding:
 const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
 headers: const [
 'Gap',
 'Root Cause',
 'Impact',
 'Action',
 'Status'
 ],
 data: _rootCauses
 .map((r) => [
 _pc(r.gap),
 _pc(r.rootCause),
 _pc(r.impact),
 _pc(r.correctiveAction),
 _pc(r.status),
 ])
 .toList(),
 ),
 pw.SizedBox(height: 20),
 _pdfSectionTitle('Follow-Up Actions'),
 pw.SizedBox(height: 6),
 if (_followUpActions.isEmpty)
 pw.Text('No follow-up actions.',
 style:
 const pw.TextStyle(fontSize: 9, color: PdfColors.grey500))
 else
 pw.TableHelper.fromTextArray(
 headerStyle:
 pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
 headerDecoration:
 const pw.BoxDecoration(color: PdfColor(0.93, 0.95, 0.98)),
 cellStyle: const pw.TextStyle(fontSize: 8.5),
 cellAlignment: pw.Alignment.topLeft,
 headerAlignment: pw.Alignment.centerLeft,
 cellPadding:
 const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
 headers: const [
 'Action',
 'Details',
 'Owner',
 'Status'
 ],
 data: _followUpActions
 .map((f) => [
 _pc(f.title),
 _pc(f.details),
 _pc(f.owner),
 _pc(f.status),
 ])
 .toList(),
 ),
 ],
 ),
 );

 final bytes = await doc.save();
 if (kIsWeb) {
 download_helper.downloadFile(bytes, filename,
 mimeType: 'application/pdf');
 } else {
 await Printing.sharePdf(bytes: bytes, filename: filename);
 }

 if (mounted) {
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(content: Text('PDF exported: $filename')),
 );
 }
 } catch (e) {
 debugPrint('PDF export error: $e');
 if (mounted) {
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(content: Text('Failed to generate PDF: $e')),
 );
 }
 }
 if (mounted) setState(() => _isExporting = false);
 }

 pw.Widget _pdfSectionTitle(String title) {
 return pw.Container(
 width: double.infinity,
 padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 8),
 decoration: const pw.BoxDecoration(
 color: PdfColor(0.06, 0.27, 0.45),
 borderRadius: pw.BorderRadius.all(pw.Radius.circular(4)),
 ),
 child: pw.Text(title,
 style: pw.TextStyle(
 fontSize: 11,
 fontWeight: pw.FontWeight.bold,
 color: PdfColors.white)),
 );
 }

 String _pc(String v) => v.trim().isEmpty ? '-' : v.trim();
  // Launch Insights: KPIs + completion donut (auto-derived from project data)
  Widget _buildLaunchInsights() {
    final projectData = ProjectDataHelper.getData(context);
    final scopeTotal = projectData.withinScope
                .where((s) => s.trim().isNotEmpty)
                .length +
            projectData.outOfScope.where((s) => s.trim().isNotEmpty).length;
        final completionPct =
            scopeTotal == 0 ? 0.0 : (projectData.withinScope.where((s) => s.trim().isNotEmpty).length / scopeTotal);
    return LaunchInsightsHeader(
      sectionTitle: 'Scope & Deliverable Reconciliation',
      sectionSubtitle: 'Planned vs actual scope, deliverables, and acceptance status',
      sectionIcon: Icons.compare_arrows_outlined,
      sectionColor: const Color(0xFF06B6D4),
      completionPercent: completionPct,
      completionLabel: 'RECONCILED',
      completionCaption:
          '${(completionPct * 100).round()}% complete - auto-derived from project data',
      kpiTiles: [
        LaunchKpiTile(
              label: 'In-Scope Items',
              value: '${projectData.withinScope.where((s) => s.trim().isNotEmpty).length}',
              icon: Icons.check_circle_outline,
              color: const Color(0xFF10B981),
              delta: 'committed scope',
            ),
            LaunchKpiTile(
              label: 'Out-of-Scope',
              value: '${projectData.outOfScope.where((s) => s.trim().isNotEmpty).length}',
              icon: Icons.cancel_outlined,
              color: const Color(0xFFEF4444),
              delta: 'excluded',
            ),
            LaunchKpiTile(
              label: 'Milestones',
              value: '${projectData.keyMilestones.length}',
              icon: Icons.flag_outlined,
              color: const Color(0xFFD97706),
              delta: 'planned checkpoints',
            ),
            LaunchKpiTile(
              label: 'Allowance Burn',
              value: '\$${projectData.frontEndPlanning.allowanceItems.fold<double>(0, (s, i) => s + i.actualAmount).toStringAsFixed(0)}',
              icon: Icons.local_fire_department_outlined,
              color: const Color(0xFFF59E0B),
              delta: 'actual consumed',
            ),
      ],
    );
  }


}
