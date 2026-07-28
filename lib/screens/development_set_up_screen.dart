import 'package:ndu_project/widgets/voice_text_field.dart';
import 'package:ndu_project/theme.dart';
// ignore_for_file: unused_element

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:ndu_project/providers/project_data_provider.dart';
import 'package:ndu_project/models/project_data_model.dart';
import 'package:ndu_project/screens/technical_alignment_screen.dart';
import 'package:ndu_project/screens/ui_ux_design_screen.dart';
import 'package:ndu_project/services/project_navigation_service.dart';
import 'package:ndu_project/widgets/launch_phase_navigation.dart';
import 'package:ndu_project/widgets/planning_phase_header.dart';
import 'package:ndu_project/widgets/kaz_ai_chat_bubble.dart';
import 'package:ndu_project/widgets/responsive.dart';
import 'package:ndu_project/widgets/responsive_scaffold.dart';
import 'package:ndu_project/utils/pdf_export_helper.dart';
import 'package:ndu_project/utils/project_data_helper.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Development Set Up — CRUD-Enabled Overhaul
//
// Industry-standard Development Environment Setup page covering three
// methodology paradigms with CRUD-enabled registers. Content is based on
// PMI PMBOK 7th Ed., ISO/IEC 12207, SAFe 6.0, and the Contract Tracking
// page pattern for data persistence and CRUD operations.
// ─────────────────────────────────────────────────────────────────────────────

class DevelopmentSetUpScreen extends StatefulWidget {
 const DevelopmentSetUpScreen({super.key});

 @override
 State<DevelopmentSetUpScreen> createState() => _DevelopmentSetUpScreenState();
}

class _DevelopmentSetUpScreenState extends State<DevelopmentSetUpScreen> {
 // ── Methodology selection ──────────────────────────────────────────────
 String _selectedMethodology = 'Hybrid';

 static const List<String> _methodologyOptions = [
 'Hybrid', 'Agile', 'Waterfall',
 ];

 static const List<String> _qualityStatusOptions = [
 'Planned', 'Not Started', 'In Progress', 'Active', 'Completed', 'Waived',
 ];

 // ── Filter chips ───────────────────────────────────────────────────────
 final Set<String> _selectedFilters = {'All registers'};

 // ── CRUD data lists ────────────────────────────────────────────────────
 List<_EnvProvisionItem> _envItems = [];
 List<_CicdPipelineItem> _cicdItems = [];
 List<_DevToolItem> _toolItems = [];
 List<_QualityGateItem> _qualityItems = [];
 List<_SecurityBaselineItem> _securityItems = [];
 List<_ApprovalGateItem> _approvalGates = [];

 final _Debouncer _saveDebounce = _Debouncer();
 bool _isLoading = false;
 bool _suspendSave = false;
 bool _frameworkGuideExpanded = false;

 @override
 void initState() {
 super.initState();
 _envItems = _defaultEnvItems();
 _cicdItems = _defaultCicdItems();
 _toolItems = _defaultToolItems();
 _qualityItems = _defaultQualityItems();
 _securityItems = _defaultSecurityItems();
 _approvalGates = _defaultApprovalGates();
 WidgetsBinding.instance.addPostFrameCallback((_) async {
 final provider = ProjectDataInherited.maybeOf(context);
 final projectId = provider?.projectData.projectId;
 if (projectId != null && projectId.isNotEmpty) {
 await ProjectNavigationService.instance
 .saveLastPage(projectId, 'development-set-up');
 }
 await _loadFromFirestore();
 });
 }

 @override
 void dispose() {
 _saveDebounce.dispose();
 super.dispose();
 }

 // ── Firestore ──────────────────────────────────────────────────────────

 String? get _projectId {
 try {
 final provider = ProjectDataInherited.maybeOf(context);
 return provider?.projectData.projectId;
 } catch (e) {
 return null;
 }
 }

 DocumentReference<Map<String, dynamic>> _docFor(String projectId) {
 return FirebaseFirestore.instance
 .collection('projects')
 .doc(projectId)
 .collection('design_phase_sections')
 .doc('development_setup');
 }

 void _scheduleSave() {
 if (_suspendSave) return;
 _saveDebounce.run(_saveToFirestore);
 }

 Future<void> _saveToFirestore() async {
 final projectId = _projectId;
 if (projectId == null || projectId.isEmpty) return;
 try {
 await _docFor(projectId).set({
 'methodology': _selectedMethodology,
 'envItems': _envItems.map((e) => e.toMap()).toList(),
 'cicdItems': _cicdItems.map((e) => e.toMap()).toList(),
 'toolItems': _toolItems.map((e) => e.toMap()).toList(),
 'qualityItems': _qualityItems.map((e) => e.toMap()).toList(),
 'securityItems': _securityItems.map((e) => e.toMap()).toList(),
 'approvalGates': _approvalGates.map((e) => e.toMap()).toList(),
 'updatedAt': FieldValue.serverTimestamp(),
 }, SetOptions(merge: true));
 } catch (error) {
 debugPrint('Development setup save error: $error');
 }
 }

 Future<void> _loadFromFirestore() async {
 final projectId = _projectId;
 if (projectId == null || projectId.isEmpty) return;
 if (!mounted) return;
 setState(() => _isLoading = true);
 try {
 final doc = await _docFor(projectId).get();
 final data = doc.data() ?? {};
 _suspendSave = true;
 if (!mounted) return;
 setState(() {
 if (data['methodology'] != null) {
 _selectedMethodology = data['methodology'] as String;
 }
 final envList = _EnvProvisionItem.fromList(data['envItems']);
 final cicdList = _CicdPipelineItem.fromList(data['cicdItems']);
 final toolList = _DevToolItem.fromList(data['toolItems']);
 final qualList = _QualityGateItem.fromList(data['qualityItems']);
 final secList = _SecurityBaselineItem.fromList(data['securityItems']);
 final gateList = _ApprovalGateItem.fromList(data['approvalGates']);
 if (envList.isNotEmpty) _envItems = envList;
 if (cicdList.isNotEmpty) _cicdItems = cicdList;
 if (toolList.isNotEmpty) _toolItems = toolList;
 if (qualList.isNotEmpty) _qualityItems = qualList;
 if (secList.isNotEmpty) _securityItems = secList;
 if (gateList.isNotEmpty) _approvalGates = gateList;
 });
 } catch (error) {
 debugPrint('Development setup load error: $error');
 } finally {
 _suspendSave = false;
 if (mounted) setState(() => _isLoading = false);
 }
 }

 // ── Helpers ────────────────────────────────────────────────────────────

 String _newId() => DateTime.now().microsecondsSinceEpoch.toString();

 Color _statusColor(String status) {
 switch (status) {
 case 'Provisioned':
 case 'Ready':
 case 'Active':
 case 'Done':
 return const Color(0xFF10B981);
 case 'In Progress':
 case 'Pending':
 case 'Planned':
 case 'In Review':
 return const Color(0xFFF59E0B);
 case 'Not Started':
 case 'Blocked':
 return const Color(0xFFEF4444);
 default:
 return const Color(0xFF6B7280);
 }
 }

 Widget _buildStatusTag(String status, Color color) {
 return Container(
 padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
 decoration: BoxDecoration(
 color: color.withOpacity(0.12),
 borderRadius: BorderRadius.circular(6),
 ),
 child: Text(
 status,
 style: TextStyle(
 fontSize: 10,
 fontWeight: FontWeight.w700,
 color: color,
 ),
 ),
 );
 }

 // ── Default data ───────────────────────────────────────────────────────

 List<_EnvProvisionItem> _defaultEnvItems() {
 return [
 _EnvProvisionItem(
 id: _newId(),
 environment: 'Development Workspace',
 type: 'Cloud VM',
 status: 'Provisioned',
 accessUrl: 'https://dev.ndu.internal',
 owner: 'Dev Lead',
 targetDate: '2025-01-15',
 notes: 'Core delivery team access',
 ),
 _EnvProvisionItem(
 id: _newId(),
 environment: 'Staging Environment',
 type: 'Cloud VM',
 status: 'In Progress',
 accessUrl: 'https://staging.ndu.internal',
 owner: 'Platform Owner',
 targetDate: '2025-01-20',
 notes: 'Mirror of production config',
 ),
 _EnvProvisionItem(
 id: _newId(),
 environment: 'Production Environment',
 type: 'Bare Metal',
 status: 'Not Started',
 accessUrl: 'https://prod.ndu.internal',
 owner: 'Site Ops',
 targetDate: '2025-02-01',
 notes: 'HA/DR configuration required',
 ),
 _EnvProvisionItem(
 id: _newId(),
 environment: 'Physical Site',
 type: 'On-Premise',
 status: 'In Progress',
 accessUrl: 'Site A - Main Campus',
 owner: 'Operations',
 targetDate: '2025-01-25',
 notes: 'Fencing and access control pending',
 ),
 ];
 }

 List<_CicdPipelineItem> _defaultCicdItems() {
 return [
 _CicdPipelineItem(
 id: _newId(),
 stage: 'Build',
 tool: 'GitHub Actions',
 status: 'Ready',
 trigger: 'Push to main',
 gateCriteria: 'Lint + Unit Tests Pass',
 owner: 'Dev Lead',
 ),
 _CicdPipelineItem(
 id: _newId(),
 stage: 'Test',
 tool: 'Jest/Cypress',
 status: 'Ready',
 trigger: 'After Build',
 gateCriteria: '80% Coverage Threshold',
 owner: 'QA Lead',
 ),
 _CicdPipelineItem(
 id: _newId(),
 stage: 'Staging Deploy',
 tool: 'ArgoCD',
 status: 'Pending',
 trigger: 'After Test',
 gateCriteria: 'Smoke Tests Pass',
 owner: 'Platform Owner',
 ),
 _CicdPipelineItem(
 id: _newId(),
 stage: 'Production Deploy',
 tool: 'ArgoCD',
 status: 'Not Started',
 trigger: 'Manual Approval',
 gateCriteria: 'All Gates Passed',
 owner: 'Release Manager',
 ),
 ];
 }

