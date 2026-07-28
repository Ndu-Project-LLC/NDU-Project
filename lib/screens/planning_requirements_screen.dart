import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:ndu_project/models/project_data_model.dart';
import 'package:ndu_project/services/api_key_manager.dart';
import 'package:ndu_project/services/firebase_auth_service.dart';
import 'package:ndu_project/services/openai_service_secure.dart';
import 'package:ndu_project/services/project_service.dart';
import 'package:ndu_project/services/user_service.dart';
import 'package:ndu_project/screens/ssher_stacked_screen.dart';
import 'package:ndu_project/utils/planning_phase_navigation.dart';
import 'package:ndu_project/utils/project_data_helper.dart';
import 'package:ndu_project/widgets/admin_edit_toggle.dart';
import 'package:ndu_project/widgets/draggable_sidebar.dart';
import 'package:ndu_project/widgets/initiation_like_sidebar.dart';
import 'package:ndu_project/widgets/kaz_ai_chat_bubble.dart';
import 'package:ndu_project/widgets/proceed_confirmation_gate.dart';
import 'package:ndu_project/widgets/responsive.dart';
import 'package:ndu_project/widgets/planning_phase_header.dart';

import 'package:ndu_project/widgets/voice_text_field.dart';
import 'package:ndu_project/utils/pdf_export_helper.dart';
import 'package:ndu_project/widgets/csv_import_dialog.dart';
import 'package:ndu_project/utils/csv_import_helper.dart';
import 'package:ndu_project/utils/download_helper.dart' as dl;
class PlanningRequirementsScreen extends StatefulWidget {
 const PlanningRequirementsScreen({super.key});

 @override
 State<PlanningRequirementsScreen> createState() =>
 _PlanningRequirementsScreenState();
}

