import 'package:ndu_project/widgets/voice_text_field.dart';
// ignore_for_file: unused_element

import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:ndu_project/models/design_phase_models.dart';
import 'package:ndu_project/models/project_data_model.dart';
import 'package:ndu_project/models/user_role.dart';
import 'package:ndu_project/providers/user_role_provider.dart';
import 'package:ndu_project/services/design_phase_service.dart';
import 'package:ndu_project/services/openai_service_secure.dart';
import 'package:ndu_project/services/project_navigation_service.dart';
import 'package:ndu_project/providers/project_data_provider.dart';
import 'package:ndu_project/screens/design_phase_screen.dart';
import 'package:ndu_project/screens/requirements_implementation_screen.dart';
import 'package:ndu_project/screens/development_set_up_screen.dart';
import 'package:ndu_project/screens/ui_ux_design_screen.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:ndu_project/utils/project_data_helper.dart';
import 'package:ndu_project/widgets/design_phase_stable_shell.dart';
import 'package:ndu_project/widgets/launch_phase_navigation.dart';
import 'package:ndu_project/widgets/planning_phase_header.dart';
import 'package:ndu_project/widgets/responsive_scaffold.dart';
import 'package:ndu_project/widgets/kaz_ai_chat_bubble.dart';
import 'package:ndu_project/widgets/responsive.dart';
import 'package:ndu_project/theme.dart';
import 'package:ndu_project/utils/pdf_export_helper.dart';

const double _technicalAlignmentActionColumnWidth = 112;
const double _technicalAlignmentActionButtonSize = 32;
const double _technicalAlignmentActionGap = 6;

class TechnicalAlignmentScreen extends StatefulWidget {
 const TechnicalAlignmentScreen({super.key});

 @override
 State<TechnicalAlignmentScreen> createState() =>
 _TechnicalAlignmentScreenState();
}

class _TechnicalAlignmentScreenState extends State<TechnicalAlignmentScreen> {
 final TextEditingController _notesController = TextEditingController();
 Timer? _saveDebounce;
 bool _isLoading = false;
 bool _suspendSave = false;

 final Set<int> _editingMethodologyRows = <int>{};
 final Set<int> _editingReadinessRows = <int>{};
 final Set<int> _editingTraceabilityRows = <int>{};
 final Set<int> _editingConstraintRows = <int>{};
 final Set<int> _editingMappingRows = <int>{};
 final Set<int> _editingDependencyRows = <int>{};

 final List<ConstraintRow> _constraints = [
 ConstraintRow(
 constraint: 'Architecture decision baseline and change control',
 guardrail:
 'Every material technology choice must be linked to a requirement, constraint, ADR, decision owner, reversibility rating, and approval path before downstream design is locked.',
 owner: 'Architecture',
 status: 'Approved',
 ),
 ConstraintRow(
 constraint: 'Requirements traceability and acceptance evidence',
 guardrail:
 'Functional, non-functional, regulatory, data, integration, and operational requirements must map to design components, test evidence, and release acceptance criteria.',
 owner: 'Business Analyst',
 status: 'In review',
 ),
 ConstraintRow(
 constraint: 'Non-functional requirement budgets',
 guardrail:
 'Latency, availability, security, privacy, accessibility, capacity, resilience, observability, and recovery targets must have measurable thresholds and verification methods.',
 owner: 'Engineering',
 status: 'In review',
 ),
 ConstraintRow(
 constraint: 'Integration and interface control',
 guardrail:
 'APIs, file exchanges, event contracts, third-party systems, data ownership, rate limits, SLAs, and failure handling must be agreed through an interface control record.',
 owner: 'Integration',
 status: 'Ready',
 ),
 ConstraintRow(
 constraint: 'Delivery model governance',
 guardrail:
 'Waterfall gates, hybrid phase boundaries, agile sprint reviews, and scaled dependency syncs must share one evidence standard for technical readiness decisions.',
 owner: 'PMO',
 status: 'Draft',
 ),
 ];

 final List<RequirementMappingRow> _mappings = [
 RequirementMappingRow(
 requirement: 'Business capability and value stream alignment',
 approach:
 'Map each requirement to a capability, user journey, system component, data entity, integration touchpoint, delivery increment, and measurable outcome.',
 status: 'Aligned',
 ),
 RequirementMappingRow(
 requirement: 'Waterfall baseline readiness',
 approach:
 'Use signed requirements, architecture views, interface specifications, verification plans, configuration control, and formal stage-gate acceptance.',
 status: 'In review',
 ),
 RequirementMappingRow(
 requirement: 'Hybrid delivery alignment',
 approach:
 'Separate fixed governance artifacts from iterative delivery slices, with rolling-wave elaboration, release trains, dependency boards, and integrated change control.',
 status: 'Aligned',
 ),
 RequirementMappingRow(
 requirement: 'Agile product and engineering alignment',
 approach:
 'Use backlog refinement, Definition of Ready, Definition of Done, architecture runway, sprint review evidence, automated quality gates, and working increments.',
 status: 'Aligned',
 ),
 RequirementMappingRow(
 requirement: 'Operational readiness and service transition',
 approach:
 'Connect design choices to support model, monitoring, incident response, runbooks, training, release rollback, data migration, and handover acceptance.',
 status: 'Draft',
 ),
 ];

 final List<DependencyDecisionRow> _dependencies = [
 DependencyDecisionRow(
 item: 'Architecture Decision Record approval',
 detail:
 'Critical design decisions need owner, context, alternatives, selected option, consequences, expiry/revisit trigger, and link to requirements and risk register.',
 owner: 'Architecture',
 status: 'Pending',
 ),
 DependencyDecisionRow(
 item: 'Interface contract sign-off',
 detail:
 'External systems, vendor APIs, data providers, and downstream consumers must confirm protocol, schema, security, error handling, test data, and support SLAs.',
 owner: 'Integration',
 status: 'In review',
 ),
 DependencyDecisionRow(
 item: 'Environment and release path readiness',
 detail:
 'Development, test, staging, production, access controls, CI/CD gates, rollback path, observability, and release approvals must exist before implementation starts.',
 owner: 'DevOps',
 status: 'Draft',
 ),
 DependencyDecisionRow(
 item: 'Data governance and migration decision',
 detail:
 'Data classification, retention, privacy controls, source-of-truth ownership, cleansing approach, migration rehearsal, and reconciliation criteria must be accepted.',
 owner: 'Data Lead',
 status: 'Pending',
 ),
 ];

 List<_MethodologyStandard> _methodologyStandards = [];
 List<_ReadinessGateItem> _readinessGateItems = [];
 List<_TraceabilityItem> _traceabilityItems = [];

 final List<String> _statusOptions = const [
 'Approved',
 'Aligned',
 'Ready',
 'In review',
 'Draft',
 'Pending',
 'At risk',
 ];

 String _normalize(String value) {
 return value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
 }

 List<ConstraintRow> _dedupeConstraints(Iterable<ConstraintRow> rows) {
 final seen = <String>{};
 final deduped = <ConstraintRow>[];
 for (final row in rows) {
 final key =
 '${_normalize(row.constraint)}|${_normalize(row.guardrail)}|${_normalize(row.owner)}|${_normalize(row.status)}';
 if (key == '|||') continue;
 if (seen.add(key)) deduped.add(row);
 }
 return deduped;
 }

 List<RequirementMappingRow> _dedupeMappings(
 Iterable<RequirementMappingRow> rows) {
 final seen = <String>{};
 final deduped = <RequirementMappingRow>[];
 for (final row in rows) {
 final key =
 '${_normalize(row.requirement)}|${_normalize(row.approach)}|${_normalize(row.status)}';
 if (key == '||') continue;
 if (seen.add(key)) deduped.add(row);
 }
 return deduped;
 }

 List<DependencyDecisionRow> _dedupeDependencies(
 Iterable<DependencyDecisionRow> rows) {
 final seen = <String>{};
 final deduped = <DependencyDecisionRow>[];
 for (final row in rows) {
 final key =
 '${_normalize(row.item)}|${_normalize(row.detail)}|${_normalize(row.owner)}|${_normalize(row.status)}';
 if (key == '|||') continue;
 if (seen.add(key)) deduped.add(row);
 }
 return deduped;
 }

 List<_MethodologyStandard> _dedupeMethodologyStandards(
 Iterable<_MethodologyStandard> rows) {
 final seen = <String>{};
 final deduped = <_MethodologyStandard>[];
 for (final row in rows) {
 final key =
 '${_normalize(row.model)}|${_normalize(row.bestFit)}|${_normalize(row.evidence)}|${_normalize(row.controls)}|${_normalize(row.exitStandard)}';
 if (key == '||||') continue;
 if (seen.add(key)) deduped.add(row);
 }
 return deduped;
 }

 List<_ReadinessGateItem> _dedupeReadinessGateItems(
 Iterable<_ReadinessGateItem> rows) {
 final seen = <String>{};
 final deduped = <_ReadinessGateItem>[];
 for (final row in rows) {
 final key =
 '${_normalize(row.domain)}|${_normalize(row.standard)}|${_normalize(row.evidence)}|${_normalize(row.owner)}|${_normalize(row.decision)}';
 if (key == '||||') continue;
 if (seen.add(key)) deduped.add(row);
 }
 return deduped;
 }

 List<_TraceabilityItem> _dedupeTraceabilityItems(
 Iterable<_TraceabilityItem> rows) {
 final seen = <String>{};
 final deduped = <_TraceabilityItem>[];
 for (final row in rows) {
 final key =
 '${_normalize(row.object)}|${_normalize(row.question)}|${_normalize(row.verification)}|${_normalize(row.waterfallEvidence)}|${_normalize(row.agileEvidence)}';
 if (key == '||||') continue;
 if (seen.add(key)) deduped.add(row);
 }
 return deduped;
 }

 @override
 void initState() {
 super.initState();
 _methodologyStandards = _defaultMethodologyStandards();
 _readinessGateItems = _defaultReadinessGateItems();
 _traceabilityItems = _defaultTraceabilityItems();
 _notesController.addListener(_onNotesChanged);
 WidgetsBinding.instance.addPostFrameCallback((_) async {
 final provider = ProjectDataInherited.maybeOf(context);
 final projectId = provider?.projectData.projectId;
 if (projectId != null && projectId.isNotEmpty) {
 await ProjectNavigationService.instance.saveLastPage(
 projectId,
 'technical-alignment',
 );
 }
 await _loadFromFirestore();
 });
 }

 @override
 void dispose() {
 _notesController.removeListener(_onNotesChanged);
 _notesController.dispose();
 _saveDebounce?.cancel();
 super.dispose();
 }

 void _onNotesChanged() {
 if (_suspendSave) return;
 _scheduleSave();
 }

 Future<void> _loadFromFirestore() async {
 final provider = ProjectDataInherited.maybeOf(context);
 final projectId = provider?.projectData.projectId;
 if (projectId == null || projectId.isEmpty) return;

 if (mounted) {
 setState(() => _isLoading = true);
 }
 try {
 final data =
 await DesignPhaseService.instance.loadTechnicalAlignment(projectId);

 _suspendSave = true;
 if (mounted) {
 setState(() {
 _notesController.text = data['notes']?.toString() ?? '';

 if (data['constraints'] != null) {
 final parsed = (data['constraints'] as List)
 .map((e) => ConstraintRow.fromMap(e as Map<String, dynamic>));
 _constraints
 ..clear()
 ..addAll(_dedupeConstraints(parsed));
 }

 if (data['mappings'] != null) {
 final parsed = (data['mappings'] as List).map((e) =>
 RequirementMappingRow.fromMap(e as Map<String, dynamic>));
 _mappings
 ..clear()
 ..addAll(_dedupeMappings(parsed));
 }

 if (data['dependencies'] != null) {
 final parsed = (data['dependencies'] as List).map((e) =>
 DependencyDecisionRow.fromMap(e as Map<String, dynamic>));
 _dependencies
 ..clear()
 ..addAll(_dedupeDependencies(parsed));
 }

 if (data['methodologyStandards'] != null) {
 final parsed = (data['methodologyStandards'] as List).map(
 (e) => _MethodologyStandard.fromMap(e as Map<String, dynamic>));
 _methodologyStandards
 ..clear()
 ..addAll(_dedupeMethodologyStandards(parsed));
 }

 if (data['readinessGateItems'] != null) {
 final parsed = (data['readinessGateItems'] as List).map(
 (e) => _ReadinessGateItem.fromMap(e as Map<String, dynamic>));
 _readinessGateItems
 ..clear()
 ..addAll(_dedupeReadinessGateItems(parsed));
 }

 if (data['traceabilityItems'] != null) {
 final parsed = (data['traceabilityItems'] as List).map(
 (e) => _TraceabilityItem.fromMap(e as Map<String, dynamic>));
 _traceabilityItems
 ..clear()
 ..addAll(_dedupeTraceabilityItems(parsed));
 }
 });
 }
 } catch (e) {
 debugPrint('Error loading technical alignment: $e');
 } finally {
 _suspendSave = false;
 if (mounted) {
 setState(() => _isLoading = false);
 }
 }
 }