 List<_DevToolItem> _defaultToolItems() {
 return [
 _DevToolItem(
 id: _newId(),
 tool: 'VS Code',
 category: 'IDE',
 license: 'Enterprise',
 assignedUsers: '12 users',
 status: 'Active',
 expiry: '2025-12-31',
 owner: 'Dev Lead',
 ),
 _DevToolItem(
 id: _newId(),
 tool: 'Jira',
 category: 'Project Mgmt',
 license: 'Premium',
 assignedUsers: '20 users',
 status: 'Active',
 expiry: '2025-06-30',
 owner: 'PMO Lead',
 ),
 _DevToolItem(
 id: _newId(),
 tool: 'GitHub',
 category: 'VCS',
 license: 'Team',
 assignedUsers: '15 users',
 status: 'Active',
 expiry: '2025-12-31',
 owner: 'Dev Lead',
 ),
 _DevToolItem(
 id: _newId(),
 tool: 'Figma',
 category: 'Design',
 license: 'Professional',
 assignedUsers: '5 users',
 status: 'Active',
 expiry: '2025-09-30',
 owner: 'Design Lead',
 ),
 _DevToolItem(
 id: _newId(),
 tool: 'AWS',
 category: 'Cloud',
 license: 'Enterprise',
 assignedUsers: '8 users',
 status: 'Active',
 expiry: '2025-12-31',
 owner: 'Platform Owner',
 ),
 ];
 }

 List<_QualityGateItem> _defaultQualityItems() {
 return [
 _QualityGateItem(
 id: _newId(),
 gate: 'Definition of Ready',
 criteria: 'Backlog items refined with acceptance criteria',
 methodology: 'Agile',
 status: 'Active',
 approver: 'Product Owner',
 targetDate: 'Sprint Start',
 ),
 _QualityGateItem(
 id: _newId(),
 gate: 'Definition of Done',
 criteria: 'Code reviewed, tested, documented',
 methodology: 'Agile',
 status: 'Active',
 approver: 'Scrum Master',
 targetDate: 'Sprint End',
 ),
 _QualityGateItem(
 id: _newId(),
 gate: 'Phase Gate Entry',
 criteria: 'All deliverables from previous phase signed off',
 methodology: 'Waterfall',
 status: 'Planned',
 approver: 'PM',
 targetDate: 'Phase Start',
 ),
 _QualityGateItem(
 id: _newId(),
 gate: 'Release Approval',
 criteria: 'All tests passed, no critical defects',
 methodology: 'Hybrid',
 status: 'Planned',
 approver: 'Release Manager',
 targetDate: 'Release Date',
 ),
 ];
 }

 List<_SecurityBaselineItem> _defaultSecurityItems() {
 return [
 _SecurityBaselineItem(
 id: _newId(),
 control: 'RBAC Configuration',
 framework: 'NIST 800-53',
 status: 'In Progress',
 evidence: 'IAM policies defined',
 owner: 'Security Lead',
 reviewDate: '2025-01-30',
 ),
 _SecurityBaselineItem(
 id: _newId(),
 control: 'Secrets Management',
 framework: 'OWASP',
 status: 'Not Started',
 evidence: 'Vault deployment pending',
 owner: 'Platform Owner',
 reviewDate: '2025-02-15',
 ),
 _SecurityBaselineItem(
 id: _newId(),
 control: 'SAST Integration',
 framework: 'OWASP',
 status: 'In Progress',
 evidence: 'SonarQube configured',
 owner: 'Dev Lead',
 reviewDate: '2025-01-25',
 ),
 _SecurityBaselineItem(
 id: _newId(),
 control: 'Compliance Audit',
 framework: 'ISO 27001',
 status: 'Planned',
 evidence: 'Audit scope defined',
 owner: 'Compliance Officer',
 reviewDate: '2025-03-01',
 ),
 ];
 }

 List<_ApprovalGateItem> _defaultApprovalGates() {
 return [
 _ApprovalGateItem(
 id: _newId(),
 gate: 'Development Readiness Gate',
 description: 'All environments provisioned, tooling licensed, team onboarded',
 status: 'In Progress',
 approver: 'Dev Lead',
 targetDate: 'TBD',
 ),
 _ApprovalGateItem(
 id: _newId(),
 gate: 'Security Sign-off Gate',
 description: 'Security baseline met, RBAC configured, SAST integrated',
 status: 'Not Started',
 approver: 'Security Lead',
 targetDate: 'TBD',
 ),
 _ApprovalGateItem(
 id: _newId(),
 gate: 'Infrastructure Readiness Gate',
 description: 'CI/CD pipeline operational, staging accessible, smoke tests passing',
 status: 'In Progress',
 approver: 'Platform Owner',
 targetDate: 'TBD',
 ),
 _ApprovalGateItem(
 id: _newId(),
 gate: 'Quality Baseline Gate',
 description: 'DoR/DoD established, quality gates configured, test coverage baseline set',
 status: 'Planned',
 approver: 'QA Lead',
 targetDate: 'TBD',
 ),
 _ApprovalGateItem(
 id: _newId(),
 gate: 'Executive Authorization',
 description: 'Final approval from executive sponsor for development to commence',
 status: 'Not Started',
 approver: 'Executive Sponsor',
 targetDate: 'TBD',
 ),
 ];
 }

 // ── Navigation ─────────────────────────────────────────────────────────

 void _navigateToTechnicalAlignment() {
 Navigator.push(
 context,
 MaterialPageRoute(builder: (_) => const TechnicalAlignmentScreen()),
 );
 }

 void _navigateToUiUxDesign() {
 Navigator.push(
 context,
 MaterialPageRoute(builder: (_) => const UiUxDesignScreen()),
 );
 }

 // ── Build ──────────────────────────────────────────────────────────────

