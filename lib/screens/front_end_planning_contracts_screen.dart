import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ndu_project/widgets/initiation_like_sidebar.dart';
import 'package:ndu_project/widgets/draggable_sidebar.dart';
import 'package:ndu_project/widgets/responsive.dart';
import 'package:ndu_project/widgets/kaz_ai_chat_bubble.dart';
import 'package:ndu_project/widgets/admin_edit_toggle.dart';
import 'package:ndu_project/services/firebase_auth_service.dart';
import 'package:ndu_project/screens/planning_procurement_screen.dart';
import 'package:ndu_project/providers/project_data_provider.dart';
import 'package:ndu_project/services/contract_service.dart';
import 'package:ndu_project/services/openai_service_secure.dart';
import 'package:ndu_project/utils/project_data_helper.dart';
import 'package:ndu_project/widgets/ai_suggesting_textfield.dart';
import 'package:ndu_project/widgets/front_end_planning_header.dart';

import 'package:ndu_project/widgets/voice_text_field.dart';
import 'package:ndu_project/utils/pdf_export_helper.dart';
const String _contractingCollection = 'contracting';
const String _contractPlanNoteKey = 'planning_contract_plan';
const String _contractPlanMarketKey = 'planning_contract_market';
const String _contractPlanCommercialKey = 'planning_contract_commercial';
const String _contractPlanScopeKey = 'planning_contract_scope';
const String _contractPlanApprovalsKey = 'planning_contract_approvals';
const String _contractPlanRisksKey = 'planning_contract_risks';
const String _contractPlanTimelineKey = 'planning_contract_timeline';
const String _contractsSeededKey = 'contracts_seeded_from_initiation';
const Color _kFabYellow = Color(0xFFFBBF24);
const Color _kFabOnYellow = Color(0xFF111827);

String _formatShortDate(DateTime? date) {
 if (date == null) return 'TBD';
 final String month = date.month.toString().padLeft(2, '0');
 final String day = date.day.toString().padLeft(2, '0');
 return '$month/$day/${date.year}';
}

String _formatMonthLabel(DateTime date) {
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
 'Dec',
 ];
 return months[date.month - 1];
}

String _formatCurrency(double value) {
 final rounded = value.round();
 final text = rounded.toString();
 final formatted =
 text.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (match) => ',');
 return '\$$formatted';
}

Color _statusColorFor(String status) {
 final normalized = status.toLowerCase();
 if (normalized.contains('award') ||
 normalized.contains('complete') ||
 normalized.contains('approved')) {
 return const Color(0xFF22C55E);
 }
 if (normalized.contains('behind') ||
 normalized.contains('risk') ||
 normalized.contains('blocked')) {
 return const Color(0xFFEF4444);
 }
 if (normalized.contains('review') ||
 normalized.contains('pending') ||
 normalized.contains('shortlist')) {
 return const Color(0xFFF59E0B);
 }
 if (normalized.contains('in progress') || normalized.contains('active')) {
 return const Color(0xFFFFC812);
 }
 return const Color(0xFF64748B);
}

/// Front End Planning – Contracts screen
/// Recreates the provided contract management mock with tabs, notes field,
/// contracting timeline, and a dashboard of completed contracts inside the shared workspace layout.
class FrontEndPlanningContractsScreen extends StatefulWidget {
 const FrontEndPlanningContractsScreen({super.key});

 static void open(BuildContext context) {
 Navigator.of(context).push(
 MaterialPageRoute(
 builder: (_) => const FrontEndPlanningContractsScreen()),
 );
 }

 @override
 State<FrontEndPlanningContractsScreen> createState() =>
 _FrontEndPlanningContractsScreenState();
}

class _FrontEndPlanningContractsScreenState
 extends State<FrontEndPlanningContractsScreen> {
 final TextEditingController _notesController = TextEditingController();
 int _selectedTabIndex = 0;
 bool _isSeedingContracts = false;

 void _openCreateContract() {
 Navigator.of(context).push(
 MaterialPageRoute(builder: (_) => const CreateContractScreen()),
 );
 }

 void _openEditContract(ContractModel contract) {
 Navigator.of(context).push(
 MaterialPageRoute(
 builder: (_) => CreateContractScreen(contract: contract)),
 );
 }

 @override
 void initState() {
 super.initState();
 WidgetsBinding.instance.addPostFrameCallback((_) {
 final saved =
 ProjectDataHelper.getData(context).frontEndPlanning.contracts;
 if (saved.trim().isNotEmpty) {
 _notesController.text = saved;
 }
 _seedContractsFromInitiationIfNeeded();
 });
 }

 
 Future<void> _exportPdf() async {
 final projectData = ProjectDataHelper.getData(context);
 final fep = projectData.frontEndPlanning;
 await PdfExportHelper.exportScreenPdf(
 context: context,
 screenTitle: 'Contracting',
 sections: [
 PdfSection.keyValue('Project Info', [
 {'Project Name': projectData.projectName ?? 'N/A'},
 ]),
 PdfSection.text('Notes', fep.requirementsNotes ?? 'No data recorded.'),
 ],
 );
 }
@override
 void dispose() {
 _notesController.dispose();
 super.dispose();
 }

 void _navigateToProcurement() {
 Navigator.push(
 context,
 MaterialPageRoute(builder: (_) => const PlanningProcurementScreen()),
 );
 }

 Future<void> _seedContractsFromInitiationIfNeeded() async {
 if (_isSeedingContracts) return;
 final data = ProjectDataHelper.getData(context);
 final projectId = data.projectId;
 if (projectId == null || projectId.isEmpty) return;

 final seededFlag =
 (data.planningNotes[_contractsSeededKey] ?? '').toString();
 if (seededFlag == 'true') return;

 final contractors = data.contractors
 .where((c) => c.name.trim().isNotEmpty || c.service.trim().isNotEmpty)
 .toList();
 if (contractors.isEmpty) return;

 final user = FirebaseAuth.instance.currentUser;
 if (user == null) return;

 _isSeedingContracts = true;
 try {
 final existing =
 await ContractService.streamContracts(projectId, limit: 1).first;
 if (existing.isNotEmpty) {
 _isSeedingContracts = false;
 return;
 }

 final now = DateTime.now();
 final defaultEnd = now.add(const Duration(days: 30));
 for (final contractor in contractors) {
 final name = contractor.name.trim().isNotEmpty
 ? contractor.name.trim()
 : 'Contract';
 final service = contractor.service.trim();
 final notesParts = <String>[];
 if (contractor.notes.trim().isNotEmpty) {
 notesParts.add(contractor.notes.trim());
 }
 notesParts.add('Imported from initiation contractor list.');
 await ContractService.createContract(
 projectId: projectId,
 name: name,
 description: service.isNotEmpty ? service : 'Imported scope',
 contractType: 'Not Sure',
 paymentType: 'TBD',
 status: contractor.status.trim().isNotEmpty
 ? contractor.status.trim()
 : 'Planned',
 estimatedValue: contractor.estimatedCost,
 startDate: now,
 endDate: defaultEnd,
 scope: service,
 discipline: service.isNotEmpty ? service : 'General',
 notes: notesParts.join(' '),
 createdById: user.uid,
 createdByEmail: user.email ?? '',
 createdByName: user.displayName ?? '',
 );
 }

 if (!mounted) return;
 await ProjectDataHelper.updateAndSave(
 context: context,
 checkpoint: 'contracts',
 dataUpdater: (data) => data.copyWith(
 planningNotes: {
 ...data.planningNotes,
 _contractsSeededKey: 'true',
 },
 ),
 showSnackbar: false,
 );
 } catch (e) {
 debugPrint('Failed to seed contracts from initiation: $e');
 } finally {
 _isSeedingContracts = false;
 }
 }

 @override
 Widget build(BuildContext context) {
 final projectData = ProjectDataHelper.getData(context);
 final isNarrow = MediaQuery.sizeOf(context).width < 1100;
 final hasDashboardPayload =
 (projectData.planningNotes['contract_dashboard_payload'] ?? '')
 .trim()
 .isNotEmpty;
 return Scaffold(
 backgroundColor: Colors.white,
 body: SafeArea(
 child: Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 DraggableSidebar(
 openWidth: AppBreakpoints.sidebarWidth(context),
 child: const InitiationLikeSidebar(activeItemLabel: 'Contract'),
 ),
 Expanded(
 child: Stack(
 children: [
 Column(
 children: [
 Expanded(
 child: SingleChildScrollView(
 padding: const EdgeInsets.only(
 left: 32, right: 32, top: 32, bottom: 32),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.stretch,
 children: [
 FrontEndPlanningHeader(title: 'Contracting', onExportPdf: _exportPdf),
 const SizedBox(height: 16),
 // Export PDF & AI Assist action buttons
 Wrap(
 spacing: 8,
 runSpacing: 6,
 alignment: WrapAlignment.end,
 children: [
 OutlinedButton.icon(
 onPressed: _exportPdf,
 style: OutlinedButton.styleFrom(
 backgroundColor: Colors.white,
 foregroundColor: Colors.black87,
 padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
 side: const BorderSide(color: Color(0xFFE5E7EB)),
 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
 ),
 icon: const Icon(Icons.picture_as_pdf_outlined, size: 16),
 label: const Text('Export PDF', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
 ),
 ElevatedButton.icon(
 onPressed: () {
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(
 content: Text('AI Assist will generate content for this section.'),
 duration: Duration(seconds: 2),
 ),
 );
 },
 style: ElevatedButton.styleFrom(
 backgroundColor: const Color(0xFF4154F1),
 foregroundColor: Colors.white,
 padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
 elevation: 0,
 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
 ),
 icon: const Icon(Icons.auto_awesome, size: 16),
 label: const Text('AI Assist', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
 ),
 ],
 ),
 const SizedBox(height: 16),
 _ContractTabs(
 selectedIndex: _selectedTabIndex,
 onTabSelected: (index) {
 setState(() => _selectedTabIndex = index);
 },
 ),
 const SizedBox(height: 20),
 _PlanningSummaryRow(
 projectId: projectData.projectId,
 approvalsText: projectData
 .planningNotes[_contractPlanApprovalsKey],
 timelineText: projectData
 .planningNotes[_contractPlanTimelineKey],
 ),
 const SizedBox(height: 20),
 _AdditionalNotesSection(
 controller: _notesController,
 onChanged: (value) async {
 await ProjectDataHelper.updateAndSave(
 context: context,
 checkpoint: 'contracts',
 dataUpdater: (data) => data.copyWith(
 frontEndPlanning:
 ProjectDataHelper.updateFEPField(
 current: data.frontEndPlanning,
 contracts: value.trim(),
 ),
 ),
 showSnackbar: false,
 );
 },
 ),
 const SizedBox(height: 20),
 _PlanningSectionCard(
 title: 'Contract Plan',
 subtitle:
 'AI drafts a contract plan using your prior planning context. Edit it to match your strategy, vendors, and approvals.',
 child: AiSuggestingTextField(
 fieldLabel: 'Contract Plan',
 hintText:
 'Outline scope, delivery model, commercial terms, milestones, vendor roles, and approval gates.',
 sectionLabel: 'Contract Plan',
 autoGenerate: true,
 autoGenerateSection: 'Contract Plan',
 initialText: projectData
 .planningNotes[_contractPlanNoteKey],
 onChanged: (value) async {
 final trimmed = value.trim();
 final provider =
 ProjectDataHelper.getProvider(context);
 provider.updateField(
 (data) => data.copyWith(
 planningNotes: {
 ...data.planningNotes,
 _contractPlanNoteKey: trimmed,
 },
 ),
 );
 await ProjectDataHelper.updateAndSave(
 context: context,
 checkpoint: 'contracts',
 dataUpdater: (data) => data.copyWith(
 planningNotes: {
 ...data.planningNotes,
 _contractPlanNoteKey: trimmed,
 },
 ),
 showSnackbar: false,
 );
 },
 onAutoGenerated: (value) async {
 final trimmed = value.trim();
 final provider =
 ProjectDataHelper.getProvider(context);
 provider.updateField(
 (data) => data.copyWith(
 planningNotes: {
 ...data.planningNotes,
 _contractPlanNoteKey: trimmed,
 },
 ),
 );
 await ProjectDataHelper.updateAndSave(
 context: context,
 checkpoint: 'contracts',
 dataUpdater: (data) => data.copyWith(
 planningNotes: {
 ...data.planningNotes,
 _contractPlanNoteKey: trimmed,
 },
 ),
 showSnackbar: false,
 );
 },
 ),
 ),
 const SizedBox(height: 24),
 if (isNarrow) ...[
 const _CollapsibleAiTextCard(
 title: 'Vendor & Market Strategy',
 subtitle:
 'Define sourcing approach, shortlist criteria, and negotiation posture.',
 noteKey: _contractPlanMarketKey,
 sectionLabel: 'Vendor & Market Strategy',
 hintText:
 'Example: RFP to 3 qualified vendors, weight on delivery record, target 10% cost leverage.',
 ),
 const SizedBox(height: 20),
 const _CollapsibleAiTextCard(
 title: 'Commercial Structure',
 subtitle:
 'Outline contract type, payment model, and incentives.',
 noteKey: _contractPlanCommercialKey,
 sectionLabel: 'Commercial Structure',
 hintText:
 'Example: Fixed-price with milestone payments, performance holdbacks, change order rules.',
 ),
 const SizedBox(height: 20),
 const _CollapsibleAiTextCard(
 title: 'Scope & Deliverables',
 subtitle:
 'Capture scope boundaries, assumptions, and exclusions.',
 noteKey: _contractPlanScopeKey,
 sectionLabel: 'Scope & Deliverables',
 hintText:
 'Example: Includes implementation and training; excludes ongoing support after 12 months.',
 ),
 const SizedBox(height: 20),
 const _CollapsibleAiTextCard(
 title: 'Approval Readiness',
 subtitle:
 'List required approvals, owners, and readiness gaps.',
 noteKey: _contractPlanApprovalsKey,
 sectionLabel: 'Approval Readiness',
 hintText:
 'Example: Legal review (owner: J. Smith), Finance sign-off, CIO approval by May 10.',
 ),
 const SizedBox(height: 20),
 const _CollapsibleAiTextCard(
 title: 'Early Risk Signals',
 subtitle:
 'Flag negotiation risks and mitigation actions.',
 noteKey: _contractPlanRisksKey,
 sectionLabel: 'Early Risk Signals',
 hintText:
 'Example: Single-source dependency; mitigate with alternative vendor option.',
 ),
 const SizedBox(height: 20),
 const _CollapsibleAiTextCard(
 title: 'Contract Timeline Plan',
 subtitle:
 'Define key dates from RFP to award and mobilization.',
 noteKey: _contractPlanTimelineKey,
 sectionLabel: 'Contract Timeline Plan',
 hintText:
 'Example: RFP release 4/15, evaluations 5/01-5/20, award 6/05, start 7/01.',
 ),
 const SizedBox(height: 20),
 _CollapsibleSectionCard(
 title: 'Contracts Preview',
 subtitle:
 'Pre-define contracts that will feed execution tracking.',
 child: _ContractsPreviewSection(
 projectId: projectData.projectId,
 onEdit: _openEditContract,
 ),
 ),
 const SizedBox(height: 20),
 const _CollapsibleSectionCard(
 title: 'Confirm Contracting Timeline',
 child: _TimelineSection(showHeader: false),
 ),
 const SizedBox(height: 20),
 ] else ...[
 Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Expanded(
 child: Column(
 children: const [
 _CollapsibleAiTextCard(
 title: 'Vendor & Market Strategy',
 subtitle:
 'Define sourcing approach, shortlist criteria, and negotiation posture.',
 noteKey: _contractPlanMarketKey,
 sectionLabel:
 'Vendor & Market Strategy',
 hintText:
 'Example: RFP to 3 qualified vendors, weight on delivery record, target 10% cost leverage.',
 ),
 SizedBox(height: 20),
 _CollapsibleAiTextCard(
 title: 'Commercial Structure',
 subtitle:
 'Outline contract type, payment model, and incentives.',
 noteKey: _contractPlanCommercialKey,
 sectionLabel:
 'Commercial Structure',
 hintText:
 'Example: Fixed-price with milestone payments, performance holdbacks, change order rules.',
 ),
 SizedBox(height: 20),
 _CollapsibleAiTextCard(
 title: 'Scope & Deliverables',
 subtitle:
 'Capture scope boundaries, assumptions, and exclusions.',
 noteKey: _contractPlanScopeKey,
 sectionLabel:
 'Scope & Deliverables',
 hintText:
 'Example: Includes implementation and training; excludes ongoing support after 12 months.',
 ),
 ],
 ),
 ),
 const SizedBox(width: 20),
 Expanded(
 child: Column(
 children: const [
 _CollapsibleAiTextCard(
 title: 'Approval Readiness',
 subtitle:
 'List required approvals, owners, and readiness gaps.',
 noteKey: _contractPlanApprovalsKey,
 sectionLabel: 'Approval Readiness',
 hintText:
 'Example: Legal review (owner: J. Smith), Finance sign-off, CIO approval by May 10.',
 ),
 SizedBox(height: 20),
 _CollapsibleAiTextCard(
 title: 'Early Risk Signals',
 subtitle:
 'Flag negotiation risks and mitigation actions.',
 noteKey: _contractPlanRisksKey,
 sectionLabel: 'Early Risk Signals',
 hintText:
 'Example: Single-source dependency; mitigate with alternative vendor option.',
 ),
 SizedBox(height: 20),
 _CollapsibleAiTextCard(
 title: 'Contract Timeline Plan',
 subtitle:
 'Define key dates from RFP to award and mobilization.',
 noteKey: _contractPlanTimelineKey,
 sectionLabel:
 'Contract Timeline Plan',
 hintText:
 'Example: RFP release 4/15, evaluations 5/01-5/20, award 6/05, start 7/01.',
 ),
 ],
 ),
 ),
 ],
 ),
 const SizedBox(height: 20),
 Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Expanded(
 child: _CollapsibleSectionCard(
 title: 'Contracts Preview',
 subtitle:
 'Pre-define contracts that will feed execution tracking.',
 child: _ContractsPreviewSection(
 projectId: projectData.projectId,
 onEdit: _openEditContract,
 ),
 ),
 ),
 const SizedBox(width: 20),
 const Expanded(
 child: _CollapsibleSectionCard(
 title: 'Confirm Contracting Timeline',
 child:
 _TimelineSection(showHeader: false),
 ),
 ),
 ],
 ),
 ],
 const SizedBox(height: 28),
 _ContractsDataSection(
 projectId: projectData.projectId,
 hasDashboardPayload: hasDashboardPayload,
 ),
 const SizedBox(height: 32),
 Align(
 alignment: Alignment.centerRight,
 child: ElevatedButton(
 onPressed: _navigateToProcurement,
 style: ElevatedButton.styleFrom(
 backgroundColor: _kFabYellow,
 foregroundColor: _kFabOnYellow,
 padding: const EdgeInsets.symmetric(
 horizontal: 32, vertical: 16),
 elevation: 0,
 shape: RoundedRectangleBorder(
 borderRadius: BorderRadius.circular(8)),
 ),
 child: const Text('Next',
 style: TextStyle(
 fontSize: 16,
 fontWeight: FontWeight.w600)),
 ),
 ),
 const SizedBox(height: 80),
 ],
 ),
 ),
 ),
 ],
 ),
 MobileSidebarHamburger(
 sidebar: const InitiationLikeSidebar(
 activeItemLabel: 'Contract',
 ),
 ),
 const KazAiChatBubble(),
 const AdminEditToggle(),
 ],
 ),
 ),
 ],
 ),
 ),
 );
 }
}

class CreateContractScreen extends StatefulWidget {
 const CreateContractScreen({super.key, this.contract});

 final ContractModel? contract;

 @override
 State<CreateContractScreen> createState() => _CreateContractScreenState();
}

class _CreateContractScreenState extends State<CreateContractScreen> {
 final _formKey = GlobalKey<FormState>();
 final TextEditingController _contractNameController = TextEditingController();
 final TextEditingController _descriptionController = TextEditingController();
 final TextEditingController _estimatedValueController =
 TextEditingController();
 final TextEditingController _scopeController = TextEditingController();
 final TextEditingController _disciplineController = TextEditingController();
 final TextEditingController _notesController = TextEditingController();

 String _contractType = 'Not Sure';
 String _paymentType = 'Not Sure';
 String _status = 'Not Started';
 String _contractStartPhase = 'Initiation';
 DateTime? _startDate;
 DateTime? _endDate;

 bool get _isEdit => widget.contract != null;

 @override
 void initState() {
 super.initState();
 final contract = widget.contract;
 if (contract == null) return;
 _contractNameController.text = contract.name;
 _descriptionController.text = contract.description;
 _estimatedValueController.text =
 contract.estimatedValue > 0 ? contract.estimatedValue.toStringAsFixed(0) : '';
 _scopeController.text = contract.scope;
 _disciplineController.text = contract.discipline;
 _notesController.text = contract.notes;
 _contractType = contract.contractType.isNotEmpty
 ? contract.contractType
 : _contractType;
 _paymentType =
 contract.paymentType.isNotEmpty ? contract.paymentType : _paymentType;
 _status = contract.status.isNotEmpty ? contract.status : _status;
 _startDate = contract.startDate;
 _endDate = contract.endDate;
 }

 @override
 void dispose() {
 _contractNameController.dispose();
 _descriptionController.dispose();
 _estimatedValueController.dispose();
 _scopeController.dispose();
 _disciplineController.dispose();
 _notesController.dispose();
 super.dispose();
 }

 Future<void> _pickDate({required bool isStart}) async {
 final DateTime now = DateTime.now();
 final DateTime initialDate =
 isStart ? (_startDate ?? now) : (_endDate ?? now);
 final DateTime firstDate = DateTime(now.year - 5);
 final DateTime lastDate = DateTime(now.year + 5);

 final DateTime? selected = await showDatePicker(
 context: context,
 initialDate: initialDate,
 firstDate: firstDate,
 lastDate: lastDate,
 );

 if (selected == null) {
 return;
 }

 setState(() {
 if (isStart) {
 _startDate = selected;
 } else {
 _endDate = selected;
 }
 });
 }

 Future<void> _handleSubmit() async {
 final messenger = ScaffoldMessenger.of(context);
 final projectProvider = ProjectDataInherited.maybeOf(context);
 final projectId =
 widget.contract?.projectId ?? projectProvider?.projectData.projectId;

 if (!(_formKey.currentState?.validate() ?? false)) {
 messenger.showSnackBar(const SnackBar(
 content: Text('Please complete all required fields.')));
 return;
 }
// Dates are optional in initiation phase - only validate if both are provided
 if (_startDate != null && _endDate != null && _endDate!.isBefore(_startDate!)) {
 messenger.showSnackBar(const SnackBar(
 content: Text('End Date cannot be before Start Date.')));
 return;
 }

 final user = FirebaseAuth.instance.currentUser;
 if (user == null) {
 messenger.showSnackBar(const SnackBar(
 content: Text('You must be signed in to save a contract.')));
 return;
 }
 if (projectId == null || projectId.isEmpty) {
 messenger.showSnackBar(const SnackBar(
 content: Text('Open or create a project before adding contracts.')));
 return;
 }

// Estimated value is optional in initiation phase - only validate if provided
final double? estValue = _estimatedValueController.text.trim().isEmpty
    ? null
    : double.tryParse(_estimatedValueController.text.trim());
if (_estimatedValueController.text.trim().isNotEmpty &&
    (estValue == null || estValue <= 0)) {
  messenger.showSnackBar(const SnackBar(
      content: Text('Estimated Value must be a positive number if provided.')));
  return;
}

 try {
 if (_isEdit) {
 await ContractService.updateContract(
 projectId: projectId,
 contractId: widget.contract!.id,
 name: _contractNameController.text.trim(),
 description: _descriptionController.text.trim(),
 contractType: _contractType,
 paymentType: _paymentType,
 status: _status,
 estimatedValue: estValue ?? 0,
 startDate: _startDate,
 endDate: _endDate,
 scope: _scopeController.text.trim(),
 discipline: _disciplineController.text.trim(),
 notes: _notesWithPhase(),
 );
 } else {
 await ContractService.createContract(
 projectId: projectId,
 name: _contractNameController.text.trim(),
 description: _descriptionController.text.trim(),
 contractType: _contractType,
 paymentType: _paymentType,
 status: _status,
 estimatedValue: estValue ?? 0,
 startDate: _startDate,
 endDate: _endDate,
 scope: _scopeController.text.trim(),
 discipline: _disciplineController.text.trim(),
 notes: _notesWithPhase(),
 createdById: user.uid,
 createdByEmail: user.email ?? '',
 createdByName: user.displayName ?? (user.email ?? 'User'),
 );
 }

 messenger.showSnackBar(SnackBar(
 content: Text(
 _isEdit ? 'Contract updated.' : 'Contract saved successfully.')));

 if (!mounted) return;
 Navigator.of(context).pop();
 } catch (e) {
 debugPrint('❌ Failed to save contract: $e');
 messenger.showSnackBar(const SnackBar(
 content: Text('Failed to save contract. Please try again.')));
 }
 }

 String _notesWithPhase() {
 final notes = _notesController.text.trim();
 final phaseLine = 'Contract start phase: $_contractStartPhase';
 if (notes.isEmpty) return phaseLine;
 if (notes.contains('Contract start phase:')) return notes;
 return '$notes\n$phaseLine';
 }

 String _formattedDate(DateTime? date) {
 if (date == null) {
 return 'Optional / TBD';
 }
 final String month = date.month.toString().padLeft(2, '0');
 final String day = date.day.toString().padLeft(2, '0');
 return '$month/$day/${date.year}';
 }

