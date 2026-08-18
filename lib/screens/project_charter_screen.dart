import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'dart:convert';
import 'package:crypto/crypto.dart';

import 'package:ndu_project/widgets/responsive.dart';
import 'package:ndu_project/widgets/responsive_scaffold.dart';
import 'package:ndu_project/widgets/launch_phase_navigation.dart';
import 'package:ndu_project/models/project_data_model.dart';
import 'package:ndu_project/providers/project_data_provider.dart';
import 'package:ndu_project/screens/project_framework_screen.dart';
import 'package:ndu_project/screens/program_basics_screen.dart' show ProjectDetailsScreen;
import 'package:ndu_project/screens/core_stakeholders_screen.dart';
import 'package:ndu_project/utils/project_data_helper.dart';
import 'package:ndu_project/utils/front_end_planning_navigation.dart';
import 'package:ndu_project/utils/charter_lock_helper.dart';
import 'package:ndu_project/services/charter_approval_service.dart';
import 'package:ndu_project/services/openai_service_secure.dart';
import 'package:ndu_project/services/api_key_manager.dart';
import 'package:ndu_project/widgets/page_regenerate_all_button.dart';

import 'package:ndu_project/screens/project_charter_sections.dart';
import 'package:ndu_project/screens/charter_governance_section.dart';
import 'package:ndu_project/widgets/kaz_ai_chat_bubble.dart';
import 'package:ndu_project/widgets/front_end_planning_header.dart';
import 'package:ndu_project/utils/pdf_export_helper.dart';

class ProjectCharterScreen extends StatefulWidget {
 const ProjectCharterScreen({super.key});

 static void open(BuildContext context) {
 context.push('/project-charter');
 }

 @override
 State<ProjectCharterScreen> createState() => _ProjectCharterScreenState();
}

class _ProjectCharterScreenState extends State<ProjectCharterScreen> {
 ProjectDataModel? _projectData;
 bool _isGenerating = false;
 late final OpenAiServiceSecure _openAi;
 @override
 void initState() {
 super.initState();
 _openAi = OpenAiServiceSecure();
 ApiKeyManager.initializeApiKey();
 WidgetsBinding.instance.addPostFrameCallback((_) async {
 final provider = ProjectDataInherited.read(context);
 if (mounted) {
 setState(() {
 _projectData = provider.projectData;
 });

 // Auto-carry stakeholders from the preferred solution into the
 // planning-phase stakeholder register (`stakeholderEntries`).
 // Idempotent — only adds stakeholders that aren't already present.
 if (_projectData != null) {
 _carryStakeholdersFromPreferredSolution(_projectData!);
 }

 // Auto-generate charter content if needed
 if (_projectData != null) {
 await _ensureCharterContent();
 }
 }
 });
 }

 /// Pulls internal + external stakeholders from the preferred
 /// solution's `coreStakeholdersData` into the planning-phase
 /// `stakeholderEntries` list. This makes them visible on the
 /// charter (via CharterStakeholdersShort) AND auto-feeds the
 /// Planning phase stakeholder register.
 void _carryStakeholdersFromPreferredSolution(ProjectDataModel data) {
 try {
 final merged = CharterApprovalService
 .carryStakeholdersFromPreferredSolution(data);
 // Only write back if something actually changed (avoid spurious
 // provider updates that would trigger cloud sync).
 if (merged.length != data.stakeholderEntries.length) {
 final provider = ProjectDataInherited.read(context);
 provider.updateField((d) =>
 d.copyWith(stakeholderEntries: merged));
 setState(() {
 _projectData = provider.projectData;
 });
 }
 } catch (e) {
 debugPrint(
 'Charter: could not carry stakeholders from preferred solution: $e');
 }
 }