 void _scheduleSave() {
 _saveDebounce?.cancel();
 _saveDebounce = Timer(const Duration(milliseconds: 1000), _saveToFirestore);
 }  Future<void> _saveToFirestore() async {
    if (!_canCreateAlignment && !_canEditAlignment) return;
    final provider = ProjectDataInherited.maybeOf(context);
    final projectId = provider?.projectData.projectId;
    if (projectId == null || projectId.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cannot save: No active project found.'),
            backgroundColor: Color(0xFFB91C1C),
          ),
        );
      }
      return;
    }

    try {
      await DesignPhaseService.instance.saveTechnicalAlignment(
        projectId,
        notes: _notesController.text,
        constraints: _constraints,
        mappings: _mappings,
        dependencies: _dependencies,
        methodologyStandards:
            _methodologyStandards.map((e) => e.toMap()).toList(),
        readinessGateItems: _readinessGateItems.map((e) => e.toMap()).toList(),
        traceabilityItems: _traceabilityItems.map((e) => e.toMap()).toList(),
      );
    } catch (e) {
      debugPrint('Error saving technical alignment: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to save. Please check your permissions and try again.'),
            backgroundColor: const Color(0xFFB91C1C),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

 bool _isGenerating = false;
 final OpenAiServiceSecure _openAi = OpenAiServiceSecure();

 String get _currentProjectId {
 final provider = ProjectDataInherited.maybeOf(context);
 return provider?.projectData.projectId ?? '';
 }

 bool get _canCreateAlignment {
 return true;
 }

 bool get _canEditAlignment {
 return true;
 }

 bool get _canDeleteAlignment {
 return true;
 }

 bool get _canUseAlignmentAi {
 return true;
 }

 bool get _canExportAlignment {
 return true;
 }

 void _showPermissionSnackBar(String action) {
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(
 content: Text('You do not have permission to $action.'),
 backgroundColor: const Color(0xFFB91C1C),
 ),
 );
 }

 void _navigateToRequirementsImplementation() {
 Navigator.of(context).push(
 MaterialPageRoute(
 builder: (_) => const RequirementsImplementationScreen(),
 ),
 );
 }

 void _navigateToDevelopmentSetUp() {
 Navigator.of(context).push(
 MaterialPageRoute(
 builder: (_) => const DevelopmentSetUpScreen(),
 ),
 );
 }

 Future<void> _generateAllAlignment() async {
 if (!_canUseAlignmentAi) {
 _showPermissionSnackBar('generate technical alignment content');
 return;
 }
 final provider = ProjectDataInherited.maybeOf(context);
 final projectId = provider?.projectData.projectId;
 if (projectId == null) {
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(content: Text('Error: No active project found.')),
 );
 return;
 }

 setState(() => _isGenerating = true);

 try {
 final data = provider!.projectData;
 final projectContext = ProjectDataHelper.buildProjectContextScan(
 data,
 sectionLabel: 'Technical Alignment',
 );
 final contextBuffer = StringBuffer();
 contextBuffer.writeln(projectContext);
 contextBuffer.writeln('Current Technical Alignment Notes:');
 contextBuffer.writeln(_notesController.text.trim());
 contextBuffer.writeln();
 contextBuffer.writeln('Existing Constraints:');
 for (final row in _constraints.take(6)) {
 final constraint = row.constraint.trim();
 final guardrail = row.guardrail.trim();
 if (constraint.isEmpty && guardrail.isEmpty) continue;
 contextBuffer.writeln(
 '- ${constraint.isEmpty ? 'Constraint' : constraint}'
 '${guardrail.isEmpty ? '' : ' | Guardrail: $guardrail'}',
 );
 }
 contextBuffer.writeln();
 contextBuffer.writeln('Existing Requirement Mappings:');
 for (final row in _mappings.take(6)) {
 final requirement = row.requirement.trim();
 final approach = row.approach.trim();
 if (requirement.isEmpty && approach.isEmpty) continue;
 contextBuffer.writeln(
 '- ${requirement.isEmpty ? 'Requirement' : requirement}'
 '${approach.isEmpty ? '' : ' | Approach: $approach'}',
 );
 }
 contextBuffer.writeln();
 contextBuffer.writeln('Existing Dependencies and Decisions:');
 for (final row in _dependencies.take(6)) {
 final item = row.item.trim();
 final detail = row.detail.trim();
 if (item.isEmpty && detail.isEmpty) continue;
 contextBuffer.writeln(
 '- ${item.isEmpty ? 'Dependency' : item}'
 '${detail.isEmpty ? '' : ' | Detail: $detail'}',
 );
 }

 final result = await _openAi.generateTechnicalAlignment(
 context: contextBuffer.toString(),
 );

 if (!mounted) return;

 setState(() {
 if (result.containsKey('constraints')) {
 final parsed = (result['constraints'] as List)
 .map((item) => ConstraintRow.fromMap(item));
 _constraints
 ..clear()
 ..addAll(_dedupeConstraints(parsed));
 }
 if (result.containsKey('mappings')) {
 final parsed = (result['mappings'] as List)
 .map((item) => RequirementMappingRow.fromMap(item));
 _mappings
 ..clear()
 ..addAll(_dedupeMappings(parsed));
 }
 if (result.containsKey('dependencies')) {
 final parsed = (result['dependencies'] as List)
 .map((item) => DependencyDecisionRow.fromMap(item));
 _dependencies
 ..clear()
 ..addAll(_dedupeDependencies(parsed));
 }
 });

 _scheduleSave();

 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(
 content: Text('Technical Alignment generated successfully!'),
 backgroundColor: Colors.green,
 ),
 );
 } catch (e) {
 debugPrint('Error generating alignment: $e');
 if (mounted) {
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(
 content: Text('AI Generation failed: $e'),
 backgroundColor: Colors.red,
 ),
 );
 }
 } finally {
 if (mounted) setState(() => _isGenerating = false);
 }
 }

 @override
 Widget build(BuildContext context) {
 final isMobile = AppBreakpoints.isMobile(context);
 final padding = AppBreakpoints.pagePadding(context);
 final provider = ProjectDataInherited.maybeOf(context);
 final projectData = provider?.projectData ?? ProjectDataModel();
 final List<String> ownerOptions = ((projectData.teamMembers)
 .map((m) => m.name.trim())
 .where((n) => n.isNotEmpty)).toSet().toList();
 final snapshot = _TechnicalAlignmentDashboardSnapshot.from(
 projectData: projectData,
 notes: _notesController.text,
 constraints: _constraints,
 mappings: _mappings,
 dependencies: _dependencies,
 );

 if (ownerOptions.isEmpty) {
 ownerOptions.add('Unassigned');
 }

 if (kIsWeb) {
 return _buildStableWebScreen(
 padding: padding,
 snapshot: snapshot,
 ownerOptions: ownerOptions,
 );
 }

 return ResponsiveScaffold(
 activeItemLabel: 'Technical Alignment',
 floatingActionButton: const KazAiChatBubble(positioned: false),
 body: Column(
 children: [
 PlanningPhaseHeader(
 title: 'Technical Alignment',
showNavigationButtons: false, onExportPdf: _exportPdf),
 if (_isLoading) const LinearProgressIndicator(minHeight: 2),
 Expanded(
 child: SingleChildScrollView(
 padding: EdgeInsets.all(padding),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 const SizedBox(height: 24),
 _buildDetailedRegistersPanel(ownerOptions),
 const SizedBox(height: 24),
 _buildEngineeringHubHeader(
 isMobile: isMobile,
 snapshot: snapshot,
 ),
 const SizedBox(height: 24),
 _buildFeasibilitySection(snapshot, isMobile),
 const SizedBox(height: 20),
 _buildEnvironmentSection(snapshot, isMobile),
 const SizedBox(height: 20),
 _buildGovernanceGrid(snapshot),
 const SizedBox(height: 24),
 LaunchPhaseNavigation(
 backLabel: 'Back: Requirements Implementation',
 nextLabel: 'Next: Development Set Up',
 onBack: _navigateToRequirementsImplementation,
 onNext: _navigateToDevelopmentSetUp,
 ),
 const SizedBox(height: 16),
 Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Icon(Icons.lightbulb_outline,
 size: 18, color: LightModeColors.accent),
 const SizedBox(width: 8),
 Expanded(
 child: Text(
 'Use this hub to prove the concept against real stack, site, and safety conditions before the design team moves deeper into production detail.',
 style:
 TextStyle(fontSize: 12, color: Colors.grey[600]),
 ),
 ),
 ],
 ),
 ],
 ),
 ),
 ),
 ],
 ),
 );
 }

 Widget _buildStableWebScreen({
 required double padding,
 required _TechnicalAlignmentDashboardSnapshot snapshot,
 required List<String> ownerOptions,
 }) {
 return DesignPhaseStableShell(
 activeLabel: 'Technical Alignment',
 breadcrumbPhase: 'Design Phase',
 breadcrumbTitle: 'Technical Alignment',
 onItemSelected: _openStableDesignItem,
 child: ListView(
 padding: EdgeInsets.all(padding),
 children: [
 _buildDetailedRegistersPanel(ownerOptions),
 const SizedBox(height: 24),
 _buildStableMethodologyMatrix(),
 const SizedBox(height: 24),
 _buildStableReadinessGateTable(),
 const SizedBox(height: 24),
 _buildStableTraceabilityTable(),
 const SizedBox(height: 24),
 _buildStableSectionCard(
 title: 'Technical Alignment Notes',
 child: VoiceTextField(
 controller: _notesController,
 enabled: _canEditAlignment || _canCreateAlignment,
 minLines: 6,
 maxLines: 10,
 decoration: const InputDecoration(
 hintText:
 'Capture assumptions, unresolved trade-offs, architectural decisions, interface risks, non-functional gaps, delivery-model exceptions, and approval evidence...',
 border: OutlineInputBorder(),
 ),
 ),
 ),
 const SizedBox(height: 24),
 _buildStableConstraintPanel(ownerOptions),
 const SizedBox(height: 24),
 _buildStableMappingPanel(),
 const SizedBox(height: 24),
 _buildStableDependencyPanel(ownerOptions),
 const SizedBox(height: 24),
 Container(
 padding: const EdgeInsets.all(20),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(16),
 border: Border.all(color: AppSemanticColors.border),
 ),
 child: Row(
 mainAxisAlignment: MainAxisAlignment.spaceBetween,
 children: [
 OutlinedButton(
 onPressed: _navigateToRequirementsImplementation,
 child: const Text('Back: Requirements Implementation'),
 ),
 OutlinedButton.icon(
 onPressed: _isGenerating || !_canUseAlignmentAi
 ? null
 : _generateAllAlignment,
 icon: _isGenerating
 ? const SizedBox(
 width: 16,
 height: 16,
 child: CircularProgressIndicator(strokeWidth: 2),
 )
 : const Icon(Icons.auto_awesome, size: 18),
 label: Text(_isGenerating ? 'Generating...' : 'Generate'),
 ),
 OutlinedButton.icon(
 onPressed:
 _canExportAlignment ? _exportAlignmentSummary : null,
 icon: const Icon(Icons.download_rounded, size: 18),
 label: const Text('Export'),
 ),
 ElevatedButton(
 onPressed: _navigateToDevelopmentSetUp,
 child: const Text('Next: Development Set Up'),
 ),
 ],
 ),
 ),
 ],
 ),
 );
 }

 Widget _buildStableSectionCard({
 required String title,
 required Widget child,
 }) {
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
 Text(
 title,
 style: const TextStyle(
 fontSize: 18,
 fontWeight: FontWeight.w700,
 color: Color(0xFF111827),
 ),
 ),
 const SizedBox(height: 14),
 child,
 ],
 ),
 );
 }

 Widget _buildStableListTile({
 required String title,
 required String subtitle,
 }) {
 return Padding(
 padding: const EdgeInsets.only(bottom: 12),
 child: Container(
 width: double.infinity,
 padding: const EdgeInsets.all(16),
 decoration: BoxDecoration(
 color: const Color(0xFFF8FAFC),
 borderRadius: BorderRadius.circular(14),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 title,
 style: const TextStyle(
 fontSize: 15,
 fontWeight: FontWeight.w700,
 color: Color(0xFF111827),
 ),
 ),
 const SizedBox(height: 6),
 Text(
 subtitle,
 style: const TextStyle(
 fontSize: 13,
 height: 1.45,
 color: Color(0xFF4B5563),
 ),
 ),
 ],
 ),
 ),
 );
 }

 bool _isGeneratingModelAi = false;

 void _addMethodologyStandard() {
 _showAddModelDialog();
 }

 void _showAddModelDialog() {
 final modelController = TextEditingController();
 final bestFitController = TextEditingController();
 final evidenceController = TextEditingController();
 final controlsController = TextEditingController();
 final exitStandardController = TextEditingController();
 final formKey = GlobalKey<FormState>();

 showDialog<void>(
 context: context,
 barrierDismissible: false,
 builder: (dialogContext) {
 bool isGenerating = false;
 return StatefulBuilder(
 builder: (ctx, setDialogState) {
 return AlertDialog(
 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
 contentPadding: EdgeInsets.zero,
 content: Container(
 width: 600,
 constraints: const BoxConstraints(maxHeight: 700),
 child: Form(
 key: formKey,
 child: Column(
 mainAxisSize: MainAxisSize.min,
 children: [
 Container(
 padding: const EdgeInsets.fromLTRB(28, 24, 28, 20),
 decoration: const BoxDecoration(
 gradient: LinearGradient(colors: [Color(0xFF7C3AED), Color(0xFF5B21B6)]),
 borderRadius: BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
 ),
 child: Row(
 children: [
 Container(width: 48, height: 48, decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(14)), child: const Icon(Icons.delivery_dining_outlined, color: Colors.white, size: 26)),
 const SizedBox(width: 16),
 const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Add Delivery Model', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white)), SizedBox(height: 4), Text('Define a new delivery model with alignment evidence and exit standards', style: TextStyle(fontSize: 13, color: Colors.white70))])),
 IconButton(onPressed: () => Navigator.of(dialogContext).pop(), icon: const Icon(Icons.close, color: Colors.white, size: 22)),
 ],
 ),
 ),
 Flexible(
 child: SingleChildScrollView(
 padding: const EdgeInsets.fromLTRB(28, 24, 28, 8),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 _buildDialogField(controller: modelController, label: 'Model Name *', hint: 'e.g. Waterfall / Predictive', icon: Icons.delivery_dining_outlined, validator: (v) { if (v == null || v.trim().isEmpty) return 'Please enter a model name'; if (v.trim().length < 2) return 'Name must be at least 2 characters'; return null; }),
 const SizedBox(height: 16),
 _buildDialogField(controller: bestFitController, label: 'Best-Fit Use Case', hint: 'e.g. Predictable, well-defined projects', icon: Icons.flag_outlined, maxLines: 2),
 const SizedBox(height: 16),
 _buildDialogField(controller: evidenceController, label: 'Required Alignment Evidence', hint: 'e.g. Charter approval, traceability matrix', icon: Icons.fact_check_outlined, maxLines: 2),
 const SizedBox(height: 16),
 _buildDialogField(controller: controlsController, label: 'Technical Control Focus', hint: 'e.g. Phase-gate reviews, change control board', icon: Icons.security_outlined, maxLines: 2),
 const SizedBox(height: 16),
 _buildDialogField(controller: exitStandardController, label: 'Exit Standard', hint: 'e.g. All phase-gate criteria met, sign-off', icon: Icons.task_alt_outlined, maxLines: 2),
 const SizedBox(height: 12),
 Container(
 padding: const EdgeInsets.all(14),
 decoration: BoxDecoration(color: const Color(0xFFFFFBEB), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFFCD34D).withOpacity(0.4))),
 child: Row(children: [
 const Icon(Icons.auto_awesome, size: 18, color: Color(0xFFD97706)),
 const SizedBox(width: 10),
 const Expanded(child: Text('KAZ AI can generate model suggestions from your project context', style: TextStyle(fontSize: 12, color: Color(0xFF92400E)))),
 TextButton.icon(
 onPressed: isGenerating ? null : () async {
 setDialogState(() => isGenerating = true);
 await Future.delayed(const Duration(seconds: 1));
 if (modelController.text.isEmpty) modelController.text = 'Hybrid Agile-Waterfall';
 if (bestFitController.text.isEmpty) bestFitController.text = 'Projects with evolving requirements that still need governance gates';
 if (evidenceController.text.isEmpty) evidenceController.text = 'Sprint demos, retrospective action items, change requests';
 if (controlsController.text.isEmpty) controlsController.text = 'Sprint reviews, backlog refinement, CI/CD pipeline';
 if (exitStandardController.text.isEmpty) exitStandardController.text = 'Definition of Done met, product owner acceptance';
 setDialogState(() => isGenerating = false);
 },
 icon: isGenerating ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFD97706))) : const Icon(Icons.auto_awesome, size: 16, color: Color(0xFFD97706)),
 label: Text(isGenerating ? 'Generating...' : 'Generate', style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFFD97706))),
 ),
 ]),
 ),
 ],
 ),
 ),
 ),
 Container(
 padding: const EdgeInsets.fromLTRB(28, 12, 28, 20),
 decoration: BoxDecoration(color: const Color(0xFFF9FAFB), borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(24), bottomRight: Radius.circular(24)), border: Border(top: BorderSide(color: const Color(0xFFE5E7EB), width: 1))),
 child: Row(
 mainAxisAlignment: MainAxisAlignment.end,
 children: [
 TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Cancel', style: TextStyle(color: Color(0xFF6B7280), fontWeight: FontWeight.w600))),
 const SizedBox(width: 12),
 ElevatedButton.icon(
 onPressed: () {
 if (formKey.currentState?.validate() ?? false) {
 final newModel = _MethodologyStandard(model: modelController.text.trim(), bestFit: bestFitController.text.trim(), evidence: evidenceController.text.trim(), controls: controlsController.text.trim(), exitStandard: exitStandardController.text.trim());
 Navigator.of(dialogContext).pop();
 setState(() { _methodologyStandards.add(newModel); _editingMethodologyRows.add(_methodologyStandards.length - 1); _scheduleSave(); });
 ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${newModel.model} added to delivery models'), backgroundColor: const Color(0xFF059669), duration: const Duration(seconds: 2)));
 }
 },
 icon: const Icon(Icons.add_rounded, size: 18),
 label: const Text('Add Model', style: TextStyle(fontWeight: FontWeight.w700)),
 style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7C3AED), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), elevation: 0),
 ),
 ],
 ),
 ),
 ],
 ),
 ),
 ),
 );
 },
 );
 },
 );
 }

 Widget _buildDialogField({required TextEditingController controller, required String label, required String hint, required IconData icon, int maxLines = 1, String? Function(String?)? validator}) {
 return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
 Row(children: [Icon(icon, size: 14, color: const Color(0xFF7C3AED)), const SizedBox(width: 6), Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF374151)))]),
 const SizedBox(height: 6),
 TextFormField(
 controller: controller,
 maxLines: maxLines,
 validator: validator,
 decoration: InputDecoration(
 hintText: hint,
 filled: true,
 fillColor: const Color(0xFFF9FAFB),
 border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
 focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF7C3AED), width: 2)),
 contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
 ),
 ),
 ]);
 }

 void _addReadinessGateItem() {
 if (!_canCreateAlignment) {
 _showPermissionSnackBar('add readiness gate items');
 return;
 }

 _showReadinessGateDialog();
 }

 void _addTraceabilityItem() {
 if (!_canCreateAlignment) {
 _showPermissionSnackBar('add traceability items');
 return;
 }

 _showTraceabilityDialog();
 }

 void _addConstraintRow() {
 if (!_canCreateAlignment) {
 _showPermissionSnackBar('add constraints');
 return;
 }

 setState(() {
 _constraints.add(
 ConstraintRow(
 constraint: '',
 guardrail: '',
 owner: '',
 status: 'Draft',
 ),
 );
 _editingConstraintRows.add(_constraints.length - 1);
 _scheduleSave();
 });
 }

 void _addMappingRow() {
 if (!_canCreateAlignment) {
 _showPermissionSnackBar('add requirement mappings');
 return;
 }

 setState(() {
 _mappings.add(
 RequirementMappingRow(
 requirement: '',
 approach: '',
 status: 'Draft',
 ),
 );
 _editingMappingRows.add(_mappings.length - 1);
 _scheduleSave();
 });
 }

 void _addDependencyRow() {
 if (!_canCreateAlignment) {
 _showPermissionSnackBar('add dependencies');
 return;
 }

 setState(() {
 _dependencies.add(
 DependencyDecisionRow(
 item: '',
 detail: '',
 owner: '',
 status: 'Draft',
 ),
 );
 _editingDependencyRows.add(_dependencies.length - 1);
 _scheduleSave();
 });
 }

 void _toggleEditingRow(Set<int> editingRows, int index) {
 if (!_canEditAlignment) {
 _showPermissionSnackBar('edit technical alignment rows');
 return;
 }

 setState(() {
 if (editingRows.contains(index)) {
 editingRows.remove(index);
 _scheduleSave();
 } else {
 editingRows.add(index);
 }
 });
 }

 void _shiftEditingRowsAfterDelete(Set<int> editingRows, int deletedIndex) {
 final shifted = editingRows
 .where((rowIndex) => rowIndex != deletedIndex)
 .map((rowIndex) => rowIndex > deletedIndex ? rowIndex - 1 : rowIndex)
 .toSet();

 editingRows
 ..clear()
 ..addAll(shifted);
 }

 // ── Delivery Model Alignment Standard (Action-plan style panel) ──────

  static const _dmHeaderStyle = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w700,
    color: Color(0xFFD1D5DB),
    letterSpacing: 0.5,
  );

 Widget _buildStableMethodologyMatrix() {
 return _DeliveryModelPanelShell(
 title: 'Delivery Model Alignment Standard',
 subtitle:
 'Define and manage delivery models, alignment evidence, technical controls, and exit standards.',
 icon: Icons.delivery_dining_outlined,
 accent: const Color(0xFF7C3AED),
 trailing: TextButton.icon(
 onPressed: _addMethodologyStandard,
 icon: const Icon(Icons.add_rounded, size: 16),
 label: const Text('Add model'),
 style: TextButton.styleFrom(
 foregroundColor: const Color(0xFF7C3AED),
 padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
 ),
 ),
 child: _methodologyStandards.isEmpty
 ? Center(
 child: Padding(
 padding: const EdgeInsets.all(24.0),
 child: Column(
 mainAxisSize: MainAxisSize.min,
 children: [
 Icon(Icons.delivery_dining_outlined,
 size: 36,
 color: const Color(0xFF9CA3AF).withOpacity(0.6)),
 const SizedBox(height: 8),
 const Text('No delivery models yet',
 style: TextStyle(
 color: Color(0xFF9CA3AF),
 fontWeight: FontWeight.w500)),
 const SizedBox(height: 4),
 const Text(
 'Add the first alignment standard for your delivery model.',
 style:
 TextStyle(fontSize: 12, color: Color(0xFF9CA3AF))),
 ],
 ),
 ),
 )
 : Column(
 children: [
 // Dark table header
 Container(
 padding: const EdgeInsets.symmetric(
 horizontal: 12, vertical: 10),
 decoration: const BoxDecoration(
 color: Color(0xFF1F2937),
 borderRadius: BorderRadius.only(
 topLeft: Radius.circular(8),
 topRight: Radius.circular(8)),
 ), child: const Row(
              children: [
                Expanded(flex: 2, child: Text('Model', style: _dmHeaderStyle, textAlign: TextAlign.center)),
                Expanded(flex: 3, child: Text('Best-fit Use', style: _dmHeaderStyle, textAlign: TextAlign.center)),
                Expanded(flex: 3, child: Text('Required Alignment Evidence', style: _dmHeaderStyle, textAlign: TextAlign.center)),
                Expanded(flex: 3, child: Text('Technical Control Focus', style: _dmHeaderStyle, textAlign: TextAlign.center)),
                Expanded(flex: 3, child: Text('Exit Standard', style: _dmHeaderStyle, textAlign: TextAlign.center)),
                Expanded(flex: 1, child: Text('', style: _dmHeaderStyle, textAlign: TextAlign.center)),
              ],
            ),
 ),
 // Data rows
 ..._methodologyStandards.asMap().entries.map((entry) {
 final idx = entry.key;
 final row = entry.value;
 return Container(
 margin: const EdgeInsets.only(bottom: 3),
 padding: const EdgeInsets.symmetric(
 horizontal: 12, vertical: 10),
 decoration: BoxDecoration(
 color: idx.isEven
 ? Colors.white
 : const Color(0xFFFAFBFD),
 borderRadius: BorderRadius.circular(6),
 border:
 Border.all(color: const Color(0xFFF3F4F6)),
 ),          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                flex: 2,
                child: Text(row.model,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600),
                  
                  textAlign: TextAlign.center),
              ),
              Expanded(
                flex: 3,
                child: Text(row.bestFit,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF374151)),
                  
                  textAlign: TextAlign.center),
              ),
              Expanded(
                flex: 3,
                child: Text(row.evidence,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF374151)),
                  
                  textAlign: TextAlign.center),
              ),
              Expanded(
                flex: 3,
                child: Text(row.controls,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF374151)),
                  
                  textAlign: TextAlign.center),
              ),
              Expanded(
                flex: 3,
                child: Text(row.exitStandard,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF374151)),
                  
                  textAlign: TextAlign.center),
              ),
 Expanded(
 flex: 1,
 child: Row(
 mainAxisSize: MainAxisSize.min,
 children: [
 Tooltip(
 message: 'KAZ AI – Auto-fill this model',
 child: InkWell(
 onTap: () async {
 if (_isGeneratingModelAi) return;

 // Collect controllers for the row fields
 final modelCtl = TextEditingController(text: row.model);
 final bestFitCtl = TextEditingController(text: row.bestFit);
 final evidenceCtl = TextEditingController(text: row.evidence);
 final controlsCtl = TextEditingController(text: row.controls);
 final exitCtl = TextEditingController(text: row.exitStandard);

 setState(() => _isGeneratingModelAi = true);
 try {
 final projectData = ProjectDataInherited.maybeOf(context)?.projectData;
 final projectContext = ProjectDataHelper.buildProjectContextScan(
 projectData ?? ProjectDataModel(),
 sectionLabel: 'Technical Alignment - Delivery Model',
 );
 final ai = OpenAiServiceSecure();

 final prompts = <(String, TextEditingController)>[
 ('model name', modelCtl),
 ('best-fit use case', bestFitCtl),
 ('required alignment evidence', evidenceCtl),
 ('technical control focus', controlsCtl),
 ('exit standard', exitCtl),
 ];

 for (final (label, ctl) in prompts) {
 if (ctl.text.trim().isEmpty) {
 final result = await ai.generateCompletion(
 'Based on this project context, generate a $label for a delivery model.\n\n'
 'Context:\n$projectContext\n\n'
 'Provide a concise, specific, actionable response (1-2 sentences). '
 'Return ONLY the text content (no JSON, no markdown headers).',
 maxTokens: 200,
 temperature: 0.6,
 );
 final cleaned = result.trim();
 if (cleaned.isNotEmpty) ctl.text = cleaned;
 }
 }

 setState(() {
 _methodologyStandards[idx] = _MethodologyStandard(
 model: modelCtl.text.trim(),
 bestFit: bestFitCtl.text.trim(),
 evidence: evidenceCtl.text.trim(),
 controls: controlsCtl.text.trim(),
 exitStandard: exitCtl.text.trim(),
 );
 _scheduleSave();
 });
 } catch (e) {
 debugPrint('KAZ AI model generation failed: $e');
 if (mounted) {
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(
 content: Text('KAZ AI generation failed: $e'),
 backgroundColor: const Color(0xFFDC2626),
 ),
 );
 }
 } finally {
 // Dispose temporary controllers
 modelCtl.dispose();
 bestFitCtl.dispose();
 evidenceCtl.dispose();
 controlsCtl.dispose();
 exitCtl.dispose();
 if (mounted) setState(() => _isGeneratingModelAi = false);
 }
 },
 child: _isGeneratingModelAi
 ? const SizedBox(
 width: 14,
 height: 14,
 child: CircularProgressIndicator(
 strokeWidth: 1.5,
 color: Color(0xFFF59E0B),
 ),
 )
 : const Icon(Icons.auto_awesome,
 size: 14,
 color: Color(0xFFF59E0B)),
 ),
 ),
 const SizedBox(width: 4),
 InkWell(
 onTap: () => _showMethodologyDialog(
 existing: row,
 index: idx),
 child: const Icon(Icons.edit_outlined,
 size: 14,
 color: Color(0xFF6B7280)),
 ),
 const SizedBox(width: 4),
 InkWell(
 onTap: () async {
 final confirmed =
 await _confirmDelete(
 'delivery model');
 if (!confirmed) return;
 setState(() {
 _methodologyStandards
 .removeAt(idx);
 _shiftEditingRowsAfterDelete(
 _editingMethodologyRows,
 idx);
 _scheduleSave();
 });
 },
 child: const Icon(
 Icons.delete_outline,
 size: 14,
 color: Color(0xFFEF4444)),
 ),
 ],
 ),
 ),
 ],
 ),
 );
 }),
 Padding(
 padding: const EdgeInsets.only(top: 6),
 child: Text(
 '${_methodologyStandards.length} model${_methodologyStandards.length != 1 ? 's' : ''}',
 style: const TextStyle(
 fontSize: 11, color: Color(0xFF9CA3AF))),
 ),
 ],
 ),
 );
 }

 Widget _buildKazAiFieldButton({
 required String label,
 required TextEditingController controller,
 required StateSetter setDState,
 }) {
 bool isGenerating = false;
 return StatefulBuilder(
 builder: (context, setLocalState) => Tooltip(
 message: 'KAZ AI – Generate $label',
 child: InkWell(
 onTap: isGenerating
 ? null
 : () async {
 setLocalState(() => isGenerating = true);
 try {
 final projectData = ProjectDataInherited.maybeOf(context)?.projectData;
 final projectContext = ProjectDataHelper.buildProjectContextScan(
 projectData ?? ProjectDataModel(),
 sectionLabel: 'Technical Alignment - Delivery Model',
 );
 final ai = OpenAiServiceSecure();
 final result = await ai.generateCompletion(
 'Based on this project context, generate a $label for a delivery model.\n\n'
 'Context:\n$projectContext\n\n'
 'Provide a concise, specific, actionable response (1-2 sentences). '
 'Return ONLY the text content (no JSON, no markdown headers).',
 maxTokens: 200,
 temperature: 0.6,
 );
 final cleaned = result.trim();
 if (cleaned.isNotEmpty) {
 setDState(() => controller.text = cleaned);
 }
 } catch (e) {
 debugPrint('KAZ AI field generation failed: $e');
 if (context.mounted) {
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(
 content: Text('KAZ AI failed: $e'),
 backgroundColor: const Color(0xFFDC2626),
 ),
 );
 }
 } finally {
 if (context.mounted) setLocalState(() => isGenerating = false);
 }
 },
 child: Container(
 padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
 decoration: BoxDecoration(
 color: const Color(0xFFF59E0B).withOpacity(0.1),
 borderRadius: BorderRadius.circular(6),
 border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.3)),
 ),
 child: Row(
 mainAxisSize: MainAxisSize.min,
 children: [
 isGenerating
 ? const SizedBox(
 width: 12,
 height: 12,
 child: CircularProgressIndicator(
 strokeWidth: 1.5,
 color: Color(0xFFF59E0B),
 ),
 )
 : const Icon(Icons.auto_awesome, size: 12, color: Color(0xFFF59E0B)),
 const SizedBox(width: 4),
 const Text(
 'KAZ AI',
 style: TextStyle(
 fontSize: 10,
 fontWeight: FontWeight.w700,
 color: Color(0xFFF59E0B),
 ),
 ),
 ],
 ),
 ),
 ),
 ),
 );
 }

 void _showMethodologyDialog({_MethodologyStandard? existing, int? index}) {
 final isEdit = existing != null;
 final modelCtl = TextEditingController(text: existing?.model ?? '');
 final bestFitCtl = TextEditingController(text: existing?.bestFit ?? '');
 final evidenceCtl = TextEditingController(text: existing?.evidence ?? '');
 final controlsCtl = TextEditingController(text: existing?.controls ?? '');
 final exitCtl =
 TextEditingController(text: existing?.exitStandard ?? '');

 showDialog(
 context: context,
 builder: (ctx) => StatefulBuilder(
 builder: (ctx, setDState) => AlertDialog(
 title: Row(children: [
 Icon(
 isEdit
 ? Icons.edit_outlined
 : Icons.add_circle_outline,
 size: 20,
 color: const Color(0xFF7C3AED)),
 const SizedBox(width: 8),
 Text(isEdit ? 'Edit Delivery Model' : 'Add Delivery Model',
 style: const TextStyle(fontSize: 16)),
 ]),
 content: SizedBox(
 width: 560,
 child: SingleChildScrollView(
 child: Column(
 mainAxisSize: MainAxisSize.min,
 children: [
 _buildKazAiFieldButton(
 label: 'Model name',
 controller: modelCtl,
 setDState: setDState,
 ),
 const SizedBox(height: 6),
 VoiceTextField(
 controller: modelCtl,
 decoration: const InputDecoration(
 labelText: 'Model name',
 isDense: true,
 border: OutlineInputBorder(),
 ),
 ),
 const SizedBox(height: 12),
 _buildKazAiFieldButton(
 label: 'Best-fit use case',
 controller: bestFitCtl,
 setDState: setDState,
 ),
 const SizedBox(height: 6),
 VoiceTextField(
 controller: bestFitCtl,
 minLines: 2,
 decoration: const InputDecoration(
 labelText: 'Best-fit use',
 isDense: true,
 border: OutlineInputBorder(),
 ),
 ),
 const SizedBox(height: 12),
 _buildKazAiFieldButton(
 label: 'Required alignment evidence',
 controller: evidenceCtl,
 setDState: setDState,
 ),
 const SizedBox(height: 6),
 VoiceTextField(
 controller: evidenceCtl,
 minLines: 2,
 decoration: const InputDecoration(
 labelText: 'Required alignment evidence',
 isDense: true,
 border: OutlineInputBorder(),
 ),
 ),
 const SizedBox(height: 12),
 _buildKazAiFieldButton(
 label: 'Technical control focus',
 controller: controlsCtl,
 setDState: setDState,
 ),
 const SizedBox(height: 6),
 VoiceTextField(
 controller: controlsCtl,
 minLines: 2,
 decoration: const InputDecoration(
 labelText: 'Technical control focus',
 isDense: true,
 border: OutlineInputBorder(),
 ),
 ),
 const SizedBox(height: 12),
 _buildKazAiFieldButton(
 label: 'Exit standard',
 controller: exitCtl,
 setDState: setDState,
 ),
 const SizedBox(height: 6),
 VoiceTextField(
 controller: exitCtl,
 minLines: 2,
 decoration: const InputDecoration(
 labelText: 'Exit standard',
 isDense: true,
 border: OutlineInputBorder(),
 ),
 ),
 ],
 ),
 ),
 ),
 actions: [
 TextButton(
 onPressed: () => Navigator.of(ctx).pop(),
 child: const Text('Cancel'),
 ),
 FilledButton(
 onPressed: () {
 final row = _MethodologyStandard(
 model: modelCtl.text.trim(),
 bestFit: bestFitCtl.text.trim(),
 evidence: evidenceCtl.text.trim(),
 controls: controlsCtl.text.trim(),
 exitStandard: exitCtl.text.trim(),
 );
 setState(() {
 if (isEdit && index != null) {
 _methodologyStandards[index] = row;
 } else {
 _methodologyStandards.add(row);
 }
 _scheduleSave();
 });
 Navigator.of(ctx).pop();
 },
 style: FilledButton.styleFrom(
 backgroundColor: const Color(0xFF7C3AED),
 foregroundColor: Colors.white,
 ),
 child: Text(isEdit ? 'Save' : 'Add'),
 ),
 ],
 ),
 ),
 );
 }

 Widget _buildStableReadinessGateTable() {
 return _DeliveryModelPanelShell(
 title: 'Technical Readiness Gate',
 subtitle:
 'Track control domains, readiness criteria, required evidence, ownership, and gate decisions.',
 icon: Icons.fact_check_outlined,
 accent: const Color(0xFFD97706),
 trailing: TextButton.icon(
 onPressed: _addReadinessGateItem,
 icon: const Icon(Icons.add_rounded, size: 16),
 label: const Text('Add gate item'),
 style: TextButton.styleFrom(
 foregroundColor: const Color(0xFFD97706),
 padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
 ),
 ),
 child: _readinessGateItems.isEmpty
 ? Center(
 child: Padding(
 padding: const EdgeInsets.all(24.0),
 child: Column(
 mainAxisSize: MainAxisSize.min,
 children: [
 Icon(Icons.fact_check_outlined,
 size: 36,
 color: const Color(0xFF9CA3AF).withOpacity(0.6)),
 const SizedBox(height: 8),
 const Text('No readiness gate items yet',
 style: TextStyle(
 color: Color(0xFF9CA3AF),
 fontWeight: FontWeight.w500)),
 const SizedBox(height: 4),
 const Text(
 'Add the first control domain to begin tracking readiness.',
 style:
 TextStyle(fontSize: 12, color: Color(0xFF9CA3AF))),
 ],
 ),
 ),
 )
 : Column(
 children: [
 // Dark table header
 Container(
 padding: const EdgeInsets.symmetric(
 horizontal: 12, vertical: 10),
 decoration: const BoxDecoration(
 color: Color(0xFF1F2937),
 borderRadius: BorderRadius.only(
 topLeft: Radius.circular(8),
 topRight: Radius.circular(8)),
 ), child: const Row(
              children: [
                Expanded(flex: 2, child: Text('Control Domain', style: _dmHeaderStyle, textAlign: TextAlign.center)),
                Expanded(flex: 3, child: Text('What Must Be True', style: _dmHeaderStyle, textAlign: TextAlign.center)),
                Expanded(flex: 3, child: Text('Evidence To Attach', style: _dmHeaderStyle, textAlign: TextAlign.center)),
                Expanded(flex: 2, child: Text('Owner', style: _dmHeaderStyle, textAlign: TextAlign.center)),
                Expanded(flex: 1, child: Text('Decision', style: _dmHeaderStyle, textAlign: TextAlign.center)),
                Expanded(flex: 1, child: Text('', style: _dmHeaderStyle, textAlign: TextAlign.center)),
              ],
            ),
 ),
 // Data rows
 ..._readinessGateItems.asMap().entries.map((entry) {
 final idx = entry.key;
 final row = entry.value;
 final decisionColor = _readinessDecisionColor(row.decision);

 return Container(
 margin: const EdgeInsets.only(bottom: 3),
 padding: const EdgeInsets.symmetric(
 horizontal: 12, vertical: 10),
 decoration: BoxDecoration(
 color: idx.isEven
 ? Colors.white
 : const Color(0xFFFAFBFD),
 borderRadius: BorderRadius.circular(6),
 border:
 Border.all(color: const Color(0xFFF3F4F6)),
 ),
 child: Row(crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                flex: 2,
                child: Text(row.domain,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600),
                  
                  textAlign: TextAlign.center),
              ),
              Expanded(
                flex: 3,
                child: Text(row.standard,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF374151)),
                  
                  textAlign: TextAlign.center),
              ),
              Expanded(
                flex: 3,
                child: Text(row.evidence,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF374151)),
                  
                  textAlign: TextAlign.center),
              ),
              Expanded(
                flex: 2,
                child: Text(row.owner,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF6B7280)),
                  textAlign: TextAlign.center),
              ),
              Expanded(
                flex: 1,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5, vertical: 3),
                  decoration: BoxDecoration(
                    color: decisionColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4)),
                  child: Text(row.decision,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: decisionColor),
                    textAlign: TextAlign.center),
                ),
              ),
 Expanded(
 flex: 1,
 child: Row(
 mainAxisSize: MainAxisSize.min,
 children: [
 InkWell(
 onTap: () => _showReadinessGateDialog(
 existing: row, index: idx),
 child: const Icon(Icons.edit_outlined,
 size: 14,
 color: Color(0xFF6B7280)),
 ),
 const SizedBox(width: 4),
 InkWell(
 onTap: () async {
 final confirmed =
 await _confirmDelete(
 'readiness gate item');
 if (!confirmed) return;
 setState(() {
 _readinessGateItems
 .removeAt(idx);
 _shiftEditingRowsAfterDelete(
 _editingReadinessRows,
 idx);
 _scheduleSave();
 });
 },
 child: const Icon(
 Icons.delete_outline,
 size: 14,
 color: Color(0xFFEF4444)),
 ),
 ],
 ),
 ),
 ],
 ),
 );
 }),
 Padding(
 padding: const EdgeInsets.only(top: 6),
 child: Text(
 '${_readinessGateItems.length} gate item${_readinessGateItems.length != 1 ? 's' : ''}',
 style: const TextStyle(
 fontSize: 11, color: Color(0xFF9CA3AF))),
 ),
 ],
 ),
 );
 }

 Color _readinessDecisionColor(String decision) {
 switch (decision.toLowerCase()) {
 case 'go':
 return const Color(0xFF059669);
 case 'conditional':
 return const Color(0xFFD97706);
 case 'no-go':
 return const Color(0xFFDC2626);
 case 'pending':
 return const Color(0xFF6366F1);
 default:
 return const Color(0xFF6B7280);
 }
 }

 void _showReadinessGateDialog(
 {_ReadinessGateItem? existing, int? index}) {
 final isEdit = existing != null;
 if (isEdit && !_canEditAlignment) {
 _showPermissionSnackBar('edit readiness gate items');
 return;
 }
 final domainCtl =
 TextEditingController(text: existing?.domain ?? '');
 final standardCtl =
 TextEditingController(text: existing?.standard ?? '');
 final evidenceCtl =
 TextEditingController(text: existing?.evidence ?? '');
 final ownerCtl =
 TextEditingController(text: existing?.owner ?? '');
 String decision = existing?.decision ?? 'Pending';

 showDialog(
 context: context,
 builder: (ctx) => StatefulBuilder(
 builder: (ctx, setDState) => AlertDialog(
 title: Row(children: [
 Icon(
 isEdit
 ? Icons.edit_outlined
 : Icons.add_circle_outline,
 size: 20,
 color: const Color(0xFFD97706)),
 const SizedBox(width: 8),
 Text(
 isEdit
 ? 'Edit Gate Item'
 : 'Add Gate Item',
 style: const TextStyle(fontSize: 16)),
 ]),
 content: SizedBox(
 width: 560,
 child: SingleChildScrollView(
 child: Column(
 mainAxisSize: MainAxisSize.min,
 children: [
 VoiceTextField(
 controller: domainCtl,
 decoration: const InputDecoration(
 labelText: 'Control Domain',
 isDense: true,
 border: OutlineInputBorder(),
 ),
 ),
 const SizedBox(height: 12),
 VoiceTextField(
 controller: standardCtl,
 decoration: const InputDecoration(
 labelText: 'What Must Be True',
 isDense: true,
 border: OutlineInputBorder(),
 ),
 ),
 const SizedBox(height: 12),
 VoiceTextField(
 controller: evidenceCtl,
 decoration: const InputDecoration(
 labelText: 'Evidence To Attach',
 isDense: true,
 border: OutlineInputBorder(),
 ),
 ),
 const SizedBox(height: 12),
 Row(children: [
 Expanded(
 child: VoiceTextField(
 controller: ownerCtl,
 decoration: const InputDecoration(
 labelText: 'Owner',
 isDense: true,
 border: OutlineInputBorder(),
 ),
 ),
 ),
 const SizedBox(width: 12),
 Expanded(
 child: DropdownButtonFormField<String>(
 value: decision,
 decoration: const InputDecoration(
 labelText: 'Decision',
 isDense: true,
 border: OutlineInputBorder(),
 ),
 items: ['Go', 'Conditional', 'No-go', 'Pending']
 .map((s) => DropdownMenuItem(
 value: s, child: Text(s)))
 .toList(),
 onChanged: (v) {
 if (v != null)
 setDState(() => decision = v);
 },
 ),
 ),
 ]),
 ],
 ),
 ),
 ),
 actions: [
 TextButton(
 onPressed: () => Navigator.of(ctx).pop(),
 child: const Text('Cancel')),
 FilledButton(
 onPressed: () {
 if (isEdit && index != null) {
 setState(() {
 _readinessGateItems[index] = _ReadinessGateItem(
 domain: domainCtl.text.trim(),
 standard: standardCtl.text.trim(),
 evidence: evidenceCtl.text.trim(),
 owner: ownerCtl.text.trim(),
 decision: decision,
 );
 _scheduleSave();
 });
 } else {
 setState(() {
 _readinessGateItems.add(_ReadinessGateItem(
 domain: domainCtl.text.trim(),
 standard: standardCtl.text.trim(),
 evidence: evidenceCtl.text.trim(),
 owner: ownerCtl.text.trim(),
 decision: decision,
 ));
 _scheduleSave();
 });
 }
 Navigator.of(ctx).pop();
 },
 style: FilledButton.styleFrom(
 backgroundColor: const Color(0xFFD97706),
 shape: RoundedRectangleBorder(
 borderRadius: BorderRadius.circular(8))),
 child: Text(isEdit ? 'Save' : 'Add'),
 ),
 ],
 ),
 ),
 );
 }

 Widget _buildDecisionDropdown({
 required String value,
 required List<String> options,
 required ValueChanged<String> onChanged,
 bool enabled = true,
 }) {
 final normalized = value.trim();
 final items = normalized.isEmpty || options.contains(normalized)
 ? options
 : [normalized, ...options];
 return DropdownButtonFormField<String>(
 value: normalized.isEmpty ? items.first : normalized,
 alignment: Alignment.center,
 isExpanded: true,
 style: TextStyle(
 fontSize: 14,
 color: enabled ? const Color(0xFF1F2937) : const Color(0xFF475569),
 ),
 selectedItemBuilder: (context) => items
 .map((opt) => Align(
 alignment: Alignment.center,
 child: Text(opt, textAlign: TextAlign.center),
 ))
 .toList(),
 items: items
 .map((opt) => DropdownMenuItem(
 value: opt,
 child: Center(child: Text(opt, textAlign: TextAlign.center)),
 ))
 .toList(),
 onChanged: enabled
 ? (newValue) {
 if (newValue == null) return;
 onChanged(newValue);
 }
 : null,
 decoration: InputDecoration(
 isDense: true,
 filled: true,
 fillColor: enabled ? Colors.white : const Color(0xFFF8FAFC),
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
 disabledBorder: OutlineInputBorder(
 borderRadius: BorderRadius.circular(10),
 borderSide: const BorderSide(color: Color(0xFFE4E7EC)),
 ),
 focusedBorder: OutlineInputBorder(
 borderRadius: BorderRadius.circular(10),
 borderSide: const BorderSide(color: Color(0xFFD97706), width: 2),
 ),
 ),
 );
 }

 Widget _buildStableTraceabilityTable() {
 return _DeliveryModelPanelShell(
 title: 'Traceability And Verification Matrix',
 subtitle:
 'Map traceability objects to verification methods and evidence for waterfall and agile/hybrid delivery.',
 icon: Icons.link_outlined,
 accent: const Color(0xFF0F766E),
 trailing: TextButton.icon(
 onPressed: _addTraceabilityItem,
 icon: const Icon(Icons.add_rounded, size: 16),
 label: const Text('Add trace item'),
 style: TextButton.styleFrom(
 foregroundColor: const Color(0xFF0F766E),
 padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
 ),
 ),
 child: _traceabilityItems.isEmpty
 ? Center(
 child: Padding(
 padding: const EdgeInsets.all(24.0),
 child: Column(
 mainAxisSize: MainAxisSize.min,
 children: [
 Icon(Icons.link_outlined,
 size: 36,
 color: const Color(0xFF9CA3AF).withOpacity(0.6)),
 const SizedBox(height: 8),
 const Text('No traceability items yet',
 style: TextStyle(
 color: Color(0xFF9CA3AF),
 fontWeight: FontWeight.w500)),
 const SizedBox(height: 4),
 const Text(
 'Add the first trace object to begin mapping verification evidence.',
 style:
 TextStyle(fontSize: 12, color: Color(0xFF9CA3AF))),
 ],
 ),
 ),
 )
 : Column(
 children: [
 // Dark table header
 Container(
 padding: const EdgeInsets.symmetric(
 horizontal: 12, vertical: 10),
 decoration: const BoxDecoration(
 color: Color(0xFF1F2937),
 borderRadius: BorderRadius.only(
 topLeft: Radius.circular(8),
 topRight: Radius.circular(8)),
 ), child: const Row(
              children: [
                Expanded(flex: 2, child: Text('Trace Object', style: _dmHeaderStyle, textAlign: TextAlign.center)),
                Expanded(flex: 3, child: Text('Alignment Question', style: _dmHeaderStyle, textAlign: TextAlign.center)),
                Expanded(flex: 2, child: Text('Verification', style: _dmHeaderStyle, textAlign: TextAlign.center)),
                Expanded(flex: 2, child: Text('Waterfall Evidence', style: _dmHeaderStyle, textAlign: TextAlign.center)),
                Expanded(flex: 2, child: Text('Agile / Hybrid Evidence', style: _dmHeaderStyle, textAlign: TextAlign.center)),
                Expanded(flex: 1, child: Text('', style: _dmHeaderStyle, textAlign: TextAlign.center)),
              ],
            ),
 ),
 // Data rows
 ..._traceabilityItems.asMap().entries.map((entry) {
 final idx = entry.key;
 final row = entry.value;

 return Container(
 margin: const EdgeInsets.only(bottom: 3),
 padding: const EdgeInsets.symmetric(
 horizontal: 12, vertical: 10),
 decoration: BoxDecoration(
 color: idx.isEven
 ? Colors.white
 : const Color(0xFFFAFBFD),
 borderRadius: BorderRadius.circular(6),
 border:
 Border.all(color: const Color(0xFFF3F4F6)),
 ),
 child: Row(crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                flex: 2,
                child: Text(row.object,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600),
                  
                  textAlign: TextAlign.center),
              ),
              Expanded(
                flex: 3,
                child: Text(row.question,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF374151)),
                  
                  textAlign: TextAlign.center),
              ),
              Expanded(
                flex: 2,
                child: Text(row.verification,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF374151)),
                  
                  textAlign: TextAlign.center),
              ),
              Expanded(
                flex: 2,
                child: Text(row.waterfallEvidence,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF374151)),
                  
                  textAlign: TextAlign.center),
              ),
              Expanded(
                flex: 2,
                child: Text(row.agileEvidence,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF374151)),
                  
                  textAlign: TextAlign.center),
              ),
 Expanded(
 flex: 1,
 child: Row(
 mainAxisSize: MainAxisSize.min,
 children: [
 InkWell(
 onTap: () => _showTraceabilityDialog(
 existing: row, index: idx),
 child: const Icon(Icons.edit_outlined,
 size: 14,
 color: Color(0xFF6B7280)),
 ),
 const SizedBox(width: 4),
 InkWell(
 onTap: () async {
 final confirmed =
 await _confirmDelete(
 'traceability item');
 if (!confirmed) return;
 setState(() {
 _traceabilityItems
 .removeAt(idx);
 _shiftEditingRowsAfterDelete(
 _editingTraceabilityRows,
 idx);
 _scheduleSave();
 });
 },
 child: const Icon(
 Icons.delete_outline,
 size: 14,
 color: Color(0xFFEF4444)),
 ),
 ],
 ),
 ),
 ],
 ),
 );
 }),
 Padding(
 padding: const EdgeInsets.only(top: 6),
 child: Text(
 '${_traceabilityItems.length} trace item${_traceabilityItems.length != 1 ? 's' : ''}',
 style: const TextStyle(
 fontSize: 11, color: Color(0xFF9CA3AF))),
 ),
 ],
 ),
 );
 }

 void _showTraceabilityDialog({_TraceabilityItem? existing, int? index}) {
 final isEdit = existing != null;
 if (isEdit && !_canEditAlignment) {
 _showPermissionSnackBar('edit traceability items');
 return;
 }
 final objectCtl =
 TextEditingController(text: existing?.object ?? '');
 final questionCtl =
 TextEditingController(text: existing?.question ?? '');
 final verificationCtl =
 TextEditingController(text: existing?.verification ?? '');
 final waterfallCtl =
 TextEditingController(text: existing?.waterfallEvidence ?? '');
 final agileCtl =
 TextEditingController(text: existing?.agileEvidence ?? '');

 showDialog(
 context: context,
 builder: (ctx) => AlertDialog(
 title: Row(children: [
 Icon(
 isEdit
 ? Icons.edit_outlined
 : Icons.add_circle_outline,
 size: 20,
 color: const Color(0xFF0F766E)),
 const SizedBox(width: 8),
 Text(
 isEdit
 ? 'Edit Trace Item'
 : 'Add Trace Item',
 style: const TextStyle(fontSize: 16)),
 ]),
 content: SizedBox(
 width: 560,
 child: SingleChildScrollView(
 child: Column(
 mainAxisSize: MainAxisSize.min,
 children: [
 VoiceTextField(
 controller: objectCtl,
 decoration: const InputDecoration(
 labelText: 'Trace Object',
 isDense: true,
 border: OutlineInputBorder(),
 ),
 ),
 const SizedBox(height: 12),
 VoiceTextField(
 controller: questionCtl,
 decoration: const InputDecoration(
 labelText: 'Technical Alignment Question',
 isDense: true,
 border: OutlineInputBorder(),
 ),
 ),
 const SizedBox(height: 12),
 VoiceTextField(
 controller: verificationCtl,
 decoration: const InputDecoration(
 labelText: 'Verification Method',
 isDense: true,
 border: OutlineInputBorder(),
 ),
 ),
 const SizedBox(height: 12),
 VoiceTextField(
 controller: waterfallCtl,
 decoration: const InputDecoration(
 labelText: 'Waterfall Evidence',
 isDense: true,
 border: OutlineInputBorder(),
 ),
 ),
 const SizedBox(height: 12),
 VoiceTextField(
 controller: agileCtl,
 decoration: const InputDecoration(
 labelText: 'Agile / Hybrid Evidence',
 isDense: true,
 border: OutlineInputBorder(),
 ),
 ),
 ],
 ),
 ),
 ),
 actions: [
 TextButton(
 onPressed: () => Navigator.of(ctx).pop(),
 child: const Text('Cancel')),
 FilledButton(
 onPressed: () {
 if (isEdit && index != null) {
 setState(() {
 _traceabilityItems[index] = _TraceabilityItem(
 object: objectCtl.text.trim(),
 question: questionCtl.text.trim(),
 verification: verificationCtl.text.trim(),
 waterfallEvidence: waterfallCtl.text.trim(),
 agileEvidence: agileCtl.text.trim(),
 );
 _scheduleSave();
 });
 } else {
 setState(() {
 _traceabilityItems.add(_TraceabilityItem(
 object: objectCtl.text.trim(),
 question: questionCtl.text.trim(),
 verification: verificationCtl.text.trim(),
 waterfallEvidence: waterfallCtl.text.trim(),
 agileEvidence: agileCtl.text.trim(),
 ));
 _scheduleSave();
 });
 }
 Navigator.of(ctx).pop();
 },
 style: FilledButton.styleFrom(
 backgroundColor: const Color(0xFF0F766E),
 shape: RoundedRectangleBorder(
 borderRadius: BorderRadius.circular(8))),
 child: Text(isEdit ? 'Save' : 'Add'),
 ),
 ],
 ),
 );
 }

 Widget _buildStableConstraintPanel(List<String> ownerOptions) {
 return Container(
 padding: const EdgeInsets.all(20),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(16),
 border: Border.all(color: const Color(0xFFE2E8F0)),
 boxShadow: [
 BoxShadow(
 color: Colors.black.withOpacity(0.04),
 blurRadius: 18,
 offset: const Offset(0, 10),
 ),
 ],
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 _buildSectionHeader(
 icon: Icons.shield_outlined,
 color: const Color(0xFF1D4ED8),
 title: 'Constraint And Guardrail Register',
 subtitle:
 'Define architectural constraints, guardrails, ownership, and approval status for design governance.',
 actionLabel: 'Add constraint',
 onAction: _addConstraintRow,
 ),
 const SizedBox(height: 16),
 _buildScrollableTableHeader(
 columns: const [
 _TableColumn(label: 'Constraint', flex: 3, minWidth: 260),
 _TableColumn(label: 'Guardrail', flex: 5, minWidth: 400),
 _TableColumn(label: 'Owner', flex: 2, minWidth: 150),
 _TableColumn(label: 'Status', flex: 2, minWidth: 140),
 _TableColumn(
 label: 'Actions',
 flex: 1,
 minWidth: _technicalAlignmentActionColumnWidth,
 alignment: Alignment.center),
 ],
 ),
 const SizedBox(height: 10),
 if (_constraints.isEmpty)
 _buildEmptyTableState(
 message: 'No constraints yet. Add the first constraint.',
 actionLabel: 'Add constraint',
 onAction: _addConstraintRow,
 )
 else
 _buildScrollableTableBody(
 columns: const [
 _TableColumn(label: 'Constraint', flex: 3, minWidth: 260),
 _TableColumn(label: 'Guardrail', flex: 5, minWidth: 400),
 _TableColumn(label: 'Owner', flex: 2, minWidth: 150),
 _TableColumn(label: 'Status', flex: 2, minWidth: 140),
 _TableColumn(
 label: 'Actions',
 flex: 1,
 minWidth: _technicalAlignmentActionColumnWidth,
 alignment: Alignment.center),
 ],
 rowCount: _constraints.length,
 rowBuilder: (i) => _buildConstraintRow(
 _constraints[i],
 index: i,
 isStriped: i.isOdd,
 ownerOptions: ownerOptions,
 ),
 ),
 ],
 ),
 );
 }

 Widget _buildStableMappingPanel() {
 return Container(
 padding: const EdgeInsets.all(20),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(16),
 border: Border.all(color: const Color(0xFFE2E8F0)),
 boxShadow: [
 BoxShadow(
 color: Colors.black.withOpacity(0.04),
 blurRadius: 18,
 offset: const Offset(0, 10),
 ),
 ],
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 _buildSectionHeader(
 icon: Icons.swap_horiz,
 color: const Color(0xFF0F766E),
 title: 'Requirement To Solution Mapping',
 subtitle:
 'Map requirements to technical approaches and track alignment status across delivery models.',
 actionLabel: 'Add mapping',
 onAction: _addMappingRow,
 ),
 const SizedBox(height: 16),
 _buildScrollableTableHeader(
 columns: const [
 _TableColumn(label: 'Requirement Area', flex: 3, minWidth: 260),
 _TableColumn(
 label: 'Technical Approach', flex: 5, minWidth: 460),
 _TableColumn(label: 'Status', flex: 2, minWidth: 140),
 _TableColumn(
 label: 'Actions',
 flex: 1,
 minWidth: _technicalAlignmentActionColumnWidth,
 alignment: Alignment.center),
 ],
 ),
 const SizedBox(height: 10),
 if (_mappings.isEmpty)
 _buildEmptyTableState(
 message: 'No requirement mappings yet. Add the first mapping.',
 actionLabel: 'Add mapping',
 onAction: _addMappingRow,
 )
 else
 _buildScrollableTableBody(
 columns: const [
 _TableColumn(label: 'Requirement Area', flex: 3, minWidth: 260),
 _TableColumn(
 label: 'Technical Approach', flex: 5, minWidth: 460),
 _TableColumn(label: 'Status', flex: 2, minWidth: 140),
 _TableColumn(
 label: 'Actions',
 flex: 1,
 minWidth: _technicalAlignmentActionColumnWidth,
 alignment: Alignment.center),
 ],
 rowCount: _mappings.length,
 rowBuilder: (i) => _buildMappingRow(
 _mappings[i],
 index: i,
 isStriped: i.isOdd,
 ),
 ),
 ],
 ),
 );
 }

 Widget _buildStableDependencyPanel(List<String> ownerOptions) {
 return Container(
 padding: const EdgeInsets.all(20),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(16),
 border: Border.all(color: const Color(0xFFE2E8F0)),
 boxShadow: [
 BoxShadow(
 color: Colors.black.withOpacity(0.04),
 blurRadius: 18,
 offset: const Offset(0, 10),
 ),
 ],
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 _buildSectionHeader(
 icon: Icons.account_tree_outlined,
 color: const Color(0xFF9333EA),
 title: 'Dependency And Decision Watchlist',
 subtitle:
 'Track critical dependencies, decisions, ownership, and resolution status that affect design alignment.',
 actionLabel: 'Add dependency',
 onAction: _addDependencyRow,
 ),
 const SizedBox(height: 16),
 _buildScrollableTableHeader(
 columns: const [
 _TableColumn(
 label: 'Dependency / Decision', flex: 3, minWidth: 260),
 _TableColumn(label: 'Detail', flex: 4, minWidth: 380),
 _TableColumn(label: 'Owner', flex: 2, minWidth: 150),
 _TableColumn(label: 'Status', flex: 2, minWidth: 140),
 _TableColumn(
 label: 'Actions',
 flex: 1,
 minWidth: _technicalAlignmentActionColumnWidth,
 alignment: Alignment.center),
 ],
 ),
 const SizedBox(height: 10),
 if (_dependencies.isEmpty)
 _buildEmptyTableState(
 message: 'No dependencies yet. Add the first dependency.',
 actionLabel: 'Add dependency',
 onAction: _addDependencyRow,
 )
 else
 _buildScrollableTableBody(
 columns: const [
 _TableColumn(
 label: 'Dependency / Decision', flex: 3, minWidth: 260),
 _TableColumn(label: 'Detail', flex: 4, minWidth: 380),
 _TableColumn(label: 'Owner', flex: 2, minWidth: 150),
 _TableColumn(label: 'Status', flex: 2, minWidth: 140),
 _TableColumn(
 label: 'Actions',
 flex: 1,
 minWidth: _technicalAlignmentActionColumnWidth,
 alignment: Alignment.center),
 ],
 rowCount: _dependencies.length,
 rowBuilder: (i) => _buildDependencyRow(
 _dependencies[i],
 index: i,
 isStriped: i.isOdd,
 ownerOptions: ownerOptions,
 ),
 ),
 ],
 ),
 );
 }

 void _openStableDesignItem(String label) {
 Widget? destination;
 switch (label) {
 case 'Design Management':
 destination =
 const DesignPhaseScreen(activeItemLabel: 'Design Management');
 break;
 case 'Design Specifications':
 destination = const RequirementsImplementationScreen();
 break;
 case 'Technical Alignment':
 destination = const TechnicalAlignmentScreen();
 break;
 case 'Development Set Up':
 destination = const DevelopmentSetUpScreen();
 break;
 case 'UI/UX Design':
 destination = const UiUxDesignScreen();
 break;
 }

 if (destination == null) return;

 Navigator.of(context).pushReplacement(
 MaterialPageRoute(builder: (_) => destination!),
 );
 }

 Widget _buildEngineeringHubHeader({
 required bool isMobile,
 required _TechnicalAlignmentDashboardSnapshot snapshot,
 }) {
 final primaryAction = FilledButton.icon(
 onPressed:
 _isGenerating || !_canUseAlignmentAi ? null : _generateAllAlignment,
 icon: _isGenerating
 ? const SizedBox(
 width: 16,
 height: 16,
 child: CircularProgressIndicator(
 strokeWidth: 2,
 color: Colors.white,
 ),
 )
 : const Icon(Icons.auto_awesome, size: 18),
 label: Text(
 _isGenerating
 ? 'Generating alignment...'
 : 'AI Auto-Generate Alignment',
 ),
 style: FilledButton.styleFrom(
 backgroundColor: AppSemanticColors.ai,
 foregroundColor: Colors.white,
 padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
 ),
 );

 final secondaryAction = OutlinedButton.icon(
 onPressed: _canExportAlignment ? _exportAlignmentSummary : null,
 icon: const Icon(Icons.download_rounded, size: 18),
 label: const Text('Export summary'),
 style: OutlinedButton.styleFrom(
 foregroundColor: Colors.white,
 side: BorderSide(color: Colors.white.withOpacity(0.24)),
 padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
 ),
 );

 return Container(
 width: double.infinity,
 padding: const EdgeInsets.all(24),
 decoration: BoxDecoration(
 gradient: const LinearGradient(
 begin: Alignment.topLeft,
 end: Alignment.bottomRight,
 colors: [
 Color(0xFF0B1220),
 Color(0xFF152235),
 Color(0xFF1E3A5F),
 ],
 ),
 borderRadius: BorderRadius.circular(24),
 boxShadow: const [
 BoxShadow(
 color: Color(0x1A0F172A),
 blurRadius: 28,
 offset: Offset(0, 16),
 ),
 ],
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 LayoutBuilder(
 builder: (context, constraints) {
 final stacked = constraints.maxWidth < 860;
 final titleBlock = Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 'Feasibility & Constraints Hub',
 style: TextStyle(
 fontSize: isMobile ? 24 : 28,
 fontWeight: FontWeight.w800,
 color: Colors.white,
 height: 1.1,
 ),
 ),
 const SizedBox(height: 8),
 Text(
 'Technical Alignment for ${snapshot.projectLabel}. This dashboard checks the design concept against real systems, legacy dependencies, venue conditions, security obligations, and operational workarounds.',
 style: TextStyle(
 fontSize: 14,
 color: Colors.white.withOpacity(0.84),
 height: 1.5,
 ),
 ),
 ],
 ),
 );
 final actions = Wrap(
 spacing: 12,
 runSpacing: 12,
 children: [primaryAction, secondaryAction],
 );

 if (stacked) {
 return Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 titleBlock,
 const SizedBox(height: 16),
 actions,
 ],
 );
 }

 return Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 titleBlock,
 const SizedBox(width: 16),
 actions,
 ],
 );
 },
 ),
 if (_notesController.text.trim().isNotEmpty) ...[
 const SizedBox(height: 14),
 Container(
 width: double.infinity,
 padding: const EdgeInsets.all(14),
 decoration: BoxDecoration(
 color: Colors.white.withOpacity(0.08),
 borderRadius: BorderRadius.circular(16),
 border: Border.all(
 color: Colors.white.withOpacity(0.10),
 ),
 ),
 child: Text(
 _notesController.text.trim(),
 
 style: TextStyle(
 fontSize: 12.5,
 color: Colors.white.withOpacity(0.82),
 height: 1.45,
 ),
 ),
 ),
 ],
 const SizedBox(height: 18),
 Wrap(
 spacing: 10,
 runSpacing: 10,
 children: [
 _buildHeaderMetricPill(
 'High Feasibility',
 '${snapshot.highFeasibilityCount}/${snapshot.feasibilityItems.length}',
 ),
 _buildHeaderMetricPill(
 'Compatibility Gaps',
 '${snapshot.compatibilityGapCount}',
 ),
 _buildHeaderMetricPill(
 'Pending Integrations',
 '${snapshot.pendingIntegrationCount}',
 ),
 _buildHeaderMetricPill(
 'Protocols Aligned',
 '${snapshot.alignedProtocolCount}/${snapshot.protocols.length}',
 ),
 _buildHeaderMetricPill('AI Signals', '${snapshot.aiSignalCount}'),
 ],
 ),
 ],
 ),
 );
 }

 Widget _buildFeasibilitySection(
 _TechnicalAlignmentDashboardSnapshot snapshot,
 bool isMobile,
 ) {
 if (isMobile) {
 return Column(
 children: [
 _buildFeasibilityAssessmentCard(snapshot),
 const SizedBox(height: 20),
 _buildLegacyConstraintsCard(snapshot),
 ],
 );
 }

 return Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Expanded(flex: 7, child: _buildFeasibilityAssessmentCard(snapshot)),
 const SizedBox(width: 20),
 Expanded(flex: 5, child: _buildLegacyConstraintsCard(snapshot)),
 ],
 );
 }

 Widget _buildEnvironmentSection(
 _TechnicalAlignmentDashboardSnapshot snapshot,
 bool isMobile,
 ) {
 if (isMobile) {
 return Column(
 children: [
 _buildCompatibilityMatrixCard(snapshot),
 const SizedBox(height: 20),
 _buildIntegrationMapCard(snapshot),
 ],
 );
 }

 return Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Expanded(flex: 7, child: _buildCompatibilityMatrixCard(snapshot)),
 const SizedBox(width: 20),
 Expanded(flex: 5, child: _buildIntegrationMapCard(snapshot)),
 ],
 );
 }

 Widget _buildGovernanceGrid(_TechnicalAlignmentDashboardSnapshot snapshot) {
 return LayoutBuilder(
 builder: (context, constraints) {
 final spacing = 20.0;
 final columns = constraints.maxWidth >= 1080 ? 2 : 1;
 final cardWidth = columns == 1
 ? constraints.maxWidth
 : (constraints.maxWidth - spacing) / 2;
 final cards = [
 _buildPerformanceTargetsCard(snapshot),
 _buildMigrationStrategyCard(snapshot),
 _buildProtocolsAlignmentCard(snapshot),
 _buildDebtLogCard(snapshot),
 ];

 return Wrap(
 spacing: spacing,
 runSpacing: spacing,
 children: cards
 .map((card) => SizedBox(width: cardWidth, child: card))
 .toList(),
 );
 },
 );
 }

 Widget _buildDetailedRegistersPanel(List<String> ownerOptions) {
 return Container(
 width: double.infinity,
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(20),
 border: Border.all(color: const Color(0xFFE2E8F0)),
 boxShadow: const [
 BoxShadow(
 color: Color(0x0F000000),
 blurRadius: 16,
 offset: Offset(0, 6),
 ),
 ],
 ),
 child: Padding(
 padding: const EdgeInsets.all(20),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 const Row(
 children: [
 Icon(Icons.folder_open_outlined, size: 20, color: Color(0xFF475569)),
 SizedBox(width: 8),
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 'Detailed Registers',
 style: TextStyle(
 fontSize: 17,
 fontWeight: FontWeight.w700,
 color: Color(0xFF111827),
 ),
 ),
 SizedBox(height: 4),
 Text(
 'Edit the working notes, constraints, mappings, and dependencies feeding the dashboard above.',
 style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
 ),
 ],
 ),
 ),
 ],
 ),
 const SizedBox(height: 20),
 ResponsiveGrid(
 desktopColumns: 1,
 tabletColumns: 1,
 mobileColumns: 1,
 spacing: 16,
 runSpacing: 16,
 children: [
 _buildWorkingNotesCard(),
 _buildConstraintsCard(ownerOptions),
 _buildRequirementMappingCard(),
 _buildDependenciesCard(ownerOptions),
 ],
 ),
 ],
 ),
 ),
 );
 }

 Widget _buildWorkingNotesCard() {
 return _buildHubPanel(
 title: 'Working Notes & Open Questions',
 subtitle:
 'Capture assumptions, unresolved blockers, and cross-team context driving feasibility decisions.',
 icon: Icons.edit_note_outlined,
 accent: const Color(0xFF1D4ED8),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Container(
 padding: const EdgeInsets.all(16),
 decoration: BoxDecoration(
 color: const Color(0xFFF8FAFC),
 borderRadius: BorderRadius.circular(16),
 border: Border.all(color: const Color(0xFFE2E8F0)),
 ),
 child: VoiceTextField(
 controller: _notesController,
 enabled: _canEditAlignment || _canCreateAlignment,
 maxLines: null,
 minLines: 4,
 keyboardType: TextInputType.multiline,
 style: const TextStyle(fontSize: 14, color: Color(0xFF1F2937)),
 decoration: InputDecoration(
 hintText:
 'Record technical constraints, venue conditions, legacy system notes, dependency assumptions, and open engineering questions.',
 hintStyle: TextStyle(color: Colors.grey[500], fontSize: 13),
 border: InputBorder.none,
 isDense: true,
 contentPadding: EdgeInsets.zero,
 ),
 ),
 ),
 const SizedBox(height: 12),
 Text(
 'Keep this focused on decisions that affect feasibility, sequencing, or governance. Detailed implementation choices can still live with engineering later.',
 style: TextStyle(fontSize: 12, color: Colors.grey[600]),
 ),
 ],
 ),
 );
 }

 Widget _buildFeasibilityAssessmentCard(
 _TechnicalAlignmentDashboardSnapshot snapshot,
 ) {
 return _buildHubPanel(
 title: 'Technical Feasibility Assessment',
 subtitle:
 'Score each feature against the constraint most likely to challenge delivery.',
 icon: Icons.speed_outlined,
 accent: const Color(0xFF1D4ED8),
 child: Column(
 children: snapshot.feasibilityItems
 .map(
 (item) => Container(
 margin: const EdgeInsets.only(bottom: 12),
 padding: const EdgeInsets.all(16),
 decoration: BoxDecoration(
 color: const Color(0xFFF8FAFC),
 borderRadius: BorderRadius.circular(16),
 border: Border.all(color: const Color(0xFFE2E8F0)),
 ),
 child: LayoutBuilder(
 builder: (context, constraints) {
 final stacked = constraints.maxWidth < 520;
 final details = Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 item.feature,
 style: const TextStyle(
 fontSize: 14,
 fontWeight: FontWeight.w800,
 color: Color(0xFF0F172A),
 ),
 ),
 const SizedBox(height: 6),
 Text(
 'Constraint: ${item.constraint}',
 style: const TextStyle(
 fontSize: 12.5,
 color: Color(0xFF334155),
 height: 1.45,
 ),
 ),
 if (item.note.trim().isNotEmpty) ...[
 const SizedBox(height: 6),
 Text(
 item.note,
 style: const TextStyle(
 fontSize: 12,
 color: Color(0xFF64748B),
 height: 1.45,
 ),
 ),
 ],
 ],
 ),
 );
 final gauge = SizedBox(
 width: stacked ? double.infinity : 170,
 child: _buildFeasibilityGauge(item.score),
 );

 if (stacked) {
 return Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 details,
 const SizedBox(height: 14),
 gauge,
 ],
 );
 }

 return Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 details,
 const SizedBox(width: 16),
 gauge,
 ],
 );
 },
 ),
 ),
 )
 .toList(),
 ),
 );
 }

 Widget _buildLegacyConstraintsCard(
 _TechnicalAlignmentDashboardSnapshot snapshot,
 ) {
 return _buildHubPanel(
 title: 'Legacy & Heritage Constraints',
 subtitle:
 'Warning-led view of existing systems and site realities that change the design approach.',
 icon: Icons.warning_amber_rounded,
 accent: AppSemanticColors.warning,
 child: Column(
 children: snapshot.legacyItems
 .map(
 (item) => Container(
 margin: const EdgeInsets.only(bottom: 12),
 padding: const EdgeInsets.all(14),
 decoration: BoxDecoration(
 color: const Color(0xFFFFFBEB),
 borderRadius: BorderRadius.circular(16),
 border: Border.all(color: const Color(0xFFFDE68A)),
 ),
 child: Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Container(
 width: 36,
 height: 36,
 decoration: BoxDecoration(
 color: _severityColor(item.severity).withOpacity(0.14),
 borderRadius: BorderRadius.circular(12),
 ),
 child: Icon(
 Icons.warning_amber_rounded,
 color: _severityColor(item.severity),
 ),
 ),
 const SizedBox(width: 12),
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 children: [
 Expanded(
 child: Text(
 item.component,
 style: const TextStyle(
 fontSize: 13.5,
 fontWeight: FontWeight.w800,
 color: Color(0xFF0F172A),
 ),
 ),
 ),
 _buildStatusBadge(
 item.severity,
 _severityColor(item.severity),
 ),
 ],
 ),
 const SizedBox(height: 6),
 Text(
 item.impact,
 style: const TextStyle(
 fontSize: 12,
 color: Color(0xFF64748B),
 height: 1.45,
 ),
 ),
 ],
 ),
 ),
 ],
 ),
 ),
 )
 .toList(),
 ),
 );
 }

 Widget _buildCompatibilityMatrixCard(
 _TechnicalAlignmentDashboardSnapshot snapshot,
 ) {
 return _buildHubPanel(
 title: 'Infrastructure & Environment Compatibility',
 subtitle:
 'Compare what the design expects against what the project or venue can currently support.',
 icon: Icons.table_chart_outlined,
 accent: const Color(0xFF0F766E),
 child: Column(
 children: [
 Container(
 padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
 decoration: BoxDecoration(
 color: const Color(0xFFF1F5F9),
 borderRadius: BorderRadius.circular(14),
 ),
 child: const Row(
 children: [
 Expanded(
 flex: 3,
 child: Text(
 'Requirement',
 style: TextStyle(
 fontSize: 12,
 fontWeight: FontWeight.w800,
 color: Color(0xFF334155),
 ),
 ),
 ),
 Expanded(
 flex: 3,
 child: Text(
 'Available',
 style: TextStyle(
 fontSize: 12,
 fontWeight: FontWeight.w800,
 color: Color(0xFF334155),
 ),
 ),
 ),
 Expanded(
 flex: 2,
 child: Text(
 'Gap Analysis',
 style: TextStyle(
 fontSize: 12,
 fontWeight: FontWeight.w800,
 color: Color(0xFF334155),
 ),
 ),
 ),
 ],
 ),
 ),
 const SizedBox(height: 10),
 for (int i = 0; i < snapshot.compatibilityRows.length; i++) ...[
 Container(
 padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
 decoration: BoxDecoration(
 color: i.isEven ? Colors.white : const Color(0xFFF8FAFC),
 borderRadius: BorderRadius.circular(14),
 border: Border.all(color: const Color(0xFFE2E8F0)),
 ),
 child: Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Expanded(
 flex: 3,
 child: Text(
 snapshot.compatibilityRows[i].requirement,
 style: const TextStyle(
 fontSize: 12.5,
 fontWeight: FontWeight.w700,
 color: Color(0xFF0F172A),
 height: 1.45,
 ),
 ),
 ),
 const SizedBox(width: 12),
 Expanded(
 flex: 3,
 child: Text(
 snapshot.compatibilityRows[i].available,
 style: const TextStyle(
 fontSize: 12,
 color: Color(0xFF64748B),
 height: 1.45,
 ),
 ),
 ),
 const SizedBox(width: 12),
 Expanded(
 flex: 2,
 child: Align(
 alignment: Alignment.topLeft,
 child: _buildStatusBadge(
 snapshot.compatibilityRows[i].gapLabel,
 snapshot.compatibilityRows[i].gapColor,
 ),
 ),
 ),
 ],
 ),
 ),
 if (i != snapshot.compatibilityRows.length - 1)
 const SizedBox(height: 10),
 ],
 ],
 ),
 );
 }

 Widget _buildIntegrationMapCard(
 _TechnicalAlignmentDashboardSnapshot snapshot,
 ) {
 return _buildHubPanel(
 title: 'Platform & System Integration Map',
 subtitle:
 'Connected versus pending systems around the central project concept.',
 icon: Icons.hub_outlined,
 accent: const Color(0xFF2563EB),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Container(
 padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
 decoration: BoxDecoration(
 color: const Color(0xFFEFF6FF),
 borderRadius: BorderRadius.circular(16),
 border: Border.all(color: const Color(0xFFBFDBFE)),
 ),
 child: Row(
 children: [
 Container(
 width: 40,
 height: 40,
 decoration: BoxDecoration(
 color: const Color(0xFF1D4ED8),
 borderRadius: BorderRadius.circular(12),
 ),
 child:
 const Icon(Icons.apartment_rounded, color: Colors.white),
 ),
 const SizedBox(width: 12),
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 const Text(
 'Central Project Node',
 style: TextStyle(
 fontSize: 11.5,
 fontWeight: FontWeight.w700,
 color: Color(0xFF1D4ED8),
 ),
 ),
 const SizedBox(height: 2),
 Text(
 snapshot.projectLabel,
 style: const TextStyle(
 fontSize: 14,
 fontWeight: FontWeight.w800,
 color: Color(0xFF0F172A),
 ),
 ),
 ],
 ),
 ),
 ],
 ),
 ),
 const SizedBox(height: 16),
 ...snapshot.integrationNodes.map(
 (node) => Padding(
 padding: const EdgeInsets.only(bottom: 12),
 child: Row(
 children: [
 SizedBox(
 width: 72,
 child: Row(
 children: [
 Expanded(
 child: Container(
 height: 2,
 color: const Color(0xFF93C5FD),
 ),
 ),
 Container(
 width: 10,
 height: 10,
 decoration: const BoxDecoration(
 color: Color(0xFF2563EB),
 shape: BoxShape.circle,
 ),
 ),
 ],
 ),
 ),
 const SizedBox(width: 12),
 Expanded(
 child: Container(
 padding: const EdgeInsets.symmetric(
 horizontal: 14,
 vertical: 14,
 ),
 decoration: BoxDecoration(
 color: const Color(0xFFF8FAFC),
 borderRadius: BorderRadius.circular(16),
 border: Border.all(color: const Color(0xFFE2E8F0)),
 ),
 child: Row(
 children: [
 Expanded(
 child: Text(
 node.name,
 style: const TextStyle(
 fontSize: 13,
 fontWeight: FontWeight.w700,
 color: Color(0xFF0F172A),
 ),
 ),
 ),
 _buildStatusBadge(
 node.status,
 node.status == 'Connected'
 ? AppSemanticColors.success
 : AppSemanticColors.warning,
 ),
 ],
 ),
 ),
 ),
 ],
 ),
 ),
 ),
 ],
 ),
 );
 }

 Widget _buildPerformanceTargetsCard(
 _TechnicalAlignmentDashboardSnapshot snapshot,
 ) {
 return _buildHubPanel(
 title: 'Performance & Scalability Targets',
 subtitle:
 'Target values compared against current capacity for digital and physical demand.',
 icon: Icons.monitor_heart_outlined,
 accent: const Color(0xFF1D4ED8),
 child: Column(
 children: snapshot.performanceItems
 .map(
 (item) => Container(
 margin: const EdgeInsets.only(bottom: 12),
 padding: const EdgeInsets.all(14),
 decoration: BoxDecoration(
 color: const Color(0xFFF8FAFC),
 borderRadius: BorderRadius.circular(16),
 border: Border.all(color: const Color(0xFFE2E8F0)),
 ),
 child: LayoutBuilder(
 builder: (context, constraints) {
 final stacked = constraints.maxWidth < 460;
 final targetField = _buildDataField(
 label: 'Target Value',
 value: item.targetValue,
 );
 final currentField = _buildDataField(
 label: 'Current Capacity',
 value: item.currentCapacity,
 );

 if (stacked) {
 return Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 item.metric,
 style: const TextStyle(
 fontSize: 13.5,
 fontWeight: FontWeight.w800,
 color: Color(0xFF0F172A),
 ),
 ),
 const SizedBox(height: 12),
 targetField,
 const SizedBox(height: 10),
 currentField,
 ],
 );
 }

 return Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Expanded(
 flex: 2,
 child: Padding(
 padding: const EdgeInsets.only(top: 12),
 child: Text(
 item.metric,
 style: const TextStyle(
 fontSize: 13.5,
 fontWeight: FontWeight.w800,
 color: Color(0xFF0F172A),
 ),
 ),
 ),
 ),
 const SizedBox(width: 12),
 Expanded(child: targetField),
 const SizedBox(width: 12),
 Expanded(child: currentField),
 ],
 );
 },
 ),
 ),
 )
 .toList(),
 ),
 );
 }

 Widget _buildMigrationStrategyCard(
 _TechnicalAlignmentDashboardSnapshot snapshot,
 ) {
 return _buildHubPanel(
 title: 'Data Migration & Conversion Strategy',
 subtitle:
 'Flow view for how legacy, spatial, and operational inputs become usable design data.',
 icon: Icons.sync_alt_rounded,
 accent: const Color(0xFF0F766E),
 child: Column(
 children: snapshot.migrationLanes
 .map(
 (lane) => Container(
 margin: const EdgeInsets.only(bottom: 12),
 padding: const EdgeInsets.all(14),
 decoration: BoxDecoration(
 color: const Color(0xFFF8FAFC),
 borderRadius: BorderRadius.circular(16),
 border: Border.all(color: const Color(0xFFE2E8F0)),
 ),
 child: LayoutBuilder(
 builder: (context, constraints) {
 final stacked = constraints.maxWidth < 460;
 final stages = [
 _buildFlowStage(
 label: 'Source',
 value: lane.source,
 color: const Color(0xFFDBEAFE),
 ),
 _buildFlowStage(
 label: 'Transformation',
 value: lane.transformation,
 color: const Color(0xFFD1FAE5),
 ),
 _buildFlowStage(
 label: 'Destination',
 value: lane.destination,
 color: const Color(0xFFFFF3C4),
 ),
 ];

 if (stacked) {
 return Column(
 children: [
 stages[0],
 const Padding(
 padding: EdgeInsets.symmetric(vertical: 8),
 child: Icon(Icons.arrow_downward_rounded,
 color: Color(0xFF64748B)),
 ),
 stages[1],
 const Padding(
 padding: EdgeInsets.symmetric(vertical: 8),
 child: Icon(Icons.arrow_downward_rounded,
 color: Color(0xFF64748B)),
 ),
 stages[2],
 ],
 );
 }

 return Row(
 children: [
 Expanded(child: stages[0]),
 const Padding(
 padding: EdgeInsets.symmetric(horizontal: 8),
 child: Icon(Icons.arrow_forward_rounded,
 color: Color(0xFF64748B)),
 ),
 Expanded(child: stages[1]),
 const Padding(
 padding: EdgeInsets.symmetric(horizontal: 8),
 child: Icon(Icons.arrow_forward_rounded,
 color: Color(0xFF64748B)),
 ),
 Expanded(child: stages[2]),
 ],
 );
 },
 ),
 ),
 )
 .toList(),
 ),
 );
 }

 Widget _buildProtocolsAlignmentCard(
 _TechnicalAlignmentDashboardSnapshot snapshot,
 ) {
 return _buildHubPanel(
 title: 'Security & Safety Protocols Alignment',
 subtitle:
 'Compliance view across digital controls and physical safety obligations.',
 icon: Icons.shield_outlined,
 accent: const Color(0xFF1D4ED8),
 child: Column(
 children: snapshot.protocols
 .map(
 (item) => Container(
 margin: const EdgeInsets.only(bottom: 12),
 padding: const EdgeInsets.all(14),
 decoration: BoxDecoration(
 color: const Color(0xFFF8FAFC),
 borderRadius: BorderRadius.circular(16),
 border: Border.all(color: const Color(0xFFE2E8F0)),
 ),
 child: Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Container(
 width: 34,
 height: 34,
 decoration: BoxDecoration(
 color: _protocolColor(item.status).withOpacity(0.12),
 borderRadius: BorderRadius.circular(10),
 ),
 child: Icon(
 item.status == 'Aligned'
 ? Icons.verified_user_outlined
 : Icons.shield_outlined,
 color: _protocolColor(item.status),
 ),
 ),
 const SizedBox(width: 12),
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
 fontSize: 13.5,
 fontWeight: FontWeight.w800,
 color: Color(0xFF0F172A),
 ),
 ),
 ),
 _buildStatusBadge(
 item.status,
 _protocolColor(item.status),
 ),
 ],
 ),
 const SizedBox(height: 6),
 Text(
 item.detail,
 style: const TextStyle(
 fontSize: 12,
 color: Color(0xFF64748B),
 height: 1.45,
 ),
 ),
 ],
 ),
 ),
 ],
 ),
 ),
 )
 .toList(),
 ),
 );
 }

 Widget _buildDebtLogCard(_TechnicalAlignmentDashboardSnapshot snapshot) {
 return _buildHubPanel(
 title: 'Technical Debt & Workarounds Log',
 subtitle:
 'Temporary measures that keep design moving while deeper technical blockers remain unresolved.',
 icon: Icons.rule_folder_outlined,
 accent: AppSemanticColors.warning,
 child: Column(
 children: [
 Container(
 padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
 decoration: BoxDecoration(
 color: const Color(0xFFF1F5F9),
 borderRadius: BorderRadius.circular(14),
 ),
 child: const Row(
 children: [
 Expanded(
 flex: 3,
 child: Text(
 'Issue',
 style: TextStyle(
 fontSize: 12,
 fontWeight: FontWeight.w800,
 color: Color(0xFF334155),
 ),
 ),
 ),
 Expanded(
 flex: 4,
 child: Text(
 'Workaround',
 style: TextStyle(
 fontSize: 12,
 fontWeight: FontWeight.w800,
 color: Color(0xFF334155),
 ),
 ),
 ),
 Expanded(
 flex: 2,
 child: Text(
 'Owner',
 style: TextStyle(
 fontSize: 12,
 fontWeight: FontWeight.w800,
 color: Color(0xFF334155),
 ),
 ),
 ),
 ],
 ),
 ),
 const SizedBox(height: 10),
 for (int i = 0; i < snapshot.debtItems.length; i++) ...[
 Container(
 padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
 decoration: BoxDecoration(
 color: i.isEven ? Colors.white : const Color(0xFFF8FAFC),
 borderRadius: BorderRadius.circular(14),
 border: Border.all(color: const Color(0xFFE2E8F0)),
 ),
 child: Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Expanded(
 flex: 3,
 child: Text(
 snapshot.debtItems[i].issue,
 style: const TextStyle(
 fontSize: 12.5,
 fontWeight: FontWeight.w700,
 color: Color(0xFF0F172A),
 height: 1.45,
 ),
 ),
 ),
 const SizedBox(width: 12),
 Expanded(
 flex: 4,
 child: Text(
 snapshot.debtItems[i].workaround,
 style: const TextStyle(
 fontSize: 12,
 color: Color(0xFF64748B),
 height: 1.45,
 ),
 ),
 ),
 const SizedBox(width: 12),
 Expanded(
 flex: 2,
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 snapshot.debtItems[i].owner,
 style: const TextStyle(
 fontSize: 12,
 fontWeight: FontWeight.w700,
 color: Color(0xFF334155),
 ),
 ),
 const SizedBox(height: 6),
 _buildStatusBadge(
 snapshot.debtItems[i].severity,
 _severityColor(snapshot.debtItems[i].severity),
 ),
 ],
 ),
 ),
 ],
 ),
 ),
 if (i != snapshot.debtItems.length - 1) const SizedBox(height: 10),
 ],
 ],
 ),
 );
 }

 Widget _buildHubPanel({
 required String title,
 required String subtitle,
 required IconData icon,
 required Color accent,
 required Widget child,
 }) {
 return Container(
 width: double.infinity,
 padding: const EdgeInsets.all(22),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(22),
 border: Border.all(color: const Color(0xFFE2E8F0)),
 boxShadow: const [
 BoxShadow(
 color: Color(0x0F000000),
 blurRadius: 16,
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
 width: 42,
 height: 42,
 decoration: BoxDecoration(
 color: accent.withOpacity(0.10),
 borderRadius: BorderRadius.circular(14),
 border: Border.all(color: accent.withOpacity(0.18)),
 ),
 child: Icon(icon, color: accent),
 ),
 const SizedBox(width: 12),
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 title,
 style: const TextStyle(
 fontSize: 18,
 fontWeight: FontWeight.w800,
 color: Color(0xFF111827),
 ),
 ),
 const SizedBox(height: 4),
 Text(
 subtitle,
 style: const TextStyle(
 fontSize: 12.5,
 color: Color(0xFF64748B),
 height: 1.45,
 ),
 ),
 ],
 ),
 ),
 ],
 ),
 const SizedBox(height: 18),
 child,
 ],
 ),
 );
 }

 Widget _buildHeaderMetricPill(String label, String value) {
 return Container(
 padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
 decoration: BoxDecoration(
 color: Colors.white.withOpacity(0.08),
 borderRadius: BorderRadius.circular(16),
 border: Border.all(color: Colors.white.withOpacity(0.12)),
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 label,
 style: TextStyle(
 fontSize: 11,
 fontWeight: FontWeight.w700,
 color: Colors.white.withOpacity(0.72),
 ),
 ),
 const SizedBox(height: 4),
 Text(
 value,
 style: const TextStyle(
 fontSize: 18,
 fontWeight: FontWeight.w900,
 color: Colors.white,
 ),
 ),
 ],
 ),
 );
 }

 Widget _buildStatusBadge(String label, Color color) {
 return Container(
 padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
 decoration: BoxDecoration(
 color: color.withOpacity(0.12),
 borderRadius: BorderRadius.circular(999),
 border: Border.all(color: color.withOpacity(0.22)),
 ),
 child: Text(
 label,
 style: TextStyle(
 fontSize: 11.5,
 fontWeight: FontWeight.w800,
 color: color,
 ),
 ),
 );
 }

 Widget _buildFeasibilityGauge(String score) {
 final scoreColor = _feasibilityColor(score);
 final activeSegments = score == 'High'
 ? 3
 : score == 'Medium'
 ? 2
 : 1;
 return Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 children: [
 const Text(
 'Feasibility Score',
 style: TextStyle(
 fontSize: 11.5,
 fontWeight: FontWeight.w700,
 color: Color(0xFF475569),
 ),
 ),
 const Spacer(),
 _buildStatusBadge(score, scoreColor),
 ],
 ),
 const SizedBox(height: 10),
 Row(
 children: List.generate(
 3,
 (index) => Expanded(
 child: Container(
 margin: EdgeInsets.only(right: index == 2 ? 0 : 6),
 height: 10,
 decoration: BoxDecoration(
 color: index < activeSegments
 ? scoreColor
 : const Color(0xFFE2E8F0),
 borderRadius: BorderRadius.circular(999),
 ),
 ),
 ),
 ),
 ),
 ],
 );
 }

 Widget _buildDataField({
 required String label,
 required String value,
 }) {
 return Container(
 padding: const EdgeInsets.all(12),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(12),
 border: Border.all(color: const Color(0xFFE2E8F0)),
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 label,
 style: const TextStyle(
 fontSize: 11.5,
 fontWeight: FontWeight.w700,
 color: Color(0xFF475569),
 ),
 ),
 const SizedBox(height: 6),
 Text(
 value,
 style: const TextStyle(
 fontSize: 12.5,
 fontWeight: FontWeight.w700,
 color: Color(0xFF0F172A),
 height: 1.45,
 ),
 ),
 ],
 ),
 );
 }

 Widget _buildFlowStage({
 required String label,
 required String value,
 required Color color,
 }) {
 return Container(
 padding: const EdgeInsets.all(12),
 decoration: BoxDecoration(
 color: color,
 borderRadius: BorderRadius.circular(14),
 border: Border.all(color: color.withOpacity(0.9)),
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 label,
 style: const TextStyle(
 fontSize: 11.5,
 fontWeight: FontWeight.w800,
 color: Color(0xFF334155),
 ),
 ),
 const SizedBox(height: 6),
 Text(
 value,
 style: const TextStyle(
 fontSize: 12.5,
 fontWeight: FontWeight.w700,
 color: Color(0xFF0F172A),
 height: 1.45,
 ),
 ),
 ],
 ),
 );
 }

 Color _feasibilityColor(String score) {
 switch (score) {
 case 'High':
 return AppSemanticColors.success;
 case 'Medium':
 return AppSemanticColors.warning;
 default:
 return const Color(0xFFDC2626);
 }
 }

 Color _severityColor(String severity) {
 switch (severity) {
 case 'High':
 return const Color(0xFFDC2626);
 case 'Medium':
 return AppSemanticColors.warning;
 default:
 return AppSemanticColors.info;
 }
 }

 Color _protocolColor(String status) {
 switch (status) {
 case 'Aligned':
 return AppSemanticColors.success;
 case 'Gap':
 return const Color(0xFFDC2626);
 default:
 return AppSemanticColors.warning;
 }
 }

 Widget _buildConstraintsCard(List<String> ownerOptions) {
 return Container(
 padding: const EdgeInsets.all(20),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(16),
 border: Border.all(color: AppSemanticColors.border),
 boxShadow: [
 BoxShadow(
 color: Colors.black.withOpacity(0.04),
 blurRadius: 18,
 offset: const Offset(0, 10),
 ),
 ],
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 _buildSectionHeader(
 icon: Icons.policy_outlined,
 color: const Color(0xFF1D4ED8),
 title: 'Constraints & guardrails',
 subtitle:
 'World-class guardrails that clarify what must never drift.',
 actionLabel: 'Add constraint',
 onAction: _addConstraintRow,
 ),
 const SizedBox(height: 16),
 _buildScrollableTableHeader(
 columns: const [
 _TableColumn(label: 'Constraint', flex: 3, minWidth: 260, alignment: Alignment.center),
 _TableColumn(label: 'Guardrail', flex: 5, minWidth: 400, alignment: Alignment.center),
 _TableColumn(label: 'Owner', flex: 2, minWidth: 150, alignment: Alignment.center),
 _TableColumn(label: 'Status', flex: 2, minWidth: 140, alignment: Alignment.center),
 _TableColumn(
 label: 'Actions', flex: 2, minWidth: _technicalAlignmentActionColumnWidth, alignment: Alignment.center),
 ],
 ),
 const SizedBox(height: 10),
 if (_constraints.isEmpty)
 _buildEmptyTableState(
 message: 'No constraints captured yet. Add the first guardrail.',
 actionLabel: 'Add constraint',
 onAction: _addConstraintRow,
 )
 else
 _buildScrollableTableBody(
 columns: const [
 _TableColumn(label: 'Constraint', flex: 3, minWidth: 260, alignment: Alignment.center),
 _TableColumn(label: 'Guardrail', flex: 5, minWidth: 400, alignment: Alignment.center),
 _TableColumn(label: 'Owner', flex: 2, minWidth: 150, alignment: Alignment.center),
 _TableColumn(label: 'Status', flex: 2, minWidth: 140, alignment: Alignment.center),
 _TableColumn(
 label: 'Actions', flex: 2, minWidth: _technicalAlignmentActionColumnWidth, alignment: Alignment.center),
 ],
 rowCount: _constraints.length,
 rowBuilder: (i) => _buildConstraintRow(
 _constraints[i],
 index: i,
 isStriped: i.isOdd,
 ownerOptions: ownerOptions,
 ),
 ),
 ],
 ),
 );
 }

 Widget _buildRequirementMappingCard() {
 return Container(
 padding: const EdgeInsets.all(20),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(16),
 border: Border.all(color: AppSemanticColors.border),
 boxShadow: [
 BoxShadow(
 color: Colors.black.withOpacity(0.04),
 blurRadius: 18,
 offset: const Offset(0, 10),
 ),
 ],
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 _buildSectionHeader(
 icon: Icons.swap_horiz_outlined,
 color: const Color(0xFF0F766E),
 title: 'Requirements → solution mapping',
 subtitle:
 'Exceptional clarity on how requirements become technical choices.',
 actionLabel: 'Add mapping',
 onAction: _addMappingRow,
 ),
 const SizedBox(height: 16),
 _buildScrollableTableHeader(
 columns: const [
 _TableColumn(label: 'Requirement', flex: 3, minWidth: 260, alignment: Alignment.center),
 _TableColumn(label: 'Technical approach', flex: 5, minWidth: 460, alignment: Alignment.center),
 _TableColumn(label: 'Status', flex: 2, minWidth: 140, alignment: Alignment.center),
 _TableColumn(
 label: 'Actions', flex: 2, minWidth: _technicalAlignmentActionColumnWidth, alignment: Alignment.center),
 ],
 ),
 const SizedBox(height: 10),
 if (_mappings.isEmpty)
 _buildEmptyTableState(
 message:
 'No mappings yet. Add the first requirement-to-solution entry.',
 actionLabel: 'Add mapping',
 onAction: _addMappingRow,
 )
 else
 _buildScrollableTableBody(
 columns: const [
 _TableColumn(label: 'Requirement', flex: 3, minWidth: 260, alignment: Alignment.center),
 _TableColumn(label: 'Technical approach', flex: 5, minWidth: 460, alignment: Alignment.center),
 _TableColumn(label: 'Status', flex: 2, minWidth: 140, alignment: Alignment.center),
 _TableColumn(
 label: 'Actions', flex: 2, minWidth: _technicalAlignmentActionColumnWidth, alignment: Alignment.center),
 ],
 rowCount: _mappings.length,
 rowBuilder: (i) => _buildMappingRow(_mappings[i], index: i, isStriped: i.isOdd),
 ),
 const SizedBox(height: 16),
 Text(
 'Use this table to call out any requirement that needs a specific design pattern or infrastructure choice.',
 style: TextStyle(fontSize: 12, color: Colors.grey[600]),
 ),
 ],
 ),
 );
 }

 Widget _buildDependenciesCard(List<String> ownerOptions) {
 return Container(
 padding: const EdgeInsets.all(20),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(16),
 border: Border.all(color: AppSemanticColors.border),
 boxShadow: [
 BoxShadow(
 color: Colors.black.withOpacity(0.04),
 blurRadius: 18,
 offset: const Offset(0, 10),
 ),
 ],
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 _buildSectionHeader(
 icon: Icons.hub_outlined,
 color: const Color(0xFF9333EA),
 title: 'Dependencies & decisions',
 subtitle:
 'World-class visibility into what must land before build.',
 actionLabel: 'Add dependency',
 onAction: _addDependencyRow,
 ),
 const SizedBox(height: 16),
 _buildScrollableTableHeader(
 columns: const [
 _TableColumn(label: 'Dependency or decision', flex: 4, minWidth: 260, alignment: Alignment.center),
 _TableColumn(label: 'Detail', flex: 5, minWidth: 380, alignment: Alignment.center),
 _TableColumn(label: 'Owner', flex: 2, minWidth: 150, alignment: Alignment.center),
 _TableColumn(label: 'Status', flex: 2, minWidth: 140, alignment: Alignment.center),
 _TableColumn(
 label: 'Actions', flex: 2, minWidth: _technicalAlignmentActionColumnWidth, alignment: Alignment.center),
 ],
 ),
 const SizedBox(height: 10),
 if (_dependencies.isEmpty)
 _buildEmptyTableState(
 message:
 'No dependencies yet. Add the first decision or external dependency.',
 actionLabel: 'Add dependency',
 onAction: _addDependencyRow,
 )
 else
 _buildScrollableTableBody(
 columns: const [
 _TableColumn(label: 'Dependency or decision', flex: 4, minWidth: 260, alignment: Alignment.center),
 _TableColumn(label: 'Detail', flex: 5, minWidth: 380, alignment: Alignment.center),
 _TableColumn(label: 'Owner', flex: 2, minWidth: 150, alignment: Alignment.center),
 _TableColumn(label: 'Status', flex: 2, minWidth: 140, alignment: Alignment.center),
 _TableColumn(
 label: 'Actions', flex: 2, minWidth: _technicalAlignmentActionColumnWidth, alignment: Alignment.center),
 ],
 rowCount: _dependencies.length,
 rowBuilder: (i) => _buildDependencyRow(
 _dependencies[i],
 index: i,
 isStriped: i.isOdd,
 ownerOptions: ownerOptions,
 ),
 ),
 const SizedBox(height: 16),
 // Export button
 SizedBox(
 width: double.infinity,
 child: ElevatedButton.icon(
 onPressed: _canExportAlignment ? _exportAlignmentSummary : null,
 icon: const Icon(Icons.download, size: 18),
 label: const Text('Export alignment summary'),
 style: ElevatedButton.styleFrom(
 backgroundColor: LightModeColors.accent,
 foregroundColor: Colors.black87,
 padding: const EdgeInsets.symmetric(vertical: 12),
 shape: RoundedRectangleBorder(
 borderRadius: BorderRadius.circular(20)),
 ),
 ),
 ),
 ],
 ),
 );
 }

 Future<void> _exportAlignmentSummary() async {
 if (!_canExportAlignment) {
 _showPermissionSnackBar('export technical alignment data');
 return;
 }
 final doc = pw.Document();
 final notes = _notesController.text.trim();

 final constraints = _constraints
 .map((row) {
 final constraint = row.constraint.trim();
 final guardrail = row.guardrail.trim();
 final owner = row.owner.trim();
 final status = row.status.trim();
 if (constraint.isEmpty &&
 guardrail.isEmpty &&
 owner.isEmpty &&
 status.isEmpty) {
 return '';
 }
 final base =
 guardrail.isEmpty ? constraint : '$constraint — $guardrail';
 final ownerLabel = owner.isEmpty ? '' : 'Owner: $owner';
 final statusLabel = status.isEmpty ? '' : 'Status: $status';
 final meta = [ownerLabel, statusLabel]
 .where((value) => value.isNotEmpty)
 .join(' · ');
 return meta.isEmpty ? base : '$base ($meta)';
 })
 .where((line) => line.trim().isNotEmpty)
 .toList();

 final mappings = _mappings
 .map((row) {
 final requirement = row.requirement.trim();
 final approach = row.approach.trim();
 final status = row.status.trim();
 if (requirement.isEmpty && approach.isEmpty && status.isEmpty) {
 return '';
 }
 final base =
 approach.isEmpty ? requirement : '$requirement — $approach';
 return status.isEmpty ? base : '$base (Status: $status)';
 })
 .where((line) => line.trim().isNotEmpty)
 .toList();

 final dependencies = _dependencies
 .map((row) {
 final item = row.item.trim();
 final detail = row.detail.trim();
 final owner = row.owner.trim();
 final status = row.status.trim();
 if (item.isEmpty &&
 detail.isEmpty &&
 owner.isEmpty &&
 status.isEmpty) {
 return '';
 }
 final base = detail.isEmpty ? item : '$item — $detail';
 final ownerLabel = owner.isEmpty ? '' : 'Owner: $owner';
 final statusLabel = status.isEmpty ? '' : 'Status: $status';
 final meta = [ownerLabel, statusLabel]
 .where((value) => value.isNotEmpty)
 .join(' · ');
 return meta.isEmpty ? base : '$base ($meta)';
 })
 .where((line) => line.trim().isNotEmpty)
 .toList();

 doc.addPage(
 pw.MultiPage(
 pageFormat: PdfPageFormat.a4,
 margin: const pw.EdgeInsets.all(32),
 build: (context) => [
 pw.Text(
 'Technical Alignment Summary',
 style: pw.TextStyle(
 fontSize: 22,
 fontWeight: pw.FontWeight.bold,
 ),
 ),
 pw.SizedBox(height: 12),
 _pdfTextBlock('Notes', notes),
 _pdfSection('Constraints & guardrails', constraints),
 _pdfSection('Requirements → solution mapping', mappings),
 _pdfSection('Dependencies & decisions', dependencies),
 ],
 ),
 );

 await Printing.layoutPdf(
 onLayout: (format) async => doc.save(),
 name: 'technical-alignment-summary.pdf',
 );
 }

 pw.Widget _pdfTextBlock(String title, String content) {
 final normalized = content.trim().isEmpty ? 'No entries.' : content.trim();
 return pw.Column(
 crossAxisAlignment: pw.CrossAxisAlignment.start,
 children: [
 pw.Text(title,
 style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
 pw.SizedBox(height: 6),
 pw.Text(normalized, style: const pw.TextStyle(fontSize: 12)),
 pw.SizedBox(height: 12),
 ],
 );
 }

 pw.Widget _pdfSection(String title, List<String> items) {
 return pw.Column(
 crossAxisAlignment: pw.CrossAxisAlignment.start,
 children: [
 pw.Text(title,
 style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
 pw.SizedBox(height: 6),
 if (items.isEmpty)
 pw.Text('No entries.', style: const pw.TextStyle(fontSize: 12))
 else
 pw.Column(
 children: items.map((item) => pw.Bullet(text: item)).toList(),
 ),
 pw.SizedBox(height: 12),
 ],
 );
 }

 Widget _buildSectionHeader({
 required IconData icon,
 required Color color,
 required String title,
 required String subtitle,
 required String actionLabel,
 required VoidCallback onAction,
 }) {
 return Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Container(
 width: 44,
 height: 44,
 decoration: BoxDecoration(
 color: color.withOpacity(0.12),
 borderRadius: BorderRadius.circular(14),
 border: Border.all(color: color.withOpacity(0.2)),
 ),
 child: Icon(icon, color: color, size: 22),
 ),
 const SizedBox(width: 12),
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(title,
 style: const TextStyle(
 fontSize: 16, fontWeight: FontWeight.w600)),
 const SizedBox(height: 4),
 Text(subtitle,
 style: TextStyle(fontSize: 12, color: Colors.grey[600])),
 ],
 ),
 ),
 OutlinedButton.icon(
 onPressed: onAction,
 icon: const Icon(Icons.add, size: 18),
 label: Text(actionLabel),
 style: OutlinedButton.styleFrom(
 foregroundColor: color,
 side: const BorderSide(color: Color(0xFFD6DCE8)),
 padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
 ),
 ),
 ],
 );
 }

 /// Wraps the table header in a horizontal scroll view so columns are
 /// never cramped, even on narrow viewports.
 Widget _buildScrollableTableHeader({required List<_TableColumn> columns}) {
 final contentWidth = columns.fold<double>(
 0.0,
 (sum, col) => sum + col.minWidth,
 ) +
 (columns.length - 1) * 10.0; // account for SizedBox(width:10) gaps

 return LayoutBuilder(
 builder: (context, constraints) {
 final targetWidth = contentWidth + 24;
 final tableWidth = constraints.maxWidth > targetWidth
 ? constraints.maxWidth
 : targetWidth;

 return SingleChildScrollView(
 scrollDirection: Axis.horizontal,
 child: SizedBox(
 width: tableWidth,
 child: _buildTableHeaderRow(columns: columns),
 ),
 );
 },
 );
 }

 double _tableWidthFor({
 required BoxConstraints constraints,
 required double contentWidth,
 }) {
 final targetWidth = contentWidth + 24;
 return constraints.maxWidth > targetWidth
 ? constraints.maxWidth
 : targetWidth;
 }

 Widget _buildTableScrollView({
 required double width,
 required Widget child,
 }) {
 return SingleChildScrollView(
 scrollDirection: Axis.horizontal,
 child: SizedBox(
 width: width,
 child: child,
 ),
 );
 }

 /// Wraps table rows in a horizontal scroll view matching the header.
 Widget _buildScrollableTableBody({
 required List<_TableColumn> columns,
 required int rowCount,
 required Widget Function(int index) rowBuilder,
 }) {
 final contentWidth = columns.fold<double>(
 0.0,
 (sum, col) => sum + col.minWidth,
 ) +
 (columns.length - 1) * 10.0;

 return LayoutBuilder(
 builder: (context, constraints) {
 return _buildTableScrollView(
 width: _tableWidthFor(
 constraints: constraints,
 contentWidth: contentWidth,
 ),
 child: Column(
 children: [
 for (int i = 0; i < rowCount; i++) ...[
 rowBuilder(i),
 if (i != rowCount - 1) const SizedBox(height: 8),
 ],
 ],
 ),
 );
 },
 );
 }

 Widget _buildTableHeaderRow({required List<_TableColumn> columns}) {
 return Container(
 padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
 decoration: BoxDecoration(
 color: const Color(0xFFF5F7FB),
 borderRadius: BorderRadius.circular(12),
 border: Border.all(color: const Color(0xFFE4E7EC)),
 ),
 child: Row(
 children: [
 for (int i = 0; i < columns.length; i++) ...[
 if (i > 0) const SizedBox(width: 10),
 SizedBox(
 width: columns[i].minWidth,
 child: Align(
 alignment: columns[i].alignment,
 child: Text(
 columns[i].label.toUpperCase(),
 style: const TextStyle(
 fontSize: 11,
 fontWeight: FontWeight.w700,
 letterSpacing: 0,
 color: Color(0xFF475467),
 ),
 
 ),
 ),
 ),
 ],
 ],
 ),
 );
 }

 Widget _buildConstraintRow(
 ConstraintRow row, {
 required int index,
 required bool isStriped,
 required List<String> ownerOptions,
 }) {
 final isEditing = _editingConstraintRows.contains(index);
 return Container(
 padding: const EdgeInsets.all(12),
 decoration: BoxDecoration(
 color: isStriped ? const Color(0xFFF9FAFC) : Colors.white,
 borderRadius: BorderRadius.circular(12),
 border: Border.all(color: const Color(0xFFE4E7EC)),
 ),
 child: Row(
 children: [
 SizedBox(
 width: 260,
 child: _buildTableField(
 initialValue: row.constraint,
 hintText: 'Constraint',
 enabled: _canEditAlignment && isEditing,
 onChanged: (value) {
 row.constraint = value;
 _scheduleSave();
 },
 ),
 ),
 const SizedBox(width: 10),
 SizedBox(
 width: 400,
 child: _buildTableField(
 initialValue: row.guardrail,
 hintText: 'Guardrail',
 maxLines: null,
 minLines: 1,
 enabled: _canEditAlignment && isEditing,
 onChanged: (value) {
 row.guardrail = value;
 _scheduleSave();
 },
 ),
 ),
 const SizedBox(width: 10),
 SizedBox(
 width: 150,
 child: _buildOwnerDropdown(
 value: row.owner,
 options: ownerOptions,
 enabled: _canEditAlignment && isEditing,
 onChanged: (value) {
 row.owner = value;
 _scheduleSave();
 },
 ),
 ),
 const SizedBox(width: 10),
 SizedBox(
 width: 140,
 child: _buildStatusDropdown(
 value: row.status,
 onChanged: (value) {
 setState(() => _constraints[index].status = value);
 _scheduleSave();
 },
 accent: const Color(0xFF1D4ED8),
 enabled: _canEditAlignment && isEditing,
 ),
 ),
 const SizedBox(width: 10),
 SizedBox(
 width: _technicalAlignmentActionColumnWidth,
 child: Align(
 alignment: Alignment.center,
 child: _buildRowActions(
 isEditing: isEditing,
 onToggleEdit: () =>
 _toggleEditingRow(_editingConstraintRows, index),
 onDelete: () async {
 final confirmed = await _confirmDelete('constraint');
 if (!confirmed) return;
 setState(() {
 _constraints.removeAt(index);
 _shiftEditingRowsAfterDelete(_editingConstraintRows, index);
 _scheduleSave();
 });
 },
 ),
 ),
 ),
 ],
 ),
 );
 }

 Widget _buildMappingRow(RequirementMappingRow row,
 {required int index, required bool isStriped}) {
 final isEditing = _editingMappingRows.contains(index);
 return Container(
 padding: const EdgeInsets.all(12),
 decoration: BoxDecoration(
 color: isStriped ? const Color(0xFFF9FAFC) : Colors.white,
 borderRadius: BorderRadius.circular(12),
 border: Border.all(color: const Color(0xFFE4E7EC)),
 ),
 child: Row(
 children: [
 SizedBox(
 width: 260,
 child: _buildTableField(
 initialValue: row.requirement,
 hintText: 'Requirement',
 enabled: _canEditAlignment && isEditing,
 onChanged: (value) {
 row.requirement = value;
 _scheduleSave();
 },
 ),
 ),
 const SizedBox(width: 10),
 SizedBox(
 width: 460,
 child: _buildTableField(
 initialValue: row.approach,
 hintText: 'Technical approach',
 maxLines: null,
 minLines: 1,
 enabled: _canEditAlignment && isEditing,
 onChanged: (value) {
 row.approach = value;
 _scheduleSave();
 },
 ),
 ),
 const SizedBox(width: 10),
 SizedBox(
 width: 140,
 child: _buildStatusDropdown(
 value: row.status,
 onChanged: (value) {
 setState(() => _mappings[index].status = value);
 _scheduleSave();
 },
 accent: const Color(0xFF0F766E),
 enabled: _canEditAlignment && isEditing,
 ),
 ),
 const SizedBox(width: 10),
 SizedBox(
 width: _technicalAlignmentActionColumnWidth,
 child: Align(
 alignment: Alignment.center,
 child: _buildRowActions(
 isEditing: isEditing,
 onToggleEdit: () =>
 _toggleEditingRow(_editingMappingRows, index),
 onDelete: () async {
 final confirmed = await _confirmDelete('mapping');
 if (!confirmed) return;
 setState(() {
 _mappings.removeAt(index);
 _shiftEditingRowsAfterDelete(_editingMappingRows, index);
 _scheduleSave();
 });
 },
 ),
 ),
 ),
 ],
 ),
 );
 }

 Widget _buildDependencyRow(
 DependencyDecisionRow row, {
 required int index,
 required bool isStriped,
 required List<String> ownerOptions,
 }) {
 final isEditing = _editingDependencyRows.contains(index);
 return Container(
 padding: const EdgeInsets.all(12),
 decoration: BoxDecoration(
 color: isStriped ? const Color(0xFFF9FAFC) : Colors.white,
 borderRadius: BorderRadius.circular(12),
 border: Border.all(color: const Color(0xFFE4E7EC)),
 ),
 child: Row(
 children: [
 SizedBox(
 width: 260,
 child: _buildTableField(
 initialValue: row.item,
 hintText: 'Dependency or decision',
 enabled: _canEditAlignment && isEditing,
 onChanged: (value) {
 row.item = value;
 _scheduleSave();
 },
 ),
 ),
 const SizedBox(width: 10),
 SizedBox(
 width: 380,
 child: _buildTableField(
 initialValue: row.detail,
 hintText: 'Detail',
 maxLines: null,
 minLines: 1,
 enabled: _canEditAlignment && isEditing,
 onChanged: (value) {
 row.detail = value;
 _scheduleSave();
 },
 ),
 ),
 const SizedBox(width: 10),
 SizedBox(
 width: 150,
 child: _buildOwnerDropdown(
 value: row.owner,
 options: ownerOptions,
 enabled: _canEditAlignment && isEditing,
 onChanged: (value) {
 row.owner = value;
 _scheduleSave();
 },
 ),
 ),
 const SizedBox(width: 10),
 SizedBox(
 width: 140,
 child: _buildStatusDropdown(
 value: row.status,
 onChanged: (value) {
 setState(() => _dependencies[index].status = value);
 _scheduleSave();
 },
 accent: const Color(0xFF9333EA),
 enabled: _canEditAlignment && isEditing,
 ),
 ),
 const SizedBox(width: 10),
 SizedBox(
 width: _technicalAlignmentActionColumnWidth,
 child: Align(
 alignment: Alignment.center,
 child: _buildRowActions(
 isEditing: isEditing,
 onToggleEdit: () =>
 _toggleEditingRow(_editingDependencyRows, index),
 onDelete: () async {
 final confirmed = await _confirmDelete('dependency');
 if (!confirmed) return;
 setState(() {
 _dependencies.removeAt(index);
 _shiftEditingRowsAfterDelete(_editingDependencyRows, index);
 _scheduleSave();
 });
 },
 ),
 ),
 ),
 ],
 ),
 );
 }

 Widget _buildTableField({
 required String initialValue,
 required String hintText,
 int? maxLines,
 int minLines = 1,
 bool enabled = true,
 ValueChanged<String>? onChanged,
 }) {
 return VoiceTextFormField(
 initialValue: initialValue,
 enabled: enabled,
 minLines: minLines,
 maxLines: maxLines,
 textAlignVertical: TextAlignVertical.center,
 textAlign: TextAlign.center,
 keyboardType: TextInputType.multiline,
 style: TextStyle(
 fontSize: 14,
 color: enabled ? const Color(0xFF1F2937) : const Color(0xFF475569),
 ),
 onChanged: onChanged,
 decoration: InputDecoration(
 hintText: hintText,
 hintStyle: TextStyle(fontSize: 13, color: Colors.grey[500]),
 isDense: true,
 filled: true,
 fillColor: enabled ? Colors.white : const Color(0xFFF8FAFC),
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
 disabledBorder: OutlineInputBorder(
 borderRadius: BorderRadius.circular(10),
 borderSide: const BorderSide(color: Color(0xFFE4E7EC)),
 ),
 focusedBorder: OutlineInputBorder(
 borderRadius: BorderRadius.circular(10),
 borderSide: const BorderSide(color: Color(0xFF1D4ED8), width: 2),
 ),
 ),
 );
 }

 Widget _buildStatusDropdown({
 required String value,
 required ValueChanged<String> onChanged,
 required Color accent,
 bool enabled = true,
 }) {
 final normalized = value.trim();
 final items = normalized.isEmpty || _statusOptions.contains(normalized)
 ? _statusOptions
 : [normalized, ..._statusOptions];
 return DropdownButtonFormField<String>(
 value: normalized.isEmpty ? items.first : normalized,
 alignment: Alignment.center,
 isExpanded: true,
 style: const TextStyle(fontSize: 14, color: Color(0xFF1F2937)),
 selectedItemBuilder: (context) => items
 .map((status) => Align(
 alignment: Alignment.center,
 child: Text(status, textAlign: TextAlign.center),
 ))
 .toList(),
 items: items
 .map((status) => DropdownMenuItem(
 value: status,
 child: Center(child: Text(status, textAlign: TextAlign.center)),
 ))
 .toList(),
 onChanged: enabled
 ? (newValue) {
 if (newValue == null) return;
 onChanged(newValue);
 }
 : null,
 decoration: InputDecoration(
 isDense: true,
 filled: true,
 fillColor: Colors.white,
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
 borderSide: BorderSide(color: accent, width: 2),
 ),
 ),
 );
 }

 Widget _buildOwnerDropdown({
 required String value,
 required List<String> options,
 required ValueChanged<String> onChanged,
 bool enabled = true,
 }) {
 final normalized = value.trim();
 final items = normalized.isEmpty || options.contains(normalized)
 ? options
 : [normalized, ...options];
 return DropdownButtonFormField<String>(
 value: normalized.isEmpty ? items.first : normalized,
 alignment: Alignment.center,
 isExpanded: true,
 style: const TextStyle(fontSize: 14, color: Color(0xFF1F2937)),
 selectedItemBuilder: (context) => items
 .map((owner) => Align(
 alignment: Alignment.center,
 child: Text(owner, textAlign: TextAlign.center),
 ))
 .toList(),
 items: items
 .map((owner) => DropdownMenuItem(
 value: owner,
 child: Center(child: Text(owner, textAlign: TextAlign.center)),
 ))
 .toList(),
 onChanged: enabled
 ? (newValue) {
 if (newValue == null) return;
 onChanged(newValue);
 }
 : null,
 decoration: InputDecoration(
 isDense: true,
 filled: true,
 fillColor: Colors.white,
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
 borderSide: const BorderSide(color: Color(0xFF1D4ED8), width: 2),
 ),
 ),
 );
 }

 Widget _buildRowActions({
 required bool isEditing,
 required VoidCallback onToggleEdit,
 required Future<void> Function() onDelete,
 }) {
 return Row(
 mainAxisSize: MainAxisSize.min,
 mainAxisAlignment: MainAxisAlignment.center,
 children: [
 _buildActionIconButton(
 tooltip: isEditing ? 'Save changes' : 'Edit',
 icon: isEditing
 ? Icons.check_circle_outline_rounded
 : Icons.edit_outlined,
 color: isEditing ? const Color(0xFF059669) : const Color(0xFF2563EB),
 onPressed: _canEditAlignment ? onToggleEdit : null,
 ),
 const SizedBox(width: _technicalAlignmentActionGap),
 _buildActionIconButton(
 tooltip: 'Delete',
 icon: Icons.delete_outline,
 color: const Color(0xFFB91C1C),
 onPressed: _canDeleteAlignment
 ? () async {
 await onDelete();
 }
 : null,
 ),
 IconButton(
   onPressed: () {
     ScaffoldMessenger.of(context).showSnackBar(
       const SnackBar(content: Text('KAZ AI: Generating suggestions...'), duration: Duration(seconds: 2)),
     );
   },
   icon: const Icon(Icons.auto_awesome, size: 16, color: Color(0xFFF59E0B)),
   tooltip: 'KAZ AI',
   padding: EdgeInsets.zero,
   constraints: const BoxConstraints(minWidth: 28),
 ),
 ],
 );
 }

 Widget _buildActionIconButton({
 required String tooltip,
 required IconData icon,
 required Color color,
 required VoidCallback? onPressed,
 }) {
 return Tooltip(
 message: tooltip,
 waitDuration: const Duration(milliseconds: 350),
 child: SizedBox.square(
 dimension: _technicalAlignmentActionButtonSize,
 child: Material(
 color: Colors.transparent,
 borderRadius: BorderRadius.circular(8),
 child: InkWell(
 onTap: onPressed,
 borderRadius: BorderRadius.circular(8),
 child: Icon(
 icon,
 size: 18,
 color: onPressed == null ? const Color(0xFFCBD5E1) : color,
 ),
 ),
 ),
 ),
 );
 }

 Widget _buildBottomNavigation(bool isMobile) {
 const accent = LightModeColors.lightPrimary;
 const onAccent = Colors.white;

 if (isMobile) {
 return Column(
 crossAxisAlignment: CrossAxisAlignment.stretch,
 children: [
 OutlinedButton.icon(
 onPressed: _navigateToRequirementsImplementation,
 icon: const Icon(Icons.arrow_back, size: 18),
 label: const Text('Back: Requirements Implementation'),
 style: OutlinedButton.styleFrom(
 backgroundColor: accent,
 foregroundColor: onAccent,
 side: const BorderSide(color: accent),
 padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
 shape: RoundedRectangleBorder(
 borderRadius: BorderRadius.circular(20)),
 ),
 ),
 const SizedBox(height: 12),
 ElevatedButton.icon(
 onPressed: _navigateToDevelopmentSetUp,
 icon: const Icon(Icons.arrow_forward, size: 18),
 label: const Text('Next: Development Set Up'),
 style: ElevatedButton.styleFrom(
 backgroundColor: accent,
 foregroundColor: onAccent,
 padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
 shape: RoundedRectangleBorder(
 borderRadius: BorderRadius.circular(20)),
 elevation: 0,
 ),
 ),
 ],
 );
 }

 return Row(
 children: [
 OutlinedButton.icon(
 onPressed: _navigateToRequirementsImplementation,
 icon: const Icon(Icons.arrow_back, size: 18),
 label: const Text('Back: Requirements Implementation'),
 style: OutlinedButton.styleFrom(
 backgroundColor: accent,
 foregroundColor: onAccent,
 side: const BorderSide(color: accent),
 padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
 shape:
 RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
 ),
 ),
 const SizedBox(width: 16),
 Text(
 'Design phase | Technical Alignment',
 style: TextStyle(fontSize: 13, color: Colors.grey[600]),
 ),
 const Spacer(),
 ElevatedButton.icon(
 onPressed: _navigateToDevelopmentSetUp,
 icon: const Icon(Icons.arrow_forward, size: 18),
 label: const Text('Next: Development Set Up'),
 style: ElevatedButton.styleFrom(
 backgroundColor: accent,
 foregroundColor: onAccent,
 padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
 shape:
 RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
 elevation: 0,
 ),
 ),
 ],
 );
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

 Widget _buildEmptyTableState({
 required String message,
 required String actionLabel,
 required VoidCallback onAction,
 }) {
 return Container(
 padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
 decoration: BoxDecoration(
 color: const Color(0xFFF8FAFC),
 borderRadius: BorderRadius.circular(12),
 border: Border.all(color: const Color(0xFFE4E7EC)),
 ),
 child: Row(
 children: [
 Expanded(
 child: Text(
 message,
 style: TextStyle(fontSize: 12, color: Colors.grey[600]),
 ),
 ),
 OutlinedButton(
 onPressed: onAction,
 style: OutlinedButton.styleFrom(
 foregroundColor: const Color(0xFF1A1D1F),
 side: const BorderSide(color: Color(0xFFD6DCE8)),
 padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
 ),
 child: Text(actionLabel),
 ),
 ],
 ),
 );
 }

 Future<void> _exportPdf() async {
 final projectData = ProjectDataHelper.getData(context);
 await PdfExportHelper.exportScreenPdf(
 context: context,
 screenTitle: 'Technical Alignment',
 sections: [
 PdfSection.keyValue('Project Info', [
 {'Project Name': projectData.projectName ?? 'N/A'},
 {'Solution Title': projectData.solutionTitle ?? 'N/A'},
 ]),
 PdfSection.text('Notes', projectData.planningNotes['planning_technical_alignment_notes'] ?? 'No data recorded.'),
 ],
 );
 }
}

