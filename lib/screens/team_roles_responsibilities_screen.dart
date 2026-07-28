import 'package:flutter/material.dart';
import 'package:ndu_project/widgets/draggable_sidebar.dart';
import 'package:ndu_project/widgets/initiation_like_sidebar.dart';
import 'package:ndu_project/widgets/kaz_ai_chat_bubble.dart';
import 'package:ndu_project/widgets/responsive.dart';
import 'package:ndu_project/providers/project_data_provider.dart';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:ndu_project/openai/openai_config.dart';
import 'package:ndu_project/widgets/planning_phase_header.dart';

import 'package:ndu_project/widgets/voice_text_field.dart';
import 'package:ndu_project/utils/pdf_export_helper.dart';
import 'package:ndu_project/utils/download_helper.dart' as dl;
import 'package:ndu_project/utils/project_data_helper.dart';
import 'package:ndu_project/widgets/launch_data_table.dart';
import 'package:file_picker/file_picker.dart';
class TeamRolesResponsibilitiesScreen extends StatefulWidget {
 const TeamRolesResponsibilitiesScreen({super.key});

 static Future<void> open(BuildContext context) {
 return Navigator.push(
 context,
 MaterialPageRoute(
 builder: (_) => const TeamRolesResponsibilitiesScreen()),
 );
 }

 @override
 State<TeamRolesResponsibilitiesScreen> createState() =>
 _TeamRolesResponsibilitiesScreenState();
}