 @override
 Widget build(BuildContext context) {
 final double horizontalPadding = AppBreakpoints.isMobile(context) ? 20 : 48;

 return Scaffold(
 backgroundColor: Colors.white,
 body: SafeArea(
 child: Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 DraggableSidebar(
 openWidth: AppBreakpoints.sidebarWidth(context),
 child: const InitiationLikeSidebar(activeItemLabel: 'Contract'),
 ),
 Expanded(
 child: Stack(
 children: [
 SingleChildScrollView(
 padding: EdgeInsets.symmetric(
 horizontal: horizontalPadding,
 vertical: AppBreakpoints.isMobile(context) ? 28 : 48,
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Builder(builder: (context) {
 final provider =
 ProjectDataInherited.maybeOf(context);
 final projectId = provider?.projectData.projectId;

 if (projectId == null || projectId.isEmpty) {
 return Align(
 alignment: Alignment.center,
 child: Text(
 'Project',
 textAlign: TextAlign.center,
 style: TextStyle(
 fontSize: AppBreakpoints.isMobile(context)
 ? 24
 : 30,
 fontWeight: FontWeight.w700,
 color: const Color(0xFF111827),
 ),
 ),
 );
 }

 // StreamBuilder to listen to main project document for real-time updates
 return StreamBuilder<DocumentSnapshot>(
 stream: FirebaseFirestore.instance
 .collection('projects')
 .doc(projectId)
 .snapshots(),
 builder: (context, snapshot) {
 String title = 'Project';

 if (snapshot.hasData && snapshot.data!.exists) {
 final data = snapshot.data!.data()
 as Map<String, dynamic>?;
 if (data != null) {
 // Read from main project document
 final projectName = (data['projectName'] ??
 data['name'] ??
 '')
 .toString()
 .trim();
 final solutionTitle =
 (data['solutionTitle'] ?? '')
 .toString()
 .trim();

 if (projectName.isNotEmpty) {
 title = projectName;
 } else if (solutionTitle.isNotEmpty) {
 title = solutionTitle;
 }

 // Update provider if data changed
 if (provider != null) {
 final currentData = provider.projectData;
 final syncedProjectName =
 projectName.isNotEmpty
 ? projectName
 : currentData.projectName;
 final syncedSolutionTitle =
 solutionTitle.isNotEmpty
 ? solutionTitle
 : currentData.solutionTitle;

 if (currentData.projectName !=
 syncedProjectName ||
 currentData.solutionTitle !=
 syncedSolutionTitle) {
 WidgetsBinding.instance
 .addPostFrameCallback((_) {
 if (!mounted) return;
 final latestProvider =
 ProjectDataInherited.maybeOf(
 context);
 final latestData =
 latestProvider?.projectData;
 if (latestProvider == null ||
 latestData == null) {
 return;
 }
 if (latestData.projectName ==
 syncedProjectName &&
 latestData.solutionTitle ==
 syncedSolutionTitle) {
 return;
 }
 latestProvider.updateInitiationData(
 projectName: syncedProjectName,
 solutionTitle: syncedSolutionTitle,
 );
 });
 }
 }
 }
 } else {
 // Fallback to provider data
 final projectName =
 provider?.projectData.projectName.trim();
 if (projectName != null &&
 projectName.isNotEmpty) {
 title = projectName;
 }
 }

 return Align(
 alignment: Alignment.center,
 child: Text(
 title,
 textAlign: TextAlign.center,
 style: TextStyle(
 fontSize: AppBreakpoints.isMobile(context)
 ? 24
 : 30,
 fontWeight: FontWeight.w700,
 color: const Color(0xFF111827),
 ),
 ),
 );
 },
 );
 }),
 SizedBox(
 height: AppBreakpoints.isMobile(context) ? 18 : 24),
 // Wrap the entire form content in a Form so validators run
 Container(
 width: double.infinity,
 constraints: const BoxConstraints(maxWidth: 1160),
 padding: EdgeInsets.symmetric(
 horizontal:
 AppBreakpoints.isMobile(context) ? 20 : 36,
 vertical:
 AppBreakpoints.isMobile(context) ? 24 : 36,
 ),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(
 AppBreakpoints.isMobile(context) ? 20 : 30),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 boxShadow: const [
 BoxShadow(
 color: Color(0x0A0F172A),
 blurRadius: 26,
 offset: Offset(0, 14)),
 ],
 ),
 child: Form(
 key: _formKey,
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 _LabeledField(
 label: 'Contract Name*',
 child: _ContractTextField(
 controller: _contractNameController,
 hintText: 'e.g. Office Renovation',
 validator: (v) =>
 (v == null || v.trim().isEmpty)
 ? 'Required'
 : null,
 ),
 ),
 SizedBox(
 height: AppBreakpoints.isMobile(context)
 ? 18
 : 24),
 _LabeledField(
 label: 'Description*',
 child: _ContractTextField(
 controller: _descriptionController,
 hintText:
 'Brief description of the contract scope',
 maxLines: 4,
 validator: (v) =>
 (v == null || v.trim().isEmpty)
 ? 'Required'
 : null,
 ),
 ),
 SizedBox(
 height: AppBreakpoints.isMobile(context)
 ? 18
 : 24),
 _ResponsiveRow(
 spacing: AppBreakpoints.isMobile(context)
 ? 16
 : 24,
 children: [
 _LabeledField(
 label: 'Contract Type*',
 child: _ContractDropdownField(
 value: _contractType,
 items: const [
 'Not Sure',
 'Fixed Price',
 'Time and Materials',
 'Retainer'
 ],
 onChanged: (value) => setState(() =>
 _contractType =
 value ?? _contractType),
 validator: (v) =>
 (v == null || v.isEmpty)
 ? 'Required'
 : null,
 ),
 ),
 _LabeledField(
 label: 'Payment Type*',
 child: _ContractDropdownField(
 value: _paymentType,
 items: const [
 'Not Sure',
 'Milestone-based',
 'Monthly',
 'On Completion'
 ],
 onChanged: (value) => setState(() =>
 _paymentType =
 value ?? _paymentType),
 validator: (v) =>
 (v == null || v.isEmpty)
 ? 'Required'
 : null,
 ),
 ),
 ],
 ),
 SizedBox(
 height: AppBreakpoints.isMobile(context)
 ? 18
 : 24),
 _ResponsiveRow(
 spacing: AppBreakpoints.isMobile(context)
 ? 16
 : 24,
 children: [
 _LabeledField(
 label: 'Contract Start Phase*',
 child: _ContractDropdownField(
 value: _contractStartPhase,
 items: const [
 'Initiation',
 'Planning',
 'Execution',
 'Operations / Closeout'
 ],
 onChanged: (value) => setState(() =>
 _contractStartPhase = value ?? _contractStartPhase),
 validator: (v) =>
 (v == null || v.isEmpty)
 ? 'Required'
 : null,
 ),
 ),
 _LabeledField(
 label: 'Status*',
 child: _ContractDropdownField(
 value: _status,
 items: const [
 'Not Started',
 'In Progress',
 'Pending Review',
 'Completed'
 ],
 onChanged: (value) => setState(
 () => _status = value ?? _status),
 validator: (v) =>
 (v == null || v.isEmpty)
 ? 'Required'
 : null,
 ),
 ),
 _LabeledField(
 label: 'Cost / Total Value (optional in initiation)',
 child: _ContractTextField(
 controller: _estimatedValueController,
 hintText: 'Leave blank if not known yet',
 keyboardType: TextInputType.number,
 validator: (v) {
 final t = v?.trim() ?? '';
 if (t.isEmpty) return null;
 final d = double.tryParse(t);
 if (d == null || d <= 0) {
 return 'Enter a valid amount or leave blank';
 }
 return null;
 },
 ),
 ),
 ],
 ),
 SizedBox(
 height: AppBreakpoints.isMobile(context)
 ? 18
 : 24),
 _ResponsiveRow(
 spacing: AppBreakpoints.isMobile(context)
 ? 16
 : 24,
 children: [
 _LabeledField(
 label: 'Start Date',
 child: _ContractDateField(
 displayText: _formattedDate(_startDate),
 onTap: () => _pickDate(isStart: true),
 ),
 ),
 _LabeledField(
 label: 'End Date',
 child: _ContractDateField(
 displayText: _formattedDate(_endDate),
 onTap: () => _pickDate(isStart: false),
 ),
 ),
 ],
 ),
 SizedBox(
 height: AppBreakpoints.isMobile(context)
 ? 18
 : 24),
 _ResponsiveRow(
 spacing: AppBreakpoints.isMobile(context)
 ? 16
 : 24,
 children: [
 _LabeledField(
 label: 'Scope*',
 child: _ContractTextField(
 controller: _scopeController,
 hintText: 'e.g. Operations',
 validator: (v) =>
 (v == null || v.trim().isEmpty)
 ? 'Required'
 : null,
 ),
 ),
 _LabeledField(
 label: 'Discipline*',
 child: _ContractTextField(
 controller: _disciplineController,
 hintText: 'e.g. REQ-2023-001',
 validator: (v) =>
 (v == null || v.trim().isEmpty)
 ? 'Required'
 : null,
 ),
 ),
 ],
 ),
 SizedBox(
 height: AppBreakpoints.isMobile(context)
 ? 18
 : 24),
 _LabeledField(
 label: 'Additional Notes',
 child: _ContractTextField(
 controller: _notesController,
 hintText:
 'Any additional information about this contract',
 maxLines: 4,
 ),
 ),
 SizedBox(
 height: AppBreakpoints.isMobile(context)
 ? 24
 : 36),
 Row(
 mainAxisAlignment: MainAxisAlignment.end,
 children: [
 TextButton(
 onPressed: () =>
 Navigator.of(context).maybePop(),
 style: TextButton.styleFrom(
 padding: const EdgeInsets.symmetric(
 horizontal: 28, vertical: 16),
 backgroundColor:
 const Color(0xFFF3F4F6),
 foregroundColor:
 const Color(0xFF6B7280),
 shape: RoundedRectangleBorder(
 borderRadius:
 BorderRadius.circular(30),
 side: const BorderSide(
 color: Color(0xFFE5E7EB)),
 ),
 ),
 child: const Text('Cancel',
 style: TextStyle(
 fontSize: 14,
 fontWeight: FontWeight.w600)),
 ),
 const SizedBox(width: 16),
 ElevatedButton(
 onPressed: _handleSubmit,
 style: ElevatedButton.styleFrom(
 backgroundColor: _kFabYellow,
 foregroundColor: _kFabOnYellow,
 padding: const EdgeInsets.symmetric(
 horizontal: 34, vertical: 18),
 elevation: 0,
 shape: RoundedRectangleBorder(
 borderRadius:
 BorderRadius.circular(30)),
 ),
 child: Row(
 mainAxisSize: MainAxisSize.min,
 children: [
 Text(_isEdit ? 'Save' : 'Next',
 style: const TextStyle(
 fontSize: 15,
 fontWeight: FontWeight.w600)),
 if (!_isEdit) ...[
 const SizedBox(width: 12),
 const Icon(Icons.arrow_forward,
 size: 18),
 ],
 ],
 ),
 ),
 ],
 ),
 ],
 ),
 ),
 ),
 ],
 ),
 ),
 MobileSidebarHamburger(
 sidebar: const InitiationLikeSidebar(
 activeItemLabel: 'Contract',
 ),
 ),
 const KazAiChatBubble(),
 const AdminEditToggle(),
 ],
 ),
 ),
 ],
 ),
 ),
 );
 }
}

class ContractingStrategyScreen extends StatefulWidget {
 const ContractingStrategyScreen({super.key});

 @override
 State<ContractingStrategyScreen> createState() =>
 _ContractingStrategyScreenState();
}

class _ContractingStrategyScreenState extends State<ContractingStrategyScreen> {
 String _awardStrategy = 'Sole Source';
 String _contractType = 'Not Sure';
 final List<_QuoteRowData> _quotes = [];
 bool _loadedStrategy = false;
 bool _isGeneratingStrategy = false;
 bool _aiGeneratedStrategy = false;

 @override
 void initState() {
 super.initState();
 WidgetsBinding.instance.addPostFrameCallback((_) => _loadStrategyData());
 }

 void _openContractDetails() {
 Navigator.of(context).push(
 MaterialPageRoute(
 settings: const RouteSettings(name: 'ContractDetailsScreen'),
 builder: (_) => const ContractDetailsScreen(),
 ),
 );
 }

 void _openContractingStatus() {
 Navigator.of(context).push(
 MaterialPageRoute(
 settings: const RouteSettings(name: 'ContractingStatusScreen'),
 builder: (_) => const ContractingStatusScreen(),
 ),
 );
 }

 Future<void> _loadStrategyData() async {
 if (_loadedStrategy) return;
 final provider = ProjectDataHelper.getProvider(context);
 final projectId = provider.projectData.projectId;
 if (projectId == null || projectId.isEmpty) return;

 try {
 final doc = await FirebaseFirestore.instance
 .collection('projects')
 .doc(projectId)
 .collection(_contractingCollection)
 .doc('strategy')
 .get();
 if (doc.exists) {
 final data = doc.data() ?? {};
 final quotes = (data['quotes'] as List?)
 ?.whereType<Map>()
 .map((row) =>
 _QuoteRowData.fromJson(Map<String, dynamic>.from(row)))
 .toList() ??
 [];
 if (!mounted) return;
 setState(() {
 _awardStrategy = (data['awardStrategy'] ?? _awardStrategy).toString();
 _contractType = (data['contractType'] ?? _contractType).toString();
 _quotes
 ..clear()
 ..addAll(quotes);
 });
 }
 _loadedStrategy = true;
 } catch (error) {
 debugPrint('Failed to load contract strategy data: $error');
 }
 }

 // ignore: unused_element
 Future<void> _populateStrategyFromAi() async {
 if (_aiGeneratedStrategy || _isGeneratingStrategy) return;
 final projectData = ProjectDataHelper.getData(context);
 final contextText = ProjectDataHelper.buildFepContext(projectData,
 sectionLabel: 'Contracting Strategy');
 if (contextText.trim().isEmpty) return;

 setState(() => _isGeneratingStrategy = true);
 Map<String, List<Map<String, dynamic>>> generated = {};
 try {
 generated = await OpenAiServiceSecure().generateLaunchPhaseEntries(
 context: contextText,
 sections: const {
 'contract_quotes':
 'Existing contracting quotes (title=contractor, details=summary of scope, status=estimated value or status)',
 },
 itemsPerSection: 3,
 );
 } catch (error) {
 debugPrint('Strategy AI call failed: $error');
 }

 if (!mounted) return;
 if (_quotes.isNotEmpty) {
 setState(() => _isGeneratingStrategy = false);
 _aiGeneratedStrategy = true;
 return;
 }

 final mapped = _mapQuoteRows(generated['contract_quotes']);
 setState(() {
 _quotes
 ..clear()
 ..addAll(mapped);
 _isGeneratingStrategy = false;
 });
 _aiGeneratedStrategy = true;
 await _persistStrategy();
 }

 List<_QuoteRowData> _mapQuoteRows(List<Map<String, dynamic>>? raw) {
 if (raw == null) return [];
 return raw
 .map(_QuoteRowData.fromLaunchEntry)
 .where((row) => row.contractor.isNotEmpty)
 .toList();
 }

 Future<void> _persistStrategy() async {
 final provider = ProjectDataHelper.getProvider(context);
 final projectId = provider.projectData.projectId;
 if (projectId == null || projectId.isEmpty) return;

 final payload = {
 'awardStrategy': _awardStrategy,
 'contractType': _contractType,
 'quotes': _quotes.map((row) => row.toJson()).toList(),
 'updatedAt': FieldValue.serverTimestamp(),
 };

 try {
 await FirebaseFirestore.instance
 .collection('projects')
 .doc(projectId)
 .collection(_contractingCollection)
 .doc('strategy')
 .set(payload, SetOptions(merge: true));
 } catch (error) {
 debugPrint('Failed to save contract strategy: $error');
 }
 }

 @override
 Widget build(BuildContext context) {
 final bool isMobile = AppBreakpoints.isMobile(context);
 final double horizontalPadding = isMobile ? 24 : 48;

 return Scaffold(
 backgroundColor: Colors.white,
 body: SafeArea(
 child: Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 DraggableSidebar(
 openWidth: AppBreakpoints.sidebarWidth(context),
 child: const InitiationLikeSidebar(activeItemLabel: 'Contract'),
 ),
 Expanded(
 child: Stack(
 children: [
 SingleChildScrollView(
 padding: EdgeInsets.symmetric(
 horizontal: horizontalPadding,
 vertical: isMobile ? 28 : 48,
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 _StrategyHeader(
 onBack: () => Navigator.of(context).maybePop()),
 SizedBox(height: isMobile ? 24 : 36),
 _StrategyStepPills(
 selectedIndex: 0,
 onStepTap: (index) {
 if (index == 1) {
 _openContractDetails();
 } else if (index == 2) {
 _openContractingStatus();
 } else if (index == 3) {
 ContractingSummaryScreen.open(context);
 }
 },
 ),
 SizedBox(height: isMobile ? 24 : 36),
 _ContractingStrategyCard(
 selectedAwardStrategy: _awardStrategy,
 onAwardStrategyChanged: (value) {
 setState(() => _awardStrategy = value);
 _persistStrategy();
 },
 selectedContractType: _contractType,
 onContractTypeChanged: (value) {
 setState(() => _contractType = value);
 _persistStrategy();
 },
 ),
 SizedBox(height: isMobile ? 28 : 40),
 _ExistingQuotesSection(
 quotes: _quotes,
 onViewDetails: _openContractDetails,
 ),
 SizedBox(height: isMobile ? 24 : 32),
 Align(
 alignment: Alignment.centerRight,
 child: ElevatedButton.icon(
 onPressed: _openContractDetails,
 style: ElevatedButton.styleFrom(
 backgroundColor: const Color(0xFFFFC812),
 foregroundColor: Colors.white,
 padding: const EdgeInsets.symmetric(
 horizontal: 28, vertical: 16),
 elevation: 0,
 shape: RoundedRectangleBorder(
 borderRadius: BorderRadius.circular(14)),
 ),
 icon: const Icon(Icons.description_outlined,
 size: 18),
 label: const Text('Contract Details',
 style: TextStyle(
 fontSize: 14, fontWeight: FontWeight.w600)),
 ),
 ),
 SizedBox(height: isMobile ? 80 : 120),
 ],
 ),
 ),
 MobileSidebarHamburger(
 sidebar: const InitiationLikeSidebar(
 activeItemLabel: 'Contract',
 ),
 ),
 const KazAiChatBubble(),
 const AdminEditToggle(),
 ],
 ),
 ),
 ],
 ),
 ),
 );
 }
}

class _StrategyHeader extends StatelessWidget {
 const _StrategyHeader({required this.onBack});

 final VoidCallback onBack;

 @override
 Widget build(BuildContext context) {
 return Row(
 crossAxisAlignment: CrossAxisAlignment.center,
 children: [
 _CircleIconButton(
 icon: Icons.arrow_back_ios_new_rounded, onTap: onBack),
 const SizedBox(width: 12),
 const _CircleIconButton(icon: Icons.arrow_forward_ios_rounded),
 const SizedBox(width: 24),
 const Text(
 'Contract',
 style: TextStyle(
 fontSize: 28,
 fontWeight: FontWeight.w600,
 color: Color(0xFF111827)),
 ),
 const Spacer(),
 const _UserBadge(),
 ],
 );
 }
}

class _StrategyStepPills extends StatelessWidget {
 const _StrategyStepPills({required this.selectedIndex, this.onStepTap});

 final int selectedIndex;
 final ValueChanged<int>? onStepTap;

 @override
 Widget build(BuildContext context) {
 final bool isNarrow = MediaQuery.of(context).size.width < 720;

 Widget buildPill(String label, int index) {
 final bool isSelected = index == selectedIndex;
 final Color backgroundColor =
 isSelected ? const Color(0xFFFFC812) : const Color(0xFFFFC947);
 final Color textColor =
 isSelected ? Colors.white : const Color(0xFF1F2937);

 return _StepPill(
 label: label,
 backgroundColor: backgroundColor,
 textColor: textColor,
 onTap: onStepTap != null ? () => onStepTap!(index) : null,
 );
 }

 if (isNarrow) {
 return Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 buildPill('Contracting Strategy', 0),
 const SizedBox(height: 12),
 buildPill('Contract Details', 1),
 const SizedBox(height: 12),
 buildPill('Contracting Status', 2),
 const SizedBox(height: 12),
 buildPill('Contracting Summary', 3),
 ],
 );
 }

 return Row(
 children: [
 buildPill('Contracting Strategy', 0),
 const SizedBox(width: 18),
 buildPill('Contract Details', 1),
 const SizedBox(width: 18),
 buildPill('Contracting Status', 2),
 const SizedBox(width: 18),
 buildPill('Contracting Summary', 3),
 ],
 );
 }
}

class _StepPill extends StatelessWidget {
 const _StepPill(
 {required this.label,
 required this.backgroundColor,
 required this.textColor,
 this.onTap});

 final String label;
 final Color backgroundColor;
 final Color textColor;
 final VoidCallback? onTap;

 @override
 Widget build(BuildContext context) {
 final Widget pill = Container(
 padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 14),
 decoration: BoxDecoration(
 color: backgroundColor,
 borderRadius: BorderRadius.circular(999),
 boxShadow: const [
 BoxShadow(
 color: Color(0x13000000), blurRadius: 12, offset: Offset(0, 6)),
 ],
 ),
 child: Text(
 label,
 style: TextStyle(
 fontSize: 15, fontWeight: FontWeight.w600, color: textColor),
 ),
 );

 if (onTap == null) {
 return pill;
 }

 return InkWell(
 onTap: onTap,
 borderRadius: BorderRadius.circular(999),
 child: pill,
 );
 }
}

class _ContractingStrategyCard extends StatelessWidget {
 const _ContractingStrategyCard({
 required this.selectedAwardStrategy,
 required this.onAwardStrategyChanged,
 required this.selectedContractType,
 required this.onContractTypeChanged,
 });

 final String selectedAwardStrategy;
 final ValueChanged<String> onAwardStrategyChanged;
 final String selectedContractType;
 final ValueChanged<String> onContractTypeChanged;

 static const Map<String, String> _awardDescriptions = {
 'Sole Source':
 'Contracting directly with a single vendor without a competitive process. Used when a specific vendor has unique qualifications, intellectual property, or prior experience crucial to the project.',
 'Competitive Bidding':
 'Invite multiple vendors to submit proposals so the project team can compare cost, quality, and delivery expectations before selecting a partner.',
 'Not Sure':
 'Review the project requirements with the procurement team to determine the best award strategy before moving forward.',
 };

 static const Map<String, String> _contractTypeDescriptions = {
 'Reimbursable (Time & Materials)':
 'Contractor bills for actual labor and material costs plus any agreed markups. Useful when scope is evolving or difficult to estimate.',
 'Lump Sum (Fixed Price)':
 'A fixed price for the entire scope of work. Provides budget certainty but requires detailed specifications and shifts risk of overruns to the contractor.',
 'Not Sure':
 'Explore the pros and cons of both pricing models with the project sponsor before finalizing the contract type.',
 };

 @override
 Widget build(BuildContext context) {
 final bool isTight = MediaQuery.of(context).size.width < 1160;

 return Container(
 padding: EdgeInsets.symmetric(
 horizontal: isTight ? 24 : 36,
 vertical: isTight ? 28 : 36,
 ),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(24),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 boxShadow: const [
 BoxShadow(
 color: Color(0x0D0F172A), blurRadius: 24, offset: Offset(0, 16)),
 ],
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 const Text(
 'Contracting Strategy',
 style: TextStyle(
 fontSize: 20,
 fontWeight: FontWeight.w600,
 color: Color(0xFF111827)),
 ),
 const SizedBox(height: 8),
 const Text(
 'Define the contracting approach',
 style: TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
 ),
 const SizedBox(height: 28),
 LayoutBuilder(
 builder: (context, constraints) {
 final bool stack = constraints.maxWidth < 840;
 final children = [
 Expanded(
 child: _StrategySelectionColumn(
 title: 'Award strategy',
 options: const [
 'Sole Source',
 'Competitive Bidding',
 'Not Sure'
 ],
 selected: selectedAwardStrategy,
 onChanged: onAwardStrategyChanged,
 infoTitle:
 'About ${selectedAwardStrategy == 'Sole Source' ? 'Sole Source' : selectedAwardStrategy}',
 infoDescription:
 _awardDescriptions[selectedAwardStrategy] ?? '',
 ),
 ),
 const SizedBox(width: 32),
 Expanded(
 child: _StrategySelectionColumn(
 title: 'Contract type',
 options: const [
 'Reimbursable (Time & Materials)',
 'Lump Sum (Fixed Price)',
 'Not Sure'
 ],
 selected: selectedContractType,
 onChanged: onContractTypeChanged,
 infoTitle: selectedContractType == 'Lump Sum (Fixed Price)'
 ? 'About Lump Sum (Fixed Price)'
 : 'About ${selectedContractType == 'Reimbursable (Time & Materials)' ? 'Reimbursable (Time & Materials)' : selectedContractType}',
 infoDescription:
 _contractTypeDescriptions[selectedContractType] ?? '',
 ),
 ),
 ];

 if (stack) {
 return Column(
 crossAxisAlignment: CrossAxisAlignment.stretch,
 children: [
 children[0],
 const SizedBox(height: 28),
 children[2],
 ],
 );
 }

 return Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: children,
 );
 },
 ),
 ],
 ),
 );
 }
}

class _StrategySelectionColumn extends StatelessWidget {
 const _StrategySelectionColumn({
 required this.title,
 required this.options,
 required this.selected,
 required this.onChanged,
 required this.infoTitle,
 required this.infoDescription,
 });

 final String title;
 final List<String> options;
 final String selected;
 final ValueChanged<String> onChanged;
 final String infoTitle;
 final String infoDescription;

 @override
 Widget build(BuildContext context) {
 return Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(title,
 style: const TextStyle(
 fontSize: 15,
 fontWeight: FontWeight.w600,
 color: Color(0xFF111827))),
 const SizedBox(height: 18),
 ...options.map(
 (option) => _RadioOptionRow(
 label: option,
 groupValue: selected,
 onChanged: onChanged,
 ),
 ),
 const SizedBox(height: 18),
 _StrategyInfoCard(title: infoTitle, description: infoDescription),
 ],
 );
 }
}

class _RadioOptionRow extends StatelessWidget {
 const _RadioOptionRow(
 {required this.label, required this.groupValue, required this.onChanged});

 final String label;
 final String groupValue;
 final ValueChanged<String> onChanged;

 @override
 Widget build(BuildContext context) {
 final bool isSelected = label == groupValue;

 return InkWell(
 onTap: () => onChanged(label),
 borderRadius: BorderRadius.circular(12),
 child: Padding(
 padding: const EdgeInsets.symmetric(vertical: 8),
 child: Row(
 children: [
 Radio<String>(
 value: label,
 // ignore: deprecated_member_use
 groupValue: groupValue,
 // ignore: deprecated_member_use
 onChanged: (_) => onChanged(label),
 activeColor: const Color(0xFFFFC812),
 materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
 ),
 const SizedBox(width: 4),
 Expanded(
 child: Text(
 label,
 style: TextStyle(
 fontSize: 14,
 color: isSelected
 ? const Color(0xFF111827)
 : const Color(0xFF4B5563),
 ),
 ),
 ),
 ],
 ),
 ),
 );
 }
}

class _StrategyInfoCard extends StatelessWidget {
 const _StrategyInfoCard({required this.title, required this.description});

 final String title;
 final String description;

 @override
 Widget build(BuildContext context) {
 return Container(
 width: double.infinity,
 padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
 decoration: BoxDecoration(
 color: const Color(0xFFF9FAFB),
 borderRadius: BorderRadius.circular(18),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 title,
 style: const TextStyle(
 fontSize: 13,
 fontWeight: FontWeight.w600,
 color: Color(0xFF111827)),
 ),
 const SizedBox(height: 8),
 Text(
 description,
 style: const TextStyle(
 fontSize: 13, height: 1.4, color: Color(0xFF4B5563)),
 ),
 ],
 ),
 );
 }
}

class _ExistingQuotesSection extends StatelessWidget {
 const _ExistingQuotesSection({required this.quotes, this.onViewDetails});

 final List<_QuoteRowData> quotes;
 final VoidCallback? onViewDetails;

 @override
 Widget build(BuildContext context) {
 if (quotes.isEmpty) {
 return Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: const [
 Text(
 'Existing Contracting quotes',
 style: TextStyle(
 fontSize: 18,
 fontWeight: FontWeight.w600,
 color: Color(0xFF111827)),
 ),
 SizedBox(height: 6),
 Text(
 'Review initial obtained quotes from earlier project phase and decide on how to proceed.',
 style: TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
 ),
 SizedBox(height: 18),
 _EmptyPanelMessage(
 'No quotes loaded yet. Add contracts to populate this section.'),
 ],
 );
 }

 return Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 const Text(
 'Existing Contracting quotes',
 style: TextStyle(
 fontSize: 18,
 fontWeight: FontWeight.w600,
 color: Color(0xFF111827)),
 ),
 const SizedBox(height: 6),
 const Text(
 'Review initial obtained quotes from earlier project phase and decide on how to proceed.',
 style: TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
 ),
 const SizedBox(height: 18),
 _ExistingQuotesTable(quotes: quotes, onViewDetails: onViewDetails),
 ],
 );
 }
}

class _ExistingQuotesTable extends StatelessWidget {
 const _ExistingQuotesTable({required this.quotes, this.onViewDetails});

 final List<_QuoteRowData> quotes;
 final VoidCallback? onViewDetails;

 @override
 Widget build(BuildContext context) {
 return Container(
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(22),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 boxShadow: const [
 BoxShadow(
 color: Color(0x0C0F172A), blurRadius: 18, offset: Offset(0, 12)),
 ],
 ),
 child: Column(
 children: [
 _ExistingQuotesHeader(),
 const Divider(height: 1, color: Color(0xFFE5E7EB)),
 for (int i = 0; i < quotes.length; i++) ...[
 _ExistingQuotesRow(data: quotes[i], onViewDetails: onViewDetails),
 if (i != quotes.length - 1)
 const Divider(height: 1, color: Color(0xFFE5E7EB)),
 ],
 ],
 ),
 );
 }
}

class _ExistingQuotesHeader extends StatelessWidget {
 @override
 Widget build(BuildContext context) {
 const style = TextStyle(
 fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF6B7280));

 return Padding(
 padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
 child: Row(
 children: const [
 Expanded(flex: 24, child: Text('Contractor', style: style)),
 Expanded(flex: 26, child: Text('Description', style: style)),
 Expanded(flex: 18, child: Text('Estimated Value', style: style)),
 Expanded(flex: 18, child: Text('Status', style: style)),
 Expanded(
 flex: 14,
 child: Align(
 alignment: Alignment.centerRight,
 child: Text('Actions', style: style))),
 ],
 ),
 );
 }
}

class _ExistingQuotesRow extends StatelessWidget {
 const _ExistingQuotesRow({required this.data, this.onViewDetails});

 final _QuoteRowData data;
 final VoidCallback? onViewDetails;

 @override
 Widget build(BuildContext context) {
 return Padding(
 padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
 child: Row(
 crossAxisAlignment: CrossAxisAlignment.center,
 children: [
 Expanded(
 flex: 24,
 child: Text(
 data.contractor,
 style: const TextStyle(
 fontSize: 14,
 fontWeight: FontWeight.w500,
 color: Color(0xFF111827)),
 ),
 ),
 Expanded(
 flex: 26,
 child: Text(
 data.description,
 style: const TextStyle(fontSize: 13, color: Color(0xFF4B5563)),
 ),
 ),
 Expanded(
 flex: 18,
 child: Text(
 data.estimatedValue,
 style: const TextStyle(fontSize: 13, color: Color(0xFF111827)),
 ),
 ),
 Expanded(
 flex: 18,
 child: Align(
 alignment: Alignment.centerLeft,
 child:
 _QuoteStatusChip(label: data.status, color: data.statusColor),
 ),
 ),
 Expanded(
 flex: 14,
 child: Align(
 alignment: Alignment.centerRight,
 child: data.showViewDetails
 ? TextButton(
 onPressed: onViewDetails,
 style: TextButton.styleFrom(
 foregroundColor: const Color(0xFFFFC812),
 padding: EdgeInsets.zero,
 minimumSize: const Size(0, 0),
 ),
 child: const Text(
 'View Details',
 style: TextStyle(
 fontSize: 13, fontWeight: FontWeight.w600),
 ),
 )
 : Container(
 width: 38,
 height: 38,
 decoration: BoxDecoration(
 color: const Color(0xFFF3F4F6),
 borderRadius: BorderRadius.circular(12),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 ),
 child: const Icon(Icons.more_vert,
 size: 18, color: Color(0xFF6B7280)),
 ),
 ),
 ),
 ],
 ),
 );
 }
}

class _QuoteStatusChip extends StatelessWidget {
 const _QuoteStatusChip({required this.label, required this.color});

 final String label;
 final Color color;

 @override
 Widget build(BuildContext context) {
 return Container(
 padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
 decoration: BoxDecoration(
 color: color.withOpacity(0.12),
 borderRadius: BorderRadius.circular(999),
 border: Border.all(color: color.withOpacity(0.26)),
 ),
 child: Text(
 label,
 style:
 TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color),
 ),
 );
 }
}

class _QuoteRowData {
 _QuoteRowData({
 required this.contractor,
 required this.description,
 required this.estimatedValue,
 required this.status,
 this.showViewDetails = false,
 });

 final String contractor;
 final String description;
 final String estimatedValue;
 final String status;
 final bool showViewDetails;

 Color get statusColor => _statusColorFor(status);

 factory _QuoteRowData.fromJson(Map<String, dynamic> json) {
 return _QuoteRowData(
 contractor: (json['contractor'] ?? '').toString(),
 description: (json['description'] ?? '').toString(),
 estimatedValue: (json['estimatedValue'] ?? '').toString(),
 status: (json['status'] ?? '').toString(),
 showViewDetails: json['showViewDetails'] == true,
 );
 }

 factory _QuoteRowData.fromLaunchEntry(Map<String, dynamic> json) {
 final title = (json['title'] ?? '').toString().trim();
 final details = (json['details'] ?? '').toString().trim();
 final status = (json['status'] ?? '').toString().trim();
 String value = 'TBD';
 if (status.startsWith(r'$')) {
 value = status;
 } else if (details.contains(r'$')) {
 final parts = details.split(RegExp(r'(?=\$)'));
 value = parts.isNotEmpty ? parts.last.trim() : 'TBD';
 }
 return _QuoteRowData(
 contractor: title,
 description: details.isEmpty ? 'Quote details pending.' : details,
 estimatedValue: value,
 status: status.isEmpty ? 'In review' : status,
 showViewDetails: status.toLowerCase().contains('contract') ||
 status.toLowerCase().contains('awarded'),
 );
 }