 @override
 Widget build(BuildContext context) {
 final isMobile = AppBreakpoints.isMobile(context);
 final padding = AppBreakpoints.pagePadding(context);
 final provider = ProjectDataInherited.maybeOf(context);
 final projectData = provider?.projectData ?? ProjectDataModel();

 return ResponsiveScaffold(
 activeItemLabel: 'Development Set Up',
 floatingActionButton: const KazAiChatBubble(positioned: false),
 body: SingleChildScrollView(
 padding: EdgeInsets.all(padding),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 if (_isLoading) const LinearProgressIndicator(minHeight: 2),
 if (_isLoading) const SizedBox(height: 16),
 PlanningPhaseHeader(
 title: 'Development Set Up', onExportPdf: _exportPdf),
 const SizedBox(height: 16),
 _buildHeroHeader(isMobile: isMobile),
 const SizedBox(height: 24),
 _buildMethodologySelector(),
 const SizedBox(height: 24),
 _buildFilterChips(),
 const SizedBox(height: 20),
 _buildStatsRow(),
 const SizedBox(height: 20),
 _buildFrameworkGuidePanel(),
 const SizedBox(height: 24),
 _buildEnvProvisionRegister(),
 const SizedBox(height: 20),
 _buildCicdPipelineRegister(),
 const SizedBox(height: 20),
 _buildDevToolsRegister(),
 const SizedBox(height: 20),
 _buildQualityGatesRegister(),
 const SizedBox(height: 20),
 _buildSecurityBaselineRegister(),
 const SizedBox(height: 20),
 _buildApprovalGatesPanel(),
 const SizedBox(height: 24),
 LaunchPhaseNavigation(
 backLabel: 'Back: Technical Alignment',
 nextLabel: 'Next: UI/UX Design',
 onBack: _navigateToTechnicalAlignment,
 onNext: _navigateToUiUxDesign,
 ),
 ],
 ),
 ),
 );
 }

 // ══════════════════════════════════════════════════════════════════════════
 // HERO HEADER
 // ══════════════════════════════════════════════════════════════════════════

 Widget _buildHeroHeader({required bool isMobile}) {
 return Container(
 width: double.infinity,
 padding: const EdgeInsets.all(28),
 decoration: BoxDecoration(
 gradient: const LinearGradient(
 begin: Alignment.topLeft,
 end: Alignment.bottomRight,
 colors: [
 Color(0xFF0F172A),
 Color(0xFF102A43),
 Color(0xFF78350F),
 ],
 ),
 borderRadius: BorderRadius.circular(24),
 boxShadow: const [
 BoxShadow(
 color: Color(0x180F172A),
 blurRadius: 28,
 offset: Offset(0, 16),
 ),
 ],
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 LayoutBuilder(
 builder: (context, constraints) {
 final stacked = constraints.maxWidth < 760;
 final titleBlock = Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 'Development Environment Setup',
 style: TextStyle(
 fontSize: isMobile ? 24 : 28,
 fontWeight: FontWeight.w800,
 color: Colors.white,
 height: 1.1,
 ),
 ),
 const SizedBox(height: 8),
 Text(
 'Prepare environments, tooling, pipelines, quality gates, and security baselines so execution can start without blockers. Content aligns with PMI PMBOK 7th Ed., ISO/IEC 12207, and SAFe 6.0 standards for $_selectedMethodology methodology.',
 style: TextStyle(
 fontSize: 14,
 color: Colors.white.withOpacity(0.84),
 height: 1.5,
 ),
 ),
 ],
 ),
 );
 final badge = _buildDarkBadge(
 label: 'DEV SETUP CONTROL',
 icon: Icons.settings_suggest_outlined,
 );

 if (stacked) {
 return Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Container(
 width: 48,
 height: 48,
 decoration: BoxDecoration(
 color: Colors.white.withOpacity(0.10),
 borderRadius: BorderRadius.circular(16),
 border: Border.all(
 color: Colors.white.withOpacity(0.14),
 ),
 ),
 child: const Icon(
 Icons.settings_suggest_outlined,
 color: Colors.white,
 ),
 ),
 const SizedBox(width: 14),
 titleBlock,
 ],
 ),
 const SizedBox(height: 14),
 badge,
 ],
 );
 }

 return Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Container(
 width: 48,
 height: 48,
 decoration: BoxDecoration(
 color: Colors.white.withOpacity(0.10),
 borderRadius: BorderRadius.circular(16),
 border: Border.all(
 color: Colors.white.withOpacity(0.14),
 ),
 ),
 child: const Icon(
 Icons.settings_suggest_outlined,
 color: Colors.white,
 ),
 ),
 const SizedBox(width: 14),
 titleBlock,
 const SizedBox(width: 16),
 badge,
 ],
 );
 },
 ),
 const SizedBox(height: 18),
 Wrap(
 spacing: 10,
 runSpacing: 10,
 children: [
 _buildMetricPill('Environments', '${_envItems.length}'),
 _buildMetricPill('Pipeline Stages', '${_cicdItems.length}'),
 _buildMetricPill('Licensed Tools', '${_toolItems.length}'),
 _buildMetricPill('Quality Gates', '${_qualityItems.length}'),
 _buildMetricPill('Security Controls', '${_securityItems.length}'),
 _buildMetricPill('Methodology', _selectedMethodology, highlight: true),
 ],
 ),
 ],
 ),
 );
 }

 Widget _buildDarkBadge({required String label, required IconData icon}) {
 return Container(
 padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
 decoration: BoxDecoration(
 color: const Color(0xFFFFC812),
 borderRadius: BorderRadius.circular(8),
 ),
 child: Row(
 mainAxisSize: MainAxisSize.min,
 children: [
 Icon(icon, size: 16, color: Colors.black),
 const SizedBox(width: 8),
 Text(
 label,
 style: const TextStyle(
 fontSize: 11,
 fontWeight: FontWeight.w800,
 color: Colors.black,
 letterSpacing: 0.8,
 ),
 ),
 ],
 ),
 );
 }

 Widget _buildMetricPill(String label, String value, {bool highlight = false}) {
 return Container(
 padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
 decoration: BoxDecoration(
 color: highlight
 ? const Color(0xFFD97706).withOpacity(0.20)
 : Colors.white.withOpacity(0.10),
 borderRadius: BorderRadius.circular(8),
 border: Border.all(
 color: highlight
 ? const Color(0xFFD97706).withOpacity(0.30)
 : Colors.white.withOpacity(0.14),
 ),
 ),
 child: Row(
 mainAxisSize: MainAxisSize.min,
 children: [
 Text(
 value,
 style: TextStyle(
 fontSize: 13,
 fontWeight: FontWeight.w800,
 color: highlight ? const Color(0xFFFFC812) : Colors.white,
 ),
 ),
 const SizedBox(width: 6),
 Text(
 label,
 style: TextStyle(
 fontSize: 11,
 color: Colors.white.withOpacity(0.70),
 ),
 ),
 ],
 ),
 );
 }

 // ══════════════════════════════════════════════════════════════════════════
 // METHODOLOGY SELECTOR
 // ══════════════════════════════════════════════════════════════════════════

 Widget _buildMethodologySelector() {
 return _PanelShell(
 title: 'Development Methodology',
 subtitle: 'Select the delivery methodology to tailor setup requirements. Each methodology dictates different environment provisioning, quality gates, and tooling expectations per industry standards.',
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 LayoutBuilder(
 builder: (context, constraints) {
 final isNarrow = constraints.maxWidth < 700;
 if (isNarrow) {
 return Column(
 children: [
 _buildMethodologyCard('Waterfall', 'Sequential, phase-gated delivery. All environments and tooling must be fully provisioned before development begins.', Icons.timeline, const Color(0xFFD97706)),
 const SizedBox(height: 12),
 _buildMethodologyCard('Hybrid', 'Combines waterfall rigour for infrastructure with agile flexibility for feature delivery. Core environments upfront; development evolves iteratively.', Icons.merge_type_outlined, const Color(0xFF7C3AED)),
 const SizedBox(height: 12),
 _buildMethodologyCard('Agile', 'Iterative, incremental delivery. Minimal viable environment for Sprint 1; tooling and infrastructure evolve with each iteration.', Icons.autorenew_outlined, const Color(0xFF16A34A)),
 ],
 );
 }
 return Row(
 children: [
 Expanded(child: _buildMethodologyCard('Waterfall', 'Sequential, phase-gated delivery. All environments and tooling must be fully provisioned before development begins.', Icons.timeline, const Color(0xFFD97706))),
 const SizedBox(width: 12),
 Expanded(child: _buildMethodologyCard('Hybrid', 'Combines waterfall rigour for infrastructure with agile flexibility for feature delivery. Core environments upfront; development evolves iteratively.', Icons.merge_type_outlined, const Color(0xFF7C3AED))),
 const SizedBox(width: 12),
 Expanded(child: _buildMethodologyCard('Agile', 'Iterative, incremental delivery. Minimal viable environment for Sprint 1; tooling and infrastructure evolve with each iteration.', Icons.autorenew_outlined, const Color(0xFF16A34A))),
 ],
 );
 },
 ),
 ],
 ),
 );
 }

 Widget _buildMethodologyCard(String label, String description, IconData icon, Color color) {
 final isSelected = _selectedMethodology == label;
 return GestureDetector(
 onTap: () {
 setState(() => _selectedMethodology = label);
 _scheduleSave();
 },
 child: AnimatedContainer(
 duration: const Duration(milliseconds: 200),
 padding: const EdgeInsets.all(18),
 decoration: BoxDecoration(
 color: isSelected ? color.withOpacity(0.08) : const Color(0xFFF8FAFC),
 borderRadius: BorderRadius.circular(18),
 border: Border.all(
 color: isSelected ? color : const Color(0xFFE2E8F0),
 width: isSelected ? 2.0 : 1.0,
 ),
 boxShadow: isSelected
 ? [BoxShadow(color: color.withOpacity(0.12), blurRadius: 12, offset: const Offset(0, 4))]
 : [],
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 children: [
 Container(
 width: 38,
 height: 38,
 decoration: BoxDecoration(
 color: color.withOpacity(0.12),
 borderRadius: BorderRadius.circular(12),
 border: Border.all(color: color.withOpacity(0.22)),
 ),
 child: Icon(icon, color: color, size: 20),
 ),
 const SizedBox(width: 10),
 Expanded(
 child: Text(label, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: isSelected ? color : const Color(0xFF0F172A))),
 ),
 if (isSelected)
 Container(
 padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
 decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(999)),
 child: const Text('Active', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white)),
 ),
 ],
 ),
 const SizedBox(height: 10),
 Text(description, style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B), height: 1.5)),
 ],
 ),
 ),
 );
 }



 // ══════════════════════════════════════════════════════════════════════════
 // FILTER CHIPS
 // ══════════════════════════════════════════════════════════════════════════

 Widget _buildFilterChips() {
 const filters = ['All registers', 'Environments', 'CI/CD', 'Tooling', 'Quality', 'Security'];
 return Wrap(
 spacing: 10,
 runSpacing: 10,
 children: filters.map((filter) {
 final selected = _selectedFilters.contains(filter);
 return ChoiceChip(
 label: Text(filter, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: selected ? Colors.white : const Color(0xFF475569))),
 selected: selected,
 selectedColor: const Color(0xFF111827),
 backgroundColor: Colors.white,
 shape: StadiumBorder(side: BorderSide(color: const Color(0xFFE5E7EB))),
 onSelected: (value) {
 setState(() {
 if (value) {
 if (filter == 'All registers') {
 _selectedFilters..clear()..add(filter);
 } else {
 _selectedFilters..remove('All registers')..add(filter);
 }
 } else {
 _selectedFilters.remove(filter);
 if (_selectedFilters.isEmpty) _selectedFilters.add('All registers');
 }
 });
 },
 );
 }).toList(),
 );
 }

 // ══════════════════════════════════════════════════════════════════════════
 // STATS ROW
 // ══════════════════════════════════════════════════════════════════════════

 Widget _buildStatsRow() {
 final envReady = _envItems.where((e) => e.status == 'Provisioned').length;
 final pipelineReady = _cicdItems.where((e) => e.status == 'Ready').length;
 final toolsActive = _toolItems.where((e) => e.status == 'Active').length;
 final secInProgress = _securityItems.where((e) => e.status == 'In Progress' || e.status == 'Not Started').length;
 final stats = [
 _StatCardData('Environments Ready', '$envReady/${_envItems.length}', 'Provisioned spaces', const Color(0xFF0EA5E9)),
 _StatCardData('Pipeline Stages', '$pipelineReady/${_cicdItems.length}', 'Ready stages', const Color(0xFF10B981)),
 _StatCardData('Active Tools', '$toolsActive', 'Licensed and active', const Color(0xFFF97316)),
 _StatCardData('Security Pending', '$secInProgress', secInProgress > 0 ? 'Require attention' : 'All complete', const Color(0xFF6366F1)),
 ];
 return LayoutBuilder(
 builder: (context, constraints) {
 final isNarrow = constraints.maxWidth < 700;
 if (isNarrow) {
 return Column(
 children: [
 for (int i = 0; i < stats.length; i++) ...[
 SizedBox(width: double.infinity, child: _buildStatCard(stats[i])),
 if (i < stats.length - 1) const SizedBox(height: 12),
 ],
 ],
 );
 }
 return Row(
 children: [
 for (int i = 0; i < stats.length; i++) ...[
 Expanded(child: _buildStatCard(stats[i])),
 if (i < stats.length - 1) const SizedBox(width: 12),
 ],
 ],
 );
 },
 );
 }

 Widget _buildStatCard(_StatCardData data) {
 return Container(
 padding: const EdgeInsets.all(16),
 decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE2E8F0))),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(data.value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: data.color)),
 const SizedBox(height: 6),
 Text(data.label, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
 const SizedBox(height: 6),
 Text(data.supporting, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: data.color)),
 ],
 ),
 );
 }

 // ══════════════════════════════════════════════════════════════════════════
 // FRAMEWORK GUIDE PANEL
 // ══════════════════════════════════════════════════════════════════════════

 Widget _buildFrameworkGuidePanel() {
 return Container(
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(16),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 6))],
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
 child: Text('Development setup best practices', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF111827))),
 ),
 AnimatedRotation(
 duration: const Duration(milliseconds: 200),
 turns: _frameworkGuideExpanded ? 0.5 : 0,
 child: Icon(Icons.expand_more, size: 22, color: const Color(0xFF6B7280)),
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
 'Grounded in PMI PMBOK Resource Management (9), Quality Management (8), and SAFe 6.0 CALMR approach. '
 'Effective development setup ensures that environments, pipelines, tooling, quality gates, and security baselines '
 'are provisioned and validated before development execution begins.',
 style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF6B7280), height: 1.5),
 ),
 const SizedBox(height: 18),
 _buildGuideCard(Icons.dns_outlined, 'Environment First', 'Provision and validate all environments before onboarding the team. Each environment should mirror its target configuration to prevent late-stage surprises.', const Color(0xFF0EA5E9)),
 const SizedBox(height: 12),
 _buildGuideCard(Icons.play_circle_outline, 'Pipeline Automation', 'Automate build, test, and deployment from day one. Fast feedback loops catch issues early and reduce manual coordination overhead.', const Color(0xFF10B981)),
 const SizedBox(height: 12),
 _buildGuideCard(Icons.handyman_outlined, 'License Governance', 'Track tool licenses, assigned users, and expiry dates. Expired licenses block the team and create compliance risk.', const Color(0xFFF59E0B)),
 const SizedBox(height: 12),
 _buildGuideCard(Icons.shield_outlined, 'Shift-Left Security', 'Integrate security scanning (SAST/DAST) in the CI pipeline from the start. Security debt compounds rapidly if deferred to later phases.', const Color(0xFFEF4444)),
 ],
 ),
 ),
 crossFadeState: _frameworkGuideExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
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
 decoration: BoxDecoration(color: color.withOpacity(0.04), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withOpacity(0.12))),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 children: [
 Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(8)), child: Icon(icon, size: 16, color: color)),
 const SizedBox(width: 10),
 Expanded(child: Text(title, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color))),
 ],
 ),
 const SizedBox(height: 10),
 Text(description, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Color(0xFF4B5563), height: 1.5)),
 ],
 ),
 );
 }

 // ══════════════════════════════════════════════════════════════════════════
 // 1. ENVIRONMENT PROVISIONING REGISTER (CRUD)
 // ══════════════════════════════════════════════════════════════════════════

 Widget _buildEnvProvisionRegister() {
 return _PanelShell(
 title: 'Environment Provisioning Register',
 subtitle: 'Track environment provisioning status, access URLs, and ownership across all deployment spaces.',
 trailing: OutlinedButton.icon(
 onPressed: () => _openEnvDialog(),
 icon: const Icon(Icons.add, size: 16),
 label: const Text('Add', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
 style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFF475569), side: const BorderSide(color: Color(0xFFE2E8F0)), padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
 ),
 child: Column(
 children: [
 // Table header
 Container(
 padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
 decoration: const BoxDecoration(color: Color(0xFFF8FAFC)),
 child: const Row(
 children: [
 Expanded(flex: 4, child: Text('ENVIRONMENT', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF6B7280), letterSpacing: 0.8))),
 SizedBox(width: 110, child: Text('TYPE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF6B7280), letterSpacing: 0.8))),
 SizedBox(width: 120, child: Text('STATUS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF6B7280), letterSpacing: 0.8))),
 Expanded(flex: 3, child: Text('ACCESS URL', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF6B7280), letterSpacing: 0.8))),
 SizedBox(width: 120, child: Text('OWNER', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF6B7280), letterSpacing: 0.8))),
 SizedBox(width: 110, child: Text('TARGET', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF6B7280), letterSpacing: 0.8))),
 SizedBox(width: 60, child: Text('', style: TextStyle(fontSize: 10))),
 ],
 ),
 ),
 if (_envItems.isEmpty)
 const Padding(padding: EdgeInsets.all(32), child: Center(child: Text('No environments registered. Click Add to create one.', style: TextStyle(color: Color(0xFF6B7280)))))
 else
 ...List.generate(_envItems.length, (i) => _buildEnvRow(_envItems[i], i)),
 ],
 ),
 );
 }

 Widget _buildEnvRow(_EnvProvisionItem item, int index) {
 final color = _statusColor(item.status);
 return Container(
 padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
 decoration: BoxDecoration(color: index.isEven ? Colors.white : const Color(0xFFF8FAFC), border: Border(bottom: BorderSide(color: const Color(0xFFF1F5F9)))),
 child: Row(
 children: [
 Expanded(flex: 4, child: Text(item.environment, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)))),
 SizedBox(width: 110, child: Text(item.type, style: const TextStyle(fontSize: 12, color: Color(0xFF475569)))),
 SizedBox(width: 120, child: _buildStatusTag(item.status, color)),
 Expanded(flex: 3, child: Text(item.accessUrl, style: const TextStyle(fontSize: 11, fontFamily: appFontFamily, color: Color(0xFFD97706)), overflow: TextOverflow.ellipsis)),
 SizedBox(width: 120, child: Text(item.owner, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)))),
 SizedBox(width: 110, child: Text(item.targetDate, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)))),
 SizedBox(
 width: 60,
 child: Row(
 children: [
 IconButton(icon: const Icon(Icons.edit_outlined, size: 16, color: Color(0xFF64748B)), onPressed: () => _openEnvDialog(existing: item), padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 28, minHeight: 28)),
 IconButton(icon: const Icon(Icons.delete_outline, size: 16, color: Color(0xFFEF4444)), onPressed: () => _confirmDelete('environment', item.id, () { setState(() => _envItems.removeWhere((e) => e.id == item.id)); _scheduleSave(); }), padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 28, minHeight: 28)),
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
 ),
 ),
 ],
 ),
 );
 }

 Future<void> _openEnvDialog({_EnvProvisionItem? existing}) async {
 final isEdit = existing != null;
 final envCtrl = TextEditingController(text: existing?.environment ?? '');
 final typeCtrl = TextEditingController(text: existing?.type ?? '');
 final statusCtrl = TextEditingController(text: existing?.status ?? 'Not Started');
 final urlCtrl = TextEditingController(text: existing?.accessUrl ?? '');
 final ownerCtrl = TextEditingController(text: existing?.owner ?? '');
 final dateCtrl = TextEditingController(text: existing?.targetDate ?? '');
 final notesCtrl = TextEditingController(text: existing?.notes ?? '');
 await showDialog(
 context: context,
 builder: (ctx) => AlertDialog(
 title: Text(isEdit ? 'Edit Environment' : 'Add Environment'),
 content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
 _dialogField('Environment', envCtrl),
 _dialogField('Type', typeCtrl),
 _dialogField('Status', statusCtrl, hint: 'Provisioned / In Progress / Not Started'),
 _dialogField('Access URL', urlCtrl),
 _dialogField('Owner', ownerCtrl),
 _dialogField('Target Date', dateCtrl),
 _dialogField('Notes', notesCtrl),
 ])),
 actions: [
 TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
 ElevatedButton(onPressed: () {
 final item = _EnvProvisionItem(
 id: existing?.id ?? _newId(),
 environment: envCtrl.text.trim(),
 type: typeCtrl.text.trim(),
 status: statusCtrl.text.trim(),
 accessUrl: urlCtrl.text.trim(),
 owner: ownerCtrl.text.trim(),
 targetDate: dateCtrl.text.trim(),
 notes: notesCtrl.text.trim(),
 );
 setState(() {
 if (isEdit) {
 final idx = _envItems.indexWhere((e) => e.id == item.id);
 if (idx >= 0) _envItems[idx] = item;
 } else {
 _envItems.add(item);
 }
 });
 _scheduleSave();
 Navigator.pop(ctx);
 }, child: Text(isEdit ? 'Save' : 'Add')),
 ],
 ),
 );
 }

 // ══════════════════════════════════════════════════════════════════════════
 // 2. CI/CD PIPELINE REGISTER (CRUD)
 // ══════════════════════════════════════════════════════════════════════════

 Widget _buildCicdPipelineRegister() {
 return _PanelShell(
 title: 'CI/CD Pipeline Register',
 subtitle: 'Track pipeline stages, tools, triggers, and gate criteria for the build-test-deploy workflow.',
 trailing: OutlinedButton.icon(
 onPressed: () => _openCicdDialog(),
 icon: const Icon(Icons.add, size: 16),
 label: const Text('Add', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
 style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFF475569), side: const BorderSide(color: Color(0xFFE2E8F0)), padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
 ),
 child: Column(
 children: [
 Container(
 padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
 decoration: const BoxDecoration(color: Color(0xFFF8FAFC)),
 child: const Row(
 children: [
 Expanded(flex: 3, child: Text('STAGE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF6B7280), letterSpacing: 0.8))),
 SizedBox(width: 130, child: Text('TOOL', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF6B7280), letterSpacing: 0.8))),
 SizedBox(width: 120, child: Text('STATUS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF6B7280), letterSpacing: 0.8))),
 Expanded(flex: 3, child: Text('TRIGGER', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF6B7280), letterSpacing: 0.8))),
 Expanded(flex: 3, child: Text('GATE CRITERIA', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF6B7280), letterSpacing: 0.8))),
 SizedBox(width: 130, child: Text('OWNER', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF6B7280), letterSpacing: 0.8))),
 SizedBox(width: 60, child: Text('', style: TextStyle(fontSize: 10))),
 ],
 ),
 ),
 if (_cicdItems.isEmpty)
 const Padding(padding: EdgeInsets.all(32), child: Center(child: Text('No pipeline stages registered. Click Add to create one.', style: TextStyle(color: Color(0xFF6B7280)))))
 else
 ...List.generate(_cicdItems.length, (i) => _buildCicdRow(_cicdItems[i], i)),
 ],
 ),
 );
 }

 Widget _buildCicdRow(_CicdPipelineItem item, int index) {
 final color = _statusColor(item.status);
 return Container(
 padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
 decoration: BoxDecoration(color: index.isEven ? Colors.white : const Color(0xFFF8FAFC), border: Border(bottom: BorderSide(color: const Color(0xFFF1F5F9)))),
 child: Row(
 children: [
 Expanded(flex: 3, child: Text(item.stage, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)))),
 SizedBox(width: 130, child: Text(item.tool, style: const TextStyle(fontSize: 12, color: Color(0xFF475569)))),
 SizedBox(width: 120, child: _buildStatusTag(item.status, color)),
 Expanded(flex: 3, child: Text(item.trigger, style: const TextStyle(fontSize: 12, color: Color(0xFF475569)), overflow: TextOverflow.ellipsis)),
 Expanded(flex: 3, child: Text(item.gateCriteria, style: const TextStyle(fontSize: 12, color: Color(0xFF475569)), overflow: TextOverflow.ellipsis)),
 SizedBox(width: 130, child: Text(item.owner, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)))),
 SizedBox(
 width: 60,
 child: Row(
 children: [
 IconButton(icon: const Icon(Icons.edit_outlined, size: 16, color: Color(0xFF64748B)), onPressed: () => _openCicdDialog(existing: item), padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 28, minHeight: 28)),
 IconButton(icon: const Icon(Icons.delete_outline, size: 16, color: Color(0xFFEF4444)), onPressed: () => _confirmDelete('pipeline stage', item.id, () { setState(() => _cicdItems.removeWhere((e) => e.id == item.id)); _scheduleSave(); }), padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 28, minHeight: 28)),
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
 ),
 ),
 ],
 ),
 );
 }

 Future<void> _openCicdDialog({_CicdPipelineItem? existing}) async {
 final isEdit = existing != null;
 final stageCtrl = TextEditingController(text: existing?.stage ?? '');
 final toolCtrl = TextEditingController(text: existing?.tool ?? '');
 final statusCtrl = TextEditingController(text: existing?.status ?? 'Pending');
 final triggerCtrl = TextEditingController(text: existing?.trigger ?? '');
 final gateCtrl = TextEditingController(text: existing?.gateCriteria ?? '');
 final ownerCtrl = TextEditingController(text: existing?.owner ?? '');
 await showDialog(
 context: context,
 builder: (ctx) => AlertDialog(
 title: Text(isEdit ? 'Edit Pipeline Stage' : 'Add Pipeline Stage'),
 content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
 _dialogField('Stage', stageCtrl),
 _dialogField('Tool', toolCtrl),
 _dialogField('Status', statusCtrl, hint: 'Ready / Pending / Not Started'),
 _dialogField('Trigger', triggerCtrl),
 _dialogField('Gate Criteria', gateCtrl),
 _dialogField('Owner', ownerCtrl),
 ])),
 actions: [
 TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
 ElevatedButton(onPressed: () {
 final item = _CicdPipelineItem(
 id: existing?.id ?? _newId(),
 stage: stageCtrl.text.trim(),
 tool: toolCtrl.text.trim(),
 status: statusCtrl.text.trim(),
 trigger: triggerCtrl.text.trim(),
 gateCriteria: gateCtrl.text.trim(),
 owner: ownerCtrl.text.trim(),
 );
 setState(() {
 if (isEdit) {
 final idx = _cicdItems.indexWhere((e) => e.id == item.id);
 if (idx >= 0) _cicdItems[idx] = item;
 } else {
 _cicdItems.add(item);
 }
 });
 _scheduleSave();
 Navigator.pop(ctx);
 }, child: Text(isEdit ? 'Save' : 'Add')),
 ],
 ),
 );
 }

 // ══════════════════════════════════════════════════════════════════════════
 // 3. DEVELOPMENT TOOLS REGISTER (CRUD)
 // ══════════════════════════════════════════════════════════════════════════

 Widget _buildDevToolsRegister() {
 return _PanelShell(
 title: 'Development Tools Register',
 subtitle: 'Track tool licensing, assigned users, status, and expiry dates for the project toolchain.',
 trailing: OutlinedButton.icon(
 onPressed: () => _openToolDialog(),
 icon: const Icon(Icons.add, size: 16),
 label: const Text('Add', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
 style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFF475569), side: const BorderSide(color: Color(0xFFE2E8F0)), padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
 ),
 child: Column(
 children: [
 Container(
 padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
 decoration: const BoxDecoration(color: Color(0xFFF8FAFC)),
 child: const Row(
 children: [
 Expanded(flex: 3, child: Text('TOOL', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF6B7280), letterSpacing: 0.8))),
 SizedBox(width: 120, child: Text('CATEGORY', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF6B7280), letterSpacing: 0.8))),
 SizedBox(width: 110, child: Text('LICENSE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF6B7280), letterSpacing: 0.8))),
 SizedBox(width: 110, child: Text('USERS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF6B7280), letterSpacing: 0.8))),
 SizedBox(width: 70, child: Text('STATUS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF6B7280), letterSpacing: 0.8))),
 SizedBox(width: 110, child: Text('EXPIRY', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF6B7280), letterSpacing: 0.8))),
 SizedBox(width: 120, child: Text('OWNER', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF6B7280), letterSpacing: 0.8))),
 SizedBox(width: 60, child: Text('', style: TextStyle(fontSize: 10))),
 ],
 ),
 ),
 if (_toolItems.isEmpty)
 const Padding(padding: EdgeInsets.all(32), child: Center(child: Text('No tools registered. Click Add to create one.', style: TextStyle(color: Color(0xFF6B7280)))))
 else
 ...List.generate(_toolItems.length, (i) => _buildToolRow(_toolItems[i], i)),
 ],
 ),
 );
 }

 Widget _buildToolRow(_DevToolItem item, int index) {
 final color = _statusColor(item.status);
 return Container(
 padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
 decoration: BoxDecoration(color: index.isEven ? Colors.white : const Color(0xFFF8FAFC), border: Border(bottom: BorderSide(color: const Color(0xFFF1F5F9)))),
 child: Row(
 children: [
 Expanded(flex: 3, child: Text(item.tool, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)))),
 SizedBox(width: 120, child: Text(item.category, style: const TextStyle(fontSize: 12, color: Color(0xFF475569)))),
 SizedBox(width: 110, child: Text(item.license, style: const TextStyle(fontSize: 12, color: Color(0xFF475569)))),
 SizedBox(width: 110, child: Text(item.assignedUsers, style: const TextStyle(fontSize: 12, color: Color(0xFF475569)))),
 SizedBox(width: 70, child: _buildStatusTag(item.status, color)),
 SizedBox(width: 110, child: Text(item.expiry, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)))),
 SizedBox(width: 120, child: Text(item.owner, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)))),
 SizedBox(
 width: 60,
 child: Row(
 children: [
 IconButton(icon: const Icon(Icons.edit_outlined, size: 16, color: Color(0xFF64748B)), onPressed: () => _openToolDialog(existing: item), padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 28, minHeight: 28)),
 IconButton(icon: const Icon(Icons.delete_outline, size: 16, color: Color(0xFFEF4444)), onPressed: () => _confirmDelete('tool', item.id, () { setState(() => _toolItems.removeWhere((e) => e.id == item.id)); _scheduleSave(); }), padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 28, minHeight: 28)),
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
 ),
 ),
 ],
 ),
 );
 }

 Future<void> _openToolDialog({_DevToolItem? existing}) async {
 final isEdit = existing != null;
 final toolCtrl = TextEditingController(text: existing?.tool ?? '');
 final catCtrl = TextEditingController(text: existing?.category ?? '');
 final licCtrl = TextEditingController(text: existing?.license ?? '');
 final usersCtrl = TextEditingController(text: existing?.assignedUsers ?? '');
 final statusCtrl = TextEditingController(text: existing?.status ?? 'Active');
 final expiryCtrl = TextEditingController(text: existing?.expiry ?? '');
 final ownerCtrl = TextEditingController(text: existing?.owner ?? '');
 await showDialog(
 context: context,
 builder: (ctx) => AlertDialog(
 title: Text(isEdit ? 'Edit Tool' : 'Add Tool'),
 content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
 _dialogField('Tool', toolCtrl),
 _dialogField('Category', catCtrl, hint: 'IDE / VCS / Cloud / Design'),
 _dialogField('License', licCtrl, hint: 'Enterprise / Premium / Team'),
 _dialogField('Assigned Users', usersCtrl),
 _dialogField('Status', statusCtrl, hint: 'Active / Expired / Pending'),
 _dialogField('Expiry', expiryCtrl),
 _dialogField('Owner', ownerCtrl),
 ])),
 actions: [
 TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
 ElevatedButton(onPressed: () {
 final item = _DevToolItem(
 id: existing?.id ?? _newId(),
 tool: toolCtrl.text.trim(),
 category: catCtrl.text.trim(),
 license: licCtrl.text.trim(),
 assignedUsers: usersCtrl.text.trim(),
 status: statusCtrl.text.trim(),
 expiry: expiryCtrl.text.trim(),
 owner: ownerCtrl.text.trim(),
 );
 setState(() {
 if (isEdit) {
 final idx = _toolItems.indexWhere((e) => e.id == item.id);
 if (idx >= 0) _toolItems[idx] = item;
 } else {
 _toolItems.add(item);
 }
 });
 _scheduleSave();
 Navigator.pop(ctx);
 }, child: Text(isEdit ? 'Save' : 'Add')),
 ],
 ),
 );
 }

 // ══════════════════════════════════════════════════════════════════════════
 // 4. QUALITY GATES REGISTER (CRUD)
 // ══════════════════════════════════════════════════════════════════════════

 Widget _buildQualityGatesRegister() {
 return _PanelShell(
 title: 'Quality Gates Register',
 subtitle: 'Track quality gates, criteria, methodology alignment, and approver accountability for all quality checkpoints.',
 trailing: OutlinedButton.icon(
 onPressed: () => _openQualityDialog(),
 icon: const Icon(Icons.add, size: 16),
 label: const Text('Add', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
 style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFF475569), side: const BorderSide(color: Color(0xFFE2E8F0)), padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
 ),
 child: Column(
 children: [
 Container(
 padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
 decoration: const BoxDecoration(color: Color(0xFFF8FAFC)),
 child: const Row(
 children: [
 Expanded(flex: 3, child: Text('GATE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF6B7280), letterSpacing: 0.8))),
 Expanded(flex: 4, child: Text('CRITERIA', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF6B7280), letterSpacing: 0.8))),
 SizedBox(width: 120, child: Text('METHOD', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF6B7280), letterSpacing: 0.8))),
 SizedBox(width: 110, child: Text('STATUS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF6B7280), letterSpacing: 0.8))),
 SizedBox(width: 130, child: Text('APPROVER', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF6B7280), letterSpacing: 0.8))),
 SizedBox(width: 120, child: Text('TARGET', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF6B7280), letterSpacing: 0.8))),
 SizedBox(width: 60, child: Text('', style: TextStyle(fontSize: 10))),
 ],
 ),
 ),
 if (_qualityItems.isEmpty)
 const Padding(padding: EdgeInsets.all(32), child: Center(child: Text('No quality gates registered. Click Add to create one.', style: TextStyle(color: Color(0xFF6B7280)))))
 else
 ...List.generate(_qualityItems.length, (i) => _buildQualityRow(_qualityItems[i], i)),
 ],
 ),
 );
 }

 Widget _buildQualityRow(_QualityGateItem item, int index) {
 final color = _statusColor(item.status);
 return Container(
 padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
 decoration: BoxDecoration(color: index.isEven ? Colors.white : const Color(0xFFF8FAFC), border: Border(bottom: BorderSide(color: const Color(0xFFF1F5F9)))),
 child: Row(
 children: [
 Expanded(flex: 3, child: Text(item.gate, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)))),
 Expanded(flex: 4, child: Text(item.criteria, style: const TextStyle(fontSize: 12, color: Color(0xFF475569)), overflow: TextOverflow.ellipsis)),
 SizedBox(width: 120, child: Text(item.methodology, style: const TextStyle(fontSize: 12, color: Color(0xFF475569)))),
 SizedBox(width: 110, child: _buildStatusTag(item.status, color)),
 SizedBox(width: 130, child: Text(item.approver, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)))),
 SizedBox(width: 120, child: Text(item.targetDate, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)))),
 SizedBox(
 width: 60,
 child: Row(
 children: [
 IconButton(icon: const Icon(Icons.edit_outlined, size: 16, color: Color(0xFF64748B)), onPressed: () => _openQualityDialog(existing: item), padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 28, minHeight: 28)),
 IconButton(icon: const Icon(Icons.delete_outline, size: 16, color: Color(0xFFEF4444)), onPressed: () => _confirmDelete('quality gate', item.id, () { setState(() => _qualityItems.removeWhere((e) => e.id == item.id)); _scheduleSave(); }), padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 28, minHeight: 28)),
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
 ),
 ),
 ],
 ),
 );
 }

 Future<void> _openQualityDialog({_QualityGateItem? existing}) async {
 final isEdit = existing != null;
 final gateCtrl = TextEditingController(text: existing?.gate ?? '');
 final critCtrl = TextEditingController(text: existing?.criteria ?? '');
 var selectedMethodology = _methodologyOptions.contains(existing?.methodology)
 ? existing!.methodology
 : _methodologyOptions.first;
 var selectedStatus = _qualityStatusOptions.contains(existing?.status)
 ? existing!.status
 : _qualityStatusOptions.first;
 final apprCtrl = TextEditingController(text: existing?.approver ?? '');
 DateTime? selectedTargetDate;
 if (existing?.targetDate != null && existing!.targetDate.isNotEmpty) {
 selectedTargetDate = DateFormat('MMM dd, yyyy').tryParse(existing.targetDate) ??
 DateFormat('yyyy-MM-dd').tryParse(existing.targetDate);
 }

 await showDialog(
 context: context,
 builder: (ctx) => StatefulBuilder(
 builder: (ctx, setDialogState) => AlertDialog(
 title: Text(isEdit ? 'Edit Quality Gate' : 'Add Quality Gate'),
 content: SizedBox(
 width: 560,
 child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
 _dialogField('Gate', gateCtrl, hint: 'e.g. Sprint Review Gate'),
 const SizedBox(height: 4),
 _dialogField('Criteria', critCtrl, hint: 'e.g. All acceptance tests pass'),
 const SizedBox(height: 4),
 DropdownButtonFormField<String>(
 value: selectedMethodology,
 decoration: const InputDecoration(
 labelText: 'Methodology',
 border: OutlineInputBorder(),
 isDense: true,
 contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
 ),
 items: _methodologyOptions
 .map((m) => DropdownMenuItem(value: m, child: Text(m, style: const TextStyle(fontSize: 12))))
 .toList(),
 onChanged: (value) {
 if (value == null) return;
 setDialogState(() => selectedMethodology = value);
 },
 ),
 const SizedBox(height: 16),
 DropdownButtonFormField<String>(
 value: selectedStatus,
 decoration: const InputDecoration(
 labelText: 'Status',
 border: OutlineInputBorder(),
 isDense: true,
 contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
 ),
 items: _qualityStatusOptions
 .map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 12))))
 .toList(),
 onChanged: (value) {
 if (value == null) return;
 setDialogState(() => selectedStatus = value);
 },
 ),
 const SizedBox(height: 16),
 _dialogField('Approver', apprCtrl, hint: 'e.g. QA Lead'),
 const SizedBox(height: 4),
 GestureDetector(
 onTap: () async {
 final picked = await showDatePicker(
 context: context,
 initialDate: selectedTargetDate ?? DateTime.now().add(const Duration(days: 30)),
 firstDate: DateTime(2020),
 lastDate: DateTime(2040),
 );
 if (picked != null) {
 setDialogState(() => selectedTargetDate = picked);
 }
 },
 child: InputDecorator(
 decoration: const InputDecoration(
 labelText: 'Target Date',
 border: OutlineInputBorder(),
 isDense: true,
 contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
 suffixIcon: Icon(Icons.calendar_today, size: 18),
 ),
 child: Text(
 selectedTargetDate != null
 ? DateFormat('MMM dd, yyyy').format(selectedTargetDate!)
 : 'Select date',
 style: TextStyle(
 color: selectedTargetDate != null ? null : Colors.grey,
 fontSize: 14,
 ),
 ),
 ),
 ),
 ])),
 ),
 actions: [
 TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
 ElevatedButton(onPressed: () {
 final item = _QualityGateItem(
 id: existing?.id ?? _newId(),
 gate: gateCtrl.text.trim(),
 criteria: critCtrl.text.trim(),
 methodology: selectedMethodology,
 status: selectedStatus,
 approver: apprCtrl.text.trim(),
 targetDate: selectedTargetDate != null
 ? DateFormat('MMM dd, yyyy').format(selectedTargetDate!)
 : '',
 );
 setState(() {
 if (isEdit) {
 final idx = _qualityItems.indexWhere((e) => e.id == item.id);
 if (idx >= 0) _qualityItems[idx] = item;
 } else {
 _qualityItems.add(item);
 }
 });
 _scheduleSave();
 Navigator.pop(ctx);
 }, child: Text(isEdit ? 'Save' : 'Add')),
 ],
 ),
 ),
 );
 }

 // ══════════════════════════════════════════════════════════════════════════
 // 5. SECURITY BASELINE REGISTER (CRUD)
 // ══════════════════════════════════════════════════════════════════════════

 Widget _buildSecurityBaselineRegister() {
 return _PanelShell(
 title: 'Security Baseline Register',
 subtitle: 'Track security controls, framework compliance, evidence, and review dates for all security baseline items.',
 trailing: OutlinedButton.icon(
 onPressed: () => _openSecurityDialog(),
 icon: const Icon(Icons.add, size: 16),
 label: const Text('Add', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
 style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFF475569), side: const BorderSide(color: Color(0xFFE2E8F0)), padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
 ),
 child: Column(
 children: [
 Container(
 padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
 decoration: const BoxDecoration(color: Color(0xFFF8FAFC)),
 child: const Row(
 children: [
 Expanded(flex: 3, child: Text('CONTROL', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF6B7280), letterSpacing: 0.8))),
 SizedBox(width: 120, child: Text('FRAMEWORK', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF6B7280), letterSpacing: 0.8))),
 SizedBox(width: 120, child: Text('STATUS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF6B7280), letterSpacing: 0.8))),
 Expanded(flex: 3, child: Text('EVIDENCE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF6B7280), letterSpacing: 0.8))),
 SizedBox(width: 130, child: Text('OWNER', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF6B7280), letterSpacing: 0.8))),
 SizedBox(width: 110, child: Text('REVIEW', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF6B7280), letterSpacing: 0.8))),
 SizedBox(width: 60, child: Text('', style: TextStyle(fontSize: 10))),
 ],
 ),
 ),
 if (_securityItems.isEmpty)
 const Padding(padding: EdgeInsets.all(32), child: Center(child: Text('No security controls registered. Click Add to create one.', style: TextStyle(color: Color(0xFF6B7280)))))
 else
 ...List.generate(_securityItems.length, (i) => _buildSecurityRow(_securityItems[i], i)),
 ],
 ),
 );
 }

 Widget _buildSecurityRow(_SecurityBaselineItem item, int index) {
 final color = _statusColor(item.status);
 return Container(
 padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
 decoration: BoxDecoration(color: index.isEven ? Colors.white : const Color(0xFFF8FAFC), border: Border(bottom: BorderSide(color: const Color(0xFFF1F5F9)))),
 child: Row(
 children: [
 Expanded(flex: 3, child: Text(item.control, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)))),
 SizedBox(width: 120, child: Text(item.framework, style: const TextStyle(fontSize: 12, color: Color(0xFF475569)))),
 SizedBox(width: 120, child: _buildStatusTag(item.status, color)),
 Expanded(flex: 3, child: Text(item.evidence, style: const TextStyle(fontSize: 12, color: Color(0xFF475569)), overflow: TextOverflow.ellipsis)),
 SizedBox(width: 130, child: Text(item.owner, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)))),
 SizedBox(width: 110, child: Text(item.reviewDate, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)))),
 SizedBox(
 width: 60,
 child: Row(
 children: [
 IconButton(icon: const Icon(Icons.edit_outlined, size: 16, color: Color(0xFF64748B)), onPressed: () => _openSecurityDialog(existing: item), padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 28, minHeight: 28)),
 IconButton(icon: const Icon(Icons.delete_outline, size: 16, color: Color(0xFFEF4444)), onPressed: () => _confirmDelete('security control', item.id, () { setState(() => _securityItems.removeWhere((e) => e.id == item.id)); _scheduleSave(); }), padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 28, minHeight: 28)),
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
 ),
 ),
 ],
 ),
 );
 }

 Future<void> _openSecurityDialog({_SecurityBaselineItem? existing}) async {
 final isEdit = existing != null;
 final ctrlCtrl = TextEditingController(text: existing?.control ?? '');
 final frameFieldCtrl = TextEditingController(text: existing?.framework ?? '');
 final statusCtrl = TextEditingController(text: existing?.status ?? 'Not Started');
 final evidCtrl = TextEditingController(text: existing?.evidence ?? '');
 final ownerCtrl = TextEditingController(text: existing?.owner ?? '');
 final dateCtrl = TextEditingController(text: existing?.reviewDate ?? '');
 await showDialog(
 context: context,
 builder: (ctx) => AlertDialog(
 title: Text(isEdit ? 'Edit Security Control' : 'Add Security Control'),
 content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
 _dialogField('Control', ctrlCtrl),
 _dialogField('Framework', frameFieldCtrl, hint: 'NIST 800-53 / OWASP / ISO 27001'),
 _dialogField('Status', statusCtrl, hint: 'In Progress / Not Started / Planned'),
 _dialogField('Evidence', evidCtrl),
 _dialogField('Owner', ownerCtrl),
 _dialogField('Review Date', dateCtrl),
 ])),
 actions: [
 TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
 ElevatedButton(onPressed: () {
 final item = _SecurityBaselineItem(
 id: existing?.id ?? _newId(),
 control: ctrlCtrl.text.trim(),
 framework: frameFieldCtrl.text.trim(),
 status: statusCtrl.text.trim(),
 evidence: evidCtrl.text.trim(),
 owner: ownerCtrl.text.trim(),
 reviewDate: dateCtrl.text.trim(),
 );
 setState(() {
 if (isEdit) {
 final idx = _securityItems.indexWhere((e) => e.id == item.id);
 if (idx >= 0) _securityItems[idx] = item;
 } else {
 _securityItems.add(item);
 }
 });
 _scheduleSave();
 Navigator.pop(ctx);
 }, child: Text(isEdit ? 'Save' : 'Add')),
 ],
 ),
 );
 }

 // ══════════════════════════════════════════════════════════════════════════
 // 6. APPROVAL GATES PANEL
 // ══════════════════════════════════════════════════════════════════════════

 Widget _buildApprovalGatesPanel() {
 return _PanelShell(
 title: 'Approval Gates',
 subtitle: 'Development readiness approval gates aligned with PMI PMBOK phase gates and organizational authority matrices. Each gate must be cleared before development can commence.',
 trailing: OutlinedButton.icon(
 onPressed: () => _openApprovalDialog(),
 icon: const Icon(Icons.add, size: 16),
 label: const Text('Add gate', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
 style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFF475569), side: const BorderSide(color: Color(0xFFE2E8F0)), padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
 ),
 child: Column(
 children: _approvalGates.isEmpty
 ? [const Padding(padding: EdgeInsets.all(12), child: Text('No approval gates configured.', style: TextStyle(color: Color(0xFF6B7280))))]
 : _approvalGates.map((gate) => _buildApprovalGateCard(gate)).toList(),
 ),
 );
 }

 Widget _buildApprovalGateCard(_ApprovalGateItem gate) {
 final color = _statusColor(gate.status);
 return Container(
 margin: const EdgeInsets.only(bottom: 12),
 padding: const EdgeInsets.all(16),
 decoration: BoxDecoration(
 color: color.withOpacity(0.04),
 borderRadius: BorderRadius.circular(12),
 border: Border.all(color: color.withOpacity(0.15)),
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 children: [
 Container(
 padding: const EdgeInsets.all(8),
 decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
 child: Icon(Icons.verified_user_outlined, size: 18, color: color),
 ),
 const SizedBox(width: 12),
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(gate.gate, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
 const SizedBox(height: 2),
 Text(gate.description, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.4)),
 ],
 ),
 ),
 const SizedBox(width: 8),
 _buildStatusTag(gate.status, color),
 const SizedBox(width: 8),
 IconButton(icon: const Icon(Icons.edit_outlined, size: 16, color: Color(0xFF64748B)), onPressed: () => _openApprovalDialog(existing: gate), padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 32, minHeight: 32)),
 IconButton(icon: const Icon(Icons.delete_outline, size: 16, color: Color(0xFFEF4444)), onPressed: () => _confirmDelete('approval gate', gate.id, () { setState(() => _approvalGates.removeWhere((e) => e.id == gate.id)); _scheduleSave(); }), padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 32, minHeight: 32)),
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
 ),
 const SizedBox(height: 10),
 Row(
 children: [
 const Icon(Icons.person_outline, size: 14, color: Color(0xFF9CA3AF)),
 const SizedBox(width: 4),
 Text(gate.approver, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
 const SizedBox(width: 16),
 const Icon(Icons.calendar_today_outlined, size: 14, color: Color(0xFF9CA3AF)),
 const SizedBox(width: 4),
 Text(gate.targetDate, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
 ],
 ),
 ],
 ),
 );
 }

 Future<void> _openApprovalDialog({_ApprovalGateItem? existing}) async {
 final isEdit = existing != null;
 final gateCtrl = TextEditingController(text: existing?.gate ?? '');
 final descCtrl = TextEditingController(text: existing?.description ?? '');
 final statusCtrl = TextEditingController(text: existing?.status ?? 'Not Started');
 final apprCtrl = TextEditingController(text: existing?.approver ?? '');
 final dateCtrl = TextEditingController(text: existing?.targetDate ?? 'TBD');
 await showDialog(
 context: context,
 builder: (ctx) => AlertDialog(
 title: Text(isEdit ? 'Edit Approval Gate' : 'Add Approval Gate'),
 content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
 _dialogField('Gate', gateCtrl),
 _dialogField('Description', descCtrl),
 _dialogField('Status', statusCtrl, hint: 'Not Started / In Progress / Approved'),
 _dialogField('Approver', apprCtrl),
 _dialogField('Target Date', dateCtrl),
 ])),
 actions: [
 TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
 ElevatedButton(onPressed: () {
 final item = _ApprovalGateItem(
 id: existing?.id ?? _newId(),
 gate: gateCtrl.text.trim(),
 description: descCtrl.text.trim(),
 status: statusCtrl.text.trim(),
 approver: apprCtrl.text.trim(),
 targetDate: dateCtrl.text.trim(),
 );
 setState(() {
 if (isEdit) {
 final idx = _approvalGates.indexWhere((e) => e.id == item.id);
 if (idx >= 0) _approvalGates[idx] = item;
 } else {
 _approvalGates.add(item);
 }
 });
 _scheduleSave();
 Navigator.pop(ctx);
 }, child: Text(isEdit ? 'Save' : 'Add')),
 ],
 ),
 );
 }

 // ══════════════════════════════════════════════════════════════════════════
 // SHARED: DELETE CONFIRMATION
 // ══════════════════════════════════════════════════════════════════════════

 void _confirmDelete(String itemType, String itemId, VoidCallback onDelete) {
 showDialog(
 context: context,
 builder: (ctx) => AlertDialog(
 title: Text('Delete $itemType?'),
 content: Text('Are you sure you want to delete this $itemType? This action cannot be undone.'),
 actions: [
 TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
 ElevatedButton(
 style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444), foregroundColor: Colors.white),
 onPressed: () {
 onDelete();
 Navigator.pop(ctx);
 },
 child: const Text('Delete'),
 ),
 ],
 ),
 );
 }

 // ══════════════════════════════════════════════════════════════════════════
 // SHARED: DIALOG FIELD
 // ══════════════════════════════════════════════════════════════════════════

 Widget _dialogField(String label, TextEditingController controller, {String? hint}) {
 return Padding(
 padding: const EdgeInsets.only(bottom: 12),
 child: VoiceTextField(
 controller: controller,
 decoration: InputDecoration(
 labelText: label,
 hintText: hint,
 border: const OutlineInputBorder(),
 isDense: true,
 contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
 ),
 ),
 );
 }

 Future<void> _exportPdf() async {
 final projectData = ProjectDataHelper.getData(context);
 await PdfExportHelper.exportScreenPdf(
 context: context,
 screenTitle: 'Development Set-Up',
 sections: [
 PdfSection.keyValue('Project Info', [
 {'Project Name': projectData.projectName ?? 'N/A'},
 {'Solution Title': projectData.solutionTitle ?? 'N/A'},
 ]),
 PdfSection.text('Notes', projectData.planningNotes['planning_development_set_up_notes'] ?? 'No data recorded.'),
 ],
 );
 }
}

