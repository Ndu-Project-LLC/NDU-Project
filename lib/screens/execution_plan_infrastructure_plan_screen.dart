import 'dart:async';
import 'package:ndu_project/screens/execution_plan_agile_delivery_plan_screen.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:ndu_project/widgets/responsive_scaffold.dart';
import 'package:ndu_project/widgets/responsive.dart';
import 'package:ndu_project/widgets/execution_plan_shared.dart';
import 'package:ndu_project/providers/project_data_provider.dart';
import 'package:ndu_project/models/project_data_model.dart';
import 'package:ndu_project/utils/planning_phase_navigation.dart';
import 'package:ndu_project/widgets/kaz_ai_chat_bubble.dart';

import 'package:ndu_project/widgets/voice_text_field.dart';
import 'package:ndu_project/utils/pdf_export_helper.dart';
import 'package:ndu_project/utils/project_data_helper.dart';

Future<void> _exportInfrastructurePlanPdf(BuildContext context) async {
 final projectData = ProjectDataHelper.getData(context);
 await PdfExportHelper.exportScreenPdf(
 context: context,
 screenTitle: 'Infrastructure Plan',
 sections: [
 PdfSection.keyValue('Project Info', [
 {'Project Name': projectData.projectName ?? 'N/A'},
 ]),
 PdfSection.text('Notes', projectData.planningNotes['execution_plan_infrastructure_plan_screen'] ?? 'No data recorded.'),
 ],
 );
}

class ExecutionPlanInfrastructurePlanScreen extends StatelessWidget {
 const ExecutionPlanInfrastructurePlanScreen({super.key});

 static void open(BuildContext context) {
 Navigator.of(context).push(
 MaterialPageRoute(
 builder: (_) => const ExecutionPlanInfrastructurePlanScreen()),
 );
 }

 @override
 Widget build(BuildContext context) {
 final bool isMobile = AppBreakpoints.isMobile(context);
 final double horizontalPadding = isMobile ? 20 : 40;

 return ResponsiveScaffold(
 activeItemLabel: 'Execution Plan - Infrastructure Plan',
 backgroundColor: Colors.white,
 floatingActionButton: const KazAiChatBubble(positioned: false),
 body: SingleChildScrollView(
 padding: EdgeInsets.symmetric(
 horizontal: horizontalPadding, vertical: 32),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 ExecutionPlanHeader(
 onBack: () => PlanningPhaseNavigation.goToPrevious(
 context, 'execution_plan_infrastructure_plan'),
 onNext: () => PlanningPhaseNavigation.goToNext(
 context, 'execution_plan_infrastructure_plan'), onExportPdf: () => _exportInfrastructurePlanPdf(context)),
 const SizedBox(height: 32),
 const SectionIntro(
 title: 'Execution Plan - Infrastructure Plan'),
 const SizedBox(height: 24),
 const ExecutionPlanForm(
 title: 'Execution Plan - Infrastructure Plan',
 hintText:
 'Outline infrastructure dependencies, scope, and delivery approach.',
 noteKey: 'execution_infrastructure_plan',
 showDiagram: false,
 ),
 const SizedBox(height: 32),
 const _InfrastructurePlanSection(),
 const SizedBox(height: 24),
 const _PlanningInfrastructureCostSection(),
 const SizedBox(height: 56),
 ],
 ),
 ),
 );
 }
}

class _InfrastructurePlanSection extends StatelessWidget {
 const _InfrastructurePlanSection();

 @override
 Widget build(BuildContext context) {
 final bool isMobile = AppBreakpoints.isMobile(context);

 return Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 const Text(
 'Infrastructure Plan',
 style: TextStyle(
 fontSize: 22,
 fontWeight: FontWeight.w700,
 color: Color(0xFF111827),
 ),
 ),
 const SizedBox(height: 24),
 const PlanDecisionSection(
 question: 'Will infrastructure work be done by this project?',
 planKeyPrefix: 'execution_infrastructure_plan',
 formTitle: 'Infrastructure Plan Inputs',
 formSubtitle:
 'Define the environments, capacity, and operational readiness needed for delivery.',
 fields: [
 PlanFieldConfig(
 keyName: 'scope',
 label: 'Infrastructure scope & components',
 hint: 'List core platforms, environments, and services in scope.',
 minLines: 2,
 maxLines: 4,
 fullWidth: true,
 ),
 PlanFieldConfig(
 keyName: 'environment',
 label: 'Environment strategy',
 hint: 'Dev/test/stage/prod topology and parity goals.',
 minLines: 2,
 maxLines: 4,
 ),
 PlanFieldConfig(
 keyName: 'capacity',
 label: 'Capacity & performance targets',
 hint: 'Sizing assumptions, scalability targets, and SLAs.',
 minLines: 2,
 maxLines: 4,
 ),
 PlanFieldConfig(
 keyName: 'security',
 label: 'Security, compliance & DR',
 hint:
 'Security controls, data protection, backup/restore, RTO/RPO.',
 minLines: 2,
 maxLines: 4,
 fullWidth: true,
 ),
 PlanFieldConfig(
 keyName: 'dependencies',
 label: 'Dependencies & vendors',
 hint: 'Third-party services, contracts, and lead times.',
 minLines: 2,
 maxLines: 4,
 ),
 PlanFieldConfig(
 keyName: 'cutover',
 label: 'Migration & cutover plan',
 hint: 'Data migration steps, cutover windows, rollback.',
 minLines: 2,
 maxLines: 4,
 ),
 PlanFieldConfig(
 keyName: 'monitoring',
 label: 'Operations & monitoring',
 hint: 'Monitoring, alerting, and on-call ownership.',
 minLines: 2,
 maxLines: 4,
 fullWidth: true,
 ),
 ],
 ),
 const SizedBox(height: 44),
 if (isMobile)
 _MobileInfrastructurePlanActions()
 else
 const _DesktopInfrastructurePlanActions(),
 ],
 );
 }
}