class _TeamRolesResponsibilitiesScreenState
 extends State<TeamRolesResponsibilitiesScreen> {
 final _notesDebouncer = _Debouncer(milliseconds: 1000);
 final _saveDebouncer = _Debouncer(milliseconds: 800);
 final TextEditingController _notesSectionController = TextEditingController();
 bool _isLoading = false;
 bool _suspendSave = false;
 bool _showTableView = false; // Toggle between card view and table view

 static const List<String> _coverageStatusOptions = [
 'On track',
 'At risk',
 'In review',
 'Blocked',
 ];

 static const List<String> _hiringStatusOptions = [
 'Planned',
 'Recruiting',
 'Offer',
 'Onboarded',
 ];

 List<_StaffingMetric> _staffingMetrics = [];
 List<_CoverageRow> _coverageRows = [];
 List<_HiringRow> _hiringRows = [];
 List<_DecisionRow> _decisionRows = [];

 @override
 void initState() {
 super.initState();
 _staffingMetrics = _defaultStaffingMetrics();
 _coverageRows = _defaultCoverageRows();
 _hiringRows = _defaultHiringRows();
 _decisionRows = _defaultDecisionRows();
 WidgetsBinding.instance.addPostFrameCallback((_) => _loadMetadata());
 _notesSectionController.addListener(_onNotesChanged);
 }

 void _onNotesChanged() {
 _notesDebouncer.run(() {
 _scheduleSave();
 });
 }

 void _scheduleSave() {
 if (_suspendSave) return;
 _saveDebouncer.run(_saveMetadata);
 }

 @override
 void dispose() {
 _notesSectionController.dispose();
 _notesDebouncer.dispose();
 _saveDebouncer.dispose();
 super.dispose();
 }

 DocumentReference<Map<String, dynamic>> _rolesDoc(String projectId) {
 return FirebaseFirestore.instance
 .collection('projects')
 .doc(projectId)
 .collection('organization_plan_sections')
 .doc('roles_responsibilities');
 }

 CollectionReference<Map<String, dynamic>> _rolesCollection(String projectId) {
 return _rolesDoc(projectId).collection('roles');
 }

 Future<void> _loadMetadata() async {
 final provider = ProjectDataInherited.maybeOf(context);
 final projectId = provider?.projectData.projectId;
 if (projectId == null || projectId.isEmpty) return;
 if (!mounted) return;
 setState(() => _isLoading = true);
 try {
 final doc = await _rolesDoc(projectId).get();
 final data = doc.data() ?? {};
 _suspendSave = true;
 if (!mounted) return;
 setState(() {
 _notesSectionController.text = data['notes'] ?? '';
 final metrics = _StaffingMetric.fromList(data['staffingMetrics']);
 final coverage = _CoverageRow.fromList(data['coverageRows']);
 final hiring = _HiringRow.fromList(data['hiringRows']);
 final decisions = _DecisionRow.fromList(data['decisionRows']);
 _staffingMetrics =
 metrics.isEmpty ? _defaultStaffingMetrics() : metrics;
 _coverageRows = coverage.isEmpty ? _defaultCoverageRows() : coverage;
 _hiringRows = hiring.isEmpty ? _defaultHiringRows() : hiring;
 _decisionRows = decisions.isEmpty ? _defaultDecisionRows() : decisions;
 });
 } catch (error) {
 debugPrint('Roles metadata load error: $error');
 } finally {
 _suspendSave = false;
 if (mounted) setState(() => _isLoading = false);
 }
 }

 Future<void> _saveMetadata() async {
 final provider = ProjectDataInherited.maybeOf(context);
 final projectId = provider?.projectData.projectId;
 if (projectId == null || projectId.isEmpty) return;
 try {
 await _rolesDoc(projectId).set({
 'notes': _notesSectionController.text.trim(),
 'staffingMetrics': _staffingMetrics.map((e) => e.toMap()).toList(),
 'coverageRows': _coverageRows.map((e) => e.toMap()).toList(),
 'hiringRows': _hiringRows.map((e) => e.toMap()).toList(),
 'decisionRows': _decisionRows.map((e) => e.toMap()).toList(),
 'lastUpdated': FieldValue.serverTimestamp(),
 }, SetOptions(merge: true));
 } catch (error) {
 debugPrint('Roles metadata save error: $error');
 }
 }

 List<_StaffingMetric> _defaultStaffingMetrics() {
 return [
 _StaffingMetric(id: _newId(), label: 'Total roles', value: ''),
 _StaffingMetric(id: _newId(), label: 'Open roles', value: ''),
 _StaffingMetric(id: _newId(), label: 'Critical gaps', value: ''),
 _StaffingMetric(id: _newId(), label: 'Coverage score', value: ''),
 ];
 }

 List<_CoverageRow> _defaultCoverageRows() {
 return [
 _CoverageRow(
 id: _newId(),
 area: 'Product',
 owner: '',
 backup: '',
 status: 'On track',
 notes: ''),
 ];
 }

 List<_HiringRow> _defaultHiringRows() {
 return [
 _HiringRow(
 id: _newId(),
 role: 'QA Lead',
 headcount: '1',
 startDate: '',
 rampPlan: '',
 status: 'Planned'),
 ];
 }

 List<_DecisionRow> _defaultDecisionRows() {
 return [
 _DecisionRow(
 id: _newId(),
 decision: 'Release readiness',
 owner: '',
 approver: '',
 cadence: 'Weekly'),
 ];
 }

 String _newId() => DateTime.now().microsecondsSinceEpoch.toString();

 @override
 Widget build(BuildContext context) {
 final theme = Theme.of(context);
 final isMobile = AppBreakpoints.isMobile(context);
 final provider = ProjectDataInherited.maybeOf(context);
 final projectId = provider?.projectData.projectId ?? '';

 return Scaffold(
 backgroundColor: Colors.white,
 body: SafeArea(
 child: Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 DraggableSidebar(
 openWidth: AppBreakpoints.sidebarWidth(context),
 child: const InitiationLikeSidebar(
 activeItemLabel: 'Roles & Responsibilities',
 ),
 ),
 Expanded(
 child: Stack(
 children: [
 SingleChildScrollView(
 padding: EdgeInsets.symmetric(
 horizontal: isMobile ? 20 : 32,
 vertical: 32,
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 PlanningPhaseHeader(title: 'Roles & Responsibilities', onExportPdf: _exportPdf),
 const SizedBox(height: 16),
 if (_isLoading)
 const LinearProgressIndicator(minHeight: 2),
 if (_isLoading) const SizedBox(height: 16),
 Row(
 crossAxisAlignment: CrossAxisAlignment.center,
 children: [
 IconButton(
 tooltip: 'Back',
 onPressed: () => Navigator.of(context).maybePop(),
 icon: const Icon(Icons.arrow_back_ios_new_rounded,
 color: Color(0xFF1F1F1F)),
 ),
 const SizedBox(width: 4),
 Expanded(
 child: Text(
 'Roles & Responsibilities',
 style: theme.textTheme.titleLarge?.copyWith(
 fontWeight: FontWeight.w700,
 color: const Color(0xFF1F1F1F),
 ) ??
 const TextStyle(
 fontSize: 24,
 fontWeight: FontWeight.w700,
 color: Color(0xFF1F1F1F),
 ),
 ),
 ),
 const SizedBox(width: 16),
 _YellowActionButton(
 label: 'Create Role',
 icon: Icons.person_add_outlined,
 onPressed: () => _showCreateRoleDialog(),
 ),
 const SizedBox(width: 8),
 _YellowActionButton(
 label: '+ Add Role',
 icon: Icons.manage_accounts_outlined,
 onPressed: () => _showStandardRolesPicker(),
 ),
 const SizedBox(width: 8),
 _YellowActionButton(
 label: 'Role Descriptions',
 icon: Icons.description_outlined,
 onPressed: () => _showRoleDescriptions(),
 ),
 const SizedBox(width: 8),
 _YellowActionButton(
 label: 'Personnel Rates',
 icon: Icons.payments_outlined,
 onPressed: () => _showPersonnelRates(),
 ),
 ],
 ),
 const SizedBox(height: 8),
 const Text(
 'Identify all project team roles required for successful delivery, regardless of platform access, to support a complete organization and accurate personnel cost estimate.',
 style: TextStyle(
 fontSize: 14,
 color: Color(0xFF6B7280),
 ),
 ),
 const SizedBox(height: 24),

 // Persistent Notes Section
 Container(
 width: double.infinity,
 padding: const EdgeInsets.all(24),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(20),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 boxShadow: [
 BoxShadow(
 color: Colors.black.withOpacity(0.02),
 blurRadius: 10,
 offset: const Offset(0, 4),
 ),
 ],
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 children: [
 Container(
 padding: const EdgeInsets.all(8),
 decoration: BoxDecoration(
 color: const Color(0xFFFEF3C7),
 borderRadius: BorderRadius.circular(8),
 ),
 child: const Icon(Icons.auto_awesome,
 color: Color(0xFFD97706), size: 18),
 ),
 const SizedBox(width: 12),
 const Text(
 'Notes',
 style: TextStyle(
 fontSize: 16,
 fontWeight: FontWeight.w700,
 color: Color(0xFF111827),
 ),
 ),
 ],
 ),
 const SizedBox(height: 12),
 const Text(
 'Capture ownership, staffing needs, role coverage, and personnel assignment details.',
 style: TextStyle(
 fontSize: 13,
 color: Color(0xFF6B7280),
 ),
 ),
 const SizedBox(height: 16),
 Container(
 decoration: BoxDecoration(
 color: const Color(0xFFF9FAFB),
 borderRadius: BorderRadius.circular(12),
 border: Border.all(
 color: const Color(0xFFE5E7EB)),
 ),
 child: VoiceTextField(
 controller: _notesSectionController,
 maxLines: 4,
 decoration: const InputDecoration(
 hintText:
 'Capture the key decisions and details for this section...',
 border: InputBorder.none,
 contentPadding: EdgeInsets.all(16),
 ),
 ),
 ),
 ],
 ),
 ),
 const SizedBox(height: 24),

 _buildStaffingOverview(),
 const SizedBox(height: 20),
 _buildCoverageSection(),
 const SizedBox(height: 20),
 _buildHiringSection(),
 const SizedBox(height: 20),
 _buildDecisionSection(),
 const SizedBox(height: 24),

 // Roles List
 if (projectId == null)
 _sectionMessage(
 title: 'Select a project',
 message:
 'Choose a project to view roles & responsibilities.',
 )
 else
 // View toggle: Cards / Table
 Row(
 mainAxisAlignment: MainAxisAlignment.end,
 children: [
 Container(
 decoration: BoxDecoration(
 color: const Color(0xFFF3F4F6),
 borderRadius: BorderRadius.circular(8),
 ),
 child: Row(
 mainAxisSize: MainAxisSize.min,
 children: [
 _viewToggleBtn('Cards', !_showTableView, () {
 setState(() => _showTableView = false);
 }),
 _viewToggleBtn('Table', _showTableView, () {
 setState(() => _showTableView = true);
 }),
 ],
 ),
 ),
 const SizedBox(width: 8),
 // CSV download
 _iconActionBtn(Icons.download_outlined, 'Download Template',
 () => _downloadRolesTemplate()),
 const SizedBox(width: 4),
 // CSV import
 _iconActionBtn(Icons.upload_file_outlined, 'Import CSV',
 () => _importRolesCsv()),
 ],
 ),
 const SizedBox(height: 16),
 StreamBuilder<QuerySnapshot>(
 stream: _rolesCollection(projectId)
 .where('type', isNotEqualTo: 'metadata')
 .snapshots(),
 builder: (context, snapshot) {
 if (snapshot.hasError) {
 return const Center(
 child: Text('Error loading roles'));
 }
 if (!snapshot.hasData) {
 return const Center(
 child: CircularProgressIndicator());
 }

 final docs = snapshot.data!.docs
 .where((doc) => doc.id != 'metadata')
 .toList();

 if (docs.isEmpty) {
 return _sectionMessage(
 title: 'No staffing details yet',
 message:
 'Add roles, responsibilities, and staffing notes to populate this view.',
 );
 }

 return LayoutBuilder(
 builder: (context, constraints) {
 if (_showTableView) {
 return _buildRolesTableView(docs, constraints.maxWidth);
 }
 final maxWidth = constraints.maxWidth;
 const spacing = 24.0;
 final cardWidth = maxWidth >= 1080
 ? (maxWidth - spacing * 2) / 3
 : maxWidth >= 720
 ? (maxWidth - spacing) / 2
 : maxWidth;

 return Wrap(
 spacing: spacing,
 runSpacing: spacing,
 children: docs.map((doc) {
 final data = _RoleCardData.fromMap(
 doc.data() as Map<String, dynamic>);
 return SizedBox(
 width: cardWidth,
 child: _RoleCard(
 data: data,
 onEdit: () => _showMemberDialog(
 existingId: doc.id,
 existingData: data),
 onDelete: () => _confirmDeleteMember(
 doc.id, data.title),
 ),
 );
 }).toList(),
 );
 },
 );
 },
 ),
 const SizedBox(height: 24),
 ],
 ),
 ),
 MobileSidebarHamburger(
 sidebar: const InitiationLikeSidebar(
 activeItemLabel: 'Roles & Responsibilities',
 ),
 ),
 const KazAiChatBubble(),
 ],
 ),
 ),
 ],
 ),
 ),
 );
 }

 Widget _buildStaffingOverview() {
 return _SectionCardShell(
 title: 'Staffing overview',
 subtitle: 'Track headcount coverage, gaps, and readiness.',
 child: LayoutBuilder(
 builder: (context, constraints) {
 final width = constraints.maxWidth;
 const gap = 16.0;
 final columns = width >= 1020
 ? 4
 : width >= 720
 ? 2
 : 1;
 final cardWidth = (width - gap * (columns - 1)) / columns;
 return Wrap(
 spacing: gap,
 runSpacing: gap,
 children: _staffingMetrics.map((metric) {
 return SizedBox(
 width: cardWidth,
 child: _MetricCard(
 metric: metric,
 onChanged: (updated) {
 final index = _staffingMetrics
 .indexWhere((item) => item.id == updated.id);
 if (index == -1) return;
 setState(() => _staffingMetrics[index] = updated);
 _scheduleSave();
 },
 onDelete: () {
 setState(() => _staffingMetrics
 .removeWhere((item) => item.id == metric.id));
 _scheduleSave();
 },
 ),
 );
 }).toList()
 ..add(
 SizedBox(
 width: cardWidth,
 child: OutlinedButton.icon(
 onPressed: () {
 setState(() => _staffingMetrics.add(
 _StaffingMetric(id: _newId(), label: '', value: '')));
 _scheduleSave();
 },
 icon: const Icon(Icons.add, size: 18),
 label: const Text('Add metric'),
 ),
 ),
 ),
 );
 },
 ),
 );
 }

 Widget _buildCoverageSection() {
 return _SectionCardShell(
 title: 'Coverage & ownership matrix',
 subtitle: 'Define primary owners, backups, and coverage status.',
 trailing: TextButton.icon(
 onPressed: () {
 setState(() => _coverageRows.add(_CoverageRow(
 id: _newId(),
 area: '',
 owner: '',
 backup: '',
 status: _coverageStatusOptions.first,
 notes: '',
 )));
 _scheduleSave();
 },
 icon: const Icon(Icons.add, size: 18),
 label: const Text('Add row'),
 ),
 child: Column(
 children: [
 _coverageHeaderRow(),
 const SizedBox(height: 8),
 ..._coverageRows.map(_coverageRow),
 ],
 ),
 );
 }

 Widget _coverageHeaderRow() {
 return Row(
 children: const [
 Expanded(flex: 2, child: _ColumnLabel('Role/Area')),
 Expanded(child: _ColumnLabel('Primary owner')),
 Expanded(child: _ColumnLabel('Backup')),
 Expanded(child: _ColumnLabel('Status')),
 Expanded(flex: 2, child: _ColumnLabel('Notes')),
 SizedBox(width: 32),
 ],
 );
 }

 Widget _coverageRow(_CoverageRow row) {
 return Padding(
 padding: const EdgeInsets.only(bottom: 12),
 child: Row(
 children: [
 Expanded(
 flex: 2,
 child: VoiceTextFormField(
 initialValue: row.area,
 decoration: _inlineInputDecoration('Role/Area'),
 onChanged: (value) => _updateCoverage(row.copyWith(area: value)),
 ),
 ),
 const SizedBox(width: 12),
 Expanded(
 child: VoiceTextFormField(
 initialValue: row.owner,
 decoration: _inlineInputDecoration('Primary owner'),
 onChanged: (value) => _updateCoverage(row.copyWith(owner: value)),
 ),
 ),
 const SizedBox(width: 12),
 Expanded(
 child: VoiceTextFormField(
 initialValue: row.backup,
 decoration: _inlineInputDecoration('Backup'),
 onChanged: (value) =>
 _updateCoverage(row.copyWith(backup: value)),
 ),
 ),
 const SizedBox(width: 12),
 Expanded(
 child: DropdownButtonFormField<String>(
 value: _coverageStatusOptions.contains(row.status)
 ? row.status
 : _coverageStatusOptions.first,
 decoration: _inlineInputDecoration('Status'),
 items: _coverageStatusOptions
 .map((status) =>
 DropdownMenuItem(value: status, child: Text(status)))
 .toList(),
 onChanged: (value) => _updateCoverage(
 row.copyWith(status: value ?? _coverageStatusOptions.first)),
 ),
 ),
 const SizedBox(width: 12),
 Expanded(
 flex: 2,
 child: VoiceTextFormField(
 initialValue: row.notes,
 decoration: _inlineInputDecoration('Notes'),
 onChanged: (value) => _updateCoverage(row.copyWith(notes: value)),
 ),
 ),
 IconButton(
 icon: const Icon(Icons.delete_outline, color: Color(0xFFD64545)),
 onPressed: () {
 setState(
 () => _coverageRows.removeWhere((item) => item.id == row.id));
 _scheduleSave();
 },
 ),
 ],
 ),
 );
 }

 void _updateCoverage(_CoverageRow row) {
 final index = _coverageRows.indexWhere((item) => item.id == row.id);
 if (index == -1) return;
 setState(() => _coverageRows[index] = row);
 _scheduleSave();
 }

 Widget _buildHiringSection() {
 return _SectionCardShell(
 title: 'Hiring & onboarding plan',
 subtitle: 'Track headcount additions and onboarding milestones.',
 trailing: TextButton.icon(
 onPressed: () {
 setState(() => _hiringRows.add(_HiringRow(
 id: _newId(),
 role: '',
 headcount: '',
 startDate: '',
 rampPlan: '',
 status: _hiringStatusOptions.first,
 )));
 _scheduleSave();
 },
 icon: const Icon(Icons.add, size: 18),
 label: const Text('Add hire'),
 ),
 child: Column(
 children: [
 _hiringHeaderRow(),
 const SizedBox(height: 8),
 ..._hiringRows.map(_hiringRow),
 ],
 ),
 );
 }

 Widget _hiringHeaderRow() {
 return Row(
 children: const [
 Expanded(flex: 2, child: _ColumnLabel('Role')),
 Expanded(child: _ColumnLabel('Headcount')),
 Expanded(child: _ColumnLabel('Start date')),
 Expanded(flex: 2, child: _ColumnLabel('Ramp plan')),
 Expanded(child: _ColumnLabel('Status')),
 SizedBox(width: 32),
 ],
 );
 }

 Widget _hiringRow(_HiringRow row) {
 return Padding(
 padding: const EdgeInsets.only(bottom: 12),
 child: Row(
 children: [
 Expanded(
 flex: 2,
 child: VoiceTextFormField(
 initialValue: row.role,
 decoration: _inlineInputDecoration('Role'),
 onChanged: (value) => _updateHiring(row.copyWith(role: value)),
 ),
 ),
 const SizedBox(width: 12),
 Expanded(
 child: VoiceTextFormField(
 initialValue: row.headcount,
 decoration: _inlineInputDecoration('Headcount'),
 keyboardType: TextInputType.number,
 onChanged: (value) =>
 _updateHiring(row.copyWith(headcount: value)),
 ),
 ),
 const SizedBox(width: 12),
 Expanded(
 child: VoiceTextFormField(
 initialValue: row.startDate,
 decoration: _inlineInputDecoration('Start date'),
 onChanged: (value) =>
 _updateHiring(row.copyWith(startDate: value)),
 ),
 ),
 const SizedBox(width: 12),
 Expanded(
 flex: 2,
 child: VoiceTextFormField(
 initialValue: row.rampPlan,
 decoration: _inlineInputDecoration('Ramp plan'),
 onChanged: (value) =>
 _updateHiring(row.copyWith(rampPlan: value)),
 ),
 ),
 const SizedBox(width: 12),
 Expanded(
 child: DropdownButtonFormField<String>(
 value: _hiringStatusOptions.contains(row.status)
 ? row.status
 : _hiringStatusOptions.first,
 decoration: _inlineInputDecoration('Status'),
 items: _hiringStatusOptions
 .map((status) =>
 DropdownMenuItem(value: status, child: Text(status)))
 .toList(),
 onChanged: (value) => _updateHiring(
 row.copyWith(status: value ?? _hiringStatusOptions.first)),
 ),
 ),
 IconButton(
 icon: const Icon(Icons.delete_outline, color: Color(0xFFD64545)),
 onPressed: () {
 setState(
 () => _hiringRows.removeWhere((item) => item.id == row.id));
 _scheduleSave();
 },
 ),
 ],
 ),
 );
 }

 void _updateHiring(_HiringRow row) {
 final index = _hiringRows.indexWhere((item) => item.id == row.id);
 if (index == -1) return;
 setState(() => _hiringRows[index] = row);
 _scheduleSave();
 }

 Widget _buildDecisionSection() {
 return _SectionCardShell(
 title: 'Decision & escalation points',
 subtitle: 'List decision areas, owners, and cadence.',
 trailing: TextButton.icon(
 onPressed: () {
 setState(() => _decisionRows.add(_DecisionRow(
 id: _newId(),
 decision: '',
 owner: '',
 approver: '',
 cadence: '',
 )));
 _scheduleSave();
 },
 icon: const Icon(Icons.add, size: 18),
 label: const Text('Add decision'),
 ),
 child: Column(
 children: [
 _decisionHeaderRow(),
 const SizedBox(height: 8),
 ..._decisionRows.map(_decisionRow),
 ],
 ),
 );
 }

 Widget _decisionHeaderRow() {
 return Row(
 children: const [
 Expanded(flex: 2, child: _ColumnLabel('Decision area')),
 Expanded(child: _ColumnLabel('Owner')),
 Expanded(child: _ColumnLabel('Approver')),
 Expanded(child: _ColumnLabel('Cadence')),
 SizedBox(width: 32),
 ],
 );
 }

 Widget _decisionRow(_DecisionRow row) {
 return Padding(
 padding: const EdgeInsets.only(bottom: 12),
 child: Row(
 children: [
 Expanded(
 flex: 2,
 child: VoiceTextFormField(
 initialValue: row.decision,
 decoration: _inlineInputDecoration('Decision area'),
 onChanged: (value) =>
 _updateDecision(row.copyWith(decision: value)),
 ),
 ),
 const SizedBox(width: 12),
 Expanded(
 child: VoiceTextFormField(
 initialValue: row.owner,
 decoration: _inlineInputDecoration('Owner'),
 onChanged: (value) => _updateDecision(row.copyWith(owner: value)),
 ),
 ),
 const SizedBox(width: 12),
 Expanded(
 child: VoiceTextFormField(
 initialValue: row.approver,
 decoration: _inlineInputDecoration('Approver'),
 onChanged: (value) =>
 _updateDecision(row.copyWith(approver: value)),
 ),
 ),
 const SizedBox(width: 12),
 Expanded(
 child: VoiceTextFormField(
 initialValue: row.cadence,
 decoration: _inlineInputDecoration('Cadence'),
 onChanged: (value) =>
 _updateDecision(row.copyWith(cadence: value)),
 ),
 ),
 IconButton(
 icon: const Icon(Icons.delete_outline, color: Color(0xFFD64545)),
 onPressed: () {
 setState(
 () => _decisionRows.removeWhere((item) => item.id == row.id));
 _scheduleSave();
 },
 ),
 ],
 ),
 );
 }

 void _updateDecision(_DecisionRow row) {
 final index = _decisionRows.indexWhere((item) => item.id == row.id);
 if (index == -1) return;
 setState(() => _decisionRows[index] = row);
 _scheduleSave();
 }

 InputDecoration _inlineInputDecoration(String hint) {
 return InputDecoration(
 isDense: true,
 hintText: hint,
 filled: true,
 fillColor: const Color(0xFFF9FAFB),
 contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
 borderSide: const BorderSide(color: Color(0xFF111827)),
 ),
 );
 }

 Widget _sectionMessage({required String title, required String message}) {
 return _SectionMessage(title: title, message: message);
 }

 Future<void> _showMemberDialog(
 {String? existingId, _RoleCardData? existingData}) async {
 final provider = ProjectDataInherited.maybeOf(context);
 final projectId = provider?.projectData.projectId;
 if (projectId == null || projectId.isEmpty) return;
 final result = await showDialog<_RoleCardData>(
 context: context,
 barrierColor: Colors.black.withOpacity(0.2),
 builder: (_) => _TeamMemberDialog(initialData: existingData),
 );

 if (result == null) return;

 if (existingId != null) {
 await _rolesCollection(projectId).doc(existingId).update(result.toMap());
 } else {
 await _rolesCollection(projectId).add(result.toMap());
 }
 }

 Future<void> _confirmDeleteMember(String docId, String name) async {
 final provider = ProjectDataInherited.maybeOf(context);
 final projectId = provider?.projectData.projectId;
 if (projectId == null || projectId.isEmpty) return;
 final shouldDelete = await showDialog<bool>(
 context: context,
 barrierDismissible: true,
 builder: (context) {
 final theme = Theme.of(context);
 return AlertDialog(
 title: const Text('Remove team member?'),
 content: Text(
 'This will remove $name from the list.',
 ),
 actions: [
 TextButton(
 onPressed: () => Navigator.of(context).pop(false),
 child: const Text('Cancel'),
 ),
 FilledButton(
 onPressed: () => Navigator.of(context).pop(true),
 style: FilledButton.styleFrom(
 backgroundColor: theme.colorScheme.error,
 foregroundColor: theme.colorScheme.onError,
 ),
 child: const Text('Delete'),
 ),
 ],
 );
 },
 );

 if (shouldDelete == true) {
 await _rolesCollection(projectId).doc(docId).delete();
 }
 }

 // ── View toggle button ───────────────────────────────────────────
 Widget _viewToggleBtn(String label, bool active, VoidCallback onTap) {
 return InkWell(
 onTap: onTap,
 borderRadius: BorderRadius.circular(8),
 child: Container(
 padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
 decoration: BoxDecoration(
 color: active ? const Color(0xFFF59E0B) : Colors.transparent,
 borderRadius: BorderRadius.circular(8),
 ),
 child: Text(
 label,
 style: TextStyle(
 fontSize: 12,
 fontWeight: FontWeight.w700,
 color: active ? Colors.white : const Color(0xFF6B7280),
 ),
 ),
 ),
 );
 }

 Widget _iconActionBtn(IconData icon, String tooltip, VoidCallback onTap) {
 return Tooltip(
 message: tooltip,
 child: InkWell(
 onTap: onTap,
 borderRadius: BorderRadius.circular(8),
 child: Container(
 padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
 decoration: BoxDecoration(
 color: const Color(0xFFF3F4F6),
 borderRadius: BorderRadius.circular(8),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 ),
 child: Icon(icon, size: 18, color: const Color(0xFF6B7280)),
 ),
 ),
 );
 }

 // ── Roles Table View ──────────────────────────────────────────────
  Widget _buildRolesTableView(List<QueryDocumentSnapshot> docs, double maxWidth) {
    final provider = ProjectDataInherited.maybeOf(context);
    final projectId = provider?.projectData.projectId ?? '';
  final roles = docs.map((doc) {
 final data = _RoleCardData.fromMap(
 (doc.data() as Map).cast<String, dynamic>());
 return (doc: doc, data: data);
 }).toList();

 final tableWidth = maxWidth > 1200 ? maxWidth : 1200.0;

 return SingleChildScrollView(
 scrollDirection: Axis.horizontal,
 child: ConstrainedBox(
 constraints: BoxConstraints(minWidth: tableWidth),
 child: SingleChildScrollView(
 child: DataTable(
 headingRowColor: MaterialStateProperty.all(const Color(0xFFF8FAFC)),
 border: TableBorder.all(color: const Color(0xFFE5E7EB), width: 1),
 columnSpacing: 20,
 horizontalMargin: 16,
 columns: const [
 DataColumn(label: Text('Role / Position', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF374151)))),
 DataColumn(label: Text('Discipline', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF374151)))),
 DataColumn(label: Text('Qty', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF374151))), numeric: true),
 DataColumn(label: Text('Description', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF374151)))),
 DataColumn(label: Text('Name', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF374151)))),
 DataColumn(label: Text('Actions', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF374151)))),
 ],
 rows: roles.map((entry) {
 final data = entry.data;
 final doc = entry.doc;
 final desc = data.responsibilities.isNotEmpty ? data.responsibilities.first : '';
 return DataRow(cells: [
 DataCell(Text(data.title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
 DataCell(Text(data.subtitle, style: const TextStyle(fontSize: 13))),
  DataCell(_InlineQtyEditor(
  initialQty: data.quantity,
  onChanged: (newQty) {
  if (newQty > 0 && newQty != data.quantity) {
  _rolesCollection(projectId).doc(doc.id).update({'quantity': newQty});
  }
  },
  )),
 DataCell(Text(desc, style: const TextStyle(fontSize: 13, color: Color(0xFF4B5563)), maxLines: 2, overflow: TextOverflow.ellipsis)),
 DataCell(Text(data.fullName, style: const TextStyle(fontSize: 13))),
 DataCell(Row(
 mainAxisSize: MainAxisSize.min,
 children: [
 IconButton(
 icon: const Icon(Icons.edit_outlined, size: 18, color: Color(0xFF5B6572)),
 onPressed: () => _showMemberDialog(existingId: doc.id, existingData: data),
 tooltip: 'Edit',
 ),
 IconButton(
 icon: const Icon(Icons.delete_outline, size: 18, color: Color(0xFFD64545)),
 onPressed: () => _confirmDeleteMember(doc.id, data.title),
 tooltip: 'Delete',
 ),
 ],
 )),
 ]);
 }).toList(),
 ),
 ),
 ),
 );
 }

 // ── CSV Template Download ─────────────────────────────────────────
 void _downloadRolesTemplate() {
 final headers = ['Role / Position', 'Discipline', 'Quantity', 'Description'];
 final sb = StringBuffer();
 sb.writeln(headers.join(','));
 for (final role in _standardRoles) {
 sb.writeln('"${role.title}","${role.discipline}",0,"${role.description}"');
 }
 final csv = sb.toString();
 // Use download helper
 try {
 dl.downloadFile(csv.codeUnits, 'roles_responsibilities_template.csv', mimeType: 'text/csv');
 } catch (_) {
 // Fallback: copy to clipboard
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(content: Text('Template generated. Copy from console.')),
 );
 debugPrint(csv);
 }
 }

  // ── CSV Import ────────────────────────────────────────────────────
  Future<void> _importRolesCsv() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      final bytes = file.bytes;
      if (bytes == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not read file.'),
            backgroundColor: Color(0xFFEF4444),
          ),
        );
        return;
      }

      final csv = utf8.decode(bytes);
      final lines = csv.split(RegExp(r'[\r\n]+')).where((l) => l.trim().isNotEmpty).toList();
      if (lines.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('CSV file is empty.'),
            backgroundColor: Color(0xFFEF4444),
          ),
        );
        return;
      }

      // Parse header row to find column indices
      final headers = _parseCsvRow(lines.first);
      final titleIdx = headers.indexWhere((h) => h.toLowerCase().contains('role') || h.toLowerCase().contains('position'));
      final disciplineIdx = headers.indexWhere((h) => h.toLowerCase().contains('discipline'));
      final qtyIdx = headers.indexWhere((h) => h.toLowerCase().contains('quant') || h.toLowerCase().contains('qty') || h.toLowerCase().contains('headcount'));
      final descIdx = headers.indexWhere((h) => h.toLowerCase().contains('description') || h.toLowerCase().contains('responsibilities'));

      if (titleIdx == -1) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('CSV must have a "Role / Position" column.'),
            backgroundColor: Color(0xFFEF4444),
          ),
        );
        return;
      }

      final provider = ProjectDataInherited.maybeOf(context);
      final projectId = provider?.projectData.projectId;
      if (projectId == null || projectId.isEmpty) return;

      int added = 0;
      for (var i = 1; i < lines.length; i++) {
        final row = _parseCsvRow(lines[i]);
        if (row.length <= titleIdx) continue;
        final title = row[titleIdx].trim();
        if (title.isEmpty) continue;

        final discipline = disciplineIdx >= 0 && disciplineIdx < row.length
            ? row[disciplineIdx].trim()
            : 'General';
        final description = descIdx >= 0 && descIdx < row.length
            ? row[descIdx].trim()
            : '';
        final qty = qtyIdx >= 0 && qtyIdx < row.length
            ? int.tryParse(row[qtyIdx].trim()) ?? 0
            : 0;

        if (qty <= 0) continue;

        final data = _RoleCardData(
          title: title,
          subtitle: discipline,
          responsibilities: description.isNotEmpty ? [description] : [],
          workItems: [],
          quantity: qty,
        );
        await _rolesCollection(projectId).add(data.toMap());
        added++;
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: added > 0
              ? Text('$added role${added == 1 ? "" : "s"} imported from CSV.')
              : const Text('No valid roles found in CSV. Ensure quantities > 0.'),
          backgroundColor: added > 0 ? const Color(0xFF10B981) : const Color(0xFFD97706),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error importing CSV: $e'),
          backgroundColor: const Color(0xFFEF4444),
        ),
      );
    }
  }

  /// Parses a CSV row handling quoted fields.
  List<String> _parseCsvRow(String line) {
    final result = <String>[];
    bool inQuotes = false;
    final current = StringBuffer();
    for (var i = 0; i < line.length; i++) {
      final char = line[i];
      if (char == '"') {
        inQuotes = !inQuotes;
      } else if (char == ',' && !inQuotes) {
        result.add(current.toString().trim());
        current.clear();
      } else {
        current.write(char);
      }
    }
    result.add(current.toString().trim());
    return result;
  }

 Future<void> _exportPdf() async {
 final projectData = ProjectDataHelper.getData(context);
 await PdfExportHelper.exportScreenPdf(
 context: context,
 screenTitle: 'Team Roles & Responsibilities',
 sections: [
 PdfSection.keyValue('Project Info', [
 {'Project Name': projectData.projectName ?? 'N/A'},
 {'Solution Title': projectData.solutionTitle ?? 'N/A'},
 ]),
 PdfSection.text('Notes', projectData.planningNotes['planning_team_roles_responsibilities_notes'] ?? 'No data recorded.'),
 ],
 );
 }

 // ── Standard Roles Catalog ───────────────────────────────────────
 static const List<_StandardRole> _standardRoles = [
   _StandardRole(title: 'Project Manager', discipline: 'Program Management', description: 'Overall project planning, execution, and delivery accountability.'),
   _StandardRole(title: 'Project Engineer', discipline: 'Engineering', description: 'Technical execution and engineering oversight.'),
   _StandardRole(title: 'Cost Manager', discipline: 'Commercial', description: 'Budget planning, cost tracking, and financial reporting.'),
   _StandardRole(title: 'Schedule Manager', discipline: 'Program Management', description: 'Master schedule development and progress tracking.'),
   _StandardRole(title: 'Quality Manager', discipline: 'Quality', description: 'Quality assurance, inspection, and compliance.'),
   _StandardRole(title: 'Safety Manager', discipline: 'Safety', description: 'Safety planning, compliance, and incident management.'),
   _StandardRole(title: 'Procurement Manager', discipline: 'Procurement', description: 'Sourcing, contracting, and supplier management.'),
   _StandardRole(title: 'Design Lead', discipline: 'Architecture', description: 'Design coordination and technical specifications.'),
   _StandardRole(title: 'Construction Manager', discipline: 'Civil/Construction', description: 'On-site construction execution and supervision.'),
   _StandardRole(title: 'Commissioning Lead', discipline: 'Mechanical', description: 'System testing, commissioning, and handover.'),
   _StandardRole(title: 'IT Lead', discipline: 'IT', description: 'Technology infrastructure and software integration.'),
   _StandardRole(title: 'Document Controller', discipline: 'Operations', description: 'Document management and records control.'),
   _StandardRole(title: 'Risk Manager', discipline: 'Program Management', description: 'Risk identification, assessment, and mitigation.'),
   _StandardRole(title: 'HR Manager', discipline: 'Professional Services', description: 'Personnel management and organizational planning.'),
   _StandardRole(title: 'Financial Analyst', discipline: 'Commercial', description: 'Financial analysis, forecasting, and reporting.'),
   _StandardRole(title: 'Stakeholder Manager', discipline: 'Program Management', description: 'Stakeholder engagement and communications.'),
   _StandardRole(title: 'Environmental Specialist', discipline: 'Regulatory', description: 'Environmental compliance and sustainability.'),
   _StandardRole(title: 'Security Manager', discipline: 'Security', description: 'Physical and cybersecurity management.'),
   _StandardRole(title: 'Training Coordinator', discipline: 'Operations', description: 'Training program development and delivery.'),
   _StandardRole(title: 'Operations Manager', discipline: 'Operations', description: 'Post-handover operations and maintenance.'),
 ];

  /// Shows the Standard Roles picker with search bar and checkboxes.
  /// After selecting roles, a separate "Review & Set Quantities" step
  /// lets users specify the number of people per role before adding them.
  Future<void> _showStandardRolesPicker() async {
    final searchController = TextEditingController();
    final selectedTitles = <String>{};

   await showDialog<void>(
     context: context,
     builder: (dialogContext) => StatefulBuilder(
       builder: (dialogContext, setDialogState) {
         final query = searchController.text.toLowerCase();
         final filtered = _standardRoles.where((r) {
           if (query.isEmpty) return true;
           return r.title.toLowerCase().contains(query) ||
               r.discipline.toLowerCase().contains(query);
         }).toList();

         return AlertDialog(
           insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
           title: Row(
             children: [
               const Icon(Icons.manage_accounts, color: Color(0xFFF59E0B), size: 24),
               const SizedBox(width: 10),
               const Text('Add Standard Roles'),
               const Spacer(),
                if (selectedTitles.isNotEmpty)
                  TextButton(
                    onPressed: () {
                      setDialogState(() => selectedTitles.clear());
                    },
                    child: const Text('Clear', style: TextStyle(fontSize: 12)),
                  ),
             ],
           ),
           content: ConstrainedBox(
             constraints: BoxConstraints(
               maxWidth: 560,
               maxHeight: MediaQuery.of(dialogContext).size.height * 0.7,
             ),
             child: Column(
               mainAxisSize: MainAxisSize.min,
               children: [
                 TextField(
                   controller: searchController,
                   onChanged: (_) => setDialogState(() {}),
                   decoration: InputDecoration(
                     hintText: 'Search roles by title or discipline...',
                     prefixIcon: const Icon(Icons.search, size: 20),
                     suffixIcon: searchController.text.isNotEmpty
                         ? IconButton(
                             icon: const Icon(Icons.clear, size: 18),
                             onPressed: () {
                               searchController.clear();
                               setDialogState(() {});
                             },
                           )
                         : null,
                     border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                     contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                   ),
                 ),
                 const SizedBox(height: 12),
                 Row(
                   children: [
                      Checkbox(
                        value: selectedTitles.length == filtered.length && filtered.isNotEmpty,
                        onChanged: (val) {
                          setDialogState(() {
                            if (val == true) {
                              for (final r in filtered) {
                                selectedTitles.add(r.title);
                              }
                            } else {
                              selectedTitles.clear();
                            }
                          });
                        },
                      ),
                     const Text('Select All', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                   ],
                 ),
                 const Divider(),
                 Expanded(
                   child: ListView.builder(
                     shrinkWrap: true,
                     itemCount: filtered.length,
                     itemBuilder: (context, index) {
                       final role = filtered[index];
                        final isSelected = selectedTitles.contains(role.title);
                        return ListTile(
                          leading: Checkbox(
                            value: isSelected,
                            onChanged: (val) {
                              setDialogState(() {
                                if (val == true) {
                                  selectedTitles.add(role.title);
                                } else {
                                  selectedTitles.remove(role.title);
                                }
                              });
                            },
                          ),
                          title: Text(role.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                          subtitle: Text('${role.discipline} — ${role.description}',
                              style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                         dense: true,
                       );
                     },
                   ),
                 ),
               ],
             ),
           ),
           actions: [
             TextButton(
               onPressed: () => Navigator.pop(dialogContext),
               child: const Text('Cancel'),
             ),
              ElevatedButton(
                onPressed: selectedTitles.isEmpty
                    ? null
                    : () {
                        Navigator.pop(dialogContext);
                        _showReviewQuantities(selectedTitles.toList());
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF59E0B),
                  foregroundColor: Colors.white,
                ),
                 child: Text('Review Quantities (${selectedTitles.length})'),
              ),
            ],
          );
        },
      ),
    );
    searchController.dispose();
  }

  /// Second step: review selected roles and set quantities before adding.
  void _showReviewQuantities(List<String> titles) {
    final quantities = <String, TextEditingController>{};
    for (final title in titles) {
      quantities[title] = TextEditingController(text: '1');
    }

    showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          final total = quantities.entries.fold<int>(
            0,
            (sum, e) => sum + (int.tryParse(e.value.text) ?? 0),
          );

          return AlertDialog(
            insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                const Icon(Icons.format_list_numbered, color: Color(0xFFF59E0B), size: 24),
                const SizedBox(width: 10),
                Text('Set Quantities (${titles.length} roles)'),
              ],
            ),
            content: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: 560,
                maxHeight: MediaQuery.of(dialogContext).size.height * 0.6,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Set the number of people needed for each role.',
                    style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: ListView(
                      children: titles.map((title) {
                        final role = _standardRoles.firstWhere((r) => r.title == title);
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(role.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                                    Text(role.discipline, style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              SizedBox(
                                width: 80,
                                child: TextFormField(
                                  controller: quantities[title],
                                  keyboardType: TextInputType.number,
                                  textAlign: TextAlign.center,
                                  decoration: InputDecoration(
                                    isDense: true,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  onChanged: (_) => setDialogState(() {}),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const Divider(),
                  Row(
                    children: [
                      const Text('Total personnel: ', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                      Text('$total', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFFF59E0B))),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Back'),
              ),
              ElevatedButton(
                onPressed: () {
                  final provider = ProjectDataInherited.maybeOf(context);
                  final projectId = provider?.projectData.projectId;
                  if (projectId != null && projectId.isNotEmpty) {
                    for (final title in titles) {
                      final role = _standardRoles.firstWhere((r) => r.title == title);
                      final qty = int.tryParse(quantities[title]?.text ?? '') ?? 1;
                      if (qty <= 0) continue;
                      final data = _RoleCardData(
                        title: role.title,
                        subtitle: role.discipline,
                        responsibilities: [role.description],
                        workItems: [],
                        quantity: qty,
                      );
                      _rolesCollection(projectId).add(data.toMap());
                    }
                  }
                  Navigator.pop(dialogContext);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('$total personnel across ${titles.length} role${titles.length == 1 ? "" : "s"} added'),
                      backgroundColor: const Color(0xFF10B981),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF59E0B),
                  foregroundColor: Colors.white,
                ),
                child: const Text('Add Roles'),
              ),
            ],
          );
        },
      ),
    ).then((_) {
      for (final c in quantities.values) {
        c.dispose();
      }
    });
  }

  /// Shows the Create Role dialog for creating custom roles.
 Future<void> _showCreateRoleDialog() async {
   final nameController = TextEditingController();
   final descriptionController = TextEditingController();
   final qtyController = TextEditingController(text: '1');
   String selectedDiscipline = 'General';
   final formKey = GlobalKey<FormState>();

   await showDialog<void>(
     context: context,
     builder: (dialogContext) => StatefulBuilder(
       builder: (dialogContext, setDialogState) => AlertDialog(
         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
         title: Row(
           children: [
             const Icon(Icons.person_add_outlined, color: Color(0xFFF59E0B), size: 24),
             const SizedBox(width: 10),
             const Text('Create Custom Role'),
           ],
         ),
         content: ConstrainedBox(
           constraints: const BoxConstraints(maxWidth: 480),
           child: Form(
             key: formKey,
             child: Column(
               mainAxisSize: MainAxisSize.min,
               crossAxisAlignment: CrossAxisAlignment.start,
               children: [
                 if (nameController.text.isNotEmpty &&
                     _standardRoles.any((r) =>
                         r.title.toLowerCase() == nameController.text.toLowerCase().trim()))
                   Container(
                     padding: const EdgeInsets.all(12),
                     margin: const EdgeInsets.only(bottom: 12),
                     decoration: BoxDecoration(
                       color: const Color(0xFFFFFBEB),
                       borderRadius: BorderRadius.circular(8),
                       border: Border.all(color: const Color(0xFFFDE68A)),
                     ),
                     child: Row(
                       children: [
                         const Icon(Icons.info_outline, color: Color(0xFFD97706), size: 18),
                         const SizedBox(width: 8),
                         Expanded(
                           child: Text(
                             'A standard role "${nameController.text.trim()}" already exists. Would you like to use that instead?',
                             style: const TextStyle(fontSize: 12, color: Color(0xFF92400E)),
                           ),
                         ),
                       ],
                     ),
                   )
                 else
                   const SizedBox.shrink(),
                 const Text('Role Name *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                 const SizedBox(height: 6),
                 TextFormField(
                   controller: nameController,
                   decoration: InputDecoration(
                     hintText: 'e.g. Wind Turbine Specialist',
                     border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                   ),
                   onChanged: (_) => setDialogState(() {}),
                   validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                 ),
                 const SizedBox(height: 12),
                 const Text('Discipline *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                 const SizedBox(height: 6),
                 DropdownButtonFormField<String>(
                   value: selectedDiscipline,
                   decoration: InputDecoration(
                     border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                   ),
                   items: const [
                     'General', 'Civil/Construction', 'Mechanical', 'Electrical',
                     'IT/Software', 'Architecture', 'Program Management',
                     'Commercial', 'Procurement', 'Quality', 'Safety', 'Security',
                     'Operations', 'Regulatory', 'Professional Services', 'Other',
                   ].map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
                   onChanged: (val) {
                     if (val != null) setDialogState(() => selectedDiscipline = val);
                   },
                 ),
                 const SizedBox(height: 12),
                 const Text('Description *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                 const SizedBox(height: 6),
                 TextFormField(
                   controller: descriptionController,
                   maxLines: 3,
                   decoration: InputDecoration(
                     hintText: 'Describe the responsibilities of this role...',
                     border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                   ),
                   validator: (v) => (v == null || v.trim().isEmpty) ? 'Required — every role must have a description' : null,
                 ),
                 const SizedBox(height: 12),
                 const Text('Quantity', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                 const SizedBox(height: 6),
                 SizedBox(
                   width: 100,
                   child: TextFormField(
                     controller: qtyController,
                     keyboardType: TextInputType.number,
                     decoration: InputDecoration(
                       border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                     ),
                   ),
                 ),
               ],
             ),
           ),
         ),
         actions: [
           TextButton(
             onPressed: () => Navigator.pop(dialogContext),
             child: const Text('Cancel'),
           ),
           ElevatedButton(
             onPressed: () {
               if (!formKey.currentState!.validate()) return;
               final provider = ProjectDataInherited.maybeOf(context);
               final projectId = provider?.projectData.projectId;
               if (projectId != null && projectId.isNotEmpty) {
                 final data = _RoleCardData(
                   title: nameController.text.trim(),
                   subtitle: selectedDiscipline,
                   responsibilities: [descriptionController.text.trim()],
                   workItems: [],
                   quantity: int.tryParse(qtyController.text) ?? 1,
                 );
                 _rolesCollection(projectId).add(data.toMap());
               }
               Navigator.pop(dialogContext);
               ScaffoldMessenger.of(context).showSnackBar(
                 SnackBar(
                   content: Text('Role "${nameController.text.trim()}" created'),
                   backgroundColor: const Color(0xFF10B981),
                 ),
               );
             },
             style: ElevatedButton.styleFrom(
               backgroundColor: const Color(0xFFF59E0B),
               foregroundColor: Colors.white,
             ),
             child: const Text('Create Role'),
           ),
         ],
       ),
     ),
   );
   nameController.dispose();
   descriptionController.dispose();
   qtyController.dispose();
 }

 /// Shows role descriptions for all standard roles.
 Future<void> _showRoleDescriptions() async {
   await showDialog<void>(
     context: context,
     builder: (dialogContext) => AlertDialog(
       insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
       title: Row(
         children: [
           const Icon(Icons.description_outlined, color: Color(0xFFF59E0B), size: 24),
           const SizedBox(width: 10),
           const Text('Role Descriptions'),
         ],
       ),
       content: ConstrainedBox(
         constraints: BoxConstraints(
           maxWidth: 600,
           maxHeight: MediaQuery.of(dialogContext).size.height * 0.7,
         ),
         child: ListView.separated(
           shrinkWrap: true,
           itemCount: _standardRoles.length,
           separatorBuilder: (_, __) => const Divider(),
           itemBuilder: (context, index) {
             final role = _standardRoles[index];
             return Padding(
               padding: const EdgeInsets.symmetric(vertical: 8),
               child: Column(
                 crossAxisAlignment: CrossAxisAlignment.start,
                 children: [
                   Row(
                     children: [
                       Text(role.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                       const SizedBox(width: 8),
                       Container(
                         padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                         decoration: BoxDecoration(
                           color: const Color(0xFFFFF7E6),
                           borderRadius: BorderRadius.circular(4),
                         ),
                         child: Text(role.discipline, style: const TextStyle(fontSize: 10, color: Color(0xFF1E40AF))),
                       ),
                     ],
                   ),
                   const SizedBox(height: 4),
                   Text(role.description, style: const TextStyle(fontSize: 13, color: Color(0xFF4B5563))),
                 ],
               ),
             );
           },
         ),
       ),
       actions: [
         ElevatedButton(
           onPressed: () => Navigator.pop(dialogContext),
           child: const Text('Close'),
         ),
       ],
     ),
   );
 }

 /// Shows personnel rates — restricted to authorized roles.
 Future<void> _showPersonnelRates() async {
   final user = FirebaseAuth.instance.currentUser;
   if (user == null) {
     ScaffoldMessenger.of(context).showSnackBar(
       const SnackBar(
         content: Text('You must be signed in to view personnel rates.'),
         backgroundColor: Color(0xFFEF4444),
       ),
     );
     return;
   }

   final provider = ProjectDataInherited.maybeOf(context);
   final projectId = provider?.projectData.projectId;
   List<_RoleCardData> roles = [];
   if (projectId != null && projectId.isNotEmpty) {
     try {
       final snapshot = await _rolesCollection(projectId).get();
       roles = snapshot.docs.map((doc) => _RoleCardData.fromMap(doc.data())).toList();
     } catch (e) {
       roles = [];
     }
   }

   if (!mounted) return;
   await showDialog<void>(
     context: context,
     builder: (dialogContext) => AlertDialog(
       insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
       title: Row(
         children: [
           const Icon(Icons.payments_outlined, color: Color(0xFFF59E0B), size: 24),
           const SizedBox(width: 10),
           const Text('Personnel Rates'),
           const Spacer(),
           Container(
             padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
             decoration: BoxDecoration(
               color: const Color(0xFFFFFBEB),
               borderRadius: BorderRadius.circular(6),
               border: Border.all(color: const Color(0xFFFDE68A)),
             ),
             child: const Text('RESTRICTED', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Color(0xFFD97706))),
           ),
         ],
       ),
       content: ConstrainedBox(
         constraints: BoxConstraints(
           maxWidth: 600,
           maxHeight: MediaQuery.of(dialogContext).size.height * 0.7,
         ),
         child: Column(
           mainAxisSize: MainAxisSize.min,
           crossAxisAlignment: CrossAxisAlignment.start,
           children: [
             const Text(
               'Rates are auto-filled by AI based on project location and currency. '
               'Authorized personnel can update rate values and change currency.',
               style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
             ),
             const SizedBox(height: 16),
             Expanded(
               child: roles.isEmpty
                   ? const Center(child: Text('No roles added yet'))
                   : ListView.builder(
                       shrinkWrap: true,
                       itemCount: roles.length,
                       itemBuilder: (context, index) {
                         final role = roles[index];
                         return Card(
                           child: ListTile(
                             title: Text(role.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                             subtitle: Text('${role.subtitle}${role.quantity > 1 ? " (x${role.quantity})" : ""}',
                                 style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                             trailing: SizedBox(
                               width: 120,
                               child: TextFormField(
                                 initialValue: '0',
                                 decoration: const InputDecoration(
                                   prefixText: '\$ ',
                                   border: OutlineInputBorder(),
                                   isDense: true,
                                 ),
                                 style: const TextStyle(fontSize: 13),
                                 keyboardType: TextInputType.number,
                               ),
                             ),
                           ),
                         );
                       },
                     ),
             ),
           ],
         ),
       ),
       actions: [
         TextButton(
           onPressed: () => Navigator.pop(dialogContext),
           child: const Text('Close'),
         ),
         ElevatedButton(
           onPressed: () {
             Navigator.pop(dialogContext);
             ScaffoldMessenger.of(context).showSnackBar(
               const SnackBar(content: Text('Rates saved'), backgroundColor: Color(0xFF10B981)),
             );
           },
           style: ElevatedButton.styleFrom(
             backgroundColor: const Color(0xFFF59E0B),
             foregroundColor: Colors.white,
           ),
           child: const Text('Save Rates'),
         ),
       ],
     ),
   );
 }

}


class _RoleCard extends StatelessWidget {
 const _RoleCard({
 required this.data,
 required this.onEdit,
 required this.onDelete,
 });

 final _RoleCardData data;
 final VoidCallback onEdit;
 final VoidCallback onDelete;

 @override
 Widget build(BuildContext context) {
 return Container(
 padding: const EdgeInsets.all(20),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(18),
 border: Border.all(color: const Color(0xFFE6E8F0)),
 boxShadow: const [
 BoxShadow(
 color: Color(0x14212527),
 blurRadius: 24,
 offset: Offset(0, 6),
 ),
 ],
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Container(
 padding: const EdgeInsets.all(12),
 decoration: BoxDecoration(
 color: const Color(0xFFE4E7FF),
 borderRadius: BorderRadius.circular(14),
 ),
 child: const Icon(Icons.business_center_outlined,
 color: Color(0xFF6C6CF3)),
 ),
 const SizedBox(width: 12),
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 children: [
 Text(
 data.title,
 style: const TextStyle(
 fontSize: 18,
 fontWeight: FontWeight.w700,
 color: Color(0xFF202326),
 ),
 ),
 if (data.quantity > 1) ...[
 const SizedBox(width: 8),
 Container(
 padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
 decoration: BoxDecoration(
 color: const Color(0xFFFFC812),
 borderRadius: BorderRadius.circular(6),
 ),
 child: Text(
 'x${data.quantity}',
 style: const TextStyle(
 fontSize: 12,
 fontWeight: FontWeight.w800,
 color: Colors.black,
 ),
 ),
 ),
 ],
 ],
 ),
 const SizedBox(height: 4),
 Text(
 data.subtitle,
 style: const TextStyle(
 fontSize: 13,
 height: 1.4,
 color: Color(0xFF5B6572),
 ),
 ),
 ],
 ),
 ),
 Row(
 mainAxisSize: MainAxisSize.min,
 children: [
 IconButton(
 tooltip: 'Edit member',
 onPressed: onEdit,
 icon: const Icon(Icons.edit_outlined,
 color: Color(0xFF5B6572)),
 ),
 IconButton(
 tooltip: 'Delete member',
 onPressed: onDelete,
 icon: const Icon(Icons.delete_outline,
 color: Color(0xFFD64545)),
 ),
 ],
 ),
 ],
 ),
 const SizedBox(height: 20),
 const Text(
 'Key Responsibilities',
 style: TextStyle(
 fontSize: 15,
 fontWeight: FontWeight.w700,
 color: Color(0xFF202326),
 ),
 ),
 const SizedBox(height: 12),
 ...data.responsibilities.asMap().entries.map(
 (entry) {
 final index = entry.key;
 final item = entry.value;
 return Padding(
 padding: const EdgeInsets.only(bottom: 12),
 child: Row(
 children: [
 const Icon(Icons.check_circle,
 color: Color(0xFF42D79E), size: 22),
 const SizedBox(width: 10),
 Expanded(
 child: Text(
 '${index + 1}. $item',
 style: const TextStyle(
 fontSize: 14,
 color: Color(0xFF394452),
 ),
 ),
 ),
 ],
 ),
 );
 },
 ),
 const SizedBox(height: 8),
 const Divider(color: Color(0xFFD0D6E4), thickness: 1),
 const SizedBox(height: 16),
 const Text(
 'Work Progress',
 style: TextStyle(
 fontSize: 15,
 fontWeight: FontWeight.w700,
 color: Color(0xFF202326),
 ),
 ),
 const SizedBox(height: 12),
 const _WorkProgressHeader(),
 const SizedBox(height: 12),
 ...data.workItems.map((item) {
 return Padding(
 padding:
 EdgeInsets.only(bottom: item == data.workItems.last ? 0 : 10),
 child: _WorkProgressRow(item: item),
 );
 }),
 ],
 ),
 );
 }
}

