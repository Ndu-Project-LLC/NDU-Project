import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:ndu_project/providers/project_data_provider.dart';
import 'package:ndu_project/screens/status_reports_screen.dart';
import 'package:ndu_project/screens/vendor_tracking_screen.dart';
import 'package:ndu_project/services/contract_service.dart';
import 'package:ndu_project/services/execution_phase_service.dart';
import 'package:ndu_project/utils/execution_phase_ai_seed.dart';
import 'package:ndu_project/utils/auto_bullet_text_controller.dart';
import 'package:ndu_project/utils/rich_text_editing_controller.dart';
import 'package:ndu_project/widgets/contracts_table_widget.dart';
import 'package:ndu_project/widgets/kaz_ai_chat_bubble.dart';
import 'package:ndu_project/widgets/launch_phase_navigation.dart';
import 'package:ndu_project/widgets/responsive.dart';
import 'package:ndu_project/widgets/responsive_scaffold.dart';
import 'package:ndu_project/widgets/text_formatting_toolbar.dart';
import 'package:ndu_project/widgets/planning_phase_header.dart';

import 'package:ndu_project/widgets/voice_text_field.dart';
import 'package:ndu_project/utils/pdf_export_helper.dart';
import 'package:ndu_project/utils/project_data_helper.dart';
import 'package:ndu_project/widgets/delete_confirmation_dialog.dart';
class ContractsTrackingScreen extends StatefulWidget {
 const ContractsTrackingScreen({super.key});

 static void open(BuildContext context) {
 Navigator.of(context).push(
 MaterialPageRoute(builder: (_) => const ContractsTrackingScreen()),
 );
 }

 @override
 State<ContractsTrackingScreen> createState() =>
 _ContractsTrackingScreenState();
}

class _ContractsTrackingScreenState extends State<ContractsTrackingScreen> {
 final _Debouncer _saveDebouncer = _Debouncer();
 bool _isLoading = false;
 bool _suspendSave = false;
 bool _hasSavedData = false;
 bool _autoGenerationTriggered = false;
 bool _isAutoGenerating = false;

 List<_RenewalLaneData> _renewalLanes = [];
 List<_RiskSignalData> _riskSignals = [];
 List<_ApprovalCheckpointData> _approvalCheckpoints = [];
 String? _contractsStreamProjectId;
 Stream<List<ContractModel>>? _contractsStream;

 static const List<String> _riskStatusOptions = [
 'On track',
 'At risk',
 'Needs review',
 'Blocked',
 ];

 String? get _projectId {
 try {
 final provider = ProjectDataInherited.maybeOf(context);
 return provider?.projectData.projectId;
 } catch (e) {
 return null;
 }
 }

 @override
 void initState() {
 super.initState();
 _renewalLanes = _defaultRenewalLanes();
 _riskSignals = _defaultRiskSignals();
 _approvalCheckpoints = _defaultApprovalCheckpoints();
 WidgetsBinding.instance.addPostFrameCallback((_) => _loadTrackingData());
 }

 @override
 void dispose() {
 _saveDebouncer.dispose();
 super.dispose();
 }

 DocumentReference<Map<String, dynamic>> _trackingDoc(String projectId) {
 return FirebaseFirestore.instance
 .collection('projects')
 .doc(projectId)
 .collection('execution_phase_sections')
 .doc('contracts_tracking');
 }

 void _scheduleSave() {
 if (_suspendSave) return;
 _saveDebouncer.run(_saveTrackingData);
 }

 Future<void> _loadTrackingData() async {
 final projectId = _projectId;
 if (projectId == null || projectId.isEmpty) return;
 if (!mounted) return;
 setState(() => _isLoading = true);
 try {
 final doc = await _trackingDoc(projectId).get();
 final data = doc.data() ?? {};
 _suspendSave = true;
 if (!mounted) return;
 final lanes = _RenewalLaneData.fromList(data['renewalLanes']);
 final signals = _RiskSignalData.fromList(data['riskSignals']);
 final approvals =
 _ApprovalCheckpointData.fromList(data['approvalCheckpoints']);
 setState(() {
 _renewalLanes = lanes.isEmpty ? _defaultRenewalLanes() : lanes;
 _riskSignals = signals.isEmpty ? _defaultRiskSignals() : signals;
 _approvalCheckpoints =
 approvals.isEmpty ? _defaultApprovalCheckpoints() : approvals;
 });
 _hasSavedData = doc.exists &&
 (lanes.isNotEmpty || signals.isNotEmpty || approvals.isNotEmpty);
 } catch (error) {
 debugPrint('Contracts tracking load error: $error');
 } finally {
 _suspendSave = false;
 if (mounted) setState(() => _isLoading = false);
 }
 await _autoGenerateIfNeeded();
 }

 Future<void> _autoGenerateIfNeeded() async {
 if (!mounted || _autoGenerationTriggered || _isAutoGenerating) return;
 if (_hasSavedData) return;

 _autoGenerationTriggered = true;
 _isAutoGenerating = true;
 try {
 final contextText = ExecutionPhaseAiSeed.buildContext(
 context,
 section: 'Contracts Tracking',
 );
 if (contextText.isEmpty) return;

 final generated = await ExecutionPhaseAiSeed.generateEntries(
 context: context,
 section: 'Contracts Tracking',
 sections: const {
 'riskSignals': 'Contract renewal risks and signals',
 'approvalCheckpoints': 'Approval checkpoints and sign-offs',
 },
 itemsPerSection: 3,
 );

 final riskSignals = generated['riskSignals'] ?? const [];
 final approvalCheckpoints = generated['approvalCheckpoints'] ?? const [];

 if (riskSignals.isNotEmpty) {
 _riskSignals = riskSignals
 .map(
 (entry) => _RiskSignalData(
 id: _newId(),
 title: entry.title,
 detail: entry.details,
 owner: 'Legal',
 status: entry.status?.isNotEmpty == true
 ? entry.status!
 : 'On track',
 ),
 )
 .toList();
 }

 if (approvalCheckpoints.isNotEmpty) {
 _approvalCheckpoints = approvalCheckpoints
 .map(
 (entry) => _ApprovalCheckpointData(
 id: _newId(),
 gate: entry.title,
 description: entry.details,
 status: entry.status?.isNotEmpty == true
 ? entry.status!
 : 'Pending',
 approver: 'Legal',
 targetDate: 'TBD',
 ),
 )
 .toList();
 }

 if (mounted) {
 setState(() {});
 await _saveTrackingData();
 }
 } catch (e) {
 debugPrint('Error auto-generating contracts tracking data: $e');
 } finally {
 _isAutoGenerating = false;
 }
 }

 Future<void> _saveTrackingData() async {
 final projectId = _projectId;
 if (projectId == null || projectId.isEmpty) return;
 try {
 await _trackingDoc(projectId).set({
 'renewalLanes': _renewalLanes.map((e) => e.toMap()).toList(),
 'riskSignals': _riskSignals.map((e) => e.toMap()).toList(),
 'approvalCheckpoints':
 _approvalCheckpoints.map((e) => e.toMap()).toList(),
 'updatedAt': FieldValue.serverTimestamp(),
 }, SetOptions(merge: true));
 } catch (error) {
 debugPrint('Contracts tracking save error: $error');
 }
 }

 List<_RenewalLaneData> _defaultRenewalLanes() {
 final now = DateTime.now();
 return [
 _RenewalLaneData(
 id: _newId(),
 contractName: 'Cloud Infrastructure Services',
 contractType: 'Service Level Agreement',
 expiryDate: DateFormat('MMM d, yyyy').format(now.add(const Duration(days: 18))),
 daysUntilExpiry: 18,
 renewalAction: 'Renegotiate',
 owner: 'IT Director',
 status: 'In Negotiation',
 committedValue: '\$2.4M',
 notes: 'SLA uptime requirement increasing to 99.95%; bandwidth upgrade needed',
 ),
 _RenewalLaneData(
 id: _newId(),
 contractName: 'Project Management Platform',
 contractType: 'Software License',
 expiryDate: DateFormat('MMM d, yyyy').format(now.add(const Duration(days: 42))),
 daysUntilExpiry: 42,
 renewalAction: 'Renew',
 owner: 'PMO Lead',
 status: 'Draft Ready',
 committedValue: '\$180K',
 notes: 'Multi-year discount available if renewed before expiry',
 ),
 _RenewalLaneData(
 id: _newId(),
 contractName: 'Site Security & Surveillance',
 contractType: 'Service Level Agreement',
 expiryDate: DateFormat('MMM d, yyyy').format(now.add(const Duration(days: 67))),
 daysUntilExpiry: 67,
 renewalAction: 'Renew',
 owner: 'Operations Manager',
 status: 'Not Started',
 committedValue: '\$560K',
 notes: 'Annual physical security review required before renewal approval',
 ),
 _RenewalLaneData(
 id: _newId(),
 contractName: 'Environmental Compliance Audit',
 contractType: 'Consulting Agreement',
 expiryDate: DateFormat('MMM d, yyyy').format(now.add(const Duration(days: 89))),
 daysUntilExpiry: 89,
 renewalAction: 'Extend',
 owner: 'HSE Manager',
 status: 'Not Started',
 committedValue: '\$95K',
 notes: 'Regulatory audit scope expansion pending; hold renewal until scope confirmed',
 ),
 _RenewalLaneData(
 id: _newId(),
 contractName: 'Heavy Equipment Lease',
 contractType: 'Procurement',
 expiryDate: DateFormat('MMM d, yyyy').format(now.add(const Duration(days: 125))),
 daysUntilExpiry: 125,
 renewalAction: 'Renegotiate',
 owner: 'Procurement Lead',
 status: 'Not Started',
 committedValue: '\$3.1M',
 notes: 'Market rate review needed; competitor quotes due by next quarter',
 ),
 ];
 }

 List<_RiskSignalData> _defaultRiskSignals() {
 return [
 _RiskSignalData(
 id: _newId(),
 title: 'Renewal risk flagged',
 detail: 'Track renewals with expiring SLAs',
 owner: 'Legal',
 status: 'Needs review'),
 ];
 }

 List<_ApprovalCheckpointData> _defaultApprovalCheckpoints() {
 return [
 _ApprovalCheckpointData(
 id: _newId(),
 gate: 'Legal Review & Compliance',
 description: 'Verify contract terms against regulatory requirements, liability clauses, and IP provisions',
 approver: 'General Counsel',
 department: 'Legal',
 priority: 'Critical',
 status: 'In Review',
 targetDate: 'TBD',
 ),
 _ApprovalCheckpointData(
 id: _newId(),
 gate: 'Financial Authorization',
 description: 'Confirm budget allocation, payment schedule, and fiscal compliance for committed value',
 approver: 'CFO / Finance Director',
 department: 'Finance',
 priority: 'Critical',
 status: 'Pending',
 targetDate: 'TBD',
 ),
 _ApprovalCheckpointData(
 id: _newId(),
 gate: 'Scope & Deliverable Alignment',
 description: 'Validate that contracted scope matches approved project scope and WBS deliverables',
 approver: 'Project Manager',
 department: 'Project Office',
 priority: 'High',
 status: 'Pending',
 targetDate: 'TBD',
 ),
 _ApprovalCheckpointData(
 id: _newId(),
 gate: 'Technical Feasibility Sign-off',
 description: 'Confirm vendor capability and technical approach meet acceptance criteria and SLA targets',
 approver: 'Technical Lead',
 department: 'Engineering',
 priority: 'High',
 status: 'Not Started',
 targetDate: 'TBD',
 ),
 _ApprovalCheckpointData(
 id: _newId(),
 gate: 'Executive Authorization',
 description: 'Final approval from executive sponsor for contract execution and vendor onboarding',
 approver: 'Executive Sponsor',
 department: 'Executive',
 priority: 'High',
 status: 'Not Started',
 targetDate: 'TBD',
 ),
 _ApprovalCheckpointData(
 id: _newId(),
 gate: 'Insurance & Indemnity Verification',
 description: 'Confirm vendor insurance certificates, indemnity provisions, and risk transfer mechanisms',
 approver: 'Risk Manager',
 department: 'Risk',
 priority: 'Medium',
 status: 'Not Started',
 targetDate: 'TBD',
 ),
 ];
 }

