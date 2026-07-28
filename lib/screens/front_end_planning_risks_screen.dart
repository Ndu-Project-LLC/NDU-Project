import 'package:flutter/material.dart';
import 'package:ndu_project/screens/front_end_planning_opportunities_screen.dart';
import 'package:ndu_project/widgets/draggable_sidebar.dart';
import 'package:ndu_project/widgets/initiation_like_sidebar.dart';
import 'package:ndu_project/widgets/responsive.dart';
import 'package:ndu_project/widgets/kaz_ai_chat_bubble.dart';
import 'package:ndu_project/services/openai_service_secure.dart';
import 'package:ndu_project/utils/project_data_helper.dart';
import 'package:ndu_project/utils/form_validation_engine.dart';
import 'package:ndu_project/utils/front_end_planning_navigation.dart';
import 'package:ndu_project/models/project_data_model.dart';
import 'package:ndu_project/widgets/content_text.dart';
import 'package:ndu_project/widgets/admin_edit_toggle.dart';
import 'package:ndu_project/widgets/front_end_planning_header.dart';
import 'package:ndu_project/widgets/page_regenerate_all_button.dart';
import 'package:ndu_project/widgets/delete_confirmation_dialog.dart';

import 'package:ndu_project/widgets/voice_text_field.dart';
import 'package:ndu_project/utils/pdf_export_helper.dart';
/// Front End Planning – Project Risks page
/// Matches the provided screenshot with:
/// - Top bar (back/forward, centered title, user chip)
/// - Notes field
/// - "Project Risks (Highlight and quantify known and/or anticipated risks here)" title
/// - Table with columns: Risk | Project | Category | Probability | Impact | Risk Level | Status | Ac
/// - Bottom-left info circle, bottom-right AI hint and yellow Next button
class FrontEndPlanningRisksScreen extends StatefulWidget {
 const FrontEndPlanningRisksScreen({super.key});

 static void open(BuildContext context) {
 Navigator.of(context).push(
 MaterialPageRoute(builder: (_) => const FrontEndPlanningRisksScreen()),
 );
 }

 @override
 State<FrontEndPlanningRisksScreen> createState() =>
 _FrontEndPlanningRisksScreenState();
}

