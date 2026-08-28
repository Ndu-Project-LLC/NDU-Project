import 'package:ndu_project/widgets/voice_text_field.dart';
import 'package:ndu_project/utils/planning_phase_navigation.dart';
// ignore_for_file: unused_element

import 'dart:async';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:ndu_project/models/design_phase_models.dart';
import 'package:ndu_project/models/project_data_model.dart';
import 'package:ndu_project/services/design_phase_service.dart';
import 'package:ndu_project/providers/project_data_provider.dart';
import 'package:ndu_project/screens/design_phase_screen.dart';
import 'package:ndu_project/screens/development_set_up_screen.dart';
import 'package:ndu_project/screens/technical_alignment_screen.dart';
import 'package:ndu_project/widgets/kaz_ai_chat_bubble.dart';
import 'package:ndu_project/screens/ui_ux_design_screen.dart';
import 'package:ndu_project/services/project_navigation_service.dart';
import 'package:ndu_project/widgets/launch_phase_navigation.dart';
import 'package:ndu_project/widgets/design_phase_stable_shell.dart';
import 'package:ndu_project/widgets/planning_phase_header.dart';
import 'package:ndu_project/widgets/requirements_traceability_dashboard.dart';
import 'package:ndu_project/widgets/responsive.dart';
import 'package:ndu_project/widgets/responsive_scaffold.dart';
import 'package:ndu_project/utils/pdf_export_helper.dart';
import 'package:ndu_project/utils/project_data_helper.dart';
import 'package:go_router/go_router.dart';
import 'package:ndu_project/routing/app_router.dart';

import 'package:ndu_project/widgets/delete_success_snackbar.dart';
class RequirementsImplementationScreen extends StatefulWidget {
 const RequirementsImplementationScreen({super.key});

 @override
 State<RequirementsImplementationScreen> createState() =>
 _RequirementsImplementationScreenState();
}