 String _newId() => DateTime.now().microsecondsSinceEpoch.toString();

 Stream<List<ContractModel>>? _contractStreamForProject() {
 final projectId = _projectId;
 if (projectId == null || projectId.isEmpty) return null;
 if (_contractsStreamProjectId != projectId || _contractsStream == null) {
 _contractsStreamProjectId = projectId;
 _contractsStream = ContractService.streamContracts(projectId);
 }
 return _contractsStream;
 }

 @override
 Widget build(BuildContext context) {
 final padding = AppBreakpoints.pagePadding(context);

 return ResponsiveScaffold(
 activeItemLabel: 'Contracts Tracking',
 backgroundColor: Colors.white,
 floatingActionButton: const KazAiChatBubble(positioned: false),
 body: SingleChildScrollView(
 padding: EdgeInsets.all(padding),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 if (_isLoading) const LinearProgressIndicator(minHeight: 2),
 if (_isLoading) const SizedBox(height: 16),
 PlanningPhaseHeader(
 title: 'Contracts Tracking',
showNavigationButtons: false, onExportPdf: _exportPdf),
 const SizedBox(height: 24),
 _buildContractManagementGuide(),
 const SizedBox(height: 24),
 Column(
 children: [
 _buildContractRegister(),
 const SizedBox(height: 20),
 _buildRenewalPanel(),
 const SizedBox(height: 20),
 _buildSignalsPanel(),
 const SizedBox(height: 20),
 _buildApprovalsPanel(),
 ],
 ),
 const SizedBox(height: 24),
 LaunchPhaseNavigation(
 backLabel: 'Back: Status Reports',
 nextLabel: 'Next: Vendor Tracking',
 onBack: () => StatusReportsScreen.open(context),
 onNext: () => VendorTrackingScreen.open(context),
 ),
 ],
 ),
 ),
 );
 }

 Widget _buildContractManagementGuide() {
 return Container(
 padding: const EdgeInsets.all(20),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(16),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 boxShadow: [
 BoxShadow(
 color: Colors.black.withOpacity(0.04),
 blurRadius: 12,
 offset: const Offset(0, 6),
 ),
 ],
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 const Text(
 'Contract control framework',
 style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF111827)),
 ),
 const SizedBox(height: 6),
 const Text(
 'Grounded in PMI PMBOK Conduct Procurements (12.2) and Control Procurements (12.3), '
 'FIDIC contract conditions, and PRINCE2 procurement conventions. Effective contract '
 'tracking ensures that scope, value, timelines, and compliance obligations remain '
 'visible and actionable throughout the project lifecycle.',
 style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF6B7280), height: 1.5),
 ),
 const SizedBox(height: 18),
 Column(
 children: [
 _buildGuideCard(
 Icons.gavel_outlined,
 'Contract Lifecycle',
 'Draft → Legal Review → Signed → Active → Renewal/Expiry. '
 'Each contract should be tracked from initiation through close-out. '
 'Set renewal alerts at 90/60/30-day intervals to avoid lapses.',
 const Color(0xFFD97706),
 ),
 const SizedBox(height: 12),
 _buildGuideCard(
 Icons.assignment_turned_in_outlined,
 'Scope & SLA Compliance',
 'Monitor vendor performance against contracted deliverables and service '
 'level agreements. Document scope changes through the Change Control '
 'process before amending contract terms.',
 const Color(0xFF10B981),
 ),
 const SizedBox(height: 12),
 _buildGuideCard(
 Icons.attach_money_outlined,
 'Financial Controls',
 'Track committed value against actuals. Tie contract payments to verified '
 'milestones and deliverable acceptance. Maintain audit-ready records of '
 'all amendments, change orders, and payment approvals.',
 const Color(0xFFF59E0B),
 ),
 const SizedBox(height: 12),
 _buildGuideCard(
 Icons.warning_amber_outlined,
 'Risk & Renewal Signals',
 'Flag contracts approaching expiry, those with unresolved disputes, or '
 'vendors failing SLA targets. Escalate risk signals to the project board '
 'when they exceed threshold tolerance levels.',
 const Color(0xFFEF4444),
 ),
 ],
 ),
 ],
 ),
 );
 }

 Widget _buildGuideCard(IconData icon, String title, String description, Color color) {
 return Container(
 width: double.infinity,
 padding: const EdgeInsets.all(14),
 decoration: BoxDecoration(
 color: color.withOpacity(0.04),
 borderRadius: BorderRadius.circular(12),
 border: Border.all(color: color.withOpacity(0.12)),
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 children: [
 Container(
 padding: const EdgeInsets.all(6),
 decoration: BoxDecoration(
 color: color.withOpacity(0.12),
 borderRadius: BorderRadius.circular(8),
 ),
 child: Icon(icon, size: 16, color: color),
 ),
 const SizedBox(width: 10),
 Expanded(
 child: Text(
 title,
 style: TextStyle(
 fontSize: 12,
 fontWeight: FontWeight.w700,
 color: color,
 ),
 ),
 ),
 ],
 ),
 const SizedBox(height: 10),
 Text(
 description,
 style: const TextStyle(
 fontSize: 11,
 fontWeight: FontWeight.w500,
 color: Color(0xFF4B5563),
 height: 1.5,
 ),
 ),
 ],
 ),
 );
 }

 Widget _buildContractRegister() {
 final contractsStream = _contractStreamForProject();
 if (contractsStream == null) {
 return _PanelShell(
 title: 'Contract register',
 subtitle: 'Track scope, owners, and renewal milestones',
 child: const Center(
 child: Padding(
 padding: EdgeInsets.all(24.0),
 child: Text('No project selected. Please open a project first.',
 style: TextStyle(color: Color(0xFF64748B))),
 ),
 ),
 );
 }

 return _PanelShell(
 title: 'Contract register',
 subtitle: 'Track scope, owners, and renewal milestones',
 child: StreamBuilder<List<ContractModel>>(
 stream: contractsStream,
 builder: (context, snapshot) {
 if (snapshot.connectionState == ConnectionState.waiting) {
 return const Center(
 child: Padding(
 padding: EdgeInsets.all(24.0),
 child: CircularProgressIndicator()));
 }

 if (snapshot.hasError) {
 return Center(
 child: Padding(
 padding: const EdgeInsets.all(24.0),
 child: Text('Error loading contracts: ${snapshot.error}',
 style: const TextStyle(color: Colors.red)),
 ),
 );
 }

 final contracts = snapshot.data ?? [];

 if (contracts.isEmpty) {
 return Center(
 child: Padding(
 padding: const EdgeInsets.all(24.0),
 child: Column(
 children: [
 const Text('No contracts found.',
 style: TextStyle(color: Color(0xFF64748B))),
 const SizedBox(height: 12),
 ElevatedButton.icon(
 onPressed: () => _showAddContractDialog(context),
 icon: const Icon(Icons.add, size: 18),
 label: const Text('Add First Contract'),
 ),
 ],
 ),
 ),
 );
 }

 return ContractsTableWidget(
 contracts: contracts,
 onContractUpdated: (updated) async {
 await _updateContract(updated);
 },
 onContractDeleted: (deleted) async {
 await _deleteContract(deleted);
 },
 );
 },
 ),
 );
 }

 Widget _buildRenewalPanel() {
 if (_projectId == null) {
 return _PanelShell(
 title: 'Renewal pipeline',
 subtitle:
 'Contract renewal tracker aligned with PMI PMBOK Control Procurements. '
 'Monitor contracts approaching expiry, assign renewal owners, and track '
 'renegotiation progress across urgency windows.',
 child: const SizedBox.shrink(),
 );
 }

 return Container(
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(16),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 boxShadow: [
 BoxShadow(
 color: Colors.black.withOpacity(0.04),
 blurRadius: 12,
 offset: const Offset(0, 6),
 ),
 ],
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Padding(
 padding: const EdgeInsets.all(20),
 child: Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 const Text(
 'Renewal pipeline',
 style: TextStyle(
 fontSize: 16,
 fontWeight: FontWeight.w800,
 color: Color(0xFF111827),
 ),
 ),
 const SizedBox(height: 6),
 Text(
 'Contract renewal tracker aligned with PMI PMBOK Control '
 'Procurements. Monitor contracts approaching expiry, assign '
 'renewal owners, and track renegotiation progress across urgency windows.',
 style: const TextStyle(
 fontSize: 12,
 fontWeight: FontWeight.w500,
 color: Color(0xFF6B7280),
 height: 1.45,
 ),
 ),
 ],
 ),
 ),
 const SizedBox(width: 12),
 OutlinedButton.icon(
 onPressed: _showRenewalEntryEditor,
 icon: const Icon(Icons.add, size: 16),
 label: const Text('Add contract',
 style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
 style: OutlinedButton.styleFrom(
 foregroundColor: const Color(0xFF475569),
 side: const BorderSide(color: Color(0xFFE2E8F0)),
 padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
 ),
 ),
 ],
 ),
 ),
 const Divider(height: 1, thickness: 1, color: Color(0xFFE5E7EB)),
 if (_renewalLanes.isEmpty)
 Padding(
 padding: const EdgeInsets.all(32),
 child: Center(
 child: Column(
 children: [
 const Icon(Icons.autorenew_outlined, color: Color(0xFF9CA3AF), size: 32),
 const SizedBox(height: 12),
 const Text(
 'No contracts in the renewal pipeline. Add contracts to start tracking renewals.',
 style: TextStyle(
 fontSize: 13,
 fontWeight: FontWeight.w500,
 color: Color(0xFF6B7280),
 ),
 ),
 ],
 ),
 ),
 )
 else ...[
 // Table header
 Container(
 padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
 decoration: const BoxDecoration(color: Color(0xFFF8FAFC)),
 child: const Row(
 children: [
 Expanded(flex: 4, child: Text('CONTRACT', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF6B7280), letterSpacing: 0.8))),
 SizedBox(width: 130, child: Text('TYPE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF6B7280), letterSpacing: 0.8), textAlign: TextAlign.center)),
 SizedBox(width: 130, child: Text('EXPIRY', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF6B7280), letterSpacing: 0.8), textAlign: TextAlign.center)),
 SizedBox(width: 130, child: Text('URGENCY', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF6B7280), letterSpacing: 0.8), textAlign: TextAlign.center)),
 SizedBox(width: 130, child: Text('ACTION', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF6B7280), letterSpacing: 0.8), textAlign: TextAlign.center)),
 SizedBox(width: 130, child: Text('STATUS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF6B7280), letterSpacing: 0.8), textAlign: TextAlign.center)),
 Expanded(flex: 2, child: Text('OWNER', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF6B7280), letterSpacing: 0.8), textAlign: TextAlign.center)),
 SizedBox(width: 120, child: Text('VALUE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF6B7280), letterSpacing: 0.8), textAlign: TextAlign.center)),
 SizedBox(width: 60, child: Text('', style: TextStyle(fontSize: 10))),
 ],
 ),
 ),
 // Table rows sorted by urgency (soonest expiry first)
 ...List.generate(
 _sortedRenewalLanes.length,
 (index) {
 final lane = _sortedRenewalLanes[index];
 final isLast = index == _sortedRenewalLanes.length - 1;
 return _RenewalEntryRow(
 entry: lane,
 onEdit: () => _showRenewalEntryEditor(entry: lane),
 onDelete: () => _confirmDeleteRenewalEntry(lane),
 showDivider: !isLast,
 );
 },
 ),
 ],
 ],
 ),
 );
 }

 List<_RenewalLaneData> get _sortedRenewalLanes {
 final sorted = List<_RenewalLaneData>.from(_renewalLanes);
 sorted.sort((a, b) {
 final aDays = a.daysUntilExpiry ?? 9999;
 final bDays = b.daysUntilExpiry ?? 9999;
 return aDays.compareTo(bDays);
 });
 return sorted;
 }

 Widget _buildSignalsPanel() {
 if (_projectId == null) {
 return _PanelShell(
 title: 'Risk signals',
 subtitle: 'Items that need attention this week',
 child: const SizedBox.shrink(),
 );
 }

 return _PanelShell(
 title: 'Risk signals',
 subtitle: 'Items that need attention this week',
 trailing: TextButton.icon(
 onPressed: () => _showRiskSignalEditor(),
 icon: const Icon(Icons.add, size: 18),
 label: const Text('Add signal'),
 ),
 child: Column(
 children: _riskSignals.isEmpty
 ? [
 const Padding(
 padding: EdgeInsets.all(12),
 child: Text('No active risk signals',
 style: TextStyle(color: Color(0xFF10B981))),
 ),
 ]
 : _riskSignals.map(_buildRiskSignal).toList(),
 ),
 );
 }

 Widget _buildApprovalsPanel() {
 if (_projectId == null) {
 return _PanelShell(
 title: 'Approval readiness',
 subtitle:
 'Contract approval gates aligned with PMI PMBOK Close Procurements '
 'and organizational authority matrices. Each gate must be cleared '
 'before the contract advances to the next stage.',
 child: const SizedBox.shrink(),
 );
 }

 return Container(
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(16),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 boxShadow: [
 BoxShadow(
 color: Colors.black.withOpacity(0.04),
 blurRadius: 12,
 offset: const Offset(0, 6),
 ),
 ],
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 // Panel header
 Padding(
 padding: const EdgeInsets.all(20),
 child: Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 const Text(
 'Approval readiness',
 style: TextStyle(
 fontSize: 16,
 fontWeight: FontWeight.w800,
 color: Color(0xFF111827),
 ),
 ),
 const SizedBox(height: 6),
 Text(
 'Contract approval gates aligned with PMI PMBOK Close Procurements '
 'and organizational authority matrices. Each gate must be cleared '
 'before the contract advances to the next stage.',
 style: const TextStyle(
 fontSize: 12,
 fontWeight: FontWeight.w500,
 color: Color(0xFF6B7280),
 height: 1.45,
 ),
 ),
 ],
 ),
 ),
 const SizedBox(width: 12),
 OutlinedButton.icon(
 onPressed: _showApprovalCheckpointEditor,
 icon: const Icon(Icons.add, size: 16),
 label: const Text('Add gate',
 style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
 style: OutlinedButton.styleFrom(
 foregroundColor: const Color(0xFF475569),
 side: const BorderSide(color: Color(0xFFE2E8F0)),
 padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
 ),
 ),
 ],
 ),
 ),
 const Divider(height: 1, thickness: 1, color: Color(0xFFE5E7EB)),
 // Table
 if (_approvalCheckpoints.isEmpty)
 Padding(
 padding: const EdgeInsets.all(32),
 child: Center(
 child: Column(
 children: [
 const Icon(Icons.verified_outlined, color: Color(0xFF9CA3AF), size: 32),
 const SizedBox(height: 12),
 const Text(
 'No approval gates defined. Add gates to set up the approval workflow.',
 style: TextStyle(
 fontSize: 13,
 fontWeight: FontWeight.w500,
 color: Color(0xFF6B7280),
 ),
 ),
 ],
 ),
 ),
 )
 else ...[
 // Table header
 Container(
 padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
 decoration: const BoxDecoration(color: Color(0xFFF8FAFC)),
 child: const Row(
 children: [
 Expanded(flex: 5, child: Text('APPROVAL GATE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF6B7280), letterSpacing: 0.8))),
 Expanded(flex: 3, child: Text('APPROVER', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF6B7280), letterSpacing: 0.8))),
 SizedBox(width: 130, child: Text('DEPT', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF6B7280), letterSpacing: 0.8), textAlign: TextAlign.center)),
 SizedBox(width: 120, child: Text('PRIORITY', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF6B7280), letterSpacing: 0.8), textAlign: TextAlign.center)),
 SizedBox(width: 130, child: Text('STATUS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF6B7280), letterSpacing: 0.8), textAlign: TextAlign.center)),
 SizedBox(width: 130, child: Text('TARGET', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF6B7280), letterSpacing: 0.8), textAlign: TextAlign.center)),
 SizedBox(width: 60, child: Text('ACTION', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF6B7280), letterSpacing: 0.8), textAlign: TextAlign.center)),
 ],
 ),
 ),
 // Table rows
 ...List.generate(_approvalCheckpoints.length, (index) {
 final checkpoint = _approvalCheckpoints[index];
 final isLast = index == _approvalCheckpoints.length - 1;
 return _ApprovalGateRow(
 checkpoint: checkpoint,
 onEdit: () => _showApprovalCheckpointEditor(checkpoint: checkpoint),
 onDelete: () => _confirmDeleteApprovalCheckpoint(checkpoint),
 showDivider: !isLast,
 );
 }),
 ],
 ],
 ),
 );
 }

 Future<void> _updateContract(ContractModel contract) async {
 final projectId = _projectId;
 if (projectId == null) return;

 try {
 await ContractService.updateContract(
 projectId: projectId,
 contractId: contract.id,
 name: contract.name,
 description: contract.description,
 contractType: contract.contractType,
 paymentType: contract.paymentType,
 status: contract.status,
 estimatedValue: contract.estimatedValue,
 startDate: contract.startDate,
 endDate: contract.endDate,
 scope: contract.scope,
 discipline: contract.discipline,
 notes: contract.notes,
 );
 // Sync to Progress Tracking budget (only if value changed)
 // Note: Budget sync is handled in ContractsTableWidget._updateContract
 // This is a fallback for direct updates
 } catch (e) {
 debugPrint('Error updating contract: $e');
 }
 }

  Future<void> _deleteContract(ContractModel contract) async {
    final confirmed = await showDeleteConfirmationDialog(
      context,
      title: 'Delete Contract',
      itemLabel: contract.name,
    );
    if (!confirmed) return;
    final projectId = _projectId;
    if (projectId == null) return;

    try {
      await ContractService.deleteContract(
        projectId: projectId,
        contractId: contract.id,
      );
      // Sync to Progress Tracking budget (remove value)
      await _syncContractValueToBudget(contract, isDelete: true);
    } catch (e) {
      debugPrint('Error deleting contract: $e');
    }
  }

 // ignore: unused_element
 Future<void> _restoreContract(ContractModel contract) async {
 final projectId = _projectId;
 if (projectId == null) return;

 try {
 // Recreate the contract
 await ContractService.createContract(
 projectId: projectId,
 name: contract.name,
 description: contract.description,
 contractType: contract.contractType,
 paymentType: contract.paymentType,
 status: contract.status,
 estimatedValue: contract.estimatedValue,
 startDate: contract.startDate,
 endDate: contract.endDate,
 scope: contract.scope,
 discipline: contract.discipline,
 notes: contract.notes,
 createdById: contract.createdById,
 createdByEmail: contract.createdByEmail,
 createdByName: contract.createdByName,
 );
 // Sync to budget
 await _syncContractValueToBudget(contract, isDelete: false);
 } catch (e) {
 debugPrint('Error restoring contract: $e');
 }
 }

 Future<void> _syncContractValueToBudget(ContractModel contract,
 {bool isDelete = false}) async {
 final projectId = _projectId;
 if (projectId == null) return;

 try {
 await ExecutionPhaseService.syncContractValueToBudget(
 projectId: projectId,
 contractValue: contract.estimatedValue,
 contractName: contract.name,
 isDelete: isDelete,
 userId: FirebaseAuth.instance.currentUser?.uid,
 );
 } catch (e) {
 debugPrint('Error syncing contract value to budget: $e');
 // Don't show error to user - budget sync is background operation
 }
 }

 Widget _buildRiskSignal(_RiskSignalData signal) {
 final statusColor = _riskStatusColor(signal.status);

 return Container(
 margin: const EdgeInsets.only(bottom: 12),
 padding: const EdgeInsets.all(14),
 decoration: BoxDecoration(
 color: const Color(0xFFF8FAFC),
 borderRadius: BorderRadius.circular(12),
 border: Border.all(color: const Color(0xFFE2E8F0)),
 ),
 child: Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Container(
 width: 10,
 height: 10,
 margin: const EdgeInsets.only(top: 5),
 decoration: BoxDecoration(
 color: statusColor,
 shape: BoxShape.circle,
 ),
 ),
 const SizedBox(width: 12),
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 signal.title.trim().isEmpty
 ? 'Untitled signal'
 : signal.title,
 style: const TextStyle(
 fontSize: 13,
 fontWeight: FontWeight.w700,
 color: Color(0xFF0F172A),
 ),
 ),
 if (signal.detail.trim().isNotEmpty) ...[
 const SizedBox(height: 6),
 Text(
 signal.detail,
 style: const TextStyle(
 fontSize: 12,
 height: 1.45,
 color: Color(0xFF64748B),
 ),
 ),
 ],
 const SizedBox(height: 10),
 Wrap(
 spacing: 8,
 runSpacing: 8,
 children: [
 _RiskSignalPill(
 icon: Icons.person_outline,
 label: signal.owner.trim().isEmpty
 ? 'Owner unassigned'
 : signal.owner,
 ),
 _RiskSignalPill(
 icon: Icons.flag_outlined,
 label: signal.status,
 color: statusColor,
 ),
 ],
 ),
 ],
 ),
 ),
 const SizedBox(width: 8),
 PopupMenuButton<String>(
 tooltip: 'Risk signal actions',
 icon: const Icon(Icons.more_horiz, color: Color(0xFF64748B)),
 onSelected: (action) {
 if (action == 'edit') {
 _showRiskSignalEditor(signal: signal);
 } else if (action == 'delete') {
 _confirmDeleteRiskSignal(signal);
 }
 },
 itemBuilder: (context) => const [
 PopupMenuItem(
 value: 'edit',
 child: ListTile(
 dense: true,
 leading: Icon(Icons.edit_outlined),
 title: Text('Edit signal'),
 ),
 ),
 PopupMenuItem(
 value: 'delete',
 child: ListTile(
 dense: true,
 leading: Icon(Icons.delete_outline, color: Color(0xFFEF4444)),
 title: Text('Delete signal'),
 ),
 ),
 ],
 ),
 ],
 ),
 );
 }

 Color _riskStatusColor(String status) {
 switch (status.trim().toLowerCase()) {
 case 'blocked':
 return const Color(0xFFDC2626);
 case 'at risk':
 case 'needs review':
 return const Color(0xFFF59E0B);
 case 'on track':
 return const Color(0xFF10B981);
 default:
 return const Color(0xFF64748B);
 }
 }

 static const List<String> _contractTypeOptions = [
 'Service Level Agreement',
 'Software License',
 'Procurement',
 'Consulting Agreement',
 'NDA',
 'Employment',
 'Lease',
 ];

 static const List<String> _renewalActionOptions = [
 'Renew',
 'Renegotiate',
 'Extend',
 'Terminate',
 ];

 static const List<String> _renewalStatusOptions = [
 'Not Started',
 'In Negotiation',
 'Draft Ready',
 'Pending Signature',
 'Completed',
 ];

 static const List<int> _daysLeftOptions = [
 0, 7, 14, 21, 30, 45, 60, 90, 120, 180, 270, 365,
 ];

 Future<void> _showRenewalEntryEditor({_RenewalLaneData? entry}) async {
 final isEdit = entry != null;
 final nameController = TextEditingController(text: entry?.contractName ?? '');
 var selectedType = _contractTypeOptions.contains(entry?.contractType)
 ? entry!.contractType
 : _contractTypeOptions.first;
 DateTime? selectedExpiryDate;
 if (entry?.expiryDate != null && entry!.expiryDate.isNotEmpty) {
 selectedExpiryDate = DateFormat('MMM dd, yyyy').tryParse(entry.expiryDate) ??
 DateFormat('yyyy-MM-dd').tryParse(entry.expiryDate);
 }
 var selectedDaysLeft = entry?.daysUntilExpiry ?? 30;
 var selectedAction = _renewalActionOptions.contains(entry?.renewalAction)
 ? (entry?.renewalAction ?? 'Renew')
 : 'Renew';
 var selectedStatus = _renewalStatusOptions.contains(entry?.status)
 ? (entry?.status ?? 'Not Started')
 : 'Not Started';
 final ownerController = TextEditingController(text: entry?.owner ?? '');
 final valueController = TextEditingController(text: entry?.committedValue ?? '');
 final notesController = TextEditingController(text: entry?.notes ?? '');

 final saved = await showDialog<_RenewalLaneData>(
 context: context,
 builder: (dialogContext) {
 return StatefulBuilder(
 builder: (context, setDialogState) {
 return AlertDialog(
 title: Text(isEdit ? 'Edit renewal entry' : 'Add contract to pipeline'),
 content: SizedBox(
 width: 580,
 child: SingleChildScrollView(
 child: Column(
 mainAxisSize: MainAxisSize.min,
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 VoiceTextField(
 controller: nameController,
 decoration: const InputDecoration(
 labelText: 'Contract / Vendor name *',
 hintText: 'e.g. Cloud Infrastructure Services',
 isDense: true,
 ),
 ),
 const SizedBox(height: 12),
 Row(
 children: [
 Expanded(
 child: DropdownButtonFormField<String>(
 value: selectedType,
 decoration: const InputDecoration(
 labelText: 'Contract type',
 isDense: true,
 ),
 items: _contractTypeOptions
 .map((t) => DropdownMenuItem(value: t, child: Text(t, style: const TextStyle(fontSize: 12))))
 .toList(),
 onChanged: (value) {
 if (value == null) return;
 setDialogState(() => selectedType = value);
 },
 ),
 ),
 const SizedBox(width: 12),
 Expanded(
 child: DropdownButtonFormField<String>(
 value: selectedAction,
 decoration: const InputDecoration(
 labelText: 'Renewal action',
 isDense: true,
 ),
 items: _renewalActionOptions
 .map((a) => DropdownMenuItem(value: a, child: Text(a, style: const TextStyle(fontSize: 12))))
 .toList(),
 onChanged: (value) {
 if (value == null) return;
 setDialogState(() => selectedAction = value);
 },
 ),
 ),
 ],
 ),
 const SizedBox(height: 12),
 Row(
 children: [
 Expanded(
 child: GestureDetector(
 onTap: () async {
 final picked = await showDatePicker(
 context: context,
 initialDate: selectedExpiryDate ?? DateTime.now().add(const Duration(days: 90)),
 firstDate: DateTime(2020),
 lastDate: DateTime(2040),
 );
 if (picked != null) {
 setDialogState(() => selectedExpiryDate = picked);
 }
 },
 child: InputDecorator(
 decoration: const InputDecoration(
 labelText: 'Expiry date',
 isDense: true,
 suffixIcon: Icon(Icons.calendar_today, size: 18),
 ),
 child: Text(
 selectedExpiryDate != null
 ? DateFormat('MMM dd, yyyy').format(selectedExpiryDate!)
 : 'Select date',
 style: TextStyle(
 color: selectedExpiryDate != null ? null : Colors.grey,
 fontSize: 14,
 ),
 ),
 ),
 ),
 ),
 const SizedBox(width: 12),
 Expanded(
 child: DropdownButtonFormField<int>(
 value: _daysLeftOptions.contains(selectedDaysLeft) ? selectedDaysLeft : null,
 decoration: const InputDecoration(
 labelText: 'Days left',
 isDense: true,
 ),
 items: _daysLeftOptions
 .map((d) => DropdownMenuItem(
 value: d,
 child: Text(d == 0 ? 'Expired' : '$d days', style: const TextStyle(fontSize: 12)),
 ))
 .toList(),
 onChanged: (value) {
 if (value != null) setDialogState(() => selectedDaysLeft = value);
 },
 ),
 ),
 ],
 ),
 const SizedBox(height: 12),
 Row(
 children: [
 Expanded(
 child: VoiceTextField(
 controller: ownerController,
 decoration: const InputDecoration(
 labelText: 'Renewal owner',
 hintText: 'e.g. IT Director',
 isDense: true,
 ),
 ),
 ),
 const SizedBox(width: 12),
 Expanded(
 child: VoiceTextField(
 controller: valueController,
 decoration: const InputDecoration(
 labelText: 'Committed value',
 hintText: 'e.g. \$2.4M',
 isDense: true,
 ),
 ),
 ),
 ],
 ),
 const SizedBox(height: 12),
 DropdownButtonFormField<String>(
 value: selectedStatus,
 decoration: const InputDecoration(
 labelText: 'Renewal status',
 isDense: true,
 ),
 items: _renewalStatusOptions
 .map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 12))))
 .toList(),
 onChanged: (value) {
 if (value == null) return;
 setDialogState(() => selectedStatus = value);
 },
 ),
 const SizedBox(height: 12),
 VoiceTextField(
 controller: notesController,
 decoration: const InputDecoration(
 labelText: 'Notes',
 hintText: 'Renegotiation context, key terms, or blockers',
 isDense: true,
 ),
 maxLines: 3,
 ),
 ],
 ),
 ),
 ),
 actions: [
 TextButton(
 onPressed: () => Navigator.of(dialogContext).pop(),
 child: const Text('Cancel'),
 ),
 FilledButton(
 onPressed: () {
 if (nameController.text.trim().isEmpty) {
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(content: Text('Contract name is required.')),
 );
 return;
 }
 Navigator.of(dialogContext).pop(
 _RenewalLaneData(
 id: entry?.id ?? _newId(),
 contractName: nameController.text.trim(),
 contractType: selectedType,
 expiryDate: selectedExpiryDate != null
 ? DateFormat('MMM dd, yyyy').format(selectedExpiryDate!)
 : '',
 daysUntilExpiry: selectedDaysLeft,
 renewalAction: selectedAction,
 owner: ownerController.text.trim(),
 status: selectedStatus,
 committedValue: valueController.text.trim(),
 notes: notesController.text.trim(),
 ),
 );
 },
 child: Text(isEdit ? 'Save changes' : 'Add to pipeline'),
 ),
 ],
 );
 },
 );
 },
 );

 nameController.dispose();
 ownerController.dispose();
 valueController.dispose();
 notesController.dispose();

 if (saved == null) return;
 final index = _renewalLanes.indexWhere((item) => item.id == saved.id);
 setState(() {
 if (index == -1) {
 _renewalLanes.add(saved);
 } else {
 _renewalLanes[index] = saved;
 }
 });
 _scheduleSave();
 }

 Future<void> _confirmDeleteRenewalEntry(_RenewalLaneData entry) async {
 final confirmed = await showDialog<bool>(
 context: context,
 builder: (dialogContext) => AlertDialog(
 title: const Text('Remove from pipeline?'),
 content: Text(
 'Remove "${entry.contractName}" from the renewal pipeline.',
 ),
 actions: [
 TextButton(
 onPressed: () => Navigator.of(dialogContext).pop(false),
 child: const Text('Cancel'),
 ),
 FilledButton(
 style: FilledButton.styleFrom(
 backgroundColor: const Color(0xFFDC2626),
 foregroundColor: Colors.white,
 ),
 onPressed: () => Navigator.of(dialogContext).pop(true),
 child: const Text('Remove'),
 ),
 ],
 ),
 );

 if (confirmed == true) {
 setState(() => _renewalLanes.removeWhere((item) => item.id == entry.id));
 _scheduleSave();
 }
 }

 Future<void> _showRiskSignalEditor({_RiskSignalData? signal}) async {
 final formKey = GlobalKey<FormState>();
 final titleController = TextEditingController(text: signal?.title ?? '');
 final detailController = TextEditingController(text: signal?.detail ?? '');
 final ownerController = TextEditingController(text: signal?.owner ?? '');
 var selectedStatus = _riskStatusOptions.contains(signal?.status)
 ? signal!.status
 : _riskStatusOptions.first;

 final saved = await showDialog<_RiskSignalData>(
 context: context,
 builder: (dialogContext) {
 return StatefulBuilder(
 builder: (context, setDialogState) {
 return AlertDialog(
 title:
 Text(signal == null ? 'Add risk signal' : 'Edit risk signal'),
 content: SizedBox(
 width: 520,
 child: Form(
 key: formKey,
 child: Column(
 mainAxisSize: MainAxisSize.min,
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 VoiceTextFormField(
 controller: titleController,
 decoration: const InputDecoration(
 labelText: 'Signal title',
 hintText: 'e.g. Renewal risk flagged',
 ),
 validator: (value) {
 if ((value ?? '').trim().isEmpty) {
 return 'Add a clear signal title';
 }
 return null;
 },
 ),
 const SizedBox(height: 12),
 VoiceTextFormField(
 controller: detailController,
 decoration: const InputDecoration(
 labelText: 'Why it matters',
 hintText:
 'Describe the contract risk or follow-up needed',
 ),
 minLines: 2,
 maxLines: 4,
 ),
 const SizedBox(height: 12),
 Row(
 children: [
 Expanded(
 child: VoiceTextFormField(
 controller: ownerController,
 decoration: const InputDecoration(
 labelText: 'Owner',
 hintText: 'e.g. Legal',
 ),
 ),
 ),
 const SizedBox(width: 12),
 Expanded(
 child: DropdownButtonFormField<String>(
 value: selectedStatus,
 decoration: const InputDecoration(
 labelText: 'Status',
 ),
 items: _riskStatusOptions
 .map((status) => DropdownMenuItem(
 value: status,
 child: Text(status),
 ))
 .toList(),
 onChanged: (value) {
 if (value == null) return;
 setDialogState(() => selectedStatus = value);
 },
 ),
 ),
 ],
 ),
 ],
 ),
 ),
 ),
 actions: [
 TextButton(
 onPressed: () => Navigator.of(dialogContext).pop(),
 child: const Text('Cancel'),
 ),
 FilledButton(
 onPressed: () {
 if (!(formKey.currentState?.validate() ?? false)) return;
 Navigator.of(dialogContext).pop(
 _RiskSignalData(
 id: signal?.id ?? _newId(),
 title: titleController.text.trim(),
 detail: detailController.text.trim(),
 owner: ownerController.text.trim(),
 status: selectedStatus,
 ),
 );
 },
 child: Text(signal == null ? 'Add signal' : 'Save changes'),
 ),
 ],
 );
 },
 );
 },
 );

 titleController.dispose();
 detailController.dispose();
 ownerController.dispose();

 if (saved == null) return;
 final index = _riskSignals.indexWhere((item) => item.id == saved.id);
 setState(() {
 if (index == -1) {
 _riskSignals.add(saved);
 } else {
 _riskSignals[index] = saved;
 }
 });
 _scheduleSave();
 }

 void _deleteRiskSignal(String id) {
 setState(() => _riskSignals.removeWhere((item) => item.id == id));
 _scheduleSave();
 }

 Future<void> _confirmDeleteRiskSignal(_RiskSignalData signal) async {
 final confirmed = await showDialog<bool>(
 context: context,
 builder: (dialogContext) => AlertDialog(
 title: const Text('Delete risk signal?'),
 content: Text(
 'This will remove "${signal.title}" from the contract risk signals.',
 ),
 actions: [
 TextButton(
 onPressed: () => Navigator.of(dialogContext).pop(false),
 child: const Text('Cancel'),
 ),
 FilledButton(
 style: FilledButton.styleFrom(
 backgroundColor: const Color(0xFFDC2626),
 foregroundColor: Colors.white,
 ),
 onPressed: () => Navigator.of(dialogContext).pop(true),
 child: const Text('Delete'),
 ),
 ],
 ),
 );

 if (confirmed == true) {
 _deleteRiskSignal(signal.id);
 }
 }

 static const List<String> _approvalPriorityOptions = [
 'Critical',
 'High',
 'Medium',
 'Low',
 ];

 static const List<String> _approvalDepartmentOptions = [
 'Legal',
 'Finance',
 'Executive',
 'Project Office',
 'Engineering',
 'Risk',
 'Compliance',
 'Operations',
 ];

 static const List<String> _gateStatusOptions = [
 'Not Started',
 'In Review',
 'Pending',
 'Approved',
 'Rejected',
 'Waived',
 ];

 Future<void> _showApprovalCheckpointEditor(
 {_ApprovalCheckpointData? checkpoint}) async {
 final isEdit = checkpoint != null;
 final gateController = TextEditingController(text: checkpoint?.gate ?? '');
 final descController =
 TextEditingController(text: checkpoint?.description ?? '');
 final approverController =
 TextEditingController(text: checkpoint?.approver ?? '');
 var selectedDepartment =
 _approvalDepartmentOptions.contains(checkpoint?.department)
 ? checkpoint!.department
 : _approvalDepartmentOptions.first;
 var selectedPriority = _approvalPriorityOptions.contains(checkpoint?.priority)
 ? checkpoint!.priority
 : _approvalPriorityOptions[2];
 var selectedStatus = _gateStatusOptions.contains(checkpoint?.status)
 ? checkpoint!.status
 : _gateStatusOptions.first;
 final targetDateController =
 TextEditingController(text: checkpoint?.targetDate ?? '');
 final notesController = TextEditingController(text: checkpoint?.notes ?? '');

 final saved = await showDialog<_ApprovalCheckpointData>(
 context: context,
 builder: (dialogContext) {
 return StatefulBuilder(
 builder: (context, setDialogState) {
 return AlertDialog(
 title: Text(isEdit ? 'Edit approval gate' : 'Add approval gate'),
 content: SizedBox(
 width: 600,
 child: SingleChildScrollView(
 child: Column(
 mainAxisSize: MainAxisSize.min,
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 VoiceTextField(
 controller: gateController,
 decoration: const InputDecoration(
 labelText: 'Approval gate name *',
 hintText:
 'e.g. Legal Review & Compliance',
 isDense: true,
 ),
 ),
 const SizedBox(height: 12),
 VoiceTextField(
 controller: descController,
 decoration: const InputDecoration(
 labelText: 'Description',
 hintText:
 'What this approval covers and why it matters',
 isDense: true,
 ),
 minLines: 2,
 maxLines: 4,
 ),
 const SizedBox(height: 12),
 Row(
 children: [
 Expanded(
 child: VoiceTextField(
 controller: approverController,
 decoration: const InputDecoration(
 labelText: 'Approver *',
 hintText: 'e.g. General Counsel',
 isDense: true,
 ),
 ),
 ),
 const SizedBox(width: 12),
 Expanded(
 child: DropdownButtonFormField<String>(
 value: selectedDepartment,
 decoration: const InputDecoration(
 labelText: 'Department',
 isDense: true,
 ),
 items: _approvalDepartmentOptions
 .map((d) => DropdownMenuItem(
 value: d, child: Text(d, style: const TextStyle(fontSize: 13))))
 .toList(),
 onChanged: (value) {
 if (value == null) return;
 setDialogState(() => selectedDepartment = value);
 },
 ),
 ),
 ],
 ),
 const SizedBox(height: 12),
 Row(
 children: [
 Expanded(
 child: DropdownButtonFormField<String>(
 value: selectedPriority,
 decoration: const InputDecoration(
 labelText: 'Priority',
 isDense: true,
 ),
 items: _approvalPriorityOptions
 .map((p) => DropdownMenuItem(
 value: p, child: Text(p, style: const TextStyle(fontSize: 13))))
 .toList(),
 onChanged: (value) {
 if (value == null) return;
 setDialogState(() => selectedPriority = value);
 },
 ),
 ),
 const SizedBox(width: 12),
 Expanded(
 child: DropdownButtonFormField<String>(
 value: selectedStatus,
 decoration: const InputDecoration(
 labelText: 'Status',
 isDense: true,
 ),
 items: _gateStatusOptions
 .map((s) => DropdownMenuItem(
 value: s, child: Text(s, style: const TextStyle(fontSize: 13))))
 .toList(),
 onChanged: (value) {
 if (value == null) return;
 setDialogState(() => selectedStatus = value);
 },
 ),
 ),
 ],
 ),
 const SizedBox(height: 12),
 VoiceTextField(
 controller: targetDateController,
 decoration: const InputDecoration(
 labelText: 'Target date',
 hintText: 'e.g. 2025-03-15 or Before signing',
 isDense: true,
 ),
 ),
 const SizedBox(height: 12),
 VoiceTextField(
 controller: notesController,
 decoration: const InputDecoration(
 labelText: 'Notes',
 hintText: 'Additional context or prerequisites',
 isDense: true,
 ),
 maxLines: 2,
 ),
 ],
 ),
 ),
 ),
 actions: [
 TextButton(
 onPressed: () => Navigator.of(dialogContext).pop(),
 child: const Text('Cancel'),
 ),
 FilledButton(
 onPressed: () {
 if (gateController.text.trim().isEmpty) {
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(
 content: Text('Approval gate name is required.')),
 );
 return;
 }
 Navigator.of(dialogContext).pop(
 _ApprovalCheckpointData(
 id: checkpoint?.id ?? _newId(),
 gate: gateController.text.trim(),
 description: descController.text.trim(),
 approver: approverController.text.trim(),
 department: selectedDepartment,
 priority: selectedPriority,
 status: selectedStatus,
 targetDate: targetDateController.text.trim(),
 notes: notesController.text.trim(),
 ),
 );
 },
 child: Text(isEdit ? 'Save changes' : 'Add gate'),
 ),
 ],
 );
 },
 );
 },
 );

 gateController.dispose();
 descController.dispose();
 approverController.dispose();
 targetDateController.dispose();
 notesController.dispose();

 if (saved == null) return;
 final index = _approvalCheckpoints.indexWhere((item) => item.id == saved.id);
 setState(() {
 if (index == -1) {
 _approvalCheckpoints.add(saved);
 } else {
 _approvalCheckpoints[index] = saved;
 }
 });
 _scheduleSave();
 }

 Future<void> _confirmDeleteApprovalCheckpoint(
 _ApprovalCheckpointData checkpoint) async {
 final confirmed = await showDialog<bool>(
 context: context,
 builder: (dialogContext) => AlertDialog(
 title: const Text('Delete approval gate?'),
 content: Text(
 'This will remove "${checkpoint.gate}" from the approval readiness tracker.',
 ),
 actions: [
 TextButton(
 onPressed: () => Navigator.of(dialogContext).pop(false),
 child: const Text('Cancel'),
 ),
 FilledButton(
 style: FilledButton.styleFrom(
 backgroundColor: const Color(0xFFDC2626),
 foregroundColor: Colors.white,
 ),
 onPressed: () => Navigator.of(dialogContext).pop(true),
 child: const Text('Delete'),
 ),
 ],
 ),
 );

 if (confirmed == true) {
 setState(() => _approvalCheckpoints.removeWhere((item) => item.id == checkpoint.id));
 _scheduleSave();
 }
 }

 void _showAddContractDialog(BuildContext context) {
 final projectId = _projectId;
 if (projectId == null) {
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(
 content: Text('No project selected. Please open a project first.')),
 );
 return;
 }
 _showContractDialog(null, projectId);
 }

 // ignore: unused_element
 void _showEditContractDialog(BuildContext context, ContractModel contract) {
 final projectId = _projectId;
 if (projectId == null) {
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(
 content: Text('No project selected. Please open a project first.')),
 );
 return;
 }
 _showContractDialog(contract, projectId);
 }

 Future<void> _showContractDialog(
 ContractModel? contract, String projectId) async {
 final isEdit = contract != null;

 // Load External/Contractor roles from Staff Needs
 List<String> externalRoles = [];
 try {
 final staffRows =
 await ExecutionPhaseService.loadStaffingRows(projectId: projectId);
 externalRoles = staffRows
 .where((row) => !row.isInternal) // External/Contractor roles
 .map((row) => row.role)
 .where((role) => role.isNotEmpty)
 .toList();
 } catch (e) {
 debugPrint('Error loading staff roles: $e');
 }

 if (!mounted) return;

 final nameController = TextEditingController(text: contract?.name ?? '');
 final descriptionController =
 TextEditingController(text: contract?.description ?? '');
 final contractTypeController =
 TextEditingController(text: contract?.contractType ?? '');
 final paymentTypeController =
 TextEditingController(text: contract?.paymentType ?? '');
 var selectedStatus = contract?.status ?? 'Draft';
 final estimatedValueController =
 TextEditingController(text: contract?.estimatedValue.toString() ?? '0');
 // Key Terms (scope) - use AutoBulletTextController
 final scopeController =
 contract?.scope != null && contract!.scope.isNotEmpty
 ? AutoBulletTextController(text: contract.scope)
 : AutoBulletTextController();
 final disciplineController =
 TextEditingController(text: contract?.discipline ?? '');
 // Contract Notes - regular TextEditingController (prose)
 final notesController =
 RichTextEditingController(text: contract?.notes ?? '');
 DateTime? startDate = contract?.startDate;
 DateTime? endDate = contract?.endDate;

 showDialog(
 context: context,
 builder: (context) => StatefulBuilder(
 builder: (context, setDialogState) => AlertDialog(
 title: Text(isEdit ? 'Edit Contract' : 'Add New Contract'),
 content: SingleChildScrollView(
 child: Column(
 mainAxisSize: MainAxisSize.min,
 children: [
 // Vendor/Party Name with suggestions from External roles
 if (externalRoles.isNotEmpty && !isEdit) ...[
 Text(
 'Suggested from External/Contractor roles:',
 style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
 ),
 Wrap(
 spacing: 6,
 runSpacing: 6,
 children: externalRoles.take(5).map((role) {
 return ActionChip(
 label: Text(role, style: const TextStyle(fontSize: 11)),
 onPressed: () {
 nameController.text = role;
 setDialogState(() {});
 },
 backgroundColor: const Color(0xFFF3F4F6),
 );
 }).toList(),
 ),
 const SizedBox(height: 12),
 ],
 VoiceTextField(
 controller: nameController,
 decoration: const InputDecoration(
 labelText: 'Vendor/Party Name *',
 isDense: true,
 ),
 ),
 const SizedBox(height: 12),
 VoiceTextField(
 controller: descriptionController,
 decoration: const InputDecoration(
 labelText: 'Description *',
 isDense: true,
 ),
 maxLines: 2,
 ),
 const SizedBox(height: 12),
 DropdownButtonFormField<String>(
 value: contractTypeController.text.isEmpty
 ? null
 : contractTypeController.text,
 decoration: const InputDecoration(
 labelText: 'Contract Type *',
 isDense: true,
 ),
 items: const [
 'Service Level Agreement (SLA)',
 'NDA',
 'Procurement',
 'Employment',
 ]
 .map((type) => DropdownMenuItem(
 value: type,
 child: Text(type,
 style: const TextStyle(fontSize: 13)),
 ))
 .toList(),
 onChanged: (v) {
 if (v != null) {
 contractTypeController.text = v;
 setDialogState(() {});
 }
 },
 ),
 const SizedBox(height: 12),
 VoiceTextField(
 controller: paymentTypeController,
 decoration: const InputDecoration(
 labelText: 'Payment Type *',
 isDense: true,
 ),
 ),
 const SizedBox(height: 12),
 DropdownButtonFormField<String>(
 value: selectedStatus.isEmpty ? null : selectedStatus,
 decoration: const InputDecoration(
 labelText: 'Status *',
 isDense: true,
 ),
 items: const [
 'Draft',
 'Signed',
 'Active',
 'Expired',
 ]
 .map((status) => DropdownMenuItem(
 value: status,
 child: Text(status,
 style: const TextStyle(fontSize: 13)),
 ))
 .toList(),
 onChanged: (v) {
 setDialogState(() => selectedStatus = v ?? 'Draft');
 },
 ),
 const SizedBox(height: 12),
 VoiceTextField(
 controller: estimatedValueController,
 decoration: const InputDecoration(
 labelText: 'Total Value *',
 hintText: 'e.g., 1000000',
 isDense: true,
 ),
 keyboardType: TextInputType.number,
 ),
 const SizedBox(height: 12),
 ListTile(
 title: Text(
 'Effective Date: ${startDate != null ? DateFormat('MMM dd, yyyy').format(startDate!) : 'Not set'}'),
 trailing: const Icon(Icons.calendar_today, size: 18),
 onTap: () async {
 final date = await showDatePicker(
 context: context,
 initialDate: startDate ?? DateTime.now(),
 firstDate: DateTime(2020),
 lastDate: DateTime(2030),
 );
 if (date != null) setDialogState(() => startDate = date);
 },
 ),
 ListTile(
 title: Text(
 'Expiry Date: ${endDate != null ? DateFormat('MMM dd, yyyy').format(endDate!) : 'Not set'}'),
 trailing: const Icon(Icons.calendar_today, size: 18),
 onTap: () async {
 final date = await showDatePicker(
 context: context,
 initialDate: endDate ?? DateTime.now(),
 firstDate: DateTime(2020),
 lastDate: DateTime(2030),
 );
 if (date != null) setDialogState(() => endDate = date);
 },
 ),
 const SizedBox(height: 12),
 VoiceTextField(
 controller: scopeController,
 decoration: const InputDecoration(
 labelText: 'Key Terms',
 hintText: 'Use "." bullet format',
 isDense: true,
 ),
 maxLines: 5,
 ),
 const SizedBox(height: 12),
 VoiceTextField(
 controller: disciplineController,
 decoration: const InputDecoration(
 labelText: 'Discipline',
 isDense: true,
 ),
 ),
 const SizedBox(height: 12),
 const SizedBox(height: 6),
 VoiceTextField(
 controller: notesController,
 decoration: const InputDecoration(
 labelText: 'Contract Notes',
 hintText: 'Prose description, no bullets',
 isDense: true,
 ),
 maxLines: 3,
 ),
 ],
 ),
 ),
 actions: [
 TextButton(
 onPressed: () => Navigator.pop(context),
 child: const Text('Cancel'),
 ),
 ElevatedButton(
 onPressed: () async {
 if (nameController.text.isEmpty ||
 descriptionController.text.isEmpty ||
 startDate == null ||
 endDate == null) {
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(
 content: Text('Please fill in all required fields')),
 );
 return;
 }

 try {
 final user = FirebaseAuth.instance.currentUser;
 final estimatedValue =
 double.tryParse(estimatedValueController.text) ?? 0.0;

 if (isEdit) {
 await ContractService.updateContract(
 projectId: projectId,
 contractId: contract.id,
 name: nameController.text.trim(),
 description: descriptionController.text.trim(),
 contractType: contractTypeController.text.trim(),
 paymentType: paymentTypeController.text.trim(),
 status: selectedStatus,
 estimatedValue: estimatedValue,
 startDate: startDate!,
 endDate: endDate!,
 scope: scopeController.text.trim(),
 discipline: disciplineController.text.trim(),
 notes: notesController.text.trim().isEmpty
 ? null
 : notesController.text.trim(),
 );
 // Sync to Progress Tracking budget
 final updatedContract = ContractModel(
 id: contract.id,
 projectId: projectId,
 name: nameController.text.trim(),
 description: descriptionController.text.trim(),
 contractType: contractTypeController.text.trim(),
 paymentType: paymentTypeController.text.trim(),
 status: selectedStatus,
 estimatedValue: estimatedValue,
 startDate: startDate!,
 endDate: endDate!,
 scope: scopeController.text.trim(),
 discipline: disciplineController.text.trim(),
 notes: notesController.text.trim(),
 createdById: contract.createdById,
 createdByEmail: contract.createdByEmail,
 createdByName: contract.createdByName,
 createdAt: contract.createdAt,
 updatedAt: DateTime.now(),
 );
 await _syncContractValueToBudget(updatedContract);
 } else {
 final contractId = await ContractService.createContract(
 projectId: projectId,
 name: nameController.text.trim(),
 description: descriptionController.text.trim(),
 contractType: contractTypeController.text.trim(),
 paymentType: paymentTypeController.text.trim(),
 status: selectedStatus,
 estimatedValue: estimatedValue,
 startDate: startDate!,
 endDate: endDate!,
 scope: scopeController.text.trim(),
 discipline: disciplineController.text.trim(),
 notes: notesController.text.trim(),
 createdById: user?.uid ?? '',
 createdByEmail: user?.email ?? '',
 createdByName: user?.displayName ??
 user?.email?.split('@').first ??
 '',
 );
 // Sync to Progress Tracking budget
 final newContract = await ContractService.getContract(
 projectId: projectId,
 contractId: contractId,
 );
 if (newContract != null) {
 await _syncContractValueToBudget(newContract);
 }
 }

 if (context.mounted) {
 Navigator.pop(context);
 }
 } catch (e) {
 if (context.mounted) {
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(content: Text('Error: $e')),
 );
 }
 }
 },
 child: Text(isEdit ? 'Update' : 'Add'),
 ),
 ],
 ),
 ),
 );
 }

 // ignore: unused_element
 void _showDeleteContractDialog(BuildContext context, ContractModel contract) {
 final projectId = _projectId;
 if (projectId == null) {
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(
 content: Text('No project selected. Please open a project first.')),
 );
 return;
 }

 showDialog(
 context: context,
 builder: (context) => AlertDialog(
 title: const Text('Delete Contract'),
 content: Text(
 'Are you sure you want to delete "${contract.name}"? This action cannot be undone.'),
 actions: [
 TextButton(
 onPressed: () => Navigator.pop(context),
 child: const Text('Cancel'),
 ),
 ElevatedButton(
 onPressed: () async {
 try {
 await ContractService.deleteContract(
 projectId: projectId, contractId: contract.id);
 if (context.mounted) {
 Navigator.pop(context);
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(
 content: Text('Contract deleted successfully')),
 );
 }
 } catch (e) {
 if (context.mounted) {
 Navigator.pop(context);
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(content: Text('Error deleting contract: $e')),
 );
 }
 }
 },
 style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
 child: const Text('Delete', style: TextStyle(color: Colors.white)),
 ),
 ],
 ),
 );
 }

 Future<void> _exportPdf() async {
 final projectData = ProjectDataHelper.getData(context);
 await PdfExportHelper.exportScreenPdf(
 context: context,
 screenTitle: 'Contracts Tracking',
 sections: [
 PdfSection.keyValue('Project Info', [
 {'Project Name': projectData.projectName ?? 'N/A'},
 {'Solution Title': projectData.solutionTitle ?? 'N/A'},
 ]),
 PdfSection.text('Notes', projectData.planningNotes['planning_contracts_tracking_notes'] ?? 'No data recorded.'),
 ],
 );
 }
}