class _FrontEndPlanningRisksScreenState
 extends State<FrontEndPlanningRisksScreen> {
 final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
 final GlobalKey _riskTableKey = GlobalKey();
 final TextEditingController _notesController = TextEditingController();
 bool _isSyncReady = false;
 bool _isApplyingNotesSummary = false;
 bool _hasShownDueDiligencePrompt = false;
 bool _autoGenerationTriggered = false;
 bool _riskTableHasError = false;
 String? _riskTableErrorText;

 // Backing rows for the table; built from incoming requirements (if any).
 late List<_RiskItem> _rows;
 bool _isGeneratingRequirements = false;

 @override
 void initState() {
 super.initState();
 _rows = [];
 WidgetsBinding.instance.addPostFrameCallback((_) {
 final projectData = ProjectDataHelper.getData(context);
 _notesController.text =
 _summarizeNotesText(projectData.frontEndPlanning.risks);
 _notesController.addListener(_syncRisksToProvider);
 _isSyncReady = true;
 _loadSavedRisks(projectData);
 _syncRisksToProvider();
 _triggerAutoRiskGenerationIfMissing();
 _showDueDiligencePromptIfNeeded();

 if (mounted) setState(() {});
 });
 }

 
 Future<void> _exportPdf() async {
 final projectData = ProjectDataHelper.getData(context);
 final fep = projectData.frontEndPlanning;
 await PdfExportHelper.exportScreenPdf(
 context: context,
 screenTitle: 'Risks',
 sections: [
 PdfSection.keyValue('Project Info', [
 {'Project Name': projectData.projectName ?? 'N/A'},
 ]),
 PdfSection.text('Notes', fep.requirementsNotes ?? 'No data recorded.'),
 ],
 );
 }
bool get _hasAnyDefinedRisk => _rows.any((row) => row.risk.trim().isNotEmpty);

 Future<void> _triggerAutoRiskGenerationIfMissing() async {
 if (_autoGenerationTriggered || _isGeneratingRequirements || !mounted) {
 return;
 }
 if (_hasAnyDefinedRisk) return;
 _autoGenerationTriggered = true;
 await _generateRequirementsFromBusinessCase();
 }

 void _loadSavedRisks(ProjectDataModel data) {
 final savedRegister = data.frontEndPlanning.riskRegisterItems;
 if (savedRegister.isNotEmpty) {
 _rows = savedRegister.asMap().entries.map((entry) {
 final item = entry.value;
 return _RiskItem(
 id: _generateId(entry.key + 1),
 requirement: item.requirement,
 requirementType: item.requirementType,
 risk: item.riskName,
 description: item.description,
 category: item.category,
 probability: item.likelihood,
 impact: item.impactLevel,
 riskValue: '',
 riskLevel: _deriveRiskLevel(item.likelihood, item.impactLevel),
 mitigation: item.mitigationStrategy,
 discipline: item.discipline,
 projectRole: item.projectRole,
 owner: item.owner,
 status: item.status.isNotEmpty ? item.status : 'Identified',
 );
 }).toList();
 return;
 }

 final preferredRiskSeeds = _findPreferredSolutionRiskSeeds(data);
 if (preferredRiskSeeds.isNotEmpty) {
 _rows = preferredRiskSeeds.asMap().entries.map((entry) {
 final riskSeed = entry.value;
 return _RiskItem(
 id: _generateId(entry.key + 1),
 requirement: '',
 requirementType: '',
 risk: riskSeed,
 description: riskSeed,
 category: 'Operational',
 probability: 'Medium',
 impact: 'Medium',
 riskValue: '',
 riskLevel: 'Medium',
 mitigation:
 'Assign an owner, define mitigation actions, and monitor early warning indicators.',
 discipline: 'Risk Management',
 projectRole: 'Project Manager',
 owner: '',
 status: 'Identified',
 );
 }).toList();
 return;
 }

 final requirements = data.frontEndPlanning.requirementItems;
 if (requirements.isNotEmpty) {
 _rows = requirements.asMap().entries.map((entry) {
 final req = entry.value;
 return _RiskItem(
 id: _generateId(entry.key + 1),
 requirement: req.description,
 requirementType: req.requirementType,
 risk: '',
 description: '',
 category: '',
 probability: '',
 impact: '',
 riskValue: '',
 riskLevel: '',
 mitigation: '',
 discipline: '',
 projectRole: req.role.trim(),
 owner: req.person.trim(),
 status: 'Identified',
 );
 }).toList();
 }
 }

 Future<void> _showDueDiligencePromptIfNeeded() async {
 if (!mounted || _hasShownDueDiligencePrompt) return;
 _hasShownDueDiligencePrompt = true;
 await showDialog<void>(
 context: context,
 builder: (context) => AlertDialog(
 title: const Text('Risk Collaboration Reminder'),
 content: const Text(
 'Please engage project team members and subject matter experts in the risk identification, ranking, and mitigation process to ensure thorough due diligence.',
 ),
 actions: [
 TextButton(
 onPressed: () => Navigator.pop(context),
 child: const Text('OK'),
 ),
 ],
 ),
 );
 }

 String _resolvePreferredSolutionTitle(ProjectDataModel data) {
 final preferred = data.preferredSolutionAnalysis;
 final directTitle = preferred?.selectedSolutionTitle?.trim() ?? '';
 if (directTitle.isNotEmpty) return directTitle;

 final preferredIndex = preferred?.selectedSolutionIndex;
 if (preferredIndex != null &&
 preferredIndex >= 0 &&
 preferredIndex < data.potentialSolutions.length) {
 final indexedTitle = data.potentialSolutions[preferredIndex].title.trim();
 if (indexedTitle.isNotEmpty) return indexedTitle;
 }

 final preferredId = preferred?.selectedSolutionId?.trim() ?? '';
 if (preferredId.isNotEmpty) {
 for (final solution in data.potentialSolutions) {
 if (solution.id.trim() == preferredId &&
 solution.title.trim().isNotEmpty) {
 return solution.title.trim();
 }
 }
 }

 final preferredSolution = data.preferredSolution;
 if (preferredSolution != null &&
 preferredSolution.title.trim().isNotEmpty) {
 return preferredSolution.title.trim();
 }

 if (data.solutionTitle.trim().isNotEmpty) return data.solutionTitle.trim();
 return data.potentialSolution.trim();
 }

 List<String> _findPreferredSolutionRiskSeeds(ProjectDataModel data) {
 final title = _resolvePreferredSolutionTitle(data);
 if (title.isEmpty) return const <String>[];
 final normalizedTitle = _normalizeForMatch(title);

 for (final riskSet in data.solutionRisks) {
 if (_normalizeForMatch(riskSet.solutionTitle) != normalizedTitle) {
 continue;
 }
 final items = riskSet.risks
 .map((e) => e.trim())
 .where((e) => e.isNotEmpty)
 .toList();
 if (items.isNotEmpty) return items;
 }

 final analysis = data.preferredSolutionAnalysis;
 if (analysis != null) {
 for (final item in analysis.solutionAnalyses) {
 if (_normalizeForMatch(item.solutionTitle) != normalizedTitle) {
 continue;
 }
 final items =
 item.risks.map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
 if (items.isNotEmpty) return items;
 }
 }

 return const <String>[];
 }

 String _normalizeForMatch(String value) {
 return value
 .trim()
 .toLowerCase()
 .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
 .replaceAll(RegExp(r'\s+'), ' ');
 }

 Future<void> _regenerateAllRisks() async {
 await _generateRequirementsFromBusinessCase();
 }

 Future<void> _generateRequirementsFromBusinessCase() async {
 setState(() => _isGeneratingRequirements = true);
 final data = ProjectDataHelper.getData(context);
 final provider = ProjectDataHelper.getProvider(context);
 final requirements = data.frontEndPlanning.requirementItems;
 final preferredRiskSeeds = _findPreferredSolutionRiskSeeds(data);
 final preferredTitle = _resolvePreferredSolutionTitle(data);

 try {
 // Track field history before regenerating
 for (final row in _rows) {
 if (row.risk.trim().isNotEmpty) {
 provider.addFieldToHistory(
 'fep_risk_${row.id}_risk',
 row.risk,
 isAiGenerated: true,
 );
 }
 if (row.description.trim().isNotEmpty) {
 provider.addFieldToHistory(
 'fep_risk_${row.id}_description',
 row.description,
 isAiGenerated: true,
 );
 }
 }

 final baseContext = ProjectDataHelper.buildFepContext(data,
 sectionLabel: 'Initial Project Risks');
 final preferredRiskContext = preferredRiskSeeds.isEmpty
 ? ''
 : '\n\nPreferred solution risk seeds (${preferredTitle.isEmpty ? 'Selected Solution' : preferredTitle}):\n- ${preferredRiskSeeds.join('\n- ')}';
 final ctx = '$baseContext$preferredRiskContext'.trim();
 final aiService = OpenAiServiceSecure();

 // Preferred solution risks should be the starting point when available.
 final seedCount = preferredRiskSeeds.isNotEmpty
 ? preferredRiskSeeds.length
 : (requirements.isNotEmpty ? requirements.length : 8);
 final riskCount = seedCount < 5 ? 5 : seedCount;
 final risks = await aiService.generateFepRisks(ctx, minCount: riskCount);

 if (!mounted) return;
 setState(() {
 final targetCount = preferredRiskSeeds.isNotEmpty
 ? preferredRiskSeeds.length
 : (requirements.isNotEmpty
 ? requirements.length
 : (risks.isNotEmpty ? risks.length : riskCount));

 _rows = List.generate(targetCount, (index) {
 final req = requirements.isNotEmpty && index < requirements.length
 ? requirements[index]
 : null;
 final seedRisk = index < preferredRiskSeeds.length
 ? preferredRiskSeeds[index]
 : '';
 final riskData = risks.isEmpty
 ? const <String, String>{}
 : risks[index % risks.length];

 final generatedTitle = (riskData['title'] ?? '').toString().trim();
 final riskTitle = _buildFallbackRiskTitle(
 index: index,
 requirementText: req?.description ?? '',
 seedRisk: seedRisk,
 generatedTitle: generatedTitle,
 );
 final probability = _normalizeRiskScale(
 (riskData['probability'] ?? '').toString(),
 fallback: 'Medium');
 final impact = _normalizeRiskScale(
 (riskData['impact'] ?? '').toString(),
 fallback: 'Medium');
 final riskLevel = _deriveRiskLevel(probability, impact);
 final aiDescription =
 (riskData['description'] ?? '').toString().trim();
 final riskDescription = aiDescription.isNotEmpty
 ? aiDescription
 : riskTitle.isNotEmpty
 ? riskTitle
 : req?.description.trim() ?? '';

 final riskItem = _RiskItem(
 id: _generateId(index + 1),
 requirement: req?.description.trim() ?? '',
 requirementType: req?.requirementType.trim() ?? '',
 risk: riskTitle,
 description: riskDescription,
 category: (riskData['category'] ?? '').toString().trim().isNotEmpty
 ? (riskData['category'] ?? '').toString().trim()
 : 'Operational',
 probability: probability,
 impact: impact,
 riskValue: '',
 riskLevel: riskLevel,
 mitigation: (riskData['mitigationStrategy'] ?? '')
 .toString()
 .trim()
 .isNotEmpty
 ? (riskData['mitigationStrategy'] ?? '').toString().trim()
 : 'Assign an owner, define mitigation actions, and monitor early warning indicators.',
 discipline:
 (riskData['discipline'] ?? '').toString().trim().isNotEmpty
 ? (riskData['discipline'] ?? '').toString().trim()
 : (req?.discipline.trim().isNotEmpty == true
 ? req!.discipline.trim()
 : 'Risk Management'),
 projectRole:
 (riskData['projectRole'] ?? '').toString().trim().isNotEmpty
 ? (riskData['projectRole'] ?? '').toString().trim()
 : (req?.role.trim() ?? 'Project Manager'),
 owner: req?.person.trim() ?? '',
 status: 'Identified',
 );

 if (riskItem.risk.trim().isNotEmpty) {
 provider.addFieldToHistory(
 'fep_risk_${riskItem.id}_risk',
 riskItem.risk,
 isAiGenerated: true,
 );
 }
 if (riskItem.description.trim().isNotEmpty) {
 provider.addFieldToHistory(
 'fep_risk_${riskItem.id}_description',
 riskItem.description,
 isAiGenerated: true,
 );
 }
 return riskItem;
 });
 _isGeneratingRequirements = false;
 });
 _syncRisksToProvider();
 await _showDueDiligencePromptIfNeeded();
 } catch (e) {
 if (!mounted) return;
 debugPrint('Risk generation failed: $e');
 final fallbackRows = _buildFallbackRows(
 requirements: requirements,
 preferredRiskSeeds: preferredRiskSeeds,
 );
 if (fallbackRows.isNotEmpty) {
 setState(() {
 _rows = fallbackRows;
 _isGeneratingRequirements = false;
 });
 _syncRisksToProvider();
 } else {
 setState(() => _isGeneratingRequirements = false);
 }
 }
 }

 List<_RiskItem> _buildFallbackRows({
 required List<RequirementItem> requirements,
 required List<String> preferredRiskSeeds,
 }) {
 if (preferredRiskSeeds.isNotEmpty) {
 return preferredRiskSeeds.asMap().entries.map((entry) {
 final title = entry.value.trim();
 return _RiskItem(
 id: _generateId(entry.key + 1),
 requirement: '',
 requirementType: '',
 risk: title,
 description: title,
 category: 'Operational',
 probability: 'Medium',
 impact: 'Medium',
 riskValue: '',
 riskLevel: 'Medium',
 mitigation:
 'Assign an owner, define mitigation actions, and monitor early warning indicators.',
 discipline: 'Risk Management',
 projectRole: 'Project Manager',
 owner: '',
 status: 'Identified',
 );
 }).toList();
 }

 if (requirements.isNotEmpty) {
 return requirements.asMap().entries.map((entry) {
 final req = entry.value;
 final riskTitle = _buildFallbackRiskTitle(
 index: entry.key,
 requirementText: req.description,
 seedRisk: '',
 generatedTitle: '',
 );
 return _RiskItem(
 id: _generateId(entry.key + 1),
 requirement: req.description,
 requirementType: req.requirementType,
 risk: riskTitle,
 description: 'Potential risk related to: ${req.description}',
 category: 'Operational',
 probability: 'Medium',
 impact: 'Medium',
 riskValue: '',
 riskLevel: 'Medium',
 mitigation:
 'Assign an owner, define mitigation actions, and monitor early warning indicators.',
 discipline: req.discipline.trim(),
 projectRole:
 req.role.trim().isNotEmpty ? req.role.trim() : 'Project Manager',
 owner: req.person.trim(),
 status: 'Identified',
 );
 }).toList();
 }

 return const <_RiskItem>[];
 }

 String _buildFallbackRiskTitle({
 required int index,
 required String requirementText,
 required String seedRisk,
 required String generatedTitle,
 }) {
 final seed = seedRisk.trim();
 if (seed.isNotEmpty) return seed;

 final generated = generatedTitle.trim();
 if (generated.isNotEmpty) return generated;

 final requirement = requirementText.trim();
 if (requirement.isNotEmpty) {
 return 'Risk associated with $requirement';
 }

 return 'Project risk ${index + 1}';
 }

 String _generateId(int number) {
 return number.toString().padLeft(3, '0');
 }

 void _addNewRisk() {
 setState(() {
 _rows.add(_RiskItem(
 id: _generateId(_rows.length + 1),
 requirement: '',
 requirementType: '',
 risk: '',
 description: '',
 category: '',
 probability: '',
 impact: '',
 riskValue: '',
 riskLevel: '',
 mitigation: '',
 discipline: '',
 projectRole: '',
 owner: '',
 status: '',
 ));
 _clearRiskTableValidationState();
 });
 // Open edit dialog for the new item
 Future.delayed(const Duration(milliseconds: 100), () {
 _showEditRiskSheet(_rows.length - 1);
 });
 }

 Future<void> _showEditRiskSheet(int index) async {
 if (index < 0 || index >= _rows.length) return;
 final current = _rows[index];

 final idCtrl = TextEditingController(text: current.id);
 final requirementCtrl = TextEditingController(text: current.requirement);
 final riskCtrl = TextEditingController(text: current.risk);
 final descriptionCtrl = TextEditingController(text: current.description);
 final categoryCtrl = TextEditingController(text: current.category);
 final mitigationCtrl = TextEditingController(text: current.mitigation);
 final disciplineCtrl = TextEditingController(text: current.discipline);
 final projectRoleCtrl = TextEditingController(text: current.projectRole);
 final ownerCtrl = TextEditingController(text: current.owner);
 // Dropdown options
 const requirementTypeOptions = [
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
 const probabilityOptions = ['High', 'Medium', 'Low'];
 const impactOptions = ['High', 'Medium', 'Low'];
 const riskLevelOptions = ['High', 'Medium', 'Low'];
 const statusOptions = ['Open', 'Mitigated', 'Closed'];

 String selectedRequirementType =
 current.requirementType.isEmpty ? '' : current.requirementType;
 String selectedProbability =
 current.probability.isEmpty ? '' : current.probability;
 String selectedImpact = current.impact.isEmpty ? '' : current.impact;
 String selectedRiskLevel =
 current.riskLevel.isEmpty ? '' : current.riskLevel;
 String selectedStatus = current.status.isEmpty ? '' : current.status;

 // Ensure custom previously-saved values still appear in dropdowns
 List<String> requirementTypeItems = [
 ...requirementTypeOptions,
 if (selectedRequirementType.isNotEmpty &&
 !requirementTypeOptions.contains(selectedRequirementType))
 selectedRequirementType,
 ];
 List<String> probabilityItems = [
 ...probabilityOptions,
 if (selectedProbability.isNotEmpty &&
 !probabilityOptions.contains(selectedProbability))
 selectedProbability,
 ];
 List<String> impactItems = [
 ...impactOptions,
 if (selectedImpact.isNotEmpty && !impactOptions.contains(selectedImpact))
 selectedImpact,
 ];
 List<String> riskLevelItems = [
 ...riskLevelOptions,
 if (selectedRiskLevel.isNotEmpty &&
 !riskLevelOptions.contains(selectedRiskLevel))
 selectedRiskLevel,
 ];
 List<String> statusItems = [
 ...statusOptions,
 if (selectedStatus.isNotEmpty && !statusOptions.contains(selectedStatus))
 selectedStatus,
 ];

 final result = await showDialog<_RiskItem>(
 context: context,
 barrierDismissible: true,
 barrierColor: Colors.black.withOpacity(0.45),
 builder: (ctx) {
 final viewInsets = MediaQuery.of(ctx).viewInsets;
 return Center(
 child: ConstrainedBox(
 constraints: const BoxConstraints(maxWidth: 560),
 child: Material(
 color: Colors.white,
 borderRadius: BorderRadius.circular(20),
 child: Padding(
 padding:
 EdgeInsets.fromLTRB(20, 16, 20, 16 + viewInsets.bottom),
 child: StatefulBuilder(
 builder: (ctx, setLocal) {
 return SingleChildScrollView(
 child: Column(
 mainAxisSize: MainAxisSize.min,
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 children: const [
 Icon(Icons.edit_note, color: Color(0xFF111827)),
 SizedBox(width: 8),
 Text('Edit Risk',
 style: TextStyle(
 fontSize: 16,
 fontWeight: FontWeight.w800)),
 ],
 ),
 const SizedBox(height: 16),
 _LabeledField(
 label: 'ID', controller: idCtrl, enabled: false),
 const SizedBox(height: 12),
 _LabeledField(
 label: 'Requirement',
 controller: requirementCtrl,
 autofocus: true),
 const SizedBox(height: 12),
 _LabeledDropdown(
 label: 'Requirement Type',
 value: selectedRequirementType.isEmpty
 ? null
 : selectedRequirementType,
 hint: 'e.g. Functional/Technical',
 items: requirementTypeItems,
 onChanged: (v) => setLocal(
 () => selectedRequirementType = v ?? ''),
 ),
 const SizedBox(height: 12),
 _LabeledField(
 label: 'Risk Title', controller: riskCtrl),
 const SizedBox(height: 12),
 _LabeledField(
 label: 'Description',
 controller: descriptionCtrl),
 const SizedBox(height: 12),
 _LabeledField(
 label: 'Category', controller: categoryCtrl),
 const SizedBox(height: 12),
 Row(
 children: [
 Expanded(
 child: _LabeledDropdown(
 label: 'Probability',
 value: selectedProbability.isEmpty
 ? null
 : selectedProbability,
 hint: 'e.g. High/Medium/Low',
 items: probabilityItems,
 onChanged: (v) => setLocal(
 () => selectedProbability = v ?? ''),
 ),
 ),
 const SizedBox(width: 12),
 Expanded(
 child: _LabeledDropdown(
 label: 'Impact',
 value: selectedImpact.isEmpty
 ? null
 : selectedImpact,
 hint: 'e.g. High/Medium/Low',
 items: impactItems,
 onChanged: (v) =>
 setLocal(() => selectedImpact = v ?? ''),
 ),
 ),
 ],
 ),
 const SizedBox(height: 12),
 Row(
 children: [
 Expanded(
 child: _LabeledDropdown(
 label: 'Risk Level',
 value: selectedRiskLevel.isEmpty
 ? null
 : selectedRiskLevel,
 hint: 'e.g. High/Medium/Low',
 items: riskLevelItems,
 onChanged: (v) => setLocal(
 () => selectedRiskLevel = v ?? ''),
 ),
 ),
 const SizedBox(width: 12),
 Expanded(
 child: _LabeledDropdown(
 label: 'Status',
 value: selectedStatus.isEmpty
 ? null
 : selectedStatus,
 hint: 'e.g. Open/Mitigated/Closed',
 items: statusItems,
 onChanged: (v) =>
 setLocal(() => selectedStatus = v ?? ''),
 ),
 ),
 ],
 ),
 const SizedBox(height: 12),
 _LabeledField(
 label: 'Mitigation', controller: mitigationCtrl),
 const SizedBox(height: 12),
 _LabeledField(
 label: 'Discipline', controller: disciplineCtrl),
 const SizedBox(height: 12),
 _LabeledField(
 label: 'Project Role',
 controller: projectRoleCtrl),
 const SizedBox(height: 12),
 _LabeledField(label: 'Owner', controller: ownerCtrl),
 const SizedBox(height: 20),
 Row(
 children: [
 TextButton(
 onPressed: () => Navigator.of(ctx).pop(null),
 child: const Text('Cancel'),
 ),
 const Spacer(),
 ElevatedButton.icon(
 icon: const Icon(Icons.check,
 color: Colors.black),
 label: const Text('Save',
 style: TextStyle(color: Colors.black)),
 onPressed: () {
 Navigator.of(ctx).pop(_RiskItem(
 id: current.id,
 requirement: requirementCtrl.text.trim(),
 requirementType: selectedRequirementType,
 risk: riskCtrl.text.trim(),
 description: descriptionCtrl.text.trim(),
 category: categoryCtrl.text.trim(),
 probability: selectedProbability,
 impact: selectedImpact,
 riskValue: current.riskValue,
 riskLevel: selectedRiskLevel,
 mitigation: mitigationCtrl.text.trim(),
 discipline: disciplineCtrl.text.trim(),
 projectRole: projectRoleCtrl.text.trim(),
 owner: ownerCtrl.text.trim(),
 status: selectedStatus,
 ));
 },
 style: ElevatedButton.styleFrom(
 backgroundColor: const Color(0xFFFFD700),
 foregroundColor: Colors.black,
 elevation: 0,
 shape: RoundedRectangleBorder(
 borderRadius: BorderRadius.circular(12)),
 padding: const EdgeInsets.symmetric(
 horizontal: 18, vertical: 12),
 ),
 ),
 ],
 ),
 ],
 ),
 );
 },
 ),
 ),
 ),
 ),
 );
 },
 );

 if (result != null) {
 _recordRowFieldHistory(previous: current, next: result);
 setState(() {
 _rows[index] = result;
 _clearRiskTableValidationState();
 });
 _syncRisksToProvider();
 }
 }

 void _recordRowFieldHistory(
 {required _RiskItem previous, required _RiskItem next}) {
 final provider = ProjectDataHelper.getProvider(context);
 final fieldPairs = <MapEntry<String, String>>[
 MapEntry('requirement', previous.requirement),
 MapEntry('requirement_type', previous.requirementType),
 MapEntry('risk', previous.risk),
 MapEntry('description', previous.description),
 MapEntry('category', previous.category),
 MapEntry('probability', previous.probability),
 MapEntry('impact', previous.impact),
 MapEntry('risk_level', previous.riskLevel),
 MapEntry('mitigation', previous.mitigation),
 MapEntry('discipline', previous.discipline),
 MapEntry('project_role', previous.projectRole),
 MapEntry('owner', previous.owner),
 MapEntry('status', previous.status),
 ];

 final nextValues = <String, String>{
 'requirement': next.requirement,
 'requirement_type': next.requirementType,
 'risk': next.risk,
 'description': next.description,
 'category': next.category,
 'probability': next.probability,
 'impact': next.impact,
 'risk_level': next.riskLevel,
 'mitigation': next.mitigation,
 'discipline': next.discipline,
 'project_role': next.projectRole,
 'owner': next.owner,
 'status': next.status,
 };

 for (final pair in fieldPairs) {
 final oldValue = pair.value.trim();
 final newValue = (nextValues[pair.key] ?? '').trim();
 if (oldValue == newValue) continue;
 provider.addFieldToHistory(
 'fep_risk_${previous.id}_${pair.key}',
 pair.value,
 isAiGenerated: false,
 );
 }
 }

 bool _canUndoRiskRow(int index) {
 if (index < 0 || index >= _rows.length) return false;
 final row = _rows[index];
 final data = ProjectDataHelper.getData(context);
 final keys = [
 'fep_risk_${row.id}_requirement',
 'fep_risk_${row.id}_requirement_type',
 'fep_risk_${row.id}_risk',
 'fep_risk_${row.id}_description',
 'fep_risk_${row.id}_category',
 'fep_risk_${row.id}_probability',
 'fep_risk_${row.id}_impact',
 'fep_risk_${row.id}_risk_level',
 'fep_risk_${row.id}_mitigation',
 'fep_risk_${row.id}_discipline',
 'fep_risk_${row.id}_project_role',
 'fep_risk_${row.id}_owner',
 'fep_risk_${row.id}_status',
 ];
 return keys.any(data.canUndoField);
 }

 void _undoRiskRow(int index) {
 if (index < 0 || index >= _rows.length) return;
 final row = _rows[index];
 final data = ProjectDataHelper.getData(context);

 String undoOrCurrent(String fieldSuffix, String currentValue) {
 final key = 'fep_risk_${row.id}_$fieldSuffix';
 return data.undoField(key) ?? currentValue;
 }

 final reverted = row.copyWith(
 requirement: undoOrCurrent('requirement', row.requirement),
 requirementType: undoOrCurrent('requirement_type', row.requirementType),
 risk: undoOrCurrent('risk', row.risk),
 description: undoOrCurrent('description', row.description),
 category: undoOrCurrent('category', row.category),
 probability: undoOrCurrent('probability', row.probability),
 impact: undoOrCurrent('impact', row.impact),
 riskLevel: undoOrCurrent('risk_level', row.riskLevel),
 mitigation: undoOrCurrent('mitigation', row.mitigation),
 discipline: undoOrCurrent('discipline', row.discipline),
 projectRole: undoOrCurrent('project_role', row.projectRole),
 owner: undoOrCurrent('owner', row.owner),
 status: undoOrCurrent('status', row.status),
 );

 if (_sameRiskItem(reverted, row)) return;
 setState(() {
 _rows[index] = reverted;
 });
 _syncRisksToProvider();
 }

 bool _sameRiskItem(_RiskItem a, _RiskItem b) {
 return a.id == b.id &&
 a.requirement == b.requirement &&
 a.requirementType == b.requirementType &&
 a.risk == b.risk &&
 a.description == b.description &&
 a.category == b.category &&
 a.probability == b.probability &&
 a.impact == b.impact &&
 a.riskLevel == b.riskLevel &&
 a.mitigation == b.mitigation &&
 a.discipline == b.discipline &&
 a.projectRole == b.projectRole &&
 a.owner == b.owner &&
 a.status == b.status;
 }

 Future<void> _confirmAndDeleteRow(int index) async {
 final shouldDelete = await showDeleteConfirmationDialog(
 context,
 title: 'Delete Risk?',
 itemLabel:
 index >= 0 && index < _rows.length ? _rows[index].risk.trim() : null,
 );

 if (shouldDelete == true && index >= 0 && index < _rows.length) {
 setState(() {
 _rows.removeAt(index);
 });
 _syncRisksToProvider();
 }
 }

 @override
 void dispose() {
 if (_isSyncReady) {
 _notesController.removeListener(_syncRisksToProvider);
 }
 _notesController.dispose();
 super.dispose();
 }

 void _syncRisksToProvider() {
 if (!mounted || !_isSyncReady || _isApplyingNotesSummary) return;
 final summaryFromRows = _buildRiskSummaryFromRows();
 final currentNotes = _notesController.text.trim();
 final notesLookAutoGenerated = currentNotes.startsWith('Key risks:');
 final value = summaryFromRows.isNotEmpty
 ? summaryFromRows
 : (notesLookAutoGenerated ? '' : _summarizeNotesText(currentNotes));

 if (summaryFromRows.isNotEmpty &&
 _notesController.text.trim() != summaryFromRows) {
 _isApplyingNotesSummary = true;
 _notesController.value = TextEditingValue(
 text: summaryFromRows,
 selection: TextSelection.collapsed(offset: summaryFromRows.length),
 );
 _isApplyingNotesSummary = false;
 } else if (summaryFromRows.isEmpty && notesLookAutoGenerated) {
 _isApplyingNotesSummary = true;
 _notesController.clear();
 _isApplyingNotesSummary = false;
 }

 final riskRegisterItems = _rows
 .map((r) => RiskRegisterItem(
 riskName: r.risk.trim(),
 description: r.description.trim(),
 category: r.category.trim(),
 requirement: r.requirement.trim(),
 requirementType: r.requirementType.trim(),
 impactLevel: (r.impact.trim().isNotEmpty
 ? r.impact.trim()
 : r.riskLevel.trim())
 .isNotEmpty
 ? (r.impact.trim().isNotEmpty
 ? r.impact.trim()
 : r.riskLevel.trim())
 : 'Medium',
 likelihood: r.probability.trim().isNotEmpty
 ? r.probability.trim()
 : 'Medium',
 mitigationStrategy: r.mitigation.trim().isNotEmpty
 ? r.mitigation.trim()
 : 'Assign an owner, define mitigation actions, and monitor early warning indicators.',
 discipline: r.discipline.trim(),
 projectRole: r.projectRole.trim(),
 owner: r.owner.trim(),
 status: r.status.trim(),
 ))
 .where((r) =>
 r.riskName.isNotEmpty ||
 r.description.isNotEmpty ||
 r.requirement.isNotEmpty ||
 r.requirementType.isNotEmpty ||
 r.mitigationStrategy.isNotEmpty ||
 r.discipline.isNotEmpty ||
 r.projectRole.isNotEmpty ||
 r.owner.isNotEmpty ||
 r.status.isNotEmpty)
 .toList();
 final provider = ProjectDataHelper.getProvider(context);
 provider.updateField(
 (data) => data.copyWith(
 frontEndPlanning: ProjectDataHelper.updateFEPField(
 current: data.frontEndPlanning,
 risks: value,
 riskRegisterItems: riskRegisterItems,
 ),
 ),
 );
 provider.saveToFirebase(checkpoint: 'fep_risks');
 }

 String _buildRiskSummaryFromRows({int previewCount = 4}) {
 final populated = _rows.where((r) => r.risk.trim().isNotEmpty).toList();
 if (populated.isEmpty) return '';

 final ranked = populated
 .map((row) => _RankedRiskRow(
 row: row,
 severity: _resolveRiskSeverity(row),
 ))
 .toList()
 ..sort((a, b) {
 final severityCompare = _riskSeverityWeight(b.severity)
 .compareTo(_riskSeverityWeight(a.severity));
 if (severityCompare != 0) return severityCompare;
 return a.row.id.compareTo(b.row.id);
 });

 final counts = <String, int>{
 'Critical': 0,
 'High': 0,
 'Medium': 0,
 'Low': 0,
 };
 for (final item in ranked) {
 counts[item.severity] = (counts[item.severity] ?? 0) + 1;
 }

 final highlights = ranked
 .take(previewCount)
 .map((item) {
 final label = _shortRiskLabel(item.row.risk);
 if (label.isEmpty) return '';
 return '$label (${item.severity})';
 })
 .where((value) => value.isNotEmpty)
 .toList();
 final remainingCount = ranked.length - highlights.length;
 final suffix = remainingCount > 0 ? ', +$remainingCount more' : '';

 return 'Key risks: ${highlights.join(', ')}$suffix. Total ${populated.length} '
 '(Critical: ${counts['Critical']}, High: ${counts['High']}, Medium: ${counts['Medium']}, Low: ${counts['Low']}).';
 }

 String _resolveRiskSeverity(_RiskItem row) {
 final explicit = row.riskLevel.trim().toLowerCase();
 if (explicit == 'critical') return 'Critical';
 if (explicit == 'high') return 'High';
 if (explicit == 'medium') return 'Medium';
 if (explicit == 'low') return 'Low';

 final probability =
 _normalizeRiskScale(row.probability, fallback: 'Medium');
 final impact = _normalizeRiskScale(row.impact, fallback: 'Medium');

 if (probability == 'High' && impact == 'High') return 'Critical';
 if (probability == 'High' || impact == 'High') return 'High';
 if (probability == 'Low' && impact == 'Low') return 'Low';
 return 'Medium';
 }

 int _riskSeverityWeight(String severity) {
 switch (severity) {
 case 'Critical':
 return 4;
 case 'High':
 return 3;
 case 'Medium':
 return 2;
 case 'Low':
 return 1;
 default:
 return 0;
 }
 }

 Map<String, int> _riskSeverityDistribution() {
 final counts = <String, int>{
 'Critical': 0,
 'High': 0,
 'Medium': 0,
 'Low': 0,
 };
 for (final row in _rows.where((r) => r.risk.trim().isNotEmpty)) {
 final severity = _resolveRiskSeverity(row);
 counts[severity] = (counts[severity] ?? 0) + 1;
 }
 return counts;
 }

 String _summarizeNotesText(String text, {int maxItems = 4}) {
 final trimmed = text.trim();
 if (trimmed.isEmpty) return '';

 final normalizedInline = trimmed.replaceAll(RegExp(r'\s+'), ' ');
 if (!trimmed.contains('\n') && normalizedInline.length <= 220) {
 return normalizedInline;
 }

 final lines = trimmed
 .split(RegExp(r'[\r\n]+'))
 .map((line) => line.trim())
 .where((line) => line.isNotEmpty)
 .toList();
 if (lines.isEmpty) {
 return normalizedInline.length <= 220
 ? normalizedInline
 : '${normalizedInline.substring(0, 217)}...';
 }

 final highlights = lines.take(maxItems).map((line) {
 final candidate = line.contains(':') ? line.split(':').first : line;
 return _shortRiskLabel(candidate);
 }).toList();

 final remainingCount = lines.length - highlights.length;
 final suffix = remainingCount > 0 ? ', +$remainingCount more' : '';
 return 'Key risks: ${highlights.join(', ')}$suffix.';
 }

 String _normalizeRiskScale(String rawValue, {String fallback = 'Medium'}) {
 final normalized = rawValue.trim().toLowerCase();
 if (normalized.startsWith('h')) return 'High';
 if (normalized.startsWith('l')) return 'Low';
 if (normalized.startsWith('m')) return 'Medium';
 return fallback;
 }

 String _deriveRiskLevel(String probability, String impact) {
 final prob =
 _normalizeRiskScale(probability, fallback: 'Medium').toLowerCase();
 final imp = _normalizeRiskScale(impact, fallback: 'Medium').toLowerCase();
 if ((prob == 'high' && imp == 'high') ||
 (prob == 'high' && imp == 'medium') ||
 (prob == 'medium' && imp == 'high')) {
 return 'High';
 }
 if ((prob == 'low' && imp == 'low') ||
 (prob == 'low' && imp == 'medium') ||
 (prob == 'medium' && imp == 'low')) {
 return 'Low';
 }
 return 'Medium';
 }

 String _shortRiskLabel(String value, {int maxChars = 54}) {
 final normalized = value.replaceAll(RegExp(r'\s+'), ' ').trim();
 if (normalized.length <= maxChars) {
 return normalized;
 }
 return '${normalized.substring(0, maxChars - 3)}...';
 }

 FormValidationResult _validateRiskSection() {
 return FormValidationEngine.validateForm([
 ValidationFieldRule(
 id: 'risk_title',
 label: 'Risk Title',
 section: 'Project Risks',
 type: ValidationFieldType.custom,
 value: _rows,
 fieldKey: _riskTableKey,
 errorText: 'Add at least one risk title',
 isMissing: (_) => _rows.every((row) => row.risk.trim().isEmpty),
 ),
 ValidationFieldRule(
 id: 'mitigation_strategy',
 label: 'Mitigation Strategy',
 section: 'Project Risks',
 type: ValidationFieldType.custom,
 value: _rows,
 fieldKey: _riskTableKey,
 errorText: 'Add mitigation for each identified risk',
 isMissing: (_) => _rows.any((row) =>
 row.risk.trim().isNotEmpty && row.mitigation.trim().isEmpty),
 ),
 ]);
 }

 void _applyRiskValidationState(FormValidationResult validation) {
 String? sectionError;
 for (final issue in validation.issues) {
 if (issue.section == 'Project Risks') {
 sectionError = issue.errorText;
 break;
 }
 }
 setState(() {
 _riskTableHasError = sectionError != null;
 _riskTableErrorText = sectionError;
 });
 }

 void _clearRiskTableValidationState() {
 _riskTableHasError = false;
 _riskTableErrorText = null;
 }

 Future<void> _focusFirstRiskIssue(FormValidationResult validation) async {
 await FormValidationEngine.scrollToFirstIssue(validation);
 final issue = validation.firstIssue;
 if (issue == null) return;

 if (issue.id == 'risk_title') {
 if (_rows.isEmpty) {
 _addNewRisk();
 return;
 }

 final firstMissingTitle =
 _rows.indexWhere((row) => row.risk.trim().isEmpty);
 if (firstMissingTitle != -1) {
 _showEditRiskSheet(firstMissingTitle);
 }
 return;
 }

 if (issue.id == 'mitigation_strategy') {
 final firstMissingMitigation = _rows.indexWhere(
 (row) => row.risk.trim().isNotEmpty && row.mitigation.trim().isEmpty);
 if (firstMissingMitigation != -1) {
 _showEditRiskSheet(firstMissingMitigation);
 }
 }
 }

 Future<void> _saveAndNavigateToOpportunities({
 bool skippedValidation = false,
 }) async {
 if (skippedValidation && mounted) {
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(
 content: Text(
 'Continuing to Opportunities. You can complete remaining risk details later.',
 ),
 duration: Duration(seconds: 3),
 ),
 );
 }

 final risksText = _buildRiskSummaryFromRows();
 await ProjectDataHelper.saveAndNavigate(
 context: context,
 checkpoint: 'fep_risks',
 saveInBackground: true,
 nextScreenBuilder: () => const FrontEndPlanningOpportunitiesScreen(),
 dataUpdater: (data) => data.copyWith(
 frontEndPlanning: ProjectDataHelper.updateFEPField(
 current: data.frontEndPlanning,
 risks: risksText.isNotEmpty
 ? risksText
 : _summarizeNotesText(_notesController.text.trim()),
 ),
 ),
 );
 }

 Future<void> _saveAndContinue() async {
 final validation = _validateRiskSection();
 if (!validation.isValid) {
 _applyRiskValidationState(validation);

 FormValidationEngine.showValidationSnackBar(
 context,
 validation,
 intro:
 'Risk details are recommended before proceeding. You can continue now and complete them later.',
 backgroundColor: const Color(0xFFF59E0B),
 );

 if (_riskTableHasError) {
 setState(_clearRiskTableValidationState);
 }
 await _saveAndNavigateToOpportunities(skippedValidation: true);
 return;
 }

 if (_riskTableHasError) {
 setState(_clearRiskTableValidationState);
 }

 await _saveAndNavigateToOpportunities();
 }

 @override
 Widget build(BuildContext context) {
 final isMobile = AppBreakpoints.isMobile(context);
 if (isMobile) {
 return _buildMobileScaffold(context);
 }

 return Scaffold(
 // Ensure white background as requested
 backgroundColor: Colors.white,
 body: SafeArea(
 child: Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 // Use the same sidebar component used in PreferredSolutionAnalysisScreen
 DraggableSidebar(
 openWidth: AppBreakpoints.sidebarWidth(context),
 child:
 const InitiationLikeSidebar(activeItemLabel: 'Project Risks'),
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
 _roundedField(
 controller: _notesController,
 hint: 'Input your notes here...',
 minLines: 2,
 maxLines: 4,
 ),
 const SizedBox(height: 22),
 Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Expanded(
 child: Column(
 crossAxisAlignment:
 CrossAxisAlignment.start,
 children: const [
 EditableContentText(
 contentKey:
 'fep_initial_project_risks_title',
 fallback: 'Initial Project Risks',
 category: 'front_end_planning',
 style: TextStyle(
 fontSize: 20,
 fontWeight: FontWeight.w700,
 color: Color(0xFF111827),
 ),
 ),
 SizedBox(height: 6),
 EditableContentText(
 contentKey: 'fep_risks_subtitle',
 fallback:
 '(Highlight and quantify known and/or anticipated risks here)',
 category: 'front_end_planning',
 style: TextStyle(
 fontSize: 14,
 color: Color(0xFF6B7280),
 ),
 ),
 ],
 ),
 ),
 PageRegenerateAllButton(
 onRegenerateAll: () async {
 final confirmed =
 await showRegenerateAllConfirmation(
 context);
 if (confirmed && mounted) {
 await _regenerateAllRisks();
 }
 },
 isLoading: _isGeneratingRequirements,
 tooltip: 'Regenerate all risks',
 ),
 ],
 ),
 const SizedBox(height: 14),
 _buildRiskDistributionMatrix(),
 const SizedBox(height: 14),
 const Row(
 children: [
 Icon(Icons.info_outline,
 size: 16, color: Color(0xFF6B7280)),
 SizedBox(width: 6),
 Expanded(
 child: Text(
 'Use the Action column or double-click any row cell to edit risk details.',
 style: TextStyle(
 fontSize: 12.5,
 color: Color(0xFF6B7280),
 ),
 ),
 ),
 ],
 ),
 const SizedBox(height: 10),
 if (_isGeneratingRequirements)
 const Center(
 child: Padding(
 padding: EdgeInsets.all(24.0),
 child: Column(
 children: [
 CircularProgressIndicator(),
 SizedBox(height: 12),
 Text(
 'Generating project risks from project context...'),
 ],
 ),
 ),
 )
 else
 _buildRiskTable(context),
 if (_riskTableHasError) ...[
 const SizedBox(height: 8),
 Text(
 _riskTableErrorText ??
 'This field is required',
 style: const TextStyle(
 color: Color(0xFFDC2626),
 fontSize: 12,
 fontWeight: FontWeight.w600,
 ),
 ),
 ],
 const SizedBox(height: 16),
 Align(
 alignment: Alignment.centerLeft,
 child: ElevatedButton.icon(
 onPressed: _addNewRisk,
 icon: const Icon(Icons.add,
 color: Colors.black, size: 18),
 label: const Text('Add Item',
 style: TextStyle(
 color: Colors.black,
 fontWeight: FontWeight.w600)),
 style: ElevatedButton.styleFrom(
 backgroundColor: const Color(0xFFFFD700),
 foregroundColor: Colors.black,
 elevation: 0,
 padding: const EdgeInsets.symmetric(
 horizontal: 20, vertical: 12),
 shape: RoundedRectangleBorder(
 borderRadius:
 BorderRadius.circular(20)),
 ),
 ),
 ),
 const SizedBox(height: 140),
 ],
 ),
 ),
 ),
 ],
 ),
 MobileSidebarHamburger(
 sidebar: const InitiationLikeSidebar(
 activeItemLabel: 'Project Risks',
 ),
 ),
 const KazAiChatBubble(),
 _BottomOverlays(
 onNext: _saveAndContinue,
 ),
 ],
 ),
 ),
 ],
 ),
 ),
 );
 }

 Widget _buildMobileScaffold(BuildContext context) {
 final data = ProjectDataHelper.getData(context);
 final projectName = data.projectName.trim().isEmpty
 ? 'Project Workspace'
 : data.projectName.trim();

 return Scaffold(
 key: _scaffoldKey,
 backgroundColor: Colors.white,
 drawer: Drawer(
 width: MediaQuery.sizeOf(context).width * 0.88,
 child: const SafeArea(
 child: InitiationLikeSidebar(activeItemLabel: 'Project Risks'),
 ),
 ),
 body: SafeArea(
 child: Column(
 children: [
 Padding(
 padding: const EdgeInsets.fromLTRB(8, 8, 10, 6),
 child: Row(
 children: [
 IconButton(
 onPressed: () => FrontEndPlanningNavigation.goToPrevious(
 context,
 'fep_risks',
 ),
 icon:
 const Icon(Icons.arrow_back_ios_new_rounded, size: 17),
 visualDensity: VisualDensity.compact,
 ),
 const Expanded(
 child: Text(
 'Front End Planning',
 textAlign: TextAlign.center,
 style: TextStyle(
 fontSize: 12.5,
 fontWeight: FontWeight.w500,
 color: Color(0xFF6B7280),
 ),
 ),
 ),
 InkWell(
 onTap: () => _scaffoldKey.currentState?.openDrawer(),
 borderRadius: BorderRadius.circular(20),
 child: const CircleAvatar(
 radius: 13,
 backgroundColor: Color(0xFF2563EB),
 child: Text('C',
 style: TextStyle(
 color: Colors.white,
 fontWeight: FontWeight.w700,
 fontSize: 12)),
 ),
 ),
 ],
 ),
 ),
 Expanded(
 child: SingleChildScrollView(
 padding: const EdgeInsets.fromLTRB(12, 2, 12, 110),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 const Text(
 'ZAMBIA PHARMACY HUB EXPANSION',
 style: TextStyle(
 fontSize: 9.5,
 fontWeight: FontWeight.w700,
 color: Color(0xFF9CA3AF),
 letterSpacing: 0.4,
 ),
 ),
 const SizedBox(height: 4),
 Text(
 projectName,
 maxLines: 1,
 overflow: TextOverflow.ellipsis,
 style: const TextStyle(
 fontSize: 14,
 fontWeight: FontWeight.w500,
 color: Color(0xFF6B7280),
 ),
 ),
 const SizedBox(height: 10),
 const Text(
 'Initial Project Risks',
 style: TextStyle(
 fontSize: 31,
 height: 1.0,
 fontWeight: FontWeight.w800,
 color: Color(0xFF111827),
 ),
 ),
 const SizedBox(height: 4),
 const Text(
 '(Highlight and quantify known and/or anticipated risks here)',
 style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
 ),
 const SizedBox(height: 10),
 _buildRiskDistributionMatrix(),
 const SizedBox(height: 12),
 const Text(
 'Tap any risk card to edit details.',
 style:
 TextStyle(fontSize: 11.5, color: Color(0xFF6B7280)),
 ),
 const SizedBox(height: 10),
 ..._rows.asMap().entries.map((entry) {
 final index = entry.key;
 final row = entry.value;
 return Padding(
 padding: const EdgeInsets.only(bottom: 12),
 child: _buildMobileRiskCard(index, row),
 );
 }),
 ],
 ),
 ),
 ),
 ],
 ),
 ),
 bottomNavigationBar: SafeArea(
 top: false,
 child: Padding(
 padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
 child: Row(
 children: [
 Expanded(
 child: OutlinedButton.icon(
 onPressed:
 _isGeneratingRequirements ? null : _regenerateAllRisks,
 icon: _isGeneratingRequirements
 ? const SizedBox(
 width: 14,
 height: 14,
 child: CircularProgressIndicator(strokeWidth: 2),
 )
 : const Icon(Icons.auto_awesome_rounded, size: 15),
 label: const Text(
 'AI Suggestions',
 style: TextStyle(fontWeight: FontWeight.w700),
 ),
 style: OutlinedButton.styleFrom(
 foregroundColor: const Color(0xFF2563EB),
 side: const BorderSide(color: Color(0xFFBFDBFE)),
 shape: RoundedRectangleBorder(
 borderRadius: BorderRadius.circular(12)),
 padding: const EdgeInsets.symmetric(vertical: 13),
 ),
 ),
 ),
 const SizedBox(width: 10),
 Expanded(
 child: ElevatedButton(
 onPressed: _saveAndContinue,
 style: ElevatedButton.styleFrom(
 backgroundColor: const Color(0xFFF4B400),
 foregroundColor: Colors.black,
 elevation: 0,
 shape: RoundedRectangleBorder(
 borderRadius: BorderRadius.circular(12)),
 padding: const EdgeInsets.symmetric(vertical: 13),
 ),
 child: const Text(
 'Next',
 style: TextStyle(fontWeight: FontWeight.w800),
 ),
 ),
 ),
 ],
 ),
 ),
 ),
 );
 }

 Widget _buildMobileRiskCard(int index, _RiskItem row) {
 final probability =
 row.probability.trim().isEmpty ? 'Medium' : row.probability;
 final impact = row.impact.trim().isEmpty ? 'Medium' : row.impact;
 final probabilityValue = _levelToSlider(probability);
 final impactValue = _levelToSlider(impact);

 return InkWell(
 onTap: () => _showEditRiskSheet(index),
 borderRadius: BorderRadius.circular(18),
 child: Container(
 width: double.infinity,
 padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(18),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 children: [
 Container(
 padding:
 const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
 decoration: BoxDecoration(
 color: const Color(0xFFECFDF5),
 borderRadius: BorderRadius.circular(999),
 ),
 child: Text(
 (row.requirementType.isEmpty
 ? 'Operational'
 : row.requirementType)
 .toUpperCase(),
 style: const TextStyle(
 fontSize: 9,
 fontWeight: FontWeight.w700,
 color: Color(0xFF059669),
 ),
 ),
 ),
 const Spacer(),
 Text(
 'ID: ${row.id}',
 style:
 const TextStyle(fontSize: 10.5, color: Color(0xFF9CA3AF)),
 ),
 ],
 ),
 const SizedBox(height: 6),
 Align(
 alignment: Alignment.centerRight,
 child: InkWell(
 onTap: _isGeneratingRequirements ? null : _regenerateAllRisks,
 borderRadius: BorderRadius.circular(999),
 child: Container(
 padding:
 const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
 decoration: BoxDecoration(
 color: const Color(0xFFF2F4FA),
 borderRadius: BorderRadius.circular(999),
 border: Border.all(color: const Color(0xFFDCE2F0)),
 ),
 child: const Row(
 mainAxisSize: MainAxisSize.min,
 children: [
 Icon(Icons.auto_awesome_rounded,
 size: 11, color: Color(0xFF4F46E5)),
 SizedBox(width: 4),
 Text(
 'AI ASSISTANCE',
 style: TextStyle(
 fontSize: 9,
 fontWeight: FontWeight.w700,
 color: Color(0xFF4F46E5),
 ),
 ),
 ],
 ),
 ),
 ),
 ),
 const SizedBox(height: 8),
 Text(
 row.risk.trim().isEmpty
 ? row.requirement.trim().isEmpty
 ? 'Tap to define risk title'
 : row.requirement.trim()
 : row.risk.trim(),
 style: const TextStyle(
 fontSize: 26,
 height: 1.0,
 fontWeight: FontWeight.w700,
 color: Color(0xFF1F2937),
 ),
 ),
 const SizedBox(height: 6),
 Text(
 row.requirement.trim().isEmpty
 ? 'Requirement not set.'
 : 'Requirement: ${row.requirement.trim()}',
 style: const TextStyle(fontSize: 11.5, color: Color(0xFF9CA3AF)),
 ),
 if (row.projectRole.trim().isNotEmpty ||
 row.owner.trim().isNotEmpty) ...[
 const SizedBox(height: 4),
 Text(
 'Role: ${row.projectRole.trim().isEmpty ? 'Not set' : row.projectRole.trim()} | Owner: ${row.owner.trim().isEmpty ? 'Not set' : row.owner.trim()}',
 style:
 const TextStyle(fontSize: 11.5, color: Color(0xFF9CA3AF)),
 ),
 ],
 const SizedBox(height: 10),
 Row(
 children: [
 Expanded(
 child: _buildSliderColumn('PROBABILITY', probabilityValue),
 ),
 const SizedBox(width: 10),
 Expanded(
 child: _buildSliderColumn('IMPACT', impactValue),
 ),
 ],
 ),
 const SizedBox(height: 10),
 const Text(
 'MITIGATION PLAN',
 style: TextStyle(
 fontSize: 9.5,
 color: Color(0xFF9CA3AF),
 fontWeight: FontWeight.w700,
 letterSpacing: 0.35),
 ),
 const SizedBox(height: 5),
 Container(
 decoration: BoxDecoration(
 color: const Color(0xFFF3F4F6),
 borderRadius: BorderRadius.circular(10),
 ),
 padding: const EdgeInsets.symmetric(horizontal: 10),
 child: VoiceTextFormField(
 initialValue: row.mitigation,
 minLines: 2,
 maxLines: 3,
 onChanged: (value) {
 if (index >= 0 && index < _rows.length) {
 setState(() {
 _rows[index] = _rows[index].copyWith(mitigation: value);
 _clearRiskTableValidationState();
 });
 _syncRisksToProvider();
 }
 },
 decoration: const InputDecoration(
 border: InputBorder.none,
 hintText: 'Describe how to mitigate this risk...',
 hintStyle: TextStyle(color: Color(0xFFB6BDC8)),
 ),
 style:
 const TextStyle(fontSize: 12.5, color: Color(0xFF374151)),
 ),
 ),
 ],
 ),
 ),
 );
 }

 Widget _buildSliderColumn(String label, double value) {
 return Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 label,
 style: const TextStyle(
 fontSize: 9.5,
 color: Color(0xFF9CA3AF),
 fontWeight: FontWeight.w700,
 letterSpacing: 0.35,
 ),
 ),
 SliderTheme(
 data: SliderThemeData(
 thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
 overlayShape: SliderComponentShape.noOverlay,
 activeTrackColor: const Color(0xFFF4B400),
 inactiveTrackColor: const Color(0xFFE5E7EB),
 ),
 child: Slider(
 value: value,
 min: 0,
 max: 1,
 onChanged: null,
 ),
 ),
 const Row(
 mainAxisAlignment: MainAxisAlignment.spaceBetween,
 children: [
 Text('LOW',
 style: TextStyle(fontSize: 8.5, color: Color(0xFF9CA3AF))),
 Text('MED',
 style: TextStyle(fontSize: 8.5, color: Color(0xFF9CA3AF))),
 Text('HIGH',
 style: TextStyle(fontSize: 8.5, color: Color(0xFF9CA3AF))),
 ],
 ),
 ],
 );
 }

 double _levelToSlider(String value) {
 final normalized = value.trim().toLowerCase();
 if (normalized == 'high' || normalized == 'critical') return 0.9;
 if (normalized == 'low') return 0.2;
 return 0.55;
 }

 Widget _buildRiskDistributionMatrix() {
 final distribution = _riskSeverityDistribution();
 final total = distribution.values.fold<int>(0, (sum, value) => sum + value);

 return Container(
 width: double.infinity,
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(12),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 ),
 padding: const EdgeInsets.all(16),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 children: [
 const Expanded(
 child: Text(
 'Risk Matrix Distribution',
 style: TextStyle(
 fontSize: 16,
 fontWeight: FontWeight.w700,
 color: Color(0xFF111827),
 ),
 ),
 ),
 Text(
 'Total: $total',
 style: const TextStyle(
 fontSize: 13,
 fontWeight: FontWeight.w600,
 color: Color(0xFF6B7280),
 ),
 ),
 ],
 ),
 const SizedBox(height: 4),
 const Text(
 'Distribution of risks by severity: Low, Medium, High, Critical.',
 style: TextStyle(fontSize: 12.5, color: Color(0xFF6B7280)),
 ),
 const SizedBox(height: 12),
 Wrap(
 spacing: 10,
 runSpacing: 10,
 children: [
 _buildDistributionTile(
 label: 'Critical',
 value: distribution['Critical'] ?? 0,
 background: const Color(0xFFFEE2E2),
 foreground: const Color(0xFFB91C1C),
 ),
 _buildDistributionTile(
 label: 'High',
 value: distribution['High'] ?? 0,
 background: const Color(0xFFFFE4E6),
 foreground: const Color(0xFFDC2626),
 ),
 _buildDistributionTile(
 label: 'Medium',
 value: distribution['Medium'] ?? 0,
 background: const Color(0xFFFFF7ED),
 foreground: const Color(0xFFC2410C),
 ),
 _buildDistributionTile(
 label: 'Low',
 value: distribution['Low'] ?? 0,
 background: const Color(0xFFDCFCE7),
 foreground: const Color(0xFF15803D),
 ),
 ],
 ),
 ],
 ),
 );
 }

 Widget _buildDistributionTile({
 required String label,
 required int value,
 required Color background,
 required Color foreground,
 }) {
 return Container(
 constraints: const BoxConstraints(minWidth: 132),
 padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
 decoration: BoxDecoration(
 color: background,
 borderRadius: BorderRadius.circular(10),
 border: Border.all(color: foreground.withOpacity(0.25)),
 ),
 child: Row(
 mainAxisSize: MainAxisSize.min,
 children: [
 Text(
 label,
 style: TextStyle(
 fontSize: 12.5,
 fontWeight: FontWeight.w700,
 color: foreground,
 ),
 ),
 const SizedBox(width: 10),
 Text(
 '$value',
 style: TextStyle(
 fontSize: 13,
 fontWeight: FontWeight.w800,
 color: foreground,
 ),
 ),
 ],
 ),
 );
 }

 Widget _buildRiskTable(BuildContext context) {
 final border = const BorderSide(color: Color(0xFFE5E7EB));
 final headerStyle = const TextStyle(
 fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF4B5563));
 final cellStyle = const TextStyle(fontSize: 14, color: Color(0xFF111827));

 return Container(
 key: _riskTableKey,
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(12),
 border: Border.all(
 color: _riskTableHasError
 ? const Color(0xFFEF4444)
 : const Color(0xFFE5E7EB),
 ),
 ),
 child: LayoutBuilder(
 builder: (context, constraints) {
 final minTableWidth = 1940.0;
 final tableWidth = constraints.maxWidth < minTableWidth
 ? minTableWidth
 : constraints.maxWidth;

 return Scrollbar(
 thumbVisibility: true,
 child: SingleChildScrollView(
 scrollDirection: Axis.horizontal,
 child: SizedBox(
 width: tableWidth,
 child: Table(
 columnWidths: const {
 0: FixedColumnWidth(60),
 1: FixedColumnWidth(220),
 2: FixedColumnWidth(260),
 3: FixedColumnWidth(130),
 4: FixedColumnWidth(100),
 5: FixedColumnWidth(100),
 6: FixedColumnWidth(120),
 7: FixedColumnWidth(260),
 8: FixedColumnWidth(140),
 9: FixedColumnWidth(160),
 10: FixedColumnWidth(140),
 11: FixedColumnWidth(120),
 12: FixedColumnWidth(132),
 },
 border: TableBorder(
 horizontalInside: border,
 verticalInside: border,
 top: border,
 bottom: border,
 left: border,
 right: border,
 ),
 defaultVerticalAlignment: TableCellVerticalAlignment.middle,
 children: [
 TableRow(
 decoration: const BoxDecoration(color: Color(0xFFF9FAFB)),
 children: [
 _th('ID', headerStyle),
 _th('Risk Title', headerStyle),
 _th('Description', headerStyle),
 _th('Category', headerStyle),
 _th('Probability', headerStyle),
 _th('Impact', headerStyle),
 _th('Risk Level', headerStyle),
 _th('Mitigation', headerStyle),
 _th('Discipline', headerStyle),
 _th('Project Role', headerStyle),
 _th('Owner', headerStyle),
 _th('Status', headerStyle),
 _th('Action', headerStyle),
 ],
 ),
 ...List.generate(_rows.length, (i) {
 final r = _rows[i];
 final severity = _displayRiskSeverity(r);
 final rowCanUndo = _canUndoRiskRow(i);
 return TableRow(children: [
 _td(Text(r.id, style: cellStyle),
 onDoubleTap: () => _showEditRiskSheet(i)),
 _td(
 _ExpandableCellText(
 text: r.risk,
 style: cellStyle,
 collapsedLines: 2,
 ),
 onDoubleTap: () => _showEditRiskSheet(i)),
 _td(
 _ExpandableCellText(
 text: r.description,
 style: cellStyle,
 collapsedLines: 2,
 ),
 onDoubleTap: () => _showEditRiskSheet(i)),
 _td(
 r.category.isEmpty
 ? const SizedBox.shrink()
 : _chip(r.category, const Color(0xFFF3E8FF),
 const Color(0xFF7C3AED)),
 onDoubleTap: () => _showEditRiskSheet(i)),
 _td(
 Text(
 r.probability.trim().isEmpty
 ? '-'
 : r.probability,
 style: cellStyle,
 ),
 onDoubleTap: () => _showEditRiskSheet(i)),
 _td(
 Text(
 r.impact.trim().isEmpty ? '-' : r.impact,
 style: cellStyle,
 ),
 onDoubleTap: () => _showEditRiskSheet(i)),
 _td(
 severity.isEmpty
 ? const SizedBox.shrink()
 : _riskLevelChip(severity),
 onDoubleTap: () => _showEditRiskSheet(i)),
 _td(
 _ExpandableCellText(
 text: r.mitigation,
 style: cellStyle,
 collapsedLines: 2,
 ),
 onDoubleTap: () => _showEditRiskSheet(i)),
 _td(
 _ExpandableCellText(
 text: r.discipline,
 style: cellStyle,
 collapsedLines: 2,
 ),
 onDoubleTap: () => _showEditRiskSheet(i)),
 _td(
 _ExpandableCellText(
 text: r.projectRole,
 style: cellStyle,
 collapsedLines: 2,
 ),
 onDoubleTap: () => _showEditRiskSheet(i)),
 _td(
 _ExpandableCellText(
 text: r.owner,
 style: cellStyle,
 collapsedLines: 2,
 ),
 onDoubleTap: () => _showEditRiskSheet(i)),
 _td(
 r.status.isEmpty
 ? const SizedBox.shrink()
 : _statusPill(r.status),
 onDoubleTap: () => _showEditRiskSheet(i)),
 _td(
 Center(
 child: Row(
 mainAxisSize: MainAxisSize.min,
 children: [
 InkWell(
 onTap: () => _showEditRiskSheet(i),
 borderRadius: BorderRadius.circular(8),
 child: Container(
 padding: const EdgeInsets.all(6),
 decoration: BoxDecoration(
 color: const Color(0xFFF3F4F6),
 borderRadius: BorderRadius.circular(8),
 ),
 child: const Icon(Icons.edit_outlined,
 size: 16, color: Color(0xFF4B5563)),
 ),
 ),
 const SizedBox(width: 6),
 InkWell(
 onTap:
 rowCanUndo ? () => _undoRiskRow(i) : null,
 borderRadius: BorderRadius.circular(8),
 child: Container(
 padding: const EdgeInsets.all(6),
 decoration: BoxDecoration(
 color: rowCanUndo
 ? const Color(0xFFEFF6FF)
 : const Color(0xFFF3F4F6),
 borderRadius: BorderRadius.circular(8),
 ),
 child: Icon(Icons.undo_rounded,
 size: 16,
 color: rowCanUndo
 ? const Color(0xFF2563EB)
 : const Color(0xFF9CA3AF)),
 ),
 ),
 const SizedBox(width: 6),
 InkWell(
 onTap: () => _confirmAndDeleteRow(i),
 borderRadius: BorderRadius.circular(8),
 child: Container(
 padding: const EdgeInsets.all(6),
 decoration: BoxDecoration(
 color: const Color(0xFFFEF2F2),
 borderRadius: BorderRadius.circular(8),
 ),
 child: const Icon(Icons.delete_outline,
 size: 16, color: Color(0xFFDC2626)),
 ),
 ),
 ],
 ),
 ),
 ),
 ]);
 }),
 ],
 ),
 ),
 ),
 );
 },
 ),
 );
 }

 Widget _th(String text, TextStyle style) {
 return Padding(
 padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
 child: Center(
 child: EditableContentText(
 contentKey:
 'fep_risks_header_${text.toLowerCase().replaceAll(' ', '_')}',
 fallback: text,
 category: 'front_end_planning',
 style: style,
 textAlign: TextAlign.center,
 ),
 ),
 );
 }

 Widget _td(Widget child, {VoidCallback? onDoubleTap}) {
 return Padding(
 padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
 child: onDoubleTap == null
 ? child
 : GestureDetector(
 onDoubleTap: onDoubleTap,
 behavior: HitTestBehavior.translucent,
 child: child,
 ),
 );
 }

 String _displayRiskSeverity(_RiskItem row) {
 if (row.riskLevel.trim().isEmpty &&
 row.probability.trim().isEmpty &&
 row.impact.trim().isEmpty) {
 return '';
 }
 return _resolveRiskSeverity(row);
 }

 Widget _riskLevelChip(String severity) {
 switch (severity) {
 case 'Critical':
 return _chip(
 severity, const Color(0xFFFEE2E2), const Color(0xFFB91C1C));
 case 'High':
 return _chip(
 severity, const Color(0xFFFFE4E6), const Color(0xFFDC2626));
 case 'Low':
 return _chip(
 severity, const Color(0xFFDCFCE7), const Color(0xFF16A34A));
 case 'Medium':
 default:
 return _chip(
 severity, const Color(0xFFFFF7ED), const Color(0xFFC2410C));
 }
 }

 Widget _chip(String label, Color bg, Color fg) {
 return Align(
 alignment: Alignment.centerLeft,
 child: Container(
 padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
 decoration: BoxDecoration(
 color: bg,
 borderRadius: BorderRadius.circular(18),
 ),
 child: Text(label,
 style: TextStyle(
 color: fg, fontSize: 12, fontWeight: FontWeight.w700)),
 ),
 );
 }

 Widget _statusPill(String status) {
 return Align(
 alignment: Alignment.centerLeft,
 child: Container(
 padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
 decoration: BoxDecoration(
 color: const Color(0xFFFFE4E6),
 borderRadius: BorderRadius.circular(16),
 ),
 child: Text(status,
 style: const TextStyle(
 color: Color(0xFFDC2626),
 fontSize: 12,
 fontWeight: FontWeight.w700)),
 ),
 );
 }
}