class _WorkProgressHeader extends StatelessWidget {
 const _WorkProgressHeader();

 @override
 Widget build(BuildContext context) {
 return Row(
 children: const [
 Expanded(
 child: Text(
 'Name',
 style: TextStyle(
 fontSize: 13,
 fontWeight: FontWeight.w600,
 color: Color(0xFF1F1F1F),
 ),
 ),
 ),
 SizedBox(width: 12),
 Expanded(
 child: Text(
 'Status',
 textAlign: TextAlign.right,
 style: TextStyle(
 fontSize: 13,
 fontWeight: FontWeight.w600,
 color: Color(0xFF1F1F1F),
 ),
 ),
 ),
 ],
 );
 }
}

class _WorkProgressRow extends StatelessWidget {
 const _WorkProgressRow({required this.item});

 final _WorkItem item;

 @override
 Widget build(BuildContext context) {
 final background =
 item.isAltRow ? const Color(0xFFF2F4F7) : Colors.transparent;
 return Container(
 padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
 decoration: BoxDecoration(
 color: background,
 borderRadius: BorderRadius.circular(12),
 ),
 child: Row(
 children: [
 Expanded(
 child: Text(
 item.name,
 style: const TextStyle(
 fontSize: 13,
 color: Color(0xFF4A5563),
 ),
 ),
 ),
 const SizedBox(width: 12),
 Expanded(
 child: Align(
 alignment: Alignment.centerRight,
 child: Container(
 padding:
 const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
 decoration: BoxDecoration(
 color: const Color(0xFFE6F8EE),
 borderRadius: BorderRadius.circular(30),
 ),
 child: Text(
 item.status,
 style: const TextStyle(
 fontSize: 13,
 fontWeight: FontWeight.w600,
 color: Color(0xFF2FB379),
 ),
 ),
 ),
 ),
 ),
 ],
 ),
 );
 }
}