class _PanelShell extends StatelessWidget {
 const _PanelShell({
 required this.title,
 required this.subtitle,
 required this.child,
 this.trailing,
 });

 final String title;
 final String subtitle;
 final Widget child;
 final Widget? trailing;

 @override
 Widget build(BuildContext context) {
 return Container(
 padding: const EdgeInsets.all(20),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(16),
 border: Border.all(color: const Color(0xFFE2E8F0)),
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
 fontSize: 16, fontWeight: FontWeight.w700)),
 const SizedBox(height: 4),
 Text(subtitle,
 style: const TextStyle(
 fontSize: 12, color: Color(0xFF64748B))),
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

class _ApprovalGateRow extends StatefulWidget {
 const _ApprovalGateRow({
 required this.checkpoint,
 required this.onEdit,
 required this.onDelete,
 required this.showDivider,
 });

 final _ApprovalCheckpointData checkpoint;
 final VoidCallback onEdit;
 final VoidCallback onDelete;
 final bool showDivider;

 @override
 State<_ApprovalGateRow> createState() => _ApprovalGateRowState();
}

class _ApprovalGateRowState extends State<_ApprovalGateRow> {
 bool _isHovering = false;

 Color _priorityColor(String priority) {
 switch (priority) {
 case 'Critical':
 return const Color(0xFFDC2626);
 case 'High':
 return const Color(0xFFF59E0B);
 case 'Medium':
 return const Color(0xFFD97706);
 case 'Low':
 return const Color(0xFF6B7280);
 default:
 return const Color(0xFF6B7280);
 }
 }

