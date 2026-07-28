import 'package:flutter/material.dart';
import 'package:ndu_project/screens/identify_staff_ops_team_screen.dart';
import 'package:ndu_project/screens/punchlist_actions_screen.dart';
import 'package:ndu_project/widgets/kaz_ai_chat_bubble.dart';
import 'package:ndu_project/widgets/launch_phase_navigation.dart';
import 'package:ndu_project/widgets/responsive_scaffold.dart';
import 'package:ndu_project/widgets/responsive.dart';
import 'package:ndu_project/utils/project_data_helper.dart';
import 'package:ndu_project/utils/execution_phase_ai_seed.dart';
import 'package:ndu_project/services/openai_service_secure.dart';
import 'package:ndu_project/models/project_data_model.dart';
import 'package:ndu_project/widgets/launch_editable_section.dart';
import 'package:ndu_project/widgets/delete_confirmation_dialog.dart';
import 'package:ndu_project/widgets/planning_phase_header.dart';

import 'package:ndu_project/widgets/voice_text_field.dart';
import 'package:ndu_project/utils/pdf_export_helper.dart';
class TechnicalDebtManagementScreen extends StatefulWidget {
 const TechnicalDebtManagementScreen({super.key});

 static void open(BuildContext context) {
 Navigator.of(context).push(
 MaterialPageRoute(builder: (_) => const TechnicalDebtManagementScreen()),
 );
 }

 @override
 State<TechnicalDebtManagementScreen> createState() =>
 _TechnicalDebtManagementScreenState();
}

