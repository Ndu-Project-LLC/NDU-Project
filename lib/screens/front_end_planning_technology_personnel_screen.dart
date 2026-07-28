import 'package:flutter/material.dart';
import 'package:ndu_project/models/project_data_model.dart';
import 'package:ndu_project/screens/planning_contracting_screen.dart';
import 'package:ndu_project/utils/project_data_helper.dart';
import 'package:ndu_project/widgets/admin_edit_toggle.dart';
import 'package:ndu_project/widgets/front_end_planning_header.dart';
import 'package:ndu_project/widgets/kaz_ai_chat_bubble.dart';
import 'package:ndu_project/widgets/program_workspace_scaffold.dart';

import 'package:ndu_project/widgets/voice_text_field.dart';
import 'package:ndu_project/utils/pdf_export_helper.dart';
class FrontEndPlanningTechnologyPersonnelScreen extends StatefulWidget {
 const FrontEndPlanningTechnologyPersonnelScreen({super.key});

 static void open(BuildContext context) {
 Navigator.of(context).push(
 MaterialPageRoute(
 builder: (_) => const FrontEndPlanningTechnologyPersonnelScreen(),
 ),
 );
 }

 @override
 State<FrontEndPlanningTechnologyPersonnelScreen> createState() =>
 _FrontEndPlanningTechnologyPersonnelScreenState();
}