 Color _statusColor(String status) {
 switch (status) {
 case 'Approved':
 return const Color(0xFF10B981);
 case 'In Review':
 return const Color(0xFFD97706);
 case 'Pending':
 return const Color(0xFFF59E0B);
 case 'Rejected':
 return const Color(0xFFEF4444);
 case 'Waived':
 return const Color(0xFF8B5CF6);
 case 'Not Started':
 return const Color(0xFF9CA3AF);
 default:
 return const Color(0xFF9CA3AF);
 }
 }

 IconData _statusIcon(String status) {
 switch (status) {
 case 'Approved':
 return Icons.check_circle_outline;
 case 'In Review':
 return Icons.sync_outlined;
 case 'Pending':
 return Icons.schedule_outlined;
 case 'Rejected':
 return Icons.cancel_outlined;
 case 'Waived':
 return Icons.skip_next_outlined;
 case 'Not Started':
 return Icons.radio_button_unchecked;
 default:
 return Icons.radio_button_unchecked;
 }
 }

 Color _deptColor(String dept) {
 switch (dept) {
 case 'Legal':
 return const Color(0xFF7C3AED);
 case 'Finance':
 return const Color(0xFF059669);
 case 'Executive':
 return const Color(0xFFDC2626);
 case 'Engineering':
 return const Color(0xFFD97706);
 case 'Risk':
 return const Color(0xFFEA580C);
 case 'Compliance':
 return const Color(0xFF0D9488);
 case 'Project Office':
 return const Color(0xFF4F46E5);
 case 'Operations':
 return const Color(0xFF64748B);
 default:
 return const Color(0xFF64748B);
 }
 }