class _PlanningRequirementsScreenState
 extends State<PlanningRequirementsScreen> {
 final TextEditingController _notesController = TextEditingController();
 final TextEditingController _requirementsPlanController =
 TextEditingController();
 final ScrollController _requirementsHorizontalController = ScrollController();
 final ScrollController _requirementsVerticalController = ScrollController();

 bool _isGeneratingRequirements = false;
 bool _isGeneratingRequirementsPlan = false;
 bool _planEditedManually = false;
 bool _settingPlanFromAi = false;
 bool _isRegeneratingRow = false;
 int? _regeneratingRowIndex;

 Timer? _autoSaveTimer;
 Timer? _planTimer;
 DateTime? _lastAutoSaveSnackAt;

 List<_AssignableMember> _memberOptions = const <_AssignableMember>[];
 final List<_RequirementRow> _rows = [];

 static const Set<String> _authorizedRequirementSubmitRoles = {
 'owner',
 'project manager',
 'technical manager',
 };

 @override
 void initState() {
 super.initState();
 ApiKeyManager.initializeApiKey();

 WidgetsBinding.instance.addPostFrameCallback((_) async {
 if (!mounted) return;

 final projectData = ProjectDataHelper.getData(context);
 _notesController.text = projectData.frontEndPlanning.requirementsNotes;
 _requirementsPlanController.text =
 projectData.frontEndPlanning.requirementsPlan;
 _planEditedManually = _requirementsPlanController.text.trim().isNotEmpty;

 _notesController.addListener(_handleNotesChanged);
 _requirementsPlanController.addListener(_handlePlanChanged);

 _loadSavedRequirements(projectData);
 await _loadAssignableMembers(projectData);

 if (_rows.isEmpty) {
 _rows.add(_createRow(1));
 }

 if (_rows.length == 1 &&
 _rows.first.descriptionController.text.trim().isEmpty) {
 await _generateRequirementsFromContext();
 }

 _maybeAutoGenerateRequirementsPlan();
 if (mounted) setState(() {});
 });
 }

 _RequirementRow _createRow(int number) {
 return _RequirementRow(
 number: number, onChanged: _handleRequirementChanged);
 }

 Future<void> _loadAssignableMembers(ProjectDataModel data) async {
 final merged = <_AssignableMember>[];
 final seen = <String>{};

 void addMember({
 required String id,
 required String name,
 required String email,
 required String role,
 required String source,
 }) {
 final normalizedEmail = email.trim().toLowerCase();
 final normalizedName = name.trim().toLowerCase();
 final key = normalizedEmail.isNotEmpty
 ? 'email:$normalizedEmail'
 : (id.trim().isNotEmpty
 ? 'id:${id.trim().toLowerCase()}'
 : 'name:$normalizedName');
 if (key.trim().isEmpty || seen.contains(key)) return;
 seen.add(key);
 merged.add(
 _AssignableMember(
 id: id.trim(),
 name: name.trim(),
 email: email.trim(),
 role: role.trim(),
 source: source,
 ),
 );
 }

 for (final member in data.teamMembers) {
 if (member.name.trim().isEmpty && member.email.trim().isEmpty) continue;
 addMember(
 id: member.id,
 name: member.name,
 email: member.email,
 role: member.role,
 source: 'Project Team',
 );
 }

 try {
 final users = await UserService.searchUsers('');
 for (final user in users) {
 if (user.displayName.trim().isEmpty && user.email.trim().isEmpty) {
 continue;
 }
 addMember(
 id: user.uid,
 name: user.displayName,
 email: user.email,
 role: user.isAdmin ? 'Admin' : 'Member',
 source: 'Company Members',
 );
 }
 } catch (e) {
 debugPrint(
 'Failed loading company members for planning requirements: $e');
 }

 merged.sort((a, b) {
 final sourceWeight =
 a.source == b.source ? 0 : (a.source == 'Project Team' ? -1 : 1);
 if (sourceWeight != 0) return sourceWeight;
 return a.displayLabel
 .toLowerCase()
 .compareTo(b.displayLabel.toLowerCase());
 });

 if (!mounted) return;
 setState(() => _memberOptions = merged);
 }

 void _loadSavedRequirements(ProjectDataModel data) {
 final savedItems = data.frontEndPlanning.requirementItems;
 if (savedItems.isNotEmpty) {
 _replaceRowsSafely(
 savedItems.asMap().entries.map((entry) {
 final item = entry.value;
 final row = _createRow(entry.key + 1);
 row.setDescription(item.description);
 row.commentsController.text = item.comments;
 row.selectedType =
 _normalizeRequirementTypeSelection(item.requirementType);
 row.selectedDiscipline =
 _normalizeDisciplineSelection(item.discipline);
 row.roleController.text = item.role;
 row.personController.text =
 _resolvePersonSelection(item.person, roleHint: item.role);
 row.selectedPhase = _normalizePhaseSelection(item.phase);
 row.sourceController.text = item.requirementSource;
 return row;
 }).toList(),
 );
 return;
 }

 final savedText = data.frontEndPlanning.requirements.trim();
 if (savedText.isNotEmpty) {
 final lines = savedText
 .split('\n')
 .map((line) => line.trim())
 .where((line) => line.isNotEmpty)
 .toList();
 if (lines.isNotEmpty) {
 _replaceRowsSafely(
 lines.asMap().entries.map((entry) {
 final row = _createRow(entry.key + 1);
 row.setDescription(entry.value);
 return row;
 }).toList(),
 );
 }
 }
 }

 void _replaceRowsSafely(List<_RequirementRow> nextRows) {
 final previousRows = List<_RequirementRow>.from(_rows);
 if (!mounted) {
 for (final row in previousRows) {
 row.dispose();
 }
 for (final row in nextRows) {
 row.dispose();
 }
 return;
 }

 setState(() {
 _rows
 ..clear()
 ..addAll(nextRows);
 });

 for (final row in previousRows) {
 row.dispose();
 }
 }

 Future<void> _generateRequirementsFromContext() async {
 if (_isGeneratingRequirements) return;
 setState(() => _isGeneratingRequirements = true);

 try {
 final data = ProjectDataHelper.getData(context);
 final ctx = StringBuffer()
 ..writeln(
 ProjectDataHelper.buildFepContext(
 data,
 sectionLabel: 'Project Requirements',
 ),
 )
 ..writeln()
 ..writeln('Discipline assignment instructions:')
 ..writeln(
 '- Return a specific discipline for each requirement from this list whenever possible:',
 )
 ..writeln(_RequirementRow.disciplineOptions.join(', '))
 ..writeln('- Never return placeholder text like "Discipline".')
 ..writeln('- If no discipline fits, return "Other".');

 final ai = OpenAiServiceSecure();
 final reqs =
 await ai.generateRequirementsFromBusinessCase(ctx.toString());
 if (!mounted) return;
 if (reqs.isEmpty) return;

 _replaceRowsSafely(
 reqs.asMap().entries.map((entry) {
 final row = _createRow(entry.key + 1);
 final value = entry.value;
 final reqText = (value['requirement'] ?? '').toString().trim();
 final reqType = (value['requirementType'] ?? '').toString().trim();
 final discipline = (value['discipline'] ?? '').toString().trim();
 final role =
 (value['role'] ?? value['ownerRole'] ?? '').toString().trim();
 final person =
 (value['person'] ?? value['ownerPerson'] ?? '').toString().trim();
 final phase = (value['phase'] ?? value['implementationPhase'] ?? '')
 .toString()
 .trim();
 final source =
 (value['requirementSource'] ?? value['source'] ?? '').toString();

 row.setDescription(reqText);
 row.selectedType = _normalizeRequirementTypeSelection(reqType);
 row.selectedDiscipline = _normalizeDisciplineSelection(discipline);
 row.roleController.text = role;
 row.personController.text =
 _resolvePersonSelection(person, roleHint: role);
 row.selectedPhase = _normalizePhaseSelection(phase);
 row.sourceController.text = source.trim();
 return row;
 }).toList(),
 );

 _commitAutoSave(showSnack: false);
 _schedulePlanRegenerate();
 } catch (e) {
 debugPrint('AI requirements suggestion failed: $e');
 } finally {
 if (mounted) {
 setState(() => _isGeneratingRequirements = false);
 }
 }
 }

 void _maybeAutoGenerateRequirementsPlan() {
 if (_planEditedManually &&
 _requirementsPlanController.text.trim().isNotEmpty) {
 return;
 }
 if (_requirementsPlanController.text.trim().isNotEmpty) return;
 if (_rows.every((row) => row.descriptionController.text.trim().isEmpty)) {
 return;
 }
 _schedulePlanRegenerate();
 }

 void _handleRequirementChanged() {
 _scheduleAutoSave();
 _schedulePlanRegenerate();
 }

 void _handlePlanChanged() {
 if (!_settingPlanFromAi) {
 _planEditedManually = _requirementsPlanController.text.trim().isNotEmpty;
 }
 _scheduleAutoSave();
 }

 void _schedulePlanRegenerate() {
 if (_isGeneratingRequirementsPlan) return;
 if (_planEditedManually &&
 _requirementsPlanController.text.trim().isNotEmpty) {
 return;
 }

 _planTimer?.cancel();
 _planTimer = Timer(const Duration(milliseconds: 800), () {
 _generateRequirementsPlan();
 });
 }

 String _requirementsPlanContext() {
 final data = ProjectDataHelper.getData(context);
 final base =
 ProjectDataHelper.buildFepContext(data, sectionLabel: 'Requirements');
 final lines = _rows
 .map((row) => row.descriptionController.text.trim())
 .where((t) => t.isNotEmpty)
 .toList();
 final requirementsList = lines.isEmpty
 ? 'No requirements entered yet.'
 : lines.map((t) => '- $t').join('\n');

 return '''
$base

Requirements:
$requirementsList
''';
 }

 Future<void> _generateRequirementsPlan({bool force = false}) async {
 if (_isGeneratingRequirementsPlan) return;
 if (!force &&
 _planEditedManually &&
 _requirementsPlanController.text.trim().isNotEmpty) {
 return;
 }

 final hasAnyRequirement =
 _rows.any((row) => row.descriptionController.text.trim().isNotEmpty);
 if (!hasAnyRequirement) return;

 setState(() => _isGeneratingRequirementsPlan = true);

 try {
 final ctx = _requirementsPlanContext();
 if (ctx.trim().isEmpty) return;

 final ai = OpenAiServiceSecure();
 final text = await ai.generateFepSectionText(
 section: 'Requirements Plan',
 context: ctx,
 maxTokens: 700,
 temperature: 0.5,
 );

 if (!mounted) return;
 if (text.trim().isEmpty) return;

 _settingPlanFromAi = true;
 _requirementsPlanController.text = text.trim();
 _settingPlanFromAi = false;
 _planEditedManually = false;
 _commitAutoSave(showSnack: false);
 } catch (e) {
 debugPrint('AI requirements plan generation failed: $e');
 if (mounted) {
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(content: Text('Failed to generate plan: ${e.toString()}')),
 );
 }
 } finally {
 if (mounted) {
 setState(() => _isGeneratingRequirementsPlan = false);
 }
 }
 }

 Future<void> _regenerateRequirementRow(int index) async {
 if (index < 0 || index >= _rows.length) return;
 if (_isGeneratingRequirements || _isRegeneratingRow) return;

 setState(() {
 _isRegeneratingRow = true;
 _regeneratingRowIndex = index;
 });

 try {
 final data = ProjectDataHelper.getData(context);
 final ctx = ProjectDataHelper.buildFepContext(
 data,
 sectionLabel: 'Project Requirements',
 );
 final ai = OpenAiServiceSecure();
 final reqs = await ai.generateRequirementsFromBusinessCase(ctx);
 if (!mounted) return;

 final pickedIndex = reqs.isNotEmpty ? (index % reqs.length) : null;
 final picked = pickedIndex == null ? null : reqs[pickedIndex];
 final nextText =
 picked == null ? '' : (picked['requirement'] ?? '').toString().trim();

 if (nextText.isEmpty) {
 if (mounted) {
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(content: Text('AI returned no requirement text.')),
 );
 }
 return;
 }

 final row = _rows[index];
 row.aiUndoText = row.descriptionController.text;
 row.setDescription(nextText);

 final nextType = (picked?['requirementType'] ?? '').toString().trim();
 final nextDiscipline = (picked?['discipline'] ?? '').toString().trim();
 final nextRole =
 (picked?['role'] ?? picked?['ownerRole'] ?? '').toString().trim();
 final nextPerson =
 (picked?['person'] ?? picked?['ownerPerson'] ?? '').toString().trim();
 final nextPhase =
 (picked?['phase'] ?? picked?['implementationPhase'] ?? '')
 .toString()
 .trim();
 final nextSource =
 (picked?['requirementSource'] ?? picked?['source'] ?? '')
 .toString()
 .trim();

 if (nextType.isNotEmpty) {
 row.selectedType = _normalizeRequirementTypeSelection(nextType);
 }
 if (nextDiscipline.isNotEmpty) {
 row.selectedDiscipline = _normalizeDisciplineSelection(nextDiscipline);
 }
 if (nextRole.isNotEmpty) row.roleController.text = nextRole;
 if (nextPerson.isNotEmpty) {
 row.personController.text =
 _resolvePersonSelection(nextPerson, roleHint: nextRole);
 }
 if (nextPhase.isNotEmpty) {
 row.selectedPhase = _normalizePhaseSelection(nextPhase);
 }
 if (nextSource.isNotEmpty) {
 row.sourceController.text = nextSource;
 }

 _commitAutoSave(showSnack: false);
 await ProjectDataHelper.getProvider(context)
 .saveToFirebase(checkpoint: 'requirements');
 if (mounted) setState(() {});
 } catch (e) {
 debugPrint('Row requirement regenerate failed: $e');
 } finally {
 if (mounted) {
 setState(() {
 _isRegeneratingRow = false;
 _regeneratingRowIndex = null;
 });
 }
 }
 }

 void _undoRequirementRow(int index) {
 if (index < 0 || index >= _rows.length) return;
 final row = _rows[index];
 final previous = row.aiUndoText;
 if (previous == null || previous.isEmpty) return;

 row.setDescription(previous);
 row.aiUndoText = null;
 _commitAutoSave(showSnack: false);
 ProjectDataHelper.getProvider(context)
 .saveToFirebase(checkpoint: 'requirements');
 if (mounted) setState(() {});
 }

 String _normalizePhaseSelection(String? rawValue) {
 final value = (rawValue ?? '').trim();
 if (value.isEmpty) return 'Planning';

 for (final option in _RequirementRow.phaseOptions) {
 if (option.toLowerCase() == value.toLowerCase()) {
 return option;
 }
 }

 final normalized = value.toLowerCase();
 if (normalized.startsWith('init')) return 'Initiation';
 if (normalized.startsWith('plan')) return 'Planning';
 if (normalized.startsWith('des')) return 'Design';
 if (normalized.startsWith('exec') || normalized.contains('implement')) {
 return 'Execution';
 }
 if (normalized.startsWith('launch') ||
 normalized.contains('go live') ||
 normalized.contains('golive')) {
 return 'Launch';
 }
 if (normalized == 'all phases' || normalized == 'all phase') return 'ALL';
 return 'Planning';
 }

 String? _normalizeRequirementTypeSelection(String? rawValue) {
 final value = (rawValue ?? '').trim();
 if (value.isEmpty) return null;

 for (final option in _RequirementRow.requirementTypeOptions) {
 if (option.toLowerCase() == value.toLowerCase()) {
 return option;
 }
 }

 final normalized = value.toLowerCase();
 if (normalized.contains('functional') &&
 !normalized.contains('non-functional')) {
 return 'Functional';
 }
 if (normalized.contains('non') && normalized.contains('functional')) {
 return 'Non-Functional';
 }
 if (normalized.contains('technical') || normalized == 'tech') {
 return 'Technical';
 }
 if (normalized.contains('regulat') || normalized.contains('compliance')) {
 return 'Regulatory';
 }
 if (normalized.contains('operat')) {
 return 'Operational';
 }
 if (normalized.contains('safe')) {
 return 'Safety';
 }
 if (normalized.contains('sustain')) {
 return 'Sustainability';
 }
 if (normalized.contains('business')) {
 return 'Business';
 }
 if (normalized.contains('stakeholder')) {
 return 'Stakeholder';
 }
 if (normalized.contains('solution')) {
 return 'Solutions';
 }
 if (normalized.contains('transition')) {
 return 'Transitional';
 }
 if (normalized == 'other' || normalized == 'general') {
 return 'Other';
 }

 return null;
 }

 String? _normalizeDisciplineSelection(String? rawValue) {
 final value = (rawValue ?? '').trim();
 if (value.isEmpty) return null;

 for (final option in _RequirementRow.disciplineOptions) {
 if (option.toLowerCase() == value.toLowerCase()) {
 return option;
 }
 }

 final normalized = value.toLowerCase();
 if (normalized == 'discipline') return 'Other';
 if (normalized.contains('arch')) return 'Architecture';
 if (normalized.contains('civil')) return 'Civil';
 if (normalized.contains('elect')) return 'Electrical';
 if (normalized.contains('mech')) return 'Mechanical';
 if (normalized == 'it' || normalized.contains('information technology')) {
 return 'IT';
 }
 if (normalized.contains('operat')) return 'Operations';
 if (normalized.contains('safe')) return 'Safety';
 if (normalized.contains('secur')) return 'Security';
 if (normalized.contains('procure')) return 'Procurement';
 if (normalized.contains('commerc')) return 'Commercial';
 if (normalized.contains('qualit')) return 'Quality';
 if (normalized.contains('regulat') || normalized.contains('compliance')) {
 return 'Regulatory';
 }
 if (normalized.contains('program') ||
 normalized.contains('project management')) {
 return 'Program Management';
 }
 return 'Other';
 }

 String _resolvePersonSelection(String rawValue, {String roleHint = ''}) {
 final value = rawValue.trim();
 if (value.isEmpty) {
 return _matchMemberByRole(roleHint)?.displayLabel ?? '';
 }

 _AssignableMember? exactMatch;
 final normalizedValue = value.toLowerCase();
 for (final member in _memberOptions) {
 final memberLabel = member.displayLabel.toLowerCase();
 final memberEmail = member.email.toLowerCase();
 if (memberLabel == normalizedValue || memberEmail == normalizedValue) {
 exactMatch = member;
 break;
 }
 }

 if (exactMatch != null) return exactMatch.displayLabel;

 final roleMatch = _matchMemberByRole(roleHint);
 if (roleMatch != null) return roleMatch.displayLabel;
 return value;
 }

 _AssignableMember? _matchMemberByRole(String rawRole) {
 final role = rawRole.trim().toLowerCase();
 if (role.isEmpty) return null;
 for (final member in _memberOptions) {
 final memberRole = member.role.trim().toLowerCase();
 if (memberRole.isEmpty) continue;
 if (memberRole == role ||
 memberRole.contains(role) ||
 role.contains(memberRole)) {
 return member;
 }
 }
 return null;
 }

 Future<String> _resolveCurrentUserRoleForRequirementsSubmit() async {
 var resolvedRole = 'Member';

 try {
 final user = FirebaseAuth.instance.currentUser;
 final provider = ProjectDataHelper.getProvider(context);
 final data = provider.projectData;
 final email = user?.email?.trim().toLowerCase() ?? '';
 final uid = user?.uid ?? '';
 final displayName =
 FirebaseAuthService.displayNameOrEmail(fallback: '').trim();

 if (UserService.isAdminEmail(email)) {
 resolvedRole = 'Owner';
 }

 final projectId = data.projectId?.trim() ?? '';
 if (projectId.isNotEmpty && uid.isNotEmpty) {
 final project = await ProjectService.getProjectById(projectId);
 if (project != null) {
 final ownerEmail = project.ownerEmail.trim().toLowerCase();
 if (project.ownerId == uid ||
 (email.isNotEmpty && ownerEmail == email)) {
 resolvedRole = 'Owner';
 }
 }
 }

 if (!_isRoleAuthorizedForRequirementSubmit(resolvedRole)) {
 for (final member in data.teamMembers) {
 final memberEmail = member.email.trim().toLowerCase();
 final memberName = member.name.trim().toLowerCase();
 final role = member.role.trim();
 final matchesByEmail = email.isNotEmpty &&
 memberEmail.isNotEmpty &&
 memberEmail == email;
 final matchesByName = displayName.isNotEmpty &&
 memberName.isNotEmpty &&
 (memberName == displayName.toLowerCase() ||
 memberName.contains(displayName.toLowerCase()) ||
 displayName.toLowerCase().contains(memberName));
 if ((matchesByEmail || matchesByName) && role.isNotEmpty) {
 resolvedRole = role;
 break;
 }
 }
 }

 if (!_isRoleAuthorizedForRequirementSubmit(resolvedRole)) {
 final pmName = data.charterProjectManagerName.trim();
 if (_matchesIdentity(pmName, displayName, email)) {
 resolvedRole = 'Project Manager';
 }
 }
 } catch (e) {
 debugPrint('Failed to resolve submitter role for requirements: $e');
 }

 return resolvedRole;
 }

 bool _matchesIdentity(String candidate, String displayName, String email) {
 final normalizedCandidate = candidate.trim().toLowerCase();
 if (normalizedCandidate.isEmpty) return false;

 final normalizedDisplay = displayName.trim().toLowerCase();
 final emailLocal = email.contains('@')
 ? email.split('@').first.trim().toLowerCase()
 : email.trim().toLowerCase();

 if (normalizedDisplay.isNotEmpty) {
 if (normalizedCandidate == normalizedDisplay) return true;
 if (normalizedDisplay.contains(normalizedCandidate) ||
 normalizedCandidate.contains(normalizedDisplay)) {
 return true;
 }
 }

 if (emailLocal.isNotEmpty) {
 if (normalizedCandidate == emailLocal) return true;
 if (emailLocal.contains(normalizedCandidate) ||
 normalizedCandidate.contains(emailLocal)) {
 return true;
 }
 }

 return false;
 }

 String _normalizeRole(String role) {
 final lower = role.trim().toLowerCase();
 if (lower.contains('project manager')) return 'project manager';
 if (lower.contains('technical manager')) return 'technical manager';
 if (lower.contains('founder')) return 'owner';
 if (lower.contains('owner')) return 'owner';
 return lower;
 }

 bool _isRoleAuthorizedForRequirementSubmit(String role) {
 return _authorizedRequirementSubmitRoles.contains(_normalizeRole(role));
 }  void _onReorder(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex--;
    if (oldIndex < 0 || oldIndex >= _rows.length) return;
    if (newIndex < 0 || newIndex >= _rows.length) return;
    setState(() {
      final row = _rows.removeAt(oldIndex);
      _rows.insert(newIndex, row);
      for (var i = 0; i < _rows.length; i++) {
        _rows[i].number = i + 1;
      }
    });
    _commitAutoSave(showSnack: false);
  }

  void _deleteRow(int index) {
    if (index < 0 || index >= _rows.length) return;
    setState(() {
      _rows[index].dispose();
      _rows.removeAt(index);
      for (var i = 0; i < _rows.length; i++) {
        _rows[i].number = i + 1;
      }
    });
    _commitAutoSave(showSnack: false);
  }

 List<RequirementItem> _buildRequirementItems() {
 return _rows
 .map(
 (row) => RequirementItem(
 description: row.descriptionController.text.trim(),
 requirementType: row.selectedType ?? '',
 discipline: row.selectedDiscipline ?? '',
 role: row.roleController.text.trim(),
 person: row.personController.text.trim(),
 phase: row.selectedPhase ?? '',
 requirementSource: row.sourceController.text.trim(),
 comments: row.commentsController.text.trim(),
 ),
 )
 .where(
 (item) =>
 item.description.isNotEmpty ||
 item.requirementType.isNotEmpty ||
 item.discipline.isNotEmpty ||
 item.role.isNotEmpty ||
 item.person.isNotEmpty ||
 item.phase.isNotEmpty ||
 item.requirementSource.isNotEmpty ||
 item.comments.isNotEmpty,
 )
 .toList();
 }

 void _handleSubmit() async {
 final continueAnyway = await showProceedWithoutReviewDialog(
 context,
 title: 'Confirm before submitting requirements',
 message:
 'You are about to continue to the next step. You can proceed now and return later to refine details, or cancel and review first.',
 );
 if (!continueAnyway) return;

 final requirementItems = _buildRequirementItems();
 if (requirementItems.isEmpty) {
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(
 content: Text('Add at least one requirement before submitting.'),
 ),
 );
 return;
 }

 final missingAssignmentRows = <int>[];
 final missingPhaseRows = <int>[];
 for (var i = 0; i < requirementItems.length; i++) {
 final item = requirementItems[i];
 final hasAssignment = item.discipline.trim().isNotEmpty ||
 item.role.trim().isNotEmpty ||
 item.person.trim().isNotEmpty;
 if (!hasAssignment) {
 missingAssignmentRows.add(i + 1);
 }
 if (item.phase.trim().isEmpty) {
 missingPhaseRows.add(i + 1);
 }
 }

 if (missingAssignmentRows.isNotEmpty) {
 await showDialog<void>(
 context: context,
 builder: (dialogContext) => AlertDialog(
 title: const Text('Assignment Required'),
 content: Text(
 'Each requirement must include at least one assignment: Discipline, Role, or Person.\n\nUpdate rows: ${missingAssignmentRows.join(', ')}',
 ),
 actions: [
 TextButton(
 onPressed: () => Navigator.pop(dialogContext),
 child: const Text('OK'),
 ),
 ],
 ),
 );
 return;
 }

 if (missingPhaseRows.isNotEmpty) {
 await showDialog<void>(
 context: context,
 builder: (dialogContext) => AlertDialog(
 title: const Text('Phase Required'),
 content: Text(
 'Assign an implementation phase (Initiation, Planning, Design, Execution, Launch, or ALL) for every requirement.\n\nUpdate rows: ${missingPhaseRows.join(', ')}',
 ),
 actions: [
 TextButton(
 onPressed: () => Navigator.pop(dialogContext),
 child: const Text('OK'),
 ),
 ],
 ),
 );
 return;
 }

 final resolvedRole = await _resolveCurrentUserRoleForRequirementsSubmit();
 if (!_isRoleAuthorizedForRequirementSubmit(resolvedRole)) {
 if (!mounted) return;
 await showDialog<void>(
 context: context,
 builder: (dialogContext) => AlertDialog(
 title: const Text('Authorization Required'),
 content: Text(
 'Only Owner, Project Manager, or Technical Manager can submit final requirements.\n\nCurrent role: $resolvedRole\n\nPlease notify the correct person to review and submit this section.',
 ),
 actions: [
 TextButton(
 onPressed: () => Navigator.pop(dialogContext),
 child: const Text('OK'),
 ),
 ],
 ),
 );
 return;
 }

 if (!mounted) return;
 final confirmed = await showDialog<bool>(
 context: context,
 builder: (dialogContext) => AlertDialog(
 title: const Text('Confirm Requirement Coverage'),
 content: const Text(
 'Please confirm that all applicable project requirements, particularly regulatory, functional, and operational, are fully captured here, as this will serve as the foundation for the defined project scope.',
 ),
 actions: [
 TextButton(
 onPressed: () => Navigator.pop(dialogContext, false),
 child: const Text('Cancel'),
 ),
 ElevatedButton(
 onPressed: () => Navigator.pop(dialogContext, true),
 child: const Text('Confirm and Submit'),
 ),
 ],
 ),
 );

 if (confirmed != true || !mounted) return;

 final requirementsText = requirementItems
 .map((item) => item.description.trim())
 .where((text) => text.isNotEmpty)
 .join('\n');
 final requirementsNotes = _notesController.text.trim();
 final requirementsPlan = _requirementsPlanController.text.trim();

 await ProjectDataHelper.saveAndNavigate(
 context: context,
 checkpoint: 'requirements',
 saveInBackground: true,
 nextScreenBuilder: () =>
 PlanningPhaseNavigation.resolveNextScreen(context, 'requirements') ??
 const SsherStackedScreen(),
 dataUpdater: (data) => data.copyWith(
 frontEndPlanning: ProjectDataHelper.updateFEPField(
 current: data.frontEndPlanning,
 requirements: requirementsText,
 requirementsPlan: requirementsPlan,
 requirementsNotes: requirementsNotes,
 requirementItems: requirementItems,
 ),
 ),
 );
 }

 void _handleNotesChanged() {
 _scheduleAutoSave();
 }

 void _scheduleAutoSave({bool showSnack = true}) {
 _autoSaveTimer?.cancel();
 _autoSaveTimer = Timer(const Duration(milliseconds: 500), () {
 _commitAutoSave(showSnack: showSnack);
 });
 }

 void _commitAutoSave({bool showSnack = true}) {
 if (!mounted) return;

 final items = _buildRequirementItems();
 final requirementsText = items
 .map((item) => item.description.trim())
 .where((text) => text.isNotEmpty)
 .join('\n');
 final requirementsNotes = _notesController.text.trim();
 final requirementsPlan = _requirementsPlanController.text.trim();
 final provider = ProjectDataHelper.getProvider(context);

 provider.updateField(
 (data) => data.copyWith(
 frontEndPlanning: ProjectDataHelper.updateFEPField(
 current: data.frontEndPlanning,
 requirements: requirementsText,
 requirementsPlan: requirementsPlan,
 requirementsNotes: requirementsNotes,
 requirementItems: items,
 ),
 ),
 );
 provider.saveToFirebase(checkpoint: 'requirements');

 if (showSnack) {
 _showAutoSaveSnack();
 }
 }

 void _showAutoSaveSnack() {
 final now = DateTime.now();
 if (_lastAutoSaveSnackAt != null &&
 now.difference(_lastAutoSaveSnackAt!) < const Duration(seconds: 4)) {
 return;
 }

 _lastAutoSaveSnackAt = now;
 final messenger = ScaffoldMessenger.maybeOf(context);
 if (messenger == null) return;

 messenger
 ..removeCurrentSnackBar()
 ..showSnackBar(
 const SnackBar(
 content: Text('Draft saved'),
 duration: Duration(seconds: 1),
 ),
 );
 }

 bool _hasAnyRequirementInputs() {
 for (final row in _rows) {
 if (row.descriptionController.text.trim().isNotEmpty ||
 row.commentsController.text.trim().isNotEmpty ||
 row.roleController.text.trim().isNotEmpty ||
 row.personController.text.trim().isNotEmpty ||
 row.sourceController.text.trim().isNotEmpty ||
 (row.selectedDiscipline ?? '').trim().isNotEmpty ||
 (row.selectedType ?? '').trim().isNotEmpty) {
 return true;
 }
 }
 return false;
 }

 Future<void> _confirmRegenerate() async {
 if (_isGeneratingRequirements) return;
 if (!_hasAnyRequirementInputs()) {
 await _generateRequirementsFromContext();
 return;
 }

 final shouldRegenerate = await showDialog<bool>(
 context: context,
 builder: (dialogContext) => AlertDialog(
 title: const Text('Regenerate requirements?'),
 content: const Text(
 'This will replace your current requirements. Continue?',
 ),
 actions: [
 TextButton(
 onPressed: () => Navigator.of(dialogContext).pop(false),
 child: const Text('Cancel'),
 ),
 ElevatedButton(
 onPressed: () => Navigator.of(dialogContext).pop(true),
 child: const Text('Regenerate'),
 ),
 ],
 ),
 );

 if (shouldRegenerate == true && mounted) {
 await _generateRequirementsFromContext();
 }
 }

 @override
 void dispose() {
 _autoSaveTimer?.cancel();
 _planTimer?.cancel();
 _requirementsHorizontalController.dispose();
 _requirementsVerticalController.dispose();
 _notesController.removeListener(_handleNotesChanged);
 _requirementsPlanController.removeListener(_handlePlanChanged);
 _notesController.dispose();
 _requirementsPlanController.dispose();
 for (final row in _rows) {
 row.dispose();
 }
 super.dispose();
 }

 @override
 Widget build(BuildContext context) {
 return Scaffold(
 backgroundColor: Colors.white,
 body: SafeArea(
 child: Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 DraggableSidebar(
 openWidth: AppBreakpoints.sidebarWidth(context),
 child:
 const InitiationLikeSidebar(activeItemLabel: 'Requirements'),
 ),
 Expanded(
 child: Stack(
 children: [
 MobileSidebarHamburger(
 sidebar: const InitiationLikeSidebar(
 activeItemLabel: 'Requirements',
 ),
 ),
 const AdminEditToggle(),
 Column(
 children: [
 _buildHeader(context),
 Expanded(
 child: Column(
 children: [
 Expanded(
 child: SingleChildScrollView(
 padding: const EdgeInsets.symmetric(
 horizontal: 32,
 vertical: 24,
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 PlanningPhaseHeader(title: 'Requirements', onExportPdf: _exportPdf),
 const SizedBox(height: 16),
 _roundedField(
 controller: _notesController,
 hint: 'Input your notes here...',
 minLines: 3,
 ),
 const SizedBox(height: 20),
 Row(
 crossAxisAlignment:
 CrossAxisAlignment.start,
 children: [
 Expanded(
 child: Column(
 crossAxisAlignment:
 CrossAxisAlignment.start,
 children: const [
 Text(
 'Requirements Plan',
 style: TextStyle(
 fontSize: 20,
 fontWeight: FontWeight.w700,
 color: Color(0xFF111827),
 ),
 ),
 SizedBox(height: 6),
 Text(
 'AI-suggested plan for implementing the requirements. You can edit it.',
 style: TextStyle(
 fontSize: 13,
 color: Color(0xFF6B7280),
 height: 1.2,
 ),
 ),
 ],
 ),
 ),
 IconButton(
 icon: _isGeneratingRequirementsPlan
 ? const SizedBox(
 width: 20,
 height: 20,
 child:
 CircularProgressIndicator(
 strokeWidth: 2,
 color: Color(0xFF2563EB),
 ),
 )
 : const Icon(
 Icons.auto_fix_high,
 size: 20,
 color: Color(0xFF2563EB),
 ),
 onPressed:
 _isGeneratingRequirementsPlan
 ? null
 : () =>
 _generateRequirementsPlan(
 force: true,
 ),
 tooltip:
 'Regenerate requirements plan',
 ),
 ],
 ),
 const SizedBox(height: 12),
 _roundedField(
 controller: _requirementsPlanController,
 hint:
 'AI will generate a requirements plan based on your entries...',
 minLines: 4,
 ),
 const SizedBox(height: 24),
 Row(
 crossAxisAlignment:
 CrossAxisAlignment.start,
 children: [
 const Expanded(
 child: Column(
 crossAxisAlignment:
 CrossAxisAlignment.start,
 children: [
 Text(
 'Project Requirements',
 style: TextStyle(
 fontSize: 20,
 fontWeight: FontWeight.w700,
 color: Color(0xFF111827),
 ),
 ),
 SizedBox(height: 6),
 Text(
 'Identify actual needs, conditions, or capabilities that this project must meet to be considered successful',
 style: TextStyle(
 fontSize: 13,
 color: Color(0xFF6B7280),
 height: 1.2,
 ),
 ),
 ],
 ),
 ),
 IconButton(
 icon: _isGeneratingRequirements
 ? const SizedBox(
 width: 20,
 height: 20,
 child:
 CircularProgressIndicator(
 strokeWidth: 2,
 color: Color(0xFF2563EB),
 ),
 )
 : const Icon(
 Icons.refresh,
 size: 20,
 color: Color(0xFF2563EB),
 ),
 onPressed: _isGeneratingRequirements
 ? null
 : _confirmRegenerate,
 tooltip: 'Regenerate requirements',
 ),
 ],
 ),
 const SizedBox(height: 14),
 _buildRequirementsTable(context),
 const SizedBox(height: 16),
 _buildActionButtons(),
 const SizedBox(height: 24),
 ],
 ),
 ),
 ),
 Padding(
 padding: const EdgeInsets.fromLTRB(32, 0, 96, 24),
 child: _buildDesktopFooter(context),
 ),
 ],
 ),
 ),
 ],
 ),
 const Positioned(
 right: 24,
 bottom: 112,
 child: KazAiChatBubble(positioned: false),
 ),
 ],
 ),
 ),
 ],
 ),
 ),
 );
 }

 Widget _buildHeader(BuildContext context) {
 final user = FirebaseAuth.instance.currentUser;
 final displayName =
 FirebaseAuthService.displayNameOrEmail(fallback: 'User');
 final email = user?.email ?? '';
 final initial = displayName.trim().isNotEmpty
 ? displayName.trim().characters.first.toUpperCase()
 : 'U';

 return Container(
 height: 88,
 padding: const EdgeInsets.symmetric(horizontal: 24),
 decoration: const BoxDecoration(
 color: Colors.white,
 border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
 ),
 child: Row(
 children: [
 IconButton(
 icon: const Icon(Icons.arrow_back_ios, size: 16),
 onPressed: () =>
 PlanningPhaseNavigation.goToPrevious(context, 'requirements'),
 ),
 IconButton(
 icon: const Icon(Icons.arrow_forward_ios, size: 16),
 onPressed: () =>
 PlanningPhaseNavigation.goToNext(context, 'requirements'),
 ),
 const Spacer(),
 const Text(
 'Planning Phase',
 style: TextStyle(
 fontSize: 24,
 fontWeight: FontWeight.w700,
 color: Color(0xFF111827),
 ),
 ),
 const Spacer(),
 const SizedBox(width: 12),
 Row(
 children: [
 CircleAvatar(
 radius: 16,
 backgroundColor: const Color(0xFFFFC812),
 child: Text(
 initial,
 style: const TextStyle(
 fontSize: 14,
 fontWeight: FontWeight.bold,
 color: Colors.black,
 ),
 ),
 ),
 const SizedBox(width: 8),
 Column(
 mainAxisAlignment: MainAxisAlignment.center,
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 displayName,
 style: const TextStyle(
 fontSize: 13,
 fontWeight: FontWeight.w600,
 ),
 ),
 StreamBuilder<bool>(
 stream: UserService.watchAdminStatus(),
 builder: (context, snapshot) {
 final isAdmin =
 snapshot.data ?? UserService.isAdminEmail(email);
 return Text(
 isAdmin ? 'Admin' : 'Member',
 style:
 const TextStyle(fontSize: 11, color: Colors.grey),
 );
 },
 ),
 ],
 ),
 ],
 ),
 ],
 ),
 );
 }  Widget _buildRequirementsTable(BuildContext context) {
    final headerStyle = const TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w700,
      color: Color(0xFF4B5563),
    );
    final borderColor = const Color(0xFFE5E7EB);
    final bgHeader = const Color(0xFFF9FAFB);

    // Column widths matching the original table
    const colW = <double>[
      64,   // 0: No + drag handle
      612,  // 1: Requirement
      190,  // 2: Requirement type
      180,  // 3: Discipline
      190,  // 4: Role
      190,  // 5: Person
      150,  // 6: Phase
      260,  // 7: Requirement source
      468,  // 8: Comments & source links
      56,   // 9: Delete
    ];
    const totalWidth = 2360.0;

    // Helper to build a header cell
    Widget hCell(String text, double w) {
      return SizedBox(
        width: w,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Center(child: Text(text, style: headerStyle, textAlign: TextAlign.center)),
        ),
      );
    }

    // Helper to build a data row
    Widget buildDataRow(int index) {
      final row = _rows[index];
      final isRowLoading = _isRegeneratingRow && _regeneratingRowIndex == index;

      return Container(
        key: ValueKey('req_row_$index'),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: borderColor)),
        ),
        child: Row(
          children: [
            // Col 0: No + drag handle
            ReorderableDragStartListener(
              index: index,
              child: SizedBox(
                width: colW[0],
                child: Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.drag_indicator, size: 18, color: const Color(0xFF9CA3AF)),
                      const SizedBox(width: 2),
                      Text('${row.number}',
                        style: const TextStyle(fontSize: 14, color: Color(0xFF111827)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Col 1: Requirement
            SizedBox(
              width: colW[1],
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Tooltip(
                            message: 'Regenerate (AI)',
                            child: IconButton(
                              onPressed: isRowLoading ? null : () => _regenerateRequirementRow(index),
                              icon: isRowLoading
                                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                                  : const Icon(Icons.refresh, size: 18, color: Color(0xFF2563EB)),
                              padding: const EdgeInsets.all(6),
                              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                              splashRadius: 18,
                            ),
                          ),
                          Tooltip(
                            message: 'Undo',
                            child: IconButton(
                              onPressed: () => _undoRequirementRow(index),
                              icon: const Icon(Icons.undo, size: 18, color: Color(0xFF6B7280)),
                              padding: const EdgeInsets.all(6),
                              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                              splashRadius: 18,
                            ),
                          ),
                        ],
                      ),
                    ),
                    VoiceTextField(
                      controller: row.descriptionController,
                      minLines: 2,
                      maxLines: null,
                      onChanged: (_) => _handleRequirementChanged(),
                      decoration: const InputDecoration(
                        hintText: 'Requirement description',
                        hintStyle: TextStyle(color: Color(0xFF9CA3AF)),
                        border: InputBorder.none,
                        isDense: true,
                      ),
                      style: const TextStyle(fontSize: 14, color: Color(0xFF111827)),
                    ),
                  ],
                ),
              ),
            ),
            // Col 2: Requirement type
            SizedBox(
              width: colW[2],
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: _TypeDropdown(
                  value: row.selectedType,
                  onChanged: (value) {
                    row.selectedType = value;
                    _handleRequirementChanged();
                  },
                ),
              ),
            ),
            // Col 3: Discipline
            SizedBox(
              width: colW[3],
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: _DisciplineDropdown(
                  value: row.selectedDiscipline,
                  onChanged: (value) {
                    row.selectedDiscipline = value;
                    _handleRequirementChanged();
                  },
                ),
              ),
            ),
            // Col 4: Role
            SizedBox(
              width: colW[4],
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: VoiceTextField(
                  controller: row.roleController,
                  maxLines: 1,
                  onChanged: (_) => _handleRequirementChanged(),
                  decoration: const InputDecoration(
                    hintText: 'Role',
                    hintStyle: TextStyle(color: Color(0xFF9CA3AF)),
                    border: InputBorder.none,
                    isDense: true,
                  ),
                  style: const TextStyle(fontSize: 14, color: Color(0xFF111827)),
                ),
              ),
            ),
            // Col 5: Person
            SizedBox(
              width: colW[5],
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: _PersonDropdownField(
                  value: row.personController.text,
                  options: _memberOptions,
                  hint: 'Person',
                  onChanged: (value) {
                    row.personController.text = value;
                    _handleRequirementChanged();
                  },
                ),
              ),
            ),
            // Col 6: Phase
            SizedBox(
              width: colW[6],
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: _PhaseDropdown(
                  value: row.selectedPhase,
                  onChanged: (value) {
                    row.selectedPhase = value;
                    _handleRequirementChanged();
                  },
                ),
              ),
            ),
            // Col 7: Requirement source
            SizedBox(
              width: colW[7],
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: VoiceTextField(
                  controller: row.sourceController,
                  maxLines: 1,
                  onChanged: (_) => _handleRequirementChanged(),
                  decoration: const InputDecoration(
                    hintText: 'Requirement source',
                    hintStyle: TextStyle(color: Color(0xFF9CA3AF)),
                    border: InputBorder.none,
                    isDense: true,
                  ),
                  style: const TextStyle(fontSize: 14, color: Color(0xFF111827)),
                ),
              ),
            ),
            // Col 8: Comments & source links
            SizedBox(
              width: colW[8],
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: VoiceTextField(
                  controller: row.commentsController,
                  minLines: 2,
                  maxLines: null,
                  onChanged: (_) => _handleRequirementChanged(),
                  decoration: const InputDecoration(
                    hintText: 'Comments / source links',
                    hintStyle: TextStyle(color: Color(0xFF9CA3AF)),
                    border: InputBorder.none,
                    isDense: true,
                  ),
                  style: const TextStyle(fontSize: 14, color: Color(0xFF111827)),
                ),
              ),
            ),
            // Col 9: Delete
            SizedBox(
              width: colW[9],
              child: Center(
                child: IconButton(
                  icon: const Icon(Icons.delete_outline, size: 20, color: Color(0xFFEF4444)),
                  onPressed: () => _deleteRow(index),
                  tooltip: 'Delete requirement',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: SizedBox(
        height: 460,
        child: Scrollbar(
          controller: _requirementsHorizontalController,
          thumbVisibility: true,
          child: SingleChildScrollView(
            controller: _requirementsHorizontalController,
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: totalWidth),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header row (non-draggable)
                  Container(
                    key: const ValueKey('req_header'),
                    decoration: BoxDecoration(
                      color: bgHeader,
                      border: Border(
                        bottom: BorderSide(color: borderColor),
                      ),
                    ),
                    child: Row(
                      children: [
                        hCell('No', colW[0]),
                        hCell('Requirement', colW[1]),
                        hCell('Requirement type', colW[2]),
                        hCell('Discipline', colW[3]),
                        hCell('Role', colW[4]),
                        hCell('Person', colW[5]),
                        hCell('Phase', colW[6]),
                        hCell('Requirement source', colW[7]),
                        hCell('Comments and Requirement Source Links', colW[8]),
                        hCell('', colW[9]),
                      ],
                    ),
                  ),
                  // Data rows (draggable) or empty state
                  Expanded(
                    child: _rows.isEmpty
                        ? const Center(
                            child: Text(
                              'No requirements yet. Add one or import from CSV.',
                              style: TextStyle(color: Color(0xFF9CA3AF)),
                            ),
                          )
                        : Scrollbar(
                            controller: _requirementsVerticalController,
                            thumbVisibility: true,
                            child: ReorderableListView(
                              buildDefaultDragHandles: false,
                              onReorder: _onReorder,
                              children: List.generate(_rows.length, (i) => buildDataRow(i)),
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

 Widget _buildDesktopFooter(BuildContext context) {
 return Container(
 width: double.infinity,
 padding: const EdgeInsets.all(14),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(12),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 ),
 child: Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 OutlinedButton(
 onPressed: () =>
 PlanningPhaseNavigation.goToPrevious(context, 'requirements'),
 style: OutlinedButton.styleFrom(
 foregroundColor: const Color(0xFF374151),
 side: const BorderSide(color: Color(0xFFD1D5DB)),
 shape: RoundedRectangleBorder(
 borderRadius: BorderRadius.circular(12),
 ),
 padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
 ),
 child: const Icon(Icons.arrow_back_ios_new_rounded, size: 16),
 ),
 const SizedBox(width: 16),
 const Expanded(child: SizedBox.shrink()),
 const SizedBox(width: 16),
 ElevatedButton(
 onPressed: _handleSubmit,
 style: ElevatedButton.styleFrom(
 backgroundColor: const Color(0xFFFFD700),
 foregroundColor: Colors.black,
 disabledBackgroundColor: const Color(0xFFE5E7EB),
 disabledForegroundColor: const Color(0xFF9CA3AF),
 padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
 shape: RoundedRectangleBorder(
 borderRadius: BorderRadius.circular(22),
 ),
 elevation: 0,
 ),
 child: const Text(
 'Submit',
 style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
 ),
 ),
 ],
 ),
 );
 }

  List<CsvColumnSpec> get _csvColumns => [
    CsvColumnSpec(key: 'description', label: 'Requirement', required: true, sampleValue: 'The system shall support user authentication'),
    CsvColumnSpec(key: 'type', label: 'Type', allowedValues: _RequirementRow.requirementTypeOptions, defaultValue: 'Functional', sampleValue: 'Functional'),
    CsvColumnSpec(key: 'discipline', label: 'Discipline', allowedValues: _RequirementRow.disciplineOptions, defaultValue: 'IT', sampleValue: 'IT'),
    CsvColumnSpec(key: 'role', label: 'Role', sampleValue: 'Requirements Lead'),
    CsvColumnSpec(key: 'person', label: 'Person', sampleValue: 'John Doe'),
    CsvColumnSpec(key: 'phase', label: 'Phase', allowedValues: _RequirementRow.phaseOptions, defaultValue: 'Planning', sampleValue: 'Planning'),
    CsvColumnSpec(key: 'source', label: 'Source', sampleValue: 'Stakeholder interview'),
    CsvColumnSpec(key: 'comments', label: 'Comments', sampleValue: 'High priority'),
  ];

  void _downloadTemplate() {
    final template = CsvImportHelper.generateTemplate(_csvColumns);
    final filename = CsvImportHelper.templateFilename('Project Requirements');
    final bytes = utf8.encode(template);
    dl.downloadFile(bytes, filename, mimeType: 'text/csv');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('CSV template downloaded!'),
          backgroundColor: Color(0xFF10B981),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Widget _buildActionButtons() {
  return Row(
  children: [
  SizedBox(
  height: 44,
  child: OutlinedButton.icon(
  onPressed: () async {
  final rows = await showCsvImportDialog(
  context,
  tableTitle: 'Project Requirements',
  columns: _csvColumns,
  );
  if (rows == null || !mounted) return;
 setState(() {
 for (final row in rows) {
 final newRow = _createRow(_rows.length + 1);
 newRow.descriptionController.text = row['description'] ?? '';
 newRow.selectedType = _RequirementRow.requirementTypeOptions.contains(row['type']) ? row['type'] : 'Functional';
 newRow.selectedDiscipline = _RequirementRow.disciplineOptions.contains(row['discipline']) ? row['discipline'] : 'IT';
 newRow.selectedPhase = _RequirementRow.phaseOptions.contains(row['phase']) ? row['phase'] : 'Planning';
 newRow.roleController.text = row['role'] ?? '';
 newRow.personController.text = row['person'] ?? '';
 newRow.sourceController.text = row['source'] ?? '';
 newRow.commentsController.text = row['comments'] ?? '';
 _rows.add(newRow);
 }
 });
 _scheduleAutoSave(showSnack: false);
 if (mounted) {
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(
 content: Text('${rows.length} requirements imported from CSV'),
 backgroundColor: Colors.green,
 behavior: SnackBarBehavior.floating,
 ),
 );
 }
 },
 icon: const Icon(Icons.upload_file_outlined, size: 18),
 label: const Text('Import CSV', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
 style: OutlinedButton.styleFrom(
 backgroundColor: Colors.white,
 foregroundColor: const Color(0xFF2563EB),
 side: const BorderSide(color: Color(0xFF93C5FD)),
 shape: RoundedRectangleBorder(
 borderRadius: BorderRadius.circular(12),
 ),
 padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
 ),
  ),
  ),
  const SizedBox(width: 12),
  SizedBox(
  height: 44,
  child: OutlinedButton.icon(
  onPressed: _downloadTemplate,
  icon: const Icon(Icons.download, size: 18),
  label: const Text('Template', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
  style: OutlinedButton.styleFrom(
  backgroundColor: Colors.white,
  foregroundColor: const Color(0xFF2563EB),
  side: const BorderSide(color: Color(0xFF93C5FD)),
  shape: RoundedRectangleBorder(
  borderRadius: BorderRadius.circular(12),
  ),
  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
  ),
  ),
  ),
  const SizedBox(width: 12),
  SizedBox(
  height: 44,
  child: OutlinedButton(
  onPressed: () {
  setState(() {
  _rows.add(_createRow(_rows.length + 1));
  });
  _scheduleAutoSave(showSnack: false);
  },
  style: OutlinedButton.styleFrom(
  backgroundColor: Colors.white,
  foregroundColor: const Color(0xFF111827),
  side: const BorderSide(color: Color(0xFFE5E7EB)),
  shape: RoundedRectangleBorder(
  borderRadius: BorderRadius.circular(12),
  ),
  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
  ),
  child: const Text(
  'Add another',
  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
  ),
  ),
  ),
  ],
 );
 }

 Widget _roundedField({
 required TextEditingController controller,
 required String hint,
 int minLines = 1,
 }) {
 return Container(
 width: double.infinity,
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(12),
 border: Border.all(color: const Color(0xFFE4E7EC)),
 ),
 padding: const EdgeInsets.all(14),
 child: VoiceTextField(
 controller: controller,
 minLines: minLines,
 maxLines: null,
 decoration: InputDecoration(
 isDense: true,
 border: InputBorder.none,
 hintText: hint,
 hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
 ),
 style: const TextStyle(fontSize: 14, color: Color(0xFF374151)),
 ),
 );
 }

 Future<void> _exportPdf() async {
 final projectData = ProjectDataHelper.getData(context);
 await PdfExportHelper.exportScreenPdf(
 context: context,
 screenTitle: 'Planning Requirements',
 sections: [
 PdfSection.keyValue('Project Info', [
 {'Project Name': projectData.projectName ?? 'N/A'},
 {'Solution Title': projectData.solutionTitle ?? 'N/A'},
 ]),
 PdfSection.text('Notes', projectData.planningNotes['planning_requirements_notes'] ?? 'No data recorded.'),
 ],
 );
 }
}

class _AssignableMember {
 const _AssignableMember({
 required this.id,
 required this.name,
 required this.email,
 required this.role,
 required this.source,
 });

 final String id;
 final String name;
 final String email;
 final String role;
 final String source;

 String get displayLabel {
 if (name.trim().isNotEmpty) return name.trim();
 if (email.trim().isNotEmpty) return email.trim();
 return 'Unknown member';
 }

 String get subtitle {
 final segments = <String>[];
 if (email.trim().isNotEmpty) {
 segments.add(email.trim());
 }
 if (role.trim().isNotEmpty) {
 segments.add(role.trim());
 }
 segments.add(source);
 return segments.join(' | ');
 }
}

class _RequirementRow {
 static const List<String> requirementTypeOptions = [
 'Technical',
 'Regulatory',
 'Functional',
 'Operational',
 'Non-Functional',
 'Safety',
 'Sustainability',
 'Business',
 'Stakeholder',
 'Solutions',
 'Transitional',
 'Other',
 ];

 static const List<String> disciplineOptions = [
 'Architecture',
 'Civil',
 'Electrical',
 'Mechanical',
 'IT',
 'Operations',
 'Safety',
 'Security',
 'Procurement',
 'Commercial',
 'Quality',
 'Regulatory',
 'Program Management',
 'Other',
 ];

 static const List<String> phaseOptions = [
 'Initiation',
 'Planning',
 'Design',
 'Execution',
 'Launch',
 'ALL',
 ];

 _RequirementRow({required this.number, this.onChanged})
 : descriptionController = TextEditingController(),
 commentsController = TextEditingController(),
 roleController = TextEditingController(),
 personController = TextEditingController(),
 sourceController = TextEditingController();

 int number;

 final TextEditingController descriptionController;
 final TextEditingController commentsController;
 final TextEditingController roleController;
 final TextEditingController personController;
 final TextEditingController sourceController;

 String? selectedType;
 String? selectedDiscipline;
 String? selectedPhase = 'Planning';
 final VoidCallback? onChanged;
 String? aiUndoText;

 void setDescription(String value) {
 descriptionController.text = value;
 }

 void dispose() {
 descriptionController.dispose();
 commentsController.dispose();
 roleController.dispose();
 personController.dispose();
 sourceController.dispose();
 }
}

class _TypeDropdown extends StatefulWidget {
 const _TypeDropdown({this.value, required this.onChanged});

 final String? value;
 final ValueChanged<String?> onChanged;

 @override
 State<_TypeDropdown> createState() => _TypeDropdownState();
}

class _TypeDropdownState extends State<_TypeDropdown> {
 late String? _value = _coerceValue(widget.value);

 String? _coerceValue(String? value) {
 if (value == null || value.trim().isEmpty) return null;
 return _RequirementRow.requirementTypeOptions.contains(value)
 ? value
 : null;
 }

 @override
 void didUpdateWidget(covariant _TypeDropdown oldWidget) {
 super.didUpdateWidget(oldWidget);
 if (oldWidget.value != widget.value) {
 _value = _coerceValue(widget.value);
 }
 }

 @override
 Widget build(BuildContext context) {
 return Container(
 height: 40,
 padding: const EdgeInsets.symmetric(horizontal: 12),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(10),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 ),
 child: DropdownButtonHideUnderline(
 child: DropdownButton<String?>(
 value: _value,
 hint: const Text(
 'Select...',
 style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 14),
 ),
 icon: const Icon(
 Icons.keyboard_arrow_down_rounded,
 color: Color(0xFF6B7280),
 size: 20,
 ),
 isExpanded: true,
 onChanged: (value) {
 setState(() => _value = value);
 widget.onChanged(value);
 },
 items: _RequirementRow.requirementTypeOptions
 .map(
 (option) => DropdownMenuItem<String?>(
 value: option,
 child: Text(
 option,
 style: const TextStyle(fontSize: 14),
 overflow: TextOverflow.ellipsis,
 ),
 ),
 )
 .toList(),
 ),
 ),
 );
 }
}

class _DisciplineDropdown extends StatefulWidget {
 const _DisciplineDropdown({this.value, required this.onChanged});

 final String? value;
 final ValueChanged<String?> onChanged;

 @override
 State<_DisciplineDropdown> createState() => _DisciplineDropdownState();
}

class _DisciplineDropdownState extends State<_DisciplineDropdown> {
 late String? _value = _coerceValue(widget.value);

 String? _coerceValue(String? value) {
 if (value == null || value.trim().isEmpty) return null;
 return _RequirementRow.disciplineOptions.contains(value) ? value : null;
 }

 @override
 void didUpdateWidget(covariant _DisciplineDropdown oldWidget) {
 super.didUpdateWidget(oldWidget);
 if (oldWidget.value != widget.value) {
 _value = _coerceValue(widget.value);
 }
 }

 @override
 Widget build(BuildContext context) {
 return Container(
 height: 40,
 padding: const EdgeInsets.symmetric(horizontal: 12),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(10),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 ),
 child: DropdownButtonHideUnderline(
 child: DropdownButton<String>(
 value: _value,
 hint: const Text(
 'Discipline',
 style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 14),
 ),
 icon: const Icon(
 Icons.keyboard_arrow_down_rounded,
 color: Color(0xFF6B7280),
 size: 20,
 ),
 isExpanded: true,
 onChanged: (value) {
 setState(() => _value = value);
 widget.onChanged(value);
 },
 items: _RequirementRow.disciplineOptions
 .map(
 (option) => DropdownMenuItem<String>(
 value: option,
 child: Text(
 option,
 style: const TextStyle(fontSize: 14),
 overflow: TextOverflow.ellipsis,
 ),
 ),
 )
 .toList(),
 ),
 ),
 );
 }
}

class _PhaseDropdown extends StatefulWidget {
 const _PhaseDropdown({this.value, required this.onChanged});

 final String? value;
 final ValueChanged<String?> onChanged;

 @override
 State<_PhaseDropdown> createState() => _PhaseDropdownState();
}

class _PhaseDropdownState extends State<_PhaseDropdown> {
 late String? _value = _coerceValue(widget.value);

 String? _coerceValue(String? value) {
 if (value == null || value.trim().isEmpty) return null;
 return _RequirementRow.phaseOptions.contains(value) ? value : null;
 }

 @override
 void didUpdateWidget(covariant _PhaseDropdown oldWidget) {
 super.didUpdateWidget(oldWidget);
 if (oldWidget.value != widget.value) {
 _value = _coerceValue(widget.value);
 }
 }

 @override
 Widget build(BuildContext context) {
 return Container(
 height: 40,
 padding: const EdgeInsets.symmetric(horizontal: 12),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(10),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 ),
 child: DropdownButtonHideUnderline(
 child: DropdownButton<String>(
 value: _value,
 hint: const Text(
 'Phase',
 style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 14),
 ),
 icon: const Icon(
 Icons.keyboard_arrow_down_rounded,
 color: Color(0xFF6B7280),
 size: 20,
 ),
 isExpanded: true,
 onChanged: (value) {
 setState(() => _value = value);
 widget.onChanged(value);
 },
 items: _RequirementRow.phaseOptions
 .map(
 (option) => DropdownMenuItem<String>(
 value: option,
 child: Text(
 option,
 style: const TextStyle(fontSize: 14),
 overflow: TextOverflow.ellipsis,
 ),
 ),
 )
 .toList(),
 ),
 ),
 );
 }
}

