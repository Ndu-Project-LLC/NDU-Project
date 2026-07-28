import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:ndu_project/models/user_role.dart';
import 'package:ndu_project/providers/user_role_provider.dart';
import 'package:ndu_project/providers/project_data_provider.dart';
import 'package:ndu_project/routing/app_router.dart';
import 'package:ndu_project/services/activity_log_service.dart';
import 'package:ndu_project/services/integration_oauth_service.dart';
import 'package:ndu_project/services/openai_service_secure.dart';
import 'package:ndu_project/services/user_service.dart';
import 'package:ndu_project/widgets/kaz_ai_chat_bubble.dart';
import 'package:ndu_project/widgets/planning_phase_header.dart';
import 'package:ndu_project/widgets/launch_phase_navigation.dart';
import 'package:ndu_project/widgets/responsive.dart';
import 'package:ndu_project/widgets/responsive_scaffold.dart';

import 'package:ndu_project/widgets/voice_text_field.dart';
class ToolsIntegrationScreen extends StatefulWidget {
 const ToolsIntegrationScreen({super.key});

 static void open(BuildContext context) => Navigator.push(
 context,
 MaterialPageRoute(builder: (_) => const ToolsIntegrationScreen()),
 );

 @override
 State<ToolsIntegrationScreen> createState() => _ToolsIntegrationScreenState();
}

class _ToolsIntegrationScreenState extends State<ToolsIntegrationScreen> {
 final Set<String> _selectedFilters = {'All tools'};
 final _Debouncer _saveDebouncer = _Debouncer();
 bool _isLoading = false;
 bool _suspendSave = false;
 String? _loadError;

 List<_IntegrationRow> _integrations = [];
 List<_KpiRow> _customKpiRows = [];
 List<_RiskSignalRow> _riskSignals = [];
 List<_ActionRow> _actionRows = [];
 List<_ApprovalGateData> _approvalGates = [];
 List<_DataFlowRow> _dataFlows = [];
 bool _frameworkGuideExpanded = false;

 String? get _projectId {
 try {
 final provider = ProjectDataInherited.maybeOf(context);
 return provider?.projectData.projectId;
 } catch (e) {
 return null;
 }
 }

 _ToolsCrudPolicy get _crudPolicy {
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
 return _ToolsCrudPolicy.fromRole(role: effectiveRole, hasProject: hasProject);
 }

 @override
 void initState() {
 super.initState();
 _integrations = _defaultIntegrations();
 _riskSignals = _defaultRiskSignals();
 _actionRows = _defaultActionRows();
 _approvalGates = _defaultApprovalGates();
 _dataFlows = _defaultDataFlows();
 WidgetsBinding.instance.addPostFrameCallback((_) {
 _loadFromFirestore();
 _refreshIntegrationStatuses();
 });
 }

 @override
 void dispose() {
 _saveDebouncer.dispose();
 super.dispose();
 }

 // ---------------------------------------------------------------------------
 // Firestore persistence
 // ---------------------------------------------------------------------------

 DocumentReference<Map<String, dynamic>> _docFor(String projectId) {
 return FirebaseFirestore.instance
 .collection('projects')
 .doc(projectId)
 .collection('design_phase_sections')
 .doc('tools_integration');
 }

 void _scheduleSave() {
 if (_suspendSave) return;
 _saveDebouncer.run(_saveToFirestore);
 }

 Future<void> _loadFromFirestore() async {
 final projectId = _projectId;
 if (projectId == null || projectId.isEmpty) return;
 if (!mounted) return;
 setState(() {
 _isLoading = true;
 _loadError = null;
 });
 try {
 final doc = await _docFor(projectId).get();
 final data = doc.data() ?? {};
 _suspendSave = true;
 if (!mounted) return;
 setState(() {
 final integrations = _IntegrationRow.fromList(data['integrations']);
 final kpis = _KpiRow.fromList(data['customKpiRows']);
 final signals = _RiskSignalRow.fromList(data['riskSignals']);
 final actions = _ActionRow.fromList(data['actionRows']);
 final gates = _ApprovalGateData.fromList(data['approvalGates']);
 final flows = _DataFlowRow.fromList(data['dataFlows']);
 _integrations = integrations.isEmpty ? _defaultIntegrations() : integrations;
 _customKpiRows = kpis;
 _riskSignals = signals.isEmpty ? _defaultRiskSignals() : signals;
 _actionRows = actions.isEmpty ? _defaultActionRows() : actions;
 _approvalGates = gates.isEmpty ? _defaultApprovalGates() : gates;
 _dataFlows = flows.isEmpty ? _defaultDataFlows() : flows;
 });
 } catch (error) {
 debugPrint('Tools integration load error: $error');
 if (!mounted) return;
 setState(() {
 _loadError = 'Unable to load tools integration data right now. Please retry.';
 });
 } finally {
 _suspendSave = false;
 if (mounted) setState(() => _isLoading = false);
 }
 }