 @override
 Widget build(BuildContext context) {
 final c = widget.checkpoint;
 final statusColor = _statusColor(c.status);
 final priorityColor = _priorityColor(c.priority);
 final deptColor = _deptColor(c.department);

 return MouseRegion(
 onEnter: (_) => Future.microtask(() {
 if (mounted) setState(() => _isHovering = true);
 }),
 onExit: (_) => Future.microtask(() {
 if (mounted) setState(() => _isHovering = false);
 }),
 child: Column(
 children: [
 Container(
 color: _isHovering ? const Color(0xFFF9FAFB) : Colors.white,
 padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
 child: Row(
 crossAxisAlignment: CrossAxisAlignment.center,
 children: [
 // Gate name + description
 Expanded(
 flex: 5,
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 c.gate.trim().isEmpty ? 'Untitled gate' : c.gate,
 style: const TextStyle(
 fontSize: 12,
 fontWeight: FontWeight.w700,
 color: Color(0xFF111827),
 ),
 ),
 if (c.description.trim().isNotEmpty) ...[
 const SizedBox(height: 4),
 Text(
 c.description,
 maxLines: 2,
 overflow: TextOverflow.ellipsis,
 style: const TextStyle(
 fontSize: 11,
 fontWeight: FontWeight.w500,
 color: Color(0xFF6B7280),
 height: 1.4,
 ),
 ),
 ],
 ],
 ),
 ),
 // Approver
 Expanded(
 flex: 3,
 child: Center(
 child: Text(
 c.approver.trim().isEmpty ? 'Unassigned' : c.approver,
 style: TextStyle(
 fontSize: 12,
 fontWeight: FontWeight.w600,
 color: c.approver.trim().isEmpty
 ? const Color(0xFF9CA3AF)
 : const Color(0xFF334155),
 ),
 ),
 ),
 ),
 // Department
 SizedBox(
 width: 130,
 child: Center(
 child: Container(
 padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
 decoration: BoxDecoration(
 color: deptColor.withOpacity(0.08),
 borderRadius: BorderRadius.circular(6),
 border: Border.all(color: deptColor.withOpacity(0.18)),
 ),
 child: Text(
 c.department,
 textAlign: TextAlign.center,
 style: TextStyle(
 fontSize: 10,
 fontWeight: FontWeight.w700,
 color: deptColor,
 ),
 ),
 ),
 ),
 ),
 // Priority
 SizedBox(
 width: 120,
 child: Center(
 child: Container(
 padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
 decoration: BoxDecoration(
 color: priorityColor.withOpacity(0.08),
 borderRadius: BorderRadius.circular(6),
 ),
 child: Row(
 mainAxisSize: MainAxisSize.min,
 children: [
 Container(
 width: 6,
 height: 6,
 decoration: BoxDecoration(
 color: priorityColor,
 shape: BoxShape.circle,
 ),
 ),
 const SizedBox(width: 6),
 Text(
 c.priority,
 style: TextStyle(
 fontSize: 10,
 fontWeight: FontWeight.w700,
 color: priorityColor,
 ),
 ),
 ],
 ),
 ),
 ),
 ),
 // Status
 SizedBox(
 width: 130,
 child: Center(
 child: Container(
 padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
 decoration: BoxDecoration(
 color: statusColor.withOpacity(0.1),
 borderRadius: BorderRadius.circular(8),
 ),
 child: Row(
 mainAxisSize: MainAxisSize.min,
 children: [
 Icon(_statusIcon(c.status), size: 13, color: statusColor),
 const SizedBox(width: 6),
 Flexible(
 child: Text(
 c.status,
 overflow: TextOverflow.ellipsis,
 style: TextStyle(
 fontSize: 10,
 fontWeight: FontWeight.w700,
 color: statusColor,
 ),
 ),
 ),
 ],
 ),
 ),
 ),
 ),
 // Target date
 SizedBox(
 width: 130,
 child: Center(
 child: Text(
 c.targetDate.trim().isEmpty ? '—' : c.targetDate,
 style: const TextStyle(
 fontSize: 11,
 fontWeight: FontWeight.w600,
 color: Color(0xFF475569),
 ),
 ),
 ),
 ),
 // Actions
 SizedBox(
 width: 60,
 child: _isHovering
 ? Row(
 mainAxisSize: MainAxisSize.min,
 children: [
 IconButton(
 icon: const Icon(Icons.edit_outlined, size: 15, color: Color(0xFF64748B)),
 onPressed: widget.onEdit,
 tooltip: 'Edit',
 padding: EdgeInsets.zero,
 constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
 ),
 IconButton(
 icon: const Icon(Icons.delete_outline, size: 15, color: Color(0xFFEF4444)),
 onPressed: widget.onDelete,
 tooltip: 'Delete',
 padding: EdgeInsets.zero,
 constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
 ),
 IconButton(
   onPressed: () {
     ScaffoldMessenger.of(context).showSnackBar(
       const SnackBar(content: Text('KAZ AI: Generating suggestions...'), duration: Duration(seconds: 2)),
     );
   },
   icon: const Icon(Icons.auto_awesome, size: 16, color: Color(0xFFF59E0B)),
   tooltip: 'KAZ AI',
   padding: EdgeInsets.zero,
   constraints: const BoxConstraints(minWidth: 28),
 ),
 ],
 )
 : const SizedBox(width: 56),
 ),
 ],
 ),
 ),
 if (widget.showDivider)
 const Divider(height: 1, thickness: 1, color: Color(0xFFE5E7EB)),
 ],
 ),
 );
 }
}