 Map<String, dynamic> toJson() => {
 'contractor': contractor,
 'description': description,
 'estimatedValue': estimatedValue,
 'status': status,
 'showViewDetails': showViewDetails,
 };
}

class _LabeledField extends StatelessWidget {
 const _LabeledField({
 required this.label,
 required this.child,
 });

 final String label;
 final Widget child;

 @override
 Widget build(BuildContext context) {
 return Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 label,
 style: const TextStyle(
 fontSize: 14,
 fontWeight: FontWeight.w600,
 color: Color(0xFF111827)),
 ),
 const SizedBox(height: 12),
 child,
 ],
 );
 }
}

class _ContractTextField extends StatelessWidget {
 const _ContractTextField({
 required this.controller,
 required this.hintText,
 this.maxLines,
 this.keyboardType,
 this.validator,
 });

 final TextEditingController controller;
 final String hintText;
 final int? maxLines;
 final TextInputType? keyboardType;
 final String? Function(String?)? validator;

 @override
 Widget build(BuildContext context) {
 final int minLines = maxLines != null && maxLines! > 1 ? maxLines! : 1;

 return VoiceTextFormField(
 controller: controller,
 minLines: minLines,
 maxLines: maxLines ?? 1,
 keyboardType: keyboardType,
 validator: validator,
 decoration: InputDecoration(
 hintText: hintText,
 hintStyle: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 14),
 filled: true,
 fillColor: const Color(0xFFF9FAFB),
 contentPadding:
 const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
 border: OutlineInputBorder(
 borderRadius: BorderRadius.circular(24),
 borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
 ),
 enabledBorder: OutlineInputBorder(
 borderRadius: BorderRadius.circular(24),
 borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
 ),
 focusedBorder: OutlineInputBorder(
 borderRadius: BorderRadius.circular(24),
 borderSide: const BorderSide(color: Color(0xFFFFD700), width: 1.2),
 ),
 ),
 style: const TextStyle(fontSize: 14, color: Color(0xFF1F2937)),
 );
 }
}

class _ContractDropdownField extends StatelessWidget {
 const _ContractDropdownField({
 required this.value,
 required this.items,
 required this.onChanged,
 this.validator,
 });

 final String value;
 final List<String> items;
 final ValueChanged<String?> onChanged;
 final String? Function(String?)? validator;

 @override
 Widget build(BuildContext context) {
 return DropdownButtonFormField<String>(
 value: value,
 onChanged: onChanged,
 validator: validator,
 items: items
 .map(
 (item) => DropdownMenuItem<String>(
 value: item,
 child: Text(item,
 style:
 const TextStyle(fontSize: 14, color: Color(0xFF1F2937))),
 ),
 )
 .toList(),
 icon: const Icon(Icons.keyboard_arrow_down_rounded,
 color: Color(0xFF6B7280)),
 decoration: InputDecoration(
 filled: true,
 fillColor: const Color(0xFFF9FAFB),
 contentPadding:
 const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
 border: OutlineInputBorder(
 borderRadius: BorderRadius.circular(24),
 borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
 ),
 enabledBorder: OutlineInputBorder(
 borderRadius: BorderRadius.circular(24),
 borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
 ),
 focusedBorder: OutlineInputBorder(
 borderRadius: BorderRadius.circular(24),
 borderSide: const BorderSide(color: Color(0xFFFFD700), width: 1.2),
 ),
 ),
 dropdownColor: Colors.white,
 );
 }
}

class _ResponsiveRow extends StatelessWidget {
 const _ResponsiveRow({required this.children, this.spacing = 24});

 final List<Widget> children;
 final double spacing;

 @override
 Widget build(BuildContext context) {
 return LayoutBuilder(
 builder: (context, constraints) {
 final bool useColumn = constraints.maxWidth < 720;
 if (useColumn) {
 return Column(
 crossAxisAlignment: CrossAxisAlignment.stretch,
 children: [
 for (int i = 0; i < children.length; i++) ...[
 if (i != 0) SizedBox(height: spacing),
 children[i],
 ],
 ],
 );
 }
 return Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 for (int i = 0; i < children.length; i++) ...[
 Expanded(child: children[i]),
 if (i != children.length - 1) SizedBox(width: spacing),
 ],
 ],
 );
 },
 );
 }
}

class _ContractDateField extends StatelessWidget {
 const _ContractDateField({required this.displayText, required this.onTap});

 final String displayText;
 final VoidCallback onTap;

 @override
 Widget build(BuildContext context) {
 final bool isPlaceholder = displayText == 'Pick a date';

 return InkWell(
 onTap: onTap,
 borderRadius: BorderRadius.circular(24),
 child: Container(
 padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
 decoration: BoxDecoration(
 color: const Color(0xFFF9FAFB),
 borderRadius: BorderRadius.circular(24),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 ),
 child: Row(
 children: [
 Expanded(
 child: Text(
 displayText,
 style: TextStyle(
 fontSize: 14,
 color: isPlaceholder
 ? const Color(0xFF9CA3AF)
 : const Color(0xFF1F2937),
 ),
 ),
 ),
 const Icon(Icons.calendar_today_outlined,
 color: Color(0xFF6B7280), size: 18),
 ],
 ),
 ),
 );
 }
}

class _ContractHeader extends StatelessWidget {
 const _ContractHeader({
 required this.title,
 this.onBack,
 this.onForward,
 this.onCreateContract,
 });

 final String title;
 final VoidCallback? onBack;
 final VoidCallback? onForward;
 final VoidCallback? onCreateContract;

 @override
 Widget build(BuildContext context) {
 return Row(
 crossAxisAlignment: CrossAxisAlignment.center,
 children: [
 _CircleIconButton(
 icon: Icons.arrow_back_ios_new_rounded,
 onTap: onBack ?? () => Navigator.maybePop(context),
 ),
 const SizedBox(width: 12),
 _CircleIconButton(
 icon: Icons.arrow_forward_ios_rounded,
 onTap: onForward,
 ),
 const SizedBox(width: 24),
 Expanded(
 child: Text(
 title,
 style: const TextStyle(
 fontSize: 28,
 fontWeight: FontWeight.w600,
 color: Color(0xFF111827)),
 ),
 ),
 const _UserBadge(),
 const SizedBox(width: 20),
 ElevatedButton(
 onPressed: onCreateContract,
 style: ElevatedButton.styleFrom(
 backgroundColor: _kFabYellow,
 foregroundColor: _kFabOnYellow,
 padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 16),
 elevation: 0,
 shape:
 RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
 ),
 child: const Text('Create Contract',
 style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
 ),
 ],
 );
 }
}

class _ContractTabs extends StatelessWidget {
 const _ContractTabs(
 {required this.selectedIndex, required this.onTabSelected});

 final int selectedIndex;
 final ValueChanged<int> onTabSelected;

 @override
 Widget build(BuildContext context) {
 return Container(
 decoration: BoxDecoration(
 color: const Color(0xFFF3F4F6),
 borderRadius: BorderRadius.circular(12),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 ),
 padding: const EdgeInsets.all(6),
 child: Row(
 children: [
 _TabButton(
 label: 'Contract Management',
 isSelected: selectedIndex == 0,
 onTap: () => onTabSelected(0),
 ),
 ],
 ),
 );
 }
}

class _PlanningSummaryRow extends StatelessWidget {
 const _PlanningSummaryRow({
 required this.projectId,
 required this.approvalsText,
 required this.timelineText,
 });

 final String? projectId;
 final String? approvalsText;
 final String? timelineText;

 @override
 Widget build(BuildContext context) {
 final approvalsDefined = (approvalsText ?? '').trim().isNotEmpty;
 final timelineDefined = (timelineText ?? '').trim().isNotEmpty;
 if (projectId == null || projectId!.isEmpty) {
 return _PlanningSummaryCards(
 stats: [
 _SummaryStatData('Planned Contracts', '—', 'No project selected',
 const Color(0xFFFFC812)),
 _SummaryStatData('Estimated Value', '—', 'Set in preview list',
 const Color(0xFF059669)),
 _SummaryStatData('Approval Readiness', '—', 'Define checkpoints',
 const Color(0xFFF59E0B)),
 _SummaryStatData('Target Award Window', '—', 'Set timeline targets',
 const Color(0xFF7C3AED)),
 ],
 );
 }

 return StreamBuilder<List<ContractModel>>(
 stream: ContractService.streamContracts(projectId!),
 builder: (context, snapshot) {
 final contracts = snapshot.data ?? const <ContractModel>[];
 final plannedCount = contracts.length;
 final totalValue =
 contracts.fold<double>(0.0, (total, c) => total + c.estimatedValue);
 final stats = [
 _SummaryStatData(
 'Planned Contracts',
 plannedCount.toString(),
 plannedCount == 0 ? 'Add contracts below' : 'Pre-award list',
 const Color(0xFFFFC812)),
 _SummaryStatData(
 'Estimated Value',
 plannedCount == 0 ? 'TBD' : _formatCurrency(totalValue),
 'Budget alignment',
 const Color(0xFF059669)),
 _SummaryStatData(
 'Approval Readiness',
 approvalsDefined ? 'Defined' : 'Not set',
 approvalsDefined ? 'Check owners & dates' : 'Add checkpoints',
 const Color(0xFFF59E0B)),
 _SummaryStatData(
 'Target Award Window',
 timelineDefined ? 'Defined' : 'Not set',
 timelineDefined ? 'Review milestones' : 'Add timeline targets',
 const Color(0xFF7C3AED)),
 ];
 return _PlanningSummaryCards(stats: stats);
 },
 );
 }
}

class _PlanningSummaryCards extends StatelessWidget {
 const _PlanningSummaryCards({required this.stats});

 final List<_SummaryStatData> stats;

 @override
 Widget build(BuildContext context) {
 return LayoutBuilder(builder: (context, constraints) {
 const gap = 12.0;
 var cardWidth = constraints.maxWidth;
 if (constraints.maxWidth >= 980) {
 cardWidth = (constraints.maxWidth - gap * 3) / 4;
 } else if (constraints.maxWidth >= 620) {
 cardWidth = (constraints.maxWidth - gap) / 2;
 }
 return Wrap(
 spacing: gap,
 runSpacing: gap,
 children: stats
 .map((stat) => SizedBox(
 width: cardWidth,
 child: _SummaryStatCard(stat: stat),
 ))
 .toList(),
 );
 });
 }
}

class _SummaryStatCard extends StatelessWidget {
 const _SummaryStatCard({required this.stat});

 final _SummaryStatData stat;

 @override
 Widget build(BuildContext context) {
 return Container(
 padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(16),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 boxShadow: const [
 BoxShadow(
 color: Color(0x08000000), blurRadius: 10, offset: Offset(0, 6)),
 ],
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(stat.value,
 style: TextStyle(
 fontSize: 20,
 fontWeight: FontWeight.w700,
 color: stat.color)),
 const SizedBox(height: 6),
 Text(stat.label,
 style: const TextStyle(
 fontSize: 12,
 fontWeight: FontWeight.w600,
 color: Color(0xFF6B7280))),
 const SizedBox(height: 6),
 Text(stat.supporting,
 style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
 ],
 ),
 );
 }
}

class _PlanningSectionCard extends StatelessWidget {
 const _PlanningSectionCard({
 required this.title,
 required this.child,
 this.subtitle,
 this.trailing,
 });

 final String title;
 final String? subtitle;
 final Widget child;
 final Widget? trailing;

 @override
 Widget build(BuildContext context) {
 return Container(
 padding: const EdgeInsets.all(20),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(18),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 boxShadow: const [
 BoxShadow(
 color: Color(0x0A000000), blurRadius: 12, offset: Offset(0, 6)),
 ],
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(title,
 style: const TextStyle(
 fontSize: 16,
 fontWeight: FontWeight.w700,
 color: Color(0xFF111827))),
 if ((subtitle ?? '').trim().isNotEmpty) ...[
 const SizedBox(height: 6),
 Text(subtitle!,
 style: const TextStyle(
 fontSize: 12, color: Color(0xFF6B7280))),
 ],
 ],
 ),
 ),
 if (trailing != null) trailing!,
 ],
 ),
 const SizedBox(height: 16),
 child,
 ],
 ),
 );
 }
}

class _CollapsibleSectionCard extends StatefulWidget {
 const _CollapsibleSectionCard({
 required this.title,
 required this.child,
 this.subtitle,
 this.onAiRegenerate,
 this.isAiLoading = false,
 this.initiallyExpanded = false,
 });

 final String title;
 final String? subtitle;
 final Widget child;
 final VoidCallback? onAiRegenerate;
 final bool isAiLoading;
 final bool initiallyExpanded;

 @override
 State<_CollapsibleSectionCard> createState() =>
 _CollapsibleSectionCardState();
}

class _CollapsibleSectionCardState extends State<_CollapsibleSectionCard> {
 late bool _expanded;

 @override
 void initState() {
 super.initState();
 _expanded = widget.initiallyExpanded;
 }

 @override
 Widget build(BuildContext context) {
 return Container(
 padding: const EdgeInsets.all(20),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(18),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 boxShadow: const [
 BoxShadow(
 color: Color(0x0A000000), blurRadius: 12, offset: Offset(0, 6)),
 ],
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(widget.title,
 style: const TextStyle(
 fontSize: 16,
 fontWeight: FontWeight.w700,
 color: Color(0xFF111827))),
 if ((widget.subtitle ?? '').trim().isNotEmpty) ...[
 const SizedBox(height: 6),
 Text(widget.subtitle!,
 style: const TextStyle(
 fontSize: 12, color: Color(0xFF6B7280))),
 ],
 ],
 ),
 ),
 if (widget.onAiRegenerate != null)
 Padding(
 padding: const EdgeInsets.only(right: 6),
 child: TextButton.icon(
 onPressed:
 widget.isAiLoading ? null : widget.onAiRegenerate,
 icon: widget.isAiLoading
 ? const SizedBox(
 width: 14,
 height: 14,
 child: CircularProgressIndicator(strokeWidth: 2),
 )
 : const Icon(Icons.auto_awesome, size: 16),
 label: const Text('Regenerate',
 style: TextStyle(fontSize: 12)),
 style: TextButton.styleFrom(
 foregroundColor: const Color(0xFFFFC812),
 padding: const EdgeInsets.symmetric(
 horizontal: 10, vertical: 6),
 ),
 ),
 ),
 IconButton(
 onPressed: () => setState(() => _expanded = !_expanded),
 icon: Icon(
 _expanded ? Icons.expand_less : Icons.expand_more,
 color: const Color(0xFF6B7280),
 ),
 tooltip: _expanded ? 'Collapse' : 'Expand',
 ),
 ],
 ),
 if (_expanded) ...[
 const SizedBox(height: 16),
 widget.child,
 ],
 ],
 ),
 );
 }
}

class _CollapsibleAiTextCard extends StatefulWidget {
 const _CollapsibleAiTextCard({
 required this.title,
 required this.noteKey,
 required this.sectionLabel,
 required this.hintText,
 this.subtitle,
 this.minLines = 3,
 this.maxLines = 8,
 this.initiallyExpanded = false,
 });

 final String title;
 final String? subtitle;
 final String noteKey;
 final String sectionLabel;
 final String hintText;
 final int minLines;
 final int maxLines;
 final bool initiallyExpanded;

 @override
 State<_CollapsibleAiTextCard> createState() => _CollapsibleAiTextCardState();
}

class _CollapsibleAiTextCardState extends State<_CollapsibleAiTextCard> {
 final _saveDebounce = _Debouncer();
 late TextEditingController _controller;
 bool _didInit = false;
 bool _isRegenerating = false;

 @override
 void didChangeDependencies() {
 super.didChangeDependencies();
 if (_didInit) return;
 final data = ProjectDataHelper.getData(context);
 final saved = data.planningNotes[widget.noteKey] ?? '';
 _controller = TextEditingController(text: saved);
 _didInit = true;
 }

 @override
 void dispose() {
 _saveDebounce.dispose();
 _controller.dispose();
 super.dispose();
 }

 void _handleChanged(String value) {
 final trimmed = value.trim();
 final provider = ProjectDataHelper.getProvider(context);
 provider.updateField(
 (data) => data.copyWith(
 planningNotes: {
 ...data.planningNotes,
 widget.noteKey: trimmed,
 },
 ),
 );
 _saveDebounce.run(() async {
 await ProjectDataHelper.updateAndSave(
 context: context,
 checkpoint: 'contracts',
 dataUpdater: (data) => data.copyWith(
 planningNotes: {
 ...data.planningNotes,
 widget.noteKey: trimmed,
 },
 ),
 showSnackbar: false,
 );
 });
 }

 Future<void> _handleRegenerate() async {
 if (_isRegenerating) return;
 final data = ProjectDataHelper.getData(context);
 final contextText = ProjectDataHelper.buildFepContext(data,
 sectionLabel: widget.sectionLabel);
 if (contextText.trim().isEmpty) {
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(
 content: Text('Add project context to use AI regenerate.')),
 );
 return;
 }

 setState(() => _isRegenerating = true);
 try {
 final ai = OpenAiServiceSecure();
 final regenerated = await ai.generateFepSectionText(
 section: widget.sectionLabel,
 context: contextText,
 );
 if (!mounted) return;
 if (regenerated.trim().isEmpty) {
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(content: Text('AI returned empty content.')),
 );
 return;
 }
 _controller.text = regenerated.trim();
 _controller.selection = TextSelection.fromPosition(
 TextPosition(offset: _controller.text.length),
 );
 _handleChanged(_controller.text);
 } catch (e) {
 if (!mounted) return;
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(content: Text('Failed to regenerate: $e')),
 );
 } finally {
 if (mounted) setState(() => _isRegenerating = false);
 }
 }

 @override
 Widget build(BuildContext context) {
 return _CollapsibleSectionCard(
 title: widget.title,
 subtitle: widget.subtitle,
 onAiRegenerate: _handleRegenerate,
 isAiLoading: _isRegenerating,
 initiallyExpanded: widget.initiallyExpanded,
 child: VoiceTextField(
 controller: _controller,
 minLines: widget.minLines,
 maxLines: widget.maxLines,
 onChanged: _handleChanged,
 decoration: InputDecoration(
 hintText: widget.hintText,
 hintStyle: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 13),
 filled: true,
 fillColor: const Color(0xFFF8FAFC),
 contentPadding: const EdgeInsets.all(14),
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
 borderSide: const BorderSide(color: Color(0xFFFFD700), width: 1.2),
 ),
 ),
 style: const TextStyle(fontSize: 13, color: Color(0xFF1F2937)),
 ),
 );
 }
}

class _ContractsPreviewSection extends StatelessWidget {
 const _ContractsPreviewSection({
 required this.projectId,
 required this.onEdit,
 });

 final String? projectId;
 final ValueChanged<ContractModel> onEdit;

 @override
 Widget build(BuildContext context) {
 return projectId == null || projectId!.isEmpty
 ? const Text('Open a project to add contracts.',
 style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)))
 : StreamBuilder<List<ContractModel>>(
 stream: ContractService.streamContracts(projectId!),
 builder: (context, snapshot) {
 final contracts = snapshot.data ?? const <ContractModel>[];
 if (contracts.isEmpty) {
 return Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: const [
 Text('No planned contracts yet.',
 style:
 TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
 SizedBox(height: 10),
 Text(
 'Use “Create Contract” to define vendors, value, and dates.',
 style:
 TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
 ],
 );
 }
 return Column(
 children: contracts
 .take(5)
 .map(
 (contract) => _ContractPreviewRow(
 contract: contract,
 onTap: () => onEdit(contract),
 ),
 )
 .toList(),
 );
 },
 );
 }
}

class _ContractPreviewRow extends StatelessWidget {
 const _ContractPreviewRow({required this.contract, required this.onTap});

 final ContractModel contract;
 final VoidCallback onTap;

 @override
 Widget build(BuildContext context) {
 return InkWell(
 onTap: onTap,
 borderRadius: BorderRadius.circular(12),
 child: Container(
 margin: const EdgeInsets.only(bottom: 12),
 padding: const EdgeInsets.all(12),
 decoration: BoxDecoration(
 color: const Color(0xFFF8FAFC),
 borderRadius: BorderRadius.circular(12),
 border: Border.all(color: const Color(0xFFE2E8F0)),
 ),
 child: Row(
 children: [
 Expanded(
 flex: 3,
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(contract.name,
 style: const TextStyle(
 fontSize: 13,
 fontWeight: FontWeight.w700,
 color: Color(0xFF111827))),
 const SizedBox(height: 4),
 Text(
 contract.contractType.isNotEmpty
 ? contract.contractType
 : 'Contract type TBD',
 style:
 const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
 ),
 ],
 ),
 ),
 Expanded(
 flex: 2,
 child: Text(_formatCurrency(contract.estimatedValue),
 style: const TextStyle(
 fontSize: 12,
 fontWeight: FontWeight.w600,
 color: Color(0xFFFFC812))),
 ),
 Expanded(
 flex: 2,
 child: Text(
 '${_formatShortDate(contract.startDate)} - ${_formatShortDate(contract.endDate)}',
 style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
 ),
 ),
 ],
 ),
 ),
 );
 }
}

class _ContractsDataSection extends StatelessWidget {
 const _ContractsDataSection({
 required this.projectId,
 required this.hasDashboardPayload,
 });

 final String? projectId;
 final bool hasDashboardPayload;

 @override
 Widget build(BuildContext context) {
 if (projectId == null || projectId!.isEmpty) {
 return const _EmptyContractsState();
 }
 return StreamBuilder<List<ContractModel>>(
 stream: ContractService.streamContracts(projectId!),
 builder: (context, snapshot) {
 final contracts = snapshot.data ?? const <ContractModel>[];
 final hasContractData = hasDashboardPayload || contracts.isNotEmpty;
 if (!hasContractData) {
 return const _EmptyContractsState();
 }
 return Column(
 crossAxisAlignment: CrossAxisAlignment.stretch,
 children: const [
 _ContractingNoteBanner(),
 ],
 );
 },
 );
 }
}

class _AdditionalNotesSection extends StatelessWidget {
 const _AdditionalNotesSection(
 {required this.controller, required this.onChanged});

 final TextEditingController controller;
 final ValueChanged<String> onChanged;

 @override
 Widget build(BuildContext context) {
 return Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 const Text(
 'Additional Notes',
 style: TextStyle(
 fontSize: 16,
 fontWeight: FontWeight.w700,
 color: Color(0xFF111827)),
 ),
 const SizedBox(height: 10),
 _NotesField(controller: controller, onChanged: onChanged),
 ],
 );
 }
}

class _NotesField extends StatelessWidget {
 const _NotesField({required this.controller, this.onChanged});

 final TextEditingController controller;
 final ValueChanged<String>? onChanged;

 @override
 Widget build(BuildContext context) {
 return Container(
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(16),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 boxShadow: const [
 BoxShadow(
 color: Color(0x0A000000), blurRadius: 10, offset: Offset(0, 6)),
 ],
 ),
 padding: const EdgeInsets.all(20),
 child: VoiceTextField(
 controller: controller,
 minLines: 5,
 maxLines: null,
 onChanged: onChanged,
 decoration: const InputDecoration(
 border: InputBorder.none,
 hintText: 'Input your notes here...',
 hintStyle: TextStyle(color: Color(0xFF9CA3AF), fontSize: 14),
 ),
 style: const TextStyle(fontSize: 14, color: Color(0xFF1F2937)),
 ),
 );
 }
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

class _SummaryStatData {
 const _SummaryStatData(this.label, this.value, this.supporting, this.color);

 final String label;
 final String value;
 final String supporting;
 final Color color;
}

class _EmptyContractsState extends StatelessWidget {
 const _EmptyContractsState();

 @override
 Widget build(BuildContext context) {
 return Container(
 width: double.infinity,
 padding: const EdgeInsets.all(24),
 decoration: BoxDecoration(
 color: const Color(0xFFF9FAFB),
 borderRadius: BorderRadius.circular(20),
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
 child: const Icon(Icons.description_outlined,
 color: Color(0xFFF59E0B)),
 ),
 const SizedBox(width: 14),
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: const [
 Text('No contract data yet',
 style: TextStyle(
 fontSize: 14,
 fontWeight: FontWeight.w700,
 color: Color(0xFF111827))),
 SizedBox(height: 6),
 Text(
 'Capture contract notes or add contract details to populate the dashboard.',
 style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
 ),
 ],
 ),
 ),
 ],
 ),
 );
 }
}

class _EmptyPanelMessage extends StatelessWidget {
 const _EmptyPanelMessage(this.message);

 final String message;

 @override
 Widget build(BuildContext context) {
 return Container(
 width: double.infinity,
 padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
 decoration: BoxDecoration(
 color: const Color(0xFFF9FAFB),
 borderRadius: BorderRadius.circular(18),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 ),
 child: Text(
 message,
 style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
 ),
 );
 }
}

class _TimelineSection extends StatefulWidget {
 const _TimelineSection({this.showHeader = true});

 final bool showHeader;

 @override
 State<_TimelineSection> createState() => _TimelineSectionState();
}

class _TimelineSectionState extends State<_TimelineSection> {
 // store per-step min/max estimates
 final Map<int, int> _minDays = {1: 1, 2: 3, 3: 1, 4: 7, 5: 1};
 final Map<int, int> _maxDays = {1: 2, 2: 5, 3: 2, 4: 9, 5: 2};

 String _estimateLabel(int number) {
 final min = _minDays[number] ?? 0;
 final max = _maxDays[number] ?? min;
 if (min == max) return 'Estimated: $min days';
 return 'Estimated: $min-$max days';
 }

 String _totalEstimateLabel() {
 int totalMin = 0;
 int totalMax = 0;
 for (final n in [1, 2, 3, 4, 5]) {
 totalMin += _minDays[n] ?? 0;
 totalMax += _maxDays[n] ?? (_minDays[n] ?? 0);
 }
 if (totalMin == totalMax) return 'Total estimate time:\n$totalMin days';
 return 'Total estimate time:\n$totalMin-$totalMax days';
 }

 Future<void> _editEstimate(BuildContext context, int number) async {
 final minController =
 TextEditingController(text: (_minDays[number] ?? 0).toString());
 final maxController = TextEditingController(
 text: (_maxDays[number] ?? (_minDays[number] ?? 0)).toString());

 await showDialog(
 context: context,
 builder: (ctx) {
 return AlertDialog(
 shape:
 RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
 title: const Text('Set estimated days'),
 content: SizedBox(
 width: 420,
 child: Column(
 mainAxisSize: MainAxisSize.min,
 children: [
 VoiceTextField(
 controller: minController,
 keyboardType: TextInputType.number,
 decoration: const InputDecoration(
 labelText: 'Minimum days', hintText: 'e.g. 1'),
 ),
 const SizedBox(height: 12),
 VoiceTextField(
 controller: maxController,
 keyboardType: TextInputType.number,
 decoration: const InputDecoration(
 labelText: 'Maximum days', hintText: 'e.g. 3'),
 ),
 ],
 ),
 ),
 actions: [
 TextButton(
 onPressed: () => Navigator.pop(ctx),
 child: const Text('Cancel')),
 ElevatedButton(
 onPressed: () {
 final min = int.tryParse(minController.text.trim());
 final max = int.tryParse(maxController.text.trim());
 if (min == null || min < 0) {
 Navigator.pop(ctx);
 return;
 }
 final resolvedMax = (max == null || max < min) ? min : max;
 setState(() {
 _minDays[number] = min;
 _maxDays[number] = resolvedMax;
 });
 Navigator.pop(ctx);
 },
 style: ElevatedButton.styleFrom(
 backgroundColor: const Color(0xFFFFC812),
 foregroundColor: Colors.white),
 child: const Text('Save'),
 ),
 ],
 );
 },
 );
 }

 @override
 Widget build(BuildContext context) {
 final steps = [
 _TimelineStepData(
 number: 1,
 title: 'Contract Creation',
 description:
 'Develop scope of work, identify potential contractors, etc.',
 estimate: _estimateLabel(1),
 status: _TimelineStatus.current,
 ),
 _TimelineStepData(
 number: 2,
 title: 'Internal Review',
 description: 'Review by key stakeholders',
 estimate: _estimateLabel(2),
 status: _TimelineStatus.current,
 ),
 _TimelineStepData(
 number: 3,
 title: 'Contractor review',
 description: 'Request for information and/or Quote',
 estimate: _estimateLabel(3),
 status: _TimelineStatus.current,
 ),
 _TimelineStepData(
 number: 4,
 title: 'Bidding and Contract Review',
 description: 'Review of bids and clarification cycles',
 estimate: _estimateLabel(4),
 status: _TimelineStatus.current, // highlight like 1-3
 ),
 _TimelineStepData(
 number: 5,
 title: 'Contract Award',
 description: 'Selection of contractor, contract signing',
 estimate: _estimateLabel(5),
 status: _TimelineStatus.current, // highlight like 1-3
 ),
 ];

 return Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 if (widget.showHeader) ...[
 const Text(
 'Confirm Contracting Timeline',
 style: TextStyle(
 fontSize: 18,
 fontWeight: FontWeight.w600,
 color: Color(0xFF111827)),
 ),
 const SizedBox(height: 16),
 ],
 Container(
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(20),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 ),
 padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 for (final step in steps) ...[
 _TimelineStep(
 step: step,
 onEdit: () => _editEstimate(context, step.number)),
 const SizedBox(height: 24),
 ],
 Container(
 width: double.infinity,
 padding:
 const EdgeInsets.symmetric(vertical: 16, horizontal: 18),
 decoration: BoxDecoration(
 borderRadius: BorderRadius.circular(18),
 color: const Color(0xFFF9FAFB),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 ),
 child: Text(
 _totalEstimateLabel(),
 style: const TextStyle(
 fontSize: 14,
 fontWeight: FontWeight.w600,
 color: Color(0xFF111827)),
 ),
 ),
 ],
 ),
 ),
 ],
 );
 }
}

class _ContractingNoteBanner extends StatelessWidget {
 const _ContractingNoteBanner();