// ════════════════════════════════════════════════════════════════════════════
// PANEL SHELL WIDGET
// ════════════════════════════════════════════════════════════════════════════

class _PanelShell extends StatelessWidget {
 final String title;
 final String subtitle;
 final Widget? trailing;
 final Widget child;

 const _PanelShell({
 required this.title,
 required this.subtitle,
 this.trailing,
 required this.child,
 });

 @override
 Widget build(BuildContext context) {
 return Container(
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(16),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 6))],
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
 child,
 ],
 ),
 );
 }
}

// ════════════════════════════════════════════════════════════════════════════
// STAT CARD DATA
// ════════════════════════════════════════════════════════════════════════════

class _StatCardData {
 final String label;
 final String value;
 final String supporting;
 final Color color;
 const _StatCardData(this.label, this.value, this.supporting, this.color);
}

// ════════════════════════════════════════════════════════════════════════════
// DATA MODEL CLASSES
// ════════════════════════════════════════════════════════════════════════════

class _EnvProvisionItem {
 final String id;
 final String environment;
 final String type;
 final String status;
 final String accessUrl;
 final String owner;
 final String targetDate;
 final String notes;

 const _EnvProvisionItem({
 required this.id,
 required this.environment,
 required this.type,
 required this.status,
 required this.accessUrl,
 required this.owner,
 required this.targetDate,
 required this.notes,
 });