class _RenewalEntryRow extends StatefulWidget {
 const _RenewalEntryRow({
 required this.entry,
 required this.onEdit,
 required this.onDelete,
 required this.showDivider,
 });

 final _RenewalLaneData entry;
 final VoidCallback onEdit;
 final VoidCallback onDelete;
 final bool showDivider;

 @override
 State<_RenewalEntryRow> createState() => _RenewalEntryRowState();
}

class _RenewalEntryRowState extends State<_RenewalEntryRow> {
 bool _isHovering = false;

 Color _typeColor(String type) {
 switch (type) {
 case 'SLA':
 return const Color(0xFFD97706);
 case 'NDA':
 return const Color(0xFF7C3AED);
 case 'MSA':
 return const Color(0xFF059669);
 case 'License':
 return const Color(0xFFEA580C);
 case 'Lease':
 return const Color(0xFF0D9488);
 case 'Insurance':
 return const Color(0xFFDC2626);
 case 'Warranty':
 return const Color(0xFF8B5CF6);
 case 'Subscription':
 return const Color(0xFF4F46E5);
 default:
 return const Color(0xFF64748B);
 }
 }

 Color _actionColor(String action) {
 switch (action) {
 case 'Renew':
 return const Color(0xFF10B981);
 case 'Renegotiate':
 return const Color(0xFFF59E0B);
 case 'Terminate':
 return const Color(0xFFEF4444);
 case 'Extend':
 return const Color(0xFFD97706);
 case 'Consolidate':
 return const Color(0xFF8B5CF6);
 case 'Transfer':
 return const Color(0xFF0D9488);
 default:
 return const Color(0xFF64748B);
 }
 }