 @override
 Widget build(BuildContext context) {
 return Container(
 width: double.infinity,
 padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 22),
 decoration: BoxDecoration(
 borderRadius: BorderRadius.circular(18),
 gradient: const LinearGradient(
 colors: [Color(0xFFF3F4FF), Color(0xFFDDE9FF)],
 begin: Alignment.topLeft,
 end: Alignment.bottomRight,
 ),
 border: Border.all(color: const Color(0xFFB4C9FF)),
 ),
 child: const Text(
 'Note that the contracting timeline would be applied to all contracts but can be adjusted when required for respective contracts.\nNeed help? Ask AI KAZ some prompting questions related to your project type',
 style: TextStyle(fontSize: 14, color: Color(0xFF0F172A), height: 1.4),
 ),
 );
 }
}

class _UserBadge extends StatelessWidget {
 const _UserBadge();

 String _roleFor(User? user) {
 final email = user?.email?.toLowerCase() ?? '';
 if (email.endsWith('@nduproject.com')) {
 return 'Owner';
 }
 return 'Member';
 }

 @override
 Widget build(BuildContext context) {
 final user = FirebaseAuth.instance.currentUser;
 final displayName =
 FirebaseAuthService.displayNameOrEmail(fallback: 'User');
 final email = user?.email ?? '';
 final initials = _initials(displayName.isNotEmpty
 ? displayName
 : (email.isNotEmpty ? email : 'U'));
 final role = _roleFor(user);

 return Container(
 padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(999),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 ),
 child: Row(
 mainAxisSize: MainAxisSize.min,
 children: [
 CircleAvatar(
 radius: 22,
 backgroundColor: const Color(0xFFE5E7EB),
 child: Text(initials,
 style: const TextStyle(
 fontSize: 14,
 fontWeight: FontWeight.w600,
 color: Color(0xFF1F2937))),
 ),
 const SizedBox(width: 10),
 Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 mainAxisSize: MainAxisSize.min,
 children: [
 Text(
 email.isNotEmpty ? email : displayName,
 style: const TextStyle(
 fontSize: 13,
 fontWeight: FontWeight.w600,
 color: Color(0xFF111827)),
 ),
 Text(
 role,
 style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
 ),
 ],
 ),
 const SizedBox(width: 6),
 const Icon(Icons.keyboard_arrow_down_rounded,
 color: Color(0xFF9CA3AF)),
 ],
 ),
 );
 }

 String _initials(String text) {
 final trimmed = text.trim();
 if (trimmed.isEmpty) {
 return 'U';
 }
 final parts = trimmed.split(' ');
 if (parts.length >= 2) {
 final first = parts[0].isNotEmpty ? parts[0][0] : '';
 final second = parts[1].isNotEmpty ? parts[1][0] : '';
 final result = '$first$second';
 return result.isEmpty ? 'U' : result.toUpperCase();
 }
 return trimmed[0].toUpperCase();
 }
}

class _TimelineStep extends StatelessWidget {
 const _TimelineStep({required this.step, this.onEdit});

 final _TimelineStepData step;
 final VoidCallback? onEdit;

 @override
 Widget build(BuildContext context) {
 final isCurrent = step.status == _TimelineStatus.current;
 final circleColor =
 isCurrent ? const Color(0xFFFFD233) : const Color(0xFFE5E7EB);
 final numberColor =
 isCurrent ? const Color(0xFF111827) : const Color(0xFF9CA3AF);
 final titleColor =
 isCurrent ? const Color(0xFF111827) : const Color(0xFF9CA3AF);
 final descriptionColor =
 isCurrent ? const Color(0xFF4B5563) : const Color(0xFF9CA3AF);

 return Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Container(
 width: 42,
 height: 42,
 decoration: BoxDecoration(
 color: circleColor,
 shape: BoxShape.circle,
 ),
 alignment: Alignment.center,
 child: Text(
 step.number.toString(),
 style: TextStyle(
 fontSize: 18, fontWeight: FontWeight.w700, color: numberColor),
 ),
 ),
 const SizedBox(width: 18),
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(step.title,
 style: TextStyle(
 fontSize: 16,
 fontWeight: FontWeight.w600,
 color: titleColor)),
 const SizedBox(height: 6),
 Text(step.description,
 style: TextStyle(fontSize: 14, color: descriptionColor)),
 const SizedBox(height: 8),
 Row(
 mainAxisSize: MainAxisSize.min,
 children: [
 // Make the estimate label itself editable/clickable
 Tooltip(
 message: 'Edit estimated days',
 child: InkWell(
 onTap: onEdit,
 borderRadius: BorderRadius.circular(6),
 child: Padding(
 padding: const EdgeInsets.symmetric(
 horizontal: 4, vertical: 2),
 child: Text(
 step.estimate,
 style: TextStyle(
 fontSize: 12,
 fontWeight: FontWeight.w700,
 color: const Color(0xFFFFC812),
 decoration: TextDecoration.underline,
 ),
 ),
 ),
 ),
 ),
 if (onEdit != null) ...[
 const SizedBox(width: 12),
 TextButton.icon(
 onPressed: onEdit,
 style: TextButton.styleFrom(
 padding: const EdgeInsets.symmetric(
 horizontal: 12, vertical: 8),
 minimumSize: const Size(0, 0),
 foregroundColor: const Color(0xFFFFC812),
 ),
 icon: const Icon(Icons.edit_outlined, size: 14),
 label: const Text('Set days',
 style: TextStyle(
 fontSize: 12, fontWeight: FontWeight.w600)),
 ),
 ],
 ],
 ),
 ],
 ),
 ),
 ],
 );
 }
}

class _ContractMetricsRow extends StatelessWidget {
 const _ContractMetricsRow({required this.metrics});

 final List<_ContractMetricData> metrics;

 @override
 Widget build(BuildContext context) {
 return LayoutBuilder(
 builder: (context, constraints) {
 const double gap = 16;
 double cardWidth = constraints.maxWidth;

 if (constraints.maxWidth >= 1080) {
 cardWidth = (constraints.maxWidth - (metrics.length - 1) * gap) /
 metrics.length;
 } else if (constraints.maxWidth >= 720) {
 cardWidth = (constraints.maxWidth - gap) / 2;
 }

 return Wrap(
 spacing: gap,
 runSpacing: gap,
 children: metrics
 .map(
 (metric) => SizedBox(
 width: cardWidth,
 child: _ContractMetricCard(metric: metric),
 ),
 )
 .toList(),
 );
 },
 );
 }
}

class _ContractMetricCard extends StatelessWidget {
 const _ContractMetricCard({required this.metric});

 final _ContractMetricData metric;

 @override
 Widget build(BuildContext context) {
 return Container(
 padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(20),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 boxShadow: const [
 BoxShadow(
 color: Color(0x08000000), blurRadius: 12, offset: Offset(0, 6)),
 ],
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Container(
 width: 42,
 height: 42,
 decoration: BoxDecoration(
 color: metric.accentColor.withOpacity(0.12),
 borderRadius: BorderRadius.circular(14),
 ),
 child: Icon(metric.icon, color: metric.accentColor, size: 22),
 ),
 const SizedBox(height: 18),
 Text(
 metric.value,
 style: const TextStyle(
 fontSize: 26,
 fontWeight: FontWeight.w700,
 color: Color(0xFF111827)),
 ),
 const SizedBox(height: 6),
 Text(
 metric.label,
 style: const TextStyle(
 fontSize: 14,
 fontWeight: FontWeight.w600,
 color: Color(0xFF6B7280)),
 ),
 const SizedBox(height: 10),
 Text(
 metric.detail,
 style: const TextStyle(fontSize: 13, color: Color(0xFF4B5563)),
 ),
 ],
 ),
 );
 }
}

class _ContractRecordCard extends StatelessWidget {
 const _ContractRecordCard({required this.record});

 final _ContractRecord record;

 @override
 Widget build(BuildContext context) {
 return Container(
 padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 28),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(22),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 boxShadow: const [
 BoxShadow(
 color: Color(0x09000000), blurRadius: 14, offset: Offset(0, 10)),
 ],
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 record.name,
 style: const TextStyle(
 fontSize: 18,
 fontWeight: FontWeight.w600,
 color: Color(0xFF111827)),
 ),
 const SizedBox(height: 6),
 Text(
 record.code,
 style: const TextStyle(
 fontSize: 13, color: Color(0xFF6B7280)),
 ),
 const SizedBox(height: 4),
 Text(
 'Owner: ${record.owner}',
 style: const TextStyle(
 fontSize: 13, color: Color(0xFF4B5563)),
 ),
 ],
 ),
 ),
 _StatusPill(label: record.status, color: record.statusColor),
 ],
 ),
 const SizedBox(height: 22),
 Wrap(
 spacing: 18,
 runSpacing: 12,
 children: [
 _RecordInfoRow(
 icon: Icons.payments_outlined,
 label: 'Contract Value',
 value: record.value),
 _RecordInfoRow(
 icon: Icons.calendar_month_outlined,
 label: 'Effective',
 value:
 '${record.effectiveDate} • Renewals on ${record.renewalDate}',
 ),
 ],
 ),
 const SizedBox(height: 20),
 const Divider(color: Color(0xFFE5E7EB), height: 32),
 const Text(
 'Highlights',
 style: TextStyle(
 fontSize: 14,
 fontWeight: FontWeight.w600,
 color: Color(0xFF111827)),
 ),
 const SizedBox(height: 12),
 ...record.highlights.map(
 (item) => Padding(
 padding: const EdgeInsets.only(bottom: 8),
 child: Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 const Padding(
 padding: EdgeInsets.only(top: 4),
 child: Icon(Icons.check_circle,
 size: 16, color: Color(0xFF10B981)),
 ),
 const SizedBox(width: 8),
 Expanded(
 child: Text(
 item,
 style: const TextStyle(
 fontSize: 13, color: Color(0xFF4B5563), height: 1.4),
 ),
 ),
 ],
 ),
 ),
 ),
 const SizedBox(height: 14),
 Row(
 mainAxisAlignment: MainAxisAlignment.spaceBetween,
 children: [
 Text(
 record.lastUpdated,
 style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
 ),
 TextButton.icon(
 onPressed: () {},
 style: TextButton.styleFrom(
 foregroundColor: const Color(0xFFFFC812),
 padding:
 const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
 shape: RoundedRectangleBorder(
 borderRadius: BorderRadius.circular(12)),
 ),
 icon: const Icon(Icons.open_in_new_rounded, size: 16),
 label: const Text('View Contract',
 style:
 TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
 ),
 ],
 )
 ],
 ),
 );
 }
}

class _RecordInfoRow extends StatelessWidget {
 const _RecordInfoRow(
 {required this.icon, required this.label, required this.value});

 final IconData icon;
 final String label;
 final String value;

 @override
 Widget build(BuildContext context) {
 return ConstrainedBox(
 constraints: const BoxConstraints(minWidth: 220),
 child: Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Container(
 width: 36,
 height: 36,
 decoration: BoxDecoration(
 color: const Color(0xFFF3F4F6),
 borderRadius: BorderRadius.circular(12),
 ),
 child: Icon(icon, color: const Color(0xFFFFC812), size: 18),
 ),
 const SizedBox(width: 12),
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(label,
 style: const TextStyle(
 fontSize: 12, color: Color(0xFF6B7280))),
 const SizedBox(height: 4),
 Text(value,
 style: const TextStyle(
 fontSize: 13,
 fontWeight: FontWeight.w600,
 color: Color(0xFF111827))),
 ],
 ),
 ),
 ],
 ),
 );
 }
}

class _StatusPill extends StatelessWidget {
 const _StatusPill({required this.label, required this.color});

 final String label;
 final Color color;

 @override
 Widget build(BuildContext context) {
 return Container(
 padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
 decoration: BoxDecoration(
 color: color.withOpacity(0.12),
 borderRadius: BorderRadius.circular(999),
 border: Border.all(color: color.withOpacity(0.32)),
 ),
 child: Row(
 mainAxisSize: MainAxisSize.min,
 children: [
 Icon(Icons.verified_rounded, color: color, size: 16),
 const SizedBox(width: 6),
 Text(label,
 style: TextStyle(
 fontSize: 12, fontWeight: FontWeight.w600, color: color)),
 ],
 ),
 );
 }
}

class ContractDetailsScreen extends StatefulWidget {
 const ContractDetailsScreen({super.key});

 @override
 State<ContractDetailsScreen> createState() => _ContractDetailsScreenState();
}

class _ContractDetailsScreenState extends State<ContractDetailsScreen> {
 final TextEditingController _additionalInfoController =
 TextEditingController();
 int _selectedTabIndex = 0;
 bool _detailsLoaded = false;
 bool _isGeneratingDetails = false;
 bool _aiGeneratedDetails = false;
 ContractModel? _primaryContract;
 String _overviewTitle = '';
 String _overviewStatus = '';
 String _contractIdLabel = '';
 List<_ContractMilestoneData> _overviewMilestones = [];
 String _overviewDescription = '';
 List<String> _scopeItems = [];
 List<_ContractDocumentData> _documents = [];
 List<_BidderInfoData> _bidderInfo = [];
 _ContactInfoData? _contactInfo;
 _PreBidMeetingData? _preBidMeeting;

 @override
 void initState() {
 super.initState();
 WidgetsBinding.instance.addPostFrameCallback((_) => _loadDetailsData());
 }

 @override
 void dispose() {
 _additionalInfoController.dispose();
 super.dispose();
 }

 Future<void> _loadDetailsData() async {
 if (_detailsLoaded) return;
 final provider = ProjectDataHelper.getProvider(context);
 final projectId = provider.projectData.projectId;
 if (projectId == null || projectId.isEmpty) return;

 try {
 final contracts = await ContractService.streamContracts(projectId).first;
 if (contracts.isNotEmpty) {
 _primaryContract = contracts.first;
 }
 } catch (error) {
 debugPrint('Failed to load contracts for details: $error');
 }

 try {
 final doc = await FirebaseFirestore.instance
 .collection('projects')
 .doc(projectId)
 .collection(_contractingCollection)
 .doc('details')
 .get();
 final docExists = doc.exists;
 if (doc.exists) {
 final data = doc.data() ?? {};
 final milestones = (data['milestones'] as List?)
 ?.whereType<Map>()
 .map((row) => _ContractMilestoneData.fromJson(
 Map<String, dynamic>.from(row)))
 .toList() ??
 [];
 final documents = (data['documents'] as List?)
 ?.whereType<Map>()
 .map((row) => _ContractDocumentData.fromJson(
 Map<String, dynamic>.from(row)))
 .toList() ??
 [];
 final bidderInfo = (data['bidderInfo'] as List?)
 ?.whereType<Map>()
 .map((row) =>
 _BidderInfoData.fromJson(Map<String, dynamic>.from(row)))
 .toList() ??
 [];
 final contact = data['contactInfo'];
 final meeting = data['preBidMeeting'];
 final scope = (data['scopeItems'] as List?)
 ?.map((item) => item.toString())
 .where((item) => item.trim().isNotEmpty)
 .toList() ??
 [];
 if (!mounted) return;
 setState(() {
 _additionalInfoController.text =
 (data['additionalInfo'] ?? '').toString();
 _overviewTitle = (data['overviewTitle'] ?? '').toString();
 _overviewStatus = (data['overviewStatus'] ?? '').toString();
 _contractIdLabel = (data['contractIdLabel'] ?? '').toString();
 _overviewDescription = (data['overviewDescription'] ?? '').toString();
 _overviewMilestones
 ..clear()
 ..addAll(milestones);
 _documents
 ..clear()
 ..addAll(documents);
 _bidderInfo
 ..clear()
 ..addAll(bidderInfo);
 _scopeItems
 ..clear()
 ..addAll(scope);
 _contactInfo = contact is Map
 ? _ContactInfoData.fromJson(Map<String, dynamic>.from(contact))
 : null;
 _preBidMeeting = meeting is Map
 ? _PreBidMeetingData.fromJson(Map<String, dynamic>.from(meeting))
 : null;
 });
 }
 _detailsLoaded = true;
 if (_documents.isEmpty &&
 _bidderInfo.isEmpty &&
 _overviewMilestones.isEmpty) {
 _applyContractFallbacks();
 } else {
 _applyContractFallbacks();
 if (!docExists && _primaryContract != null) {
 await _persistDetails();
 }
 }
 } catch (error) {
 debugPrint('Failed to load contract details: $error');
 }
 }

 void _applyContractFallbacks() {
 if (_primaryContract == null) return;
 final contract = _primaryContract!;
 if (_overviewTitle.trim().isEmpty) {
 _overviewTitle = contract.name;
 }
 if (_contractIdLabel.trim().isEmpty) {
 _contractIdLabel = contract.id;
 }
 if (_overviewStatus.trim().isEmpty) {
 _overviewStatus = contract.status;
 }
 if (_overviewDescription.trim().isEmpty &&
 contract.description.trim().isNotEmpty) {
 _overviewDescription = contract.description.trim();
 }
 if (_scopeItems.isEmpty && contract.scope.trim().isNotEmpty) {
 _scopeItems = contract.scope
 .split(RegExp(r'[\n;•]+'))
 .map((item) => item.trim())
 .where((item) => item.isNotEmpty)
 .toList();
 }
 if (_overviewMilestones.isEmpty) {
 final created = contract.createdAt;
 final start = contract.startDate;
 final end = contract.endDate;
 final bidOpeningDate =
 end?.add(const Duration(days: 2));
 _overviewMilestones = [
 _ContractMilestoneData(
 title: 'Published Date',
 value: _formatShortDate(created),
 accentColor: const Color(0xFFFFC812),
 ),
 _ContractMilestoneData(
 title: 'Clarification Deadline',
 value: _formatShortDate(start),
 accentColor: const Color(0xFFFFC812),
 ),
 _ContractMilestoneData(
 title: 'Submission Deadline',
 value: _formatShortDate(end),
 accentColor: const Color(0xFFEF4444),
 emphasize: true,
 ),
 _ContractMilestoneData(
 title: 'Bid Opening',
 value: _formatShortDate(bidOpeningDate),
 accentColor: const Color(0xFFFFC812),
 ),
 ];
 }
 }

 // ignore: unused_element
 Future<void> _populateDetailsFromAi() async {
 if (_aiGeneratedDetails || _isGeneratingDetails) return;
 final projectData = ProjectDataHelper.getData(context);
 final contextText = ProjectDataHelper.buildFepContext(projectData,
 sectionLabel: 'Contract Details');
 if (contextText.trim().isEmpty) return;

 setState(() => _isGeneratingDetails = true);
 Map<String, List<Map<String, dynamic>>> generated = {};
 try {
 generated = await OpenAiServiceSecure().generateLaunchPhaseEntries(
 context: contextText,
 sections: const {
 'contract_overview':
 'Contract overview milestone cards (title=label, details=date/value, status=priority)',
 'contract_description':
 'Contract description (title=heading, details=paragraph)',
 'scope_items': 'Scope of work bullets (title=item)',
 'contract_documents':
 'Required documents (title=document, details=type/size, status=file type)',
 'bidder_information':
 'Information for bidders (title=topic, details=guidance)',
 'contact_details':
 'Primary contact (title=name, details=role, status=email)',
 'prebid_meeting':
 'Pre-bid meeting (title=date, details=time, status=location)',
 },
 itemsPerSection: 3,
 );
 } catch (error) {
 debugPrint('Details AI call failed: $error');
 }

 if (!mounted) return;
 if (_documents.isNotEmpty ||
 _bidderInfo.isNotEmpty ||
 _overviewMilestones.isNotEmpty) {
 setState(() => _isGeneratingDetails = false);
 _aiGeneratedDetails = true;
 return;
 }

 setState(() {
 _overviewMilestones =
 _mapOverviewMilestones(generated['contract_overview']);
 _overviewDescription = _mapDescription(generated['contract_description']);
 _scopeItems = _mapScopeItems(generated['scope_items']);
 _documents = _mapDocuments(generated['contract_documents']);
 _bidderInfo = _mapBidderInfo(generated['bidder_information']);
 _contactInfo = _mapContactInfo(generated['contact_details']);
 _preBidMeeting = _mapPreBidMeeting(generated['prebid_meeting']);
 _isGeneratingDetails = false;
 });
 _applyContractFallbacks();
 _aiGeneratedDetails = true;
 await _persistDetails();
 }

 List<_ContractMilestoneData> _mapOverviewMilestones(
 List<Map<String, dynamic>>? raw) {
 if (raw == null) return [];
 return raw
 .map((item) {
 final title = (item['title'] ?? '').toString().trim();
 final value = (item['details'] ?? '').toString().trim();
 final status = (item['status'] ?? '').toString().trim();
 if (title.isEmpty || value.isEmpty) return null;
 final bool emphasize = status.toLowerCase().contains('deadline');
 return _ContractMilestoneData(
 title: title,
 value: value,
 accentColor:
 emphasize ? const Color(0xFFEF4444) : const Color(0xFFFFC812),
 emphasize: emphasize,
 );
 })
 .whereType<_ContractMilestoneData>()
 .toList();
 }

 String _mapDescription(List<Map<String, dynamic>>? raw) {
 if (raw == null || raw.isEmpty) return '';
 final details =
 (raw.first['details'] ?? raw.first['title'] ?? '').toString().trim();
 return details;
 }

 List<String> _mapScopeItems(List<Map<String, dynamic>>? raw) {
 if (raw == null) return [];
 return raw
 .map((item) => (item['title'] ?? '').toString().trim())
 .where((text) => text.isNotEmpty)
 .toList();
 }

 List<_ContractDocumentData> _mapDocuments(List<Map<String, dynamic>>? raw) {
 if (raw == null) return [];
 return raw
 .map((item) => _ContractDocumentData.fromLaunchEntry(item))
 .where((doc) => doc.title.isNotEmpty)
 .toList();
 }

 List<_BidderInfoData> _mapBidderInfo(List<Map<String, dynamic>>? raw) {
 if (raw == null) return [];
 return raw
 .map((item) => _BidderInfoData.fromLaunchEntry(item))
 .where((info) => info.title.isNotEmpty)
 .toList();
 }

 _ContactInfoData? _mapContactInfo(List<Map<String, dynamic>>? raw) {
 if (raw == null || raw.isEmpty) return null;
 return _ContactInfoData.fromLaunchEntry(raw.first);
 }

 _PreBidMeetingData? _mapPreBidMeeting(List<Map<String, dynamic>>? raw) {
 if (raw == null || raw.isEmpty) return null;
 return _PreBidMeetingData.fromLaunchEntry(raw.first);
 }

 Future<void> _persistDetails() async {
 final provider = ProjectDataHelper.getProvider(context);
 final projectId = provider.projectData.projectId;
 if (projectId == null || projectId.isEmpty) return;

 final payload = {
 'additionalInfo': _additionalInfoController.text.trim(),
 'overviewTitle': _overviewTitle,
 'overviewStatus': _overviewStatus,
 'contractIdLabel': _contractIdLabel,
 'overviewDescription': _overviewDescription,
 'scopeItems': _scopeItems,
 'milestones': _overviewMilestones.map((item) => item.toJson()).toList(),
 'documents': _documents.map((item) => item.toJson()).toList(),
 'bidderInfo': _bidderInfo.map((item) => item.toJson()).toList(),
 'contactInfo': _contactInfo?.toJson(),
 'preBidMeeting': _preBidMeeting?.toJson(),
 'updatedAt': FieldValue.serverTimestamp(),
 };

 try {
 await FirebaseFirestore.instance
 .collection('projects')
 .doc(projectId)
 .collection(_contractingCollection)
 .doc('details')
 .set(payload, SetOptions(merge: true));
 } catch (error) {
 debugPrint('Failed to save contract details: $error');
 }
 }

 void _handleStepTap(int index) {
 if (index == 0) {
 Navigator.of(context).maybePop();
 } else if (index == 2) {
 _openContractingStatus();
 } else if (index == 3) {
 ContractingSummaryScreen.open(context);
 }
 }

 void _openContractingStatus() {
 Navigator.of(context).push(
 MaterialPageRoute(
 settings: const RouteSettings(name: 'ContractingStatusScreen'),
 builder: (_) => const ContractingStatusScreen(),
 ),
 );
 }

 @override
 Widget build(BuildContext context) {
 final bool isMobile = AppBreakpoints.isMobile(context);
 final double horizontalPadding = isMobile ? 24 : 48;

 return Scaffold(
 backgroundColor: Colors.white,
 body: SafeArea(
 child: Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 DraggableSidebar(
 openWidth: AppBreakpoints.sidebarWidth(context),
 child: const InitiationLikeSidebar(activeItemLabel: 'Contract'),
 ),
 Expanded(
 child: Stack(
 children: [
 SingleChildScrollView(
 padding: EdgeInsets.symmetric(
 horizontal: horizontalPadding,
 vertical: isMobile ? 28 : 48,
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 _StrategyHeader(
 onBack: () => Navigator.of(context).maybePop()),
 SizedBox(height: isMobile ? 24 : 36),
 _StrategyStepPills(
 selectedIndex: 1, onStepTap: _handleStepTap),
 SizedBox(height: isMobile ? 24 : 32),
 _AdditionalInfoField(
 controller: _additionalInfoController,
 onChanged: (_) => _persistDetails(),
 ),
 SizedBox(height: isMobile ? 24 : 32),
 _ContractOverviewSummaryCard(
 title: _overviewTitle.isNotEmpty
 ? _overviewTitle
 : (_primaryContract?.name ?? 'Contract overview'),
 contractId: _contractIdLabel.isNotEmpty
 ? _contractIdLabel
 : (_primaryContract?.id ?? 'TBD'),
 statusLabel: _overviewStatus.isNotEmpty
 ? _overviewStatus
 : (_primaryContract?.status ?? 'Pending'),
 milestones: _overviewMilestones,
 ),
 SizedBox(height: isMobile ? 24 : 32),
 _ContractDetailsContent(
 selectedIndex: _selectedTabIndex,
 onTabSelected: (index) =>
 setState(() => _selectedTabIndex = index),
 description: _overviewDescription,
 scopeItems: _scopeItems,
 documents: _documents,
 bidderInfo: _bidderInfo,
 contactInfo: _contactInfo,
 preBidMeeting: _preBidMeeting,
 ),
 SizedBox(height: isMobile ? 80 : 120),
 ],
 ),
 ),
 MobileSidebarHamburger(
 sidebar: const InitiationLikeSidebar(
 activeItemLabel: 'Contract',
 ),
 ),
 const KazAiChatBubble(),
 const AdminEditToggle(),
 ],
 ),
 ),
 ],
 ),
 ),
 );
 }
}

class ContractingStatusScreen extends StatefulWidget {
 const ContractingStatusScreen({super.key});

 @override
 State<ContractingStatusScreen> createState() =>
 _ContractingStatusScreenState();
}

class _ContractingStatusScreenState extends State<ContractingStatusScreen> {
 final TextEditingController _additionalInfoController =
 TextEditingController();
 String _selectedView = 'Overview';
 String _selectedContract = 'Select contract';
 String _selectedContractorStatus = 'All Status';
 bool _statusLoaded = false;
 bool _isGeneratingStatus = false;
 bool _aiGeneratedStatus = false;
 List<String> _timelineMonths = [];
 List<_StatusTimelineRowData> _timelineRows = [];
 double _timelineProgress = 0.0;
 _StatusSummaryData _summaryData = const _StatusSummaryData();
 List<_RecentActivityData> _recentActivity = [];
 List<_MilestoneEntry> _milestones = [];
 List<_ExecutionStepData> _executionSteps = [];
 List<_ContractorRowData> _contractors = [];
 List<ContractModel> _contracts = [];
 List<String> _contractOptions = [];

 @override
 void initState() {
 super.initState();
 WidgetsBinding.instance.addPostFrameCallback((_) => _loadStatusData());
 }

 @override
 void dispose() {
 _additionalInfoController.dispose();
 super.dispose();
 }

 Future<void> _loadStatusData() async {
 if (_statusLoaded) return;
 final provider = ProjectDataHelper.getProvider(context);
 final projectId = provider.projectData.projectId;
 if (projectId == null || projectId.isEmpty) return;

 try {
 _contracts = await ContractService.streamContracts(projectId).first;
 _contractOptions = _contracts
 .map((c) => c.name)
 .where((name) => name.isNotEmpty)
 .toList();
 if (_contractOptions.isNotEmpty) {
 _selectedContract = _contractOptions.first;
 }
 } catch (error) {
 debugPrint('Failed to load contracts for status: $error');
 }

 try {
 final doc = await FirebaseFirestore.instance
 .collection('projects')
 .doc(projectId)
 .collection(_contractingCollection)
 .doc('status')
 .get();
 if (doc.exists) {
 final data = doc.data() ?? {};
 final timeline = data['timeline'] as Map<String, dynamic>? ?? {};
 final rows = (timeline['rows'] as List?)
 ?.whereType<Map>()
 .map((row) => _StatusTimelineRowData.fromJson(
 Map<String, dynamic>.from(row)))
 .toList() ??
 [];
 final milestones = (data['milestones'] as List?)
 ?.whereType<Map>()
 .map((row) =>
 _MilestoneEntry.fromJson(Map<String, dynamic>.from(row)))
 .toList() ??
 [];
 final recent = (data['recentActivity'] as List?)
 ?.whereType<Map>()
 .map((row) => _RecentActivityData.fromJson(
 Map<String, dynamic>.from(row)))
 .toList() ??
 [];
 final contractors = (data['contractors'] as List?)
 ?.whereType<Map>()
 .map((row) =>
 _ContractorRowData.fromJson(Map<String, dynamic>.from(row)))
 .toList() ??
 [];
 final steps = (data['executionSteps'] as List?)
 ?.whereType<Map>()
 .map((row) =>
 _ExecutionStepData.fromJson(Map<String, dynamic>.from(row)))
 .toList() ??
 [];
 if (!mounted) return;
 setState(() {
 _additionalInfoController.text =
 (data['additionalInfo'] ?? '').toString();
 _timelineMonths = (timeline['months'] as List?)
 ?.map((e) => e.toString())
 .toList() ??
 [];
 _timelineRows = rows;
 _timelineProgress = (timeline['progress'] as num?)?.toDouble() ?? 0.0;
 _summaryData = _StatusSummaryData.fromJson(
 data['summary'] as Map<String, dynamic>? ?? {});
 _recentActivity = recent;
 _milestones = milestones;
 _contractors = contractors;
 _executionSteps = steps;
 });
 }
 _statusLoaded = true;
 if (_timelineRows.isEmpty &&
 _contractors.isEmpty &&
 _executionSteps.isEmpty) {
 if (_contracts.isNotEmpty) {
 _buildTimelineFromContracts();
 _applySummaryFromContracts();
 }
 } else if (_timelineRows.isEmpty && _contracts.isNotEmpty) {
 _buildTimelineFromContracts();
 }

 if (_summaryData.averageBidValue == 'TBD' && _contracts.isNotEmpty) {
 _applySummaryFromContracts();
 }
 } catch (error) {
 debugPrint('Failed to load contract status data: $error');
 }
 }