 Future<void> _exportPdf() async {
 final projectData = ProjectDataHelper.getData(context);
 final fep = projectData.frontEndPlanning;
 await PdfExportHelper.exportScreenPdf(
 context: context,
 screenTitle: 'Project Charter',
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
 super.dispose();
 }

 Future<void> _regenerateAllCharter() async {
 if (_projectData == null) return;
 // Defense-in-depth: charter is read-only once approved.
 // The button itself is hidden when locked, but block here too
 // so accidental callers (e.g. tests, future code) cannot mutate
 // an approved charter.
 if (CharterLockHelper.isFepLocked(_projectData)) {
 if (!mounted) return;
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(
 content: Text(
 'Charter is approved and locked. Regeneration is disabled.'),
 backgroundColor: Color(0xFFD97706),
 behavior: SnackBarBehavior.floating,
 duration: Duration(seconds: 3),
 ),
 );
 return;
 }
 final provider = ProjectDataInherited.read(context);
 provider.updateField((data) {
 return data.copyWith(
 businessCase: '',
 projectGoals: [],
 charterAssumptions: '',
 charterConstraints: '',
 );
 });
 setState(() {
 _projectData = provider.projectData;
 });
 await _ensureCharterContent();
 }

 Future<void> _ensureCharterContent() async {
 if (_projectData == null || _isGenerating) return;
 // Defense-in-depth: never regenerate an approved charter.
 if (CharterLockHelper.isFepLocked(_projectData)) return;

 // ── Task 9.8 — Charter caching ────────────────────────────────────
 // Compute a hash of the FEP source inputs that feed the charter. If the
 // hash matches the stored `charterSourceHash`, the cached charter content
 // is fresh and we skip regeneration entirely. If it differs (or the
 // charter has never been generated), we proceed to (re)generate.
 final currentSourceHash = _computeCharterSourceHash(_projectData!);
 final cachedHash = _projectData!.charterSourceHash;
 final cacheIsFresh = cachedHash.isNotEmpty && cachedHash == currentSourceHash;

 final needsOverview = _projectData!.businessCase.trim().isEmpty &&
 _projectData!.solutionDescription.trim().isEmpty;
 final needsAssumptions = _projectData!.charterAssumptions.trim().isEmpty;
 final needsConstraints = _projectData!.charterConstraints.trim().isEmpty;

 // If cache is fresh and no section is empty, return early — the cached
 // charter is still valid.
 if (cacheIsFresh && !needsOverview && !needsAssumptions && !needsConstraints) {
 return;
 }

 // If cache is fresh but a section was manually cleared, we still
 // regenerate only the missing section(s) without invalidating the
 // overall cache.
 if (!needsOverview && !needsAssumptions && !needsConstraints && !cacheIsFresh) {
 // All sections populated but cache hash differs → FEP inputs changed.
 // Force regeneration of all sections to keep the charter in sync.
 // (This branch is reached when the user edits FEP inputs after the
 // charter was first generated.)
 }

 setState(() => _isGenerating = true);

 try {
 final projectContext = ProjectDataHelper.buildFepContext(_projectData!);

 if (projectContext.trim().isNotEmpty) {
 // When the cache is stale (FEP inputs changed), force regeneration
 // of ALL sections by treating them as "needed" even if they have
 // existing content.
 final forceRegenerate = !cacheIsFresh && cachedHash.isNotEmpty;
 final regenOverview = needsOverview || forceRegenerate;
 final regenAssumptions = needsAssumptions || forceRegenerate;
 final regenConstraints = needsConstraints || forceRegenerate;

 if (regenOverview) {
 try {
 final overview = await _openAi.generateFepSectionText(
 section: 'Project Overview',
 context: projectContext,
 maxTokens: 600,
 );

 if (mounted && overview.isNotEmpty && _projectData != null) {
 final provider = ProjectDataInherited.read(context);
 provider.updateField((data) {
 // Only overwrite if regenerating (cache stale) or field
 // is empty (first-time generation).
 if (forceRegenerate ||
 data.businessCase.trim().isEmpty) {
 return data.copyWith(businessCase: overview);
 }
 return data;
 });

 setState(() {
 _projectData = provider.projectData;
 });
 }
 } catch (e) {
 debugPrint('Error generating charter overview: $e');
 }
 }

 if (regenAssumptions || regenConstraints) {
 if (!mounted) return;
 final provider = ProjectDataInherited.read(context);
 if (regenAssumptions) {
 try {
 final assumptions = await _openAi.generateFepSectionText(
 section: 'Assumptions',
 context: projectContext,
 maxTokens: 320,
 );
 if (mounted && assumptions.trim().isNotEmpty) {
 provider.updateField((data) =>
 data.copyWith(charterAssumptions: assumptions.trim()));
 }
 } catch (e) {
 debugPrint('Error generating charter assumptions: $e');
 }
 }
 if (regenConstraints) {
 try {
 final constraints = await _openAi.generateFepSectionText(
 section: 'Constraints',
 context: projectContext,
 maxTokens: 320,
 );
 if (mounted && constraints.trim().isNotEmpty) {
 provider.updateField((data) =>
 data.copyWith(charterConstraints: constraints.trim()));
 }
 } catch (e) {
 debugPrint('Error generating charter constraints: $e');
 }
 }
 if (mounted) {
 setState(() {
 _projectData = provider.projectData;
 });
 }
 }

 // ── Stamp the cache hash ─────────────────────────────────────────
 // After successful generation, persist the new source hash so future
 // opens can skip regeneration when nothing has changed.
 if (mounted) {
 final provider = ProjectDataInherited.read(context);
 provider.updateField((data) =>
 data.copyWith(charterSourceHash: currentSourceHash));
 if (mounted) {
 setState(() {
 _projectData = provider.projectData;
 });
 }
 }
 }
 } catch (e) {
 debugPrint('Error ensuring charter content: $e');
 } finally {
 if (mounted) {
 setState(() => _isGenerating = false);
 }
 }
 }