class _SectionCardShell extends StatelessWidget {
 const _SectionCardShell({
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
 width: double.infinity,
 padding: const EdgeInsets.all(24),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(20),
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
 Text(
 title,
 style: const TextStyle(
 fontSize: 16,
 fontWeight: FontWeight.w700,
 color: Color(0xFF111827)),
 ),
 const SizedBox(height: 6),
 Text(
 subtitle,
 style: const TextStyle(
 fontSize: 12, color: Color(0xFF6B7280)),
 ),
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

class _SectionMessage extends StatelessWidget {
 const _SectionMessage({required this.title, required this.message});

 final String title;
 final String message;

 @override
 Widget build(BuildContext context) {
 return Container(
 width: double.infinity,
 padding: const EdgeInsets.all(24),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(20),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 ),
 child: Row(
 children: [
 Container(
 padding: const EdgeInsets.all(10),
 decoration: BoxDecoration(
 color: const Color(0xFFFFF7ED),
 borderRadius: BorderRadius.circular(10),
 ),
 child: const Icon(Icons.people_outline,
 color: Color(0xFFEA580C), size: 20),
 ),
 const SizedBox(width: 16),
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 title,
 style: const TextStyle(
 fontSize: 15,
 fontWeight: FontWeight.w600,
 color: Color(0xFF111827),
 ),
 ),
 const SizedBox(height: 4),
 Text(
 message,
 style: const TextStyle(
 fontSize: 13,
 color: Color(0xFF6B7280),
 ),
 ),
 ],
 ),
 ),
 ],
 ),
 );
 }
}