 void _buildTimelineFromContracts() {
 if (_contracts.isEmpty) return;
 final contractsWithDates = _contracts
 .where((c) => c.startDate != null && c.endDate != null)
 .toList();
 if (contractsWithDates.isEmpty) return;
 final startDates = contractsWithDates.map((c) => c.startDate!).toList();
 final endDates = contractsWithDates.map((c) => c.endDate!).toList();
 final earliest = startDates.reduce((a, b) => a.isBefore(b) ? a : b);
 final latest = endDates.reduce((a, b) => a.isAfter(b) ? a : b);

 final months = <String>[];
 DateTime cursor = DateTime(earliest.year, earliest.month);
 final endCursor = DateTime(latest.year, latest.month);
 while (!cursor.isAfter(endCursor) && months.length < 9) {
 months.add(_formatMonthLabel(cursor));
 cursor = DateTime(cursor.year, cursor.month + 1);
 }

 final now = DateTime.now();
 final rows = contractsWithDates.map((contract) {
 final cells = months.map((_) {
 if (now.isAfter(contract.endDate!)) {
 return const _StatusTimelineCellData(
 status: _TimelineStatusState.complete);
 }
 if (now.isBefore(contract.startDate!)) {
 return const _StatusTimelineCellData(
 status: _TimelineStatusState.notStarted);
 }
 return const _StatusTimelineCellData(
 status: _TimelineStatusState.inProgress);
 }).toList();
 return _StatusTimelineRowData(label: contract.name, cells: cells);
 }).toList();

 setState(() {
 _timelineMonths = months;
 _timelineRows = rows;
 _timelineProgress = _contracts.isEmpty ? 0.0 : 0.5;
 });
 }

 void _applySummaryFromContracts() {
 if (_contracts.isEmpty) return;
 final totalValue =
 _contracts.fold<double>(0.0, (total, c) => total + c.estimatedValue);
 final averageValue = totalValue / _contracts.length;
 final completed = _contracts
 .where((c) => c.status.toLowerCase().contains('complete'))
 .length;
 final statusLabel =
 completed == _contracts.length ? 'Complete' : 'In Progress';
 setState(() {
 _summaryData = _StatusSummaryData(
 averageBidValue: _formatCurrency(averageValue),
 totalContractors: '${_contracts.length}',
 milestoneProgress: '$completed/${_contracts.length} Complete',
 statusLabel: statusLabel,
 );
 });
 }

 // ignore: unused_element
 Future<void> _populateStatusFromAi() async {
 if (_aiGeneratedStatus || _isGeneratingStatus) return;
 final projectData = ProjectDataHelper.getData(context);
 final contextText = ProjectDataHelper.buildFepContext(projectData,
 sectionLabel: 'Contracting Status');
 if (contextText.trim().isEmpty) return;

 setState(() => _isGeneratingStatus = true);
 Map<String, List<Map<String, dynamic>>> generated = {};
 try {
 generated = await OpenAiServiceSecure().generateLaunchPhaseEntries(
 context: contextText,
 sections: const {
 'contract_timeline':
 'Contract status timeline rows (title=row label, details=summary, status=status)',
 'contract_status_summary':
 'Contract summary metrics (title=label, details=value, status=overall status)',
 'contract_recent_activity':
 'Recent activity (title=activity, details=date)',
 'contract_milestones':
 'Milestone dates (title=milestone, details=date, status=status)',
 'contract_execution_steps':
 'Execution steps (title=step, details=description, status=next action)',
 'contractors_directory':
 'Contractor entries (title=name, details=role | location | bid, status=status)',
 },
 itemsPerSection: 4,
 );
 } catch (error) {
 debugPrint('Status AI call failed: $error');
 }

 if (!mounted) return;
 if (_timelineRows.isNotEmpty ||
 _contractors.isNotEmpty ||
 _executionSteps.isNotEmpty) {
 setState(() => _isGeneratingStatus = false);
 _aiGeneratedStatus = true;
 return;
 }

 final months = _defaultTimelineMonths();
 setState(() {
 _timelineMonths = months;
 _timelineRows =
 _mapTimelineRows(generated['contract_timeline'], months.length);
 _timelineProgress = 0.45;
 _summaryData =
 _StatusSummaryData.fromEntries(generated['contract_status_summary']);
 _recentActivity =
 _mapRecentActivity(generated['contract_recent_activity']);
 _milestones = _mapMilestones(generated['contract_milestones']);
 _executionSteps =
 _mapExecutionSteps(generated['contract_execution_steps']);
 _contractors = _mapContractors(generated['contractors_directory']);
 _isGeneratingStatus = false;
 });
 _aiGeneratedStatus = true;
 await _persistStatus();
 }

 List<String> _defaultTimelineMonths() {
 final now = DateTime.now();
 return List.generate(
 6, (index) => _formatMonthLabel(DateTime(now.year, now.month + index)));
 }

 List<_StatusTimelineRowData> _mapTimelineRows(
 List<Map<String, dynamic>>? raw, int monthsLength) {
 if (raw == null) return [];
 return raw
 .map((item) =>
 _StatusTimelineRowData.fromLaunchEntry(item, monthsLength))
 .where((row) => row.label.isNotEmpty)
 .toList();
 }

 List<_RecentActivityData> _mapRecentActivity(
 List<Map<String, dynamic>>? raw) {
 if (raw == null) return [];
 return raw
 .map((item) => _RecentActivityData.fromLaunchEntry(item))
 .where((entry) => entry.description.isNotEmpty)
 .toList();
 }

 List<_MilestoneEntry> _mapMilestones(List<Map<String, dynamic>>? raw) {
 if (raw == null) return [];
 return raw
 .map((item) => _MilestoneEntry.fromLaunchEntry(item))
 .where((entry) => entry.label.isNotEmpty)
 .toList();
 }

 List<_ExecutionStepData> _mapExecutionSteps(List<Map<String, dynamic>>? raw) {
 if (raw == null) return [];
 final steps = raw
 .map((item) => _ExecutionStepData.fromLaunchEntry(item))
 .where((entry) => entry.title.isNotEmpty)
 .toList();
 if (steps.isNotEmpty) {
 final first = steps.first;
 steps[0] = _ExecutionStepData(
 title: first.title,
 description: first.description,
 statusDetail: first.statusDetail,
 highlightAction: true,
 );
 }
 return steps;
 }

 List<_ContractorRowData> _mapContractors(List<Map<String, dynamic>>? raw) {
 if (raw == null) return [];
 return raw
 .map((item) => _ContractorRowData.fromLaunchEntry(item))
 .where((entry) => entry.name.isNotEmpty)
 .toList();
 }

 Future<void> _persistStatus() async {
 final provider = ProjectDataHelper.getProvider(context);
 final projectId = provider.projectData.projectId;
 if (projectId == null || projectId.isEmpty) return;

 final payload = {
 'additionalInfo': _additionalInfoController.text.trim(),
 'timeline': {
 'months': _timelineMonths,
 'rows': _timelineRows.map((row) => row.toJson()).toList(),
 'progress': _timelineProgress,
 },
 'summary': _summaryData.toJson(),
 'recentActivity': _recentActivity.map((entry) => entry.toJson()).toList(),
 'milestones': _milestones.map((entry) => entry.toJson()).toList(),
 'executionSteps': _executionSteps.map((entry) => entry.toJson()).toList(),
 'contractors': _contractors.map((entry) => entry.toJson()).toList(),
 'updatedAt': FieldValue.serverTimestamp(),
 };

 try {
 await FirebaseFirestore.instance
 .collection('projects')
 .doc(projectId)
 .collection(_contractingCollection)
 .doc('status')
 .set(payload, SetOptions(merge: true));
 } catch (error) {
 debugPrint('Failed to save contract status: $error');
 }
 }

 void _handleStepTap(int index) {
 if (index == 1) {
 Navigator.of(context).pop();
 return;
 }
 if (index == 0) {
 Navigator.of(context).popUntil(
 (route) =>
 route.settings.name == 'ContractingStrategyScreen' || route.isFirst,
 );
 return;
 }
 if (index == 3) {
 ContractingSummaryScreen.open(context);
 }
 }

 Widget _buildSelectedView({required bool isMobile}) {
 switch (_selectedView) {
 case 'Overview':
 return Column(
 crossAxisAlignment: CrossAxisAlignment.stretch,
 children: [
 _ContractStatusOverview(
 isMobile: isMobile,
 months: _timelineMonths,
 rows: _timelineRows,
 progress: _timelineProgress,
 summaryData: _summaryData,
 recentActivity: _recentActivity,
 ),
 SizedBox(height: isMobile ? 24 : 32),
 _ContractStatusMilestonesCard(milestones: _milestones),
 SizedBox(height: isMobile ? 28 : 36),
 _ContractExecutionSection(
 selectedContract: _selectedContract,
 onContractChanged: (value) =>
 setState(() => _selectedContract = value),
 steps: _executionSteps,
 contractOptions: _contractOptions,
 ),
 ],
 );
 case 'Contractors':
 return _ContractorsDirectorySection(
 isMobile: isMobile,
 selectedStatus: _selectedContractorStatus,
 onStatusChanged: (value) =>
 setState(() => _selectedContractorStatus = value),
 rows: _filteredContractors(),
 contractTitle: _selectedContract,
 );
 case 'Contract Specifications':
 case 'Milestones':
 case 'Documents':
 return _StatusViewPlaceholder(label: _selectedView);
 default:
 return const SizedBox.shrink();
 }
 }

 List<_ContractorRowData> _filteredContractors() {
 if (_selectedContractorStatus == 'All Status') {
 return _contractors;
 }
 return _contractors
 .where((row) => row.statusLabel
 .toLowerCase()
 .contains(_selectedContractorStatus.toLowerCase()))
 .toList();
 }

 @override
 Widget build(BuildContext context) {
 final bool isMobile = AppBreakpoints.isMobile(context);
 final double horizontalPadding = isMobile ? 24 : 48;

 return Scaffold(
 backgroundColor: Colors.white,
 body: SafeArea(
 child: Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 DraggableSidebar(
 openWidth: AppBreakpoints.sidebarWidth(context),
 child: const InitiationLikeSidebar(activeItemLabel: 'Contract'),
 ),
 Expanded(
 child: Stack(
 children: [
 SingleChildScrollView(
 padding: EdgeInsets.symmetric(
 horizontal: horizontalPadding,
 vertical: isMobile ? 28 : 48,
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 _StrategyHeader(
 onBack: () => Navigator.of(context).maybePop()),
 SizedBox(height: isMobile ? 24 : 36),
 _StrategyStepPills(
 selectedIndex: 2, onStepTap: _handleStepTap),
 SizedBox(height: isMobile ? 24 : 32),
 _AdditionalInfoField(
 controller: _additionalInfoController,
 onChanged: (_) => _persistStatus(),
 ),
 SizedBox(height: isMobile ? 24 : 32),
 Align(
 alignment: Alignment.centerLeft,
 child: ConstrainedBox(
 constraints: const BoxConstraints(maxWidth: 220),
 child: DropdownButtonFormField<String>(
 value: _selectedView,
 items: const [
 DropdownMenuItem(
 value: 'Overview', child: Text('Overview')),
 DropdownMenuItem(
 value: 'Contractors',
 child: Text('Contractors')),
 DropdownMenuItem(
 value: 'Contract Specifications',
 child: Text('Contract Specifications')),
 DropdownMenuItem(
 value: 'Milestones',
 child: Text('Milestones')),
 DropdownMenuItem(
 value: 'Documents',
 child: Text('Documents')),
 ],
 onChanged: (value) => setState(
 () => _selectedView = value ?? _selectedView),
 icon: const Icon(
 Icons.keyboard_arrow_down_rounded,
 color: Color(0xFF6B7280)),
 decoration: InputDecoration(
 contentPadding: const EdgeInsets.symmetric(
 horizontal: 18, vertical: 14),
 filled: true,
 fillColor: Colors.white,
 border: OutlineInputBorder(
 borderRadius: BorderRadius.circular(14),
 borderSide: const BorderSide(
 color: Color(0xFFE5E7EB)),
 ),
 enabledBorder: OutlineInputBorder(
 borderRadius: BorderRadius.circular(14),
 borderSide: const BorderSide(
 color: Color(0xFFE5E7EB)),
 ),
 focusedBorder: OutlineInputBorder(
 borderRadius: BorderRadius.circular(14),
 borderSide: const BorderSide(
 color: Color(0xFFFFC812), width: 1.2),
 ),
 ),
 style: const TextStyle(
 fontSize: 14,
 color: Color(0xFF1F2937),
 fontWeight: FontWeight.w600),
 ),
 ),
 ),
 SizedBox(height: isMobile ? 20 : 28),
 _buildSelectedView(isMobile: isMobile),
 SizedBox(height: isMobile ? 80 : 120),
 ],
 ),
 ),
 MobileSidebarHamburger(
 sidebar: const InitiationLikeSidebar(
 activeItemLabel: 'Contract',
 ),
 ),
 const KazAiChatBubble(),
 const AdminEditToggle(),
 ],
 ),
 ),
 ],
 ),
 ),
 );
 }
}

class ContractingSummaryScreen extends StatefulWidget {
 const ContractingSummaryScreen({super.key});

 static void open(BuildContext context) {
 Navigator.of(context).push(
 MaterialPageRoute(
 settings: const RouteSettings(name: 'ContractingSummaryScreen'),
 builder: (_) => const ContractingSummaryScreen(),
 ),
 );
 }

 @override
 State<ContractingSummaryScreen> createState() =>
 _ContractingSummaryScreenState();
}

class _ContractingSummaryScreenState extends State<ContractingSummaryScreen> {
 bool _summaryLoaded = false;
 bool _isGeneratingSummary = false;
 bool _aiGeneratedSummary = false;
 List<ContractModel> _contracts = [];
 List<_SummaryTableRowData> _summaryRows = [];
 _BudgetImpactData _budgetImpact = const _BudgetImpactData();
 _ScheduleImpactData _scheduleImpact = const _ScheduleImpactData();
 List<_WarrantyRowData> _warrantyRows = [];
 List<_SummaryHighlightCardData> _highlightCards = [];

 @override
 void initState() {
 super.initState();
 WidgetsBinding.instance.addPostFrameCallback((_) => _loadSummaryData());
 }

 void _handleStepTap(int index) {
 if (index == 0) {
 _returnToStrategy();
 } else if (index == 1) {
 _openContractDetails();
 } else if (index == 2) {
 _openContractingStatus();
 }
 }

 void _returnToStrategy() {
 Navigator.of(context).popUntil(
 (route) =>
 route.settings.name == 'ContractingStrategyScreen' || route.isFirst,
 );
 }

 void _openContractDetails() {
 Navigator.of(context).push(
 MaterialPageRoute(
 settings: const RouteSettings(name: 'ContractDetailsScreen'),
 builder: (_) => const ContractDetailsScreen(),
 ),
 );
 }

 void _openContractingStatus() {
 Navigator.of(context).push(
 MaterialPageRoute(
 settings: const RouteSettings(name: 'ContractingStatusScreen'),
 builder: (_) => const ContractingStatusScreen(),
 ),
 );
 }

 Future<void> _loadSummaryData() async {
 if (_summaryLoaded) return;
 final provider = ProjectDataHelper.getProvider(context);
 final projectId = provider.projectData.projectId;
 if (projectId == null || projectId.isEmpty) return;

 try {
 _contracts = await ContractService.streamContracts(projectId).first;
 } catch (error) {
 debugPrint('Failed to load contracts for summary: $error');
 }

 try {
 final doc = await FirebaseFirestore.instance
 .collection('projects')
 .doc(projectId)
 .collection(_contractingCollection)
 .doc('summary')
 .get();
 if (doc.exists) {
 final data = doc.data() ?? {};
 final summaryRows = (data['summaryRows'] as List?)
 ?.whereType<Map>()
 .map((row) => _SummaryTableRowData.fromJson(
 Map<String, dynamic>.from(row)))
 .toList() ??
 [];
 final warrantyRows = (data['warrantyRows'] as List?)
 ?.whereType<Map>()
 .map((row) =>
 _WarrantyRowData.fromJson(Map<String, dynamic>.from(row)))
 .toList() ??
 [];
 final highlightCards = (data['highlightCards'] as List?)
 ?.whereType<Map>()
 .map((row) => _SummaryHighlightCardData.fromJson(
 Map<String, dynamic>.from(row)))
 .toList() ??
 [];
 if (!mounted) return;
 setState(() {
 _summaryRows = summaryRows;
 _budgetImpact = _BudgetImpactData.fromJson(
 data['budgetImpact'] as Map<String, dynamic>? ?? {});
 _scheduleImpact = _ScheduleImpactData.fromJson(
 data['scheduleImpact'] as Map<String, dynamic>? ?? {});
 _warrantyRows = warrantyRows;
 _highlightCards = highlightCards;
 });
 }
 _summaryLoaded = true;
 if (_summaryRows.isEmpty && _contracts.isNotEmpty) {
 _buildSummaryFromContracts();
 await _persistSummary();
 }
 } catch (error) {
 debugPrint('Failed to load contract summary: $error');
 }
 }

 void _buildSummaryFromContracts() {
 if (_contracts.isEmpty) return;
 final rows = <_SummaryTableRowData>[];
 double totalValue = 0.0;
 int maxDurationDaysWithDates = 0;
 for (final contract in _contracts) {
 final hasDates = contract.startDate != null && contract.endDate != null;
 final duration = hasDates
 ? contract.endDate!.difference(contract.startDate!).inDays
 : 0;
 if (hasDates) {
 maxDurationDaysWithDates = duration > maxDurationDaysWithDates
 ? duration
 : maxDurationDaysWithDates;
 }
 totalValue += contract.estimatedValue;
 rows.add(_SummaryTableRowData(
 contract: contract.name,
 contractor: contract.contractorName.isNotEmpty
 ? contract.contractorName
 : (contract.discipline.isNotEmpty
 ? contract.discipline
 : (contract.createdByName.isNotEmpty
 ? contract.createdByName
 : 'TBD')),
 method: '${contract.contractType} / ${contract.paymentType}',
 estimatedValue: _formatCurrency(contract.estimatedValue),
 duration: hasDates ? '${duration < 0 ? 0 : duration} days' : 'TBD',
 statusLabel: contract.status.isNotEmpty ? contract.status : 'Pending',
 ));
 }
 rows.add(_SummaryTableRowData(
 contract: 'Total',
 contractor: '',
 method: '',
 estimatedValue: _formatCurrency(totalValue),
 duration: maxDurationDaysWithDates > 0
 ? '${maxDurationDaysWithDates < 0 ? 0 : maxDurationDaysWithDates} days'
 : 'TBD',
 isTotals: true,
 ));
 _summaryRows = rows;

 _budgetImpact = _BudgetImpactData(
 headline:
 'The total contract value of ${_formatCurrency(totalValue)} has been added to the project cost estimate.',
 originalBudget: 'TBD',
 currentEstimate: _formatCurrency(totalValue),
 variance: 'TBD',
 );
 final datedContracts = _contracts
 .where((c) => c.startDate != null && c.endDate != null)
 .toList();
 DateTime? earliest;
 DateTime? latest;
 if (datedContracts.isNotEmpty) {
 earliest = datedContracts
 .map((c) => c.startDate!)
 .reduce((a, b) => a.isBefore(b) ? a : b);
 latest = datedContracts
 .map((c) => c.endDate!)
 .reduce((a, b) => a.isAfter(b) ? a : b);
 }
 _scheduleImpact = _ScheduleImpactData(
 summary:
 'Contract durations have been incorporated into the project schedule. The longest contract duration informs the critical path.',
 projectStart: _formatShortDate(earliest),
 contractingFinish: _formatShortDate(latest),
 totalDuration: (earliest != null && latest != null)
 ? '${latest.difference(earliest).inDays} days'
 : 'TBD',
 );
 _warrantyRows = _contracts
 .map((contract) => _WarrantyRowData(
 contract: contract.name,
 warrantyPeriod: 'TBD',
 supportType: 'TBD',
 contactInformation: contract.createdByEmail.isNotEmpty
 ? contract.createdByEmail
 : 'TBD',
 documentLabel: 'View',
 ))
 .toList();
 _highlightCards = _buildHighlightsFromContracts(totalValue);
 }

 List<_SummaryHighlightCardData> _buildHighlightsFromContracts(
 double totalValue) {
 final total = _contracts.length;
 final completed = _contracts
 .where((c) => c.status.toLowerCase().contains('complete'))
 .length;
 final inProgress = _contracts
 .where((c) => c.status.toLowerCase().contains('progress'))
 .length;
 return [
 _SummaryHighlightCardData(
 title: 'Contract Summary',
 items: [
 '$total Contracts Planned',
 '$inProgress Contracts In-Progress',
 '$completed Contracts Completed',
 ],
 ),
 _SummaryHighlightCardData(
 title: 'Timeline Status',
 items: [
 '${total - completed} Contracts Active',
 '$completed Contracts Closed',
 'Next milestone in review',
 ],
 ),
 _SummaryHighlightCardData(
 title: 'Budget Impact',
 items: [
 '${_formatCurrency(totalValue)} Total Contract Value.',
 'Budget tracking in progress.',
 'Variance pending.',
 ],
 ),
 ];
 }

 // ignore: unused_element
 Future<void> _populateSummaryFromAi() async {
 if (_aiGeneratedSummary || _isGeneratingSummary) return;
 final projectData = ProjectDataHelper.getData(context);
 final contextText = ProjectDataHelper.buildFepContext(projectData,
 sectionLabel: 'Contracting Summary');
 if (contextText.trim().isEmpty) return;

 setState(() => _isGeneratingSummary = true);
 Map<String, List<Map<String, dynamic>>> generated = {};
 try {
 generated = await OpenAiServiceSecure().generateLaunchPhaseEntries(
 context: contextText,
 sections: const {
 'summary_rows':
 'Summary table rows (title=contract, details=contractor/method/value/duration, status=status)',
 'budget_impact': 'Budget impact stats (title=label, details=value)',
 'schedule_impact':
 'Schedule impact stats (title=label, details=value)',
 'warranty_support':
 'Warranty & support entries (title=contract, details=warranty/support/contact, status=document label)',
 'summary_highlights':
 'Summary highlights (title=card title, details=bullet list)',
 },
 itemsPerSection: 3,
 );
 } catch (error) {
 debugPrint('Summary AI call failed: $error');
 }

 if (!mounted) return;
 if (_summaryRows.isNotEmpty) {
 setState(() => _isGeneratingSummary = false);
 _aiGeneratedSummary = true;
 return;
 }

 setState(() {
 _summaryRows = _mapSummaryRows(generated['summary_rows']);
 _budgetImpact = _BudgetImpactData.fromEntries(generated['budget_impact']);
 _scheduleImpact =
 _ScheduleImpactData.fromEntries(generated['schedule_impact']);
 _warrantyRows = _mapWarrantyRows(generated['warranty_support']);
 _highlightCards = _mapHighlightCards(generated['summary_highlights']);
 _isGeneratingSummary = false;
 });
 _aiGeneratedSummary = true;
 await _persistSummary();
 }

 List<_SummaryTableRowData> _mapSummaryRows(List<Map<String, dynamic>>? raw) {
 if (raw == null) return [];
 return raw
 .map((item) => _SummaryTableRowData.fromLaunchEntry(item))
 .where((row) => row.contract.isNotEmpty)
 .toList();
 }

 List<_WarrantyRowData> _mapWarrantyRows(List<Map<String, dynamic>>? raw) {
 if (raw == null) return [];
 return raw
 .map((item) => _WarrantyRowData.fromLaunchEntry(item))
 .where((row) => row.contract.isNotEmpty)
 .toList();
 }

 List<_SummaryHighlightCardData> _mapHighlightCards(
 List<Map<String, dynamic>>? raw) {
 if (raw == null) return [];
 return raw
 .map((item) => _SummaryHighlightCardData.fromLaunchEntry(item))
 .where((card) => card.title.isNotEmpty)
 .toList();
 }

 Future<void> _persistSummary() async {
 final provider = ProjectDataHelper.getProvider(context);
 final projectId = provider.projectData.projectId;
 if (projectId == null || projectId.isEmpty) return;

 final payload = {
 'summaryRows': _summaryRows.map((row) => row.toJson()).toList(),
 'budgetImpact': _budgetImpact.toJson(),
 'scheduleImpact': _scheduleImpact.toJson(),
 'warrantyRows': _warrantyRows.map((row) => row.toJson()).toList(),
 'highlightCards': _highlightCards.map((row) => row.toJson()).toList(),
 'updatedAt': FieldValue.serverTimestamp(),
 };

 try {
 await FirebaseFirestore.instance
 .collection('projects')
 .doc(projectId)
 .collection(_contractingCollection)
 .doc('summary')
 .set(payload, SetOptions(merge: true));
 } catch (error) {
 debugPrint('Failed to save contract summary: $error');
 }
 }

 @override
 Widget build(BuildContext context) {
 final bool isMobile = AppBreakpoints.isMobile(context);
 final double horizontalPadding = isMobile ? 24 : 48;

 return Scaffold(
 backgroundColor: Colors.white,
 body: SafeArea(
 child: Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 DraggableSidebar(
 openWidth: AppBreakpoints.sidebarWidth(context),
 child: const InitiationLikeSidebar(activeItemLabel: 'Contract'),
 ),
 Expanded(
 child: Stack(
 children: [
 SingleChildScrollView(
 padding: EdgeInsets.symmetric(
 horizontal: horizontalPadding,
 vertical: isMobile ? 28 : 48,
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 _StrategyHeader(
 onBack: () => Navigator.of(context).maybePop()),
 SizedBox(height: isMobile ? 24 : 36),
 _StrategyStepPills(
 selectedIndex: 3, onStepTap: _handleStepTap),
 SizedBox(height: isMobile ? 24 : 32),
 _ContractingSummaryOverviewCard(rows: _summaryRows),
 SizedBox(height: isMobile ? 24 : 32),
 _ContractingSummaryImpactsRow(
 budgetImpact: _budgetImpact,
 scheduleImpact: _scheduleImpact,
 ),
 SizedBox(height: isMobile ? 24 : 32),
 _ContractingSummaryWarrantyCard(rows: _warrantyRows),
 SizedBox(height: isMobile ? 24 : 32),
 _ContractingSummaryHighlightsRow(
 cards: _highlightCards),
 SizedBox(height: isMobile ? 80 : 120),
 ],
 ),
 ),
 MobileSidebarHamburger(
 sidebar: const InitiationLikeSidebar(
 activeItemLabel: 'Contract',
 ),
 ),
 const KazAiChatBubble(),
 const AdminEditToggle(),
 ],
 ),
 ),
 ],
 ),
 ),
 );
 }
}

class _ContractingSummaryOverviewCard extends StatelessWidget {
 const _ContractingSummaryOverviewCard({required this.rows});

 final List<_SummaryTableRowData> rows;

 @override
 Widget build(BuildContext context) {
 return Container(
 width: double.infinity,
 padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(26),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 boxShadow: const [
 BoxShadow(
 color: Color(0x0C0F172A), blurRadius: 20, offset: Offset(0, 14))
 ],
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 const Text(
 'Contracting Summary',
 style: TextStyle(
 fontSize: 20,
 fontWeight: FontWeight.w700,
 color: Color(0xFF111827)),
 ),
 const SizedBox(height: 6),
 const Text(
 'Summary of all contracts with cost and timeline impact.',
 style: TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
 ),
 const SizedBox(height: 24),
 DecoratedBox(
 decoration: BoxDecoration(
 borderRadius: BorderRadius.circular(22),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 ),
 child: ClipRRect(
 borderRadius: BorderRadius.circular(22),
 child: Column(
 children: [
 Container(
 color: const Color(0xFFF9FAFB),
 padding: const EdgeInsets.symmetric(
 horizontal: 28, vertical: 18),
 child: Row(
 children: const [
 _SummaryTableHeaderCell(label: 'Contract', flex: 20),
 _SummaryTableHeaderCell(label: 'Contractor', flex: 20),
 _SummaryTableHeaderCell(
 label: 'Contracting Method', flex: 20),
 _SummaryTableHeaderCell(
 label: 'Estimated Value', flex: 16),
 _SummaryTableHeaderCell(label: 'Duration', flex: 14),
 _SummaryTableHeaderCell(label: 'Status', flex: 10),
 ],
 ),
 ),
 if (rows.isEmpty)
 const Padding(
 padding: EdgeInsets.all(24),
 child: _EmptyPanelMessage(
 'No contracts have been summarized yet.'),
 )
 else
 for (int i = 0; i < rows.length; i++) ...[
 _SummaryTableRow(data: rows[i]),
 if (i != rows.length - 1)
 const Divider(height: 1, color: Color(0xFFE5E7EB)),
 ],
 ],
 ),
 ),
 ),
 ],
 ),
 );
 }
}

class _SummaryTableHeaderCell extends StatelessWidget {
 const _SummaryTableHeaderCell({required this.label, required this.flex});

 final String label;
 final int flex;

 @override
 Widget build(BuildContext context) {
 return Expanded(
 flex: flex,
 child: Text(
 label,
 style: const TextStyle(
 fontSize: 12,
 fontWeight: FontWeight.w700,
 color: Color(0xFF6B7280)),
 ),
 );
 }
}

class _SummaryTableRow extends StatelessWidget {
 const _SummaryTableRow({required this.data});

 final _SummaryTableRowData data;