class _RiskItem {
 final String id;
 final String requirement;
 final String requirementType;
 final String risk;
 final String description;
 final String category;
 final String probability;
 final String impact;
 final String riskValue;
 final String riskLevel;
 final String mitigation;
 final String discipline;
 final String projectRole;
 final String owner;
 final String status;
 const _RiskItem({
 required this.id,
 required this.requirement,
 required this.requirementType,
 required this.risk,
 required this.description,
 required this.category,
 required this.probability,
 required this.impact,
 required this.riskValue,
 required this.riskLevel,
 required this.mitigation,
 required this.discipline,
 required this.projectRole,
 required this.owner,
 required this.status,
 });

 _RiskItem copyWith({
 String? id,
 String? requirement,
 String? requirementType,
 String? risk,
 String? description,
 String? category,
 String? probability,
 String? impact,
 String? riskValue,
 String? riskLevel,
 String? mitigation,
 String? discipline,
 String? projectRole,
 String? owner,
 String? status,
 }) {
 return _RiskItem(
 id: id ?? this.id,
 requirement: requirement ?? this.requirement,
 requirementType: requirementType ?? this.requirementType,
 risk: risk ?? this.risk,
 description: description ?? this.description,
 category: category ?? this.category,
 probability: probability ?? this.probability,
 impact: impact ?? this.impact,
 riskValue: riskValue ?? this.riskValue,
 riskLevel: riskLevel ?? this.riskLevel,
 mitigation: mitigation ?? this.mitigation,
 discipline: discipline ?? this.discipline,
 projectRole: projectRole ?? this.projectRole,
 owner: owner ?? this.owner,
 status: status ?? this.status,
 );
 }
}

