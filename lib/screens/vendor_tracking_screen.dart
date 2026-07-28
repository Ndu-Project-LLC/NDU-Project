import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:ndu_project/models/user_role.dart';
import 'package:ndu_project/providers/user_role_provider.dart';
import 'package:ndu_project/screens/contracts_tracking_screen.dart';
import 'package:ndu_project/screens/detailed_design_screen.dart';
import 'package:ndu_project/services/vendor_service.dart';
import 'package:ndu_project/services/contract_service.dart';
import 'package:ndu_project/providers/project_data_provider.dart';
import 'package:ndu_project/services/openai_service_secure.dart';
import 'package:ndu_project/services/user_service.dart';
import 'package:ndu_project/utils/execution_phase_ai_seed.dart';
import 'package:ndu_project/widgets/kaz_ai_chat_bubble.dart';
import 'package:ndu_project/widgets/launch_phase_navigation.dart';
import 'package:ndu_project/widgets/responsive.dart';
import 'package:ndu_project/widgets/responsive_scaffold.dart';
import 'package:ndu_project/widgets/vendors_table_widget.dart';
import 'package:ndu_project/widgets/launch_data_table.dart';
import 'package:ndu_project/utils/auto_bullet_text_controller.dart';
import 'package:ndu_project/utils/rich_text_editing_controller.dart';
import 'package:ndu_project/widgets/text_formatting_toolbar.dart';
import 'package:ndu_project/widgets/planning_phase_header.dart';

import 'package:ndu_project/widgets/voice_text_field.dart';
import 'package:ndu_project/utils/pdf_export_helper.dart';
import 'package:ndu_project/utils/project_data_helper.dart';
class VendorTrackingScreen extends StatefulWidget {
 const VendorTrackingScreen({super.key});

 static void open(BuildContext context) {
 Navigator.of(context).push(
 MaterialPageRoute(builder: (_) => const VendorTrackingScreen()),
 );
 }

 @override
 State<VendorTrackingScreen> createState() => _VendorTrackingScreenState();
}

class _VendorTrackingScreenState extends State<VendorTrackingScreen> {
 bool _isSeedingVendors = false;

 final List<_KpiRow> _customKpiRows = [];
 final List<_RiskSignalRow> _customSignalRows = [];
 final List<_ActionRow> _actionRows = [
 _ActionRow(id: 'act_1', title: 'Quarterly business review', priority: 'High', dueDate: 'Oct 21', owner: 'Vendor Manager', status: 'Agenda locked'),
 _ActionRow(id: 'act_2', title: 'Security compliance audit', priority: 'Critical', dueDate: 'Oct 25', owner: 'Compliance Lead', status: 'Docs requested'),
 _ActionRow(id: 'act_3', title: 'Performance tuning workshop', priority: 'Medium', dueDate: 'Nov 02', owner: 'Operations Lead', status: 'Pending invite'),
 ];

 String? get _projectId {
 try {
 final provider = ProjectDataInherited.maybeOf(context);
 return provider?.projectData.projectId;
 } catch (e) {
 return null;
 }
 }

 _VendorCrudPolicy get _crudPolicy {
 final projectId = _projectId;
 final user = FirebaseAuth.instance.currentUser;
 final roleProvider = UserRoleInherited.of(context);
 final baseRole = roleProvider.siteRole;
 final isAdminByEmail = UserService.isAdminEmail(user?.email ?? '');
 final effectiveRole = isAdminByEmail
 ? SiteRole.admin
 : baseRole == SiteRole.guest && user != null
 ? SiteRole.user
 : baseRole;
 final hasProject = projectId != null && projectId.isNotEmpty;

 return _VendorCrudPolicy.fromRole(
 role: effectiveRole,
 hasProject: hasProject,
 );
 }

 @override
 void initState() {
 super.initState();
 WidgetsBinding.instance.addPostFrameCallback((_) => _seedVendorsIfNeeded());
 }

 Future<void> _seedVendorsIfNeeded() async {
 if (_isSeedingVendors) return;
 final projectId = _projectId;
 final provider = ProjectDataInherited.maybeOf(context);
 final data = provider?.projectData;
 if (projectId == null || data == null) return;
 final contextText = ExecutionPhaseAiSeed.buildContext(
 context,
 section: 'Vendor Tracking',
 );

 final hasVendors = await VendorService.hasAnyVendors(projectId);
 if (hasVendors) return;

 _isSeedingVendors = true;
 try {
 final ai = OpenAiServiceSecure();
 final vendors = await ai.generateProcurementVendors(
 projectName: data.projectName,
 solutionTitle: data.solutionTitle,
 contextNotes: contextText,
 count: 5,
 preferredCategories: const [
 'Logistics',
 'Technology',
 'Operations',
 'Facilities',
 'Services'
 ],
 );

 for (final vendor in vendors) {
 final name = (vendor['name'] ?? '').toString().trim();
 final category = (vendor['category'] ?? 'Operations').toString().trim();
 if (name.isEmpty) continue;
 await VendorService.createVendor(
 projectId: projectId,
 name: name,
 category: category,
 sla: '95%',
 leadTime: '14 days',
 requiredDeliverables:
 '. Weekly status updates\n. Deliverables meet quality standards\n. SLA compliance reporting',
 rating: 'B',
 status: 'Active',
 nextReview: 'TBD',
 onTimeDelivery: 0.8,
 incidentResponse: 0.85,
 qualityScore: 0.82,
 costAdherence: 0.78,
 notes: 'Auto-generated vendor entry.',
 );
 }
 } catch (e) {
 debugPrint('Error seeding vendors: $e');
 } finally {
 _isSeedingVendors = false;
 }
 }