class _TechnicalDebtManagementScreenState
 extends State<TechnicalDebtManagementScreen> {
 static const List<_GovernanceColorOption> _governanceColorOptions = [
 _GovernanceColorOption('Critical red', 0xFFEF4444),
 _GovernanceColorOption('High amber', 0xFFF97316),
 _GovernanceColorOption('Control blue', 0xFF0EA5E9),
 _GovernanceColorOption('Governance indigo', 0xFF6366F1),
 _GovernanceColorOption('On-track green', 0xFF10B981),
 ];

 // Local copies updated from provider
 List<DebtItem> _debtItems = [];
 List<DebtInsight> _rootCauses = [];
 List<RemediationTrack> _tracks = [];
 List<OwnerItem> _owners = [];

 final _ai = OpenAiServiceSecure();
 bool _autoGenerationTriggered = false;
 bool _isAutoGenerating = false;

 @override
 void initState() {
 super.initState();
 WidgetsBinding.instance.addPostFrameCallback((_) {
 _autoPopulateIfNeeded();
 });
 }

 @override
 Widget build(BuildContext context) {
 final data = ProjectDataHelper.getData(context).frontEndPlanning;
 // sync local view lists from persisted project data
 _debtItems = data.technicalDebtItems;
 _rootCauses = data.technicalDebtRootCauses;
 _tracks = data.technicalDebtTracks;
 _owners = data.technicalDebtOwners;
 final isNarrow = MediaQuery.sizeOf(context).width < 980;
 final padding = AppBreakpoints.pagePadding(context);

 return ResponsiveScaffold(
 activeItemLabel: 'Technical Debt Management',
 backgroundColor: Colors.white,
 floatingActionButton: const KazAiChatBubble(positioned: false),
 body: SingleChildScrollView(
 padding: EdgeInsets.all(padding),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 PlanningPhaseHeader(
 title: 'Technical Debt Management',
showNavigationButtons: false, onExportPdf: _exportPdf),
 const SizedBox(height: 16),
 _buildHeader(isNarrow),
 const SizedBox(height: 16),
 _buildStatsRow(isNarrow),
 const SizedBox(height: 24),
 Column(
 crossAxisAlignment: CrossAxisAlignment.stretch,
 children: [
 _buildDebtRegister(),
 const SizedBox(height: 20),
 _buildRemediationPanel(),
 const SizedBox(height: 20),
 _buildRootCausePanel(),
 const SizedBox(height: 20),
 _buildOwnershipPanel(),
 const SizedBox(height: 24),
 LaunchPhaseNavigation(
 backLabel: 'Back: Punchlist Actions',
 nextLabel: 'Next: Identify & Staff Ops Team',
 onBack: () => PunchlistActionsScreen.open(context),
 onNext: () => IdentifyStaffOpsTeamScreen.open(context),
 ),
 ],
 ),
 ],
 ),
 ),
 );
 }

 Widget _buildHeader(bool isNarrow) {
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
 'EXECUTION HEALTH',
 style: TextStyle(
 fontSize: 11, fontWeight: FontWeight.w700, color: Colors.black),
 ),
 ),
 const SizedBox(height: 10),
 Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: const [
 Text(
 'Technical Debt Management',
 style: TextStyle(
 fontSize: 24,
 fontWeight: FontWeight.w700,
 color: Color(0xFF111827)),
 ),
 SizedBox(height: 6),
 Text(
 'Track residual debt, prioritize remediation, and align owners before project close-out.',
 style: TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
 ),
 ],
 ),
 ),
 if (!isNarrow) const SizedBox.shrink(),
 ],
 ),
 if (isNarrow) ...[
 const SizedBox(height: 12),
 ],
 ],
 );
 }

 Widget _buildHeaderActions() {
 return Wrap(
 spacing: 10,
 runSpacing: 10,
 children: [
 _actionButton(Icons.add, 'Add debt item',
 onPressed: _showAddDebtItemDialog),
 _actionButton(Icons.tune, 'Prioritize backlog', onPressed: () {
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(
 content: Text(
 'Use severity, status, and target fields to prioritize the backlog.')),
 );
 }),
 _actionButton(Icons.description_outlined, 'Generate report',
 onPressed: _showDebtSnapshotReport),
 _primaryButton('Launch remediation sprint'),
 ],
 );
 }

 Widget _actionButton(IconData icon, String label, {VoidCallback? onPressed}) {
 return OutlinedButton.icon(
 onPressed: onPressed ?? () {},
 icon: Icon(icon, size: 18, color: const Color(0xFF64748B)),
 label: Text(label,
 style: const TextStyle(
 fontSize: 12,
 fontWeight: FontWeight.w600,
 color: Color(0xFF64748B))),
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
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(
 content: Text(
 'Remediation sprint launched. Keep debt status and targets updated to track closure velocity.'),
 ),
 );
 },
 icon: const Icon(Icons.play_arrow, size: 18),
 label: Text(label,
 style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
 style: ElevatedButton.styleFrom(
 backgroundColor: const Color(0xFF0EA5E9),
 foregroundColor: Colors.white,
 padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
 ),
 );
 }

 Widget _buildStatsRow(bool isNarrow) {
 final stats = [
 _StatCardData(
 'Open debt items', '18', '6 critical', const Color(0xFFEF4444)),
 _StatCardData(
 'In remediation', '7', '2 sprint owners', const Color(0xFF0EA5E9)),
 _StatCardData(
 'Monthly burn-down', '14%', 'Goal 20%', const Color(0xFF10B981)),
 _StatCardData('Owner coverage', '92%', '2 gaps', const Color(0xFF6366F1)),
 ];

 if (isNarrow) {
 return Wrap(
 spacing: 12,
 runSpacing: 12,
 children: stats.map((stat) => _buildStatCard(stat)).toList(),
 );
 }

 return Row(
 children: stats
 .map((stat) => Expanded(
 child: Padding(
 padding: const EdgeInsets.only(right: 12),
 child: _buildStatCard(stat),
 ),
 ))
 .toList(),
 );
 }

 Widget _buildStatCard(_StatCardData data) {
 return Container(
 padding: const EdgeInsets.all(16),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(16),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(data.value,
 style: TextStyle(
 fontSize: 20,
 fontWeight: FontWeight.w700,
 color: data.color)),
 const SizedBox(height: 6),
 Text(data.label,
 style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
 const SizedBox(height: 6),
 Text(data.supporting,
 style: TextStyle(
 fontSize: 12,
 fontWeight: FontWeight.w600,
 color: data.color)),
 ],
 ),
 );
 }

 Widget _buildDebtRegister() {
 return _PanelShell(
 title: 'Debt register',
 subtitle: 'Track high-impact debt items and remediation targets',
 trailing: Row(children: [
 _actionButton(Icons.filter_list, 'Filter', onPressed: () {
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(
 content: Text('Use the chips above to filter the register.')),
 );
 }),
 const SizedBox(width: 8),
 OutlinedButton.icon(
 onPressed: () async {
 try {
 final ctx = ProjectDataHelper.buildExecutivePlanContext(
 ProjectDataHelper.getData(context),
 sectionLabel: 'Technical Debt Management',
 );
 final text = await _ai.generateFepSectionText(
 section: 'Technical Debt',
 context: ctx,
 maxTokens: 700,
 );
 if (!mounted) return;
 final lines = text
 .split(RegExp(r'[\n\r]+'))
 .map((s) => s.replaceAll('*', '').trim())
 .where((s) => s.isNotEmpty)
 .toList();
 if (lines.isEmpty) return;

 final now = DateTime.now().millisecondsSinceEpoch;
 final newItems =
 lines.take(6).toList().asMap().entries.map((entry) {
 final line = entry.value;
 return DebtItem(
 id: 'TD-${now + entry.key}',
 title: line,
 area: 'Architecture',
 owner: '',
 severity: 'Medium',
 status: 'Backlog',
 target: '',
 );
 }).toList();

 await _upsertDebtItems([..._debtItems, ...newItems]);
 if (!mounted) return;
 setState(() => _debtItems = [..._debtItems, ...newItems]);
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(
 content: Text('Added ${newItems.length} AI debt items.')),
 );
 } catch (e) {
 if (!mounted) return;
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(content: Text('AI auto-populate failed: $e')),
 );
 }
 },
 icon: const Icon(Icons.auto_fix_high, size: 16),
 label: const Text('Auto-populate (AI)'),
 ),
 ]),
 child: LayoutBuilder(
 builder: (context, constraints) {
 final availableWidth = constraints.maxWidth;
 final isNarrow = availableWidth < 800;

 return Column(
 crossAxisAlignment: CrossAxisAlignment.stretch,
 children: [
 // Header row
 Container(
 padding: EdgeInsets.all(isNarrow ? 10 : 12),
 decoration: const BoxDecoration(
 color: Color(0xFFF8FAFC),
 border: Border(
 bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1),
 ),
 ),
 child: Row(
 children: [
 _tableHeaderCell('ID', flex: isNarrow ? 0.6 : 0.5),
 _tableHeaderCell('Item', flex: 2.0),
 _tableHeaderCell('Area', flex: 1.0),
 _tableHeaderCell('Owner', flex: 1.2),
 _tableHeaderCell('Severity', flex: 1.0),
 _tableHeaderCell('Status', flex: 1.1),
 _tableHeaderCell('Target', flex: 1.0),
 _tableHeaderCell('Actions', flex: 0.8),
 ],
 ),
 ),
 // Data rows
 if (_debtItems.isEmpty)
 Container(
 padding: const EdgeInsets.all(24),
 child: const Text(
 'No debt items yet. Use + Add debt item to get started.',
 style: TextStyle(
 color: Color(0xFF64748B),
 fontStyle: FontStyle.italic,
 ),
 ),
 )
 else
 ..._debtItems.asMap().entries.map((entry) {
 final index = entry.key;
 final item = entry.value;
 return Container(
 padding: EdgeInsets.all(isNarrow ? 10 : 12),
 decoration: BoxDecoration(
 color: index % 2 == 0
 ? Colors.white
 : const Color(0xFFFAFAFA),
 border: const Border(
 bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1),
 ),
 ),
 child: Row(
 children: [
 _tableCell(item.id,
 flex: isNarrow ? 0.6 : 0.5,
 textStyle: const TextStyle(
 fontSize: 12, color: Color(0xFF0EA5E9))),
 _tableCell(item.title,
 flex: 2.0,
 textStyle: const TextStyle(fontSize: 13)),
 _tableCell(item.area, flex: 1.0, isChip: true),
 _tableCell(item.owner,
 flex: 1.2,
 textStyle: const TextStyle(
 fontSize: 13, color: Color(0xFF64748B))),
 _tableCell(item.severity,
 flex: 1.0, isSeverityChip: true),
 _tableCell(item.status, flex: 1.1, isStatusChip: true),
 _tableCell(item.target,
 flex: 1.0,
 textStyle: const TextStyle(fontSize: 12)),
 _actionsCell(
 flex: 0.8,
 onEdit: () => _showEditDebtItemDialog(item),
 onDelete: () => _deleteDebtItem(item),
 ),
 ],
 ),
 );
 }),
 ],
 );
 },
 ),
 );
 }

 Widget _buildRemediationPanel() {
 final rows = _remediationTableRows();
 return _PanelShell(
 title: 'Remediation runway',
 subtitle: 'Risk-ranked closure plan with acceptance evidence',
 trailing: _tableToolbar(
 chipLabel: 'Weekly cadence',
 buttonLabel: 'Add lane',
 onAdd: _showAddRemediationTrackDialog,
 ),
 child: _GovernanceTable(
 columns: const [
 _GovernanceColumn('Priority lane', 1.35),
 _GovernanceColumn('Exit criteria / closure standard', 2.3),
 _GovernanceColumn('Verification evidence', 2.1),
 _GovernanceColumn('Accountability / cadence', 1.55),
 _GovernanceColumn('Progress', 1.0),
 _GovernanceColumn('Actions', 0.7),
 ],
 rows: rows.asMap().entries.map(
 (entry) {
 final index = entry.key;
 final row = entry.value;
 return [
 _PriorityCell(
 title: row.primary,
 supporting: row.secondary,
 color: row.color,
 ),
 _BodyCell(row.exitCriteria),
 _BodyCell(row.evidence),
 _BodyCell(row.ownerCadence),
 _ProgressCell(value: row.progress, color: row.color),
 _RowActionsCell(
 onEdit: () => _showEditRemediationTrackDialog(index, row),
 onDelete: () => _deleteRemediationTrack(index, row.primary),
 ),
 ];
 },
 ).toList(),
 ),
 );
 }

 Widget _buildRootCausePanel() {
 final rows = _rootCauseTableRows();
 return _PanelShell(
 title: 'Root cause signals',
 subtitle: 'Leading indicators mapped to controls and verification',
 trailing: _tableToolbar(
 buttonLabel: 'Add signal',
 onAdd: _showAddRootCauseDialog,
 ),
 child: _GovernanceTable(
 columns: const [
 _GovernanceColumn('Signal cluster', 1.35),
 _GovernanceColumn('Diagnostic interpretation', 1.9),
 _GovernanceColumn('Detection evidence', 1.8),
 _GovernanceColumn('Control action', 1.85),
 _GovernanceColumn('Risk tier', 0.85),
 _GovernanceColumn('Actions', 0.7),
 ],
 rows: rows.asMap().entries.map(
 (entry) {
 final index = entry.key;
 final row = entry.value;
 return [
 _PriorityCell(
 title: row.signal,
 supporting: row.source,
 color: row.color,
 ),
 _BodyCell(row.indicator),
 _BodyCell(row.evidence),
 _BodyCell(row.control),
 _RiskTierCell(label: row.tier, color: row.color),
 _RowActionsCell(
 onEdit: () => _showEditRootCauseDialog(index, row),
 onDelete: () => _deleteRootCause(index, row.signal),
 ),
 ];
 },
 ).toList(),
 ),
 );
 }

 Widget _buildOwnershipPanel() {
 final rows = _ownershipTableRows();
 return _PanelShell(
 title: 'Ownership coverage',
 subtitle: 'RACI coverage, review checkpoints, and escalation triggers',
 trailing: _tableToolbar(
 chipLabel: 'Next review: Oct 14',
 buttonLabel: 'Add owner',
 onAdd: _showAddOwnerDialog,
 ),
 child: _GovernanceTable(
 columns: const [
 _GovernanceColumn('Workstream', 1.35),
 _GovernanceColumn('Accountable owner', 1.4),
 _GovernanceColumn('Coverage standard', 1.9),
 _GovernanceColumn('Review checkpoint', 1.55),
 _GovernanceColumn('Escalation trigger', 1.8),
 _GovernanceColumn('Actions', 0.7),
 ],
 rows: rows.asMap().entries.map(
 (entry) {
 final index = entry.key;
 final row = entry.value;
 return [
 _PriorityCell(
 title: row.workstream,
 supporting: row.scope,
 color: row.color,
 ),
 _OwnerCoverageCell(owner: row.owner, count: row.count),
 _BodyCell(row.coverage),
 _BodyCell(row.review),
 _BodyCell(row.escalation),
 _RowActionsCell(
 onEdit: () => _showEditOwnerDialog(index, row),
 onDelete: () => _deleteOwner(index, row.owner),
 ),
 ];
 },
 ).toList(),
 ),
 );
 }

 bool _isPlaceholderText(String value) {
 final normalized = value.trim().toLowerCase();
 return normalized.isEmpty ||
 normalized == 'launch action item' ||
 normalized.startsWith('add details for');
 }

 List<_RemediationRunwayRow> _remediationTableRows() {
 final usableTracks =
 _tracks.where((track) => !_isPlaceholderText(track.label)).toList();
 if (usableTracks.isNotEmpty) {
 return usableTracks.map((track) {
 final lane = track.exitCriteria.isNotEmpty && track.evidence.isNotEmpty
 ? null
 : _classifyLane(track.label);
 return _RemediationRunwayRow(
 primary: track.label,
 secondary: track.secondary.isNotEmpty
 ? track.secondary
 : (lane?.secondary ?? ''),
 exitCriteria: track.exitCriteria.isNotEmpty
 ? track.exitCriteria
 : (lane?.exitCriteria ?? ''),
 evidence: track.evidence.isNotEmpty
 ? track.evidence
 : (lane?.evidence ?? ''),
 ownerCadence: track.ownerCadence.isNotEmpty
 ? track.ownerCadence
 : (lane?.ownerCadence ?? ''),
 progress: track.progress.clamp(0.0, 1.0),
 color: Color(track.colorValue),
 );
 }).toList();
 }

 return const [
 _RemediationRunwayRow(
 primary: 'P0 risk containment',
 secondary: 'Reliability, security, and production-impacting defects',
 exitCriteria:
 'Critical findings resolved, compensating controls approved, and no unresolved launch blockers remain.',
 evidence:
 'Static analysis criticals, penetration-test actions, Sev 1/2 defect trend, rollback test results.',
 ownerCadence: 'Engineering Lead + Security Lead; daily until green',
 progress: 0.58,
 color: Color(0xFFEF4444),
 ),
 _RemediationRunwayRow(
 primary: 'P1 operability hardening',
 secondary: 'Monitoring, runbooks, support readiness, and recovery',
 exitCriteria:
 'SLO dashboards, alerts, runbooks, backup/restore, and incident handoff are validated by Ops.',
 evidence:
 'Readiness review minutes, alert test logs, DR rehearsal result, support acceptance sign-off.',
 ownerCadence: 'Ops Lead + Platform Lead; twice weekly',
 progress: 0.46,
 color: Color(0xFF0EA5E9),
 ),
 _RemediationRunwayRow(
 primary: 'P2 maintainability refactor',
 secondary: 'Complexity, coupling, duplication, and fragile modules',
 exitCriteria:
 'Hotspots meet agreed complexity thresholds and refactors are covered by automated regression tests.',
 evidence:
 'Complexity scan, code review approvals, regression pass rate, module ownership records.',
 ownerCadence: 'Tech Lead; weekly sprint review',
 progress: 0.34,
 color: Color(0xFF6366F1),
 ),
 _RemediationRunwayRow(
 primary: 'P3 backlog governance',
 secondary: 'Deferred debt, waivers, and lifecycle risk decisions',
 exitCriteria:
 'Every deferred item has business rationale, expiry date, owner, cost-of-delay, and review trigger.',
 evidence:
 'Debt register, risk acceptance log, roadmap link, quarterly architecture review outcome.',
 ownerCadence: 'Product Owner + Architecture Review Board; monthly',
 progress: 0.72,
 color: Color(0xFF10B981),
 ),
 ];
 }

 List<_RootCauseSignalRow> _rootCauseTableRows() {
 final usableSignals =
 _rootCauses.where((item) => !_isPlaceholderText(item.title)).toList();
 if (usableSignals.isNotEmpty) {
 return usableSignals.map((item) {
 final profile = item.evidence.isNotEmpty && item.control.isNotEmpty
 ? null
 : _classifyRootCause(item.title, item.subtitle);
 return _RootCauseSignalRow(
 signal: item.title,
 source: profile?.source ?? 'Custom signal',
 indicator: item.subtitle.trim().isNotEmpty
 ? item.subtitle
 : (profile?.indicator ?? ''),
 evidence: item.evidence.isNotEmpty
 ? item.evidence
 : (profile?.evidence ?? ''),
 control:
 item.control.isNotEmpty ? item.control : (profile?.control ?? ''),
 tier: item.tier.isNotEmpty ? item.tier : (profile?.tier ?? 'Medium'),
 color: Color(item.colorValue),
 );
 }).toList();
 }

 return const [
 _RootCauseSignalRow(
 signal: 'Test automation gaps',
 source: 'Quality engineering',
 indicator:
 'Manual regression, low branch coverage, or unstable test environments are allowing rework to accumulate.',
 evidence:
 'Coverage trend, flaky-test rate, escaped defects, failed release-candidate cycles.',
 control:
 'Protect critical paths with automated regression, CI quality gates, and definition-of-done checks.',
 tier: 'High',
 color: Color(0xFFF97316),
 ),
 _RootCauseSignalRow(
 signal: 'Architecture coupling',
 source: 'Architecture review',
 indicator:
 'Simple changes require broad coordination because boundaries, interfaces, or ownership are unclear.',
 evidence:
 'Change lead time, dependency graph hotspots, cyclic imports, review comments on hidden coupling.',
 control:
 'Define service boundaries, retire duplicated logic, and assign module stewards for high-change areas.',
 tier: 'High',
 color: Color(0xFFEF4444),
 ),
 _RootCauseSignalRow(
 signal: 'Deferred non-functional work',
 source: 'Product and delivery governance',
 indicator:
 'Security, performance, accessibility, or operability requirements were accepted late or waived.',
 evidence:
 'Waiver log, NFR traceability gaps, performance baseline misses, late-stage hardening tasks.',
 control:
 'Add NFR acceptance criteria to backlog items and require time-boxed remediation plans for waivers.',
 tier: 'Medium',
 color: Color(0xFF6366F1),
 ),
 _RootCauseSignalRow(
 signal: 'Dependency aging',
 source: 'Platform and security tooling',
 indicator:
 'Unsupported packages, stale SDKs, or unpatched vulnerabilities are increasing maintenance risk.',
 evidence:
 'SBOM age, vulnerability scan, end-of-support dates, upgrade failure notes.',
 control:
 'Create an upgrade lane with tested compatibility windows and release-owner approval.',
 tier: 'Medium',
 color: Color(0xFF0EA5E9),
 ),
 ];
 }

 List<_OwnershipCoverageRow> _ownershipTableRows() {
 final usableOwners =
 _owners.where((owner) => !_isPlaceholderText(owner.name)).toList();
 if (usableOwners.isNotEmpty) {
 return usableOwners.map((owner) {
 final profile = owner.coverage.isNotEmpty && owner.escalation.isNotEmpty
 ? null
 : _classifyOwner(owner.name, owner.note);
 return _OwnershipCoverageRow(
 workstream: owner.workstream.isNotEmpty
 ? owner.workstream
 : (profile?.workstream ?? ''),
 scope: owner.scope.isNotEmpty ? owner.scope : (profile?.scope ?? ''),
 owner: owner.name,
 count: owner.count.trim().isNotEmpty ? owner.count : '1',
 coverage: owner.coverage.isNotEmpty
 ? owner.coverage
 : (profile?.coverage ?? ''),
 review: owner.note.trim().isNotEmpty
 ? owner.note
 : (profile?.review ?? ''),
 escalation: owner.escalation.isNotEmpty
 ? owner.escalation
 : (profile?.escalation ?? ''),
 color: profile?.color ?? const Color(0xFF0EA5E9),
 );
 }).toList();
 }

 return const [
 _OwnershipCoverageRow(
 workstream: 'Engineering remediation',
 scope: 'Code quality, refactoring, defect closure',
 owner: 'Engineering Lead',
 count: '1',
 coverage:
 'One directly accountable lead, named module stewards, peer-review approvers, and release acceptance owner.',
 review: 'Sprint review plus weekly debt burndown checkpoint',
 escalation:
 'Critical item blocked longer than five business days or target release moves.',
 color: Color(0xFF0EA5E9),
 ),
 _OwnershipCoverageRow(
 workstream: 'Security and compliance',
 scope: 'Vulnerabilities, access controls, audit evidence',
 owner: 'Security Lead',
 count: '1',
 coverage:
 'Risk acceptance cannot close without security sign-off and evidence attached to the debt record.',
 review: 'Weekly risk review until all critical/high findings close',
 escalation:
 'Unpatched critical vulnerability, expired waiver, or missing compensating control.',
 color: Color(0xFFEF4444),
 ),
 _OwnershipCoverageRow(
 workstream: 'Operations readiness',
 scope: 'Monitoring, runbooks, support model, recovery',
 owner: 'Operations Lead',
 count: '1',
 coverage:
 'Ops owns support acceptance, incident playbooks, alert tests, restore evidence, and handover completion.',
 review: 'Launch readiness review and post-launch hypercare review',
 escalation:
 'SLO, alerting, backup, or runbook evidence missing before launch approval.',
 color: Color(0xFF10B981),
 ),
 _OwnershipCoverageRow(
 workstream: 'Product governance',
 scope: 'Trade-offs, waivers, roadmap funding, cost-of-delay',
 owner: 'Product Owner',
 count: '1',
 coverage:
 'Every deferred item has business rationale, funded follow-up, expiry date, and architecture review link.',
 review: 'Monthly portfolio governance checkpoint',
 escalation:
 'Deferred risk has no funded remediation path or exceeds approved waiver date.',
 color: Color(0xFF6366F1),
 ),
 ];
 }

 _LaneProfile _classifyLane(String text) {
 final value = text.toLowerCase();
 if (value.contains('security') ||
 value.contains('critical') ||
 value.contains('risk') ||
 value.contains('reliability')) {
 return const _LaneProfile(
 secondary: 'Reliability, security, and production-impacting defects',
 exitCriteria:
 'Critical findings resolved, accepted with controls, or removed from release scope.',
 evidence:
 'Security scan, incident trend, defect aging, release-blocker register.',
 ownerCadence: 'Engineering Lead + Security Lead; daily until green',
 );
 }
 if (value.contains('ops') ||
 value.contains('operat') ||
 value.contains('runbook') ||
 value.contains('support')) {
 return const _LaneProfile(
 secondary: 'Monitoring, runbooks, support readiness, and recovery',
 exitCriteria:
 'Operational acceptance evidence is complete and support handoff is approved.',
 evidence:
 'Alert tests, runbook review, restore evidence, SLO dashboard.',
 ownerCadence: 'Ops Lead + Platform Lead; twice weekly',
 );
 }
 if (value.contains('refactor') ||
 value.contains('maintain') ||
 value.contains('architecture')) {
 return const _LaneProfile(
 secondary: 'Complexity, coupling, duplication, and fragile modules',
 exitCriteria:
 'Hotspots meet agreed complexity thresholds and regression coverage is in place.',
 evidence: 'Complexity scan, code review, regression results.',
 ownerCadence: 'Tech Lead; weekly sprint review',
 );
 }
 return const _LaneProfile(
 secondary: 'Deferred debt, waivers, and lifecycle risk decisions',
 exitCriteria:
 'Every deferred item has owner, expiry, rationale, and funded review path.',
 evidence: 'Debt register, waiver log, roadmap link, review minutes.',
 ownerCadence: 'Product Owner + Architecture Review Board; monthly',
 );
 }

 _RootCauseProfile _classifyRootCause(String title, String subtitle) {
 final value = '$title $subtitle'.toLowerCase();
 if (value.contains('test') || value.contains('quality')) {
 return const _RootCauseProfile(
 source: 'Quality engineering',
 indicator:
 'Regression safety net is insufficient for the pace of change.',
 evidence: 'Coverage trend, flaky-test rate, escaped defects.',
 control: 'Add automated regression gates to critical workflows.',
 tier: 'High',
 color: Color(0xFFF97316),
 );
 }
 if (value.contains('security') || value.contains('compliance')) {
 return const _RootCauseProfile(
 source: 'Security review',
 indicator: 'Control requirements are being discovered too late.',
 evidence: 'Vulnerability scan, waiver log, access-review exceptions.',
 control: 'Shift security criteria into backlog acceptance checks.',
 tier: 'High',
 color: Color(0xFFEF4444),
 );
 }
 if (value.contains('dependency') || value.contains('upgrade')) {
 return const _RootCauseProfile(
 source: 'Platform tooling',
 indicator: 'Aging components are increasing support and patch risk.',
 evidence: 'SBOM age, end-of-support dates, vulnerability scan.',
 control: 'Create a tested upgrade lane with release-owner approval.',
 tier: 'Medium',
 color: Color(0xFF0EA5E9),
 );
 }
 return const _RootCauseProfile(
 source: 'Architecture review',
 indicator:
 'Design trade-offs or unclear boundaries are increasing change cost.',
 evidence: 'Complexity hotspots, change lead time, review comments.',
 control: 'Assign module stewards and reduce coupling in priority areas.',
 tier: 'Medium',
 color: Color(0xFF6366F1),
 );
 }

 _OwnerProfile _classifyOwner(String name, String note) {
 final value = '$name $note'.toLowerCase();
 if (value.contains('security') || value.contains('compliance')) {
 return const _OwnerProfile(
 workstream: 'Security and compliance',
 scope: 'Vulnerabilities, access controls, audit evidence',
 coverage: 'Security sign-off required for closure and risk acceptance.',
 review: 'Weekly risk review',
 escalation: 'Critical vulnerability or expired waiver remains open.',
 color: Color(0xFFEF4444),
 );
 }
 if (value.contains('ops') ||
 value.contains('operation') ||
 value.contains('support')) {
 return const _OwnerProfile(
 workstream: 'Operations readiness',
 scope: 'Monitoring, runbooks, support model, recovery',
 coverage: 'Ops acceptance required for runbooks, alerts, and handover.',
 review: 'Launch readiness and hypercare review',
 escalation: 'Operational evidence missing before launch approval.',
 color: Color(0xFF10B981),
 );
 }
 if (value.contains('product') || value.contains('business')) {
 return const _OwnerProfile(
 workstream: 'Product governance',
 scope: 'Trade-offs, waivers, roadmap funding',
 coverage: 'Business rationale and funded follow-up required.',
 review: 'Monthly portfolio checkpoint',
 escalation: 'Deferred risk lacks a funded remediation path.',
 color: Color(0xFF6366F1),
 );
 }
 return const _OwnerProfile(
 workstream: 'Engineering remediation',
 scope: 'Code quality, refactoring, defect closure',
 coverage:
 'Named lead, module stewards, review approvers, and release owner.',
 review: 'Sprint review plus weekly debt burndown',
 escalation: 'Critical item blocked longer than five business days.',
 color: Color(0xFF0EA5E9),
 );
 }

 Future<void> _autoPopulateIfNeeded() async {
 if (_autoGenerationTriggered || _isAutoGenerating) return;
 _autoGenerationTriggered = true;
 final fep = ProjectDataHelper.getData(context).frontEndPlanning;
 if (fep.technicalDebtItems.isNotEmpty ||
 fep.technicalDebtRootCauses.isNotEmpty ||
 fep.technicalDebtTracks.isNotEmpty ||
 fep.technicalDebtOwners.isNotEmpty) {
 return;
 }

 setState(() => _isAutoGenerating = true);
 Map<String, List<LaunchEntry>> generated = {};
 try {
 generated = await ExecutionPhaseAiSeed.generateEntries(
 context: context,
 section: 'Technical Debt Management',
 sections: const {
 'debt_items': 'Technical debt items with owner, severity, status',
 'root_causes': 'Root cause themes driving technical debt',
 'remediation_tracks': 'Remediation tracks with progress',
 'owners': 'Owner coverage and next review notes',
 },
 itemsPerSection: 4,
 );
 } catch (error) {
 debugPrint('Technical debt AI call failed: $error');
 }

 if (!mounted) return;
 final debtItems = _mapDebtItems(generated['debt_items']);
 final rootCauses = _mapRootCauses(generated['root_causes']);
 final tracks = _mapRemediationTracks(generated['remediation_tracks']);
 final owners = _mapOwners(generated['owners']);

 await _upsertTechnicalDebtData(
 items: debtItems.isNotEmpty ? debtItems : _debtItems,
 rootCauses: rootCauses.isNotEmpty ? rootCauses : _rootCauses,
 tracks: tracks.isNotEmpty ? tracks : _tracks,
 owners: owners.isNotEmpty ? owners : _owners,
 );

 if (!mounted) return;
 setState(() {
 if (debtItems.isNotEmpty) _debtItems = debtItems;
 if (rootCauses.isNotEmpty) _rootCauses = rootCauses;
 if (tracks.isNotEmpty) _tracks = tracks;
 if (owners.isNotEmpty) _owners = owners;
 _isAutoGenerating = false;
 });
 }

 String _extractField(String text, String key) {
 final match = RegExp('$key\\s*[:=-]\\s*([^|;\\n]+)', caseSensitive: false)
 .firstMatch(text);
 return match?.group(1)?.trim() ?? '';
 }

 double _parsePercent(String text) {
 final match = RegExp(r'(\\d{1,3})').firstMatch(text);
 final value = match != null ? int.tryParse(match.group(1) ?? '') : null;
 if (value == null) return 0.4;
 return (value.clamp(10, 95) / 100);
 }

 List<DebtItem> _mapDebtItems(List<LaunchEntry>? entries) {
 if (entries == null) return [];
 return entries
 .map((entry) {
 final details = entry.details;
 final owner = _extractField(details, 'Owner');
 final area = _extractField(details, 'Area');
 final severity = _extractField(details, 'Severity');
 final status = entry.status?.trim().isNotEmpty == true
 ? entry.status!.trim()
 : _extractField(details, 'Status');
 final target = _extractField(details, 'Target');
 return DebtItem(
 id: 'TD-${DateTime.now().millisecondsSinceEpoch}',
 title: entry.title.trim(),
 area: area.isNotEmpty ? area : 'Architecture',
 owner: owner,
 severity: severity.isNotEmpty ? severity : 'Medium',
 status: status.isNotEmpty ? status : 'Backlog',
 target: target,
 );
 })
 .where((item) => item.title.isNotEmpty)
 .toList();
 }

 List<DebtInsight> _mapRootCauses(List<LaunchEntry>? entries) {
 if (entries == null) return [];
 return entries
 .map((entry) => DebtInsight(
 title: entry.title.trim(),
 subtitle: entry.details.trim().isNotEmpty
 ? entry.details.trim()
 : 'Capture mitigation actions.',
 ))
 .where((item) => item.title.isNotEmpty)
 .toList();
 }

 List<RemediationTrack> _mapRemediationTracks(List<LaunchEntry>? entries) {
 if (entries == null) return [];
 return entries
 .map((entry) => RemediationTrack(
 label: entry.title.trim(),
 progress: _parsePercent('${entry.details} ${entry.status ?? ''}'),
 colorValue: const Color(0xFF0EA5E9).toARGB32(),
 ))
 .where((item) => item.label.isNotEmpty)
 .toList();
 }

 List<OwnerItem> _mapOwners(List<LaunchEntry>? entries) {
 if (entries == null) return [];
 return entries
 .map((entry) {
 final count = _extractField(entry.details, 'Count');
 return OwnerItem(
 name: entry.title.trim(),
 count: count.isNotEmpty ? count : '1',
 note: entry.details.trim(),
 );
 })
 .where((item) => item.name.isNotEmpty)
 .toList();
 }

 void _showDebtSnapshotReport() {
 final critical =
 _debtItems.where((item) => item.severity == 'Critical').length;
 final inProgress =
 _debtItems.where((item) => item.status == 'In progress').length;
 final backlog = _debtItems.where((item) => item.status == 'Backlog').length;
 final resolved = _debtItems.where((item) => item.status == 'Done').length;

 showDialog<void>(
 context: context,
 builder: (dialogContext) => AlertDialog(
 title: const Text('Technical Debt Snapshot'),
 content: Column(
 mainAxisSize: MainAxisSize.min,
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text('Total items: ${_debtItems.length}'),
 Text('Critical: $critical'),
 Text('In progress: $inProgress'),
 Text('Backlog: $backlog'),
 Text('Resolved: $resolved'),
 ],
 ),
 actions: [
 TextButton(
 onPressed: () => Navigator.of(dialogContext).pop(),
 child: const Text('Close'),
 ),
 ],
 ),
 );
 }

 void _showAddDebtItemDialog() {
 _showDebtItemDialog();
 }

 void _showEditDebtItemDialog(DebtItem item) {
 _showDebtItemDialog(existing: item);
 }

 void _showDebtItemDialog({DebtItem? existing}) {
 final isEdit = existing != null;
 final idController = TextEditingController(
 text: existing?.id ?? 'TD-${DateTime.now().millisecondsSinceEpoch}',
 );
 final titleController = TextEditingController(text: existing?.title ?? '');
 final areaController = TextEditingController(text: existing?.area ?? '');
 final ownerController = TextEditingController(text: existing?.owner ?? '');
 final targetController =
 TextEditingController(text: existing?.target ?? '');
 var selectedSeverity = (existing?.severity ?? 'Medium').trim();
 var selectedStatus = (existing?.status ?? 'Backlog').trim();

 if (!['Critical', 'High', 'Medium', 'Low'].contains(selectedSeverity)) {
 selectedSeverity = 'Medium';
 }
 if (!['Backlog', 'In progress', 'Blocked', 'Done']
 .contains(selectedStatus)) {
 selectedStatus = 'Backlog';
 }

 showDialog<void>(
 context: context,
 builder: (dialogContext) => StatefulBuilder(
 builder: (dialogContext, setDialogState) => AlertDialog(
 title: Text(isEdit ? 'Edit debt item' : 'Add debt item'),
 content: SingleChildScrollView(
 child: Column(
 mainAxisSize: MainAxisSize.min,
 children: [
 VoiceTextField(
 controller: idController,
 decoration: const InputDecoration(labelText: 'ID *'),
 ),
 const SizedBox(height: 12),
 VoiceTextField(
 controller: titleController,
 decoration: const InputDecoration(labelText: 'Item *'),
 ),
 const SizedBox(height: 12),
 VoiceTextField(
 controller: areaController,
 decoration: const InputDecoration(labelText: 'Area'),
 ),
 const SizedBox(height: 12),
 VoiceTextField(
 controller: ownerController,
 decoration: const InputDecoration(labelText: 'Owner'),
 ),
 const SizedBox(height: 12),
 DropdownButtonFormField<String>(
 value: selectedSeverity,
 decoration: const InputDecoration(labelText: 'Severity'),
 items: const ['Critical', 'High', 'Medium', 'Low']
 .map((value) =>
 DropdownMenuItem(value: value, child: Text(value)))
 .toList(),
 onChanged: (value) {
 if (value != null) {
 setDialogState(() => selectedSeverity = value);
 }
 },
 ),
 const SizedBox(height: 12),
 DropdownButtonFormField<String>(
 value: selectedStatus,
 decoration: const InputDecoration(labelText: 'Status'),
 items: const ['Backlog', 'In progress', 'Blocked', 'Done']
 .map((value) =>
 DropdownMenuItem(value: value, child: Text(value)))
 .toList(),
 onChanged: (value) {
 if (value != null) {
 setDialogState(() => selectedStatus = value);
 }
 },
 ),
 const SizedBox(height: 12),
 VoiceTextField(
 controller: targetController,
 decoration: const InputDecoration(labelText: 'Target / Due'),
 ),
 ],
 ),
 ),
 actions: [
 TextButton(
 onPressed: () => Navigator.of(dialogContext).pop(),
 child: const Text('Cancel'),
 ),
 ElevatedButton(
 onPressed: () async {
 final id = idController.text.trim();
 final title = titleController.text.trim();
 if (id.isEmpty || title.isEmpty) {
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(content: Text('ID and Item are required.')),
 );
 return;
 }

 final updatedItem = DebtItem(
 id: id,
 title: title,
 area: areaController.text.trim(),
 owner: ownerController.text.trim(),
 severity: selectedSeverity,
 status: selectedStatus,
 target: targetController.text.trim(),
 );

 final updatedList = [..._debtItems];
 final existingIndex = updatedList
 .indexWhere((element) => element.id == updatedItem.id);
 if (existingIndex >= 0) {
 updatedList[existingIndex] = updatedItem;
 } else {
 updatedList.add(updatedItem);
 }

 await _upsertDebtItems(updatedList);
 if (!mounted || !dialogContext.mounted) return;
 setState(() => _debtItems = updatedList);
 Navigator.of(dialogContext).pop();
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(
 content: Text(
 isEdit ? 'Debt item updated.' : 'Debt item added.')),
 );
 },
 child: Text(isEdit ? 'Update' : 'Add'),
 ),
 ],
 ),
 ),
 );
 }

 Future<void> _deleteDebtItem(DebtItem item) async {
 final updated = [..._debtItems]
 ..removeWhere((element) => element.id == item.id);
 await _upsertDebtItems(updated);
 if (!mounted) return;
 setState(() => _debtItems = updated);
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(content: Text('Removed debt item ${item.id}.')),
 );
 }

 void _showAddRemediationTrackDialog() => _showRemediationTrackDialog();

 void _showEditRemediationTrackDialog(
 int displayIndex,
 _RemediationRunwayRow row,
 ) {
 _showRemediationTrackDialog(displayIndex: displayIndex, seed: row);
 }

 void _showRemediationTrackDialog({
 int? displayIndex,
 _RemediationRunwayRow? seed,
 }) {
 final labelController = TextEditingController(text: seed?.primary ?? '');
 final secondaryController =
 TextEditingController(text: seed?.secondary ?? '');
 final exitCriteriaController =
 TextEditingController(text: seed?.exitCriteria ?? '');
 final evidenceController =
 TextEditingController(text: seed?.evidence ?? '');
 final ownerCadenceController =
 TextEditingController(text: seed?.ownerCadence ?? '');
 var progress = seed?.progress ?? 0.35;
 var selectedColorValue =
 (seed?.color ?? const Color(0xFF0EA5E9)).toARGB32();

 showDialog<void>(
 context: context,
 builder: (dialogContext) => StatefulBuilder(
 builder: (dialogContext, setDialogState) => AlertDialog(
 title: Text(displayIndex == null
 ? 'Add remediation lane'
 : 'Edit remediation lane'),
 content: SizedBox(
 width: 600,
 child: SingleChildScrollView(
 child: Column(
 mainAxisSize: MainAxisSize.min,
 crossAxisAlignment: CrossAxisAlignment.stretch,
 children: [
 VoiceTextField(
 controller: labelController,
 decoration: const InputDecoration(
 labelText: 'Priority lane *',
 helperText:
 'Use a risk-ranked lane such as P0 containment or P1 operability.',
 ),
 ),
 const SizedBox(height: 16),
 VoiceTextField(
 controller: secondaryController,
 maxLines: 2,
 decoration: const InputDecoration(
 labelText: 'Scope description',
 helperText: 'Brief description of what this lane covers.',
 ),
 ),
 const SizedBox(height: 16),
 VoiceTextField(
 controller: exitCriteriaController,
 maxLines: 3,
 decoration: const InputDecoration(
 labelText: 'Exit criteria / closure standard',
 helperText:
 'What must be achieved to consider this lane complete?',
 ),
 ),
 const SizedBox(height: 16),
 VoiceTextField(
 controller: evidenceController,
 maxLines: 3,
 decoration: const InputDecoration(
 labelText: 'Verification evidence',
 helperText: 'What evidence proves exit criteria are met?',
 ),
 ),
 const SizedBox(height: 16),
 VoiceTextField(
 controller: ownerCadenceController,
 decoration: const InputDecoration(
 labelText: 'Accountability / cadence',
 helperText: 'Who owns this and how often is it reviewed?',
 ),
 ),
 const SizedBox(height: 20),
 Text('Progress ${(progress * 100).round()}%',
 style: const TextStyle(fontWeight: FontWeight.w600)),
 Slider(
 value: progress,
 min: 0,
 max: 1,
 divisions: 20,
 onChanged: (value) =>
 setDialogState(() => progress = value),
 ),
 const SizedBox(height: 12),
 DropdownButtonFormField<int>(
 value: selectedColorValue,
 decoration: const InputDecoration(labelText: 'Risk color'),
 items: _governanceColorOptions
 .map((option) => DropdownMenuItem<int>(
 value: option.value,
 child: Text(option.label),
 ))
 .toList(),
 onChanged: (value) {
 if (value != null) {
 setDialogState(() => selectedColorValue = value);
 }
 },
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
 ElevatedButton(
 onPressed: () async {
 final label = labelController.text.trim();
 if (label.isEmpty) {
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(content: Text('Priority lane is required.')),
 );
 return;
 }

 final updated = _effectiveTracks();
 final lane = _classifyLane(label);
 final item = RemediationTrack(
 label: label,
 secondary: secondaryController.text.trim().isNotEmpty
 ? secondaryController.text.trim()
 : lane.secondary,
 exitCriteria: exitCriteriaController.text.trim().isNotEmpty
 ? exitCriteriaController.text.trim()
 : lane.exitCriteria,
 evidence: evidenceController.text.trim().isNotEmpty
 ? evidenceController.text.trim()
 : lane.evidence,
 ownerCadence: ownerCadenceController.text.trim().isNotEmpty
 ? ownerCadenceController.text.trim()
 : lane.ownerCadence,
 progress: progress,
 colorValue: selectedColorValue,
 );
 if (displayIndex == null || displayIndex >= updated.length) {
 updated.add(item);
 } else {
 updated[displayIndex] = item;
 }
 await _upsertRemediationTracks(updated);
 if (!mounted || !dialogContext.mounted) return;
 setState(() => _tracks = updated);
 Navigator.of(dialogContext).pop();
 },
 child: Text(displayIndex == null ? 'Add' : 'Update'),
 ),
 ],
 ),
 ),
 );
 }

 void _showAddRootCauseDialog() => _showRootCauseDialog();

 void _showEditRootCauseDialog(int displayIndex, _RootCauseSignalRow row) {
 _showRootCauseDialog(displayIndex: displayIndex, seed: row);
 }

 void _showRootCauseDialog({
 int? displayIndex,
 _RootCauseSignalRow? seed,
 }) {
 final titleController = TextEditingController(text: seed?.signal ?? '');
 final subtitleController =
 TextEditingController(text: seed?.indicator ?? '');
 final evidenceController =
 TextEditingController(text: seed?.evidence ?? '');
 final controlController = TextEditingController(text: seed?.control ?? '');
 var selectedTier = seed?.tier ?? 'Medium';
 var selectedColorValue =
 (seed?.color ?? const Color(0xFFF97316)).toARGB32();

 showDialog<void>(
 context: context,
 builder: (dialogContext) => StatefulBuilder(
 builder: (dialogContext, setDialogState) => AlertDialog(
 title: Text(displayIndex == null
 ? 'Add root cause signal'
 : 'Edit root cause signal'),
 content: SizedBox(
 width: 600,
 child: SingleChildScrollView(
 child: Column(
 mainAxisSize: MainAxisSize.min,
 crossAxisAlignment: CrossAxisAlignment.stretch,
 children: [
 VoiceTextField(
 controller: titleController,
 decoration:
 const InputDecoration(labelText: 'Signal cluster *'),
 ),
 const SizedBox(height: 16),
 VoiceTextField(
 controller: subtitleController,
 maxLines: 3,
 decoration: const InputDecoration(
 labelText: 'Diagnostic interpretation',
 helperText:
 'Describe the leading indicator, evidence pattern, or systemic cause.',
 ),
 ),
 const SizedBox(height: 16),
 VoiceTextField(
 controller: evidenceController,
 maxLines: 2,
 decoration: const InputDecoration(
 labelText: 'Detection evidence',
 helperText: 'What data points confirm this signal?',
 ),
 ),
 const SizedBox(height: 16),
 VoiceTextField(
 controller: controlController,
 maxLines: 2,
 decoration: const InputDecoration(
 labelText: 'Control action',
 helperText:
 'What mitigation or prevention action should be taken?',
 ),
 ),
 const SizedBox(height: 16),
 DropdownButtonFormField<String>(
 value: selectedTier,
 decoration: const InputDecoration(labelText: 'Risk tier'),
 items: const [
 DropdownMenuItem(
 value: 'Critical', child: Text('Critical')),
 DropdownMenuItem(value: 'High', child: Text('High')),
 DropdownMenuItem(value: 'Medium', child: Text('Medium')),
 DropdownMenuItem(value: 'Low', child: Text('Low')),
 ],
 onChanged: (value) {
 if (value != null) {
 setDialogState(() => selectedTier = value);
 }
 },
 ),
 const SizedBox(height: 16),
 DropdownButtonFormField<int>(
 value: selectedColorValue,
 decoration:
 const InputDecoration(labelText: 'Severity color'),
 items: _governanceColorOptions
 .map((option) => DropdownMenuItem(
 value: option.value,
 child: Text(option.label),
 ))
 .toList(),
 onChanged: (value) {
 if (value != null) {
 setDialogState(() => selectedColorValue = value);
 }
 },
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
 ElevatedButton(
 onPressed: () async {
 final title = titleController.text.trim();
 if (title.isEmpty) {
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(
 content: Text('Signal cluster is required.')),
 );
 return;
 }
 final updated = _effectiveRootCauses();
 final profile = titleController.text.trim().isNotEmpty &&
 evidenceController.text.trim().isNotEmpty
 ? null
 : _classifyRootCause(title, subtitleController.text.trim());
 final item = DebtInsight(
 title: title,
 subtitle: subtitleController.text.trim(),
 evidence: evidenceController.text.trim().isNotEmpty
 ? evidenceController.text.trim()
 : (profile?.evidence ?? ''),
 control: controlController.text.trim().isNotEmpty
 ? controlController.text.trim()
 : (profile?.control ?? ''),
 tier: selectedTier,
 colorValue: selectedColorValue,
 );
 if (displayIndex == null || displayIndex >= updated.length) {
 updated.add(item);
 } else {
 updated[displayIndex] = item;
 }
 await _upsertRootCauses(updated);
 if (!mounted || !dialogContext.mounted) return;
 setState(() => _rootCauses = updated);
 Navigator.of(dialogContext).pop();
 },
 child: Text(displayIndex == null ? 'Add' : 'Update'),
 ),
 ],
 ),
 ),
 );
 }

 void _showAddOwnerDialog() => _showOwnerDialog();

 void _showEditOwnerDialog(int displayIndex, _OwnershipCoverageRow row) {
 _showOwnerDialog(displayIndex: displayIndex, seed: row);
 }

 void _showOwnerDialog({
 int? displayIndex,
 _OwnershipCoverageRow? seed,
 }) {
 final ownerController = TextEditingController(text: seed?.owner ?? '');
 final workstreamController =
 TextEditingController(text: seed?.workstream ?? '');
 final scopeController = TextEditingController(text: seed?.scope ?? '');
 final countController = TextEditingController(text: seed?.count ?? '1');
 final coverageController =
 TextEditingController(text: seed?.coverage ?? '');
 final reviewController = TextEditingController(text: seed?.review ?? '');
 final escalationController =
 TextEditingController(text: seed?.escalation ?? '');
 var selectedColorValue =
 (seed?.color ?? const Color(0xFF0EA5E9)).toARGB32();

 showDialog<void>(
 context: context,
 builder: (dialogContext) => StatefulBuilder(
 builder: (dialogContext, setDialogState) => AlertDialog(
 title: Text(
 displayIndex == null ? 'Add accountable owner' : 'Edit owner'),
 content: SizedBox(
 width: 650,
 child: SingleChildScrollView(
 child: Column(
 mainAxisSize: MainAxisSize.min,
 crossAxisAlignment: CrossAxisAlignment.stretch,
 children: [
 VoiceTextField(
 controller: ownerController,
 decoration:
 const InputDecoration(labelText: 'Accountable owner *'),
 ),
 const SizedBox(height: 16),
 VoiceTextField(
 controller: workstreamController,
 decoration: const InputDecoration(
 labelText: 'Workstream',
 helperText:
 'The domain or area this owner is responsible for.',
 ),
 ),
 const SizedBox(height: 16),
 VoiceTextField(
 controller: scopeController,
 maxLines: 2,
 decoration: const InputDecoration(
 labelText: 'Scope',
 helperText:
 'What specific areas fall under this ownership?',
 ),
 ),
 const SizedBox(height: 16),
 VoiceTextField(
 controller: countController,
 keyboardType: TextInputType.number,
 decoration: const InputDecoration(
 labelText: 'Number of accountable roles'),
 ),
 const SizedBox(height: 16),
 VoiceTextField(
 controller: coverageController,
 maxLines: 3,
 decoration: const InputDecoration(
 labelText: 'Coverage standard',
 helperText: 'What coverage model defines accountability?',
 ),
 ),
 const SizedBox(height: 16),
 VoiceTextField(
 controller: reviewController,
 maxLines: 2,
 decoration: const InputDecoration(
 labelText: 'Review checkpoint',
 helperText: 'When and how often is ownership reviewed?',
 ),
 ),
 const SizedBox(height: 16),
 VoiceTextField(
 controller: escalationController,
 maxLines: 2,
 decoration: const InputDecoration(
 labelText: 'Escalation trigger',
 helperText: 'What conditions trigger escalation?',
 ),
 ),
 const SizedBox(height: 16),
 DropdownButtonFormField<int>(
 value: selectedColorValue,
 decoration:
 const InputDecoration(labelText: 'Workstream color'),
 items: _governanceColorOptions
 .map((option) => DropdownMenuItem(
 value: option.value,
 child: Text(option.label),
 ))
 .toList(),
 onChanged: (value) {
 if (value != null) {
 setDialogState(() => selectedColorValue = value);
 }
 },
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
 ElevatedButton(
 onPressed: () async {
 final owner = ownerController.text.trim();
 if (owner.isEmpty) {
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(
 content: Text('Accountable owner is required.')),
 );
 return;
 }
 final updated = _effectiveOwners();
 final profile = ownerController.text.trim().isNotEmpty &&
 coverageController.text.trim().isNotEmpty
 ? null
 : _classifyOwner(owner, reviewController.text.trim());
 final item = OwnerItem(
 name: owner,
 workstream: workstreamController.text.trim().isNotEmpty
 ? workstreamController.text.trim()
 : (profile?.workstream ?? ''),
 scope: scopeController.text.trim().isNotEmpty
 ? scopeController.text.trim()
 : (profile?.scope ?? ''),
 count: countController.text.trim().isEmpty
 ? '1'
 : countController.text.trim(),
 coverage: coverageController.text.trim().isNotEmpty
 ? coverageController.text.trim()
 : (profile?.coverage ?? ''),
 note: reviewController.text.trim().isNotEmpty
 ? reviewController.text.trim()
 : (profile?.review ?? ''),
 escalation: escalationController.text.trim().isNotEmpty
 ? escalationController.text.trim()
 : (profile?.escalation ?? ''),
 );
 if (displayIndex == null || displayIndex >= updated.length) {
 updated.add(item);
 } else {
 updated[displayIndex] = item;
 }
 await _upsertOwners(updated);
 if (!mounted || !dialogContext.mounted) return;
 setState(() => _owners = updated);
 Navigator.of(dialogContext).pop();
 },
 child: Text(displayIndex == null ? 'Add' : 'Update'),
 ),
 ],
 ),
 ),
 );
 }

 Future<void> _deleteRemediationTrack(int displayIndex, String label) async {
 final confirmed = await showDeleteConfirmationDialog(
 context,
 title: 'Delete remediation lane',
 itemLabel: label,
 );
 if (!confirmed) return;
 final updated = _effectiveTracks();
 if (displayIndex >= 0 && displayIndex < updated.length) {
 updated.removeAt(displayIndex);
 }
 await _upsertRemediationTracks(updated);
 if (!mounted) return;
 setState(() => _tracks = updated);
 }

 Future<void> _deleteRootCause(int displayIndex, String label) async {
 final confirmed = await showDeleteConfirmationDialog(
 context,
 title: 'Delete root cause signal',
 itemLabel: label,
 );
 if (!confirmed) return;
 final updated = _effectiveRootCauses();
 if (displayIndex >= 0 && displayIndex < updated.length) {
 updated.removeAt(displayIndex);
 }
 await _upsertRootCauses(updated);
 if (!mounted) return;
 setState(() => _rootCauses = updated);
 }

 Future<void> _deleteOwner(int displayIndex, String label) async {
 final confirmed = await showDeleteConfirmationDialog(
 context,
 title: 'Delete owner coverage',
 itemLabel: label,
 );
 if (!confirmed) return;
 final updated = _effectiveOwners();
 if (displayIndex >= 0 && displayIndex < updated.length) {
 updated.removeAt(displayIndex);
 }
 await _upsertOwners(updated);
 if (!mounted) return;
 setState(() => _owners = updated);
 }

 List<RemediationTrack> _effectiveTracks() {
 final usable =
 _tracks.where((track) => !_isPlaceholderText(track.label)).toList();
 if (usable.isNotEmpty) return [...usable];
 return _remediationTableRows()
 .map((row) => RemediationTrack(
 label: row.primary,
 progress: row.progress,
 colorValue: row.color.toARGB32(),
 ))
 .toList();
 }

 List<DebtInsight> _effectiveRootCauses() {
 final usable =
 _rootCauses.where((item) => !_isPlaceholderText(item.title)).toList();
 if (usable.isNotEmpty) return [...usable];
 return _rootCauseTableRows()
 .map((row) => DebtInsight(title: row.signal, subtitle: row.indicator))
 .toList();
 }

 List<OwnerItem> _effectiveOwners() {
 final usable =
 _owners.where((owner) => !_isPlaceholderText(owner.name)).toList();
 if (usable.isNotEmpty) return [...usable];
 return _ownershipTableRows()
 .map((row) => OwnerItem(
 name: row.owner,
 count: row.count,
 note: row.review,
 ))
 .toList();
 }

 Future<void> _upsertDebtItems(List<DebtItem> items) async {
 await ProjectDataHelper.updateAndSave(
 context: context,
 checkpoint: 'technical_debt_management',
 showSnackbar: false,
 dataUpdater: (current) {
 final updatedFep = ProjectDataHelper.updateFEPField(
 current: current.frontEndPlanning,
 technicalDebtItems: items,
 );
 return current.copyWith(frontEndPlanning: updatedFep);
 },
 );
 }

 Future<void> _upsertRemediationTracks(List<RemediationTrack> tracks) async {
 await ProjectDataHelper.updateAndSave(
 context: context,
 checkpoint: 'technical_debt_management',
 showSnackbar: false,
 dataUpdater: (current) {
 final updatedFep = ProjectDataHelper.updateFEPField(
 current: current.frontEndPlanning,
 technicalDebtTracks: tracks,
 );
 return current.copyWith(frontEndPlanning: updatedFep);
 },
 );
 }

 Future<void> _upsertRootCauses(List<DebtInsight> rootCauses) async {
 await ProjectDataHelper.updateAndSave(
 context: context,
 checkpoint: 'technical_debt_management',
 showSnackbar: false,
 dataUpdater: (current) {
 final updatedFep = ProjectDataHelper.updateFEPField(
 current: current.frontEndPlanning,
 technicalDebtRootCauses: rootCauses,
 );
 return current.copyWith(frontEndPlanning: updatedFep);
 },
 );
 }

 Future<void> _upsertOwners(List<OwnerItem> owners) async {
 await ProjectDataHelper.updateAndSave(
 context: context,
 checkpoint: 'technical_debt_management',
 showSnackbar: false,
 dataUpdater: (current) {
 final updatedFep = ProjectDataHelper.updateFEPField(
 current: current.frontEndPlanning,
 technicalDebtOwners: owners,
 );
 return current.copyWith(frontEndPlanning: updatedFep);
 },
 );
 }

 Future<void> _upsertTechnicalDebtData({
 required List<DebtItem> items,
 required List<DebtInsight> rootCauses,
 required List<RemediationTrack> tracks,
 required List<OwnerItem> owners,
 }) async {
 await ProjectDataHelper.updateAndSave(
 context: context,
 checkpoint: 'technical_debt_management',
 showSnackbar: false,
 dataUpdater: (current) {
 final updatedFep = ProjectDataHelper.updateFEPField(
 current: current.frontEndPlanning,
 technicalDebtItems: items,
 technicalDebtRootCauses: rootCauses,
 technicalDebtTracks: tracks,
 technicalDebtOwners: owners,
 );
 return current.copyWith(frontEndPlanning: updatedFep);
 },
 );
 }

 Widget _chip(String label) {
 return Container(
 padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
 decoration: BoxDecoration(
 color: const Color(0xFFF1F5F9),
 borderRadius: BorderRadius.circular(16),
 ),
 child: Text(label,
 style: const TextStyle(
 fontSize: 11,
 fontWeight: FontWeight.w600,
 color: Color(0xFF475569))),
 );
 }

 Widget _tableToolbar({
 String? chipLabel,
 required String buttonLabel,
 required VoidCallback onAdd,
 }) {
 return Wrap(
 spacing: 8,
 runSpacing: 8,
 crossAxisAlignment: WrapCrossAlignment.center,
 children: [
 if (chipLabel != null) _chip(chipLabel),
 OutlinedButton.icon(
 onPressed: onAdd,
 icon: const Icon(Icons.add, size: 16),
 label: Text(buttonLabel),
 style: OutlinedButton.styleFrom(
 padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
 textStyle:
 const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
 side: const BorderSide(color: Color(0xFFE2E8F0)),
 shape:
 RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
 ),
 ),
 ],
 );
 }

 Widget _severityChip(String label) {
 Color color;
 switch (label) {
 case 'Critical':
 color = const Color(0xFFEF4444);
 break;
 case 'High':
 color = const Color(0xFFF97316);
 break;
 case 'Medium':
 color = const Color(0xFF6366F1);
 break;
 default:
 color = const Color(0xFF94A3B8);
 }
 return Container(
 padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
 decoration: BoxDecoration(
 color: color.withOpacity(0.12),
 borderRadius: BorderRadius.circular(16),
 ),
 child: Text(label,
 style: TextStyle(
 fontSize: 11, fontWeight: FontWeight.w600, color: color)),
 );
 }

 Widget _statusChip(String label) {
 final color = label == 'In progress'
 ? const Color(0xFF0EA5E9)
 : label == 'Backlog'
 ? const Color(0xFFF59E0B)
 : const Color(0xFF6366F1);
 return Container(
 padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
 decoration: BoxDecoration(
 color: color.withOpacity(0.12),
 borderRadius: BorderRadius.circular(16),
 ),
 child: Text(label,
 style: TextStyle(
 fontSize: 11, fontWeight: FontWeight.w600, color: color)),
 );
 }

 Widget _tableHeaderCell(String text, {required double flex}) {
 return Expanded(
 flex: (flex * 10).round(),
 child: Text(
 text,
 style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
 overflow: TextOverflow.ellipsis,
 ),
 );
 }

 Widget _tableCell(
 String text, {
 required double flex,
 TextStyle? textStyle,
 bool isChip = false,
 bool isSeverityChip = false,
 bool isStatusChip = false,
 }) {
 Widget? child;
 if (isChip) {
 child = _chip(text);
 } else if (isSeverityChip) {
 child = _severityChip(text);
 } else if (isStatusChip) {
 child = _statusChip(text);
 } else {
 child = Text(
 text,
 style: textStyle ?? const TextStyle(fontSize: 13),
 overflow: TextOverflow.ellipsis,
 );
 }
 return Expanded(
 flex: (flex * 10).round(),
 child: child,
 );
 }

 Widget _actionsCell({
 required double flex,
 required VoidCallback onEdit,
 required VoidCallback onDelete,
 }) {
 return Expanded(
 flex: (flex * 10).round(),
 child: Row(
 mainAxisSize: MainAxisSize.min,
 children: [
 IconButton(
 onPressed: onEdit,
 icon: const Icon(Icons.edit, size: 16),
 color: const Color(0xFF64748B),
 tooltip: 'Edit',
 padding: EdgeInsets.zero,
 constraints: const BoxConstraints(),
 ),
 IconButton(
 onPressed: onDelete,
 icon: const Icon(Icons.delete_outline, size: 16),
 color: const Color(0xFFEF4444),
 tooltip: 'Delete',
 padding: EdgeInsets.zero,
 constraints: const BoxConstraints(),
 ),
 ],
 ),
 );
 }

 Future<void> _exportPdf() async {
 final projectData = ProjectDataHelper.getData(context);
 await PdfExportHelper.exportScreenPdf(
 context: context,
 screenTitle: 'Technical Debt Management',
 sections: [
 PdfSection.keyValue('Project Info', [
 {'Project Name': projectData.projectName ?? 'N/A'},
 {'Solution Title': projectData.solutionTitle ?? 'N/A'},
 ]),
 PdfSection.text('Notes', projectData.planningNotes['planning_technical_debt_management_notes'] ?? 'No data recorded.'),
 ],
 );
 }
}

class _GovernanceTable extends StatelessWidget {
 const _GovernanceTable({
 required this.columns,
 required this.rows,
 });

 final List<_GovernanceColumn> columns;
 final List<List<Widget>> rows;

 @override
 Widget build(BuildContext context) {
 return LayoutBuilder(
 builder: (context, constraints) {
 final minWidth = columns.fold<double>(
 0,
 (sum, column) => sum + (column.flex * 142),
 );
 final tableWidth =
 constraints.maxWidth < minWidth ? minWidth : constraints.maxWidth;

 return ClipRRect(
 borderRadius: BorderRadius.circular(16),
 child: DecoratedBox(
 decoration: BoxDecoration(
 border: Border.all(color: const Color(0xFFE5E7EB)),
 borderRadius: BorderRadius.circular(16),
 ),
 child: SingleChildScrollView(
 scrollDirection: Axis.horizontal,
 child: SizedBox(
 width: tableWidth,
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.stretch,
 children: [
 _GovernanceHeaderRow(columns: columns),
 ...rows.asMap().entries.map(
 (entry) => _GovernanceBodyRow(
 columns: columns,
 cells: entry.value,
 isLast: entry.key == rows.length - 1,
 isAlt: entry.key.isOdd,
 ),
 ),
 ],
 ),
 ),
 ),
 ),
 );
 },
 );
 }
}

class _GovernanceHeaderRow extends StatelessWidget {
 const _GovernanceHeaderRow({required this.columns});

 final List<_GovernanceColumn> columns;

 @override
 Widget build(BuildContext context) {
 return Container(
 padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
 color: const Color(0xFFF8FAFC),
 child: Row(
 children: columns
 .map(
 (column) => Expanded(
 flex: column.flexValue,
 child: Padding(
 padding: const EdgeInsets.only(right: 12),
 child: Text(
 column.label,
 style: const TextStyle(
 fontSize: 11,
 fontWeight: FontWeight.w700,
 color: Color(0xFF475569),
 ),
 ),
 ),
 ),
 )
 .toList(),
 ),
 );
 }
}

class _GovernanceBodyRow extends StatelessWidget {
 const _GovernanceBodyRow({
 required this.columns,
 required this.cells,
 required this.isLast,
 required this.isAlt,
 });

 final List<_GovernanceColumn> columns;
 final List<Widget> cells;
 final bool isLast;
 final bool isAlt;

 @override
 Widget build(BuildContext context) {
 return Container(
 padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
 decoration: BoxDecoration(
 color: isAlt ? const Color(0xFFFCFDFF) : Colors.white,
 border: isLast
 ? null
 : const Border(
 top: BorderSide(color: Color(0xFFE2E8F0)),
 ),
 ),
 child: Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: List.generate(columns.length, (index) {
 return Expanded(
 flex: columns[index].flexValue,
 child: Padding(
 padding: const EdgeInsets.only(right: 12),
 child: cells[index],
 ),
 );
 }),
 ),
 );
 }
}

class _PriorityCell extends StatelessWidget {
 const _PriorityCell({
 required this.title,
 required this.supporting,
 required this.color,
 });

 final String title;
 final String supporting;
 final Color color;

 @override
 Widget build(BuildContext context) {
 return Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Container(
 width: 8,
 height: 8,
 margin: const EdgeInsets.only(top: 5),
 decoration: BoxDecoration(color: color, shape: BoxShape.circle),
 ),
 const SizedBox(width: 8),
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 title,
 style: const TextStyle(
 fontSize: 13,
 fontWeight: FontWeight.w700,
 color: Color(0xFF111827),
 ),
 ),
 const SizedBox(height: 4),
 Text(
 supporting,
 style: const TextStyle(
 fontSize: 11,
 height: 1.35,
 color: Color(0xFF64748B),
 ),
 ),
 ],
 ),
 ),
 ],
 );
 }
}