 @override
 Widget build(BuildContext context) {
 final TextStyle primaryStyle = TextStyle(
 fontSize: 13,
 fontWeight: data.isTotals ? FontWeight.w700 : FontWeight.w600,
 color: const Color(0xFF111827),
 );
 final TextStyle secondaryStyle = TextStyle(
 fontSize: 13,
 fontWeight: data.isTotals ? FontWeight.w600 : FontWeight.w500,
 color: data.isTotals ? const Color(0xFF111827) : const Color(0xFF4B5563),
 );

 String placeholderIfNeeded(String value) {
 if (value.isEmpty && !data.isTotals) {
 return '—';
 }
 return value;
 }

 return Container(
 color: data.isTotals ? const Color(0xFFF9FAFB) : Colors.white,
 padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
 child: Row(
 crossAxisAlignment: CrossAxisAlignment.center,
 children: [
 Expanded(flex: 20, child: Text(data.contract, style: primaryStyle)),
 Expanded(
 flex: 20,
 child: Text(placeholderIfNeeded(data.contractor),
 style: secondaryStyle)),
 Expanded(
 flex: 20,
 child: Text(placeholderIfNeeded(data.method),
 style: secondaryStyle)),
 Expanded(
 flex: 16,
 child: Text(data.estimatedValue, style: secondaryStyle)),
 Expanded(flex: 14, child: Text(data.duration, style: secondaryStyle)),
 Expanded(
 flex: 10,
 child: data.statusLabel != null
 ? Align(
 alignment: Alignment.centerLeft,
 child: _ContractStatusChip(
 label: data.statusLabel!,
 color: data.statusColor,
 ),
 )
 : const SizedBox.shrink(),
 ),
 ],
 ),
 );
 }
}

class _SummaryTableRowData {
 _SummaryTableRowData({
 required this.contract,
 required this.contractor,
 required this.method,
 required this.estimatedValue,
 required this.duration,
 this.statusLabel,
 this.isTotals = false,
 });

 final String contract;
 final String contractor;
 final String method;
 final String estimatedValue;
 final String duration;
 final String? statusLabel;
 final bool isTotals;

 Color get statusColor => _statusColorFor(statusLabel ?? '');

 factory _SummaryTableRowData.fromJson(Map<String, dynamic> json) {
 return _SummaryTableRowData(
 contract: (json['contract'] ?? '').toString(),
 contractor: (json['contractor'] ?? '').toString(),
 method: (json['method'] ?? '').toString(),
 estimatedValue: (json['estimatedValue'] ?? '').toString(),
 duration: (json['duration'] ?? '').toString(),
 statusLabel: (json['statusLabel'] ?? '').toString(),
 isTotals: json['isTotals'] == true,
 );
 }

 factory _SummaryTableRowData.fromLaunchEntry(Map<String, dynamic> json) {
 final title = (json['title'] ?? '').toString().trim();
 final details = (json['details'] ?? '').toString().trim();
 final status = (json['status'] ?? '').toString().trim();
 final parts = details.split('|').map((part) => part.trim()).toList();
 return _SummaryTableRowData(
 contract: title,
 contractor: parts.isNotEmpty ? parts[0] : 'TBD',
 method: parts.length > 1 ? parts[1] : 'TBD',
 estimatedValue: parts.length > 2 ? parts[2] : 'TBD',
 duration: parts.length > 3 ? parts[3] : 'TBD',
 statusLabel: status.isEmpty ? 'Pending' : status,
 );
 }

 Map<String, dynamic> toJson() => {
 'contract': contract,
 'contractor': contractor,
 'method': method,
 'estimatedValue': estimatedValue,
 'duration': duration,
 'statusLabel': statusLabel,
 'isTotals': isTotals,
 };
}

class _ContractingSummaryImpactsRow extends StatelessWidget {
 const _ContractingSummaryImpactsRow({
 required this.budgetImpact,
 required this.scheduleImpact,
 });

 final _BudgetImpactData budgetImpact;
 final _ScheduleImpactData scheduleImpact;

 @override
 Widget build(BuildContext context) {
 return LayoutBuilder(
 builder: (context, constraints) {
 if (constraints.maxWidth < 960) {
 return Column(
 crossAxisAlignment: CrossAxisAlignment.stretch,
 children: [
 _ContractingSummaryBudgetImpactCard(data: budgetImpact),
 const SizedBox(height: 24),
 _ContractingSummaryScheduleImpactCard(data: scheduleImpact),
 ],
 );
 }
 return Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Expanded(
 child: _ContractingSummaryBudgetImpactCard(data: budgetImpact)),
 const SizedBox(width: 24),
 Expanded(
 child: _ContractingSummaryScheduleImpactCard(
 data: scheduleImpact)),
 ],
 );
 },
 );
 }
}

class _ContractingSummaryBudgetImpactCard extends StatelessWidget {
 const _ContractingSummaryBudgetImpactCard({required this.data});

 final _BudgetImpactData data;

 @override
 Widget build(BuildContext context) {
 return Container(
 padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 26),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(24),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 boxShadow: const [
 BoxShadow(
 color: Color(0x0C0F172A), blurRadius: 18, offset: Offset(0, 12))
 ],
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 const Text('Budget Impact',
 style: TextStyle(
 fontSize: 16,
 fontWeight: FontWeight.w700,
 color: Color(0xFF111827))),
 const SizedBox(height: 14),
 Text(
 data.headline,
 style: const TextStyle(
 fontSize: 13, height: 1.6, color: Color(0xFF4B5563)),
 ),
 const SizedBox(height: 18),
 _ImpactStatRow(label: 'Original Budget', value: data.originalBudget),
 const SizedBox(height: 10),
 _ImpactStatRow(
 label: 'Current Estimate', value: data.currentEstimate),
 const SizedBox(height: 10),
 _ImpactStatRow(
 label: 'Variance',
 value: data.variance,
 valueColor: data.varianceColor,
 ),
 const SizedBox(height: 18),
 TextButton(
 onPressed: () {},
 style: TextButton.styleFrom(
 foregroundColor: const Color(0xFFFFC812),
 padding: EdgeInsets.zero,
 minimumSize: const Size(0, 0),
 textStyle:
 const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
 alignment: Alignment.centerLeft,
 ),
 child: const Text('View Cost Estimates'),
 ),
 ],
 ),
 );
 }
}

class _ContractingSummaryScheduleImpactCard extends StatelessWidget {
 const _ContractingSummaryScheduleImpactCard({required this.data});

 final _ScheduleImpactData data;

 @override
 Widget build(BuildContext context) {
 return Container(
 padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 26),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(24),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 boxShadow: const [
 BoxShadow(
 color: Color(0x0C0F172A), blurRadius: 18, offset: Offset(0, 12))
 ],
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 const Text('Schedule Impact',
 style: TextStyle(
 fontSize: 16,
 fontWeight: FontWeight.w700,
 color: Color(0xFF111827))),
 const SizedBox(height: 14),
 Text(
 data.summary,
 style: const TextStyle(
 fontSize: 13, height: 1.6, color: Color(0xFF4B5563)),
 ),
 const SizedBox(height: 18),
 _ImpactStatRow(label: 'Project Start', value: data.projectStart),
 const SizedBox(height: 10),
 _ImpactStatRow(
 label: 'Contracting Finish', value: data.contractingFinish),
 const SizedBox(height: 10),
 _ImpactStatRow(label: 'Total Duration', value: data.totalDuration),
 const SizedBox(height: 18),
 TextButton(
 onPressed: () {},
 style: TextButton.styleFrom(
 foregroundColor: const Color(0xFFFFC812),
 padding: EdgeInsets.zero,
 minimumSize: const Size(0, 0),
 textStyle:
 const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
 alignment: Alignment.centerLeft,
 ),
 child: const Text('View Project Schedule'),
 ),
 ],
 ),
 );
 }
}

class _ImpactStatRow extends StatelessWidget {
 const _ImpactStatRow(
 {required this.label, required this.value, this.valueColor});

 final String label;
 final String value;
 final Color? valueColor;

 @override
 Widget build(BuildContext context) {
 return Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Expanded(
 flex: 2,
 child: Text(label,
 style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
 ),
 Expanded(
 flex: 3,
 child: Text(
 value,
 style: TextStyle(
 fontSize: 13,
 fontWeight: FontWeight.w600,
 color: valueColor ?? const Color(0xFF111827)),
 textAlign: TextAlign.right,
 ),
 ),
 ],
 );
 }
}

class _BudgetImpactData {
 const _BudgetImpactData({
 this.headline = 'Budget impact details pending.',
 this.originalBudget = 'TBD',
 this.currentEstimate = 'TBD',
 this.variance = 'TBD',
 this.varianceColor = const Color(0xFFDC2626),
 });

 final String headline;
 final String originalBudget;
 final String currentEstimate;
 final String variance;
 final Color varianceColor;

 factory _BudgetImpactData.fromJson(Map<String, dynamic> json) {
 return _BudgetImpactData(
 headline:
 (json['headline'] ?? 'Budget impact details pending.').toString(),
 originalBudget: (json['originalBudget'] ?? 'TBD').toString(),
 currentEstimate: (json['currentEstimate'] ?? 'TBD').toString(),
 variance: (json['variance'] ?? 'TBD').toString(),
 varianceColor: Color((json['varianceColor'] ?? 0xFFDC2626) as int),
 );
 }

 factory _BudgetImpactData.fromEntries(List<Map<String, dynamic>>? raw) {
 if (raw == null || raw.isEmpty) return const _BudgetImpactData();
 String original = 'TBD';
 String current = 'TBD';
 String variance = 'TBD';
 for (final entry in raw) {
 final label = (entry['title'] ?? '').toString().toLowerCase();
 final value = (entry['details'] ?? '').toString();
 if (label.contains('original')) {
 original = value;
 } else if (label.contains('current')) {
 current = value;
 } else if (label.contains('variance')) {
 variance = value;
 }
 }
 return _BudgetImpactData(
 headline:
 raw.first['details']?.toString() ?? 'Budget impact details pending.',
 originalBudget: original,
 currentEstimate: current,
 variance: variance,
 );
 }

 Map<String, dynamic> toJson() => {
 'headline': headline,
 'originalBudget': originalBudget,
 'currentEstimate': currentEstimate,
 'variance': variance,
 'varianceColor': varianceColor.toARGB32(),
 };
}

class _ScheduleImpactData {
 const _ScheduleImpactData({
 this.summary = 'Schedule impact details pending.',
 this.projectStart = 'TBD',
 this.contractingFinish = 'TBD',
 this.totalDuration = 'TBD',
 });

 final String summary;
 final String projectStart;
 final String contractingFinish;
 final String totalDuration;

 factory _ScheduleImpactData.fromJson(Map<String, dynamic> json) {
 return _ScheduleImpactData(
 summary:
 (json['summary'] ?? 'Schedule impact details pending.').toString(),
 projectStart: (json['projectStart'] ?? 'TBD').toString(),
 contractingFinish: (json['contractingFinish'] ?? 'TBD').toString(),
 totalDuration: (json['totalDuration'] ?? 'TBD').toString(),
 );
 }

 factory _ScheduleImpactData.fromEntries(List<Map<String, dynamic>>? raw) {
 if (raw == null || raw.isEmpty) return const _ScheduleImpactData();
 String start = 'TBD';
 String finish = 'TBD';
 String duration = 'TBD';
 for (final entry in raw) {
 final label = (entry['title'] ?? '').toString().toLowerCase();
 final value = (entry['details'] ?? '').toString();
 if (label.contains('start')) {
 start = value;
 } else if (label.contains('finish')) {
 finish = value;
 } else if (label.contains('duration')) {
 duration = value;
 }
 }
 return _ScheduleImpactData(
 summary: raw.first['details']?.toString() ??
 'Schedule impact details pending.',
 projectStart: start,
 contractingFinish: finish,
 totalDuration: duration,
 );
 }

 Map<String, dynamic> toJson() => {
 'summary': summary,
 'projectStart': projectStart,
 'contractingFinish': contractingFinish,
 'totalDuration': totalDuration,
 };
}

class _ContractingSummaryWarrantyCard extends StatelessWidget {
 const _ContractingSummaryWarrantyCard({required this.rows});

 final List<_WarrantyRowData> rows;

 @override
 Widget build(BuildContext context) {
 return Container(
 width: double.infinity,
 padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(26),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 boxShadow: const [
 BoxShadow(
 color: Color(0x0C0F172A), blurRadius: 18, offset: Offset(0, 12))
 ],
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 const Text(
 'Warranty & Support Documentation',
 style: TextStyle(
 fontSize: 16,
 fontWeight: FontWeight.w700,
 color: Color(0xFF111827)),
 ),
 const SizedBox(height: 6),
 const Text(
 'Keep track of warranties, maintenance agreements, and support contacts for all contracts.',
 style: TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
 ),
 const SizedBox(height: 24),
 DecoratedBox(
 decoration: BoxDecoration(
 borderRadius: BorderRadius.circular(22),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 ),
 child: ClipRRect(
 borderRadius: BorderRadius.circular(22),
 child: Column(
 children: [
 Container(
 color: const Color(0xFFF9FAFB),
 padding: const EdgeInsets.symmetric(
 horizontal: 28, vertical: 18),
 child: Row(
 children: const [
 _WarrantyTableHeaderCell(label: 'Contract', flex: 24),
 _WarrantyTableHeaderCell(
 label: 'Warranty Period', flex: 18),
 _WarrantyTableHeaderCell(
 label: 'Support Type', flex: 18),
 _WarrantyTableHeaderCell(
 label: 'Contact Information', flex: 24),
 _WarrantyTableHeaderCell(label: 'Documents', flex: 16),
 ],
 ),
 ),
 if (rows.isEmpty)
 const Padding(
 padding: EdgeInsets.all(24),
 child: _EmptyPanelMessage(
 'No warranty or support records yet.'),
 )
 else
 for (int i = 0; i < rows.length; i++) ...[
 _WarrantyTableRow(data: rows[i]),
 if (i != rows.length - 1)
 const Divider(height: 1, color: Color(0xFFE5E7EB)),
 ],
 ],
 ),
 ),
 ),
 ],
 ),
 );
 }
}

class _WarrantyTableHeaderCell extends StatelessWidget {
 const _WarrantyTableHeaderCell({required this.label, required this.flex});

 final String label;
 final int flex;

 @override
 Widget build(BuildContext context) {
 return Expanded(
 flex: flex,
 child: Text(
 label,
 style: const TextStyle(
 fontSize: 12,
 fontWeight: FontWeight.w700,
 color: Color(0xFF6B7280)),
 ),
 );
 }
}

class _WarrantyTableRow extends StatelessWidget {
 const _WarrantyTableRow({required this.data});

 final _WarrantyRowData data;

 @override
 Widget build(BuildContext context) {
 const TextStyle primaryStyle = TextStyle(
 fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF111827));
 const TextStyle secondaryStyle =
 TextStyle(fontSize: 13, color: Color(0xFF4B5563));

 return Container(
 color: Colors.white,
 padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
 child: Row(
 crossAxisAlignment: CrossAxisAlignment.center,
 children: [
 Expanded(flex: 24, child: Text(data.contract, style: primaryStyle)),
 Expanded(
 flex: 18,
 child: Text(data.warrantyPeriod, style: secondaryStyle)),
 Expanded(
 flex: 18, child: Text(data.supportType, style: secondaryStyle)),
 Expanded(
 flex: 24,
 child: Text(data.contactInformation, style: secondaryStyle)),
 Expanded(
 flex: 16,
 child: data.documentLabel != null
 ? Align(
 alignment: Alignment.centerLeft,
 child: TextButton(
 onPressed: () {},
 style: TextButton.styleFrom(
 foregroundColor: const Color(0xFFFFC812),
 padding: EdgeInsets.zero,
 minimumSize: const Size(0, 0),
 textStyle: const TextStyle(
 fontSize: 13, fontWeight: FontWeight.w600),
 ),
 child: Text(data.documentLabel!),
 ),
 )
 : const SizedBox.shrink(),
 ),
 ],
 ),
 );
 }
}

class _WarrantyRowData {
 const _WarrantyRowData({
 required this.contract,
 required this.warrantyPeriod,
 required this.supportType,
 required this.contactInformation,
 this.documentLabel,
 });

 final String contract;
 final String warrantyPeriod;
 final String supportType;
 final String contactInformation;
 final String? documentLabel;

 factory _WarrantyRowData.fromJson(Map<String, dynamic> json) {
 return _WarrantyRowData(
 contract: (json['contract'] ?? '').toString(),
 warrantyPeriod: (json['warrantyPeriod'] ?? '').toString(),
 supportType: (json['supportType'] ?? '').toString(),
 contactInformation: (json['contactInformation'] ?? '').toString(),
 documentLabel: (json['documentLabel'] ?? '').toString(),
 );
 }

 factory _WarrantyRowData.fromLaunchEntry(Map<String, dynamic> json) {
 final title = (json['title'] ?? '').toString().trim();
 final details = (json['details'] ?? '').toString().trim();
 final parts = details.split('|').map((part) => part.trim()).toList();
 return _WarrantyRowData(
 contract: title,
 warrantyPeriod: parts.isNotEmpty ? parts[0] : 'TBD',
 supportType: parts.length > 1 ? parts[1] : 'TBD',
 contactInformation: parts.length > 2 ? parts[2] : 'TBD',
 documentLabel: (json['status'] ?? 'View').toString(),
 );
 }

 Map<String, dynamic> toJson() => {
 'contract': contract,
 'warrantyPeriod': warrantyPeriod,
 'supportType': supportType,
 'contactInformation': contactInformation,
 'documentLabel': documentLabel,
 };
}

class _ContractingSummaryHighlightsRow extends StatelessWidget {
 const _ContractingSummaryHighlightsRow({required this.cards});

 final List<_SummaryHighlightCardData> cards;

 @override
 Widget build(BuildContext context) {
 return LayoutBuilder(
 builder: (context, constraints) {
 if (cards.isEmpty) {
 return const _EmptyPanelMessage(
 'No summary highlights available yet.');
 }
 if (constraints.maxWidth < 900) {
 return Column(
 crossAxisAlignment: CrossAxisAlignment.stretch,
 children: List.generate(cards.length, (index) {
 return Padding(
 padding:
 EdgeInsets.only(bottom: index == cards.length - 1 ? 0 : 20),
 child: _SummaryHighlightCard(data: cards[index]),
 );
 }),
 );
 }
 return Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 for (int i = 0; i < cards.length; i++) ...[
 Expanded(child: _SummaryHighlightCard(data: cards[i])),
 if (i != cards.length - 1) const SizedBox(width: 20),
 ],
 ],
 );
 },
 );
 }
}

class _SummaryHighlightCard extends StatelessWidget {
 const _SummaryHighlightCard({required this.data});

 final _SummaryHighlightCardData data;

 @override
 Widget build(BuildContext context) {
 return Container(
 padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 24),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(24),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 boxShadow: const [
 BoxShadow(
 color: Color(0x0C0F172A), blurRadius: 18, offset: Offset(0, 12))
 ],
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 data.title,
 style: const TextStyle(
 fontSize: 15,
 fontWeight: FontWeight.w700,
 color: Color(0xFF111827)),
 ),
 const SizedBox(height: 16),
 for (int i = 0; i < data.items.length; i++)
 Padding(
 padding:
 EdgeInsets.only(bottom: i == data.items.length - 1 ? 0 : 12),
 child: _SummaryHighlightBullet(text: data.items[i]),
 ),
 ],
 ),
 );
 }
}

class _SummaryHighlightCardData {
 const _SummaryHighlightCardData({required this.title, required this.items});

 final String title;
 final List<String> items;

 factory _SummaryHighlightCardData.fromJson(Map<String, dynamic> json) {
 return _SummaryHighlightCardData(
 title: (json['title'] ?? '').toString(),
 items:
 (json['items'] as List?)?.map((item) => item.toString()).toList() ??
 [],
 );
 }

 factory _SummaryHighlightCardData.fromLaunchEntry(Map<String, dynamic> json) {
 final title = (json['title'] ?? '').toString().trim();
 final details = (json['details'] ?? '').toString();
 final items = details
 .split(RegExp(r'[•\n]'))
 .map((item) => item.trim())
 .where((item) => item.isNotEmpty)
 .toList();
 return _SummaryHighlightCardData(
 title: title, items: items.isEmpty ? ['Details pending.'] : items);
 }

 Map<String, dynamic> toJson() => {
 'title': title,
 'items': items,
 };
}

class _SummaryHighlightBullet extends StatelessWidget {
 const _SummaryHighlightBullet({required this.text});

 final String text;

 @override
 Widget build(BuildContext context) {
 return Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 const Padding(
 padding: EdgeInsets.only(top: 6),
 child: Icon(Icons.fiber_manual_record,
 size: 8, color: Color(0xFFFFC812)),
 ),
 const SizedBox(width: 10),
 Expanded(
 child: Text(
 text,
 style: const TextStyle(
 fontSize: 13, color: Color(0xFF4B5563), height: 1.5),
 ),
 ),
 ],
 );
 }
}

class _ContractStatusOverview extends StatelessWidget {
 const _ContractStatusOverview({
 required this.isMobile,
 required this.months,
 required this.rows,
 required this.progress,
 required this.summaryData,
 required this.recentActivity,
 });

 final bool isMobile;
 final List<String> months;
 final List<_StatusTimelineRowData> rows;
 final double progress;
 final _StatusSummaryData summaryData;
 final List<_RecentActivityData> recentActivity;

 @override
 Widget build(BuildContext context) {
 if (isMobile) {
 return Column(
 crossAxisAlignment: CrossAxisAlignment.stretch,
 children: [
 _ContractStatusTimelineCard(
 months: months, rows: rows, progress: progress),
 const SizedBox(height: 24),
 _ContractStatusSummaryCard(summaryData: summaryData),
 const SizedBox(height: 20),
 _ContractStatusRecentActivityCard(activities: recentActivity),
 ],
 );
 }

 return LayoutBuilder(
 builder: (context, constraints) {
 if (constraints.maxWidth < 720) {
 return Column(
 crossAxisAlignment: CrossAxisAlignment.stretch,
 children: [
 _ContractStatusTimelineCard(
 months: months, rows: rows, progress: progress),
 const SizedBox(height: 24),
 _ContractStatusSummaryCard(summaryData: summaryData),
 const SizedBox(height: 20),
 _ContractStatusRecentActivityCard(activities: recentActivity),
 ],
 );
 }

 final double rightColumnWidth = 300;
 final double spacing = 24;
 final double timelineWidth =
 constraints.maxWidth - rightColumnWidth - spacing;

 return Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 SizedBox(
 width: timelineWidth,
 child: _ContractStatusTimelineCard(
 months: months, rows: rows, progress: progress)),
 SizedBox(width: spacing),
 SizedBox(
 width: rightColumnWidth,
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.stretch,
 children: [
 _ContractStatusSummaryCard(summaryData: summaryData),
 const SizedBox(height: 20),
 _ContractStatusRecentActivityCard(activities: recentActivity),
 ],
 ),
 ),
 ],
 );
 },
 );
 }
}

class _ContractStatusTimelineCard extends StatelessWidget {
 const _ContractStatusTimelineCard({
 required this.months,
 required this.rows,
 required this.progress,
 });

 final List<String> months;
 final List<_StatusTimelineRowData> rows;
 final double progress;

 @override
 Widget build(BuildContext context) {
 final displayMonths = months.isNotEmpty
 ? months
 : const ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun'];
 return Container(
 padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 28),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(26),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 boxShadow: const [
 BoxShadow(
 color: Color(0x0C0F172A), blurRadius: 20, offset: Offset(0, 16))
 ],
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 mainAxisAlignment: MainAxisAlignment.spaceBetween,
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: const [
 Text('Contract Status Timeline',
 style: TextStyle(
 fontSize: 18,
 fontWeight: FontWeight.w700,
 color: Color(0xFF111827))),
 SizedBox(height: 6),
 Text('Complete | In Progress | Not Started | Behind Schedule',
 style: TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
 ],
 ),
 const _TimelineLegend(),
 ],
 ),
 const SizedBox(height: 22),
 _TimelineHeader(months: displayMonths),
 const Divider(height: 32, color: Color(0xFFE5E7EB)),
 if (rows.isEmpty)
 const _EmptyPanelMessage('No timeline data available yet.')
 else
 for (int i = 0; i < rows.length; i++) ...[
 _TimelineRow(row: rows[i]),
 if (i != rows.length - 1) const SizedBox(height: 18),
 ],
 const SizedBox(height: 28),
 const Divider(height: 24, color: Color(0xFFE5E7EB)),
 const SizedBox(height: 12),
 const Text('Overall Progress',
 style: TextStyle(
 fontSize: 13,
 fontWeight: FontWeight.w600,
 color: Color(0xFF6B7280))),
 const SizedBox(height: 10),
 ClipRRect(
 borderRadius: BorderRadius.circular(999),
 child: LinearProgressIndicator(
 value: progress.clamp(0.0, 1.0),
 minHeight: 10,
 backgroundColor: const Color(0xFFF3F4F6),
 valueColor:
 const AlwaysStoppedAnimation<Color>(Color(0xFFFFC233)),
 ),
 ),
 const SizedBox(height: 10),
 Text('${(progress * 100).round()}% complete',
 style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF))),
 ],
 ),
 );
 }
}

class _TimelineHeader extends StatelessWidget {
 const _TimelineHeader({required this.months});

 final List<String> months;

 @override
 Widget build(BuildContext context) {
 return Padding(
 padding: const EdgeInsets.only(left: 4),
 child: Row(
 children: [
 const Expanded(
 flex: 32,
 child: Text('Contract',
 style: TextStyle(
 fontSize: 13,
 fontWeight: FontWeight.w600,
 color: Color(0xFF6B7280))),
 ),
 for (final month in months)
 Expanded(
 flex: 12,
 child: Text(month,
 style: const TextStyle(
 fontSize: 12,
 fontWeight: FontWeight.w600,
 color: Color(0xFF9CA3AF)),
 textAlign: TextAlign.center),
 ),
 ],
 ),
 );
 }
}

class _TimelineRow extends StatelessWidget {
 const _TimelineRow({required this.row});

 final _StatusTimelineRowData row;

 Color _colorForStatus(_TimelineStatusState status) {
 switch (status) {
 case _TimelineStatusState.complete:
 return const Color(0xFF22C55E);
 case _TimelineStatusState.inProgress:
 return const Color(0xFFFFC812);
 case _TimelineStatusState.behindSchedule:
 return const Color(0xFFF59E0B);
 case _TimelineStatusState.notStarted:
 return const Color(0xFFE5E7EB);
 }
 }

 @override
 Widget build(BuildContext context) {
 return Padding(
 padding: const EdgeInsets.only(left: 4),
 child: Row(
 crossAxisAlignment: CrossAxisAlignment.center,
 children: [
 Expanded(
 flex: 32,
 child: Text(
 row.label,
 style: const TextStyle(
 fontSize: 13,
 fontWeight: FontWeight.w600,
 color: Color(0xFF111827)),
 ),
 ),
 for (final cell in row.cells)
 Expanded(
 flex: 12,
 child: Padding(
 padding: const EdgeInsets.symmetric(horizontal: 4),
 child: Container(
 height: 18,
 decoration: BoxDecoration(
 color: _colorForStatus(cell.status),
 borderRadius: BorderRadius.circular(6),
 ),
 ),
 ),
 ),
 ],
 ),
 );
 }
}

class _TimelineLegend extends StatelessWidget {
 const _TimelineLegend();

 static const List<_TimelineLegendItem> _items = [
 _TimelineLegendItem(label: 'Complete', color: Color(0xFF22C55E)),
 _TimelineLegendItem(label: 'In Progress', color: Color(0xFFFFC812)),
 _TimelineLegendItem(label: 'Not Started', color: Color(0xFFE5E7EB)),
 _TimelineLegendItem(label: 'Behind Schedule', color: Color(0xFFF59E0B)),
 ];

 @override
 Widget build(BuildContext context) {
 return Wrap(
 spacing: 12,
 runSpacing: 8,
 children: _items
 .map(
 (item) => Row(
 mainAxisSize: MainAxisSize.min,
 children: [
 Container(
 width: 10,
 height: 10,
 decoration: BoxDecoration(
 color: item.color, shape: BoxShape.circle)),
 const SizedBox(width: 6),
 Text(item.label,
 style: const TextStyle(
 fontSize: 12, color: Color(0xFF6B7280))),
 ],
 ),
 )
 .toList(),
 );
 }
}

class _ContractStatusSummaryCard extends StatelessWidget {
 const _ContractStatusSummaryCard({required this.summaryData});

 final _StatusSummaryData summaryData;

 @override
 Widget build(BuildContext context) {
 return Container(
 padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 26),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(24),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 boxShadow: const [
 BoxShadow(
 color: Color(0x0C0F172A), blurRadius: 20, offset: Offset(0, 14))
 ],
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 const Text('Contract Summary',
 style: TextStyle(
 fontSize: 16,
 fontWeight: FontWeight.w700,
 color: Color(0xFF111827))),
 const SizedBox(height: 18),
 const Text('Average Bid Value',
 style: TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
 const SizedBox(height: 6),
 Text(
 summaryData.averageBidValue,
 style: const TextStyle(
 fontSize: 26,
 fontWeight: FontWeight.w700,
 color: Color(0xFF111827)),
 ),
 const SizedBox(height: 12),
 _SummaryStat(
 label: 'Total Contractors', value: summaryData.totalContractors),
 const SizedBox(height: 10),
 _SummaryStat(
 label: 'Milestone Progress',
 value: summaryData.milestoneProgress),
 const SizedBox(height: 16),
 Row(
 mainAxisAlignment: MainAxisAlignment.spaceBetween,
 children: [
 const Text('Status',
 style: TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
 _StatusPill(
 label: summaryData.statusLabel,
 color: _statusColorFor(summaryData.statusLabel)),
 ],
 ),
 ],
 ),
 );
 }
}

class _SummaryStat extends StatelessWidget {
 const _SummaryStat({required this.label, required this.value});

 final String label;
 final String value;

 @override
 Widget build(BuildContext context) {
 return Row(
 mainAxisAlignment: MainAxisAlignment.spaceBetween,
 children: [
 Text(label,
 style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
 Text(value,
 style: const TextStyle(
 fontSize: 13,
 fontWeight: FontWeight.w600,
 color: Color(0xFF1F2937))),
 ],
 );
 }
}

class _StatusSummaryData {
 const _StatusSummaryData({
 this.averageBidValue = 'TBD',
 this.totalContractors = '0',
 this.milestoneProgress = '0/0',
 this.statusLabel = 'Pending',
 });

 final String averageBidValue;
 final String totalContractors;
 final String milestoneProgress;
 final String statusLabel;