class _PersonDropdownField extends StatelessWidget {
 const _PersonDropdownField({
 required this.value,
 required this.options,
 required this.hint,
 required this.onChanged,
 });

 final String value;
 final List<_AssignableMember> options;
 final String hint;
 final ValueChanged<String> onChanged;

 @override
 Widget build(BuildContext context) {
 final hasValue = value.trim().isNotEmpty;
 final noMembers = options.isEmpty;

 return InkWell(
 onTap: noMembers
 ? null
 : () async {
 final selected = await showDialog<_AssignableMember>(
 context: context,
 builder: (dialogContext) => _MemberPickerDialog(
 options: options,
 initialQuery: value,
 ),
 );
 if (selected != null) {
 onChanged(selected.displayLabel);
 }
 },
 borderRadius: BorderRadius.circular(10),
 child: Container(
 height: 40,
 padding: const EdgeInsets.symmetric(horizontal: 12),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(10),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 ),
 child: Row(
 children: [
 Expanded(
 child: Text(
 noMembers
 ? 'No members available'
 : (hasValue ? value.trim() : hint),
 style: TextStyle(
 fontSize: 14,
 color: noMembers
 ? const Color(0xFF9CA3AF)
 : (hasValue
 ? const Color(0xFF111827)
 : const Color(0xFF9CA3AF)),
 ),
 overflow: TextOverflow.ellipsis,
 ),
 ),
 Icon(
 Icons.search_rounded,
 size: 18,
 color:
 noMembers ? const Color(0xFFCBD5E1) : const Color(0xFF6B7280),
 ),
 ],
 ),
 ),
 );
 }
}