 Map<String, dynamic> toMap() => {
 'id': id, 'environment': environment, 'type': type, 'status': status,
 'accessUrl': accessUrl, 'owner': owner, 'targetDate': targetDate, 'notes': notes,
 };

 static List<_EnvProvisionItem> fromList(dynamic data) {
 if (data is! List) return [];
 return data.map((e) {
 final m = e as Map<String, dynamic>;
 return _EnvProvisionItem(
 id: m['id'] ?? '', environment: m['environment'] ?? '', type: m['type'] ?? '',
 status: m['status'] ?? '', accessUrl: m['accessUrl'] ?? '', owner: m['owner'] ?? '',
 targetDate: m['targetDate'] ?? '', notes: m['notes'] ?? '',
 );
 }).toList();
 }
}

class _CicdPipelineItem {
 final String id;
 final String stage;
 final String tool;
 final String status;
 final String trigger;
 final String gateCriteria;
 final String owner;

 const _CicdPipelineItem({
 required this.id,
 required this.stage,
 required this.tool,
 required this.status,
 required this.trigger,
 required this.gateCriteria,
 required this.owner,
 });

 Map<String, dynamic> toMap() => {
 'id': id, 'stage': stage, 'tool': tool, 'status': status,
 'trigger': trigger, 'gateCriteria': gateCriteria, 'owner': owner,
 };

