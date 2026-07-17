import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:ndu_project/models/project_data_model.dart';
import 'package:ndu_project/screens/project_charter_screen.dart';
import 'package:ndu_project/services/api_key_manager.dart';
import 'package:ndu_project/services/openai_service_secure.dart';
import 'package:ndu_project/utils/front_end_planning_navigation.dart';
import 'package:ndu_project/utils/project_data_helper.dart';
import 'package:ndu_project/widgets/admin_edit_toggle.dart';
import 'package:ndu_project/widgets/draggable_sidebar.dart';
import 'package:ndu_project/widgets/front_end_planning_header.dart';
import 'package:ndu_project/widgets/initiation_like_sidebar.dart';
import 'package:ndu_project/widgets/kaz_ai_chat_bubble.dart';
import 'package:ndu_project/widgets/page_regenerate_all_button.dart';
import 'package:ndu_project/widgets/responsive.dart';
import 'package:ndu_project/widgets/delete_confirmation_dialog.dart';

import 'package:ndu_project/widgets/voice_text_field.dart';
import 'package:ndu_project/utils/pdf_export_helper.dart';
/// Front End Planning – Allowance screen
/// Refactored to support structured "Program-Aware Financial Inputs".
///
/// TODO: Each allowance item NEEDS to support role/person assignment.
/// Users should be able to specify WHO is responsible for managing each
/// allowance (e.g., "Finance Manager", "John Doe"). This enables tracking
/// and accountability for budget items throughout the project lifecycle.
///
/// The "Applies To" field determines WHERE the allowance applies (Estimate,
/// Schedule, Training, etc.), while "Assigned To" determines WHO manages it.
/// This feature is highlighted in the requirements screenshots and needs implementation.
class FrontEndPlanningAllowanceScreen extends StatefulWidget {
 const FrontEndPlanningAllowanceScreen({super.key});

 static void open(BuildContext context) {
 Navigator.of(context).push(
 MaterialPageRoute(
 builder: (_) => const FrontEndPlanningAllowanceScreen()),
 );
 }

 @override
 State<FrontEndPlanningAllowanceScreen> createState() =>
 _FrontEndPlanningAllowanceScreenState();
}