class _MemberPickerDialog extends StatefulWidget {
 const _MemberPickerDialog({
 required this.options,
 required this.initialQuery,
 });

 final List<_AssignableMember> options;
 final String initialQuery;

 @override
 State<_MemberPickerDialog> createState() => _MemberPickerDialogState();
}

class _MemberPickerDialogState extends State<_MemberPickerDialog> {
 late final TextEditingController _searchController =
 TextEditingController(text: widget.initialQuery);

 @override
 void dispose() {
 _searchController.dispose();
 super.dispose();
 }

 List<_AssignableMember> _filteredMembers() {
 final query = _searchController.text.trim().toLowerCase();
 if (query.isEmpty) return widget.options;

 return widget.options.where((member) {
 final name = member.name.toLowerCase();
 final email = member.email.toLowerCase();
 final role = member.role.toLowerCase();
 final source = member.source.toLowerCase();
 return name.contains(query) ||
 email.contains(query) ||
 role.contains(query) ||
 source.contains(query);
 }).toList();
 }

 @override
 Widget build(BuildContext context) {
 final filtered = _filteredMembers();
 final grouped = <String, List<_AssignableMember>>{};
 for (final member in filtered) {
 grouped
 .putIfAbsent(member.source, () => <_AssignableMember>[])
 .add(member);
 }

 return AlertDialog(
 title: const Text('Select Person'),
 content: SizedBox(
 width: 520,
 height: 420,
 child: Column(
 children: [
 VoiceTextField(
 controller: _searchController,
 onChanged: (_) => setState(() {}),
 decoration: const InputDecoration(
 hintText: 'Search project team or company members...',
 prefixIcon: Icon(Icons.search_rounded),
 border: OutlineInputBorder(),
 isDense: true,
 ),
 ),
 const SizedBox(height: 10),
 Expanded(
 child: filtered.isEmpty
 ? const Center(
 child: Text(
 'No members available',
 style: TextStyle(color: Color(0xFF9CA3AF)),
 ),
 )
 : ListView(
 children: grouped.entries.map((entry) {
 final source = entry.key;
 final members = entry.value;
 return Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Padding(
 padding: const EdgeInsets.fromLTRB(4, 10, 4, 6),
 child: Text(
 source,
 style: const TextStyle(
 fontSize: 12,
 fontWeight: FontWeight.w700,
 color: Color(0xFF64748B),
 ),
 ),
 ),
 ...members.map(
 (member) => ListTile(
 dense: true,
 leading: CircleAvatar(
 radius: 14,
 backgroundColor: const Color(0xFFDBEAFE),
 child: Text(
 member.displayLabel[0].toUpperCase(),
 style: const TextStyle(
 fontSize: 12,
 fontWeight: FontWeight.w700,
 color: Color(0xFF1D4ED8),
 ),
 ),
 ),
 title: Text(
 member.displayLabel,
 style: const TextStyle(fontSize: 13),
 ),
 subtitle: Text(
 member.subtitle,
 style: const TextStyle(fontSize: 11),
 ),
 onTap: () => Navigator.pop(context, member),
 ),
 ),
 ],
 );
 }).toList(),
 ),
 ),
 ],
 ),
 ),
 actions: [
 TextButton(
 onPressed: () => Navigator.pop(context),
 child: const Text('Cancel'),
 ),
 ],
 );
 }
}