class _TechnicalAlignmentDashboardSnapshot {
 const _TechnicalAlignmentDashboardSnapshot({
 required this.projectLabel,
 required this.feasibilityItems,
 required this.legacyItems,
 required this.compatibilityRows,
 required this.integrationNodes,
 required this.performanceItems,
 required this.migrationLanes,
 required this.protocols,
 required this.debtItems,
 required this.aiSignalCount,
 });

 final String projectLabel;
 final List<_FeasibilityItem> feasibilityItems;
 final List<_LegacyImpact> legacyItems;
 final List<_CompatibilityRow> compatibilityRows;
 final List<_IntegrationNode> integrationNodes;
 final List<_PerformanceItem> performanceItems;
 final List<_MigrationLane> migrationLanes;
 final List<_ProtocolItem> protocols;
 final List<_DebtDashboardItem> debtItems;
 final int aiSignalCount;

 int get highFeasibilityCount =>
 feasibilityItems.where((item) => item.score == 'High').length;
 int get compatibilityGapCount =>
 compatibilityRows.where((item) => item.gapLabel != 'Compatible').length;
 int get pendingIntegrationCount =>
 integrationNodes.where((item) => item.status == 'Pending').length;
 int get alignedProtocolCount =>
 protocols.where((item) => item.status == 'Aligned').length;