 static List<_CicdPipelineItem> fromList(dynamic data) {
 if (data is! List) return [];
 return data.map((e) {
 final m = e as Map<String, dynamic>;
 return _CicdPipelineItem(
 id: m['id'] ?? '', stage: m['stage'] ?? '', tool: m['tool'] ?? '',
 status: m['status'] ?? '', trigger: m['trigger'] ?? '',
 gateCriteria: m['gateCriteria'] ?? '', owner: m['owner'] ?? '',
 );
 }).toList();
 }
}

class _DevToolItem {
 final String id;
 final String tool;
 final String category;
 final String license;
 final String assignedUsers;
 final String status;
 final String expiry;
 final String owner;

 const _DevToolItem({
 required this.id,
 required this.tool,
 required this.category,
 required this.license,
 required this.assignedUsers,
 required this.status,
 required this.expiry,
 required this.owner,
 });

 Map<String, dynamic> toMap() => {
 'id': id, 'tool': tool, 'category': category, 'license': license,
 'assignedUsers': assignedUsers, 'status': status, 'expiry': expiry, 'owner': owner,
 };

 static List<_DevToolItem> fromList(dynamic data) {
 if (data is! List) return [];
 return data.map((e) {
 final m = e as Map<String, dynamic>;
 return _DevToolItem(
 id: m['id'] ?? '', tool: m['tool'] ?? '', category: m['category'] ?? '',
 license: m['license'] ?? '', assignedUsers: m['assignedUsers'] ?? '',
 status: m['status'] ?? '', expiry: m['expiry'] ?? '', owner: m['owner'] ?? '',
 );
 }).toList();
 }
}