class _BodyCell extends StatelessWidget {
 const _BodyCell(this.value);

 final String value;

 @override
 Widget build(BuildContext context) {
 return Text(
 value,
 style: const TextStyle(
 fontSize: 12,
 height: 1.35,
 color: Color(0xFF334155),
 ),
 );
 }
}

class _ProgressCell extends StatelessWidget {
 const _ProgressCell({
 required this.value,
 required this.color,
 });

 final double value;
 final Color color;

 @override
 Widget build(BuildContext context) {
 final percentage = (value.clamp(0.0, 1.0) * 100).round();
 return Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 '$percentage%',
 style: TextStyle(
 fontSize: 13,
 fontWeight: FontWeight.w700,
 color: color,
 ),
 ),
 const SizedBox(height: 8),
 ClipRRect(
 borderRadius: BorderRadius.circular(8),
 child: LinearProgressIndicator(
 value: value.clamp(0.0, 1.0),
 minHeight: 8,
 backgroundColor: const Color(0xFFE5E7EB),
 valueColor: AlwaysStoppedAnimation<Color>(color),
 ),
 ),
 ],
 );
 }
}

class _RiskTierCell extends StatelessWidget {
 const _RiskTierCell({
 required this.label,
 required this.color,
 });

 final String label;
 final Color color;