class _RankedRiskRow {
 final _RiskItem row;
 final String severity;

 const _RankedRiskRow({
 required this.row,
 required this.severity,
 });
}

class _ExpandableCellText extends StatefulWidget {
 final String text;
 final TextStyle style;
 final int collapsedLines;

 const _ExpandableCellText({
 required this.text,
 required this.style,
 this.collapsedLines = 2,
 });

 @override
 State<_ExpandableCellText> createState() => _ExpandableCellTextState();
}

class _ExpandableCellTextState extends State<_ExpandableCellText> {
 bool _isExpanded = false;

 @override
 Widget build(BuildContext context) {
 final trimmed = widget.text.trim();
 if (trimmed.isEmpty) {
 return Text('-',
 style: widget.style.copyWith(color: const Color(0xFF9CA3AF)));
 }

 return LayoutBuilder(
 builder: (context, constraints) {
 final painter = TextPainter(
 text: TextSpan(text: trimmed, style: widget.style),
 textDirection: Directionality.of(context),
 maxLines: widget.collapsedLines,
 )..layout(maxWidth: constraints.maxWidth);

 final hasOverflow = painter.didExceedMaxLines;
 if (!hasOverflow) {
 return Text(trimmed, style: widget.style, softWrap: true);
 }

 return Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 trimmed,
 style: widget.style,
 maxLines: _isExpanded ? null : widget.collapsedLines,
 overflow:
 _isExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
 softWrap: true,
 ),
 const SizedBox(height: 4),
 InkWell(
 onTap: () => setState(() => _isExpanded = !_isExpanded),
 borderRadius: BorderRadius.circular(6),
 child: Padding(
 padding: const EdgeInsets.symmetric(vertical: 1),
 child: Text(
 _isExpanded ? 'View less' : 'View more',
 style: widget.style.copyWith(
 color: const Color(0xFF2563EB),
 fontSize: 12.5,
 fontWeight: FontWeight.w700,
 ),
 ),
 ),
 ),
 ],
 );
 },
 );
 }
}