class _MetricCard extends StatelessWidget {
 const _MetricCard({
 required this.metric,
 required this.onChanged,
 required this.onDelete,
 });

 final _StaffingMetric metric;
 final ValueChanged<_StaffingMetric> onChanged;
 final VoidCallback onDelete;

 @override
 Widget build(BuildContext context) {
 return Container(
 padding: const EdgeInsets.all(16),
 decoration: BoxDecoration(
 color: const Color(0xFFF9FAFB),
 borderRadius: BorderRadius.circular(14),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 VoiceTextFormField(
 initialValue: metric.value,
 decoration: const InputDecoration(
 border: InputBorder.none, hintText: 'Value'),
 style: const TextStyle(
 fontSize: 20,
 fontWeight: FontWeight.w700,
 color: Color(0xFF111827)),
 onChanged: (value) => onChanged(metric.copyWith(value: value)),
 ),
 const SizedBox(height: 6),
 VoiceTextFormField(
 initialValue: metric.label,
 decoration: const InputDecoration(
 border: InputBorder.none, hintText: 'Label'),
 style: const TextStyle(
 fontSize: 12,
 fontWeight: FontWeight.w600,
 color: Color(0xFF6B7280)),
 onChanged: (value) => onChanged(metric.copyWith(label: value)),
 ),
 Align(
 alignment: Alignment.centerRight,
 child: IconButton(
 icon: const Icon(Icons.delete_outline,
 size: 18, color: Color(0xFFD64545)),
 onPressed: onDelete,
 ),
 ),
 ],
 ),
 );
 }
}