 /// Task 9.8 — Computes a stable SHA-1 hash of the FEP source inputs
 /// that the charter depends on. When any of these inputs change, the
 /// hash changes, and the charter is eligible for regeneration.
 String _computeCharterSourceHash(ProjectDataModel data) {
 final fep = data.frontEndPlanning;
 final buffer = StringBuffer()
 ..write(data.projectName ?? '')
 ..write('|')
 ..write(data.projectObjective)
 ..write('|')
 ..write(data.solutionTitle)
 ..write('|')
 ..write(data.solutionDescription)
 ..write('|')
 ..write(data.businessCase)
 ..write('|')
 ..write(data.overallFramework ?? '')
 ..write('|')
 ..write(fep.requirements)
 ..write('|')
 ..write(fep.requirementsNotes)
 ..write('|')
 ..write(fep.infrastructure)
 ..write('|')
 ..write(fep.security)
 ..write('|')
 ..write(fep.procurement)
 ..write('|')
 ..write(fep.allowance)
 ..write('|')
 ..write(fep.summary)
 ..write('|')
 ..write(fep.technology)
 ..write('|')
 ..write(fep.personnel)
 ..write('|')
 ..write(fep.contracts)
 ..write('|')
 ..write(fep.milestoneStartDate)
 ..write('|')
 ..write(fep.milestoneEndDate);
 final bytes = utf8.encode(buffer.toString());
 return sha1.convert(bytes).toString();
 }

 Future<void> _generateSection(String sectionType) async {
 if (_projectData == null || _isGenerating) return;
 // Defense-in-depth: charter is read-only once approved.
 if (CharterLockHelper.isFepLocked(_projectData)) {
 if (!mounted) return;
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(
 content: Text(
 'Charter is approved and locked. Section regeneration is disabled.'),
 backgroundColor: Color(0xFFD97706),
 behavior: SnackBarBehavior.floating,
 duration: Duration(seconds: 3),
 ),
 );
 return;
 }
 setState(() => _isGenerating = true);

