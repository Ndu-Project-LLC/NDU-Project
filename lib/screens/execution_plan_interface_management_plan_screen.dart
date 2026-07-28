import 'dart:async';
import 'package:ndu_project/screens/execution_plan_interface_management_overview_screen.dart';
import 'package:flutter/material.dart';
import 'package:ndu_project/widgets/responsive_scaffold.dart';
import 'package:ndu_project/widgets/responsive.dart';
import 'package:ndu_project/widgets/execution_plan_shared.dart';
import 'package:ndu_project/providers/project_data_provider.dart';
import 'package:ndu_project/services/execution_service.dart';
import 'package:ndu_project/utils/project_data_helper.dart';
import 'package:ndu_project/widgets/kaz_ai_chat_bubble.dart';

import 'package:ndu_project/widgets/voice_text_field.dart';
import 'package:ndu_project/utils/pdf_export_helper.dart';
import 'package:ndu_project/utils/planning_phase_navigation.dart';

Future<void> _exportInterfaceManagementPlanPdf(BuildContext context) async {
 final projectData = ProjectDataHelper.getData(context);
 await PdfExportHelper.exportScreenPdf(
 context: context,
 screenTitle: 'Interface Management Plan',
 sections: [
 PdfSection.keyValue('Project Info', [
 {'Project Name': projectData.projectName ?? 'N/A'},
 ]),
 PdfSection.text('Notes', projectData.planningNotes['execution_plan_interface_management_plan_screen'] ?? 'No data recorded.'),
 ],
 );
}

class ExecutionPlanInterfaceManagementPlanScreen extends StatelessWidget {
 const ExecutionPlanInterfaceManagementPlanScreen({super.key});

 static void open(BuildContext context) {
 Navigator.of(context).push(
 MaterialPageRoute(
 builder: (_) => const ExecutionPlanInterfaceManagementPlanScreen()),
 );
 }

 @override
 Widget build(BuildContext context) {
 final bool isMobile = AppBreakpoints.isMobile(context);
 final double horizontalPadding = isMobile ? 20 : 40;

 return ResponsiveScaffold(
 activeItemLabel: 'Execution Interface Management Plan',
 backgroundColor: Colors.white,
 floatingActionButton: const KazAiChatBubble(positioned: false),
 body: SingleChildScrollView(
 padding: EdgeInsets.symmetric(
 horizontal: horizontalPadding, vertical: 32),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 ExecutionPlanHeader(
 onBack: () => PlanningPhaseNavigation.goToPrevious(context, 'execution_plan_interface_management_plan'),
 onNext: () => PlanningPhaseNavigation.goToNext(context, 'execution_plan_interface_management_plan'), onExportPdf: () => _exportInterfaceManagementPlanPdf(context)),
 const SizedBox(height: 32),
 const SectionIntro(
 title: 'Execution Interface Management Plan'),
 const SizedBox(height: 16),
 const CrossReferenceNote(standalonePage: 'Interface Management'),
 const SizedBox(height: 24),
 const ExecutionPlanForm(
 title: 'Execution Interface Management Plan',
 hintText:
 'Summarize interface management plan objectives and control points.',
 noteKey: 'execution_interface_management_plan',
 ),
 const SizedBox(height: 32),
 const _InterfaceManagementPlanForm(),
 const SizedBox(height: 48),
 const _InterfaceManagementPlanSection(),
 const SizedBox(height: 56),
 ],
 ),
 ),
 );
 }
}

class _InterfaceManagementPlanForm extends StatefulWidget {
 const _InterfaceManagementPlanForm();

 @override
 State<_InterfaceManagementPlanForm> createState() =>
 _InterfaceManagementPlanFormState();
}

