import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:ndu_project/models/project_data_model.dart';
import 'package:ndu_project/utils/planning_phase_navigation.dart';
import 'package:ndu_project/utils/project_data_helper.dart';
import 'package:ndu_project/utils/download_helper.dart' as download_helper;
import 'package:ndu_project/widgets/draggable_sidebar.dart';
import 'package:ndu_project/widgets/initiation_like_sidebar.dart';
import 'package:ndu_project/widgets/unified_phase_header.dart';
import 'package:ndu_project/widgets/planning_phase_header.dart';
import 'package:ndu_project/widgets/launch_phase_navigation.dart';
import 'package:ndu_project/widgets/launch_modal.dart';
import 'package:ndu_project/widgets/planning_ai_notes_card.dart';
import 'package:ndu_project/widgets/premium_edit_dialog.dart';
import 'package:ndu_project/widgets/responsive.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:ndu_project/widgets/voice_text_field.dart';
import 'package:ndu_project/utils/pdf_export_helper.dart';

class TeamTrainingAndBuildingScreen extends StatefulWidget {
 const TeamTrainingAndBuildingScreen({super.key});

 @override
 State<TeamTrainingAndBuildingScreen> createState() =>
 _TeamTrainingAndBuildingScreenState();
}

class _TeamTrainingAndBuildingScreenState
 extends State<TeamTrainingAndBuildingScreen> {
 final GlobalKey _onboardingSectionKey =
 GlobalKey(debugLabel: 'team_training_onboarding');
 final GlobalKey _disciplineSectionKey =
 GlobalKey(debugLabel: 'team_training_discipline');
 final GlobalKey _teamBuildingSectionKey =
 GlobalKey(debugLabel: 'team_training_team_building');

 late final List<_ResourceButtonSpec> _resourceButtons = [
 const _ResourceButtonSpec(
 id: 'welcome',
 label: 'Welcome',
 description:
 'Company and project introduction, location, hours, and first-week orientation.',
 category: 'Onboarding',
 defaultDuration: '30 mins',
 mandatory: true,
 icon: Icons.handshake_outlined,
 ),
 const _ResourceButtonSpec(
 id: 'project_onboarding',
 label: 'Project Onboarding',
 description:
 'Project summary, framework, goals, milestone windows, and core tools.',
 category: 'Onboarding',
 defaultDuration: '60 mins',
 mandatory: true,
 icon: Icons.auto_awesome,
 ),
 const _ResourceButtonSpec(
 id: 'team_vacation',
 label: 'Team & Vacation',
 description:
 'Role map, responsibilities, ownership handoff, and vacation coverage.',
 category: 'Onboarding',
 defaultDuration: '45 mins',
 mandatory: true,
 icon: Icons.group_outlined,
 ),
 const _ResourceButtonSpec(
 id: 'meetings',
 label: 'Meetings',
 description:
 'Core recurring ceremonies and cadence for planning, execution, and retros.',
 category: 'Discipline-Specific',
 defaultDuration: '15 mins daily',
 mandatory: true,
 icon: Icons.event_note_outlined,
 ),
 const _ResourceButtonSpec(
 id: 'trainings',
 label: 'Trainings',
 description:
 'Required discipline training plan with objective, owner, and verification.',
 category: 'Discipline-Specific',
 defaultDuration: '2 hours',
 mandatory: true,
 icon: Icons.school_outlined,
 ),
 const _ResourceButtonSpec(
 id: 'team_building',
 label: 'Team Building',
 description:
 'Collaboration rituals, ice breakers, recognition, and team cohesion actions.',
 category: 'Team Building',
 defaultDuration: '60 mins',
 mandatory: false,
 icon: Icons.favorite_outline,
 ),
 ];

 @override
 Widget build(BuildContext context) {
 final isMobile = AppBreakpoints.isMobile(context);
 final sidebarWidth = AppBreakpoints.sidebarWidth(context);

 final header = PlanningPhaseHeader(
 title: 'Training & Team Building',
 breadcrumbPhase: 'Planning Phase',
 breadcrumbTitle: 'Team Training',
 onBack: () =>
 PlanningPhaseNavigation.goToPrevious(context, 'team_training'),
 onForward: () =>
 PlanningPhaseNavigation.goToNext(context, 'team_training'), onExportPdf: _exportPdf);

 // --- Mobile layout ---
 if (isMobile) {
 return Scaffold(
 backgroundColor: Colors.grey[50],
 drawer: Drawer(
 width: sidebarWidth,
 child: SafeArea(
 child: InitiationLikeSidebar(
 activeItemLabel: 'Team Training and Team Building',
 showHeader: true,
 ),
 ),
 ),
 body: SafeArea(
 top: true,
 child: Column(
 children: [
 header,
 Expanded(child: _buildMain(context)),
 ],
 ),
 ),
 );
 }

 // --- Desktop layout ---
 return Scaffold(
 backgroundColor: Colors.grey[50],
 body: SafeArea(
 top: true,
 child: Column(
 children: [
 header,
 Expanded(
 child: Row(
 children: [
 DraggableSidebar(
 openWidth: sidebarWidth,
 child: const InitiationLikeSidebar(
 activeItemLabel: 'Team Training and Team Building'),
 ),
 Expanded(child: _buildMain(context)),
 ],
 ),
 ),
 ],
 ),
 ),
 );
 }

 Widget _buildMain(BuildContext context) {
 final data = ProjectDataHelper.getData(context);
 final onboardingActivities = data.trainingActivities
 .where((a) => _normalizeCategory(a.category) == 'Onboarding')
 .toList();
 final disciplineActivities = data.trainingActivities
 .where((a) => _normalizeCategory(a.category) == 'Discipline-Specific')
 .toList();
 final teamBuildingActivities = data.trainingActivities
 .where((a) => _normalizeCategory(a.category) == 'Team Building')
 .toList();

 return SingleChildScrollView(
 child: Padding(
 padding: const EdgeInsets.fromLTRB(32, 24, 32, 32),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 children: [
 const Spacer(),
 _yellowButton(
 label: 'Onboarding Template',
 icon: Icons.auto_awesome,
 onPressed: () => _addOnboardingTemplate(context),
 ),
 ],
 ),
 const SizedBox(height: 12),
 const Padding(
 padding: EdgeInsets.only(left: 6.0),
 child: Text(
 'Identify team training opportunities and team building intervals',
 style: TextStyle(fontSize: 16, color: Colors.black87),
 ),
 ),
 const SizedBox(height: 16),
 const PlanningAiNotesCard(
 title: 'Notes',
 sectionLabel: 'Team Training and Team Building',
 noteKey: 'planning_team_training_notes',
 checkpoint: 'team_training',
 description:
 'Outline training themes, cadence, and team-building priorities.',
 ),
 const SizedBox(height: 16),
 _buildTopButtonRow(context),
 const SizedBox(height: 24),
 Container(
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(12),
 border: Border.all(color: Colors.grey.withOpacity(0.25)),
 boxShadow: [
 BoxShadow(
 color: Colors.black.withOpacity(0.05),
 blurRadius: 10,
 offset: const Offset(0, 2),
 )
 ],
 ),
 padding: const EdgeInsets.all(16),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 const Text('Team Development Overview',
 style:
 TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
 const SizedBox(height: 6),
 Text(
 'Templates above map into these three sections. Uploads are stored and downloadable, and each activity can be marked read/completed.',
 style: TextStyle(fontSize: 13, color: Colors.grey[700]),
 ),
 const SizedBox(height: 16),
 LayoutBuilder(
 builder: (context, constraints) {
 final compact = constraints.maxWidth < 1120;
 final onboardingSection = _buildOverviewSectionCard(
 context: context,
 sectionKey: _onboardingSectionKey,
 title: 'Onboarding',
 subtitle:
 'Mandatory steps to integrate new project members.',
 addLabel: 'Add Onboarding',
 addIcon: Icons.checklist_rtl,
 activities: onboardingActivities,
 accent: Colors.green,
 onAdd: () => _addActivity(
 context,
 title: 'New Onboarding',
 category: 'Onboarding',
 mandatory: true,
 ),
 );
 final disciplineSection = _buildOverviewSectionCard(
 context: context,
 sectionKey: _disciplineSectionKey,
 title: 'Discipline-Specific',
 subtitle:
 'Technical training tailored to specific roles and tasks.',
 addLabel: 'Add Discipline Training',
 addIcon: Icons.school_outlined,
 activities: disciplineActivities,
 accent: Colors.blue,
 onAdd: () => _addActivity(
 context,
 title: 'New Training',
 category: 'Discipline-Specific',
 ),
 );
 final teamBuildingSection = _buildOverviewSectionCard(
 context: context,
 sectionKey: _teamBuildingSectionKey,
 title: 'Team Building',
 subtitle:
 'Strengthen relationships and improve communication.',
 addLabel: 'Add Team Building',
 addIcon: Icons.favorite_outline,
 activities: teamBuildingActivities,
 accent: Colors.purple,
 heart: true,
 onAdd: () => _addActivity(
 context,
 title: 'New Event',
 category: 'Team Building',
 ),
 );

 if (compact) {
 return Column(
 children: [
 onboardingSection,
 const SizedBox(height: 16),
 disciplineSection,
 const SizedBox(height: 16),
 teamBuildingSection,
 ],
 );
 }

 return Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Expanded(child: onboardingSection),
 const SizedBox(width: 16),
 Expanded(child: disciplineSection),
 const SizedBox(width: 16),
 Expanded(child: teamBuildingSection),
 ],
 );
 },
 ),
 ],
 ),
 ),
 const SizedBox(height: 16),
 Row(
 children: const [
 Expanded(
 child: _BenefitCard(
 icon: Icons.lightbulb_outline,
 title: 'Skill Development',
 subtitle:
 'Enhance technical and soft skills through structured learning',
 ),
 ),
 SizedBox(width: 12),
 Expanded(
 child: _BenefitCard(
 icon: Icons.favorite_border,
 title: 'Team Cohesion',
 subtitle: 'Build stronger relationships and mutual trust',
 ),
 ),
 SizedBox(width: 12),
 Expanded(
 child: _BenefitCard(
 icon: Icons.speed_outlined,
 title: 'Improved Performance',
 subtitle: 'Boost productivity and quality of deliverables',
 ),
 ),
 SizedBox(width: 12),
 Expanded(
 child: _BenefitCard(
 icon: Icons.auto_awesome_outlined,
 title: 'Innovation',
 subtitle:
 'Improve delivery through practical learning and feedback',
 ),
 ),
 ],
 ),
 const SizedBox(height: 24),
 LaunchPhaseNavigation(
 backLabel: PlanningPhaseNavigation.backLabel('team_training'),
 nextLabel: PlanningPhaseNavigation.nextLabel('team_training'),
 onBack: () => PlanningPhaseNavigation.goToPrevious(
 context, 'team_training'),
 onNext: () =>
 PlanningPhaseNavigation.goToNext(context, 'team_training'),
 ),
 const SizedBox(height: 40),
 ],
 ),
 ),
 );
 }

 Widget _buildOverviewSectionCard({
 required BuildContext context,
 required GlobalKey sectionKey,
 required String title,
 required String subtitle,
 required String addLabel,
 required IconData addIcon,
 required List<TrainingActivity> activities,
 required Color accent,
 required VoidCallback onAdd,
 bool heart = false,
 }) {
 return Container(
 key: sectionKey,
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 children: [
 Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
 const SizedBox(width: 12),
 _yellowButton(
 label: addLabel,
 icon: addIcon,
 onPressed: onAdd,
 ),
 ],
 ),
 const SizedBox(height: 4),
 Text(
 subtitle,
 style: TextStyle(fontSize: 12, color: Colors.grey[700]),
 ),
 const SizedBox(height: 12),
 _UpcomingTrainingList(
 activities: activities,
 accent: accent,
 heart: heart,
 onDownload: (activity) => _downloadAttachment(
 context,
 activity.attachedFileUrl,
 ),
 onEdit: (activity) => _editActivity(context, activity),
 onDelete: (activity) => _deleteActivity(context, activity),
 ),
 ],
 ),
 );
 }

 Widget _buildTopButtonRow(BuildContext context) {
 return Wrap(
 spacing: 12,
 runSpacing: 12,
 children: _resourceButtons.map((b) => _topButton(context, b)).toList(),
 );
 }

 Widget _topButton(BuildContext context, _ResourceButtonSpec spec) {
 return InkWell(
 onTap: () => _showResourceDialog(context, spec),
 borderRadius: BorderRadius.circular(12),
 child: Container(
 width: 146,
 padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
 decoration: BoxDecoration(
 color: const Color(0xFF1F2933),
 borderRadius: BorderRadius.circular(12),
 boxShadow: [
 BoxShadow(
 color: Colors.black.withOpacity(0.1),
 blurRadius: 4,
 offset: const Offset(0, 2),
 )
 ],
 ),
 child: Column(
 children: [
 Icon(spec.icon, size: 18, color: Colors.white),
 const SizedBox(height: 8),
 Text(
 spec.label,
 textAlign: TextAlign.center,
 style: const TextStyle(
 color: Colors.white,
 fontWeight: FontWeight.w700,
 fontSize: 14,
 ),
 ),
 ],
 ),
 ),
 );
 }

 Future<void> _addActivity(
 BuildContext context, {
 required String title,
 required String category,
 bool mandatory = false,
 }) async {
 final data = ProjectDataHelper.getData(context);
 final newActivity = TrainingActivity(
 title: title,
 category: category,
 isMandatory: mandatory,
 );
 final updated = [...data.trainingActivities, newActivity];
 await _saveActivities(context, updated);
 }

 Future<void> _saveActivities(
 BuildContext context, List<TrainingActivity> updated) async {
 await ProjectDataHelper.saveAndNavigate(
 context: context,
 checkpoint: 'team_training',
 saveInBackground: true,
 nextScreenBuilder: () => const TeamTrainingAndBuildingScreen(),
 dataUpdater: (d) => d.copyWith(trainingActivities: updated),
 );
 }

 Future<void> _saveActivitiesSilently(
 BuildContext context, List<TrainingActivity> updated) async {
 await ProjectDataHelper.updateAndSave(
 context: context,
 checkpoint: 'team_training',
 dataUpdater: (d) => d.copyWith(trainingActivities: updated),
 showSnackbar: false,
 );
 }

 bool _activityMatchesDraft(TrainingActivity current, TrainingActivity draft) {
 return current.title == draft.title &&
 current.description == draft.description &&
 current.date == draft.date &&
 current.duration == draft.duration &&
 _normalizeCategory(current.category) ==
 _normalizeCategory(draft.category) &&
 current.status == draft.status &&
 current.isMandatory == draft.isMandatory &&
 current.attachedFile == draft.attachedFile &&
 current.attachedFileUrl == draft.attachedFileUrl &&
 current.attachedFileStoragePath == draft.attachedFileStoragePath &&
 current.isCompleted == draft.isCompleted;
 }

 Future<void> _persistActivityDraft(
 BuildContext context, TrainingActivity draft) async {
 final updated = List<TrainingActivity>.from(
 ProjectDataHelper.getProvider(context).projectData.trainingActivities,
 );
 final index = updated.indexWhere((a) => a.id == draft.id);
 if (index == -1) return;
 if (_activityMatchesDraft(updated[index], draft)) return;
 updated[index] = draft;
 await _saveActivitiesSilently(context, updated);
 }

 String _templateDraftNoteKey(String templateId) =>
 'team_training_template_$templateId';

 String _templateTextForButton(
 _ResourceButtonSpec spec, ProjectDataModel data) {
 final saved = data.planningNotes[_templateDraftNoteKey(spec.id)]?.trim();
 if (saved != null && saved.isNotEmpty) {
 return saved;
 }
 return _buildTemplateForButton(spec, data);
 }

 Future<void> _persistTemplateDraft(
 BuildContext context, {
 required _ResourceButtonSpec spec,
 required String templateText,
 }) async {
 final nextValue = templateText.trim();
 final noteKey = _templateDraftNoteKey(spec.id);
 final currentValue =
 (ProjectDataHelper.getData(context).planningNotes[noteKey] ?? '')
 .trim();
 if (currentValue == nextValue) return;

 await ProjectDataHelper.updateAndSave(
 context: context,
 checkpoint: 'team_training',
 showSnackbar: false,
 dataUpdater: (data) {
 final notes = Map<String, String>.from(data.planningNotes);
 final generatedDefault = _buildTemplateForButton(spec, data).trim();
 if (nextValue.isEmpty || nextValue == generatedDefault) {
 notes.remove(noteKey);
 } else {
 notes[noteKey] = nextValue;
 }
 return data.copyWith(planningNotes: notes);
 },
 );
 }

 Future<void> _editActivity(
 BuildContext context, TrainingActivity activity) async {
 final rootContext = context;
 final titleController = TextEditingController(text: activity.title);
 final descriptionController =
 TextEditingController(text: activity.description);
 final dateController = TextEditingController(text: activity.date);
 final durationController = TextEditingController(text: activity.duration);

 bool isMandatory = activity.isMandatory;
 bool isCompleted = activity.isCompleted;
 String category = _normalizeCategory(activity.category);
 String? attachedFile = activity.attachedFile;
 String? attachedFileUrl = activity.attachedFileUrl;
 String? attachedFileStoragePath = activity.attachedFileStoragePath;
 String? selectedExistingDocUrl = attachedFileUrl;
 final manualUrlController =
 TextEditingController(text: attachedFileUrl ?? '');
 bool uploading = false;
 var latestAutoSaveToken = 0;
 Timer? autoSaveDebounce;
 var didExplicitSave = false;

 TrainingActivity buildDraft() {
 final manualUrl = manualUrlController.text.trim();
 return TrainingActivity(
 id: activity.id,
 title: titleController.text.trim(),
 description: descriptionController.text.trim(),
 date: dateController.text.trim(),
 duration: durationController.text.trim(),
 category: _normalizeCategory(category),
 status: activity.status,
 isMandatory: isMandatory,
 attachedFile: attachedFile ??
 (manualUrl.isNotEmpty ? _baseName(manualUrl) : null),
 attachedFileUrl: manualUrl.isNotEmpty ? manualUrl : attachedFileUrl,
 attachedFileStoragePath: attachedFileStoragePath,
 isCompleted: isCompleted,
 );
 }

 void scheduleAutoSave() {
 autoSaveDebounce?.cancel();
 final token = ++latestAutoSaveToken;
 autoSaveDebounce = Timer(const Duration(milliseconds: 700), () async {
 if (!rootContext.mounted) return;
 await _persistActivityDraft(rootContext, buildDraft());
 if (token != latestAutoSaveToken) return;
 });
 }

 for (final controller in [
 titleController,
 descriptionController,
 dateController,
 durationController,
 manualUrlController,
 ]) {
 controller.addListener(scheduleAutoSave);
 }

 await showDialog(
 context: rootContext,
 builder: (dialogContext) => StatefulBuilder(
 builder: (context, setDialogState) {
 final existingDocs = _sectionDocuments(
 rootContext,
 category: category,
 excludeActivityId: activity.id,
 );

 return PremiumEditDialog(
 title: 'Edit Activity',
 icon: category == 'Onboarding'
 ? Icons.checklist_rtl
 : category == 'Team Building'
 ? Icons.favorite_border
 : Icons.school_outlined,
 onSave: () async {
 didExplicitSave = true;
 final updated = List<TrainingActivity>.from(
 ProjectDataHelper.getProvider(rootContext)
 .projectData
 .trainingActivities,
 );
 final index = updated.indexWhere((a) => a.id == activity.id);
 if (index != -1) {
 updated[index] = buildDraft();
 }
 autoSaveDebounce?.cancel();
 Navigator.pop(dialogContext);
 await _saveActivities(rootContext, updated);
 },
 children: [
 PremiumEditDialog.fieldLabel('Title'),
 PremiumEditDialog.textField(
 controller: titleController,
 hint: 'Activity name...',
 ),
 const SizedBox(height: 16),
 PremiumEditDialog.fieldLabel('Template / Notes'),
 VoiceTextField(
 controller: descriptionController,
 maxLines: 8,
 decoration: InputDecoration(
 hintText:
 'Store onboarding/training notes, plan details, or checklist.',
 filled: true,
 fillColor: Colors.grey[50],
 border: OutlineInputBorder(
 borderRadius: BorderRadius.circular(12),
 borderSide: BorderSide.none,
 ),
 ),
 ),
 const SizedBox(height: 8),
 Align(
 alignment: Alignment.centerLeft,
 child: OutlinedButton.icon(
 onPressed: () => _downloadTemplatePdf(
 rootContext,
 title: titleController.text.trim().isEmpty
 ? 'training_template'
 : titleController.text.trim(),
 category: category,
 templateText: descriptionController.text.trim(),
 ),
 icon: const Icon(Icons.picture_as_pdf_outlined, size: 16),
 label: const Text('Download Template PDF'),
 ),
 ),
 const SizedBox(height: 16),
 PremiumEditDialog.fieldLabel('Category'),
 DropdownButtonFormField<String>(
 value: category,
 items: const [
 DropdownMenuItem(
 value: 'Onboarding', child: Text('Onboarding')),
 DropdownMenuItem(
 value: 'Discipline-Specific',
 child: Text('Discipline-Specific'),
 ),
 DropdownMenuItem(
 value: 'Team Building',
 child: Text('Team Building'),
 ),
 ],
 onChanged: (v) {
 if (v == null) return;
 setDialogState(() {
 category = v;
 selectedExistingDocUrl = null;
 scheduleAutoSave();
 });
 },
 decoration: InputDecoration(
 filled: true,
 fillColor: Colors.grey[50],
 border: OutlineInputBorder(
 borderRadius: BorderRadius.circular(12),
 borderSide: BorderSide.none,
 ),
 ),
 ),
 const SizedBox(height: 16),
 CheckboxListTile(
 title: const Text(
 'Mandatory Requirement',
 style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
 ),
 value: isMandatory,
 onChanged: (v) => setDialogState(() {
 isMandatory = v ?? false;
 scheduleAutoSave();
 }),
 contentPadding: EdgeInsets.zero,
 controlAffinity: ListTileControlAffinity.leading,
 ),
 CheckboxListTile(
 title: const Text(
 'Completed / Read',
 style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
 ),
 value: isCompleted,
 onChanged: (v) => setDialogState(() {
 isCompleted = v ?? false;
 scheduleAutoSave();
 }),
 contentPadding: EdgeInsets.zero,
 controlAffinity: ListTileControlAffinity.leading,
 ),
 const SizedBox(height: 16),
 PremiumEditDialog.fieldLabel('Attachment'),
 if (attachedFile != null)
 Container(
 margin: const EdgeInsets.only(bottom: 10),
 padding:
 const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
 decoration: BoxDecoration(
 color: Colors.blue[50],
 borderRadius: BorderRadius.circular(8),
 border: Border.all(color: Colors.blue[100]!),
 ),
 child: Row(
 children: [
 const Icon(Icons.attach_file,
 size: 16, color: Colors.blue),
 const SizedBox(width: 8),
 Expanded(
 child: Text(
 _baseName(attachedFile!),
 maxLines: 1,
 overflow: TextOverflow.ellipsis,
 style:
 TextStyle(color: Colors.blue[900], fontSize: 13),
 ),
 ),
 if ((attachedFileUrl ?? '').trim().isNotEmpty)
 IconButton(
 tooltip: 'Download',
 onPressed: () =>
 _downloadAttachment(rootContext, attachedFileUrl),
 icon: const Icon(Icons.download_outlined,
 size: 18, color: Colors.blue),
 ),
 IconButton(
 tooltip: 'Remove attachment',
 onPressed: () => setDialogState(() {
 attachedFile = null;
 attachedFileUrl = null;
 attachedFileStoragePath = null;
 selectedExistingDocUrl = null;
 manualUrlController.text = '';
 scheduleAutoSave();
 }),
 icon: const Icon(Icons.close,
 size: 16, color: Colors.blue),
 ),
 ],
 ),
 ),
 Row(
 children: [
 ElevatedButton.icon(
 onPressed: uploading
 ? null
 : () async {
 setDialogState(() => uploading = true);
 final uploaded = await _pickAndUploadAttachment(
 rootContext,
 folder: 'team_training',
 );
 if (!dialogContext.mounted) return;
 setDialogState(() {
 uploading = false;
 if (uploaded != null) {
 attachedFile = uploaded.name;
 attachedFileUrl = uploaded.url;
 attachedFileStoragePath = uploaded.storagePath;
 selectedExistingDocUrl = uploaded.url;
 manualUrlController.text = uploaded.url;
 }
 scheduleAutoSave();
 });
 },
 icon: uploading
 ? const SizedBox(
 width: 16,
 height: 16,
 child: CircularProgressIndicator(strokeWidth: 2),
 )
 : const Icon(Icons.upload_file, size: 16),
 label: Text(uploading ? 'Uploading...' : 'Upload'),
 style: ElevatedButton.styleFrom(
 elevation: 0,
 backgroundColor: Colors.grey[100],
 foregroundColor: Colors.black,
 ),
 ),
 const SizedBox(width: 8),
 if ((attachedFileUrl ?? '').trim().isNotEmpty)
 OutlinedButton.icon(
 onPressed: () =>
 _downloadAttachment(rootContext, attachedFileUrl),
 icon: const Icon(Icons.download_outlined, size: 16),
 label: const Text('Download'),
 ),
 ],
 ),
 if (existingDocs.isNotEmpty) ...[
 const SizedBox(height: 10),
 DropdownButtonFormField<String>(
 value: selectedExistingDocUrl != null &&
 existingDocs
 .any((doc) => doc.url == selectedExistingDocUrl)
 ? selectedExistingDocUrl
 : null,
 items: existingDocs
 .map(
 (doc) => DropdownMenuItem(
 value: doc.url,
 child: Text(
 doc.name,
 overflow: TextOverflow.ellipsis,
 ),
 ),
 )
 .toList(),
 onChanged: (v) {
 if (v == null) return;
 final doc = existingDocs.firstWhere((d) => d.url == v);
 setDialogState(() {
 selectedExistingDocUrl = v;
 attachedFile = doc.name;
 attachedFileUrl = doc.url;
 attachedFileStoragePath = doc.storagePath;
 manualUrlController.text = doc.url;
 scheduleAutoSave();
 });
 },
 decoration: InputDecoration(
 labelText: 'Select Existing Document In This Section',
 filled: true,
 fillColor: Colors.grey[50],
 border: OutlineInputBorder(
 borderRadius: BorderRadius.circular(12),
 borderSide: BorderSide.none,
 ),
 ),
 ),
 ],
 const SizedBox(height: 10),
 VoiceTextField(
 controller: manualUrlController,
 decoration: InputDecoration(
 labelText: 'Or Paste Existing Download URL',
 hintText:
 'https://firebasestorage.googleapis.com/... (fallback if browser upload is blocked)',
 filled: true,
 fillColor: Colors.grey[50],
 border: OutlineInputBorder(
 borderRadius: BorderRadius.circular(12),
 borderSide: BorderSide.none,
 ),
 ),
 ),
 const SizedBox(height: 16),
 Row(
 children: [
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 PremiumEditDialog.fieldLabel('Date'),
 PremiumEditDialog.textField(
 controller: dateController,
 hint: 'e.g. Q3 2026',
 ),
 ],
 ),
 ),
 const SizedBox(width: 16),
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 PremiumEditDialog.fieldLabel('Duration / Interval'),
 PremiumEditDialog.textField(
 controller: durationController,
 hint: 'e.g. 2 hours',
 ),
 ],
 ),
 ),
 ],
 ),
 ],
 );
 },
 ),
 );

 autoSaveDebounce?.cancel();
 if (!didExplicitSave && rootContext.mounted) {
 await _persistActivityDraft(rootContext, buildDraft());
 }
 titleController.dispose();
 descriptionController.dispose();
 dateController.dispose();
 durationController.dispose();
 manualUrlController.dispose();
 }

 Future<void> _showResourceDialog(
 BuildContext context, _ResourceButtonSpec spec) async {
 final rootContext = context;
 final data = ProjectDataHelper.getData(rootContext);
 final initialTemplateText = _templateTextForButton(spec, data).trim();
 final templateController = TextEditingController(text: initialTemplateText);
 final titleController = TextEditingController(text: '${spec.label} Plan');
 final dateController = TextEditingController();
 final durationController =
 TextEditingController(text: spec.defaultDuration);

 String category = spec.category;
 bool confirmedRead = false;
 bool mandatory = spec.mandatory;
 String? attachedFile;
 String? attachedFileUrl;
 String? attachedFileStoragePath;
 String? selectedExistingDocUrl;
 final manualUrlController = TextEditingController();
 bool uploading = false;

 await showDialog(
 context: rootContext,
 barrierDismissible: true,
 builder: (dialogContext) => StatefulBuilder(
 builder: (context, setDialogState) {
 final existingDocs =
 _sectionDocuments(rootContext, category: category);

 return LaunchModalShell(
 icon: spec.icon,
 accent: const Color(0xFFFFC107),
 title: spec.label,
 subtitle: spec.description,
 body: Column(
 mainAxisSize: MainAxisSize.min,
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 LaunchModalTextField(
 label: 'Activity Title',
 controller: titleController,
 hint: 'e.g. Onboarding session 1',
 ),
 const SizedBox(height: 12),
 LaunchModalDropdown<String>(
 label: 'Link To Section',
 value: category,
 items: const ['Onboarding', 'Discipline-Specific', 'Team Building'],
 onChanged: (v) {
 if (v == null) return;
 setDialogState(() {
 category = v;
 selectedExistingDocUrl = null;
 });
 },
 ),
 const SizedBox(height: 12),
 Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 mainAxisSize: MainAxisSize.min,
 children: [
 const LaunchModalLabel('Template (Editable)'),
 const SizedBox(height: 4),
 VoiceTextField(
 controller: templateController,
 maxLines: 14,
 enableDocxImport: false,
 decoration: const InputDecoration(
 hintText: 'Edit the activity template text…',
 isDense: true,
 filled: true,
 fillColor: Colors.white,
 contentPadding: EdgeInsets.symmetric(
 horizontal: 12, vertical: 11),
 border: OutlineInputBorder(
 borderRadius: BorderRadius.all(Radius.circular(8)),
 borderSide: BorderSide(color: Color(0xFFE4E7EC), width: 1),
 ),
 enabledBorder: OutlineInputBorder(
 borderRadius: BorderRadius.all(Radius.circular(8)),
 borderSide: BorderSide(color: Color(0xFFE4E7EC), width: 1),
 ),
 focusedBorder: OutlineInputBorder(
 borderRadius: BorderRadius.all(Radius.circular(8)),
 borderSide:
 BorderSide(color: Color(0xFFFFC107), width: 1.6),
 ),
 ),
 ),
 ],
 ),
 const SizedBox(height: 8),
 Align(
 alignment: Alignment.centerLeft,
 child: OutlinedButton.icon(
 onPressed: () => _downloadTemplatePdf(
 rootContext,
 title: titleController.text.trim().isEmpty
 ? spec.label
 : titleController.text.trim(),
 category: category,
 templateText: templateController.text.trim(),
 ),
 icon:
 const Icon(Icons.picture_as_pdf_outlined, size: 16),
 label: const Text('Download Template PDF'),
 ),
 ),
 const SizedBox(height: 14),
 const LaunchModalLabel('Resource File'),
 const SizedBox(height: 8),
 if (attachedFile != null)
 Container(
 margin: const EdgeInsets.only(bottom: 10),
 padding: const EdgeInsets.symmetric(
 horizontal: 10, vertical: 10),
 decoration: BoxDecoration(
 color: const Color(0xFFEFF6FF),
 borderRadius: BorderRadius.circular(8),
 border: Border.all(color: const Color(0xFFBFDBFE)),
 ),
 child: Row(
 children: [
 const Icon(Icons.attach_file,
 size: 16, color: Color(0xFF2563EB)),
 const SizedBox(width: 8),
 Expanded(
 child: Text(
 _baseName(attachedFile!),
 overflow: TextOverflow.ellipsis,
 style: const TextStyle(
 color: Color(0xFF1E3A8A), fontSize: 13),
 ),
 ),
 if ((attachedFileUrl ?? '').trim().isNotEmpty)
 IconButton(
 tooltip: 'Download',
 onPressed: () => _downloadAttachment(
 rootContext, attachedFileUrl),
 icon: const Icon(Icons.download_outlined,
 size: 18, color: Color(0xFF2563EB)),
 ),
 IconButton(
 tooltip: 'Remove',
 onPressed: () => setDialogState(() {
 attachedFile = null;
 attachedFileUrl = null;
 attachedFileStoragePath = null;
 selectedExistingDocUrl = null;
 manualUrlController.text = '';
 }),
 icon: const Icon(Icons.close,
 size: 16, color: Color(0xFF2563EB)),
 ),
 ],
 ),
 ),
 Row(
 children: [
 ElevatedButton.icon(
 onPressed: uploading
 ? null
 : () async {
 setDialogState(() => uploading = true);
 final uploaded =
 await _pickAndUploadAttachment(
 rootContext,
 folder: 'team_training',
 );
 if (!dialogContext.mounted) return;
 setDialogState(() {
 uploading = false;
 if (uploaded != null) {
 attachedFile = uploaded.name;
 attachedFileUrl = uploaded.url;
 attachedFileStoragePath =
 uploaded.storagePath;
 selectedExistingDocUrl = uploaded.url;
 manualUrlController.text = uploaded.url;
 }
 });
 },
 icon: uploading
 ? const SizedBox(
 width: 16,
 height: 16,
 child:
 CircularProgressIndicator(strokeWidth: 2),
 )
 : const Icon(Icons.upload_file, size: 16),
 label: Text(uploading ? 'Uploading...' : 'Upload'),
 style: ElevatedButton.styleFrom(elevation: 0),
 ),
 const SizedBox(width: 8),
 if ((attachedFileUrl ?? '').trim().isNotEmpty)
 OutlinedButton.icon(
 onPressed: () => _downloadAttachment(
 rootContext, attachedFileUrl),
 icon: const Icon(Icons.download_outlined, size: 16),
 label: const Text('Download'),
 ),
 ],
 ),
 if (existingDocs.isNotEmpty) ...[
 const SizedBox(height: 10),
 DropdownButtonFormField<String>(
 value: selectedExistingDocUrl != null &&
 existingDocs.any(
 (doc) => doc.url == selectedExistingDocUrl)
 ? selectedExistingDocUrl
 : null,
 items: existingDocs
 .map(
 (doc) => DropdownMenuItem(
 value: doc.url,
 child: Text(
 doc.name,
 overflow: TextOverflow.ellipsis,
 ),
 ),
 )
 .toList(),
 onChanged: (v) {
 if (v == null) return;
 final doc =
 existingDocs.firstWhere((d) => d.url == v);
 setDialogState(() {
 selectedExistingDocUrl = v;
 attachedFile = doc.name;
 attachedFileUrl = doc.url;
 attachedFileStoragePath = doc.storagePath;
 manualUrlController.text = doc.url;
 });
 },
 decoration: const InputDecoration(
 labelText: 'Select Existing Document In This Section',
 isDense: true,
 filled: true,
 fillColor: Colors.white,
 contentPadding: EdgeInsets.symmetric(
 horizontal: 12, vertical: 11),
 border: OutlineInputBorder(
 borderRadius: BorderRadius.all(Radius.circular(8)),
 borderSide: BorderSide(color: Color(0xFFE4E7EC), width: 1),
 ),
 enabledBorder: OutlineInputBorder(
 borderRadius: BorderRadius.all(Radius.circular(8)),
 borderSide: BorderSide(color: Color(0xFFE4E7EC), width: 1),
 ),
 focusedBorder: OutlineInputBorder(
 borderRadius: BorderRadius.all(Radius.circular(8)),
 borderSide:
 BorderSide(color: Color(0xFFFFC107), width: 1.6),
 ),
 ),
 ),
 ],
 const SizedBox(height: 10),
 LaunchModalTextField(
 label: 'Or Paste Existing Download URL',
 controller: manualUrlController,
 hint:
 'https://firebasestorage.googleapis.com/… (fallback if browser upload is blocked)',
 ),
 const SizedBox(height: 12),
 Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Expanded(
 child: LaunchModalTextField(
 label: 'Date',
 controller: dateController,
 hint: 'e.g. Weekly / Q2 2026',
 ),
 ),
 const SizedBox(width: 10),
 Expanded(
 child: LaunchModalTextField(
 label: 'Duration / Interval',
 controller: durationController,
 hint: 'e.g. 60 mins',
 ),
 ),
 ],
 ),
 const SizedBox(height: 10),
 CheckboxListTile(
 value: mandatory,
 onChanged: (v) =>
 setDialogState(() => mandatory = v == true),
 title: const Text('Mandatory Requirement'),
 contentPadding: EdgeInsets.zero,
 controlAffinity: ListTileControlAffinity.leading,
 ),
 CheckboxListTile(
 value: confirmedRead,
 onChanged: (v) =>
 setDialogState(() => confirmedRead = v == true),
 title: const Text('Confirm Read / Completed'),
 contentPadding: EdgeInsets.zero,
 controlAffinity: ListTileControlAffinity.leading,
 ),
 ],
 ),
 actions: [
 LaunchModalCancelButton(
 label: 'Close',
 onPressed: () => Navigator.pop(dialogContext),
 ),
 OutlinedButton(
 onPressed: () => _downloadTemplatePdf(
 rootContext,
 title: titleController.text.trim().isEmpty
 ? spec.label
 : titleController.text.trim(),
 category: category,
 templateText: templateController.text.trim(),
 ),
 style: OutlinedButton.styleFrom(
 foregroundColor: const Color(0xFF6B7280),
 side: const BorderSide(color: Color(0xFFE4E7EC)),
 padding:
 const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
 shape: RoundedRectangleBorder(
 borderRadius: BorderRadius.circular(8)),
 ),
 child: const Text('Template PDF',
 style: TextStyle(
 fontSize: 13, fontWeight: FontWeight.w600)),
 ),
 OutlinedButton(
 onPressed: () {
 Navigator.pop(dialogContext);
 _scrollToSection(category);
 },
 style: OutlinedButton.styleFrom(
 foregroundColor: const Color(0xFF6B7280),
 side: const BorderSide(color: Color(0xFFE4E7EC)),
 padding:
 const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
 shape: RoundedRectangleBorder(
 borderRadius: BorderRadius.circular(8)),
 ),
 child: const Text('Go To Section',
 style: TextStyle(
 fontSize: 13, fontWeight: FontWeight.w600)),
 ),
 LaunchModalPrimaryButton(
 label: 'Link to Overview',
 icon: Icons.link_rounded,
 onPressed: () async {
 final manualUrl = manualUrlController.text.trim();
 final title = titleController.text.trim().isEmpty
 ? spec.label
 : titleController.text.trim();
 final newActivity = TrainingActivity(
 title: title,
 description: templateController.text.trim(),
 category: _normalizeCategory(category),
 date: dateController.text.trim(),
 duration: durationController.text.trim(),
 attachedFile: attachedFile ??
 (manualUrl.isNotEmpty ? _baseName(manualUrl) : null),
 attachedFileUrl:
 manualUrl.isNotEmpty ? manualUrl : attachedFileUrl,
 attachedFileStoragePath: attachedFileStoragePath,
 isCompleted: confirmedRead,
 isMandatory: mandatory,
 );

 final updated = List<TrainingActivity>.from(
 ProjectDataHelper.getProvider(rootContext)
 .projectData
 .trainingActivities,
 )..add(newActivity);

 Navigator.pop(dialogContext);
 await _saveActivities(rootContext, updated);
 },
 ),
 ],
 );
 },
 ),
 );

 if (rootContext.mounted &&
 templateController.text.trim() != initialTemplateText) {
 await _persistTemplateDraft(
 rootContext,
 spec: spec,
 templateText: templateController.text,
 );
 }

 templateController.dispose();
 titleController.dispose();
 dateController.dispose();
 durationController.dispose();
 manualUrlController.dispose();
 }

 Future<_UploadedDoc?> _pickAndUploadAttachment(
 BuildContext context, {
 required String folder,
 }) async {
 final messenger = ScaffoldMessenger.of(context);
 final currentUser = FirebaseAuth.instance.currentUser;
 if (currentUser == null) {
 if (!context.mounted) return null;
 messenger.showSnackBar(
 const SnackBar(
 content: Text('Sign in is required before uploading attachments.'),
 ),
 );
 return null;
 }

 final projectId = ProjectDataHelper.getData(context).projectId;
 if (projectId == null || projectId.isEmpty) {
 if (!context.mounted) return null;
 messenger.showSnackBar(
 const SnackBar(
 content: Text('Select a project before uploading files.')),
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
 if (!context.mounted) return null;
 if (result == null || result.files.isEmpty) return null;

 final file = result.files.first;
 final Uint8List? bytes = file.bytes;
 if (bytes == null) {
 if (!context.mounted) return null;
 messenger.showSnackBar(
 const SnackBar(content: Text('Unable to read file bytes.')),
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
 );
 } on FirebaseException catch (error) {
 if (!context.mounted) return null;
 _showStorageUploadError(context, error.toString());
 return null;
 } catch (error) {
 if (!context.mounted) return null;
 _showStorageUploadError(context, error.toString());
 return null;
 }
 }

 Future<void> _downloadAttachment(BuildContext context, String? url) async {
 final messenger = ScaffoldMessenger.of(context);
 final cleanUrl = (url ?? '').trim();
 if (cleanUrl.isEmpty) {
 if (!context.mounted) return;
 messenger.showSnackBar(
 const SnackBar(content: Text('No downloadable file linked.')),
 );
 return;
 }

 final uri = Uri.tryParse(cleanUrl);
 if (uri == null) {
 if (!context.mounted) return;
 messenger.showSnackBar(
 const SnackBar(content: Text('Invalid download URL.')),
 );
 return;
 }

 final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
 if (!context.mounted) return;
 if (!launched) {
 messenger.showSnackBar(
 const SnackBar(content: Text('Could not open attachment URL.')),
 );
 }
 }

 Future<void> _downloadTemplatePdf(
 BuildContext context, {
 required String title,
 required String category,
 required String templateText,
 }) async {
 final messenger = ScaffoldMessenger.of(context);
 final now = DateTime.now();
 final cleanTitle =
 title.trim().isEmpty ? 'training_template' : title.trim();
 final cleanCategory =
 category.trim().isEmpty ? 'training' : _normalizeCategory(category);
 final body = templateText.trim().isEmpty
 ? 'No template content entered yet.'
 : templateText.trim();
 final filename =
 '${_safeFileToken(cleanTitle)}_${_safeFileToken(cleanCategory)}_${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}.pdf';

 try {
 final doc = pw.Document();
 doc.addPage(
 pw.MultiPage(
 pageFormat: PdfPageFormat.a4,
 margin: const pw.EdgeInsets.all(28),
 build: (_) => [
 pw.Text(
 cleanTitle,
 style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
 ),
 pw.SizedBox(height: 6),
 pw.Text(
 'Category: $cleanCategory',
 style: const pw.TextStyle(fontSize: 11),
 ),
 pw.Text(
 'Generated: ${now.toIso8601String().split('T').first}',
 style: const pw.TextStyle(fontSize: 10),
 ),
 pw.SizedBox(height: 14),
 pw.Text(
 body,
 style: const pw.TextStyle(fontSize: 11),
 ),
 ],
 ),
 );
 final bytes = await doc.save();

 if (kIsWeb) {
 download_helper.downloadFile(
 bytes,
 filename,
 mimeType: 'application/pdf',
 );
 } else {
 await Printing.sharePdf(bytes: bytes, filename: filename);
 }

 if (!context.mounted) return;
 messenger.showSnackBar(
 SnackBar(content: Text('Template PDF ready: $filename')),
 );
 } catch (error) {
 if (!context.mounted) return;
 messenger.showSnackBar(
 SnackBar(content: Text('Failed to create PDF: $error')),
 );
 }
 }

 void _showStorageUploadError(BuildContext context, String rawError) {
 final lower = rawError.toLowerCase();
 final bucket = FirebaseStorage.instance.app.options.storageBucket;
 final isCorsIssue = lower.contains('cors') ||
 lower.contains('preflight') ||
 lower.contains('xmlhttprequest') ||
 lower.contains('net::err_failed');
 final isPermissionIssue =
 lower.contains('permission') || lower.contains('unauthorized');

 String message;
 if (isCorsIssue) {
 message =
 'Upload blocked by browser CORS for bucket "$bucket". Apply bucket CORS config, then retry. You can paste a download URL meanwhile.';
 } else if (isPermissionIssue) {
 message =
 'Upload blocked by Storage rules/permissions for bucket "$bucket". Check Firebase Storage rules for authenticated writes.';
 } else {
 message = 'Failed to upload file: $rawError';
 }

 debugPrint('Storage upload error: $rawError');
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(content: Text(message)),
 );
 }

 String _safeFileToken(String value) {
 final token = value.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_');
 final trimmed = token.replaceAll(RegExp(r'_+'), '_').replaceAll(
 RegExp(r'^_|_$'),
 '',
 );
 return trimmed.isEmpty ? 'template' : trimmed.toLowerCase();
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
 case 'jpg':
 case 'jpeg':
 return 'image/jpeg';
 case 'png':
 return 'image/png';
 default:
 return 'application/octet-stream';
 }
 }

 List<_SectionDocumentRef> _sectionDocuments(
 BuildContext context, {
 required String category,
 String? excludeActivityId,
 }) {
 final normalized = _normalizeCategory(category);
 final seen = <String>{};
 final docs = <_SectionDocumentRef>[];

 for (final activity
 in ProjectDataHelper.getData(context).trainingActivities) {
 if (excludeActivityId != null && activity.id == excludeActivityId) {
 continue;
 }
 if (_normalizeCategory(activity.category) != normalized) {
 continue;
 }

 final url = (activity.attachedFileUrl ?? '').trim();
 if (url.isEmpty) continue;
 if (!seen.add(url)) continue;

 final name = (activity.attachedFile ?? '').trim().isNotEmpty
 ? activity.attachedFile!.trim()
 : _baseName(url);

 docs.add(
 _SectionDocumentRef(
 name: name,
 url: url,
 storagePath: activity.attachedFileStoragePath,
 ),
 );
 }

 docs.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
 return docs;
 }

 String _normalizeCategory(String category) {
 if (category == 'Training') return 'Discipline-Specific';
 return category;
 }

 String _baseName(String raw) {
 final withoutQuery = raw.split('?').first;
 return withoutQuery.split('/').last.split('\\').last;
 }

 void _scrollToSection(String category) {
 final key = _keyForCategory(_normalizeCategory(category));
 final context = key.currentContext;
 if (context == null) return;
 Scrollable.ensureVisible(
 context,
 duration: const Duration(milliseconds: 350),
 curve: Curves.easeInOut,
 alignment: 0.05,
 );
 }

 GlobalKey _keyForCategory(String category) {
 switch (category) {
 case 'Onboarding':
 return _onboardingSectionKey;
 case 'Team Building':
 return _teamBuildingSectionKey;
 case 'Discipline-Specific':
 default:
 return _disciplineSectionKey;
 }
 }

 _ProjectContextSnapshot _buildContextSnapshot(ProjectDataModel data) {
 return _ProjectContextSnapshot(
 projectName: _firstNonEmpty(
 [data.projectName, data.solutionTitle],
 fallback: 'TBD Project',
 ),
 objective: _firstNonEmpty(
 [data.projectObjective, data.businessCase, data.solutionDescription],
 fallback: 'Objective not captured yet',
 ),
 framework: _firstNonEmpty(
 [data.overallFramework ?? '', data.potentialSolution],
 fallback: 'Framework pending',
 ),
 location: _firstNonEmpty(
 [data.charterOrganizationalUnit],
 fallback: 'Location not set',
 ),
 manager: _firstNonEmpty(
 [data.charterProjectManagerName],
 fallback: 'Project manager not set',
 ),
 sponsor: _firstNonEmpty(
 [data.charterProjectSponsorName],
 fallback: 'Project sponsor not set',
 ),
 roleLines: _collectRoleLines(data),
 goalLines: _collectGoalLines(data),
 milestoneLines: _collectMilestoneLines(data),
 noteHighlights: _collectPlanningNoteHighlights(data),
 );
 }

 String _buildTemplateForButton(
 _ResourceButtonSpec spec, ProjectDataModel data) {
 final snapshot = _buildContextSnapshot(data);
 final rolesText = snapshot.roleLines.isEmpty
 ? '- Add role owners and back-up owners.'
 : snapshot.roleLines.map((r) => '- $r').join('\n');
 final goalsText = snapshot.goalLines.isEmpty
 ? '- Add project goals and measurable outcomes.'
 : snapshot.goalLines.map((g) => '- $g').join('\n');
 final milestonesText = snapshot.milestoneLines.isEmpty
 ? '- Add milestone checkpoints and target dates.'
 : snapshot.milestoneLines.map((m) => '- $m').join('\n');
 final notesText = snapshot.noteHighlights.isEmpty
 ? '- No prior planning notes found.'
 : snapshot.noteHighlights.map((n) => '- $n').join('\n');

 switch (spec.id) {
 case 'welcome':
 return '''
WELCOME TEMPLATE
Purpose: standardize first-day orientation and reduce onboarding gaps.

Project Context
- Project: ${snapshot.projectName}
- Objective: ${snapshot.objective}
- Location/Org: ${snapshot.location}
- Project Manager: ${snapshot.manager}
- Sponsor: ${snapshot.sponsor}

Phased Checklist
- Pre-start: access request, tool setup, compliance docs, first-week agenda.
- Day 1: mission, scope, success criteria, and working model briefing.
- Week 1: expectations, buddy assignment, escalation path, and communication norms.
- Day 30: onboarding check, blockers review, and onboarding effectiveness check.

Completion Criteria
- New member can explain project scope and first sprint priorities.
- Read/completion confirmed.
''';
 case 'project_onboarding':
 return '''
PROJECT ONBOARDING TEMPLATE
Purpose: give every team member one consistent project brief.

Core Project Summary
- Project: ${snapshot.projectName}
- Objective: ${snapshot.objective}
- Framework: ${snapshot.framework}

Goals
$goalsText

Milestones
$milestonesText

Required Sections
- Scope in/out and assumptions.
- Key deliverables and acceptance criteria.
- Tools, repositories, and document locations.
- Risks, dependencies, and escalation flow.

Relevant Prior Notes
$notesText
''';
 case 'team_vacation':
 return '''
TEAM & VACATION TEMPLATE
Purpose: keep role coverage clear while preserving PTO and continuity.

Role and Ownership Matrix
$rolesText

Coverage Plan
- Primary owner per role.
- Backup owner per role.
- Handoff notes location.
- Vacation blackout windows (if any).
- Weekly capacity update and rebalancing rules.

Vacation Workflow
- Submit PTO at least 2 weeks in advance.
- Handoff checklist completed before leave.
- Critical tasks reassigned and acknowledged.
- Return-to-work sync scheduled.
''';
 case 'meetings':
 return '''
MEETINGS TEMPLATE
Purpose: establish recurring, timeboxed meetings with clear outcomes.

Recommended Core Cadence
- Daily sync / standup: 15 minutes.
- Sprint planning (if agile): up to 8 hours for a 1-month sprint.
- Sprint review (if agile): up to 4 hours for a 1-month sprint.
- Sprint retrospective (if agile): up to 3 hours for a 1-month sprint.

Meeting Catalog
- Name and cadence.
- Required attendees.
- Agenda owner.
- Expected output (decision, action list, blocker resolution).
- Notes repository and follow-up SLA.
''';
 case 'trainings':
 return '''
TRAINING PLAN TEMPLATE
Purpose: align mandatory learning with project needs.

Project and Objective
- Project: ${snapshot.projectName}
- Objective: ${snapshot.objective}

Training Plan Structure
- Need/skill gap.
- SMART learning objective.
- Delivery mode (workshop, simulation, peer session, self-paced).
- Owner and due date.
- Evidence of completion (quiz/demo/observation).

Evaluation Checklist
- Knowledge check completed.
- On-the-job application reviewed after 2-4 weeks.
- Training impact logged against delivery quality or cycle time.
''';
 case 'team_building':
 return '''
TEAM BUILDING TEMPLATE
Purpose: improve trust, communication, and team cohesion during delivery.

Team Context
- Project: ${snapshot.projectName}
- Manager: ${snapshot.manager}
- Sponsor: ${snapshot.sponsor}

Monthly Rhythm
- Weekly check-in ritual (10-15 mins).
- Bi-weekly collaboration exercise.
- Monthly team-building activity.
- Retro action follow-up and recognition moment.

Activity Backlog
- Ice breaker before key meetings.
- Cross-team shadowing pairs.
- Peer recognition board.
- Problem-solving session on a live project challenge.
''';
 default:
 return '''
RESOURCE TEMPLATE
- Project: ${snapshot.projectName}
- Objective: ${snapshot.objective}
- Context notes:
$notesText
''';
 }
 }

 List<String> _collectRoleLines(ProjectDataModel data) {
 final lines = <String>[];
 final seen = <String>{};

 for (final member in data.teamMembers) {
 final name = member.name.trim();
 final role = member.role.trim();
 if (name.isEmpty && role.isEmpty) continue;
 final line =
 role.isNotEmpty && name.isNotEmpty ? '$role - $name' : '$role$name';
 if (line.trim().isEmpty) continue;
 if (seen.add(line.toLowerCase())) lines.add(line);
 }

 for (final role in data.projectRoles) {
 final title = role.title.trim();
 final owner = role.workstream.trim();
 if (title.isEmpty && owner.isEmpty) continue;
 final line = owner.isNotEmpty && title.isNotEmpty
 ? '$title ($owner)'
 : '$title$owner';
 if (line.trim().isEmpty) continue;
 if (seen.add(line.toLowerCase())) lines.add(line);
 }

 for (final staffing in data.staffingRequirements) {
 final role = staffing.title.trim();
 final person = staffing.personName.trim();
 if (role.isEmpty && person.isEmpty) continue;
 final line = person.isNotEmpty && role.isNotEmpty
 ? '$role - $person'
 : '$role$person';
 if (line.trim().isEmpty) continue;
 if (seen.add(line.toLowerCase())) lines.add(line);
 }

 return lines.take(8).toList();
 }

 List<String> _collectGoalLines(ProjectDataModel data) {
 final lines = <String>[];
 for (final goal in data.projectGoals) {
 final name = goal.name.trim();
 final desc = goal.description.trim();
 if (name.isEmpty && desc.isEmpty) continue;
 lines.add(name.isNotEmpty
 ? '$name: ${_truncate(desc, 90)}'
 : _truncate(desc, 90));
 }
 for (final goal in data.planningGoals) {
 final name = goal.title.trim();
 final desc = goal.description.trim();
 if (name.isEmpty && desc.isEmpty) continue;
 final label = name.isEmpty ? 'Goal ${goal.goalNumber}' : name;
 lines.add('$label: ${_truncate(desc, 90)}');
 }
 return lines.take(6).toList();
 }

 List<String> _collectMilestoneLines(ProjectDataModel data) {
 final lines = <String>[];
 for (final milestone in data.keyMilestones) {
 final name = milestone.name.trim();
 final due = milestone.dueDate.trim();
 final discipline = milestone.discipline.trim();
 if (name.isEmpty && due.isEmpty && discipline.isEmpty) continue;
 final label = name.isEmpty ? 'Milestone' : name;
 final suffix = [
 if (due.isNotEmpty) 'Due: $due',
 if (discipline.isNotEmpty) discipline,
 ].join(' | ');
 lines.add(suffix.isEmpty ? label : '$label | $suffix');
 }
 return lines.take(6).toList();
 }

 List<String> _collectPlanningNoteHighlights(ProjectDataModel data) {
 if (data.planningNotes.isEmpty) return [];

 final prioritized = data.planningNotes.entries.where((entry) {
 final key = entry.key.toLowerCase();
 return key.contains('project') ||
 key.contains('summary') ||
 key.contains('team') ||
 key.contains('personnel') ||
 key.contains('organization') ||
 key.contains('meeting');
 }).toList();

 final source =
 prioritized.isEmpty ? data.planningNotes.entries.toList() : prioritized;

 return source
 .where((entry) => entry.value.trim().isNotEmpty)
 .take(4)
 .map((entry) => '${entry.key}: ${_truncate(entry.value.trim(), 100)}')
 .toList();
 }

 String _firstNonEmpty(List<String> values, {required String fallback}) {
 for (final value in values) {
 final v = value.trim();
 if (v.isNotEmpty) return v;
 }
 return fallback;
 }

 String _truncate(String text, int maxLength) {
 final value = text.trim();
 if (value.length <= maxLength) return value;
 return '${value.substring(0, maxLength - 3)}...';
 }

 Future<void> _addOnboardingTemplate(BuildContext context) async {
 final data = ProjectDataHelper.getData(context);
 final welcomeSpec =
 _resourceButtons.firstWhere((button) => button.id == 'welcome');
 final projectSpec = _resourceButtons
 .firstWhere((button) => button.id == 'project_onboarding');
 final teamSpec =
 _resourceButtons.firstWhere((button) => button.id == 'team_vacation');
 final meetingsSpec =
 _resourceButtons.firstWhere((button) => button.id == 'meetings');

 final template = [
 TrainingActivity(
 title: 'Welcome Orientation',
 description: _templateTextForButton(welcomeSpec, data),
 category: 'Onboarding',
 isMandatory: true,
 duration: '30 mins',
 ),
 TrainingActivity(
 title: 'Project Overview & Objectives',
 description: _templateTextForButton(projectSpec, data),
 category: 'Onboarding',
 isMandatory: true,
 duration: '60 mins',
 ),
 TrainingActivity(
 title: 'Roles, Responsibilities, and Vacation Coverage',
 description: _templateTextForButton(teamSpec, data),
 category: 'Onboarding',
 isMandatory: true,
 duration: '45 mins',
 ),
 TrainingActivity(
 title: 'Meeting Cadence and Communication Channels',
 description: _templateTextForButton(meetingsSpec, data),
 category: 'Onboarding',
 isMandatory: true,
 duration: '30 mins',
 ),
 ];

 final existing = data.trainingActivities;
 final retained = existing
 .where(
 (activity) => _normalizeCategory(activity.category) != 'Onboarding')
 .toList();
 final updated = [...retained, ...template];
 await _saveActivities(context, updated);
 }

 Future<void> _deleteActivity(
 BuildContext context, TrainingActivity activity) async {
 final rootContext = context;
 showDialog(
 context: rootContext,
 barrierDismissible: true,
 builder: (dialogContext) => LaunchModalShell(
 icon: Icons.delete_outline_rounded,
 accent: const Color(0xFFEF4444),
 title: 'Delete Activity',
 subtitle: 'This action cannot be undone.',
 body: Text(
 'Are you sure you want to delete "${activity.title}"? '
 'Once removed, the activity cannot be recovered.',
 style: const TextStyle(
 fontSize: 14,
 color: Color(0xFF4B5563),
 height: 1.5,
 ),
 ),
 actions: [
 LaunchModalCancelButton(
 label: 'Cancel',
 onPressed: () => Navigator.pop(dialogContext),
 ),
 LaunchModalDangerButton(
 label: 'Delete',
 onPressed: () async {
 final updated = List<TrainingActivity>.from(
 ProjectDataHelper.getProvider(rootContext)
 .projectData
 .trainingActivities,
 )..removeWhere((a) => a.id == activity.id);
 Navigator.pop(dialogContext);
 await _saveActivities(rootContext, updated);
 },
 ),
 ],
 ),
 );
 }

 Widget _yellowButton({
 required String label,
 required IconData icon,
 required VoidCallback onPressed,
 }) {
 return ElevatedButton.icon(
 onPressed: onPressed,
 icon: Icon(icon, size: 16),
 label: Text(label),
 style: ElevatedButton.styleFrom(
 backgroundColor: const Color(0xFFFFC107),
 foregroundColor: const Color(0xFF1F2933),
 elevation: 0,
 padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
 textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
 ),
 );
 }

 Future<void> _exportPdf() async {
 final projectData = ProjectDataHelper.getData(context);
 await PdfExportHelper.exportScreenPdf(
 context: context,
 screenTitle: 'Team Training & Building',
 sections: [
 PdfSection.keyValue('Project Info', [
 {'Project Name': projectData.projectName ?? 'N/A'},
 {'Solution Title': projectData.solutionTitle ?? 'N/A'},
 ]),
 PdfSection.text('Notes', projectData.planningNotes['planning_team_training_building_notes'] ?? 'No data recorded.'),
 ],
 );
 }
}

