import 'package:ndu_project/widgets/launch_notes_section.dart';
import 'package:ndu_project/widgets/launch_insights_widgets.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import 'package:ndu_project/models/launch_phase_models.dart';
import 'package:ndu_project/screens/actual_vs_planned_gap_analysis_screen.dart';
import 'package:ndu_project/screens/fat_mechanical_completion_screen.dart';
import 'package:ndu_project/screens/transition_to_prod_team_screen.dart';
import 'package:ndu_project/screens/vendor_account_close_out_screen.dart';
import 'package:ndu_project/services/launch_phase_service.dart';
import 'package:ndu_project/utils/launch_phase_ai_seed.dart';
import 'package:ndu_project/utils/download_helper.dart' as download_helper;
import 'package:ndu_project/utils/project_data_helper.dart';
import 'package:ndu_project/widgets/execution_phase_ui.dart';
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

class ContractCloseOutScreen extends StatefulWidget {
 const ContractCloseOutScreen({super.key});

 static void open(BuildContext context) {
 Navigator.of(context).push(
 MaterialPageRoute(builder: (_) => const ContractCloseOutScreen()),
 );
 }

 @override
 State<ContractCloseOutScreen> createState() => _ContractCloseOutScreenState();
}

class _ContractCloseOutScreenState extends State<ContractCloseOutScreen> {
 List<LaunchContractItem> _contracts = [];
  final TextEditingController _notesController = TextEditingController();
 List<LaunchCloseOutStep> _closeOutSteps = [];
 List<LaunchApproval> _signOffs = [];
 List<LaunchFinancialMetric> _financialSummary = [];

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
 activeItemLabel: '4. Vendor & Contract Closeout',
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
 title: 'Vendor & Contract Closeout',
showNavigationButtons: false,
 showActivityLogAction: false,
 onExportPdf: _exportPdf),
 const SizedBox(height: 16),
            _buildLaunchInsights(),
            const SizedBox(height: 16),
 _buildMetricsRow(),
 const SizedBox(height: 16),
            LaunchNotesSection(
              controller: _notesController,
              onChanged: (v) {},
            ),
            const SizedBox(height: 20),
 _buildFinancialSummaryPanel(),
 const SizedBox(height: 16),
 _buildContractsPanel(),
 const SizedBox(height: 16),
 _buildCloseOutStepsPanel(),
 const SizedBox(height: 16),
 _buildSignOffsPanel(),
 const SizedBox(height: 24),
 LaunchPhaseNavigation(
 backLabel: 'Back: FAT, Mechanical Completion & Commission Solution',
 nextLabel: 'Next: Scope & Deliverable Reconciliation',
 onBack: () => FatMechanicalCompletionScreen.open(context),
 onNext: () => ActualVsPlannedGapAnalysisScreen.open(context),
 ),
 const SizedBox(height: 48),
 ],
 ),
 ),
 );
 }

 Widget _buildMetricsRow() {
 final open = _contracts.where((c) => c.closeOutStatus == 'Open').length;
 final inProgress =
 _contracts.where((c) => c.closeOutStatus == 'In Progress').length;
 final closed = _contracts.where((c) => c.closeOutStatus == 'Closed').length;
 final disputed =
 _contracts.where((c) => c.closeOutStatus == 'Disputed').length;

 return ExecutionMetricsGrid(
 metrics: [
 ExecutionMetricData(
 label: 'Total Contracts',
 value: '${_contracts.length}',
 icon: Icons.description_outlined,
 emphasisColor: const Color(0xFF2563EB),
 ),
 ExecutionMetricData(
 label: 'Open',
 value: '$open',
 icon: Icons.pending_outlined,
 emphasisColor: const Color(0xFFF59E0B),
 ),
 ExecutionMetricData(
 label: 'Closed',
 value: '$closed',
 icon: Icons.check_circle_outline,
 emphasisColor: const Color(0xFF10B981),
 ),
 ExecutionMetricData(
 label: 'Disputed',
 value: '$disputed',
 icon: Icons.warning_amber_outlined,
 emphasisColor:
 disputed > 0 ? const Color(0xFFEF4444) : const Color(0xFF10B981),
 ),
 ],
 );
 }

 Widget _buildFinancialSummaryPanel() {
 return LaunchDataTable(
 title: 'Financial Summary',
 subtitle: 'Key financial metrics for contract close-out.',
 columns: const [LaunchColumn(label: 'Metric', flexible: true, fieldType: LaunchFieldType.text, hint: 'Metric'), LaunchColumn(label: 'Value', width: 120, fieldType: LaunchFieldType.text, hint: 'Value'), LaunchColumn(label: 'Notes', flexible: true, fieldType: LaunchFieldType.text, hint: 'Notes')],
 rowCount: _financialSummary.length,
 onAddValues: (values) {
 setState(() {
 _financialSummary.add(LaunchFinancialMetric(
 label: values['Metric'] ?? '',
 value: values['Value'] ?? '',
 notes: values['Notes'] ?? '',
 ));
 });
 _scheduleSave();
 },
 csvColumns: const [
 CsvColumnSpec(key: 'metric', label: 'Metric', sampleValue: 'Total Contract Value'),
 CsvColumnSpec(key: 'value', label: 'Value', sampleValue: '\$500,000'),
 CsvColumnSpec(key: 'notes', label: 'Notes', sampleValue: 'From execution contracts'),
 ],
 onCsvImport: (rows) async {
 for (final row in rows) {
 setState(() {
 _financialSummary.add(LaunchFinancialMetric(
 label: row['metric'] ?? '',
 value: row['value'] ?? '',
 notes: row['notes'] ?? '',
 ));
 });
 }
 _scheduleSave();
 },
 emptyMessage:
 'Track total contract value, payments, and pending amounts.',
 cellBuilder: (context, idx) {
 final item = _financialSummary[idx];
 return LaunchDataRow(
 onEdit: () => _scheduleSave(),
 onDelete: () async {
 final ok = await launchConfirmDelete(context,
 itemName: 'financial metric');
 if (!ok || !mounted) return;
 setState(() => _financialSummary.removeAt(idx));
 _scheduleSave();
 },
 onKazAi: () => _regenerateFinancialRow(idx),
 cells: [
 LaunchEditableCell(
 value: item.label,
 hint: 'Metric',
 bold: true,
 expand: true,
 onChanged: (v) {
 _financialSummary[idx] = item.copyWith(label: v);
 _scheduleSave();
 },
 ),
 LaunchEditableCell(
 value: item.value,
 hint: 'Value',
 width: 120,
 onChanged: (v) {
 _financialSummary[idx] = item.copyWith(value: v);
 _scheduleSave();
 },
 ),
 LaunchEditableCell(
 value: item.notes,
 hint: 'Notes',
 expand: true,
 onChanged: (v) {
 _financialSummary[idx] = item.copyWith(notes: v);
 _scheduleSave();
 },
 ),
 ],
 );
 },
 );
 }

 Widget _buildContractsPanel() {
 return LaunchDataTable(
 title: 'Contracts Status',
 subtitle:
 'All contracts requiring close-out. Import from execution or add manually.',
 columns: const [LaunchColumn(label: 'Contract', flexible: true, fieldType: LaunchFieldType.text, hint: 'Contract'), LaunchColumn(label: 'Vendor', width: 130, fieldType: LaunchFieldType.text, hint: 'Vendor'), LaunchColumn(label: 'Ref', width: 130, fieldType: LaunchFieldType.text, hint: 'Ref'), LaunchColumn(label: 'Value', width: 130, fieldType: LaunchFieldType.text, hint: 'Value'), LaunchColumn(label: 'Status', width: 120, fieldType: LaunchFieldType.dropdown, dropdownItems: LaunchContractItem.closeOutStatuses)],
 rowCount: _contracts.length,
 onAddValues: (values) {
 setState(() {
 _contracts.add(LaunchContractItem(
 contractName: values['Contract'] ?? '',
 vendor: values['Vendor'] ?? '',
 contractRef: values['Ref'] ?? '',
 value: values['Value'] ?? '',
 closeOutStatus: values['Status'] ?? 'Open',
 ));
 });
 _scheduleSave();
 },
 csvColumns: const [
 CsvColumnSpec(key: 'contract', label: 'Contract', sampleValue: 'Cloud Services Agreement'),
 CsvColumnSpec(key: 'vendor', label: 'Vendor', sampleValue: 'Acme Corp'),
 CsvColumnSpec(key: 'ref', label: 'Ref', sampleValue: 'CTR-001'),
 CsvColumnSpec(key: 'value', label: 'Value', sampleValue: '\$100,000'),
 CsvColumnSpec(key: 'status', label: 'Status', sampleValue: 'Open', allowedValues: ['Open', 'In Progress', 'Closed', 'Disputed']),
 ],
 onCsvImport: (rows) async {
 for (final row in rows) {
 setState(() {
 _contracts.add(LaunchContractItem(
 contractName: row['contract'] ?? '',
 vendor: row['vendor'] ?? '',
 contractRef: row['ref'] ?? '',
 value: row['value'] ?? '',
 closeOutStatus: row['status'] ?? 'Open',
 ));
 });
 }
 _scheduleSave();
 },
 importLabel: 'Import',
 onImport: _importContracts,
 emptyMessage: 'Import contracts from execution phase or add manually.',
 cellBuilder: (context, idx) {
 final item = _contracts[idx];
 return LaunchDataRow(
 onEdit: () => _scheduleSave(),
 onDelete: () async {
 final ok = await launchConfirmDelete(context, itemName: 'contract');
 if (!ok || !mounted) return;
 setState(() => _contracts.removeAt(idx));
 _scheduleSave();
 },
 onKazAi: () => _regenerateContractRow(idx),
 cells: [
 LaunchEditableCell(
 value: item.contractName,
 hint: 'Contract',
 bold: true,
 expand: true,
 onChanged: (v) {
 _contracts[idx] = item.copyWith(contractName: v);
 _scheduleSave();
 },
 ),
 LaunchEditableCell(
 value: item.vendor,
 hint: 'Vendor',
 width: 120,
 onChanged: (v) {
 _contracts[idx] = item.copyWith(vendor: v);
 _scheduleSave();
 },
 ),
 LaunchEditableCell(
 value: item.contractRef,
 hint: 'Ref',
 width: 130,
 onChanged: (v) {
 _contracts[idx] = item.copyWith(contractRef: v);
 _scheduleSave();
 },
 ),
 LaunchEditableCell(
 value: item.value,
 hint: 'Value',
 width: 130,
 onChanged: (v) {
 _contracts[idx] = item.copyWith(value: v);
 _scheduleSave();
 },
 ),
 LaunchStatusDropdown(
 value: item.closeOutStatus,
 items: LaunchContractItem.closeOutStatuses,
 onChanged: (v) {
 if (v == null) return;
 _contracts[idx] = item.copyWith(closeOutStatus: v);
 _scheduleSave();
 setState(() {});
 },
 ),
 ],
 );
 },
 );
 }

 Widget _buildCloseOutStepsPanel() {
 return LaunchDataTable(
 title: 'Close-Out Steps',
 subtitle: 'Standardized steps to verify each contract is fully closed.',
 columns: const [LaunchColumn(label: 'Step', flexible: true, fieldType: LaunchFieldType.text, hint: 'Step'), LaunchColumn(label: 'Contract Ref', width: 120, fieldType: LaunchFieldType.text, hint: 'Ref'), LaunchColumn(label: 'Status', width: 120, fieldType: LaunchFieldType.dropdown, dropdownItems: ['Pending', 'In Progress', 'Complete']), LaunchColumn(label: 'Notes', flexible: true, fieldType: LaunchFieldType.text, hint: 'Notes')],
 rowCount: _closeOutSteps.length,
 onAddValues: (values) {
 setState(() {
 _closeOutSteps.add(LaunchCloseOutStep(
 step: values['Step'] ?? '',
 contractRef: values['Contract Ref'] ?? '',
 status: values['Status'] ?? 'Pending',
 notes: values['Notes'] ?? '',
 ));
 });
 _scheduleSave();
 },
 csvColumns: const [
 CsvColumnSpec(key: 'step', label: 'Step', sampleValue: 'Verify deliverables accepted'),
 CsvColumnSpec(key: 'contractRef', label: 'Contract Ref', sampleValue: 'CTR-001'),
 CsvColumnSpec(key: 'status', label: 'Status', sampleValue: 'Pending', allowedValues: ['Pending', 'In Progress', 'Complete']),
 CsvColumnSpec(key: 'notes', label: 'Notes', sampleValue: 'Awaiting vendor confirmation'),
 ],
 onCsvImport: (rows) async {
 for (final row in rows) {
 setState(() {
 _closeOutSteps.add(LaunchCloseOutStep(
 step: row['step'] ?? '',
 contractRef: row['contractRef'] ?? '',
 status: row['status'] ?? 'Pending',
 notes: row['notes'] ?? '',
 ));
 });
 }
 _scheduleSave();
 },
 emptyMessage:
 'Add steps like: final deliverable accepted, payments settled, warranties confirmed.',
 cellBuilder: (context, idx) {
 final item = _closeOutSteps[idx];
 return LaunchDataRow(
 onEdit: () => _scheduleSave(),
 onDelete: () async {
 final ok =
 await launchConfirmDelete(context, itemName: 'close-out step');
 if (!ok || !mounted) return;
 setState(() => _closeOutSteps.removeAt(idx));
 _scheduleSave();
 },
 onKazAi: () => _regenerateCloseOutStepRow(idx),
 cells: [
 LaunchEditableCell(
 value: item.step,
 hint: 'Step',
 bold: true,
 expand: true,
 onChanged: (v) {
 _closeOutSteps[idx] = item.copyWith(step: v);
 _scheduleSave();
 },
 ),
 LaunchEditableCell(
 value: item.contractRef,
 hint: 'Ref',
 width: 130,
 onChanged: (v) {
 _closeOutSteps[idx] = item.copyWith(contractRef: v);
 _scheduleSave();
 },
 ),
 LaunchStatusDropdown(
 value: item.status,
 items: const ['Pending', 'In Progress', 'Complete'],
 onChanged: (v) {
 if (v == null) return;
 _closeOutSteps[idx] = item.copyWith(status: v);
 _scheduleSave();
 setState(() {});
 },
 ),
 LaunchEditableCell(
 value: item.notes,
 hint: 'Notes',
 expand: true,
 onChanged: (v) {
 _closeOutSteps[idx] = item.copyWith(notes: v);
 _scheduleSave();
 },
 ),
 ],
 );
 },
 );
 }

 Widget _buildSignOffsPanel() {
 return LaunchDataTable(
 title: 'Financial & Compliance Sign-Off',
 subtitle: 'Track approvals from finance, legal, and compliance.',
 columns: const [LaunchColumn(label: 'Approver', flexible: true, fieldType: LaunchFieldType.text, hint: 'Name'), LaunchColumn(label: 'Role', width: 120, fieldType: LaunchFieldType.text, hint: 'Role'), LaunchColumn(label: 'Status', width: 120, fieldType: LaunchFieldType.dropdown, dropdownItems: ['Pending', 'Approved', 'Rejected']), LaunchColumn(label: 'Date', width: 130, fieldType: LaunchFieldType.date, hint: 'Date'), LaunchColumn(label: 'Notes', flexible: true, fieldType: LaunchFieldType.text, hint: 'Notes')],
 rowCount: _signOffs.length,
 onAddValues: (values) {
 setState(() {
 _signOffs.add(LaunchApproval(
 stakeholder: values['Approver'] ?? '',
 role: values['Role'] ?? '',
 status: values['Status'] ?? 'Pending',
 date: values['Date'] ?? '',
 notes: values['Notes'] ?? '',
 ));
 });
 _scheduleSave();
 },
 csvColumns: const [
 CsvColumnSpec(key: 'approver', label: 'Approver', sampleValue: 'Jane Smith'),
 CsvColumnSpec(key: 'role', label: 'Role', sampleValue: 'Finance Director'),
 CsvColumnSpec(key: 'status', label: 'Status', sampleValue: 'Pending', allowedValues: ['Pending', 'Approved', 'Rejected']),
 CsvColumnSpec(key: 'date', label: 'Date', sampleValue: '2025-01-15'),
 CsvColumnSpec(key: 'notes', label: 'Notes', sampleValue: 'Under review'),
 ],
 onCsvImport: (rows) async {
 for (final row in rows) {
 setState(() {
 _signOffs.add(LaunchApproval(
 stakeholder: row['approver'] ?? '',
 role: row['role'] ?? '',
 status: row['status'] ?? 'Pending',
 date: row['date'] ?? '',
 notes: row['notes'] ?? '',
 ));
 });
 }
 _scheduleSave();
 },
 emptyMessage: 'Track finance and compliance approval status.',
 cellBuilder: (context, idx) {
 final item = _signOffs[idx];
 return LaunchDataRow(
 onEdit: () => _scheduleSave(),
 onDelete: () async {
 final ok = await launchConfirmDelete(context, itemName: 'sign-off');
 if (!ok || !mounted) return;
 setState(() => _signOffs.removeAt(idx));
 _scheduleSave();
 },
 onKazAi: () => _regenerateSignOffRow(idx),
 cells: [
 LaunchEditableCell(
 value: item.stakeholder,
 hint: 'Name',
 bold: true,
 expand: true,
 onChanged: (v) {
 _signOffs[idx] = item.copyWith(stakeholder: v);
 _scheduleSave();
 },
 ),
 LaunchEditableCell(
 value: item.role,
 hint: 'Role',
 expand: true,
 onChanged: (v) {
 _signOffs[idx] = item.copyWith(role: v);
 _scheduleSave();
 },
 ),
 LaunchStatusDropdown(
 value: item.status,
 items: const ['Pending', 'Approved', 'Rejected'],
 onChanged: (v) {
 if (v == null) return;
 _signOffs[idx] = item.copyWith(status: v);
 _scheduleSave();
 setState(() {});
 },
 ),
 LaunchDateCell(
 value: item.date,
 hint: 'Date',
 width: 130,
 onChanged: (v) {
 _signOffs[idx] = item.copyWith(date: v);
 _scheduleSave();
 },
 ),
 LaunchEditableCell(
 value: item.notes,
 hint: 'Notes',
 expand: true,
 onChanged: (v) {
 _signOffs[idx] = item.copyWith(notes: v);
 _scheduleSave();
 },
 ),
 ],
 );
 },
 );
 }

 Future<void> _importContracts() async {
 if (_projectId == null) return;
 final imported =
 await LaunchPhaseService.loadExecutionContracts(_projectId!);
 if (imported.isEmpty) {
 if (mounted) {
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(content: Text('No contracts found to import.')));
 }
 return;
 }
 setState(() {
 final existing = _contracts.map((c) => c.contractName).toSet();
 for (final c in imported) {
 if (!existing.contains(c.contractName)) _contracts.add(c);
 }
 });
 _scheduleSave();
 }

 void _scheduleSave() {
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
 await LaunchPhaseService.loadContractCloseOut(projectId: _projectId!);
 if (!mounted) return;
 setState(() {
 _contracts = r.contracts;
 _closeOutSteps = r.closeOutSteps;
 _signOffs = r.signOffs;
 _financialSummary = r.financialSummary;
 _isLoading = false;
 _hasLoaded = true;
 });
 final allEmpty = _contracts.isEmpty &&
 _closeOutSteps.isEmpty &&
 _signOffs.isEmpty &&
 _financialSummary.isEmpty;
 if (allEmpty) {
 await _autoPopulateFromPriorPhases();
 }

 final stillEmpty = _contracts.isEmpty &&
 _closeOutSteps.isEmpty &&
 _signOffs.isEmpty &&
 _financialSummary.isEmpty;
 if (stillEmpty) await _populateFromAi();
 } catch (e) {
 debugPrint('Contract close-out load error: $e');
 if (mounted) setState(() => _isLoading = false);
 }
 _suspendSave = false;
 }

 Future<void> _persistData() async {
 if (_projectId == null) return;
 try {
 await LaunchPhaseService.saveContractCloseOut(
 projectId: _projectId!,
 contracts: _contracts,
 closeOutSteps: _closeOutSteps,
 signOffs: _signOffs,
 financialSummary: _financialSummary,
 );
 } catch (e) {
 debugPrint('Contract close-out save error: $e');
 }
 }

 Future<void> _autoPopulateFromPriorPhases() async {
 if (_projectId == null) return;
 try {
 final cp = await LaunchPhaseAiSeed.loadCrossPhaseData(_projectId!);
 if (!mounted) return;

 // Pre-fill contracts from cross-phase data
 if (_contracts.isEmpty && cp.contracts.isNotEmpty) {
 final existing = _contracts.map((c) => c.contractName).toSet();
 final newContracts = cp.contracts
 .where((c) => !existing.contains(c.contractName))
 .toList();
 if (newContracts.isNotEmpty) {
 setState(() => _contracts.addAll(newContracts));
 }
 }

 // Pre-fill financial summary from budget calculations
 if (_financialSummary.isEmpty) {
 final newMetrics = <LaunchFinancialMetric>[];
 if (cp.totalPlannedBudget > 0) {
 newMetrics.add(LaunchFinancialMetric(
 label: 'Total Planned Budget',
 value: '\$${cp.totalPlannedBudget.toStringAsFixed(0)}',
 notes: 'From budget tracking',
 ));
 }
 if (cp.totalActualBudget > 0) {
 newMetrics.add(LaunchFinancialMetric(
 label: 'Total Actual Spend',
 value: '\$${cp.totalActualBudget.toStringAsFixed(0)}',
 notes: 'From budget tracking',
 ));
 }
 if (cp.totalPlannedBudget > 0 || cp.totalActualBudget > 0) {
 newMetrics.add(LaunchFinancialMetric(
 label: 'Budget Variance',
 value: '\$${cp.budgetVariance.toStringAsFixed(0)}',
 notes: cp.budgetVariance >= 0 ? 'Under budget' : 'Over budget',
 ));
 }
 if (cp.totalContractValue > 0) {
 newMetrics.add(LaunchFinancialMetric(
 label: 'Total Contract Value',
 value: '\$${cp.totalContractValue.toStringAsFixed(0)}',
 notes: 'From execution contracts',
 ));
 }
 if (newMetrics.isNotEmpty) {
 setState(() => _financialSummary.addAll(newMetrics));
 }
 }

 // Pre-fill close-out steps based on contract count
 if (_closeOutSteps.isEmpty && cp.contracts.isNotEmpty) {
 final newSteps = <LaunchCloseOutStep>[];
 for (final c in cp.contracts.take(3)) {
 newSteps.add(LaunchCloseOutStep(
 step: 'Verify deliverables accepted: ${c.contractName}',
 contractRef: c.contractRef,
 status: 'Pending',
 ));
 }
 newSteps.add(LaunchCloseOutStep(
 step: 'Confirm all payments settled',
 status: 'Pending',
 ));
 newSteps.add(LaunchCloseOutStep(
 step: 'Validate warranty and SLA documentation',
 status: 'Pending',
 ));
 if (newSteps.isNotEmpty) {
 setState(() => _closeOutSteps.addAll(newSteps));
 }
 }

 final hasNewData = _contracts.isNotEmpty ||
 _financialSummary.isNotEmpty ||
 _closeOutSteps.isNotEmpty;
 if (hasNewData) await _persistData();
 } catch (e) {
 debugPrint('Contract close-out auto-populate error: $e');
 }
 }

 Future<void> _populateFromAi() async {
 if (_isGenerating) return;

 setState(() => _isGenerating = true);
 LaunchAiResult? result;
 try {
 result = await LaunchPhaseAiSeed.generateEntries(
 context: context,
 sectionLabel: 'Contract Close Out',
 sections: const {
 'financial_summary':
 'Financial metrics with "label", "value", "notes"',
 'contracts': 'Contracts with "contract_name", "vendor", "value", "close_out_status"',
 'closeout_steps': 'Close-out verification steps with "step", "status", "notes"',
 'signoffs': 'Finance and compliance approvers with "stakeholder", "role", "status"',
 },
 itemsPerSection: 3,
 );
 } catch (e) {
 debugPrint('Contract AI error: $e');
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

 final hasData = _contracts.isNotEmpty ||
 _closeOutSteps.isNotEmpty ||
 _signOffs.isNotEmpty ||
 _financialSummary.isNotEmpty;
 if (hasData) {
 setState(() => _isGenerating = false);
 return;
 }
 setState(() {
 _financialSummary = _mapMetrics(generated['financial_summary']);
 _contracts = _mapContracts(generated['contracts']);
 _closeOutSteps = _mapSteps(generated['closeout_steps']);
 _signOffs = _mapApprovals(generated['signoffs']);
 _isGenerating = false;
 });
 await _persistData();
 }

 // ── KAZ AI Row Regeneration ─────────────────────────────────────────────

 Future<void> _regenerateFinancialRow(int index) async {
 if (index < 0 || index >= _financialSummary.length) return;
 final key = 'financial_$index';
 if (_kazAiRegenerating[key] == true) return;
 setState(() => _kazAiRegenerating[key] = true);
 try {
 final projectData = ProjectDataHelper.getData(context);
 final ctx = ProjectDataHelper.buildProjectContextScan(projectData, sectionLabel: 'Financial Summary');
 final openai = OpenAiServiceSecure();
 final result = await openai.generateCompletion(
 'Based on this project context, suggest a financial metric name, value, and notes for contract close-out.\n\nContext:\n$ctx\n\nReturn ONLY a valid JSON object with keys: "label", "value", "notes".',
 maxTokens: 250, temperature: 0.6,
 );
 final start = result.indexOf('{');
 final end = result.lastIndexOf('}');
 if (start != -1 && end != -1) {
 final parsed = jsonDecode(result.substring(start, end + 1)) as Map<String, dynamic>;
 if (mounted) {
 setState(() {
 _financialSummary[index] = _financialSummary[index].copyWith(
 label: (parsed['label'] ?? '').toString(),
 value: (parsed['value'] ?? '').toString(),
 notes: (parsed['notes'] ?? _financialSummary[index].notes).toString(),
 );
 });
 _scheduleSave();
 }
 }
 } catch (e) {
 if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('KAZ AI failed: $e')));
 } finally {
 if (mounted) setState(() => _kazAiRegenerating[key] = false);
 }
 }

 Future<void> _regenerateContractRow(int index) async {
 if (index < 0 || index >= _contracts.length) return;
 final key = 'contract_$index';
 if (_kazAiRegenerating[key] == true) return;
 setState(() => _kazAiRegenerating[key] = true);
 try {
 final projectData = ProjectDataHelper.getData(context);
 final ctx = ProjectDataHelper.buildProjectContextScan(projectData, sectionLabel: 'Contract Close Out');
 final openai = OpenAiServiceSecure();
 final result = await openai.generateCompletion(
 'Based on this project context, suggest a contract name, vendor, ref, value, and close-out status.\n\nContext:\n$ctx\n\nReturn ONLY a valid JSON object with keys: "contract_name", "vendor", "ref", "value", "status". Status must be Open, In Progress, Closed, or Disputed.',
 maxTokens: 250, temperature: 0.6,
 );
 final start = result.indexOf('{');
 final end = result.lastIndexOf('}');
 if (start != -1 && end != -1) {
 final parsed = jsonDecode(result.substring(start, end + 1)) as Map<String, dynamic>;
 if (mounted) {
 setState(() {
 _contracts[index] = _contracts[index].copyWith(
 contractName: (parsed['contract_name'] ?? '').toString(),
 vendor: (parsed['vendor'] ?? _contracts[index].vendor).toString(),
 contractRef: (parsed['ref'] ?? _contracts[index].contractRef).toString(),
 value: (parsed['value'] ?? _contracts[index].value).toString(),
 closeOutStatus: (parsed['status'] ?? _contracts[index].closeOutStatus).toString(),
 );
 });
 _scheduleSave();
 }
 }
 } catch (e) {
 if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('KAZ AI failed: $e')));
 } finally {
 if (mounted) setState(() => _kazAiRegenerating[key] = false);
 }
 }

 Future<void> _regenerateCloseOutStepRow(int index) async {
 if (index < 0 || index >= _closeOutSteps.length) return;
 final key = 'step_$index';
 if (_kazAiRegenerating[key] == true) return;
 setState(() => _kazAiRegenerating[key] = true);
 try {
 final projectData = ProjectDataHelper.getData(context);
 final ctx = ProjectDataHelper.buildProjectContextScan(projectData, sectionLabel: 'Close-Out Steps');
 final openai = OpenAiServiceSecure();
 final result = await openai.generateCompletion(
 'Based on this project context, suggest a close-out verification step, contract ref, and notes.\n\nContext:\n$ctx\n\nReturn ONLY a valid JSON object with keys: "step", "contract_ref", "status", "notes". Status must be Pending, In Progress, or Complete.',
 maxTokens: 250, temperature: 0.6,
 );
 final start = result.indexOf('{');
 final end = result.lastIndexOf('}');
 if (start != -1 && end != -1) {
 final parsed = jsonDecode(result.substring(start, end + 1)) as Map<String, dynamic>;
 if (mounted) {
 setState(() {
 _closeOutSteps[index] = _closeOutSteps[index].copyWith(
 step: (parsed['step'] ?? '').toString(),
 contractRef: (parsed['contract_ref'] ?? _closeOutSteps[index].contractRef).toString(),
 status: (parsed['status'] ?? _closeOutSteps[index].status).toString(),
 notes: (parsed['notes'] ?? _closeOutSteps[index].notes).toString(),
 );
 });
 _scheduleSave();
 }
 }
 } catch (e) {
 if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('KAZ AI failed: $e')));
 } finally {
 if (mounted) setState(() => _kazAiRegenerating[key] = false);
 }
 }

 Future<void> _regenerateSignOffRow(int index) async {
 if (index < 0 || index >= _signOffs.length) return;
 final key = 'signoff_$index';
 if (_kazAiRegenerating[key] == true) return;
 setState(() => _kazAiRegenerating[key] = true);
 try {
 final projectData = ProjectDataHelper.getData(context);
 final ctx = ProjectDataHelper.buildProjectContextScan(projectData, sectionLabel: 'Financial & Compliance Sign-Off');
 final openai = OpenAiServiceSecure();
 final result = await openai.generateCompletion(
 'Based on this project context, suggest a finance/compliance approver name, role, and status.\n\nContext:\n$ctx\n\nReturn ONLY a valid JSON object with keys: "stakeholder", "role", "status", "notes". Status must be Pending, Approved, or Rejected.',
 maxTokens: 250, temperature: 0.6,
 );
 final start = result.indexOf('{');
 final end = result.lastIndexOf('}');
 if (start != -1 && end != -1) {
 final parsed = jsonDecode(result.substring(start, end + 1)) as Map<String, dynamic>;
 if (mounted) {
 setState(() {
 _signOffs[index] = _signOffs[index].copyWith(
 stakeholder: (parsed['stakeholder'] ?? '').toString(),
 role: (parsed['role'] ?? _signOffs[index].role).toString(),
 status: (parsed['status'] ?? _signOffs[index].status).toString(),
 notes: (parsed['notes'] ?? _signOffs[index].notes).toString(),
 );
 });
 _scheduleSave();
 }
 }
 } catch (e) {
 if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('KAZ AI failed: $e')));
 } finally {
 if (mounted) setState(() => _kazAiRegenerating[key] = false);
 }
 }

 List<LaunchFinancialMetric> _mapMetrics(List<Map<String, dynamic>>? r) =>
 (r ?? [])
 .map((m) => LaunchFinancialMetric(
 label: (m['title'] ?? '').toString().trim(),
 value: (m['details'] ?? '').toString().trim()))
 .where((i) => i.label.isNotEmpty)
 .toList();
 List<LaunchContractItem> _mapContracts(
 List<Map<String, dynamic>>? r) =>
 (r ?? [])
 .map((m) => LaunchContractItem(
 contractName: (m['title'] ?? '').toString().trim(),
 vendor: (m['details'] ?? '').toString().trim(),
 closeOutStatus: _ns(m['status'], 'Open')))
 .where((i) => i.contractName.isNotEmpty)
 .toList();
 List<LaunchCloseOutStep> _mapSteps(List<Map<String, dynamic>>? r) => (r ?? [])
 .map((m) => LaunchCloseOutStep(
 step: (m['title'] ?? '').toString().trim(),
 notes: (m['details'] ?? '').toString().trim(),
 status: _ns(m['status'], 'Pending')))
 .where((i) => i.step.isNotEmpty)
 .toList();
 List<LaunchApproval> _mapApprovals(List<Map<String, dynamic>>? r) => (r ?? [])
 .map((m) => LaunchApproval(
 stakeholder: (m['title'] ?? '').toString().trim(),
 role: (m['details'] ?? '').toString().trim(),
 status: _ns(m['status'], 'Pending')))
 .where((i) => i.stakeholder.isNotEmpty)
 .toList();
 String _ns(dynamic v, String fb) =>
 (v ?? '').toString().trim().isEmpty ? fb : v.toString().trim();

 Future<void> _exportPdf() async {
 setState(() => _isExporting = true);
 try {
 final projectData = ProjectDataHelper.getData(context);
 final projectName = projectData.projectName;
 final now = DateTime.now();
 final stamp =
 '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
 final filename =
 'contract_close_out_${projectName.replaceAll(' ', '_')}_$stamp.pdf';

 final doc = pw.Document();

 doc.addPage(
 pw.MultiPage(
 pageFormat: PdfPageFormat.a4,
 margin: const pw.EdgeInsets.all(32),
 build: (_) => [
 pw.Text(
 'Contract Close Out',
 style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
 ),
 pw.SizedBox(height: 4),
 pw.Text(
 '$projectName — Generated ${now.toLocal().toIso8601String()}',
 style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
 ),
 pw.SizedBox(height: 16),
 _pdfSectionTitle('Financial Summary'),
 pw.SizedBox(height: 6),
 if (_financialSummary.isEmpty)
 pw.Text('No financial metrics.',
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
 headers: const ['Metric', 'Value', 'Notes'],
 data: _financialSummary
 .map((m) => [
 _pc(m.label),
 _pc(m.value),
 _pc(m.notes),
 ])
 .toList(),
 ),
 pw.SizedBox(height: 20),
 _pdfSectionTitle('Contracts Status'),
 pw.SizedBox(height: 6),
 if (_contracts.isEmpty)
 pw.Text('No contracts.',
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
 headers: const ['Contract', 'Vendor', 'Ref', 'Value', 'Status'],
 data: _contracts
 .map((c) => [
 _pc(c.contractName),
 _pc(c.vendor),
 _pc(c.contractRef),
 _pc(c.value),
 _pc(c.closeOutStatus),
 ])
 .toList(),
 ),
 pw.SizedBox(height: 20),
 _pdfSectionTitle('Close-Out Steps'),
 pw.SizedBox(height: 6),
 if (_closeOutSteps.isEmpty)
 pw.Text('No close-out steps.',
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
 headers: const ['Step', 'Contract Ref', 'Status', 'Notes'],
 data: _closeOutSteps
 .map((s) => [
 _pc(s.step),
 _pc(s.contractRef),
 _pc(s.status),
 _pc(s.notes),
 ])
 .toList(),
 ),
 pw.SizedBox(height: 20),
 _pdfSectionTitle('Financial & Compliance Sign-Off'),
 pw.SizedBox(height: 6),
 if (_signOffs.isEmpty)
 pw.Text('No sign-off records.',
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
 'Approver',
 'Role',
 'Status',
 'Date',
 'Notes'
 ],
 data: _signOffs
 .map((s) => [
 _pc(s.stakeholder),
 _pc(s.role),
 _pc(s.status),
 _pc(s.date),
 _pc(s.notes),
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
    final totalContracts =
            projectData.contractors.length + projectData.vendors.length;
        final closed = projectData.contractors
                .where((c) =>
                    c.status.toLowerCase() == 'closed' ||
                    c.status.toLowerCase() == 'complete')
                .length +
            projectData.vendors
                .where((v) =>
                    v.procurementStage.toLowerCase() == 'closed' ||
                    v.procurementStage.toLowerCase() == 'complete')
                .length;
        final completionPct =
            totalContracts == 0 ? 0.0 : closed / totalContracts;
    return LaunchInsightsHeader(
      sectionTitle: 'Vendor & Contract Closeout Progress',
      sectionSubtitle: 'Final invoices, deliverables, sign-offs, and retention releases',
      sectionIcon: Icons.handshake_outlined,
      sectionColor: const Color(0xFF7C3AED),
      completionPercent: completionPct,
      completionLabel: 'CLOSED',
      completionCaption:
          '${(completionPct * 100).round()}% complete - auto-derived from project data',
      kpiTiles: [
        LaunchKpiTile(
              label: 'Contractors',
              value: '${projectData.contractors.length}',
              icon: Icons.construction_outlined,
              color: const Color(0xFF2563EB),
              delta: 'to close out',
            ),
            LaunchKpiTile(
              label: 'Vendors',
              value: '${projectData.vendors.length}',
              icon: Icons.inventory_2_outlined,
              color: const Color(0xFFF59E0B),
              delta: 'final invoices',
            ),
            LaunchKpiTile(
              label: 'Contract Value',
              value: '\$${projectData.contractors.fold<double>(0, (s, c) => s + c.estimatedCost).toStringAsFixed(0)}',
              icon: Icons.payments_outlined,
              color: const Color(0xFFD97706),
              delta: 'total awarded',
            ),
            LaunchKpiTile(
              label: 'Pending Sign-off',
              value: '${projectData.contractors.where((c) => c.status.toLowerCase() != 'closed' && c.status.toLowerCase() != 'complete').length}',
              icon: Icons.pending_actions_outlined,
              color: const Color(0xFFEF4444),
              delta: 'awaiting close',
            ),
      ],
    );
  }


}