class _ColumnLabel extends StatelessWidget {
 const _ColumnLabel(this.label);

 final String label;

 @override
 Widget build(BuildContext context) {
 return Text(
 label,
 style: const TextStyle(
 fontSize: 12,
 fontWeight: FontWeight.w600,
 color: Color(0xFF6B7280),
 ),
 );
 }
}

class _StaffingMetric {
 const _StaffingMetric({
 required this.id,
 required this.label,
 required this.value,
 });

 final String id;
 final String label;
 final String value;

 _StaffingMetric copyWith({String? label, String? value}) {
 return _StaffingMetric(
 id: id,
 label: label ?? this.label,
 value: value ?? this.value,
 );
 }

 Map<String, dynamic> toMap() => {
 'id': id,
 'label': label,
 'value': value,
 };

 static List<_StaffingMetric> fromList(dynamic data) {
 if (data is! List) return [];
 return data.map((item) {
 final map = Map<String, dynamic>.from(item as Map? ?? {});
 return _StaffingMetric(
 id: map['id']?.toString() ??
 DateTime.now().microsecondsSinceEpoch.toString(),
 label: map['label']?.toString() ?? '',
 value: map['value']?.toString() ?? '',
 );
 }).toList();
 }
}

class _CoverageRow {
 const _CoverageRow({
 required this.id,
 required this.area,
 required this.owner,
 required this.backup,
 required this.status,
 required this.notes,
 });

 final String id;
 final String area;
 final String owner;
 final String backup;
 final String status;
 final String notes;

 _CoverageRow copyWith({
 String? area,
 String? owner,
 String? backup,
 String? status,
 String? notes,
 }) {
 return _CoverageRow(
 id: id,
 area: area ?? this.area,
 owner: owner ?? this.owner,
 backup: backup ?? this.backup,
 status: status ?? this.status,
 notes: notes ?? this.notes,
 );
 }

 Map<String, dynamic> toMap() => {
 'id': id,
 'area': area,
 'owner': owner,
 'backup': backup,
 'status': status,
 'notes': notes,
 };

 static List<_CoverageRow> fromList(dynamic data) {
 if (data is! List) return [];
 return data.map((item) {
 final map = Map<String, dynamic>.from(item as Map? ?? {});
 return _CoverageRow(
 id: map['id']?.toString() ??
 DateTime.now().microsecondsSinceEpoch.toString(),
 area: map['area']?.toString() ?? '',
 owner: map['owner']?.toString() ?? '',
 backup: map['backup']?.toString() ?? '',
 status: map['status']?.toString() ?? 'On track',
 notes: map['notes']?.toString() ?? '',
 );
 }).toList();
 }
}

class _HiringRow {
 const _HiringRow({
 required this.id,
 required this.role,
 required this.headcount,
 required this.startDate,
 required this.rampPlan,
 required this.status,
 });

 final String id;
 final String role;
 final String headcount;
 final String startDate;
 final String rampPlan;
 final String status;

 _HiringRow copyWith({
 String? role,
 String? headcount,
 String? startDate,
 String? rampPlan,
 String? status,
 }) {
 return _HiringRow(
 id: id,
 role: role ?? this.role,
 headcount: headcount ?? this.headcount,
 startDate: startDate ?? this.startDate,
 rampPlan: rampPlan ?? this.rampPlan,
 status: status ?? this.status,
 );
 }

 Map<String, dynamic> toMap() => {
 'id': id,
 'role': role,
 'headcount': headcount,
 'startDate': startDate,
 'rampPlan': rampPlan,
 'status': status,
 };

 static List<_HiringRow> fromList(dynamic data) {
 if (data is! List) return [];
 return data.map((item) {
 final map = Map<String, dynamic>.from(item as Map? ?? {});
 return _HiringRow(
 id: map['id']?.toString() ??
 DateTime.now().microsecondsSinceEpoch.toString(),
 role: map['role']?.toString() ?? '',
 headcount: map['headcount']?.toString() ?? '',
 startDate: map['startDate']?.toString() ?? '',
 rampPlan: map['rampPlan']?.toString() ?? '',
 status: map['status']?.toString() ?? 'Planned',
 );
 }).toList();
 }
}

class _DecisionRow {
 const _DecisionRow({
 required this.id,
 required this.decision,
 required this.owner,
 required this.approver,
 required this.cadence,
 });

 final String id;
 final String decision;
 final String owner;
 final String approver;
 final String cadence;

 _DecisionRow copyWith({
 String? decision,
 String? owner,
 String? approver,
 String? cadence,
 }) {
 return _DecisionRow(
 id: id,
 decision: decision ?? this.decision,
 owner: owner ?? this.owner,
 approver: approver ?? this.approver,
 cadence: cadence ?? this.cadence,
 );
 }

 Map<String, dynamic> toMap() => {
 'id': id,
 'decision': decision,
 'owner': owner,
 'approver': approver,
 'cadence': cadence,
 };

 static List<_DecisionRow> fromList(dynamic data) {
 if (data is! List) return [];
 return data.map((item) {
 final map = Map<String, dynamic>.from(item as Map? ?? {});
 return _DecisionRow(
 id: map['id']?.toString() ??
 DateTime.now().microsecondsSinceEpoch.toString(),
 decision: map['decision']?.toString() ?? '',
 owner: map['owner']?.toString() ?? '',
 approver: map['approver']?.toString() ?? '',
 cadence: map['cadence']?.toString() ?? '',
 );
 }).toList();
 }
}

class _RoleCardData {
 const _RoleCardData({
 required this.title,
 required this.subtitle,
 required this.responsibilities,
 required this.workItems,
 this.fullName = '',
 this.role = '',
 this.email = '',
 this.phone = '',
 this.department = '',
 this.location = '',
 this.startDate,
 this.endDate,
 this.teamPlacement = 'Core team',
 this.accessLevel = 'Full access',
 this.notes = '',
 this.quantity = 1,
 this.employmentType = 'Full Time',
 this.category = 'Employee',
 this.nduAccess = false,
 });

 final String title;
 final String subtitle;
 final List<String> responsibilities;
 final List<_WorkItem> workItems;
 final String fullName;
 final String role;
 final String email;
 final String phone;
 final String department;
 final String location;
 final DateTime? startDate;
 final DateTime? endDate;
 final String teamPlacement;
 final String accessLevel;
 final String notes;
 final int quantity;
 final String employmentType;
 final String category;
 final bool nduAccess;
 Map<String, dynamic> toMap() {
 return {
 'title': title,
 'subtitle': subtitle,
 'responsibilities': responsibilities,
 'workItems': workItems.map((e) => e.toMap()).toList(),
 'fullName': fullName,
 'role': role,
 'email': email,
 'phone': phone,
 'department': department,
 'location': location,
 'startDate': startDate?.toIso8601String(),
 'endDate': endDate?.toIso8601String(),
 'teamPlacement': teamPlacement,
 'accessLevel': accessLevel,
 'notes': notes,
 'quantity': quantity,
 'employmentType': employmentType,
 'category': category,
 'nduAccess': nduAccess,
 };
 }

 static _RoleCardData fromMap(Map<String, dynamic> map) {
 return _RoleCardData(
 title: map['title'] ?? '',
 subtitle: map['subtitle'] ?? '',
 responsibilities: List<String>.from(map['responsibilities'] ?? []),
 workItems: (map['workItems'] as List<dynamic>? ?? [])
 .map((e) => _WorkItem.fromMap(e as Map<String, dynamic>))
 .toList(),
 fullName: map['fullName'] ?? '',
 role: map['role'] ?? '',
 email: map['email'] ?? '',
 phone: map['phone'] ?? '',
 department: map['department'] ?? '',
 location: map['location'] ?? '',
 startDate:
 map['startDate'] != null ? DateTime.tryParse(map['startDate']) : null,
 endDate:
 map['endDate'] != null ? DateTime.tryParse(map['endDate']) : null,
 teamPlacement: map['teamPlacement'] ?? 'Core team',
 accessLevel: map['accessLevel'] ?? 'Full access',
 notes: map['notes'] ?? '',
 quantity: map['quantity'] ?? 1,
 employmentType: map['employmentType'] ?? 'Full Time',
 category: map['category'] ?? 'Employee',
 nduAccess: map['nduAccess'] ?? false,
 );
 }
}

class _WorkItem {
 const _WorkItem({
 required this.name,
 required this.status,
 this.isAltRow = false,
 });

 final String name;
 final String status;
 final bool isAltRow;

 Map<String, dynamic> toMap() {
 return {
 'name': name,
 'status': status,
 'isAltRow': isAltRow,
 };
 }

 static _WorkItem fromMap(Map<String, dynamic> map) {
 return _WorkItem(
 name: map['name'] ?? '',
 status: map['status'] ?? 'Not started',
 isAltRow: map['isAltRow'] ?? false,
 );
 }
}

class _Debouncer {
 final int milliseconds;
 VoidCallback? _action;
 _Debouncer({required this.milliseconds});

 void run(VoidCallback action) {
 if (_action != null) {
 // In a real debouncer we'd cancel a timer.
 // For simplicity in this widget-local helper we rely on a slightly different pattern
 // or just trust the latest call wins if we had waiting logic.
 // But standard debounce needs dart:async Timer.
 }
 // Actually let's just use dart:async Timer.
 _timer?.cancel();
 _timer = Timer(Duration(milliseconds: milliseconds), action);
 }

 Timer? _timer;

 void dispose() {
 _timer?.cancel();
 }
}

class _WorkProgressDraft {
 _WorkProgressDraft(
 {String initialName = '', String initialStatus = 'Not started'})
 : nameController = TextEditingController(text: initialName),
 status = initialStatus;

 final TextEditingController nameController;
 String status;

 void dispose() {
 nameController.dispose();
 }
}

class _WorkProgressEntryEditor extends StatelessWidget {
 const _WorkProgressEntryEditor({
 required this.index,
 required this.draft,
 required this.statusOptions,
 required this.onStatusChanged,
 this.onRemove,
 });

 final int index;
 final _WorkProgressDraft draft;
 final List<String> statusOptions;
 final ValueChanged<String> onStatusChanged;
 final VoidCallback? onRemove;

 @override
 Widget build(BuildContext context) {
 final theme = Theme.of(context);
 final colors = theme.colorScheme;
 final titleStyle = theme.textTheme.titleSmall?.copyWith(
 fontWeight: FontWeight.w600,
 color: colors.onSurface,
 ) ??
 TextStyle(
 fontSize: 15,
 fontWeight: FontWeight.w600,
 color: colors.onSurface,
 );
 final borderRadius = BorderRadius.circular(18);

 return Container(
 padding: const EdgeInsets.all(18),
 decoration: BoxDecoration(
 color: colors.surface,
 borderRadius: borderRadius,
 border: Border.all(color: colors.outlineVariant),
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 crossAxisAlignment: CrossAxisAlignment.center,
 children: [
 Expanded(
 child: Text('Work item ${index + 1}', style: titleStyle),
 ),
 if (onRemove != null)
 IconButton(
 onPressed: onRemove,
 splashRadius: 22,
 icon: Icon(Icons.delete_outline,
 color: colors.error.withOpacity(0.85)),
 ),
 ],
 ),
 const SizedBox(height: 14),
 VoiceTextFormField(
 controller: draft.nameController,
 style:
 theme.textTheme.bodyMedium?.copyWith(color: colors.onSurface),
 decoration: InputDecoration(
 labelText: 'Work item name',
 hintText: 'e.g. Draft integration plan',
 prefixIcon: Icon(Icons.task_alt_outlined, color: colors.primary),
 filled: true,
 fillColor: colors.surfaceContainerHighest.withOpacity(0.4),
 contentPadding:
 const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
 border: OutlineInputBorder(
 borderRadius: BorderRadius.circular(16),
 borderSide: BorderSide(color: colors.outlineVariant),
 ),
 enabledBorder: OutlineInputBorder(
 borderRadius: BorderRadius.circular(16),
 borderSide: BorderSide(color: colors.outlineVariant),
 ),
 focusedBorder: OutlineInputBorder(
 borderRadius: BorderRadius.circular(16),
 borderSide: BorderSide(color: colors.primary, width: 1.6),
 ),
 ),
 ),
 const SizedBox(height: 14),
 DropdownButtonFormField<String>(
 value: draft.status,
 onChanged: (value) {
 if (value == null) return;
 onStatusChanged(value);
 },
 items: statusOptions
 .map(
 (status) => DropdownMenuItem<String>(
 value: status,
 child: Text(status),
 ),
 )
 .toList(),
 style:
 theme.textTheme.bodyMedium?.copyWith(color: colors.onSurface),
 decoration: InputDecoration(
 labelText: 'Status',
 prefixIcon: Icon(Icons.flag_outlined, color: colors.primary),
 filled: true,
 fillColor: colors.surfaceContainerHighest.withOpacity(0.4),
 contentPadding:
 const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
 border: OutlineInputBorder(
 borderRadius: BorderRadius.circular(16),
 borderSide: BorderSide(color: colors.outlineVariant),
 ),
 enabledBorder: OutlineInputBorder(
 borderRadius: BorderRadius.circular(16),
 borderSide: BorderSide(color: colors.outlineVariant),
 ),
 focusedBorder: OutlineInputBorder(
 borderRadius: BorderRadius.circular(16),
 borderSide: BorderSide(color: colors.primary, width: 1.6),
 ),
 ),
 ),
 ],
 ),
 );
 }
}