class _FrontEndPlanningAllowanceScreenState
 extends State<FrontEndPlanningAllowanceScreen> {
 final TextEditingController _notes = TextEditingController();

 // Local state for list items
 List<AllowanceItem> _allowanceItems = [];
 bool _isSyncReady = false;
 bool _isGenerating = false;
 late final OpenAiServiceSecure _openAi;

 String? _projectId() => ProjectDataHelper.getData(context).projectId;

 Future<bool> _isSectionInitialized(String flagKey) async {
 final projectId = _projectId();
 if (projectId == null || projectId.isEmpty) return false;
 try {
 final doc = await FirebaseFirestore.instance
 .collection('projects')
 .doc(projectId)
 .collection('planning_meta')
 .doc('initialization_flags')
 .get();
 return doc.data()?[flagKey] == true;
 } catch (e) {
 return false;
 }
 }

 Future<void> _markSectionInitialized(String flagKey) async {
 final projectId = _projectId();
 if (projectId == null || projectId.isEmpty) return;
 try {
 await FirebaseFirestore.instance
 .collection('projects')
 .doc(projectId)
 .collection('planning_meta')
 .doc('initialization_flags')
 .set({flagKey: true, '${flagKey}_at': FieldValue.serverTimestamp()}, SetOptions(merge: true));
 } catch (e) { debugPrint('Error: $e'); }
 }

 @override
 void initState() {
 super.initState();
 _openAi = OpenAiServiceSecure();
 ApiKeyManager.initializeApiKey();
 WidgetsBinding.instance.addPostFrameCallback((_) {
 final data = ProjectDataHelper.getData(context);
 _notes.text = data.frontEndPlanning
 .allowance; // Legacy field used for general notes now?
 // Actually, let's keep _notes separate if we want general notes.
 // The user said "Convert simple text box to structured List".
 // I'll keep the top notes field for "General Allowance Notes" and map it to the old string field for now,
 // or just use a separate field if available, but FEP data has `allowance` string.
 // I'll use `allowance` for general notes text.

 _allowanceItems = List.from(data.frontEndPlanning.allowanceItems);

 _notes.addListener(_syncNotesToProvider);
 _isSyncReady = true;
 _syncItemsToProvider();
 if (_allowanceItems.isEmpty) {
 _checkAndGenerateDefaultAllowances();
 }
 setState(() {});
 });
 }

 
 Future<void> _exportPdf() async {
 final projectData = ProjectDataHelper.getData(context);
 final fep = projectData.frontEndPlanning;
 await PdfExportHelper.exportScreenPdf(
 context: context,
 screenTitle: 'Allowance',
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
 _notes.removeListener(_syncNotesToProvider);
 _notes.dispose();
 super.dispose();
 }

 void _syncNotesToProvider() {
 if (!mounted || !_isSyncReady) return;
 final provider = ProjectDataHelper.getProvider(context);
 provider.updateField(
 (data) => data.copyWith(
 frontEndPlanning: ProjectDataHelper.updateFEPField(
 current: data.frontEndPlanning,
 allowance: _notes.text, // Sync general notes
 ),
 ),
 );
 provider.saveToFirebase(checkpoint: 'fep_allowance');
 }

 void _syncItemsToProvider() {
 if (!mounted || !_isSyncReady) return;
 final provider = ProjectDataHelper.getProvider(context);
 provider.updateField(
 (data) {
 final updated = data.copyWith(
 frontEndPlanning: ProjectDataHelper.updateFEPField(
 current: data.frontEndPlanning,
 allowanceItems: _allowanceItems,
 ),
 );
 return ProjectDataHelper.applyTaggedFrontEndPlanningData(updated);
 },
 );
 provider.saveToFirebase(checkpoint: 'fep_allowance');
 if (_allowanceItems.isNotEmpty) {
 _markSectionInitialized('allowance_initialized');
 }
 }

 Future<void> _checkAndGenerateDefaultAllowances() async {
 final initialized = await _isSectionInitialized('allowance_initialized');
 if (!initialized && mounted) {
 await _generateDefaultAllowances();
 }
 }

 Future<void> _generateDefaultAllowances() async {
 if (_isGenerating) return;
 setState(() => _isGenerating = true);

 // Show immediate feedback so the user knows the AI assist click was
 // registered (fixes the "clicked AI assist and didn't get any feedback"
 // issue).
 if (mounted) {
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(
 content: Row(
 children: [
 SizedBox(
 width: 18,
 height: 18,
 child: CircularProgressIndicator(
 strokeWidth: 2,
 color: Colors.white,
 ),
 ),
 SizedBox(width: 12),
 Expanded(
 child: Text(
 'AI is generating region-aware allowances and contingencies...'),
 ),
 ],
 ),
 duration: Duration(seconds: 5),
 backgroundColor: Color(0xFF2563EB),
 behavior: SnackBarBehavior.floating,
 ),
 );
 }

 try {
 final data = ProjectDataHelper.getData(context);
 final sb = StringBuffer();
 sb
 ..writeln(
 ProjectDataHelper.buildFepContext(
 data,
 sectionLabel: 'Allowance',
 ),
 )
 ..writeln()
 ..writeln(
 ProjectDataHelper.buildProjectContextScan(
 data,
 sectionLabel: 'Allowance Planning',
 ),
 )
 ..writeln()
 ..writeln('Section-specific guidance:')
 ..writeln(
 '- Generate allowances that reflect this project type, phase risks, and procurement realities.',
 )
 ..writeln(
 '- Include realistic contingency items for schedule, commercial, operational, and compliance exposure.',
 )
 ..writeln(
 '- Factor in the project LOCATION and REGION (hurricanes in the US Gulf Coast, typhoons in East/Southeast Asia, power instability in West/Central Africa, security issues in fragile regions, monsoon flooding in South Asia, seismic activity in the Pacific Rim, winter storms in North America/Europe).',
 )
 ..writeln(
 '- For each item, populate description, estimated cost/quantity, schedule impact (with weeks), responsible discipline, assumptions, and trigger context.',
 );

 final newItems =
 await _openAi.generateAllowancesFromContext(sb.toString());

 if (mounted) {
 setState(() {
 _allowanceItems.addAll(newItems);
 });
 _syncItemsToProvider();
 // Show success feedback so the user sees the AI assist result.
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(
 content: Text(
 'Generated ${newItems.length} region-aware allowances successfully.'),
 backgroundColor: const Color(0xFF10B981),
 behavior: SnackBarBehavior.floating,
 duration: const Duration(seconds: 3),
 ),
 );
 }
 } catch (e) {
 if (mounted) {
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(
 content: Text('Error generating allowances: $e'),
 backgroundColor: const Color(0xFFDC2626),
 behavior: SnackBarBehavior.floating,
 duration: const Duration(seconds: 5),
 ),
 );
 }
 } finally {
 if (mounted) {
 setState(() => _isGenerating = false);
 }
 }
 }

 void _addItem() {
 _showItemDialog();
 }

 void _editItem(AllowanceItem item) {
 _showItemDialog(item: item);
 }

 Future<void> _deleteItem(String id) async {
 AllowanceItem? item;
 for (final entry in _allowanceItems) {
 if (entry.id == id) {
 item = entry;
 break;
 }
 }
 final confirmed = await showDeleteConfirmationDialog(
 context,
 title: 'Delete Allowance?',
 itemLabel: item?.name,
 );
 if (!confirmed) return;

 setState(() {
 _allowanceItems.removeWhere((item) => item.id == id);
 });
 _syncItemsToProvider();
 }

 String _nextFlowDestinationLabel() {
 final rawLabel =
 FrontEndPlanningNavigation.nextLabel(context, 'fep_allowance').trim();
 if (rawLabel.startsWith('Next:')) {
 final parsed = rawLabel.substring('Next:'.length).trim();
 if (parsed.isNotEmpty && parsed.toLowerCase() != 'next') {
 return parsed;
 }
 }
 return 'Project Charter';
 }

 Future<bool> _confirmProceedWithoutAllowances() async {
 if (_allowanceItems.isNotEmpty) return true;
 final destination = _nextFlowDestinationLabel();
 if (!mounted) return true;
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(
 content: Text(
 'No allowance items added yet. Continue to $destination and update allowances anytime.',
 ),
 ),
 );
 return true;
 }

 void _goToPreviousStep() {
 FrontEndPlanningNavigation.goToPrevious(context, 'fep_allowance');
 }

 Future<void> _saveAndNavigateToNextStep() async {
 final shouldProceed = await _confirmProceedWithoutAllowances();
 if (!shouldProceed || !mounted) return;

 final nextCheckpoint =
 FrontEndPlanningNavigation.nextCheckpoint(context, 'fep_allowance') ??
 'project_charter';
 final nextScreen =
 FrontEndPlanningNavigation.resolveScreen(context, nextCheckpoint) ??
 const ProjectCharterScreen();

 await ProjectDataHelper.saveAndNavigate(
 context: context,
 checkpoint: 'fep_allowance',
 nextScreenBuilder: () => nextScreen,
 dataUpdater: (data) => data.copyWith(
 frontEndPlanning: ProjectDataHelper.updateFEPField(
 current: data.frontEndPlanning,
 allowance: _notes.text,
 allowanceItems: _allowanceItems,
 ),
 ),
 );
 }

 Future<void> _showItemDialog({AllowanceItem? item}) async {
 final isEditing = item != null;
 final nameController = TextEditingController(text: item?.name ?? '');
 final descriptionController =
 TextEditingController(text: item?.description ?? '');
 final amountController =
 TextEditingController(text: item?.amount.toString() ?? '0');
 final estimatedCostOrQtyController = TextEditingController(
 text: item?.estimatedCostOrQuantity.isNotEmpty == true
 ? item!.estimatedCostOrQuantity
 : (item != null && item.amount > 0
 ? '\$${item.amount.toStringAsFixed(0)}'
 : ''),
 );
 final scheduleImpactController =
 TextEditingController(text: item?.scheduleImpact ?? '');
 final scheduleImpactWeeksController = TextEditingController(
 text: item != null && item.scheduleImpactWeeks > 0
 ? item.scheduleImpactWeeks.toStringAsFixed(1)
 : '',
 );
 final responsibleDisciplineController =
 TextEditingController(text: item?.responsibleDiscipline ?? '');
 final assumptionsController =
 TextEditingController(text: item?.assumptions ?? '');
 final appliesToController =
 TextEditingController(text: item?.appliesTo.join(', ') ?? '');
 final assignedToController =
 TextEditingController(text: item?.assignedTo ?? '');
 final notesController = TextEditingController(text: item?.notes ?? '');
 final triggerContextController =
 TextEditingController(text: item?.triggerContext ?? '');
 String selectedType = item?.type ?? 'Contingency';
 String releaseStatus = item?.releaseStatus ?? 'Reserved';
 final releasedAmountController = TextEditingController(
 text: item != null ? item.releasedAmount.toString() : '0',
 );
 final actualAmountController = TextEditingController(
 text: item != null ? item.actualAmount.toString() : '0',
 );

 InputDecoration fieldDecoration({
 required String hintText,
 String? prefixText,
 }) {
 const borderColor = Color(0xFFD1D5DB);
 return InputDecoration(
 hintText: hintText,
 prefixText: prefixText,
 prefixStyle: const TextStyle(color: Color(0xFF374151), fontSize: 20),
 filled: true,
 fillColor: const Color(0xFFF8FAFC),
 isDense: true,
 contentPadding:
 const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
 enabledBorder: OutlineInputBorder(
 borderRadius: BorderRadius.circular(12),
 borderSide: const BorderSide(color: borderColor),
 ),
 focusedBorder: OutlineInputBorder(
 borderRadius: BorderRadius.circular(12),
 borderSide: const BorderSide(color: Color(0xFF3B82F6), width: 1.2),
 ),
 );
 }

 Widget fieldLabel(String text) {
 return Padding(
 padding: const EdgeInsets.only(bottom: 6),
 child: Text(
 text,
 style: const TextStyle(
 fontSize: 12,
 fontWeight: FontWeight.w600,
 color: Color(0xFF374151),
 ),
 ),
 );
 }

 final result = await showDialog<bool>(
 context: context,
 builder: (dialogContext) => StatefulBuilder(
 builder: (dialogContext, setDialogState) => AlertDialog(
 insetPadding:
 const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
 shape:
 RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
 titlePadding:
 const EdgeInsets.only(left: 24, right: 24, top: 20, bottom: 8),
 contentPadding:
 const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
 actionsPadding:
 const EdgeInsets.only(left: 20, right: 20, bottom: 18, top: 8),
 title: Text(
 isEditing ? 'Edit Allowance' : 'Add Allowance',
 style: const TextStyle(
 fontSize: 20,
 fontWeight: FontWeight.w700,
 color: Color(0xFF0F172A),
 ),
 ),
 content: ConstrainedBox(
 constraints: BoxConstraints(
 maxWidth: 560,
 maxHeight: MediaQuery.of(dialogContext).size.height * 0.78,
 ),
 child: SingleChildScrollView(
 child: Column(
 mainAxisSize: MainAxisSize.min,
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 fieldLabel('Allowance Description *'),
 VoiceTextField(
 controller: descriptionController,
 decoration: fieldDecoration(
 hintText:
 'e.g. Hurricane schedule contingency for Gulf Coast construction'),
 ),
 const SizedBox(height: 12),
 fieldLabel('Name (short label)'),
 VoiceTextField(
 controller: nameController,
 decoration: fieldDecoration(hintText: 'Allowance name'),
 ),
 const SizedBox(height: 12),
 fieldLabel('Type'),
 DropdownButtonFormField<String>(
 value: selectedType,
 isExpanded: true,
 decoration: fieldDecoration(hintText: 'Select type'),
 items: const [
 'Contingency',
 'Training',
 'Staffing',
 'Tech',
 'Other'
 ]
 .map((t) => DropdownMenuItem(value: t, child: Text(t)))
 .toList(),
 onChanged: (val) {
 if (val == null) return;
 setDialogState(() => selectedType = val);
 },
 ),
 const SizedBox(height: 12),
 Row(
 children: [
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 fieldLabel('Estimated Cost (\$)'),
 VoiceTextField(
 controller: amountController,
 keyboardType:
 const TextInputType.numberWithOptions(decimal: true),
 decoration: fieldDecoration(
 hintText: '0', prefixText: '\$'),
 ),
 ],
 ),
 ),
 const SizedBox(width: 12),
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 fieldLabel('Estimated Cost / Quantity (text)'),
 VoiceTextField(
 controller: estimatedCostOrQtyController,
 decoration: fieldDecoration(
 hintText: '\$50,000 / 10% / 200 hrs'),
 ),
 ],
 ),
 ),
 ],
 ),
 const SizedBox(height: 12),
 Row(
 children: [
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 fieldLabel('Schedule Impact (text)'),
 VoiceTextField(
 controller: scheduleImpactController,
 decoration: fieldDecoration(
 hintText:
 'e.g. Adds 2 weeks to commissioning'),
 ),
 ],
 ),
 ),
 const SizedBox(width: 12),
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 fieldLabel('Schedule Impact (weeks)'),
 VoiceTextField(
 controller: scheduleImpactWeeksController,
 keyboardType:
 const TextInputType.numberWithOptions(decimal: true),
 decoration: fieldDecoration(hintText: '0'),
 ),
 ],
 ),
 ),
 ],
 ),
 const SizedBox(height: 12),
 fieldLabel('Responsible Discipline'),
 VoiceTextField(
 controller: responsibleDisciplineController,
 decoration: fieldDecoration(
 hintText:
 'e.g. Project Controls, Procurement, Civil'),
 ),
 const SizedBox(height: 12),
 fieldLabel('Trigger Context (auto / regional)'),
 VoiceTextField(
 controller: triggerContextController,
 decoration: fieldDecoration(
 hintText:
 'e.g. Hurricane exposure — Gulf Coast US'),
 ),
 const SizedBox(height: 12),
 fieldLabel('Assumptions'),
 VoiceTextField(
 controller: assumptionsController,
 maxLines: 3,
 decoration: fieldDecoration(
 hintText: 'Assumptions underpinning this allowance'),
 ),
 const SizedBox(height: 12),
 fieldLabel('Release Status'),
 DropdownButtonFormField<String>(
 value: releaseStatus,
 isExpanded: true,
 decoration: fieldDecoration(hintText: 'Select status'),
 items: const [
 'Reserved',
 'Partially Released',
 'Released',
 'Consumed',
 'Closed',
 ]
 .map((t) => DropdownMenuItem(value: t, child: Text(t)))
 .toList(),
 onChanged: (val) {
 if (val == null) return;
 setDialogState(() => releaseStatus = val);
 },
 ),
 const SizedBox(height: 12),
 Row(
 children: [
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 fieldLabel('Released Amount'),
 VoiceTextField(
 controller: releasedAmountController,
 keyboardType:
 const TextInputType.numberWithOptions(
 decimal: true,
 ),
 decoration: fieldDecoration(
 hintText: '0', prefixText: '\$'),
 ),
 ],
 ),
 ),
 const SizedBox(width: 12),
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 fieldLabel('Actual Amount'),
 VoiceTextField(
 controller: actualAmountController,
 keyboardType:
 const TextInputType.numberWithOptions(
 decimal: true,
 ),
 decoration: fieldDecoration(
 hintText: '0', prefixText: '\$'),
 ),
 ],
 ),
 ),
 ],
 ),
 const SizedBox(height: 12),
 fieldLabel('Applies To'),
 VoiceTextField(
 controller: appliesToController,
 decoration: fieldDecoration(
 hintText: 'Estimate, Schedule, Training'),
 ),
 const SizedBox(height: 12),
 fieldLabel('Assigned To'),
 VoiceTextField(
 controller: assignedToController,
 decoration:
 fieldDecoration(hintText: 'Role or person name'),
 ),
 const SizedBox(height: 12),
 fieldLabel('Notes'),
 VoiceTextField(
 controller: notesController,
 maxLines: 4,
 decoration:
 fieldDecoration(hintText: 'Context or assumptions'),
 ),
 ],
 ),
 ),
 ),
 actions: [
 TextButton(
 onPressed: () => Navigator.pop(dialogContext, false),
 child: const Text(
 'Cancel',
 style: TextStyle(
 fontWeight: FontWeight.w600,
 color: Color(0xFF2563EB),
 ),
 ),
 ),
 ElevatedButton(
 onPressed: () => Navigator.pop(dialogContext, true),
 style: ElevatedButton.styleFrom(
 backgroundColor: const Color(0xFFFFC812),
 foregroundColor: Colors.black,
 elevation: 0,
 padding:
 const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
 shape: RoundedRectangleBorder(
 borderRadius: BorderRadius.circular(999)),
 ),
 child: const Text(
 'Save',
 style: TextStyle(fontWeight: FontWeight.w700),
 ),
 ),
 ],
 ),
 ),
 );

 if (result == true) {
 final description = descriptionController.text.trim();
 final name = nameController.text.trim().isNotEmpty
 ? nameController.text.trim()
 : description;
 if (name.isEmpty) return;

 final amount =
 double.tryParse(amountController.text.replaceAll(',', '')) ?? 0.0;
 final releasedAmount =
 double.tryParse(releasedAmountController.text.replaceAll(',', '')) ??
 0.0;
 final actualAmount =
 double.tryParse(actualAmountController.text.replaceAll(',', '')) ??
 0.0;
 final scheduleImpactWeeks =
 double.tryParse(scheduleImpactWeeksController.text.replaceAll(',', '')) ??
 0.0;
 final appliesTo = appliesToController.text
 .split(',')
 .map((e) => e.trim())
 .where((e) => e.isNotEmpty)
 .toList();

 final newItem = AllowanceItem(
 id: item?.id ?? '${DateTime.now().microsecondsSinceEpoch}_${_allowanceItems.length}',
 number: item?.number ?? (_allowanceItems.length + 1),
 name: name,
 description: description,
 type: selectedType,
 amount: amount,
 estimatedCostOrQuantity: estimatedCostOrQtyController.text.trim(),
 scheduleImpact: scheduleImpactController.text.trim(),
 scheduleImpactWeeks: scheduleImpactWeeks,
 responsibleDiscipline: responsibleDisciplineController.text.trim(),
 assumptions: assumptionsController.text.trim(),
 triggerContext: triggerContextController.text.trim(),
 appliesTo: appliesTo,
 assignedTo: assignedToController.text.trim(),
 notes: notesController.text.trim(),
 releaseStatus: releaseStatus,
 releasedAmount: releasedAmount,
 actualAmount: actualAmount,
 );

 final editingItemId = item?.id;
 setState(() {
 if (isEditing && editingItemId != null) {
 final index =
 _allowanceItems.indexWhere((i) => i.id == editingItemId);
 if (index != -1) _allowanceItems[index] = newItem;
 } else if (!isEditing) {
 _allowanceItems.add(newItem);
 }
 });
 _syncItemsToProvider();
 }
 }

 Widget _buildCostSummary(
 ProjectDataModel projectData, CostAnalysisData costData) {
 // 1. Correctly identify the preferred solution
 final preferredId = projectData.preferredSolutionId;
 final preferredSolution = projectData.potentialSolutions.firstWhere(
 (s) => s.id == preferredId,
 orElse: () => PotentialSolution.empty(id: 'empty', number: 0));

 // 2. Find cost data for that solution title
 final solutionCost = costData.solutionCosts.firstWhere(
 (s) => s.solutionTitle == preferredSolution.title,
 orElse: () => SolutionCostData(),
 );

 // 3. Calculate total
 double totalCost = 0.0;
 for (final row in solutionCost.costRows) {
 // Clean string currency to double
 final clean = row.cost.replaceAll(RegExp(r'[^0-9.]'), '');
 totalCost += double.tryParse(clean) ?? 0.0;
 }

 final hasPreferred =
 preferredId != null && preferredSolution.title.isNotEmpty;
 final formatter = NumberFormat.simpleCurrency(decimalDigits: 0);

 return Wrap(
 spacing: 24,
 runSpacing: 12,
 children: [
 if (hasPreferred)
 _CostMetaItem(
 label: 'Preferred Solution',
 value: preferredSolution.title,
 isHighlight: true,
 ),
 _CostMetaItem(
 label: 'Est. Total Cost',
 value: hasPreferred ? formatter.format(totalCost) : '--',
 ),
 _CostMetaItem(
 label: 'Total Budget',
 value: costData.projectValueAmount.isEmpty
 ? '--'
 : '\$${costData.projectValueAmount}'),
 ],
 );
 }

 Widget _buildAllowanceItemCard(AllowanceItem item) {
 final formatter = NumberFormat.simpleCurrency(decimalDigits: 0);
 return Container(
 padding: const EdgeInsets.all(16),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(12),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 boxShadow: [
 BoxShadow(
 color: Colors.black.withOpacity(0.02),
 blurRadius: 4,
 offset: const Offset(0, 2),
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
 padding: const EdgeInsets.all(10),
 decoration: BoxDecoration(
 color: const Color(0xFFEFF6FF),
 borderRadius: BorderRadius.circular(8),
 ),
 child: const Icon(Icons.monetization_on_outlined,
 color: Color(0xFF2563EB), size: 24),
 ),
 const SizedBox(width: 16),
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 children: [
 Expanded(
 child: Text(
 item.name,
 style: const TextStyle(
 fontWeight: FontWeight.w700, fontSize: 16),
 ),
 ),
 const SizedBox(width: 8),
 Container(
 padding: const EdgeInsets.symmetric(
 horizontal: 8, vertical: 2),
 decoration: BoxDecoration(
 color: const Color(0xFFF3F4F6),
 borderRadius: BorderRadius.circular(4),
 ),
 child: Text(
 item.type,
 style: const TextStyle(
 fontSize: 12,
 fontWeight: FontWeight.w500,
 color: Color(0xFF4B5563)),
 ),
 ),
 const SizedBox(width: 8),
 Text(
 formatter.format(item.amount),
 style: const TextStyle(
 fontWeight: FontWeight.w700,
 fontSize: 16,
 color: Color(0xFF059669)),
 ),
 ],
 ),
 if (item.description.isNotEmpty && item.description != item.name) ...[
 const SizedBox(height: 6),
 Text(
 item.description,
 style: const TextStyle(
 fontSize: 13, color: Color(0xFF4B5563)),
 maxLines: 2,
 overflow: TextOverflow.ellipsis,
 ),
 ],
 // New: Estimated Cost / Quantity + Schedule Impact
 const SizedBox(height: 8),
 Wrap(
 spacing: 12,
 runSpacing: 6,
 children: [
 if (item.estimatedCostOrQuantity.isNotEmpty)
 _detailChip(
 icon: Icons.attach_money_outlined,
 label: 'Est: ${item.estimatedCostOrQuantity}',
 color: const Color(0xFF059669),
 ),
 if (item.scheduleImpact.isNotEmpty ||
 item.scheduleImpactWeeks > 0)
 _detailChip(
 icon: Icons.schedule_outlined,
 label: item.scheduleImpactWeeks > 0
 ? 'Schedule: ${item.scheduleImpactWeeks.toStringAsFixed(item.scheduleImpactWeeks.truncateToDouble() == item.scheduleImpactWeeks ? 0 : 1)} wk'
 '${item.scheduleImpact.isNotEmpty ? ' — ${item.scheduleImpact}' : ''}'
 : 'Schedule: ${item.scheduleImpact}',
 color: const Color(0xFFD97706),
 ),
 if (item.responsibleDiscipline.isNotEmpty)
 _detailChip(
 icon: Icons.engineering_outlined,
 label: item.responsibleDiscipline,
 color: const Color(0xFF2563EB),
 ),
 if (item.triggerContext.isNotEmpty)
 _detailChip(
 icon: Icons.public_outlined,
 label: item.triggerContext,
 color: const Color(0xFF7C3AED),
 ),
 ],
 ),
 if (item.assignedTo.isNotEmpty) ...[
 const SizedBox(height: 6),
 Row(
 children: [
 const Icon(Icons.person_outline,
 size: 14, color: Color(0xFF6B7280)),
 const SizedBox(width: 4),
 Text(
 item.assignedTo,
 style: const TextStyle(
 fontSize: 12,
 fontWeight: FontWeight.w600,
 color: Color(0xFF374151)),
 ),
 ],
 ),
 ],
 if (item.assumptions.isNotEmpty) ...[
 const SizedBox(height: 6),
 Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 const Icon(Icons.lightbulb_outline,
 size: 14, color: Color(0xFF6B7280)),
 const SizedBox(width: 4),
 Expanded(
 child: Text(
 'Assumptions: ${item.assumptions}',
 style: const TextStyle(
 fontSize: 12, color: Color(0xFF4B5563)),
 maxLines: 2,
 overflow: TextOverflow.ellipsis,
 ),
 ),
 ],
 ),
 ],
 if (item.notes.isNotEmpty) ...[
 const SizedBox(height: 4),
 Text(
 item.notes,
 style: const TextStyle(
 fontSize: 14, color: Color(0xFF4B5563)),
 maxLines: 2,
 overflow: TextOverflow.ellipsis,
 ),
 ],
 ],
 ),
 ),
 const SizedBox(width: 12),
 GestureDetector(
 onTapDown: (details) {
 showMenu(
 context: context,
 position: RelativeRect.fromLTRB(
 details.globalPosition.dx,
 details.globalPosition.dy,
 details.globalPosition.dx,
 details.globalPosition.dy,
 ),
 items: [
 PopupMenuItem(
 child: const Text('Edit'),
 onTap: () => Future.delayed(
 Duration.zero,
 () => _editItem(item),
 ),
 ),
 PopupMenuItem(
 child: const Text('Delete',
 style: TextStyle(color: Colors.red)),
 onTap: () => Future.delayed(
 Duration.zero,
 () => _deleteItem(item.id),
 ),
 ),
 ],
 );
 },
 child: const Icon(Icons.more_vert,
 size: 20, color: Color(0xFF9CA3AF)),
 ),
 ],
 ),
 const SizedBox(height: 12),
 const Divider(height: 1, color: Color(0xFFF3F4F6)),
 const SizedBox(height: 12),
 Row(
 children: [
 Container(
 padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
 decoration: BoxDecoration(
 color: const Color(0xFFF8FAFC),
 borderRadius: BorderRadius.circular(999),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 ),
 child: Text(
 item.releaseStatus,
 style: const TextStyle(
 fontSize: 12,
 fontWeight: FontWeight.w600,
 color: Color(0xFF4B5563),
 ),
 ),
 ),
 const SizedBox(width: 12),
 Text(
 'Released ${formatter.format(item.releasedAmount)}',
 style: const TextStyle(
 fontSize: 12,
 color: Color(0xFF6B7280),
 ),
 ),
 const SizedBox(width: 12),
 Text(
 'Actual ${formatter.format(item.actualAmount)}',
 style: const TextStyle(
 fontSize: 12,
 color: Color(0xFF6B7280),
 ),
 ),
 ],
 ),
 const SizedBox(height: 12),
 Row(
 children: [
 const Text(
 'Apply to:',
 style: TextStyle(
 fontSize: 12,
 fontWeight: FontWeight.w500,
 color: Color(0xFF6B7280)),
 ),
 const SizedBox(width: 8),
 Wrap(
 spacing: 8,
 children: [
 _ApplyChip(
 label: 'Estimate',
 isActive: item.appliesTo.contains('Estimate'),
 onToggle: (isActive) =>
 _toggleApply(item, 'Estimate', isActive),
 ),
 _ApplyChip(
 label: 'Training',
 isActive: item.appliesTo.contains('Training'),
 onToggle: (isActive) =>
 _toggleApply(item, 'Training', isActive),
 ),
 _ApplyChip(
 label: 'Schedule',
 isActive: item.appliesTo.contains('Schedule'),
 onToggle: (isActive) =>
 _toggleApply(item, 'Schedule', isActive),
 ),
 ],
 ),
 ],
 ),
 ],
 ),
 );
 }

 Widget _detailChip({
 required IconData icon,
 required String label,
 required Color color,
 }) {
 return Container(
 padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
 decoration: BoxDecoration(
 color: color.withOpacity(0.08),
 borderRadius: BorderRadius.circular(6),
 border: Border.all(color: color.withOpacity(0.25)),
 ),
 child: Row(
 mainAxisSize: MainAxisSize.min,
 children: [
 Icon(icon, size: 12, color: color),
 const SizedBox(width: 4),
 Text(
 label,
 style: TextStyle(
 fontSize: 11,
 fontWeight: FontWeight.w600,
 color: color,
 ),
 ),
 ],
 ),
 );
 }

 void _toggleApply(AllowanceItem item, String tag, bool isActive) {
 setState(() {
 if (isActive) {
 if (!item.appliesTo.contains(tag)) {
 item.appliesTo.add(tag);
 }
 } else {
 item.appliesTo.remove(tag);
 }
 });
 _syncItemsToProvider();
 }

 @override
 Widget build(BuildContext context) {
 final projectData = ProjectDataHelper.getData(context, listen: true);
 final costData = projectData.costAnalysisData;

 return Scaffold(
 backgroundColor: Colors.white,
 body: SafeArea(
 child: Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 DraggableSidebar(
 openWidth: AppBreakpoints.sidebarWidth(context),
 child: const InitiationLikeSidebar(activeItemLabel: 'Allowance'),
 ),
 Expanded(
 child: Stack(
 children: [
 const AdminEditToggle(),
 Column(
 children: [
 FrontEndPlanningHeader(onExportPdf: _exportPdf),
 Expanded(
 child: SingleChildScrollView(
 padding: const EdgeInsets.symmetric(
 horizontal: 32, vertical: 24),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 // Cost Details Container (Blue)
 Container(
 width: double.infinity,
 padding: const EdgeInsets.all(20),
 decoration: BoxDecoration(
 color: const Color(0xFFEFF6FF),
 borderRadius: BorderRadius.circular(12),
 border: Border.all(
 color: const Color(0xFFBFDBFE)),
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 children: [
 const Icon(Icons.analytics_outlined,
 color: Color(0xFF1E40AF)),
 const SizedBox(width: 12),
 const Text(
 'Cost Details from Cost Basis Analysis',
 style: TextStyle(
 fontSize: 16,
 fontWeight: FontWeight.w700,
 color: Color(0xFF1E3A8A),
 ),
 ),
 if (costData == null) ...[
 const Spacer(),
 const Text(
 '(No analysis data yet)',
 style: TextStyle(
 color: Color(0xFF6B7280),
 fontSize: 13,
 fontStyle: FontStyle.italic),
 )
 ],
 ],
 ),
 if (costData != null) ...[
 const SizedBox(height: 16),
 _buildCostSummary(projectData, costData),
 ],
 ],
 ),
 ),
 const SizedBox(height: 24),

 const Text('Allowance',
 style: TextStyle(
 fontWeight: FontWeight.w700,
 fontSize: 20,
 color: Color(0xFF111827))),
 const SizedBox(height: 8),
 const Text(
 'Predefined provisions for uncertain or variable elements, such as cost, time, or resources, set aside to accommodate expected variability without changing the approved scope.',
 style: TextStyle(
 fontSize: 14, color: Color(0xFF6B7280)),
 ),
 const SizedBox(height: 16),
 _roundedField(
 controller: _notes,
 hint: 'Input your notes here...',
 minLines: 3),
 const SizedBox(height: 32),

 // Header Row
 Row(
 mainAxisAlignment:
 MainAxisAlignment.spaceBetween,
 children: [
 const Column(
 crossAxisAlignment:
 CrossAxisAlignment.start,
 children: [
 Text(
 'Allowance & Contingency Items',
 style: TextStyle(
 fontSize: 18,
 fontWeight: FontWeight.w700,
 color: Color(0xFF111827),
 ),
 ),
 ],
 ),
 Row(
 children: [
 PageRegenerateAllButton(
 onRegenerateAll: () async {
 final confirmed =
 await showRegenerateAllConfirmation(
 context);
 if (confirmed && mounted) {
 await _generateDefaultAllowances();
 }
 },
 isLoading: _isGenerating,
 tooltip:
 'Generate suggested allowances',
 ),
 const SizedBox(width: 12),
 ElevatedButton.icon(
 onPressed: _addItem,
 icon: const Icon(Icons.add, size: 18),
 label: const Text('Add Item'),
 style: ElevatedButton.styleFrom(
 backgroundColor: Colors.black,
 foregroundColor: Colors.white,
 padding: const EdgeInsets.symmetric(
 horizontal: 16, vertical: 12),
 shape: RoundedRectangleBorder(
 borderRadius:
 BorderRadius.circular(8)),
 ),
 ),
 ],
 ),
 ],
 ),
 const SizedBox(height: 18),

 // List of Items
 if (_allowanceItems.isEmpty)
 Container(
 width: double.infinity,
 padding: const EdgeInsets.all(32),
 decoration: BoxDecoration(
 color: const Color(0xFFF9FAFB),
 borderRadius: BorderRadius.circular(12),
 border: Border.all(
 color: const Color(0xFFE5E7EB),
 style: BorderStyle.solid),
 ),
 child: const Center(
 child: Text(
 'No allowance items added yet.\nClick "Add Item" or "Generate" to start.',
 textAlign: TextAlign.center,
 style:
 TextStyle(color: Color(0xFF9CA3AF)),
 ),
 ),
 )
 else
 ListView.separated(
 physics: const NeverScrollableScrollPhysics(),
 shrinkWrap: true,
 itemCount: _allowanceItems.length,
 separatorBuilder: (_, __) =>
 const SizedBox(height: 12),
 itemBuilder: (context, index) {
 final item = _allowanceItems[index];
 return _buildAllowanceItemCard(item);
 },
 ),

 const SizedBox(height: 140),
 ],
 ),
 ),
 ),
 ],
 ),
 _BottomOverlay(
 onBack: _goToPreviousStep,
 onNext: () {
 _saveAndNavigateToNextStep();
 },
 ),
 MobileSidebarHamburger(
 sidebar: const InitiationLikeSidebar(
 activeItemLabel: 'Allowance',
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
}

class _ApplyChip extends StatelessWidget {
 final String label;
 final bool isActive;
 final ValueChanged<bool> onToggle;

 const _ApplyChip({
 required this.label,
 required this.isActive,
 required this.onToggle,
 });

 @override
 Widget build(BuildContext context) {
 return InkWell(
 onTap: () => onToggle(!isActive),
 borderRadius: BorderRadius.circular(16),
 child: Container(
 padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
 decoration: BoxDecoration(
 color: isActive ? const Color(0xFFEFF6FF) : Colors.white,
 borderRadius: BorderRadius.circular(16),
 border: Border.all(
 color: isActive ? const Color(0xFF3B82F6) : const Color(0xFFD1D5DB),
 ),
 ),
 child: Row(
 mainAxisSize: MainAxisSize.min,
 children: [
 if (isActive) ...[
 const Icon(Icons.check, size: 12, color: Color(0xFF3B82F6)),
 const SizedBox(width: 4),
 ],
 Text(
 label,
 style: TextStyle(
 fontSize: 12,
 fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
 color: isActive
 ? const Color(0xFF1E40AF)
 : const Color(0xFF374151),
 ),
 ),
 ],
 ),
 ),
 );
 }
}

class _CostMetaItem extends StatelessWidget {
 final String label;
 final String value;
 final bool isHighlight;

 const _CostMetaItem(
 {required this.label, required this.value, this.isHighlight = false});

 @override
 Widget build(BuildContext context) {
 return Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 label.toUpperCase(),
 style: const TextStyle(
 fontSize: 11,
 fontWeight: FontWeight.w600,
 color: Color(0xFF6B7280),
 letterSpacing: 0.5,
 ),
 ),
 const SizedBox(height: 4),
 Text(
 value,
 style: TextStyle(
 fontSize: 16,
 fontWeight: FontWeight.w600,
 color: isHighlight ? const Color(0xFF1E3A8A) : Colors.black87,
 ),
 ),
 ],
 );
 }
}