 @override
 Widget build(BuildContext context) {
 return Align(
 alignment: Alignment.centerLeft,
 child: Container(
 padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
 decoration: BoxDecoration(
 color: color.withOpacity(0.12),
 borderRadius: BorderRadius.circular(16),
 ),
 child: Text(
 label,
 style: TextStyle(
 fontSize: 11,
 fontWeight: FontWeight.w700,
 color: color,
 ),
 ),
 ),
 );
 }
}

class _OwnerCoverageCell extends StatelessWidget {
 const _OwnerCoverageCell({
 required this.owner,
 required this.count,
 });

 final String owner;
 final String count;

 @override
 Widget build(BuildContext context) {
 final initial = owner.trim().isEmpty ? '?' : owner.trim()[0].toUpperCase();
 return Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 CircleAvatar(
 radius: 15,
 backgroundColor: const Color(0xFF0EA5E9).withOpacity(0.14),
 child: Text(
 initial,
 style: const TextStyle(
 fontSize: 11,
 fontWeight: FontWeight.w700,
 color: Color(0xFF0EA5E9),
 ),
 ),
 ),
 const SizedBox(width: 8),
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 owner,
 style: const TextStyle(
 fontSize: 13,
 fontWeight: FontWeight.w700,
 color: Color(0xFF111827),
 ),
 ),
 const SizedBox(height: 3),
 Text(
 '$count accountable role${count == '1' ? '' : 's'}',
 style: const TextStyle(
 fontSize: 11,
 color: Color(0xFF64748B),
 ),
 ),
 ],
 ),
 ),
 ],
 );
 }
}