class _PlanningInfrastructureCostSection extends StatefulWidget {
 const _PlanningInfrastructureCostSection();

 @override
 State<_PlanningInfrastructureCostSection> createState() =>
 _PlanningInfrastructureCostSectionState();
}

class _PlanningInfrastructureCostSectionState
 extends State<_PlanningInfrastructureCostSection> {
 Future<void> _exportPdf() async {
 final projectData = ProjectDataHelper.getData(context);
 await PdfExportHelper.exportScreenPdf(
 context: context,
 screenTitle: 'Infrastructure Plan',
 sections: [
 PdfSection.keyValue('Project Info', [
 {'Project Name': projectData.projectName ?? 'N/A'},
 ]),
 PdfSection.text('Notes', projectData.planningNotes['execution_plan_infrastructure_plan_screen'] ?? 'No data recorded.'),
 ],
 );
 }

 Future<void> _editItem({
 InfrastructurePlanningItem? existing,
 }) async {
 final nameController = TextEditingController(text: existing?.name ?? '');
 final summaryController =
 TextEditingController(text: existing?.summary ?? '');
 final detailsController =
 TextEditingController(text: existing?.details ?? '');
 final costController = TextEditingController(
 text: existing == null || existing.potentialCost == 0
 ? ''
 : existing.potentialCost.toStringAsFixed(2),
 );
 final ownerController = TextEditingController(text: existing?.owner ?? '');
 final statusController =
 TextEditingController(text: existing?.status ?? 'Planned');

 final result = await showDialog<InfrastructurePlanningItem>(
 context: context,
 builder: (dialogContext) => AlertDialog(
 title: Text(existing == null
 ? 'Add Infrastructure Cost Item'
 : 'Edit Infrastructure Cost Item'),
 content: SizedBox(
 width: 560,
 child: SingleChildScrollView(
 child: Column(
 mainAxisSize: MainAxisSize.min,
 children: [
 VoiceTextField(
 controller: nameController,
 decoration: const InputDecoration(
 labelText: 'Item name',
 border: OutlineInputBorder(),
 ),
 ),
 const SizedBox(height: 12),
 VoiceTextField(
 controller: summaryController,
 decoration: const InputDecoration(
 labelText: 'Summary',
 border: OutlineInputBorder(),
 ),
 ),
 const SizedBox(height: 12),
 VoiceTextField(
 controller: detailsController,
 minLines: 2,
 maxLines: 4,
 decoration: const InputDecoration(
 labelText: 'Details / assumptions',
 border: OutlineInputBorder(),
 ),
 ),
 const SizedBox(height: 12),
 VoiceTextField(
 controller: costController,
 keyboardType:
 const TextInputType.numberWithOptions(decimal: true),
 decoration: const InputDecoration(
 labelText: 'Estimated cost',
 border: OutlineInputBorder(),
 ),
 ),
 const SizedBox(height: 12),
 VoiceTextField(
 controller: ownerController,
 decoration: const InputDecoration(
 labelText: 'Owner',
 border: OutlineInputBorder(),
 ),
 ),
 const SizedBox(height: 12),
 VoiceTextField(
 controller: statusController,
 decoration: const InputDecoration(
 labelText: 'Status',
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
 final name = nameController.text.trim();
 if (name.isEmpty) return;
 Navigator.of(dialogContext).pop(
 InfrastructurePlanningItem(
 id: existing?.id ??
 DateTime.now().microsecondsSinceEpoch.toString(),
 number: existing?.number ?? 0,
 name: name,
 summary: summaryController.text.trim(),
 details: detailsController.text.trim(),
 potentialCost:
 double.tryParse(costController.text.trim()) ?? 0,
 owner: ownerController.text.trim(),
 status: statusController.text.trim().isEmpty
 ? 'Planned'
 : statusController.text.trim(),
 ),
 );
 },
 child: const Text('Save'),
 ),
 ],
 ),
 );

 if (result == null || !mounted) return;
 final provider = ProjectDataInherited.of(context);
 final current = List<InfrastructurePlanningItem>.from(
 provider.projectData.planningInfrastructureItems,
 );
 final index = current.indexWhere((item) => item.id == result.id);
 if (index == -1) {
 current.add(result.copyWith(number: current.length + 1));
 } else {
 current[index] = result.copyWith(number: current[index].number);
 }
 provider.updateField(
 (data) => data.copyWith(planningInfrastructureItems: current),
 );
 await provider.saveToFirebase(checkpoint: 'execution_infrastructure_plan');
 }

 Future<void> _deleteItem(String id) async {
 final provider = ProjectDataInherited.of(context);
 final current = List<InfrastructurePlanningItem>.from(
 provider.projectData.planningInfrastructureItems,
 )..removeWhere((item) => item.id == id);
 provider.updateField(
 (data) => data.copyWith(planningInfrastructureItems: current),
 );
 await provider.saveToFirebase(checkpoint: 'execution_infrastructure_plan');
 }

 @override
 Widget build(BuildContext context) {
 final items = ProjectDataInherited.of(context)
 .projectData
 .planningInfrastructureItems;
 final currency = NumberFormat.simpleCurrency(decimalDigits: 0);
 return Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 children: [
 const Expanded(
 child: Text(
 'Infrastructure Cost Register',
 style: TextStyle(
 fontSize: 20,
 fontWeight: FontWeight.w700,
 color: Color(0xFF111827),
 ),
 ),
 ),
 ElevatedButton.icon(
 onPressed: () => _editItem(),
 icon: const Icon(Icons.add),
 label: const Text('Add Item'),
 ),
 ],
 ),
 const SizedBox(height: 8),
 const Text(
 'Capture the structured infrastructure cost items that should feed the planning cost estimate before the project reaches the cost page.',
 style: TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
 ),
 const SizedBox(height: 16),
 if (items.isEmpty)
 Container(
 width: double.infinity,
 padding: const EdgeInsets.all(20),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(14),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 ),
 child: const Text(
 'No infrastructure cost items yet. Add hosting, environments, network, tooling, migration, or platform costs here.',
 style: TextStyle(color: Color(0xFF6B7280)),
 ),
 )
 else
 ...items.map((item) {
 return Container(
 margin: const EdgeInsets.only(bottom: 12),
 padding: const EdgeInsets.all(16),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(14),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 ),
 child: Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 item.name.trim().isEmpty
 ? 'Unnamed infrastructure item'
 : item.name.trim(),
 style: const TextStyle(
 fontSize: 16,
 fontWeight: FontWeight.w700,
 ),
 ),
 const SizedBox(height: 6),
 if (item.summary.trim().isNotEmpty)
 Text(
 item.summary.trim(),
 style: const TextStyle(color: Color(0xFF374151)),
 ),
 if (item.details.trim().isNotEmpty) ...[
 const SizedBox(height: 6),
 Text(
 item.details.trim(),
 style: const TextStyle(color: Color(0xFF6B7280)),
 ),
 ],
 const SizedBox(height: 8),
 Wrap(
 spacing: 12,
 runSpacing: 8,
 children: [
 Text(
 currency.format(item.potentialCost),
 style: const TextStyle(
 fontWeight: FontWeight.w700,
 color: Color(0xFF2563EB),
 ),
 ),
 if (item.owner.trim().isNotEmpty)
 Text(
 'Owner: ${item.owner.trim()}',
 style:
 const TextStyle(color: Color(0xFF4B5563)),
 ),
 Text(
 item.status.trim().isEmpty
 ? 'Planned'
 : item.status.trim(),
 style: const TextStyle(color: Color(0xFF4B5563)),
 ),
 ],
 ),
 ],
 ),
 ),
 PopupMenuButton<String>(
 onSelected: (value) {
 if (value == 'edit') {
 _editItem(existing: item);
 } else if (value == 'delete') {
 _deleteItem(item.id);
 }
 },
 itemBuilder: (context) => const [
 PopupMenuItem(value: 'edit', child: Text('Edit')),
 PopupMenuItem(value: 'delete', child: Text('Delete')),
 ],
 ),
 ],
 ),
 );
 }),
 ],
 );
 }
}

class _DesktopInfrastructurePlanActions extends StatelessWidget {
 const _DesktopInfrastructurePlanActions();

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
 'Plan infrastructure requirements including temporary facilities, utilities, and logistics.',
 ),
 ),
 ),
 ),
 const SizedBox(width: 24),
 YellowActionButton(
 label: 'Next',
 onPressed: () => ExecutionPlanAgileDeliveryPlanScreen.open(context),
 ),
 ],
 );
 }
}

class _MobileInfrastructurePlanActions extends StatelessWidget {
 const _MobileInfrastructurePlanActions();

 @override
 Widget build(BuildContext context) {
 return Column(
 crossAxisAlignment: CrossAxisAlignment.center,
 children: [
 const InfoBadge(),
 const SizedBox(height: 20),
 const AiTipCard(
 text:
 'Plan infrastructure requirements including temporary facilities, utilities, and logistics.',
 ),
 const SizedBox(height: 20),
 YellowActionButton(
 label: 'Next',
 onPressed: () => ExecutionPlanAgileDeliveryPlanScreen.open(context),
 ),
 ],
 );
 }
}
