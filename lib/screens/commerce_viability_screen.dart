import 'dart:convert';
import 'package:ndu_project/utils/download_helper_stub.dart'
 if (dart.library.html) 'package:ndu_project/utils/download_helper_web.dart' as loader;
import 'package:flutter/material.dart';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'package:ndu_project/models/launch_phase_models.dart';
import 'package:ndu_project/screens/actual_vs_planned_gap_analysis_screen.dart';
import 'package:ndu_project/screens/financial_closeout_screen.dart';
import 'package:ndu_project/screens/summarize_account_risks_screen.dart';
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
class CommerceViabilityScreen extends StatefulWidget {
 const CommerceViabilityScreen({super.key});

 static void open(BuildContext context) {
 Navigator.of(context).push(
 MaterialPageRoute(builder: (_) => const CommerceViabilityScreen()),
 );
 }

 @override
 State<CommerceViabilityScreen> createState() =>
 _CommerceViabilityScreenState();
}

class _CommerceViabilityScreenState extends State<CommerceViabilityScreen> {
 List<LaunchWarrantyItem> _warranties = [];
 List<LaunchOpsCostItem> _opsCosts = [];
 List<LaunchFinancialMetric> _financialMetrics = [];
 List<LaunchFollowUpItem> _recommendations = [];
 LaunchClosureNotes _decision = LaunchClosureNotes();

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
 activeItemLabel: '6. Hypercare & Warranty Support',
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
 title: 'Hypercare & Warranty Support',
showNavigationButtons: false, onExportPdf: _exportPdf),
 const SizedBox(height: 20),
            _buildLaunchInsights(),
            const SizedBox(height: 16),
 _buildMetricsRow(),
 const SizedBox(height: 20),
 _buildFinancialMetricsPanel(),
 const SizedBox(height: 16),
 _buildWarrantiesPanel(),
 const SizedBox(height: 16),
 _buildOpsCostsPanel(),
 const SizedBox(height: 16),
 _buildDecisionPanel(),
 const SizedBox(height: 16),
 _buildRecommendationsPanel(),
 const SizedBox(height: 24),
 LaunchPhaseNavigation(
 backLabel: 'Back: Scope & Deliverable Reconciliation',
 nextLabel: 'Next: Financial Closeout',
 onBack: () => ActualVsPlannedGapAnalysisScreen.open(context),
 onNext: () => FinancialCloseoutScreen.open(context),
 ),
 const SizedBox(height: 48),
 ],
 ),
 ),
 );
 }



 Widget _buildMetricsRow() {
 final activeWarranties =
 _warranties.where((w) => w.status == 'Active').length;
 final monthlyTotal = _opsCosts.fold<double>(
 0,
 (sum, c) =>
 sum +
 (double.tryParse(c.monthlyCost.replaceAll(RegExp(r'[^\d.]'), '')) ??
 0));
 return ExecutionMetricsGrid(
 metrics: [
 ExecutionMetricData(
 label: 'Active Warranties',
 value: '$activeWarranties',
 icon: Icons.verified_user_outlined,
 emphasisColor: const Color(0xFF2563EB)),
 ExecutionMetricData(
 label: 'Monthly Ops Cost',
 value:
 monthlyTotal > 0 ? '\$${monthlyTotal.toStringAsFixed(0)}' : '—',
 icon: Icons.trending_up_outlined,
 emphasisColor: const Color(0xFF10B981)),
 ExecutionMetricData(
 label: 'Financial Metrics',
 value: '${_financialMetrics.length}',
 icon: Icons.analytics_outlined,
 emphasisColor: const Color(0xFF8B5CF6)),
 ExecutionMetricData(
 label: 'Recommendations',
 value: '${_recommendations.length}',
 icon: Icons.lightbulb_outline,
 emphasisColor: const Color(0xFFF59E0B)),
 ],
 );
 }

 Widget _buildFinancialMetricsPanel() {
 return LaunchDataTable(
 title: 'Financial Metrics',
 subtitle: 'ROI, payback period, total investment, and projected returns.',
 columns: const [
 LaunchColumn(label: 'Metric', flexible: true, fieldType: LaunchFieldType.text, hint: 'Metric'),
 LaunchColumn(label: 'Value', width: 120, fieldType: LaunchFieldType.text, hint: 'Value'),
 LaunchColumn(label: 'Notes', flexible: true, fieldType: LaunchFieldType.text, hint: 'Notes'),
 ],
 rowCount: _financialMetrics.length,
 onAddValues: (values) {
 setState(() {
 _financialMetrics.add(LaunchFinancialMetric(
 label: values['Metric'] ?? '',
 value: values['Value'] ?? '',
 notes: values['Notes'] ?? '',
 ));
 });
 _save();
 },
 csvColumns: const [
 CsvColumnSpec(key: 'metric', label: 'Metric', sampleValue: 'ROI'),
 CsvColumnSpec(key: 'value', label: 'Value', sampleValue: '150%'),
 CsvColumnSpec(key: 'notes', label: 'Notes', sampleValue: '3-year projection'),
 ],
 onCsvImport: (rows) async {
 for (final row in rows) {
 setState(() {
 _financialMetrics.add(LaunchFinancialMetric(
 label: row['metric'] ?? '',
 value: row['value'] ?? '',
 notes: row['notes'] ?? '',
 ));
 });
 }
 _save();
 },
 emptyMessage:
 'Track total investment, projected return, ROI, payback period.',
 cellBuilder: (context, i) {
 final m = _financialMetrics[i];
 return LaunchDataRow(
 onDelete: () async {
 final confirmed = await launchConfirmDelete(context,
 itemName: 'financial metric');
 if (!confirmed || !mounted) return;
 setState(() => _financialMetrics.removeAt(i));
 _save();
 },
 onKazAi: () => _regenerateFinancialMetricRow(i),
 cells: [
 LaunchEditableCell(
 value: m.label,
 hint: 'Metric',
 bold: true,
 expand: true,
 onChanged: (s) {
 _financialMetrics[i] = m.copyWith(label: s);
 _save();
 },
 ),
 LaunchEditableCell(
 value: m.value,
 hint: 'Value',
 width: 120,
 onChanged: (s) {
 _financialMetrics[i] = m.copyWith(value: s);
 _save();
 },
 ),
 LaunchEditableCell(
 value: m.notes,
 hint: 'Notes',
 expand: true,
 onChanged: (s) {
 _financialMetrics[i] = m.copyWith(notes: s);
 _save();
 },
 ),
 ],
 );
 },
 );
 }

 Widget _buildWarrantiesPanel() {
 return LaunchDataTable(
 title: 'Warranty Tracker',
 subtitle:
 'Track warranty coverage for deliverables, equipment, and services.',
 columns: const [
 LaunchColumn(label: 'Item', flexible: true, fieldType: LaunchFieldType.text, hint: 'Item'),
 LaunchColumn(label: 'Vendor', width: 130, fieldType: LaunchFieldType.text, hint: 'Vendor'),
 LaunchColumn(label: 'Type', width: 130, fieldType: LaunchFieldType.text, hint: 'Type'),
 LaunchColumn(label: 'Start', width: 130, fieldType: LaunchFieldType.date, hint: 'Start'),
 LaunchColumn(label: 'Expiry', width: 130, fieldType: LaunchFieldType.date, hint: 'Expiry'),
 LaunchColumn(label: 'Status', width: 120, fieldType: LaunchFieldType.dropdown, dropdownItems: ['Active', 'Expiring Soon', 'Expired', 'Claimed']),
 ],
 rowCount: _warranties.length,
 onAddValues: (values) {
 setState(() {
 _warranties.add(LaunchWarrantyItem(
 item: values['Item'] ?? '',
 vendor: values['Vendor'] ?? '',
 warrantyType: values['Type'] ?? '',
 startDate: values['Start'] ?? '',
 expiryDate: values['Expiry'] ?? '',
 status: values['Status'] ?? 'Active',
 ));
 });
 _save();
 },
 csvColumns: const [
 CsvColumnSpec(key: 'item', label: 'Item', sampleValue: 'Server hardware'),
 CsvColumnSpec(key: 'vendor', label: 'Vendor', sampleValue: 'Dell'),
 CsvColumnSpec(key: 'type', label: 'Type', sampleValue: 'Standard'),
 CsvColumnSpec(key: 'start', label: 'Start', sampleValue: '2025-01-01'),
 CsvColumnSpec(key: 'expiry', label: 'Expiry', sampleValue: '2028-01-01'),
 CsvColumnSpec(key: 'status', label: 'Status', sampleValue: 'Active', allowedValues: ['Active', 'Expiring Soon', 'Expired', 'Claimed']),
 ],
 onCsvImport: (rows) async {
 for (final row in rows) {
 setState(() {
 _warranties.add(LaunchWarrantyItem(
 item: row['item'] ?? '',
 vendor: row['vendor'] ?? '',
 warrantyType: row['type'] ?? '',
 startDate: row['start'] ?? '',
 expiryDate: row['expiry'] ?? '',
 status: row['status'] ?? 'Active',
 ));
 });
 }
 _save();
 },
 emptyMessage: 'Add warranty items with vendor, type, and expiry.',
 cellBuilder: (context, i) {
 final w = _warranties[i];
 return LaunchDataRow(
 onDelete: () async {
 final confirmed =
 await launchConfirmDelete(context, itemName: 'warranty');
 if (!confirmed || !mounted) return;
 setState(() => _warranties.removeAt(i));
 _save();
 },
 onKazAi: () => _regenerateWarrantyRow(i),
 cells: [
 LaunchEditableCell(
 value: w.item,
 hint: 'Item',
 bold: true,
 expand: true,
 onChanged: (s) {
 _warranties[i] = w.copyWith(item: s);
 _save();
 },
 ),
 LaunchEditableCell(
 value: w.vendor,
 hint: 'Vendor',
 width: 130,
 onChanged: (s) {
 _warranties[i] = w.copyWith(vendor: s);
 _save();
 },
 ),
 LaunchEditableCell(
 value: w.warrantyType,
 hint: 'Type',
 width: 130,
 onChanged: (s) {
 _warranties[i] = w.copyWith(warrantyType: s);
 _save();
 },
 ),
 LaunchDateCell(
 value: w.startDate,
 hint: 'Start',
 width: 130,
 onChanged: (s) {
 _warranties[i] = w.copyWith(startDate: s);
 _save();
 },
 ),
 LaunchDateCell(
 value: w.expiryDate,
 hint: 'Expiry',
 width: 130,
 onChanged: (s) {
 _warranties[i] = w.copyWith(expiryDate: s);
 _save();
 },
 ),
 LaunchStatusDropdown(
 value: w.status,
 items: const ['Active', 'Expiring Soon', 'Expired', 'Claimed'],
 width: 120,
 onChanged: (s) {
 if (s == null) return;
 _warranties[i] = w.copyWith(status: s);
 _save();
 setState(() {});
 },
 ),
 ],
 );
 },
 );
 }

 Widget _buildOpsCostsPanel() {
 return LaunchDataTable(
 title: 'Operations Cost Projection',
 subtitle: 'Monthly and annual ongoing costs post-launch.',
 columns: const [
 LaunchColumn(label: 'Category', flexible: true, fieldType: LaunchFieldType.text, hint: 'Category'),
 LaunchColumn(label: 'Monthly', width: 130, fieldType: LaunchFieldType.text, hint: 'Monthly'),
 LaunchColumn(label: 'Annual', width: 130, fieldType: LaunchFieldType.text, hint: 'Annual'),
 LaunchColumn(label: 'Notes', flexible: true, fieldType: LaunchFieldType.text, hint: 'Notes'),
 ],
 rowCount: _opsCosts.length,
 onAddValues: (values) {
 setState(() {
 _opsCosts.add(LaunchOpsCostItem(
 category: values['Category'] ?? '',
 monthlyCost: values['Monthly'] ?? '',
 annualCost: values['Annual'] ?? '',
 notes: values['Notes'] ?? '',
 ));
 });
 _save();
 },
 csvColumns: const [
 CsvColumnSpec(key: 'category', label: 'Category', sampleValue: 'Cloud Hosting'),
 CsvColumnSpec(key: 'monthly', label: 'Monthly', sampleValue: '\$5,000'),
 CsvColumnSpec(key: 'annual', label: 'Annual', sampleValue: '\$60,000'),
 CsvColumnSpec(key: 'notes', label: 'Notes', sampleValue: 'AWS production environment'),
 ],
 onCsvImport: (rows) async {
 for (final row in rows) {
 setState(() {
 _opsCosts.add(LaunchOpsCostItem(
 category: row['category'] ?? '',
 monthlyCost: row['monthly'] ?? '',
 annualCost: row['annual'] ?? '',
 notes: row['notes'] ?? '',
 ));
 });
 }
 _save();
 },
 emptyMessage:
 'Project infrastructure, licenses, support, and maintenance costs.',
 cellBuilder: (context, i) {
 final c = _opsCosts[i];
 return LaunchDataRow(
 onDelete: () async {
 final confirmed =
 await launchConfirmDelete(context, itemName: 'cost projection');
 if (!confirmed || !mounted) return;
 setState(() => _opsCosts.removeAt(i));
 _save();
 },
 onKazAi: () => _regenerateOpsCostRow(i),
 cells: [
 LaunchEditableCell(
 value: c.category,
 hint: 'Category',
 bold: true,
 expand: true,
 onChanged: (s) {
 _opsCosts[i] = c.copyWith(category: s);
 _save();
 },
 ),
 LaunchEditableCell(
 value: c.monthlyCost,
 hint: 'Monthly',
 width: 130,
 onChanged: (s) {
 _opsCosts[i] = c.copyWith(monthlyCost: s);
 _save();
 },
 ),
 LaunchEditableCell(
 value: c.annualCost,
 hint: 'Annual',
 width: 130,
 onChanged: (s) {
 _opsCosts[i] = c.copyWith(annualCost: s);
 _save();
 },
 ),
 LaunchEditableCell(
 value: c.notes,
 hint: 'Notes',
 expand: true,
 onChanged: (s) {
 _opsCosts[i] = c.copyWith(notes: s);
 _save();
 },
 ),
 ],
 );
 },
 );
 }

 Widget _buildDecisionPanel() {
 return ExecutionPanelShell(
 title: 'Commercial Decision',
 subtitle: 'Record the go / grow / pause recommendation with rationale.',
 collapsible: true,
 initiallyExpanded: false,
 headerIcon: Icons.trending_up_rounded,
 headerIconColor: const Color(0xFF10B981),
 child: VoiceTextFormField(
 initialValue: _decision.notes,
 maxLines: 4,
 style: const TextStyle(fontSize: 13, height: 1.6),
 decoration: InputDecoration(
 hintText:
 'Go / Grow / Pause — provide recommendation and supporting context…',
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
 _decision = LaunchClosureNotes(notes: v);
 _save();
 },
 ),
 );
 }

 Widget _buildRecommendationsPanel() {
 return LaunchDataTable(
 title: 'Recommendations',
 subtitle: 'Key actions for commercial sustainability.',
 columns: const [
 LaunchColumn(label: 'Recommendation', flexible: true, fieldType: LaunchFieldType.text, hint: 'Title'),
 LaunchColumn(label: 'Details', flexible: true, fieldType: LaunchFieldType.text, hint: 'Details'),
 LaunchColumn(label: 'Status', width: 120, fieldType: LaunchFieldType.dropdown, dropdownItems: ['Open', 'In Progress', 'Complete']),
 ],
 rowCount: _recommendations.length,
 onAddValues: (values) {
 setState(() {
 _recommendations.add(LaunchFollowUpItem(
 title: values['Recommendation'] ?? '',
 details: values['Details'] ?? '',
 status: values['Status'] ?? 'Open',
 ));
 });
 _save();
 },
 csvColumns: const [
 CsvColumnSpec(key: 'recommendation', label: 'Recommendation', sampleValue: 'Negotiate extended warranty'),
 CsvColumnSpec(key: 'details', label: 'Details', sampleValue: 'Extend server warranty by 2 years'),
 CsvColumnSpec(key: 'status', label: 'Status', sampleValue: 'Open', allowedValues: ['Open', 'In Progress', 'Complete']),
 ],
 onCsvImport: (rows) async {
 for (final row in rows) {
 setState(() {
 _recommendations.add(LaunchFollowUpItem(
 title: row['recommendation'] ?? '',
 details: row['details'] ?? '',
 status: row['status'] ?? 'Open',
 ));
 });
 }
 _save();
 },
 emptyMessage: 'Add actions to ensure commercial viability.',
 cellBuilder: (context, i) {
 final r = _recommendations[i];
 return LaunchDataRow(
 onDelete: () async {
 final confirmed =
 await launchConfirmDelete(context, itemName: 'recommendation');
 if (!confirmed || !mounted) return;
 setState(() => _recommendations.removeAt(i));
 _save();
 },
 onKazAi: () => _regenerateRecommendationRow(i),
 cells: [
 LaunchEditableCell(
 value: r.title,
 hint: 'Title',
 bold: true,
 expand: true,
 onChanged: (s) {
 _recommendations[i] = r.copyWith(title: s);
 _save();
 },
 ),
 LaunchEditableCell(
 value: r.details,
 hint: 'Details',
 expand: true,
 onChanged: (s) {
 _recommendations[i] = r.copyWith(details: s);
 _save();
 },
 ),
 LaunchStatusDropdown(
 value: r.status,
 items: const ['Open', 'In Progress', 'Complete'],
 width: 120,
 onChanged: (s) {
 if (s == null) return;
 _recommendations[i] = r.copyWith(status: s);
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

 Future<void> _regenerateFinancialMetricRow(int index) async {
 if (index < 0 || index >= _financialMetrics.length) return;
 final key = 'metric_$index';
 if (_kazAiRegenerating[key] == true) return;
 setState(() => _kazAiRegenerating[key] = true);
 try {
 final projectData = ProjectDataHelper.getData(context);
 final ctx = ProjectDataHelper.buildProjectContextScan(projectData, sectionLabel: 'Financial Metrics');
 final openai = OpenAiServiceSecure();
 final result = await openai.generateCompletion(
 'Based on this project context, suggest a financial metric name, value, and notes.\n\nContext:\n$ctx\n\nReturn ONLY a valid JSON object with keys: "label", "value", "notes".',
 maxTokens: 250, temperature: 0.6,
 );
 final start = result.indexOf('{');
 final end = result.lastIndexOf('}');
 if (start != -1 && end != -1) {
 final parsed = jsonDecode(result.substring(start, end + 1)) as Map<String, dynamic>;
 if (mounted) {
 setState(() {
 _financialMetrics[index] = _financialMetrics[index].copyWith(
 label: (parsed['label'] ?? '').toString(),
 value: (parsed['value'] ?? '').toString(),
 notes: (parsed['notes'] ?? _financialMetrics[index].notes).toString(),
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

 Future<void> _regenerateWarrantyRow(int index) async {
 if (index < 0 || index >= _warranties.length) return;
 final key = 'warranty_$index';
 if (_kazAiRegenerating[key] == true) return;
 setState(() => _kazAiRegenerating[key] = true);
 try {
 final projectData = ProjectDataHelper.getData(context);
 final ctx = ProjectDataHelper.buildProjectContextScan(projectData, sectionLabel: 'Warranty Tracker');
 final openai = OpenAiServiceSecure();
 final result = await openai.generateCompletion(
 'Based on this project context, suggest a warranty item name, vendor, type, and status.\n\nContext:\n$ctx\n\nReturn ONLY a valid JSON object with keys: "item", "vendor", "type", "status". Status must be Active, Expiring Soon, Expired, or Claimed.',
 maxTokens: 250, temperature: 0.6,
 );
 final start = result.indexOf('{');
 final end = result.lastIndexOf('}');
 if (start != -1 && end != -1) {
 final parsed = jsonDecode(result.substring(start, end + 1)) as Map<String, dynamic>;
 if (mounted) {
 setState(() {
 _warranties[index] = _warranties[index].copyWith(
 item: (parsed['item'] ?? '').toString(),
 vendor: (parsed['vendor'] ?? _warranties[index].vendor).toString(),
 warrantyType: (parsed['type'] ?? _warranties[index].warrantyType).toString(),
 status: (parsed['status'] ?? _warranties[index].status).toString(),
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

 Future<void> _regenerateOpsCostRow(int index) async {
 if (index < 0 || index >= _opsCosts.length) return;
 final key = 'opscost_$index';
 if (_kazAiRegenerating[key] == true) return;
 setState(() => _kazAiRegenerating[key] = true);
 try {
 final projectData = ProjectDataHelper.getData(context);
 final ctx = ProjectDataHelper.buildProjectContextScan(projectData, sectionLabel: 'Operations Cost Projection');
 final openai = OpenAiServiceSecure();
 final result = await openai.generateCompletion(
 'Based on this project context, suggest an operations cost category, monthly cost, annual cost, and notes.\n\nContext:\n$ctx\n\nReturn ONLY a valid JSON object with keys: "category", "monthly", "annual", "notes".',
 maxTokens: 250, temperature: 0.6,
 );
 final start = result.indexOf('{');
 final end = result.lastIndexOf('}');
 if (start != -1 && end != -1) {
 final parsed = jsonDecode(result.substring(start, end + 1)) as Map<String, dynamic>;
 if (mounted) {
 setState(() {
 _opsCosts[index] = _opsCosts[index].copyWith(
 category: (parsed['category'] ?? '').toString(),
 monthlyCost: (parsed['monthly'] ?? _opsCosts[index].monthlyCost).toString(),
 annualCost: (parsed['annual'] ?? _opsCosts[index].annualCost).toString(),
 notes: (parsed['notes'] ?? _opsCosts[index].notes).toString(),
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

 Future<void> _regenerateRecommendationRow(int index) async {
 if (index < 0 || index >= _recommendations.length) return;
 final key = 'rec_$index';
 if (_kazAiRegenerating[key] == true) return;
 setState(() => _kazAiRegenerating[key] = true);
 try {
 final projectData = ProjectDataHelper.getData(context);
 final ctx = ProjectDataHelper.buildProjectContextScan(projectData, sectionLabel: 'Recommendations');
 final openai = OpenAiServiceSecure();
 final result = await openai.generateCompletion(
 'Based on this project context, suggest a recommendation title, details, and status.\n\nContext:\n$ctx\n\nReturn ONLY a valid JSON object with keys: "title", "details", "status". Status must be Open, In Progress, or Complete.',
 maxTokens: 250, temperature: 0.6,
 );
 final start = result.indexOf('{');
 final end = result.lastIndexOf('}');
 if (start != -1 && end != -1) {
 final parsed = jsonDecode(result.substring(start, end + 1)) as Map<String, dynamic>;
 if (mounted) {
 setState(() {
 _recommendations[index] = _recommendations[index].copyWith(
 title: (parsed['title'] ?? '').toString(),
 details: (parsed['details'] ?? _recommendations[index].details).toString(),
 status: (parsed['status'] ?? _recommendations[index].status).toString(),
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
 final r = await LaunchPhaseService.loadCommerceViability(
 projectId: _projectId!);
 if (!mounted) return;
 setState(() {
 _warranties = r.warranties;
 _opsCosts = r.opsCosts;
 _financialMetrics = r.financialMetrics;
 _recommendations = r.recommendations;
 _decision = r.decision;
 _isLoading = false;
 _hasLoaded = true;
 });
 if (_warranties.isEmpty &&
 _opsCosts.isEmpty &&
 _financialMetrics.isEmpty &&
 _recommendations.isEmpty) {
 await _autoPopulateFromPriorPhases();
 }
 if (_warranties.isEmpty &&
 _opsCosts.isEmpty &&
 _financialMetrics.isEmpty &&
 _recommendations.isEmpty) {
 await _populateFromAi();
 }
 } catch (e) {
 debugPrint('Commerce load error: $e');
 if (mounted) setState(() => _isLoading = false);
 }
 _suspendSave = false;
 }

 Future<void> _persistData() async {
 if (_projectId == null) return;
 try {
 await LaunchPhaseService.saveCommerceViability(
 projectId: _projectId!,
 warranties: _warranties,
 opsCosts: _opsCosts,
 financialMetrics: _financialMetrics,
 recommendations: _recommendations,
 decision: _decision);
 } catch (e) {
 debugPrint('Commerce save error: $e');
 }
 }

 Future<void> _autoPopulateFromPriorPhases() async {
 if (_projectId == null) return;
 try {
 final cp = await LaunchPhaseAiSeed.loadCrossPhaseData(_projectId!);

 if (!mounted) return;

 final warrantyExisting = _warranties.map((w) => w.item).toSet();
 final newWarranties = <LaunchWarrantyItem>[];
 for (final c in cp.contracts) {
 if (c.contractName.isNotEmpty && !warrantyExisting.contains(c.contractName)) {
 newWarranties.add(LaunchWarrantyItem(
 item: c.contractName,
 vendor: c.vendor,
 warrantyType: 'Standard',
 status: 'Active',
 ));
 }
 }
 if (newWarranties.isNotEmpty) {
 setState(() => _warranties.addAll(newWarranties));
 }

 final opsCostExisting = _opsCosts.map((c) => c.category).toSet();
 final newOpsCosts = <LaunchOpsCostItem>[];
 for (final s in cp.staffing) {
 if (s.name.isNotEmpty && !opsCostExisting.contains(s.name)) {
 newOpsCosts.add(LaunchOpsCostItem(
 category: 'Staff: ${s.name}',
 notes: s.role,
 ));
 }
 }
 for (final br in cp.budgetRows) {
 final cat = br['category']?.toString() ?? '';
 if (cat.isNotEmpty && !opsCostExisting.contains(cat)) {
 final planned = br['plannedAmount']?.toString() ?? '';
 if (planned.isNotEmpty) {
 final numVal = double.tryParse(planned.replaceAll(RegExp(r'[^\d.]'), '')) ?? 0;
 newOpsCosts.add(LaunchOpsCostItem(
 category: cat,
 monthlyCost: planned,
 annualCost: (numVal * 12).toStringAsFixed(0),
 ));
 }
 }
 }
 if (newOpsCosts.isNotEmpty) {
 setState(() => _opsCosts.addAll(newOpsCosts));
 }

 final metricExisting = _financialMetrics.map((m) => m.label).toSet();
 final newMetrics = <LaunchFinancialMetric>[];

 if (cp.totalPlannedBudget > 0 && !metricExisting.contains('Total Planned Budget')) {
 newMetrics.add(LaunchFinancialMetric(
 label: 'Total Planned Budget',
 value: '\$${cp.totalPlannedBudget.toStringAsFixed(0)}',
 ));
 }
 if (cp.totalActualBudget > 0 && !metricExisting.contains('Total Actual Spend')) {
 newMetrics.add(LaunchFinancialMetric(
 label: 'Total Actual Spend',
 value: '\$${cp.totalActualBudget.toStringAsFixed(0)}',
 ));
 }
 if (cp.totalPlannedBudget > 0 && !metricExisting.contains('Budget Variance')) {
 final variance = cp.budgetVariance;
 newMetrics.add(LaunchFinancialMetric(
 label: 'Budget Variance',
 value: '\$${variance.toStringAsFixed(0)}',
 notes: variance >= 0 ? 'Under budget' : 'Over budget',
 ));
 }

 if (cp.totalContractValue > 0 && !metricExisting.contains('Total Contract Value')) {
 newMetrics.add(LaunchFinancialMetric(
 label: 'Total Contract Value',
 value: '\$${cp.totalContractValue.toStringAsFixed(0)}',
 ));
 }
 if (newMetrics.isNotEmpty) {
 setState(() => _financialMetrics.addAll(newMetrics));
 }

 final recExisting = _recommendations.map((r) => r.title).toSet();
 final newRecs = <LaunchFollowUpItem>[];
 for (final mp in cp.mitigationPlans) {
 final title = mp['title']?.toString() ?? mp['action']?.toString() ?? '';
 if (title.isNotEmpty && !recExisting.contains(title)) {
 newRecs.add(LaunchFollowUpItem(
 title: title,
 details: mp['description']?.toString() ?? mp['details']?.toString() ?? '',
 status: 'Open',
 ));
 }
 }
 if (newRecs.isNotEmpty) {
 setState(() => _recommendations.addAll(newRecs));
 }

 if (newWarranties.isNotEmpty || newOpsCosts.isNotEmpty || newMetrics.isNotEmpty || newRecs.isNotEmpty) {
 await _persistData();
 }
 } catch (e) {
 debugPrint('Commerce auto-populate error: $e');
 }
 }

 Future<void> _populateFromAi() async {
 if (_isGenerating) return;
 setState(() => _isGenerating = true);
 LaunchAiResult? result;
 try {
 result = await LaunchPhaseAiSeed.generateEntries(
 context: context,
 sectionLabel: 'Commerce Viability',
 sections: const {
 'financial_metrics':
 'ROI metrics with "label", "value", "notes"',
 'warranties':
 'Warranty items with "item", "vendor", "warranty_type", "start_date", "expiry_date", "status"',
 'ops_costs':
 'Post-launch operational costs with "category", "monthly_cost", "annual_cost", "notes"',
 'recommendations': 'Recommendations with "title", "details", "status"',
 },
 itemsPerSection: 3,
 );
 } catch (e) {
 debugPrint('Commerce AI error: $e');
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

 final hasData = _warranties.isNotEmpty ||
 _opsCosts.isNotEmpty ||
 _financialMetrics.isNotEmpty ||
 _recommendations.isNotEmpty;
 if (hasData) {
 setState(() => _isGenerating = false);
 return;
 }
 setState(() {
 _financialMetrics = (generated['financial_metrics'] ?? [])
 .map((m) => LaunchFinancialMetric(
 label: _s(m['title']), value: _s(m['details'])))
 .where((i) => i.label.isNotEmpty)
 .toList();
 _warranties = (generated['warranties'] ?? [])
 .map((m) => LaunchWarrantyItem(
 item: _s(m['title']),
 vendor: _s(m['details']),
 status: _ns(m['status'], 'Active')))
 .where((i) => i.item.isNotEmpty)
 .toList();
 _opsCosts = (generated['ops_costs'] ?? [])
 .map((m) => LaunchOpsCostItem(
 category: _s(m['title']), monthlyCost: _s(m['details'])))
 .where((i) => i.category.isNotEmpty)
 .toList();
 _recommendations = (generated['recommendations'] ?? [])
 .map((m) => LaunchFollowUpItem(
 title: _s(m['title']),
 details: _s(m['details']),
 status: _ns(m['status'], 'Open')))
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
 final filename = 'commerce_viability_${projectName.replaceAll(' ', '_')}_$stamp.pdf';

 final doc = pw.Document();

 doc.addPage(
 pw.MultiPage(
 pageFormat: PdfPageFormat.a4,
 margin: const pw.EdgeInsets.all(32),
 build: (_) => [
 pw.Text('Warranties & Operations Support', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
 pw.SizedBox(height: 4),
 pw.Text('$projectName — Generated ${now.toLocal().toIso8601String()}', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
 pw.SizedBox(height: 16),

 // Financial Metrics
 _pdfSectionTitle('Financial Metrics'),
 pw.SizedBox(height: 6),
 if (_financialMetrics.isEmpty)
 _pdfCell('No financial metrics recorded.')
 else
 pw.Table.fromTextArray(
 headers: ['Metric', 'Value', 'Notes'],
 data: _financialMetrics.map((m) => [m.label, m.value, m.notes]).toList(),
 headerStyle: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
 cellStyle: const pw.TextStyle(fontSize: 9),
 headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
 cellPadding: const pw.EdgeInsets.all(6),
 ),
 pw.SizedBox(height: 14),

 // Warranties
 _pdfSectionTitle('Warranty Tracker'),
 pw.SizedBox(height: 6),
 if (_warranties.isEmpty)
 _pdfCell('No warranties recorded.')
 else
 pw.Table.fromTextArray(
 headers: ['Item', 'Vendor', 'Type', 'Status'],
 data: _warranties.map((w) => [w.item, w.vendor, w.warrantyType, w.status]).toList(),
 headerStyle: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
 cellStyle: const pw.TextStyle(fontSize: 9),
 headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
 cellPadding: const pw.EdgeInsets.all(6),
 ),
 pw.SizedBox(height: 14),

 // Ops Costs
 _pdfSectionTitle('Operations Cost Projection'),
 pw.SizedBox(height: 6),
 if (_opsCosts.isEmpty)
 _pdfCell('No ops costs recorded.')
 else
 pw.Table.fromTextArray(
 headers: ['Category', 'Monthly', 'Annual', 'Notes'],
 data: _opsCosts.map((c) => [c.category, c.monthlyCost, c.annualCost, c.notes]).toList(),
 headerStyle: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
 cellStyle: const pw.TextStyle(fontSize: 9),
 headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
 cellPadding: const pw.EdgeInsets.all(6),
 ),
 pw.SizedBox(height: 14),

 // Recommendations
 _pdfSectionTitle('Recommendations'),
 pw.SizedBox(height: 6),
 if (_recommendations.isEmpty)
 _pdfCell('No recommendations recorded.')
 else
 pw.Table.fromTextArray(
 headers: ['Recommendation', 'Details', 'Status'],
 data: _recommendations.map((r) => [r.title, r.details, r.status]).toList(),
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

 pw.Widget _pdfHeaderCell(String text) {
 return pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(text, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)));
 }

 pw.Widget _pdfCell(String text) {
 return pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(text, style: const pw.TextStyle(fontSize: 9)));
 }

 String _s(dynamic v) => (v ?? '').toString().trim();
 String _ns(dynamic v, String fb) => _s(v).isEmpty ? fb : _s(v);
  // Launch Insights: KPIs + completion donut (auto-derived from project data)
  Widget _buildLaunchInsights() {
    final projectData = ProjectDataHelper.getData(context);
    final totalProviders =
            projectData.vendors.length + projectData.contractors.length;
        final completionPct =
            totalProviders == 0 ? 0.0 : (projectData.vendors.length / totalProviders).clamp(0.0, 1.0);
    return LaunchInsightsHeader(
      sectionTitle: 'Hypercare & Warranty Status',
      sectionSubtitle: 'Warranty coverage, hypercare tickets, and SLA performance',
      sectionIcon: Icons.support_agent_outlined,
      sectionColor: const Color(0xFFD97706),
      completionPercent: completionPct,
      completionLabel: 'COVERED',
      completionCaption:
          '${(completionPct * 100).round()}% complete - auto-derived from project data',
      kpiTiles: [
        LaunchKpiTile(
              label: 'Vendors',
              value: '${projectData.vendors.length}',
              icon: Icons.inventory_2_outlined,
              color: const Color(0xFF2563EB),
              delta: 'under warranty',
            ),
            LaunchKpiTile(
              label: 'Contractors',
              value: '${projectData.contractors.length}',
              icon: Icons.construction_outlined,
              color: const Color(0xFFF59E0B),
              delta: 'warranty providers',
            ),
            LaunchKpiTile(
              label: 'Allowances',
              value: '${projectData.frontEndPlanning.allowanceItems.length}',
              icon: Icons.savings_outlined,
              color: const Color(0xFF7C3AED),
              delta: 'contingency tracked',
            ),
            LaunchKpiTile(
              label: 'Open Risks',
              value: '${projectData.frontEndPlanning.riskRegisterItems.where((r) => r.status.toLowerCase() != 'closed').length}',
              icon: Icons.warning_amber_outlined,
              color: const Color(0xFFEF4444),
              delta: 'live during hypercare',
            ),
      ],
    );
  }


}
