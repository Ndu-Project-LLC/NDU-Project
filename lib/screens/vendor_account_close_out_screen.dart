import 'package:ndu_project/widgets/launch_notes_section.dart';
import 'package:ndu_project/widgets/launch_notes_section.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import 'package:ndu_project/models/launch_phase_models.dart';
import 'package:ndu_project/screens/contract_close_out_screen.dart';
import 'package:ndu_project/screens/summarize_account_risks_screen.dart';
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

class VendorAccountCloseOutScreen extends StatefulWidget {
 const VendorAccountCloseOutScreen({super.key});

 static void open(BuildContext context) {
 Navigator.of(context).push(
 MaterialPageRoute(builder: (_) => const VendorAccountCloseOutScreen()),
 );
 }

 @override
 State<VendorAccountCloseOutScreen> createState() =>
 _VendorAccountCloseOutScreenState();
}

class _VendorAccountCloseOutScreenState extends State<VendorAccountCloseOutScreen> {
  final TextEditingController _notesController = TextEditingController();
 List<LaunchVendorItem> _vendors = [];
 List<LaunchAccessItem> _accessItems = [];
 List<LaunchFollowUpItem> _obligations = [];
 List<LaunchFollowUpItem> _closureChecklist = [];

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
 activeItemLabel: 'Vendor Account Close Out',
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
 title: 'Vendor Account Close Out',
showNavigationButtons: false,
 showActivityLogAction: false,
 onExportPdf: _exportPdf,
 showAiAssist: true,
 onAiAssist: _isGenerating ? null : _populateFromAi,
 ),
 const SizedBox(height: 12),
 _buildMetricsRow(),
 const SizedBox(height: 16),
            LaunchNotesSection(
              controller: _notesController,
              onChanged: (v) {},
            ),
            const SizedBox(height: 20),
 _buildVendorsPanel(),
 const SizedBox(height: 16),
 _buildAccessPanel(),
 const SizedBox(height: 16),
 _buildObligationsPanel(),
 const SizedBox(height: 16),
 _buildClosureChecklistPanel(),
 const SizedBox(height: 24),
 LaunchPhaseNavigation(
 backLabel: 'Back: Contract Close Out',
 nextLabel: 'Next: Project Summary',
 onBack: () => ContractCloseOutScreen.open(context),
 onNext: () => SummarizeAccountRisksScreen.open(context),
 ),
 const SizedBox(height: 48),
 ],
 ),
 ),
 );
 }



 Widget _buildMetricsRow() {
 final active = _vendors.where((v) => v.accountStatus == 'Active').length;
 final closed = _vendors.where((v) => v.accountStatus == 'Closed').length;
 final pendingAccess =
 _accessItems.where((a) => a.status != 'Revoked').length;
 final openObligations =
 _obligations.where((o) => o.status != 'Complete').length;

 return ExecutionMetricsGrid(
 metrics: [
 ExecutionMetricData(
 label: 'Vendors',
 value: '${_vendors.length}',
 icon: Icons.business_outlined,
 emphasisColor: const Color(0xFFD97706),
 helper: '$active active, $closed closed',
 ),
 ExecutionMetricData(
 label: 'Access Items',
 value: '$pendingAccess',
 icon: Icons.vpn_key_outlined,
 emphasisColor: pendingAccess > 0
 ? const Color(0xFFF59E0B)
 : const Color(0xFF10B981),
 helper: 'pending revocation',
 ),
 ExecutionMetricData(
 label: 'Open Obligations',
 value: '$openObligations',
 icon: Icons.pending_actions_outlined,
 emphasisColor: openObligations > 0
 ? const Color(0xFFEF4444)
 : const Color(0xFF10B981),
 ),
 ExecutionMetricData(
 label: 'Closure Tasks',
 value:
 '${_closureChecklist.where((c) => c.status == 'Complete').length} / ${_closureChecklist.length}',
 icon: Icons.checklist_outlined,
 emphasisColor: const Color(0xFF8B5CF6),
 ),
 ],
 );
 }

 Widget _buildVendorsPanel() {
 return LaunchDataTable(
 title: 'Vendor Close-Out Table',
 subtitle: 'Track each vendor\'s account status and outstanding items.',
 columns: const [LaunchColumn(label: 'Vendor', flexible: true, fieldType: LaunchFieldType.text, hint: 'Vendor'), LaunchColumn(label: 'Contract Ref', width: 120, fieldType: LaunchFieldType.text, hint: 'Ref'), LaunchColumn(label: 'Status', width: 120, fieldType: LaunchFieldType.dropdown, dropdownItems: ['Active', 'Closing', 'Closed']), LaunchColumn(label: 'Outstanding', flexible: true, fieldType: LaunchFieldType.text, hint: 'Items'), LaunchColumn(label: 'Notes', flexible: true, fieldType: LaunchFieldType.text, hint: 'Notes')],
 rowCount: _vendors.length,
 onAddValues: (values) {
 setState(() {
 _vendors.add(LaunchVendorItem(
 vendorName: values['Vendor'] ?? '',
 contractRef: values['Contract Ref'] ?? '',
 accountStatus: values['Status'] ?? 'Active',
 outstandingItems: values['Outstanding'] ?? '',
 notes: values['Notes'] ?? '',
 ));
 });
 _save();
 },
 csvColumns: const [
 CsvColumnSpec(key: 'vendor', label: 'Vendor', sampleValue: 'Acme Corp'),
 CsvColumnSpec(key: 'contractRef', label: 'Contract Ref', sampleValue: 'CTR-001'),
 CsvColumnSpec(key: 'status', label: 'Status', sampleValue: 'Active', allowedValues: ['Active', 'Closing', 'Closed']),
 CsvColumnSpec(key: 'outstanding', label: 'Outstanding', sampleValue: 'Pending invoice'),
 CsvColumnSpec(key: 'notes', label: 'Notes', sampleValue: 'Final payment pending'),
 ],
 onCsvImport: (rows) async {
 for (final row in rows) {
 setState(() {
 _vendors.add(LaunchVendorItem(
 vendorName: row['vendor'] ?? '',
 contractRef: row['contractRef'] ?? '',
 accountStatus: row['status'] ?? 'Active',
 outstandingItems: row['outstanding'] ?? '',
 notes: row['notes'] ?? '',
 ));
 });
 }
 _save();
 },

 emptyMessage:
 'No vendors yet. Import vendors from execution or add manually.',
 cellBuilder: (context, i) {
 final v = _vendors[i];
 return LaunchDataRow(
 onEdit: () => _save(),
 onDelete: () async {
 final confirmed = await launchConfirmDelete(context,
 itemName: 'vendor ${v.vendorName}');
 if (!confirmed || !mounted) return;
 setState(() => _vendors.removeAt(i));
 _save();
 },
 onKazAi: () => _regenerateVendorRow(i),
 cells: [
 LaunchEditableCell(
 value: v.vendorName,
 hint: 'Vendor',
 bold: true,
 expand: true,
 onChanged: (s) {
 _vendors[i] = v.copyWith(vendorName: s);
 _save();
 },
 ),
 LaunchEditableCell(
 value: v.contractRef,
 hint: 'Ref',
 width: 120,
 onChanged: (s) {
 _vendors[i] = v.copyWith(contractRef: s);
 _save();
 },
 ),
 LaunchStatusDropdown(
 value: v.accountStatus,
 items: const ['Active', 'Closing', 'Closed'],
 width: 110,
 onChanged: (s) {
 if (s == null) return;
 _vendors[i] = v.copyWith(accountStatus: s);
 _save();
 setState(() {});
 },
 ),
 LaunchEditableCell(
 value: v.outstandingItems,
 hint: 'Items',
 width: 120,
 onChanged: (s) {
 _vendors[i] = v.copyWith(outstandingItems: s);
 _save();
 },
 ),
 LaunchEditableCell(
 value: v.notes,
 hint: 'Notes',
 expand: true,
 onChanged: (s) {
 _vendors[i] = v.copyWith(notes: s);
 _save();
 },
 ),
 ],
 );
 },
 );
 }

 Widget _buildAccessPanel() {
 return LaunchDataTable(
 title: 'Access Revocation',
 subtitle:
 'Track system/tool access that needs to be revoked for each vendor.',
 columns: const [LaunchColumn(label: 'System', flexible: true, fieldType: LaunchFieldType.text, hint: 'System'), LaunchColumn(label: 'Vendor', width: 130, fieldType: LaunchFieldType.text, hint: 'Vendor'), LaunchColumn(label: 'Access Level', width: 120, fieldType: LaunchFieldType.text, hint: 'Level'), LaunchColumn(label: 'Revoked Date', width: 130, fieldType: LaunchFieldType.date, hint: 'Date'), LaunchColumn(label: 'Status', width: 120, fieldType: LaunchFieldType.dropdown, dropdownItems: ['Pending', 'Revoked', 'Confirmed'])],
 rowCount: _accessItems.length,
 onAddValues: (values) {
 setState(() {
 _accessItems.add(LaunchAccessItem(
 system: values['System'] ?? '',
 vendor: values['Vendor'] ?? '',
 accessLevel: values['Access Level'] ?? '',
 revokedDate: values['Revoked Date'] ?? '',
 status: values['Status'] ?? 'Pending',
 ));
 });
 _save();
 },
 csvColumns: const [
 CsvColumnSpec(key: 'system', label: 'System', sampleValue: 'AWS Console'),
 CsvColumnSpec(key: 'vendor', label: 'Vendor', sampleValue: 'Acme Corp'),
 CsvColumnSpec(key: 'accessLevel', label: 'Access Level', sampleValue: 'Admin'),
 CsvColumnSpec(key: 'revokedDate', label: 'Revoked Date', sampleValue: '2025-01-20'),
 CsvColumnSpec(key: 'status', label: 'Status', sampleValue: 'Pending', allowedValues: ['Pending', 'Revoked', 'Confirmed']),
 ],
 onCsvImport: (rows) async {
 for (final row in rows) {
 setState(() {
 _accessItems.add(LaunchAccessItem(
 system: row['system'] ?? '',
 vendor: row['vendor'] ?? '',
 accessLevel: row['accessLevel'] ?? '',
 revokedDate: row['revokedDate'] ?? '',
 status: row['status'] ?? 'Pending',
 ));
 });
 }
 _save();
 },
 emptyMessage:
 'No access items. Track vendor access that needs revocation.',
 cellBuilder: (context, i) {
 final a = _accessItems[i];
 return LaunchDataRow(
 onEdit: () => _save(),
 onDelete: () async {
 final confirmed = await launchConfirmDelete(context,
 itemName: 'access item ${a.system}');
 if (!confirmed || !mounted) return;
 setState(() => _accessItems.removeAt(i));
 _save();
 },
 onKazAi: () => _regenerateAccessRow(i),
 cells: [
 LaunchEditableCell(
 value: a.system,
 hint: 'System',
 bold: true,
 expand: true,
 onChanged: (s) {
 _accessItems[i] = a.copyWith(system: s);
 _save();
 },
 ),
 LaunchEditableCell(
 value: a.vendor,
 hint: 'Vendor',
 expand: true,
 onChanged: (s) {
 _accessItems[i] = a.copyWith(vendor: s);
 _save();
 },
 ),
 LaunchEditableCell(
 value: a.accessLevel,
 hint: 'Level',
 width: 120,
 onChanged: (s) {
 _accessItems[i] = a.copyWith(accessLevel: s);
 _save();
 },
 ),
 LaunchDateCell(
 value: a.revokedDate,
 hint: 'Date',
 width: 120,
 onChanged: (s) {
 _accessItems[i] = a.copyWith(revokedDate: s);
 _save();
 },
 ),
 LaunchStatusDropdown(
 value: a.status,
 items: const ['Pending', 'Revoked', 'Confirmed'],
 width: 120,
 onChanged: (s) {
 if (s == null) return;
 _accessItems[i] = a.copyWith(status: s);
 _save();
 setState(() {});
 },
 ),
 ],
 );
 },
 );
 }

 Widget _buildObligationsPanel() {
 return LaunchDataTable(
 title: 'Outstanding Obligations',
 subtitle:
 'Pending payments, deliverables, SLAs, or warranties requiring resolution.',
 columns: const [LaunchColumn(label: 'Obligation', flexible: true, fieldType: LaunchFieldType.text, hint: 'Title'), LaunchColumn(label: 'Details', flexible: true, fieldType: LaunchFieldType.text, hint: 'Details'), LaunchColumn(label: 'Owner', width: 120, fieldType: LaunchFieldType.text, hint: 'Owner'), LaunchColumn(label: 'Status', width: 120, fieldType: LaunchFieldType.dropdown, dropdownItems: ['Open', 'In Progress', 'Complete'])],
 rowCount: _obligations.length,
 onAddValues: (values) {
 setState(() {
 _obligations.add(LaunchFollowUpItem(
 title: values['Obligation'] ?? '',
 details: values['Details'] ?? '',
 owner: values['Owner'] ?? '',
 status: values['Status'] ?? 'Open',
 ));
 });
 _save();
 },
 csvColumns: const [
 CsvColumnSpec(key: 'obligation', label: 'Obligation', sampleValue: 'Final payment'),
 CsvColumnSpec(key: 'details', label: 'Details', sampleValue: 'Outstanding invoice \$50K'),
 CsvColumnSpec(key: 'owner', label: 'Owner', sampleValue: 'Finance Lead'),
 CsvColumnSpec(key: 'status', label: 'Status', sampleValue: 'Open', allowedValues: ['Open', 'In Progress', 'Complete']),
 ],
 onCsvImport: (rows) async {
 for (final row in rows) {
 setState(() {
 _obligations.add(LaunchFollowUpItem(
 title: row['obligation'] ?? '',
 details: row['details'] ?? '',
 owner: row['owner'] ?? '',
 status: row['status'] ?? 'Open',
 ));
 });
 }
 _save();
 },
 emptyMessage: 'No obligations. Track pending vendor obligations.',
 cellBuilder: (context, i) {
 final o = _obligations[i];
 return LaunchDataRow(
 onEdit: () => _save(),
 onDelete: () async {
 final confirmed = await launchConfirmDelete(context,
 itemName: 'obligation ${o.title}');
 if (!confirmed || !mounted) return;
 setState(() => _obligations.removeAt(i));
 _save();
 },
 onKazAi: () => _regenerateObligationRow(i),
 cells: [
 LaunchEditableCell(
 value: o.title,
 hint: 'Title',
 bold: true,
 expand: true,
 onChanged: (s) {
 _obligations[i] = o.copyWith(title: s);
 _save();
 },
 ),
 LaunchEditableCell(
 value: o.details,
 hint: 'Details',
 expand: true,
 onChanged: (s) {
 _obligations[i] = o.copyWith(details: s);
 _save();
 },
 ),
 LaunchEditableCell(
 value: o.owner,
 hint: 'Owner',
 width: 120,
 onChanged: (s) {
 _obligations[i] = o.copyWith(owner: s);
 _save();
 },
 ),
 LaunchStatusDropdown(
 value: o.status,
 items: const ['Open', 'In Progress', 'Complete'],
 width: 120,
 onChanged: (s) {
 if (s == null) return;
 _obligations[i] = o.copyWith(status: s);
 _save();
 setState(() {});
 },
 ),
 ],
 );
 },
 );
 }

 Widget _buildClosureChecklistPanel() {
 return LaunchDataTable(
 title: 'Account Closure Checklist',
 subtitle:
 'Standardized steps to verify each vendor account is fully closed.',
 columns: const [LaunchColumn(label: 'Task', flexible: true, fieldType: LaunchFieldType.text, hint: 'Task'), LaunchColumn(label: 'Details', flexible: true, fieldType: LaunchFieldType.text, hint: 'Details'), LaunchColumn(label: 'Owner', width: 120, fieldType: LaunchFieldType.text, hint: 'Owner'), LaunchColumn(label: 'Status', width: 120, fieldType: LaunchFieldType.dropdown, dropdownItems: ['Pending', 'In Progress', 'Complete'])],
 rowCount: _closureChecklist.length,
 onAddValues: (values) {
 setState(() {
 _closureChecklist.add(LaunchFollowUpItem(
 title: values['Task'] ?? '',
 details: values['Details'] ?? '',
 owner: values['Owner'] ?? '',
 status: values['Status'] ?? 'Pending',
 ));
 });
 _save();
 },
 csvColumns: const [
 CsvColumnSpec(key: 'task', label: 'Task', sampleValue: 'Revoke all vendor access'),
 CsvColumnSpec(key: 'details', label: 'Details', sampleValue: 'Remove VPN, email, and system accounts'),
 CsvColumnSpec(key: 'owner', label: 'Owner', sampleValue: 'IT Lead'),
 CsvColumnSpec(key: 'status', label: 'Status', sampleValue: 'Pending', allowedValues: ['Pending', 'In Progress', 'Complete']),
 ],
 onCsvImport: (rows) async {
 for (final row in rows) {
 setState(() {
 _closureChecklist.add(LaunchFollowUpItem(
 title: row['task'] ?? '',
 details: row['details'] ?? '',
 owner: row['owner'] ?? '',
 status: row['status'] ?? 'Pending',
 ));
 });
 }
 _save();
 },
 emptyMessage: 'No checklist items. Add closure verification tasks.',
 cellBuilder: (context, i) {
 final c = _closureChecklist[i];
 return LaunchDataRow(
 onEdit: () => _save(),
 onDelete: () async {
 final confirmed = await launchConfirmDelete(context,
 itemName: 'checklist task ${c.title}');
 if (!confirmed || !mounted) return;
 setState(() => _closureChecklist.removeAt(i));
 _save();
 },
 onKazAi: () => _regenerateClosureChecklistRow(i),
 cells: [
 LaunchEditableCell(
 value: c.title,
 hint: 'Task',
 bold: true,
 expand: true,
 onChanged: (s) {
 _closureChecklist[i] = c.copyWith(title: s);
 _save();
 },
 ),
 LaunchEditableCell(
 value: c.details,
 hint: 'Details',
 expand: true,
 onChanged: (s) {
 _closureChecklist[i] = c.copyWith(details: s);
 _save();
 },
 ),
 LaunchEditableCell(
 value: c.owner,
 hint: 'Owner',
 width: 120,
 onChanged: (s) {
 _closureChecklist[i] = c.copyWith(owner: s);
 _save();
 },
 ),
 LaunchStatusDropdown(
 value: c.status,
 items: const ['Pending', 'In Progress', 'Complete'],
 width: 120,
 onChanged: (s) {
 if (s == null) return;
 _closureChecklist[i] = c.copyWith(status: s);
 _save();
 setState(() {});
 },
 ),
 ],
 );
 },
 );
 }

 Future<void> _importVendors() async {
 if (_projectId == null) return;
 final imported = await LaunchPhaseService.loadExecutionVendors(_projectId!);
 if (imported.isEmpty) {
 if (mounted) {
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(content: Text('No vendors found to import.')));
 }
 return;
 }
 setState(() {
 final existing = _vendors.map((v) => v.vendorName).toSet();
 for (final v in imported) {
 if (!existing.contains(v.vendorName)) _vendors.add(v);
 }
 });
 _save();
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
 final r = await LaunchPhaseService.loadVendorAccountCloseOut(
 projectId: _projectId!);
 if (!mounted) return;
 setState(() {
 _vendors = r.vendors;
 _accessItems = r.accessItems;
 _obligations = r.obligations;
 _closureChecklist = r.closureChecklist;
 _isLoading = false;
 _hasLoaded = true;
 });
 final allEmpty = _vendors.isEmpty &&
 _accessItems.isEmpty &&
 _obligations.isEmpty &&
 _closureChecklist.isEmpty;
 if (allEmpty) {
 await _autoPopulateFromPriorPhases();
 }

 final stillEmpty = _vendors.isEmpty &&
 _accessItems.isEmpty &&
 _obligations.isEmpty &&
 _closureChecklist.isEmpty;
 if (stillEmpty) await _populateFromAi();
 } catch (e) {
 debugPrint('Vendor close-out load error: $e');
 if (mounted) setState(() => _isLoading = false);
 }
 _suspendSave = false;
 }

 Future<void> _persistData() async {
 if (_projectId == null) return;
 try {
 await LaunchPhaseService.saveVendorAccountCloseOut(
 projectId: _projectId!,
 vendors: _vendors,
 accessItems: _accessItems,
 obligations: _obligations,
 closureChecklist: _closureChecklist);
 } catch (e) {
 debugPrint('Vendor close-out save error: $e');
 }
 }

 Future<void> _autoPopulateFromPriorPhases() async {
 if (_projectId == null) return;
 try {
 final cp = await LaunchPhaseAiSeed.loadCrossPhaseData(_projectId!);
 if (!mounted) return;

 // Pre-fill vendors from cross-phase data
 if (_vendors.isEmpty && cp.vendors.isNotEmpty) {
 final existing = _vendors.map((v) => v.vendorName).toSet();
 final newVendors = cp.vendors
 .where((v) => !existing.contains(v.vendorName))
 .toList();
 if (newVendors.isNotEmpty) {
 setState(() => _vendors.addAll(newVendors));
 }
 }

 // Pre-fill access items from vendor + contract data
 if (_accessItems.isEmpty) {
 final newAccess = <LaunchAccessItem>[];
 for (final v in cp.vendors.take(5)) {
 newAccess.add(LaunchAccessItem(
 system: 'Project Systems & Tools',
 vendor: v.vendorName,
 accessLevel: 'Standard',
 status: 'Pending',
 ));
 }
 for (final c in cp.contracts.take(3)) {
 if (c.vendor.isNotEmpty) {
 final alreadyAdded = newAccess.any((a) => a.vendor == c.vendor);
 if (!alreadyAdded) {
 newAccess.add(LaunchAccessItem(
 system: 'Contract Systems',
 vendor: c.vendor,
 accessLevel: 'Standard',
 status: 'Pending',
 ));
 }
 }
 }
 if (newAccess.isNotEmpty) {
 setState(() => _accessItems.addAll(newAccess));
 }
 }

 // Pre-fill obligations from open risk items
 if (_obligations.isEmpty && cp.openRiskItems.isNotEmpty) {
 final newObligations = cp.openRiskItems
 .map((r) => LaunchFollowUpItem(
 title: r['title']?.toString() ?? r['risk']?.toString() ?? '',
 details: r['description']?.toString() ?? r['details']?.toString() ?? '',
 owner: r['owner']?.toString() ?? '',
 status: r['status']?.toString() ?? 'Open',
 ))
 .where((o) => o.title.isNotEmpty)
 .toList();
 if (newObligations.isNotEmpty) {
 setState(() => _obligations.addAll(newObligations));
 }
 }

 final hasNewData = _vendors.isNotEmpty ||
 _accessItems.isNotEmpty ||
 _obligations.isNotEmpty;
 if (hasNewData) await _persistData();
 } catch (e) {
 debugPrint('Vendor close-out auto-populate error: $e');
 }
 }

 Future<void> _populateFromAi() async {
 if (_isGenerating) return;

 setState(() => _isGenerating = true);
 LaunchAiResult? result;
 try {
 result = await LaunchPhaseAiSeed.generateEntries(
 context: context,
 sectionLabel: 'Vendor Account Close Out',
 sections: const {
 'vendors':
 'Vendors with "vendor_name", "contract_ref", "outstanding_items", "status"',
 'access_items':
 'System access items with "system", "vendor", "access_level", "revoked_date", "status"',
 'obligations':
 'Outstanding obligations with "title", "details", "owner", "status"',
 'closure_checklist': 'Closure verification tasks with "title", "details", "status"',
 },
 itemsPerSection: 3,
 );
 } catch (e) {
 debugPrint('Vendor AI error: $e');
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

 final hasData = _vendors.isNotEmpty ||
 _accessItems.isNotEmpty ||
 _obligations.isNotEmpty ||
 _closureChecklist.isNotEmpty;
 if (hasData) {
 setState(() => _isGenerating = false);
 return;
 }
 setState(() {
 _vendors = (generated['vendors'] ?? [])
 .map((m) => LaunchVendorItem(
 vendorName: _s(m['title']),
 outstandingItems: _s(m['details']),
 accountStatus: _ns(m['status'], 'Active')))
 .where((i) => i.vendorName.isNotEmpty)
 .toList();
 _accessItems = (generated['access_items'] ?? [])
 .map((m) => LaunchAccessItem(
 system: _s(m['title']),
 vendor: _s(m['details']),
 status: _ns(m['status'], 'Pending')))
 .where((i) => i.system.isNotEmpty)
 .toList();
 _obligations = (generated['obligations'] ?? [])
 .map((m) => LaunchFollowUpItem(
 title: _s(m['title']),
 details: _s(m['details']),
 status: _ns(m['status'], 'Open')))
 .where((i) => i.title.isNotEmpty)
 .toList();
 _closureChecklist = (generated['closure_checklist'] ?? [])
 .map((m) => LaunchFollowUpItem(
 title: _s(m['title']),
 details: _s(m['details']),
 status: _ns(m['status'], 'Pending')))
 .where((i) => i.title.isNotEmpty)
 .toList();
 _isGenerating = false;
 });
 await _persistData();
 }

 // ── KAZ AI Row Regeneration ─────────────────────────────────────────────

 Future<void> _regenerateVendorRow(int index) async {
 if (index < 0 || index >= _vendors.length) return;
 final key = 'vendor_$index';
 if (_kazAiRegenerating[key] == true) return;
 setState(() => _kazAiRegenerating[key] = true);
 try {
 final projectData = ProjectDataHelper.getData(context);
 final ctx = ProjectDataHelper.buildProjectContextScan(projectData, sectionLabel: 'Vendor Account Close Out');
 final openai = OpenAiServiceSecure();
 final result = await openai.generateCompletion(
 'Based on this project context, suggest a vendor name, contract ref, outstanding items, and status for vendor close-out.\n\nContext:\n$ctx\n\nReturn ONLY a valid JSON object with keys: "vendor", "contract_ref", "outstanding", "status", "notes". Status must be Active, Closing, or Closed.',
 maxTokens: 250, temperature: 0.6,
 );
 final start = result.indexOf('{');
 final end = result.lastIndexOf('}');
 if (start != -1 && end != -1) {
 final parsed = jsonDecode(result.substring(start, end + 1)) as Map<String, dynamic>;
 if (mounted) {
 setState(() {
 _vendors[index] = _vendors[index].copyWith(
 vendorName: (parsed['vendor'] ?? '').toString(),
 contractRef: (parsed['contract_ref'] ?? _vendors[index].contractRef).toString(),
 outstandingItems: (parsed['outstanding'] ?? _vendors[index].outstandingItems).toString(),
 accountStatus: (parsed['status'] ?? _vendors[index].accountStatus).toString(),
 notes: (parsed['notes'] ?? _vendors[index].notes).toString(),
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

 Future<void> _regenerateAccessRow(int index) async {
 if (index < 0 || index >= _accessItems.length) return;
 final key = 'access_$index';
 if (_kazAiRegenerating[key] == true) return;
 setState(() => _kazAiRegenerating[key] = true);
 try {
 final projectData = ProjectDataHelper.getData(context);
 final ctx = ProjectDataHelper.buildProjectContextScan(projectData, sectionLabel: 'Access Revocation');
 final openai = OpenAiServiceSecure();
 final result = await openai.generateCompletion(
 'Based on this project context, suggest a system, vendor, and access level for access revocation tracking.\n\nContext:\n$ctx\n\nReturn ONLY a valid JSON object with keys: "system", "vendor", "access_level", "status". Status must be Pending, Revoked, or Confirmed.',
 maxTokens: 250, temperature: 0.6,
 );
 final start = result.indexOf('{');
 final end = result.lastIndexOf('}');
 if (start != -1 && end != -1) {
 final parsed = jsonDecode(result.substring(start, end + 1)) as Map<String, dynamic>;
 if (mounted) {
 setState(() {
 _accessItems[index] = _accessItems[index].copyWith(
 system: (parsed['system'] ?? '').toString(),
 vendor: (parsed['vendor'] ?? _accessItems[index].vendor).toString(),
 accessLevel: (parsed['access_level'] ?? _accessItems[index].accessLevel).toString(),
 status: (parsed['status'] ?? _accessItems[index].status).toString(),
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

 Future<void> _regenerateObligationRow(int index) async {
 if (index < 0 || index >= _obligations.length) return;
 final key = 'obligation_$index';
 if (_kazAiRegenerating[key] == true) return;
 setState(() => _kazAiRegenerating[key] = true);
 try {
 final projectData = ProjectDataHelper.getData(context);
 final ctx = ProjectDataHelper.buildProjectContextScan(projectData, sectionLabel: 'Outstanding Obligations');
 final openai = OpenAiServiceSecure();
 final result = await openai.generateCompletion(
 'Based on this project context, suggest an outstanding obligation title, details, and owner.\n\nContext:\n$ctx\n\nReturn ONLY a valid JSON object with keys: "title", "details", "owner", "status". Status must be Open, In Progress, or Complete.',
 maxTokens: 250, temperature: 0.6,
 );
 final start = result.indexOf('{');
 final end = result.lastIndexOf('}');
 if (start != -1 && end != -1) {
 final parsed = jsonDecode(result.substring(start, end + 1)) as Map<String, dynamic>;
 if (mounted) {
 setState(() {
 _obligations[index] = _obligations[index].copyWith(
 title: (parsed['title'] ?? '').toString(),
 details: (parsed['details'] ?? _obligations[index].details).toString(),
 owner: (parsed['owner'] ?? _obligations[index].owner).toString(),
 status: (parsed['status'] ?? _obligations[index].status).toString(),
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

 Future<void> _regenerateClosureChecklistRow(int index) async {
 if (index < 0 || index >= _closureChecklist.length) return;
 final key = 'closure_$index';
 if (_kazAiRegenerating[key] == true) return;
 setState(() => _kazAiRegenerating[key] = true);
 try {
 final projectData = ProjectDataHelper.getData(context);
 final ctx = ProjectDataHelper.buildProjectContextScan(projectData, sectionLabel: 'Account Closure Checklist');
 final openai = OpenAiServiceSecure();
 final result = await openai.generateCompletion(
 'Based on this project context, suggest a closure checklist task, details, and owner.\n\nContext:\n$ctx\n\nReturn ONLY a valid JSON object with keys: "task", "details", "owner", "status". Status must be Pending, In Progress, or Complete.',
 maxTokens: 250, temperature: 0.6,
 );
 final start = result.indexOf('{');
 final end = result.lastIndexOf('}');
 if (start != -1 && end != -1) {
 final parsed = jsonDecode(result.substring(start, end + 1)) as Map<String, dynamic>;
 if (mounted) {
 setState(() {
 _closureChecklist[index] = _closureChecklist[index].copyWith(
 title: (parsed['task'] ?? '').toString(),
 details: (parsed['details'] ?? _closureChecklist[index].details).toString(),
 owner: (parsed['owner'] ?? _closureChecklist[index].owner).toString(),
 status: (parsed['status'] ?? _closureChecklist[index].status).toString(),
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
 'vendor_account_close_out_${projectName.replaceAll(' ', '_')}_$stamp.pdf';

 final doc = pw.Document();

 doc.addPage(
 pw.MultiPage(
 pageFormat: PdfPageFormat.a4,
 margin: const pw.EdgeInsets.all(32),
 build: (_) => [
 pw.Text(
 'Vendor Account Close Out',
 style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
 ),
 pw.SizedBox(height: 4),
 pw.Text(
 '$projectName — Generated ${now.toLocal().toIso8601String()}',
 style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
 ),
 pw.SizedBox(height: 16),
 _pdfSectionTitle('Vendor Close-Out Table'),
 pw.SizedBox(height: 6),
 if (_vendors.isEmpty)
 pw.Text('No vendors.',
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
 'Vendor',
 'Contract Ref',
 'Status',
 'Outstanding',
 'Notes'
 ],
 data: _vendors
 .map((v) => [
 _pc(v.vendorName),
 _pc(v.contractRef),
 _pc(v.accountStatus),
 _pc(v.outstandingItems),
 _pc(v.notes),
 ])
 .toList(),
 ),
 pw.SizedBox(height: 20),
 _pdfSectionTitle('Access Revocation'),
 pw.SizedBox(height: 6),
 if (_accessItems.isEmpty)
 pw.Text('No access items.',
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
 'System',
 'Vendor',
 'Access Level',
 'Revoked Date',
 'Status'
 ],
 data: _accessItems
 .map((a) => [
 _pc(a.system),
 _pc(a.vendor),
 _pc(a.accessLevel),
 _pc(a.revokedDate),
 _pc(a.status),
 ])
 .toList(),
 ),
 pw.SizedBox(height: 20),
 _pdfSectionTitle('Outstanding Obligations'),
 pw.SizedBox(height: 6),
 if (_obligations.isEmpty)
 pw.Text('No obligations.',
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
 'Obligation',
 'Details',
 'Owner',
 'Status'
 ],
 data: _obligations
 .map((o) => [
 _pc(o.title),
 _pc(o.details),
 _pc(o.owner),
 _pc(o.status),
 ])
 .toList(),
 ),
 pw.SizedBox(height: 20),
 _pdfSectionTitle('Account Closure Checklist'),
 pw.SizedBox(height: 6),
 if (_closureChecklist.isEmpty)
 pw.Text('No checklist items.',
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
 headers: const ['Task', 'Details', 'Owner', 'Status'],
 data: _closureChecklist
 .map((c) => [
 _pc(c.title),
 _pc(c.details),
 _pc(c.owner),
 _pc(c.status),
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
}