class _BottomOverlays extends StatelessWidget {
 const _BottomOverlays({required this.onNext});
 final VoidCallback onNext;

 @override
 Widget build(BuildContext context) {
 return Positioned.fill(
 child: IgnorePointer(
 ignoring: false,
 child: Stack(
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
 _aiHint(),
 const SizedBox(width: 16),
 ElevatedButton(
 onPressed: onNext,
 style: ElevatedButton.styleFrom(
 backgroundColor: const Color(0xFFFFD700),
 foregroundColor: Colors.black,
 padding: const EdgeInsets.symmetric(
 horizontal: 28, vertical: 14),
 shape: RoundedRectangleBorder(
 borderRadius: BorderRadius.circular(22)),
 elevation: 0,
 ),
 child: const Text('Next',
 style: TextStyle(
 fontSize: 16, fontWeight: FontWeight.w600)),
 ),
 ],
 ),
 ),
 ],
 ),
 ),
 );
 }

 Widget _aiHint() {
 return Container(
 padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
 decoration: BoxDecoration(
 color: const Color(0xFFE6F1FF),
 borderRadius: BorderRadius.circular(12),
 border: Border.all(color: const Color(0xFFD7E5FF)),
 ),
 child: Row(
 children: const [
 Icon(Icons.lightbulb_outline, color: Color(0xFF2563EB)),
 SizedBox(width: 8),
 Text('Hint',
 style: TextStyle(
 fontWeight: FontWeight.w800, color: Color(0xFF2563EB))),
 SizedBox(width: 10),
 Text('Focus on major risks associated with each potential solution.',
 style: TextStyle(color: Color(0xFF1F2937))),
 ],
 ),
 );
 }
}