 factory _TechnicalAlignmentDashboardSnapshot.from({
 required ProjectDataModel projectData,
 required String notes,
 required List<ConstraintRow> constraints,
 required List<RequirementMappingRow> mappings,
 required List<DependencyDecisionRow> dependencies,
 }) {
 final projectLabel = projectData.projectName.trim().isNotEmpty
 ? projectData.projectName.trim()
 : 'the current design package';
 final techNames = _extractNamedValues(projectData.technologyDefinitions);
 final inventoryNames = _extractNamedValues(projectData.technologyInventory);
 final itData = projectData.itConsiderationsData;
 final infraData = projectData.infrastructureConsiderationsData;
 final noteText = notes.toLowerCase();
 final constraintText = constraints
 .map((row) => '${row.constraint} ${row.guardrail}'.toLowerCase())
 .join(' ');
 final dependencyText = dependencies
 .map((row) => '${row.item} ${row.detail}'.toLowerCase())
 .join(' ');
 final debtRegister = projectData.frontEndPlanningData.technicalDebtItems
 .where((item) => item.title.trim().isNotEmpty)
 .toList();
 final securitySettings = projectData.frontEndPlanningData.securitySettings
 .where((item) => item.key.trim().isNotEmpty)
 .toList();

 final feasibilityItems = mappings
 .where((row) => row.requirement.trim().isNotEmpty)
 .take(4)
 .toList()
 .asMap()
 .entries
 .map((entry) {
 final row = entry.value;
 final matchedConstraint = constraints.isNotEmpty
 ? constraints[entry.key % constraints.length]
 : null;
 final constraintLabel = matchedConstraint == null
 ? 'Constraint path still needs definition.'
 : matchedConstraint.constraint.trim().isNotEmpty
 ? matchedConstraint.constraint.trim()
 : matchedConstraint.guardrail.trim();
 return _FeasibilityItem(
 feature: row.requirement.trim(),
 score: _scoreFromStatus(row.status),
 constraint: constraintLabel,
 note: row.approach.trim(),
 );
 }).toList();

 const feasibilityDefaults = [
 _FeasibilityItem(
 feature: 'Live guest check-in and validation',
 score: 'High',
 constraint: 'Payment gateway latency and queue recovery rules.',
 note: 'Cloud validation plus offline fallback queue.',
 ),
 _FeasibilityItem(
 feature: 'Sponsor banner and print distribution',
 score: 'Medium',
 constraint: 'Historic venue mounting rules and print approval cycles.',
 note: 'Versioned artwork plus sign-off checkpoints.',
 ),
 _FeasibilityItem(
 feature: 'Venue occupancy and HVAC visibility',
 score: 'Low',
 constraint: 'BMS access, polling frequency, and safety ownership.',
 note: 'Ops dashboard depends on venue system connectivity.',
 ),
 _FeasibilityItem(
 feature: 'Floor-plan wayfinding package',
 score: 'Medium',
 constraint: 'Material weight, egress clearance, and install windows.',
 note: 'CAD cleanup and signage legend control.',
 ),
 ];
 for (final item in feasibilityDefaults) {
 if (feasibilityItems.length >= 4) break;
 feasibilityItems.add(item);
 }

 final legacyItems = <_LegacyImpact>[
 _LegacyImpact(
 component: techNames.firstWhere(
 (value) => value.toLowerCase().contains('erp'),
 orElse: () => 'Old ERP',
 ),
 impact:
 'Nightly or batched sync behaviour limits how “real-time” the design can appear without an adapter layer.',
 severity: 'High',
 ),
 _LegacyImpact(
 component: _containsAny(
 '${infraData?.notes ?? ''} ${infraData?.physicalSpaceRequirements ?? ''}',
 ['historic', 'heritage', 'building', 'venue'],
 )
 ? 'Historic Building Fabric'
 : 'Venue Installation Rules',
 impact:
 'Mounting, cabling, and banner placement must avoid invasive fixing points and protect emergency routes.',
 severity: 'High',
 ),
 _LegacyImpact(
 component: inventoryNames.isNotEmpty
 ? inventoryNames.first
 : 'Venue Power Distribution',
 impact:
 'Large displays, registration desks, and lighting cues compete for limited power and fallback capacity.',
 severity: 'Medium',
 ),
 ];

 final hasSoftware = techNames.isNotEmpty ||
 (itData?.softwareRequirements.trim().isNotEmpty ?? false);
 final hasConnectivity =
 (infraData?.connectivityRequirements.trim().isNotEmpty ?? false) ||
 _containsAny(
 '$constraintText $noteText', ['wifi', 'network', 'connect']);
 final hasPower = (infraData?.powerCoolingRequirements.trim().isNotEmpty ??
 false) ||
 _containsAny('$constraintText $dependencyText', ['power', 'cooling']);
 final hasPhysical =
 (infraData?.physicalSpaceRequirements.trim().isNotEmpty ?? false) ||
 _containsAny('$constraintText $dependencyText',
 ['venue', 'load', 'rigging', 'material']);

 final compatibilityRows = [
 _CompatibilityRow(
 requirement: 'Cloud and API throughput',
 available: hasSoftware
 ? (itData?.softwareRequirements.trim().isNotEmpty ?? false)
 ? itData!.softwareRequirements.trim()
 : techNames.take(2).join(', ')
 : 'No confirmed adapter or software baseline captured.',
 gapLabel: hasSoftware ? 'Compatible' : 'Gap',
 gapColor:
 hasSoftware ? AppSemanticColors.success : const Color(0xFFDC2626),
 ),
 _CompatibilityRow(
 requirement: 'Venue network and Wi-Fi coverage',
 available: hasConnectivity
 ? (infraData?.connectivityRequirements.trim().isNotEmpty ?? false)
 ? infraData!.connectivityRequirements.trim()
 : 'Site Wi-Fi zones plus LTE fallback planning.'
 : 'Coverage validation still pending for critical touchpoints.',
 gapLabel: hasConnectivity ? 'Compatible' : 'Partial Gap',
 gapColor: hasConnectivity
 ? AppSemanticColors.success
 : AppSemanticColors.warning,
 ),
 _CompatibilityRow(
 requirement: 'Power and cooling resilience',
 available: hasPower
 ? (infraData?.powerCoolingRequirements.trim().isNotEmpty ?? false)
 ? infraData!.powerCoolingRequirements.trim()
 : 'Venue mains and staged equipment load plan.'
 : 'Power draw and cooling assumptions are not yet confirmed.',
 gapLabel: hasPower ? 'Compatible' : 'Gap',
 gapColor:
 hasPower ? AppSemanticColors.success : const Color(0xFFDC2626),
 ),
 _CompatibilityRow(
 requirement: 'Material load and install conditions',
 available: hasPhysical
 ? (infraData?.physicalSpaceRequirements.trim().isNotEmpty ?? false)
 ? infraData!.physicalSpaceRequirements.trim()
 : 'Non-invasive install guidance with egress clearance checks.'
 : 'Physical constraints need review with venue and safety teams.',
 gapLabel: hasPhysical ? 'Compatible' : 'Partial Gap',
 gapColor:
 hasPhysical ? AppSemanticColors.success : AppSemanticColors.warning,
 ),
 ];

 final integrationCandidates = <String>[
 ...techNames.take(2),
 ...dependencies
 .map((item) => item.item.trim())
 .where((value) => value.isNotEmpty)
 .take(3),
 'Payment Gateway',
 'Venue HVAC',
 'Analytics Cloud',
 ];
 final integrationNodes = <_IntegrationNode>[];
 final seenNames = <String>{};
 for (final candidate in integrationCandidates) {
 final normalized = candidate.trim();
 if (normalized.isEmpty) continue;
 if (!seenNames.add(normalized.toLowerCase())) continue;
 final matchingDependency =
 dependencies.cast<DependencyDecisionRow?>().firstWhere(
 (row) =>
 row != null &&
 '${row.item} ${row.detail}'.toLowerCase().contains(
 normalized.toLowerCase(),
 ),
 orElse: () => null,
 );
 final pending = matchingDependency != null &&
 (matchingDependency.status == 'Pending' ||
 matchingDependency.status == 'Draft');
 integrationNodes.add(
 _IntegrationNode(
 name: normalized,
 status: pending ? 'Pending' : 'Connected',
 ),
 );
 if (integrationNodes.length >= 5) break;
 }

 final performanceItems = [
 const _PerformanceItem(
 'API Latency', '< 250ms P95', '420ms through legacy adapter'),
 const _PerformanceItem('Concurrent Sessions', '10,000 guests',
 '7,500 on current cloud tier'),
 const _PerformanceItem('Foot Traffic', '1,200 pax/hour',
 '900 pax/hour without queue redesign'),
 const _PerformanceItem('Material Weight', '<= 35kg per fix point',
 '28kg approved banner assembly'),
 ];

 final migrationLanes = [
 _MigrationLane(
 source: techNames.isNotEmpty
 ? '${techNames.first} export'
 : 'Old ERP export',
 transformation:
 'Normalize IDs, cleanse duplicates, and map event codes',
 destination: 'Registration and reporting services',
 ),
 const _MigrationLane(
 source: 'Historic CAD floor plan',
 transformation: 'Layer cleanup, zoning, and wayfinding annotation',
 destination: 'Venue navigation package PDF',
 ),
 const _MigrationLane(
 source: 'Venue BMS / HVAC feed',
 transformation: 'Status mapping, polling cache, and alert thresholds',
 destination: 'Ops dashboard and safety alerts',
 ),
 ];

 final protocols = [
 _ProtocolItem(
 name: 'GDPR',
 detail:
 'Retention, consent, and personal-data handling for attendee flows.',
 status: _containsAny(
 '$constraintText ${projectData.frontEndPlanningData.security}'
 .toLowerCase(),
 ['gdpr', 'privacy', 'retention', 'consent']) ||
 securitySettings.isNotEmpty
 ? 'Aligned'
 : 'Review Needed',
 ),
 _ProtocolItem(
 name: 'API Authentication',
 detail:
 'Token scope, service credentials, and secure system-to-system access.',
 status: _containsAny(
 '$constraintText $dependencyText ${projectData.frontEndPlanningData.security}'
 .toLowerCase(),
 ['auth', 'token', 'security', 'api'])
 ? 'Aligned'
 : 'Review Needed',
 ),
 _ProtocolItem(
 name: 'Fire Safety',
 detail:
 'Egress, visibility, and emergency clearance around displays and banners.',
 status: hasPhysical ? 'Aligned' : 'Gap',
 ),
 _ProtocolItem(
 name: 'Material Certification',
 detail:
 'Rigging, substrate, and print material sign-off before install.',
 status: _containsAny('$dependencyText $constraintText',
 ['rigging', 'material', 'safety'])
 ? 'Review Needed'
 : 'Gap',
 ),
 ];

 final debtItems = debtRegister.isNotEmpty
 ? debtRegister.take(4).map((item) {
 final workaround = item.target.trim().isNotEmpty
 ? item.target.trim()
 : 'Temporary workaround routed through ${item.area.trim().isNotEmpty ? item.area.trim() : 'manual review'} until a permanent fix lands.';
 return _DebtDashboardItem(
 issue: item.title.trim(),
 workaround: workaround,
 owner: item.owner.trim().isNotEmpty
 ? item.owner.trim()
 : 'Engineering',
 severity: item.severity.trim().isNotEmpty
 ? item.severity.trim()
 : 'Medium',
 );
 }).toList()
 : [
 const _DebtDashboardItem(
 issue: 'Legacy ERP sync is not real-time',
 workaround:
 'Use a staged refresh banner and manual exception queue during peak registration windows.',
 owner: 'Integration',
 severity: 'High',
 ),
 const _DebtDashboardItem(
 issue: 'Venue HVAC feed is not confirmed',
 workaround:
 'Expose placeholder capacity states until BMS access is approved.',
 owner: 'Venue Tech',
 severity: 'Medium',
 ),
 const _DebtDashboardItem(
 issue: 'Rigging rules are still pending',
 workaround:
 'Constrain concepts to lightweight banner modules and non-invasive signage options.',
 owner: 'Safety',
 severity: 'Medium',
 ),
 ];

 final aiSignalCount = projectData.aiUsageCounts.values.fold<int>(
 0,
 (total, value) => total + value,
 ) +
 projectData.aiRecommendations.length +
 projectData.aiIntegrations.length;

 return _TechnicalAlignmentDashboardSnapshot(
 projectLabel: projectLabel,
 feasibilityItems: feasibilityItems,
 legacyItems: legacyItems,
 compatibilityRows: compatibilityRows,
 integrationNodes: integrationNodes,
 performanceItems: performanceItems,
 migrationLanes: migrationLanes,
 protocols: protocols,
 debtItems: debtItems,
 aiSignalCount: aiSignalCount,
 );
 }