 factory _StatusSummaryData.fromJson(Map<String, dynamic> json) {
 return _StatusSummaryData(
 averageBidValue: (json['averageBidValue'] ?? 'TBD').toString(),
 totalContractors: (json['totalContractors'] ?? '0').toString(),
 milestoneProgress: (json['milestoneProgress'] ?? '0/0').toString(),
 statusLabel: (json['statusLabel'] ?? 'Pending').toString(),
 );
 }

 factory _StatusSummaryData.fromEntries(List<Map<String, dynamic>>? raw) {
 if (raw == null || raw.isEmpty) return const _StatusSummaryData();
 String average = 'TBD';
 String total = '0';
 String progress = '0/0';
 String status = 'Pending';
 for (final entry in raw) {
 final label = (entry['title'] ?? '').toString().toLowerCase();
 final value = (entry['details'] ?? '').toString();
 if (label.contains('average')) {
 average = value;
 } else if (label.contains('contractor')) {
 total = value;
 } else if (label.contains('milestone')) {
 progress = value;
 } else if (label.contains('status')) {
 status = value;
 }
 }
 return _StatusSummaryData(
 averageBidValue: average,
 totalContractors: total,
 milestoneProgress: progress,
 statusLabel: status.isEmpty ? 'Pending' : status,
 );
 }

 Map<String, dynamic> toJson() => {
 'averageBidValue': averageBidValue,
 'totalContractors': totalContractors,
 'milestoneProgress': milestoneProgress,
 'statusLabel': statusLabel,
 };
}

class _ContractStatusRecentActivityCard extends StatelessWidget {
 const _ContractStatusRecentActivityCard({required this.activities});

 final List<_RecentActivityData> activities;

 @override
 Widget build(BuildContext context) {
 return Container(
 padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(24),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 boxShadow: const [
 BoxShadow(
 color: Color(0x0C0F172A), blurRadius: 20, offset: Offset(0, 14))
 ],
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 const Text('Recent Activity',
 style: TextStyle(
 fontSize: 16,
 fontWeight: FontWeight.w700,
 color: Color(0xFF111827))),
 const SizedBox(height: 18),
 if (activities.isEmpty)
 const _EmptyPanelMessage('No recent contract activity yet.')
 else
 ...activities.map(
 (activity) => Padding(
 padding: const EdgeInsets.only(bottom: 12),
 child: Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 const Padding(
 padding: EdgeInsets.only(top: 5),
 child: Icon(Icons.fiber_manual_record,
 size: 8, color: Color(0xFFFFC812)),
 ),
 const SizedBox(width: 10),
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(activity.description,
 style: const TextStyle(
 fontSize: 13, color: Color(0xFF1F2937))),
 const SizedBox(height: 4),
 Text(activity.date,
 style: const TextStyle(
 fontSize: 12, color: Color(0xFF9CA3AF))),
 ],
 ),
 ),
 ],
 ),
 ),
 ),
 ],
 ),
 );
 }
}

class _ContractorsDirectorySection extends StatelessWidget {
 const _ContractorsDirectorySection({
 required this.isMobile,
 required this.selectedStatus,
 required this.onStatusChanged,
 required this.rows,
 required this.contractTitle,
 });

 final bool isMobile;
 final String selectedStatus;
 final ValueChanged<String> onStatusChanged;
 final List<_ContractorRowData> rows;
 final String contractTitle;

 static const List<String> _statusFilters = [
 'All Status',
 'Bid Submitted',
 'Under Review',
 'Shortlisted',
 'Awarded',
 ];

 @override
 Widget build(BuildContext context) {
 return Container(
 width: double.infinity,
 padding: EdgeInsets.symmetric(
 horizontal: isMobile ? 20 : 32, vertical: isMobile ? 24 : 32),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(isMobile ? 24 : 28),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 boxShadow: const [
 BoxShadow(
 color: Color(0x0C0F172A), blurRadius: 22, offset: Offset(0, 14))
 ],
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 if (isMobile)
 Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 'Contractors for ${contractTitle.isNotEmpty ? contractTitle : 'selected contract'}',
 style: const TextStyle(
 fontSize: 18,
 fontWeight: FontWeight.w700,
 color: Color(0xFF111827)),
 ),
 const SizedBox(height: 12),
 const _ContractComparisonsButton(fullWidth: true),
 ],
 )
 else
 Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Expanded(
 child: Text(
 'Contractors for ${contractTitle.isNotEmpty ? contractTitle : 'selected contract'}',
 style: const TextStyle(
 fontSize: 20,
 fontWeight: FontWeight.w700,
 color: Color(0xFF111827)),
 ),
 ),
 const SizedBox(width: 16),
 const _ContractComparisonsButton(),
 ],
 ),
 SizedBox(height: isMobile ? 20 : 24),
 if (isMobile)
 Column(
 crossAxisAlignment: CrossAxisAlignment.stretch,
 children: [
 _ContractorSearchField(),
 const SizedBox(height: 12),
 _ContractorStatusDropdown(
 selectedStatus: selectedStatus, onChanged: onStatusChanged),
 ],
 )
 else
 Row(
 children: [
 const Expanded(child: _ContractorSearchField()),
 const SizedBox(width: 16),
 SizedBox(
 width: 180,
 child: _ContractorStatusDropdown(
 selectedStatus: selectedStatus,
 onChanged: onStatusChanged)),
 ],
 ),
 const SizedBox(height: 24),
 if (rows.isEmpty)
 const _EmptyPanelMessage('No contractor records available yet.')
 else
 _ContractorsTable(rows: rows, isMobile: isMobile),
 ],
 ),
 );
 }
}

class _ContractorSearchField extends StatelessWidget {
 const _ContractorSearchField();

 @override
 Widget build(BuildContext context) {
 return VoiceTextField(
 decoration: InputDecoration(
 hintText: 'Search contractors...',
 hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)),
 prefixIcon:
 const Icon(Icons.search, size: 20, color: Color(0xFF9CA3AF)),
 filled: true,
 fillColor: const Color(0xFFF3F4F6),
 contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 0),
 border: OutlineInputBorder(
 borderRadius: BorderRadius.circular(16),
 borderSide: BorderSide.none,
 ),
 enabledBorder: OutlineInputBorder(
 borderRadius: BorderRadius.circular(16),
 borderSide: BorderSide.none,
 ),
 focusedBorder: OutlineInputBorder(
 borderRadius: BorderRadius.circular(16),
 borderSide: const BorderSide(color: Color(0xFFFFD700), width: 1.2),
 ),
 ),
 style: const TextStyle(fontSize: 13, color: Color(0xFF1F2937)),
 );
 }
}

class _ContractorStatusDropdown extends StatelessWidget {
 const _ContractorStatusDropdown(
 {required this.selectedStatus, required this.onChanged});

 final String selectedStatus;
 final ValueChanged<String> onChanged;

 @override
 Widget build(BuildContext context) {
 return DropdownButtonFormField<String>(
 value: selectedStatus,
 items: _ContractorsDirectorySection._statusFilters
 .map((status) => DropdownMenuItem(value: status, child: Text(status)))
 .toList(),
 onChanged: (value) {
 if (value != null) {
 onChanged(value);
 }
 },
 icon: const Icon(Icons.keyboard_arrow_down_rounded,
 color: Color(0xFF6B7280)),
 decoration: InputDecoration(
 contentPadding:
 const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
 filled: true,
 fillColor: Colors.white,
 border: OutlineInputBorder(
 borderRadius: BorderRadius.circular(16),
 borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
 ),
 enabledBorder: OutlineInputBorder(
 borderRadius: BorderRadius.circular(16),
 borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
 ),
 focusedBorder: OutlineInputBorder(
 borderRadius: BorderRadius.circular(16),
 borderSide: const BorderSide(color: Color(0xFFFFD700), width: 1.2),
 ),
 ),
 style: const TextStyle(
 fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1F2937)),
 );
 }
}

class _ContractorsTable extends StatelessWidget {
 const _ContractorsTable({required this.rows, required this.isMobile});

 final List<_ContractorRowData> rows;
 final bool isMobile;

 @override
 Widget build(BuildContext context) {
 final Widget table = Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Padding(
 padding: const EdgeInsets.only(bottom: 18),
 child: Row(
 children: const [
 _ContractorsHeaderCell(label: 'CONTRACTOR', flex: 32),
 _ContractorsHeaderCell(label: 'LOCATION', flex: 18),
 _ContractorsHeaderCell(label: 'BID AMOUNT', flex: 16),
 _ContractorsHeaderCell(label: 'STATUS', flex: 16),
 _ContractorsHeaderCell(label: 'SUBMISSION DATE', flex: 14),
 _ContractorsHeaderCell(label: 'SCORE', flex: 14),
 _ContractorsHeaderCell(
 label: 'ACTIONS', flex: 12, textAlign: TextAlign.right),
 ],
 ),
 ),
 ...List.generate(rows.length, (index) {
 final _ContractorRowData data = rows[index];
 return Column(
 children: [
 _ContractorTableRow(data: data),
 if (index != rows.length - 1)
 const Divider(height: 24, color: Color(0xFFE5E7EB)),
 ],
 );
 }),
 ],
 );

 if (isMobile) {
 return SingleChildScrollView(
 scrollDirection: Axis.horizontal,
 child: ConstrainedBox(
 constraints: const BoxConstraints(minWidth: 960),
 child: table,
 ),
 );
 }

 return table;
 }
}

class _ContractorTableRow extends StatelessWidget {
 const _ContractorTableRow({required this.data});

 final _ContractorRowData data;

 @override
 Widget build(BuildContext context) {
 return Padding(
 padding: const EdgeInsets.symmetric(vertical: 14),
 child: Row(
 crossAxisAlignment: CrossAxisAlignment.center,
 children: [
 Expanded(
 flex: 32,
 child: Row(
 children: [
 const CircleAvatar(
 radius: 22,
 backgroundColor: Color(0xFFE5E7EB),
 child: Icon(Icons.apartment_rounded,
 size: 20, color: Color(0xFF6B7280)),
 ),
 const SizedBox(width: 12),
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(data.name,
 style: const TextStyle(
 fontSize: 14,
 fontWeight: FontWeight.w700,
 color: Color(0xFF111827))),
 const SizedBox(height: 4),
 Text(data.role,
 style: const TextStyle(
 fontSize: 12, color: Color(0xFF6B7280))),
 ],
 ),
 ),
 ],
 ),
 ),
 Expanded(
 flex: 18,
 child: Text(data.location,
 style: const TextStyle(fontSize: 13, color: Color(0xFF4B5563))),
 ),
 Expanded(
 flex: 16,
 child: Text(data.bidAmount,
 style: const TextStyle(
 fontSize: 13,
 fontWeight: FontWeight.w600,
 color: Color(0xFF111827))),
 ),
 Expanded(
 flex: 16,
 child: _ContractStatusChip(
 label: data.statusLabel, color: data.statusColor),
 ),
 Expanded(
 flex: 14,
 child: Text(data.submissionDate,
 style: const TextStyle(fontSize: 13, color: Color(0xFF4B5563))),
 ),
 Expanded(
 flex: 14,
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text('${data.score}',
 style: const TextStyle(
 fontSize: 14,
 fontWeight: FontWeight.w700,
 color: Color(0xFF111827))),
 const SizedBox(height: 6),
 ClipRRect(
 borderRadius: BorderRadius.circular(999),
 child: LinearProgressIndicator(
 value: data.score / 100,
 minHeight: 6,
 backgroundColor: const Color(0xFFF3F4F6),
 valueColor: AlwaysStoppedAnimation<Color>(data.scoreColor),
 ),
 ),
 ],
 ),
 ),
 Expanded(
 flex: 12,
 child: Align(
 alignment: Alignment.centerRight,
 child: TextButton(
 onPressed: () {},
 style: TextButton.styleFrom(
 foregroundColor: const Color(0xFFFFC812),
 padding: EdgeInsets.zero,
 minimumSize: const Size(0, 0),
 tapTargetSize: MaterialTapTargetSize.shrinkWrap,
 textStyle: const TextStyle(
 fontSize: 13, fontWeight: FontWeight.w600),
 ),
 child: const Text('View Details'),
 ),
 ),
 ),
 ],
 ),
 );
 }
}

class _ContractorsHeaderCell extends StatelessWidget {
 const _ContractorsHeaderCell(
 {required this.label,
 required this.flex,
 this.textAlign = TextAlign.left});

 final String label;
 final int flex;
 final TextAlign textAlign;

 @override
 Widget build(BuildContext context) {
 return Expanded(
 flex: flex,
 child: Text(
 label,
 style: const TextStyle(
 fontSize: 12,
 fontWeight: FontWeight.w700,
 color: Color(0xFF6B7280),
 letterSpacing: 0.3),
 textAlign: textAlign,
 ),
 );
 }
}

class _ContractStatusChip extends StatelessWidget {
 const _ContractStatusChip({required this.label, required this.color});

 final String label;
 final Color color;

 @override
 Widget build(BuildContext context) {
 return Align(
 alignment: Alignment.centerLeft,
 child: Container(
 padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
 decoration: BoxDecoration(
 color: color.withOpacity(0.14),
 borderRadius: BorderRadius.circular(999),
 ),
 child: Text(label,
 style: TextStyle(
 fontSize: 12, fontWeight: FontWeight.w600, color: color)),
 ),
 );
 }
}

class _ContractComparisonsButton extends StatelessWidget {
 const _ContractComparisonsButton({this.fullWidth = false});

 final bool fullWidth;

 @override
 Widget build(BuildContext context) {
 final Widget button = ElevatedButton(
 onPressed: () {},
 style: ElevatedButton.styleFrom(
 backgroundColor: const Color(0xFFFFC233),
 foregroundColor: const Color(0xFF111827),
 elevation: 0,
 padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 16),
 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
 textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
 ),
 child: const Text('Contract Comparisons'),
 );

 if (fullWidth) {
 return SizedBox(width: double.infinity, child: button);
 }

 return button;
 }
}

class _ContractorRowData {
 _ContractorRowData({
 required this.name,
 required this.role,
 required this.location,
 required this.bidAmount,
 required this.statusLabel,
 required this.submissionDate,
 required this.score,
 });

 final String name;
 final String role;
 final String location;
 final String bidAmount;
 final String statusLabel;
 final String submissionDate;
 final int score;

 Color get statusColor => _statusColorFor(statusLabel);

 Color get scoreColor {
 if (score >= 90) return const Color(0xFF22C55E);
 if (score >= 80) return const Color(0xFFF59E0B);
 return const Color(0xFFEF4444);
 }

 factory _ContractorRowData.fromJson(Map<String, dynamic> json) {
 return _ContractorRowData(
 name: (json['name'] ?? '').toString(),
 role: (json['role'] ?? '').toString(),
 location: (json['location'] ?? '').toString(),
 bidAmount: (json['bidAmount'] ?? '').toString(),
 statusLabel: (json['statusLabel'] ?? '').toString(),
 submissionDate: (json['submissionDate'] ?? '').toString(),
 score: (json['score'] ?? 0) is num ? (json['score'] as num).toInt() : 0,
 );
 }

 factory _ContractorRowData.fromLaunchEntry(Map<String, dynamic> json) {
 final title = (json['title'] ?? '').toString().trim();
 final details = (json['details'] ?? '').toString().trim();
 final status = (json['status'] ?? '').toString().trim();
 final parts = details.split('|').map((part) => part.trim()).toList();
 final role = parts.isNotEmpty ? parts[0] : 'Contractor';
 final location = parts.length > 1 ? parts[1] : 'Remote';
 final bidAmount = parts.length > 2 ? parts[2] : 'TBD';
 final score = status.toLowerCase().contains('award')
 ? 94
 : status.toLowerCase().contains('short')
 ? 88
 : status.toLowerCase().contains('review')
 ? 82
 : 76;
 return _ContractorRowData(
 name: title,
 role: role,
 location: location,
 bidAmount: bidAmount,
 statusLabel: status.isEmpty ? 'Under Review' : status,
 submissionDate: _formatShortDate(DateTime.now()),
 score: score,
 );
 }

 Map<String, dynamic> toJson() => {
 'name': name,
 'role': role,
 'location': location,
 'bidAmount': bidAmount,
 'statusLabel': statusLabel,
 'submissionDate': submissionDate,
 'score': score,
 };
}

class _StatusViewPlaceholder extends StatelessWidget {
 const _StatusViewPlaceholder({required this.label});

 final String label;

 @override
 Widget build(BuildContext context) {
 return Container(
 width: double.infinity,
 padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(26),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 boxShadow: const [
 BoxShadow(
 color: Color(0x0C0F172A), blurRadius: 18, offset: Offset(0, 12))
 ],
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(label,
 style: const TextStyle(
 fontSize: 18,
 fontWeight: FontWeight.w700,
 color: Color(0xFF111827))),
 const SizedBox(height: 12),
 const Text(
 'Content for this section is coming soon. We are keeping navigation consistent while designs finalize.',
 style:
 TextStyle(fontSize: 13, color: Color(0xFF6B7280), height: 1.5),
 ),
 ],
 ),
 );
 }
}

class _ContractStatusMilestonesCard extends StatelessWidget {
 const _ContractStatusMilestonesCard({required this.milestones});

 final List<_MilestoneEntry> milestones;

 @override
 Widget build(BuildContext context) {
 return Container(
 width: double.infinity,
 padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 26),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(26),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 boxShadow: const [
 BoxShadow(
 color: Color(0x0C0F172A), blurRadius: 18, offset: Offset(0, 14))
 ],
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 const Text('Key Milestone Dates',
 style: TextStyle(
 fontSize: 16,
 fontWeight: FontWeight.w700,
 color: Color(0xFF111827))),
 const SizedBox(height: 20),
 if (milestones.isEmpty)
 const _EmptyPanelMessage('No milestone dates set yet.')
 else
 ...milestones.map(
 (entry) => Padding(
 padding: const EdgeInsets.only(bottom: 16),
 child: Row(
 children: [
 Expanded(
 child: Text(entry.label,
 style: const TextStyle(
 fontSize: 13, color: Color(0xFF4B5563))),
 ),
 Row(
 children: [
 Container(
 width: 10,
 height: 10,
 decoration: BoxDecoration(
 color: entry.statusColor,
 shape: BoxShape.circle)),
 const SizedBox(width: 10),
 Text(entry.date,
 style: const TextStyle(
 fontSize: 13,
 fontWeight: FontWeight.w600,
 color: Color(0xFF111827))),
 ],
 ),
 ],
 ),
 ),
 ),
 ],
 ),
 );
 }
}

class _ContractExecutionSection extends StatelessWidget {
 const _ContractExecutionSection({
 required this.selectedContract,
 required this.onContractChanged,
 required this.steps,
 required this.contractOptions,
 });

 final String selectedContract;
 final ValueChanged<String> onContractChanged;
 final List<_ExecutionStepData> steps;
 final List<String> contractOptions;

 @override
 Widget build(BuildContext context) {
 final availableContracts =
 contractOptions.isNotEmpty ? contractOptions : [selectedContract];
 return Container(
 width: double.infinity,
 padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 28),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(26),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 boxShadow: const [
 BoxShadow(
 color: Color(0x0C0F172A), blurRadius: 18, offset: Offset(0, 14))
 ],
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 mainAxisAlignment: MainAxisAlignment.spaceBetween,
 crossAxisAlignment: CrossAxisAlignment.center,
 children: [
 const Text('Contract Execution',
 style: TextStyle(
 fontSize: 16,
 fontWeight: FontWeight.w700,
 color: Color(0xFF111827))),
 ConstrainedBox(
 constraints: const BoxConstraints(maxWidth: 300),
 child: DropdownButtonFormField<String>(
 value: selectedContract,
 onChanged: (value) =>
 onContractChanged(value ?? selectedContract),
 items: availableContracts
 .map((contract) => DropdownMenuItem(
 value: contract, child: Text(contract)))
 .toList(),
 icon: const Icon(Icons.keyboard_arrow_down_rounded,
 color: Color(0xFF6B7280)),
 decoration: InputDecoration(
 contentPadding: const EdgeInsets.symmetric(
 horizontal: 20, vertical: 14),
 filled: true,
 fillColor: const Color(0xFFF9FAFB),
 border: OutlineInputBorder(
 borderRadius: BorderRadius.circular(16),
 borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
 ),
 enabledBorder: OutlineInputBorder(
 borderRadius: BorderRadius.circular(16),
 borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
 ),
 focusedBorder: OutlineInputBorder(
 borderRadius: BorderRadius.circular(16),
 borderSide: const BorderSide(
 color: Color(0xFFFFC812), width: 1.2),
 ),
 ),
 style: const TextStyle(
 fontSize: 13,
 fontWeight: FontWeight.w600,
 color: Color(0xFF1F2937)),
 ),
 ),
 ],
 ),
 const SizedBox(height: 28),
 if (steps.isEmpty)
 const _EmptyPanelMessage('No execution steps defined yet.')
 else
 Column(
 children: List.generate(
 steps.length,
 (index) => _ExecutionTimelineRow(
 data: steps[index],
 isFirst: index == 0,
 isLast: index == steps.length - 1,
 ),
 ),
 ),
 ],
 ),
 );
 }
}

class _ExecutionTimelineRow extends StatelessWidget {
 const _ExecutionTimelineRow(
 {required this.data, required this.isFirst, required this.isLast});

 final _ExecutionStepData data;
 final bool isFirst;
 final bool isLast;

 @override
 Widget build(BuildContext context) {
 return Padding(
 padding: const EdgeInsets.symmetric(vertical: 10),
 child: Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 SizedBox(
 width: 36,
 child: Column(
 children: [
 if (!isFirst)
 Container(
 height: 14,
 width: 2,
 color: const Color(0xFFE5E7EB),
 ),
 Container(
 width: 24,
 height: 24,
 decoration: BoxDecoration(
 color: isFirst
 ? const Color(0xFFFFC812)
 : const Color(0xFFE5E7EB),
 shape: BoxShape.circle,
 ),
 alignment: Alignment.center,
 child: Text(
 data.shortCode,
 style: TextStyle(
 fontSize: 11,
 fontWeight: FontWeight.w700,
 color: isFirst ? Colors.white : const Color(0xFF6B7280),
 ),
 ),
 ),
 if (!isLast)
 Container(
 height: 70,
 width: 2,
 color: const Color(0xFFE5E7EB),
 ),
 ],
 ),
 ),
 const SizedBox(width: 16),
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(data.title,
 style: const TextStyle(
 fontSize: 15,
 fontWeight: FontWeight.w700,
 color: Color(0xFF111827))),
 const SizedBox(height: 6),
 Text(data.description,
 style: const TextStyle(
 fontSize: 13, color: Color(0xFF4B5563))),
 const SizedBox(height: 6),
 Text(data.statusDetail,
 style: const TextStyle(
 fontSize: 12, color: Color(0xFF9CA3AF))),
 if (data.highlightAction) ...[
 const SizedBox(height: 12),
 ElevatedButton(
 onPressed: () => PlanningProcurementScreen.open(context),
 style: ElevatedButton.styleFrom(
 backgroundColor: _kFabYellow,
 foregroundColor: _kFabOnYellow,
 padding: const EdgeInsets.symmetric(
 horizontal: 22, vertical: 14),
 shape: RoundedRectangleBorder(
 borderRadius: BorderRadius.circular(12)),
 elevation: 0,
 ),
 child: const Text('Start Request for Quote (RFQ)',
 style: TextStyle(
 fontSize: 13, fontWeight: FontWeight.w600)),
 ),
 ],
 ],
 ),
 ),
 ],
 ),
 );
 }
}

class _TimelineLegendItem {
 const _TimelineLegendItem({required this.label, required this.color});

 final String label;
 final Color color;
}

class _StatusTimelineRowData {
 const _StatusTimelineRowData({required this.label, required this.cells});

 final String label;
 final List<_StatusTimelineCellData> cells;

 factory _StatusTimelineRowData.fromJson(Map<String, dynamic> json) {
 final cells = (json['cells'] as List?)
 ?.whereType<Map>()
 .map((cell) => _StatusTimelineCellData.fromJson(
 Map<String, dynamic>.from(cell)))
 .toList() ??
 [];
 return _StatusTimelineRowData(
 label: (json['label'] ?? '').toString(),
 cells: cells,
 );
 }

 factory _StatusTimelineRowData.fromLaunchEntry(
 Map<String, dynamic> json, int monthsLength) {
 final label = (json['title'] ?? '').toString().trim();
 final statusText = (json['status'] ?? '').toString().trim().toLowerCase();
 final status = _StatusTimelineCellData._statusFromText(statusText);
 final cells = List.generate(
 monthsLength,
 (index) => _StatusTimelineCellData(
 status: index < monthsLength / 2
 ? status
 : _TimelineStatusState.notStarted),
 );
 return _StatusTimelineRowData(label: label, cells: cells);
 }

 Map<String, dynamic> toJson() => {
 'label': label,
 'cells': cells.map((cell) => cell.toJson()).toList(),
 };
}

class _StatusTimelineCellData {
 const _StatusTimelineCellData({required this.status});

 final _TimelineStatusState status;

 factory _StatusTimelineCellData.fromJson(Map<String, dynamic> json) {
 final statusText = (json['status'] ?? '').toString();
 return _StatusTimelineCellData(
 status: _StatusTimelineCellData._statusFromText(statusText));
 }

 Map<String, dynamic> toJson() => {
 'status': status.name,
 };

 static _TimelineStatusState _statusFromText(String statusText) {
 final text = statusText.toLowerCase();
 if (text.contains('complete')) return _TimelineStatusState.complete;
 if (text.contains('behind') || text.contains('risk')) {
 return _TimelineStatusState.behindSchedule;
 }
 if (text.contains('progress')) return _TimelineStatusState.inProgress;
 return _TimelineStatusState.notStarted;
 }
}

enum _TimelineStatusState { complete, inProgress, notStarted, behindSchedule }

class _MilestoneEntry {
 const _MilestoneEntry(
 {required this.label, required this.date, required this.statusColor});

 final String label;
 final String date;
 final Color statusColor;

 factory _MilestoneEntry.fromJson(Map<String, dynamic> json) {
 return _MilestoneEntry(
 label: (json['label'] ?? '').toString(),
 date: (json['date'] ?? '').toString(),
 statusColor: Color((json['statusColor'] ?? 0xFFD97706) as int),
 );
 }

 factory _MilestoneEntry.fromLaunchEntry(Map<String, dynamic> json) {
 final label = (json['title'] ?? '').toString().trim();
 final date = (json['details'] ?? '').toString().trim();
 final status = (json['status'] ?? '').toString().trim();
 return _MilestoneEntry(
 label: label,
 date: date.isEmpty ? 'TBD' : date,
 statusColor: _statusColorFor(status),
 );
 }

 Map<String, dynamic> toJson() => {
 'label': label,
 'date': date,
 'statusColor': statusColor.toARGB32(),
 };
}

class _RecentActivityData {
 const _RecentActivityData({required this.description, required this.date});

 final String description;
 final String date;

 factory _RecentActivityData.fromJson(Map<String, dynamic> json) {
 return _RecentActivityData(
 description: (json['description'] ?? '').toString(),
 date: (json['date'] ?? '').toString(),
 );
 }

 factory _RecentActivityData.fromLaunchEntry(Map<String, dynamic> json) {
 return _RecentActivityData(
 description: (json['title'] ?? '').toString().trim(),
 date: (json['details'] ?? '').toString().trim(),
 );
 }

 Map<String, dynamic> toJson() => {
 'description': description,
 'date': date,
 };
}

class _ExecutionStepData {
 const _ExecutionStepData(
 {required this.title,
 required this.description,
 required this.statusDetail,
 this.highlightAction = false});

 final String title;
 final String description;
 final String statusDetail;
 final bool highlightAction;

 String get shortCode => title.isNotEmpty ? title[0].toUpperCase() : '?';

 factory _ExecutionStepData.fromJson(Map<String, dynamic> json) {
 return _ExecutionStepData(
 title: (json['title'] ?? '').toString(),
 description: (json['description'] ?? '').toString(),
 statusDetail: (json['statusDetail'] ?? '').toString(),
 highlightAction: json['highlightAction'] == true,
 );
 }

 factory _ExecutionStepData.fromLaunchEntry(Map<String, dynamic> json) {
 return _ExecutionStepData(
 title: (json['title'] ?? '').toString().trim(),
 description: (json['details'] ?? '').toString().trim(),
 statusDetail: (json['status'] ?? '').toString().trim(),
 highlightAction: false,
 );
 }

 Map<String, dynamic> toJson() => {
 'title': title,
 'description': description,
 'statusDetail': statusDetail,
 'highlightAction': highlightAction,
 };
}

class _AdditionalInfoField extends StatelessWidget {
 const _AdditionalInfoField({required this.controller, this.onChanged});

 final TextEditingController controller;
 final ValueChanged<String>? onChanged;

 @override
 Widget build(BuildContext context) {
 return Container(
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(18),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 boxShadow: const [
 BoxShadow(
 color: Color(0x0F0F172A), blurRadius: 16, offset: Offset(0, 10))
 ],
 ),
 padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
 child: VoiceTextField(
 controller: controller,
 maxLines: 4,
 onChanged: onChanged,
 decoration: const InputDecoration(
 border: InputBorder.none,
 hintText: 'Any additional information about this contract',
 hintStyle: TextStyle(fontSize: 14, color: Color(0xFF9CA3AF)),
 ),
 style: const TextStyle(fontSize: 14, color: Color(0xFF1F2937)),
 ),
 );
 }
}

class _ContractOverviewSummaryCard extends StatelessWidget {
 const _ContractOverviewSummaryCard({
 required this.title,
 required this.contractId,
 required this.statusLabel,
 required this.milestones,
 });

 final String title;
 final String contractId;
 final String statusLabel;
 final List<_ContractMilestoneData> milestones;