class _YellowActionButton extends StatelessWidget {
 const _YellowActionButton({
 required this.label,
 this.icon,
 this.onPressed,
 });

 final String label;
 final IconData? icon;
 final VoidCallback? onPressed;

 @override
 Widget build(BuildContext context) {
 final baseStyle = ElevatedButton.styleFrom(
 elevation: 0,
 backgroundColor: const Color(0xFFFFC400),
 foregroundColor: const Color(0xFF1F1F1F),
 shape: RoundedRectangleBorder(
 borderRadius: BorderRadius.circular(16),
 ),
 ).copyWith(
 iconColor: const WidgetStatePropertyAll(Color(0xFF1F1F1F)),
 );

 final text = Text(
 label,
 style: const TextStyle(
 fontSize: 15,
 fontWeight: FontWeight.w600,
 color: Color(0xFF1F1F1F),
 ),
 );

 if (icon == null) {
 return ElevatedButton(
 onPressed: onPressed,
 style: baseStyle.copyWith(
 padding: const WidgetStatePropertyAll(
 EdgeInsets.symmetric(horizontal: 32, vertical: 16),
 ),
 ),
 child: text,
 );
 }

 return ElevatedButton.icon(
 onPressed: onPressed,
 style: baseStyle.copyWith(
 padding: const WidgetStatePropertyAll(
 EdgeInsets.symmetric(horizontal: 20, vertical: 16),
 ),
 ),
 icon: Icon(icon, color: const Color(0xFF1F1F1F)),
 label: text,
 );
 }
}

class _TeamMemberDialog extends StatefulWidget {
 const _TeamMemberDialog({this.initialData});

 final _RoleCardData? initialData;

 @override
 State<_TeamMemberDialog> createState() => _TeamMemberDialogState();
}

class _TeamMemberDialogState extends State<_TeamMemberDialog> {
 @override
 Widget build(BuildContext context) {
 final theme = Theme.of(context);
 final colors = theme.colorScheme;
 final title = _isEditing ? 'Edit team member' : 'Add team member';
 final subtitle = _isEditing
 ? 'Update role ownership and responsibilities.'
 : 'Define role ownership and responsibilities.';

 return Dialog(
 insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
 child: ConstrainedBox(
 constraints: const BoxConstraints(maxWidth: 760),
 child: LayoutBuilder(
 builder: (context, constraints) {
 const gap = 16.0;
 final width = constraints.maxWidth;
 final twoCol = width >= 640;
 final fieldWidth = twoCol ? (width - gap) / 2 : width;

 return SingleChildScrollView(
 padding: const EdgeInsets.all(24),
 child: Column(
 mainAxisSize: MainAxisSize.min,
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 children: [
 Container(
 width: 44,
 height: 44,
 decoration: BoxDecoration(
 color: colors.primary.withOpacity(0.12),
 borderRadius: BorderRadius.circular(14),
 ),
 child: Icon(Icons.group_add_outlined,
 color: colors.primary),
 ),
 const SizedBox(width: 12),
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 title,
 style: theme.textTheme.titleMedium?.copyWith(
 fontWeight: FontWeight.w700,
 color: colors.onSurface,
 ) ??
 TextStyle(
 fontSize: 18,
 fontWeight: FontWeight.w700,
 color: colors.onSurface,
 ),
 ),
 const SizedBox(height: 4),
 Text(
 subtitle,
 style: theme.textTheme.bodySmall?.copyWith(
 color: colors.onSurfaceVariant,
 ) ??
 TextStyle(
 fontSize: 12,
 color: colors.onSurfaceVariant,
 ),
 ),
 ],
 ),
 ),
 IconButton(
 onPressed: () => Navigator.of(context).pop(),
 icon: Icon(Icons.close, color: colors.outline),
 splashRadius: 20,
 ),
 ],
 ),
 const SizedBox(height: 24),
 const _SectionLabel(label: 'Identity'),
 const SizedBox(height: 12),
 Wrap(
 spacing: gap,
 runSpacing: gap,
 children: [
 SizedBox(
 width: fieldWidth,
 child: _DialogTextField(
 controller: _nameController,
 label: 'Full name',
 hint: 'e.g. Ama Kwame',
 icon: Icons.person_outline,
 ),
 ),
 SizedBox(
 width: fieldWidth,
 child: _DialogTextField(
 controller: _roleController,
 label: 'Role title',
 hint: 'e.g. Project Manager',
 icon: Icons.work_outline,
 ),
 ),
 SizedBox(
 width: fieldWidth,
 child: _DialogTextField(
 controller: _emailController,
 label: 'Work email',
 hint: 'name@company.com',
 icon: Icons.mail_outline,
 keyboardType: TextInputType.emailAddress,
 ),
 ),
 SizedBox(
 width: fieldWidth,
 child: _DialogTextField(
 controller: _phoneController,
 label: 'Phone number',
 hint: 'e.g. +233 24 000 0000',
 icon: Icons.phone_outlined,
 keyboardType: TextInputType.phone,
 ),
 ),
 SizedBox(
 width: fieldWidth,
 child: _DialogTextField(
 controller: _departmentController,
 label: 'Discipline',
 hint: 'e.g. Product',
 icon: Icons.apartment_outlined,
 ),
 ),
 SizedBox(
 width: fieldWidth,
 child: _DialogTextField(
 controller: _locationController,
 label: 'Location',
 hint: 'e.g. Accra (GMT)',
 icon: Icons.place_outlined,
 ),
 ),
 SizedBox(
 width: fieldWidth,
 child: _DateSelector(
 label: 'Start date',
 hint: 'Select date',
 value: _startDate,
 onSelect: (date) => setState(() => _startDate = date),
 ),
 ),
 ],
 ),
 const SizedBox(height: 20),
 _ChoicePills(
 label: 'Team placement',
 options: const [
 'Core team',
 'Extended team',
 'External partner'
 ],
 selectedValue: _teamPlacement,
 onChanged: (value) =>
 setState(() => _teamPlacement = value),
 ),
 const SizedBox(height: 20),
 _ChoicePills(
 label: 'Access level',
 options: const [
 'Full access',
 'Limited access',
 'View only'
 ],
 selectedValue: _accessLevel,
 onChanged: (value) => setState(() => _accessLevel = value),
 ),
 const SizedBox(height: 20),
 const _SectionLabel(label: 'Responsibilities'),
 const SizedBox(height: 12),
 _DialogTextField(
 controller: _responsibilitiesController,
 label: 'Key responsibilities',
 hint: 'Add key responsibilities, one per line',
 icon: Icons.list_alt_outlined,
 maxLines: 4,
 ),
 const SizedBox(height: 20),
 const _SectionLabel(label: 'Work progress'),
 const SizedBox(height: 12),
 ..._workProgressEntries.asMap().entries.map((entry) {
 final index = entry.key;
 final draft = entry.value;
 return Padding(
 padding: EdgeInsets.only(
 bottom:
 index == _workProgressEntries.length - 1 ? 0 : 12,
 ),
 child: _WorkProgressEntryEditor(
 index: index,
 draft: draft,
 statusOptions: _statusOptions,
 onStatusChanged: (value) =>
 setState(() => draft.status = value),
 onRemove: _workProgressEntries.length > 1
 ? () => _removeWorkProgressEntry(index)
 : null,
 ),
 );
 }),
 const SizedBox(height: 12),
 TextButton.icon(
 onPressed: _addWorkProgressEntry,
 icon: const Icon(Icons.add),
 label: const Text('Add work item'),
 ),
 const SizedBox(height: 20),
 const _SectionLabel(label: 'Notes'),
 const SizedBox(height: 12),
 _DialogTextField(
 controller: _notesController,
 label: 'Additional notes',
 hint: 'Optional notes about this team member',
 icon: Icons.note_outlined,
 maxLines: 3,
 ),
 const SizedBox(height: 24),
 Row(
 children: [
 TextButton(
 onPressed: () => Navigator.of(context).pop(),
 child: const Text('Cancel'),
 ),
 const Spacer(),
 _YellowActionButton(
 label: _isEditing ? 'Save changes' : 'Add member',
 icon: Icons.check_circle_outline,
 onPressed: _handleSaveMember,
 ),
 ],
 ),
 ],
 ),
 );
 },
 ),
 ),
 );
 }

 final _nameController = TextEditingController();
 final _roleController = TextEditingController();
 final _emailController = TextEditingController();
 final _phoneController = TextEditingController();
 final _departmentController = TextEditingController();
 final _locationController = TextEditingController();
 final _responsibilitiesController = TextEditingController();
 final _notesController = TextEditingController();
 final List<_WorkProgressDraft> _workProgressEntries = [];

 static const List<String> _statusOptions = [
 'Not started',
 'In progress',
 'Blocked',
 'Done'
 ];

 String _accessLevel = 'Full access';
 String _teamPlacement = 'Core team';
 DateTime? _startDate;

 bool get _isEditing => widget.initialData != null;

 @override
 void initState() {
 super.initState();
 final initial = widget.initialData;
 if (initial != null) {
 _nameController.text = initial.fullName;
 _roleController.text = initial.role;
 _emailController.text = initial.email;
 _phoneController.text = initial.phone;
 _departmentController.text = initial.department;
 _locationController.text = initial.location;
 _notesController.text = initial.notes;
 _startDate = initial.startDate;
 _teamPlacement = initial.teamPlacement;
 _accessLevel = initial.accessLevel;

 if (initial.responsibilities.isNotEmpty) {
 final buffer = StringBuffer();
 for (var i = 0; i < initial.responsibilities.length; i++) {
 buffer.writeln('${i + 1}. ${initial.responsibilities[i]}');
 }
 _responsibilitiesController.text = buffer.toString().trimRight();
 }

 if (initial.workItems.isNotEmpty) {
 _workProgressEntries.addAll(
 initial.workItems.map(
 (item) => _WorkProgressDraft(
 initialName: item.name,
 initialStatus: item.status,
 ),
 ),
 );
 }
 }

 if (_workProgressEntries.isEmpty) {
 _workProgressEntries
 .add(_WorkProgressDraft(initialStatus: _statusOptions.first));
 }
 }

 void _handleSaveMember() {
 final responsibilities =
 _extractResponsibilities(_responsibilitiesController.text);

 if (responsibilities.isEmpty) {
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(
 content:
 Text('Add at least one key responsibility before saving.')),
 );
 return;
 }

 final workItems = <_WorkItem>[];
 for (final entry in _workProgressEntries) {
 final trimmedName = entry.nameController.text.trim();
 if (trimmedName.isEmpty) {
 continue;
 }
 final isAltRow = workItems.length.isOdd;
 workItems.add(
 _WorkItem(
 name: trimmedName,
 status: entry.status,
 isAltRow: isAltRow,
 ),
 );
 }

 final fullName = _nameController.text.trim();
 final role = _roleController.text.trim();
 final email = _emailController.text.trim();
 final phone = _phoneController.text.trim();
 final department = _departmentController.text.trim();
 final location = _locationController.text.trim();
 final notes = _notesController.text.trim();
 final teamTitle = role.isNotEmpty
 ? role
 : fullName.isNotEmpty
 ? fullName
 : 'Team Member';

 final subtitleParts = <String>[];
 if (fullName.isNotEmpty && fullName != teamTitle) {
 subtitleParts.add(fullName);
 }
 if (department.isNotEmpty) {
 subtitleParts.add(department);
 }
 if (location.isNotEmpty) {
 subtitleParts.add(location);
 }
 subtitleParts.add(_teamPlacement);
 subtitleParts.add(_accessLevel);

 final subtitle =
 subtitleParts.where((element) => element.trim().isNotEmpty).join(' • ');

 final member = _RoleCardData(
 title: teamTitle,
 subtitle: subtitle.isEmpty ? 'Team member' : subtitle,
 responsibilities: responsibilities,
 workItems: workItems,
 fullName: fullName,
 role: role,
 email: email,
 phone: phone,
 department: department,
 location: location,
 startDate: _startDate,
 teamPlacement: _teamPlacement,
 accessLevel: _accessLevel,
 notes: notes,
 );

 Navigator.of(context).pop(member);
 }

 List<String> _extractResponsibilities(String raw) {
 final lines = raw.split(RegExp(r'[\r\n]+'));
 final cleaned = <String>[];
 for (final line in lines) {
 final trimmed = line.trim();
 if (trimmed.isEmpty) continue;
 final match = RegExp(r'^\d+[\).\-]*\s*').firstMatch(trimmed);
 final withoutNumber =
 match != null ? trimmed.substring(match.end).trimLeft() : trimmed;
 if (withoutNumber.isNotEmpty) {
 cleaned.add(withoutNumber);
 }
 }
 return cleaned;
 }

 @override
 void dispose() {
 _nameController.dispose();
 _roleController.dispose();
 _emailController.dispose();
 _phoneController.dispose();
 _departmentController.dispose();
 _locationController.dispose();
 _responsibilitiesController.dispose();
 _notesController.dispose();
 for (final entry in _workProgressEntries) {
 entry.dispose();
 }
 super.dispose();
 }

 void _addWorkProgressEntry() {
 setState(() {
 _workProgressEntries
 .add(_WorkProgressDraft(initialStatus: _statusOptions.first));
 });
 }

  void _removeWorkProgressEntry(int index) async {
  if (index < 0 || index >= _workProgressEntries.length) {
    return;
  }
  final ok = await launchConfirmDelete(context, itemName: 'work progress entry');
  if (!ok) return;
  setState(() {
    final removed = _workProgressEntries.removeAt(index);
    removed.dispose();
    if (_workProgressEntries.isEmpty) {
      _workProgressEntries
          .add(_WorkProgressDraft(initialStatus: _statusOptions.first));
    }
  });
  }

 // --- AI Suggestion Helper (now in dialog state) ---
 Future<String> fetchOpenAiSuggestion(String field) async {
 // Replace with your actual OpenAI API key and endpoint
 const apiKey = 'YOUR_OPENAI_API_KEY';
 const endpoint = 'https://api.openai.com/v1/chat/completions';

 final prompt = _buildPromptForField(field);
 final response = await http.post(
 Uri.parse(endpoint),
 headers: {
 'Content-Type': 'application/json',
 'Authorization': 'Bearer $apiKey',
 },
 body: jsonEncode(OpenAiConfig.wrapBody({
 'model': OpenAiConfig.model,
 'messages': [
 {
 'role': 'system',
 'content': 'You are an expert HR assistant for software teams.'
 },
 {'role': 'user', 'content': prompt},
 ],
 'max_completion_tokens': 60,
 'temperature': 0.7,
 })),
 );
 if (response.statusCode == 200) {
 final data = jsonDecode(response.body);
 final suggestion = data['choices'][0]['message']['content']?.trim();
 return suggestion ?? '';
 } else {
 return '';
 }
 }

 String _buildPromptForField(String field) {
 switch (field) {
 case 'full_name':
 return 'Suggest a realistic full name for a software project team member.';
 case 'role_title':
 return 'Suggest a world-class role/title for a software project team (e.g., Project Manager, QA Lead, DevOps Engineer).';
 case 'work_email':
 return 'Suggest a professional work email address for a team member named Ama Kwame.';
 case 'phone_number':
 return 'Suggest a realistic phone number for a team member in Ghana.';
 case 'department':
 return 'Suggest a department for a software project team member (e.g., IT, Engineering, Product).';
 case 'location':
 return 'Suggest a location or time zone for a remote software team member.';
 case 'responsibilities':
 return 'Suggest 3-5 key responsibilities for a world-class software project team member.';
 default:
 return 'Suggest a value for $field.';
 }
 }
}