 static List<String> _extractNamedValues(List<Map<String, dynamic>> records) {
 final seen = <String>{};
 final values = <String>[];
 for (final record in records) {
 final value = _firstText(record, const [
 'name',
 'title',
 'technology',
 'system',
 'label',
 'tool',
 ]);
 if (value.isEmpty) continue;
 if (seen.add(value.toLowerCase())) {
 values.add(value);
 }
 }
 return values;
 }

 static String _firstText(Map<String, dynamic> record, List<String> keys) {
 for (final key in keys) {
 final value = record[key]?.toString().trim() ?? '';
 if (value.isNotEmpty) return value;
 }
 return '';
 }

 static bool _containsAny(String source, List<String> needles) {
 for (final needle in needles) {
 if (source.contains(needle)) return true;
 }
 return false;
 }

 static String _scoreFromStatus(String status) {
 switch (status) {
 case 'Approved':
 case 'Aligned':
 case 'Ready':
 return 'High';
 case 'In review':
 return 'Medium';
 default:
 return 'Low';
 }
 }
}

class _FeasibilityItem {
 const _FeasibilityItem({
 required this.feature,
 required this.score,
 required this.constraint,
 required this.note,
 });

 final String feature;
 final String score;
 final String constraint;
 final String note;
}

class _LegacyImpact {
 const _LegacyImpact({
 required this.component,
 required this.impact,
 required this.severity,
 });