class _QualityGateItem {
 final String id;
 final String gate;
 final String criteria;
 final String methodology;
 final String status;
 final String approver;
 final String targetDate;

 const _QualityGateItem({
 required this.id,
 required this.gate,
 required this.criteria,
 required this.methodology,
 required this.status,
 required this.approver,
 required this.targetDate,
 });

 Map<String, dynamic> toMap() => {
 'id': id, 'gate': gate, 'criteria': criteria, 'methodology': methodology,
 'status': status, 'approver': approver, 'targetDate': targetDate,
 };

 static List<_QualityGateItem> fromList(dynamic data) {
 if (data is! List) return [];
 return data.map((e) {
 final m = e as Map<String, dynamic>;
 return _QualityGateItem(
 id: m['id'] ?? '', gate: m['gate'] ?? '', criteria: m['criteria'] ?? '',
 methodology: m['methodology'] ?? '', status: m['status'] ?? '',
 approver: m['approver'] ?? '', targetDate: m['targetDate'] ?? '',
 );
 }).toList();
 }
}

class _SecurityBaselineItem {
 final String id;
 final String control;
 final String framework;
 final String status;
 final String evidence;
 final String owner;
 final String reviewDate;

 const _SecurityBaselineItem({
 required this.id,
 required this.control,
 required this.framework,
 required this.status,
 required this.evidence,
 required this.owner,
 required this.reviewDate,
 });