Widget _roundedField(
 {required TextEditingController controller,
 required String hint,
 int minLines = 1,
 int maxLines = 4}) {
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
 maxLines: maxLines,
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

class _LabeledField extends StatelessWidget {
 final String label;
 final TextEditingController controller;
 final bool autofocus;
 final bool enabled;
 final String? hintText;
 const _LabeledField({
 required this.label,
 required this.controller,
 this.hintText,
 this.autofocus = false,
 this.enabled = true,
 });

 @override
 Widget build(BuildContext context) {
 return Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(label,
 style: const TextStyle(
 fontSize: 12,
 fontWeight: FontWeight.w700,
 color: Color(0xFF6B7280))),
 const SizedBox(height: 6),
 Container(
 decoration: BoxDecoration(
 color: enabled ? Colors.white : const Color(0xFFF3F4F6),
 borderRadius: BorderRadius.circular(12),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 ),
 padding: const EdgeInsets.symmetric(horizontal: 12),
 child: VoiceTextField(
 controller: controller,
 autofocus: autofocus,
 enabled: enabled,
 decoration: InputDecoration(
 border: InputBorder.none,
 ),
 ),
 ),
 ],
 );
 }
}

class _LabeledDropdown extends StatelessWidget {
 final String label;
 final String? value;
 final List<String> items;
 final String? hint;
 final ValueChanged<String?> onChanged;

 const _LabeledDropdown({
 required this.label,
 required this.value,
 required this.items,
 required this.onChanged,
 this.hint,
 });

 @override
 Widget build(BuildContext context) {
 return Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(label,
 style: const TextStyle(
 fontSize: 12,
 fontWeight: FontWeight.w700,
 color: Color(0xFF6B7280))),
 const SizedBox(height: 6),
 Container(
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(12),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 ),
 padding: const EdgeInsets.symmetric(horizontal: 12),
 child: DropdownButtonHideUnderline(
 child: DropdownButton<String>(
 isExpanded: true,
 value: value,
 hint: hint == null
 ? null
 : Text(hint!,
 style: const TextStyle(color: Color(0xFF9CA3AF))),
 items: items
 .map(
 (e) => DropdownMenuItem<String>(value: e, child: Text(e)))
 .toList(),
 onChanged: onChanged,
 icon: const Icon(Icons.keyboard_arrow_down_rounded,
 color: Color(0xFF9CA3AF)),
 ),
 ),
 ),
 ],
 );
 }
}