class _UpcomingTrainingList extends StatelessWidget {
 const _UpcomingTrainingList({
 required this.activities,
 required this.accent,
 this.heart = false,
 this.onEdit,
 this.onDelete,
 this.onDownload,
 });

 final List<TrainingActivity> activities;
 final Color accent;
 final bool heart;
 final ValueChanged<TrainingActivity>? onEdit;
 final ValueChanged<TrainingActivity>? onDelete;
 final ValueChanged<TrainingActivity>? onDownload;

 @override
 Widget build(BuildContext context) {
 return Container(
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(12),
 border: Border.all(color: Colors.grey.withOpacity(0.25)),
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Container(
 padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
 decoration: BoxDecoration(
 color: accent.withOpacity(0.06),
 borderRadius:
 const BorderRadius.vertical(top: Radius.circular(12)),
 ),
 child: Row(
 children: [
 Icon(heart ? Icons.favorite_border : Icons.auto_awesome,
 color: accent),
 const SizedBox(width: 8),
 Text(
 heart ? 'Upcoming Events' : 'Upcoming Training',
 style: TextStyle(color: accent, fontWeight: FontWeight.w700),
 ),
 ],
 ),
 ),
 if (activities.isEmpty)
 const Padding(
 padding: EdgeInsets.all(16.0),
 child: Text('No upcoming activities.',
 style: TextStyle(fontSize: 12, color: Colors.grey)),
 )
 else
 ...activities.map<Widget>((a) => Column(
 children: [
 _trainingItem(a),
 if (a != activities.last) const Divider(height: 1),
 ],
 )),
 ],
 ),
 );
 }

 Widget _trainingItem(TrainingActivity activity) {
 final hasDownload = (activity.attachedFileUrl ?? '').trim().isNotEmpty;

 return Padding(
 padding: const EdgeInsets.all(12.0),
 child: Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 children: [
 if (activity.isCompleted)
 Padding(
 padding: const EdgeInsets.only(right: 8.0),
 child: Icon(Icons.check_circle,
 size: 16, color: Colors.green[700]),
 ),
 Expanded(
 child: Text(
 activity.title,
 style: const TextStyle(fontWeight: FontWeight.w700),
 ),
 ),
 if (activity.attachedFile != null) ...[
 const SizedBox(width: 6),
 const Icon(Icons.attach_file,
 size: 14, color: Colors.blue),
 ],
 if (activity.isMandatory) ...[
 const SizedBox(width: 8),
 Container(
 padding: const EdgeInsets.symmetric(
 horizontal: 6, vertical: 2),
 decoration: BoxDecoration(
 color: Colors.red[50],
 borderRadius: BorderRadius.circular(4),
 ),
 child: Text(
 'MANDATORY',
 style: TextStyle(
 fontSize: 9,
 fontWeight: FontWeight.w800,
 color: Colors.red[700],
 ),
 ),
 ),
 ],
 ],
 ),
 if (activity.description.trim().isNotEmpty) ...[
 const SizedBox(height: 6),
 Text(
 activity.description.trim(),
 maxLines: 2,
 overflow: TextOverflow.ellipsis,
 style: TextStyle(fontSize: 11, color: Colors.grey[700]),
 ),
 ],
 if (activity.attachedFile != null) ...[
 const SizedBox(height: 8),
 Row(
 children: [
 Icon(Icons.insert_drive_file_outlined,
 size: 14, color: Colors.blue[800]),
 const SizedBox(width: 6),
 Expanded(
 child: Text(
 activity.attachedFile!,
 maxLines: 1,
 overflow: TextOverflow.ellipsis,
 style: TextStyle(
 fontSize: 11,
 color: Colors.blue[800],
 fontStyle: FontStyle.italic,
 ),
 ),
 ),
 if (!hasDownload)
 Text(
 'No URL',
 style: TextStyle(
 fontSize: 10,
 color: Colors.grey[600],
 ),
 ),
 ],
 ),
 ],
 const SizedBox(height: 8),
 Row(
 children: [
 const Icon(Icons.event_outlined,
 size: 18, color: Colors.grey),
 const SizedBox(width: 6),
 Text(
 activity.date.isEmpty ? 'TBD' : activity.date,
 style: const TextStyle(color: Colors.black87),
 ),
 const SizedBox(width: 12),
 const Icon(Icons.schedule_outlined,
 size: 18, color: Colors.grey),
 const SizedBox(width: 6),
 Text(
 activity.duration.isEmpty ? 'TBD' : activity.duration,
 style: const TextStyle(color: Colors.black87),
 ),
 ],
 ),
 ],
 ),
 ),
 if (onDownload != null && hasDownload)
 IconButton(
 onPressed: () => onDownload!(activity),
 icon: const Icon(Icons.download_outlined,
 size: 18, color: Colors.blue),
 padding: EdgeInsets.zero,
 constraints: const BoxConstraints(),
 ),
 if (onEdit != null) ...[
 const SizedBox(width: 8),
 IconButton(
 onPressed: () => onEdit!(activity),
 icon:
 const Icon(Icons.edit_outlined, size: 18, color: Colors.grey),
 padding: EdgeInsets.zero,
 constraints: const BoxConstraints(),
 ),
 ],
 if (onDelete != null) ...[
 const SizedBox(width: 8),
 IconButton(
 onPressed: () => onDelete!(activity),
 icon: const Icon(Icons.delete_outline,
 size: 18, color: Color(0xFFEF4444)),
 padding: EdgeInsets.zero,
 constraints: const BoxConstraints(),
 ),
 ],
 ],
 ),
 );
 }
}