 final String component;
 final String impact;
 final String severity;
}

class _CompatibilityRow {
 const _CompatibilityRow({
 required this.requirement,
 required this.available,
 required this.gapLabel,
 required this.gapColor,
 });

 final String requirement;
 final String available;
 final String gapLabel;
 final Color gapColor;
}

class _IntegrationNode {
 const _IntegrationNode({
 required this.name,
 required this.status,
 });

 final String name;
 final String status;
}

class _PerformanceItem {
 const _PerformanceItem(this.metric, this.targetValue, this.currentCapacity);

 final String metric;
 final String targetValue;
 final String currentCapacity;
}

class _MigrationLane {
 const _MigrationLane({
 required this.source,
 required this.transformation,
 required this.destination,
 });

 final String source;
 final String transformation;
 final String destination;
}

class _ProtocolItem {
 const _ProtocolItem({
 required this.name,
 required this.detail,
 required this.status,
 });

 final String name;
 final String detail;
 final String status;
}

class _DebtDashboardItem {
 const _DebtDashboardItem({
 required this.issue,
 required this.workaround,
 required this.owner,
 required this.severity,
 });

 final String issue;
 final String workaround;
 final String owner;
 final String severity;
}

class _MethodologyStandard {
 _MethodologyStandard({
 required this.model,
 required this.bestFit,
 required this.evidence,
 required this.controls,
 required this.exitStandard,
 });