 @override
 Widget build(BuildContext context) {
 return Container(
 width: double.infinity,
 padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(26),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 boxShadow: const [
 BoxShadow(
 color: Color(0x0D0F172A), blurRadius: 24, offset: Offset(0, 16)),
 ],
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 title.isNotEmpty ? title : 'Contract overview',
 style: const TextStyle(
 fontSize: 22,
 fontWeight: FontWeight.w700,
 color: Color(0xFF111827)),
 ),
 const SizedBox(height: 8),
 Row(
 children: [
 const Text(
 'Contract ID:',
 style:
 TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
 ),
 const SizedBox(width: 8),
 Container(
 padding: const EdgeInsets.symmetric(
 horizontal: 12, vertical: 6),
 decoration: BoxDecoration(
 color: const Color(0xFFF3F4F6),
 borderRadius: BorderRadius.circular(10),
 ),
 child: Text(
 contractId.isNotEmpty ? contractId : 'TBD',
 style: TextStyle(
 fontSize: 13,
 fontWeight: FontWeight.w600,
 color: Color(0xFF111827)),
 ),
 ),
 ],
 ),
 ],
 ),
 ),
 _StatusPill(
 label: statusLabel.isNotEmpty ? statusLabel : 'Pending',
 color: _statusColorFor(statusLabel),
 ),
 ],
 ),
 const SizedBox(height: 28),
 LayoutBuilder(
 builder: (context, constraints) {
 final bool stack = constraints.maxWidth < 720;
 final milestoneCards = milestones.isNotEmpty
 ? milestones
 : [
 const _ContractMilestoneData(
 title: 'Published Date',
 value: 'TBD',
 accentColor: Color(0xFFFFC812),
 ),
 ];
 if (stack) {
 return Column(
 children: milestoneCards
 .map(
 (milestone) => Padding(
 padding: const EdgeInsets.only(bottom: 12),
 child: _ContractMilestoneCard(data: milestone),
 ),
 )
 .toList(),
 );
 }

 return Row(
 children: List.generate(milestoneCards.length, (index) {
 final Widget card =
 _ContractMilestoneCard(data: milestoneCards[index]);
 return Expanded(
 child: Padding(
 padding: EdgeInsets.only(
 right: index == milestoneCards.length - 1 ? 0 : 18),
 child: card,
 ),
 );
 }),
 );
 },
 ),
 ],
 ),
 );
 }
}

class _ContractMilestoneCard extends StatelessWidget {
 const _ContractMilestoneCard({required this.data});

 final _ContractMilestoneData data;

 @override
 Widget build(BuildContext context) {
 final Color background = data.emphasize
 ? const Color(0xFFFFF5F5)
 : data.accentColor.withOpacity(0.08);
 final Color textColor =
 data.emphasize ? const Color(0xFFB91C1C) : const Color(0xFF1F2937);

 return Container(
 padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
 decoration: BoxDecoration(
 color: background,
 borderRadius: BorderRadius.circular(20),
 border: Border.all(color: data.accentColor.withOpacity(0.2)),
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(data.title,
 style: TextStyle(
 fontSize: 13,
 fontWeight: FontWeight.w600,
 color: data.accentColor)),
 const SizedBox(height: 8),
 Text(
 data.value,
 style: TextStyle(
 fontSize: 15,
 fontWeight: FontWeight.w700,
 color: textColor,
 height: 1.4),
 ),
 ],
 ),
 );
 }
}

class _ContractMilestoneData {
 const _ContractMilestoneData(
 {required this.title,
 required this.value,
 required this.accentColor,
 this.emphasize = false});

 final String title;
 final String value;
 final Color accentColor;
 final bool emphasize;

 factory _ContractMilestoneData.fromJson(Map<String, dynamic> json) {
 return _ContractMilestoneData(
 title: (json['title'] ?? '').toString(),
 value: (json['value'] ?? '').toString(),
 accentColor: Color((json['accentColor'] ?? 0xFFD97706) as int),
 emphasize: json['emphasize'] == true,
 );
 }

 Map<String, dynamic> toJson() => {
 'title': title,
 'value': value,
 'accentColor': accentColor.toARGB32(),
 'emphasize': emphasize,
 };
}

class _ContractDetailsContent extends StatelessWidget {
 const _ContractDetailsContent({
 required this.selectedIndex,
 required this.onTabSelected,
 required this.description,
 required this.scopeItems,
 required this.documents,
 required this.bidderInfo,
 required this.contactInfo,
 required this.preBidMeeting,
 });

 final int selectedIndex;
 final ValueChanged<int> onTabSelected;
 final String description;
 final List<String> scopeItems;
 final List<_ContractDocumentData> documents;
 final List<_BidderInfoData> bidderInfo;
 final _ContactInfoData? contactInfo;
 final _PreBidMeetingData? preBidMeeting;

 @override
 Widget build(BuildContext context) {
 return LayoutBuilder(
 builder: (context, constraints) {
 final bool stack = constraints.maxWidth < 1120;
 const double sidebarWidth = 300;

 if (stack || constraints.maxWidth < sidebarWidth + 520) {
 return Column(
 crossAxisAlignment: CrossAxisAlignment.stretch,
 children: [
 _ContractDetailsTabBlock(
 selectedIndex: selectedIndex,
 onTabSelected: onTabSelected,
 description: description,
 scopeItems: scopeItems,
 documents: documents,
 bidderInfo: bidderInfo,
 ),
 const SizedBox(height: 24),
 _ContractDetailsSidebar(
 contactInfo: contactInfo,
 preBidMeeting: preBidMeeting,
 ),
 ],
 );
 }

 final double contentWidth = constraints.maxWidth - sidebarWidth - 24;

 return Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 SizedBox(
 width: contentWidth,
 child: _ContractDetailsTabBlock(
 selectedIndex: selectedIndex,
 onTabSelected: onTabSelected,
 description: description,
 scopeItems: scopeItems,
 documents: documents,
 bidderInfo: bidderInfo,
 ),
 ),
 const SizedBox(width: 24),
 SizedBox(
 width: sidebarWidth,
 child: _ContractDetailsSidebar(
 contactInfo: contactInfo,
 preBidMeeting: preBidMeeting,
 ),
 ),
 ],
 );
 },
 );
 }
}

class _ContractDetailsTabBlock extends StatelessWidget {
 const _ContractDetailsTabBlock({
 required this.selectedIndex,
 required this.onTabSelected,
 required this.description,
 required this.scopeItems,
 required this.documents,
 required this.bidderInfo,
 });

 final int selectedIndex;
 final ValueChanged<int> onTabSelected;
 final String description;
 final List<String> scopeItems;
 final List<_ContractDocumentData> documents;
 final List<_BidderInfoData> bidderInfo;

 @override
 Widget build(BuildContext context) {
 return Column(
 crossAxisAlignment: CrossAxisAlignment.stretch,
 children: [
 _ContractDetailsTabCard(
 selectedIndex: selectedIndex,
 onTabSelected: onTabSelected,
 description: description,
 scopeItems: scopeItems,
 documents: documents,
 bidderInfo: bidderInfo,
 ),
 const SizedBox(height: 24),
 const _UploadBidDocumentsCard(),
 ],
 );
 }
}

class _ContractDetailsTabCard extends StatelessWidget {
 const _ContractDetailsTabCard({
 required this.selectedIndex,
 required this.onTabSelected,
 required this.description,
 required this.scopeItems,
 required this.documents,
 required this.bidderInfo,
 });

 final int selectedIndex;
 final ValueChanged<int> onTabSelected;
 final String description;
 final List<String> scopeItems;
 final List<_ContractDocumentData> documents;
 final List<_BidderInfoData> bidderInfo;

 @override
 Widget build(BuildContext context) {
 return Container(
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(26),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 boxShadow: const [
 BoxShadow(
 color: Color(0x0C0F172A), blurRadius: 20, offset: Offset(0, 14)),
 ],
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 _ContractDetailsTabBar(
 selectedIndex: selectedIndex, onTabSelected: onTabSelected),
 const Divider(height: 1, color: Color(0xFFE5E7EB)),
 Padding(
 padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 28),
 child: _ContractDetailsTabContent(
 selectedIndex: selectedIndex,
 description: description,
 scopeItems: scopeItems,
 documents: documents,
 bidderInfo: bidderInfo,
 ),
 ),
 ],
 ),
 );
 }
}

class _ContractDetailsTabBar extends StatelessWidget {
 const _ContractDetailsTabBar(
 {required this.selectedIndex, required this.onTabSelected});

 final int selectedIndex;
 final ValueChanged<int> onTabSelected;

 static const List<String> _labels = [
 'Description',
 'Contract Documents',
 'Information for Bidders'
 ];

 @override
 Widget build(BuildContext context) {
 return Padding(
 padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
 child: Row(
 children: List.generate(_labels.length, (index) {
 final bool isSelected = index == selectedIndex;
 return Expanded(
 child: InkWell(
 onTap: () => onTabSelected(index),
 borderRadius: BorderRadius.circular(14),
 child: Column(
 mainAxisSize: MainAxisSize.min,
 children: [
 Text(
 _labels[index],
 style: TextStyle(
 fontSize: 14,
 fontWeight: FontWeight.w600,
 color: isSelected
 ? const Color(0xFF1F2937)
 : const Color(0xFF6B7280),
 ),
 ),
 const SizedBox(height: 12),
 AnimatedContainer(
 duration: const Duration(milliseconds: 200),
 height: 3,
 decoration: BoxDecoration(
 color: isSelected
 ? const Color(0xFFFFC812)
 : Colors.transparent,
 borderRadius: BorderRadius.circular(999),
 ),
 ),
 ],
 ),
 ),
 );
 }),
 ),
 );
 }
}

class _ContractDetailsTabContent extends StatelessWidget {
 const _ContractDetailsTabContent({
 required this.selectedIndex,
 required this.description,
 required this.scopeItems,
 required this.documents,
 required this.bidderInfo,
 });

 final int selectedIndex;
 final String description;
 final List<String> scopeItems;
 final List<_ContractDocumentData> documents;
 final List<_BidderInfoData> bidderInfo;

 @override
 Widget build(BuildContext context) {
 switch (selectedIndex) {
 case 0:
 return _DescriptionTabContent(
 description: description, scopeItems: scopeItems);
 case 1:
 return _ContractDocumentsTabContent(documents: documents);
 case 2:
 return _InformationForBiddersTabContent(info: bidderInfo);
 default:
 return const SizedBox.shrink();
 }
 }
}

class _DescriptionTabContent extends StatelessWidget {
 const _DescriptionTabContent(
 {required this.description, required this.scopeItems});

 final String description;
 final List<String> scopeItems;

 @override
 Widget build(BuildContext context) {
 final descriptionText = description.trim().isNotEmpty
 ? description.trim()
 : 'Description not available yet.';
 final items = scopeItems.isNotEmpty
 ? scopeItems
 : ['Scope details will appear here once added to the contract.'];
 return Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 const Text(
 'Project Overview',
 style: TextStyle(
 fontSize: 16,
 fontWeight: FontWeight.w700,
 color: Color(0xFF111827)),
 ),
 const SizedBox(height: 12),
 Text(
 descriptionText,
 style: const TextStyle(
 fontSize: 14, height: 1.6, color: Color(0xFF4B5563)),
 ),
 const SizedBox(height: 22),
 const Text(
 'Scope of Work',
 style: TextStyle(
 fontSize: 16,
 fontWeight: FontWeight.w700,
 color: Color(0xFF111827)),
 ),
 const SizedBox(height: 12),
 ...items.map((item) => _BulletItem(text: item)),
 ],
 );
 }
}

class _ContractDocumentsTabContent extends StatelessWidget {
 const _ContractDocumentsTabContent({required this.documents});

 final List<_ContractDocumentData> documents;

 @override
 Widget build(BuildContext context) {
 return Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 mainAxisAlignment: MainAxisAlignment.spaceBetween,
 children: [
 const Text(
 'Required Documents',
 style: TextStyle(
 fontSize: 16,
 fontWeight: FontWeight.w700,
 color: Color(0xFF111827)),
 ),
 ElevatedButton(
 onPressed: () {},
 style: ElevatedButton.styleFrom(
 backgroundColor: const Color(0xFF6366F1),
 foregroundColor: Colors.white,
 elevation: 0,
 padding:
 const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
 shape: RoundedRectangleBorder(
 borderRadius: BorderRadius.circular(12)),
 ),
 child: const Text('Download All (.zip)',
 style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
 ),
 ],
 ),
 const SizedBox(height: 18),
 if (documents.isEmpty)
 const _EmptyPanelMessage('No contract documents added yet.')
 else
 Column(
 children: documents
 .map(
 (doc) => Padding(
 padding: const EdgeInsets.only(bottom: 12),
 child: _ContractDocumentRow(data: doc),
 ),
 )
 .toList(),
 ),
 ],
 );
 }
}

class _InformationForBiddersTabContent extends StatelessWidget {
 const _InformationForBiddersTabContent({required this.info});

 final List<_BidderInfoData> info;

 @override
 Widget build(BuildContext context) {
 return Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: info.isEmpty
 ? const [
 _EmptyPanelMessage('No bidder information added yet.'),
 ]
 : info
 .map(
 (item) => Padding(
 padding: const EdgeInsets.only(bottom: 18),
 child: _BidderInfoRow(data: item),
 ),
 )
 .toList(),
 );
 }
}

class _ContractDetailsSidebar extends StatelessWidget {
 const _ContractDetailsSidebar({this.contactInfo, this.preBidMeeting});

 final _ContactInfoData? contactInfo;
 final _PreBidMeetingData? preBidMeeting;

 @override
 Widget build(BuildContext context) {
 return Column(
 crossAxisAlignment: CrossAxisAlignment.stretch,
 children: [
 const _ActionsSidebarCard(),
 const SizedBox(height: 20),
 _ContactSidebarCard(contactInfo: contactInfo),
 const SizedBox(height: 20),
 _PreBidMeetingSidebarCard(preBidMeeting: preBidMeeting),
 ],
 );
 }
}

class _ActionsSidebarCard extends StatelessWidget {
 const _ActionsSidebarCard();

 @override
 Widget build(BuildContext context) {
 return _SidebarCard(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 const Text('Actions',
 style: TextStyle(
 fontSize: 15,
 fontWeight: FontWeight.w700,
 color: Color(0xFF111827))),
 const SizedBox(height: 18),
 SizedBox(
 width: double.infinity,
 child: ElevatedButton(
 onPressed: () {},
 style: ElevatedButton.styleFrom(
 backgroundColor: const Color(0xFF4F46E5),
 foregroundColor: Colors.white,
 elevation: 0,
 padding: const EdgeInsets.symmetric(vertical: 16),
 shape: RoundedRectangleBorder(
 borderRadius: BorderRadius.circular(14)),
 ),
 child: const Text('Submit Final Bid',
 style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
 ),
 ),
 const SizedBox(height: 12),
 SizedBox(
 width: double.infinity,
 child: OutlinedButton(
 onPressed: () {},
 style: OutlinedButton.styleFrom(
 foregroundColor: const Color(0xFF4B5563),
 backgroundColor: Colors.white,
 padding: const EdgeInsets.symmetric(vertical: 16),
 side: const BorderSide(color: Color(0xFFE5E7EB)),
 shape: RoundedRectangleBorder(
 borderRadius: BorderRadius.circular(14)),
 ),
 child: const Text('Save as Draft',
 style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
 ),
 ),
 ],
 ),
 );
 }
}

class _ContactSidebarCard extends StatelessWidget {
 const _ContactSidebarCard({this.contactInfo});

 final _ContactInfoData? contactInfo;

 @override
 Widget build(BuildContext context) {
 final info = contactInfo;
 return _SidebarCard(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 const Text('Contact for Inquiries',
 style: TextStyle(
 fontSize: 15,
 fontWeight: FontWeight.w700,
 color: Color(0xFF111827))),
 const SizedBox(height: 18),
 Row(
 children: [
 Container(
 width: 44,
 height: 44,
 decoration: BoxDecoration(
 color: const Color(0xFFE5E7EB),
 borderRadius: BorderRadius.circular(14),
 ),
 alignment: Alignment.center,
 child: Text(
 info?.initials ?? '—',
 style: const TextStyle(
 fontSize: 15,
 fontWeight: FontWeight.w700,
 color: Color(0xFF111827)),
 ),
 ),
 const SizedBox(width: 14),
 Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 info?.name ?? 'Contact not set',
 style: const TextStyle(
 fontSize: 14,
 fontWeight: FontWeight.w600,
 color: Color(0xFF111827)),
 ),
 const SizedBox(height: 4),
 Text(
 info?.role ?? 'Role pending',
 style:
 const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
 ),
 const SizedBox(height: 4),
 Text(
 info?.email ?? 'Email pending',
 style:
 const TextStyle(fontSize: 13, color: Color(0xFFFFC812)),
 ),
 ],
 ),
 ],
 ),
 ],
 ),
 );
 }
}

class _PreBidMeetingSidebarCard extends StatelessWidget {
 const _PreBidMeetingSidebarCard({this.preBidMeeting});

 final _PreBidMeetingData? preBidMeeting;

 @override
 Widget build(BuildContext context) {
 final meeting = preBidMeeting;
 return _SidebarCard(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 const Text('Pre-Bid Meeting',
 style: TextStyle(
 fontSize: 15,
 fontWeight: FontWeight.w700,
 color: Color(0xFF111827))),
 const SizedBox(height: 16),
 _SidebarInfoRow(label: 'Date', value: meeting?.date ?? 'TBD'),
 const SizedBox(height: 10),
 _SidebarInfoRow(label: 'Time', value: meeting?.time ?? 'TBD'),
 const SizedBox(height: 10),
 _SidebarInfoRow(label: 'Location', value: meeting?.location ?? 'TBD'),
 const SizedBox(height: 22),
 SizedBox(
 width: double.infinity,
 child: ElevatedButton(
 onPressed: () {},
 style: ElevatedButton.styleFrom(
 backgroundColor: const Color(0xFF10B981),
 foregroundColor: Colors.white,
 elevation: 0,
 padding: const EdgeInsets.symmetric(vertical: 16),
 shape: RoundedRectangleBorder(
 borderRadius: BorderRadius.circular(14)),
 ),
 child: const Text('Register for Meeting',
 style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
 ),
 ),
 ],
 ),
 );
 }
}

class _SidebarCard extends StatelessWidget {
 const _SidebarCard({required this.child});

 final Widget child;

 @override
 Widget build(BuildContext context) {
 return Container(
 padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(24),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 boxShadow: const [
 BoxShadow(
 color: Color(0x0C0F172A), blurRadius: 18, offset: Offset(0, 12)),
 ],
 ),
 child: child,
 );
 }
}

class _SidebarInfoRow extends StatelessWidget {
 const _SidebarInfoRow({required this.label, required this.value});

 final String label;
 final String value;

 @override
 Widget build(BuildContext context) {
 return Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(label,
 style: const TextStyle(
 fontSize: 12,
 fontWeight: FontWeight.w600,
 color: Color(0xFF6B7280))),
 const SizedBox(height: 4),
 Text(value,
 style: const TextStyle(
 fontSize: 13, color: Color(0xFF1F2937), height: 1.4)),
 ],
 );
 }
}

class _UploadBidDocumentsCard extends StatelessWidget {
 const _UploadBidDocumentsCard();

 @override
 Widget build(BuildContext context) {
 return Container(
 padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 32),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(24),
 border: Border.all(color: const Color(0xFFD1D5DB), width: 1.2),
 boxShadow: const [
 BoxShadow(
 color: Color(0x08000000), blurRadius: 14, offset: Offset(0, 10)),
 ],
 ),
 child: Column(
 mainAxisSize: MainAxisSize.min,
 crossAxisAlignment: CrossAxisAlignment.center,
 children: const [
 Icon(Icons.cloud_upload_outlined, size: 44, color: Color(0xFFFFC812)),
 SizedBox(height: 16),
 Text(
 'Upload Your Bid Documents',
 style: TextStyle(
 fontSize: 16,
 fontWeight: FontWeight.w700,
 color: Color(0xFF111827)),
 ),
 SizedBox(height: 12),
 Text.rich(
 TextSpan(
 children: [
 TextSpan(
 text: 'Drag & drop files here or ',
 style: TextStyle(fontSize: 13, color: Color(0xFF4B5563))),
 TextSpan(
 text: 'click to browse',
 style: TextStyle(
 fontSize: 13,
 color: Color(0xFFFFC812),
 fontWeight: FontWeight.w600)),
 ],
 ),
 textAlign: TextAlign.center,
 ),
 SizedBox(height: 8),
 Text(
 'Max file size: 100MB. Supported formats: PDF, DOCX, XLSX',
 style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
 textAlign: TextAlign.center,
 ),
 ],
 ),
 );
 }
}

class _ContractDocumentRow extends StatelessWidget {
 const _ContractDocumentRow({required this.data});

 final _ContractDocumentData data;

 @override
 Widget build(BuildContext context) {
 return Container(
 padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
 decoration: BoxDecoration(
 color: const Color(0xFFF9FAFB),
 borderRadius: BorderRadius.circular(18),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 ),
 child: Row(
 children: [
 Container(
 width: 44,
 height: 44,
 decoration: BoxDecoration(
 color: data.accentColor.withOpacity(0.12),
 borderRadius: BorderRadius.circular(14),
 ),
 child: Icon(data.icon, color: data.accentColor, size: 22),
 ),
 const SizedBox(width: 16),
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(data.title,
 style: const TextStyle(
 fontSize: 14,
 fontWeight: FontWeight.w600,
 color: Color(0xFF111827))),
 const SizedBox(height: 4),
 Text(data.details,
 style: const TextStyle(
 fontSize: 12, color: Color(0xFF6B7280))),
 ],
 ),
 ),
 TextButton(
 onPressed: () {},
 style: TextButton.styleFrom(
 foregroundColor: const Color(0xFFFFC812),
 padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
 minimumSize: const Size(0, 0),
 ),
 child: const Text('Download',
 style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
 ),
 ],
 ),
 );
 }
}

class _ContractDocumentData {
 const _ContractDocumentData(
 {required this.title,
 required this.details,
 required this.accentColor,
 required this.icon});

 final String title;
 final String details;
 final Color accentColor;
 final IconData icon;

 static final Map<int, IconData> _iconLookup = {
 Icons.description_outlined.codePoint: Icons.description_outlined,
 Icons.picture_as_pdf_outlined.codePoint: Icons.picture_as_pdf_outlined,
 Icons.table_chart_outlined.codePoint: Icons.table_chart_outlined,
 Icons.insert_drive_file_outlined.codePoint:
 Icons.insert_drive_file_outlined,
 Icons.folder_outlined.codePoint: Icons.folder_outlined,
 Icons.assignment_outlined.codePoint: Icons.assignment_outlined,
 };

 factory _ContractDocumentData.fromJson(Map<String, dynamic> json) {
 final codePoint =
 (json['iconCodePoint'] ?? Icons.description_outlined.codePoint) as int;
 return _ContractDocumentData(
 title: (json['title'] ?? '').toString(),
 details: (json['details'] ?? '').toString(),
 accentColor: Color((json['accentColor'] ?? 0xFFD97706) as int),
 icon: _iconLookup[codePoint] ?? Icons.description_outlined,
 );
 }

 factory _ContractDocumentData.fromLaunchEntry(Map<String, dynamic> json) {
 final title = (json['title'] ?? '').toString().trim();
 final details = (json['details'] ?? '').toString().trim();
 final status = (json['status'] ?? '').toString().toLowerCase();
 IconData icon = Icons.description_outlined;
 Color color = const Color(0xFFFFC812);
 if (status.contains('pdf') || details.toLowerCase().contains('pdf')) {
 icon = Icons.picture_as_pdf_outlined;
 color = const Color(0xFFEF4444);
 } else if (status.contains('xls') ||
 details.toLowerCase().contains('xls')) {
 icon = Icons.table_chart_outlined;
 color = const Color(0xFF22C55E);
 } else if (status.contains('doc') ||
 details.toLowerCase().contains('doc')) {
 icon = Icons.description_outlined;
 color = const Color(0xFF6366F1);
 }
 return _ContractDocumentData(
 title: title,
 details: details.isEmpty ? 'Document details pending.' : details,
 accentColor: color,
 icon: icon,
 );
 }

 Map<String, dynamic> toJson() => {
 'title': title,
 'details': details,
 'accentColor': accentColor.toARGB32(),
 'iconCodePoint': icon.codePoint,
 };
}

class _BidderInfoRow extends StatelessWidget {
 const _BidderInfoRow({required this.data});

 final _BidderInfoData data;

 @override
 Widget build(BuildContext context) {
 return Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text('${data.title}:',
 style: const TextStyle(
 fontSize: 14,
 fontWeight: FontWeight.w700,
 color: Color(0xFF111827))),
 const SizedBox(height: 8),
 Text(data.description,
 style: const TextStyle(
 fontSize: 13, height: 1.6, color: Color(0xFF4B5563))),
 ],
 );
 }
}

class _BidderInfoData {
 const _BidderInfoData({required this.title, required this.description});

 final String title;
 final String description;

 factory _BidderInfoData.fromJson(Map<String, dynamic> json) {
 return _BidderInfoData(
 title: (json['title'] ?? '').toString(),
 description: (json['description'] ?? '').toString(),
 );
 }

 factory _BidderInfoData.fromLaunchEntry(Map<String, dynamic> json) {
 return _BidderInfoData(
 title: (json['title'] ?? '').toString().trim(),
 description: (json['details'] ?? json['status'] ?? '').toString().trim(),
 );
 }

 Map<String, dynamic> toJson() => {
 'title': title,
 'description': description,
 };
}

class _ContactInfoData {
 const _ContactInfoData(
 {required this.name, required this.role, required this.email});

 final String name;
 final String role;
 final String email;

 String get initials {
 final parts = name.trim().split(' ').where((p) => p.isNotEmpty).toList();
 if (parts.isEmpty) return '—';
 if (parts.length == 1) return parts.first[0].toUpperCase();
 return '${parts.first[0]}${parts[1][0]}'.toUpperCase();
 }

 factory _ContactInfoData.fromJson(Map<String, dynamic> json) {
 return _ContactInfoData(
 name: (json['name'] ?? '').toString(),
 role: (json['role'] ?? '').toString(),
 email: (json['email'] ?? '').toString(),
 );
 }

 factory _ContactInfoData.fromLaunchEntry(Map<String, dynamic> json) {
 return _ContactInfoData(
 name: (json['title'] ?? '').toString().trim(),
 role: (json['details'] ?? '').toString().trim(),
 email: (json['status'] ?? '').toString().trim(),
 );
 }

 Map<String, dynamic> toJson() => {
 'name': name,
 'role': role,
 'email': email,
 };
}

class _PreBidMeetingData {
 const _PreBidMeetingData(
 {required this.date, required this.time, required this.location});

 final String date;
 final String time;
 final String location;

 factory _PreBidMeetingData.fromJson(Map<String, dynamic> json) {
 return _PreBidMeetingData(
 date: (json['date'] ?? '').toString(),
 time: (json['time'] ?? '').toString(),
 location: (json['location'] ?? '').toString(),
 );
 }

 factory _PreBidMeetingData.fromLaunchEntry(Map<String, dynamic> json) {
 return _PreBidMeetingData(
 date: (json['title'] ?? '').toString().trim(),
 time: (json['details'] ?? '').toString().trim(),
 location: (json['status'] ?? '').toString().trim(),
 );
 }

 Map<String, dynamic> toJson() => {
 'date': date,
 'time': time,
 'location': location,
 };
}

class _BulletItem extends StatelessWidget {
 const _BulletItem({required this.text});

 final String text;

 @override
 Widget build(BuildContext context) {
 return Padding(
 padding: const EdgeInsets.only(bottom: 10),
 child: Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 const Padding(
 padding: EdgeInsets.only(top: 6),
 child: Icon(Icons.circle, size: 6, color: Color(0xFFFFC812)),
 ),
 const SizedBox(width: 10),
 Expanded(
 child: Text(
 text,
 style: const TextStyle(
 fontSize: 13, height: 1.6, color: Color(0xFF4B5563)),
 ),
 ),
 ],
 ),
 );
 }
}

class _ContractMetricData {
 const _ContractMetricData({
 required this.label,
 required this.value,
 required this.detail,
 required this.icon,
 required this.accentColor,
 });

 final String label;
 final String value;
 final String detail;
 final IconData icon;
 final Color accentColor;
}

class _ContractRecord {
 const _ContractRecord({
 required this.name,
 required this.code,
 required this.owner,
 required this.value,
 required this.status,
 required this.statusColor,
 required this.effectiveDate,
 required this.renewalDate,
 required this.lastUpdated,
 required this.highlights,
 });

 final String name;
 final String code;
 final String owner;
 final String value;
 final String status;
 final Color statusColor;
 final String effectiveDate;
 final String renewalDate;
 final String lastUpdated;
 final List<String> highlights;
}

class _CircleIconButton extends StatelessWidget {
 const _CircleIconButton({required this.icon, this.onTap});

 final IconData icon;
 final VoidCallback? onTap;

 @override
 Widget build(BuildContext context) {
 return InkWell(
 onTap: onTap,
 borderRadius: BorderRadius.circular(999),
 child: Container(
 width: 40,
 height: 40,
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

class _TabButton extends StatelessWidget {
 const _TabButton(
 {required this.label, required this.isSelected, required this.onTap});

 final String label;
 final bool isSelected;
 final VoidCallback onTap;

 @override
 Widget build(BuildContext context) {
 return Expanded(
 child: InkWell(
 onTap: onTap,
 borderRadius: BorderRadius.circular(10),
 child: AnimatedContainer(
 duration: const Duration(milliseconds: 200),
 padding: const EdgeInsets.symmetric(vertical: 14),
 decoration: BoxDecoration(
 color: isSelected ? Colors.white : Colors.transparent,
 borderRadius: BorderRadius.circular(10),
 border: Border.all(
 color:
 isSelected ? const Color(0xFFFFC812) : Colors.transparent,
 width: 1.4),
 boxShadow: isSelected
 ? const [
 BoxShadow(
 color: Color(0x14000000),
 blurRadius: 8,
 offset: Offset(0, 4))
 ]
 : null,
 ),
 alignment: Alignment.center,
 child: Text(
 label,
 style: TextStyle(
 fontSize: 14,
 fontWeight: FontWeight.w600,
 color: isSelected
 ? const Color(0xFF111827)
 : const Color(0xFF6B7280),
 ),
 ),
 ),
 ),
 );
 }
}

class _TimelineStepData {
 const _TimelineStepData({
 required this.number,
 required this.title,
 required this.description,
 required this.estimate,
 required this.status,
 });

 final int number;
 final String title;
 final String description;
 final String estimate;
 final _TimelineStatus status;
}

// ignore: unused_field
enum _TimelineStatus { current, upcoming }