class _InterfaceManagementPlanFormState
 extends State<_InterfaceManagementPlanForm> {
 Future<void> _exportPdf() async {
 final projectData = ProjectDataHelper.getData(context);
 await PdfExportHelper.exportScreenPdf(
 context: context,
 screenTitle: 'Interface Management Plan',
 sections: [
 PdfSection.keyValue('Project Info', [
 {'Project Name': projectData.projectName ?? 'N/A'},
 ]),
 PdfSection.text('Notes', projectData.planningNotes['execution_plan_interface_management_plan_screen'] ?? 'No data recorded.'),
 ],
 );
 }

 final _responsibilityMatrixController = TextEditingController();
 final _escalationProceduresController = TextEditingController();
 final _coordinationMeetingsController = TextEditingController();
 Timer? _saveDebounce;
 bool _didInit = false;
 DateTime? _lastSavedAt;

 @override
 void dispose() {
 _saveDebounce?.cancel();
 _responsibilityMatrixController.dispose();
 _escalationProceduresController.dispose();
 _coordinationMeetingsController.dispose();
 super.dispose();
 }

 void _scheduleSave() {
 _saveDebounce?.cancel();
 _saveDebounce = Timer(const Duration(milliseconds: 700), _saveNow);
 }

 Future<void> _saveNow() async {
 final updates = <String, String>{
 'execution_imp_responsibility_matrix':
 _responsibilityMatrixController.text.trim(),
 'execution_imp_escalation_procedures':
 _escalationProceduresController.text.trim(),
 'execution_imp_coordination_meetings':
 _coordinationMeetingsController.text.trim(),
 };
 final success = await ProjectDataHelper.updateAndSave(
 context: context,
 checkpoint:
 resolveExecutionCheckpoint('execution_interface_management_plan'),
 dataUpdater: (data) => data.copyWith(
 planningNotes: {
 ...data.planningNotes,
 ...updates,
 },
 ),
 showSnackbar: false,
 );
 if (mounted && success) {
 setState(() => _lastSavedAt = DateTime.now());
 }
 }

 @override
 Widget build(BuildContext context) {
 if (!_didInit) {
 final notes = ProjectDataHelper.getData(context).planningNotes;
 _responsibilityMatrixController.text =
 notes['execution_imp_responsibility_matrix'] ?? '';
 _escalationProceduresController.text =
 notes['execution_imp_escalation_procedures'] ?? '';
 _coordinationMeetingsController.text =
 notes['execution_imp_coordination_meetings'] ?? '';
 _didInit = true;
 }

 return Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 const Text(
 'Interface Management Plan Details',
 style: TextStyle(
 fontSize: 16,
 fontWeight: FontWeight.w600,
 color: Color(0xFF111827),
 ),
 ),
 const SizedBox(height: 16),
 Container(
 padding: const EdgeInsets.all(20),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(12),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 ),
 child: const Text(
 'The Interface Management Plan defines the coordination framework, responsibilities, escalation procedures, and communication protocols for managing interfaces between project packages, disciplines, and external stakeholders.',
 style: TextStyle(
 fontSize: 14,
 fontWeight: FontWeight.w400,
 color: Color(0xFF6B7280),
 height: 1.6,
 ),
 ),
 ),
 const SizedBox(height: 20),
 VoiceTextField(
 controller: _responsibilityMatrixController,
 decoration: const InputDecoration(
 labelText: 'Responsibility Matrix',
 hintText: 'Define roles and responsibilities for each interface...',
 border: OutlineInputBorder(),
 ),
 maxLines: 3,
 onChanged: (_) => _scheduleSave(),
 ),
 const SizedBox(height: 16),
 VoiceTextField(
 controller: _escalationProceduresController,
 decoration: const InputDecoration(
 labelText: 'Escalation Procedures',
 hintText: 'Describe escalation paths and triggers...',
 border: OutlineInputBorder(),
 ),
 maxLines: 3,
 onChanged: (_) => _scheduleSave(),
 ),
 const SizedBox(height: 16),
 VoiceTextField(
 controller: _coordinationMeetingsController,
 decoration: const InputDecoration(
 labelText: 'Coordination Meeting Schedule',
 hintText: 'Define meeting cadence, attendees, and objectives...',
 border: OutlineInputBorder(),
 ),
 maxLines: 3,
 onChanged: (_) => _scheduleSave(),
 ),
 if (_lastSavedAt != null)
 Padding(
 padding: const EdgeInsets.only(top: 8),
 child: Text(
 'Saved ${TimeOfDay.fromDateTime(_lastSavedAt!).format(context)}',
 style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
 ),
 ),
 ],
 );
 }
}