 Color _renewalStatusColor(String status) {
 switch (status) {
 case 'On Track':
 return const Color(0xFF10B981);
 case 'In Progress':
 return const Color(0xFFD97706);
 case 'At Risk':
 return const Color(0xFFF59E0B);
 case 'Overdue':
 return const Color(0xFFEF4444);
 case 'Completed':
 return const Color(0xFF059669);
 case 'Not Started':
 return const Color(0xFF9CA3AF);
 default:
 return const Color(0xFF9CA3AF);
 }
 }

 IconData _renewalStatusIcon(String status) {
 switch (status) {
 case 'On Track':
 return Icons.check_circle_outline;
 case 'In Progress':
 return Icons.sync_outlined;
 case 'At Risk':
 return Icons.warning_amber_outlined;
 case 'Overdue':
 return Icons.error_outline;
 case 'Completed':
 return Icons.task_alt_outlined;
 case 'Not Started':
 return Icons.radio_button_unchecked;
 default:
 return Icons.radio_button_unchecked;
 }
 }

 @override
 Widget build(BuildContext context) {
 final e = widget.entry;
 final urgencyColor = e.urgencyColor;
 final typeColor = _typeColor(e.contractType);
 final actionColor = _actionColor(e.renewalAction);
 final statusColor = _renewalStatusColor(e.status);

 return MouseRegion(
 onEnter: (_) => setState(() => _isHovering = true),
 onExit: (_) => setState(() => _isHovering = false),
 child: Column(
 children: [
 Container(
 color: _isHovering ? const Color(0xFFF9FAFB) : Colors.white,
 padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
 child: Row(
 crossAxisAlignment: CrossAxisAlignment.center,
 children: [
 // Contract name + value
 Expanded(
 flex: 4,
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 e.contractName.trim().isEmpty
 ? 'Unnamed contract'
 : e.contractName,
 style: const TextStyle(
 fontSize: 12,
 fontWeight: FontWeight.w700,
 color: Color(0xFF111827),
 ),
 ),
 if (e.committedValue.trim().isNotEmpty) ...[
 const SizedBox(height: 3),
 Text(
 e.committedValue,
 style: const TextStyle(
 fontSize: 11,
 fontWeight: FontWeight.w600,
 color: Color(0xFF059669),
 ),
 ),
 ],
 ],
 ),
 ),
 // Type
 SizedBox(
 width: 110,
 child: Center(
 child: Container(
 padding:
 const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
 decoration: BoxDecoration(
 color: typeColor.withOpacity(0.08),
 borderRadius: BorderRadius.circular(6),
 border:
 Border.all(color: typeColor.withOpacity(0.18)),
 ),
 child: Text(
 e.contractType,
 textAlign: TextAlign.center,
 style: TextStyle(
 fontSize: 10,
 fontWeight: FontWeight.w700,
 color: typeColor,
 ),
 ),
 ),
 ),
 ),
 // Expiry date
 SizedBox(
 width: 120,
 child: Center(
 child: Text(
 e.expiryDate.trim().isEmpty ? '—' : e.expiryDate,
 style: const TextStyle(
 fontSize: 11,
 fontWeight: FontWeight.w600,
 color: Color(0xFF475569),
 ),
 ),
 ),
 ),
 // Urgency window
 SizedBox(
 width: 130,
 child: Center(
 child: Container(
 padding:
 const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
 decoration: BoxDecoration(
 color: urgencyColor.withOpacity(0.08),
 borderRadius: BorderRadius.circular(6),
 ),
 child: Row(
 mainAxisSize: MainAxisSize.min,
 children: [
 Container(
 width: 6,
 height: 6,
 decoration: BoxDecoration(
 color: urgencyColor,
 shape: BoxShape.circle,
 ),
 ),
 const SizedBox(width: 6),
 Flexible(
 child: Text(
 e.urgencyWindow,
 overflow: TextOverflow.ellipsis,
 style: TextStyle(
 fontSize: 10,
 fontWeight: FontWeight.w700,
 color: urgencyColor,
 ),
 ),
 ),
 ],
 ),
 ),
 ),
 ),
 // Action
 SizedBox(
 width: 130,
 child: Center(
 child: Container(
 padding:
 const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
 decoration: BoxDecoration(
 color: actionColor.withOpacity(0.08),
 borderRadius: BorderRadius.circular(6),
 ),
 child: Text(
 e.renewalAction,
 textAlign: TextAlign.center,
 style: TextStyle(
 fontSize: 10,
 fontWeight: FontWeight.w700,
 color: actionColor,
 ),
 ),
 ),
 ),
 ),
 // Status
 SizedBox(
 width: 130,
 child: Center(
 child: Container(
 padding:
 const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
 decoration: BoxDecoration(
 color: statusColor.withOpacity(0.1),
 borderRadius: BorderRadius.circular(8),
 ),
 child: Row(
 mainAxisSize: MainAxisSize.min,
 children: [
 Icon(_renewalStatusIcon(e.status),
 size: 13, color: statusColor),
 const SizedBox(width: 6),
 Flexible(
 child: Text(
 e.status,
 overflow: TextOverflow.ellipsis,
 style: TextStyle(
 fontSize: 10,
 fontWeight: FontWeight.w700,
 color: statusColor,
 ),
 ),
 ),
 ],
 ),
 ),
 ),
 ),
 // Owner
 SizedBox(
 width: 120,
 child: Center(
 child: Text(
 e.owner.trim().isEmpty ? 'Unassigned' : e.owner,
 style: TextStyle(
 fontSize: 12,
 fontWeight: FontWeight.w600,
 color: e.owner.trim().isEmpty
 ? const Color(0xFF9CA3AF)
 : const Color(0xFF334155),
 ),
 ),
 ),
 ),
 // Actions
 SizedBox(
 width: 60,
 child: _isHovering
 ? Row(
 mainAxisSize: MainAxisSize.min,
 children: [
 IconButton(
 icon: const Icon(Icons.edit_outlined,
 size: 15, color: Color(0xFF64748B)),
 onPressed: widget.onEdit,
 tooltip: 'Edit',
 padding: EdgeInsets.zero,
 constraints:
 const BoxConstraints(minWidth: 28, minHeight: 28),
 ),
 IconButton(
 icon: const Icon(Icons.delete_outline,
 size: 15, color: Color(0xFFEF4444)),
 onPressed: widget.onDelete,
 tooltip: 'Delete',
 padding: EdgeInsets.zero,
 constraints:
 const BoxConstraints(minWidth: 28, minHeight: 28),
 ),
 IconButton(
   onPressed: () {
     ScaffoldMessenger.of(context).showSnackBar(
       const SnackBar(content: Text('KAZ AI: Generating suggestions...'), duration: Duration(seconds: 2)),
     );
   },
   icon: const Icon(Icons.auto_awesome, size: 16, color: Color(0xFFF59E0B)),
   tooltip: 'KAZ AI',
   padding: EdgeInsets.zero,
   constraints: const BoxConstraints(minWidth: 28),
 ),
 ],
 )
 : const SizedBox(width: 56),
 ),
 ],
 ),
 ),
 if (widget.showDivider)
 const Divider(height: 1, thickness: 1, color: Color(0xFFE5E7EB)),
 ],
 ),
 );
 }
}