class _RowActionsCell extends StatelessWidget {
 const _RowActionsCell({
 required this.onEdit,
 required this.onDelete,
 });

 final VoidCallback onEdit;
 final VoidCallback onDelete;

 @override
 Widget build(BuildContext context) {
 return Row(
 mainAxisSize: MainAxisSize.min,
 children: [
 IconButton(
 onPressed: onEdit,
 icon: const Icon(Icons.edit, size: 16),
 color: const Color(0xFF64748B),
 tooltip: 'Edit',
 padding: EdgeInsets.zero,
 constraints: const BoxConstraints.tightFor(width: 32, height: 32),
 ),
 IconButton(
 onPressed: onDelete,
 icon: const Icon(Icons.delete_outline, size: 16),
 color: const Color(0xFFEF4444),
 tooltip: 'Delete',
 padding: EdgeInsets.zero,
 constraints: const BoxConstraints.tightFor(width: 32, height: 32),
 ),
 ],
 );
 }
}

class _GovernanceColumn {
 const _GovernanceColumn(this.label, this.flex);

 final String label;
 final double flex;

 int get flexValue => (flex * 100).round();
}

class _GovernanceColorOption {
 const _GovernanceColorOption(this.label, this.value);

 final String label;
 final int value;
}

class _RemediationRunwayRow {
 const _RemediationRunwayRow({
 required this.primary,
 required this.secondary,
 required this.exitCriteria,
 required this.evidence,
 required this.ownerCadence,
 required this.progress,
 required this.color,
 });