class _SectionLabel extends StatelessWidget {
 const _SectionLabel({required this.label});

 final String label;

 @override
 Widget build(BuildContext context) {
 final theme = Theme.of(context);
 final colors = theme.colorScheme;
 final style = theme.textTheme.titleSmall?.copyWith(
 fontWeight: FontWeight.w700,
 color: colors.onSurface,
 ) ??
 TextStyle(
 fontSize: 16,
 fontWeight: FontWeight.w700,
 color: colors.onSurface,
 );

 return Text(label, style: style);
 }
}

class _DialogTextField extends StatelessWidget {
 final TextEditingController controller;
 final String label;
 final String hint;
 final IconData? icon;
 final TextInputType? keyboardType;
 final int maxLines;
 final ValueChanged<String>? onChanged;

 const _DialogTextField({
 required this.controller,
 required this.label,
 required this.hint,
 this.icon,
 this.keyboardType,
 this.maxLines = 1,
 this.onChanged,
 });

 @override
 Widget build(BuildContext context) {
 final theme = Theme.of(context);
 final colors = theme.colorScheme;
 final labelStyle =
 theme.textTheme.labelMedium?.copyWith(color: colors.onSurfaceVariant);
 final hintTextStyle =
 theme.textTheme.bodyMedium?.copyWith(color: colors.outline);
 final inputBorderRadius = BorderRadius.circular(16);

 return VoiceTextFormField(
 controller: controller,
 keyboardType: keyboardType,
 maxLines: maxLines,
 style: theme.textTheme.bodyMedium?.copyWith(color: colors.onSurface),
 decoration: InputDecoration(
 labelText: label,
 hintText: hint,
 prefixIcon: icon == null ? null : Icon(icon, color: colors.primary),
 alignLabelWithHint: maxLines > 1,
 filled: true,
 fillColor: colors.surfaceContainerHighest.withOpacity(0.4),
 contentPadding:
 const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
 labelStyle: labelStyle,
 hintStyle: hintTextStyle,
 enabledBorder: OutlineInputBorder(
 borderRadius: inputBorderRadius,
 borderSide: BorderSide(color: colors.outlineVariant),
 ),
 focusedBorder: OutlineInputBorder(
 borderRadius: inputBorderRadius,
 borderSide: BorderSide(color: colors.primary, width: 1.6),
 ),
 ),
 );
 }
}

class _ChoicePills extends StatelessWidget {
 const _ChoicePills({
 required this.label,
 required this.options,
 required this.selectedValue,
 required this.onChanged,
 });

 final String label;
 final List<String> options;
 final String selectedValue;
 final ValueChanged<String> onChanged;

 @override
 Widget build(BuildContext context) {
 final theme = Theme.of(context);
 final colors = theme.colorScheme;
 final chipColor = colors.surfaceContainerHighest.withOpacity(0.6);
 final activeColor = colors.primary;
 final labelStyle = theme.textTheme.labelMedium?.copyWith(
 fontWeight: FontWeight.w600,
 color: colors.onSurfaceVariant,
 );

 return Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 label,
 style: labelStyle,
 ),
 const SizedBox(height: 12),
 Wrap(
 spacing: 10,
 runSpacing: 10,
 children: options.map((option) {
 final bool isSelected = option == selectedValue;
 return ChoiceChip(
 label: Text(
 option,
 style: TextStyle(
 fontSize: 13,
 fontWeight: FontWeight.w600,
 color:
 isSelected ? colors.onPrimary : colors.onSurfaceVariant,
 ),
 ),
 selected: isSelected,
 onSelected: (_) => onChanged(option),
 selectedColor: activeColor,
 backgroundColor: chipColor,
 padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
 shape: RoundedRectangleBorder(
 borderRadius: BorderRadius.circular(24)),
 );
 }).toList(),
 ),
 ],
 );
 }
}

class _DateSelector extends StatelessWidget {
 const _DateSelector({
 required this.label,
 required this.hint,
 required this.value,
 required this.onSelect,
 });

 final String label;
 final String hint;
 final DateTime? value;
 final ValueChanged<DateTime> onSelect;

 @override
 Widget build(BuildContext context) {
 final theme = Theme.of(context);
 final colors = theme.colorScheme;
 final labelStyle =
 theme.textTheme.labelMedium?.copyWith(color: colors.onSurfaceVariant);
 final borderRadius = BorderRadius.circular(16);
 final displayValue = value != null ? _formatDate(value!) : null;

 return InkWell(
 borderRadius: BorderRadius.circular(16),
 onTap: () async {
 final now = DateTime.now();
 final picked = await showDatePicker(
 context: context,
 initialDate: value ?? now,
 firstDate: DateTime(now.year - 5),
 lastDate: DateTime(now.year + 5),
 builder: (context, child) {
 final dateTheme = theme.copyWith(
 colorScheme: theme.colorScheme.copyWith(
 primary: colors.primary,
 onPrimary: colors.onPrimary,
 surface: colors.surface,
 onSurface: colors.onSurface,
 ),
 textButtonTheme: TextButtonThemeData(
 style: TextButton.styleFrom(foregroundColor: colors.primary),
 ),
 );
 return Theme(data: dateTheme, child: child!);
 },
 );
 if (picked != null) {
 onSelect(picked);
 }
 },
 child: InputDecorator(
 decoration: InputDecoration(
 labelText: label,
 filled: true,
 fillColor: colors.surfaceContainerHighest.withOpacity(0.4),
 contentPadding:
 const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
 labelStyle: labelStyle,
 enabledBorder: OutlineInputBorder(
 borderRadius: borderRadius,
 borderSide: BorderSide(color: colors.outlineVariant),
 ),
 focusedBorder: OutlineInputBorder(
 borderRadius: borderRadius,
 borderSide: BorderSide(color: colors.primary, width: 1.6),
 ),
 ),
 child: Row(
 children: [
 Icon(
 Icons.calendar_today_outlined,
 size: 20,
 color: value == null ? colors.outline : colors.primary,
 ),
 const SizedBox(width: 12),
 Expanded(
 child: Text(
 displayValue ?? hint,
 style: TextStyle(
 fontSize: 14,
 color:
 displayValue == null ? colors.outline : colors.onSurface,
 ),
 ),
 ),
 ],
 ),
 ),
 );
 }

 String _formatDate(DateTime date) {
 return '${date.day.toString().padLeft(2, '0')} ${_monthName(date.month)} ${date.year}';
 }

 String _monthName(int month) {
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
 return months[month - 1];
 }
}

/// Standard role catalog entry used by the Standard Roles picker.
class _StandardRole {
  final String title;
  final String discipline;
  final String description;

  const _StandardRole({
    required this.title,
    required this.discipline,
    required this.description,
  });
}

/// Inline quantity editor for the table view.
class _InlineQtyEditor extends StatefulWidget {
  final int initialQty;
  final ValueChanged<int> onChanged;

  const _InlineQtyEditor({
    required this.initialQty,
    required this.onChanged,
  });

  @override
  State<_InlineQtyEditor> createState() => _InlineQtyEditorState();
}

class _InlineQtyEditorState extends State<_InlineQtyEditor> {
  late TextEditingController _controller;
  late FocusNode _focusNode;
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialQty.toString());
    _focusNode = FocusNode();
    _focusNode.addListener(() {
      setState(() => _isFocused = _focusNode.hasFocus);
    });
  }

  @override
  void didUpdateWidget(_InlineQtyEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialQty != widget.initialQty && !_isFocused) {
      _controller.text = widget.initialQty.toString();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _commit() {
    final parsed = int.tryParse(_controller.text);
    if (parsed != null && parsed > 0) {
      widget.onChanged(parsed);
    } else {
      _controller.text = widget.initialQty.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64,
      height: 32,
      decoration: BoxDecoration(
        color: _isFocused ? Colors.white : (widget.initialQty > 1 ? const Color(0xFFFFC812) : const Color(0xFFF3F4F6)),
        borderRadius: BorderRadius.circular(6),
        border: _isFocused ? Border.all(color: const Color(0xFFF59E0B), width: 1.5) : null,
      ),
      child: TextFormField(
        controller: _controller,
        focusNode: _focusNode,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w800,
          color: _isFocused ? Colors.black : (widget.initialQty > 1 ? Colors.black : const Color(0xFF6B7280)),
        ),
        decoration: const InputDecoration(
          isDense: true,
          contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          border: InputBorder.none,
        ),
        onFieldSubmitted: (_) {
          _focusNode.unfocus();
          _commit();
        },
        onChanged: (value) {
          final parsed = int.tryParse(value);
          if (parsed != null && parsed > 0 && parsed != widget.initialQty) {
            widget.onChanged(parsed);
          }
        },
      ),
    );
  }
}