class _RiskSignalPill extends StatelessWidget {
 const _RiskSignalPill({
 required this.icon,
 required this.label,
 this.color = const Color(0xFF64748B),
 });

 final IconData icon;
 final String label;
 final Color color;

 @override
 Widget build(BuildContext context) {
 return Container(
 padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
 decoration: BoxDecoration(
 color: color.withOpacity(0.08),
 borderRadius: BorderRadius.circular(999),
 border: Border.all(color: color.withOpacity(0.18)),
 ),
 child: Row(
 mainAxisSize: MainAxisSize.min,
 children: [
 Icon(icon, size: 14, color: color),
 const SizedBox(width: 6),
 Text(
 label,
 style: TextStyle(
 fontSize: 11,
 fontWeight: FontWeight.w700,
 color: color,
 ),
 ),
 ],
 ),
 );
 }
}

class _RenewalLaneData {
 const _RenewalLaneData({
 required this.id,
 required this.contractName,
 this.contractType = 'SLA',
 this.expiryDate = '',
 this.daysUntilExpiry,
 this.renewalAction = 'Renew',
 this.owner = '',
 this.status = 'Not Started',
 this.committedValue = '',
 this.notes = '',
 });

 final String id;
 final String contractName;
 final String contractType;
 final String expiryDate;
 final int? daysUntilExpiry;
 final String renewalAction;
 final String owner;
 final String status;
 final String committedValue;
 final String notes;

 String get urgencyWindow {
 final days = daysUntilExpiry;
 if (days == null) return 'No date';
 if (days <= 0) return 'Expired';
 if (days <= 30) return 'Immediate';
 if (days <= 60) return 'Approaching';
 if (days <= 90) return 'Planning';
 return 'Stable';
 }

 Color get urgencyColor {
 final days = daysUntilExpiry;
 if (days == null) return const Color(0xFF9CA3AF);
 if (days <= 0) return const Color(0xFFDC2626);
 if (days <= 30) return const Color(0xFFEF4444);
 if (days <= 60) return const Color(0xFFF97316);
 if (days <= 90) return const Color(0xFFD97706);
 return const Color(0xFF10B981);
 }

 _RenewalLaneData copyWith({
 String? contractName,
 String? contractType,
 String? expiryDate,
 int? daysUntilExpiry,
 String? renewalAction,
 String? owner,
 String? status,
 String? committedValue,
 String? notes,
 }) {
 return _RenewalLaneData(
 id: id,
 contractName: contractName ?? this.contractName,
 contractType: contractType ?? this.contractType,
 expiryDate: expiryDate ?? this.expiryDate,
 daysUntilExpiry: daysUntilExpiry ?? this.daysUntilExpiry,
 renewalAction: renewalAction ?? this.renewalAction,
 owner: owner ?? this.owner,
 status: status ?? this.status,
 committedValue: committedValue ?? this.committedValue,
 notes: notes ?? this.notes,
 );
 }

 Map<String, dynamic> toMap() => {
 'id': id,
 'contractName': contractName,
 'contractType': contractType,
 'expiryDate': expiryDate,
 'daysUntilExpiry': daysUntilExpiry,
 'renewalAction': renewalAction,
 'owner': owner,
 'status': status,
 'committedValue': committedValue,
 'notes': notes,
 };

 static List<_RenewalLaneData> fromList(dynamic data) {
 if (data is! List) return [];
 return data.map((item) {
 final map = Map<String, dynamic>.from(item as Map? ?? {});
 // Backward-compat: migrate old label/count/note/color fields
 final oldLabel = map['label']?.toString() ?? '';
 return _RenewalLaneData(
 id: map['id']?.toString() ??
 DateTime.now().microsecondsSinceEpoch.toString(),
 contractName: map['contractName']?.toString() ??
 (oldLabel.isNotEmpty ? oldLabel : ''),
 contractType: map['contractType']?.toString() ?? 'SLA',
 expiryDate: map['expiryDate']?.toString() ?? '',
 daysUntilExpiry: map['daysUntilExpiry'] is int
 ? map['daysUntilExpiry'] as int
 : null,
 renewalAction: map['renewalAction']?.toString() ?? 'Renew',
 owner: map['owner']?.toString() ?? '',
 status: map['status']?.toString() ?? 'Not Started',
 committedValue: map['committedValue']?.toString() ?? '',
 notes: map['notes']?.toString() ?? map['note']?.toString() ?? '',
 );
 }).toList();
 }
}

class _RiskSignalData {
 const _RiskSignalData({
 required this.id,
 required this.title,
 required this.detail,
 required this.owner,
 required this.status,
 });

 final String id;
 final String title;
 final String detail;
 final String owner;
 final String status;

 _RiskSignalData copyWith(
 {String? title, String? detail, String? owner, String? status}) {
 return _RiskSignalData(
 id: id,
 title: title ?? this.title,
 detail: detail ?? this.detail,
 owner: owner ?? this.owner,
 status: status ?? this.status,
 );
 }

 Map<String, dynamic> toMap() => {
 'id': id,
 'title': title,
 'detail': detail,
 'owner': owner,
 'status': status,
 };

 static List<_RiskSignalData> fromList(dynamic data) {
 if (data is! List) return [];
 return data.map((item) {
 final map = Map<String, dynamic>.from(item as Map? ?? {});
 return _RiskSignalData(
 id: map['id']?.toString() ??
 DateTime.now().microsecondsSinceEpoch.toString(),
 title: map['title']?.toString() ?? '',
 detail: map['detail']?.toString() ?? '',
 owner: map['owner']?.toString() ?? '',
 status: map['status']?.toString() ?? 'On track',
 );
 }).toList();
 }
}

class _ApprovalCheckpointData {
 const _ApprovalCheckpointData({
 required this.id,
 required this.gate,
 this.description = '',
 this.approver = '',
 this.department = 'Legal',
 this.priority = 'Medium',
 this.status = 'Pending',
 this.targetDate = '',
 this.notes = '',
 });

 final String id;
 final String gate;
 final String description;
 final String approver;
 final String department;
 final String priority;
 final String status;
 final String targetDate;
 final String notes;

 _ApprovalCheckpointData copyWith({
 String? gate,
 String? description,
 String? approver,
 String? department,
 String? priority,
 String? status,
 String? targetDate,
 String? notes,
 }) {
 return _ApprovalCheckpointData(
 id: id,
 gate: gate ?? this.gate,
 description: description ?? this.description,
 approver: approver ?? this.approver,
 department: department ?? this.department,
 priority: priority ?? this.priority,
 status: status ?? this.status,
 targetDate: targetDate ?? this.targetDate,
 notes: notes ?? this.notes,
 );
 }

 Map<String, dynamic> toMap() => {
 'id': id,
 'gate': gate,
 'description': description,
 'approver': approver,
 'department': department,
 'priority': priority,
 'status': status,
 'targetDate': targetDate,
 'notes': notes,
 };

 static List<_ApprovalCheckpointData> fromList(dynamic data) {
 if (data is! List) return [];
 return data.map((item) {
 final map = Map<String, dynamic>.from(item as Map? ?? {});
 return _ApprovalCheckpointData(
 id: map['id']?.toString() ??
 DateTime.now().microsecondsSinceEpoch.toString(),
 gate: map['gate']?.toString() ?? map['title']?.toString() ?? '',
 description: map['description']?.toString() ?? '',
 approver: map['approver']?.toString() ?? map['owner']?.toString() ?? '',
 department: map['department']?.toString() ?? 'Legal',
 priority: map['priority']?.toString() ?? 'Medium',
 status: map['status']?.toString() ?? 'Pending',
 targetDate: map['targetDate']?.toString() ?? map['dueDate']?.toString() ?? '',
 notes: map['notes']?.toString() ?? '',
 );
 }).toList();
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

 void dispose() {
 _timer?.cancel();
 }
}