 final String primary;
 final String secondary;
 final String exitCriteria;
 final String evidence;
 final String ownerCadence;
 final double progress;
 final Color color;
}

class _RootCauseSignalRow {
 const _RootCauseSignalRow({
 required this.signal,
 required this.source,
 required this.indicator,
 required this.evidence,
 required this.control,
 required this.tier,
 required this.color,
 });

 final String signal;
 final String source;
 final String indicator;
 final String evidence;
 final String control;
 final String tier;
 final Color color;
}

class _OwnershipCoverageRow {
 const _OwnershipCoverageRow({
 required this.workstream,
 required this.scope,
 required this.owner,
 required this.count,
 required this.coverage,
 required this.review,
 required this.escalation,
 required this.color,
 });

 final String workstream;
 final String scope;
 final String owner;
 final String count;
 final String coverage;
 final String review;
 final String escalation;
 final Color color;
}

class _LaneProfile {
 const _LaneProfile({
 required this.secondary,
 required this.exitCriteria,
 required this.evidence,
 required this.ownerCadence,
 });

 final String secondary;
 final String exitCriteria;
 final String evidence;
 final String ownerCadence;
}

class _RootCauseProfile {
 const _RootCauseProfile({
 required this.source,
 required this.indicator,
 required this.evidence,
 required this.control,
 required this.tier,
 required this.color,
 });

 final String source;
 final String indicator;
 final String evidence;
 final String control;
 final String tier;
 final Color color;
}

class _OwnerProfile {
 const _OwnerProfile({
 required this.workstream,
 required this.scope,
 required this.coverage,
 required this.review,
 required this.escalation,
 required this.color,
 });

 final String workstream;
 final String scope;
 final String coverage;
 final String review;
 final String escalation;
 final Color color;
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
 border: Border.all(color: const Color(0xFFE5E7EB)),
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

// Legacy private data classes removed; using persisted models from project_data_model.dart

class _StatCardData {
 const _StatCardData(this.label, this.value, this.supporting, this.color);

 final String label;
 final String value;
 final String supporting;
 final Color color;
}

class _DebtItem {
 const _DebtItem(this.id, this.title, this.area, this.owner, this.severity, this.status, this.target);

 final String id;
 final String title;
 final String area;
 final String owner;
 final String severity;
 final String status;
 final String target;
}

class _DebtInsight {
 const _DebtInsight(this.title, this.subtitle);

 final String title;
 final String subtitle;
}

class _RemediationTrack {
 const _RemediationTrack(this.label, this.progress, this.color);

 final String label;
 final double progress;
 final Color color;
}