 Map<String, dynamic> toMap() => {
 'id': id, 'control': control, 'framework': framework, 'status': status,
 'evidence': evidence, 'owner': owner, 'reviewDate': reviewDate,
 };

 static List<_SecurityBaselineItem> fromList(dynamic data) {
 if (data is! List) return [];
 return data.map((e) {
 final m = e as Map<String, dynamic>;
 return _SecurityBaselineItem(
 id: m['id'] ?? '', control: m['control'] ?? '', framework: m['framework'] ?? '',
 status: m['status'] ?? '', evidence: m['evidence'] ?? '',
 owner: m['owner'] ?? '', reviewDate: m['reviewDate'] ?? '',
 );
 }).toList();
 }
}

class _ApprovalGateItem {
 final String id;
 final String gate;
 final String description;
 final String status;
 final String approver;
 final String targetDate;

 const _ApprovalGateItem({
 required this.id,
 required this.gate,
 required this.description,
 required this.status,
 required this.approver,
 required this.targetDate,
 });

 Map<String, dynamic> toMap() => {
 'id': id, 'gate': gate, 'description': description, 'status': status,
 'approver': approver, 'targetDate': targetDate,
 };

 static List<_ApprovalGateItem> fromList(dynamic data) {
 if (data is! List) return [];
 return data.map((e) {
 final m = e as Map<String, dynamic>;
 return _ApprovalGateItem(
 id: m['id'] ?? '', gate: m['gate'] ?? '', description: m['description'] ?? '',
 status: m['status'] ?? '', approver: m['approver'] ?? '', targetDate: m['targetDate'] ?? '',
 );
 }).toList();
 }
}

// ════════════════════════════════════════════════════════════════════════════
// DEBOUNCER
// ════════════════════════════════════════════════════════════════════════════

class _Debouncer {
 Timer? _timer;
 void run(VoidCallback action) {
 _timer?.cancel();
 _timer = Timer(const Duration(milliseconds: 600), action);
 }

 void dispose() {
 _timer?.cancel();
 }
}