 @override
 Widget build(BuildContext context) {
 final padding = AppBreakpoints.pagePadding(context);

 return ResponsiveScaffold(
 activeItemLabel: 'Vendor Tracking',
 backgroundColor: Colors.white,
 floatingActionButton: const KazAiChatBubble(positioned: false),
 body: SingleChildScrollView(
 padding: EdgeInsets.all(padding),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 PlanningPhaseHeader(
 title: 'Vendor Tracking',
showNavigationButtons: false, onExportPdf: _exportPdf),
 const SizedBox(height: 24),
 Column(
 crossAxisAlignment: CrossAxisAlignment.stretch,
 children: [
 _buildVendorRegister(),
 const SizedBox(height: 20),
 _buildPerformancePanel(),
 const SizedBox(height: 20),
 _buildSignalsPanel(),
 const SizedBox(height: 20),
 _buildActionPanel(),
 ],
 ),
 const SizedBox(height: 24),
 LaunchPhaseNavigation(
 backLabel: 'Back: Contracts Tracking',
 nextLabel: 'Next: Detailed Design',
 onBack: () => ContractsTrackingScreen.open(context),
 onNext: () => DetailedDesignScreen.open(context),
 ),
 ],
 ),
 ),
 );
 }

 Widget _actionButton(IconData icon, String label, {VoidCallback? onPressed}) {
 final enabled = onPressed != null;
 return OutlinedButton.icon(
 onPressed: onPressed,
 icon: Icon(icon,
 size: 18,
 color: enabled ? const Color(0xFF64748B) : const Color(0xFFCBD5E1)),
 label: Text(label,
 style: TextStyle(
 fontSize: 12,
 fontWeight: FontWeight.w600,
 color:
 enabled ? const Color(0xFF64748B) : const Color(0xFF94A3B8))),
 style: OutlinedButton.styleFrom(
 side: const BorderSide(color: Color(0xFFE2E8F0)),
 padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
 ),
 );
 }

 Widget _buildVendorRegister() {
 final policy = _crudPolicy;
 if (_projectId == null || _projectId!.isEmpty) {
 return _PanelShell(
 title: 'Vendor scorecard',
 subtitle: 'Performance, rating, and compliance checkpoints',
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
 title: 'Vendor scorecard',
 subtitle:
 'Performance, rating, SLA, criticality, and compliance checkpoints',
 trailing: policy.canCreate
 ? _actionButton(Icons.add, 'Add vendor',
 onPressed: () => _showAddVendorDialog(context))
 : null,
 child: StreamBuilder<List<VendorModel>>(
 stream: VendorService.streamVendors(_projectId!),
 builder: (context, snapshot) {
 if (snapshot.connectionState == ConnectionState.waiting) {
 return const Center(
 child: Padding(
 padding: EdgeInsets.all(24.0),
 child: CircularProgressIndicator()));
 }

 if (snapshot.hasError) {
 return _buildPermissionError(snapshot.error);
 }

 final vendors = snapshot.data ?? [];

 if (vendors.isEmpty) {
 return Center(
 child: Padding(
 padding: const EdgeInsets.all(24.0),
 child: Column(
 children: [
 Text(
 policy.canCreate
 ? 'No vendors found.'
 : 'No vendors available in your current view.',
 style: const TextStyle(color: Color(0xFF64748B))),
 const SizedBox(height: 12),
 ElevatedButton.icon(
 onPressed: policy.canCreate
 ? () => _showAddVendorDialog(context)
 : null,
 icon: Icon(
 policy.canCreate ? Icons.add : Icons.lock_outline,
 size: 18),
 label: Text(
 policy.canCreate ? 'Add First Vendor' : 'Read-only'),
 ),
 ],
 ),
 ),
 );
 }

 return VendorsTableWidget(
 vendors: vendors,
 canEdit: policy.canUpdate,
 canDelete: policy.canDelete,
 canUseAi: policy.canUpdate,
 onUpdated: (vendor) {
 // Vendor updated via table widget
 },
 onDeleted: (vendor) {
 // Vendor deleted via table widget
 },
 );
 },
 ),
 );
 }

 Widget _buildPermissionError(Object? error) {
 final isPermissionDenied =
 error is FirebaseException && error.code == 'permission-denied';
 final message = isPermissionDenied
 ? 'You are not authorized to view vendors for this project. Contact the project owner or admin to request access.'
 : 'Error loading vendors: ${error ?? 'Unknown error'}';
 return Center(
 child: Padding(
 padding: const EdgeInsets.all(24.0),
 child: Text(message, style: const TextStyle(color: Color(0xFFDC2626))),
 ),
 );
 }

 Widget _buildPerformancePanel() {
 if (_projectId == null) {
 return _PanelShell(
 title: 'Performance pulse',
 subtitle: 'Key service health indicators',
 child: const SizedBox.shrink(),
 );
 }

 return _PanelShell(
 title: 'Performance pulse',
 subtitle: 'Key service health indicators',
 trailing: TextButton.icon(
 onPressed: () => _showPerformanceEntryDialog(),
 icon: const Icon(Icons.add_rounded, size: 16),
 label: const Text('Add metric'),
 style: TextButton.styleFrom(
 foregroundColor: const Color(0xFF4154F1),
 padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
 ),
 ),
 child: StreamBuilder<List<VendorModel>>(
 stream: VendorService.streamVendors(_projectId!),
 builder: (context, snapshot) {
 if (!snapshot.hasData || snapshot.data!.isEmpty) {
 return const Center(
 child: Padding(
 padding: EdgeInsets.all(24.0),
 child: Text('No vendor data available',
 style: TextStyle(color: Color(0xFF64748B))),
 ),
 );
 }

 final vendors = snapshot.data!;
 final onTimeAvg =
 vendors.map((v) => v.onTimeDelivery).reduce((a, b) => a + b) /
 vendors.length;
 final incidentAvg =
 vendors.map((v) => v.incidentResponse).reduce((a, b) => a + b) /
 vendors.length;
 final qualityAvg =
 vendors.map((v) => v.qualityScore).reduce((a, b) => a + b) /
 vendors.length;
 final costAvg =
 vendors.map((v) => v.costAdherence).reduce((a, b) => a + b) /
 vendors.length;

 // Build rows: auto-computed + user-added
 final rows = <_KpiRow>[
 _KpiRow(id: 'auto_ontime', metric: 'On-time delivery', value: onTimeAvg, target: 0.90, trend: onTimeAvg >= 0.90 ? 'On target' : 'Below target', owner: 'Vendor Manager', source: 'Auto-computed'),
 _KpiRow(id: 'auto_incident', metric: 'Incident response', value: incidentAvg, target: 0.85, trend: incidentAvg >= 0.85 ? 'On target' : 'Below target', owner: 'Operations Lead', source: 'Auto-computed'),
 _KpiRow(id: 'auto_quality', metric: 'Quality score', value: qualityAvg, target: 0.80, trend: qualityAvg >= 0.80 ? 'On target' : 'Below target', owner: 'QA Lead', source: 'Auto-computed'),
 _KpiRow(id: 'auto_cost', metric: 'Cost adherence', value: costAvg, target: 0.85, trend: costAvg >= 0.85 ? 'On target' : 'Below target', owner: 'Finance Lead', source: 'Auto-computed'),
 ..._customKpiRows,
 ];

 return Column(
 children: [
 // Table header
 Container(
 padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
 decoration: BoxDecoration(
 color: const Color(0xFF1F2937),
 borderRadius: BorderRadius.circular(8),
 ),
 child: const Row(
 children: [
 Expanded(flex: 3, child: Text('KPI Metric', style: _perfHeaderStyle)),
 Expanded(flex: 1, child: Text('Actual', style: _perfHeaderStyle)),
 Expanded(flex: 1, child: Text('Target', style: _perfHeaderStyle)),
 Expanded(flex: 1, child: Text('Gap', style: _perfHeaderStyle)),
 Expanded(flex: 2, child: Text('Trend', style: _perfHeaderStyle)),
 Expanded(flex: 2, child: Text('Owner', style: _perfHeaderStyle)),
 Expanded(flex: 1, child: Text('', style: _perfHeaderStyle)),
 ],
 ),
 ),
 const SizedBox(height: 4),
 ...rows.asMap().entries.map((entry) {
 final row = entry.value;
 final idx = entry.key;
 final isAuto = row.source == 'Auto-computed';
 final gap = row.value - row.target;
 final gapColor = gap >= 0 ? const Color(0xFF059669) : const Color(0xFFDC2626);
 final barColor = _kpiColor(row.value);

 return Container(
 margin: const EdgeInsets.only(bottom: 3),
 padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
 decoration: BoxDecoration(
 color: idx.isEven ? Colors.white : const Color(0xFFFAFBFD),
 borderRadius: BorderRadius.circular(6),
 border: Border.all(color: const Color(0xFFF3F4F6)),
 ),
 child: Row(
 children: [
 Expanded(
 flex: 3,
 child: Row(
 children: [
 Expanded(child: Text(row.metric, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500))),
 const SizedBox(width: 8),
 SizedBox(
 width: 60,
 child: ClipRRect(
 borderRadius: BorderRadius.circular(3),
 child: LinearProgressIndicator(
 value: row.value.clamp(0.0, 1.0),
 minHeight: 5,
 backgroundColor: const Color(0xFFE5E7EB),
 valueColor: AlwaysStoppedAnimation<Color>(barColor),
 ),
 ),
 ),
 ],
 ),
 ),
 Expanded(
 flex: 1,
 child: Text('${(row.value * 100).round()}%',
 style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: barColor)),
 ),
 Expanded(
 flex: 1,
 child: Text('${(row.target * 100).round()}%',
 style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
 ),
 Expanded(
 flex: 1,
 child: Text('${gap >= 0 ? '+' : ''}${(gap * 100).round()}%',
 style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: gapColor)),
 ),
 Expanded(
 flex: 2,
 child: Container(
 padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
 decoration: BoxDecoration(
 color: gap >= 0 ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
 borderRadius: BorderRadius.circular(4),
 ),
 child: Text(row.trend, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: gapColor)),
 ),
 ),
 Expanded(
 flex: 2,
 child: Text(row.owner, style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
 ),
 Expanded(
 flex: 1,
 child: isAuto
 ? const SizedBox.shrink()
 : Row(
 mainAxisSize: MainAxisSize.min,
 children: [
 InkWell(
 onTap: () => _showPerformanceEntryDialog(existing: row),
 child: const Icon(Icons.edit_outlined, size: 14, color: Color(0xFF6B7280)),
 ),
 const SizedBox(width: 4),
 InkWell(
 onTap: () => _removeCustomKpi(row.id),
 child: const Icon(Icons.delete_outline, size: 14, color: Color(0xFFEF4444)),
 ),
 ],
 ),
 ),
 ],
 ),
 );
 }),
 if (_customKpiRows.isNotEmpty)
 Padding(
 padding: const EdgeInsets.only(top: 6),
 child: Text('${_customKpiRows.length} custom metric${_customKpiRows.length != 1 ? 's' : ''}',
 style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
 ),
 ],
 );
 },
 ),
 );
 }

 static const _perfHeaderStyle = TextStyle(
 fontSize: 10,
 fontWeight: FontWeight.w700,
 color: Color(0xFFD1D5DB),
 letterSpacing: 0.5,
 );

 Color _kpiColor(double value) {
 if (value >= 0.80) return const Color(0xFF059669);
 if (value >= 0.60) return const Color(0xFFD97706);
 return const Color(0xFFDC2626);
 }

 void _showPerformanceEntryDialog({_KpiRow? existing}) {
 final isEdit = existing != null;
 final metricCtl = TextEditingController(text: existing?.metric ?? '');
 final valueCtl = TextEditingController(text: existing != null ? '${(existing.value * 100).round()}' : '');
 final targetCtl = TextEditingController(text: existing != null ? '${(existing.target * 100).round()}' : '85');
 final ownerCtl = TextEditingController(text: existing?.owner ?? '');
 final trendCtl = TextEditingController(text: existing?.trend ?? '');
 showDialog(
 context: context,
 builder: (ctx) => AlertDialog(
 title: Row(
 children: [
 Icon(isEdit ? Icons.edit_outlined : Icons.add_circle_outline, size: 20, color: const Color(0xFF4154F1)),
 const SizedBox(width: 8),
 Text(isEdit ? 'Edit KPI Metric' : 'Add KPI Metric', style: const TextStyle(fontSize: 16)),
 ],
 ),
 content: SingleChildScrollView(
 child: SizedBox(
 width: 480,
 child: Column(
 mainAxisSize: MainAxisSize.min,
 children: [
 VoiceTextField(controller: metricCtl, decoration: const InputDecoration(labelText: 'Metric name', isDense: true, border: OutlineInputBorder())),
 const SizedBox(height: 12),
 Row(children: [
 Expanded(child: VoiceTextField(controller: valueCtl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Actual %', isDense: true, border: OutlineInputBorder(), suffixText: '%'))),
 const SizedBox(width: 12),
 Expanded(child: VoiceTextField(controller: targetCtl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Target %', isDense: true, border: OutlineInputBorder(), suffixText: '%'))),
 ]),
 const SizedBox(height: 12),
 Row(children: [
 Expanded(child: VoiceTextField(controller: ownerCtl, decoration: const InputDecoration(labelText: 'Owner', isDense: true, border: OutlineInputBorder()))),
 const SizedBox(width: 12),
 Expanded(child: VoiceTextField(controller: trendCtl, decoration: const InputDecoration(labelText: 'Trend note', isDense: true, border: OutlineInputBorder()))),
 ]),
 ],
 ),
 ),
 ),
 actions: [
 TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
 FilledButton(
 onPressed: () {
 final val = (int.tryParse(valueCtl.text.trim()) ?? 0).clamp(0, 100) / 100.0;
 final tgt = (int.tryParse(targetCtl.text.trim()) ?? 85).clamp(0, 100) / 100.0;
 final row = _KpiRow(
 id: existing?.id ?? 'custom_${DateTime.now().millisecondsSinceEpoch}',
 metric: metricCtl.text.trim(),
 value: val,
 target: tgt,
 trend: trendCtl.text.trim().isNotEmpty ? trendCtl.text.trim() : (val >= tgt ? 'On target' : 'Below target'),
 owner: ownerCtl.text.trim(),
 source: 'Manual',
 );
 setState(() {
 if (isEdit) {
 final idx = _customKpiRows.indexWhere((r) => r.id == row.id);
 if (idx != -1) _customKpiRows[idx] = row;
 } else {
 _customKpiRows.add(row);
 }
 });
 Navigator.of(ctx).pop();
 },
 style: FilledButton.styleFrom(backgroundColor: const Color(0xFF4154F1), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
 child: Text(isEdit ? 'Save' : 'Add'),
 ),
 ],
 ),
 );
 }

  void _removeCustomKpi(String id) async {
  final ok = await launchConfirmDelete(context, itemName: 'custom KPI');
  if (!ok) return;
  setState(() => _customKpiRows.removeWhere((r) => r.id == id));
  }

 Widget _buildSignalsPanel() {
 if (_projectId == null) {
 return _PanelShell(
 title: 'Risk signals',
 subtitle: 'Active alerts and vendor watch items',
 child: const SizedBox.shrink(),
 );
 }

 return _PanelShell(
 title: 'Risk signals',
 subtitle: 'Active alerts and vendor watch items',
 trailing: TextButton.icon(
 onPressed: () => _showSignalDialog(),
 icon: const Icon(Icons.add_rounded, size: 16),
 label: const Text('Add signal'),
 style: TextButton.styleFrom(
 foregroundColor: const Color(0xFF4154F1),
 padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
 ),
 ),
 child: StreamBuilder<List<VendorModel>>(
 stream: VendorService.streamVendors(_projectId!),
 builder: (context, snapshot) {
 // Build auto-detected signals
 final autoSignals = <_RiskSignalRow>[];
 if (snapshot.hasData && snapshot.data!.isNotEmpty) {
 final vendors = snapshot.data!;
 final atRiskCount = vendors.where((v) => v.status == 'At risk').length;
 final watchCount = vendors.where((v) => v.status == 'Watch').length;
 final lowSlaCount = vendors.where((v) {
 final slaNum = double.tryParse(v.sla.replaceAll('%', '')) ?? 0;
 return slaNum < 80;
 }).length;

 if (atRiskCount > 0) {
 autoSignals.add(_RiskSignalRow(
 id: 'auto_atrisk', signal: 'At-risk vendors',
 description: '$atRiskCount vendor${atRiskCount > 1 ? 's' : ''} require immediate attention.',
 severity: 'Critical', category: 'Vendor status',
 owner: 'Vendor Manager', source: 'Auto-detected',
 status: 'Open',
 ));
 }
 if (watchCount > 0) {
 autoSignals.add(_RiskSignalRow(
 id: 'auto_watch', signal: 'Watchlist items',
 description: '$watchCount vendor${watchCount > 1 ? 's' : ''} on watchlist.',
 severity: 'High', category: 'Vendor status',
 owner: 'Procurement Lead', source: 'Auto-detected',
 status: 'Monitoring',
 ));
 }
 if (lowSlaCount > 0) {
 autoSignals.add(_RiskSignalRow(
 id: 'auto_sla', signal: 'SLA breaches',
 description: '$lowSlaCount vendor${lowSlaCount > 1 ? 's' : ''} below 80% SLA.',
 severity: 'High', category: 'SLA performance',
 owner: 'Operations Lead', source: 'Auto-detected',
 status: 'Open',
 ));
 }
 }

 final allSignals = [...autoSignals, ..._customSignalRows];

 if (allSignals.isEmpty) {
 return Center(
 child: Padding(
 padding: const EdgeInsets.all(24.0),
 child: Column(
 mainAxisSize: MainAxisSize.min,
 children: [
 Icon(Icons.shield_outlined, size: 36, color: const Color(0xFF10B981).withOpacity(0.6)),
 const SizedBox(height: 8),
 const Text('No active risk signals', style: TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.w600)),
 ],
 ),
 ),
 );
 }

 return Column(
 children: [
 // Table header
 Container(
 padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
 decoration: const BoxDecoration(
 color: Color(0xFF1F2937),
 borderRadius: BorderRadius.only(topLeft: Radius.circular(8), topRight: Radius.circular(8)),
 ),
 child: const Row(
 children: [
 Expanded(flex: 3, child: Text('Signal', style: _perfHeaderStyle)),
 Expanded(flex: 1, child: Text('Severity', style: _perfHeaderStyle)),
 Expanded(flex: 2, child: Text('Category', style: _perfHeaderStyle)),
 Expanded(flex: 2, child: Text('Owner', style: _perfHeaderStyle)),
 Expanded(flex: 1, child: Text('Status', style: _perfHeaderStyle)),
 Expanded(flex: 1, child: Text('', style: _perfHeaderStyle)),
 ],
 ),
 ),
 ...allSignals.asMap().entries.map((entry) {
 final sig = entry.value;
 final idx = entry.key;
 final isAuto = sig.source == 'Auto-detected';
 final sevColor = _severityColor(sig.severity);
 final statusColor = _signalStatusColor(sig.status);

 return Container(
 margin: const EdgeInsets.only(bottom: 3),
 padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
 decoration: BoxDecoration(
 color: idx.isEven ? Colors.white : const Color(0xFFFAFBFD),
 borderRadius: BorderRadius.circular(6),
 border: Border(
 left: BorderSide(color: sevColor, width: 3),
 top: BorderSide(color: const Color(0xFFF3F4F6)),
 right: BorderSide(color: const Color(0xFFF3F4F6)),
 bottom: BorderSide(color: const Color(0xFFF3F4F6)),
 ),
 ),
 child: Column(
 children: [
 Row(
 children: [
 Expanded(
 flex: 3,
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(sig.signal, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
 Text(sig.description, style: const TextStyle(fontSize: 10, color: Color(0xFF9CA3AF)), maxLines: 1, overflow: TextOverflow.ellipsis),
 ],
 ),
 ),
 Expanded(
 flex: 1,
 child: Container(
 padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
 decoration: BoxDecoration(color: sevColor.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
 child: Text(sig.severity, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: sevColor), textAlign: TextAlign.center),
 ),
 ),
 Expanded(flex: 2, child: Text(sig.category, style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280)))),
 Expanded(flex: 2, child: Text(sig.owner, style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280)))),
 Expanded(
 flex: 1,
 child: Container(
 padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
 decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
 child: Text(sig.status, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: statusColor), textAlign: TextAlign.center),
 ),
 ),
 Expanded(
 flex: 1,
 child: isAuto
 ? const SizedBox.shrink()
 : Row(mainAxisSize: MainAxisSize.min, children: [
 InkWell(onTap: () => _showSignalDialog(existing: sig), child: const Icon(Icons.edit_outlined, size: 14, color: Color(0xFF6B7280))),
 const SizedBox(width: 4),
 InkWell(onTap: () => _removeSignal(sig.id), child: const Icon(Icons.delete_outline, size: 14, color: Color(0xFFEF4444))),
 ]),
 ),
 ],
 ),
 ],
 ),
 );
 }),
 if (_customSignalRows.isNotEmpty)
 Padding(
 padding: const EdgeInsets.only(top: 6),
 child: Text('${_customSignalRows.length} custom signal${_customSignalRows.length != 1 ? 's' : ''}',
 style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
 ),
 ],
 );
 },
 ),
 );
 }

 Color _severityColor(String sev) {
 switch (sev.toLowerCase()) {
 case 'critical': return const Color(0xFFDC2626);
 case 'high': return const Color(0xFFEA580C);
 case 'medium': return const Color(0xFFD97706);
 case 'low': return const Color(0xFF059669);
 default: return const Color(0xFF6B7280);
 }
 }

 Color _signalStatusColor(String status) {
 switch (status.toLowerCase()) {
 case 'open': return const Color(0xFFDC2626);
 case 'monitoring': return const Color(0xFFD97706);
 case 'mitigated': return const Color(0xFF059669);
 case 'closed': return const Color(0xFF9CA3AF);
 default: return const Color(0xFF6B7280);
 }
 }

 void _showSignalDialog({_RiskSignalRow? existing}) {
 final isEdit = existing != null;
 final signalCtl = TextEditingController(text: existing?.signal ?? '');
 final descCtl = TextEditingController(text: existing?.description ?? '');
 final ownerCtl = TextEditingController(text: existing?.owner ?? '');
 final catCtl = TextEditingController(text: existing?.category ?? '');
 String severity = existing?.severity ?? 'Medium';
 String status = existing?.status ?? 'Open';

 showDialog(
 context: context,
 builder: (ctx) => StatefulBuilder(
 builder: (ctx, setDState) => AlertDialog(
 title: Row(children: [
 Icon(isEdit ? Icons.edit_outlined : Icons.warning_amber_rounded, size: 20, color: const Color(0xFF4154F1)),
 const SizedBox(width: 8),
 Text(isEdit ? 'Edit Risk Signal' : 'Add Risk Signal', style: const TextStyle(fontSize: 16)),
 ]),
 content: SingleChildScrollView(
 child: SizedBox(
 width: 480,
 child: Column(
 mainAxisSize: MainAxisSize.min,
 children: [
 VoiceTextField(controller: signalCtl, decoration: const InputDecoration(labelText: 'Signal name', isDense: true, border: OutlineInputBorder())),
 const SizedBox(height: 12),
 VoiceTextField(controller: descCtl, decoration: const InputDecoration(labelText: 'Description', isDense: true, border: OutlineInputBorder()), maxLines: 2),
 const SizedBox(height: 12),
 Row(children: [
 Expanded(child: DropdownButtonFormField<String>(
 value: severity,
 decoration: const InputDecoration(labelText: 'Severity', isDense: true, border: OutlineInputBorder()),
 items: ['Critical', 'High', 'Medium', 'Low'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
 onChanged: (v) { if (v != null) setDState(() => severity = v); },
 )),
 const SizedBox(width: 12),
 Expanded(child: DropdownButtonFormField<String>(
 value: status,
 decoration: const InputDecoration(labelText: 'Status', isDense: true, border: OutlineInputBorder()),
 items: ['Open', 'Monitoring', 'Mitigated', 'Closed'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
 onChanged: (v) { if (v != null) setDState(() => status = v); },
 )),
 ]),
 const SizedBox(height: 12),
 Row(children: [
 Expanded(child: VoiceTextField(controller: ownerCtl, decoration: const InputDecoration(labelText: 'Owner', isDense: true, border: OutlineInputBorder()))),
 const SizedBox(width: 12),
 Expanded(child: VoiceTextField(controller: catCtl, decoration: const InputDecoration(labelText: 'Category', isDense: true, border: OutlineInputBorder()))),
 ]),
 ],
 ),
 ),
 ),
 actions: [
 TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
 FilledButton(
 onPressed: () {
 final row = _RiskSignalRow(
 id: existing?.id ?? 'sig_${DateTime.now().millisecondsSinceEpoch}',
 signal: signalCtl.text.trim(),
 description: descCtl.text.trim(),
 severity: severity,
 category: catCtl.text.trim(),
 owner: ownerCtl.text.trim(),
 source: 'Manual',
 status: status,
 );
 setState(() {
 if (isEdit) {
 final idx = _customSignalRows.indexWhere((r) => r.id == row.id);
 if (idx != -1) _customSignalRows[idx] = row;
 } else {
 _customSignalRows.add(row);
 }
 });
 Navigator.of(ctx).pop();
 },
 style: FilledButton.styleFrom(backgroundColor: const Color(0xFF4154F1), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
 child: Text(isEdit ? 'Save' : 'Add'),
 ),
 ],
 ),
 ),
 );
 }

  void _removeSignal(String id) async {
  final ok = await launchConfirmDelete(context, itemName: 'risk signal');
  if (!ok) return;
  setState(() => _customSignalRows.removeWhere((r) => r.id == id));
  }

 Widget _buildActionPanel() {
 return _PanelShell(
 title: 'Action plan',
 subtitle: 'Upcoming touchpoints and remediation',
 trailing: TextButton.icon(
 onPressed: () => _showActionDialog(),
 icon: const Icon(Icons.add_rounded, size: 16),
 label: const Text('Add action'),
 style: TextButton.styleFrom(
 foregroundColor: const Color(0xFF4154F1),
 padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
 ),
 ),
 child: _actionRows.isEmpty
 ? Center(
 child: Padding(
 padding: const EdgeInsets.all(24.0),
 child: Column(
 mainAxisSize: MainAxisSize.min,
 children: [
 Icon(Icons.event_note_outlined, size: 36, color: const Color(0xFF9CA3AF).withOpacity(0.6)),
 const SizedBox(height: 8),
 const Text('No action items yet', style: TextStyle(color: Color(0xFF9CA3AF), fontWeight: FontWeight.w500)),
 const SizedBox(height: 4),
 const Text('Add touchpoints, reviews, and remediation tasks.', style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF))),
 ],
 ),
 ),
 )
 : Column(
 children: [
 // Table header
 Container(
 padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
 decoration: const BoxDecoration(
 color: Color(0xFF1F2937),
 borderRadius: BorderRadius.only(topLeft: Radius.circular(8), topRight: Radius.circular(8)),
 ),
 child: const Row(
 children: [
 Expanded(flex: 3, child: Text('Action Item', style: _perfHeaderStyle)),
 Expanded(flex: 1, child: Text('Priority', style: _perfHeaderStyle)),
 Expanded(flex: 2, child: Text('Due Date', style: _perfHeaderStyle)),
 Expanded(flex: 2, child: Text('Owner', style: _perfHeaderStyle)),
 Expanded(flex: 2, child: Text('Status', style: _perfHeaderStyle)),
 Expanded(flex: 1, child: Text('', style: _perfHeaderStyle)),
 ],
 ),
 ),
 ..._actionRows.asMap().entries.map((entry) {
 final act = entry.value;
 final idx = entry.key;
 final prioColor = _severityColor(act.priority);
 final statusColor = _actionStatusColor(act.status);

 return Container(
 margin: const EdgeInsets.only(bottom: 3),
 padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
 decoration: BoxDecoration(
 color: idx.isEven ? Colors.white : const Color(0xFFFAFBFD),
 borderRadius: BorderRadius.circular(6),
 border: Border.all(color: const Color(0xFFF3F4F6)),
 ),
 child: Row(
 children: [
 Expanded(
 flex: 3,
 child: Text(act.title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
 ),
 Expanded(
 flex: 1,
 child: Container(
 padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
 decoration: BoxDecoration(color: prioColor.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
 child: Text(act.priority, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: prioColor), textAlign: TextAlign.center),
 ),
 ),
 Expanded(
 flex: 2,
 child: Text(act.dueDate, style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
 ),
 Expanded(
 flex: 2,
 child: Text(act.owner, style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
 ),
 Expanded(
 flex: 2,
 child: Container(
 padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
 decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
 child: Text(act.status, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: statusColor), textAlign: TextAlign.center),
 ),
 ),
 Expanded(
 flex: 1,
 child: Row(mainAxisSize: MainAxisSize.min, children: [
 InkWell(onTap: () => _showActionDialog(existing: act), child: const Icon(Icons.edit_outlined, size: 14, color: Color(0xFF6B7280))),
 const SizedBox(width: 4),
 InkWell(onTap: () => _removeAction(act.id), child: const Icon(Icons.delete_outline, size: 14, color: Color(0xFFEF4444))),
 ]),
 ),
 ],
 ),
 );
 }),
 Padding(
 padding: const EdgeInsets.only(top: 6),
 child: Text('${_actionRows.length} action${_actionRows.length != 1 ? 's' : ''}',
 style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
 ),
 ],
 ),
 );
 }

 Color _actionStatusColor(String status) {
 switch (status.toLowerCase()) {
 case 'agenda locked': return const Color(0xFF0EA5E9);
 case 'docs requested': return const Color(0xFFD97706);
 case 'pending invite': return const Color(0xFF6366F1);
 case 'completed': return const Color(0xFF059669);
 case 'overdue': return const Color(0xFFDC2626);
 default: return const Color(0xFF6B7280);
 }
 }

 void _showActionDialog({_ActionRow? existing}) {
 final isEdit = existing != null;
 final titleCtl = TextEditingController(text: existing?.title ?? '');
 final dueCtl = TextEditingController(text: existing?.dueDate ?? '');
 final ownerCtl = TextEditingController(text: existing?.owner ?? '');
 String priority = existing?.priority ?? 'Medium';
 String status = existing?.status ?? 'Pending invite';

 showDialog(
 context: context,
 builder: (ctx) => StatefulBuilder(
 builder: (ctx, setDState) => AlertDialog(
 title: Row(children: [
 Icon(isEdit ? Icons.edit_outlined : Icons.add_circle_outline, size: 20, color: const Color(0xFF4154F1)),
 const SizedBox(width: 8),
 Text(isEdit ? 'Edit Action Item' : 'Add Action Item', style: const TextStyle(fontSize: 16)),
 ]),
 content: SizedBox(
 width: 480,
 child: Column(
 mainAxisSize: MainAxisSize.min,
 children: [
 VoiceTextField(controller: titleCtl, decoration: const InputDecoration(labelText: 'Action item', isDense: true, border: OutlineInputBorder())),
 const SizedBox(height: 12),
 Row(children: [
 Expanded(child: DropdownButtonFormField<String>(
 value: priority,
 decoration: const InputDecoration(labelText: 'Priority', isDense: true, border: OutlineInputBorder()),
 items: ['Critical', 'High', 'Medium', 'Low'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
 onChanged: (v) { if (v != null) setDState(() => priority = v); },
 )),
 const SizedBox(width: 12),
 Expanded(child: DropdownButtonFormField<String>(
 value: status,
 decoration: const InputDecoration(labelText: 'Status', isDense: true, border: OutlineInputBorder()),
 items: ['Agenda locked', 'Docs requested', 'Pending invite', 'Completed', 'Overdue'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
 onChanged: (v) { if (v != null) setDState(() => status = v); },
 )),
 ]),
 const SizedBox(height: 12),
 Row(children: [
 Expanded(child: VoiceTextField(controller: dueCtl, decoration: const InputDecoration(labelText: 'Due date', isDense: true, border: OutlineInputBorder(), hintText: 'e.g. Nov 15'))),
 const SizedBox(width: 12),
 Expanded(child: VoiceTextField(controller: ownerCtl, decoration: const InputDecoration(labelText: 'Owner', isDense: true, border: OutlineInputBorder()))),
 ]),
 ],
 ),
 ),
 actions: [
 TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
 FilledButton(
 onPressed: () {
 final row = _ActionRow(
 id: existing?.id ?? 'act_${DateTime.now().millisecondsSinceEpoch}',
 title: titleCtl.text.trim(),
 priority: priority,
 dueDate: dueCtl.text.trim(),
 owner: ownerCtl.text.trim(),
 status: status,
 );
 setState(() {
 if (isEdit) {
 final idx = _actionRows.indexWhere((r) => r.id == row.id);
 if (idx != -1) _actionRows[idx] = row;
 } else {
 _actionRows.add(row);
 }
 });
 Navigator.of(ctx).pop();
 },
 style: FilledButton.styleFrom(backgroundColor: const Color(0xFF4154F1), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
 child: Text(isEdit ? 'Save' : 'Add'),
 ),
 ],
 ),
 ),
 );
 }

  void _removeAction(String id) async {
  final ok = await launchConfirmDelete(context, itemName: 'action');
  if (!ok) return;
  setState(() => _actionRows.removeWhere((r) => r.id == id));
  }

 void _showAddVendorDialog(BuildContext context) {
 final policy = _crudPolicy;
 if (!policy.canCreate) {
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(content: Text(policy.restrictedMessage)),
 );
 return;
 }
 final projectId = _projectId;
 if (projectId == null) {
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(
 content: Text('No project selected. Please open a project first.')),
 );
 return;
 }

 _showVendorDialog(context, null, projectId);
 }

 void _showVendorDialog(
 BuildContext context, VendorModel? vendor, String projectId) async {
 final isEdit = vendor != null;
 final policy = _crudPolicy;
 if ((isEdit && !policy.canUpdate) || (!isEdit && !policy.canCreate)) {
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(content: Text(policy.restrictedMessage)),
 );
 return;
 }
 final nameController = TextEditingController(text: vendor?.name ?? '');
 var selectedCategory = vendor?.category ?? 'Logistics';
 var selectedCriticality = vendor?.criticality ?? 'Medium';
 final slaController = TextEditingController(text: vendor?.sla ?? '92%');
 final slaPerformanceController = TextEditingController(
 text: vendor?.slaPerformance.toString() ?? '0.85');
 final leadTimeController =
 TextEditingController(text: vendor?.leadTime ?? '14 Days');
 // Required Deliverables (SLA Terms) - use AutoBulletTextController
 final requiredDeliverablesController =
 AutoBulletTextController(text: vendor?.requiredDeliverables ?? '');
 final ratingController = TextEditingController(text: vendor?.rating ?? 'B');
 final statusController =
 TextEditingController(text: vendor?.status ?? 'Active');
 final nextReviewController =
 TextEditingController(text: vendor?.nextReview ?? '');
 var selectedContractId = vendor?.contractId;
 final onTimeController = TextEditingController(
 text: vendor?.onTimeDelivery.toString() ?? '0.86');
 final incidentController = TextEditingController(
 text: vendor?.incidentResponse.toString() ?? '0.72');
 final qualityController =
 TextEditingController(text: vendor?.qualityScore.toString() ?? '0.79');
 final costController =
 TextEditingController(text: vendor?.costAdherence.toString() ?? '0.65');
 // Vendor Notes - regular TextEditingController (prose)
 final notesController =
 RichTextEditingController(text: vendor?.notes ?? '');

 // Grab provider early so we don't cross async gaps with BuildContext.
 final provider = ProjectDataInherited.maybeOf(context);

 // Load contracts for linking
 List<ContractModel> contracts = [];
 try {
 // Use streamContracts and take first snapshot
 final stream = ContractService.streamContracts(projectId);
 final snapshot = await stream.first;
 contracts = snapshot;
 } catch (e) {
 debugPrint('Error loading contracts: $e');
 }
 if (!context.mounted) return;

 // Load infrastructure data for vendor suggestions
 List<String> infrastructureSuggestions = [];
 if (provider != null) {
 final infraData = provider.projectData.infrastructureConsiderationsData;
 if (infraData != null) {
 for (var solutionInfra in infraData.solutionInfrastructureData) {
 final infraText = solutionInfra.majorInfrastructure.toLowerCase();
 if (infraText.contains('hardware') ||
 infraText.contains('server') ||
 infraText.contains('network') ||
 infraText.contains('equipment')) {
 infrastructureSuggestions.addAll([
 'Dell Technologies',
 'Cisco Systems',
 'HP Enterprise',
 ]);
 }
 if (infraText.contains('logistics') || infraText.contains('supply')) {
 infrastructureSuggestions.addAll([
 'FedEx',
 'DHL',
 'UPS',
 ]);
 }
 }
 }
 }

 showDialog(
 context: context,
 builder: (context) => AlertDialog(
 title: Text(isEdit ? 'Edit Vendor' : 'Add New Vendor'),
 content: StatefulBuilder(
 builder: (context, setDialogState) => SingleChildScrollView(
 child: Column(
 mainAxisSize: MainAxisSize.min,
 children: [
 VoiceTextField(
 controller: nameController,
 decoration:
 const InputDecoration(labelText: 'Vendor Name *')),
 if (infrastructureSuggestions.isNotEmpty) ...[
 const SizedBox(height: 8),
 Wrap(
 spacing: 8,
 runSpacing: 8,
 children:
 infrastructureSuggestions.take(3).map((suggestion) {
 return ActionChip(
 label: Text(suggestion,
 style: const TextStyle(fontSize: 11)),
 onPressed: () {
 nameController.text = suggestion;
 setDialogState(() {});
 },
 avatar: const Icon(Icons.add, size: 16),
 );
 }).toList(),
 ),
 ],
 const SizedBox(height: 12),
 DropdownButtonFormField<String>(
 value: selectedCategory,
 decoration: const InputDecoration(labelText: 'Category *'),
 items: const [
 'Logistics',
 'IT Hardware',
 'Consulting',
 'Raw Materials',
 'Utilities',
 ]
 .map((cat) =>
 DropdownMenuItem(value: cat, child: Text(cat)))
 .toList(),
 onChanged: (v) {
 if (v != null) {
 setDialogState(() => selectedCategory = v);
 }
 },
 ),
 const SizedBox(height: 12),
 DropdownButtonFormField<String>(
 value: selectedCriticality,
 decoration: const InputDecoration(labelText: 'Criticality *'),
 items: const ['High', 'Medium', 'Low']
 .map((crit) =>
 DropdownMenuItem(value: crit, child: Text(crit)))
 .toList(),
 onChanged: (v) {
 if (v != null) {
 setDialogState(() => selectedCriticality = v);
 }
 },
 ),
 const SizedBox(height: 12),
 VoiceTextField(
 controller: slaController,
 decoration: const InputDecoration(
 labelText: 'SLA % *', hintText: 'e.g., 92%')),
 const SizedBox(height: 12),
 VoiceTextField(
 controller: slaPerformanceController,
 decoration: const InputDecoration(
 labelText: 'SLA Performance (0.0-1.0) *',
 hintText: 'e.g., 0.85')),
 const SizedBox(height: 12),
 VoiceTextField(
 controller: leadTimeController,
 decoration: const InputDecoration(
 labelText: 'Lead Time *', hintText: 'e.g., 14 Days')),
 const SizedBox(height: 12),
 VoiceTextField(
 controller: requiredDeliverablesController,
 decoration: const InputDecoration(
 labelText: 'Required Deliverables (SLA Terms)',
 hintText: 'Use "." bullet format'),
 maxLines: 5),
 const SizedBox(height: 12),
 DropdownButtonFormField<String>(
 value: ratingController.text,
 decoration: const InputDecoration(labelText: 'Rating *'),
 items: ['A', 'B', 'C', 'D']
 .map((r) => DropdownMenuItem(value: r, child: Text(r)))
 .toList(),
 onChanged: (v) => ratingController.text = v ?? 'B',
 ),
 const SizedBox(height: 12),
 DropdownButtonFormField<String>(
 value: statusController.text,
 decoration: const InputDecoration(labelText: 'Status *'),
 items: ['Active', 'Watch', 'At risk', 'Onboard']
 .map((s) => DropdownMenuItem(value: s, child: Text(s)))
 .toList(),
 onChanged: (v) => statusController.text = v ?? 'Active',
 ),
 const SizedBox(height: 12),
 VoiceTextField(
 controller: nextReviewController,
 decoration: const InputDecoration(
 labelText: 'Next Review *', hintText: 'e.g., Oct 28')),
 if (contracts.isNotEmpty) ...[
 const SizedBox(height: 12),
 DropdownButtonFormField<String?>(
 value: selectedContractId,
 decoration: const InputDecoration(
 labelText: 'Linked Contract (Optional)'),
 items: [
 const DropdownMenuItem<String?>(
 value: null, child: Text('None')),
 ...contracts.map((contract) => DropdownMenuItem<String?>(
 value: contract.id,
 child: Text(contract.name,
 overflow: TextOverflow.ellipsis),
 )),
 ],
 onChanged: (v) {
 setDialogState(() => selectedContractId = v);
 },
 ),
 ],
 const SizedBox(height: 12),
 VoiceTextField(
 controller: onTimeController,
 decoration: const InputDecoration(
 labelText: 'On-time Delivery (0.0-1.0) *')),
 const SizedBox(height: 12),
 VoiceTextField(
 controller: incidentController,
 decoration: const InputDecoration(
 labelText: 'Incident Response (0.0-1.0) *')),
 const SizedBox(height: 12),
 VoiceTextField(
 controller: qualityController,
 decoration: const InputDecoration(
 labelText: 'Quality Score (0.0-1.0) *')),
 const SizedBox(height: 12),
 VoiceTextField(
 controller: costController,
 decoration: const InputDecoration(
 labelText: 'Cost Adherence (0.0-1.0) *')),
 const SizedBox(height: 12),
 const SizedBox(height: 6),
 VoiceTextField(
 controller: notesController,
 decoration: const InputDecoration(
 labelText: 'Vendor Notes',
 hintText: 'Prose description, no bullets'),
 maxLines: 3),
 ],
 ),
 ),
 ),
 actions: [
 TextButton(
 onPressed: () => Navigator.pop(context),
 child: const Text('Cancel'),
 ),
 ElevatedButton(
 onPressed: () async {
 if (nameController.text.isEmpty || selectedCategory.isEmpty) {
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(
 content: Text('Please fill in required fields')),
 );
 return;
 }

 try {
 final onTime = double.tryParse(onTimeController.text) ?? 0.0;
 final incident =
 double.tryParse(incidentController.text) ?? 0.0;
 final quality = double.tryParse(qualityController.text) ?? 0.0;
 final cost = double.tryParse(costController.text) ?? 0.0;
 final slaPerformance =
 double.tryParse(slaPerformanceController.text) ?? 0.0;

 if (isEdit && vendor != null) {
 await VendorService.updateVendor(
 projectId: projectId,
 vendorId: vendor.id,
 name: nameController.text,
 category: selectedCategory,
 criticality: selectedCriticality,
 sla: slaController.text,
 slaPerformance: slaPerformance,
 leadTime: leadTimeController.text,
 requiredDeliverables: requiredDeliverablesController.text,
 rating: ratingController.text,
 status: statusController.text,
 nextReview: nextReviewController.text,
 contractId: selectedContractId,
 onTimeDelivery: onTime,
 incidentResponse: incident,
 qualityScore: quality,
 costAdherence: cost,
 notes: notesController.text.isEmpty
 ? null
 : notesController.text,
 );
 } else {
 await VendorService.createVendor(
 projectId: projectId,
 name: nameController.text,
 category: selectedCategory,
 criticality: selectedCriticality,
 sla: slaController.text,
 slaPerformance: slaPerformance,
 leadTime: leadTimeController.text,
 requiredDeliverables: requiredDeliverablesController.text,
 rating: ratingController.text,
 status: statusController.text,
 nextReview: nextReviewController.text,
 contractId: selectedContractId,
 onTimeDelivery: onTime,
 incidentResponse: incident,
 qualityScore: quality,
 costAdherence: cost,
 notes: notesController.text.isEmpty
 ? null
 : notesController.text,
 );
 }

 if (context.mounted) {
 Navigator.pop(context);
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(
 content: Text(isEdit
 ? 'Vendor updated successfully'
 : 'Vendor added successfully')),
 );
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
 );
 }

 Future<void> _exportPdf() async {
 final projectData = ProjectDataHelper.getData(context);
 await PdfExportHelper.exportScreenPdf(
 context: context,
 screenTitle: 'Vendor Tracking',
 sections: [
 PdfSection.keyValue('Project Info', [
 {'Project Name': projectData.projectName ?? 'N/A'},
 {'Solution Title': projectData.solutionTitle ?? 'N/A'},
 ]),
 PdfSection.text('Notes', projectData.planningNotes['planning_vendor_tracking_notes'] ?? 'No data recorded.'),
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
 crossAxisAlignment: CrossAxisAlignment.stretch,
 children: [
 Stack(
 children: [
 Align(
 alignment: Alignment.topCenter,
 child: Padding(
 padding: EdgeInsets.only(
 left: trailing == null ? 0 : 120,
 right: trailing == null ? 0 : 120,
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.center,
 children: [
 Text(title,
 textAlign: TextAlign.center,
 style: const TextStyle(
 fontSize: 16, fontWeight: FontWeight.w700)),
 const SizedBox(height: 4),
 Text(subtitle,
 textAlign: TextAlign.center,
 style: const TextStyle(
 fontSize: 12, color: Color(0xFF64748B))),
 ],
 ),
 ),
 ),
 if (trailing != null)
 Align(
 alignment: Alignment.topRight,
 child: trailing!,
 ),
 ],
 ),
 const SizedBox(height: 16),
 child,
 ],
 ),
 );
 }
}

class _VendorCrudPolicy {
 const _VendorCrudPolicy({
 required this.role,
 required this.hasProject,
 required this.canCreate,
 required this.canUpdate,
 required this.canDelete,
 required this.canReview,
 required this.canExport,
 required this.canAudit,
 });

 final SiteRole role;
 final bool hasProject;
 final bool canCreate;
 final bool canUpdate;
 final bool canDelete;
 final bool canReview;
 final bool canExport;
 final bool canAudit;

 factory _VendorCrudPolicy.fromRole({
 required SiteRole role,
 required bool hasProject,
 }) {
 final level = role.level;
 return _VendorCrudPolicy(
 role: role,
 hasProject: hasProject,
 canCreate: hasProject && level >= SiteRole.editor.level,
 canUpdate: hasProject && level >= SiteRole.editor.level,
 canDelete: hasProject && level >= SiteRole.admin.level,
 canReview: hasProject && level >= SiteRole.user.level,
 canExport: hasProject && level >= SiteRole.user.level,
 canAudit: hasProject && level >= SiteRole.editor.level,
 );
 }

 String get roleLabel => hasProject ? role.displayName : 'No project';

 Color get roleColor => hasProject ? role.color : const Color(0xFF94A3B8);

 String get restrictedMessage {
 if (!hasProject) {
 return 'No project selected. Please open a project first.';
 }
 return 'Your current access is ${role.displayName}. Vendor edits require Editor access; deletes require Admin access.';
 }
}

class _KpiRow {
 const _KpiRow({
 required this.id,
 required this.metric,
 required this.value,
 required this.target,
 required this.trend,
 required this.owner,
 required this.source,
 });
 final String id;
 final String metric;
 final double value;
 final double target;
 final String trend;
 final String owner;
 final String source;
}

class _RiskSignalRow {
 const _RiskSignalRow({
 required this.id,
 required this.signal,
 required this.description,
 required this.severity,
 required this.category,
 required this.owner,
 required this.source,
 required this.status,
 });
 final String id;
 final String signal;
 final String description;
 final String severity;
 final String category;
 final String owner;
 final String source;
 final String status;
}

class _ActionRow {
 const _ActionRow({
 required this.id,
 required this.title,
 required this.priority,
 required this.dueDate,
 required this.owner,
 required this.status,
 });
 final String id;
 final String title;
 final String priority;
 final String dueDate;
 final String owner;
 final String status;
}