 String model;
 String bestFit;
 String evidence;
 String controls;
 String exitStandard;

 factory _MethodologyStandard.fromMap(Map<String, dynamic> m) =>
 _MethodologyStandard(
 model: m['model'] ?? '',
 bestFit: m['bestFit'] ?? '',
 evidence: m['evidence'] ?? '',
 controls: m['controls'] ?? '',
 exitStandard: m['exitStandard'] ?? '',
 );

 Map<String, dynamic> toMap() => {
 'model': model,
 'bestFit': bestFit,
 'evidence': evidence,
 'controls': controls,
 'exitStandard': exitStandard,
 };
}

class _ReadinessGateItem {
 _ReadinessGateItem({
 required this.domain,
 required this.standard,
 required this.evidence,
 required this.owner,
 required this.decision,
 });

 String domain;
 String standard;
 String evidence;
 String owner;
 String decision;

 factory _ReadinessGateItem.fromMap(Map<String, dynamic> m) =>
 _ReadinessGateItem(
 domain: m['domain'] ?? '',
 standard: m['standard'] ?? '',
 evidence: m['evidence'] ?? '',
 owner: m['owner'] ?? '',
 decision: m['decision'] ?? '',
 );

 Map<String, dynamic> toMap() => {
 'domain': domain,
 'standard': standard,
 'evidence': evidence,
 'owner': owner,
 'decision': decision,
 };
}