class _FrontEndPlanningTechnologyPersonnelScreenState
 extends State<FrontEndPlanningTechnologyPersonnelScreen> {
 final TextEditingController _notes = TextEditingController();
 List<TechnologyPersonnelItem> _rows = [];
 bool _isSyncReady = false;

 @override
 void initState() {
 super.initState();
 WidgetsBinding.instance.addPostFrameCallback((_) {
 final data = ProjectDataHelper.getData(context);
 setState(() {
 _notes.text = data.frontEndPlanning.technology;
 _rows = List<TechnologyPersonnelItem>.from(
 data.frontEndPlanning.technologyPersonnelItems,
 );
 _isSyncReady = true;
 });
 _notes.addListener(_syncToProvider);
 });
 }

 
 Future<void> _exportPdf() async {
 final projectData = ProjectDataHelper.getData(context);
 final fep = projectData.frontEndPlanning;
 await PdfExportHelper.exportScreenPdf(
 context: context,
 screenTitle: 'Technology Personnel',
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
 _notes.removeListener(_syncToProvider);
 _notes.dispose();
 super.dispose();
 }

 void _syncToProvider() {
 if (!mounted || !_isSyncReady) return;
 final provider = ProjectDataHelper.getProvider(context);
 provider.updateField(
 (data) => data.copyWith(
 frontEndPlanning: ProjectDataHelper.updateFEPField(
 current: data.frontEndPlanning,
 technology: _notes.text,
 technologyPersonnelItems: _rows,
 ),
 ),
 );
 provider.saveToFirebase(checkpoint: 'fep_technology_personnel');
 }

 Future<void> _upsertRow({TechnologyPersonnelItem? existing}) async {
 final technologyController =
 TextEditingController(text: existing?.technologyArea ?? '');
 final ownerController =
 TextEditingController(text: existing?.primaryOwner ?? '');
 final supportController =
 TextEditingController(text: existing?.backupSupport ?? '');
 final notesController = TextEditingController(text: existing?.notes ?? '');

 try {
 final result = await showDialog<TechnologyPersonnelItem>(
 context: context,
 builder: (dialogContext) {
 return AlertDialog(
 title: Text(existing == null
 ? 'Add Technology Owner'
 : 'Edit Technology Owner'),
 content: SizedBox(
 width: 560,
 child: SingleChildScrollView(
 child: Column(
 mainAxisSize: MainAxisSize.min,
 children: [
 VoiceTextField(
 controller: technologyController,
 decoration: const InputDecoration(
 labelText: 'Technology Area',
 border: OutlineInputBorder(),
 ),
 ),
 const SizedBox(height: 12),
 VoiceTextField(
 controller: ownerController,
 decoration: const InputDecoration(
 labelText: 'Primary Owner',
 border: OutlineInputBorder(),
 ),
 ),
 const SizedBox(height: 12),
 VoiceTextField(
 controller: supportController,
 decoration: const InputDecoration(
 labelText: 'Backup / Support',
 border: OutlineInputBorder(),
 ),
 ),
 const SizedBox(height: 12),
 VoiceTextField(
 controller: notesController,
 minLines: 3,
 maxLines: 5,
 decoration: const InputDecoration(
 labelText: 'Notes',
 border: OutlineInputBorder(),
 ),
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
 onPressed: () {
 final technology = technologyController.text.trim();
 if (technology.isEmpty) return;
 Navigator.of(dialogContext).pop(
 TechnologyPersonnelItem(
 id: existing?.id ??
 DateTime.now().microsecondsSinceEpoch.toString(),
 number: existing?.number ?? (_rows.length + 1),
 technologyArea: technology,
 primaryOwner: ownerController.text.trim(),
 backupSupport: supportController.text.trim(),
 notes: notesController.text.trim(),
 ),
 );
 },
 child: const Text('Save'),
 ),
 ],
 );
 },
 );

 if (result == null || !mounted) return;
 setState(() {
 final index = _rows.indexWhere((item) => item.id == result.id);
 if (index == -1) {
 _rows.add(result);
 } else {
 _rows[index] = result;
 }
 });
 _syncToProvider();
 } finally {
 technologyController.dispose();
 ownerController.dispose();
 supportController.dispose();
 notesController.dispose();
 }
 }

 void _deleteRow(String id) {
 setState(() => _rows.removeWhere((item) => item.id == id));
 _syncToProvider();
 }

 @override
 Widget build(BuildContext context) {
 return ProgramWorkspaceScaffold(
 body: Stack(
 children: [
 const AdminEditToggle(),
 Column(
 children: [
 FrontEndPlanningHeader(onExportPdf: _exportPdf),
 Expanded(
 child: SingleChildScrollView(
 padding:
 const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 VoiceTextField(
 controller: _notes,
 minLines: 3,
 maxLines: 5,
 decoration: const InputDecoration(
 hintText:
 'Capture technology ownership, support handoff, and coverage notes...',
 border: OutlineInputBorder(),
 ),
 ),
 const SizedBox(height: 20),
 Row(
 children: [
 const Expanded(
 child: Text(
 'Technology Personnel',
 style: TextStyle(
 fontSize: 20,
 fontWeight: FontWeight.w700,
 color: Color(0xFF111827),
 ),
 ),
 ),
 ElevatedButton.icon(
 onPressed: () => _upsertRow(),
 icon: const Icon(Icons.add),
 label: const Text('Add Owner'),
 ),
 ],
 ),
 const SizedBox(height: 8),
 const Text(
 'Persist named owners and support contacts for technology cost and accountability traceability.',
 style: TextStyle(color: Color(0xFF6B7280)),
 ),
 const SizedBox(height: 16),
 if (_rows.isEmpty)
 Container(
 width: double.infinity,
 padding: const EdgeInsets.all(20),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(12),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 ),
 child: const Text(
 'No technology ownership rows yet. Add primary owners and backup support for key tools, platforms, and integrations.',
 style: TextStyle(color: Color(0xFF6B7280)),
 ),
 )
 else
 Column(
 children: _rows.map((item) {
 return Container(
 margin: const EdgeInsets.only(bottom: 12),
 padding: const EdgeInsets.all(16),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(12),
 border:
 Border.all(color: const Color(0xFFE5E7EB)),
 ),
 child: Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Expanded(
 child: Column(
 crossAxisAlignment:
 CrossAxisAlignment.start,
 children: [
 Text(
 item.technologyArea.trim().isEmpty
 ? 'Unnamed technology'
 : item.technologyArea.trim(),
 style: const TextStyle(
 fontSize: 16,
 fontWeight: FontWeight.w700,
 ),
 ),
 const SizedBox(height: 6),
 Text(
 item.primaryOwner.trim().isEmpty
 ? 'Primary owner not assigned'
 : 'Owner: ${item.primaryOwner.trim()}',
 style: const TextStyle(
 color: Color(0xFF374151),
 ),
 ),
 if (item.backupSupport
 .trim()
 .isNotEmpty) ...[
 const SizedBox(height: 4),
 Text(
 'Support: ${item.backupSupport.trim()}',
 style: const TextStyle(
 color: Color(0xFF4B5563),
 ),
 ),
 ],
 if (item.notes.trim().isNotEmpty) ...[
 const SizedBox(height: 8),
 Text(
 item.notes.trim(),
 style: const TextStyle(
 color: Color(0xFF6B7280),
 ),
 ),
 ],
 ],
 ),
 ),
 PopupMenuButton<String>(
 onSelected: (value) {
 if (value == 'edit') {
 _upsertRow(existing: item);
 } else if (value == 'delete') {
 _deleteRow(item.id);
 }
 },
 itemBuilder: (context) => const [
 PopupMenuItem(
 value: 'edit',
 child: Text('Edit'),
 ),
 PopupMenuItem(
 value: 'delete',
 child: Text('Delete'),
 ),
 ],
 ),
 ],
 ),
 );
 }).toList(),
 ),
 const SizedBox(height: 140),
 ],
 ),
 ),
 ),
 ],
 ),
 _BottomOverlay(
 onSubmit: () => PlanningContractingScreen.open(context),
 ),
 const KazAiChatBubble(),
 ],
 ),
 );
 }
}

class _BottomOverlay extends StatelessWidget {
 const _BottomOverlay({required this.onSubmit});

 final VoidCallback onSubmit;

 @override
 Widget build(BuildContext context) {
 return Positioned(
 right: 24,
 bottom: 24,
 child: SizedBox(
 height: 44,
 child: ElevatedButton(
 style: ElevatedButton.styleFrom(
 backgroundColor: const Color(0xFF2563EB),
 foregroundColor: Colors.white,
 ),
 onPressed: onSubmit,
 child: const Text('Continue'),
 ),
 ),
 );
 }
}