class _BottomOverlay extends StatefulWidget {
 final VoidCallback onBack;
 final VoidCallback onNext;

 const _BottomOverlay({required this.onBack, required this.onNext});

 @override
 State<_BottomOverlay> createState() => _BottomOverlayState();
}

class _BottomOverlayState extends State<_BottomOverlay> {
 bool _bannerDismissed = false;

 @override
 Widget build(BuildContext context) {
 return Stack(
 children: [
 Positioned(
 left: 24,
 bottom: 24,
 child: Container(
 width: 48,
 height: 48,
 decoration: const BoxDecoration(
 color: Color(0xFFB3D9FF), shape: BoxShape.circle),
 child: const Icon(Icons.info_outline, color: Colors.white),
 ),
 ),
 Positioned(
 right: 24,
 bottom: 24,
 child: Row(
 children: [
 if (!_bannerDismissed)
 Container(
 padding: const EdgeInsets.symmetric(
 horizontal: 18, vertical: 16),
 decoration: BoxDecoration(
 color: const Color(0xFFE6F1FF),
 borderRadius: BorderRadius.circular(14),
 border: Border.all(color: const Color(0xFFD7E5FF)),
 ),
 child: Row(
 mainAxisSize: MainAxisSize.min,
 children: [
 const Icon(Icons.auto_awesome, color: Color(0xFF2563EB)),
 const SizedBox(width: 10),
 const Text('AI',
 style: TextStyle(
 fontWeight: FontWeight.w800,
 color: Color(0xFF2563EB))),
 const SizedBox(width: 12),
 const Text(
 'Define budget allowances and contingency plans.',
 style: TextStyle(color: Color(0xFF1F2937)),
 ),
 const SizedBox(width: 8),
 Tooltip(
 message: 'Close banner',
 child: InkWell(
 onTap: () => setState(() => _bannerDismissed = true),
 borderRadius: BorderRadius.circular(12),
 child: const Padding(
 padding: EdgeInsets.all(4),
 child: Icon(
 Icons.close,
 size: 16,
 color: Color(0xFF6B7280),
 ),
 ),
 ),
 ),
 ],
 ),
 ),
 const SizedBox(width: 16),
 OutlinedButton(
 onPressed: widget.onBack,
 style: OutlinedButton.styleFrom(
 foregroundColor: const Color(0xFF374151),
 side: const BorderSide(color: Color(0xFFD1D5DB)),
 padding: const EdgeInsets.symmetric(
 horizontal: 22, vertical: 16),
 shape: RoundedRectangleBorder(
 borderRadius: BorderRadius.circular(22)),
 ),
 child: const Text(
 'Back',
 style: TextStyle(
 fontSize: 15, fontWeight: FontWeight.w700),
 ),
 ),
 const SizedBox(width: 12),
 ElevatedButton(
 onPressed: widget.onNext,
 style: ElevatedButton.styleFrom(
 backgroundColor: const Color(0xFFFFC812),
 foregroundColor: const Color(0xFF111827),
 padding: const EdgeInsets.symmetric(
 horizontal: 34, vertical: 16),
 shape: RoundedRectangleBorder(
 borderRadius: BorderRadius.circular(22)),
 elevation: 0,
 ),
 child: const Text('Next',
 style: TextStyle(
 fontSize: 16, fontWeight: FontWeight.w700)),
 ),
 ],
 ),
 ),
 ],
 );
 }
}

Widget _roundedField(
 {required TextEditingController controller,
 required String hint,
 int minLines = 1}) {
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