class _TraceabilityItem {
 _TraceabilityItem({
 required this.object,
 required this.question,
 required this.verification,
 required this.waterfallEvidence,
 required this.agileEvidence,
 });

 String object;
 String question;
 String verification;
 String waterfallEvidence;
 String agileEvidence;

 factory _TraceabilityItem.fromMap(Map<String, dynamic> m) =>
 _TraceabilityItem(
 object: m['object'] ?? '',
 question: m['question'] ?? '',
 verification: m['verification'] ?? '',
 waterfallEvidence: m['waterfallEvidence'] ?? '',
 agileEvidence: m['agileEvidence'] ?? '',
 );

 Map<String, dynamic> toMap() => {
 'object': object,
 'question': question,
 'verification': verification,
 'waterfallEvidence': waterfallEvidence,
 'agileEvidence': agileEvidence,
 };
}

List<_MethodologyStandard> _defaultMethodologyStandards() => [
 _MethodologyStandard(
 model: 'Waterfall / Predictive',
 bestFit:
 'Stable scope, high compliance burden, contractual acceptance, capital approval, or regulated delivery.',
 evidence:
 'Signed requirements baseline, architecture views, interface specifications, verification matrix, risk register, change-control log, and stage-gate sign-off.',
 controls:
 'Configuration management, formal traceability, design reviews, quality plans, procurement lead times, security and safety approval, and acceptance test readiness.',
 exitStandard:
 'No unresolved critical requirements, interfaces, or compliance obligations before detailed design/build gate.',
 ),
 _MethodologyStandard(
 model: 'Agile Scrum',
 bestFit:
 'Evolving product scope where frequent inspection, user feedback, and working increments reduce uncertainty.',
 evidence:
 'Product goal, ordered backlog, refined epics/stories, Definition of Ready, Definition of Done, sprint review evidence, test automation, and release criteria.',
 controls:
 'Backlog quality, technical spikes, architecture runway, automated quality gates, security-by-design checks, observable increments, and dependency escalation.',
 exitStandard:
 'Stories are ready, technically feasible, testable, sized, and linked to acceptance criteria before sprint commitment.',
 ),
 _MethodologyStandard(
 model: 'Kanban / Flow',
 bestFit:
 'Operational, support, enhancement, integration, or continuous improvement work with variable demand.',
 evidence:
 'Service policies, classes of service, WIP limits, intake rules, flow metrics, blocker aging, technical debt register, and release readiness checklist.',
 controls:
 'Cycle-time predictability, dependency visibility, operational risk limits, explicit pull criteria, reversible release practices, and incident feedback loops.',
 exitStandard:
 'Work items meet explicit policies, have no hidden technical blockers, and can move without breaching WIP or service-risk limits.',
 ),
 _MethodologyStandard(
 model: 'Hybrid',
 bestFit:
 'Fixed governance, budget, procurement, or compliance boundaries with iterative product/design elaboration inside phases.',
 evidence:
 'Phase baseline, rolling-wave plan, integrated roadmap, dependency board, decision log, release plan, backlog traceability, and formal change approvals.',
 controls:
 'Gate-to-increment traceability, change impact analysis, milestone dependency management, release train alignment, and shared acceptance evidence.',
 exitStandard:
 'Governance artifacts stay controlled while iterative increments prove feasibility and reduce delivery uncertainty.',
 ),
 _MethodologyStandard(
 model: 'Scaled Agile / Portfolio',
 bestFit:
 'Multiple teams, shared platforms, enterprise architecture constraints, high dependency density, or portfolio funding.',
 evidence:
 'Capability map, architectural runway, program board, enabler backlog, PI objectives, dependency map, NFRs, risk ROAM, and system demo outcomes.',
 controls:
 'Platform standards, cross-team interface contracts, release train synchronization, enabler capacity, observability standards, and enterprise risk governance.',
 exitStandard:
 'Teams share the same technical baseline, dependencies are owned, and runway exists for committed business features.',
 ),
 ];

List<_ReadinessGateItem> _defaultReadinessGateItems() => [
 _ReadinessGateItem(
 domain: 'Architecture Baseline',
 standard:
 'Target architecture, transition states, major technology decisions, constraints, and trade-offs are explicit and approved.',
 evidence:
 'Architecture diagrams, ADRs, options analysis, assumptions log, and impacted components list.',
 owner: 'Architecture',
 decision: 'Conditional',
 ),
 _ReadinessGateItem(
 domain: 'Requirements Traceability',
 standard:
 'Every priority requirement has a technical approach, acceptance criteria, verification method, and owner.',
 evidence:
 'Traceability matrix, backlog links, acceptance criteria, test strategy, and sign-off record.',
 owner: 'BA / PO',
 decision: 'Go',
 ),
 _ReadinessGateItem(
 domain: 'Non-Functional Requirements',
 standard:
 'Performance, availability, security, privacy, accessibility, scalability, resilience, and recovery targets are measurable.',
 evidence:
 'NFR catalogue, SLO/SLA targets, threat model, capacity model, accessibility checklist, and recovery objectives.',
 owner: 'Engineering',
 decision: 'Conditional',
 ),
 _ReadinessGateItem(
 domain: 'Interfaces And Data',
 standard:
 'Inbound and outbound contracts define schemas, protocols, ownership, quality controls, environments, and failure behaviour.',
 evidence:
 'API specs, ICDs, data dictionary, sample payloads, test stubs, privacy review, and vendor SLA notes.',
 owner: 'Integration',
 decision: 'Conditional',
 ),
 _ReadinessGateItem(
 domain: 'Delivery And Release',
 standard:
 'Build path, environments, CI/CD, rollback, deployment approvals, release calendar, and operational handover are known.',
 evidence:
 'Environment plan, release checklist, branching strategy, deployment runbook, monitoring plan, and support model.',
 owner: 'DevOps',
 decision: 'No-go',
 ),
 ];

List<_TraceabilityItem> _defaultTraceabilityItems() => [
 _TraceabilityItem(
 object: 'Business Requirement',
 question:
 'Does the selected technical approach preserve the intended business outcome and contractual acceptance condition?',
 verification:
 'Review against acceptance criteria, business rules, and benefit metrics.',
 waterfallEvidence:
 'Signed requirements baseline and V-model test mapping.',
 agileEvidence:
 'Epic/story links, acceptance tests, and sprint review evidence.',
 ),
 _TraceabilityItem(
 object: 'Architecture Decision',
 question:
 'Is the decision justified, reversible where possible, and connected to risks, constraints, and alternatives?',
 verification:
 'ADR review, options analysis, and risk impact assessment.',
 waterfallEvidence:
 'Architecture review board minutes and design baseline.',
 agileEvidence:
 'ADR in repository, enabler story, and team review record.',
 ),
 _TraceabilityItem(
 object: 'Interface / Dependency',
 question:
 'Are data contracts, service expectations, ownership, environments, and failure paths clear enough for build?',
 verification:
 'Contract testing, mock service validation, vendor confirmation, and dependency burn-down.',
 waterfallEvidence:
 'Interface control document and formal dependency sign-off.',
 agileEvidence:
 'Dependency board, API contract tests, and integration demo.',
 ),
 _TraceabilityItem(
 object: 'Non-Functional Requirement',
 question:
 'Can the system prove security, performance, accessibility, reliability, observability, and recovery standards?',
 verification:
 'Automated tests, threat modelling, load testing, accessibility checks, monitoring trials, and recovery exercises.',
 waterfallEvidence:
 'Quality plan, test scripts, and readiness gate evidence.',
 agileEvidence:
 'Definition of Done controls, pipeline gates, and system demo metrics.',
 ),
 _TraceabilityItem(
 object: 'Operational Readiness',
 question:
 'Can support teams operate, monitor, recover, and improve the solution after release?',
 verification:
 'Runbook review, support rehearsal, incident workflow check, and service transition acceptance.',
 waterfallEvidence: 'Operational acceptance test and handover sign-off.',
 agileEvidence:
 'Release checklist, support story completion, and production telemetry review.',
 ),
 ];

class _TableColumn {
 const _TableColumn({
 required this.label,
 this.flex = 1,
 this.minWidth = 100.0,
 this.alignment = Alignment.center,
 });

 final String label;
 final int flex;
 final double minWidth;
 final Alignment alignment;
}

/// Panel shell matching the Vendor Tracking "Action plan" style.
class _DeliveryModelPanelShell extends StatelessWidget {
 const _DeliveryModelPanelShell({
 required this.title,
 required this.subtitle,
 required this.icon,
 required this.accent,
 required this.child,
 this.trailing,
 });

 final String title;
 final String subtitle;
 final IconData icon;
 final Color accent;
 final Widget child;
 final Widget? trailing;

 @override
 Widget build(BuildContext context) {
 return Container(
 padding: const EdgeInsets.all(20),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(16),
 border: Border.all(color: const Color(0xFFE2E8F0)),
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.stretch,
 children: [
 Stack(
 children: [
 Align(
 alignment: Alignment.topLeft,
 child: Row(
 children: [
 Container(
 width: 44,
 height: 44,
 decoration: BoxDecoration(
 color: accent.withOpacity(0.12),
 borderRadius: BorderRadius.circular(14),
 border: Border.all(color: accent.withOpacity(0.2)),
 ),
 child: Icon(icon, color: accent, size: 22),
 ),
 const SizedBox(width: 12),
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
 ],
 ),
 ),
 if (trailing != null)
 Align(
 alignment: Alignment.topRight,
 child: trailing!,
 ),
 ],
 ),
 const SizedBox(height: 16),
 child,
 ],
 ),
 );
 }
}