class _RequirementsImplementationScreenState
 extends State<RequirementsImplementationScreen> {
 final TextEditingController _notesController = TextEditingController();
 Timer? _saveDebounce;
 bool _isLoading = false;
 bool _suspendSave = false;
 bool _showAllRows = false;
 bool _frameworkGuideExpanded = false;
 int _selectedRequirementIndex = 0;
 final Set<String> _selectedFilters = {'All requirements'};
 String _sectionApprovalStatus = 'Draft';
 final TextEditingController _sectionApprovedByController =
 TextEditingController();
 final TextEditingController _sectionApprovalDateController =
 TextEditingController();
 final TextEditingController _sectionApprovalNotesController =
 TextEditingController();
 final List<_DesignSpecDocumentRow> _documents = [];
 final List<_ApprovalGateData> _customApprovalGates = [];

 final List<RequirementRow> _requirementRows = [
 RequirementRow(
 requirementId: 'REQ-001',
 title: 'API endpoint authentication for partner booking sync',
 owner: 'Product',
 definition:
 'Trace the service entry point, failure states, and implementation handoff into the design pack.',
 requirementType: 'Functional',
 designArtifactType: 'Figma',
 designArtifactLabel: 'Figma service blueprint',
 validationStatus: 'Mapped',
 acceptanceCriteria:
 'Authentication states and fallback handling are visible in the approved design artifact.',
 testMethod: 'API walkthrough and contract review',
 sourceDocument: 'Contract clause 4.2',
 gapStatus: 'Closed',
 ),
 RequirementRow(
 requirementId: 'REQ-002',
 title: 'Venue capacity and circulation planning',
 owner: 'Engineering',
 definition:
 'Confirm that occupancy limits, movement flow, and physical safety logic are represented in the design controls.',
 requirementType: 'Non-Functional',
 designArtifactType: 'PDF',
 designArtifactLabel: 'Venue compliance PDF pack',
 validationStatus: 'Mapped',
 acceptanceCriteria:
 'Capacity thresholds, egress assumptions, and signage logic are documented and reviewable.',
 testMethod: 'Venue safety and operations review',
 sourceDocument: 'Safety schedule appendix B',
 gapStatus: 'Closed',
 ),
 RequirementRow(
 requirementId: 'REQ-003',
 title: 'Brand wallfinding package for main foyer',
 owner: 'Platform',
 definition:
 'Coordinate the brand expression, physical signage pack, and downstream fabrication notes.',
 requirementType: 'Non-Functional',
 designArtifactType: 'PDF',
 validationStatus: 'Unmapped',
 acceptanceCriteria:
 'Wayfinding hierarchy, material guidance, and review ownership are defined.',
 testMethod: 'Brand and venue coordination review',
 sourceDocument: 'Brand standards section 7',
 gapStatus: 'Pending Approval',
 conflictNote:
 'Brand requirements are still waiting for final venue dimensions.',
 conflictImpact: 'Low',
 ),
 ];

 // Checklist items with status
 final List<RequirementChecklistItem> _checklistItems = [
 RequirementChecklistItem(
 title: 'Key flows covered',
 description: 'All priority user journeys have mapped requirements.',
 status: ChecklistStatus.ready,
 ),
 RequirementChecklistItem(
 title: 'Constraints documented',
 description: 'Performance, security, and compliance captured.',
 status: ChecklistStatus.inReview,
 ),
 RequirementChecklistItem(
 title: 'Stakeholder sign-off',
 description: 'Product, design, and engineering alignment.',
 status: ChecklistStatus.pending,
 ),
 ];

 String _normalize(String value) {
 return value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
 }

 List<RequirementRow> _dedupeRequirements(Iterable<RequirementRow> rows) {
 final seen = <String>{};
 final deduped = <RequirementRow>[];
 for (final row in rows) {
 final key =
 '${_normalize(row.requirementId)}|${_normalize(row.title)}|${_normalize(row.owner)}|${_normalize(row.definition)}';
 if (_normalize(row.title).isEmpty && _normalize(row.definition).isEmpty) {
 continue;
 }
 if (seen.add(key)) deduped.add(row);
 }
 return deduped;
 }

 List<RequirementChecklistItem> _dedupeChecklist(
 Iterable<RequirementChecklistItem> rows) {
 final seen = <String>{};
 final deduped = <RequirementChecklistItem>[];
 for (final row in rows) {
 final key =
 '${_normalize(row.title)}|${_normalize(row.description)}|${row.status.name}|${_normalize(row.owner ?? '')}';
 if (key == '|||') continue;
 if (seen.add(key)) deduped.add(row);
 }
 return deduped;
 }

 @override
 void initState() {
 super.initState();
 _notesController.addListener(_onNotesChanged);
 WidgetsBinding.instance.addPostFrameCallback((_) async {
 await _syncAndLoad();
 if (!mounted) return;
 final provider = ProjectDataInherited.maybeOf(context);
 final pid = provider?.projectData.projectId;
 if (pid != null && pid.isNotEmpty) {
 await ProjectNavigationService.instance
 .saveLastPage(pid, 'requirements-implementation');
 }
 });
 }

 Future<void> _syncAndLoad() async {
 final provider = ProjectDataInherited.maybeOf(context);
 final projectId = provider?.projectData.projectId;
 if (projectId == null || projectId.isEmpty) return;

 // 1. Auto-sync from scope first
 try {
 final addedCount = await DesignPhaseService.instance
 .syncRequirementsFromScope(projectId);
 if (addedCount > 0 && mounted) {
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(
 content:
 Text('Synced $addedCount new requirements from Project Scope'),
 backgroundColor: const Color(0xFF16A34A),
 ),
 );
 }
 } catch (e) {
 debugPrint('Sync error: $e');
 }

 // 2. Load data
 await _loadFromFirestore();
 }

 @override
 void dispose() {
 _notesController.removeListener(_onNotesChanged);
 _notesController.dispose();
 _sectionApprovedByController.dispose();
 _sectionApprovalDateController.dispose();
 _sectionApprovalNotesController.dispose();
 _saveDebounce?.cancel();
 super.dispose();
 }

 void _onNotesChanged() {
 if (_suspendSave) return;
 _scheduleSave();
 }

 Future<void> _saveNotesNow() async {
 await _saveToFirestore();
 if (!mounted) return;
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(
 content: Text('Requirements notes saved.'),
 backgroundColor: Color(0xFF16A34A),
 ),
 );
 }

 Future<void> _loadFromFirestore() async {
 final provider = ProjectDataInherited.maybeOf(context);
 final projectId = provider?.projectData.projectId;
 if (projectId == null || projectId.isEmpty) return;
 if (!mounted) return;

 setState(() => _isLoading = true);
 try {
 final data = await DesignPhaseService.instance
 .loadRequirementsImplementation(projectId);

 _suspendSave = true;
 if (mounted) {
 setState(() {
 _notesController.text = data['notes']?.toString() ?? '';

 if (data['requirements'] != null) {
 final parsed = (data['requirements'] as List)
 .map((e) => RequirementRow.fromMap(e as Map<String, dynamic>));
 _requirementRows
 ..clear()
 ..addAll(_dedupeRequirements(parsed));
 }

 if (data['checklist'] != null) {
 final parsed = (data['checklist'] as List).map((e) =>
 RequirementChecklistItem.fromMap(e as Map<String, dynamic>));
 _checklistItems
 ..clear()
 ..addAll(_dedupeChecklist(parsed));
 }

 _sectionApprovalStatus =
 data['sectionApprovalStatus']?.toString() ?? 'Draft';
 _sectionApprovedByController.text =
 data['sectionApprovedBy']?.toString() ?? '';
 _sectionApprovalDateController.text =
 data['sectionApprovalDate']?.toString() ?? '';
 _sectionApprovalNotesController.text =
 data['sectionApprovalNotes']?.toString() ?? '';

 final rawDocuments = data['documents'];
 if (rawDocuments is List) {
 _documents
 ..clear()
 ..addAll(
 rawDocuments.whereType<Map>().map((item) =>
 _DesignSpecDocumentRow.fromMap(
 Map<String, dynamic>.from(item))),
 );
 } else {
 _documents.clear();
 }

 if (_selectedRequirementIndex >= _requirementRows.length) {
 _selectedRequirementIndex =
 _requirementRows.isEmpty ? 0 : _requirementRows.length - 1;
 }
 });
 }
 } catch (e) {
 debugPrint('Error loading requirements: $e');
 } finally {
 _suspendSave = false;
 if (mounted) setState(() => _isLoading = false);
 }
 }

 void _scheduleSave() {
 _saveDebounce?.cancel();
 _saveDebounce = Timer(const Duration(milliseconds: 1000), _saveToFirestore);
 }

 Future<void> _saveToFirestore() async {
 final provider = ProjectDataInherited.maybeOf(context);
 final projectId = provider?.projectData.projectId;
 if (projectId == null || projectId.isEmpty) return;

 try {
 final dedupedRequirements = _dedupeRequirements(_requirementRows);
 final dedupedChecklist = _dedupeChecklist(_checklistItems);
 await DesignPhaseService.instance.saveRequirementsImplementation(
 projectId,
 notes: _notesController.text,
 requirements: dedupedRequirements,
 checklist: dedupedChecklist,
 documents: _documents.map((item) => item.toMap()).toList(),
 sectionApprovalStatus: _sectionApprovalStatus,
 sectionApprovedBy: _sectionApprovedByController.text.trim(),
 sectionApprovalDate: _sectionApprovalDateController.text.trim(),
 sectionApprovalNotes: _sectionApprovalNotesController.text.trim(),
 );
 } catch (e) {
 debugPrint('Error saving requirements: $e');
 }
 }

 void _navigateToDesignOverview() {
 context.push('/design-phase');
 }

 void _navigateToTechnicalAlignment() {
 context.push('/technical-alignment');
 }

 List<String> _ownerOptions(ProjectDataModel projectData) {
 final names = <String>{
 ...projectData.teamMembers
 .map((member) => member.name.trim())
 .where((name) => name.isNotEmpty),
 };
 if (projectData.charterProjectManagerName.trim().isNotEmpty) {
 names.add(projectData.charterProjectManagerName.trim());
 }
 if (projectData.charterProjectSponsorName.trim().isNotEmpty) {
 names.add(projectData.charterProjectSponsorName.trim());
 }
 if (names.isEmpty) {
 names.addAll(const ['Unassigned', 'Design Lead', 'Technical Lead']);
 }
 final options = names.toList()..sort();
 return options;
 }

 String _buildRequirementId(int index) =>
 'REQ-${index.toString().padLeft(3, '0')}';

 int get _safeSelectedRequirementIndex {
 if (_requirementRows.isEmpty) return 0;
 if (_selectedRequirementIndex < 0) return 0;
 if (_selectedRequirementIndex >= _requirementRows.length) {
 return _requirementRows.length - 1;
 }
 return _selectedRequirementIndex;
 }

 void _selectRequirement(int index) {
 if (index < 0 || index >= _requirementRows.length) return;
 setState(() => _selectedRequirementIndex = index);
 }

 void _updateRequirement(
 int index,
 RequirementRow Function(RequirementRow current) update,
 ) {
 if (index < 0 || index >= _requirementRows.length) return;
 setState(() {
 _requirementRows[index] = update(_requirementRows[index]);
 });
 _scheduleSave();
 }

 void _updateSelectedRequirement(
 RequirementRow Function(RequirementRow current) update) {
 _updateRequirement(_safeSelectedRequirementIndex, update);
 }

 void _toggleShowAllRows() {
 setState(() => _showAllRows = !_showAllRows);
 }

 void _addRequirement(ProjectDataModel projectData) {
 final ownerOptions = _ownerOptions(projectData);
 final requirementIndex = _requirementRows.length + 1;
 final newRow = RequirementRow(
 requirementId: _buildRequirementId(requirementIndex),
 title: 'New requirement',
 owner: ownerOptions.first,
 definition:
 'Describe the requirement intent, design dependency, and release constraints.',
 requirementType: 'Functional',
 ruleType: 'Internal',
 sourceType: 'Standard',
 designArtifactType: 'Figma',
 validationStatus: 'Unmapped',
 acceptanceCriteria:
 'Define measurable criteria for design and implementation sign-off.',
 testMethod: 'Design walkthrough',
 sourceDocument: 'Planning requirement register',
 gapStatus: 'Pending Approval',
 conflictImpact: 'Low',
 );
 // Open the same modal dialog used by Edit so the user can fill in the
 // form before the row is committed to the register. The row is only
 // added to _requirementRows when the user clicks Save inside the dialog.
 _showRequirementFormDialog(row: newRow, isNew: true);
 }

 Future<void> _deleteRequirement(int index) async {
 if (index < 0 || index >= _requirementRows.length) return;
 final confirmed = await _confirmDelete('requirement');
 if (!confirmed) return;
 setState(() {
 _requirementRows.removeAt(index);
 if (_selectedRequirementIndex >= _requirementRows.length) {
 _selectedRequirementIndex =
 _requirementRows.isEmpty ? 0 : _requirementRows.length - 1;
 }
 });
 _scheduleSave();
    showDeleteSuccessSnackBar(context, itemLabel: 'Requirement');
 }

 void _showArtifactMessage(RequirementRow row) {
 final message = row.designArtifactUrl.trim().isNotEmpty
 ? '${row.designArtifactLabel} linked to ${row.designArtifactUrl}'
 : row.designArtifactLabel.trim().isNotEmpty
 ? '${row.designArtifactLabel} is captured as a ${row.designArtifactType} artifact.'
 : 'No design artifact has been linked yet.';

 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(
 content: Text(message),
 backgroundColor: const Color(0xFF0F172A),
 ),
 );
 }

 Future<void> _uploadArtifactForRequirement(RequirementRow row) async {
 final uploaded = await _pickAndUploadAttachment(
 folder: 'design-specifications',
 );
 if (uploaded == null || !mounted) return;
 final index = _requirementRows.indexWhere((item) => item.id == row.id);
 if (index == -1) return;
 setState(() {
 _requirementRows[index] = _requirementRows[index].copyWith(
 designArtifactUrl: uploaded.url,
 artifactStoragePath: uploaded.storagePath,
 artifactFileName: uploaded.name,
 artifactMimeType: uploaded.contentType,
 artifactSizeBytes: uploaded.sizeBytes,
 );
 });
 _scheduleSave();
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(content: Text('Artifact uploaded and linked.')),
 );
 }

 Future<_UploadedDoc?> _pickAndUploadAttachment({
 required String folder,
 }) async {
 final messenger = ScaffoldMessenger.of(context);
 final currentUser = FirebaseAuth.instance.currentUser;
 if (currentUser == null) {
 messenger.showSnackBar(
 const SnackBar(
 content: Text('Sign in is required before uploading files.')),
 );
 return null;
 }
 final provider = ProjectDataInherited.maybeOf(context);
 final projectId = provider?.projectData.projectId;
 if (projectId == null || projectId.isEmpty) {
 messenger.showSnackBar(
 const SnackBar(content: Text('Select a project before uploading.')),
 );
 return null;
 }

 try {
 final result = await FilePicker.pickFiles(
 type: FileType.custom,
 withData: true,
 allowedExtensions: const [
 'pdf',
 'doc',
 'docx',
 'xls',
 'xlsx',
 'ppt',
 'pptx',
 'txt',
 'csv',
 'png',
 'jpg',
 'jpeg'
 ],
 );
 if (result == null || result.files.isEmpty) return null;
 final file = result.files.first;
 final Uint8List? bytes = file.bytes;
 if (bytes == null) {
 messenger.showSnackBar(
 const SnackBar(content: Text('Unable to read selected file.')),
 );
 return null;
 }
 final safeName = file.name.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
 final storagePath =
 'projects/$projectId/$folder/${DateTime.now().millisecondsSinceEpoch}_$safeName';
 final ref = FirebaseStorage.instance.ref(storagePath);
 final metadata = SettableMetadata(
 contentType: _contentTypeForExtension(file.extension),
 );
 await ref.putData(bytes, metadata);
 final downloadUrl = await ref.getDownloadURL();
 return _UploadedDoc(
 name: file.name,
 url: downloadUrl,
 storagePath: storagePath,
 contentType: metadata.contentType ?? '',
 sizeBytes: file.size,
 );
 } on FirebaseException catch (error) {
 _showStorageUploadError(error.toString());
 return null;
 } catch (error) {
 _showStorageUploadError(error.toString());
 return null;
 }
 }

 void _showStorageUploadError(String rawError) {
 if (!mounted) return;
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(content: Text('Failed to upload file: $rawError')),
 );
 }

 String _contentTypeForExtension(String? extension) {
 switch ((extension ?? '').toLowerCase()) {
 case 'pdf':
 return 'application/pdf';
 case 'doc':
 return 'application/msword';
 case 'docx':
 return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
 case 'xls':
 return 'application/vnd.ms-excel';
 case 'xlsx':
 return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
 case 'ppt':
 return 'application/vnd.ms-powerpoint';
 case 'pptx':
 return 'application/vnd.openxmlformats-officedocument.presentationml.presentation';
 case 'csv':
 return 'text/csv';
 case 'txt':
 return 'text/plain';
 case 'png':
 return 'image/png';
 case 'jpg':
 case 'jpeg':
 return 'image/jpeg';
 default:
 return 'application/octet-stream';
 }
 }

 bool get _isDesignSpecificationsSectionReady {
 if (_requirementRows.isEmpty) return false;
 final allRowsValid = _requirementRows.every((row) {
 final baseReady = row.title.trim().isNotEmpty &&
 row.owner.trim().isNotEmpty &&
 row.definition.trim().isNotEmpty &&
 row.ruleType.trim().isNotEmpty &&
 row.sourceType.trim().isNotEmpty;
 if (!baseReady) return false;
 if (row.validationStatus.trim().toLowerCase() == 'mapped') {
 return row.acceptanceCriteria.trim().isNotEmpty &&
 row.testMethod.trim().isNotEmpty;
 }
 return true;
 });
 if (!allRowsValid) return false;

 final hasPending = _requirementRows
 .any((row) => row.gapStatus.trim().toLowerCase() == 'pending approval');
 if (hasPending) return false;

 return _sectionApprovalStatus == 'In Review' ||
 _sectionApprovalStatus == 'Approved';
 }

 Future<void> _tryNavigateToTechnicalAlignment() async {
 if (_isDesignSpecificationsSectionReady) {
 _navigateToTechnicalAlignment();
 return;
 }
 final reasons = <String>[];
 if (_requirementRows.isEmpty) {
 reasons.add('Add at least one specification row.');
 }
 final incompleteBasics = _requirementRows.where((row) =>
 row.title.trim().isEmpty ||
 row.owner.trim().isEmpty ||
 row.definition.trim().isEmpty ||
 row.ruleType.trim().isEmpty ||
 row.sourceType.trim().isEmpty);
 if (incompleteBasics.isNotEmpty) {
 reasons.add(
 'Complete required fields (title, owner, definition, rule/source type).');
 }
 final mappedMissingEvidence = _requirementRows.where((row) =>
 row.validationStatus.trim().toLowerCase() == 'mapped' &&
 (row.acceptanceCriteria.trim().isEmpty ||
 row.testMethod.trim().isEmpty));
 if (mappedMissingEvidence.isNotEmpty) {
 reasons.add(
 'Mapped items must include acceptance criteria and test method.');
 }
 if (_requirementRows.any(
 (row) => row.gapStatus.trim().toLowerCase() == 'pending approval')) {
 reasons.add('Resolve pending approval gaps before continuing.');
 }
 if (!(_sectionApprovalStatus == 'In Review' ||
 _sectionApprovalStatus == 'Approved')) {
 reasons.add('Set section approval status to In Review or Approved.');
 }
 if (!mounted) return;
 await showDialog<void>(
 context: context,
 builder: (dialogContext) => AlertDialog(
 title: const Text('Design Specifications Incomplete'),
 content: Text(reasons.join('\n')),
 actions: [
 TextButton(
 onPressed: () => Navigator.of(dialogContext).pop(),
 child: const Text('OK'),
 ),
 ],
 ),
 );
 }

 void _addDocumentRow(List<String> ownerOptions) {
 _showAddDocumentDialog(ownerOptions: ownerOptions);
 }

 // -------------------------------------------------------------------------
 // Add Document modal — collects all document metadata up-front in a
 // focused dialog (instead of dropping an empty inline row). Mirrors the
 // existing "Add Requirement" modal pattern for consistency.
 // -------------------------------------------------------------------------
 Future<void> _showAddDocumentDialog({
 required List<String> ownerOptions,
 }) async {
 final formKey = GlobalKey<FormState>();
 final nameController = TextEditingController();
 final nameFocus = FocusNode();
 final categoryController = TextEditingController();
 final versionController = TextEditingController();
 final linkedSpecIdController = TextEditingController();
 final linkController = TextEditingController();
 String selectedOwner = ownerOptions.isEmpty ? '' : ownerOptions.first;
 String selectedStatus = 'Draft';
 String selectedCategory = '';
 String? uploadedFileName;
 String? uploadedStoragePath;
 bool isUploading = false;

 // Curated, domain-appropriate option lists — saves the user from typing
 // common values and keeps the register consistent across rows.
 const categoryOptions = <String>[
 'Specification',
 'Design',
 'Architecture',
 'Test Plan',
 'Test Report',
 'User Guide',
 'Reference',
 'Contract',
 'Compliance',
 'Meeting Notes',
 'Risk Assessment',
 'Other',
 ];

 const statusOptions = <String>[
 'Draft',
 'In Review',
 'Approved',
 'Published',
 'Superseded',
 'Archived',
 ];

 // Merge curated categories with any custom ones already used in the
 // register, so the dropdown reflects real project usage.
 final mergedCategories = <String>{
 ...categoryOptions,
 ..._documents
 .map((d) => d.category.trim())
 .where((c) => c.isNotEmpty),
 }.toList()
 ..sort();

 final result = await showDialog<_DesignSpecDocumentRow?>(
 context: context,
 barrierDismissible: true,
 builder: (dialogContext) {
 return StatefulBuilder(
 builder: (innerContext, setDialogState) {
 // Helper to build a labeled field with the NDU focused-border
 // accent (matches the existing inline field styling).
 InputDecoration nduDecoration({
 required String label,
 bool required = false,
 String? hint,
 IconData? prefixIcon,
 }) {
 return InputDecoration(
 labelText: required ? '$label *' : label,
 hintText: hint,
 isDense: true,
 filled: true,
 fillColor: const Color(0xFFF8FAFC),
 contentPadding:
 const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
 prefixIcon: prefixIcon != null
 ? Icon(prefixIcon, size: 18, color: const Color(0xFFB8860B))
 : null,
 border: OutlineInputBorder(
 borderRadius: BorderRadius.circular(10),
 borderSide: const BorderSide(color: Color(0xFFE4E7EC)),
 ),
 enabledBorder: OutlineInputBorder(
 borderRadius: BorderRadius.circular(10),
 borderSide: const BorderSide(color: Color(0xFFE4E7EC)),
 ),
 focusedBorder: OutlineInputBorder(
 borderRadius: BorderRadius.circular(10),
 borderSide:
 const BorderSide(color: Color(0xFFFFC812), width: 2),
 ),
 errorBorder: OutlineInputBorder(
 borderRadius: BorderRadius.circular(10),
 borderSide: const BorderSide(color: Color(0xFFB91C1C)),
 ),
 focusedErrorBorder: OutlineInputBorder(
 borderRadius: BorderRadius.circular(10),
 borderSide:
 const BorderSide(color: Color(0xFFB91C1C), width: 2),
 ),
 );
 }

 Widget fieldLabel(String text, {bool required = false}) {
 return Padding(
 padding: const EdgeInsets.only(bottom: 6, top: 4),
 child: RichText(
 text: TextSpan(
 style: const TextStyle(
 fontSize: 12,
 fontWeight: FontWeight.w600,
 color: Color(0xFF374151),
 ),
 children: [
 TextSpan(text: text),
 if (required)
 const TextSpan(
 text: ' *',
 style: TextStyle(color: Color(0xFFB91C1C)),
 ),
 ],
 ),
 ),
 );
 }

 return AnimatedPadding(
 padding: MediaQuery.of(innerContext).viewInsets,
 duration: const Duration(milliseconds: 120),
 curve: Curves.easeOutCubic,
 child: Dialog(
 backgroundColor: Theme.of(context).scaffoldBackgroundColor,
 insetPadding: const EdgeInsets.symmetric(
 horizontal: 24, vertical: 24),
 shape: RoundedRectangleBorder(
 borderRadius: BorderRadius.circular(18)),
 child: ConstrainedBox(
 constraints: BoxConstraints(
 maxWidth: 680,
 maxHeight: MediaQuery.of(innerContext).size.height * 0.9,
 ),
 child: Form(
 key: formKey,
 child: SingleChildScrollView(
 padding: const EdgeInsets.all(24),
 child: Column(
 mainAxisSize: MainAxisSize.min,
 crossAxisAlignment: CrossAxisAlignment.stretch,
 children: [
 // ── Header ────────────────────────────────────
 Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Container(
 width: 44,
 height: 44,
 decoration: BoxDecoration(
 gradient: const LinearGradient(
 begin: Alignment.topLeft,
 end: Alignment.bottomRight,
 colors: [
 Color(0xFFFFC812),
 Color(0xFFB8860B),
 ],
 ),
 borderRadius: BorderRadius.circular(12),
 ),
 child: const Icon(
 Icons.description_outlined,
 color: Colors.white,
 size: 22,
 ),
 ),
 const SizedBox(width: 14),
 const Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 'Add Document',
 style: TextStyle(
 fontSize: 19,
 fontWeight: FontWeight.w700,
 color: Color(0xFF111827),
 letterSpacing: -0.2,
 ),
 ),
 SizedBox(height: 4),
 Text(
 'Register a new document or link in the Documents & Links Register.',
 style: TextStyle(
 fontSize: 13,
 color: Color(0xFF6B7280),
 height: 1.4,
 ),
 ),
 ],
 ),
 ),
 IconButton(
 tooltip: 'Close',
 onPressed: () =>
 Navigator.of(dialogContext).pop(null),
 icon: const Icon(Icons.close, size: 20),
 splashRadius: 20,
 ),
 ],
 ),
 const Divider(height: 28, thickness: 1,
 color: Color(0xFFF1F5F9)),

 // ── Form fields ──────────────────────────────
 // Row 1: Document Name (full width — primary field)
 fieldLabel('Document Name', required: true),
 VoiceTextFormField(
 controller: nameController,
 focusNode: nameFocus,
 autofocus: true,
 textCapitalization: TextCapitalization.sentences,
 textInputAction: TextInputAction.next,
 decoration: nduDecoration(
 label: 'Document Name',
 hint: 'e.g. API Specification v1.2',
 prefixIcon: Icons.article_outlined,
 ),
 validator: (value) {
 final v = value?.trim() ?? '';
 if (v.isEmpty) {
 return 'Document name is required';
 }
 if (v.length < 2) {
 return 'Name must be at least 2 characters';
 }
 return null;
 },
 ),

 const SizedBox(height: 16),

 // Row 2: Category + Version
 LayoutBuilder(
 builder: (context, constraints) {
 final isWide = constraints.maxWidth >= 480;
 final children = <Widget>[
 // Category dropdown
 Flexible(
 flex: isWide ? 3 : 1,
 child: Column(
 crossAxisAlignment:
 CrossAxisAlignment.start,
 children: [
 fieldLabel('Category'),
 DropdownButtonFormField<String>(
 initialValue: selectedCategory.isEmpty
 ? null
 : selectedCategory,
 isExpanded: true,
 decoration: nduDecoration(
 label: 'Category',
 prefixIcon: Icons.category_outlined,
 ).copyWith(
 labelText: null,
 hintText: 'Select category',
 ),
 items: mergedCategories
 .map((c) => DropdownMenuItem(
 value: c,
 child: Text(c,
 overflow: TextOverflow
 .ellipsis),
 ))
 .toList(),
 onChanged: (v) {
 if (v == null) return;
 setDialogState(() {
 selectedCategory = v;
 if (v == 'Other') {
 categoryController.clear();
 } else {
 categoryController.text = v;
 }
 });
 },
 ),
 if (selectedCategory == 'Other') ...[
 const SizedBox(height: 8),
 VoiceTextField(
 controller: categoryController,
 textCapitalization:
 TextCapitalization.sentences,
 decoration: nduDecoration(
 label: 'Custom Category',
 hint: 'Type custom category',
 ),
 ),
 ],
 ],
 ),
 ),
 SizedBox(width: isWide ? 12 : 0),
 // Version
 Flexible(
 flex: isWide ? 2 : 1,
 child: Column(
 crossAxisAlignment:
 CrossAxisAlignment.start,
 children: [
 fieldLabel('Version'),
 VoiceTextField(
 controller: versionController,
 textInputAction: TextInputAction.next,
 decoration: nduDecoration(
 label: 'Version',
 hint: 'e.g. 1.0.0',
 prefixIcon:
 Icons.history_outlined,
 ),
 ),
 ],
 ),
 ),
 ];
 return isWide
 ? Row(
 crossAxisAlignment:
 CrossAxisAlignment.start,
 children: children,
 )
 : Column(
 crossAxisAlignment:
 CrossAxisAlignment.stretch,
 children: children,
 );
 },
 ),

 const SizedBox(height: 16),

 // Row 3: Owner + Status
 LayoutBuilder(
 builder: (context, constraints) {
 final isWide = constraints.maxWidth >= 480;
 final children = <Widget>[
 Flexible(
 flex: isWide ? 3 : 1,
 child: Column(
 crossAxisAlignment:
 CrossAxisAlignment.start,
 children: [
 fieldLabel('Owner'),
 DropdownButtonFormField<String>(
 initialValue: selectedOwner.isEmpty
 ? null
 : selectedOwner,
 isExpanded: true,
 decoration: nduDecoration(
 label: 'Owner',
 prefixIcon: Icons.person_outline,
 ).copyWith(
 labelText: null,
 hintText: 'Select owner',
 ),
 items: ownerOptions
 .map((o) => DropdownMenuItem(
 value: o,
 child: Text(o,
 overflow: TextOverflow
 .ellipsis),
 ))
 .toList(),
 onChanged: (v) {
 if (v == null) return;
 setDialogState(() =>
 selectedOwner = v);
 },
 ),
 ],
 ),
 ),
 SizedBox(width: isWide ? 12 : 0),
 Flexible(
 flex: isWide ? 2 : 1,
 child: Column(
 crossAxisAlignment:
 CrossAxisAlignment.start,
 children: [
 fieldLabel('Status'),
 DropdownButtonFormField<String>(
 initialValue: selectedStatus,
 isExpanded: true,
 decoration: nduDecoration(
 label: 'Status',
 prefixIcon: Icons.flag_outlined,
 ).copyWith(
 labelText: null,
 ),
 items: statusOptions
 .map((s) => DropdownMenuItem(
 value: s, child: Text(s)))
 .toList(),
 onChanged: (v) {
 if (v == null) return;
 setDialogState(() =>
 selectedStatus = v);
 },
 ),
 ],
 ),
 ),
 ];
 return isWide
 ? Row(
 crossAxisAlignment:
 CrossAxisAlignment.start,
 children: children,
 )
 : Column(
 crossAxisAlignment:
 CrossAxisAlignment.stretch,
 children: children,
 );
 },
 ),

 const SizedBox(height: 16),

 // Row 4: Linked Spec ID (full width)
 fieldLabel('Linked Spec ID'),
 VoiceTextField(
 controller: linkedSpecIdController,
 textInputAction: TextInputAction.next,
 decoration: nduDecoration(
 label: 'Linked Spec ID',
 hint: 'e.g. REQ-001',
 prefixIcon: Icons.link,
 ),
 ),

 const SizedBox(height: 16),

 // Row 5: Link / Uploaded URL + Upload button
 fieldLabel('Link / Uploaded URL'),
 Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Expanded(
 child: VoiceTextField(
 controller: linkController,
 keyboardType: TextInputType.url,
 textInputAction: TextInputAction.done,
 decoration: nduDecoration(
 label: 'Link / Uploaded URL',
 hint:
 'https://… or click Upload to attach',
 prefixIcon: Icons.attach_file,
 ),
 ),
 ),
 const SizedBox(width: 8),
 SizedBox(
 height: 48,
 child: OutlinedButton.icon(
 onPressed: isUploading
 ? null
 : () async {
 setDialogState(() =>
 isUploading = true);
 try {
 final uploaded = await _pickAndUploadAttachment(
 folder: 'design-spec-docs');
 if (uploaded != null) {
 linkController.text =
 uploaded.url;
 setDialogState(() {
 uploadedFileName =
 uploaded.name;
 uploadedStoragePath =
 uploaded.storagePath;
 });
 if (dialogContext.mounted) {
 ScaffoldMessenger.of(dialogContext)
 .showSnackBar(
 SnackBar(
 content: Text(
 'Uploaded: ${uploaded.name}'),
 backgroundColor:
 const Color(0xFF16A34A),
 ),
 );
 }
 }
 } finally {
 if (dialogContext.mounted) {
 setDialogState(() =>
 isUploading = false);
 }
 }
 },
 style: OutlinedButton.styleFrom(
 foregroundColor: const Color(0xFFB8860B),
 side: const BorderSide(
 color: Color(0xFFFFC812)),
 shape: RoundedRectangleBorder(
 borderRadius:
 BorderRadius.circular(10)),
 ),
 icon: isUploading
 ? const SizedBox(
 width: 16,
 height: 16,
 child: CircularProgressIndicator(
 strokeWidth: 2),
 )
 : const Icon(Icons.upload_file, size: 18),
 label: Text(isUploading
 ? 'Uploading…'
 : 'Upload'),
 ),
 ),
 ],
 ),

 if (uploadedFileName != null) ...[
 const SizedBox(height: 8),
 Container(
 padding: const EdgeInsets.symmetric(
 horizontal: 10, vertical: 8),
 decoration: BoxDecoration(
 color: const Color(0xFFFFF8E1),
 borderRadius: BorderRadius.circular(8),
 border: Border.all(
 color: const Color(0xFFFDE68A)),
 ),
 child: Row(
 children: [
 const Icon(Icons.check_circle,
 size: 16, color: Color(0xFF16A34A)),
 const SizedBox(width: 8),
 Expanded(
 child: Text(
 'Attached: $uploadedFileName',
 style: const TextStyle(
 fontSize: 12,
 color: Color(0xFF6B7280)),
 overflow: TextOverflow.ellipsis,
 ),
 ),
 ],
 ),
 ),
 ],

 const SizedBox(height: 24),
 const Divider(height: 1, color: Color(0xFFF1F5F9)),
 const SizedBox(height: 16),

 // ── Action bar ───────────────────────────────
 Row(
 mainAxisAlignment: MainAxisAlignment.spaceBetween,
 children: [
 const Text(
 '* required',
 style: TextStyle(
 fontSize: 11,
 color: Color(0xFF9CA3AF),
 fontStyle: FontStyle.italic,
 ),
 ),
 const Spacer(),
 TextButton(
 onPressed: () =>
 Navigator.of(dialogContext).pop(null),
 style: TextButton.styleFrom(
 foregroundColor: const Color(0xFF6B7280),
 padding: const EdgeInsets.symmetric(
 horizontal: 16, vertical: 12),
 ),
 child: const Text('Cancel'),
 ),
 const SizedBox(width: 8),
 FilledButton.icon(
 onPressed: () {
 if (!(formKey.currentState?.validate() ??
 false)) {
 return;
 }
 final categoryValue = selectedCategory ==
 'Other'
 ? categoryController.text.trim()
 : (selectedCategory.isEmpty
 ? categoryController.text.trim()
 : selectedCategory);

 final row = _DesignSpecDocumentRow(
 name: nameController.text.trim(),
 category: categoryValue,
 version: versionController.text.trim(),
 owner: selectedOwner,
 linkedSpecId:
 linkedSpecIdController.text.trim(),
 link: linkController.text.trim(),
 status: selectedStatus,
 fileName: uploadedFileName ?? '',
 storagePath: uploadedStoragePath ?? '',
 );
 Navigator.of(dialogContext).pop(row);
 },
 style: FilledButton.styleFrom(
 backgroundColor: const Color(0xFFFFC812),
 foregroundColor: const Color(0xFF111827),
 padding: const EdgeInsets.symmetric(
 horizontal: 20, vertical: 14),
 shape: RoundedRectangleBorder(
 borderRadius:
 BorderRadius.circular(10)),
 elevation: 0,
 ),
 icon: const Icon(Icons.add, size: 18),
 label: const Text(
 'Add to Register',
 style: TextStyle(
 fontWeight: FontWeight.w700,
 fontSize: 14,
 ),
 ),
 ),
 ],
 ),
 ],
 ),
 ),
 ),
 ),
 ),
 );
 },
 );
 },
 );

 // Dispose controllers after dialog closes
 nameController.dispose();
 nameFocus.dispose();
 categoryController.dispose();
 versionController.dispose();
 linkedSpecIdController.dispose();
 linkController.dispose();

 // Commit the new row to the register only if user clicked "Add to Register"
 if (result == null) return;
 setState(() => _documents.add(result));
 _scheduleSave();
 if (!mounted) return;
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(
 content: Text(
 'Document "${result.name}" added to the register.'),
 backgroundColor: const Color(0xFF16A34A),
 behavior: SnackBarBehavior.floating,
 duration: const Duration(seconds: 3),
 ),
 );
 }

 void _updateDocumentRow(int index,
 _DesignSpecDocumentRow Function(_DesignSpecDocumentRow row) update) {
 if (index < 0 || index >= _documents.length) return;
 setState(() => _documents[index] = update(_documents[index]));
 _scheduleSave();
 }

 Future<void> _uploadDocumentRow(int index) async {
 if (index < 0 || index >= _documents.length) return;
 final uploaded = await _pickAndUploadAttachment(folder: 'design-spec-docs');
 if (uploaded == null) return;
 _updateDocumentRow(
 index,
 (row) => row.copyWith(
 link: uploaded.url,
 storagePath: uploaded.storagePath,
 fileName: uploaded.name,
 ),
 );
 if (!mounted) return;
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(content: Text('Document uploaded.')),
 );
 }

 @override
 Widget build(BuildContext context) {
 final isMobile = AppBreakpoints.isMobile(context);
 final horizontalPadding = isMobile ? 16.0 : 40.0;
 final provider = ProjectDataInherited.maybeOf(context);
 final projectData = provider?.projectData ?? ProjectDataModel();
 final ownerOptions = _ownerOptions(projectData);
 final selectedRequirement = _requirementRows.isEmpty
 ? null
 : _requirementRows[_safeSelectedRequirementIndex];

 if (kIsWeb) {
 return _buildStableWebScreen(
 horizontalPadding: horizontalPadding,
 projectData: projectData,
 );
 }

 return ResponsiveScaffold(
 activeItemLabel: 'Design Specifications',
 floatingActionButton: const KazAiChatBubble(positioned: false),
 body: Column(
 children: [
 PlanningPhaseHeader(
 title: 'Requirements Implementation', onExportPdf: _exportPdf),
 if (_isLoading)
 const LinearProgressIndicator(
 minHeight: 2,
 backgroundColor: Color(0xFFE5E7EB),
 color: Color(0xFFFFC812),
 ),
 Expanded(
 child: SingleChildScrollView(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 // Main content area
 Padding(
 padding: EdgeInsets.symmetric(
 horizontal: horizontalPadding, vertical: 24),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 _buildSectionApprovalCard(ownerOptions),
 const SizedBox(height: 16),
 RequirementsTraceabilityDashboard(
 projectData: projectData,
 requirements: _requirementRows,
 checklistItems: _checklistItems,
 ownerOptions: ownerOptions,
 notesController: _notesController,
 selectedRequirementIndex:
 _safeSelectedRequirementIndex,
 selectedRequirement: selectedRequirement,
 showAllRows: _showAllRows,
 onAddRequirement: () => _addRequirement(projectData),
 onRefreshContext: _syncAndLoad,
 onToggleShowAll: _toggleShowAllRows,
 onSelectRequirement: _selectRequirement,
 onDeleteRequirement: _deleteRequirement,
 onArtifactTap: _showArtifactMessage,
 onUpdateSelectedRequirement:
 _updateSelectedRequirement,
 onUploadArtifact: _uploadArtifactForRequirement,
 ),
 const SizedBox(height: 16),
 _buildDocumentsRegister(ownerOptions),
 ],
 ),
 ),
 const SizedBox(height: 24),
 LaunchPhaseNavigation(
 backLabel: PlanningPhaseNavigation.backLabel('requirements_implementation'),
 nextLabel: PlanningPhaseNavigation.nextLabel('requirements_implementation'),
 onBack: () => PlanningPhaseNavigation.goToPrevious(context, 'requirements_implementation'),
 onNext: () => PlanningPhaseNavigation.goToNext(context, 'requirements_implementation'),
 ),
 ],
 ),
 ),
 ),
 ],
 ),
 );
 }

 Widget _buildSectionApprovalCard(List<String> ownerOptions) {
 final approverOptions = <String>{
 ...ownerOptions,
 if (_sectionApprovedByController.text.trim().isNotEmpty)
 _sectionApprovedByController.text.trim(),
 }.toList()
 ..sort();
 final selectedApprover = _sectionApprovedByController.text.trim();
 final effectiveApprover = approverOptions.contains(selectedApprover)
 ? selectedApprover
 : (approverOptions.isEmpty ? '' : approverOptions.first);
 return Container(
 width: double.infinity,
 padding: const EdgeInsets.all(16),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(16),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 const Text(
 'Design Specifications Approval',
 style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
 ),
 const SizedBox(height: 6),
 const Text(
 'Section-level approval is required before continuing to Technical Alignment.',
 style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
 ),
 const SizedBox(height: 12),
 Row(
 children: [
 Expanded(
 child: DropdownButtonFormField<String>(
 initialValue: _sectionApprovalStatus,
 decoration: const InputDecoration(
 labelText: 'Approval Status',
 border: OutlineInputBorder(),
 isDense: true,
 ),
 items: const ['Draft', 'In Review', 'Approved']
 .map((value) => DropdownMenuItem(
 value: value,
 child: Text(value),
 ))
 .toList(),
 onChanged: (value) {
 if (value == null) return;
 setState(() => _sectionApprovalStatus = value);
 _scheduleSave();
 },
 ),
 ),
 const SizedBox(width: 12),
 Expanded(
 child: DropdownButtonFormField<String>(
 initialValue:
 effectiveApprover.isEmpty ? null : effectiveApprover,
 decoration: const InputDecoration(
 labelText: 'Approved By',
 border: OutlineInputBorder(),
 isDense: true,
 ),
 items: approverOptions
 .map((owner) => DropdownMenuItem(
 value: owner,
 child: Text(owner),
 ))
 .toList(),
 onChanged: (value) {
 _sectionApprovedByController.text = value ?? '';
 _scheduleSave();
 },
 ),
 ),
 const SizedBox(width: 12),
 Expanded(
 child: VoiceTextField(
 controller: _sectionApprovalDateController,
 onChanged: (_) => _scheduleSave(),
 decoration: const InputDecoration(
 labelText: 'Approval Date',
 hintText: 'YYYY-MM-DD',
 border: OutlineInputBorder(),
 isDense: true,
 ),
 ),
 ),
 ],
 ),
 const SizedBox(height: 12),
 VoiceTextField(
 controller: _sectionApprovalNotesController,
 onChanged: (_) => _scheduleSave(),
 minLines: 2,
 maxLines: 4,
 decoration: const InputDecoration(
 labelText: 'Approval Notes',
 border: OutlineInputBorder(),
 ),
 ),
 ],
 ),
 );
 }

 Widget _buildDocumentsRegister(List<String> ownerOptions) {
 return Container(
 width: double.infinity,
 padding: const EdgeInsets.all(16),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(16),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 children: [
 const Expanded(
 child: Text(
 'Documents & Links Register',
 style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
 ),
 ),
 TextButton.icon(
 onPressed: () => _addDocumentRow(ownerOptions),
 style: TextButton.styleFrom(
 foregroundColor: const Color(0xFFB8860B),
 backgroundColor: const Color(0xFFFFF8E1),
 padding: const EdgeInsets.symmetric(
 horizontal: 14, vertical: 8),
 shape: RoundedRectangleBorder(
 borderRadius: BorderRadius.circular(8)),
 ),
 icon: const Icon(Icons.add_circle_outline, size: 18),
 label: const Text(
 'Add document',
 style: TextStyle(fontWeight: FontWeight.w600),
 ),
 ),
 ],
 ),
 const SizedBox(height: 8),
 if (_documents.isEmpty)
 const Padding(
 padding: EdgeInsets.symmetric(vertical: 8),
 child: Row(
 children: [
 Icon(Icons.info_outline,
 size: 14, color: Color(0xFF9CA3AF)),
 SizedBox(width: 6),
 Text(
 'No documents added yet. Click "Add document" to register one.',
 style: TextStyle(
 fontSize: 12, color: Color(0xFF6B7280)),
 ),
 ],
 ),
 ),
 for (var i = 0; i < _documents.length; i++) ...[
 const SizedBox(height: 10),
 _buildDocumentRow(i, _documents[i], ownerOptions),
 ],
 ],
 ),
 );
 }

 Widget _buildDocumentRow(
 int index, _DesignSpecDocumentRow row, List<String> ownerOptions) {
 final options = <String>{
 ...ownerOptions,
 if (row.owner.trim().isNotEmpty) row.owner.trim(),
 }.toList()
 ..sort();
 return Container(
 padding: const EdgeInsets.all(12),
 decoration: BoxDecoration(
 color: const Color(0xFFF8FAFC),
 borderRadius: BorderRadius.circular(12),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 ),
 child: Column(
 children: [
 Row(
 children: [
 Expanded(
 child: VoiceTextFormField(
 initialValue: row.name,
 onChanged: (value) => _updateDocumentRow(
 index, (current) => current.copyWith(name: value)),
 decoration: const InputDecoration(
 labelText: 'Document Name',
 border: OutlineInputBorder(),
 isDense: true,
 ),
 ),
 ),
 const SizedBox(width: 10),
 Expanded(
 child: VoiceTextFormField(
 initialValue: row.category,
 onChanged: (value) => _updateDocumentRow(
 index, (current) => current.copyWith(category: value)),
 decoration: const InputDecoration(
 labelText: 'Category',
 border: OutlineInputBorder(),
 isDense: true,
 ),
 ),
 ),
 const SizedBox(width: 10),
 Expanded(
 child: VoiceTextFormField(
 initialValue: row.version,
 onChanged: (value) => _updateDocumentRow(
 index, (current) => current.copyWith(version: value)),
 decoration: const InputDecoration(
 labelText: 'Version',
 border: OutlineInputBorder(),
 isDense: true,
 ),
 ),
 ),
 ],
 ),
 const SizedBox(height: 10),
 Row(
 children: [
 Expanded(
 child: DropdownButtonFormField<String>(
 initialValue: options.contains(row.owner) ? row.owner : null,
 decoration: const InputDecoration(
 labelText: 'Owner',
 border: OutlineInputBorder(),
 isDense: true,
 ),
 items: options
 .map((owner) =>
 DropdownMenuItem(value: owner, child: Text(owner)))
 .toList(),
 onChanged: (value) => _updateDocumentRow(
 index,
 (current) => current.copyWith(owner: value ?? ''),
 ),
 ),
 ),
 const SizedBox(width: 10),
 Expanded(
 child: VoiceTextFormField(
 initialValue: row.linkedSpecId,
 onChanged: (value) => _updateDocumentRow(index,
 (current) => current.copyWith(linkedSpecId: value)),
 decoration: const InputDecoration(
 labelText: 'Linked Spec ID',
 border: OutlineInputBorder(),
 isDense: true,
 ),
 ),
 ),
 const SizedBox(width: 10),
 Expanded(
 child: VoiceTextFormField(
 initialValue: row.status,
 onChanged: (value) => _updateDocumentRow(
 index, (current) => current.copyWith(status: value)),
 decoration: const InputDecoration(
 labelText: 'Status',
 border: OutlineInputBorder(),
 isDense: true,
 ),
 ),
 ),
 ],
 ),
 const SizedBox(height: 10),
 Row(
 children: [
 Expanded(
 child: VoiceTextFormField(
 initialValue: row.link,
 onChanged: (value) => _updateDocumentRow(
 index, (current) => current.copyWith(link: value)),
 decoration: const InputDecoration(
 labelText: 'Link / Uploaded URL',
 border: OutlineInputBorder(),
 isDense: true,
 ),
 ),
 ),
 const SizedBox(width: 10),
 OutlinedButton.icon(
 onPressed: () => _uploadDocumentRow(index),
 icon: const Icon(Icons.upload_file),
 label: const Text('Upload'),
 ),
 const SizedBox(width: 8),
 IconButton(
 onPressed: () {
 setState(() => _documents.removeAt(index));
 _scheduleSave();
 },
 icon:
 const Icon(Icons.delete_outline, color: Color(0xFFB91C1C)),
 ),
 ],
 ),
 ],
 ),
 );
 }

 // =========================================================================
 // WEB SCREEN — World-class Design Specifications layout
 // =========================================================================

 Widget _buildStableWebScreen({
 required double horizontalPadding,
 required ProjectDataModel projectData,
 }) {
 final ownerOptions = _ownerOptions(projectData);

 return DesignPhaseStableShell(
 activeLabel: 'Design Specifications',
 breadcrumbPhase: 'Design Phase',
 breadcrumbTitle: 'Design Specifications',
 onItemSelected: _openStableDesignItem,
 child: ListView(
 padding: EdgeInsets.fromLTRB(
 horizontalPadding,
 24,
 horizontalPadding,
 32,
 ),
 children: [
 // 1. Header Section
 _buildWebHeader(projectData),
 const SizedBox(height: 16),

 // 4. Design Specifications Framework Guide
 _buildWebFrameworkGuide(),
 const SizedBox(height: 24),

 // 5. Requirements Register Table (MAIN)
 _buildWebRequirementsRegister(ownerOptions),
 const SizedBox(height: 20),

 // 7. Gap & Exception Analysis Panel
 _buildWebGapAnalysisPanel(),
 const SizedBox(height: 20),

 // 8. Approval Readiness Panel
 _buildWebApprovalReadinessPanel(),
 const SizedBox(height: 20),

 // 9. Section Approval Card
 _buildSectionApprovalCard(ownerOptions),
 const SizedBox(height: 20),

 // 10. Documents & Links Register
 _buildDocumentsRegister(ownerOptions),
 const SizedBox(height: 20),

 // Working Notes
 _buildWebWorkingNotes(),
 const SizedBox(height: 24),

 // Navigation
 LaunchPhaseNavigation(
 backLabel: PlanningPhaseNavigation.backLabel('requirements_implementation'),
 nextLabel: PlanningPhaseNavigation.nextLabel('requirements_implementation'),
 onBack: () => PlanningPhaseNavigation.goToPrevious(context, 'requirements_implementation'),
 onNext: () => PlanningPhaseNavigation.goToNext(context, 'requirements_implementation'),
 ),
 ],
 ),
 );
 }

 // -------------------------------------------------------------------------
 // 1. Header Section
 // -------------------------------------------------------------------------
 Widget _buildWebHeader(ProjectDataModel projectData) {
 return Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 // Yellow badge
 Container(
 padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
 decoration: BoxDecoration(
 color: const Color(0xFFFFC812),
 borderRadius: BorderRadius.circular(6),
 ),
 child: const Text(
 'DESIGN SPECIFICATIONS',
 style: TextStyle(
 fontSize: 11,
 fontWeight: FontWeight.w700,
 color: Colors.black,
 ),
 ),
 ),
 const SizedBox(height: 10),
 LayoutBuilder(
 builder: (context, constraints) {
 final compact = constraints.maxWidth < 1040;
 const titleBlock = Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 'Design Specifications',
 style: TextStyle(
 fontSize: 24,
 fontWeight: FontWeight.w700,
 color: Color(0xFF111827),
 ),
 ),
 SizedBox(height: 6),
 Text(
 'Track requirement traceability from source through design verification. '
 'Aligned with PMI PMBOK Collect Requirements (5.2), IEEE 830 Software Requirements '
 'Specification, ISO/IEC/IEEE 29148 Requirement Engineering Lifecycle, and INCOSE '
 'systems engineering practices. Every requirement is linked to design artifacts, '
 'acceptance criteria, and validation evidence before Technical Alignment.',
 style: TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
 ),
 ],
 );

 return titleBlock;
 },
 ),
 ],
 );
 }

 Widget _buildWebHeaderActions(ProjectDataModel projectData) {
 return Wrap(
 spacing: 10,
 runSpacing: 10,
 children: [
 _webActionButton(Icons.add, 'Add requirement',
 onPressed: () => _addRequirement(projectData)),
 _webActionButton(Icons.sync_outlined, 'Sync from scope',
 onPressed: () async {
 await _syncAndLoad();
 if (mounted) {
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(
 content: Text('Requirements synced from project scope.'),
 backgroundColor: Color(0xFF16A34A),
 ),
 );
 }
 }),
 _webActionButton(Icons.description_outlined, 'Export register',
 onPressed: () {
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(
 content: Text(
 'Export register is queued. Use the requirements table while export tools are finalized.'),
 ),
 );
 }),
 ],
 );
 }

 Widget _webActionButton(IconData icon, String label,
 {VoidCallback? onPressed}) {
 return OutlinedButton.icon(
 onPressed: onPressed ?? () {},
 icon: Icon(icon, size: 18, color: const Color(0xFF64748B)),
 label: Text(
 label,
 style: const TextStyle(
 fontSize: 12,
 fontWeight: FontWeight.w600,
 color: Color(0xFF64748B),
 ),
 ),
 style: OutlinedButton.styleFrom(
 side: const BorderSide(color: Color(0xFFE2E8F0)),
 padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
 ),
 );
 }

 // -------------------------------------------------------------------------
 // 2. Filter Chips Row
 // -------------------------------------------------------------------------
 Widget _buildWebFilterChips() {
 const filters = [
 'All requirements',
 'Mapped',
 'Unmapped',
 'Pending approval',
 'Closed'
 ];
 return Wrap(
 spacing: 10,
 runSpacing: 10,
 children: filters.map((filter) {
 final selected = _selectedFilters.contains(filter);
 return ChoiceChip(
 label: Text(
 filter,
 style: TextStyle(
 fontSize: 12,
 fontWeight: FontWeight.w600,
 color: selected ? Colors.white : const Color(0xFF475569),
 ),
 ),
 selected: selected,
 selectedColor: const Color(0xFF111827),
 backgroundColor: Theme.of(context).scaffoldBackgroundColor,
 shape: const StadiumBorder(
 side: BorderSide(color: Color(0xFFE5E7EB)),
 ),
 onSelected: (value) {
 setState(() {
 if (value) {
 if (filter == 'All requirements') {
 _selectedFilters
 ..clear()
 ..add(filter);
 } else {
 _selectedFilters
 ..remove('All requirements')
 ..add(filter);
 }
 } else {
 _selectedFilters.remove(filter);
 if (_selectedFilters.isEmpty) {
 _selectedFilters.add('All requirements');
 }
 }
 });
 },
 );
 }).toList(),
 );
 }

 /// Filter requirement rows based on selected filter chips.
 List<RequirementRow> get _filteredRequirementRows {
 if (_selectedFilters.contains('All requirements')) {
 return _requirementRows;
 }
 return _requirementRows.where((row) {
 if (_selectedFilters.contains('Mapped') &&
 row.validationStatus.trim().toLowerCase() == 'mapped') {
 return true;
 }
 if (_selectedFilters.contains('Unmapped') &&
 row.validationStatus.trim().toLowerCase() == 'unmapped') {
 return true;
 }
 if (_selectedFilters.contains('Pending approval') &&
 row.gapStatus.trim().toLowerCase() == 'pending approval') {
 return true;
 }
 if (_selectedFilters.contains('Closed') &&
 row.gapStatus.trim().toLowerCase() == 'closed') {
 return true;
 }
 return false;
 }).toList();
 }

 // -------------------------------------------------------------------------
 // 3. Stats Row
 // -------------------------------------------------------------------------
 Widget _buildWebStatsRow() {
 final totalReq = _requirementRows.length;
 final mappedCount = _requirementRows
 .where((r) => r.validationStatus.trim().toLowerCase() == 'mapped')
 .length;
 final pendingApprovalCount = _requirementRows
 .where((r) => r.gapStatus.trim().toLowerCase() == 'pending approval')
 .length;
 final gapCount = _requirementRows
 .where((r) =>
 r.gapStatus.trim().toLowerCase() != 'closed' &&
 r.gapStatus.trim().toLowerCase() != '')
 .length;

 final stats = [
 _StatCardData(
 'Total Requirements',
 '$totalReq',
 totalReq == 1 ? '1 item registered' : '$totalReq items registered',
 const Color(0xFFFFC812),
 ),
 _StatCardData(
 'Mapped to Design',
 '$mappedCount',
 mappedCount == totalReq ? 'All mapped' : '${totalReq - mappedCount} unmapped',
 const Color(0xFF10B981),
 ),
 _StatCardData(
 'Pending Approval',
 '$pendingApprovalCount',
 pendingApprovalCount > 0 ? 'Require attention' : 'All resolved',
 const Color(0xFFF97316),
 ),
 _StatCardData(
 'Gap Items',
 '$gapCount',
 gapCount > 0 ? 'Open gaps' : 'No gaps',
 const Color(0xFFB8860B),
 ),
 ];

 return Wrap(
 spacing: 12,
 runSpacing: 12,
 children: stats.map(_buildWebStatCard).toList(),
 );
 }

 Widget _buildWebStatCard(_StatCardData data) {
 return Container(
 width: 220,
 padding: const EdgeInsets.all(16),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(12),
 border: Border.all(color: const Color(0xFFE2E8F0)),
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 data.value,
 style: TextStyle(
 fontSize: 20,
 fontWeight: FontWeight.w700,
 color: data.color,
 ),
 ),
 const SizedBox(height: 6),
 Text(
 data.label,
 style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
 ),
 const SizedBox(height: 6),
 Text(
 data.supporting,
 style: TextStyle(
 fontSize: 12,
 fontWeight: FontWeight.w600,
 color: data.color,
 ),
 ),
 ],
 ),
 );
 }

 // -------------------------------------------------------------------------
 // 4. Design Specifications Framework Guide
 // -------------------------------------------------------------------------
 Widget _buildWebFrameworkGuide() {
 return Container(
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(16),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 boxShadow: [
 BoxShadow(
 color: Colors.black.withValues(alpha: 0.04),
 blurRadius: 12,
 offset: const Offset(0, 6),
 ),
 ],
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 // Collapsible header — always visible
 InkWell(
 borderRadius: BorderRadius.circular(16),
 onTap: () => setState(() {
 _frameworkGuideExpanded = !_frameworkGuideExpanded;
 }),
 child: Padding(
 padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
 child: Row(
 children: [
 const Expanded(
 child: Text(
 'Design specifications framework',
 style: TextStyle(
 fontSize: 16,
 fontWeight: FontWeight.w800,
 color: Color(0xFF111827),
 ),
 ),
 ),
 AnimatedRotation(
 turns: _frameworkGuideExpanded ? 0.5 : 0,
 duration: const Duration(milliseconds: 200),
 child: const Icon(
 Icons.keyboard_arrow_down,
 size: 22,
 color: Color(0xFF6B7280),
 ),
 ),
 ],
 ),
 ),
 ),
 // Expandable body
 AnimatedCrossFade(
 firstChild: const SizedBox.shrink(),
 secondChild: Padding(
 padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 const Text(
 'Grounded in IEEE 830 Software Requirements Specification, '
 'ISO/IEC/IEEE 29148 Requirement Engineering Lifecycle, PMI PMBOK '
 'Collect Requirements (5.2), and INCOSE systems engineering '
 'lifecycle practices. Effective requirement traceability ensures '
 'every specification is linked to design artifacts, acceptance '
 'criteria, and validation evidence before proceeding to Technical Alignment.',
 style: TextStyle(
 fontSize: 13,
 fontWeight: FontWeight.w500,
 color: Color(0xFF6B7280),
 height: 1.5,
 ),
 ),
 const SizedBox(height: 18),
 Column(
 children: [
 _buildWebGuideCard(
 Icons.account_tree_outlined,
 'Requirements Traceability',
 'The Requirements Traceability Matrix (RTM) connects each requirement '
 'to design artifacts, test cases, and source documents. Every mapped '
 'requirement should have an unbroken chain from origin through '
 'implementation to verification.',
 const Color(0xFFFFC812),
 ),
 const SizedBox(height: 12),
 _buildWebGuideCard(
 Icons.verified_outlined,
 'Validation & Evidence',
 'Each mapped requirement must have acceptance criteria and a defined '
 'test method. Validation evidence demonstrates that the design artifact '
 'satisfies the requirement intent and can be independently verified.',
 const Color(0xFF10B981),
 ),
 const SizedBox(height: 12),
 _buildWebGuideCard(
 Icons.warning_amber_outlined,
 'Gap Management',
 'Track unmapped requirements and resolve conflicts before proceeding '
 'to Technical Alignment. Pending approval gaps indicate design decisions '
 'that still need stakeholder resolution or additional evidence.',
 const Color(0xFFF59E0B),
 ),
 const SizedBox(height: 12),
 _buildWebGuideCard(
 Icons.admin_panel_settings_outlined,
 'Approval Gates',
 'Section-level approval is required before the project can advance '
 'to Technical Alignment. All gaps must be resolved, acceptance criteria '
 'defined for mapped items, and the section approver must sign off.',
 const Color(0xFFEF4444),
 ),
 ],
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

 Widget _buildWebGuideCard(
 IconData icon, String title, String description, Color color) {
 return Container(
 width: double.infinity,
 padding: const EdgeInsets.all(14),
 decoration: BoxDecoration(
 color: color.withValues(alpha: 0.04),
 borderRadius: BorderRadius.circular(12),
 border: Border.all(color: color.withValues(alpha: 0.12)),
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 children: [
 Container(
 padding: const EdgeInsets.all(6),
 decoration: BoxDecoration(
 color: color.withValues(alpha: 0.12),
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

 // -------------------------------------------------------------------------
 // 5. Requirements Register Table (MAIN TABLE)
 // -------------------------------------------------------------------------
 Widget _buildWebRequirementsRegister(List<String> ownerOptions) {
 final filteredRows = _filteredRequirementRows;

 return Container(
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(16),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 boxShadow: [
 BoxShadow(
 color: Colors.black.withValues(alpha: 0.04),
 blurRadius: 12,
 offset: const Offset(0, 6),
 ),
 ],
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 // Panel header with add button
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
 'Requirements register',
 style: TextStyle(
 fontSize: 16,
 fontWeight: FontWeight.w800,
 color: Color(0xFF111827),
 ),
 ),
 const SizedBox(height: 6),
 Text(
 '${filteredRows.length} requirements${filteredRows.length != _requirementRows.length ? ' (filtered from ${_requirementRows.length})' : ''}. '
 'Each row maps a requirement to its design artifact, validation status, and gap resolution.',
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
 onPressed: () {
 final provider = ProjectDataInherited.maybeOf(context);
 _addRequirement(provider?.projectData ?? ProjectDataModel());
 },
 icon: const Icon(Icons.add, size: 16),
 label: const Text('Add requirement',
 style:
 TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
 style: OutlinedButton.styleFrom(
 foregroundColor: const Color(0xFF475569),
 side: const BorderSide(color: Color(0xFFE2E8F0)),
 padding:
 const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
 shape: RoundedRectangleBorder(
 borderRadius: BorderRadius.circular(12)),
 ),
 ),
 ],
 ),
 ),
 const Divider(height: 1, thickness: 1, color: Color(0xFFE5E7EB)),

 // Empty state
 if (filteredRows.isEmpty)
 const Padding(
 padding: EdgeInsets.all(32),
 child: Center(
 child: Column(
 children: [
 Icon(Icons.assignment_outlined,
 color: Color(0xFF9CA3AF), size: 32),
 SizedBox(height: 12),
 Text(
 'No requirements found. Add requirements or adjust filters.',
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
 padding:
 const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
 decoration: const BoxDecoration(color: Color(0xFFF8FAFC)),
 child: const Row(
 children: [
 Expanded(
 flex: 1,
 child: Text('REQ ID',
 style: TextStyle(
 fontSize: 10,
 fontWeight: FontWeight.w800,
 color: Color(0xFF6B7280),
 letterSpacing: 0.8))),
 Expanded(
 flex: 3,
 child: Text('TITLE',
 style: TextStyle(
 fontSize: 10,
 fontWeight: FontWeight.w800,
 color: Color(0xFF6B7280),
 letterSpacing: 0.8))),
 Expanded(
 flex: 1,
 child: Text('OWNER',
 style: TextStyle(
 fontSize: 10,
 fontWeight: FontWeight.w800,
 color: Color(0xFF6B7280),
 letterSpacing: 0.8))),
 Expanded(
 flex: 1,
 child: Text('TYPE',
 style: TextStyle(
 fontSize: 10,
 fontWeight: FontWeight.w800,
 color: Color(0xFF6B7280),
 letterSpacing: 0.8),
 textAlign: TextAlign.center)),
 Expanded(
 flex: 1,
 child: Text('VALIDATION',
 style: TextStyle(
 fontSize: 10,
 fontWeight: FontWeight.w800,
 color: Color(0xFF6B7280),
 letterSpacing: 0.8),
 textAlign: TextAlign.center)),
 Expanded(
 flex: 1,
 child: Text('GAP STATUS',
 style: TextStyle(
 fontSize: 10,
 fontWeight: FontWeight.w800,
 color: Color(0xFF6B7280),
 letterSpacing: 0.8),
 textAlign: TextAlign.center)),
 SizedBox(
 width: 80,
 child: Text('ACTIONS',
 style: TextStyle(
 fontSize: 10,
 fontWeight: FontWeight.w800,
 color: Color(0xFF6B7280),
 letterSpacing: 0.8),
 textAlign: TextAlign.center)),
 ],
 ),
 ),
 // Table data rows
 ...List.generate(filteredRows.length, (index) {
 final row = filteredRows[index];
 final actualIndex = _requirementRows.indexOf(row);
 final isSelected = actualIndex == _selectedRequirementIndex;
 final isLast = index == filteredRows.length - 1;
 return _buildWebRequirementTableRow(
 row: row,
 actualIndex: actualIndex,
 isSelected: isSelected,
 isStriped: index.isOdd,
 showDivider: !isLast,
 );
 }),
 ],
 ],
 ),
 );
 }

 Widget _buildWebRequirementTableRow({
 required RequirementRow row,
 required int actualIndex,
 required bool isSelected,
 required bool isStriped,
 required bool showDivider,
 }) {
 return MouseRegion(
 cursor: SystemMouseCursors.click,
 child: GestureDetector(
 onTap: () => _showVerificationPopup(actualIndex),
 child: Container(
 color: isSelected
 ? const Color(0xFFFFF8E1)
 : isStriped
 ? const Color(0xFFF9FAFB)
 : Colors.white,
 child: Column(
 children: [
 Padding(
 padding:
 const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
 child: Row(
 crossAxisAlignment: CrossAxisAlignment.center,
 children: [
 // REQ ID
 Expanded(
 flex: 1,
 child: Text(
 row.requirementId.trim().isEmpty
 ? '—'
 : row.requirementId,
 style: const TextStyle(
 fontSize: 11,
 fontWeight: FontWeight.w700,
 color: Color(0xFF475569),
 ),
 ),
 ),
 // TITLE
 Expanded(
 flex: 3,
 child: Text(
 row.title.trim().isEmpty ? 'Untitled' : row.title,
 overflow: TextOverflow.ellipsis,
 style: TextStyle(
 fontSize: 11,
 fontWeight: FontWeight.w600,
 color: row.title.trim().isEmpty
 ? const Color(0xFF9CA3AF)
 : const Color(0xFF111827),
 ),
 ),
 ),
 // OWNER
 Expanded(
 flex: 1,
 child: Text(
 row.owner.trim().isEmpty ? '—' : row.owner,
 style: const TextStyle(
 fontSize: 11,
 color: Color(0xFF475569),
 ),
 ),
 ),
 // TYPE
 Expanded(
 flex: 1,
 child: Center(
 child: Text(
 row.requirementType,
 style: const TextStyle(
 fontSize: 11,
 color: Color(0xFF475569),
 ),
 ),
 ),
 ),
 // VALIDATION STATUS (badge)
 Expanded(
 flex: 1,
 child: Center(
 child: Container(
 padding: const EdgeInsets.symmetric(
 horizontal: 8, vertical: 4),
 decoration: BoxDecoration(
 color: _validationColor(row.validationStatus)
 .withValues(alpha: 0.1),
 borderRadius: BorderRadius.circular(12),
 ),
 child: Text(
 row.validationStatus,
 style: TextStyle(
 fontSize: 10,
 fontWeight: FontWeight.w600,
 color: _validationColor(row.validationStatus),
 ),
 ),
 ),
 ),
 ),
 // GAP STATUS (badge)
 Expanded(
 flex: 1,
 child: Center(
 child: Container(
 padding: const EdgeInsets.symmetric(
 horizontal: 8, vertical: 4),
 decoration: BoxDecoration(
 color: _gapStatusColor(row.gapStatus).withValues(alpha: 0.1),
 borderRadius: BorderRadius.circular(12),
 ),
 child: Text(
 row.gapStatus,
 style: TextStyle(
 fontSize: 10,
 fontWeight: FontWeight.w600,
 color: _gapStatusColor(row.gapStatus),
 ),
 ),
 ),
 ),
 ),
 // ACTIONS
 SizedBox(
 width: 80,
 child: Row(
 mainAxisSize: MainAxisSize.min,
 mainAxisAlignment: MainAxisAlignment.center,
 children: [
 IconButton(
 icon: const Icon(Icons.edit_outlined,
 size: 16, color: Color(0xFF64748B)),
 onPressed: () =>
 _showRequirementEditDialog(actualIndex),
 tooltip: 'Edit',
 padding: EdgeInsets.zero,
 constraints:
 const BoxConstraints(minWidth: 28, minHeight: 28),
 ),
 IconButton(
 icon: const Icon(Icons.visibility_outlined,
 size: 16, color: Color(0xFF64748B)),
 onPressed: () => _showVerificationPopup(actualIndex),
 tooltip: 'View detail',
 padding: EdgeInsets.zero,
 constraints:
 const BoxConstraints(minWidth: 28, minHeight: 28),
 ),
 IconButton(
 icon: const Icon(Icons.delete_outline,
 size: 16, color: Color(0xFF9CA3AF)),
 onPressed: () => _deleteRequirement(actualIndex),
 tooltip: 'Delete',
 padding: EdgeInsets.zero,
 constraints:
 const BoxConstraints(minWidth: 28, minHeight: 28),
 ),
 ],
 ),
 ),
 ],
 ),
 ),
 if (showDivider)
 const Divider(
 height: 1, thickness: 1, color: Color(0xFFE5E7EB)),
 ],
 ),
 ),
 ),
 );
 }

 // -------------------------------------------------------------------------
 // 6. Acceptance Criteria & Verification — Popup Dialog
 // -------------------------------------------------------------------------
 void _showVerificationPopup(int index) {
 if (index < 0 || index >= _requirementRows.length) return;
 setState(() => _selectedRequirementIndex = index);
 final selected = _requirementRows[index];
 final ownerOptions = _ownerOptions(
 ProjectDataInherited.maybeOf(context)?.projectData ?? ProjectDataModel());

 showDialog<void>(
 context: context,
 builder: (dialogContext) => _VerificationPopupDialog(
 requirement: selected,
 ownerOptions: ownerOptions,
 onUpdate: (updated) {
 _updateRequirement(index, (_) => updated);
 },
 onEditAll: () {
 Navigator.of(dialogContext).pop();
 _showRequirementEditDialog(index);
 },
 onUploadArtifact: () {
 Navigator.of(dialogContext).pop();
 _uploadArtifactForRequirement(selected);
 },
 onClose: () => Navigator.of(dialogContext).pop(),
 ),
 );
 }

 // Keep the inline builder for reuse in non-web paths (unused in web ListView now)
 // -------------------------------------------------------------------------
 // 6b. Acceptance Criteria & Verification Panel (inline — kept for reference)
 // -------------------------------------------------------------------------
 Widget _buildWebVerificationPanel(List<String> ownerOptions) {
 final selected = _requirementRows.isEmpty
 ? null
 : _requirementRows[_safeSelectedRequirementIndex];

 if (selected == null) {
 return Container(
 padding: const EdgeInsets.all(20),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(16),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 ),
 child: const Center(
 child: Padding(
 padding: EdgeInsets.all(24.0),
 child: Text('Select a requirement from the register above to view details.',
 style: TextStyle(color: Color(0xFF64748B))),
 ),
 ),
 );
 }

 return Container(
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(16),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 boxShadow: [
 BoxShadow(
 color: Colors.black.withValues(alpha: 0.04),
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
 children: [
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 'Acceptance criteria & verification — ${selected.requirementId}',
 style: const TextStyle(
 fontSize: 16,
 fontWeight: FontWeight.w800,
 color: Color(0xFF111827),
 ),
 ),
 const SizedBox(height: 4),
 Text(
 selected.title,
 style: const TextStyle(
 fontSize: 12,
 fontWeight: FontWeight.w500,
 color: Color(0xFF6B7280),
 ),
 ),
 ],
 ),
 ),
 OutlinedButton.icon(
 onPressed: () => _showRequirementEditDialog(
 _safeSelectedRequirementIndex),
 icon: const Icon(Icons.edit_outlined, size: 16),
 label: const Text('Edit all fields',
 style:
 TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
 style: OutlinedButton.styleFrom(
 foregroundColor: const Color(0xFF475569),
 side: const BorderSide(color: Color(0xFFE2E8F0)),
 padding:
 const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
 shape: RoundedRectangleBorder(
 borderRadius: BorderRadius.circular(12)),
 ),
 ),
 ],
 ),
 ),
 const Divider(height: 1, thickness: 1, color: Color(0xFFE5E7EB)),

 // Editable fields in a grid
 Padding(
 padding: const EdgeInsets.all(20),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 // Row 1: ID, Owner, Type
 Row(
 children: [
 Expanded(
 child: _buildWebInlineField(
 label: 'Requirement ID',
 value: selected.requirementId,
 onChanged: (v) => _updateSelectedRequirement(
 (r) => r.copyWith(requirementId: v)),
 ),
 ),
 const SizedBox(width: 12),
 Expanded(
 child: _buildWebOwnerDropdown(
 label: 'Owner',
 value: selected.owner,
 options: ownerOptions,
 onChanged: (v) => _updateSelectedRequirement(
 (r) => r.copyWith(owner: v)),
 ),
 ),
 const SizedBox(width: 12),
 Expanded(
 child: _buildWebDropdownField(
 label: 'Requirement Type',
 value: selected.requirementType,
 options: const [
 'Functional',
 'Non-Functional',
 'Constraint',
 'Performance',
 'Security'
 ],
 onChanged: (v) => _updateSelectedRequirement(
 (r) => r.copyWith(requirementType: v)),
 ),
 ),
 ],
 ),
 const SizedBox(height: 14),
 // Row 2: Source, Source Type
 Row(
 children: [
 Expanded(
 child: _buildWebDropdownField(
 label: 'Source (Rule Type)',
 value: selected.ruleType,
 options: const [
 'Internal',
 'External',
 ],
 onChanged: (v) => _updateSelectedRequirement(
 (r) => r.copyWith(ruleType: v)),
 ),
 ),
 const SizedBox(width: 12),
 Expanded(
 child: _buildWebDropdownField(
 label: 'Source Type',
 value: selected.sourceType,
 options: const [
 'Contract',
 'Vendor',
 'Regulatory',
 'Standard',
 'Stakeholder',
 ],
 onChanged: (v) => _updateSelectedRequirement(
 (r) => r.copyWith(sourceType: v)),
 ),
 ),
 const SizedBox(width: 12),
 Expanded(
 child: _buildWebDropdownField(
 label: 'Validation Status',
 value: selected.validationStatus,
 options: const ['Mapped', 'Unmapped', 'In Review'],
 onChanged: (v) => _updateSelectedRequirement(
 (r) => r.copyWith(validationStatus: v)),
 ),
 ),
 ],
 ),
 const SizedBox(height: 14),
 // Row 3: Description, Definition
 Row(
 children: [
 Expanded(
 child: _buildWebInlineField(
 label: 'Description / Title',
 value: selected.title,
 maxLines: 2,
 onChanged: (v) => _updateSelectedRequirement(
 (r) => r.copyWith(title: v)),
 ),
 ),
 const SizedBox(width: 12),
 Expanded(
 child: _buildWebInlineField(
 label: 'Definition / Intent',
 value: selected.definition,
 maxLines: 2,
 onChanged: (v) => _updateSelectedRequirement(
 (r) => r.copyWith(definition: v)),
 ),
 ),
 ],
 ),
 const SizedBox(height: 14),
 // Row 4: Design artifact fields
 Row(
 children: [
 Expanded(
 child: _buildWebDropdownField(
 label: 'Design Artifact Type',
 value: selected.designArtifactType,
 options: const [
 'Figma',
 'PDF',
 'Confluence',
 'Jira',
 'Miro',
 'Spreadsheet',
 'Code',
 'Other',
 ],
 onChanged: (v) => _updateSelectedRequirement(
 (r) => r.copyWith(designArtifactType: v)),
 ),
 ),
 const SizedBox(width: 12),
 Expanded(
 child: _buildWebInlineField(
 label: 'Artifact Label',
 value: selected.designArtifactLabel,
 onChanged: (v) => _updateSelectedRequirement(
 (r) => r.copyWith(designArtifactLabel: v)),
 ),
 ),
 ],
 ),
 const SizedBox(height: 14),
 // Row 5: Acceptance Criteria, Test Method
 Row(
 children: [
 Expanded(
 child: _buildWebInlineField(
 label: 'Acceptance Criteria',
 value: selected.acceptanceCriteria,
 maxLines: 2,
 onChanged: (v) => _updateSelectedRequirement(
 (r) => r.copyWith(acceptanceCriteria: v)),
 ),
 ),
 const SizedBox(width: 12),
 Expanded(
 child: _buildWebInlineField(
 label: 'Test Method',
 value: selected.testMethod,
 onChanged: (v) => _updateSelectedRequirement(
 (r) => r.copyWith(testMethod: v)),
 ),
 ),
 ],
 ),
 const SizedBox(height: 14),
 // Row 6: Source Document, Artifact URL
 Row(
 children: [
 Expanded(
 child: _buildWebInlineField(
 label: 'Source Document',
 value: selected.sourceDocument,
 onChanged: (v) => _updateSelectedRequirement(
 (r) => r.copyWith(sourceDocument: v)),
 ),
 ),
 const SizedBox(width: 12),
 Expanded(
 child: Row(
 children: [
 Expanded(
 child: _buildWebInlineField(
 label: 'Artifact URL',
 value: selected.designArtifactUrl,
 onChanged: (v) => _updateSelectedRequirement(
 (r) => r.copyWith(designArtifactUrl: v)),
 ),
 ),
 const SizedBox(width: 8),
 OutlinedButton.icon(
 onPressed: () =>
 _uploadArtifactForRequirement(selected),
 icon: const Icon(Icons.upload_file,
 size: 16, color: Color(0xFF64748B)),
 label: const Text('Upload'),
 style: OutlinedButton.styleFrom(
 foregroundColor: const Color(0xFF64748B),
 side:
 const BorderSide(color: Color(0xFFE2E8F0)),
 padding: const EdgeInsets.symmetric(
 horizontal: 10, vertical: 8),
 shape: RoundedRectangleBorder(
 borderRadius: BorderRadius.circular(8)),
 ),
 ),
 ],
 ),
 ),
 ],
 ),
 ],
 ),
 ),
 ],
 ),
 );
 }

 // -------------------------------------------------------------------------
 // 7. Gap & Exception Analysis Panel
 // -------------------------------------------------------------------------
 Widget _buildWebGapAnalysisPanel() {
 final gapItems = _requirementRows
 .where((r) => r.gapStatus.trim().toLowerCase() != 'closed')
 .toList();

 return Container(
 padding: const EdgeInsets.all(20),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(16),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 boxShadow: [
 BoxShadow(
 color: Colors.black.withValues(alpha: 0.04),
 blurRadius: 12,
 offset: const Offset(0, 6),
 ),
 ],
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 const Text(
 'Gap & exception analysis',
 style: TextStyle(
 fontSize: 16,
 fontWeight: FontWeight.w800,
 color: Color(0xFF111827),
 ),
 ),
 const SizedBox(height: 6),
 const Text(
 'Requirements with unresolved gaps or pending approval status. '
 'Resolve all gaps before proceeding to Technical Alignment.',
 style: TextStyle(
 fontSize: 12,
 fontWeight: FontWeight.w500,
 color: Color(0xFF6B7280),
 height: 1.45,
 ),
 ),
 const SizedBox(height: 16),
 if (gapItems.isEmpty)
 Container(
 padding: const EdgeInsets.all(16),
 decoration: BoxDecoration(
 color: const Color(0xFFF0FDF4),
 borderRadius: BorderRadius.circular(12),
 border: Border.all(color: const Color(0xFFBBF7D0)),
 ),
 child: const Row(
 children: [
 Icon(Icons.check_circle_outline,
 color: Color(0xFF10B981), size: 20),
 SizedBox(width: 10),
 Expanded(
 child: Text(
 'All requirements have closed gap status. No outstanding exceptions.',
 style: TextStyle(
 fontSize: 13,
 fontWeight: FontWeight.w500,
 color: Color(0xFF166534),
 ),
 ),
 ),
 ],
 ),
 )
 else
 ...gapItems.map((row) => Container(
 margin: const EdgeInsets.only(bottom: 12),
 padding: const EdgeInsets.all(14),
 decoration: BoxDecoration(
 color: const Color(0xFFFFFBEB),
 borderRadius: BorderRadius.circular(12),
 border: Border.all(color: const Color(0xFFFDE68A)),
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 children: [
 const Icon(Icons.warning_amber_outlined,
 color: Color(0xFFF59E0B), size: 18),
 const SizedBox(width: 8),
 Expanded(
 child: Text(
 '${row.requirementId} · ${row.title}',
 style: const TextStyle(
 fontSize: 13,
 fontWeight: FontWeight.w700,
 color: Color(0xFF92400E),
 ),
 ),
 ),
 Container(
 padding: const EdgeInsets.symmetric(
 horizontal: 8, vertical: 4),
 decoration: BoxDecoration(
 color: _gapStatusColor(row.gapStatus)
 .withValues(alpha: 0.1),
 borderRadius: BorderRadius.circular(12),
 ),
 child: Text(
 row.gapStatus,
 style: TextStyle(
 fontSize: 10,
 fontWeight: FontWeight.w600,
 color: _gapStatusColor(row.gapStatus),
 ),
 ),
 ),
 ],
 ),
 if (row.conflictNote.trim().isNotEmpty) ...[
 const SizedBox(height: 8),
 Text(
 'Conflict: ${row.conflictNote}',
 style: const TextStyle(
 fontSize: 12,
 color: Color(0xFF92400E),
 height: 1.4,
 ),
 ),
 ],
 if (row.conflictImpact.trim().isNotEmpty &&
 row.conflictImpact.toLowerCase() != 'low') ...[
 const SizedBox(height: 4),
 Text(
 'Impact: ${row.conflictImpact}',
 style: const TextStyle(
 fontSize: 11,
 fontWeight: FontWeight.w600,
 color: Color(0xFFDC2626),
 ),
 ),
 ],
 ],
 ),
 )),
 ],
 ),
 );
 }

 // -------------------------------------------------------------------------
 // 8. Approval Readiness Panel
 // -------------------------------------------------------------------------
 Widget _buildWebApprovalReadinessPanel() {
 // Compute gate statuses from actual data
 final reqsComplete = _requirementRows.isNotEmpty &&
 _requirementRows.every((r) =>
 r.title.trim().isNotEmpty &&
 r.owner.trim().isNotEmpty &&
 r.definition.trim().isNotEmpty);
 final artifactsLinked = _requirementRows.isNotEmpty &&
 _requirementRows
 .where((r) => r.validationStatus.trim().toLowerCase() == 'mapped')
 .every((r) => r.designArtifactLabel.trim().isNotEmpty);
 final criteriaDefined = _requirementRows.isNotEmpty &&
 _requirementRows
 .where((r) => r.validationStatus.trim().toLowerCase() == 'mapped')
 .every((r) =>
 r.acceptanceCriteria.trim().isNotEmpty &&
 r.testMethod.trim().isNotEmpty);
 final gapsResolved = _requirementRows.isEmpty ||
 !_requirementRows.any((r) =>
 r.gapStatus.trim().toLowerCase() == 'pending approval');
 final sectionApproved =
 _sectionApprovalStatus == 'In Review' ||
 _sectionApprovalStatus == 'Approved';

 final autoGates = [
 _ApprovalGateData(
 gate: 'Requirements Complete',
 description:
 'All requirements have title, owner, and definition of intent populated.',
 approver: 'Product Lead',
 priority: 'Critical',
 status: _requirementRows.isEmpty
 ? 'Not Started'
 : reqsComplete
 ? 'Complete'
 : 'In Review',
 ),
 _ApprovalGateData(
 gate: 'Artifacts Linked',
 description:
 'All mapped requirements have design artifact labels and types defined.',
 approver: 'Design Lead',
 priority: 'High',
 status: _requirementRows.isEmpty
 ? 'Not Started'
 : artifactsLinked
 ? 'Complete'
 : 'Pending',
 ),
 _ApprovalGateData(
 gate: 'Acceptance Criteria Defined',
 description:
 'All mapped requirements include acceptance criteria and test methods.',
 approver: 'QA Lead',
 priority: 'High',
 status: _requirementRows.isEmpty
 ? 'Not Started'
 : criteriaDefined
 ? 'Complete'
 : 'Pending',
 ),
 _ApprovalGateData(
 gate: 'Gap Items Resolved',
 description:
 'No pending approval gaps remain. All conflict notes are addressed.',
 approver: 'Project Manager',
 priority: 'Critical',
 status: gapsResolved ? 'Complete' : 'In Review',
 ),
 _ApprovalGateData(
 gate: 'Section Approval',
 description:
 'Section-level approval status is In Review or Approved.',
 approver: 'Section Approver',
 priority: 'Critical',
 status: sectionApproved ? 'Complete' : 'Not Started',
 ),
 ];
 final gates = [...autoGates, ..._customApprovalGates];

 return Container(
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(16),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 boxShadow: [
 BoxShadow(
 color: Colors.black.withValues(alpha: 0.04),
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
 const Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 'Approval readiness',
 style: TextStyle(
 fontSize: 16,
 fontWeight: FontWeight.w800,
 color: Color(0xFF111827),
 ),
 ),
 SizedBox(height: 6),
 Text(
 'Gates that must be cleared before advancing to Technical Alignment. '
 'Each gate is auto-computed from the requirements register data.',
 style: TextStyle(
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
 onPressed: _showAddApprovalGateDialog,
 icon: const Icon(Icons.add, size: 16),
 label: const Text('Add gate',
 style: TextStyle(
 fontSize: 12, fontWeight: FontWeight.w600)),
 style: OutlinedButton.styleFrom(
 foregroundColor: const Color(0xFF475569),
 side: const BorderSide(color: Color(0xFFE2E8F0)),
 padding: const EdgeInsets.symmetric(
 horizontal: 14, vertical: 10),
 shape: RoundedRectangleBorder(
 borderRadius: BorderRadius.circular(12)),
 ),
 ),
 ],
 ),
 ),
 const Divider(height: 1, thickness: 1, color: Color(0xFFE5E7EB)),
 if (gates.isEmpty)
 const Padding(
 padding: EdgeInsets.all(32),
 child: Center(
 child: Text('No approval gates defined.',
 style: TextStyle(color: Color(0xFF64748B))),
 ),
 )
 else ...[
 // Table header
 Container(
 padding:
 const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
 decoration: const BoxDecoration(color: Color(0xFFF8FAFC)),
 child: const Row(
 children: [
 Expanded(
 flex: 4,
 child: Text('GATE',
 style: TextStyle(
 fontSize: 10,
 fontWeight: FontWeight.w800,
 color: Color(0xFF6B7280),
 letterSpacing: 0.8))),
 Expanded(
 flex: 4,
 child: Text('DESCRIPTION',
 style: TextStyle(
 fontSize: 10,
 fontWeight: FontWeight.w800,
 color: Color(0xFF6B7280),
 letterSpacing: 0.8))),
 SizedBox(
 width: 110,
 child: Text('STATUS',
 style: TextStyle(
 fontSize: 10,
 fontWeight: FontWeight.w800,
 color: Color(0xFF6B7280),
 letterSpacing: 0.8),
 textAlign: TextAlign.center)),
 Expanded(
 flex: 2,
 child: Text('APPROVER',
 style: TextStyle(
 fontSize: 10,
 fontWeight: FontWeight.w800,
 color: Color(0xFF6B7280),
 letterSpacing: 0.8),
 textAlign: TextAlign.center)),
 SizedBox(
 width: 90,
 child: Text('PRIORITY',
 style: TextStyle(
 fontSize: 10,
 fontWeight: FontWeight.w800,
 color: Color(0xFF6B7280),
 letterSpacing: 0.8),
 textAlign: TextAlign.center)),
 ],
 ),
 ),
 // Table rows
 ...List.generate(gates.length, (index) {
 final gate = gates[index];
 final isLast = index == gates.length - 1;
 final isCustom = index >= autoGates.length;
 return _buildWebApprovalGateRow(
 gate: gate,
 showDivider: !isLast,
 isCustom: isCustom,
 onDelete: isCustom
 ? () => _removeCustomApprovalGate(index - autoGates.length)
 : null,
 );
 }),
 ],
 ],
 ),
 );
 }

 Widget _buildWebApprovalGateRow({
 required _ApprovalGateData gate,
 required bool showDivider,
 bool isCustom = false,
 VoidCallback? onDelete,
 }) {
 return Container(
 color: isCustom ? const Color(0xFFFFFDF5) : Colors.white,
 child: Column(
 children: [
 Padding(
 padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
 child: Row(
 crossAxisAlignment: CrossAxisAlignment.center,
 children: [
 // GATE
 Expanded(
 flex: 4,
 child: Row(
 children: [
 if (isCustom)
 const Padding(
 padding: EdgeInsets.only(right: 6),
 child: Icon(Icons.add_circle_outline,
 size: 12, color: Color(0xFFD97706)),
 ),
 Expanded(
 child: Text(
 gate.gate,
 style: const TextStyle(
 fontSize: 11,
 fontWeight: FontWeight.w700,
 color: Color(0xFF111827),
 ),
 ),
 ),
 ],
 ),
 ),
 // DESCRIPTION
 Expanded(
 flex: 4,
 child: Text(
 gate.description,
 style: const TextStyle(
 fontSize: 11,
 color: Color(0xFF4B5563),
 height: 1.4,
 ),
 ),
 ),
 // STATUS
 SizedBox(
 width: 110,
 child: Center(
 child: Container(
 padding: const EdgeInsets.symmetric(
 horizontal: 8, vertical: 4),
 decoration: BoxDecoration(
 color: _approvalStatusColor(gate.status).withValues(alpha: 0.1),
 borderRadius: BorderRadius.circular(12),
 ),
 child: Text(
 gate.status,
 style: TextStyle(
 fontSize: 10,
 fontWeight: FontWeight.w600,
 color: _approvalStatusColor(gate.status),
 ),
 ),
 ),
 ),
 ),
 // APPROVER
 Expanded(
 flex: 2,
 child: Center(
 child: Text(
 gate.approver,
 style: const TextStyle(
 fontSize: 11,
 color: Color(0xFF475569),
 ),
 ),
 ),
 ),
 // PRIORITY
 SizedBox(
 width: 90,
 child: Center(
 child: Container(
 padding: const EdgeInsets.symmetric(
 horizontal: 8, vertical: 4),
 decoration: BoxDecoration(
 color: _priorityColor(gate.priority).withValues(alpha: 0.1),
 borderRadius: BorderRadius.circular(12),
 ),
 child: Text(
 gate.priority,
 style: TextStyle(
 fontSize: 10,
 fontWeight: FontWeight.w600,
 color: _priorityColor(gate.priority),
 ),
 ),
 ),
 ),
 ),
 // DELETE (custom gates only)
 if (isCustom && onDelete != null)
 Padding(
 padding: const EdgeInsets.only(left: 8),
 child: InkWell(
 onTap: onDelete,
 borderRadius: BorderRadius.circular(6),
 child: const Padding(
 padding: EdgeInsets.all(4),
 child: Icon(Icons.delete_outline,
 size: 16, color: Color(0xFFEF4444)),
 ),
 ),
 ),
 ],
 ),
 ),
 if (showDivider)
 const Divider(height: 1, thickness: 1, color: Color(0xFFE5E7EB)),
 ],
 ),
 );
 }

 // -------------------------------------------------------------------------
 // Working Notes Panel
 // -------------------------------------------------------------------------
 Widget _buildWebWorkingNotes() {
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
 const Text(
 'Working notes',
 style: TextStyle(
 fontSize: 16,
 fontWeight: FontWeight.w800,
 color: Color(0xFF111827),
 ),
 ),
 const SizedBox(height: 12),
 VoiceTextField(
 controller: _notesController,
 minLines: 4,
 maxLines: 10,
 decoration: const InputDecoration(
 hintText:
 'Capture implementation notes, handoff decisions, and traceability comments...',
 border: OutlineInputBorder(),
 ),
 ),
 ],
 ),
 );
 }

 // -------------------------------------------------------------------------
 // Full Edit Dialog for a Requirement Row
 // -------------------------------------------------------------------------
 void _showRequirementEditDialog(int index) {
 if (index < 0 || index >= _requirementRows.length) return;
 _showRequirementFormDialog(
 row: _requirementRows[index],
 isNew: false,
 editIndex: index,
 );
 }

 // -------------------------------------------------------------------------
 // 7. Requirement Add/Edit — Shared Modal Form Dialog
 // -------------------------------------------------------------------------
 // Shared by both the "Add requirement" button (isNew=true) and the row
 // "Edit" action (isNew=false, editIndex provided). Opening this dialog is
 // the ONLY way new rows enter the register — there is no longer a silent
 // inline-add path, which is what caused "Add" to not trigger the modal
 // while "Edit" did.
 void _showRequirementFormDialog({
 required RequirementRow row,
 required bool isNew,
 int? editIndex,
 }) {
 final reqIdController = TextEditingController(text: row.requirementId);
 final titleController = TextEditingController(text: row.title);
 final ownerController = TextEditingController(text: row.owner);
 final definitionController = TextEditingController(text: row.definition);
 var selectedReqType = row.requirementType;
 var selectedRuleType = row.ruleType;
 var selectedSourceType = row.sourceType;
 final artifactLabelController =
 TextEditingController(text: row.designArtifactLabel);
 var selectedArtifactType = row.designArtifactType;
 var selectedValidationStatus = row.validationStatus;
 final criteriaController =
 TextEditingController(text: row.acceptanceCriteria);
 final testMethodController = TextEditingController(text: row.testMethod);
 final sourceDocController = TextEditingController(text: row.sourceDocument);
 final artifactUrlController =
 TextEditingController(text: row.designArtifactUrl);
 var selectedGapStatus = row.gapStatus;
 final conflictNoteController = TextEditingController(text: row.conflictNote);
 var selectedConflictImpact = row.conflictImpact;

 showDialog<void>(
 context: context,
 builder: (dialogContext) => StatefulBuilder(
 builder: (context, setDialogState) => AlertDialog(
 title: Row(
 children: [
 Expanded(
 child: Text(
 isNew
 ? 'Add Requirement'
 : 'Edit Requirement — ${row.requirementId}',
 style: const TextStyle(fontSize: 18),
 ),
 ),
 IconButton(
 icon: const Icon(Icons.close, size: 20),
 tooltip: 'Close',
 onPressed: () => Navigator.of(dialogContext).pop(),
 ),
 ],
 ),
 content: SizedBox(
 width: 600,
 child: SingleChildScrollView(
 child: Column(
 mainAxisSize: MainAxisSize.min,
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 // Row 1: ID, Type
 Row(
 children: [
 Expanded(
 child: VoiceTextField(
 controller: reqIdController,
 decoration: const InputDecoration(
 labelText: 'Requirement ID *',
 isDense: true,
 ),
 ),
 ),
 const SizedBox(width: 12),
 Expanded(
 child: DropdownButtonFormField<String>(
 initialValue: selectedReqType,
 decoration: const InputDecoration(
 labelText: 'Requirement Type *',
 isDense: true,
 ),
 items: const [
 'Functional',
 'Non-Functional',
 'Constraint',
 'Performance',
 'Security'
 ]
 .map((v) => DropdownMenuItem(
 value: v, child: Text(v)))
 .toList(),
 onChanged: (v) {
 if (v != null) {
 setDialogState(() => selectedReqType = v);
 }
 },
 ),
 ),
 ],
 ),
 const SizedBox(height: 12),
 // Title
 VoiceTextField(
 controller: titleController,
 decoration: const InputDecoration(
 labelText: 'Title *',
 isDense: true,
 ),
 ),
 const SizedBox(height: 12),
 // Owner
 VoiceTextField(
 controller: ownerController,
 decoration: const InputDecoration(
 labelText: 'Owner *',
 isDense: true,
 ),
 ),
 const SizedBox(height: 12),
 // Definition
 VoiceTextField(
 controller: definitionController,
 minLines: 2,
 maxLines: 4,
 decoration: const InputDecoration(
 labelText: 'Definition / Intent *',
 isDense: true,
 ),
 ),
 const SizedBox(height: 12),
 // Rule Type, Source Type
 Row(
 children: [
 Expanded(
 child: DropdownButtonFormField<String>(
 initialValue: selectedRuleType,
 decoration: const InputDecoration(
 labelText: 'Rule Type',
 isDense: true,
 ),
 items: const ['Internal', 'External']
 .map((v) => DropdownMenuItem(
 value: v, child: Text(v)))
 .toList(),
 onChanged: (v) {
 if (v != null) {
 setDialogState(() => selectedRuleType = v);
 }
 },
 ),
 ),
 const SizedBox(width: 12),
 Expanded(
 child: DropdownButtonFormField<String>(
 initialValue: selectedSourceType,
 decoration: const InputDecoration(
 labelText: 'Source Type',
 isDense: true,
 ),
 items: const [
 'Contract',
 'Vendor',
 'Regulatory',
 'Standard',
 'Stakeholder'
 ]
 .map((v) => DropdownMenuItem(
 value: v, child: Text(v)))
 .toList(),
 onChanged: (v) {
 if (v != null) {
 setDialogState(() => selectedSourceType = v);
 }
 },
 ),
 ),
 ],
 ),
 const SizedBox(height: 12),
 // Artifact Type, Artifact Label
 Row(
 children: [
 Expanded(
 child: DropdownButtonFormField<String>(
 initialValue: selectedArtifactType,
 decoration: const InputDecoration(
 labelText: 'Artifact Type',
 isDense: true,
 ),
 items: const [
 'Figma',
 'PDF',
 'Confluence',
 'Jira',
 'Miro',
 'Spreadsheet',
 'Code',
 'Other'
 ]
 .map((v) => DropdownMenuItem(
 value: v, child: Text(v)))
 .toList(),
 onChanged: (v) {
 if (v != null) {
 setDialogState(() => selectedArtifactType = v);
 }
 },
 ),
 ),
 const SizedBox(width: 12),
 Expanded(
 child: VoiceTextField(
 controller: artifactLabelController,
 decoration: const InputDecoration(
 labelText: 'Artifact Label',
 isDense: true,
 ),
 ),
 ),
 ],
 ),
 const SizedBox(height: 12),
 // Validation Status, Gap Status
 Row(
 children: [
 Expanded(
 child: DropdownButtonFormField<String>(
 initialValue: selectedValidationStatus,
 decoration: const InputDecoration(
 labelText: 'Validation Status',
 isDense: true,
 ),
 items: const ['Mapped', 'Unmapped', 'In Review']
 .map((v) => DropdownMenuItem(
 value: v, child: Text(v)))
 .toList(),
 onChanged: (v) {
 if (v != null) {
 setDialogState(
 () => selectedValidationStatus = v);
 }
 },
 ),
 ),
 const SizedBox(width: 12),
 Expanded(
 child: DropdownButtonFormField<String>(
 initialValue: selectedGapStatus,
 decoration: const InputDecoration(
 labelText: 'Gap Status',
 isDense: true,
 ),
 items: const [
 'Closed',
 'Pending Approval',
 'Open',
 'Deferred'
 ]
 .map((v) => DropdownMenuItem(
 value: v, child: Text(v)))
 .toList(),
 onChanged: (v) {
 if (v != null) {
 setDialogState(() => selectedGapStatus = v);
 }
 },
 ),
 ),
 ],
 ),
 const SizedBox(height: 12),
 // Acceptance Criteria
 VoiceTextField(
 controller: criteriaController,
 minLines: 2,
 maxLines: 4,
 decoration: const InputDecoration(
 labelText: 'Acceptance Criteria',
 isDense: true,
 ),
 ),
 const SizedBox(height: 12),
 // Test Method, Source Document
 Row(
 children: [
 Expanded(
 child: VoiceTextField(
 controller: testMethodController,
 decoration: const InputDecoration(
 labelText: 'Test Method',
 isDense: true,
 ),
 ),
 ),
 const SizedBox(width: 12),
 Expanded(
 child: VoiceTextField(
 controller: sourceDocController,
 decoration: const InputDecoration(
 labelText: 'Source Document',
 isDense: true,
 ),
 ),
 ),
 ],
 ),
 const SizedBox(height: 12),
 // Artifact URL
 VoiceTextField(
 controller: artifactUrlController,
 decoration: const InputDecoration(
 labelText: 'Artifact URL',
 isDense: true,
 ),
 ),
 const SizedBox(height: 12),
 // Conflict Note, Conflict Impact
 Row(
 children: [
 Expanded(
 flex: 3,
 child: VoiceTextField(
 controller: conflictNoteController,
 decoration: const InputDecoration(
 labelText: 'Conflict Note',
 isDense: true,
 ),
 ),
 ),
 const SizedBox(width: 12),
 Expanded(
 child: DropdownButtonFormField<String>(
 initialValue: selectedConflictImpact,
 decoration: const InputDecoration(
 labelText: 'Impact',
 isDense: true,
 ),
 items: const ['Low', 'Medium', 'High', 'Critical']
 .map((v) => DropdownMenuItem(
 value: v, child: Text(v)))
 .toList(),
 onChanged: (v) {
 if (v != null) {
 setDialogState(
 () => selectedConflictImpact = v);
 }
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
 final committed = row.copyWith(
 requirementId: reqIdController.text.trim(),
 title: titleController.text.trim(),
 owner: ownerController.text.trim(),
 definition: definitionController.text.trim(),
 requirementType: selectedReqType,
 ruleType: selectedRuleType,
 sourceType: selectedSourceType,
 designArtifactType: selectedArtifactType,
 designArtifactLabel: artifactLabelController.text.trim(),
 validationStatus: selectedValidationStatus,
 acceptanceCriteria: criteriaController.text.trim(),
 testMethod: testMethodController.text.trim(),
 sourceDocument: sourceDocController.text.trim(),
 designArtifactUrl: artifactUrlController.text.trim(),
 gapStatus: selectedGapStatus,
 conflictNote: conflictNoteController.text.trim(),
 conflictImpact: selectedConflictImpact,
 );
 if (isNew) {
 // Commit the new row to the register only on Save.
 setState(() {
 _requirementRows.add(committed);
 _selectedRequirementIndex = _requirementRows.length - 1;
 _showAllRows = true;
 });
 _scheduleSave();
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(
 content: Text(
 'Requirement ${committed.requirementId} added.'),
 backgroundColor: const Color(0xFF16A34A),
 ),
 );
 } else {
 _updateRequirement(editIndex!, (_) => committed);
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(
 content: Text(
 'Requirement ${committed.requirementId} updated.'),
 backgroundColor: const Color(0xFF16A34A),
 ),
 );
 }
 Navigator.of(dialogContext).pop();
 },
 child: const Text('Save'),
 ),
 ],
 ),
 ),
 );
 }

 // -------------------------------------------------------------------------
 // Inline editable field helper
 // -------------------------------------------------------------------------
 Widget _buildWebInlineField({
 required String label,
 required String value,
 int maxLines = 1,
 required ValueChanged<String> onChanged,
 }) {
 return VoiceTextField(
 controller: TextEditingController(text: value),
 onChanged: onChanged,
 maxLines: maxLines,
 style: const TextStyle(fontSize: 13, color: Color(0xFF1F2937)),
 decoration: InputDecoration(
 labelText: label,
 isDense: true,
 filled: true,
 fillColor: const Color(0xFFF8FAFC),
 contentPadding:
 const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
 border: OutlineInputBorder(
 borderRadius: BorderRadius.circular(10),
 borderSide: const BorderSide(color: Color(0xFFE4E7EC)),
 ),
 enabledBorder: OutlineInputBorder(
 borderRadius: BorderRadius.circular(10),
 borderSide: const BorderSide(color: Color(0xFFE4E7EC)),
 ),
 focusedBorder: OutlineInputBorder(
 borderRadius: BorderRadius.circular(10),
 borderSide: const BorderSide(color: Color(0xFFFFC812), width: 2),
 ),
 ),
 );
 }

 Widget _buildWebDropdownField({
 required String label,
 required String value,
 required List<String> options,
 required ValueChanged<String> onChanged,
 }) {
 final safeOptions = options.contains(value) ? options : [value, ...options];
 return DropdownButtonFormField<String>(
 initialValue: safeOptions.contains(value) ? value : safeOptions.first,
 decoration: InputDecoration(
 labelText: label,
 isDense: true,
 filled: true,
 fillColor: const Color(0xFFF8FAFC),
 contentPadding:
 const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
 border: OutlineInputBorder(
 borderRadius: BorderRadius.circular(10),
 borderSide: const BorderSide(color: Color(0xFFE4E7EC)),
 ),
 enabledBorder: OutlineInputBorder(
 borderRadius: BorderRadius.circular(10),
 borderSide: const BorderSide(color: Color(0xFFE4E7EC)),
 ),
 focusedBorder: OutlineInputBorder(
 borderRadius: BorderRadius.circular(10),
 borderSide: const BorderSide(color: Color(0xFFFFC812), width: 2),
 ),
 ),
 items: safeOptions
 .map((v) =>
 DropdownMenuItem(value: v, child: Text(v, style: const TextStyle(fontSize: 13))))
 .toList(),
 onChanged: (v) {
 if (v != null) onChanged(v);
 },
 );
 }

 Widget _buildWebOwnerDropdown({
 required String label,
 required String value,
 required List<String> options,
 required ValueChanged<String> onChanged,
 }) {
 final safeOptions = <String>{
 ...options,
 if (value.trim().isNotEmpty) value.trim(),
 }.toList()
 ..sort();
 return DropdownButtonFormField<String>(
 initialValue: safeOptions.contains(value.trim()) ? value.trim() : (safeOptions.isEmpty ? null : safeOptions.first),
 decoration: InputDecoration(
 labelText: label,
 isDense: true,
 filled: true,
 fillColor: const Color(0xFFF8FAFC),
 contentPadding:
 const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
 border: OutlineInputBorder(
 borderRadius: BorderRadius.circular(10),
 borderSide: const BorderSide(color: Color(0xFFE4E7EC)),
 ),
 enabledBorder: OutlineInputBorder(
 borderRadius: BorderRadius.circular(10),
 borderSide: const BorderSide(color: Color(0xFFE4E7EC)),
 ),
 focusedBorder: OutlineInputBorder(
 borderRadius: BorderRadius.circular(10),
 borderSide: const BorderSide(color: Color(0xFFFFC812), width: 2),
 ),
 ),
 items: safeOptions
 .map((v) =>
 DropdownMenuItem(value: v, child: Text(v, style: const TextStyle(fontSize: 13))))
 .toList(),
 onChanged: (v) {
 if (v != null) onChanged(v);
 },
 );
 }

 // -------------------------------------------------------------------------
 // Color helpers for badges
 // -------------------------------------------------------------------------
 Color _validationColor(String status) {
 switch (status.trim().toLowerCase()) {
 case 'mapped':
 return const Color(0xFF10B981);
 case 'unmapped':
 return const Color(0xFFF59E0B);
 case 'in review':
 return const Color(0xFFFFC812);
 default:
 return const Color(0xFF9CA3AF);
 }
 }

 Color _gapStatusColor(String status) {
 switch (status.trim().toLowerCase()) {
 case 'closed':
 return const Color(0xFF10B981);
 case 'pending approval':
 return const Color(0xFFF59E0B);
 case 'open':
 return const Color(0xFFEF4444);
 case 'deferred':
 return const Color(0xFFB8860B);
 default:
 return const Color(0xFF9CA3AF);
 }
 }

 // --- Add / Delete custom approval gates ---

 Future<void> _showAddApprovalGateDialog() async {
 final gateController = TextEditingController();
 final descController = TextEditingController();
 final approverController = TextEditingController();
 var selectedPriority = 'High';
 var selectedStatus = 'Not Started';

 final saved = await showDialog<_ApprovalGateData>(
 context: context,
 builder: (dialogContext) {
 return StatefulBuilder(
 builder: (context, setDialogState) {
 return AlertDialog(
 title: const Text('Add approval gate'),
 content: SizedBox(
 width: 520,
 child: SingleChildScrollView(
 child: Column(
 mainAxisSize: MainAxisSize.min,
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 TextField(
 controller: gateController,
 decoration: const InputDecoration(
 labelText: 'Gate name *',
 hintText: 'e.g. Legal Review & Compliance',
 isDense: true,
 border: OutlineInputBorder(),
 ),
 ),
 const SizedBox(height: 12),
 TextField(
 controller: descController,
 decoration: const InputDecoration(
 labelText: 'Description',
 hintText:
 'What this gate covers and why it matters',
 isDense: true,
 border: OutlineInputBorder(),
 ),
 minLines: 2,
 maxLines: 4,
 ),
 const SizedBox(height: 12),
 TextField(
 controller: approverController,
 decoration: const InputDecoration(
 labelText: 'Approver *',
 hintText: 'e.g. General Counsel',
 isDense: true,
 border: OutlineInputBorder(),
 ),
 ),
 const SizedBox(height: 12),
 Row(
 children: [
 Expanded(
 child: DropdownButtonFormField<String>(
 initialValue: selectedPriority,
 decoration: const InputDecoration(
 labelText: 'Priority',
 isDense: true,
 border: OutlineInputBorder(),
 ),
 items: ['Critical', 'High', 'Medium', 'Low']
 .map((p) => DropdownMenuItem(
 value: p,
 child: Text(p,
 style:
 const TextStyle(fontSize: 13)),
 ))
 .toList(),
 onChanged: (value) {
 if (value == null) return;
 setDialogState(
 () => selectedPriority = value);
 },
 ),
 ),
 const SizedBox(width: 12),
 Expanded(
 child: DropdownButtonFormField<String>(
 initialValue: selectedStatus,
 decoration: const InputDecoration(
 labelText: 'Status',
 isDense: true,
 border: OutlineInputBorder(),
 ),
 items: [
 'Not Started',
 'Pending',
 'In Review',
 'Complete',
 ]
 .map((s) => DropdownMenuItem(
 value: s,
 child: Text(s,
 style:
 const TextStyle(fontSize: 13)),
 ))
 .toList(),
 onChanged: (value) {
 if (value == null) return;
 setDialogState(
 () => selectedStatus = value);
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
 onPressed: () => Navigator.pop(dialogContext),
 child: const Text('Cancel'),
 ),
 ElevatedButton(
 onPressed: () {
 if (gateController.text.trim().isEmpty ||
 approverController.text.trim().isEmpty) {
   return;
 }
 Navigator.pop(
 dialogContext,
 _ApprovalGateData(
 gate: gateController.text.trim(),
 description: descController.text.trim(),
 approver: approverController.text.trim(),
 priority: selectedPriority,
 status: selectedStatus,
 ),
 );
 },
 style: ElevatedButton.styleFrom(
 backgroundColor: const Color(0xFFD97706),
 foregroundColor: Colors.white,
 ),
 child: const Text('Add gate'),
 ),
 ],
 );
 },
 );
 },
 );

 if (saved != null && mounted) {
 setState(() => _customApprovalGates.add(saved));
 }
 }

 void _removeCustomApprovalGate(int index) {
 setState(() => _customApprovalGates.removeAt(index));
 }

 Color _approvalStatusColor(String status) {
 switch (status.trim().toLowerCase()) {
 case 'complete':
 return const Color(0xFF10B981);
 case 'in review':
 return const Color(0xFFFFC812);
 case 'pending':
 return const Color(0xFFF59E0B);
 case 'not started':
 return const Color(0xFF9CA3AF);
 default:
 return const Color(0xFF9CA3AF);
 }
 }

 Color _priorityColor(String priority) {
 switch (priority.trim().toLowerCase()) {
 case 'critical':
 return const Color(0xFFEF4444);
 case 'high':
 return const Color(0xFFF97316);
 case 'medium':
 return const Color(0xFFF59E0B);
 default:
 return const Color(0xFF64748B);
 }
 }

 // -------------------------------------------------------------------------
 // Navigation helper for stable shell sidebar  // -------------------------------------------------------------------------
  void _openStableDesignItem(String label) {
  final destination = switch (label) {
  'Design Management' => '/${AppRoutes.designPhase}',
  'Design Specifications' => '/${AppRoutes.requirementsImplementation}',
  'Technical Alignment' => '/${AppRoutes.technicalAlignment}',
  'Development Set Up' => '/${AppRoutes.developmentSetUp}',
  'UI/UX Design' => '/${AppRoutes.uiUxDesign}',
  _ => null,
  };

  if (destination == null) return;

  context.pushReplacement(destination);
  }

 Future<bool> _confirmDelete(String label) async {
 final result = await showDialog<bool>(
 context: context,
 builder: (dialogContext) => AlertDialog(
 title: const Text('Delete row?'),
 content: Text('Remove this $label from the table?'),
 actions: [
 TextButton(
 onPressed: () => Navigator.of(dialogContext).pop(false),
 child: const Text('Cancel'),
 ),
 TextButton(
 onPressed: () => Navigator.of(dialogContext).pop(true),
 style:
 TextButton.styleFrom(foregroundColor: const Color(0xFFB91C1C)),
 child: const Text('Delete'),
 ),
 ],
 ),
 );

 return result ?? false;
 }

 String _statusLabel(ChecklistStatus status) {
 switch (status) {
 case ChecklistStatus.ready:
 return 'Ready';
 case ChecklistStatus.inReview:
 return 'In review';
 case ChecklistStatus.pending:
 return 'Pending';
 }
 }

 Future<void> _exportPdf() async {
 final projectData = ProjectDataHelper.getData(context);
 await PdfExportHelper.exportScreenPdf(
 context: context,
 screenTitle: 'Requirements Implementation',
 sections: [
 PdfSection.keyValue('Project Info', [
 {'Project Name': projectData.projectName ?? 'N/A'},
 {'Solution Title': projectData.solutionTitle ?? 'N/A'},
 ]),
 PdfSection.text('Notes', projectData.planningNotes['planning_requirements_implementation_notes'] ?? 'No data recorded.'),
 ],
 );
 }
}

// End of _RequirementsImplementationScreenState

class _StatCardData {
 const _StatCardData(this.label, this.value, this.supporting, this.color);
 final String label;
 final String value;
 final String supporting;
 final Color color;
}

class _ApprovalGateData {
 const _ApprovalGateData({
 required this.gate,
 required this.description,
 required this.approver,
 required this.priority,
 required this.status,
 });
 final String gate;
 final String description;
 final String approver;
 final String priority;
 final String status;
}

class _TableColumn {  const _TableColumn({
    required this.label,
  }) : flex = 1, alignment = Alignment.centerLeft;

 final String label;
 final int flex;
 final Alignment alignment;
}

class _UploadedDoc {
 const _UploadedDoc({
 required this.name,
 required this.url,
 required this.storagePath,
 required this.contentType,
 required this.sizeBytes,
 });

 final String name;
 final String url;
 final String storagePath;
 final String contentType;
 final int sizeBytes;
}

class _DesignSpecDocumentRow {
 _DesignSpecDocumentRow({
 String? id,
 this.name = '',
 this.category = '',
 this.version = '',
 this.owner = '',
 this.linkedSpecId = '',
 this.link = '',
 this.status = 'Draft',
 this.fileName = '',
 this.storagePath = '',
 }) : id = id ?? DateTime.now().microsecondsSinceEpoch.toString();

 final String id;
 String name;
 String category;
 String version;
 String owner;
 String linkedSpecId;
 String link;
 String status;
 String fileName;
 String storagePath;

 _DesignSpecDocumentRow copyWith({
 String? name,
 String? category,
 String? version,
 String? owner,
 String? linkedSpecId,
 String? link,
 String? status,
 String? fileName,
 String? storagePath,
 }) {
 return _DesignSpecDocumentRow(
 id: id,
 name: name ?? this.name,
 category: category ?? this.category,
 version: version ?? this.version,
 owner: owner ?? this.owner,
 linkedSpecId: linkedSpecId ?? this.linkedSpecId,
 link: link ?? this.link,
 status: status ?? this.status,
 fileName: fileName ?? this.fileName,
 storagePath: storagePath ?? this.storagePath,
 );
 }

 Map<String, dynamic> toMap() => {
 'id': id,
 'name': name,
 'category': category,
 'version': version,
 'owner': owner,
 'linkedSpecId': linkedSpecId,
 'link': link,
 'status': status,
 'fileName': fileName,
 'storagePath': storagePath,
 };

 factory _DesignSpecDocumentRow.fromMap(Map<String, dynamic> map) {
 return _DesignSpecDocumentRow(
 id: map['id']?.toString(),
 name: map['name']?.toString() ?? '',
 category: map['category']?.toString() ?? '',
 version: map['version']?.toString() ?? '',
 owner: map['owner']?.toString() ?? '',
 linkedSpecId: map['linkedSpecId']?.toString() ?? '',
 link: map['link']?.toString() ?? '',
 status: map['status']?.toString() ?? 'Draft',
 fileName: map['fileName']?.toString() ?? '',
 storagePath: map['storagePath']?.toString() ?? '',
 );
 }
}

// =========================================================================
// Verification Popup Dialog — Shown when a requirement row is clicked
// =========================================================================
class _VerificationPopupDialog extends StatefulWidget {
 final RequirementRow requirement;
 final List<String> ownerOptions;
 final ValueChanged<RequirementRow> onUpdate;
 final VoidCallback onEditAll;
 final VoidCallback onUploadArtifact;
 final VoidCallback onClose;

 const _VerificationPopupDialog({
 required this.requirement,
 required this.ownerOptions,
 required this.onUpdate,
 required this.onEditAll,
 required this.onUploadArtifact,
 required this.onClose,
 });

 @override
 State<_VerificationPopupDialog> createState() =>
 _VerificationPopupDialogState();
}

class _VerificationPopupDialogState extends State<_VerificationPopupDialog> {
 late RequirementRow _current;
 late TextEditingController _reqIdController;
 late TextEditingController _titleController;
 late TextEditingController _definitionController;
 late TextEditingController _artifactLabelController;
 late TextEditingController _criteriaController;
 late TextEditingController _testMethodController;
 late TextEditingController _sourceDocController;
 late TextEditingController _artifactUrlController;

 @override
 void initState() {
 super.initState();
 _current = widget.requirement;
 _reqIdController = TextEditingController(text: _current.requirementId);
 _titleController = TextEditingController(text: _current.title);
 _definitionController = TextEditingController(text: _current.definition);
 _artifactLabelController =
 TextEditingController(text: _current.designArtifactLabel);
 _criteriaController =
 TextEditingController(text: _current.acceptanceCriteria);
 _testMethodController = TextEditingController(text: _current.testMethod);
 _sourceDocController =
 TextEditingController(text: _current.sourceDocument);
 _artifactUrlController =
 TextEditingController(text: _current.designArtifactUrl);
 }

 @override
 void dispose() {
 _reqIdController.dispose();
 _titleController.dispose();
 _definitionController.dispose();
 _artifactLabelController.dispose();
 _criteriaController.dispose();
 _testMethodController.dispose();
 _sourceDocController.dispose();
 _artifactUrlController.dispose();
 super.dispose();
 }

 void _update(RequirementRow updated) {
 setState(() => _current = updated);
 widget.onUpdate(updated);
 }

 @override
 Widget build(BuildContext context) {
 final isNarrow = MediaQuery.of(context).size.width < 700;

 return Dialog(
 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
 insetPadding: EdgeInsets.symmetric(
 horizontal: isNarrow ? 16 : 40,
 vertical: 24,
 ),
 child: ConstrainedBox(
 constraints: BoxConstraints(
 maxWidth: isNarrow ? double.infinity : 780,
 maxHeight: MediaQuery.of(context).size.height * 0.85,
 ),
 child: Column(
 mainAxisSize: MainAxisSize.min,
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 // Header
 Container(
 padding: const EdgeInsets.all(20),
 decoration: const BoxDecoration(
 color: Color(0xFFF8FAFC),
 borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
 ),
 child: Row(
 children: [
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 'Acceptance criteria & verification — ${_current.requirementId}',
 style: const TextStyle(
 fontSize: 16,
 fontWeight: FontWeight.w800,
 color: Color(0xFF111827),
 ),
 ),
 const SizedBox(height: 4),
 Text(
 _current.title,
 style: const TextStyle(
 fontSize: 12,
 fontWeight: FontWeight.w500,
 color: Color(0xFF6B7280),
 ),
 ),
 ],
 ),
 ),
 OutlinedButton.icon(
 onPressed: widget.onEditAll,
 icon: const Icon(Icons.edit_outlined, size: 16),
 label: const Text('Edit all fields',
 style: TextStyle(
 fontSize: 12, fontWeight: FontWeight.w600)),
 style: OutlinedButton.styleFrom(
 foregroundColor: const Color(0xFF475569),
 side: const BorderSide(color: Color(0xFFE2E8F0)),
 padding: const EdgeInsets.symmetric(
 horizontal: 14, vertical: 10),
 shape: RoundedRectangleBorder(
 borderRadius: BorderRadius.circular(12)),
 ),
 ),
 const SizedBox(width: 8),
 IconButton(
 onPressed: widget.onClose,
 icon: const Icon(Icons.close, size: 20),
 color: const Color(0xFF6B7280),
 padding: EdgeInsets.zero,
 constraints:
 const BoxConstraints(minWidth: 32, minHeight: 32),
 ),
 ],
 ),
 ),
 const Divider(height: 1, thickness: 1, color: Color(0xFFE5E7EB)),

 // Scrollable content
 Flexible(
 child: SingleChildScrollView(
 padding: const EdgeInsets.all(20),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 // Row 1: ID, Owner, Type
 _buildPopupRow(
 children: [
 _buildPopupField(
 label: 'Requirement ID',
 controller: _reqIdController,
 onChanged: (v) =>
 _update(_current.copyWith(requirementId: v)),
 ),
 _buildPopupDropdown(
 label: 'Owner',
 value: _current.owner,
 options: widget.ownerOptions,
 onChanged: (v) =>
 _update(_current.copyWith(owner: v)),
 ),
 _buildPopupDropdown(
 label: 'Requirement Type',
 value: _current.requirementType,
 options: const [
 'Functional',
 'Non-Functional',
 'Constraint',
 'Performance',
 'Security'
 ],
 onChanged: (v) =>
 _update(_current.copyWith(requirementType: v)),
 ),
 ],
 ),
 const SizedBox(height: 14),
 // Row 2: Source, Source Type, Validation
 _buildPopupRow(
 children: [
 _buildPopupDropdown(
 label: 'Source (Rule Type)',
 value: _current.ruleType,
 options: const ['Internal', 'External'],
 onChanged: (v) =>
 _update(_current.copyWith(ruleType: v)),
 ),
 _buildPopupDropdown(
 label: 'Source Type',
 value: _current.sourceType,
 options: const [
 'Contract',
 'Vendor',
 'Regulatory',
 'Standard',
 'Stakeholder',
 ],
 onChanged: (v) =>
 _update(_current.copyWith(sourceType: v)),
 ),
 _buildPopupDropdown(
 label: 'Validation Status',
 value: _current.validationStatus,
 options: const ['Mapped', 'Unmapped', 'In Review'],
 onChanged: (v) =>
 _update(_current.copyWith(validationStatus: v)),
 ),
 ],
 ),
 const SizedBox(height: 14),
 // Row 3: Description, Definition
 _buildPopupRow(
 children: [
 _buildPopupField(
 label: 'Description / Title',
 controller: _titleController,
 maxLines: 2,
 onChanged: (v) =>
 _update(_current.copyWith(title: v)),
 ),
 _buildPopupField(
 label: 'Definition / Intent',
 controller: _definitionController,
 maxLines: 2,
 onChanged: (v) =>
 _update(_current.copyWith(definition: v)),
 ),
 ],
 ),
 const SizedBox(height: 14),
 // Row 4: Design artifact fields
 _buildPopupRow(
 children: [
 _buildPopupDropdown(
 label: 'Design Artifact Type',
 value: _current.designArtifactType,
 options: const [
 'Figma',
 'PDF',
 'Confluence',
 'Jira',
 'Miro',
 'Spreadsheet',
 'Code',
 'Other',
 ],
 onChanged: (v) =>
 _update(_current.copyWith(designArtifactType: v)),
 ),
 _buildPopupField(
 label: 'Artifact Label',
 controller: _artifactLabelController,
 onChanged: (v) =>
 _update(_current.copyWith(designArtifactLabel: v)),
 ),
 ],
 ),
 const SizedBox(height: 14),
 // Row 5: Acceptance Criteria, Test Method
 _buildPopupRow(
 children: [
 _buildPopupField(
 label: 'Acceptance Criteria',
 controller: _criteriaController,
 maxLines: 2,
 onChanged: (v) =>
 _update(_current.copyWith(acceptanceCriteria: v)),
 ),
 _buildPopupField(
 label: 'Test Method',
 controller: _testMethodController,
 onChanged: (v) =>
 _update(_current.copyWith(testMethod: v)),
 ),
 ],
 ),
 const SizedBox(height: 14),
 // Row 6: Source Document, Artifact URL
 _buildPopupRow(
 children: [
 _buildPopupField(
 label: 'Source Document',
 controller: _sourceDocController,
 onChanged: (v) =>
 _update(_current.copyWith(sourceDocument: v)),
 ),
 Expanded(
 child: Row(
 children: [
 Expanded(
 child: _buildPopupField(
 label: 'Artifact URL',
 controller: _artifactUrlController,
 onChanged: (v) => _update(
 _current.copyWith(designArtifactUrl: v)),
 ),
 ),
 const SizedBox(width: 8),
 OutlinedButton.icon(
 onPressed: widget.onUploadArtifact,
 icon: const Icon(Icons.upload_file,
 size: 16, color: Color(0xFF64748B)),
 label: const Text('Upload'),
 style: OutlinedButton.styleFrom(
 foregroundColor: const Color(0xFF64748B),
 side: const BorderSide(
 color: Color(0xFFE2E8F0)),
 padding: const EdgeInsets.symmetric(
 horizontal: 10, vertical: 8),
 shape: RoundedRectangleBorder(
 borderRadius: BorderRadius.circular(8)),
 ),
 ),
 ],
 ),
 ),
 ],
 ),
 ],
 ),
 ),
 ),

 // Footer with close button
 const Divider(height: 1, thickness: 1, color: Color(0xFFE5E7EB)),
 Padding(
 padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
 child: Row(
 mainAxisAlignment: MainAxisAlignment.end,
 children: [
 TextButton(
 onPressed: widget.onClose,
 style: TextButton.styleFrom(
 foregroundColor: const Color(0xFF6B7280),
 ),
 child: const Text('Close'),
 ),
 ],
 ),
 ),
 ],
 ),
 ),
 );
 }

 Widget _buildPopupRow({required List<Widget> children}) {
 return Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: children
 .expand((w) => [Expanded(child: w), const SizedBox(width: 12)])
 .toList()
 ..removeLast(),
 );
 }

 Widget _buildPopupField({
 required String label,
 required TextEditingController controller,
 int maxLines = 1,
 required ValueChanged<String> onChanged,
 }) {
 return VoiceTextField(
 controller: controller,
 onChanged: onChanged,
 maxLines: maxLines,
 decoration: InputDecoration(
 labelText: label,
 border: const OutlineInputBorder(),
 isDense: true,
 ),
 );
 }

 Widget _buildPopupDropdown({
 required String label,
 required String value,
 required List<String> options,
 required ValueChanged<String> onChanged,
 }) {
 final effectiveOptions = <String>{...options, if (value.isNotEmpty) value}
 .toList()
 ..sort();
 return DropdownButtonFormField<String>(
 initialValue: effectiveOptions.contains(value) ? value : null,
 decoration: InputDecoration(
 labelText: label,
 border: const OutlineInputBorder(),
 isDense: true,
 ),
 items: effectiveOptions
 .map((v) => DropdownMenuItem(value: v, child: Text(v)))
 .toList(),
 onChanged: (v) {
 if (v != null) onChanged(v);
 },
 );
 }
}