 try {
 final contextText = ProjectDataHelper.buildFepContext(_projectData!);
 final provider = ProjectDataInherited.read(context);

 if (sectionType == 'definition') {
 final overview = await _openAi.generateFepSectionText(
 section: 'Project Overview and Business Case',
 context: contextText,
 maxTokens: 800,
 );
 if (mounted && overview.isNotEmpty) {
 provider.updateField((data) => data.copyWith(
 businessCase: overview,
 ));
 }
 }

 if (mounted) {
 setState(() {
 _projectData = provider.projectData;
 });
 }
 } catch (e) {
 debugPrint('Error generating $sectionType: $e');
 if (mounted) {
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(content: Text('Failed to generate $sectionType: $e')),
 );
 }
 } finally {
 if (mounted) {
 setState(() => _isGenerating = false);
 }
 }
 }

 /// Navigate the user back to the Project Details page (where project
 /// scope is actually edited). The charter merely reflects that page.
 void _navigateToProjectDetails() {
 try {
 context.push('/project-details');
 } catch (e) {
 debugPrint('Could not navigate to Project Details: $e');
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(
 content: Text(
 'Project Details page is reachable from the sidebar under Front End Planning → Project Details.'),
 duration: Duration(seconds: 4),
 ),
 );
 }
 }

 /// Navigate to the Core Stakeholders screen so the user can edit the
 /// stakeholders that the charter inherits from the preferred solution.
 void _navigateToCoreStakeholders() {
   try {
     final data = _projectData;
     context.push('/core-stakeholders', extra: CoreStakeholdersScreen(
           notes: data?.coreStakeholdersData?.notes ?? data?.notes ?? '',
           solutions: const [],
           businessCase: data?.businessCase ?? '',
         ));
   } catch (e) {
     debugPrint('Could not navigate to Core Stakeholders: $e');
     ScaffoldMessenger.of(context).showSnackBar(
       const SnackBar(
         content: Text(
             'Core Stakeholders page is reachable from the sidebar under Initiation → Core Stakeholders.'),
         duration: Duration(seconds: 4),
       ),
     );
   }
 }

 /// Navigate to the Preferred Solution Analysis screen so the user can
 /// view the preferred solution that supplies IT considerations and
 /// infrastructure to the charter. The Business Case section is locked
 /// once a preferred solution is selected, but the charter's
 /// "Technical & Procurement" bento remains tailorable via the inline
 /// Edit affordance — see [_saveCharterITOverride] and
 /// [_saveCharterInfraOverride].
  void _navigateToBusinessCase() {
    try {
      context.push('/preferred-solution-analysis');
   } catch (e) {
     debugPrint('Could not navigate to Preferred Solution Analysis: $e');
     ScaffoldMessenger.of(context).showSnackBar(
       const SnackBar(
         content: Text(
             'Preferred Solution Analysis is reachable from the sidebar under Initiation → Preferred Solution Analysis.'),
         duration: Duration(seconds: 4),
       ),
     );
   }
 }

 /// Save a charter-side override for the IT Considerations text shown
 /// in the "Technical & Procurement" bento. The Business Case section
 /// itself stays locked — this only updates the charter's display.
 /// Pass an empty string to revert to the preferred-solution text.
  void _saveCharterITOverride(String text) {
    final provider = ProjectDataInherited.read(context);
    provider.updateField(
        (d) => d.copyWith(charterITOverride: text));
    setState(() {
      _projectData = provider.projectData;
    });
  }

 /// Save a charter-side override for the Infrastructure text shown in
 /// the "Technical & Procurement" bento. The Business Case section
 /// itself stays locked — this only updates the charter's display.
  void _saveCharterInfraOverride(String text) {
    final provider = ProjectDataInherited.read(context);
    provider.updateField(
        (d) => d.copyWith(charterInfraOverride: text));
    setState(() {
      _projectData = provider.projectData;
    });
  }

 /// Clear the charter-side IT override so the section reverts to the
 /// preferred-solution text.
  void _clearCharterITOverride() {
    final provider = ProjectDataInherited.read(context);
    provider.updateField(
        (d) => d.copyWith(charterITOverride: ''));
    setState(() {
      _projectData = provider.projectData;
    });
  }

 /// Clear the charter-side Infrastructure override so the section
 /// reverts to the preferred-solution text.
  void _clearCharterInfraOverride() {
    final provider = ProjectDataInherited.read(context);
    provider.updateField(
        (d) => d.copyWith(charterInfraOverride: ''));
    setState(() {
      _projectData = provider.projectData;
    });
  }

 @override
 Widget build(BuildContext context) {
 final pagePadding = AppBreakpoints.pagePadding(context);
 final isMobile = AppBreakpoints.isMobile(context);

 return ResponsiveScaffold(
 activeItemLabel: 'Project Charter',
 appBarTitle: 'Project Charter',
 backgroundColor: Colors.white,
 floatingActionButton: const KazAiChatBubble(positioned: false),
 body: _isGenerating
 ? Center(
 child: Column(
 mainAxisAlignment: MainAxisAlignment.center,
 children: [
 const CircularProgressIndicator(),
 const SizedBox(height: 16),
 Text(
 'Generating project charter...',
 style: Theme.of(context).textTheme.bodyLarge,
 ),
 ],
 ),
 )
 : Stack(
 children: [
 // Main scrollable content
 SingleChildScrollView(
 padding: EdgeInsets.only(
 left: pagePadding,
 right: pagePadding,
 top: pagePadding + (isMobile ? 16 : 24),
 bottom: 120, // Space for floating approval bar
 ),
 child: Center(
 child: ConstrainedBox(
 constraints: const BoxConstraints(maxWidth: 1400),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.stretch,
 children: [
 FrontEndPlanningHeader(title: 'Project Charter', onExportPdf: _exportPdf),
 const SizedBox(height: 16),
 // Lock banner — shows when charter is approved. FEP becomes
 // read-only and the Planning phase is unlocked.
 CharterLockHelper.lockBanner(_projectData, screenLabel: 'Charter'),

 // ─── 1. Hero Header ───
 CharterHeroHeader(
 data: _projectData,
 onRegenerateAll: () async {
 final confirmed =
 await showRegenerateAllConfirmation(context);
 if (confirmed && mounted) {
 await _regenerateAllCharter();
 }
 },
 isLoading: _isGenerating,
 ),
 const SizedBox(height: 24),

 // ─── 2. Dashboard Stats Grid ───
 CharterDashboardStats(data: _projectData),
 const SizedBox(height: 24),

 // ─── 2b. Assign Manager Walkthrough (only when no PM) ───
 if (_projectData != null &&
 _projectData!.charterProjectManagerName.trim().isEmpty) ...[
 AssignManagerWalkthrough(
 onAssignTapped: () {
 // Trigger the meta info scroll's assign dialog via a key or public method
 // For simplicity, show a snackbar directing user to the card below
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(
 content: Text('Tap the "PROJECT MANAGER" card below to assign a manager.'),
 behavior: SnackBarBehavior.floating,
 ),
 );
 },
 ),
 const SizedBox(height: 16),
 ],

 // ─── 3. Meta Info Horizontal Scroll ───
 CharterMetaInfoScroll(data: _projectData),
 const SizedBox(height: 24),

 // ─── 4. Project Definition Bento (2-col grid) ───
 LayoutBuilder(
 builder: (context, constraints) {
 final isWide = constraints.maxWidth >= 768;
 if (isWide) {
 return Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 // Left column
 Expanded(
 child: Column(
 children: [
 CharterProjectDefinition(
 data: _projectData,
 onGenerate: () =>
 _generateSection('definition'),
 ),
 const SizedBox(height: 12),
 CharterSuccessCriteria(
 data: _projectData),
 ],
 ),
 ),
 const SizedBox(width: 12),
 // Right column
 Expanded(
 child: Column(
 children: [
 CharterFinancialOverview(
 data: _projectData),
 const SizedBox(height: 12),
 CharterScope(
 data: _projectData,
 // AI Generate intentionally removed — the charter
 // reflects the Project Details page. Edit takes the
 // user back to that page in the same FEP.
 onEdit: () => _navigateToProjectDetails(),
 ),
 ],
 ),
 ),
 ],
 );
 }
 // Mobile: single column
 return Column(
 children: [
 CharterProjectDefinition(
 data: _projectData,
 onGenerate: () =>
 _generateSection('definition'),
 ),
 const SizedBox(height: 12),
 CharterFinancialOverview(data: _projectData),
 const SizedBox(height: 12),
 CharterSuccessCriteria(data: _projectData),
 const SizedBox(height: 12),
 CharterScope(
 data: _projectData,
 onEdit: () => _navigateToProjectDetails(),
 ),
 ],
 );
 },
 ),
 const SizedBox(height: 24),

 // ─── 5. Key Risks Section ───
 CharterRisks(
 data: _projectData,
 // AI Generate intentionally removed — risks are reflected from
 // the dedicated Risks page; charter is read-only here.
 ),
 const SizedBox(height: 24),

 // ─── 6. Technical & Procurement Bento ───
 CharterTechnicalProcurementBento(
 data: _projectData,
 // AI Generate intentionally removed — IT/Infrastructure comes from
 // the preferred solution (Business Case section, locked once a
 // preferred solution is selected). onEdit takes the user to view
 // the preferred solution. onSaveITOverride / onSaveInfraOverride
 // let the user tailor the wording shown in the charter directly
 // (the Business Case itself stays locked).
 onEdit: () => _navigateToBusinessCase(),
 onSaveITOverride: (text) => _saveCharterITOverride(text),
 onSaveInfraOverride: (text) => _saveCharterInfraOverride(text),
 onClearITOverride: () => _clearCharterITOverride(),
 onClearInfraOverride: () => _clearCharterInfraOverride(),
 ),
 const SizedBox(height: 24),

 // ─── 7. Tentative Schedule Timeline ───
 CharterScheduleTimeline(data: _projectData),
 const SizedBox(height: 24),

 // ─── 8. Governance Section ───
 CharterGovernanceSection(
 data: _projectData,
 onEditStakeholders: () => _navigateToCoreStakeholders(),
 ),
 const SizedBox(height: 24),

 // ─── 9. Assumptions (Collapsible) ───
 CharterAssumptions(data: _projectData),
 const SizedBox(height: 32),

 // ─── 10. Launch Phase Navigation ───
 LaunchPhaseNavigation(
 backLabel: 'Back',
 nextLabel: 'Next',
 nextEnabled:
 _projectData?.charterProjectManagerName.isNotEmpty == true &&
 (_projectData?.charterApprovalDate != null ||
 _projectData?.frontEndPlanning.charterApproved == true),
 onBack: () => FrontEndPlanningNavigation.goToPrevious(
 context,
 'project_charter',
 ),
 onNext: () {
 // Block navigation if no manager is assigned
 if (_projectData == null ||
 _projectData!.charterProjectManagerName.trim().isEmpty) {
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(
 content: Text(
 'Please assign a Project Manager before proceeding. '
 'Tap "Assign Manager" in the Project Manager card.'),
 backgroundColor: Color(0xFFDC2626),
 duration: Duration(seconds: 4),
 ),
 );
 return;
 }
 // BLOCK: Charter must be approved before Planning phase is
 // unlocked. Once approved, FEP sections are locked.
 final isCharterApproved =
 _projectData!.charterApprovalDate != null ||
 _projectData!.frontEndPlanning.charterApproved == true;
 if (!isCharterApproved) {
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(
 content: Text(
 'Charter to be approved by sponsor, owner or applicable lead '
 'before the Planning phase is unlocked. Scroll to the '
 'Governance section to review and approve.'),
 backgroundColor: Color(0xFFD97706),
 duration: Duration(seconds: 5),
 behavior: SnackBarBehavior.floating,
 ),
 );
 return;
 }
 ProjectFrameworkScreen.open(context);
 },
 ),
 ],
 ),
 ),
 ),
 ),

 // ─── Floating Approval Action Bar ───
 Positioned(
 left: 0,
 right: 0,
 bottom: 0,
 child: CharterFloatingApprovalBar(data: _projectData),
 ),
 ],
 ),
 );
 }
}