class _InterfaceManagementPlanSection extends StatelessWidget {
 const _InterfaceManagementPlanSection();

 String? _getProjectId(BuildContext context) {
 try {
 final provider = ProjectDataInherited.maybeOf(context);
 return provider?.projectData.projectId;
 } catch (e) {
 return null;
 }
 }

 @override
 Widget build(BuildContext context) {
 final bool isMobile = AppBreakpoints.isMobile(context);
 final projectId = _getProjectId(context);

 Widget summaryCard = Container(
 padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(18),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 boxShadow: const [
 BoxShadow(
 color: Color(0x0F000000), blurRadius: 10, offset: Offset(0, 6)),
 ],
 ),
 child: Row(
 mainAxisSize: MainAxisSize.min,
 children: [
 Container(
 width: 42,
 height: 42,
 decoration: const BoxDecoration(
 color: Color(0xFFE5E7EB),
 shape: BoxShape.circle,
 ),
 child: const Icon(Icons.link, color: Color(0xFF4B5563)),
 ),
 const SizedBox(width: 14),
 Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 const Text(
 'Interface Register Entries',
 style: TextStyle(
 fontSize: 15,
 fontWeight: FontWeight.w700,
 color: Color(0xFF111827),
 ),
 ),
 const SizedBox(height: 4),
 if (projectId != null)
 StreamBuilder<List<InterfaceRegisterModel>>(
 stream: ExecutionService.streamInterfaceRegister(projectId),
 builder: (context, snapshot) {
 final count = snapshot.data?.length ?? 0;
 return Text(
 '$count ${count == 1 ? 'entry' : 'entries'} registered',
 style: const TextStyle(
 fontSize: 13,
 fontWeight: FontWeight.w500,
 color: Color(0xFF6B7280),
 ),
 );
 },
 )
 else
 const Text(
 'No project selected',
 style: TextStyle(
 fontSize: 13,
 fontWeight: FontWeight.w500,
 color: Color(0xFF6B7280),
 ),
 ),
 ],
 ),
 ],
 ),
 );

 return Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 const Text(
 'Interface Management Plan',
 style: TextStyle(
 fontSize: 22,
 fontWeight: FontWeight.w700,
 color: Color(0xFF111827),
 ),
 ),
 const SizedBox(height: 28),
 summaryCard,
 const SizedBox(height: 44),
 if (isMobile)
 _MobileInterfaceManagementPlanActions()
 else
 const _DesktopInterfaceManagementPlanActions(),
 ],
 );
 }
}

class _DesktopInterfaceManagementPlanActions extends StatelessWidget {
 const _DesktopInterfaceManagementPlanActions();

 @override
 Widget build(BuildContext context) {
 return Row(
 crossAxisAlignment: CrossAxisAlignment.center,
 children: [
 const InfoBadge(),
 const SizedBox(width: 32),
 Expanded(
 child: Align(
 alignment: Alignment.centerLeft,
 child: ConstrainedBox(
 constraints: const BoxConstraints(maxWidth: 420),
 child: const AiTipCard(
 text:
 'A well-defined escalation procedure prevents interface conflicts from stalling project progress.',
 ),
 ),
 ),
 ),
 const SizedBox(width: 24),
 YellowActionButton(
 label: 'Next',
 onPressed: () =>
 ExecutionPlanInterfaceManagementOverviewScreen.open(context),
 ),
 ],
 );
 }
}

class _MobileInterfaceManagementPlanActions extends StatelessWidget {
 const _MobileInterfaceManagementPlanActions();

 @override
 Widget build(BuildContext context) {
 return Column(
 crossAxisAlignment: CrossAxisAlignment.center,
 children: [
 const InfoBadge(),
 const SizedBox(height: 20),
 const AiTipCard(
 text:
 'A well-defined escalation procedure prevents interface conflicts from stalling project progress.',
 ),
 const SizedBox(height: 20),
 YellowActionButton(
 label: 'Next',
 onPressed: () =>
 ExecutionPlanInterfaceManagementOverviewScreen.open(context),
 ),
 ],
 );
 }
}