class _BenefitCard extends StatelessWidget {
 const _BenefitCard({
 required this.icon,
 required this.title,
 required this.subtitle,
 });

 final IconData icon;
 final String title;
 final String subtitle;

 @override
 Widget build(BuildContext context) {
 return Container(
 padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(12),
 border: Border.all(color: Colors.grey.withOpacity(0.25)),
 boxShadow: [
 BoxShadow(
 color: Colors.black.withOpacity(0.05),
 blurRadius: 8,
 offset: const Offset(0, 2),
 )
 ],
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 CircleAvatar(
 radius: 18,
 backgroundColor: Colors.grey.withOpacity(0.15),
 child: Icon(icon, color: Colors.blueGrey[700]),
 ),
 const SizedBox(height: 12),
 Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
 const SizedBox(height: 6),
 Text(subtitle,
 style: TextStyle(fontSize: 12, color: Colors.grey[700])),
 ],
 ),
 );
 }
}

class _ResourceButtonSpec {
 const _ResourceButtonSpec({
 required this.id,
 required this.label,
 required this.description,
 required this.category,
 required this.defaultDuration,
 required this.mandatory,
 required this.icon,
 });

 final String id;
 final String label;
 final String description;
 final String category;
 final String defaultDuration;
 final bool mandatory;
 final IconData icon;
}

class _SectionDocumentRef {
 const _SectionDocumentRef({
 required this.name,
 required this.url,
 required this.storagePath,
 });

 final String name;
 final String url;
 final String? storagePath;
}

class _UploadedDoc {
 const _UploadedDoc({
 required this.name,
 required this.url,
 required this.storagePath,
 });

 final String name;
 final String url;
 final String storagePath;
}

class _ProjectContextSnapshot {
 const _ProjectContextSnapshot({
 required this.projectName,
 required this.objective,
 required this.framework,
 required this.location,
 required this.manager,
 required this.sponsor,
 required this.roleLines,
 required this.goalLines,
 required this.milestoneLines,
 required this.noteHighlights,
 });

 final String projectName;
 final String objective;
 final String framework;
 final String location;
 final String manager;
 final String sponsor;
 final List<String> roleLines;
 final List<String> goalLines;
 final List<String> milestoneLines;
 final List<String> noteHighlights;
}