 Future<void> _saveToFirestore() async {
 final projectId = _projectId;
 if (projectId == null || projectId.isEmpty) return;
 try {
 await _docFor(projectId).set({
 'integrations': _integrations.map((e) => e.toMap()).toList(),
 'customKpiRows': _customKpiRows.map((e) => e.toMap()).toList(),
 'riskSignals': _riskSignals.map((e) => e.toMap()).toList(),
 'actionRows': _actionRows.map((e) => e.toMap()).toList(),
 'approvalGates': _approvalGates.map((e) => e.toMap()).toList(),
 'dataFlows': _dataFlows.map((e) => e.toMap()).toList(),
 'updatedAt': FieldValue.serverTimestamp(),
 }, SetOptions(merge: true));
 await ActivityLogService.instance.logActivity(
 projectId: projectId,
 phase: 'Design Phase',
 page: 'Tools Integration',
 action: 'Updated Tools Integration data',
 );
 } catch (error) {
 debugPrint('Tools integration save error: $error');
 if (!mounted) return;
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(
 content: Text('Unable to save tools integration changes right now. Please try again.'),
 ),
 );
 }
 }

 // ---------------------------------------------------------------------------
 // OAuth refresh
 // ---------------------------------------------------------------------------

 Future<void> _refreshIntegrationStatuses() async {
 final service = IntegrationOAuthService.instance;
 for (var i = 0; i < _integrations.length; i++) {
 final prov = _providerForName(_integrations[i].provider);
 if (prov == null) continue;
 final state = await service.loadState(prov);
 final item = _integrations[i];
 final status = state.connected
 ? 'Connected'
 : state.hasToken
 ? 'Expired'
 : item.status == 'Not connected'
 ? 'Not connected'
 : item.status;
 final lastSync = state.updatedAt == null
 ? item.lastSync
 : 'Token refresh: ${_formatRelativeTime(state.updatedAt!)}';
 _integrations[i] = item.copyWith(status: status, lastSync: lastSync);
 }
 if (mounted) {
 setState(() {});
 _scheduleSave();
 }
 }

 IntegrationProvider? _providerForName(String name) {
 switch (name.toLowerCase()) {
 case 'figma':
 return IntegrationProvider.figma;
 case 'draw.io':
 case 'drawio':
 return IntegrationProvider.drawio;
 case 'miro':
 return IntegrationProvider.miro;
 case 'whiteboard':
 return IntegrationProvider.whiteboard;
 default:
 return null;
 }
 }

 String _formatRelativeTime(DateTime dt) {
 final diff = DateTime.now().difference(dt);
 if (diff.inMinutes < 1) return 'just now';
 if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
 if (diff.inHours < 24) return '${diff.inHours} hr ago';
 return '${diff.inDays} days ago';
 }

 // ---------------------------------------------------------------------------
 // Default data
 // ---------------------------------------------------------------------------

 List<_IntegrationRow> _defaultIntegrations() {
 return [
 _IntegrationRow(
 id: 'figma', name: 'Figma', subtitle: 'Design files',
 provider: 'Figma', status: 'Connected', scopes: 'files:read, files:write',
 mapsTo: 'Epics, stories', lastSync: '1 hr ago',
 icon: Icons.design_services, iconColor: const Color(0xFFF24E1E),
 features: 'Project mapping enabled.', autoHandoff: 'ON', syncMode: null, errorInfo: null,
 ),
 _IntegrationRow(
 id: 'drawio', name: 'Draw.io', subtitle: 'Architecture diagrams',
 provider: 'Draw.io', status: 'Degraded', scopes: 'diagrams:read',
 mapsTo: 'Tech specs', lastSync: '2 hr ago',
 icon: Icons.account_tree, iconColor: const Color(0xFFFF6D00),
 features: 'Change detection enabled with retries.', autoHandoff: null, syncMode: 'scheduled', errorInfo: '2 errors in last hour',
 ),
 _IntegrationRow(
 id: 'miro', name: 'Miro', subtitle: 'Workshops & ideation',
 provider: 'Miro', status: 'Connected', scopes: 'boards:read, comments',
 mapsTo: 'Requirements', lastSync: '30 min ago',
 icon: Icons.dashboard, iconColor: const Color(0xFFFFD02F),
 features: 'Cluster-to-epic mapping.', autoHandoff: null, syncMode: null, errorInfo: null,
 ),
 _IntegrationRow(
 id: 'whiteboard', name: 'Whiteboard', subtitle: 'Live sessions',
 provider: 'Whiteboard', status: 'Connected', scopes: 'sessions:read',
 mapsTo: 'Decisions, actions', lastSync: '5 min ago',
 icon: Icons.sticky_note_2, iconColor: const Color(0xFF0078D4),
 features: 'Outputs pushed to notes & actions.', autoHandoff: null, syncMode: null, errorInfo: null,
 ),
 _IntegrationRow(
 id: 'jira', name: 'Jira', subtitle: 'Sprint & backlog tracking',
 provider: 'Jira', status: 'Connected', scopes: 'issues:read, issues:write',
 mapsTo: 'Tasks, bugs', lastSync: '15 min ago',
 icon: Icons.track_changes, iconColor: const Color(0xFF0052CC),
 features: 'Sprint sync with auto-epic linking.', autoHandoff: 'ON', syncMode: null, errorInfo: null,
 ),
 _IntegrationRow(
 id: 'github', name: 'GitHub', subtitle: 'Source code & CI/CD',
 provider: 'GitHub', status: 'Not connected', scopes: 'repo:read, repo:write',
 mapsTo: 'Code, PRs', lastSync: 'Never',
 icon: Icons.code, iconColor: const Color(0xFF24292F),
 features: 'PR-to-task linking and CI pipeline triggers.', autoHandoff: null, syncMode: null, errorInfo: null,
 ),
 ];
 }

 List<_RiskSignalRow> _defaultRiskSignals() {
 return [
 _RiskSignalRow(
 id: 'sig_1', signal: 'Degraded connection',
 description: 'Draw.io experiencing retry failures — 2 errors in last hour',
 severity: 'High', category: 'Connectivity',
 owner: 'Operations Lead', source: 'Auto-detected', status: 'Open',
 ),
 _RiskSignalRow(
 id: 'sig_2', signal: 'Token expiry warning',
 description: '1 integration approaching token expiration within 48 hours',
 severity: 'Medium', category: 'Authentication',
 owner: 'Security Lead', source: 'Auto-detected', status: 'Monitoring',
 ),
 _RiskSignalRow(
 id: 'sig_3', signal: 'Scope mismatch',
 description: 'Jira scopes need update for new project fields — missing issues:write scope on 2 project boards',
 severity: 'High', category: 'Governance',
 owner: 'Integration Lead', source: 'Manual', status: 'Open',
 ),
 ];
 }

 List<_ActionRow> _defaultActionRows() {
 return [
 _ActionRow(
 id: 'act_1', title: 'Rotate GitHub API credentials',
 priority: 'Critical', dueDate: 'Oct 18', owner: 'Security Lead', status: 'Pending',
 ),
 _ActionRow(
 id: 'act_2', title: 'Update Jira integration scopes',
 priority: 'High', dueDate: 'Oct 22', owner: 'Integration Lead', status: 'In Progress',
 ),
 _ActionRow(
 id: 'act_3', title: 'Schedule Draw.io connection diagnostic',
 priority: 'Medium', dueDate: 'Oct 28', owner: 'Operations Lead', status: 'Not Started',
 ),
 ];
 }

 List<_ApprovalGateData> _defaultApprovalGates() {
 return [
 _ApprovalGateData(
 id: 'gate_1', gate: 'Security & Access Review',
 description: 'Validate OAuth scopes, API key rotation policies, and access control lists per ISO 27001 A.9',
 approver: 'Security Lead', department: 'Security', priority: 'Critical', status: 'In Review', targetDate: 'Nov 1',
 ),
 _ApprovalGateData(
 id: 'gate_2', gate: 'Data Flow Validation',
 description: 'Confirm data mapping integrity, field-level encryption, and PII handling compliance per GDPR/CCPA',
 approver: 'Data Governance Lead', department: 'Data', priority: 'Critical', status: 'Pending', targetDate: 'Nov 5',
 ),
 _ApprovalGateData(
 id: 'gate_3', gate: 'Operational Readiness',
 description: 'Verify uptime SLA targets, failover mechanisms, and incident response procedures per ITIL Service Level Management',
 approver: 'Operations Manager', department: 'Operations', priority: 'High', status: 'Pending', targetDate: 'Nov 10',
 ),
 _ApprovalGateData(
 id: 'gate_4', gate: 'Integration Testing Sign-off',
 description: 'Confirm end-to-end integration testing, error handling validation, and performance benchmarks met',
 approver: 'QA Lead', department: 'Quality', priority: 'High', status: 'Not Started', targetDate: 'Nov 15',
 ),
 _ApprovalGateData(
 id: 'gate_5', gate: 'Vendor & License Compliance',
 description: 'Verify vendor contract terms, license scope alignment, and usage limits per procurement governance',
 approver: 'Procurement Lead', department: 'Procurement', priority: 'Medium', status: 'Not Started', targetDate: 'Nov 20',
 ),
 _ApprovalGateData(
 id: 'gate_6', gate: 'Executive Authorization',
 description: 'Final approval from executive sponsor for production integration activation and data exchange authorization',
 approver: 'Executive Sponsor', department: 'Executive', priority: 'High', status: 'Not Started', targetDate: 'Nov 25',
 ),
 ];
 }

 List<_DataFlowRow> _defaultDataFlows() {
 return [
 _DataFlowRow(
 id: 'flow_1', source: 'Figma', target: 'Jira', dataType: 'Design specs',
 apiMethod: 'REST POST', frequency: 'On change', transformation: 'Component-to-epic mapping', status: 'Active',
 ),
 _DataFlowRow(
 id: 'flow_2', source: 'Jira', target: 'GitHub', dataType: 'Sprint tasks',
 apiMethod: 'REST POST/PUT', frequency: 'Real-time', transformation: 'Issue-to-PR linking', status: 'Active',
 ),
 _DataFlowRow(
 id: 'flow_3', source: 'Miro', target: 'Requirements', dataType: 'Workshop outputs',
 apiMethod: 'REST GET', frequency: 'Scheduled', transformation: 'Cluster-to-requirement mapping', status: 'Active',
 ),
 _DataFlowRow(
 id: 'flow_4', source: 'Draw.io', target: 'Tech specs', dataType: 'Architecture diagrams',
 apiMethod: 'REST GET', frequency: 'On change', transformation: 'SVG-to-document embedding', status: 'Degraded',
 ),
 _DataFlowRow(
 id: 'flow_5', source: 'Whiteboard', target: 'Decisions log', dataType: 'Session artifacts',
 apiMethod: 'WebSocket', frequency: 'Real-time', transformation: 'Auto-extract action items', status: 'Active',
 ),
 ];
 }

 // ---------------------------------------------------------------------------
 // CRUD helpers
 // ---------------------------------------------------------------------------

 String _newId() => DateTime.now().microsecondsSinceEpoch.toString();

 void _logActivity(String action, {Map<String, dynamic>? details}) {
 final projectId = _projectId?.trim() ?? '';
 if (projectId.isEmpty) return;
 unawaited(
 ActivityLogService.instance.logActivity(
 projectId: projectId,
 phase: 'Design Phase',
 page: 'Tools Integration',
 action: action,
 details: details,
 ),
 );
 }

 void _deleteIntegration(String id) {
 setState(() => _integrations.removeWhere((e) => e.id == id));
 _scheduleSave();
 _logActivity('Deleted tool integration row', details: {'itemId': id});
 }

 void _deleteRiskSignal(String id) {
 setState(() => _riskSignals.removeWhere((e) => e.id == id));
 _scheduleSave();
 _logActivity('Deleted risk signal row', details: {'itemId': id});
 }

 void _deleteActionRow(String id) {
 setState(() => _actionRows.removeWhere((e) => e.id == id));
 _scheduleSave();
 _logActivity('Deleted action item row', details: {'itemId': id});
 }

 void _removeCustomKpi(String id) {
 setState(() => _customKpiRows.removeWhere((r) => r.id == id));
 _scheduleSave();
 _logActivity('Deleted custom KPI metric', details: {'itemId': id});
 }

 void _deleteApprovalGate(String id) {
 setState(() => _approvalGates.removeWhere((e) => e.id == id));
 _scheduleSave();
 _logActivity('Deleted approval gate row', details: {'itemId': id});
 }

 void _deleteDataFlow(String id) {
 setState(() => _dataFlows.removeWhere((e) => e.id == id));
 _scheduleSave();
 _logActivity('Deleted data flow row', details: {'itemId': id});
 }

 // ---------------------------------------------------------------------------
 // Build
 // ---------------------------------------------------------------------------

 @override
 Widget build(BuildContext context) {
 final isNarrow = MediaQuery.sizeOf(context).width < 980;
 final padding = AppBreakpoints.pagePadding(context);

 return ResponsiveScaffold(
 activeItemLabel: 'Tools Integration',
 backgroundColor: Colors.white,
 floatingActionButton: const KazAiChatBubble(positioned: false),
 body: Column(
 children: [
 const PlanningPhaseHeader(
 title: 'Tools Integration',
showNavigationButtons: false,
 ),
 Expanded(
 child: SingleChildScrollView(
 padding: EdgeInsets.fromLTRB(padding, 8, padding, padding),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 if (_isLoading) const LinearProgressIndicator(minHeight: 2),
 if (_isLoading) const SizedBox(height: 16),
 if (_loadError != null) ...[
 _buildLoadErrorCard(),
 const SizedBox(height: 16),
 ],
 _buildHeader(),
 const SizedBox(height: 20),
 _buildFrameworkGuide(),
 const SizedBox(height: 24),
 Column(
 children: [
 _buildIntegrationRegister(),
 const SizedBox(height: 20),
 _buildConnectionHealthPanel(),
 const SizedBox(height: 20),
 _buildRiskSignalsPanel(),
 const SizedBox(height: 20),
 _buildActionItemsPanel(),
 const SizedBox(height: 20),
 _buildApprovalGatesPanel(),
 const SizedBox(height: 20),
 _buildDataFlowPanel(),
 ],
 ),
 const SizedBox(height: 24),
 LaunchPhaseNavigation(
 backLabel: 'Back: Technical Development',
 nextLabel: 'Next: Long Lead Equipment',
 onBack: () => context.go('/${AppRoutes.technicalDevelopment}'),
 onNext: () => context.go('/${AppRoutes.longLeadEquipmentOrdering}'),
 ),
 ],
 ),
 ),
 ),
 ],
 ),
 );
 }

 // ---------------------------------------------------------------------------
 // Load error card
 // ---------------------------------------------------------------------------

 Widget _buildLoadErrorCard() {
 return Container(
 width: double.infinity,
 padding: const EdgeInsets.all(16),
 decoration: BoxDecoration(
 color: const Color(0xFFFFFBEB),
 borderRadius: BorderRadius.circular(16),
 border: Border.all(color: const Color(0xFFFDE68A)),
 ),
 child: Row(
 children: [
 const Icon(Icons.warning_amber_rounded, color: Color(0xFFD97706)),
 const SizedBox(width: 12),
 const Expanded(
 child: Text(
 'Unable to load tools integration data right now. Please retry.',
 style: TextStyle(color: Color(0xFF92400E), fontWeight: FontWeight.w600),
 ),
 ),
 OutlinedButton(
 onPressed: _loadFromFirestore,
 child: const Text('Retry'),
 ),
 ],
 ),
 );
 }

 // ---------------------------------------------------------------------------
 // Header
 // ---------------------------------------------------------------------------

 Widget _buildHeader() {
 return Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Container(
 padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
 decoration: BoxDecoration(
 color: const Color(0xFFFFC812),
 borderRadius: BorderRadius.circular(6),
 ),
 child: const Text(
 'TOOLS INTEGRATION',
 style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.black),
 ),
 ),
 const SizedBox(height: 10),
 const Text(
 'Tools Integration',
 style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: Color(0xFF111827)),
 ),
 const SizedBox(height: 6),
 const Text(
 'Govern integration lifecycle, API scopes, and data flow health across your design and delivery toolchain. '
 'Aligned with ITIL Service Integration, PMI PMBOK 4.3 (Direct & Manage Project Work), '
 'and ISO 27001 Annex A.12 (Operations Security) for tool chain management and access control.',
 style: TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
 ),
 ],
 );
 }

 Widget _buildHeaderActions() {
 final policy = _crudPolicy;
 return Wrap(
 spacing: 10,
 runSpacing: 10,
 children: [
 _actionButton(Icons.add, 'Add tool',
 onPressed: policy.canCreate ? () => _showIntegrationDialog() : null),
 _actionButton(Icons.upload_outlined, 'Export inventory', onPressed: () {
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(content: Text('Inventory export queued. All integration records will be included.')),
 );
 }),
 _actionButton(Icons.health_and_safety_outlined, 'Start health check', onPressed: () {
 _refreshIntegrationStatuses();
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(content: Text('Health check initiated. All integration statuses are being refreshed.')),
 );
 }),
 _primaryButton('Run manual sync'),
 ],
 );
 }

 Widget _actionButton(IconData icon, String label, {VoidCallback? onPressed}) {
 final enabled = onPressed != null;
 return OutlinedButton.icon(
 onPressed: onPressed ?? () {},
 icon: Icon(icon, size: 18, color: enabled ? const Color(0xFF64748B) : const Color(0xFFCBD5E1)),
 label: Text(label,
 style: TextStyle(
 fontSize: 12,
 fontWeight: FontWeight.w600,
 color: enabled ? const Color(0xFF64748B) : const Color(0xFF94A3B8))),
 style: OutlinedButton.styleFrom(
 side: const BorderSide(color: Color(0xFFE2E8F0)),
 padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
 ),
 );
 }

 Widget _primaryButton(String label) {
 return ElevatedButton.icon(
 onPressed: () {
 _refreshIntegrationStatuses();
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(content: Text('Manual sync triggered. Refreshing all integration statuses.')),
 );
 },
 icon: const Icon(Icons.sync, size: 18),
 label: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
 style: ElevatedButton.styleFrom(
 backgroundColor: const Color(0xFF0EA5E9),
 foregroundColor: Colors.white,
 padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
 ),
 );
 }

 // ---------------------------------------------------------------------------
 // Filter chips
 // ---------------------------------------------------------------------------

 Widget _buildFilterChips() {
 const filters = ['All tools', 'Connected', 'Degraded', 'Not connected', 'Expired'];
 return Wrap(
 spacing: 10,
 runSpacing: 10,
 children: filters.map((filter) {
 final selected = _selectedFilters.contains(filter);
 return GestureDetector(
 onTap: () {
 setState(() {
 if (filter == 'All tools') {
 _selectedFilters
 ..clear()
 ..add(filter);
 } else {
 if (selected) {
 _selectedFilters.remove(filter);
 } else {
 _selectedFilters
 ..remove('All tools')
 ..add(filter);
 }
 if (_selectedFilters.isEmpty) _selectedFilters.add('All tools');
 }
 });
 },
 child: Container(
 padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
 decoration: BoxDecoration(
 color: selected ? const Color(0xFF111827) : Colors.white,
 borderRadius: BorderRadius.circular(20),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 ),
 child: Text(
 filter,
 style: TextStyle(
 fontSize: 12,
 fontWeight: FontWeight.w600,
 color: selected ? Colors.white : const Color(0xFF475569),
 ),
 ),
 ),
 );
 }).toList(),
 );
 }

 // ---------------------------------------------------------------------------
 // Governance strip
 // ---------------------------------------------------------------------------

 Widget _buildGovernanceStrip() {
 final policy = _crudPolicy;
 final items = [
 _GovernanceItem(Icons.verified_user_outlined, 'Access', policy.roleLabel, policy.roleColor),
 _GovernanceItem(Icons.add_circle_outline, 'Create',
 policy.canCreate ? 'Enabled' : 'Restricted',
 policy.canCreate ? const Color(0xFF10B981) : const Color(0xFF94A3B8)),
 _GovernanceItem(Icons.edit_outlined, 'Update',
 policy.canUpdate ? 'Enabled' : 'Read-only',
 policy.canUpdate ? const Color(0xFF0EA5E9) : const Color(0xFF94A3B8)),
 _GovernanceItem(Icons.delete_outline, 'Delete',
 policy.canDelete ? 'Admin only' : 'Restricted',
 policy.canDelete ? const Color(0xFFEF4444) : const Color(0xFF94A3B8)),
 ];

 return Container(
 width: double.infinity,
 padding: const EdgeInsets.all(14),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(12),
 border: Border.all(color: const Color(0xFFE2E8F0)),
 ),
 child: Wrap(
 spacing: 10,
 runSpacing: 10,
 alignment: WrapAlignment.spaceBetween,
 children: [
 ...items.map(_buildGovernancePill),
 Text(
 policy.hasProject
 ? 'Integration, scope, health, risk, and action controls are separated by access level per ISO 27001 A.9.'
 : 'Open a project to enable tools integration governance controls.',
 style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
 ),
 ],
 ),
 );
 }

 Widget _buildGovernancePill(_GovernanceItem item) {
 return Container(
 padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
 decoration: BoxDecoration(
 color: item.color.withOpacity(0.08),
 borderRadius: BorderRadius.circular(10),
 border: Border.all(color: item.color.withOpacity(0.18)),
 ),
 child: Row(
 mainAxisSize: MainAxisSize.min,
 children: [
 Icon(item.icon, size: 16, color: item.color),
 const SizedBox(width: 8),
 Text('${item.label}: ',
 style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
 Text(item.value,
 style: TextStyle(fontSize: 12, color: item.color, fontWeight: FontWeight.w700)),
 ],
 ),
 );
 }

 // ---------------------------------------------------------------------------
 // Stats row
 // ---------------------------------------------------------------------------

 Widget _buildStatsRow(bool isNarrow) {
 final connected = _integrations.where((i) => i.status == 'Connected').length;
 final degraded = _integrations.where((i) => i.status == 'Degraded').length;
 final notConnected = _integrations.where((i) => i.status == 'Not connected').length;
 final total = _integrations.length;

 final healthScore = total == 0 ? 0 : ((connected / total) * 100).round();
 final syncStatus = notConnected > 0 ? '$notConnected pending' : 'All synced';
 final openIssues = degraded + _riskSignals.where((s) => s.status == 'Open').length;

 final stats = [
 _StatCardData('$connected', 'Connected Tools',
 '$total total · $degraded degraded', const Color(0xFF0EA5E9)),
 _StatCardData('$healthScore%', 'Health Score',
 healthScore >= 80 ? 'Above threshold' : 'Below 80% target', healthScore >= 80 ? const Color(0xFF10B981) : const Color(0xFFF59E0B)),
 _StatCardData(syncStatus, 'Data Sync Status',
 notConnected == 0 ? 'All integrations synced' : '$notConnected not connected',
 notConnected == 0 ? const Color(0xFF10B981) : const Color(0xFFEF4444)),
 _StatCardData('$openIssues', 'Open Issues',
 openIssues > 0 ? 'Require attention' : 'All clear',
 openIssues > 0 ? const Color(0xFF6366F1) : const Color(0xFF10B981)),
 ];

 if (isNarrow) {
 return Wrap(
 spacing: 12,
 runSpacing: 12,
 children: stats.map(_buildStatCard).toList(),
 );
 }

 return Row(
 children: stats
 .map((stat) => Expanded(
 child: Padding(
 padding: const EdgeInsets.only(right: 12),
 child: _buildStatCard(stat),
 )))
 .toList(),
 );
 }

 Widget _buildStatCard(_StatCardData data) {
 return Container(
 padding: const EdgeInsets.all(16),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(12),
 border: Border.all(color: const Color(0xFFE2E8F0)),
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(data.value,
 style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: data.color)),
 const SizedBox(height: 6),
 Text(data.label, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
 const SizedBox(height: 6),
 Text(data.supporting,
 style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: data.color)),
 ],
 ),
 );
 }

 // ---------------------------------------------------------------------------
 // Framework guide
 // ---------------------------------------------------------------------------

 Widget _buildFrameworkGuide() {
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
 // Clickable header row
 InkWell(
 onTap: () => setState(() => _frameworkGuideExpanded = !_frameworkGuideExpanded),
 borderRadius: BorderRadius.circular(16),
 child: Padding(
 padding: const EdgeInsets.fromLTRB(20, 16, 16, 16),
 child: Row(
 children: [
 const Expanded(
 child: Text(
 'Tools integration framework',
 style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF111827)),
 ),
 ),
 AnimatedRotation(
 duration: const Duration(milliseconds: 200),
 turns: _frameworkGuideExpanded ? 0.5 : 0,
 child: Icon(
 Icons.expand_more,
 size: 22,
 color: const Color(0xFF6B7280),
 ),
 ),
 ],
 ),
 ),
 ),
 // Collapsible content
 AnimatedCrossFade(
 firstChild: const SizedBox(width: double.infinity, height: 0),
 secondChild: Padding(
 padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 const Text(
 'Grounded in ITIL Service Integration and Management (SIAM), PMI PMBOK 4.3 Direct & Manage Project Work, '
 'and ISO 27001 Annex A.12 Operations Security. Effective tools integration ensures that connected services '
 'maintain data integrity, access control, and operational continuity across the project delivery lifecycle.',
 style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF6B7280), height: 1.5),
 ),
 const SizedBox(height: 18),
 _buildGuideCard(
 Icons.sync_outlined,
 'Integration Lifecycle',
 'Connected → Syncing → Active → Degraded → Expired. '
 'Each integration should be tracked from initial connection through operational maturity. '
 'Set automated health checks at regular intervals and configure alerts for status transitions.',
 const Color(0xFF2563EB),
 ),
 const SizedBox(height: 12),
 _buildGuideCard(
 Icons.api_outlined,
 'Data Flow & API Governance',
 'Manage scope definitions, rate limiting, and error handling per ITIL SIAM data flow standards. '
 'Validate that all API integrations follow least-privilege access principles and document '
 'data mapping between integrated tools.',
 const Color(0xFF10B981),
 ),
 const SizedBox(height: 12),
 _buildGuideCard(
 Icons.security_outlined,
 'Security & Compliance',
 'Enforce OAuth 2.0 authentication, API key rotation schedules, and audit trails per ISO 27001 A.9 '
 'Access Control and A.12 Operations Security. Maintain credential inventories and validate '
 'encryption in transit for all data exchanges.',
 const Color(0xFFF59E0B),
 ),
 const SizedBox(height: 12),
 _buildGuideCard(
 Icons.monitor_heart_outlined,
 'Health Monitoring & Incident Response',
 'Automated health checks with configurable alerting thresholds and remediation workflows. '
 'Define escalation paths for degraded connections and maintain runbooks for common integration '
 'failure scenarios per ITIL Incident Management practices.',
 const Color(0xFFEF4444),
 ),
 ],
 ),
 ),
 crossFadeState: _frameworkGuideExpanded
 ? CrossFadeState.showSecond
 : CrossFadeState.showFirst,
 duration: const Duration(milliseconds: 250),
 sizeCurve: Curves.easeInOut,
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
 style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color),
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

 // ---------------------------------------------------------------------------
 // Integration Register (MAIN TABLE with CRUD)
 // ---------------------------------------------------------------------------

 Widget _buildIntegrationRegister() {
 final policy = _crudPolicy;
 final filtered = _filterIntegrations(_integrations);

 return _PanelShell(
 title: 'Integration register',
 subtitle: 'Track tool connections, scopes, sync status, and data mapping across the project toolchain',
 trailing: policy.canCreate
 ? _actionButton(Icons.add, 'Add tool', onPressed: () => _showIntegrationDialog())
 : null,
 child: Column(
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
 Expanded(flex: 3, child: Text('TOOL', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFFD1D5DB), letterSpacing: 0.5))),
 Expanded(flex: 2, child: Text('PROVIDER', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFFD1D5DB), letterSpacing: 0.5))),
 Expanded(flex: 2, child: Text('STATUS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFFD1D5DB), letterSpacing: 0.5))),
 Expanded(flex: 2, child: Text('SCOPES', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFFD1D5DB), letterSpacing: 0.5))),
 Expanded(flex: 2, child: Text('MAPS TO', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFFD1D5DB), letterSpacing: 0.5))),
 Expanded(flex: 2, child: Text('LAST SYNC', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFFD1D5DB), letterSpacing: 0.5))),
 SizedBox(width: 64, child: Text('ACTIONS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFFD1D5DB), letterSpacing: 0.5), textAlign: TextAlign.center)),
 ],
 ),
 ),
 const SizedBox(height: 4),
 if (filtered.isEmpty)
 Padding(
 padding: const EdgeInsets.all(32),
 child: Center(
 child: Column(
 children: [
 const Icon(Icons.extension_outlined, color: Color(0xFF9CA3AF), size: 32),
 const SizedBox(height: 12),
 const Text(
 'No integrations found. Add a tool to start tracking connections.',
 style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF6B7280)),
 ),
 ],
 ),
 ),
 )
 else
 ...filtered.asMap().entries.map((entry) {
 final idx = entry.key;
 final item = entry.value;
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
 // TOOL (name + subtitle)
 Expanded(
 flex: 3,
 child: Row(
 children: [
 Container(
 padding: const EdgeInsets.all(6),
 decoration: BoxDecoration(
 color: item.iconColor.withOpacity(0.1),
 borderRadius: BorderRadius.circular(6),
 ),
 child: Icon(item.icon, size: 16, color: item.iconColor),
 ),
 const SizedBox(width: 8),
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(item.name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF111827))),
 Text(item.subtitle, style: const TextStyle(fontSize: 10, color: Color(0xFF6B7280))),
 ],
 ),
 ),
 ],
 ),
 ),
 // PROVIDER
 Expanded(
 flex: 2,
 child: Text(item.provider, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF374151))),
 ),
 // STATUS
 Expanded(
 flex: 2,
 child: _buildStatusBadge(item.status),
 ),
 // SCOPES
 Expanded(
 flex: 2,
 child: Text(item.scopes, style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
 ),
 // MAPS TO
 Expanded(
 flex: 2,
 child: Text(item.mapsTo, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Color(0xFF374151))),
 ),
 // LAST SYNC
 Expanded(
 flex: 2,
 child: Text(item.lastSync, style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
 ),
 // ACTIONS
 SizedBox(
 width: 88,
 child: Row(
 mainAxisSize: MainAxisSize.min,
 children: [
 Tooltip(
 message: 'KAZ AI – Auto-fill this integration',
 child: InkWell(
 onTap: () => _kazAiAutoFillIntegration(item),
 child: _isKazAiLoadingRowId == item.id
 ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 1.5, color: Color(0xFFF59E0B)))
 : const Icon(Icons.auto_awesome, size: 14, color: Color(0xFFF59E0B)), 
 ),
 ),
 const SizedBox(width: 4),
 if (policy.canUpdate)
 InkWell(
 onTap: () => _showIntegrationDialog(existing: item),
 child: const Icon(Icons.edit_outlined, size: 14, color: Color(0xFF6B7280)),
 ),
 if (policy.canUpdate) const SizedBox(width: 4),
 if (policy.canDelete)
 InkWell(
 onTap: () => _confirmDeleteIntegration(item),
 child: const Icon(Icons.delete_outline, size: 14, color: Color(0xFFEF4444)),
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
 );
 }

 List<_IntegrationRow> _filterIntegrations(List<_IntegrationRow> items) {
 if (_selectedFilters.contains('All tools')) return items;
 return items.where((item) {
 if (_selectedFilters.contains('Connected') && item.status == 'Connected') return true;
 if (_selectedFilters.contains('Degraded') && item.status == 'Degraded') return true;
 if (_selectedFilters.contains('Not connected') && item.status == 'Not connected') return true;
 if (_selectedFilters.contains('Expired') && item.status == 'Expired') return true;
 return false;
 }).toList();
 }

 Widget _buildStatusBadge(String status) {
 Color bgColor;
 Color textColor;
 switch (status) {
 case 'Connected':
 case 'Active':
 case 'Approved':
 bgColor = const Color(0xFFECFDF5);
 textColor = const Color(0xFF059669);
 break;
 case 'Degraded':
 bgColor = const Color(0xFFFFFBEB);
 textColor = const Color(0xFFD97706);
 break;
 case 'Not connected':
 case 'Disabled':
 bgColor = const Color(0xFFF3F4F6);
 textColor = const Color(0xFF6B7280);
 break;
 case 'Expired':
 case 'Rejected':
 bgColor = const Color(0xFFFEF2F2);
 textColor = const Color(0xFFDC2626);
 break;
 case 'In Review':
 case 'In Progress':
 case 'Pending':
 bgColor = const Color(0xFFEFF6FF);
 textColor = const Color(0xFF2563EB);
 break;
 case 'Not Started':
 bgColor = const Color(0xFFF9FAFB);
 textColor = const Color(0xFF9CA3AF);
 break;
 default:
 bgColor = const Color(0xFFF3F4F6);
 textColor = const Color(0xFF6B7280);
 }
 return Container(
 padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
 decoration: BoxDecoration(
 color: bgColor,
 borderRadius: BorderRadius.circular(4),
 ),
 child: Text(status,
 style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: textColor)),
 );
 }

 // ---------------------------------------------------------------------------
 // Connection Health Panel (KPI metrics with progress bars)
 // ---------------------------------------------------------------------------

 Widget _buildConnectionHealthPanel() {
 final connected = _integrations.where((i) => i.status == 'Connected').length;
 final total = _integrations.length;
 final apiResponsePct = total == 0 ? 0.0 : (connected / total) * 0.95 + 0.04;
 final syncSuccessPct = total == 0 ? 0.88 : (connected / total) * 0.85 + 0.05;
 final tokenRefreshPct = total == 0 ? 0.96 : 0.94 + (connected / total) * 0.04;
 final errorRatePct = total == 0 ? 0.03 : 0.02 + (_integrations.where((i) => i.status == 'Degraded').length / total) * 0.05;

 final autoKpis = <_KpiRow>[
 _KpiRow(id: 'auto_api', metric: 'API Response Time', value: apiResponsePct.clamp(0.0, 1.0), target: 0.95, trend: apiResponsePct >= 0.95 ? 'On target' : 'Below target', owner: 'Operations Lead', source: 'Auto-computed'),
 _KpiRow(id: 'auto_sync', metric: 'Sync Success Rate', value: syncSuccessPct.clamp(0.0, 1.0), target: 0.90, trend: syncSuccessPct >= 0.90 ? 'On target' : 'Below target', owner: 'Integration Lead', source: 'Auto-computed'),
 _KpiRow(id: 'auto_token', metric: 'Token Refresh Rate', value: tokenRefreshPct.clamp(0.0, 1.0), target: 0.95, trend: tokenRefreshPct >= 0.95 ? 'On target' : 'Below target', owner: 'Security Lead', source: 'Auto-computed'),
 _KpiRow(id: 'auto_error', metric: 'Error Rate', value: errorRatePct.clamp(0.0, 1.0), target: 0.05, trend: errorRatePct <= 0.05 ? 'On target' : 'Above threshold', owner: 'Operations Lead', source: 'Auto-computed'),
 ];

 final allKpis = [...autoKpis, ..._customKpiRows];

 return _PanelShell(
 title: 'Connection health',
 subtitle: 'Key integration health indicators auto-computed from connection statuses',
 trailing: TextButton.icon(
 onPressed: () => _showKpiEntryDialog(),
 icon: const Icon(Icons.add_rounded, size: 16),
 label: const Text('Add metric'),
 style: TextButton.styleFrom(
 foregroundColor: const Color(0xFF4154F1),
 padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
 ),
 ),
 child: Column(
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
 Expanded(flex: 3, child: Text('KPI METRIC', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFFD1D5DB), letterSpacing: 0.5))),
 Expanded(flex: 1, child: Text('ACTUAL', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFFD1D5DB), letterSpacing: 0.5))),
 Expanded(flex: 1, child: Text('TARGET', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFFD1D5DB), letterSpacing: 0.5))),
 Expanded(flex: 1, child: Text('GAP', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFFD1D5DB), letterSpacing: 0.5))),
 Expanded(flex: 2, child: Text('TREND', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFFD1D5DB), letterSpacing: 0.5))),
 Expanded(flex: 2, child: Text('OWNER', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFFD1D5DB), letterSpacing: 0.5))),
 Expanded(flex: 1, child: Text('', style: TextStyle(fontSize: 10))),
 ],
 ),
 ),
 const SizedBox(height: 4),
 ...allKpis.asMap().entries.map((entry) {
 final row = entry.value;
 final idx = entry.key;
 final isAuto = row.source == 'Auto-computed';
 final isInverse = row.metric == 'Error Rate';
 final gap = isInverse ? row.target - row.value : row.value - row.target;
 final gapColor = gap >= 0 ? const Color(0xFF059669) : const Color(0xFFDC2626);
 final barColor = _kpiColor(isInverse ? (1.0 - row.value) : row.value);

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
 onTap: () => _showKpiEntryDialog(existing: row),
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
 ),
 );
 }

 Color _kpiColor(double value) {
 if (value >= 0.80) return const Color(0xFF059669);
 if (value >= 0.60) return const Color(0xFFD97706);
 return const Color(0xFFDC2626);
 }

 // ---------------------------------------------------------------------------
 // Risk Signals Panel
 // ---------------------------------------------------------------------------

 Widget _buildRiskSignalsPanel() {
 final policy = _crudPolicy;

 return _PanelShell(
 title: 'Risk signals',
 subtitle: 'Active alerts and integration watch items requiring attention',
 trailing: policy.canCreate
 ? TextButton.icon(
 onPressed: () => _showRiskSignalDialog(),
 icon: const Icon(Icons.add_rounded, size: 16),
 label: const Text('Add signal'),
 style: TextButton.styleFrom(
 foregroundColor: const Color(0xFF4154F1),
 padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
 ),
 )
 : null,
 child: _riskSignals.isEmpty
 ? Center(
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
 )
 : Column(
 children: [
 // Table header
 Container(
 padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
 decoration: const BoxDecoration(
 color: Color(0xFF1F2937),
 borderRadius: BorderRadius.all(Radius.circular(8)),
 ),
 child: const Row(
 children: [
 Expanded(flex: 3, child: Text('SIGNAL', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFFD1D5DB), letterSpacing: 0.5))),
 Expanded(flex: 3, child: Text('DESCRIPTION', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFFD1D5DB), letterSpacing: 0.5))),
 SizedBox(width: 110, child: Text('SEVERITY', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFFD1D5DB), letterSpacing: 0.5), textAlign: TextAlign.center)),
 Expanded(flex: 2, child: Text('OWNER', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFFD1D5DB), letterSpacing: 0.5))),
 SizedBox(width: 110, child: Text('STATUS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFFD1D5DB), letterSpacing: 0.5), textAlign: TextAlign.center)),
 SizedBox(width: 52, child: Text('', style: TextStyle(fontSize: 10))),
 ],
 ),
 ),
 const SizedBox(height: 4),
 ..._riskSignals.asMap().entries.map((entry) {
 final idx = entry.key;
 final sig = entry.value;
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
 child: Text(sig.signal, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF111827))),
 ),
 Expanded(
 flex: 3,
 child: Text(sig.description, style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
 ),
 SizedBox(
 width: 110,
 child: _buildSeverityBadge(sig.severity),
 ),
 Expanded(
 flex: 2,
 child: Text(sig.owner, style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
 ),
 SizedBox(
 width: 110,
 child: _buildStatusBadge(sig.status),
 ),
 SizedBox(
 width: 52,
 child: Row(
 mainAxisSize: MainAxisSize.min,
 children: [
 if (policy.canUpdate)
 InkWell(
 onTap: () => _showRiskSignalDialog(existing: sig),
 child: const Icon(Icons.edit_outlined, size: 14, color: Color(0xFF6B7280)),
 ),
 if (policy.canDelete) const SizedBox(width: 4),
 if (policy.canDelete)
 InkWell(
 onTap: () => _deleteRiskSignal(sig.id),
 child: const Icon(Icons.delete_outline, size: 14, color: Color(0xFFEF4444)),
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
 );
 }

 Widget _buildSeverityBadge(String severity) {
 Color bgColor;
 Color textColor;
 switch (severity) {
 case 'Critical':
 bgColor = const Color(0xFFFEF2F2);
 textColor = const Color(0xFFDC2626);
 break;
 case 'High':
 bgColor = const Color(0xFFFFFBEB);
 textColor = const Color(0xFFD97706);
 break;
 case 'Medium':
 bgColor = const Color(0xFFEFF6FF);
 textColor = const Color(0xFF2563EB);
 break;
 default:
 bgColor = const Color(0xFFF3F4F6);
 textColor = const Color(0xFF6B7280);
 }
 return Container(
 padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
 decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(4)),
 child: Text(severity, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: textColor), textAlign: TextAlign.center),
 );
 }

 // ---------------------------------------------------------------------------
 // Action Items Panel
 // ---------------------------------------------------------------------------

 Widget _buildActionItemsPanel() {
 final policy = _crudPolicy;

 return _PanelShell(
 title: 'Action items',
 subtitle: 'Integration-related tasks, credential rotations, and scope updates',
 trailing: policy.canCreate
 ? TextButton.icon(
 onPressed: () => _showActionDialog(),
 icon: const Icon(Icons.add_rounded, size: 16),
 label: const Text('Add action'),
 style: TextButton.styleFrom(
 foregroundColor: const Color(0xFF4154F1),
 padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
 ),
 )
 : null,
 child: _actionRows.isEmpty
 ? Center(
 child: Padding(
 padding: const EdgeInsets.all(24.0),
 child: Column(
 mainAxisSize: MainAxisSize.min,
 children: [
 Icon(Icons.check_circle_outline, size: 36, color: const Color(0xFF10B981).withOpacity(0.6)),
 const SizedBox(height: 8),
 const Text('No pending actions', style: TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.w600)),
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
 borderRadius: BorderRadius.all(Radius.circular(8)),
 ),
 child: const Row(
 children: [
 Expanded(flex: 4, child: Text('ACTION', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFFD1D5DB), letterSpacing: 0.5))),
 SizedBox(width: 110, child: Text('PRIORITY', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFFD1D5DB), letterSpacing: 0.5), textAlign: TextAlign.center)),
 SizedBox(width: 110, child: Text('DUE DATE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFFD1D5DB), letterSpacing: 0.5), textAlign: TextAlign.center)),
 Expanded(flex: 2, child: Text('OWNER', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFFD1D5DB), letterSpacing: 0.5))),
 SizedBox(width: 120, child: Text('STATUS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFFD1D5DB), letterSpacing: 0.5), textAlign: TextAlign.center)),
 SizedBox(width: 52, child: Text('', style: TextStyle(fontSize: 10))),
 ],
 ),
 ),
 const SizedBox(height: 4),
 ..._actionRows.asMap().entries.map((entry) {
 final idx = entry.key;
 final act = entry.value;
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
 flex: 4,
 child: Text(act.title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF111827))),
 ),
 SizedBox(
 width: 110,
 child: _buildSeverityBadge(act.priority),
 ),
 SizedBox(
 width: 110,
 child: Text(act.dueDate, style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280)), textAlign: TextAlign.center),
 ),
 Expanded(
 flex: 2,
 child: Text(act.owner, style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
 ),
 SizedBox(
 width: 120,
 child: _buildStatusBadge(act.status),
 ),
 SizedBox(
 width: 52,
 child: Row(
 mainAxisSize: MainAxisSize.min,
 children: [
 if (policy.canUpdate)
 InkWell(
 onTap: () => _showActionDialog(existing: act),
 child: const Icon(Icons.edit_outlined, size: 14, color: Color(0xFF6B7280)),
 ),
 if (policy.canDelete) const SizedBox(width: 4),
 if (policy.canDelete)
 InkWell(
 onTap: () => _deleteActionRow(act.id),
 child: const Icon(Icons.delete_outline, size: 14, color: Color(0xFFEF4444)),
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
 );
 }

 // ---------------------------------------------------------------------------
 // KAZ AI integration
 // ---------------------------------------------------------------------------

 String? _isKazAiLoadingRowId;

 Future<void> _kazAiAutoFillIntegration(_IntegrationRow item) async {
 if (_isKazAiLoadingRowId != null) return;
 setState(() => _isKazAiLoadingRowId = item.id);
 try {
 final ai = OpenAiServiceSecure();
 final result = await ai.generateCompletion(
 'For a project tool integration named "${item.name}" (${item.provider}), generate a concise 1-2 sentence description of its features and capabilities. Return ONLY the text.',
 maxTokens: 200,
 temperature: 0.6,
 );
 final cleaned = result.trim();
 if (cleaned.isNotEmpty && mounted) {
 final idx = _integrations.indexWhere((r) => r.id == item.id);
 if (idx != -1) {
 setState(() {
 _integrations[idx] = item.copyWith(features: cleaned);
 });
 _scheduleSave();
 }
 }
 } catch (e) {
 debugPrint('KAZ AI integration generation failed: $e');
 if (mounted) {
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(content: Text('KAZ AI generation failed: $e'), backgroundColor: const Color(0xFFDC2626)),
 );
 }
 } finally {
 if (mounted) setState(() => _isKazAiLoadingRowId = null);
 }
 }

 Future<void> _kazAiGenerateField({
 required String label,
 required TextEditingController controller,
 required StateSetter setDialogState,
 String? contextHint,
 }) async {
 try {
 final ai = OpenAiServiceSecure();
 final result = await ai.generateCompletion(
 'Based on this project context, generate a $label for a tools integration.\n\nContext: ${contextHint ?? 'Tools Integration page'}\n\nProvide a concise, specific, actionable response (1-2 sentences). Return ONLY the text content (no JSON, no markdown headers).',
 maxTokens: 200,
 temperature: 0.6,
 );
 final cleaned = result.trim();
 if (cleaned.isNotEmpty) {
 setDialogState(() => controller.text = cleaned);
 }
 } catch (e) {
 debugPrint('KAZ AI field generation failed: $e');
 if (mounted) {
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(content: Text('KAZ AI failed: $e'), backgroundColor: const Color(0xFFDC2626)),
 );
 }
 }
 }

 Widget _buildKazAiPillButton({
 required String label,
 required TextEditingController controller,
 required StateSetter setDialogState,
 }) {
 bool isLoading = false;
 return StatefulBuilder(
 builder: (context, setLocalState) => InkWell(
 onTap: isLoading
 ? null
 : () async {
 setLocalState(() => isLoading = true);
 await _kazAiGenerateField(
 label: label,
 controller: controller,
 setDialogState: setDialogState,
 );
 if (context.mounted) setLocalState(() => isLoading = false);
 },
 child: Container(
 padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
 decoration: BoxDecoration(
 color: const Color(0xFFF59E0B).withOpacity(0.1),
 borderRadius: BorderRadius.circular(6),
 border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.3)),
 ),
 child: Row(
 mainAxisSize: MainAxisSize.min,
 children: [
 isLoading
 ? const SizedBox(width: 10, height: 10, child: CircularProgressIndicator(strokeWidth: 1.5, color: Color(0xFFF59E0B)))
 : const Icon(Icons.auto_awesome, size: 10, color: Color(0xFFF59E0B)),
 const SizedBox(width: 3),
 const Text('KAZ AI', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Color(0xFFF59E0B))),
 ],
 ),
 ),
 ),
 );
 }

 // ---------------------------------------------------------------------------
 // Dialog: Add/Edit Integration
 // ---------------------------------------------------------------------------

 void _showIntegrationDialog({_IntegrationRow? existing}) {
 final isEdit = existing != null;
 final nameCtl = TextEditingController(text: existing?.name ?? '');
 final subtitleCtl = TextEditingController(text: existing?.subtitle ?? '');
 final providerCtl = TextEditingController(text: existing?.provider ?? 'Figma');
 final scopesCtl = TextEditingController(text: existing?.scopes ?? '');
 final mapsToCtl = TextEditingController(text: existing?.mapsTo ?? '');
 final featuresCtl = TextEditingController(text: existing?.features ?? '');
 String status = existing?.status ?? 'Not connected';
 IconData icon = existing?.icon ?? Icons.extension;
 Color iconColor = existing?.iconColor ?? const Color(0xFF64748B);

 showDialog(
 context: context,
 builder: (ctx) => StatefulBuilder(
 builder: (context, setDialogState) => AlertDialog(
 title: Row(
 children: [
 Icon(isEdit ? Icons.edit_outlined : Icons.add_circle_outline, size: 20, color: const Color(0xFF4154F1)),
 const SizedBox(width: 8),
 Text(isEdit ? 'Edit Integration' : 'Add Integration', style: const TextStyle(fontSize: 16)),
 ],
 ),
 content: SizedBox(
 width: 520,
 child: SingleChildScrollView(
 child: Column(
 mainAxisSize: MainAxisSize.min,
 children: [
 DropdownButtonFormField<String>(
 value: providerCtl.text,
 items: ['Figma', 'Draw.io', 'Miro', 'Whiteboard', 'Jira', 'GitHub', 'Custom']
 .map((p) => DropdownMenuItem(value: p, child: Text(p)))
 .toList(),
 onChanged: (value) {
 if (value == null) return;
 providerCtl.text = value;
 setDialogState(() {
 icon = _providerIcon(value);
 iconColor = _providerColor(value);
 if (!isEdit) {
 nameCtl.text = value;
 subtitleCtl.text = _providerSubtitle(value);
 scopesCtl.text = _providerScopes(value);
 mapsToCtl.text = _providerMapping(value);
 featuresCtl.text = _providerFeatureHint(value);
 }
 });
 },
 decoration: const InputDecoration(labelText: 'Provider', border: OutlineInputBorder()),
 ),
 const SizedBox(height: 12),
 _buildKazAiPillButton(label: 'Tool name', controller: nameCtl, setDialogState: setDialogState),
 const SizedBox(height: 4),
 VoiceTextField(controller: nameCtl, decoration: const InputDecoration(labelText: 'Tool name', border: OutlineInputBorder())),
 const SizedBox(height: 12),
 _buildKazAiPillButton(label: 'Subtitle', controller: subtitleCtl, setDialogState: setDialogState),
 const SizedBox(height: 4),
 VoiceTextField(controller: subtitleCtl, decoration: const InputDecoration(labelText: 'Subtitle', border: OutlineInputBorder())),
 const SizedBox(height: 12),
 DropdownButtonFormField<String>(
 value: status,
 items: ['Connected', 'Degraded', 'Not connected', 'Expired']
 .map((s) => DropdownMenuItem(value: s, child: Text(s)))
 .toList(),
 onChanged: (value) {
 if (value == null) return;
 setDialogState(() => status = value);
 },
 decoration: const InputDecoration(labelText: 'Status', border: OutlineInputBorder()),
 ),
 const SizedBox(height: 12),
 _buildKazAiPillButton(label: 'API scopes', controller: scopesCtl, setDialogState: setDialogState),
 const SizedBox(height: 4),
 VoiceTextField(controller: scopesCtl, decoration: const InputDecoration(labelText: 'Scopes (comma-separated)', border: OutlineInputBorder())),
 const SizedBox(height: 12),
 _buildKazAiPillButton(label: 'Mapping target', controller: mapsToCtl, setDialogState: setDialogState),
 const SizedBox(height: 4),
 VoiceTextField(controller: mapsToCtl, decoration: const InputDecoration(labelText: 'Maps to', border: OutlineInputBorder())),
 const SizedBox(height: 12),
 _buildKazAiPillButton(label: 'Features and capabilities', controller: featuresCtl, setDialogState: setDialogState),
 const SizedBox(height: 4),
 VoiceTextField(controller: featuresCtl, maxLines: 2, decoration: const InputDecoration(labelText: 'Features / notes', border: OutlineInputBorder())),
 ],
 ),
 ),
 ),
 actions: [
 TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
 FilledButton(
 onPressed: () {
 final row = _IntegrationRow(
 id: existing?.id ?? _newId(),
 name: nameCtl.text.trim(),
 subtitle: subtitleCtl.text.trim(),
 provider: providerCtl.text.trim(),
 status: status,
 scopes: scopesCtl.text.trim(),
 mapsTo: mapsToCtl.text.trim(),
 lastSync: existing?.lastSync ?? 'Never',
 icon: icon,
 iconColor: iconColor,
 features: featuresCtl.text.trim(),
 autoHandoff: existing?.autoHandoff,
 syncMode: existing?.syncMode,
 errorInfo: existing?.errorInfo,
 );
 setState(() {
 if (isEdit) {
 final idx = _integrations.indexWhere((r) => r.id == row.id);
 if (idx != -1) _integrations[idx] = row;
 } else {
 _integrations.add(row);
 }
 });
 _scheduleSave();
 _logActivity(isEdit ? 'Edited tool integration' : 'Added tool integration', details: {'itemId': row.id});
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

 void _confirmDeleteIntegration(_IntegrationRow item) {
 showDialog(
 context: context,
 builder: (ctx) => AlertDialog(
 title: const Text('Delete Integration'),
 content: Text('Are you sure you want to remove "${item.name}" from the integration register? This action cannot be undone.'),
 actions: [
 TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
 FilledButton(
 onPressed: () {
 _deleteIntegration(item.id);
 Navigator.of(ctx).pop();
 },
 style: FilledButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
 child: const Text('Delete'),
 ),
 ],
 ),
 );
 }

 // ---------------------------------------------------------------------------
 // Dialog: Add/Edit KPI metric
 // ---------------------------------------------------------------------------

 void _showKpiEntryDialog({_KpiRow? existing}) {
 final isEdit = existing != null;
 final metricCtl = TextEditingController(text: existing?.metric ?? '');
 final valueCtl = TextEditingController(text: existing != null ? '${(existing.value * 100).round()}' : '');
 final targetCtl = TextEditingController(text: existing != null ? '${(existing.target * 100).round()}' : '90');
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
 content: SizedBox(
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
 actions: [
 TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
 FilledButton(
 onPressed: () {
 final val = (int.tryParse(valueCtl.text.trim()) ?? 0).clamp(0, 100) / 100.0;
 final tgt = (int.tryParse(targetCtl.text.trim()) ?? 90).clamp(0, 100) / 100.0;
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
 _scheduleSave();
 _logActivity(isEdit ? 'Edited KPI metric' : 'Added KPI metric', details: {'itemId': row.id});
 Navigator.of(ctx).pop();
 },
 style: FilledButton.styleFrom(backgroundColor: const Color(0xFF4154F1), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
 child: Text(isEdit ? 'Save' : 'Add'),
 ),
 ],
 ),
 );
 }

 // ---------------------------------------------------------------------------
 // Dialog: Add/Edit Risk Signal
 // ---------------------------------------------------------------------------

 void _showRiskSignalDialog({_RiskSignalRow? existing}) {
 final isEdit = existing != null;
 final signalCtl = TextEditingController(text: existing?.signal ?? '');
 final descCtl = TextEditingController(text: existing?.description ?? '');
 final ownerCtl = TextEditingController(text: existing?.owner ?? '');
 String severity = existing?.severity ?? 'Medium';
 String category = existing?.category ?? 'Governance';
 String status = existing?.status ?? 'Open';

 showDialog(
 context: context,
 builder: (ctx) => StatefulBuilder(
 builder: (context, setDialogState) => AlertDialog(
 title: Row(
 children: [
 Icon(isEdit ? Icons.edit_outlined : Icons.add_circle_outline, size: 20, color: const Color(0xFF4154F1)),
 const SizedBox(width: 8),
 Text(isEdit ? 'Edit Risk Signal' : 'Add Risk Signal', style: const TextStyle(fontSize: 16)),
 ],
 ),
 content: SizedBox(
 width: 480,
 child: SingleChildScrollView(
 child: Column(
 mainAxisSize: MainAxisSize.min,
 children: [
 VoiceTextField(controller: signalCtl, decoration: const InputDecoration(labelText: 'Signal name', border: OutlineInputBorder())),
 const SizedBox(height: 12),
 VoiceTextField(controller: descCtl, maxLines: 2, decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder())),
 const SizedBox(height: 12),
 Row(children: [
 Expanded(
 child: DropdownButtonFormField<String>(
 value: severity,
 items: ['Critical', 'High', 'Medium', 'Low'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
 onChanged: (v) { if (v != null) setDialogState(() => severity = v); },
 decoration: const InputDecoration(labelText: 'Severity', border: OutlineInputBorder()),
 ),
 ),
 const SizedBox(width: 12),
 Expanded(
 child: DropdownButtonFormField<String>(
 value: category,
 items: ['Connectivity', 'Authentication', 'Governance', 'Security', 'Performance'].map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
 onChanged: (v) { if (v != null) setDialogState(() => category = v); },
 decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder()),
 ),
 ),
 ]),
 const SizedBox(height: 12),
 Row(children: [
 Expanded(child: VoiceTextField(controller: ownerCtl, decoration: const InputDecoration(labelText: 'Owner', border: OutlineInputBorder()))),
 const SizedBox(width: 12),
 Expanded(
 child: DropdownButtonFormField<String>(
 value: status,
 items: ['Open', 'Monitoring', 'Resolved', 'Escalated'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
 onChanged: (v) { if (v != null) setDialogState(() => status = v); },
 decoration: const InputDecoration(labelText: 'Status', border: OutlineInputBorder()),
 ),
 ),
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
 id: existing?.id ?? _newId(),
 signal: signalCtl.text.trim(),
 description: descCtl.text.trim(),
 severity: severity,
 category: category,
 owner: ownerCtl.text.trim(),
 source: existing?.source ?? 'Manual',
 status: status,
 );
 setState(() {
 if (isEdit) {
 final idx = _riskSignals.indexWhere((r) => r.id == row.id);
 if (idx != -1) _riskSignals[idx] = row;
 } else {
 _riskSignals.add(row);
 }
 });
 _scheduleSave();
 _logActivity(isEdit ? 'Edited risk signal' : 'Added risk signal', details: {'itemId': row.id});
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

 // ---------------------------------------------------------------------------
 // Dialog: Add/Edit Action Item
 // ---------------------------------------------------------------------------

 void _showActionDialog({_ActionRow? existing}) {
 final isEdit = existing != null;
 final titleCtl = TextEditingController(text: existing?.title ?? '');
 final ownerCtl = TextEditingController(text: existing?.owner ?? '');
 final dueDateCtl = TextEditingController(text: existing?.dueDate ?? 'TBD');
 String priority = existing?.priority ?? 'Medium';
 String status = existing?.status ?? 'Not Started';

 showDialog(
 context: context,
 builder: (ctx) => StatefulBuilder(
 builder: (context, setDialogState) => AlertDialog(
 title: Row(
 children: [
 Icon(isEdit ? Icons.edit_outlined : Icons.add_circle_outline, size: 20, color: const Color(0xFF4154F1)),
 const SizedBox(width: 8),
 Text(isEdit ? 'Edit Action Item' : 'Add Action Item', style: const TextStyle(fontSize: 16)),
 ],
 ),
 content: SizedBox(
 width: 480,
 child: SingleChildScrollView(
 child: Column(
 mainAxisSize: MainAxisSize.min,
 children: [
 VoiceTextField(controller: titleCtl, decoration: const InputDecoration(labelText: 'Action title', border: OutlineInputBorder())),
 const SizedBox(height: 12),
 Row(children: [
 Expanded(
 child: DropdownButtonFormField<String>(
 value: priority,
 items: ['Critical', 'High', 'Medium', 'Low'].map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
 onChanged: (v) { if (v != null) setDialogState(() => priority = v); },
 decoration: const InputDecoration(labelText: 'Priority', border: OutlineInputBorder()),
 ),
 ),
 const SizedBox(width: 12),
 Expanded(child: VoiceTextField(controller: dueDateCtl, decoration: const InputDecoration(labelText: 'Due date', border: OutlineInputBorder()))),
 ]),
 const SizedBox(height: 12),
 Row(children: [
 Expanded(child: VoiceTextField(controller: ownerCtl, decoration: const InputDecoration(labelText: 'Owner', border: OutlineInputBorder()))),
 const SizedBox(width: 12),
 Expanded(
 child: DropdownButtonFormField<String>(
 value: status,
 items: ['Not Started', 'In Progress', 'Pending', 'Completed'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
 onChanged: (v) { if (v != null) setDialogState(() => status = v); },
 decoration: const InputDecoration(labelText: 'Status', border: OutlineInputBorder()),
 ),
 ),
 ]),
 ],
 ),
 ),
 ),
 actions: [
 TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
 FilledButton(
 onPressed: () {
 final row = _ActionRow(
 id: existing?.id ?? _newId(),
 title: titleCtl.text.trim(),
 priority: priority,
 dueDate: dueDateCtl.text.trim(),
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
 _scheduleSave();
 _logActivity(isEdit ? 'Edited action item' : 'Added action item', details: {'itemId': row.id});
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

 // ---------------------------------------------------------------------------
 // Panel: Integration Compliance & Gate Approval
 // ---------------------------------------------------------------------------

 Widget _buildApprovalGatesPanel() {
 final policy = _crudPolicy;

 return _PanelShell(
 title: 'Integration compliance & gate approval',
 subtitle: 'Integration approval gates aligned with ITIL Service Integration, ISO 27001 A.14 Security Development, and PMI PMBOK 4.3 Direct & Manage Project Work. Verify that each integration meets security, data governance, and operational readiness criteria before activation.',
 trailing: policy.canCreate
 ? TextButton.icon(
 onPressed: () => _showApprovalGateDialog(),
 icon: const Icon(Icons.add_rounded, size: 16),
 label: const Text('Add gate'),
 style: TextButton.styleFrom(
 foregroundColor: const Color(0xFF4154F1),
 padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
 ),
 )
 : null,
 child: _approvalGates.isEmpty
 ? Center(
 child: Padding(
 padding: const EdgeInsets.all(24.0),
 child: Column(
 mainAxisSize: MainAxisSize.min,
 children: [
 Icon(Icons.verified_outlined, size: 36, color: const Color(0xFF10B981).withOpacity(0.6)),
 const SizedBox(height: 8),
 const Text('All gates cleared', style: TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.w600)),
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
 borderRadius: BorderRadius.all(Radius.circular(8)),
 ),
 child: const Row(
 children: [
 Expanded(flex: 3, child: Text('GATE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFFD1D5DB), letterSpacing: 0.5))),
 Expanded(flex: 4, child: Text('DESCRIPTION', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFFD1D5DB), letterSpacing: 0.5))),
 Expanded(flex: 2, child: Text('APPROVER', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFFD1D5DB), letterSpacing: 0.5))),
 SizedBox(width: 110, child: Text('DEPT', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFFD1D5DB), letterSpacing: 0.5), textAlign: TextAlign.center)),
 SizedBox(width: 72, child: Text('PRIORITY', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFFD1D5DB), letterSpacing: 0.5), textAlign: TextAlign.center)),
 SizedBox(width: 110, child: Text('STATUS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFFD1D5DB), letterSpacing: 0.5), textAlign: TextAlign.center)),
 SizedBox(width: 72, child: Text('TARGET', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFFD1D5DB), letterSpacing: 0.5), textAlign: TextAlign.center)),
 SizedBox(width: 52, child: Text('', style: TextStyle(fontSize: 10))),
 ],
 ),
 ),
 const SizedBox(height: 4),
 ..._approvalGates.asMap().entries.map((entry) {
 final idx = entry.key;
 final gate = entry.value;
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
 child: Text(gate.gate, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF111827))),
 ),
 Expanded(
 flex: 4,
 child: Text(gate.description, style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280)), maxLines: 2, overflow: TextOverflow.ellipsis),
 ),
 Expanded(
 flex: 2,
 child: Text(gate.approver, style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
 ),
 SizedBox(
 width: 110,
 child: Text(gate.department, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Color(0xFF374151)), textAlign: TextAlign.center),
 ),
 SizedBox(
 width: 72,
 child: _buildSeverityBadge(gate.priority),
 ),
 SizedBox(
 width: 110,
 child: _buildStatusBadge(gate.status),
 ),
 SizedBox(
 width: 72,
 child: Text(gate.targetDate, style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280)), textAlign: TextAlign.center),
 ),
 SizedBox(
 width: 52,
 child: Row(
 mainAxisSize: MainAxisSize.min,
 children: [
 if (policy.canUpdate)
 InkWell(
 onTap: () => _showApprovalGateDialog(existing: gate),
 child: const Icon(Icons.edit_outlined, size: 14, color: Color(0xFF6B7280)),
 ),
 if (policy.canDelete) const SizedBox(width: 4),
 if (policy.canDelete)
 InkWell(
 onTap: () => _confirmDeleteApprovalGate(gate),
 child: const Icon(Icons.delete_outline, size: 14, color: Color(0xFFEF4444)),
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
 );
 }

 // ---------------------------------------------------------------------------
 // Panel: Data Flow & API Mapping
 // ---------------------------------------------------------------------------

 Widget _buildDataFlowPanel() {
 final policy = _crudPolicy;

 return _PanelShell(
 title: 'Data flow & API mapping',
 subtitle: 'Track data exchange pathways, API endpoints, and transformation rules between integrated tools per ITIL SIAM data flow management and ISO 20022 messaging standards.',
 trailing: policy.canCreate
 ? TextButton.icon(
 onPressed: () => _showDataFlowDialog(),
 icon: const Icon(Icons.add_rounded, size: 16),
 label: const Text('Add flow'),
 style: TextButton.styleFrom(
 foregroundColor: const Color(0xFF4154F1),
 padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
 ),
 )
 : null,
 child: _dataFlows.isEmpty
 ? Center(
 child: Padding(
 padding: const EdgeInsets.all(24.0),
 child: Column(
 mainAxisSize: MainAxisSize.min,
 children: [
 Icon(Icons.swap_horiz, size: 36, color: const Color(0xFF9CA3AF).withOpacity(0.6)),
 const SizedBox(height: 8),
 const Text('No data flows configured', style: TextStyle(color: Color(0xFF6B7280), fontWeight: FontWeight.w600)),
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
 borderRadius: BorderRadius.all(Radius.circular(8)),
 ),
 child: const Row(
 children: [
 Expanded(flex: 2, child: Text('SOURCE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFFD1D5DB), letterSpacing: 0.5))),
 Expanded(flex: 2, child: Text('TARGET', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFFD1D5DB), letterSpacing: 0.5))),
 Expanded(flex: 2, child: Text('DATA TYPE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFFD1D5DB), letterSpacing: 0.5))),
 Expanded(flex: 2, child: Text('API METHOD', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFFD1D5DB), letterSpacing: 0.5))),
 SizedBox(width: 110, child: Text('FREQUENCY', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFFD1D5DB), letterSpacing: 0.5), textAlign: TextAlign.center)),
 Expanded(flex: 3, child: Text('TRANSFORMATION', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFFD1D5DB), letterSpacing: 0.5))),
 SizedBox(width: 110, child: Text('STATUS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFFD1D5DB), letterSpacing: 0.5), textAlign: TextAlign.center)),
 SizedBox(width: 52, child: Text('', style: TextStyle(fontSize: 10))),
 ],
 ),
 ),
 const SizedBox(height: 4),
 ..._dataFlows.asMap().entries.map((entry) {
 final idx = entry.key;
 final flow = entry.value;
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
 flex: 2,
 child: Text(flow.source, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF111827))),
 ),
 Expanded(
 flex: 2,
 child: Text(flow.target, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF111827))),
 ),
 Expanded(
 flex: 2,
 child: Text(flow.dataType, style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
 ),
 Expanded(
 flex: 2,
 child: Text(flow.apiMethod, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Color(0xFF374151))),
 ),
 SizedBox(
 width: 110,
 child: Text(flow.frequency, style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280)), textAlign: TextAlign.center),
 ),
 Expanded(
 flex: 3,
 child: Text(flow.transformation, style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280)), maxLines: 2, overflow: TextOverflow.ellipsis),
 ),
 SizedBox(
 width: 110,
 child: _buildStatusBadge(flow.status),
 ),
 SizedBox(
 width: 52,
 child: Row(
 mainAxisSize: MainAxisSize.min,
 children: [
 if (policy.canUpdate)
 InkWell(
 onTap: () => _showDataFlowDialog(existing: flow),
 child: const Icon(Icons.edit_outlined, size: 14, color: Color(0xFF6B7280)),
 ),
 if (policy.canDelete) const SizedBox(width: 4),
 if (policy.canDelete)
 InkWell(
 onTap: () => _confirmDeleteDataFlow(flow),
 child: const Icon(Icons.delete_outline, size: 14, color: Color(0xFFEF4444)),
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
 );
 }

 // ---------------------------------------------------------------------------
 // Dialog: Add/Edit Approval Gate
 // ---------------------------------------------------------------------------

 void _showApprovalGateDialog({_ApprovalGateData? existing}) {
 final isEdit = existing != null;
 final gateCtl = TextEditingController(text: existing?.gate ?? '');
 final descCtl = TextEditingController(text: existing?.description ?? '');
 final approverCtl = TextEditingController(text: existing?.approver ?? '');
 final targetDateCtl = TextEditingController(text: existing?.targetDate ?? 'TBD');
 String department = existing?.department ?? 'Security';
 String priority = existing?.priority ?? 'High';
 String status = existing?.status ?? 'Not Started';

 showDialog(
 context: context,
 builder: (ctx) => StatefulBuilder(
 builder: (context, setDialogState) => AlertDialog(
 title: Row(
 children: [
 Icon(isEdit ? Icons.edit_outlined : Icons.add_circle_outline, size: 20, color: const Color(0xFF4154F1)),
 const SizedBox(width: 8),
 Text(isEdit ? 'Edit Approval Gate' : 'Add Approval Gate', style: const TextStyle(fontSize: 16)),
 ],
 ),
 content: SizedBox(
 width: 520,
 child: SingleChildScrollView(
 child: Column(
 mainAxisSize: MainAxisSize.min,
 children: [
 VoiceTextField(controller: gateCtl, decoration: const InputDecoration(labelText: 'Gate name', border: OutlineInputBorder())),
 const SizedBox(height: 12),
 VoiceTextField(controller: descCtl, maxLines: 2, decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder())),
 const SizedBox(height: 12),
 Row(children: [
 Expanded(child: VoiceTextField(controller: approverCtl, decoration: const InputDecoration(labelText: 'Approver', border: OutlineInputBorder()))),
 const SizedBox(width: 12),
 Expanded(
 child: DropdownButtonFormField<String>(
 value: department,
 items: ['Security', 'Data', 'Operations', 'Quality', 'Procurement', 'Executive', 'Other']
 .map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
 onChanged: (v) { if (v != null) setDialogState(() => department = v); },
 decoration: const InputDecoration(labelText: 'Department', border: OutlineInputBorder()),
 ),
 ),
 ]),
 const SizedBox(height: 12),
 Row(children: [
 Expanded(
 child: DropdownButtonFormField<String>(
 value: priority,
 items: ['Critical', 'High', 'Medium', 'Low'].map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
 onChanged: (v) { if (v != null) setDialogState(() => priority = v); },
 decoration: const InputDecoration(labelText: 'Priority', border: OutlineInputBorder()),
 ),
 ),
 const SizedBox(width: 12),
 Expanded(
 child: DropdownButtonFormField<String>(
 value: status,
 items: ['Not Started', 'In Review', 'Pending', 'Approved', 'Rejected'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
 onChanged: (v) { if (v != null) setDialogState(() => status = v); },
 decoration: const InputDecoration(labelText: 'Status', border: OutlineInputBorder()),
 ),
 ),
 ]),
 const SizedBox(height: 12),
 VoiceTextField(controller: targetDateCtl, decoration: const InputDecoration(labelText: 'Target date', border: OutlineInputBorder())),
 ],
 ),
 ),
 ),
 actions: [
 TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
 FilledButton(
 onPressed: () {
 final row = _ApprovalGateData(
 id: existing?.id ?? _newId(),
 gate: gateCtl.text.trim(),
 description: descCtl.text.trim(),
 approver: approverCtl.text.trim(),
 department: department,
 priority: priority,
 status: status,
 targetDate: targetDateCtl.text.trim(),
 );
 setState(() {
 if (isEdit) {
 final idx = _approvalGates.indexWhere((r) => r.id == row.id);
 if (idx != -1) _approvalGates[idx] = row;
 } else {
 _approvalGates.add(row);
 }
 });
 _scheduleSave();
 _logActivity(isEdit ? 'Edited approval gate' : 'Added approval gate', details: {'itemId': row.id});
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

 void _confirmDeleteApprovalGate(_ApprovalGateData item) {
 showDialog(
 context: context,
 builder: (ctx) => AlertDialog(
 title: const Text('Delete Approval Gate'),
 content: Text('Are you sure you want to remove "${item.gate}" from the approval gates? This action cannot be undone.'),
 actions: [
 TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
 FilledButton(
 onPressed: () {
 _deleteApprovalGate(item.id);
 Navigator.of(ctx).pop();
 },
 style: FilledButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
 child: const Text('Delete'),
 ),
 ],
 ),
 );
 }

 // ---------------------------------------------------------------------------
 // Dialog: Add/Edit Data Flow
 // ---------------------------------------------------------------------------

 void _showDataFlowDialog({_DataFlowRow? existing}) {
 final isEdit = existing != null;
 final sourceCtl = TextEditingController(text: existing?.source ?? '');
 final targetCtl = TextEditingController(text: existing?.target ?? '');
 final dataTypeCtl = TextEditingController(text: existing?.dataType ?? '');
 final apiMethodCtl = TextEditingController(text: existing?.apiMethod ?? 'REST GET');
 final frequencyCtl = TextEditingController(text: existing?.frequency ?? '');
 final transformCtl = TextEditingController(text: existing?.transformation ?? '');
 String status = existing?.status ?? 'Active';

 showDialog(
 context: context,
 builder: (ctx) => StatefulBuilder(
 builder: (context, setDialogState) => AlertDialog(
 title: Row(
 children: [
 Icon(isEdit ? Icons.edit_outlined : Icons.add_circle_outline, size: 20, color: const Color(0xFF4154F1)),
 const SizedBox(width: 8),
 Text(isEdit ? 'Edit Data Flow' : 'Add Data Flow', style: const TextStyle(fontSize: 16)),
 ],
 ),
 content: SizedBox(
 width: 520,
 child: SingleChildScrollView(
 child: Column(
 mainAxisSize: MainAxisSize.min,
 children: [
 Row(children: [
 Expanded(child: VoiceTextField(controller: sourceCtl, decoration: const InputDecoration(labelText: 'Source', border: OutlineInputBorder()))),
 const SizedBox(width: 12),
 Expanded(child: VoiceTextField(controller: targetCtl, decoration: const InputDecoration(labelText: 'Target', border: OutlineInputBorder()))),
 ]),
 const SizedBox(height: 12),
 Row(children: [
 Expanded(child: VoiceTextField(controller: dataTypeCtl, decoration: const InputDecoration(labelText: 'Data type', border: OutlineInputBorder()))),
 const SizedBox(width: 12),
 Expanded(
 child: DropdownButtonFormField<String>(
 value: apiMethodCtl.text,
 items: ['REST GET', 'REST POST', 'REST POST/PUT', 'REST PUT', 'WebSocket', 'GraphQL', 'Webhook']
 .map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
 onChanged: (v) { if (v != null) apiMethodCtl.text = v; },
 decoration: const InputDecoration(labelText: 'API method', border: OutlineInputBorder()),
 ),
 ),
 ]),
 const SizedBox(height: 12),
 Row(children: [
 Expanded(
 child: DropdownButtonFormField<String>(
 value: frequencyCtl.text.isEmpty ? 'On change' : frequencyCtl.text,
 items: ['Real-time', 'On change', 'Scheduled', 'Manual'].map((f) => DropdownMenuItem(value: f, child: Text(f))).toList(),
 onChanged: (v) { if (v != null) frequencyCtl.text = v; },
 decoration: const InputDecoration(labelText: 'Frequency', border: OutlineInputBorder()),
 ),
 ),
 const SizedBox(width: 12),
 Expanded(
 child: DropdownButtonFormField<String>(
 value: status,
 items: ['Active', 'Degraded', 'Disabled', 'Pending'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
 onChanged: (v) { if (v != null) setDialogState(() => status = v); },
 decoration: const InputDecoration(labelText: 'Status', border: OutlineInputBorder()),
 ),
 ),
 ]),
 const SizedBox(height: 12),
 VoiceTextField(controller: transformCtl, maxLines: 2, decoration: const InputDecoration(labelText: 'Transformation rule', border: OutlineInputBorder())),
 ],
 ),
 ),
 ),
 actions: [
 TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
 FilledButton(
 onPressed: () {
 final row = _DataFlowRow(
 id: existing?.id ?? _newId(),
 source: sourceCtl.text.trim(),
 target: targetCtl.text.trim(),
 dataType: dataTypeCtl.text.trim(),
 apiMethod: apiMethodCtl.text.trim(),
 frequency: frequencyCtl.text.trim(),
 transformation: transformCtl.text.trim(),
 status: status,
 );
 setState(() {
 if (isEdit) {
 final idx = _dataFlows.indexWhere((r) => r.id == row.id);
 if (idx != -1) _dataFlows[idx] = row;
 } else {
 _dataFlows.add(row);
 }
 });
 _scheduleSave();
 _logActivity(isEdit ? 'Edited data flow' : 'Added data flow', details: {'itemId': row.id});
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

 void _confirmDeleteDataFlow(_DataFlowRow item) {
 showDialog(
 context: context,
 builder: (ctx) => AlertDialog(
 title: const Text('Delete Data Flow'),
 content: Text('Are you sure you want to remove the "${item.source} → ${item.target}" data flow? This action cannot be undone.'),
 actions: [
 TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
 FilledButton(
 onPressed: () {
 _deleteDataFlow(item.id);
 Navigator.of(ctx).pop();
 },
 style: FilledButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
 child: const Text('Delete'),
 ),
 ],
 ),
 );
 }

 // ---------------------------------------------------------------------------
 // Provider helpers
 // ---------------------------------------------------------------------------

 String _providerLabel(IntegrationProvider provider) {
 switch (provider) {
 case IntegrationProvider.figma: return 'Figma';
 case IntegrationProvider.drawio: return 'Draw.io';
 case IntegrationProvider.miro: return 'Miro';
 case IntegrationProvider.whiteboard: return 'Whiteboard';
 }
 }

 String _providerSubtitle(String provider) {
 switch (provider) {
 case 'Figma': return 'Design files';
 case 'Draw.io': return 'Architecture diagrams';
 case 'Miro': return 'Workshops & ideation';
 case 'Whiteboard': return 'Live sessions';
 case 'Jira': return 'Sprint & backlog tracking';
 case 'GitHub': return 'Source code & CI/CD';
 default: return 'Custom integration';
 }
 }

 String _providerScopes(String provider) {
 switch (provider) {
 case 'Figma': return 'files:read, files:write';
 case 'Draw.io': return 'diagrams:read';
 case 'Miro': return 'boards:read, comments';
 case 'Whiteboard': return 'sessions:read';
 case 'Jira': return 'issues:read, issues:write';
 case 'GitHub': return 'repo:read, repo:write';
 default: return 'read';
 }
 }

 String _providerMapping(String provider) {
 switch (provider) {
 case 'Figma': return 'Epics, stories';
 case 'Draw.io': return 'Tech specs';
 case 'Miro': return 'Requirements';
 case 'Whiteboard': return 'Decisions, actions';
 case 'Jira': return 'Tasks, bugs';
 case 'GitHub': return 'Code, PRs';
 default: return 'Project data';
 }
 }

 String _providerFeatureHint(String provider) {
 switch (provider) {
 case 'Figma': return 'Project mapping enabled.';
 case 'Draw.io': return 'Architecture sync with change detection.';
 case 'Miro': return 'Workshop capture with clustering.';
 case 'Whiteboard': return 'Outputs pushed to notes and actions.';
 case 'Jira': return 'Sprint sync with auto-epic linking.';
 case 'GitHub': return 'PR-to-task linking and CI pipeline triggers.';
 default: return 'Custom integration features.';
 }
 }

 Color _providerColor(String provider) {
 switch (provider) {
 case 'Figma': return const Color(0xFFF24E1E);
 case 'Draw.io': return const Color(0xFFFF6D00);
 case 'Miro': return const Color(0xFFFFD02F);
 case 'Whiteboard': return const Color(0xFF0078D4);
 case 'Jira': return const Color(0xFF0052CC);
 case 'GitHub': return const Color(0xFF24292F);
 default: return const Color(0xFF64748B);
 }
 }

 IconData _providerIcon(String provider) {
 switch (provider) {
 case 'Figma': return Icons.design_services;
 case 'Draw.io': return Icons.account_tree;
 case 'Miro': return Icons.dashboard;
 case 'Whiteboard': return Icons.sticky_note_2;
 case 'Jira': return Icons.track_changes;
 case 'GitHub': return Icons.code;
 default: return Icons.extension;
 }
 }
}

// =============================================================================
// Data models
// =============================================================================

/// Lookup table of icons used by integrations so the web tree-shaker can
/// statically resolve every [IconData].
const _knownIcons = <int, IconData>{
 0xe86b: IconData(0xe86b, fontFamily: 'MaterialIcons'), // Icons.extension
 0xe8a6: IconData(0xe8a6, fontFamily: 'MaterialIcons'), // Icons.sync
 0xe8b4: IconData(0xe8b4, fontFamily: 'MaterialIcons'), // Icons.cloud
 0xe161: IconData(0xe161, fontFamily: 'MaterialIcons'), // Icons.code
 0xe8d4: IconData(0xe8d4, fontFamily: 'MaterialIcons'), // Icons.storage
 0xe8ad: IconData(0xe8ad, fontFamily: 'MaterialIcons'), // Icons.security
 0xe8d8: IconData(0xe8d8, fontFamily: 'MaterialIcons'), // Icons.api
 0xe56c: IconData(0xe56c, fontFamily: 'MaterialIcons'), // Icons.psychology
 0xe90f: IconData(0xe90f, fontFamily: 'MaterialIcons'), // Icons.analytics
 0xe30a: IconData(0xe30a, fontFamily: 'MaterialIcons'), // Icons.mail
 0xe88e: IconData(0xe88e, fontFamily: 'MaterialIcons'), // Icons.build
 0xe0af: IconData(0xe0af, fontFamily: 'MaterialIcons'), // Icons.hub
 0xe8f5: IconData(0xe8f5, fontFamily: 'MaterialIcons'), // Icons.webhook
 0xe3af: IconData(0xe3af, fontFamily: 'MaterialIcons'), // Icons.notifications
 0xe332: IconData(0xe332, fontFamily: 'MaterialIcons'), // Icons.group
 0xe053: IconData(0xe053, fontFamily: 'MaterialIcons'), // Icons.dashboard
 0xe8c3: IconData(0xe8c3, fontFamily: 'MaterialIcons'), // Icons.link
 0xe0b9: IconData(0xe0b9, fontFamily: 'MaterialIcons'), // Icons.insights
 0xe56f: IconData(0xe56f, fontFamily: 'MaterialIcons'), // Icons.settings
 0xe33c: IconData(0xe33c, fontFamily: 'MaterialIcons'), // Icons.key
};

IconData _iconFromCodePoint(int? codePoint) {
 if (codePoint != null) {
 return _knownIcons[codePoint] ??
 const IconData(0xe86b, fontFamily: 'MaterialIcons');
 }
 return const IconData(0xe86b, fontFamily: 'MaterialIcons');
}

class _IntegrationRow {
 final String id;
 final String name;
 final String subtitle;
 final String provider;
 final String status;
 final String scopes;
 final String mapsTo;
 final String lastSync;
 final IconData icon;
 final Color iconColor;
 final String features;
 final String? autoHandoff;
 final String? syncMode;
 final String? errorInfo;

 const _IntegrationRow({
 required this.id,
 required this.name,
 required this.subtitle,
 required this.provider,
 required this.status,
 required this.scopes,
 required this.mapsTo,
 required this.lastSync,
 required this.icon,
 required this.iconColor,
 required this.features,
 this.autoHandoff,
 this.syncMode,
 this.errorInfo,
 });

 _IntegrationRow copyWith({
 String? status,
 String? lastSync,
 String? scopes,
 String? mapsTo,
 String? features,
 String? name,
 String? subtitle,
 String? provider,
 IconData? icon,
 Color? iconColor,
 String? autoHandoff,
 String? syncMode,
 String? errorInfo,
 }) {
 return _IntegrationRow(
 id: id,
 name: name ?? this.name,
 subtitle: subtitle ?? this.subtitle,
 provider: provider ?? this.provider,
 status: status ?? this.status,
 scopes: scopes ?? this.scopes,
 mapsTo: mapsTo ?? this.mapsTo,
 lastSync: lastSync ?? this.lastSync,
 icon: icon ?? this.icon,
 iconColor: iconColor ?? this.iconColor,
 features: features ?? this.features,
 autoHandoff: autoHandoff ?? this.autoHandoff,
 syncMode: syncMode ?? this.syncMode,
 errorInfo: errorInfo ?? this.errorInfo,
 );
 }

 Map<String, dynamic> toMap() => {
 'id': id,
 'name': name,
 'subtitle': subtitle,
 'provider': provider,
 'status': status,
 'scopes': scopes,
 'mapsTo': mapsTo,
 'lastSync': lastSync,
 'iconCodePoint': icon.codePoint,
 'iconColor': iconColor.toARGB32(),
 'features': features,
 'autoHandoff': autoHandoff,
 'syncMode': syncMode,
 'errorInfo': errorInfo,
 };

 static List<_IntegrationRow> fromList(dynamic data) {
 if (data is! List) return [];
 return data.map((e) {
 if (e is! Map<String, dynamic>) return null;
 return _IntegrationRow(
 id: e['id'] ?? '',
 name: e['name'] ?? '',
 subtitle: e['subtitle'] ?? '',
 provider: e['provider'] ?? '',
 status: e['status'] ?? 'Not connected',
 scopes: e['scopes'] ?? '',
 mapsTo: e['mapsTo'] ?? '',
 lastSync: e['lastSync'] ?? 'Never',
 icon: _iconFromCodePoint(e['iconCodePoint'] as int?),
 iconColor: Color(e['iconColor'] ?? const Color(0xFF64748B).toARGB32()),
 features: e['features'] ?? '',
 autoHandoff: e['autoHandoff'],
 syncMode: e['syncMode'],
 errorInfo: e['errorInfo'],
 );
 }).whereType<_IntegrationRow>().toList();
 }
}

class _KpiRow {
 final String id;
 final String metric;
 final double value;
 final double target;
 final String trend;
 final String owner;
 final String source;

 const _KpiRow({
 required this.id,
 required this.metric,
 required this.value,
 required this.target,
 required this.trend,
 required this.owner,
 required this.source,
 });

 Map<String, dynamic> toMap() => {
 'id': id,
 'metric': metric,
 'value': value,
 'target': target,
 'trend': trend,
 'owner': owner,
 'source': source,
 };

 static List<_KpiRow> fromList(dynamic data) {
 if (data is! List) return [];
 return data.map((e) {
 if (e is! Map<String, dynamic>) return null;
 return _KpiRow(
 id: e['id'] ?? '',
 metric: e['metric'] ?? '',
 value: (e['value'] is num) ? (e['value'] as num).toDouble() : 0.0,
 target: (e['target'] is num) ? (e['target'] as num).toDouble() : 0.9,
 trend: e['trend'] ?? '',
 owner: e['owner'] ?? '',
 source: e['source'] ?? 'Manual',
 );
 }).whereType<_KpiRow>().toList();
 }
}

class _RiskSignalRow {
 final String id;
 final String signal;
 final String description;
 final String severity;
 final String category;
 final String owner;
 final String source;
 final String status;

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

 Map<String, dynamic> toMap() => {
 'id': id,
 'signal': signal,
 'description': description,
 'severity': severity,
 'category': category,
 'owner': owner,
 'source': source,
 'status': status,
 };

 static List<_RiskSignalRow> fromList(dynamic data) {
 if (data is! List) return [];
 return data.map((e) {
 if (e is! Map<String, dynamic>) return null;
 return _RiskSignalRow(
 id: e['id'] ?? '',
 signal: e['signal'] ?? '',
 description: e['description'] ?? '',
 severity: e['severity'] ?? 'Medium',
 category: e['category'] ?? 'Governance',
 owner: e['owner'] ?? '',
 source: e['source'] ?? 'Manual',
 status: e['status'] ?? 'Open',
 );
 }).whereType<_RiskSignalRow>().toList();
 }
}

class _ActionRow {
 final String id;
 final String title;
 final String priority;
 final String dueDate;
 final String owner;
 final String status;

 const _ActionRow({
 required this.id,
 required this.title,
 required this.priority,
 required this.dueDate,
 required this.owner,
 required this.status,
 });

 Map<String, dynamic> toMap() => {
 'id': id,
 'title': title,
 'priority': priority,
 'dueDate': dueDate,
 'owner': owner,
 'status': status,
 };

 static List<_ActionRow> fromList(dynamic data) {
 if (data is! List) return [];
 return data.map((e) {
 if (e is! Map<String, dynamic>) return null;
 return _ActionRow(
 id: e['id'] ?? '',
 title: e['title'] ?? '',
 priority: e['priority'] ?? 'Medium',
 dueDate: e['dueDate'] ?? 'TBD',
 owner: e['owner'] ?? '',
 status: e['status'] ?? 'Not Started',
 );
 }).whereType<_ActionRow>().toList();
 }
}

class _ApprovalGateData {
 final String id;
 final String gate;
 final String description;
 final String approver;
 final String department;
 final String priority;
 final String status;
 final String targetDate;

 const _ApprovalGateData({
 required this.id,
 required this.gate,
 required this.description,
 required this.approver,
 required this.department,
 required this.priority,
 required this.status,
 required this.targetDate,
 });

 Map<String, dynamic> toMap() => {
 'id': id,
 'gate': gate,
 'description': description,
 'approver': approver,
 'department': department,
 'priority': priority,
 'status': status,
 'targetDate': targetDate,
 };

 static List<_ApprovalGateData> fromList(dynamic data) {
 if (data is! List) return [];
 return data.map((e) {
 if (e is! Map<String, dynamic>) return null;
 return _ApprovalGateData(
 id: e['id'] ?? '',
 gate: e['gate'] ?? '',
 description: e['description'] ?? '',
 approver: e['approver'] ?? '',
 department: e['department'] ?? 'Security',
 priority: e['priority'] ?? 'High',
 status: e['status'] ?? 'Not Started',
 targetDate: e['targetDate'] ?? 'TBD',
 );
 }).whereType<_ApprovalGateData>().toList();
 }
}

class _DataFlowRow {
 final String id;
 final String source;
 final String target;
 final String dataType;
 final String apiMethod;
 final String frequency;
 final String transformation;
 final String status;

 const _DataFlowRow({
 required this.id,
 required this.source,
 required this.target,
 required this.dataType,
 required this.apiMethod,
 required this.frequency,
 required this.transformation,
 required this.status,
 });

 Map<String, dynamic> toMap() => {
 'id': id,
 'source': source,
 'target': target,
 'dataType': dataType,
 'apiMethod': apiMethod,
 'frequency': frequency,
 'transformation': transformation,
 'status': status,
 };

 static List<_DataFlowRow> fromList(dynamic data) {
 if (data is! List) return [];
 return data.map((e) {
 if (e is! Map<String, dynamic>) return null;
 return _DataFlowRow(
 id: e['id'] ?? '',
 source: e['source'] ?? '',
 target: e['target'] ?? '',
 dataType: e['dataType'] ?? '',
 apiMethod: e['apiMethod'] ?? 'REST GET',
 frequency: e['frequency'] ?? 'On change',
 transformation: e['transformation'] ?? '',
 status: e['status'] ?? 'Active',
 );
 }).whereType<_DataFlowRow>().toList();
 }
}

class _StatCardData {
 final String value;
 final String label;
 final String supporting;
 final Color color;
 const _StatCardData(this.value, this.label, this.supporting, this.color);
}

class _GovernanceItem {
 final IconData icon;
 final String label;
 final String value;
 final Color color;
 const _GovernanceItem(this.icon, this.label, this.value, this.color);
}

class _ToolsCrudPolicy {
 final SiteRole role;
 final bool hasProject;
 final bool canCreate;
 final bool canUpdate;
 final bool canDelete;
 final bool canExport;
 final bool canAudit;
 final String roleLabel;
 final Color roleColor;

 const _ToolsCrudPolicy({
 required this.role,
 required this.hasProject,
 required this.canCreate,
 required this.canUpdate,
 required this.canDelete,
 required this.canExport,
 required this.canAudit,
 required this.roleLabel,
 required this.roleColor,
 });

 factory _ToolsCrudPolicy.fromRole({required SiteRole role, required bool hasProject}) {
 switch (role) {
 case SiteRole.owner:
 return _ToolsCrudPolicy(
 role: role,
 hasProject: hasProject,
 canCreate: hasProject,
 canUpdate: hasProject,
 canDelete: hasProject,
 canExport: true,
 canAudit: true,
 roleLabel: 'Owner',
 roleColor: const Color(0xFFDC2626),
 );
 case SiteRole.admin:
 return _ToolsCrudPolicy(
 role: role,
 hasProject: hasProject,
 canCreate: hasProject,
 canUpdate: hasProject,
 canDelete: hasProject,
 canExport: true,
 canAudit: true,
 roleLabel: 'Admin',
 roleColor: const Color(0xFFEF4444),
 );
 case SiteRole.editor:
 return _ToolsCrudPolicy(
 role: role,
 hasProject: hasProject,
 canCreate: hasProject,
 canUpdate: hasProject,
 canDelete: false,
 canExport: hasProject,
 canAudit: hasProject,
 roleLabel: 'Editor',
 roleColor: const Color(0xFF0EA5E9),
 );
 case SiteRole.user:
 return _ToolsCrudPolicy(
 role: role,
 hasProject: hasProject,
 canCreate: hasProject,
 canUpdate: hasProject,
 canDelete: false,
 canExport: hasProject,
 canAudit: false,
 roleLabel: 'User',
 roleColor: const Color(0xFF10B981),
 );
 case SiteRole.guest:
 return const _ToolsCrudPolicy(
 role: SiteRole.guest,
 hasProject: false,
 canCreate: false,
 canUpdate: false,
 canDelete: false,
 canExport: false,
 canAudit: false,
 roleLabel: 'Guest',
 roleColor: Color(0xFF94A3B8),
 );
 }
 }
}

// =============================================================================
// _PanelShell
// =============================================================================

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
 Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF111827))),
 const SizedBox(height: 6),
 Text(subtitle, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF6B7280), height: 1.45)),
 ],
 ),
 ),
 if (trailing != null) ...[
 const SizedBox(width: 12),
 trailing!,
 ],
 ],
 ),
 ),
 const Divider(height: 1, thickness: 1, color: Color(0xFFE5E7EB)),
 Padding(padding: const EdgeInsets.all(20), child: child),
 ],
 ),
 );
 }
}

// =============================================================================
// _Debouncer
// =============================================================================

class _Debouncer {
 _Debouncer({this.delay = const Duration(milliseconds: 300)});
 final Duration delay;
 Timer? _timer;

 void run(VoidCallback action) {
 _timer?.cancel();
 _timer = Timer(delay, action);
 }

 void dispose() => _timer?.cancel();
}
